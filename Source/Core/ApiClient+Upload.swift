//
//  
//

import Foundation

/// A protocol defining a generic upload task, requiring a URLSessionUploadTask object.
protocol AnyUploadTask: AnyObject {
  /// A URLSessionUploadTask associated with the conforming instance.
  var task: URLSessionUploadTask! { get }
  func start()
  func cancel()
}

/// A concrete class that represents a network upload task for a specific response type.
public final class UploadTask<ResponseType>: NetworkCancellable, Hashable, AnyUploadTask {
  
  /// A closure type for monitoring the progress of an upload task.
  public typealias ProgressCompletion = (_ progress: Progress) -> Void
  
  /// A closure type for receiving the result of an upload task.
  public typealias ResultCompletion = (_ response: Response<ResponseType>) -> Void
  
  /// Enumerates the various states of an upload task.
  public enum UploadState {
    case waitingStart
    case paused
    case uploading
    case completed
    case cancelled
    case error
  }
  
  // MARK: - Internal Properties
  
  /// The underlying URLSessionUploadTask. Read-only to external entities but writable internally.
  private(set) var task: URLSessionUploadTask!
  
  // MARK: - Private Properties
  
  /// A URLSession instance for managing network tasks.
  private var session: URLSession
  
  /// The URLRequest configured for the remote upload.
  private var remoteURLRequest: URLRequest
  
  /// The data being uploaded.
  private var uploadData: Data
  
  /// Endpoint information including how to construct the URLRequest.
  private var endpoint: any Requestable

  /// Whether the global debug flag is enabled.
  private var globalDebug: Bool
  
  /// Observes the progress of the upload task.
  private var progressObserver: NSKeyValueObservation?
  
  /// Data representing a partially completed upload, for use with resuming.
  private var resumedData: Data?

  private var generation = 0
  
  // MARK: - Public Properties
  
  /// The current state of the upload task.
  public var state: UploadState = .waitingStart
  
  // MARK: - Results Closures
  
  /// Collections of closures and queues for progress updates.
  private var uploadProgressClosures = [(closure: ProgressCompletion, queue: DispatchQueue)]()
  
  /// Collections of closures and queues for handling the response.
  private var responseClosures = [(closure: ResultCompletion, queue: DispatchQueue)]()
  
  /// A closure that is called when the upload is completed.
  private var onUploadCompleted: (_ upload: ObjectIdentifier) -> Void

  private let onResume: (_ upload: any AnyUploadTask) -> Void

  private let decode: (Data?) throws -> ResponseType
  
  // MARK: - Lifecycle
  
  /// Initializes a new `UploadTask` with the necessary configuration and callbacks.
  init(
    session: URLSession,
    endpoint: any Requestable,
    config: NetworkConfigurable,
    decode: @escaping (Data?) throws -> ResponseType,
    onUploadCompleted: @escaping (_ upload: ObjectIdentifier) -> Void,
    onResume: @escaping (_ upload: any AnyUploadTask) -> Void
  ) throws {
    self.session = session
    self.endpoint = endpoint
    self.globalDebug = config.debug
    self.decode = decode
    self.onUploadCompleted = onUploadCompleted
    self.onResume = onResume
    self.remoteURLRequest = try endpoint.urlRequest(with: config)
    self.remoteURLRequest.httpBody = nil
    guard let data = endpoint.form?.data else {
      throw NSError(domain: "1", code: 1)
    }
    self.uploadData = data
  }
  
  func start() {
    if #available(iOS 17.0, macOS 14.0, *), let resumedData {
      self.resumedData = nil
      startTask { session.uploadTask(withResumeData: resumedData, completionHandler: $0) }
    } else {
      startTask { session.uploadTask(with: remoteURLRequest, from: uploadData, completionHandler: $0) }
    }
  }

  // MARK: - Private Methods

  private func startTask(
    _ makeTask: (@escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask
  ) {
    generation += 1
    let taskGeneration = generation
    task = makeTask { [weak self] data, response, error in
      guard let self, taskGeneration == generation else { return }
      if let responseError = handleCommonResponse(data: data, response: response, error: error) {
        handleErrorResponse(error: responseError)
        return
      }
      do {
        handleSuccessResponse(responseObject: try decode(data))
      } catch {
        handleErrorResponse(error: error as? NetworkError ?? .parsingFailed(from: error))
      }
    }
    observeUploadProgress()
    task.resume()
    state = .uploading
  }

  /// Sets up observation for the upload progress and handles the progress updates.
  private func observeUploadProgress() {
    progressObserver?.invalidate()
    progressObserver = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
      guard let self else { return }
      self.uploadProgressClosures.forEach { uploadProgress in
        uploadProgress.queue.async {
          uploadProgress.closure(progress)
        }
      }
    }
  }
 
  // MARK: - Public Methods
  
  /// Cancels the upload task and marks its state as cancelled.
  public func cancel() {
    progressObserver?.invalidate()
    if state == .waitingStart || state == .paused {
      state = .cancelled
      handleErrorResponse(error: .generic(URLError(.cancelled)))
      return
    }
    task?.resume()
    task?.cancel()
    state = .cancelled
  }
  
  /// Pauses the currently uploading task. If the task is not uploading, the function does nothing.
  /// Changes the task's state to paused, frees its upload slot and stores the resume data for later continuation.
  /// Available only on iOS 17.0 and later.
  @available(iOS 17.0, macOS 14.0, *)
  public func pause() {
    guard state == .uploading else { return }
    progressObserver?.invalidate()
    generation += 1
    resumedData = nil
    task.resume()
    task.cancel(byProducingResumeData: { data in
      self.resumedData = data
    })
    state = .paused
    onUploadCompleted(ObjectIdentifier(self))
  }
  
  /// Resumes an upload task that was previously paused, ensuring it continues from where it left off if resume data is available.
  /// If no resume data is found, it restarts the upload task. When every upload slot is busy, it waits at the front of the queue.
  /// This function is only available on iOS 17.0 and later, and macOS 14.0 and later.
  @available(iOS 17.0, macOS 14.0, *)
  public func resume() {
    guard state == .paused else { return }
    state = .waitingStart
    onResume(self)
  }
  
  /// Adds a progress closure to be called during the upload.
  @discardableResult
  public func progress(
    queue: DispatchQueue = .global(qos: .background),
    completion: @escaping ProgressCompletion
  ) -> Self {
    uploadProgressClosures.append((completion, queue))
    return self
  }
  
  /// Adds a response closure to be called when the upload is completed.
  @discardableResult
  public func response(
    queue: DispatchQueue = .main,
    completion: @escaping ResultCompletion
  ) -> Self {
    responseClosures.append((completion, queue))
    return self
  }
  
  /// Conforms to Hashable by combining the instance identity into the hasher.
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
  
  /// Checks equality between two `UploadTask` instances based on their identity.
  public static func == (lhs: UploadTask<ResponseType>, rhs: UploadTask<ResponseType>) -> Bool {
    lhs === rhs
  }
}

/// Extension to `UploadTask` providing response and error handling utilities.
private extension UploadTask {
  /// Evaluates the HTTP response and error to determine if the response is valid and to identify any network errors.
  func handleCommonResponse(data: Data?, response: URLResponse?, error: Error?) -> NetworkError? {
    if endpoint.debugRequest ?? globalDebug {
      ApiClient.printCurl(
        session: session,
        request: remoteURLRequest,
        response: response,
        data: data
      )
    }
    
    if let error {
      return .generic(error)
    }
    guard let statusCode = response?.httpStatusCode else {
      return .emptyResponse
    }
    return (200..<300).contains(statusCode) ? nil : .error(statusCode: statusCode, data: data)
  }
  
  /// Processes and distributes an error response to all registered response closures and updates the task state.
  func handleErrorResponse(error: NetworkError) {
    responseClosures.forEach { responseClosure in
      responseClosure.queue.async {
        responseClosure.closure(Response(result: .failure(error)))
      }
    }
    if state != .cancelled {
      state = .error
    }
    onUploadCompleted(ObjectIdentifier(self))
  }
  
  /// Processes and distributes a successful response to all registered response closures and updates the task state.
  func handleSuccessResponse(responseObject: ResponseType) {
    responseClosures.forEach { responseClosure in
      responseClosure.queue.async {
        responseClosure.closure(Response(result: .success(responseObject)))
      }
    }
    state = .completed
    onUploadCompleted(ObjectIdentifier(self))
  }
}

// MARK: - Upload MultipartFormEndpoint

/// Extension of `ApiClient` to provide upload functionality
extension ApiClient {
  /// Creates an upload task with the specified endpoint.
  ///
  /// This function initializes an `UploadTask` with the necessary configuration for uploading data to a server.
  /// It ensures that the session is valid before proceeding with the task creation. Upon completion of the upload,
  /// the task is removed from the active tasks list.
  ///
  /// - Parameter endpoint: The endpoint that defines the URL, HTTP method, headers, and other request details.
  /// - Returns: An initialized `UploadTask` object ready to start the upload process.
  /// - Throws: `NetworkError.invalidSessions` if the URLSession is not available.
  func createUploadTask<T>(
    with endpoint: MultipartFormEndpoint<T>,
    decode: @escaping (Data?) throws -> T
  ) throws -> UploadTask<T> {
    guard let session = session else {
      throw NetworkError.invalidSessions
    }
    
    return try UploadTask(
      session: session,
      endpoint: endpoint,
      config: config,
      decode: decode,
      onUploadCompleted: { [weak self] upload in
        guard let self else { return }
        uploadQueue.sync {
          _ = self.uploadsTasks.removeValue(forKey: upload)
          self.pendingUploads.removeAll { ObjectIdentifier($0) == upload }
        }
        startNextPendingUpload()
      },
      onResume: { [weak self] upload in
        guard let self, self.session != nil else {
          upload.cancel()
          return
        }
        enqueue(upload, atFront: true)
      }
    )
  }

  func enqueueUpload<T>(
    _ endpoint: MultipartFormEndpoint<T>,
    decode: @escaping (Data?) throws -> T
  ) throws -> UploadTask<T> {
    let upload = try createUploadTask(with: endpoint, decode: decode)
    enqueue(upload)
    return upload
  }

  func enqueue(_ upload: any AnyUploadTask, atFront: Bool = false) {
    uploadQueue.sync {
      if uploadsTasks.count < maxConcurrentUploads {
        upload.start()
        uploadsTasks[ObjectIdentifier(upload)] = upload
      } else {
        pendingUploads.insert(upload, at: atFront ? 0 : pendingUploads.endIndex)
      }
    }
  }

  func startNextPendingUpload() {
    uploadQueue.sync {
      while uploadsTasks.count < maxConcurrentUploads && !pendingUploads.isEmpty {
        let pendingUpload = pendingUploads.removeFirst()
        pendingUpload.start()
        uploadsTasks[ObjectIdentifier(pendingUpload)] = pendingUpload
      }
    }
  }
  
  /// Initiates an upload task for a decodable response type using the specified endpoint.
  ///
  /// - Parameter endpoint: The `MultipartFormEndpoint<D>` detailing the upload's configuration.
  /// - Returns: An `UploadTask<D>` instance, ready for execution, where `D` is the expected
  ///   `Decodable` response type.
  /// - Throws: Errors from task creation, such as `NetworkError.invalidSessions`, if the session
  ///   isn't properly configured.
  public func upload<D>(
    with endpoint: MultipartFormEndpoint<D>
  ) throws -> UploadTask<D> where D: Decodable {
    try enqueueUpload(endpoint) { data in
      guard let data else { throw NetworkError.emptyResponse }
      return try JSONDecoder().decode(D.self, from: data)
    }
  }
  
  /// Initiates an upload task for a decodable response type using the specified endpoint.
  ///
  /// - Parameter endpoint: The `MultipartFormEndpoint<D>` detailing the upload's configuration.
  /// - Returns: An `UploadTask<D>` instance, ready for execution, where `D` is the expected
  ///   `String` response type.
  /// - Throws: Errors from task creation, such as `NetworkError.invalidSessions`, if the session
  ///   isn't properly configured.
  public func upload(
    with endpoint: MultipartFormEndpoint<String>
  ) throws -> UploadTask<String> {
    try enqueueUpload(endpoint) { data in
      guard let data else { throw NetworkError.emptyResponse }
      guard let string = String(data: data, encoding: .utf8) else { throw NetworkError.dataToStringFailure(data: data) }
      return string
    }
  }
  
  /// Initiates an upload task for a decodable response type using the specified endpoint.
  ///
  /// - Parameter endpoint: The `MultipartFormEndpoint<D>` detailing the upload's configuration.
  /// - Returns: An `UploadTask<D>` instance, ready for execution, where `D` is the expected
  ///   `Void` response type.
  /// - Throws: Errors from task creation, such as `NetworkError.invalidSessions`, if the session
  ///   isn't properly configured.
  public func upload(
    with endpoint: MultipartFormEndpoint<Void>
  ) throws -> UploadTask<Void> {
    try enqueueUpload(endpoint) { _ in }
  }
  
  /// Initiates an upload task for a decodable response type using the specified endpoint.
  ///
  /// - Parameter endpoint: The `MultipartFormEndpoint<D>` detailing the upload's configuration.
  /// - Returns: An `UploadTask<D>` instance, ready for execution, where `D` is the expected
  ///   `Data` response type.
  /// - Throws: Errors from task creation, such as `NetworkError.invalidSessions`, if the session
  ///   isn't properly configured.
  public func upload(
    with endpoint: MultipartFormEndpoint<Data>
  ) throws -> UploadTask<Data> {
    try enqueueUpload(endpoint) { data in
      guard let data else { throw NetworkError.emptyResponse }
      return data
    }
  }
}

//
//  
//

import Foundation

/// A protocol defining a generic upload task, requiring a URLSessionUploadTask object.
protocol AnyUploadTask: Hashable {
  /// A URLSessionUploadTask associated with the conforming instance.
  var task: URLSessionUploadTask! { get }
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
  
  /// Observes the progress of the upload task.
  private var progressObserver: NSKeyValueObservation?
  
  /// Data representing a partially completed upload, for use with resuming.
  private var resumedData: Data?
  
  // MARK: - Public Properties
  
  /// The current state of the upload task.
  public var state: UploadState = .waitingStart
  
  // MARK: - Results Closures
  
  /// Collections of closures and queues for progress updates.
  private var uploadProgressClosures = [(closure: ProgressCompletion, queue: DispatchQueue)]()
  
  /// Collections of closures and queues for handling the response.
  private var responseClosures = [(closure: ResultCompletion, queue: DispatchQueue)]()
  
  /// A closure that is called when the upload is completed.
  private var onUploadCompleted: (_ taskIdentifier: Int) -> Void
  
  // MARK: - Lifecycle
  
  /// Initializes a new `UploadTask` with the necessary configuration and callbacks.
  init(
    session: URLSession,
    endpoint: any Requestable,
    config: NetworkConfigurable,
    onUploadCompleted: @escaping (_ taskIdentifier: Int) -> Void
  ) throws {
    self.session = session
    self.endpoint = endpoint
    self.onUploadCompleted = onUploadCompleted
    self.remoteURLRequest = try endpoint.urlRequest(with: config)
    self.remoteURLRequest.httpBody = nil
    guard let data = endpoint.form?.data else {
      throw NSError(domain: "1", code: 1)
    }
    self.uploadData = data
  }
  
  // MARK: - Private Methods
  
  /// Resumes the upload using a previously paused data blob, available only on iOS 17.0 and later.
  @available(iOS 17.0, *)
  @available(macOS 14.0, *)
  private func resumeUploadWithData(_ data: Data) {
    task = session.uploadTask(withResumeData: data)
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
    task.resume()
    task.cancel()
    state = .cancelled
  }
  
  /// Pauses the upload task if it's currently uploading, available only on iOS 17.0 and later.
  @available(macOS 14.0, *)
  @available(iOS 17.0, *)
  public func pause() {
    guard state == .uploading else { return }
    progressObserver?.invalidate()
    task.resume()
    task.cancel(byProducingResumeData: { data in
      self.resumedData = data
    })
    state = .paused
  }
  
  /// Resumes the upload task from a paused state, available only on iOS 17.0 and later.
  @available(iOS 17.0, *)
  @available(macOS 14.0, *)
  public func resume() {
    guard state == .paused else { return }
    if let resumedData {
      resumeUploadWithData(resumedData)
    }
    else {
      task.cancel()
      task.resume()
      state = .uploading
    }
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
  
  /// Conforms to Hashable by combining the task identifier into the hasher.
  public func hash(into hasher: inout Hasher) {
    hasher.combine(task.taskIdentifier)
  }
  
  /// Checks equality between two `UploadTask` instances based on their task identifiers.
  public static func == (lhs: UploadTask<ResponseType>, rhs: UploadTask<ResponseType>) -> Bool {
    lhs.task.taskIdentifier == rhs.task.taskIdentifier
  }
}

/// Extension to `UploadTask` providing response and error handling utilities.
private extension UploadTask {
  /// Evaluates the HTTP response and error to determine if the response is valid and to identify any network errors.
  func handleCommonResponse(data: Data?, response: URLResponse?, error: Error?) -> (isValid: Bool, error: NetworkError?) {
    ApiClient.printCurl(
      session: session,
      request: remoteURLRequest,
      response: response,
      data: data
    )
    
    guard error == nil else {
      return (false, .generic(error!))
    }
    
    guard let httpResponse = response as? HTTPURLResponse else {
      return (false, .emptyResponse)
    }
    
    guard (200..<300).contains(httpResponse.statusCode) else {
      return (false, .error(statusCode: httpResponse.statusCode, data: nil))
    }
    
    return (true, nil)
  }
  
  /// Processes and distributes an error response to all registered response closures and updates the task state.
  func handleErrorResponse(error: NetworkError) {
    responseClosures.forEach { responseClosure in
      responseClosure.queue.async {
        responseClosure.closure(Response(result: .failure(error)))
      }
    }
    state = .error
  }
  
  /// Processes and distributes a successful response to all registered response closures and updates the task state.
  func handleSuccessResponse(responseObject: ResponseType) {
    responseClosures.forEach { responseClosure in
      responseClosure.queue.async {
        responseClosure.closure(Response(result: .success(responseObject)))
      }
    }
    state = .completed
    onUploadCompleted(task.taskIdentifier)
  }
}

/// Extension for `UploadTask` constrained to `ResponseType: Decodable`. It starts the upload task and handles JSON decoding.
extension UploadTask where ResponseType: Decodable {
  func start() {
    task = session.uploadTask(with: remoteURLRequest, from: uploadData) { [weak self] data, response, error in
      guard let self else { return }
      
      let (isValid, responseError) = self.handleCommonResponse(data: data, response: response, error: error)
      
      guard isValid else {
        self.handleErrorResponse(error: responseError!)
        return
      }
      
      guard let data else {
        self.handleErrorResponse(error: .invalidDownloadFileData)
        return
      }
      
      do {
        let responseObject = try JSONDecoder().decode(ResponseType.self, from: data)
        self.handleSuccessResponse(responseObject: responseObject)
      } catch {
        self.handleErrorResponse(error: .parsingFailed)
      }
    }
    observeUploadProgress()
    task.resume()
    state = .uploading
  }
}

/// Extension for `UploadTask` constrained to `ResponseType == Void`. It starts the upload task for cases expecting no response body.
extension UploadTask where ResponseType == Void {
  func start() {
    task = session.uploadTask(with: remoteURLRequest, from: uploadData) { [weak self] data, response, error in
      guard let self else { return }
      
      let (isValid, responseError) = self.handleCommonResponse(data: data, response: response, error: error)
      
      guard isValid else {
        self.handleErrorResponse(error: responseError!)
        return
      }
      
      self.handleSuccessResponse(responseObject: ())
    }
    observeUploadProgress()
    task.resume()
    state = .uploading
  }
}

/// Extension for `UploadTask` constrained to `ResponseType == String`. It starts the upload task and expects a string response.
extension UploadTask where ResponseType == String {
  func start() {
    task = session.uploadTask(with: remoteURLRequest, from: uploadData) { [weak self] data, response, error in
      guard let self else { return }
      
      let (isValid, responseError) = self.handleCommonResponse(data: data, response: response, error: error)
      
      guard isValid else {
        self.handleErrorResponse(error: responseError!)
        return
      }
      
      guard let data else {
        self.handleErrorResponse(error: .invalidDownloadFileData)
        return
      }
      
      guard let string = String(data: data, encoding: .utf8)
      else {
        self.handleErrorResponse(error: .dataToStringFailure(data: data))
        return
      }
      
      self.handleSuccessResponse(responseObject: string)
    }
    observeUploadProgress()
    task.resume()
    state = .uploading
  }
}

/// Extension for `UploadTask` constrained to `ResponseType == Data`. It starts the upload task expecting raw data as a response.
extension UploadTask where ResponseType == Data {
  func start() {
    task = session.uploadTask(with: remoteURLRequest, from: uploadData) { [weak self] data, response, error in
      guard let self else { return }
      
      let (isValid, responseError) = self.handleCommonResponse(data: data, response: response, error: error)
      
      guard isValid else {
        self.handleErrorResponse(error: responseError!)
        return
      }
      
      guard let data else {
        self.handleErrorResponse(error: .invalidDownloadFileData)
        return
      }

      self.handleSuccessResponse(responseObject: data)
    }
    observeUploadProgress()
    task.resume()
    state = .uploading
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
  func createUploadTask<T>(with endpoint: MultipartFormEndpoint<T>) throws -> UploadTask<T> {
    guard let session = session else {
      throw NetworkError.invalidSessions
    }
    
    return try UploadTask(
      session: session,
      endpoint: endpoint,
      config: config,
      onUploadCompleted: { [weak self] taskIdentifier in
        guard let self,
              let task = uploadsTasks.first(where: { $0.identifier == taskIdentifier })
        else { return }
        uploadsTasks.remove(task)
      }
    )
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
    let uploadTask = try createUploadTask(with: endpoint)
    
    if uploadsTasks.count < maxConcurrentUploads {
      uploadTask.start()
      uploadsTasks.insert(AnyProgressiveTransferTask(uploadTask))
    } else {
      pendingUploads.append(AnyProgressiveTransferTask(uploadTask))
    }
    
    return uploadTask
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
    let uploadTask = try createUploadTask(with: endpoint)
    
    if uploadsTasks.count < maxConcurrentUploads {
      uploadTask.start()
      uploadsTasks.insert(AnyProgressiveTransferTask(uploadTask))
    } else {
      pendingUploads.append(AnyProgressiveTransferTask(uploadTask))
    }
    
    return uploadTask
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
    let uploadTask = try createUploadTask(with: endpoint)
    
    if uploadsTasks.count < maxConcurrentUploads {
      uploadTask.start()
      uploadsTasks.insert(AnyProgressiveTransferTask(uploadTask))
    } else {
      pendingUploads.append(AnyProgressiveTransferTask(uploadTask))
    }
    
    return uploadTask
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
    let uploadTask = try createUploadTask(with: endpoint)
    
    if uploadsTasks.count < maxConcurrentUploads {
      uploadTask.start()
      uploadsTasks.insert(AnyProgressiveTransferTask(uploadTask))
    } else {
      pendingUploads.append(AnyProgressiveTransferTask(uploadTask))
    }
    
    return uploadTask
  }
}

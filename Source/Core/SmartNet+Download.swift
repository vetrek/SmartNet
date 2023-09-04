//
//  SmartNet+Download.swift
//
//  Copyright (c) 2021 Valerio69 (valerio.alsebas@gmail.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

public final class DownloadTask: NetworkCancellable, Hashable {
  
  public typealias ProgressCompletion = (_ progress: Progress, _ remoteFileSize: Int64) -> Void
  public typealias ResultCompletion = (_ response: Response<DownloadResult>) -> Void
  
  public struct DownloadResult {
    public var fileData: Data
    public var localURL: URL
  }
  
  public struct DownloadFileDestination {
    public let url: URL
    public let removePreviousFile: Bool
    
    public init(url: URL, removePreviousFile: Bool) {
      self.url = url
      self.removePreviousFile = removePreviousFile
    }
  }
  
  public enum DownloadState {
    case waitingStart
    case paused
    case downloading
    case completed
    case cancelled
    case error
  }
  
  // MARK: - Internal Properties
  
  private(set) var task: URLSessionDownloadTask!
  
  /// A value indicating the remote file size, read from Content-Length
  ///
  /// -1 indicates that the header was not provided
  var remoteFileSize: Int64 = .zero
  
  // MARK: - Private Properties
  
  private var session: URLSession
  private var remoteURLRequest: URLRequest
  private var remoteURL: URL
  private var progressObserver: NSKeyValueObservation?
  private var resumedData: Data?
  private var downloadDestination: DownloadFileDestination?
  
  // MARK: - Public Properties
  public var state: DownloadState = .waitingStart
  
  // MARK: - Results Closures
  
  private var downloadProgress: (closure: ProgressCompletion, queue: DispatchQueue)?
  private var response: (closure: ResultCompletion, queue: DispatchQueue)?
  
  // MARK: - Lifecycle
  
  init(
    session: URLSession,
    endpoint: DownloadEndpoint,
    config: NetworkConfigurable,
    destination: DownloadFileDestination?
  ) throws {
    self.session = session
    self.remoteURL = try endpoint.url(with: config)
    self.remoteURLRequest = try endpoint.urlRequest(with: config)
    self.downloadDestination = destination
  }
  
  init(
    session: URLSession,
    url: URL
  ) {
    self.session = session
    self.remoteURL = url
    self.remoteURLRequest = URLRequest(url: url)
  }
  
  // MARK: - Private Methods
  
  func startDownload() {
    task = session.downloadTask(with: remoteURLRequest)
    observeDownloadProgress()
    task.resume()
    state = .downloading
  }
  
  private func resumeDownloadWithData(_ data: Data) {
    task = session.downloadTask(withResumeData: data)
    observeDownloadProgress()
    task.resume()
    state = .downloading
  }
  
  private func observeDownloadProgress() {
    progressObserver?.invalidate()
    progressObserver = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
      guard let self = self else { return }
      self.downloadProgress?.queue.async {
        self.downloadProgress?.closure(progress, self.remoteFileSize)
      }
    }
  }
  
  internal func downloadHandler(
    tmpURL: URL?,
    urlResponse: URLResponse?,
    error: Error?
  ) {
    guard let response = response else {
      state = .error
      return
    }
    
    guard let httpResponse = urlResponse as? HTTPURLResponse else { return }
    
    guard (200..<300).contains(httpResponse.statusCode)
    else {
      response.queue.async { response.closure(Response(result: .failure(.error(statusCode: httpResponse.statusCode, data: nil)))) }
      return
    }
    
    guard let tmpURL = tmpURL else {
      response.queue.async { response.closure(Response(result: .failure(.invalidDownloadUrl))) }
      state = .error
      return
    }
    guard let data = try? Data(contentsOf: tmpURL) else {
      response.queue.async { response.closure(Response(result: .failure(.invalidDownloadFileData))) }
      state = .error
      return
    }
    
    // Try to move the file to the new URL
    var url = tmpURL
    if let downloadDestination = downloadDestination {
      guard moveFile(at: url, to: downloadDestination.url, shouldReplace: downloadDestination.removePreviousFile) else {
        response.queue.async { response.closure(Response(result: .failure(.unableToSaveFile(url)))) }
        return
      }
      url = downloadDestination.url
    }
    
    let result = DownloadResult(fileData: data, localURL: url)
    response.queue.async {
      response.closure(Response(result: .success(result)))
      self.state = .completed
    }
  }
  
  // MARK: - Public Methods
  
  public func cancel() {
    progressObserver?.invalidate()
    task.resume()
    task.cancel()
    state = .cancelled
  }
  
  public func pause() {
    guard state == .downloading else { return }
    progressObserver?.invalidate()
    task.resume()
    task.cancel(byProducingResumeData: { data in
      self.resumedData = data
    })
    state = .paused
  }
  
  public func resume() {
    guard state == .paused else { return }
    if let resumedData = resumedData {
      resumeDownloadWithData(resumedData)
    }
    else {
      task.cancel()
      startDownload()
    }
  }
  
  @discardableResult
  public func downloadProgress(
    queue: DispatchQueue = .global(qos: .background),
    completion: @escaping ProgressCompletion
  ) -> Self {
    downloadProgress = (completion, queue)
    return self
  }
  
  @discardableResult
  public func response(
    queue: DispatchQueue = .main,
    completion: @escaping ResultCompletion
  ) -> Self {
    response = (completion, queue)
    return self
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(task.taskIdentifier)
  }
  
  public static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
    lhs.task.taskIdentifier == rhs.task.taskIdentifier
  }
  
  private func moveFile(at currentURL: URL, to destinationURL: URL, shouldReplace: Bool) -> Bool {
    let fileManager = FileManager.default
    let targetURL = destinationURL.deletingLastPathComponent()
    
    do {
      // Create directory if needed
      if !fileManager.fileExists(atPath: targetURL.path) {
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
      }
      
      if fileManager.fileExists(atPath: destinationURL.path) {
        guard shouldReplace else { return true }
        _ = try fileManager.replaceItemAt(destinationURL, withItemAt: currentURL)
      } else {
        try fileManager.moveItem(at: currentURL, to: destinationURL)
      }
    }
    catch { return false }
    
    return true
  }
  
}

public extension SmartNet {
  func download(
    with endpoint: DownloadEndpoint,
    destination: DownloadTask.DownloadFileDestination? = nil
  ) -> DownloadTask? {
    guard
      let session = session,
      let downloadTask = try? DownloadTask(
        session: session,
        endpoint: endpoint,
        config: config,
        destination: destination
      )
    else { return nil }
    
    if downloadsTasks.count < maxConcurrentDownloads {
      downloadsTasks.insert(downloadTask)
      downloadTask.startDownload()
    } else {
      pendingDownloads.append(downloadTask)
    }
    
    return downloadTask
  }
  
  func download(
    with endpoint: DownloadEndpoint,
    destination: DownloadTask.DownloadFileDestination? = nil
  ) async throws -> DownloadTask.DownloadResult {
    return try await withCheckedThrowingContinuation { [weak self] continuation in
      do {
        guard
          let self,
          let session = self.session else {
          continuation.resume(throwing: NSError(domain: "SmartNet", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid Session"]))
          return
        }
        let downloadTask = try DownloadTask(
          session: session,
          endpoint: endpoint,
          config: config,
          destination: destination
        ).response { response in
          switch response.result {
          case let .success(result):
            continuation.resume(returning: result)
          case let .failure(error):
            continuation.resume(throwing: error)
          }
        }
        self.downloadsTasks.insert(downloadTask)
        
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
  
  func download(
    url: URL
  ) -> DownloadTask? {
    guard let session = session else { return nil }
    let downloadTask = DownloadTask(session: session, url: url)
    if downloadsTasks.count < maxConcurrentDownloads {
      downloadsTasks.insert(downloadTask)
      downloadTask.startDownload()
    } else {
      pendingDownloads.append(downloadTask)
    }
    return downloadTask
  }
}

extension SmartNet: URLSessionDownloadDelegate {
  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard
      let download = downloadsTasks.first(where: {
        $0.task.taskIdentifier == downloadTask.taskIdentifier
      })
    else { return }
    download.downloadHandler(
      tmpURL: location,
      urlResponse: downloadTask.response,
      error: nil
    )
    downloadsTasks.remove(download)
    
    // Start pending downloads if any
    startNextPendingDownload()
    
    if config.debug,
       let request = downloadTask.currentRequest {
      SmartNet.printCurl(
        session: session,
        request: request
      )
    }
  }
  
  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard
      let download = downloadsTasks.first(where: {
        $0.task.taskIdentifier == downloadTask.taskIdentifier
      })
    else { return }
    download.remoteFileSize = totalBytesExpectedToWrite
  }
  
  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didResumeAtOffset fileOffset: Int64,
    expectedTotalBytes: Int64
  ) {
    guard
      let download = downloadsTasks.first(where: {
        $0.task.taskIdentifier == downloadTask.taskIdentifier
      })
    else { return }
    download.remoteFileSize = expectedTotalBytes
  }
}

private extension SmartNet {
  // Manages the downloading tasks based on the current active and pending tasks.
  func startNextPendingDownload() {
    downloadQueue.sync {
      while downloadsTasks.count < 10 && !pendingDownloads.isEmpty {
        if let pendingDownload = pendingDownloads.first {
          pendingDownloads.removeFirst() // Remove from pending
          downloadsTasks.insert(pendingDownload) // Insert into active downloads
          pendingDownload.startDownload() // Start the download, assuming you have a method to do so
        }
      }
    }
  }
}

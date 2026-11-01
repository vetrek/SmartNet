//
//  ApiClient+Download.swift
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
import os

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
  private let globalDebug: Bool
  let shouldDebug: Bool?
  var onRelease: ((DownloadTask) -> Void)?
  var onResume: ((DownloadTask) -> Void)?
  
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
    self.shouldDebug = endpoint.debugRequest
    self.globalDebug = config.debug
    commonInit()
  }
  
  init(
    session: URLSession,
    url: URL,
    config: NetworkConfigurable
  ) {
    self.session = session
    self.remoteURL = url
    self.remoteURLRequest = URLRequest(url: url)
    self.shouldDebug = nil
    self.globalDebug = config.debug
    commonInit()
  }
  
  // MARK: - Private Methods
  
  func commonInit() {
    setTask(session.downloadTask(with: remoteURLRequest))
  }
  
  @discardableResult
  func startDownload() -> Self {
    if let resumedData {
      self.resumedData = nil
      setTask(session.downloadTask(withResumeData: resumedData))
    } else if task.state != .suspended {
      setTask(session.downloadTask(with: remoteURLRequest))
    }
    task.resume()
    state = .downloading
    return self
  }
  
  private func setTask(_ task: URLSessionDownloadTask) {
    task.delegate = SessionTaskDelegate(download: self)
    self.task = task
    observeDownloadProgress()
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
  
  fileprivate func didFinish(_ downloadTask: URLSessionDownloadTask, location: URL) {
    finish(result(tmpURL: location, urlResponse: downloadTask.response))
    onRelease?(self)
    if shouldDebug ?? globalDebug, let request = downloadTask.currentRequest {
      ApiClient.printCurl(session: session, request: request)
    }
  }

  fileprivate func didFail(with error: Error) {
    onRelease?(self)
    finish(.failure(ApiClient.resolve(error: error)))
  }

  private func result(tmpURL: URL, urlResponse: URLResponse?) -> Result<DownloadResult> {
    guard let httpResponse = urlResponse as? HTTPURLResponse else {
      return .failure(.emptyResponse)
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      return .failure(.error(statusCode: httpResponse.statusCode, data: nil))
    }
    guard let data = try? Data(contentsOf: tmpURL) else {
      return .failure(.invalidDownloadFileData)
    }
    var url = tmpURL
    if let downloadDestination {
      guard moveFile(at: url, to: downloadDestination.url, shouldReplace: downloadDestination.removePreviousFile) else {
        return .failure(.unableToSaveFile(url))
      }
      url = downloadDestination.url
    }
    return .success(DownloadResult(fileData: data, localURL: url))
  }

  private func finish(_ result: Result<DownloadResult>) {
    switch result {
    case .success:
      state = .completed
    case .failure:
      if state != .cancelled {
        state = .error
      }
    }
    guard let response else { return }
    response.queue.async { response.closure(Response(result: result)) }
  }
  
  // MARK: - Public Methods
  
  public func cancel() {
    progressObserver?.invalidate()
    if state == .waitingStart || state == .paused {
      state = .cancelled
      onRelease?(self)
      finish(.failure(.cancelled))
      return
    }
    task.resume()
    task.cancel()
    state = .cancelled
  }
  
  public func pause() {
    guard state == .downloading else { return }
    progressObserver?.invalidate()
    (task.delegate as? SessionTaskDelegate)?.download = nil
    resumedData = nil
    task.resume()
    task.cancel(byProducingResumeData: { data in
      self.resumedData = data
    })
    state = .paused
    onRelease?(self)
  }
  
  public func resume() {
    guard state == .paused else { return }
    state = .waitingStart
    onResume?(self)
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
    hasher.combine(ObjectIdentifier(self))
  }
  
  public static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
    lhs === rhs
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

public extension ApiClient {
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

    enqueue(downloadTask)

    return downloadTask
  }
  
  func download(
    with endpoint: DownloadEndpoint,
    destination: DownloadTask.DownloadFileDestination? = nil
  ) async throws -> DownloadTask.DownloadResult {
    guard let session else {
      throw NSError(domain: "SmartNet", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid Session"])
    }
    let downloadTask = try DownloadTask(
      session: session,
      endpoint: endpoint,
      config: config,
      destination: destination
    )
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        guard !Task.isCancelled else {
          continuation.resume(throwing: NetworkError.cancelled)
          return
        }
        let resumed = OSAllocatedUnfairLock(initialState: false)
        downloadTask.response { response in
          guard resumed.withLock({ resumed in defer { resumed = true }; return !resumed }) else { return }
          switch response.result {
          case let .success(result):
            continuation.resume(returning: result)
          case let .failure(error):
            continuation.resume(throwing: error)
          }
        }
        enqueue(downloadTask)
      }
    } onCancel: {
      downloadTask.cancel()
    }
  }
  
  func download(
    url: URL
  ) -> DownloadTask? {
    guard let session = session else { return nil }
    let downloadTask = DownloadTask(session: session, url: url, config: config)

    enqueue(downloadTask)

    return downloadTask
  }
}

private final class SessionTaskDelegate: NSObject, URLSessionDownloadDelegate {
  weak var download: DownloadTask?

  init(download: DownloadTask) {
    self.download = download
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    download?.didFinish(downloadTask, location: location)
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let error else { return }
    download?.didFail(with: error)
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    download?.remoteFileSize = totalBytesExpectedToWrite
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didResumeAtOffset fileOffset: Int64,
    expectedTotalBytes: Int64
  ) {
    download?.remoteFileSize = expectedTotalBytes
  }
}

extension ApiClient {
  func enqueue(_ download: DownloadTask, atFront: Bool = false) {
    download.onRelease = { [weak self] download in
      guard let self else { return }
      downloadQueue.sync {
        _ = self.downloadsTasks.remove(download)
        self.pendingDownloads.removeAll { $0 === download }
      }
      startNextPendingDownload()
    }
    download.onResume = { [weak self] download in
      guard let self, self.session != nil else {
        download.cancel()
        return
      }
      enqueue(download, atFront: true)
    }
    downloadQueue.sync {
      if downloadsTasks.count < maxConcurrentDownloads {
        downloadsTasks.insert(download)
        download.startDownload()
      } else {
        pendingDownloads.insert(download, at: atFront ? 0 : pendingDownloads.endIndex)
      }
    }
  }

  // Manages the downloading tasks based on the current active and pending tasks.
  private func startNextPendingDownload() {
    downloadQueue.sync {
      while downloadsTasks.count < maxConcurrentDownloads && !pendingDownloads.isEmpty {
        if let pendingDownload = pendingDownloads.first {
          pendingDownloads.removeFirst() // Remove from pending
          downloadsTasks.insert(pendingDownload) // Insert into active downloads
          pendingDownload.startDownload() // Start the download, assuming you have a method to do so
        }
      }
    }
  }
}

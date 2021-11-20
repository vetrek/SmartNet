//
//  File.swift
//  
//
//  Created by Valerio Sebastianelli on 11/1/21.
//

import Foundation



public final class DownloadTask: NetworkCancellable, Hashable {
    
    public typealias ProgressCompletion = (_ progress: Progress, _ remoteFileSize: Int64) -> Void
    public typealias ResultCompletion = (_ response: Response<DownloadResult>) -> Void
    
    public struct DownloadResult {
        var fileData: Data
        var localURL: URL
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
    private var remoteURL: URL
    private var progressObserver: NSKeyValueObservation?
    private var resumedData: Data?
    
    // MARK: - Public Properties
    public var state: DownloadState = .waitingStart
    
    // MARK: - Results Closures
    
    private var downloadProgress: (closure: ProgressCompletion, queue: DispatchQueue)?
    private var response: (closure: ResultCompletion, queue: DispatchQueue)?
    
    // MARK: - Lifecycle
    
    init(session: URLSession, endpoint: DownloadEndpoint, config: NetworkConfigurable) throws {
        self.session = session
        self.remoteURL = try endpoint.url(with: config)
        startDownload()
    }
    
    init(session: URLSession, url: URL) {
        self.session = session
        self.remoteURL = url
        startDownload()
    }
    
    // MARK: - Private Methods
    
    private func startDownload() {
        task = session.downloadTask(with: remoteURL)
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
        localURL: URL?,
        urlResponse: URLResponse?,
        error: Error?
    ) {
        guard let response = response else {
            state = .error
            return
        }
        
        guard let localURL = localURL else {
            response.queue.async { response.closure(Response(result: .failure(.invalidDownloadUrl))) }
            state = .error
            return
        }
        guard let data = try? Data(contentsOf: localURL) else {
            response.queue.async { response.closure(Response(result: .failure(.invalidDownloadFileData))) }
            state = .error
            return
        }
        
        let result = DownloadResult(fileData: data, localURL: localURL)
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
        queue: DispatchQueue = .main,
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
    
}

public extension SmartNet {
    func download(
        with endpoint: DownloadEndpoint
    ) -> DownloadTask? {
        guard
            let session = session,
            let downloadTask = try? DownloadTask(session: session, endpoint: endpoint, config: config)
        else { return nil }
        downloadsTasks.insert(downloadTask)
        return downloadTask
    }
    
    func download(
        url: URL
    ) -> DownloadTask? {
        guard let session = session else { return nil }
        let downloadTask = DownloadTask(session: session, url: url)
        downloadsTasks.insert(downloadTask)
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
            localURL: location,
            urlResponse: downloadTask.response,
            error: nil
        )
        downloadsTasks.remove(download)
        
        if config.printCurl,
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

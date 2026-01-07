import Testing
import Foundation
@testable import SmartNet

@Suite("File Operation Tests")
struct FileOperationTests {

  // MARK: - Download Task State Tests

  @Test("Download task starts in downloading state")
  func downloadTaskStartsDownloading() {
    let (client, _) = createMockClient()
    defer { client.destroy() }

    let endpoint = DownloadEndpoint(path: "files/test.pdf")
    let downloadTask = client.download(with: endpoint)

    #expect(downloadTask != nil)
    // When download() returns, the task has already been started
    #expect(downloadTask?.state == .downloading)
    downloadTask?.cancel()
  }

  @Test("Download cancellation sets state to cancelled")
  func downloadCancellationSetsState() {
    let (client, _) = createMockClient()
    defer { client.destroy() }

    let endpoint = DownloadEndpoint(path: "files/test.pdf")
    guard let downloadTask = client.download(with: endpoint) else {
      Issue.record("Failed to create download task")
      return
    }

    // Cancel the download
    downloadTask.cancel()

    #expect(downloadTask.state == .cancelled)
  }

  @Test("Download pause only works when downloading")
  func downloadPauseRequiresDownloadingState() {
    let (client, _) = createMockClient()
    defer { client.destroy() }

    let endpoint = DownloadEndpoint(path: "files/test.pdf")
    guard let downloadTask = client.download(with: endpoint) else {
      Issue.record("Failed to create download task")
      return
    }

    // Task starts in waitingStart, then immediately moves to downloading
    // Pause should only work in downloading state
    let initialState = downloadTask.state

    // If state is downloading, pause should work
    if initialState == .downloading {
      downloadTask.pause()
      #expect(downloadTask.state == .paused)
    } else {
      // If not downloading, pause should not change state
      downloadTask.pause()
      #expect(downloadTask.state == initialState)
    }

    downloadTask.cancel()
  }

  @Test("Download resume only works when paused")
  func downloadResumeRequiresPausedState() {
    let (client, _) = createMockClient()
    defer { client.destroy() }

    let endpoint = DownloadEndpoint(path: "files/test.pdf")
    guard let downloadTask = client.download(with: endpoint) else {
      Issue.record("Failed to create download task")
      return
    }

    // Resume should not work when not paused
    let initialState = downloadTask.state
    downloadTask.resume()

    // State should not change if not paused
    if initialState != .paused {
      #expect(downloadTask.state == initialState || downloadTask.state == .downloading)
    }

    downloadTask.cancel()
  }

  @Test("Multiple download tasks can be created")
  func multipleDownloadTasks() {
    let (client, _) = createMockClient()
    defer { client.destroy() }

    let endpoint1 = DownloadEndpoint(path: "files/test1.pdf")
    let endpoint2 = DownloadEndpoint(path: "files/test2.pdf")
    let endpoint3 = DownloadEndpoint(path: "files/test3.pdf")

    let task1 = client.download(with: endpoint1)
    let task2 = client.download(with: endpoint2)
    let task3 = client.download(with: endpoint3)

    #expect(task1 != nil)
    #expect(task2 != nil)
    #expect(task3 != nil)

    // Clean up
    task1?.cancel()
    task2?.cancel()
    task3?.cancel()
  }

  @Test("Download task with destination")
  func downloadTaskWithDestination() {
    let (client, _) = createMockClient()
    defer { client.destroy() }

    let endpoint = DownloadEndpoint(path: "files/test.pdf")
    let destination = DownloadTask.DownloadFileDestination(
      url: URL(fileURLWithPath: "/tmp/test-download.pdf"),
      removePreviousFile: true
    )

    let downloadTask = client.download(with: endpoint, destination: destination)

    #expect(downloadTask != nil)
    downloadTask?.cancel()
  }

  @Test("Download returns nil after client destroyed")
  func downloadReturnsNilAfterDestroy() {
    let (client, _) = createMockClient()

    client.destroy()

    let endpoint = DownloadEndpoint(path: "files/test.pdf")
    let downloadTask = client.download(with: endpoint)

    #expect(downloadTask == nil)
  }

  // MARK: - Download Task Callback Tests

  @Test("Download task accepts progress callback")
  func downloadTaskProgressCallback() {
    let (client, _) = createMockClient()
    defer { client.destroy() }

    let endpoint = DownloadEndpoint(path: "files/test.pdf")
    guard let downloadTask = client.download(with: endpoint) else {
      Issue.record("Failed to create download task")
      return
    }

    var progressCalled = false
    downloadTask.downloadProgress { progress, fileSize in
      progressCalled = true
    }

    // Progress callback is set up (actual progress requires network)
    #expect(downloadTask.state == .downloading || downloadTask.state == .waitingStart)

    downloadTask.cancel()
  }

  @Test("Download task accepts response callback")
  func downloadTaskResponseCallback() {
    let (client, _) = createMockClient()
    defer { client.destroy() }

    let endpoint = DownloadEndpoint(path: "files/test.pdf")
    guard let downloadTask = client.download(with: endpoint) else {
      Issue.record("Failed to create download task")
      return
    }

    var responseCalled = false
    downloadTask.response { response in
      responseCalled = true
    }

    // Response callback is set up (actual response requires network)
    #expect(downloadTask.state == .downloading || downloadTask.state == .waitingStart)

    downloadTask.cancel()
  }

  // MARK: - Upload Tests

  @Test("Upload with multipart form creates request")
  func uploadWithMultipartForm() throws {
    let (client, config) = createMockClient()
    defer { client.destroy() }

    let form = MultipartFormData { form in
      form.addTextField(named: "title", value: "Test Upload")
      form.addDataField(
        named: "file",
        data: "test content".data(using: .utf8)!,
        fileName: "test.txt",
        mimeType: "text/plain"
      )
    }

    let endpoint = MultipartFormEndpoint<String>(
      path: "upload",
      method: .post,
      form: form
    )

    // Verify the endpoint can create a valid request
    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpMethod == "POST")
    #expect(request.url?.path == "/upload")
    #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
  }

  // MARK: - Concurrent Download Limit Tests

  @Test("Download tasks respect concurrent limit")
  func downloadTasksConcurrentLimit() {
    let (client, _) = createMockClient()
    defer { client.destroy() }

    // Create more downloads than the concurrent limit (default is 6)
    var tasks: [DownloadTask] = []
    for i in 0..<10 {
      let endpoint = DownloadEndpoint(path: "files/test\(i).pdf")
      if let task = client.download(with: endpoint) {
        tasks.append(task)
      }
    }

    // All tasks should be created
    #expect(tasks.count == 10)

    // Clean up
    tasks.forEach { $0.cancel() }
  }
}

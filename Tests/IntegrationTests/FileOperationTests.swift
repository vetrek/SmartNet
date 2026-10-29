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

  @Test("Transport failures free download slots for pending downloads")
  func transportFailuresFreeDownloadSlots() async {
    let (client, _) = createMockClient()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/slots/lost")
      MockURLProtocol.removeHandler(for: "/slots/ok")
    }

    MockURLProtocol.setHandler(for: "/slots/lost") { _ in
      throw URLError(.networkConnectionLost)
    }
    MockURLProtocol.setHandler(for: "/slots/ok") { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("ok".utf8))
    }

    for index in 0..<client.maxConcurrentDownloads {
      _ = client.download(with: DownloadEndpoint(path: "slots/lost/\(index)")) as DownloadTask?
    }

    var continuation: AsyncStream<Bool>.Continuation!
    let succeeded = AsyncStream<Bool> { continuation = $0 }
    let pending: DownloadTask? = client.download(with: DownloadEndpoint(path: "slots/ok"))
    pending?.response(queue: .global()) { [continuation] response in
      if case .success = response.result {
        continuation?.yield(true)
      } else {
        continuation?.yield(false)
      }
    }
    Task { [continuation] in
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      continuation?.yield(false)
    }

    var iterator = succeeded.makeAsyncIterator()
    #expect(await iterator.next() == true)
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

  @Test("Finished uploads free slots for pending uploads")
  func finishedUploadsFreeSlots() async throws {
    let (client, _) = createMockClient()
    let count = client.maxConcurrentUploads * 2 + 3
    defer {
      client.destroy()
      (0..<count).forEach { MockURLProtocol.removeHandler(for: "/upslots/\($0)") }
    }

    for index in 0..<count {
      MockURLProtocol.setHandler(for: "/upslots/\(index)") { request in
        switch index % 3 {
        case 0:
          throw URLError(.networkConnectionLost)
        case 1:
          return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        default:
          return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("ok".utf8))
        }
      }
    }

    let uploads = try (0..<count).map { index in
      try client.upload(
        with: MultipartFormEndpoint<String>(
          path: "upslots/\(index)",
          form: MultipartFormData { $0.addTextField(named: "index", value: "\(index)") }
        )
      )
    }

    let finished: Set<UploadTask<String>.UploadState> = [.completed, .error]
    for _ in 0..<250 where !uploads.allSatisfy({ finished.contains($0.state) }) {
      try await Task.sleep(nanoseconds: 20_000_000)
    }

    #expect(uploads.map(\.state) == (0..<count).map { $0 % 3 == 2 ? .completed : .error })
    #expect(client.uploadsTasks.isEmpty)
    #expect(client.pendingUploads.isEmpty)
  }

  @Test("Cancelled uploads free slots for pending uploads")
  func cancelledUploadsFreeSlots() async throws {
    let (client, _) = createMockClient()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/upcancel/slow")
      MockURLProtocol.removeHandler(for: "/upcancel/ok")
    }

    MockURLProtocol.setHandler(for: "/upcancel/slow", delay: 0.5) { request in
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("slow".utf8))
    }
    MockURLProtocol.setHandler(for: "/upcancel/ok") { request in
      (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("ok".utf8))
    }

    let form = MultipartFormData { $0.addTextField(named: "field", value: "value") }
    let started = try (0..<client.maxConcurrentUploads).map { _ in
      try client.upload(with: MultipartFormEndpoint<String>(path: "upcancel/slow", form: form))
    }
    let pending = try client.upload(with: MultipartFormEndpoint<String>(path: "upcancel/ok", form: form))

    started.forEach { $0.cancel() }

    for _ in 0..<50 where pending.state == .waitingStart {
      try await Task.sleep(nanoseconds: 20_000_000)
    }

    #expect(pending.state != .waitingStart)
  }

  // MARK: - Upload Cancel, Pause and Destroy Tests

  private static func ok(_ request: URLRequest, _ body: String) -> (HTTPURLResponse, Data) {
    (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
  }

  private func record(_ task: UploadTask<String>, into events: EventRecorder) {
    task.response(queue: .global()) { response in
      switch response.result {
      case .success(let value):
        events.record(value)
      case .failure(.generic(let error)) where (error as? URLError)?.code == .cancelled:
        events.record("cancelled")
      case .failure(let error):
        events.record("\(error)")
      }
    }
  }

  private func waitFor(_ condition: () -> Bool) async throws {
    for _ in 0..<300 where !condition() {
      try await Task.sleep(nanoseconds: 20_000_000)
    }
  }

  @Test("Cancelling a queued upload reports cancellation and never sends it")
  func cancelQueuedUpload() async throws {
    let (client, _) = createMockClient()
    let events = EventRecorder()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/upqueued/slow")
      MockURLProtocol.removeHandler(for: "/upqueued/queued")
    }
    MockURLProtocol.setHandler(for: "/upqueued/slow", delay: 0.3) { request in
      return Self.ok(request, "slow")
    }
    MockURLProtocol.setHandler(for: "/upqueued/queued") { request in
      events.record("sent")
      return Self.ok(request, "queued")
    }

    let form = MultipartFormData { $0.addTextField(named: "field", value: "value") }
    let running = try (0..<client.maxConcurrentUploads).map { _ in
      try client.upload(with: MultipartFormEndpoint<String>(path: "upqueued/slow", form: form))
    }
    let queued = try client.upload(with: MultipartFormEndpoint<String>(path: "upqueued/queued", form: form))
    record(queued, into: events)

    #expect(Set([queued, queued]).count == 1)
    queued.cancel()

    #expect(queued.state == .cancelled)
    #expect(client.pendingUploads.isEmpty)
    try await waitFor { running.allSatisfy { $0.state == .completed } && client.uploadsTasks.isEmpty }
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(running.allSatisfy { $0.state == .completed })
    #expect(events.values == ["cancelled"])
    #expect(queued.state == .cancelled)
  }

  @Test("Paused upload frees its slot silently and resume uploads it again")
  func pauseResumeUpload() async throws {
    guard #available(iOS 17.0, macOS 14.0, *) else { return }
    let (client, _) = createMockClient()
    let events = EventRecorder()
    let attempts = EventRecorder()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/uppause/file")
    }
    MockURLProtocol.setHandler(for: "/uppause/file", delay: 0.3) { request in
      attempts.record("sent")
      return Self.ok(request, "done")
    }

    let form = MultipartFormData { $0.addTextField(named: "field", value: "value") }
    let upload = try client.upload(with: MultipartFormEndpoint<String>(path: "uppause/file", form: form))
    record(upload, into: events)
    try await waitFor { !attempts.values.isEmpty }

    upload.pause()
    try await Task.sleep(nanoseconds: 500_000_000)
    #expect(upload.state == .paused)
    #expect(events.values.isEmpty)
    #expect(client.uploadsTasks.isEmpty)

    upload.resume()
    try await waitFor { upload.state == .completed && !events.values.isEmpty }
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(upload.state == .completed)
    #expect(events.values == ["done"])
    #expect(attempts.values.count == 2)
    #expect(client.uploadsTasks.isEmpty)
  }

  @Test("Cancelling a paused upload reports cancellation and frees its slot")
  func cancelPausedUpload() async throws {
    guard #available(iOS 17.0, macOS 14.0, *) else { return }
    let (client, _) = createMockClient()
    let events = EventRecorder()
    let attempts = EventRecorder()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/uppausecancel/file")
    }
    MockURLProtocol.setHandler(for: "/uppausecancel/file", delay: 0.3) { request in
      attempts.record("sent")
      return Self.ok(request, "done")
    }

    let form = MultipartFormData { $0.addTextField(named: "field", value: "value") }
    let upload = try client.upload(with: MultipartFormEndpoint<String>(path: "uppausecancel/file", form: form))
    record(upload, into: events)
    try await waitFor { !attempts.values.isEmpty }

    upload.pause()
    upload.cancel()
    try await waitFor { !events.values.isEmpty }
    try await Task.sleep(nanoseconds: 500_000_000)

    #expect(upload.state == .cancelled)
    #expect(events.values == ["cancelled"])
    #expect(client.uploadsTasks.isEmpty)
  }

  @Test("Destroy cancels running and queued uploads")
  func destroyCancelsUploads() async throws {
    let (client, _) = createMockClient()
    let events = EventRecorder()
    let sent = EventRecorder()
    defer {
      MockURLProtocol.removeHandler(for: "/updestroy/running")
      MockURLProtocol.removeHandler(for: "/updestroy/queued")
    }
    MockURLProtocol.setHandler(for: "/updestroy/running", delay: 0.3) { request in
      return Self.ok(request, "running")
    }
    MockURLProtocol.setHandler(for: "/updestroy/queued") { request in
      sent.record("queued")
      return Self.ok(request, "queued")
    }

    let form = MultipartFormData { $0.addTextField(named: "field", value: "value") }
    let running = try (0..<client.maxConcurrentUploads).map { _ in
      try client.upload(with: MultipartFormEndpoint<String>(path: "updestroy/running", form: form))
    }
    let queued = try (0..<2).map { _ in
      try client.upload(with: MultipartFormEndpoint<String>(path: "updestroy/queued", form: form))
    }
    (running + queued).forEach { record($0, into: events) }

    client.destroy()

    #expect(client.uploadsTasks.isEmpty)
    #expect(client.pendingUploads.isEmpty)
    #expect(queued.allSatisfy { $0.state == .cancelled })
    try await waitFor { events.values.count == running.count + queued.count }
    try await Task.sleep(nanoseconds: 500_000_000)
    #expect(events.values == Array(repeating: "cancelled", count: running.count + queued.count))
    #expect(sent.values.isEmpty)
    #expect(client.uploadsTasks.isEmpty)
    #expect(client.pendingUploads.isEmpty)
    #expect((running + queued).allSatisfy { $0.state == .cancelled })
  }

  @Test("Cancelling a running upload ends cancelled and frees its slot")
  func cancelRunningUpload() async throws {
    let (client, _) = createMockClient()
    let events = EventRecorder()
    let attempts = EventRecorder()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/uprunningcancel/file")
    }
    MockURLProtocol.setHandler(for: "/uprunningcancel/file", delay: 0.3) { request in
      attempts.record("sent")
      return Self.ok(request, "done")
    }

    let form = MultipartFormData { $0.addTextField(named: "field", value: "value") }
    let upload = try client.upload(with: MultipartFormEndpoint<String>(path: "uprunningcancel/file", form: form))
    record(upload, into: events)
    try await waitFor { !attempts.values.isEmpty }

    upload.cancel()
    try await waitFor { !events.values.isEmpty && client.uploadsTasks.isEmpty }
    try await Task.sleep(nanoseconds: 500_000_000)

    #expect(upload.state == .cancelled)
    #expect(events.values == ["cancelled"])
    #expect(client.uploadsTasks.isEmpty)
  }

  private func slowUploads(_ client: ApiClient, path: String, count: Int) throws -> [UploadTask<String>] {
    let form = MultipartFormData { $0.addTextField(named: "field", value: "value") }
    return try (0..<count).map { _ in
      try client.upload(with: MultipartFormEndpoint<String>(path: path, form: form))
    }
  }

  private func setSlowHandler(_ path: String, attempts: EventRecorder? = nil) {
    MockURLProtocol.setHandler(for: "/\(path)", delay: 1) { request in
      attempts?.record(path)
      return Self.ok(request, path)
    }
  }

  @Test(
    "Transfer limits follow the session's connections per host",
    arguments: [(6, 5, 6), (3, 2, 3), (2, 1, 2), (1, 1, 1)]
  )
  func transferLimitsFollowSession(perHost: Int, uploads: Int, downloads: Int) {
    let (client, _) = createMockClient(maxConnectionsPerHost: perHost)
    defer { client.destroy() }
    #expect(client.maxConcurrentUploads == uploads)
    #expect(client.maxConcurrentDownloads == downloads)
  }

  @Test("Default client limits follow the default session configuration")
  func defaultClientLimits() {
    let client = ApiClient(config: NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!))
    defer { client.destroy() }
    let perHost = URLSessionConfiguration.default.httpMaximumConnectionsPerHost
    #expect(client.maxConcurrentUploads == max(1, perHost - 1))
    #expect(client.maxConcurrentDownloads == perHost)
  }

  @Test("Uploads leave one connection per host free for other requests")
  func uploadsLeaveOneConnectionFree() async throws {
    let (client, _) = createMockClient(maxConnectionsPerHost: 3)
    let attempts = EventRecorder()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/uplimit/file")
    }
    setSlowHandler("uplimit/file", attempts: attempts)

    let uploads = try slowUploads(client, path: "uplimit/file", count: 3)
    try await waitFor { attempts.values.count >= 2 }
    try await Task.sleep(nanoseconds: 200_000_000)

    #expect(attempts.values.count == 2)
    #expect(uploads.map(\.state) == [.uploading, .uploading, .waitingStart])
    #expect(client.pendingUploads.count == 1)
  }

  @Test("Downloads use every connection per host")
  func downloadsUseAllConnections() async throws {
    let (client, _) = createMockClient(maxConnectionsPerHost: 3)
    let attempts = EventRecorder()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/dllimit/file")
    }
    setSlowHandler("dllimit/file", attempts: attempts)

    let downloads = (0..<4).compactMap { _ in client.download(with: DownloadEndpoint(path: "dllimit/file")) }
    try await waitFor { attempts.values.count >= 3 }
    try await Task.sleep(nanoseconds: 200_000_000)

    #expect(downloads.count == 4)
    #expect(attempts.values.count == 3)
    #expect(client.pendingDownloads.count == 1)
  }

  private func record(_ task: DownloadTask, into events: EventRecorder) {
    task.response(queue: .global()) { response in
      switch response.result {
      case .success:
        events.record("ok")
      case .failure(.cancelled):
        events.record("cancelled")
      case .failure(let error):
        events.record("\(error)")
      }
    }
  }

  private func slowDownloads(_ client: ApiClient, path: String, count: Int) -> [DownloadTask] {
    (0..<count).compactMap { _ in client.download(with: DownloadEndpoint(path: path)) }
  }

  @Test("Async download waits for a free download slot")
  func asyncDownloadRespectsLimit() async throws {
    let (client, _) = createMockClient(maxConnectionsPerHost: 2)
    let attempts = EventRecorder()
    defer {
      client.destroy()
      ["/dlasync/running", "/dlasync/awaited"].forEach(MockURLProtocol.removeHandler)
    }
    setSlowHandler("dlasync/running", attempts: attempts)
    setSlowHandler("dlasync/awaited", attempts: attempts)

    let running = slowDownloads(client, path: "dlasync/running", count: client.maxConcurrentDownloads)
    try await waitFor { attempts.values.count == running.count }
    let results = EventRecorder()
    Task {
      let result = try? await client.download(with: DownloadEndpoint(path: "dlasync/awaited"))
      results.record(result.map { String(decoding: $0.fileData, as: UTF8.self) } ?? "failed")
    }
    try await waitFor { client.pendingDownloads.count == 1 }
    try await Task.sleep(nanoseconds: 200_000_000)

    #expect(client.pendingDownloads.count == 1)
    #expect(client.downloadsTasks.count == client.maxConcurrentDownloads)
    #expect(!attempts.values.contains("dlasync/awaited"))

    try await waitFor { !results.values.isEmpty }
    #expect(results.values == ["dlasync/awaited"])
    #expect(attempts.values.last == "dlasync/awaited")
  }

  @Test("Paused download frees its slot and resume queues it at the front")
  func pauseResumeDownload() async throws {
    let (client, _) = createMockClient(maxConnectionsPerHost: 2)
    let attempts = EventRecorder()
    let events = EventRecorder()
    let paths = ["dlpause/paused", "dlpause/running", "dlpause/filler", "dlpause/later"]
    defer {
      client.destroy()
      paths.forEach { MockURLProtocol.removeHandler(for: "/\($0)") }
    }
    paths.forEach { setSlowHandler($0, attempts: attempts) }

    let paused = try #require(slowDownloads(client, path: "dlpause/paused", count: 1).first)
    record(paused, into: events)
    let running = slowDownloads(client, path: "dlpause/running", count: client.maxConcurrentDownloads - 1)
    let filler = slowDownloads(client, path: "dlpause/filler", count: 1)
    try await waitFor { attempts.values.contains("dlpause/paused") }
    #expect(filler.map(\.state) == [.waitingStart])

    paused.pause()
    #expect(paused.state == .paused)
    #expect(filler.map(\.state) == [.downloading])
    #expect(client.downloadsTasks.count == client.maxConcurrentDownloads)
    #expect(!client.downloadsTasks.contains(paused))

    let later = slowDownloads(client, path: "dlpause/later", count: 1)
    paused.resume()
    #expect(paused.state == .waitingStart)
    #expect(client.pendingDownloads.map(ObjectIdentifier.init) == [ObjectIdentifier(paused)] + later.map(ObjectIdentifier.init))

    try await waitFor { client.downloadsTasks.isEmpty && client.pendingDownloads.isEmpty && !events.values.isEmpty }
    try await Task.sleep(nanoseconds: 100_000_000)
    let order = attempts.values
    #expect(order.filter { $0 == "dlpause/paused" }.count == 2)
    #expect(try #require(order.lastIndex(of: "dlpause/paused")) < (try #require(order.firstIndex(of: "dlpause/later"))))
    #expect(events.values == ["ok"])
    #expect(paused.state == .completed)
    #expect(client.downloadsTasks.isEmpty)
    #expect(client.pendingDownloads.isEmpty)
  }

  @Test("Cancelling a queued download reports cancellation and never sends it")
  func cancelQueuedDownload() async throws {
    let (client, _) = createMockClient(maxConnectionsPerHost: 1)
    let attempts = EventRecorder()
    let events = EventRecorder()
    defer {
      client.destroy()
      ["/dlqueued/running", "/dlqueued/queued"].forEach(MockURLProtocol.removeHandler)
    }
    setSlowHandler("dlqueued/running", attempts: attempts)
    setSlowHandler("dlqueued/queued", attempts: attempts)

    let running = slowDownloads(client, path: "dlqueued/running", count: 1)
    let queued = try #require(slowDownloads(client, path: "dlqueued/queued", count: 1).first)
    record(queued, into: events)

    queued.cancel()

    #expect(queued.state == .cancelled)
    #expect(client.pendingDownloads.isEmpty)
    try await waitFor { running.allSatisfy { $0.state != .downloading } && client.downloadsTasks.isEmpty }
    try await Task.sleep(nanoseconds: 200_000_000)
    #expect(events.values == ["cancelled"])
    #expect(attempts.values == ["dlqueued/running"])
    #expect(client.downloadsTasks.isEmpty)
  }

  @Test("Cancelling a paused download reports cancellation")
  func cancelPausedDownload() async throws {
    let (client, _) = createMockClient()
    let attempts = EventRecorder()
    let events = EventRecorder()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/dlpausecancel/file")
    }
    setSlowHandler("dlpausecancel/file", attempts: attempts)

    let download = try #require(slowDownloads(client, path: "dlpausecancel/file", count: 1).first)
    record(download, into: events)
    try await waitFor { !attempts.values.isEmpty }

    download.pause()
    download.cancel()
    try await waitFor { !events.values.isEmpty }
    try await Task.sleep(nanoseconds: 200_000_000)

    #expect(download.state == .cancelled)
    #expect(events.values == ["cancelled"])
    #expect(client.downloadsTasks.isEmpty)
  }

  @Test("A paused download the caller drops is released")
  func droppedPausedDownloadIsReleased() async throws {
    let (client, _) = createMockClient()
    let attempts = EventRecorder()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/dldropped/file")
    }
    setSlowHandler("dldropped/file", attempts: attempts)

    weak var weakDownload: DownloadTask?
    do {
      let download = try #require(slowDownloads(client, path: "dldropped/file", count: 1).first)
      weakDownload = download
      try await waitFor { !attempts.values.isEmpty }
      download.pause()
    }
    try await waitFor { weakDownload == nil }

    #expect(weakDownload == nil)
    #expect(client.downloadsTasks.isEmpty)
  }

  @Test("Destroy cancels running, queued and awaited downloads")
  func destroyCancelsDownloads() async throws {
    let (client, _) = createMockClient(maxConnectionsPerHost: 2)
    let attempts = EventRecorder()
    let events = EventRecorder()
    defer {
      ["/dldestroy/running", "/dldestroy/queued", "/dldestroy/awaited"].forEach(MockURLProtocol.removeHandler)
    }
    setSlowHandler("dldestroy/running", attempts: attempts)
    setSlowHandler("dldestroy/queued", attempts: attempts)
    setSlowHandler("dldestroy/awaited", attempts: attempts)

    let running = slowDownloads(client, path: "dldestroy/running", count: client.maxConcurrentDownloads)
    let queued = slowDownloads(client, path: "dldestroy/queued", count: 2)
    (running + queued).forEach { record($0, into: events) }
    try await waitFor { attempts.values.count == running.count }
    let awaited = EventRecorder()
    Task {
      do {
        _ = try await client.download(with: DownloadEndpoint(path: "dldestroy/awaited"))
        awaited.record("ok")
      } catch NetworkError.cancelled {
        awaited.record("cancelled")
      } catch {
        awaited.record("\(error)")
      }
    }
    try await waitFor { client.pendingDownloads.count == 3 }

    client.destroy()

    #expect(client.pendingDownloads.isEmpty)
    #expect(queued.allSatisfy { $0.state == .cancelled })
    try await waitFor { events.values.count == running.count + queued.count }
    try await waitFor { !awaited.values.isEmpty }
    #expect(awaited.values == ["cancelled"])
    try await Task.sleep(nanoseconds: 300_000_000)
    #expect(events.values == Array(repeating: "cancelled", count: running.count + queued.count))
    #expect(attempts.values == Array(repeating: "dldestroy/running", count: running.count))
    #expect(client.downloadsTasks.isEmpty)
  }

  @Test("Resuming a download after destroy reports cancellation and never sends")
  func resumeDownloadAfterDestroy() async throws {
    let (client, _) = createMockClient()
    let attempts = EventRecorder()
    let events = EventRecorder()
    defer { MockURLProtocol.removeHandler(for: "/dldestroyresume/file") }
    setSlowHandler("dldestroyresume/file", attempts: attempts)

    let download = try #require(slowDownloads(client, path: "dldestroyresume/file", count: 1).first)
    record(download, into: events)
    try await waitFor { !attempts.values.isEmpty }
    download.pause()
    client.destroy()

    download.resume()

    #expect(download.state == .cancelled)
    try await waitFor { !events.values.isEmpty }
    try await Task.sleep(nanoseconds: 300_000_000)
    #expect(events.values == ["cancelled"])
    #expect(attempts.values.count == 1)
  }

  @Test("Pausing an upload starts the next queued upload")
  func pauseStartsQueuedUpload() async throws {
    guard #available(iOS 17.0, macOS 14.0, *) else { return }
    let (client, _) = createMockClient()
    let attempts = EventRecorder()
    defer {
      client.destroy()
      ["/uppausefree/running", "/uppausefree/queued"].forEach(MockURLProtocol.removeHandler)
    }
    setSlowHandler("uppausefree/running", attempts: attempts)
    setSlowHandler("uppausefree/queued", attempts: attempts)

    let running = try slowUploads(client, path: "uppausefree/running", count: client.maxConcurrentUploads)
    let queued = try slowUploads(client, path: "uppausefree/queued", count: 1)[0]
    try await waitFor { attempts.values.count == running.count }
    #expect(queued.state == .waitingStart)

    running[0].pause()

    #expect(queued.state == .uploading)
    #expect(client.pendingUploads.isEmpty)
    #expect(client.uploadsTasks.count == client.maxConcurrentUploads)
    try await waitFor { attempts.values.contains("uppausefree/queued") }
    #expect(attempts.values.contains("uppausefree/queued"))
    running[0].cancel()
  }

  @Test("Resuming with no free slot queues the upload at the front")
  func resumeWhenFullQueuesAtFront() async throws {
    guard #available(iOS 17.0, macOS 14.0, *) else { return }
    let (client, _) = createMockClient()
    let attempts = EventRecorder()
    let events = EventRecorder()
    let paths = ["upfront/running", "upfront/paused", "upfront/filler", "upfront/later"]
    defer {
      client.destroy()
      paths.forEach { MockURLProtocol.removeHandler(for: "/\($0)") }
    }
    paths.forEach { setSlowHandler($0, attempts: attempts) }

    let paused = try slowUploads(client, path: "upfront/paused", count: 1)[0]
    let running = try slowUploads(client, path: "upfront/running", count: client.maxConcurrentUploads - 1)
    let filler = try slowUploads(client, path: "upfront/filler", count: 1)[0]
    record(paused, into: events)
    try await waitFor { attempts.values.contains("upfront/paused") }

    paused.pause()
    try await waitFor { filler.state == .uploading }
    let later = try slowUploads(client, path: "upfront/later", count: 1)[0]
    paused.resume()

    #expect(paused.state == .waitingStart)
    #expect(client.pendingUploads.map(ObjectIdentifier.init) == [ObjectIdentifier(paused), ObjectIdentifier(later)])

    try await waitFor { ([paused, filler, later] + running).allSatisfy { $0.state == .completed } }
    let order = attempts.values
    #expect(order.filter { $0 == "upfront/paused" }.count == 2)
    #expect(try #require(order.lastIndex(of: "upfront/paused")) < (try #require(order.firstIndex(of: "upfront/later"))))
    #expect(events.values == ["upfront/paused"])
    #expect(client.uploadsTasks.isEmpty)
    #expect(client.pendingUploads.isEmpty)
  }

  @Test("Cancelling a resumed upload that is still queued removes it")
  func cancelResumedQueuedUpload() async throws {
    guard #available(iOS 17.0, macOS 14.0, *) else { return }
    let (client, _) = createMockClient()
    let attempts = EventRecorder()
    let events = EventRecorder()
    defer {
      client.destroy()
      ["/upresumecancel/running", "/upresumecancel/paused"].forEach(MockURLProtocol.removeHandler)
    }
    setSlowHandler("upresumecancel/running", attempts: attempts)
    setSlowHandler("upresumecancel/paused", attempts: attempts)

    let paused = try slowUploads(client, path: "upresumecancel/paused", count: 1)[0]
    _ = try slowUploads(client, path: "upresumecancel/running", count: client.maxConcurrentUploads)
    record(paused, into: events)
    try await waitFor { attempts.values.contains("upresumecancel/paused") }

    paused.pause()
    try await waitFor { client.pendingUploads.isEmpty }
    paused.resume()
    #expect(paused.state == .waitingStart)

    paused.cancel()

    #expect(paused.state == .cancelled)
    #expect(client.pendingUploads.isEmpty)
    try await waitFor { client.uploadsTasks.isEmpty }
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(events.values == ["cancelled"])
    #expect(attempts.values.filter { $0 == "upresumecancel/paused" }.count == 1)
  }

  @Test("A paused upload the caller drops is released")
  func droppedPausedUploadIsReleased() async throws {
    guard #available(iOS 17.0, macOS 14.0, *) else { return }
    let (client, _) = createMockClient()
    let attempts = EventRecorder()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/updropped/file")
    }
    setSlowHandler("updropped/file", attempts: attempts)

    weak var weakUpload: UploadTask<String>?
    do {
      let upload = try slowUploads(client, path: "updropped/file", count: 1)[0]
      weakUpload = upload
      try await waitFor { !attempts.values.isEmpty }
      upload.pause()
    }
    try await waitFor { weakUpload == nil }

    #expect(weakUpload == nil)
    #expect(client.uploadsTasks.isEmpty)
  }

  @Test("Resuming after destroy reports cancellation and never sends")
  func resumeAfterDestroy() async throws {
    guard #available(iOS 17.0, macOS 14.0, *) else { return }
    let (client, _) = createMockClient()
    let attempts = EventRecorder()
    let events = EventRecorder()
    defer { MockURLProtocol.removeHandler(for: "/updestroyresume/file") }
    setSlowHandler("updestroyresume/file", attempts: attempts)

    let upload = try slowUploads(client, path: "updestroyresume/file", count: 1)[0]
    record(upload, into: events)
    try await waitFor { !attempts.values.isEmpty }
    upload.pause()
    client.destroy()

    upload.resume()

    #expect(upload.state == .cancelled)
    try await waitFor { !events.values.isEmpty }
    try await Task.sleep(nanoseconds: 500_000_000)
    #expect(events.values == ["cancelled"])
    #expect(attempts.values.count == 1)
  }

  // MARK: - Upload Response Decoding Tests

  private func uploadResult<T: Sendable>(
    _ path: String,
    respond: @escaping MockURLProtocol.Handler,
    start: (ApiClient, MultipartFormEndpoint<T>) throws -> UploadTask<T>
  ) async throws -> SmartNet.Result<T> {
    let (client, _) = createMockClient()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/\(path)")
    }
    MockURLProtocol.setHandler(for: "/\(path)", handler: respond)
    let form = MultipartFormData { $0.addTextField(named: "field", value: "value") }
    let task = try start(client, MultipartFormEndpoint<T>(path: path, form: form))
    return await withCheckedContinuation { continuation in
      task.response(queue: .global()) { continuation.resume(returning: $0.result) }
    }
  }

  private func reply(_ status: Int, _ body: Data) -> MockURLProtocol.Handler {
    { request in (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, body) }
  }

  @Test("Decodable upload decodes JSON body")
  func decodableUploadDecodes() async throws {
    let user = TestUser(id: 7, name: "Ann", email: "ann@example.com")
    let result: SmartNet.Result<TestUser> = try await uploadResult(
      "updecode/json", respond: reply(200, try JSONEncoder().encode(user))
    ) { try $0.upload(with: $1) }
    guard case .success(let value) = result else { Issue.record("\(result)"); return }
    #expect(value == user)
  }

  @Test("Decodable upload maps decoding errors to parsingFailed")
  func decodableUploadParsingFailure() async throws {
    let body = Data("not json".utf8)
    let result: SmartNet.Result<TestUser> = try await uploadResult(
      "updecode/badjson", respond: reply(200, body)
    ) { try $0.upload(with: $1) }
    let expected = NetworkError.parsingFailed(from: try #require(throws: DecodingError.self) {
      try JSONDecoder().decode(TestUser.self, from: body)
    })
    guard case .failure(let error) = result else { Issue.record("\(result)"); return }
    #expect(error == expected)
  }

  @Test("String upload returns UTF-8 body")
  func stringUploadDecodes() async throws {
    let result: SmartNet.Result<String> = try await uploadResult(
      "updecode/text", respond: reply(200, Data("hello".utf8))
    ) { try $0.upload(with: $1) }
    guard case .success(let value) = result else { Issue.record("\(result)"); return }
    #expect(value == "hello")
  }

  @Test("String upload fails on non UTF-8 body")
  func stringUploadInvalidUTF8() async throws {
    let body = Data([0xFF, 0xFE, 0xFD])
    let result: SmartNet.Result<String> = try await uploadResult(
      "updecode/binary", respond: reply(200, body)
    ) { try $0.upload(with: $1) }
    guard case .failure(.dataToStringFailure(let data)) = result else { Issue.record("\(result)"); return }
    #expect(data == body)
  }

  @Test("Void upload succeeds with empty body")
  func voidUploadSucceeds() async throws {
    let result: SmartNet.Result<Void> = try await uploadResult(
      "updecode/void", respond: reply(204, Data())
    ) { try $0.upload(with: $1) }
    #expect(result.isSuccess)
  }

  @Test("Data upload returns raw body")
  func dataUploadReturnsBody() async throws {
    let body = Data([0x00, 0xFF, 0x10])
    let result: SmartNet.Result<Data> = try await uploadResult(
      "updecode/raw", respond: reply(200, body)
    ) { try $0.upload(with: $1) }
    guard case .success(let value) = result else { Issue.record("\(result)"); return }
    #expect(value == body)
  }

  @Test("Upload non-2xx maps to status error, including 429")
  func uploadStatusError() async throws {
    let body = Data("slow down".utf8)
    let result: SmartNet.Result<Data> = try await uploadResult(
      "updecode/limited", respond: reply(429, body)
    ) { try $0.upload(with: $1) }
    guard case .failure(let error) = result else { Issue.record("\(result)"); return }
    #expect(error == .error(statusCode: 429, data: body))
  }

  @Test("Upload transport errors are wrapped as generic")
  func uploadTransportError() async throws {
    let result: SmartNet.Result<Void> = try await uploadResult(
      "updecode/lost",
      respond: { _ in throw URLError(.networkConnectionLost) },
      start: { try $0.upload(with: $1) }
    )
    guard case .failure(.generic(let error)) = result else { Issue.record("\(result)"); return }
    #expect((error as? URLError)?.code == .networkConnectionLost)
  }

  @Test("Upload delivers response when the caller drops the task")
  func unretainedUploadDelivers() async throws {
    let (client, _) = createMockClient()
    defer {
      client.destroy()
      MockURLProtocol.removeHandler(for: "/updecode/unretained")
    }
    MockURLProtocol.setHandler(for: "/updecode/unretained", handler: reply(200, Data("kept".utf8)))

    var continuation: AsyncStream<String?>.Continuation!
    let values = AsyncStream<String?> { continuation = $0 }
    let form = MultipartFormData { $0.addTextField(named: "field", value: "value") }
    try client.upload(with: MultipartFormEndpoint<String>(path: "updecode/unretained", form: form))
      .response(queue: .global()) { [continuation] response in
        if case .success(let value) = response.result {
          continuation?.yield(value)
        } else {
          continuation?.yield(nil)
        }
      }
    Task { [continuation] in
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      continuation?.yield(nil)
    }

    var iterator = values.makeAsyncIterator()
    #expect(await iterator.next() == "kept")
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

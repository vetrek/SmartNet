import Testing
import Foundation
@testable import SmartNet

@Suite("MultipartFormData Tests")
struct MultipartFormDataTests {

  // MARK: - Initialization Tests

  @Test("Empty form has no data")
  func emptyFormHasNoData() {
    let form = MultipartFormData()
    #expect(form.data == nil)
  }

  @Test("Boundary is unique UUID")
  func boundaryIsUUID() {
    let form1 = MultipartFormData()
    let form2 = MultipartFormData()

    // Boundaries should be valid UUIDs and different
    #expect(UUID(uuidString: form1.boundary) != nil)
    #expect(UUID(uuidString: form2.boundary) != nil)
    #expect(form1.boundary != form2.boundary)
  }

  @Test("Closure initializer works")
  func closureInitializer() {
    let form = MultipartFormData { form in
      form.addTextField(named: "name", value: "John")
    }

    let data = form.data
    #expect(data != nil)
  }

  // MARK: - Text Field Tests

  @Test("Text field is properly encoded")
  func textFieldEncoding() {
    var form = MultipartFormData()
    form.addTextField(named: "username", value: "johndoe")

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!

    #expect(string.contains("Content-Disposition: form-data; name=\"username\""))
    #expect(string.contains("Content-Type: text/plain; charset=UTF-8"))
    #expect(string.contains("johndoe"))
    #expect(string.contains("--\(form.boundary)"))
    #expect(string.contains("--\(form.boundary)--"))
  }

  @Test("Multiple text fields are encoded")
  func multipleTextFields() {
    var form = MultipartFormData()
    form.addTextField(named: "first", value: "John")
    form.addTextField(named: "last", value: "Doe")

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!

    #expect(string.contains("name=\"first\""))
    #expect(string.contains("John"))
    #expect(string.contains("name=\"last\""))
    #expect(string.contains("Doe"))
  }

  @Test("Special characters in text field value")
  func specialCharactersInValue() {
    var form = MultipartFormData()
    form.addTextField(named: "message", value: "Hello, World! 你好 🌍")

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!
    #expect(string.contains("Hello, World! 你好 🌍"))
  }

  // MARK: - Data Field Tests

  @Test("Data field without filename")
  func dataFieldWithoutFilename() {
    var form = MultipartFormData()
    // Use ASCII-safe test data
    let testData = "test binary data".data(using: .utf8)!
    form.addDataField(named: "file", data: testData)

    let data = form.data
    #expect(data != nil)

    // Convert to string using latin1 which can handle any byte sequence
    let string = String(data: data!, encoding: .isoLatin1)!
    #expect(string.contains("Content-Disposition: form-data; name=\"file\""))
    #expect(!string.contains("filename="))
  }

  @Test("Data field with filename")
  func dataFieldWithFilename() {
    var form = MultipartFormData()
    let testData = "test binary data".data(using: .utf8)!
    form.addDataField(named: "file", data: testData, fileName: "photo.png")

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .isoLatin1)!
    #expect(string.contains("filename=\"photo.png\""))
  }

  @Test("Data field with mime type")
  func dataFieldWithMimeType() {
    var form = MultipartFormData()
    let testData = "test binary data".data(using: .utf8)!
    form.addDataField(named: "image", data: testData, fileName: "photo.png", mimeType: "image/png")

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .isoLatin1)!
    #expect(string.contains("Content-Type: image/png"))
  }

  @Test("Data field with all options")
  func dataFieldWithAllOptions() {
    var form = MultipartFormData()
    let testData = "test binary data".data(using: .utf8)!
    form.addDataField(named: "document", data: testData, fileName: "report.pdf", mimeType: "application/pdf")

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .isoLatin1)!
    #expect(string.contains("name=\"document\""))
    #expect(string.contains("filename=\"report.pdf\""))
    #expect(string.contains("Content-Type: application/pdf"))
  }

  // MARK: - Mixed Fields Tests

  @Test("Mixed text and data fields")
  func mixedFields() {
    var form = MultipartFormData()
    form.addTextField(named: "title", value: "My Document")
    form.addDataField(named: "file", data: Data([0x01, 0x02, 0x03]), fileName: "data.bin", mimeType: "application/octet-stream")
    form.addTextField(named: "description", value: "A test file")

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!
    #expect(string.contains("name=\"title\""))
    #expect(string.contains("My Document"))
    #expect(string.contains("name=\"file\""))
    #expect(string.contains("filename=\"data.bin\""))
    #expect(string.contains("name=\"description\""))
    #expect(string.contains("A test file"))
  }

  // MARK: - Boundary Tests

  @Test("Data ends with closing boundary")
  func dataEndsWithClosingBoundary() {
    var form = MultipartFormData()
    form.addTextField(named: "test", value: "value")

    let data = form.data!
    let string = String(data: data, encoding: .utf8)!

    #expect(string.hasSuffix("--\(form.boundary)--"))
  }

  // MARK: - MultipartFormEndpoint Tests

  @Test("MultipartFormEndpoint creates valid URL request")
  func endpointCreatesValidRequest() throws {
    let form = MultipartFormData { form in
      form.addTextField(named: "key", value: "value")
    }

    let endpoint = MultipartFormEndpoint<String>(
      path: "upload",
      method: .post,
      form: form
    )

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.url?.absoluteString == "https://api.test.com/upload")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
    #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("boundary=\(form.boundary)") == true)
  }

  @Test("MultipartFormEndpoint with custom headers")
  func endpointWithCustomHeaders() throws {
    let form = MultipartFormData { form in
      form.addTextField(named: "key", value: "value")
    }

    let endpoint = MultipartFormEndpoint<Void>(
      path: "upload",
      headers: ["Authorization": "Bearer token"],
      form: form
    )

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
  }
}

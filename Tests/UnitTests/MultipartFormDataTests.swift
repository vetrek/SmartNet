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

// MARK: - MultipartBuilder Tests

@Suite("MultipartBuilder Tests")
struct MultipartBuilderTests {

  // MARK: - Basic Builder Tests

  @Test("Builder with single TextField")
  func singleTextField() {
    let form = MultipartFormData {
      TextField("username", value: "johndoe")
    }

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!
    #expect(string.contains("name=\"username\""))
    #expect(string.contains("johndoe"))
  }

  @Test("Builder with multiple TextFields")
  func multipleTextFields() {
    let form = MultipartFormData {
      TextField("first", value: "John")
      TextField("last", value: "Doe")
      TextField("email", value: "john@example.com")
    }

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!
    #expect(string.contains("name=\"first\""))
    #expect(string.contains("John"))
    #expect(string.contains("name=\"last\""))
    #expect(string.contains("Doe"))
    #expect(string.contains("name=\"email\""))
    #expect(string.contains("john@example.com"))
  }

  @Test("Builder with DataField")
  func dataField() {
    let testData = "binary content".data(using: .utf8)!

    let form = MultipartFormData {
      DataField("file", data: testData)
    }

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!
    #expect(string.contains("name=\"file\""))
    #expect(string.contains("binary content"))
  }

  @Test("Builder with DataField including filename and mimeType")
  func dataFieldWithOptions() {
    let testData = "image data".data(using: .utf8)!

    let form = MultipartFormData {
      DataField("avatar", data: testData, fileName: "photo.png", mimeType: "image/png")
    }

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .isoLatin1)!
    #expect(string.contains("name=\"avatar\""))
    #expect(string.contains("filename=\"photo.png\""))
    #expect(string.contains("Content-Type: image/png"))
  }

  @Test("Builder with FileField auto-detects MIME type")
  func fileFieldAutoMimeType() {
    let testData = "pdf content".data(using: .utf8)!

    let form = MultipartFormData {
      FileField("document", data: testData, fileName: "report.pdf")
    }

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .isoLatin1)!
    #expect(string.contains("filename=\"report.pdf\""))
    #expect(string.contains("Content-Type: application/pdf"))
  }

  @Test("Builder with mixed field types")
  func mixedFieldTypes() {
    let fileData = "file content".data(using: .utf8)!

    let form = MultipartFormData {
      TextField("title", value: "My Upload")
      DataField("raw", data: fileData)
      FileField("document", data: fileData, fileName: "doc.pdf")
      TextField("description", value: "A test upload")
    }

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .isoLatin1)!
    #expect(string.contains("name=\"title\""))
    #expect(string.contains("My Upload"))
    #expect(string.contains("name=\"raw\""))
    #expect(string.contains("name=\"document\""))
    #expect(string.contains("filename=\"doc.pdf\""))
    #expect(string.contains("name=\"description\""))
  }

  // MARK: - Conditional Builder Tests

  @Test("Builder with if condition - true")
  func conditionalTrue() {
    let includeEmail = true

    let form = MultipartFormData {
      TextField("name", value: "John")
      if includeEmail {
        TextField("email", value: "john@example.com")
      }
    }

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!
    #expect(string.contains("name=\"name\""))
    #expect(string.contains("name=\"email\""))
  }

  @Test("Builder with if condition - false")
  func conditionalFalse() {
    let includeEmail = false

    let form = MultipartFormData {
      TextField("name", value: "John")
      if includeEmail {
        TextField("email", value: "john@example.com")
      }
    }

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!
    #expect(string.contains("name=\"name\""))
    #expect(!string.contains("name=\"email\""))
  }

  @Test("Builder with if-else condition")
  func conditionalIfElse() {
    let isPremium = true

    let form = MultipartFormData {
      if isPremium {
        TextField("tier", value: "premium")
      } else {
        TextField("tier", value: "basic")
      }
    }

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!
    #expect(string.contains("premium"))
    #expect(!string.contains("basic"))
  }

  @Test("Builder with for loop")
  func forLoop() {
    let tags = ["swift", "ios", "networking"]

    let form = MultipartFormData {
      for (index, tag) in tags.enumerated() {
        TextField("tag[\(index)]", value: tag)
      }
    }

    let data = form.data
    #expect(data != nil)

    let string = String(data: data!, encoding: .utf8)!
    #expect(string.contains("name=\"tag[0]\""))
    #expect(string.contains("swift"))
    #expect(string.contains("name=\"tag[1]\""))
    #expect(string.contains("ios"))
    #expect(string.contains("name=\"tag[2]\""))
    #expect(string.contains("networking"))
  }

  // MARK: - FileField MIME Type Detection Tests

  @Test("FileField detects image MIME types")
  func detectImageMimeTypes() {
    let data = Data()

    let jpgForm = MultipartFormData { FileField("f", data: data, fileName: "photo.jpg") }
    let pngForm = MultipartFormData { FileField("f", data: data, fileName: "image.png") }
    let gifForm = MultipartFormData { FileField("f", data: data, fileName: "anim.gif") }

    #expect(String(data: jpgForm.data!, encoding: .isoLatin1)!.contains("image/jpeg"))
    #expect(String(data: pngForm.data!, encoding: .isoLatin1)!.contains("image/png"))
    #expect(String(data: gifForm.data!, encoding: .isoLatin1)!.contains("image/gif"))
  }

  @Test("FileField detects document MIME types")
  func detectDocumentMimeTypes() {
    let data = Data()

    let pdfForm = MultipartFormData { FileField("f", data: data, fileName: "doc.pdf") }
    let jsonForm = MultipartFormData { FileField("f", data: data, fileName: "data.json") }
    let txtForm = MultipartFormData { FileField("f", data: data, fileName: "readme.txt") }

    #expect(String(data: pdfForm.data!, encoding: .isoLatin1)!.contains("application/pdf"))
    #expect(String(data: jsonForm.data!, encoding: .isoLatin1)!.contains("application/json"))
    #expect(String(data: txtForm.data!, encoding: .isoLatin1)!.contains("text/plain"))
  }

  @Test("FileField uses octet-stream for unknown extensions")
  func unknownExtensionFallback() {
    let data = Data()

    let form = MultipartFormData {
      FileField("f", data: data, fileName: "file.xyz")
    }

    let string = String(data: form.data!, encoding: .isoLatin1)!
    #expect(string.contains("application/octet-stream"))
  }

  @Test("FileField allows MIME type override")
  func mimeTypeOverride() {
    let data = Data()

    let form = MultipartFormData {
      FileField("f", data: data, fileName: "data.bin", mimeType: "application/custom")
    }

    let string = String(data: form.data!, encoding: .isoLatin1)!
    #expect(string.contains("application/custom"))
  }

  // MARK: - Integration with MultipartFormEndpoint

  @Test("Builder works with MultipartFormEndpoint")
  func builderWithEndpoint() throws {
    let form = MultipartFormData {
      TextField("username", value: "test")
      FileField("avatar", data: Data([0x89, 0x50, 0x4E, 0x47]), fileName: "avatar.png")
    }

    let endpoint = MultipartFormEndpoint<String>(
      path: "profile/upload",
      form: form
    )

    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let request = try endpoint.urlRequest(with: config)

    #expect(request.httpBody != nil)
    #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
  }
}

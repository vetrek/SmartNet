


# SmartNet

SmartNet is a comprehensive Swift HTTP networking library designed for iOS development. It simplifies complex networking tasks, offering support for multipart/form-data, concurrent uploads and downloads, and modern Swift features like async/await and Combine.

## Features

- Global Network Configuration
- Supported Request Types: Encodable, Dictionary, String, multipart/form-data
- Flexible Response Handling: Decodable, String, Data, Void
- Concurrent Uploads/Downloads with progress tracking
- Async/Await and Combine Support
- Middleware for request/response interception

## Projects using SmartNet
- [YourVPN](https://yourvpn.world/)

## Installation

### Swift Package Manager

```plaintext
https://github.com/vetrek/SmartNet.git
```

### CocoaPods

```ruby
pod 'SmartNet'
```

## Usage Examples

### Configuring the ApiClient

```swift
let apiClient = ApiClient(
  config: NetworkConfiguration(
    baseURL: URL(string: "https://api.publicapis.org")!
  )
)
```

**Advanced**
```swift
let config = NetworkConfiguration(
    baseURL: URL(string: "https://api.publicapis.org")!,
    headers: ["Content-Type": "application/json"],
    queryParameters: ["userid": "xxxxxx"],
    trustedDomains: ["api.publicapis.org"],
    requestTimeout: 120
)
let network = ApiClient(config: config)
```

### Endpoints
```swift
// MARK: - Define Response DTO
struct Person: Codable {
  let name: string?
  let age: Int?
}

// MARK: - GET
let getEndpoint = Endpoint<Person>(
  path: "person",
  queryParameters: QueryParameters(
    parameters: [
      "name": "Jhon",
      "age": 18
    ]
  )
)

// MARK: - POST
let postEndpoint = Endpoint<Person>(
  path: "person",
  method: .post,
  body: HTTPBody(
    encodable: PersonRequst(
      name: "Jhon",
      age: 18
    )
  )
)
```

### Async

```swift
do {
  let person = try await apiClient.request(with: getEndpoint)
  print(person.name)
} catch {
    print(error)
}
```

### Closures

```swift
apiClient.request(with: postEndpoint) { response in
    switch response.result {
    case let .success(person):
        print(person.name)
    case let .failure(error):
        print(error.localizedDescription)
    }
}
```

### Combine

```swift
var subscriptions = Set<AnyCancellable>()

apiClient.request(with: getEndpoint)
    .sink(receiveCompletion: { completion in
        if case .failure(let error) = completion {
            print("Error: \(error)")
        }
    }, receiveValue: { person in
        print(person.name)
    })
    .store(in: &subscriptions)
```

### Middleware

Intercept every request and response with middleware.

```swift
// MARK: - Add a global middleware
network.addMiddleware(
  ApiClient.Middleware(
    pathComponent: "/",
    preRequestCallback: { request in
      print("Request: \(request)")
      throw NSError(
        domain: "smartnet",
        code: 1, 
        userInfo: [
          NSLocalizedDescriptionKey: "Invalid API Request"
        ]
      )
    },
    postResponseCallback: { _, _, _ in
      await testAsync()
      throw NSError(
        domain: "smartnet", 
        code: 2,
        userInfo: [
          NSLocalizedDescriptionKey: "Invalid Token Refres"
        ]
      )
    }
  )
)

// MARK: - Add path specific middleware
network.addMiddleware(
  ApiClient.Middleware(
    pathComponent: "person",
    preRequestCallback: { request in
      print("Request: \(request)")
      throw NSError(
        domain: "smartnet",
        code: 1, 
        userInfo: [
          NSLocalizedDescriptionKey: "Invalid API Request"
        ]
      )
    },
    postResponseCallback: { _, _, _ in
      print("Response received")
      throw NSError(
        domain: "smartnet", 
        code: 2,
        userInfo: [
          NSLocalizedDescriptionKey: "Invalid Token Refres"
        ]
      )
    }
  )
)
```

### Upload

Upload files with multipart/form-data. Progress updates and response handling are supported.

```swift
let uploadTask = try! network.upload(
  with: MultipartFormEndpoint(
    path: "your/upload/path",
    form: MultipartFormData { form in
      form.addTextField(named: "key-1", value: "value-1")
      form.addDataField(named: "file", data: fileData, fileName: "example.jpg", mimeType: "image/jpeg")
    }
  )
).progress { progress in
  print("Upload Progress: \(progress.fractionCompleted)")
}.response { response in
  print("Upload Response: \(response)")
}
```

### Downloading Files

Download files with progress tracking and easy response handling.

```swift
let downloadTask = network.download(url: URL(string: "https://example.com/file.zip")!)?
  .downloadProgress { progress, _ in
    print("Download Progress: \(progress.fractionCompleted)")
  }
  .response { response in
    print("Download Response: \(response.result)")
  }
```

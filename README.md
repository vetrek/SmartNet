# SmartNet

SmartNet is a modern Swift HTTP networking library designed for iOS development. It provides a clean, type-safe API for making network requests with support for multiple programming paradigms and advanced features like middleware, file operations, and debugging tools.

## Features

### Core Features

- **Flexible Configuration**: Comprehensive network configuration with support for base URLs, headers, query parameters, and more
- **Multiple Programming Paradigms**: Support for Async/Await, Combine, and closure-based callbacks
- **Type-Safe Request Building**: Generic `Endpoint<Value>` type for type-safe responses and flexible request configuration

### Advanced Features

- **Middleware System**:
  - Pre-request middleware for request modification
  - Post-response middleware for response handling
  - Path-specific middleware support
  - Async middleware support
- **File Operations**:
  - Multipart form data uploads
  - File downloads with progress tracking
  - Concurrent upload/download support
- **Debugging Tools**:
  - Debug mode configuration

## Projects using SmartNet
- [YourVPN](https://yourvpn.world/)

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vetrek/SmartNet.git", from: "1.0.0")
]
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'SmartNet'
```

## Usage

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

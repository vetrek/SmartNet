# SmartNet

**Type-safe Swift HTTP networking**

[![Platform](https://img.shields.io/badge/platform-iOS%2013%2B%20%7C%20macOS%2010.15%2B-blue.svg)](https://developer.apple.com/swift/)
[![Swift](https://img.shields.io/badge/Swift-5.5%2B-orange.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

SmartNet provides flexible, type-safe HTTP networking that adapts to any Swift project's programming paradigm. Zero dependencies, thread-safe by design.

## Features

- **Three programming paradigms**: async/await, Combine, closures
- **Type-safe generic endpoints**: `Endpoint<T>` with automatic decoding
- **Flexible path matching**: exact, wildcard, glob, regex patterns
- **Configurable retry policies**: exponential backoff, linear, immediate
- **Middleware system**: request/response interception with pattern matching
- **File operations**: upload/download with progress tracking
- **Zero external dependencies**
- **Thread-safe by design**

## Installation

Add SmartNet to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vetrek/SmartNet.git", from: "1.0.0")
]
```

## Quick Start

```swift
let client = ApiClient(config: NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!
))

struct User: Codable {
    let id: Int
    let name: String
}

let user: User = try await client.request(
    with: Endpoint(path: "users/1")
)
```

## Configuration

**Basic:**
```swift
let client = ApiClient(config: NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!
))
```

**With headers and timeout:**
```swift
let config = NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    headers: ["Content-Type": "application/json"],
    queryParameters: ["apiKey": "your-key"],
    requestTimeout: 30
)
let client = ApiClient(config: config)
```

## Making Requests

### Async/Await

```swift
do {
    let user: User = try await client.request(with: Endpoint(path: "users/1"))
    print(user.name)
} catch {
    print(error)
}
```

### Combine

```swift
var subscriptions = Set<AnyCancellable>()

client.request(with: Endpoint<User>(path: "users/1"))
    .sink(receiveCompletion: { completion in
        if case .failure(let error) = completion {
            print("Error: \(error)")
        }
    }, receiveValue: { user in
        print(user.name)
    })
    .store(in: &subscriptions)
```

### Closures

```swift
client.request(with: Endpoint<User>(path: "users/1")) { response in
    switch response.result {
    case .success(let user):
        print(user.name)
    case .failure(let error):
        print(error.localizedDescription)
    }
}
```

## Endpoints

**GET with query parameters:**
```swift
let endpoint = Endpoint<User>(
    path: "users",
    queryParameters: QueryParameters(parameters: [
        "name": "John",
        "limit": 10
    ])
)
```

**POST with body:**
```swift
struct CreateUserRequest: Codable {
    let name: String
    let email: String
}

let endpoint = Endpoint<User>(
    path: "users",
    method: .post,
    body: HTTPBody(encodable: CreateUserRequest(
        name: "John",
        email: "john@example.com"
    ))
)
```


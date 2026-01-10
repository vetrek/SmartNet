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
    .package(url: "https://github.com/vetrek/SmartNet.git", from: "2.0.1")
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

## Retry Policies

By default, SmartNet does not retry failed requests. Enable retries by configuring a retry policy using the static factory methods.

**Enable retries globally:**

```swift
let config = NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    retryPolicy: .exponential()  // 3 retries with exponential backoff
)
```

**Built-in policies:**

| Factory Method | Delay Pattern | Default Retries |
|----------------|---------------|-----------------|
| `.exponential()` | 1s, 2s, 4s, 8s... (with jitter) | 3 |
| `.linear()` | 1s, 2s, 3s, 4s... | 3 |
| `.immediate()` | No delay | 1 |
| `.none` | No retries (default) | 0 |

**Customize retry behavior:**

```swift
// Custom exponential backoff
let config = NetworkConfiguration(
    baseURL: url,
    retryPolicy: .exponential(
        maxRetries: 5,
        baseDelay: 2.0,
        jitter: false,
        conditions: [.timeout, .serverError]
    )
)
```

**Per-endpoint retry configuration:**

```swift
let endpoint = Endpoint<User>(path: "users/1")
    .retryPolicy(.exponential(maxRetries: 5))
```

**RetryCondition options:**

- `.timeout` - request timed out
- `.connectionLost` - network connection lost
- `.networkFailure` - general network failure
- `.serverError` - HTTP 5xx responses
- `.rateLimited` - HTTP 429 (respects `Retry-After` header)
- `.dnsFailure` - DNS lookup failed

## Middleware

Intercept requests and responses with path-matched middleware. Uses the `PathMatcher` system for flexible routing.

**Global middleware (all requests):**

```swift
client.addMiddleware(
    ApiClient.Middleware(
        pathMatcher: PathMatcher.contains("/"),
        preRequestCallback: { request in
            var req = request
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return req
        },
        postResponseCallback: { data, response, error in
            return .next
        }
    )
)
```

**Path-specific middleware:**

```swift
client.addMiddleware(
    ApiClient.Middleware(
        pathMatcher: PathMatcher.contains("users"),
        preRequestCallback: { request in
            print("User request: \(request.url?.path ?? "")")
            return request
        },
        postResponseCallback: { _, _, _ in .next }
    )
)
```

**PathMatcher patterns:**

| Factory Method            | Description             | Example                                 |
| ------------------------- | ----------------------- | --------------------------------------- |
| `.contains("/")`          | Global (all paths)      | Matches everything                      |
| `.contains("users")`      | Contains segment        | `/api/users/123`                        |
| `.exact("/users")`        | Exact match             | `/users` only                           |
| `.wildcard("/users/*")`   | Single segment wildcard | `/users/123` but not `/users/123/posts` |
| `.glob("/api/**")`        | Multi-segment wildcard  | `/api`, `/api/v1/users`                 |
| `.regex("^/users/\\d+$")` | Regular expression      | `/users/123`                            |

## File Operations

**Upload with multipart form:**

```swift
let uploadTask = try client.upload(
    with: MultipartFormEndpoint(
        path: "upload",
        form: MultipartFormData {
            TextField("name", value: "avatar")
            FileField("file", data: imageData, fileName: "photo.jpg")
        }
    )
)
.progress { progress in
    print("Upload: \(progress.fractionCompleted * 100)%")
}
.response { response in
    print("Done: \(response.result)")
}
```

**Download with progress:**

```swift
let downloadTask = client.download(url: URL(string: "https://example.com/file.zip")!)?
    .downloadProgress { progress, _ in
        print("Download: \(progress.fractionCompleted * 100)%")
    }
    .response { response in
        print("Saved to: \(response.result)")
    }
```

## Error Handling

All errors are returned as `NetworkError`:

```swift
do {
    let user: User = try await client.request(with: endpoint)
} catch let error as NetworkError {
    switch error {
    case .error(let statusCode, let data):
        print("HTTP \(statusCode)")
    case .timeout:
        print("Request timed out")
    case .connectionLost:
        print("Connection lost")
    case .parsingFailed(let error):
        print("Decoding failed: \(error)")
    default:
        print("Error: \(error)")
    }
}
```

## Projects Using SmartNet

- [YourVPN](https://yourvpn.world/)

## License

SmartNet is available under the MIT license.

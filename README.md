# SmartNet

**Type-safe Swift HTTP networking**

[![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20macOS%2011%2B-blue.svg)](https://developer.apple.com/swift/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

Type-safe endpoints with async/await, retry policies, middleware, and queued uploads/downloads. Zero dependencies.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/vetrek/SmartNet.git", from: "2.4.0")
]
```

## Quick Start

```swift
struct User: Codable {
    let id: Int
    let name: String
}

let client = ApiClient(config: NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    headers: ["Accept": "application/json"],
    requestTimeout: 30
))

let user: User = try await client.request(with: Endpoint(path: "users/1"))
```

Every `request` also has a Combine publisher overload and a completion-closure overload, for code that isn't async yet.

## Endpoints

```swift
let search = Endpoint<[User]>(
    path: "users",
    queryParameters: QueryParameters(parameters: ["name": "John", "limit": 10])
)

struct CreateUser: Encodable {
    let name: String
}

let create = Endpoint<User>(
    path: "users",
    method: .post,
    body: HTTPBody(encodable: CreateUser(name: "John"))
)
```

## Retry Policies

Requests are not retried unless you set a policy, globally or per endpoint:

```swift
let config = NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    retryPolicy: .exponential(maxRetries: 5, conditions: [.timeout, .serverError])
)

let endpoint = Endpoint<User>(path: "users/1").retry(.immediate())
```

| Policy | Delays | Default retries |
|--------|--------|-----------------|
| `.exponential()` | 1s, 2s, 4s… with jitter | 3 |
| `.linear()` | 1s, 2s, 3s… | 3 |
| `.immediate()` | none | 1 |
| `.none` | no retries (default) | 0 |

Conditions: `.timeout`, `.connectionLost`, `.networkFailure`, `.serverError` (5xx), `.rateLimited` (429, honours `Retry-After`), `.dnsFailure`. The default set is the first four.

## Middleware

Modify requests and inspect responses for matching paths:

```swift
client.addMiddleware(
    ApiClient.Middleware(
        pathMatcher: .contains("/"),
        preRequestCallback: { request in
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        },
        postResponseCallback: { data, response, error in
            .next
        }
    )
)
```

Throw from `preRequestCallback` to cancel the request. Return `.retryRequest` from `postResponseCallback` to send it again; the retry policy's limit still applies.

| Matcher | Matches |
|---------|---------|
| `.contains("/")` | every path |
| `.contains("users")` | any path with a `users` segment, e.g. `/api/users/123` |
| `.exact("/users")` | `/users` only |
| `.wildcard("/users/*")` | `/users/123`, not `/users/123/posts` |
| `.glob("/api/**")` | `/api`, `/api/v1/users` |
| `.regex("^/users/\\d+$")` | `/users/123` (returns `nil` for an invalid pattern) |

## Uploads and Downloads

```swift
let file = try await client.download(with: DownloadEndpoint(path: "files/report.pdf"))
print(file.localURL)
```

To track progress, pause or cancel, keep the returned task:

```swift
let upload = try client.upload(
    with: MultipartFormEndpoint<String>(
        path: "upload",
        form: MultipartFormData {
            TextField("name", value: "avatar")
            FileField("file", data: imageData, fileName: "photo.jpg")
        }
    )
)
.progress { progress in print(progress.fractionCompleted) }
.response { response in print(response.result) }

let download = client.download(url: URL(string: "https://example.com/file.zip")!)?
    .downloadProgress { progress, _ in print(progress.fractionCompleted) }
    .response { response in
        if case .success(let file) = response.result {
            print(file.localURL)
        }
    }
```

How transfers run:

- **Queued.** Downloads run up to the session's `httpMaximumConnectionsPerHost` at once (6 by default). Uploads run one fewer, so API requests to the same host always have a free connection. Extra transfers wait in `.waitingStart`, and their request timeout only starts when they do.
- **Pause and resume.** `pause()` frees the transfer's slot. `resume()` continues from resume data when the server supports it, otherwise restarts, and goes to the front of the queue. Upload pause/resume requires iOS 17 / macOS 14.
- **Cancel.** `cancel()` ends in `.cancelled` and delivers a cancellation error to `response`. `client.destroy()` cancels every running and queued transfer.
- **State.** `state` is already final (`.completed`, `.error` or `.cancelled`) when `response` runs.

## Error Handling

Every failure is a `NetworkError`:

```swift
do {
    let user: User = try await client.request(with: endpoint)
} catch let error as NetworkError {
    switch error {
    case .error(let statusCode, _):
        print("HTTP \(statusCode)")
    case .timeout, .connectionLost:
        print("Network problem")
    case .parsingFailed:
        print("Decoding failed: \(error)")
    default:
        print(error)
    }
}
```

## Projects Using SmartNet

- [YourVPN](https://yourvpn.world/)

## License

SmartNet is available under the MIT license.

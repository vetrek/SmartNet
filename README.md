# SmartNet
HTTP Networking Library which primary scope is to make Networking as easy as possible.
Greatly inspired by SENetworking (https://github.com/kudoleh/SENetworking).

## Features

- [Easy configuration](#network-configuration)
- Supported Requests:  **Encodable**, **Dictionary**, **String**
- [Supported Response Types: **Decodable**, **String**, **Data**, **Void**
- Supported QueryParameters: **Encodable**, **Dictionary**
- iOS 13+ **Combine** Support
- Light and easy Networking Interface
- "Truested Domains" list to bypass SSL Authentication Challenge (**not recommended**)

## Examples

- ### Network Default Configuration

**NetworkConfiguration** is used to define defaults settings that are going to be used in every call. 

If the Endpoint is initialized with "***useEndpointHeaderOnly: true***" the NetworkConfiguration headers are going to be ignored.

Base
```swift
let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
let network = SmartNet(config: config)
```

Advanced
```swift
let config = NetworkConfiguration(
    baseURL: URL(string: "https://api.publicapis.org")!,
    headers: ["Content-Type": "application/json"],
    queryParameters: ["userid": "xxxxxx"],
    trustedDomains: ["api.publicapis.org"],
    requestTimeout: 120
)
let network = SmartNet(config: config)
```

- ### Create an Endpoint

#### GET

```swift
let endpoint = Endpoint<Person>(
    path: "person",
    queryParameters: QueryParameters(
        parameters: [
            "name": "Jhon", 
            "age": 18
        ]
    )
)
```
Equivalent of https://api.example.com/person?name=Jhon&age=18


***POST***
```swift
let endpoint = Endpoint<Person>(
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
Equivalent of https://api.example.com/person with body equal to:

```json
{
    "name": "Jhon",
    "age": 18
}
```

**API CALL**

- Using Closures

```swift
network.request(with: endpoint) { (response) in
    switch response {
    case .success(let person):
        print("Success! \(person.name)")
    case .failure(let error):
        print(error.localizedDescription)
    }
}
```

- Using Combine

```swift
var subscriptions = Set<AnyCancellable>()

network.request(with: endpoint)?
    .sink(
        receiveCompletion: { (response) in
            if case .failure(let error) = response {
                print(error.localizedDescription)
            }
        },
        receiveValue: { (person) in
            print("Success! \(person.name)")
        }
    )
    .store(in: &subscriptions)
```

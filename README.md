# EasyNetworking
HTTP Networking Library which primary scope is to make Networking as easy as possible.
Greatly inspired by SENetworking (https://github.com/kudoleh/SENetworking).

### Features

- [Easy configuration](#config)
- Supported Requests:  [**Encodable**](#requests_encodable), [**Dictionary**](#RequestsDictionary), [**String**](#requests_string)
- [Supported Response Types: [**Decodable**](#response_decodable), [**String**](#response_string), [**Data**](#response_data), [**Void**](#response_void)
- Supported QueryParameters: [**Encodable**](#query_encodable), [**Dictionary**](#query_dictionary)
- iOS 13+ **Combine** Support
- Light and easy Networking Interface
- "Truested Domains" list to bypass SSL Authentication Challenge (**not recommended**)

## Examples

**Network configuration**:
```swift
let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
let network = EasyNetwork(config: config)
```

**Endpoint configuration**:

***GET***

```swift
let endpoint = Endpoint<Person>(
    path: "person",
    queryParameters: QueryParameters(
      parameters: ["name": "Jhon", "age": 18]
    )
)
```
Equivalent of https://api.example.com/person?name=Jhon&age=18


***POST***
```swift
let endpoint = Endpoint<Person>(
    path: "person",
    method: .post,
    body: HTTPBody(encodable: PersonRequst(name: "Jhon", age: 18), bodyEncoding: .json)
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

- Using Completion

```swift
let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
let network = EasyNetwork(config: config)

let endpoint = Endpoint<Person>(
    path: "person",
    method: .post,
    queryParameters: QueryParameters(
      parameters: ["name": "Jhon", "age": 18]
    )
)

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
network.request(with: endpoint)?
    .sink(
        receiveCompletion: { (response) in
            switch response {
            case .failure(let error):
                print(error.localizedDescription)
            case .finished:
                print("Done")
            }
        },
        receiveValue: { (response) in
                print(response)
        }
    )
    .store(in: &subscriptions)
```
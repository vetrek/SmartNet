//
//  ContentView.swift
//  EasyNetworkingDemo
//
//  Created by Valerio Sebastianelli on 7/19/21.
//

import SwiftUI
import EasyNetworking
import Combine


struct EndpointWrapper<Value>: Hashable {
    let uid = UUID()
    let endpoint: Endpoint<Value>
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    static func == (lhs: EndpointWrapper<Value>, rhs: EndpointWrapper<Value>) -> Bool {
        lhs.uid == rhs.uid
    }
}

struct ContentView: View {
//
//    init() {
//        let network = EasyNetwork(config: NetworkConfiguration(baseURL: URL(string: "https://example.com")!))
//        let endpoint = Endpoint<String>(path: "")
//        let request = network.request(with: endpoint) { (response) in
//            print(response)
//        }
//        request?.cancel()
//    }
    
    let endpoints: [EndpointWrapper<Data>] = [
        EndpointWrapper(
            endpoint: Endpoint(
                path: "entries",
                queryParameters: QueryParameters(
                    parameters: ["description": "cat"]
                )
            )
        ),
        EndpointWrapper(
            endpoint: Endpoint(
                path: "entries",
                method: .post,
                queryParameters: QueryParameters(
                    parameters: ["description": "cat"]
                )
            )
        ),
    ]
    
    let network = EasyNetwork(
        config: NetworkConfiguration(
            baseURL: URL(string: "https://api.publicapis.org")!,
            trustedDomains: ["api.publicapis.org"]
        )
    )
    
    let test = Test()
    
    var body: some View {
        ScrollView(/*@START_MENU_TOKEN@*/.vertical/*@END_MENU_TOKEN@*/, showsIndicators: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/) {
            LazyVStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/, pinnedViews: /*@START_MENU_TOKEN@*/[]/*@END_MENU_TOKEN@*/) {
                ForEach(endpoints, id: \.uid) { endpoint in
                    HStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/) {
                        Button {
                            test.asd(endpoint: endpoint.endpoint)
//                            network.request(
//                                with: endpoint.endpoint
//                            ) { (response) in
//                                print(String(data: response.value!, encoding: .utf8))
//                            }
                        } label: {
                            Text(endpoint.endpoint.method.rawValue)
                        }
                    }.padding()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


class Test {
    let endpoints: [EndpointWrapper<Data>] = [
        EndpointWrapper(
            endpoint: Endpoint(
                path: "entries",
                queryParameters: QueryParameters(
                    parameters: ["description": "cat"]
                )
            )
        ),
        EndpointWrapper(
            endpoint: Endpoint(
                path: "entries",
                method: .post,
                queryParameters: QueryParameters(
                    parameters: ["description": "cat"]
                )
            )
        ),
    ]
    
    let network = EasyNetwork(
        config: NetworkConfiguration(
            baseURL: URL(string: "https://api.publicapis.org")!,
            trustedDomains: ["api.publicapis.org"]
        )
    )
    
    var subscriptions = Set<AnyCancellable>()
    
    func asd<E>(endpoint: E) where E : Requestable, E.Response == Data {
        network.request(with: endpoint)?
            .receive(on: DispatchQueue.main)
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
                    print(String(data: response, encoding: .utf8)!)
                }
            )
            .store(in: &subscriptions)
    }
}

//
//  ContentView.swift
//
//  Copyright (c) 2021 Valerio69 (valerio.alsebas@gmail.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import SwiftUI
import SmartNet
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
//        let network = SmartNet(config: NetworkConfiguration(baseURL: URL(string: "https://example.com")!))
//        let endpoint = Endpoint<String>(path: "")
//        let request = network.request(with: endpoint) { (response) in
//            print(response)
//        }
//        request?.cancel()
//    }

    let endpoints: [EndpointWrapper<Void>] = [
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
        )
    ]

    let network = SmartNet(
        config: NetworkConfiguration(
            baseURL: URL(string: "https://api.publicapis.org")!,
            trustedDomains: ["api.publicapis.org"]
        )
    )

    let test = Test()

    var body: some View {
        ScrollView(/*@START_MENU_TOKEN@*/.vertical/*@END_MENU_TOKEN@*/, showsIndicators: true/*@END_MENU_TOKEN@*/) {
            LazyVStack(alignment: .center/*@END_MENU_TOKEN@*/, spacing: nil/*@END_MENU_TOKEN@*/, pinnedViews: []/*@END_MENU_TOKEN@*/) {
                ForEach(endpoints, id: \.uid) { endpoint in
                    HStack(alignment: .center/*@END_MENU_TOKEN@*/, spacing: nil/*@END_MENU_TOKEN@*/) {
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
        )
    ]

    let network = SmartNet(
        config: NetworkConfiguration(
            baseURL: URL(string: "https://api.publicapis.org")!,
            trustedDomains: ["api.publicapis.org"]
        )
    )

    var subscriptions = Set<AnyCancellable>()

    func asd<E>(endpoint: E) where E: Requestable, E.Response == Void {
        network.request(with: endpoint)?
            .sink(
                receiveCompletion: { (response) in
                    if case .failure(let error) = response {
                        print(error.localizedDescription)
                    }
                },
                receiveValue: { (response) in
                    print(response)
                }
            )
            .store(in: &subscriptions)
    }
}

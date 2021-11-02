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
        headers: ["ASD": "aaa"],
        trustedDomains: ["api.publicapis.org"]
    )
)

let test = Test()

var downloadTask: DownloadTask?

struct ContentView: View {

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .center, spacing: nil) {
                ForEach(endpoints, id: \.uid) { endpoint in
                    HStack(alignment: .center, spacing: nil) {
                        Button {
//                            test.asd(endpoint: endpoint.endpoint)
//                            network.request(
//                                with: endpoint.endpoint
//                            ) { (response) in
//                                print(response)
//                            }
                            downloadTask = network.download(url: URL(string: "https://jsoncompare.org/LearningContainer/SampleFiles/Video/MP4/Sample-Video-File-For-Testing.mp4")!)?
                                .downloadProgress { progress, fileSize in
                                    print("[Download - Progress]", progress.fractionCompleted, fileSize)
                                }
                                .response { response in
                                    print("[Download - Response]", response.result)
                                }
                            
                        } label: {
                            Text(endpoint.endpoint.method.rawValue)
                        }
                    }.padding()
                }
                
                HStack(alignment: .center, spacing: 30) {
                    Button {
                        downloadTask?.pause()
                    } label: {
                        Text("PAUSE")
                    }
                    
                    Button {
                        downloadTask?.resume()
                    } label: {
                        Text("RESUME")
                    }
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

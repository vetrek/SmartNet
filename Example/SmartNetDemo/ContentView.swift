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

let network = ApiClient(
  config: NetworkConfiguration(
    baseURL: URL(string: "https://httpbin.org/post")!,
    trustedDomains: ["httpbin.org"]
  )
)

var downloadTask: DownloadTask?

struct ContentView: View {
  @State private var uploadTask: UploadTask<String>?
  @State private var uploadProgress: Double?
  
  var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      VStack(alignment: .center, spacing: 20) {
        HStack {
          Button {
            uploadTask = try! network.upload(
              with: MultipartFormEndpoint(
                path: "https://httpbin.org/post",
                isFullPath: true,
                form: MultipartFormData { form in
                  // Create a Data object with 10MB size
                  form.addTextField(named: "key-1", value: .randomString(length: 100000))
                  form.addTextField(named: "key-1", value: .randomString(length: 100000))
                  
//                  let tenMB = 1 * 1024 * 1024 // 10MB in bytes
//                  form.addDataField(named: "key-1", data: Data(repeating: 0, count: tenMB))
//                  form.addDataField(named: "key-2", data: Data(repeating: 1, count: tenMB))
                }
              )
            )
            .progress { progress in
//              print("[Upload - Progress]", progress.fractionCompleted)
              uploadProgress = progress.fractionCompleted
            }
            .response { response in
//              print("[Upload - Response]", response.result)
            }
          } label: {
            Text("Upload")
          }
          
          if let uploadProgress {
            Text("\(uploadProgress)")
          }
          
          Spacer()
          
          if #available(iOS 17.0, *) {
            Button {
              uploadTask?.pause()
            } label: {
              Text("PAUSE")
            }
            
            Button {
              uploadTask?.resume()
            } label: {
              Text("RESUMe")
            }
          }
        }
        
        Button {
          downloadTask = network.download(url: URL(string: "https://jsoncompare.org/LearningContainer/SampleFiles/Video/MP4/Sample-Video-File-For-Testing.mp4")!)?
            .downloadProgress { progress, fileSize in
              print("[Download - Progress]", progress.fractionCompleted, fileSize)
            }
            .response { response in
              print("[Download - Response]", response.result)
            }
          
        } label: {
          Text("Download")
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
    .padding(24)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}

extension String {
  static func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map { _ in letters.randomElement()! })
  }
}

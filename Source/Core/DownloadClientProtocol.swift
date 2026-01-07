//
//  DownloadClientProtocol.swift
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

import Foundation

/// Protocol for download operations. Separate from ApiClientProtocol for modularity.
public protocol DownloadClientProtocol: AnyObject {

  /// Downloads a file using the specified endpoint.
  func download(
    with endpoint: DownloadEndpoint,
    destination: DownloadTask.DownloadFileDestination?
  ) -> DownloadTask?

  /// Downloads a file from the specified URL.
  func download(url: URL) -> DownloadTask?

  /// Downloads a file asynchronously and returns the result.
  func download(
    with endpoint: DownloadEndpoint,
    destination: DownloadTask.DownloadFileDestination?
  ) async throws -> DownloadTask.DownloadResult
}

// MARK: - Default Parameter Extensions

public extension DownloadClientProtocol {

  func download(
    with endpoint: DownloadEndpoint,
    destination: DownloadTask.DownloadFileDestination? = nil
  ) -> DownloadTask? {
    download(with: endpoint, destination: destination)
  }

  func download(
    with endpoint: DownloadEndpoint,
    destination: DownloadTask.DownloadFileDestination? = nil
  ) async throws -> DownloadTask.DownloadResult {
    try await download(with: endpoint, destination: destination)
  }
}

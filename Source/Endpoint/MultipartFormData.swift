//
//  SmartNet.swift
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

// https://orjpap.github.io/swift/http/ios/urlsession/2021/04/26/Multipart-Form-Requests.html

import Foundation

public struct MultipartFormData {
    let boundary: String = UUID().uuidString
    private var httpBody = NSMutableData()
    
    public init() { }

    public func addTextField(
        named name: String,
        value: String
    ) {
        httpBody.append(textFormField(named: name, value: value))
    }
    
    private func textFormField(
        named name: String,
        value: String
    ) -> String {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "Content-Type: text/plain; charset=ISO-8859-1\r\n"
        fieldString += "Content-Transfer-Encoding: 8bit\r\n"
        fieldString += "\r\n"
        fieldString += "\(value)\r\n"

        return fieldString
    }
    
    public func addDataField(
        named name: String,
        data: Data,
        mimeType: String
    ) {
        httpBody.append(dataFormField(named: name, data: data, mimeType: mimeType))
    }
    
    private func dataFormField(
        named name: String,
        data: Data,
        mimeType: String
    ) -> Data {
            let fieldData = NSMutableData()
            
            fieldData.append("--\(boundary)\r\n")
            fieldData.append("Content-Disposition: form-data; name=\"\(name)\"\r\n")
            fieldData.append("Content-Type: \(mimeType)\r\n")
            fieldData.append("\r\n")
            fieldData.append(data)
            fieldData.append("\r\n")
            
            return fieldData as Data
        }
    
    var data: Data? {
        guard
            httpBody.count > 0
        else { return nil }
        let body = NSMutableData(data: httpBody as Data)
        body.append("--\(boundary)--")
        return  body as Data
    }
    
}

extension NSMutableData {
    func append(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.append(data)
    }
}

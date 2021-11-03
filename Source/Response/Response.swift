//
//  File.swift
//  
//
//  Created by Valerio Sebastianelli on 10/16/21.
//

import Foundation

public struct Response<Value> {
    public let result: Result<Value>
    var session: URLSession?
    var request: URLRequest?
    
    public init(result: Result<Value>) {
        self.result = result
        self.session = nil
        self.request = nil
    }
    
    init(result: Result<Value>, session: URLSession?, request: URLRequest?) {
        self.result = result
        self.session = session
        self.request = request
    }
    
    // Original source: https://github.com/Alamofire/Alamofire/blob/c039ac798b5acb91830dc64e8fe5de96970a4478/Source/Request.swift#L962
    public func printCurl() {
        guard
            let session = session,
            let request = self.request
        else { return }
        SmartNet.printCurl(session: session, request: request)
    }
}

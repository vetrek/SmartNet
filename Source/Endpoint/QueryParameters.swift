//
//  QueryParameters.swift
//  SmartNet
//
//  Created by Valerio Sebastianelli on 7/19/21.
//

import Foundation

public protocol SmartNetParameters {
    var parameters: [String: Any] { get }
}

public struct QueryParameters: SmartNetParameters {
    public let parameters: [String: Any]

    public init(parameters: [String: Any]) {
        self.parameters = parameters
    }

    public init(encodable: Encodable) throws {
        guard
            let parameters = try encodable.toDictionary()
        else { fatalError("Unable to convert this object \(encodable) to dictionary") }
        self.parameters = parameters
    }
}

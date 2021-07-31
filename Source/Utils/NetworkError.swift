//
//  NetworkError.swift
//  SmartNet
//
//  Created by Valerio Sebastianelli on 7/20/21.
//

import Foundation

public enum NetworkError: Error, CustomStringConvertible {
    case error(statusCode: Int, data: Data?)
    case parsingFailed
    case emptyResponse
    case cancelled
    case networkFailure
    case urlGeneration
    case dataToStringFailure(data: Data)
    case generic(Error)

    public var description: String {
        switch self {
        case .error(let statusCode, _):
            return "Error with status code: \(statusCode)"
        case .parsingFailed:
            return "Failed to parse the JSON response."
        case .emptyResponse:
            return "The request returned an empty response."
        case .cancelled:
            return "The network request has been cancelled"
        case .networkFailure:
            return "Unable to perform the request."
        case .urlGeneration:
            return "Unable to convert Requestable to URLRequest"
        case .dataToStringFailure:
            return "Unable to convert response data to string"
        case .generic(let error):
            return "Generic error \(error.localizedDescription)"
        }
    }
}

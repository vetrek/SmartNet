//
//  Dictionary+.swift
//  EasyNetworking
//
//  Created by Valerio Sebastianelli on 7/19/21.
//

import Foundation

extension Encodable {
    func toDictionary() throws -> [String: Any]? {
        let data = try JSONEncoder().encode(self)
        let josnData = try JSONSerialization.jsonObject(with: data)
        return josnData as? [String: Any]
    }
}

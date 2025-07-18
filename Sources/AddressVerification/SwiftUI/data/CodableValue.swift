//
//  CodableValue.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/07/2025.
//


import Foundation

struct CodableValue: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let dictVal = try? container.decode([String: CodableValue].self) {
            value = dictVal
        } else if let arrayVal = try? container.decode([CodableValue].self) {
            value = arrayVal
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let val = value as? Int {
            try container.encode(val)
        } else if let val = value as? Double {
            try container.encode(val)
        } else if let val = value as? Bool {
            try container.encode(val)
        } else if let val = value as? String {
            try container.encode(val)
        } else if let val = value as? [CodableValue] {
            try container.encode(val)
        } else if let val = value as? [String: CodableValue] {
            try container.encode(val)
        }
    }
}

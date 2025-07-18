//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/07/2025.
//

import Foundation

struct AddGeoTagRequest: Codable {
    let address: String
    let latitude: Double
    let longitude: Double
}

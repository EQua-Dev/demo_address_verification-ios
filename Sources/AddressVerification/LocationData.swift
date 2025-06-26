//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 26/06/2025.
//

import Foundation
// MARK: - Data Models
public struct LocationData: Codable {
    let country: String
    let reference: String
    let identity: String
    let verificationLevel: String
    let longitude: Double
    let latitude: Double
    let addressLineOne: String
    let addressLineTwo: String
    let city: String
    let region: String
    let countryCode: String
    let postalCode: String
    let zipCode: String
}

//
//  CachedGeoTag.swift
//  AddressVerification
//
//  Created by Richard Uzor on 28/07/2025.
//


struct CachedGeoTag: Codable {
    let address: String
    let latitude: Double
    let longitude: Double
    let deviceTimestamp: String
}

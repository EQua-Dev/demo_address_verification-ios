//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/07/2025.
//

import Foundation

struct CustomerAddressHistoryResponse: Codable {
    let data: [CustomerData]
    let message: String
    let status: Bool
    let statusCode: Int
}

struct CustomerData: Codable {
    let id: String
    let artifact: String
    let customer: String
    let metadata: Metadata
    let organization: String
    let reference: String
    let verification: String
    let verificationRequestPayload: String
    let verificationResponse: CodableValue
    let verificationStatus: String
    let verifiedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case artifact, customer, metadata, organization, reference, verification, verificationRequestPayload, verificationResponse, verificationStatus, verifiedAt
    }
}

struct Metadata: Codable {
    let addressLineOne: String
    let addressType: String
    let latitude: Double
    let locations: [GeoLocation]
    let longitude: Double
    let verificationEndDate: String
}

struct GeoLocation: Codable {
    let address: String
    let latitude: Double
    let longitude: Double
    let timestamp: String
}

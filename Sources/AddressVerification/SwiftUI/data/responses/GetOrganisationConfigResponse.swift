
//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/07/2025.
//

import Foundation

struct GetOrganisationConfigResponse: Codable {
    let data: OrganisationConfigData
    let message: String
    let status: Bool
    let statusCode: Int
}

struct OrganisationConfigData: Codable {
    let distanceTolerance: Double
    let geotaggingPollingInterval: Double
    let geotaggingSessionTimeout: Int
}

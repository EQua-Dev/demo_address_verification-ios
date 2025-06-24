//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 24/06/2025.
//

import Foundation

public struct AddressVerificationConfig: Codable {
    public let initialAddressText: String?
    public let locationFetchIntervalHours: TimeInterval
    public let locationFetchDurationHours: TimeInterval
    public let verifyLocation: Bool
    
    public init(
        initialAddressText: String? = nil,
        locationFetchIntervalHours: TimeInterval = 1,
        locationFetchDurationHours: TimeInterval = 2,
        verifyLocation: Bool = false
    ) {
        self.initialAddressText = initialAddressText
        self.locationFetchIntervalHours = locationFetchIntervalHours
        self.locationFetchDurationHours = locationFetchDurationHours
        self.verifyLocation = verifyLocation
    }
}

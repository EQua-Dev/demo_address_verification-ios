//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 26/06/2025.
//

// AddressVerificationBridge.swift
import Foundation
#if canImport(React)
import React

@objc(AddressVerificationManager)
class AddressVerificationManager: NSObject {
    private var verificationField: AddressVerificationField?
    
    @objc static func requiresMainQueueSetup() -> Bool { return true }
    
    @objc func fetchConfiguration(
        apiKey: String,
        customerID: String,
        resolve: RCTPromiseResolveBlock,
        reject: RCTPromiseRejectBlock
    ) {
        Task {
            do {
                let (pollingInterval, sessionTimeout) = try await fetchRemoteConfiguration(
                    apiKey: apiKey,
                    customerID: customerID
                )
                resolve(["pollingInterval": pollingInterval, "sessionTimeout": sessionTimeout])
            } catch {
                reject("CONFIG_ERROR", "Failed to fetch config", error)
            }
        }
    }
    
    private func fetchRemoteConfiguration(
        apiKey: String,
        customerID: String
    ) async throws -> (TimeInterval, TimeInterval) {
        // Reuse your existing fetch logic
        let config = try await AddressVerificationField.fetchConfigFromServer(
            apiKey: apiKey,
            customerID: customerID
        )
        return (config.pollingInterval, config.sessionTimeout)
    }
}
#endif

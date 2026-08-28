//
//  AddressVerificationSDK.swift
//  AddressVerification
//
//  Updated with ResolvedAddress return type
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public class AddressVerification {
    public static let shared = AddressVerification()
    private init() {}
    
    // MARK: - Pick Location (Enhanced with ResolvedAddress)
    /// Opens a map interface for the user to manually pick a location
    /// - Parameters:
    ///   - viewController: The view controller to present from (optional)
    ///   - onPicked: Callback with complete ResolvedAddress object
#if os(iOS)
    public func pickLocation(
        from viewController: UIViewController? = nil,
        onPicked: @escaping (ResolvedAddress) -> Void
    ) {
        let vc = viewController ?? Self.getRootViewController()
        
        guard let presentingVC = vc else {
            print("AddressVerification: No view controller available")
            return
        }
        
        AddressVerificationInternal.shared.pickLocationCallback = onPicked
        
        let picker = LocationPickerViewController()
        picker.modalPresentationStyle = .fullScreen
        presentingVC.present(picker, animated: true)
    }
    
    private static func getRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
#endif

    // MARK: - Start Location Tracking (Existing Feature)
    public func startTrackingWithRemoteConfig(
        apiKey: String,
        customerID: String,
        verificationGroupId: String,
        onLocationPost: @escaping (Double, Double) -> Void
    ) {
        Task {
            do {
                let (interval, timeout) = try await fetchConfigFromServer(
                    apiKey: apiKey,
                    customerID: customerID
                )
                
                await LocationTrackingService.shared.startTracking(
                    apiKey: apiKey,
                    customerID: customerID,
                    verificationGroupId: verificationGroupId,
                    token: "",
                    refreshToken: ""
                )
            } catch {
                print("Failed to start tracking: \(error.localizedDescription)")
            }
        }
    }
    
    public func stopLocationTracking() {
        Task {
            await LocationTrackingService.shared.stopTracking()
        }
    }
    
    // MARK: - Config Fetching
    private func fetchConfigFromServer(
        apiKey: String,
        customerID: String
    ) async throws -> (pollingInterval: TimeInterval, sessionTimeout: TimeInterval) {
        guard let url = SidEnvironment.addressVerificationConfigURL(apiKey: apiKey) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let responseData = json?["data"] as? [String: Any]
        
        return (
            responseData?["geotaggingPollingInterval"] as? TimeInterval ?? 10,
            responseData?["geotaggingSessionTimeout"] as? TimeInterval ?? 30
        )
    }
}

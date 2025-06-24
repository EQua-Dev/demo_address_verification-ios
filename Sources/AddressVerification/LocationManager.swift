//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 24/06/2025.
//

import CoreLocation
import Foundation

@available(macOS 10.15, iOS 13.0, *)
@MainActor
class LocationManager: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
#if os(macOS)
guard authorizationStatus == .authorized else {
    continuation.resume(throwing: LocationError.permissionDenied)
    return
}
#else
guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
    continuation.resume(throwing: LocationError.permissionDenied)
    return
}
#endif

            
            locationManager.requestLocation()
            
            // Set up a timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                continuation.resume(throwing: LocationError.timeout)
            }
            
            // Store continuation for later use
            self.locationContinuation = continuation
        }
    }
    
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
        }
        
        // Resume continuation if waiting
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
        
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(throwing: error)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
    }
}

enum LocationError: Error {
    case permissionDenied
    case timeout
    case unavailable
    
    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Location permission denied"
        case .timeout:
            return "Location request timed out"
        case .unavailable:
            return "Location services unavailable"
        }
    }
}

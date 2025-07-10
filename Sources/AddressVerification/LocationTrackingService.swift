//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 24/06/2025.
//

import Foundation
import CoreLocation
import BackgroundTasks

@available(macOS 11.0, iOS 13.0, *)
@MainActor
public final class LocationTrackingService: NSObject, ObservableObject {
    public static let shared = LocationTrackingService()
    
    private let locationManager = CLLocationManager()
    private var trackingTimer: Timer?
    private var sessionTimer: Timer?
    private var onLocationPost: (@MainActor (Double, Double) -> Void) = { _, _ in }
    private var customerID: String = ""
    private var token: String = ""
    private var apiKey: String = ""
    
    // Store pending tracking parameters
    private var pendingInterval: TimeInterval?
    private var pendingDuration: TimeInterval?
    private var pendingCustomerID: String?
    private var pendingOnLocationPost: (@MainActor (Double, Double) -> Void)?
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func startLocationTracking(
        interval: TimeInterval,
        duration: TimeInterval,
        customerID: String,
        token: String,
        apiKey: String,
        onLocationPost: @escaping @MainActor (Double, Double) -> Void
    ) async {
        self.token = token
        self.customerID = customerID
        self.onLocationPost = onLocationPost
        
        print("Starting location tracking - Interval: \(interval), Duration: \(duration), CustomerID: \(customerID), apiKey: \(apiKey), token: \(token)")
        
        // Store parameters in case we need to retry after authorization
        self.pendingInterval = interval
        self.pendingDuration = duration
        self.pendingCustomerID = customerID
        self.pendingOnLocationPost = onLocationPost
        
        // Request location permission if needed
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization()
            return
        }
        
        // Clear pending parameters since we're proceeding
        clearPendingParameters()
        
        await startTrackingWithCurrentAuthorization(interval: interval, duration: duration, apiKey: apiKey)
    }
    
    private func clearPendingParameters() {
        pendingInterval = nil
        pendingDuration = nil
        pendingCustomerID = nil
        pendingOnLocationPost = nil
    }
    
    private func startTrackingWithCurrentAuthorization(interval: TimeInterval, duration: TimeInterval, apiKey: String) async {
#if os(macOS)
        guard locationManager.authorizationStatus == .authorized else {
            print("Location permission not granted (macOS)")
            return
        }
#else
        guard locationManager.authorizationStatus == .authorizedAlways ||
              locationManager.authorizationStatus == .authorizedWhenInUse else {
            print("Location permission not granted (iOS/watchOS/tvOS)")
            return
        }
#endif
        
        // Start location updates
        locationManager.startUpdatingLocation()
        
        // Set up timers on main queue
        setupTimers(interval: interval, duration: duration, apiKey: apiKey)
        
        // Post initial location
        await postCurrentLocation(apiKey: apiKey)
    }
    
    @MainActor
    func stopLocationTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        locationManager.stopUpdatingLocation()
        
        // Reset to empty closure
        onLocationPost = { _, _ in }
        
        // Clear pending parameters
        clearPendingParameters()
    }
    
    @MainActor
    private func setupTimers(interval: TimeInterval, duration: TimeInterval, apiKey: String) {
        // Invalidate existing timers
        trackingTimer?.invalidate()
        sessionTimer?.invalidate()
        
        // Set up periodic location posting
        trackingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.postCurrentLocation(apiKey: apiKey)
            }
        }
        
        // Set up session timeout
        sessionTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopLocationTracking()
            }
        }
    }
    
    @MainActor
    private func reverseGeocode(latitude: Double, longitude: Double) async -> CLPlacemark? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first
        } catch {
            print("Reverse geocoding failed with error: \(error)")
            return nil
        }
    }
    
    @MainActor
    private func postCurrentLocation(apiKey: String) async {
        guard let location = locationManager.location else {
            print("No location available - this is common in iOS Simulator")
                      print("Location services enabled: \(CLLocationManager.locationServicesEnabled())")
                      print("Authorization status: \(locationManager.authorizationStatus.rawValue)")
                      
                      // For simulator testing, you can uncomment the lines below to use mock coordinates
                      // let mockLatitude = 37.7749  // San Francisco
                      // let mockLongitude = -122.4194
                      // print("Using mock location for simulator: \(mockLatitude), \(mockLongitude)")
                      // onLocationPost(mockLatitude, mockLongitude)
                      // a
            return
        }
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        print("Posting location: \(latitude), \(longitude)")
        
        // Call the callback
        onLocationPost(latitude, longitude)
        
        await sendLocationToServer(latitude: latitude, longitude: longitude, apiKey: apiKey)
    }
    
    @MainActor
    private func sendLocationToServer(latitude: Double, longitude: Double, apiKey: String) async {
        print("fetched location \(latitude) \(longitude)")
        do {
            // Perform reverse geocoding
            guard let placemark = await reverseGeocode(latitude: latitude, longitude: longitude) else {
                throw NSError(domain: "GeocodingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to geocode location"])
            }
            
            // Extract address components from placemark
            let country = placemark.country ?? "Unknown"
            let addressLineOne = [placemark.subThoroughfare, placemark.thoroughfare]
                .compactMap { $0 }
                .joined(separator: " ")
            let addressLineTwo = placemark.subLocality ?? ""
            let city = placemark.locality ?? "Unknown"
            let region = placemark.administrativeArea ?? "Unknown"
            let countryCode = placemark.isoCountryCode ?? "NG"
            let postalCode = placemark.postalCode ?? "00000"
            
            let locationData = LocationData(
//                country: country,
//                reference: UUID().uuidString,
                identity: customerID,
//                addressType: addressType,
//                verificationLevel: "basic",
                longitude: longitude,
                latitude: latitude,
                address: "\(addressLineOne) \(addressLineTwo)"
//                addressLineTwo: addressLineTwo,
//                city: city,
//                region: region,
//                countryCode: countryCode,
//                postalCode: postalCode
//                zipCode: postalCode // Using postalCode for zipCode as well
            )
            
            guard let url = URL(string: "https://api.rd.usesourceid.com/v1/api/customer/update-location") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(token, forHTTPHeaderField: "x-auth-token")
            
            let jsonData = try JSONEncoder().encode(locationData)
            request.httpBody = jsonData
            
            print(jsonData)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("API Response Code: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("API Response: \(responseString)")
                }
            }
            
            print("Location sent: \(latitude), \(longitude)")
            
            // Show toast-like notification on main thread
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LocationSent"),
                    object: nil,
                    userInfo: [
                        "message": "Sending Location from SourceID SDK: \(latitude), \(longitude)"
                    ]
                )
            }
            
        } catch {
            print("Error sending location to server: \(error)")
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationTrackingService: CLLocationManagerDelegate {
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // No need for action here since we're manually posting locations
        Task { @MainActor in
            print("Location updated: \(locations.last?.coordinate.latitude ?? 0), \(locations.last?.coordinate.longitude ?? 0)")
        }
    }
    
    
    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                print("Location is currently unknown, but CLLocationManager will keep trying")
            case .denied:
                print("Location services are disabled or denied for this app")
            case .network:
                print("Network error - location service was unable to determine location")
            case .headingFailure:
                print("Heading could not be determined")
            case .regionMonitoringDenied:
                print("Region monitoring denied")
            case .regionMonitoringFailure:
                print("Region monitoring failed")
            case .regionMonitoringSetupDelayed:
                print("Region monitoring setup delayed")
            case .regionMonitoringResponseDelayed:
                print("Region monitoring response delayed")
            case .geocodeFoundNoResult:
                print("Geocode found no result")
            case .geocodeFoundPartialResult:
                print("Geocode found partial result")
            case .geocodeCanceled:
                print("Geocode was canceled")
            case .deferredFailed:
                print("Deferred mode failed")
            case .deferredNotUpdatingLocation:
                print("Deferred mode not updating location")
            case .deferredAccuracyTooLow:
                print("Deferred mode accuracy too low")
            case .deferredDistanceFiltered:
                print("Deferred mode distance filtered")
            case .deferredCanceled:
                print("Deferred mode canceled")
            case .rangingUnavailable:
                print("Ranging unavailable")
            case .rangingFailure:
                print("Ranging failure")
            @unknown default:
                print("Unknown location error: \(clError.localizedDescription)")
            }
        }
    }
    
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus.rawValue
        Task { @MainActor in
            print("Authorization changed: \(status)")
            let service = LocationTrackingService.shared
            
            // Check if we have pending tracking to resume
            if let interval = service.pendingInterval,
               let duration = service.pendingDuration,
               let customerID = service.pendingCustomerID,
               let onLocationPost = service.pendingOnLocationPost {
                
                print("Resuming location tracking after authorization change")
                
                // Update the service properties
                service.customerID = customerID
                service.onLocationPost = onLocationPost
                
                // Clear pending parameters
                service.clearPendingParameters()
                
                // Start tracking with the new authorization
                await service.startTrackingWithCurrentAuthorization(interval: interval, duration: duration, apiKey: service.apiKey)
            }
        }
    }
}

//MARK: - Single-use location fetch with timeout
extension LocationTrackingService {
    public static func fetchCurrentLocation(
        timeout: TimeInterval = 10.0,
        customerID: String,
        apiKey: String,
        token: String
    ) async throws -> (latitude: Double, longitude: Double) {
        let service = LocationTrackingService()
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await service.startLocationTracking(
                    interval: timeout + 1, // Ensure only one update
                    duration: timeout,
                    customerID: customerID,
                    token: token,
                    apiKey: apiKey,
                    onLocationPost: { lat, long in
                        continuation.resume(returning: (lat, long))
                        service.stopLocationTracking()
                    }
                )
            }
        }
    }
}

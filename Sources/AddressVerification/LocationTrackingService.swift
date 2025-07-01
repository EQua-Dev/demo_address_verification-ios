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
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func startLocationTracking(
        interval: TimeInterval,
        duration: TimeInterval,
        customerID: String,
        onLocationPost: @escaping @MainActor (Double, Double) -> Void
    ) async {
        self.customerID = customerID
        self.onLocationPost = onLocationPost
        
        print("Starting location tracking - Interval: \(interval), Duration: \(duration), CustomerID: \(customerID)")
        
        // Request location permission if needed
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization()
            return
        }
        
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
              setupTimers(interval: interval, duration: duration)
              
       
        // Post initial location
        await postCurrentLocation()
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
      }
    
    
     @MainActor
     private func setupTimers(interval: TimeInterval, duration: TimeInterval) {
         // Invalidate existing timers
         trackingTimer?.invalidate()
         sessionTimer?.invalidate()
         
         // Set up periodic location posting
         trackingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
             Task { [weak self] in
                 await self?.postCurrentLocation()
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
     private func postCurrentLocation() async {
         guard let location = locationManager.location else {
             return
         }
         

         let latitude = location.coordinate.latitude
         let longitude = location.coordinate.longitude
         
         // Call the callback
         onLocationPost(latitude, longitude)
         
         
         await sendLocationToServer(latitude: latitude, longitude: longitude)
     }
    @MainActor
    private func sendLocationToServer(latitude: Double, longitude: Double) async {
        print("fetched location \(latitude) \(latitude)")
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
            let countryCode = placemark.isoCountryCode ?? "US"
            let postalCode = placemark.postalCode ?? "00000"
            
            let locationData = LocationData(
                country: country,
                reference: UUID().uuidString,
                identity: customerID,
                verificationLevel: "basic",
                longitude: longitude,
                latitude: latitude,
                addressLineOne: addressLineOne,
                addressLineTwo: addressLineTwo,
                city: city,
                region: region,
                countryCode: countryCode,
                postalCode: postalCode,
                zipCode: postalCode // Using postalCode for zipCode as well
            )
            
            guard let url = URL(string: "https://api.rd.usesourceid.com/v1/api/verification/verify-address") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("sk_rd_v1_ChoPcUQjtI9pMTivjYJ9hKXop0WeXO", forHTTPHeaderField: "x-api-key")
            
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
    }
    
    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }
    
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Capture only the needed values (authorization status) which are Sendable
        let status = manager.authorizationStatus.rawValue
        Task { @MainActor in
            print("Authorization changed: \(status)")
            // If you need to do something with the manager, access it freshly here:
            let currentManager = LocationTrackingService.shared.locationManager
            // ... use currentManager if needed
        }
    }
}

//MARK: - Single-use location fetch with timeout
extension LocationTrackingService {
    public static func fetchCurrentLocation(
        timeout: TimeInterval = 10.0,
        customerID: String
    ) async throws -> (latitude: Double, longitude: Double) {
        let service = LocationTrackingService()
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await service.startLocationTracking(
                    interval: timeout + 1, // Ensure only one update
                    duration: timeout,
                    customerID: customerID,
                    onLocationPost: { lat, long in
                        continuation.resume(returning: (lat, long))
                        service.stopLocationTracking()
                    }
                )
            }
        }
    }
}


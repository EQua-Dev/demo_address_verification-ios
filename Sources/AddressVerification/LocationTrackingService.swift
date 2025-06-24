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
class LocationTrackingService: NSObject, ObservableObject {
    static let shared = LocationTrackingService()
    
    private let locationManager = CLLocationManager()
    private var trackingTimer: Timer?
    private var sessionTimer: Timer?
    private var onLocationPost: (@MainActor (Double, Double) -> Void) = { _, _ in }
    private var customerID: String = ""
    
    private override init() {
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
        do {
            let locationData = LocationData(
                country: "United States",
                reference: UUID().uuidString,
                identity: customerID,
                verificationLevel: "basic",
                longitude: longitude,
                latitude: latitude,
                addressLineOne: "123 Main Street",
                addressLineTwo: "Apt 4B",
                city: "New York",
                region: "New York",
                countryCode: "US",
                postalCode: "10001",
                zipCode: "10001"
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
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // No need for action here since we're manually posting locations
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
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

// MARK: - Data Models
private struct LocationData: Codable {
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

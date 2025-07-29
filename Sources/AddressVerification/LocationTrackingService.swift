//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 24/06/2025.
//

import Foundation
import CoreLocation
import BackgroundTasks
import Combine

@available(macOS 11.0, iOS 13.0, *)
@MainActor


class LocationTrackingService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTrackingService()

    private var locationManager: CLLocationManager!
    private var cancellables = Set<AnyCancellable>()
    
    private let apiHelper = ApiHelper()
    private var apiKey = ""
    private var token = ""
    private var refreshToken = ""
    
    private var customerID: String = ""
    private var isGeotaggingActive = false


    override init() {
        super.init()
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start(apiKey: String, token: String, customerID: String, refreshToken: String) {
        self.apiKey = apiKey
        self.token = token
        self.customerID = customerID
        self.refreshToken = refreshToken
        
        StoredCredentials.save(apiKey: apiKey, token: token, customerID: customerID, refreshToken: refreshToken)

//
//        locationManager.allowsBackgroundLocationUpdates = true
//          locationManager.pausesLocationUpdatesAutomatically = false
//          locationManager.startMonitoringSignificantLocationChanges()

        // Request location permissions first
        requestLocationPermissions()

        Task {
            await self.runScheduledGeoTagging()
        }
        scheduleBackgroundGeotagTask()

    }
    
    private func requestLocationPermissions() {
           switch locationManager.authorizationStatus {
           case .notDetermined:
               locationManager.requestAlwaysAuthorization()
           case .authorizedAlways:
               configureLocationManager()
           case .authorizedWhenInUse:
               locationManager.requestAlwaysAuthorization()
           case .denied, .restricted:
               print("❌ Location permission denied. Background location tracking unavailable.")
           @unknown default:
               print("⚠️ Unknown location authorization status")
           }
       }
    
    
    private func configureLocationManager() {
        guard locationManager.authorizationStatus == .authorizedAlways else {
            print("❌ Always location permission required for background tracking")
            return
        }
        
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Schedule the first background task
        scheduleBackgroundGeotagTask()
    }


    private func runScheduledGeoTagging() async {
        
        guard !isGeotaggingActive else {
                  print("⚠️ Geotagging session already active")
                  return
              }
              
              isGeotaggingActive = true
              defer { isGeotaggingActive = false }
              
        // Step 1: Fetch org config
        let orgConfig = await fetchOrgConfig()
        guard let config = orgConfig else {
            print("Failed to fetch org config")
            return
        }

        // Step 2: Fetch pending verification
        let pendingAddress = await fetchPendingAddress()
        guard let address = pendingAddress else {
            print("No pending verification")
            return
        }

        // Step 3: Extract timestamps and schedule
        let lastTimestamp = address.metadata.locations
            .compactMap { ISO8601DateFormatter().date(from: $0.timestamp) }
            .max() ?? Date()

        let intervalSeconds = config.geotaggingPollingInterval * 3600
        let sessionDurationSeconds = Double(config.geotaggingSessionTimeout) * 86400

        var current = lastTimestamp.timeIntervalSince1970
        let end = current + sessionDurationSeconds
        let now = Date().timeIntervalSince1970

        var timestamps: [TimeInterval] = []
        while current <= end {
            if current > now { timestamps.append(current) }
            current += intervalSeconds
        }

        print("🔄 Scheduled \(timestamps.count) timestamps")

//        for timestamp in timestamps {
//            let delay = timestamp - Date().timeIntervalSince1970
//            if delay > 0 {
//                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
//            }
        
        
        // Limit the number of iterations in background mode
        let maxIterations = min(timestamps.count, 10) // Prevent excessive background processing
        
        for i in 0..<maxIterations {
            let timestamp = timestamps[i]
            let delay = timestamp - Date().timeIntervalSince1970
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            await postCurrentLocation()
            
            
                       // Check if we should continue (for background task management)
                       if !isGeotaggingActive {
                           print("🛑 Geotagging session stopped externally")
                           break
                       }
        }

        print("✅ Finished geotagging session")
    }

    private func fetchOrgConfig() async -> OrganisationConfigData? {
        
        await withCheckedContinuation { continuation in
            print("api key: \(apiKey)")
            apiHelper.fetchOrganisationConfig(apiKey: apiKey)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Org config fetch error: \(error)")
                        continuation.resume(returning: nil)
                    }
                }, receiveValue: { response in
                    continuation.resume(returning: response.data)
                })
                .store(in: &cancellables)
        }
    }

    private func fetchPendingAddress() async -> CustomerData? {
        await withCheckedContinuation { continuation in
            apiHelper.fetchCustomerHistory(apiKey: apiKey, token: token)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Customer history fetch error: \(error)")
                        continuation.resume(returning: nil)
                    }
                }, receiveValue: { response in
                    let pending = response.data.first { $0.verificationStatus == "pending" }
                    continuation.resume(returning: pending)
                })
                .store(in: &cancellables)
        }
    }

    private func postCurrentLocation() async {
        guard CLLocationManager.locationServicesEnabled() else {
            print("Location services disabled")
            return
        }

        // Request one-time location if needed
           if locationManager.location == nil {
               locationManager.requestLocation()
               // Wait a bit for location to be available
               try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
           }

        guard let location = locationManager.location else {
            print("No current location available")
            return
        }

        let geocoder = CLGeocoder()
        let coordinate = location.coordinate

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let address = placemarks.first?.name ?? "Unknown address"
            let timestamp = ISO8601DateFormatter().string(from: Date())


            let request = AddGeoTagRequest(
                address: address,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                deviceTimestamp: timestamp
            )
            
            
            if isConnectedToInternet() {
                await sendCachedGeoTags()
                do {
                    try await sendGeoTag(geoTag: request, token: token)
                } catch {
                    print("Error sending current geotag: \(error)")
                    let cached = CachedGeoTag(
                        address: address,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        deviceTimestamp: timestamp
                    )
                    GeoTagCache.save(cached)
                }
            } else {
                print("📥 No internet. Caching geotag.")
                let cached = CachedGeoTag(
                    address: address,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    deviceTimestamp: timestamp
                )
                GeoTagCache.save(cached)
            }


        } catch {
            print("Reverse geocode failed: \(error)")
        }
    }
    
    private func sendCachedGeoTags() async {
        let cachedTags = GeoTagCache.load()
        guard !cachedTags.isEmpty else { return }

        var allSent = true

        for tag in cachedTags {
            let request = AddGeoTagRequest(
                address: tag.address,
                latitude: tag.latitude,
                longitude: tag.longitude,
                deviceTimestamp: tag.deviceTimestamp
            )

            let result = await withCheckedContinuation { continuation in
                apiHelper.addGeoTag(apiKey: apiKey, token: token, request: request)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ Failed cached geotag: \(error)")
                            continuation.resume(returning: false)
                        }
                    }, receiveValue: { _ in
                        print("✅ Cached geotag sent")
                        continuation.resume(returning: true)
                    })
                    .store(in: &cancellables)
            }

            if !result {
                allSent = false
                break
            }
        }

        if allSent {
            GeoTagCache.clear()
            print("🧹 Cleared cached geotags")
        }
    }
    
    private func sendGeoTag(geoTag: AddGeoTagRequest, token: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            apiHelper.addGeoTag(apiKey: apiKey, token: token, request: geoTag)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                }, receiveValue: { response in
                    print("📍 GeoTag posted: \(response)")
                    continuation.resume(returning: true)
                })
                .store(in: &cancellables)
        }
    }




    func stop() {
        isGeotaggingActive = false

        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()

        cancellables.removeAll()
        print("🛑 Geotagging stopped")
    }
    
    func scheduleBackgroundGeotagTask() {
        #if os(iOS)
        // Cancel any existing tasks first
              BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "tech.sourceid.addressverification.geotag")
            
        let request = BGProcessingTaskRequest(identifier: "tech.sourceid.addressverification.geotag")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        // Set earliest begin date to avoid immediate scheduling
            request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60) // 15 minutes from now

        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📆 Background geotag task scheduled for: \(request.earliestBeginDate?.description ?? "unknown")")

        } catch {
            print("❌ Failed to schedule background task: \(error)")
                  handleBackgroundTaskSchedulingError(error)
        }
        #else
        print("⚠️ Background task scheduling is only supported on iOS.")
        #endif
    }

#if os(iOS)
    private func handleBackgroundTaskSchedulingError(_ error: Error) {
            if let bgError = error as? BGTaskScheduler.Error {
                switch bgError.code {
                case .unavailable:
                    print("❌ Background tasks unavailable (simulator or device restrictions)")
                case .tooManyPendingTaskRequests:
                    print("❌ Too many pending background tasks")
                case .notPermitted:
                    print("❌ Background tasks not permitted for this app")
                @unknown default:
                    print("❌ Unknown background task error: \(bgError)")
                }
            }
        }
#endif
    
#if os(iOS)
func handleBackgroundGeotagTask(task: BGProcessingTask) {
    print("📦 Background geotag task started")
    
    var taskWasCancelled = false

    task.expirationHandler = {
        print("⏳ Geotag task expired before completion.")
        taskWasCancelled = true
        self.isGeotaggingActive = false

    }

    guard let creds = StoredCredentials.load() else {
        print("❌ Missing stored credentials")
        task.setTaskCompleted(success: false)
        return
    }

    self.apiKey = creds.apiKey
    self.token = creds.token
    self.customerID = creds.customerID
    self.refreshToken = creds.refreshToken


    Task {
        await self.runScheduledGeoTagging()

        if taskWasCancelled {
            print("🛑 Task was cancelled before finishing.")
            task.setTaskCompleted(success: false)
            return
        }

        task.setTaskCompleted(success: true)
        self.scheduleBackgroundGeotagTask() // Schedule next session
    }
}
#endif

    // MARK: - CLLocationManagerDelegate
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            // Handle location updates if needed
            print("📍 Location updated: \(locations.last?.coordinate.longitude.description ?? "unknown")")
        }
        
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("❌ Location manager error: \(error)")
        }
        
        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            print("🔐 Location authorization changed: \(status.rawValue)")
            
            switch status {
            case .authorizedAlways:
                configureLocationManager()
            case .authorizedWhenInUse:
                manager.requestAlwaysAuthorization()
            case .denied, .restricted:
                print("❌ Location access denied. Background tracking unavailable.")
                stop()
            case .notDetermined:
                manager.requestAlwaysAuthorization()
            @unknown default:
                print("⚠️ Unknown authorization status")
            }
        }

}

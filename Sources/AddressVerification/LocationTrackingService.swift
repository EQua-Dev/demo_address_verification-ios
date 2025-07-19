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
    
    private var customerID: String = ""

    override init() {
        super.init()
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start(apiKey: String, token: String, customerID: String) {
        self.apiKey = apiKey
        self.token = token
        self.customerID = customerID
        
        StoredCredentials.save(apiKey: apiKey, token: token, customerID: customerID)


        locationManager.allowsBackgroundLocationUpdates = true
          locationManager.pausesLocationUpdatesAutomatically = false
          locationManager.startMonitoringSignificantLocationChanges()

        Task {
            await self.runScheduledGeoTagging()
        }
        scheduleBackgroundGeotagTask()

    }

    private func runScheduledGeoTagging() async {
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

        for timestamp in timestamps {
            let delay = timestamp - Date().timeIntervalSince1970
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            await postCurrentLocation()
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

        guard let location = locationManager.location else {
            print("No current location available")
            return
        }

        let geocoder = CLGeocoder()
        let coordinate = location.coordinate

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let address = placemarks.first?.name ?? "Unknown address"

            let request = AddGeoTagRequest(
                address: address,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            await withCheckedContinuation { continuation in
                apiHelper.addGeoTag(apiKey: apiKey, token: token, request: request)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("Failed to post geotag: \(error)")
                        }
                        continuation.resume()
                    }, receiveValue: { response in
                        print("📍 GeoTag posted: \(response)")
                        continuation.resume()
                    })
                    .store(in: &cancellables)
            }

        } catch {
            print("Reverse geocode failed: \(error)")
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        cancellables.removeAll()
        print("🛑 Geotagging stopped")
    }
    
    func scheduleBackgroundGeotagTask() {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: "tech.sourceid.addressverification.geotag")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("📆 Background geotag task scheduled")
        } catch {
            print("❌ Failed to schedule background task: \(error)")
        }
        #else
        print("⚠️ Background task scheduling is only supported on iOS.")
        #endif
    }

#if os(iOS)
func handleBackgroundGeotagTask(task: BGProcessingTask) {
    print("📦 Background geotag task started")

    task.expirationHandler = {
        print("⏳ Geotag task expired before completion.")
    }

    guard let creds = StoredCredentials.load() else {
        print("❌ Missing stored credentials")
        task.setTaskCompleted(success: false)
        return
    }

    self.apiKey = creds.apiKey
    self.token = creds.token
    self.customerID = creds.customerID

    Task {
        await self.runScheduledGeoTagging()

        if task.isCancelled {
            print("🛑 Task was cancelled before finishing.")
            task.setTaskCompleted(success: false)
            return
        }

        task.setTaskCompleted(success: true)
        self.scheduleBackgroundGeotagTask() // Schedule next session
    }
}
#endif



}

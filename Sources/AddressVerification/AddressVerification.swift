// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import MapKit
import CoreLocation
import BackgroundTasks

@available(macOS 11.0, iOS 14.0, *)
public struct AddressVerificationField: View {
    // State properties
    @State private var query: String
    @State private var suggestions: [MKLocalSearchCompletion] = []
    @State private var selectedAddress: (String, CLLocationCoordinate2D)?
    @State private var pollingInterval: TimeInterval?
    @State private var sessionTimeout: TimeInterval?
    @State private var isLoading = true
    
    // Configuration properties
    private let apiKey: String
    private let showButton: Bool
    private let verifyLocation: Bool
    private let customerID: String
    private let token: String
    private let refreshToken: String
    private let addressType: String
    private let onAddressSelected: (String, Double, Double) -> Void
    private let onLocationPost: (Double, Double) -> Void
    
    // Manager objects
    @StateObject private var searchCompleter = SearchCompleter()
    @StateObject private var locationManager = LocationManager()
    
    public init(
        apiKey: String,
        showButton: Bool,
        initialText: String = "",
        verifyLocation: Bool = false,
        customerID: String,
        token: String,
        refreshToken: String,
        addressType: String,
        onAddressSelected: @escaping (String, Double, Double) -> Void,
        onLocationPost: @escaping (Double, Double) -> Void
    ) {
        self.apiKey = apiKey
        self.showButton = showButton
        self._query = State(initialValue: initialText)
        self.verifyLocation = verifyLocation
        self.customerID = customerID
        self.token = token
        self.refreshToken = refreshToken
        self.addressType = addressType
        self.onAddressSelected = onAddressSelected
        self.onLocationPost = onLocationPost
    }
    
    public var body: some View {
        
            Group {
                if isLoading {
                    loadingView
                } else {
                    mainContentView
                }
            }   .onAppear {
                // Use Task for iOS 14 compatibility
                Task {
                    await fetchConfiguration()
                }
            }
        
    }
    
    // MARK: - Subviews
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading configuration...")
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            addressInputField
            suggestionsList
            if showButton { submitButton }
        }
        .onReceive(searchCompleter.$results) { completions in
            self.suggestions = Array(completions.prefix(5))
        }
    }
    
    private var addressInputField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Enter your address", text: $query)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: query) { newValue in
                    if !newValue.isEmpty {
                        searchCompleter.updateSearch(query: newValue)
                    } else {
                        suggestions = []
                    }
                }
        }
    }
    
    private var suggestionsList: some View {
        Group {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                        suggestionButton(for: suggestion, isLast: index == suggestions.count - 1)
                    }
                }
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            }
        }
    }
    
    private func suggestionButton(for suggestion: MKLocalSearchCompletion, isLast: Bool) -> some View {
        Button(action: {
            selectAddress(suggestion)
        }) {
            HStack {
                Text(suggestion.title + ", " + suggestion.subtitle)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .overlay(isLast ? nil : Divider(), alignment: .bottom)
    }
    
    private var submitButton: some View {
        HStack {
            Spacer()
            Button("Submit Address") {
                submitAddress()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(selectedAddress == nil)
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Methods
    private func selectAddress(_ completion: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let response = response,
                  let mapItem = response.mapItems.first else {
                return
            }
            
            let coordinate = mapItem.placemark.coordinate
            let address = "\(completion.title), \(completion.subtitle)"
            
            DispatchQueue.main.async {
                self.selectedAddress = (address, coordinate)
                self.query = address
                self.suggestions = []
                self.onAddressSelected(address, coordinate.latitude, coordinate.longitude)
            }
        }
    }
    
    private func submitAddress() {
        guard let (address, coordinate) = selectedAddress else { return }
        
        onAddressSelected(address, coordinate.latitude, coordinate.longitude)
        
        if verifyLocation {
            Task {
                LocationTrackingService.shared.start(
                    apiKey: customerID,
                    token: token,
                    customerID: apiKey,
                    refreshToken: refreshToken
                   
                )
            }
        }
    }
}
// MARK: - Setup and Configuration
extension AddressVerificationField {
    private func fetchConfiguration() async {
        do {
            guard let url = URL(string: "https://api.rd.usesourceid.com/v1/api/organization/address-verification-config") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("*/*", forHTTPHeaderField: "accept")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let responseData = json?["data"] as? [String: Any]
                
                await MainActor.run {
                    self.pollingInterval = responseData?["geotaggingPollingInterval"] as? TimeInterval
                    self.sessionTimeout = responseData?["geotaggingSessionTimeout"] as? TimeInterval
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("Error fetching configuration: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - View Lifecycle
extension AddressVerificationField {
    
//    private func setupSearchCompleter() {
//        searchCompleter.delegate = SearchCompleter { completions in
//            DispatchQueue.main.async {
//                self.suggestions = Array(completions.prefix(5)) // Limit to 5 suggestions
//            }
//        }
//    }
//    
    private func onAppear() {
//        setupSearchCompleter()
        
        Task {
            await fetchConfiguration()
        }
    }
}

// AddressVerificationField.swift
extension AddressVerificationField {
    public static func fetchConfigFromServer(
        apiKey: String,
        customerID: String,
        token: String,
        refreshToken: String
    ) async throws -> (pollingInterval: TimeInterval, sessionTimeout: TimeInterval) {
        guard let url = URL(string: "https://api.rd.usesourceid.com/v1/api/organization/address-verification-config") else {
            throw URLError(.badURL)
        }
        
        print("apikey: \(apiKey)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let responseData = json?["data"] as? [String: Any]
        
        return (
            responseData?["geotaggingPollingInterval"] as? TimeInterval ?? 10, //eventually hours
            responseData?["geotaggingSessionTimeout"] as? TimeInterval ?? 30 //eventually days
        )
    }
    
    func startContinuousTracking() {
        Task {
            await fetchConfiguration()
            if verifyLocation, let interval = pollingInterval, let timeout = sessionTimeout {
                LocationTrackingService.shared.start(
                    apiKey: customerID,
                    token: token,
                    customerID: apiKey,
                    refreshToken: refreshToken
                    
                )
            }
        }
    }
    
#if os(iOS)
    public static func handleBackgroundGeotagTask(processingTask: BGProcessingTask){
        LocationTrackingService.shared.handleBackgroundGeotagTask(task: processingTask)

    }
#endif
    public static func startTrackingWithRemoteConfig(
           apiKey: String,
           customerID: String,
           token: String,
           refreshToken: String,
           onLocationPost: @escaping (Double, Double) -> Void
       ) {
           
           print("apikey: \(apiKey)")
           Task {
               do {
                   let (interval, timeout) = try await fetchConfigFromServer(apiKey: apiKey, customerID: customerID, token: token, refreshToken: refreshToken)
                   
                LocationTrackingService.shared.start(
                    apiKey: apiKey,
                    token: token,
                    customerID: customerID,
                    refreshToken: refreshToken
                   )
               } catch {
                   print("Failed to fetch config or start tracking: \(error.localizedDescription)")
               }
           }
       }
}

// MARK: - Search Completer Delegate
private class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    private let onUpdate: ([MKLocalSearchCompletion]) -> Void
    
    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onUpdate = onUpdate
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error)")
    }
}

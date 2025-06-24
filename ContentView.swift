//
//  ContentView.swift
//  AddressVerification
//
//  Created by Richard Uzor on 24/06/2025.
//

import Foundation
import SwiftUI
import AddressVerification

struct ContentView: View {
    var body: some View {
        AddressVerificationField(
            apiKey: "your-api-key",
            showButton: true,
            initialText: "",
            verifyLocation: false,
            customerID: "customer123",
            onAddressSelected: { address, lat, lon in
                print("Selected: \(address) at \(lat), \(lon)")
            },
            onLocationPost: { lat, lon in
                print("Location posted: \(lat), \(lon)")
            }
        )
    }
}

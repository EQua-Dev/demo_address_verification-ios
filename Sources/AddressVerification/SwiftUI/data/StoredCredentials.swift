//
//  StoredCredentials.swift
//  AddressVerification
//
//  Created by Richard Uzor on 19/07/2025.
//

import Foundation


struct StoredCredentials {
    static func save(apiKey: String, token: String, customerID: String) {
        UserDefaults.standard.set(apiKey, forKey: "geo_apiKey")
        UserDefaults.standard.set(token, forKey: "geo_token")
        UserDefaults.standard.set(customerID, forKey: "geo_customerID")
    }

    static func load() -> (apiKey: String, token: String, customerID: String)? {
        guard let apiKey = UserDefaults.standard.string(forKey: "geo_apiKey"),
              let token = UserDefaults.standard.string(forKey: "geo_token"),
              let customerID = UserDefaults.standard.string(forKey: "geo_customerID") else {
            return nil
        }
        return (apiKey, token, customerID)
    }
}

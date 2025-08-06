//
//  StoredCredentials.swift
//  AddressVerification
//
//  Created by Richard Uzor on 19/07/2025.
//

import Foundation


struct StoredCredentials {
    static func save(apiKey: String, token: String, refreshToken: String) {
        UserDefaults.standard.set(apiKey, forKey: "geo_apiKey")
        UserDefaults.standard.set(token, forKey: "geo_token")
//        UserDefaults.standard.set(customerID, forKey: "geo_customerID")
        UserDefaults.standard.set(refreshToken, forKey: "geo_refreshToken")
    }

    static func load() -> (apiKey: String, token: String, refreshToken: String)? {
        guard let apiKey = UserDefaults.standard.string(forKey: "geo_apiKey"),
              let token = UserDefaults.standard.string(forKey: "geo_token"),
//              let customerID = UserDefaults.standard.string(forKey: "geo_customerID"),
              let refreshToken = UserDefaults.standard.string(forKey: "geo_refreshToken") else {
            return nil
        }
            return (apiKey, token, refreshToken)
    }
    
    static func update(token: String?, refreshToken: String?) {
        if let token = token {
            UserDefaults.standard.set(token, forKey: "geo_token")
        }
        if let refreshToken = refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "geo_refreshToken")
        }
    }

}

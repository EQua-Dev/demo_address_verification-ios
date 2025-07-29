//
//  GeoTagCache.swift
//  AddressVerification
//
//  Created by Richard Uzor on 28/07/2025.
//

import Foundation


class GeoTagCache {
    static let key = "CachedGeoTags"

    static func save(_ geotag: CachedGeoTag) {
        var current = load()
        current.append(geotag)
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [CachedGeoTag] {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CachedGeoTag].self, from: data) {
            return decoded
        }
        return []
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

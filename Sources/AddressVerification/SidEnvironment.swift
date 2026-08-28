//
//  SidEnvironment.swift
//  AddressVerification
//

import Foundation

/// Single source of truth for the SourceID gateway base URL.
///
/// The environment is derived from the API key prefix, so consumers never pass
/// a URL. Every network call in this SDK must resolve its base URL here —
/// hardcoding a host at the call site is what previously pinned parts of the
/// SDK to a decommissioned server.
///
/// UAT is intentionally absent: that environment was retired along with the
/// `usesourceid.com` hosts.
enum SidEnvironment {

    private static let production = "https://api.sourceid.tech/v1/api"
    private static let sandbox = "https://api.sbx.sourceid.tech/v1/api"
    private static let development = "https://api-rd.tailfaed50.ts.net/v1/api"

    /// Unknown key prefixes fall back to development rather than failing, so a
    /// misconfigured key degrades to a reachable host instead of a dead one.
    static func resolveBaseUrl(apiKey: String) -> String {
        if apiKey.hasPrefix("sk_live_") { return production }
        if apiKey.hasPrefix("sk_sbx_") { return sandbox }
        return development
    }

    /// Convenience for the organisation config endpoint used in several places.
    static func addressVerificationConfigURL(apiKey: String) -> URL? {
        URL(string: resolveBaseUrl(apiKey: apiKey) + "/organization/address-verification-config")
    }
}

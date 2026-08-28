//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/07/2025.
//

import Foundation

class ApiService {
    static let shared = ApiService()
    
    private func baseUrl(for apiKey: String) -> String {
        return SidEnvironment.resolveBaseUrl(apiKey: apiKey)
    }


    private func createRequest<T: Codable>(
        endpoint: String,
        method: String,
        token: String? = nil,
        customerID: String? = nil,
        apiKey: String,
        body: T? = nil
    ) -> URLRequest? {
        let base = SidEnvironment.resolveBaseUrl(apiKey: apiKey)
        guard let url = URL(string: "\(base)/\(endpoint)") else { return nil }

//        guard let url = URL(string: "\(baseUrl)/\(endpoint)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        if let customerID = customerID {
            request.setValue(customerID, forHTTPHeaderField: "customer")
        }
        
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "x-auth-token")
        }

        if let body = body {
            do {
                let jsonData = try JSONEncoder().encode(body)
                request.httpBody = jsonData
            } catch {
                print("Failed to encode body: \(error)")
                return nil
            }
        }

        return request
    }
    
    private func createRequest(
        endpoint: String,
        method: String,
        token: String? = nil,
        customerID: String? = nil,
        apiKey: String
    ) -> URLRequest? {
        
        let base = SidEnvironment.resolveBaseUrl(apiKey: apiKey)
        guard let url = URL(string: "\(base)/\(endpoint)") else { return nil }

//        guard let url = URL(string: "\(baseUrl)/\(endpoint)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        if let customerID = customerID {
            request.setValue(customerID, forHTTPHeaderField: "customer")
        }
        
        
        if let token = token {
            request.setValue(token, forHTTPHeaderField: "x-auth-token")
        }

        return request
    }

    func fetchOrganisationConfig(apiKey: String, completion: @escaping (Result<GetOrganisationConfigResponse, Error>) -> Void) {
        performRequestWithAutoRefresh(
               endpoint: "organization/address-verification-config",
               method: "GET",
               decodeTo: GetOrganisationConfigResponse.self,
               completion: completion
           )
//        guard let request = createRequest(endpoint: "organization/address-verification-config", method: "GET", apiKey: apiKey) else {
//            print("❌ Invalid URL request")
//            return
//        }
//
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let data = data {
//                // ✅ Print raw response before decoding
//                if let jsonString = String(data: data, encoding: .utf8) {
//                    print("📦 Raw JSON Response:\n\(jsonString)")
//                }
//
//                do {
//                    let decoded = try JSONDecoder().decode(GetOrganisationConfigResponse.self, from: data)
//                    completion(.success(decoded))
//                } catch {
//                    print("❌ Decoding error: \(error.localizedDescription)")
//                    completion(.failure(error))
//                }
//            } else if let error = error {
//                print("❌ Network error: \(error.localizedDescription)")
//                completion(.failure(error))
//            } else {
//                print("❌ Unknown error: no data and no error")
//            }
//        }.resume()
    }


    func fetchCustomerHistory(verificationGroupId: String?, customerID: String, apiKey: String, completion: @escaping (Result<CustomerAddressHistoryResponse, Error>) -> Void) {
        performRequestWithAutoRefresh(
               endpoint: "customer/address-history?verificationGroupId=\(verificationGroupId)&customer=\(customerID)",
               method: "GET",
               decodeTo: CustomerAddressHistoryResponse.self,
               completion: completion
           )
    }

    func addGeoTag(token: String, apiKey: String, requestBody: AddGeoTagRequest, completion: @escaping (Result<AddGeoTagResponse, Error>) -> Void) {
        performRequestWithAutoRefresh(
               endpoint: "customer/add-geotag",
               method: "POST",
               requestBody: requestBody,
               decodeTo: AddGeoTagResponse.self,
               completion: completion
           )
    }
    
    func refreshAuthToken(refreshToken: String, apiKey: String, completion: @escaping (Result<(token: String, refreshToken: String), Error>) -> Void) {
        struct RefreshTokenRequest: Codable {
            let refreshToken: String
        }

        struct RefreshTokenResponse: Codable {
            let token: String
            let refreshToken: String
        }

        guard let request = createRequest(
            endpoint: "customer/refresh-token",  // update this to your actual endpoint
            method: "POST",
            apiKey: apiKey,
            body: RefreshTokenRequest(refreshToken: refreshToken)
        ) else {
            print("❌ Invalid refresh token request")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
                    completion(.success((decoded.token, decoded.refreshToken)))
                } catch {
                    print("❌ Failed to decode refresh token response")
                    completion(.failure(error))
                }
            } else if let error = error {
                completion(.failure(error))
            }
        }.resume()
    }

    private func performRequestWithAutoRefresh<T: Decodable, B: Codable>(
        endpoint: String,
        method: String,
        requestBody: B? = nil,
        decodeTo type: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard var credentials = StoredCredentials.load() else {
            completion(.failure(NSError(domain: "Missing credentials", code: 0)))
            return
        }

        func executeRequest(with token: String) {
            let request = createRequest(
                endpoint: endpoint,
                method: method,
                token: token,
                customerID: credentials.customerID,
                apiKey: credentials.apiKey,
                body: requestBody
            )

            guard let request = request else {
                completion(.failure(NSError(domain: "Invalid request", code: 0)))
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    // Try refresh
                    print("🔁 Token expired, attempting refresh")
                    self.refreshAuthToken(refreshToken: credentials.refreshToken, apiKey: credentials.apiKey) { result in
                        switch result {
                        case .success(let (newToken, newRefreshToken)):
                            credentials.token = newToken
                            credentials.refreshToken = newRefreshToken
                            StoredCredentials.save(apiKey: credentials.apiKey, customerID: credentials.customerID, verificationGroupId: credentials.verificationGroupId, token: newToken, refreshToken: newRefreshToken)
                            executeRequest(with: newToken) // Retry with new token
                        case .failure(let refreshError):
                            completion(.failure(refreshError))
                        }
                    }
                    return
                }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NSError(domain: "No data", code: 0)))
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }

            }.resume()
        }

        executeRequest(with: credentials.token)
    }

    private func performRequestWithAutoRefresh<T: Decodable>(
        endpoint: String,
        method: String,
        decodeTo type: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard var credentials = StoredCredentials.load() else {
            completion(.failure(NSError(domain: "Missing credentials", code: 0)))
            return
        }

        func executeRequest(with token: String) {
            let request = createRequest(
                endpoint: endpoint,
                method: method,
                token: token,
                customerID: credentials.customerID,
                apiKey: credentials.apiKey,
                body: Optional<Data>.none // 👈 explicitly nil body
            )

            guard let request = request else {
                completion(.failure(NSError(domain: "Invalid request", code: 0)))
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    // Try refresh
                    print("🔁 Token expired, attempting refresh")
                    self.refreshAuthToken(refreshToken: credentials.refreshToken, apiKey: credentials.apiKey) { result in
                        switch result {
                        case .success(let (newToken, newRefreshToken)):
                            credentials.token = newToken
                            credentials.refreshToken = newRefreshToken
                            StoredCredentials.save(apiKey: credentials.apiKey, customerID: credentials.customerID, verificationGroupId: credentials.verificationGroupId, token: newToken, refreshToken: newRefreshToken)
                            executeRequest(with: newToken)
                        case .failure(let refreshError):
                            completion(.failure(refreshError))
                        }
                    }
                    return
                }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NSError(domain: "No data", code: 0)))
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }

            }.resume()
        }

        executeRequest(with: credentials.token)
    }

}

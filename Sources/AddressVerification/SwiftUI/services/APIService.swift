//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/07/2025.
//

import Foundation

class ApiService {
    static let shared = ApiService()
    private let baseUrl = "https://api.rd.usesourceid.com/v1/api/"

    private func createRequest<T: Codable>(
        endpoint: String,
        method: String,
        token: String? = nil,
        apiKey: String,
        body: T? = nil
    ) -> URLRequest? {
        guard let url = URL(string: "\(baseUrl)/\(endpoint)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

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
        apiKey: String
    ) -> URLRequest? {
        guard let url = URL(string: "\(baseUrl)/\(endpoint)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        if let token = token {
            request.setValue(token, forHTTPHeaderField: "x-auth-token")
        }

        return request
    }

    func fetchOrganisationConfig(apiKey: String, completion: @escaping (Result<GetOrganisationConfigResponse, Error>) -> Void) {
        guard let request = createRequest(endpoint: "organization/address-verification-config", method: "GET", apiKey: apiKey) else { return }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(GetOrganisationConfigResponse.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            } else if let error = error {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchCustomerHistory(token: String, apiKey: String, completion: @escaping (Result<CustomerAddressHistoryResponse, Error>) -> Void) {
        guard let request = createRequest(endpoint: "customer/address-history", method: "GET", token: token, apiKey: apiKey) else { return }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(CustomerAddressHistoryResponse.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            } else if let error = error {
                completion(.failure(error))
            }
        }.resume()
    }

    func addGeoTag(token: String, apiKey: String, requestBody: AddGeoTagRequest, completion: @escaping (Result<AddGeoTagResponse, Error>) -> Void) {
        guard let request = createRequest(endpoint: "customer/add-geotag", method: "POST", token: token, apiKey: apiKey, body: requestBody) else { return }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(AddGeoTagResponse.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            } else if let error = error {
                completion(.failure(error))
            }
        }.resume()
    }
}

//
//  ApiHelper.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/07/2025.
//


import Foundation
import Combine

class ApiHelper {
    private let apiService: ApiService

    init(apiService: ApiService = ApiService()) {
        self.apiService = apiService
    }

    func fetchOrganisationConfig(apiKey: String) -> AnyPublisher<GetOrganisationConfigResponse, Error> {
        return Future { promise in
            self.apiService.fetchOrganisationConfig(apiKey: apiKey) { result in
                promise(result) // result is already Result<Success, Error>
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchCustomerHistory(apiKey: String, token: String) -> AnyPublisher<CustomerAddressHistoryResponse, Error> {
        return Future { promise in
            self.apiService.fetchCustomerHistory(token: token, apiKey: apiKey) { result in
                promise(result)
            }
        }
        .eraseToAnyPublisher()
    }

    func addGeoTag(apiKey: String, token: String, request: AddGeoTagRequest) -> AnyPublisher<AddGeoTagResponse, Error> {
        return Future { promise in
            self.apiService.addGeoTag(token: token, apiKey: apiKey, requestBody: request) { result in
                promise(result)
            }
        }
        .eraseToAnyPublisher()
    }
}

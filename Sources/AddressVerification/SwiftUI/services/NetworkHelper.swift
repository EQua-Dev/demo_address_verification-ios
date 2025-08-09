//
//  NetworkHelper.swift
//  AddressVerification
//
//  Created by Richard Uzor on 28/07/2025.
//


import Network

func isConnectedToInternet() -> Bool {
    let monitor = NWPathMonitor()
    var status = false
    let semaphore = DispatchSemaphore(value: 0)

    monitor.pathUpdateHandler = { path in
        status = path.status == .satisfied
        semaphore.signal()
        monitor.cancel()
    }

    let queue = DispatchQueue(label: "InternetMonitor")
    monitor.start(queue: queue)
    _ = semaphore.wait(timeout: .now() + 1.0)
    return status
}

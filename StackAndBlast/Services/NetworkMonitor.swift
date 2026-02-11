import Foundation
import Network

/// Monitors network connectivity using NWPathMonitor.
/// Game modes are disabled when the device is offline.
@Observable
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    /// Whether the device currently has a network connection.
    private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

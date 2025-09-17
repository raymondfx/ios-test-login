import Foundation
import Network

/// Monitors network connectivity status and publishes changes to observers
/// Uses Apple's Network framework to detect real-time connectivity changes
/// Conforms to ObservableObject to work seamlessly with SwiftUI and Combine
class NetworkMonitor: ObservableObject {
    // MARK: - Private Properties

    /// Network path monitor that tracks connectivity status
    private let monitor = NWPathMonitor()

    /// Background queue for network monitoring operations
    /// Prevents blocking the main thread during network status checks
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // MARK: - Published Properties

    /// Published property that tracks current network connectivity status
    /// Automatically updates UI when network status changes
    /// Default value is true to assume connectivity until proven otherwise
    @Published var isConnected = true

    // MARK: - Initialization

    /// Initializes the network monitor and starts monitoring network changes
    /// Sets up the path update handler to respond to connectivity changes
    init() {
        // Configure the monitor to handle network path changes
        monitor.pathUpdateHandler = { [weak self] path in
            // Update the connectivity status on the main thread
            // This ensures UI updates happen on the correct thread
            DispatchQueue.main.async {
                // Network is considered connected when status is satisfied
                self?.isConnected = path.status == .satisfied
            }
        }

        // Start monitoring network changes on the background queue
        monitor.start(queue: queue)
    }

    // MARK: - Deinitialization

    /// Stops network monitoring when the object is deallocated
    /// Properly cleans up resources to prevent memory leaks
    deinit {
        monitor.cancel()
    }
}
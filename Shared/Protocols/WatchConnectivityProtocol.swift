import Foundation

/// Minimal protocol for Watch Connectivity messaging, enabling testability.
@MainActor
protocol WatchConnectivityProtocol: AnyObject, Observable {
    var isReachable: Bool { get }
    var lastReceivedMessage: [String: Any] { get }
    var onMessageReceived: (([String: Any]) -> Void)? { get set }

    func sendMessage(_ message: [String: Any])
}

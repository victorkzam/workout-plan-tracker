import Foundation
@testable import WorkoutTracker

@Observable
@MainActor
final class MockWatchConnectivity: WatchConnectivityProtocol {

    // MARK: - Observable properties

    var isReachable: Bool = false
    var lastReceivedMessage: [String: Any] = [:]
    var onMessageReceived: (([String: Any]) -> Void)?

    // MARK: - Call tracking

    private(set) var sentMessages: [[String: Any]] = []

    // MARK: - Protocol conformance

    func sendMessage(_ message: [String: Any]) {
        sentMessages.append(message)
    }

    // MARK: - Test helpers

    func simulateReceivedMessage(_ message: [String: Any]) {
        lastReceivedMessage = message
        onMessageReceived?(message)
    }
}

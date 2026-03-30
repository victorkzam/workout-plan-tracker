import Foundation
import WatchConnectivity

// MARK: - Shared message keys

enum WCMessageKey {
    static let type           = "type"
    static let stepIndex      = "stepIndex"
    static let timeRemaining  = "timeRemaining"
    static let sessionID      = "sessionID"
    static let exerciseName   = "exerciseName"
    static let blockName      = "blockName"
    static let round          = "round"
    static let totalRounds    = "totalRounds"
    static let isRunning      = "isRunning"
    static let totalSteps     = "totalSteps"
    // GPS metrics (Watch → iPhone)
    static let currentPace    = "currentPace"      // sec/km
    static let distance       = "distance"          // meters
    static let heartRate      = "heartRate"         // bpm
    static let elapsedTime    = "elapsedTime"       // seconds
}

enum WCMessageType: String {
    case stepUpdate    = "stepUpdate"
    case sessionStart  = "sessionStart"
    case sessionEnd    = "sessionEnd"
    case sessionPause  = "sessionPause"
    case sessionResume = "sessionResume"
    case gpsMetrics    = "gpsMetrics"
}

// MARK: - WatchConnectivityManager

@Observable
final class WatchConnectivityManager: NSObject {

    static let shared = WatchConnectivityManager()

    // Published state consumed by both iOS and watchOS views
    private(set) var isReachable: Bool = false
    private(set) var lastReceivedMessage: [String: Any] = [:]

    /// Closure called on the main thread whenever a message arrives.
    var onMessageReceived: (([String: Any]) -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send helpers

    func sendMessage(_ message: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                // Fallback to application context on send failure
                self.updateContext(message)
            }
        } else {
            updateContext(message)
        }
    }

    private func updateContext(_ payload: [String: Any]) {
        // application context only supports Plist-compatible types
        let plistContext = payload.filter { isPlistCompatible($0.value) }
        try? WCSession.default.updateApplicationContext(plistContext)
    }

    private func isPlistCompatible(_ value: Any) -> Bool {
        value is String || value is Bool || value is Int || value is Double
            || value is Data || value is Date
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.lastReceivedMessage = message
            self.onMessageReceived?(message)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.lastReceivedMessage = applicationContext
            self.onMessageReceived?(applicationContext)
        }
    }

    // Required on iOS only — watchOS doesn't need these
#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
#endif
}

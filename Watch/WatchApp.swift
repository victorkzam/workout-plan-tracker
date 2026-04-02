import SwiftUI
import SwiftData

@main
struct WorkoutTrackerWatchApp: App {

    private let modelContainer = ModelContainerFactory.create()

    @State private var connectivity = WatchConnectivityManager.shared
    @State private var watchSession = WatchSessionController()

    var body: some Scene {
        WindowGroup {
            SessionListWatchView()
                .environment(watchSession)
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - WatchSessionController
// Receives step updates from iPhone and holds live session state.

@Observable @MainActor
final class WatchSessionController {

    var exerciseName: String = ""
    var blockName: String = ""
    var round: Int = 1
    var totalRounds: Int = 1
    var timeRemaining: Int = 0
    var totalSteps: Int = 0
    var currentStepIndex: Int = 0
    var isRunning: Bool = false
    var sessionID: String = ""
    var currentPaceSecPerKm: Double = 0
    var distanceMeters: Double = 0
    var heartRate: Double = 0
    var elapsedTime: Double = 0
    var isSessionActive: Bool = false

    private var localTimer: Timer?

    init() {
        WatchConnectivityManager.shared.onMessageReceived = { [weak self] message in
            self?.handleMessage(message)
        }
    }

    private func handleMessage(_ msg: [String: Any]) {
        guard let typeRaw = msg[WCMessageKey.type] as? String,
              let type = WCMessageType(rawValue: typeRaw) else { return }

        switch type {
        case .stepUpdate:
            exerciseName     = msg[WCMessageKey.exerciseName]    as? String ?? ""
            blockName        = msg[WCMessageKey.blockName]       as? String ?? ""
            round            = msg[WCMessageKey.round]           as? Int ?? 1
            totalRounds      = msg[WCMessageKey.totalRounds]     as? Int ?? 1
            timeRemaining    = msg[WCMessageKey.timeRemaining]   as? Int ?? 0
            totalSteps       = msg[WCMessageKey.totalSteps]      as? Int ?? 0
            currentStepIndex = msg[WCMessageKey.stepIndex]       as? Int ?? 0
            isRunning        = msg[WCMessageKey.isRunning]       as? Bool ?? false
            sessionID        = msg[WCMessageKey.sessionID]       as? String ?? ""
            isSessionActive  = true
            currentPaceSecPerKm = msg[WCMessageKey.currentPace] as? Double ?? 0
            distanceMeters   = msg[WCMessageKey.distance]       as? Double ?? 0
            elapsedTime      = msg[WCMessageKey.elapsedTime]    as? Double ?? 0
            startLocalTimer()

        case .sessionStart:
            isSessionActive = true

        case .sessionEnd:
            isSessionActive  = false
            stopLocalTimer()
            WKInterfaceDevice.current().play(.success)

        case .sessionPause:
            isRunning = false
            stopLocalTimer()

        case .sessionResume:
            isRunning = true
            startLocalTimer()

        case .gpsMetrics:
            currentPaceSecPerKm = msg[WCMessageKey.currentPace] as? Double ?? currentPaceSecPerKm
            distanceMeters   = msg[WCMessageKey.distance]      as? Double ?? distanceMeters
            heartRate        = msg[WCMessageKey.heartRate]     as? Double ?? heartRate
            elapsedTime      = msg[WCMessageKey.elapsedTime]   as? Double ?? elapsedTime
        }
    }

    // Local countdown so the Watch continues ticking even if iPhone message is delayed
    private func startLocalTimer() {
        stopLocalTimer()
        guard isRunning, timeRemaining > 0 else { return }
        localTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.isRunning else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.stopLocalTimer()
                WKInterfaceDevice.current().play(.stop)
            }
        }
    }

    private func stopLocalTimer() {
        localTimer?.invalidate()
        localTimer = nil
    }
}

import WatchKit

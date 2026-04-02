import Foundation
import HealthKit
import CoreLocation
import WatchKit
import os

// Manages an independent HKWorkoutSession on the Watch for GPS runs/cycles.
// Sends live metrics back to iPhone every 5 seconds via WatchConnectivity.

@Observable
final class WorkoutSessionManager: NSObject {

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var locationManager = CLLocationManager()
    private var broadcastTimer: Timer?

    private(set) var heartRate: Double = 0
    private(set) var distance: Double = 0
    private(set) var currentPaceSecPerKm: Double = 0
    private(set) var elapsedSeconds: Double = 0
    private(set) var isRunning: Bool = false
    private(set) var route: [CLLocation] = []

    private var recentSpeeds: [Double] = []
    private var previousLocation: CLLocation?
    private var sessionStartDate: Date?
    private var elapsedTimer: Timer?

    // MARK: - Start

    func startWorkout(activityType: HKWorkoutActivityType) async {
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType  = .outdoor

        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            let ws = try HKWorkoutSession(healthStore: store, configuration: config)
            let wb = ws.associatedWorkoutBuilder()
            wb.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            wb.delegate = self
            ws.delegate = self
            session = ws
            builder = wb

            ws.startActivity(with: Date())
            try await wb.beginCollection(at: Date())
            sessionStartDate = Date()
            isRunning = true
            Logger.workout.info("Watch workout started")
            startLocationTracking()
            startElapsedTimer()
            startBroadcastTimer()
        } catch {
            Logger.workout.error("Failed to start watch workout: \(error.localizedDescription)")
        }
    }

    // MARK: - Stop

    func stopWorkout() async {
        session?.end()
        do {
            try await builder?.endCollection(at: Date())
            _ = try await builder?.finishWorkout()
            Logger.workout.info("Watch workout stopped and saved")
        } catch {
            Logger.workout.error("Failed to finish watch workout: \(error.localizedDescription)")
        }
        stopLocationTracking()
        stopElapsedTimer()
        stopBroadcastTimer()
        isRunning = false
        WKInterfaceDevice.current().play(.success)
    }

    func pauseWorkout() {
        Logger.workout.info("Watch workout paused")
        session?.pause()
        isRunning = false
        stopElapsedTimer()
        WKInterfaceDevice.current().play(.stop)
    }

    func resumeWorkout() {
        Logger.workout.info("Watch workout resumed")
        session?.resume()
        isRunning = true
        startElapsedTimer()
        WKInterfaceDevice.current().play(.start)
    }

    // MARK: - Location

    private func startLocationTracking() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType    = .fitness
        locationManager.distanceFilter  = 3
        locationManager.startUpdatingLocation()
    }

    private func stopLocationTracking() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Timers

    private func startElapsedTimer() {
        let start = Date().addingTimeInterval(-elapsedSeconds)
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds = Date().timeIntervalSince(start)
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate(); elapsedTimer = nil
    }

    private func startBroadcastTimer() {
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.broadcastMetrics()
        }
    }

    private func stopBroadcastTimer() {
        broadcastTimer?.invalidate(); broadcastTimer = nil
    }

    private func broadcastMetrics() {
        WatchConnectivityManager.shared.sendMessage([
            WCMessageKey.type:        WCMessageType.gpsMetrics.rawValue,
            WCMessageKey.currentPace: currentPaceSecPerKm,
            WCMessageKey.distance:    distance,
            WCMessageKey.heartRate:   heartRate,
            WCMessageKey.elapsedTime: elapsedSeconds
        ])
    }

    // MARK: - Formatting

    var paceDisplayString: String {
        GPSMath.formatPace(secondsPerKm: currentPaceSecPerKm)
    }

    var distanceDisplayString: String {
        GPSMath.formatDistance(meters: distance)
    }

    var elapsedString: String {
        let t = Int(elapsedSeconds)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    func workoutSession(_ ws: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        Logger.workout.info("Workout session state: \(String(describing: fromState)) -> \(String(describing: toState))")
    }

    func workoutSession(_ ws: HKWorkoutSession, didFailWithError error: Error) {
        Logger.workout.error("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ builder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            guard let stats = builder.statistics(for: quantityType) else { continue }

            Task { @MainActor in
                if quantityType == HKQuantityType(.heartRate) {
                    self.heartRate = stats.mostRecentQuantity()?
                        .doubleValue(for: .init(from: "count/min")) ?? self.heartRate
                    Logger.workout.debug("Watch heart rate updated")
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WorkoutSessionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for loc in locations {
                guard loc.horizontalAccuracy < 20, loc.horizontalAccuracy >= 0 else { continue }
                self.route.append(loc)
                if let prev = self.previousLocation {
                    self.distance += loc.distance(from: prev)
                }
                self.previousLocation = loc
                let speed = max(loc.speed, 0)
                if speed > 0.5 {
                    self.recentSpeeds.append(speed)
                    if self.recentSpeeds.count > 3 { self.recentSpeeds.removeFirst() }
                    let avg = GPSMath.smoothSpeed(recentSpeeds: self.recentSpeeds)
                    self.currentPaceSecPerKm = GPSMath.paceFromSpeed(avg)
                }
            }
        }
    }
}

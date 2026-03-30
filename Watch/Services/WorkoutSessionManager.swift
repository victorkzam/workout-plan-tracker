import Foundation
import HealthKit
import CoreLocation
import WatchKit

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
            startLocationTracking()
            startElapsedTimer()
            startBroadcastTimer()
        } catch {}
    }

    // MARK: - Stop

    func stopWorkout() async {
        session?.end()
        do {
            try await builder?.endCollection(at: Date())
            _ = try await builder?.finishWorkout()
        } catch {}
        stopLocationTracking()
        stopElapsedTimer()
        stopBroadcastTimer()
        isRunning = false
        WKInterfaceDevice.current().play(.success)
    }

    func pauseWorkout() {
        session?.pause()
        isRunning = false
        stopElapsedTimer()
        WKInterfaceDevice.current().play(.stop)
    }

    func resumeWorkout() {
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
        guard currentPaceSecPerKm > 0 else { return "--:--" }
        let m = Int(currentPaceSecPerKm) / 60
        let s = Int(currentPaceSecPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }

    var distanceDisplayString: String {
        distance >= 1000
            ? String(format: "%.2f km", distance / 1000)
            : String(format: "%.0f m", distance)
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
                        date: Date) {}

    func workoutSession(_ ws: HKWorkoutSession, didFailWithError error: Error) {}
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ builder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            guard let stats = builder.statistics(for: quantityType) else { continue }

            DispatchQueue.main.async {
                if quantityType == HKQuantityType(.heartRate) {
                    self.heartRate = stats.mostRecentQuantity()?
                        .doubleValue(for: .init(from: "count/min")) ?? self.heartRate
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WorkoutSessionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            guard loc.horizontalAccuracy < 20, loc.horizontalAccuracy >= 0 else { continue }
            route.append(loc)
            if let prev = previousLocation {
                distance += loc.distance(from: prev)
            }
            previousLocation = loc
            let speed = max(loc.speed, 0)
            if speed > 0.5 {
                recentSpeeds.append(speed)
                if recentSpeeds.count > 3 { recentSpeeds.removeFirst() }
                let avg = recentSpeeds.reduce(0, +) / Double(recentSpeeds.count)
                currentPaceSecPerKm = 1000 / avg
            }
        }
    }
}

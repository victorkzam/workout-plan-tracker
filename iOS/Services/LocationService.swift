import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject, LocationServiceProtocol {

    private(set) var currentPaceSecPerKm: Double = 0    // smoothed
    private(set) var totalDistanceMeters: Double = 0
    private(set) var elapsedSeconds: Double = 0
    private(set) var route: [CLLocation] = []
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var recentSpeeds: [Double] = []             // last 3 raw speeds (m/s)
    private var sessionStartDate: Date?
    private var elapsedTimer: Timer?
    private var previousLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate       = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter  = 3                     // update every 3 m
        manager.activityType    = .fitness
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Control

    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    func start() {
        sessionStartDate = Date()
        totalDistanceMeters = 0
        currentPaceSecPerKm = 0
        recentSpeeds = []
        route = []
        previousLocation = nil
        manager.startUpdatingLocation()
        startElapsedTimer()
    }

    func stop() {
        manager.stopUpdatingLocation()
        stopElapsedTimer()
    }

    func pause() { manager.stopUpdatingLocation(); stopElapsedTimer() }
    func resume() { manager.startUpdatingLocation(); startElapsedTimer() }

    // MARK: - Elapsed timer

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        let start = Date().addingTimeInterval(-elapsedSeconds)
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds = Date().timeIntervalSince(start)
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Pace formatting

    var paceDisplayString: String {
        GPSMath.formatPace(secondsPerKm: currentPaceSecPerKm)
    }

    var distanceDisplayString: String {
        GPSMath.formatDistance(meters: totalDistanceMeters)
    }

    var avgPaceSecPerKm: Double {
        guard totalDistanceMeters > 10 else { return 0 }
        return elapsedSeconds / (totalDistanceMeters / 1000)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            guard location.horizontalAccuracy < 20,    // discard noisy readings
                  location.horizontalAccuracy >= 0 else { continue }

            route.append(location)

            // Accumulate distance
            if let prev = previousLocation {
                totalDistanceMeters += location.distance(from: prev)
            }
            previousLocation = location

            // Smooth pace using 3-point rolling average of raw GPS speed
            let rawSpeedMps = max(location.speed, 0)
            if rawSpeedMps > 0.5 {                     // ignore near-stationary
                recentSpeeds.append(rawSpeedMps)
                if recentSpeeds.count > 3 { recentSpeeds.removeFirst() }
                let avgSpeed = GPSMath.smoothSpeed(recentSpeeds: recentSpeeds)
                currentPaceSecPerKm = GPSMath.paceFromSpeed(avgSpeed)
            }
        }
    }
}

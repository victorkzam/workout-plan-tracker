import Foundation
import CoreLocation
@testable import WorkoutTracker

@Observable
@MainActor
final class MockLocationService: LocationServiceProtocol {

    // MARK: - Observable properties

    var route: [CLLocation] = []
    var totalDistanceMeters: Double = 0
    var currentPaceSecPerKm: Double = 0
    var elapsedSeconds: Double = 0
    var paceDisplayString: String = "--:--"
    var distanceDisplayString: String = "0 m"
    var avgPaceSecPerKm: Double = 0

    // MARK: - Call tracking

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0

    // MARK: - Protocol conformance

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func pause() {
        pauseCallCount += 1
    }

    func resume() {
        resumeCallCount += 1
    }
}

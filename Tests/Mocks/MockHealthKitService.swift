import Foundation
import HealthKit
@testable import WorkoutTracker

@Observable
@MainActor
final class MockHealthKitService: HealthKitServiceProtocol {

    // MARK: - Observable properties

    var currentHeartRate: Double = 0
    var isAuthorized: Bool = false
    var activeWorkoutSession: HKWorkoutSession? = nil

    // MARK: - Call tracking

    private(set) var requestAuthorizationCallCount = 0
    private(set) var startWorkoutSessionCallCount = 0
    private(set) var stopWorkoutSessionCallCount = 0
    private(set) var hrZoneStatusCallCount = 0

    private(set) var lastActivityType: HKWorkoutActivityType?

    // MARK: - Configurable behavior

    var requestAuthorizationHandler: (() async -> Void)?
    var startWorkoutSessionHandler: ((HKWorkoutActivityType) async -> Void)?
    var stopWorkoutSessionHandler: (() async -> Void)?
    var hrZoneStatusResult: HRZoneStatus = .unknown

    // MARK: - Protocol conformance

    func requestAuthorization() async {
        requestAuthorizationCallCount += 1
        await requestAuthorizationHandler?()
    }

    func startWorkoutSession(activityType: HKWorkoutActivityType) async {
        startWorkoutSessionCallCount += 1
        lastActivityType = activityType
        await startWorkoutSessionHandler?(activityType)
    }

    func stopWorkoutSession() async {
        stopWorkoutSessionCallCount += 1
        await stopWorkoutSessionHandler?()
    }

    func hrZoneStatus(exercise: Exercise) -> HRZoneStatus {
        hrZoneStatusCallCount += 1
        return hrZoneStatusResult
    }
}

import Foundation
import HealthKit

/// Protocol abstracting HealthKit workout and heart-rate functionality for testability.
@MainActor
protocol HealthKitServiceProtocol: AnyObject, Observable {
    var currentHeartRate: Double { get }
    var isAuthorized: Bool { get }
    var activeWorkoutSession: HKWorkoutSession? { get }

    func requestAuthorization() async
    func startWorkoutSession(activityType: HKWorkoutActivityType) async
    func stopWorkoutSession() async
    func hrZoneStatus(exercise: Exercise) -> HRZoneStatus
}

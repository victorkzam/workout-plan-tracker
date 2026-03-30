import Foundation
import HealthKit

@Observable
final class HealthKitService {

    private let store = HKHealthStore()
    private(set) var isAuthorized = false
    private(set) var currentHeartRate: Double = 0
    private(set) var activeWorkoutSession: HKWorkoutSession?

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var liveBuilder: AnyObject?  // HKLiveWorkoutBuilder, requires iOS 26+

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Permissions

    func requestAuthorization() async {
        guard Self.isAvailable else { return }
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKSeriesType.workoutRoute()
        ]
        let typesToShare: Set<HKSampleType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKObjectType.workoutType()
        ]
        do {
            try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Workout session (iOS 26+)

    func startWorkoutSession(activityType: HKWorkoutActivityType) async {
        guard Self.isAvailable else { return }
        guard #available(iOS 26.0, *) else {
            startHeartRateUpdates()
            return
        }

        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType  = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            activeWorkoutSession = session
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            liveBuilder = builder
            session.startActivity(with: Date())
            try await builder.beginCollection(at: Date())
            startHeartRateUpdates()
        } catch {
            startHeartRateUpdates()
        }
    }

    func stopWorkoutSession() async {
        if #available(iOS 26.0, *), let session = activeWorkoutSession {
            session.end()
            if let builder = liveBuilder as? HKLiveWorkoutBuilder {
                do {
                    try await builder.endCollection(at: Date())
                    _ = try await builder.finishWorkout()
                } catch {}
            }
        }
        stopHeartRateUpdates()
        activeWorkoutSession = nil
        liveBuilder = nil
    }

    // MARK: - Live HR streaming

    private func startHeartRateUpdates() {
        let hrType = HKQuantityType(.heartRate)
        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleHRSamples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleHRSamples(samples)
        }
        store.execute(query)
        heartRateQuery = query
    }

    private func stopHeartRateUpdates() {
        if let q = heartRateQuery { store.stop(q) }
        heartRateQuery = nil
    }

    private func handleHRSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample],
              let latest = samples.last else { return }
        let bpm = latest.quantity.doubleValue(for: .init(from: "count/min"))
        DispatchQueue.main.async { self.currentHeartRate = bpm }
    }
}

// MARK: - HR zone helpers

extension HealthKitService {
    /// Returns a colour name matching the current HR against an exercise's zone
    func hrZoneStatus(exercise: Exercise) -> HRZoneStatus {
        guard exercise.hasHRZone, currentHeartRate > 0 else { return .unknown }
        if currentHeartRate < Double(exercise.hrZoneMin) { return .below }
        if currentHeartRate > Double(exercise.hrZoneMax) { return .above }
        return .inZone
    }
}

enum HRZoneStatus {
    case below, inZone, above, unknown

    var colorName: String {
        switch self {
        case .below:   return "cyan"
        case .inZone:  return "green"
        case .above:   return "red"
        case .unknown: return "gray"
        }
    }
}

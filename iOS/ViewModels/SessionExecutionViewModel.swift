import Foundation
import SwiftData
import Combine
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Execution step (flattened from Block × rounds × Exercise)

struct ExecutionStep: Identifiable {
    let id: UUID
    let exercise: Exercise
    let block: WorkoutBlock
    let round: Int           // 1-indexed
    let stepIndex: Int       // global index in the flattened array
    let isRest: Bool         // true = this is a rest between exercises in a circuit

    var durationSec: Int {
        if isRest { return block.restIntervalSec > 0 ? block.restIntervalSec : 15 }
        if block.hasIntervals { return block.workIntervalSec }
        return exercise.durationSec > 0 ? exercise.durationSec : 0
    }

    var isTimed: Bool { durationSec > 0 }
    var isGPS: Bool { exercise.exerciseType.requiresGPS && !isRest }
}

// MARK: - SessionExecutionViewModel

@Observable
final class SessionExecutionViewModel {

    // Session state
    private(set) var session: WorkoutSession
    private(set) var steps: [ExecutionStep] = []
    private(set) var currentStepIndex: Int = 0

    // Timer state
    private(set) var timeRemaining: Int = 0
    private(set) var isRunning: Bool = false
    private(set) var isCompleted: Bool = false
    private(set) var elapsedTotal: Double = 0

    // Dependencies
    let locationService: LocationService
    let healthKitService: HealthKitService

    private var timerCancellable: AnyCancellable?
    private var totalElapsedTimer: AnyCancellable?
    private var sessionStartDate: Date?

    init(session: WorkoutSession,
         locationService: LocationService,
         healthKitService: HealthKitService) {
        self.session = session
        self.locationService = locationService
        self.healthKitService = healthKitService
        self.steps = Self.flattenSteps(session: session)
    }

    // MARK: - Computed

    var currentStep: ExecutionStep? { steps[safe: currentStepIndex] }
    var totalSteps: Int { steps.count }
    var progressFraction: Double { totalSteps > 0 ? Double(currentStepIndex) / Double(totalSteps) : 0 }
    var isGPSStep: Bool { currentStep?.isGPS == true }

    // MARK: - Control

    func startSession() {
        sessionStartDate = Date()
        isRunning = true
        startTotalElapsedTimer()
        prepareCurrentStep()
        broadcastState()
    }

    func pauseSession() {
        isRunning = false
        timerCancellable?.cancel()
        if isGPSStep { locationService.pause() }
        broadcastState()
    }

    func resumeSession() {
        isRunning = true
        prepareCurrentStep()
        if isGPSStep { locationService.resume() }
        broadcastState()
    }

    func skipToNext() {
        advanceStep()
    }

    func goToPrevious() {
        guard currentStepIndex > 0 else { return }
        currentStepIndex -= 1
        prepareCurrentStep()
        broadcastState()
    }

    func endSession(modelContext: ModelContext) {
        isRunning = false
        isCompleted = true
        timerCancellable?.cancel()
        totalElapsedTimer?.cancel()
        if isGPSStep { locationService.stop() }
        saveExecution(modelContext: modelContext)
        broadcastSessionEnd()
    }

    // MARK: - Internal timer

    private func prepareCurrentStep() {
        timerCancellable?.cancel()
        guard let step = currentStep else { return }

        if step.isGPS {
            locationService.start()
            return
        }

        timeRemaining = step.durationSec
        guard step.isTimed, isRunning else { return }

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.timeRemaining > 1 {
                    self.timeRemaining -= 1
                    self.broadcastState()
                } else {
                    self.advanceStep()
                }
            }

        triggerHaptic(.start)
    }

    private func advanceStep() {
        timerCancellable?.cancel()
        if isGPSStep { locationService.stop() }

        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
            prepareCurrentStep()
            broadcastState()
        } else {
            isCompleted = true
            isRunning = false
            totalElapsedTimer?.cancel()
            triggerHaptic(.stop)
            broadcastSessionEnd()
        }
    }

    private func startTotalElapsedTimer() {
        let start = Date()
        totalElapsedTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedTotal = Date().timeIntervalSince(start)
            }
    }

    // MARK: - WatchConnectivity broadcast

    private func broadcastState() {
        guard let step = currentStep else { return }
        var message: [String: Any] = [
            WCMessageKey.type:         WCMessageType.stepUpdate.rawValue,
            WCMessageKey.stepIndex:    currentStepIndex,
            WCMessageKey.totalSteps:   totalSteps,
            WCMessageKey.timeRemaining: timeRemaining,
            WCMessageKey.isRunning:    isRunning,
            WCMessageKey.exerciseName: step.exercise.name,
            WCMessageKey.blockName:    step.block.name,
            WCMessageKey.round:        step.round,
            WCMessageKey.totalRounds:  step.block.rounds,
            WCMessageKey.sessionID:    session.id.uuidString
        ]
        if isGPSStep {
            message[WCMessageKey.currentPace]  = locationService.currentPaceSecPerKm
            message[WCMessageKey.distance]     = locationService.totalDistanceMeters
            message[WCMessageKey.elapsedTime]  = locationService.elapsedSeconds
        }
        WatchConnectivityManager.shared.sendMessage(message)
    }

    private func broadcastSessionEnd() {
        WatchConnectivityManager.shared.sendMessage([
            WCMessageKey.type: WCMessageType.sessionEnd.rawValue,
            WCMessageKey.sessionID: session.id.uuidString
        ])
    }

    // MARK: - Save execution history

    private func saveExecution(modelContext: ModelContext) {
        let exec = SessionExecution(session: session)
        exec.completedAt         = Date()
        exec.durationSeconds     = elapsedTotal
        exec.totalDistanceMeters = locationService.totalDistanceMeters
        exec.avgPaceSecPerKm     = locationService.avgPaceSecPerKm
        exec.avgHeartRate        = healthKitService.currentHeartRate
        exec.routeData           = encodeRoute(locationService.route)
        modelContext.insert(exec)
        try? modelContext.save()
    }

    private func encodeRoute(_ locations: [CLLocation]) -> Data? {
        // Store as [[lat, lon, alt]]
        guard !locationService.route.isEmpty else { return nil }
        let coords = locationService.route.map {
            [$0.coordinate.latitude, $0.coordinate.longitude, $0.altitude]
        }
        return try? JSONEncoder().encode(coords)
    }

    // MARK: - Haptics

    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    // MARK: - Step flattening

    static func flattenSteps(session: WorkoutSession) -> [ExecutionStep] {
        var steps: [ExecutionStep] = []
        var globalIndex = 0

        let sortedBlocks = session.blocks.sorted { $0.sortOrder < $1.sortOrder }
        for block in sortedBlocks {
            let sortedExercises = block.exercises.sorted { $0.sortOrder < $1.sortOrder }
            for round in 1...max(1, block.rounds) {
                for (exerciseIdx, exercise) in sortedExercises.enumerated() {
                    steps.append(ExecutionStep(
                        id: UUID(),
                        exercise: exercise,
                        block: block,
                        round: round,
                        stepIndex: globalIndex,
                        isRest: false
                    ))
                    globalIndex += 1

                    // Insert rest step between exercises in interval circuits (not after the last one)
                    let isLastExercise = exerciseIdx == sortedExercises.count - 1
                    if block.hasIntervals && !isLastExercise {
                        // Create a placeholder "Rest" exercise for the rest period
                        let restExercise = Exercise(
                            name: "Rest",
                            instructions: "Active recovery — breathe, shake out your limbs.",
                            exerciseType: .timed,
                            durationSec: block.restIntervalSec,
                            sortOrder: -1
                        )
                        steps.append(ExecutionStep(
                            id: UUID(),
                            exercise: restExercise,
                            block: block,
                            round: round,
                            stepIndex: globalIndex,
                            isRest: true
                        ))
                        globalIndex += 1
                    }
                }
            }
        }
        return steps
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

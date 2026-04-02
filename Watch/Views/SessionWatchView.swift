import SwiftUI
import WatchKit

// Mirrors the active iPhone session OR drives a standalone Watch session.
struct SessionWatchView: View {

    var session: WorkoutSession? = nil
    var workoutManager: WorkoutSessionManager? = nil

    @Environment(WatchSessionController.self) private var controller
    @Environment(\.dismiss) private var dismiss

    // Local step driving (used when started from Watch independently)
    @State private var localSteps: [ExecutionStep] = []
    @State private var localIndex: Int = 0
    @State private var localTimeRemaining: Int = 0
    @State private var localIsRunning: Bool = false
    @State private var localTimer: Timer? = nil
    @State private var isStandaloneMode: Bool = false
    @State private var showGPS: Bool = false

    var body: some View {
        Group {
            if showGPS, let wm = workoutManager {
                GPSWatchView(manager: wm, onEnd: {
                    Task { await wm.stopWorkout() }
                    showGPS = false
                    advanceLocal()
                })
            } else {
                mainStepView
            }
        }
        .onAppear { setup() }
        .onDisappear { localTimer?.invalidate() }
    }

    // MARK: - Step view

    private var mainStepView: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Progress
                ProgressView(value: progressFraction)
                    .tint(.green)
                    .padding(.horizontal)
                    .accessibilityLabel("Workout progress")
                    .accessibilityValue("Step \(currentIndex + 1) of \(isStandaloneMode ? localSteps.count : controller.totalSteps)")

                // Block label
                Text(currentBlockName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                // Exercise name
                Text(currentExerciseName)
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(3)
                    .padding(.horizontal)
                    .accessibilityLabel("Current exercise: \(currentExerciseName)")

                // Round indicator
                if currentTotalRounds > 1 {
                    Text("Round \(currentRound)/\(currentTotalRounds)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Timer ring
                if currentTimeRemaining > 0 {
                    WatchTimerRing(timeRemaining: currentTimeRemaining,
                                   totalTime: currentTotalTime)
                        .frame(height: 80)
                        .accessibilityLabel("Time remaining: \(currentTimeRemaining) seconds")
                }

                // GPS launch button
                if isGPSStep {
                    Button {
                        launchGPS()
                    } label: {
                        Label("Start GPS", systemImage: "location.fill")
                    }
                    .tint(.green)
                }

                // Controls
                HStack(spacing: 12) {
                    Button {
                        previousStep()
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(currentIndex == 0)
                    .accessibilityLabel("Go to previous step")

                    Button {
                        togglePause()
                    } label: {
                        Image(systemName: isCurrentlyRunning ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isCurrentlyRunning ? .yellow : .green)
                    .accessibilityLabel(isCurrentlyRunning ? "Pause workout" : "Resume workout")

                    Button {
                        advanceLocal()
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip to next step")
                }
                .font(.title3)
                .padding(.top, 4)
            }
        }
        .navigationTitle("Session")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("End") {
                    localTimer?.invalidate()
                    dismiss()
                }
                .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Current state (resolves standalone vs mirrored)

    private var currentExerciseName: String {
        isStandaloneMode
            ? (localSteps[safe: localIndex]?.exercise.name ?? "")
            : controller.exerciseName
    }

    private var currentBlockName: String {
        isStandaloneMode
            ? (localSteps[safe: localIndex]?.block.name ?? "")
            : controller.blockName
    }

    private var currentTimeRemaining: Int {
        isStandaloneMode ? localTimeRemaining : controller.timeRemaining
    }

    private var currentTotalTime: Int {
        isStandaloneMode
            ? (localSteps[safe: localIndex]?.durationSec ?? 0)
            : 0   // unknown in mirror mode
    }

    private var currentRound: Int {
        isStandaloneMode
            ? (localSteps[safe: localIndex]?.round ?? 1)
            : controller.round
    }

    private var currentTotalRounds: Int {
        isStandaloneMode
            ? (localSteps[safe: localIndex]?.block.rounds ?? 1)
            : controller.totalRounds
    }

    private var progressFraction: Double {
        let total = isStandaloneMode ? localSteps.count : controller.totalSteps
        let idx   = isStandaloneMode ? localIndex : controller.currentStepIndex
        return total > 0 ? Double(idx) / Double(total) : 0
    }

    private var currentIndex: Int {
        isStandaloneMode ? localIndex : controller.currentStepIndex
    }

    private var isCurrentlyRunning: Bool {
        isStandaloneMode ? localIsRunning : controller.isRunning
    }

    private var isGPSStep: Bool {
        isStandaloneMode
            ? (localSteps[safe: localIndex]?.isGPS == true)
            : false
    }

    // MARK: - Setup

    private func setup() {
        if let session = session {
            // Standalone mode — launched from Watch independently
            isStandaloneMode = true
            localSteps = ExecutionStep.flattenSteps(session: session)
            localIndex = 0
            localIsRunning = true
            prepareLocalStep()
        }
        // Mirror mode: controller already receives updates from WatchConnectivity
    }

    // MARK: - Local step management

    private func prepareLocalStep() {
        localTimer?.invalidate()
        guard isStandaloneMode,
              let step = localSteps[safe: localIndex] else { return }
        localTimeRemaining = step.durationSec
        guard step.isTimed, localIsRunning else { return }
        WKInterfaceDevice.current().play(.start)
        localTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if localTimeRemaining > 1 {
                localTimeRemaining -= 1
            } else {
                advanceLocal()
            }
        }
    }

    private func advanceLocal() {
        localTimer?.invalidate()
        WKInterfaceDevice.current().play(.stop)
        if localIndex < localSteps.count - 1 {
            localIndex += 1
            prepareLocalStep()
        } else {
            WKInterfaceDevice.current().play(.success)
            localIsRunning = false
        }
    }

    private func previousStep() {
        guard localIndex > 0 else { return }
        localTimer?.invalidate()
        localIndex -= 1
        prepareLocalStep()
    }

    private func togglePause() {
        if isStandaloneMode {
            localIsRunning.toggle()
            if localIsRunning { prepareLocalStep() } else { localTimer?.invalidate() }
        }
    }

    private func launchGPS() {
        guard let wm = workoutManager,
              let step = localSteps[safe: localIndex] else { return }
        let activity: HKWorkoutActivityType = step.exercise.exerciseType == .gpsCycle
            ? .cycling : .running
        Task { await wm.startWorkout(activityType: activity) }
        showGPS = true
    }
}

// MARK: - Watch timer ring

private struct WatchTimerRing: View {
    let timeRemaining: Int
    let totalTime: Int

    private var fraction: Double {
        totalTime > 0 ? Double(timeRemaining) / Double(totalTime) : 1
    }

    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 6).foregroundStyle(.green.opacity(0.2))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
            Text(timeString)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
        }
        .padding(8)
    }

    private var timeString: String {
        let m = timeRemaining / 60; let s = timeRemaining % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)"
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

import HealthKit

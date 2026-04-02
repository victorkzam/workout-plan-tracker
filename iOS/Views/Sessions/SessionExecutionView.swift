import SwiftUI
import SwiftData

struct SessionExecutionView: View {

    let session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: SessionExecutionViewModel
    @State private var showGPS = false
    @State private var showEndConfirmation = false

    init(session: WorkoutSession) {
        self.session = session
        _viewModel = State(initialValue: SessionExecutionViewModel(
            session: session,
            locationService: LocationService(),
            healthKitService: HealthKitService()
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                if viewModel.isCompleted {
                    completionView
                } else if let step = viewModel.currentStep {
                    if step.isGPS && showGPS {
                        GPSRunView(
                            exercise: step.exercise,
                            locationService: viewModel.locationService,
                            healthKitService: viewModel.healthKitService,
                            onEnd: { showGPS = false; viewModel.skipToNext() }
                        )
                    } else {
                        ExerciseStepView(
                            step: step,
                            timeRemaining: viewModel.timeRemaining,
                            currentHR: viewModel.healthKitService.currentHeartRate,
                            isRunning: viewModel.isRunning
                        )
                        if step.isGPS && !showGPS {
                            gpsLaunchBanner
                                .padding(.horizontal)
                        }
                    }
                }

                Spacer(minLength: 0)
                controlBar
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog("End Session?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
                Button("End Session", role: .destructive) {
                    viewModel.endSession(modelContext: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your progress and any GPS data will be saved.")
            }
        }
        .task {
            await viewModel.healthKitService.requestAuthorization()
            viewModel.startSession()
        }
    }

    // MARK: - Sub-views

    private var progressBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: viewModel.progressFraction)
                .tint(.green)
            HStack {
                Text("Step \(viewModel.currentStepIndex + 1) of \(viewModel.totalSteps)")
                Spacer()
                Text(elapsedString)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout progress")
        .accessibilityValue("Step \(viewModel.currentStepIndex + 1) of \(viewModel.totalSteps), elapsed \(elapsedString)")
    }

    private var gpsLaunchBanner: some View {
        Button {
            showGPS = true
        } label: {
            Label("Open GPS Tracker", systemImage: "location.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .padding(.bottom, 8)
    }

    private var controlBar: some View {
        HStack(spacing: 24) {
            Button {
                viewModel.goToPrevious()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
            }
            .disabled(viewModel.currentStepIndex == 0)
            .accessibilityLabel("Go to previous step")

            Button {
                viewModel.isRunning ? viewModel.pauseSession() : viewModel.resumeSession()
            } label: {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(viewModel.isRunning ? .yellow : .green)
            }
            .accessibilityLabel(viewModel.isRunning ? "Pause workout" : "Start workout")

            Button {
                viewModel.skipToNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Skip to next step")
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("Session Complete!")
                .font(.title.bold())
            if viewModel.locationService.totalDistanceMeters > 10 {
                VStack(spacing: 8) {
                    Label(viewModel.locationService.distanceDisplayString, systemImage: "location.fill")
                    Label(viewModel.locationService.paceDisplayString, systemImage: "speedometer")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("End") { showEndConfirmation = true }
                .foregroundStyle(.red)
                .accessibilityLabel("End workout session")
        }
    }

    private var elapsedString: String {
        let t = Int(viewModel.elapsedTotal)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

import SwiftUI
import WatchKit

struct GPSWatchView: View {

    @ObservedObject var manager: WorkoutSessionManager
    var onEnd: () -> Void

    @State private var isPaused = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Pace
                metricRow(
                    label: "Pace",
                    value: manager.paceDisplayString,
                    icon: "speedometer",
                    color: .green
                )

                // Distance
                metricRow(
                    label: "Distance",
                    value: manager.distanceDisplayString,
                    icon: "location.fill",
                    color: .blue
                )

                // Time
                metricRow(
                    label: "Time",
                    value: manager.elapsedString,
                    icon: "clock",
                    color: .orange
                )

                // HR
                metricRow(
                    label: "HR",
                    value: manager.heartRate > 0 ? "\(Int(manager.heartRate)) bpm" : "-- bpm",
                    icon: "heart.fill",
                    color: .red
                )

                Divider()

                // Controls
                HStack(spacing: 12) {
                    Button {
                        isPaused.toggle()
                        isPaused ? manager.pauseWorkout() : manager.resumeWorkout()
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .foregroundStyle(isPaused ? .green : .yellow)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onEnd()
                    } label: {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .font(.title3)
            }
            .padding(.horizontal)
        }
        .navigationTitle("GPS Run")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricRow(label: String, value: String,
                           icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.semibold).monospacedDigit())
        }
    }
}

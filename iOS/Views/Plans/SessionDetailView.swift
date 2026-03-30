import SwiftUI

struct SessionDetailView: View {

    let session: WorkoutSession
    @State private var showExecution = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sessionHeader

                ForEach(session.blocks.sorted { $0.sortOrder < $1.sortOrder }) { block in
                    BlockPreviewView(block: block)
                }

                startButton
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showExecution) {
            SessionExecutionView(session: session)
        }
    }

    private var sessionHeader: some View {
        HStack(spacing: 16) {
            StatChip(icon: "clock", value: "\(session.totalMinutes) min")
            StatChip(icon: session.sessionType.systemImage, value: session.sessionType.displayName)
            StatChip(icon: "repeat", value: "\(session.blocks.count) blocks")
        }
    }

    private var startButton: some View {
        Button {
            showExecution = true
        } label: {
            Label("Start Session", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }
}

private struct BlockPreviewView: View {
    let block: WorkoutBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BlockTypeBadge(blockType: block.blockType)
                Text(block.name)
                    .font(.headline)
                Spacer()
                if block.rounds > 1 {
                    Text("\(block.rounds) rounds")
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if block.hasIntervals {
                Text("\(block.workIntervalSec)s on / \(block.restIntervalSec)s off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(block.exercises.sorted { $0.sortOrder < $1.sortOrder }) { exercise in
                ExercisePreviewRow(exercise: exercise)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ExercisePreviewRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(.secondary.opacity(0.3))
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(exercise.name).font(.subheadline.weight(.medium))
                    Spacer()
                    exerciseBadge
                }
                if !exercise.sideNote.isEmpty {
                    Text(exercise.sideNote).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var exerciseBadge: some View {
        if exercise.hasDuration {
            Text(formatSeconds(exercise.durationSec))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        } else if exercise.hasReps {
            Text("\(exercise.reps) reps")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if exercise.exerciseType.requiresGPS {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    private func formatSeconds(_ s: Int) -> String {
        s >= 60 ? "\(s / 60):\(String(format: "%02d", s % 60))" : "\(s)s"
    }
}

private struct StatChip: View {
    let icon: String
    let value: String

    var body: some View {
        Label(value, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.secondary.opacity(0.12))
            .clipShape(Capsule())
    }
}

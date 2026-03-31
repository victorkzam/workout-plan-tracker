import SwiftUI

struct SessionDetailWatchView: View {

    let session: WorkoutSession
    @State private var showExecution = false
    @State private var workoutManager = WorkoutSessionManager()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Label("\(session.totalMinutes) min", systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach((session.blocks ?? []).sorted { $0.sortOrder < $1.sortOrder }) { block in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(blockColor(block.blockType))
                            .frame(width: 6, height: 6)
                        Text(block.name)
                            .font(.caption)
                    }
                }

                Button("Start") {
                    showExecution = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle(session.dayLabel)
        .fullScreenCover(isPresented: $showExecution) {
            SessionWatchView(session: session, workoutManager: workoutManager)
        }
    }

    private func blockColor(_ type: BlockType) -> Color {
        switch type {
        case .warmup:   return .orange
        case .run:      return .green
        case .cycle:    return .cyan
        case .circuit:  return .red
        case .posture:  return .purple
        case .core:     return .indigo
        case .stretch:  return .teal
        case .cooldown: return .blue
        }
    }
}

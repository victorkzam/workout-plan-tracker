import SwiftUI
import SwiftData

struct SessionListWatchView: View {

    @Query(sort: \WorkoutPlan.createdAt, order: .reverse)
    private var plans: [WorkoutPlan]
    @Environment(WatchSessionController.self) private var controller

    var body: some View {
        NavigationStack {
            if controller.isSessionActive {
                // Show active session mirror
                NavigationLink(destination: SessionWatchView()) {
                    Label("Active Session", systemImage: "play.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if plans.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Open the iPhone app to import a plan")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(plans) { plan in
                        Section(plan.name) {
                            ForEach((plan.sessions ?? []).sorted { $0.sortOrder < $1.sortOrder }) { session in
                                NavigationLink(destination: SessionDetailWatchView(session: session)) {
                                    WatchSessionRow(session: session)
                                }
                            }
                        }
                    }
                }
                .listStyle(.carousel)
            }
        }
        .navigationTitle("Workouts")
    }
}

private struct WatchSessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.dayLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(session.name.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? session.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
            Text("\(session.totalMinutes) min")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

import SwiftUI

struct PlanDetailView: View {

    let plan: WorkoutPlan

    var body: some View {
        List {
            ForEach(plan.sessions.sorted { $0.sortOrder < $1.sortOrder }) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionRowView(session: session)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct SessionRowView: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.sessionType.systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(sessionColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(session.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Label(session.dayLabel, systemImage: "calendar")
                    Text("·")
                    Label("\(session.totalMinutes) min", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var sessionColor: Color {
        switch session.sessionType {
        case .run:      return .green
        case .cycle:    return .cyan
        case .strength: return .red
        case .mixed:    return .orange
        }
    }
}

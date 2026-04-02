import SwiftUI
import SwiftData

struct PlanListView: View {

    @Query(sort: \WorkoutPlan.createdAt, order: .reverse)
    private var plans: [WorkoutPlan]

    @Environment(\.modelContext) private var modelContext
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(plans) { plan in
                            NavigationLink(destination: PlanDetailView(plan: plan)) {
                                PlanRowView(plan: plan)
                            }
                            .accessibilityLabel("Workout plan: \(plan.name)")
                            .accessibilityValue("\((plan.sessions ?? []).count) sessions")
                        }
                        .onDelete(perform: deletePlans)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Workout Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showImport = true
                    } label: {
                        Label("Import Plan", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showImport) {
                PasteImportView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Plans Yet")
                .font(.title2.bold())
            Text("Tap + to paste and parse your first workout plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Import Plan") { showImport = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
        try? modelContext.save()
    }
}

private struct PlanRowView: View {
    let plan: WorkoutPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.name)
                .font(.headline)
            HStack {
                Text("\((plan.sessions ?? []).count) sessions")
                Text("·")
                Text(plan.createdAt.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

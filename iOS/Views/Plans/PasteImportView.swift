import SwiftUI
import SwiftData

struct PasteImportView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = PlanImportViewModel(
        openRouterAPIKey: Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String ?? ""
    )
    @State private var navigateToPlan: WorkoutPlan? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    labelSection
                    textEditorSection
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }
                    parseButton
                }
                .padding()
            }
            .navigationTitle("Import Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $navigateToPlan) { plan in
                PlanDetailView(plan: plan)
            }
        }
        .onChange(of: viewModel.parsedPlan) { _, plan in
            if let plan {
                navigateToPlan = plan
            }
        }
    }

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Paste your workout plan")
                .font(.headline)
            Text("The AI will extract sessions, exercises, timers, and targets automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var textEditorSection: some View {
        TextEditor(text: $viewModel.rawText)
            .frame(minHeight: 260)
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .font(.system(.body, design: .monospaced))
            .autocorrectionDisabled()
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
            }
        }
        .padding()
        .background(Color(.systemRed).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var parseButton: some View {
        Button {
            Task { await viewModel.parseWorkoutPlan(modelContext: modelContext) }
        } label: {
            HStack {
                if viewModel.isParsing {
                    ProgressView().tint(.white)
                    Text("Parsing…")
                } else {
                    Image(systemName: "sparkles")
                    Text("Parse with AI")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canParse)
    }
}

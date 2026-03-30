import Foundation
import SwiftData

@Observable
final class PlanImportViewModel {

    var rawText: String = ""
    var isParsing: Bool = false
    var errorMessage: String? = nil
    var parsedPlan: WorkoutPlan? = nil

    private let parserService: WorkoutParserService

    init(openRouterAPIKey: String) {
        self.parserService = WorkoutParserService(openRouterAPIKey: openRouterAPIKey)
    }

    var canParse: Bool { !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isParsing }

    @MainActor
    func parseWorkoutPlan(modelContext: ModelContext) async {
        errorMessage = nil
        isParsing = true
        defer { isParsing = false }

        await parserService.parse(rawText: rawText)

        switch parserService.state {
        case .success(let plan):
            modelContext.insert(plan)
            try? modelContext.save()
            parsedPlan = plan

        case .failure(let error):
            errorMessage = error.localizedDescription

        default:
            break
        }
    }

    func reset() {
        rawText = ""
        errorMessage = nil
        parsedPlan = nil
    }
}

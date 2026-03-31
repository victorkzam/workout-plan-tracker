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
            errorMessage = Self.userFriendlyMessage(for: error)

        default:
            break
        }
    }

    func reset() {
        rawText = ""
        errorMessage = nil
        parsedPlan = nil
    }

    private static func userFriendlyMessage(for error: Error) -> String {
        if let parserError = error as? ParserError {
            return parserError.localizedDescription
        }
        return "Unable to parse the workout plan. Please check the format or try again."
    }
}

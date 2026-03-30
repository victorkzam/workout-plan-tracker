import Foundation

// MARK: - WorkoutParserService
// Routes parsing to Apple Foundation Models (on-device, iOS 18+) or
// OpenRouter Gemini 2.0 Flash Lite (cloud fallback).

@Observable
final class WorkoutParserService {

    enum State {
        case idle
        case parsing
        case success(WorkoutPlan)
        case failure(Error)
    }

    private(set) var state: State = .idle

    private let openRouterAPIKey: String

    /// Approximate chars-per-token ratio for estimating token count without a tokenizer
    private let charsPerToken: Double = 4.0
    private let onDeviceTokenLimit = 3_500

    init(openRouterAPIKey: String) {
        self.openRouterAPIKey = openRouterAPIKey
    }

    @MainActor
    func parse(rawText: String) async {
        state = .parsing
        do {
            let plan = try await performParse(rawText: rawText)
            state = .success(plan)
        } catch {
            state = .failure(error)
        }
    }

    // MARK: - Private routing

    private func performParse(rawText: String) async throws -> WorkoutPlan {
        let estimatedTokens = Int(Double(rawText.count) / charsPerToken)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), estimatedTokens <= onDeviceTokenLimit {
            return try await parseOnDevice(rawText: rawText)
        }
        #endif

        return try await parseCloud(rawText: rawText)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func parseOnDevice(rawText: String) async throws -> WorkoutPlan {
        let parser = AppleFoundationParser()
        let parsed = try await parser.parse(rawText: rawText)
        return parsed.toWorkoutPlan(rawText: rawText)
    }
    #endif

    private func parseCloud(rawText: String) async throws -> WorkoutPlan {
        guard !openRouterAPIKey.isEmpty else {
            throw ParserError.onDeviceUnavailable
        }
        let parser = OpenRouterParser(apiKey: openRouterAPIKey)
        let parsed = try await parser.parse(rawText: rawText)
        return parsed.toWorkoutPlan(rawText: rawText)
    }
}

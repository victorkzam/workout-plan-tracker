import Foundation
import os

// MARK: - WorkoutParserService
// Routes parsing to Apple Foundation Models (on-device, iOS 26+) or
// OpenRouter GPT-OSS 120B (cloud fallback).

#if canImport(FoundationModels)
import FoundationModels
#endif

@Observable
final class WorkoutParserService: WorkoutParserProtocol {

    private(set) var state: ParserState = .idle

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
        Logger.parser.info("Token estimate: \(estimatedTokens), limit: \(self.onDeviceTokenLimit)")

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), estimatedTokens <= onDeviceTokenLimit {
            let availability = SystemLanguageModel.default.availability
            if availability == .available {
                do {
                    Logger.parser.info("Routing to on-device parser")
                    return try await parseOnDevice(rawText: rawText)
                } catch {
                    Logger.parser.warning("On-device parsing failed: \(error.localizedDescription, privacy: .public). Falling back to cloud.")
                    return try await parseCloud(rawText: rawText)
                }
            } else {
                Logger.parser.info("On-device model not available (status: \(String(describing: availability), privacy: .public)). Using cloud parser.")
            }
        }
        #endif

        Logger.parser.info("Routing to cloud parser")
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

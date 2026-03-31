import Foundation
import os

// MARK: - WorkoutParserService
// Routes parsing to Apple Foundation Models (on-device, iOS 26+) or
// OpenRouter Gemini 2.5 Flash Lite (cloud fallback).

#if canImport(FoundationModels)
import FoundationModels
#endif

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
    private let logger = Logger(subsystem: "com.workouttracker", category: "Parser")

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
            let availability = SystemLanguageModel.default.availability
            if availability == .available {
                do {
                    return try await parseOnDevice(rawText: rawText)
                } catch {
                    logger.warning("On-device parsing failed: \(error.localizedDescription, privacy: .public). Falling back to cloud.")
                    return try await parseCloud(rawText: rawText)
                }
            } else {
                logger.info("On-device model not available (status: \(String(describing: availability), privacy: .public)). Using cloud parser.")
            }
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

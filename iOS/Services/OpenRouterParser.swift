import Foundation
import os

// MARK: - OpenRouter / Gemini 2.5 Flash Lite parser

final class OpenRouterParser {

    private let apiKey: String
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    private let model   = "google/gemini-2.5-flash-lite"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func parse(rawText: String) async throws -> ParsedWorkoutPlan {
        Logger.parser.info("OpenRouter parse started, input length: \(rawText.count)")
        let body = buildRequestBody(rawText: rawText)
        let data = try await post(body: body)
        let plan = try extractPlan(from: data)
        Logger.parser.info("OpenRouter parse succeeded")
        return plan
    }

    // MARK: - Private

    private func buildRequestBody(rawText: String) -> [String: Any] {
        [
            "model": model,
            "max_tokens": 8192,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": rawText]
            ]
        ]
    }

    private func post(body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL) else {
            throw ParserError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod  = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)",  forHTTPHeaderField: "Authorization")
        request.setValue("WorkoutTracker/1.0", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            Logger.parser.error("OpenRouter HTTP error: \(code)")
            throw ParserError.httpError(code)
        }
        Logger.parser.info("OpenRouter response status: \(http.statusCode)")
        return data
    }

    private func extractPlan(from data: Data) throws -> ParsedWorkoutPlan {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ParserError.malformedResponse
        }

        // Strip markdown fences that some models add despite response_format: json_object
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let contentData = cleaned.data(using: .utf8) else {
            throw ParserError.malformedResponse
        }
        return try JSONDecoder().decode(ParsedWorkoutPlan.self, from: contentData)
    }
}

// MARK: - System prompt

private let systemPrompt = """
You are a workout plan parser. The user will provide a free-form text workout plan. \
Your task is to extract its structure and return a single JSON object conforming exactly to this schema:

{
  "name": "string — a short descriptive title for the overall plan",
  "sessions": [
    {
      "name": "string — full session name e.g. 'Session 1 — Monday: Easy Run + Core'",
      "dayLabel": "string — day of week e.g. 'Monday'",
      "totalMinutes": number,
      "sessionType": "run | cycle | strength | mixed",
      "blocks": [
        {
          "name": "string — block name e.g. 'Dynamic Warm-Up', 'Core Circuit'",
          "blockType": "warmup | run | cycle | circuit | posture | core | stretch | cooldown",
          "rounds": number (default 1),
          "workIntervalSec": number or null (seconds on, e.g. 45 for '45 sec on'),
          "restIntervalSec": number or null (seconds off, e.g. 15 for '15 sec off'),
          "exercises": [
            {
              "name": "string",
              "instructions": "string — full instructions including cues, form notes, modifications",
              "exerciseType": "timed | reps | distance | gpsRun | gpsCycle",
              "durationSec": number or null,
              "reps": number or null,
              "sets": number or null,
              "distanceMeters": number or null,
              "paceMinPerKmMin": number or null (lower bound as decimal min/km e.g. 5.833 for 5:50),
              "paceMinPerKmMax": number or null (upper bound as decimal min/km),
              "hrZoneMin": number or null (bpm),
              "hrZoneMax": number or null (bpm),
              "hrZoneName": "string or null e.g. 'Zone 2', 'Zone 4–5'",
              "rpeTarget": number or null (0–10 scale),
              "sideNote": "string or null e.g. 'per side', 'each leg'",
              "sortOrder": number (0-indexed)
            }
          ]
        }
      ]
    }
  ]
}

Rules:
- Running blocks (warmup jogs, easy runs, intervals, tempo, cool-down jogs): blockType="run", exerciseType="gpsRun"
- Cycling blocks: blockType="cycle", exerciseType="gpsCycle"
- Timed static exercises (planks, holds): exerciseType="timed", durationSec set
- Rep-based exercises: exerciseType="reps", reps set
- Distance-based runs (e.g. '4 × 1.5 km intervals'): exerciseType="gpsRun", distanceMeters set per rep
- Pace strings like '5:50–6:10/km': paceMinPerKmMin=5.833, paceMinPerKmMax=6.167
- HR bpm ranges map directly to hrZoneMin / hrZoneMax
- Include ALL instructional text in the instructions field
- Preserve every exercise; do not merge or omit any
- Return ONLY the JSON object with no markdown or commentary
"""

// MARK: - Errors

enum ParserError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case malformedResponse
    case onDeviceUnavailable
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid API URL."
        case .httpError(let code):   return "API error (HTTP \(code)). Please try again."
        case .malformedResponse:     return "Could not understand the workout plan. Please check the format and try again."
        case .onDeviceUnavailable:   return "On-device model is not available. Please update to iOS 26 or configure an API key."
        case .noAPIKey:              return "No API key configured. Add your OpenRouter key in Secrets.xcconfig."
        }
    }
}

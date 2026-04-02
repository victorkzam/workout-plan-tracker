import Foundation
@testable import WorkoutTracker

@Observable
@MainActor
final class MockWorkoutParser: WorkoutParserProtocol {

    // MARK: - Observable properties

    private(set) var state: WorkoutParserService.State = .idle

    // MARK: - Call tracking

    private(set) var parseCallCount = 0
    private(set) var lastRawText: String?

    // MARK: - Configurable behavior

    /// Set this to control what parse() does. If nil, state stays .idle.
    var parseResult: Result<WorkoutPlan, Error>?

    /// Alternative: provide a closure for full control.
    var parseHandler: ((String) async -> Void)?

    // MARK: - Protocol conformance

    func parse(rawText: String) async {
        parseCallCount += 1
        lastRawText = rawText

        if let handler = parseHandler {
            await handler(rawText)
            return
        }

        state = .parsing

        if let result = parseResult {
            switch result {
            case .success(let plan):
                state = .success(plan)
            case .failure(let error):
                state = .failure(error)
            }
        }
    }

    // MARK: - Test helpers

    func reset() {
        state = .idle
        parseCallCount = 0
        lastRawText = nil
        parseResult = nil
        parseHandler = nil
    }
}

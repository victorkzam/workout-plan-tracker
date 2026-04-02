import Foundation

/// Shared parsing state used by both the protocol and concrete service.
enum ParserState {
    case idle
    case parsing
    case success(WorkoutPlan)
    case failure(Error)
}

/// Protocol abstracting workout plan parsing for testability.
@MainActor
protocol WorkoutParserProtocol: AnyObject, Observable {
    var state: ParserState { get }

    func parse(rawText: String) async
}

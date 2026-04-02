import Foundation

/// Protocol abstracting workout plan parsing for testability.
@MainActor
protocol WorkoutParserProtocol: AnyObject, Observable {
    var state: WorkoutParserService.State { get }

    func parse(rawText: String) async
}

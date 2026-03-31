import Foundation
import SwiftData

enum SessionType: String, Codable, CaseIterable {
    case run       = "run"
    case cycle     = "cycle"
    case strength  = "strength"
    case mixed     = "mixed"

    var displayName: String {
        switch self {
        case .run:      return "Run"
        case .cycle:    return "Cycle"
        case .strength: return "Strength"
        case .mixed:    return "Mixed"
        }
    }

    var systemImage: String {
        switch self {
        case .run:      return "figure.run"
        case .cycle:    return "figure.outdoor.cycle"
        case .strength: return "dumbbell"
        case .mixed:    return "flame"
        }
    }
}

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var name: String = ""
    var dayLabel: String = ""
    var totalMinutes: Int = 0
    var sessionTypeRaw: String = SessionType.mixed.rawValue
    var sortOrder: Int = 0

    var plan: WorkoutPlan?

    @Relationship(deleteRule: .cascade)
    var blocks: [WorkoutBlock]?

    @Relationship(deleteRule: .cascade)
    var executions: [SessionExecution]?

    var sessionType: SessionType {
        get { SessionType(rawValue: sessionTypeRaw) ?? .mixed }
        set { sessionTypeRaw = newValue.rawValue }
    }

    init(name: String, dayLabel: String, totalMinutes: Int, sessionType: SessionType, sortOrder: Int) {
        self.id = UUID()
        self.name = name
        self.dayLabel = dayLabel
        self.totalMinutes = totalMinutes
        self.sessionTypeRaw = sessionType.rawValue
        self.sortOrder = sortOrder
        self.blocks = []
        self.executions = []
    }
}

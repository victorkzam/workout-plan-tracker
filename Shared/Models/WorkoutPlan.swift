import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var id: UUID = UUID()
    var name: String = ""
    var rawText: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade)
    var sessions: [WorkoutSession]?

    init(name: String, rawText: String) {
        self.id = UUID()
        self.name = name
        self.rawText = rawText
        self.createdAt = Date()
        self.sessions = []
    }
}

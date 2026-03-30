import Foundation
import SwiftData

@Model
final class SessionExecution {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var completedAt: Date? = nil
    var totalDistanceMeters: Double = 0
    var avgPaceSecPerKm: Double = 0
    var avgHeartRate: Double = 0
    var routeData: Data? = nil          // JSON-encoded [[Double]] (lat, lon, alt arrays)
    var durationSeconds: Double = 0

    var session: WorkoutSession?

    var isCompleted: Bool { completedAt != nil }

    var formattedDuration: String {
        let total = Int(durationSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    var formattedDistance: String {
        totalDistanceMeters >= 1000
            ? String(format: "%.2f km", totalDistanceMeters / 1000)
            : String(format: "%.0f m", totalDistanceMeters)
    }

    var formattedAvgPace: String {
        guard avgPaceSecPerKm > 0 else { return "--" }
        let m = Int(avgPaceSecPerKm) / 60
        let s = Int(avgPaceSecPerKm) % 60
        return String(format: "%d:%02d/km", m, s)
    }

    init(session: WorkoutSession) {
        self.id = UUID()
        self.startedAt = Date()
        self.session = session
    }
}

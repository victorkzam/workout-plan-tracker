import Foundation
import SwiftData

enum ExerciseType: String, Codable, CaseIterable {
    case timed    = "timed"
    case reps     = "reps"
    case distance = "distance"
    case gpsRun   = "gpsRun"
    case gpsCycle = "gpsCycle"

    var requiresGPS: Bool { self == .gpsRun || self == .gpsCycle }
    var isTimeBased: Bool { self == .timed || requiresGPS }
}

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var instructions: String = ""
    var exerciseTypeRaw: String = ExerciseType.timed.rawValue
    var durationSec: Int = 0
    var reps: Int = 0
    var sets: Int = 0
    var distanceMeters: Double = 0
    var paceMinPerKmMin: Double = 0      // lower bound (faster)
    var paceMinPerKmMax: Double = 0      // upper bound (slower)
    var hrZoneMin: Int = 0
    var hrZoneMax: Int = 0
    var hrZoneName: String = ""
    var rpeTarget: Double = 0
    var sideNote: String = ""            // "per side", "each leg"
    var sortOrder: Int = 0

    var block: WorkoutBlock?

    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRaw) ?? .timed }
        set { exerciseTypeRaw = newValue.rawValue }
    }

    var hasPaceTarget: Bool { paceMinPerKmMin > 0 || paceMinPerKmMax > 0 }
    var hasHRZone: Bool { hrZoneMin > 0 || hrZoneMax > 0 }
    var hasRPE: Bool { rpeTarget > 0 }
    var hasDuration: Bool { durationSec > 0 }
    var hasReps: Bool { reps > 0 }

    /// Human-readable pace string e.g. "5:50–6:10/km"
    var paceDisplayString: String? {
        guard hasPaceTarget else { return nil }
        let lo = paceMinPerKmMin > 0 ? formatPace(paceMinPerKmMin) : nil
        let hi = paceMinPerKmMax > 0 ? formatPace(paceMinPerKmMax) : nil
        switch (lo, hi) {
        case let (l?, h?): return "\(l)–\(h)/km"
        case let (l?, nil): return "\(l)/km"
        case let (nil, h?): return "\(h)/km"
        default: return nil
        }
    }

    private func formatPace(_ minPerKm: Double) -> String {
        let totalSec = Int(minPerKm * 60)
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%d:%02d", m, s)
    }

    init(name: String, instructions: String, exerciseType: ExerciseType,
         durationSec: Int = 0, reps: Int = 0, sets: Int = 0,
         distanceMeters: Double = 0,
         paceMinPerKmMin: Double = 0, paceMinPerKmMax: Double = 0,
         hrZoneMin: Int = 0, hrZoneMax: Int = 0, hrZoneName: String = "",
         rpeTarget: Double = 0, sideNote: String = "", sortOrder: Int) {
        self.id = UUID()
        self.name = name
        self.instructions = instructions
        self.exerciseTypeRaw = exerciseType.rawValue
        self.durationSec = durationSec
        self.reps = reps
        self.sets = sets
        self.distanceMeters = distanceMeters
        self.paceMinPerKmMin = paceMinPerKmMin
        self.paceMinPerKmMax = paceMinPerKmMax
        self.hrZoneMin = hrZoneMin
        self.hrZoneMax = hrZoneMax
        self.hrZoneName = hrZoneName
        self.rpeTarget = rpeTarget
        self.sideNote = sideNote
        self.sortOrder = sortOrder
    }
}

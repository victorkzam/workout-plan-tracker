import Foundation

// MARK: - Parsed structs used by both parsers

struct ParsedWorkoutPlan: Codable {
    var name: String
    var sessions: [ParsedSession]
}

struct ParsedSession: Codable {
    var name: String
    var dayLabel: String
    var totalMinutes: Int
    var sessionType: String      // "run" | "cycle" | "strength" | "mixed"
    var blocks: [ParsedBlock]
}

struct ParsedBlock: Codable {
    var name: String
    var blockType: String        // "warmup" | "run" | "cycle" | "circuit" | "posture" | "core" | "stretch" | "cooldown"
    var rounds: Int
    var workIntervalSec: Int?
    var restIntervalSec: Int?
    var exercises: [ParsedExercise]
}

struct ParsedExercise: Codable {
    var name: String
    var instructions: String
    var exerciseType: String     // "timed" | "reps" | "distance" | "gpsRun" | "gpsCycle"
    var durationSec: Int?
    var reps: Int?
    var sets: Int?
    var distanceMeters: Double?
    var paceMinPerKmMin: Double?
    var paceMinPerKmMax: Double?
    var hrZoneMin: Int?
    var hrZoneMax: Int?
    var hrZoneName: String?
    var rpeTarget: Double?
    var sideNote: String?
    var sortOrder: Int
}

// MARK: - Conversion helpers

extension ParsedWorkoutPlan {
    func toWorkoutPlan(rawText: String) -> WorkoutPlan {
        let plan = WorkoutPlan(name: name, rawText: rawText)
        plan.sessions = sessions.enumerated().map { idx, s in
            s.toSession(sortOrder: idx)
        }
        return plan
    }
}

extension ParsedSession {
    func toSession(sortOrder: Int) -> WorkoutSession {
        let type = SessionType(rawValue: sessionType) ?? .mixed
        let session = WorkoutSession(name: name, dayLabel: dayLabel,
                                     totalMinutes: totalMinutes,
                                     sessionType: type, sortOrder: sortOrder)
        session.blocks = blocks.enumerated().map { idx, b in
            b.toBlock(sortOrder: idx)
        }
        return session
    }
}

extension ParsedBlock {
    func toBlock(sortOrder: Int) -> WorkoutBlock {
        let type = BlockType(rawValue: blockType) ?? .circuit
        let block = WorkoutBlock(
            name: name,
            blockType: type,
            rounds: rounds,
            workIntervalSec: workIntervalSec ?? 0,
            restIntervalSec: restIntervalSec ?? 0,
            sortOrder: sortOrder
        )
        block.exercises = exercises.map { $0.toExercise() }
        return block
    }
}

extension ParsedExercise {
    func toExercise() -> Exercise {
        Exercise(
            name: name,
            instructions: instructions,
            exerciseType: ExerciseType(rawValue: exerciseType) ?? .timed,
            durationSec: durationSec ?? 0,
            reps: reps ?? 0,
            sets: sets ?? 0,
            distanceMeters: distanceMeters ?? 0,
            paceMinPerKmMin: paceMinPerKmMin ?? 0,
            paceMinPerKmMax: paceMinPerKmMax ?? 0,
            hrZoneMin: hrZoneMin ?? 0,
            hrZoneMax: hrZoneMax ?? 0,
            hrZoneName: hrZoneName ?? "",
            rpeTarget: rpeTarget ?? 0,
            sideNote: sideNote ?? "",
            sortOrder: sortOrder
        )
    }
}

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

    init(name: String, dayLabel: String, totalMinutes: Int, sessionType: String, blocks: [ParsedBlock]) {
        self.name = name
        self.dayLabel = dayLabel
        self.totalMinutes = totalMinutes
        self.sessionType = sessionType
        self.blocks = blocks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        dayLabel = try c.decodeIfPresent(String.self, forKey: .dayLabel) ?? ""
        totalMinutes = try c.decodeIfPresent(Int.self, forKey: .totalMinutes)
            ?? Int(try c.decodeIfPresent(Double.self, forKey: .totalMinutes) ?? 0)
        sessionType = try c.decodeIfPresent(String.self, forKey: .sessionType) ?? "mixed"
        blocks = try c.decodeIfPresent([ParsedBlock].self, forKey: .blocks) ?? []
    }
}

struct ParsedBlock: Codable {
    var name: String
    var blockType: String        // "warmup" | "run" | "cycle" | "circuit" | "posture" | "core" | "stretch" | "cooldown"
    var rounds: Int
    var workIntervalSec: Int?
    var restIntervalSec: Int?
    var exercises: [ParsedExercise]

    init(name: String, blockType: String, rounds: Int, workIntervalSec: Int?, restIntervalSec: Int?, exercises: [ParsedExercise]) {
        self.name = name
        self.blockType = blockType
        self.rounds = rounds
        self.workIntervalSec = workIntervalSec
        self.restIntervalSec = restIntervalSec
        self.exercises = exercises
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        blockType = try c.decodeIfPresent(String.self, forKey: .blockType) ?? "circuit"
        rounds = try c.decodeIfPresent(Int.self, forKey: .rounds)
            ?? Int(try c.decodeIfPresent(Double.self, forKey: .rounds) ?? 1)
        workIntervalSec = try c.decodeIfPresent(Int.self, forKey: .workIntervalSec)
        restIntervalSec = try c.decodeIfPresent(Int.self, forKey: .restIntervalSec)
        exercises = try c.decodeIfPresent([ParsedExercise].self, forKey: .exercises) ?? []
    }
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

    init(name: String, instructions: String, exerciseType: String,
         durationSec: Int?, reps: Int?, sets: Int?,
         distanceMeters: Double?, paceMinPerKmMin: Double?, paceMinPerKmMax: Double?,
         hrZoneMin: Int?, hrZoneMax: Int?, hrZoneName: String?,
         rpeTarget: Double?, sideNote: String?, sortOrder: Int) {
        self.name = name
        self.instructions = instructions
        self.exerciseType = exerciseType
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

    private enum CodingKeys: String, CodingKey {
        case name, instructions, exerciseType, durationSec, reps, sets
        case distanceMeters, paceMinPerKmMin, paceMinPerKmMax
        case hrZoneMin, hrZoneMax, hrZoneName, rpeTarget, sideNote, sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        exerciseType = try c.decodeIfPresent(String.self, forKey: .exerciseType) ?? "timed"
        durationSec = Self.optionalInt(from: c, key: .durationSec)
        reps = Self.optionalInt(from: c, key: .reps)
        sets = Self.optionalInt(from: c, key: .sets)
        distanceMeters = Self.optionalDouble(from: c, key: .distanceMeters)
        paceMinPerKmMin = Self.optionalDouble(from: c, key: .paceMinPerKmMin)
        paceMinPerKmMax = Self.optionalDouble(from: c, key: .paceMinPerKmMax)
        hrZoneMin = Self.optionalInt(from: c, key: .hrZoneMin)
        hrZoneMax = Self.optionalInt(from: c, key: .hrZoneMax)
        hrZoneName = try c.decodeIfPresent(String.self, forKey: .hrZoneName)
        rpeTarget = Self.optionalDouble(from: c, key: .rpeTarget)
        sideNote = try c.decodeIfPresent(String.self, forKey: .sideNote)
        sortOrder = Self.optionalInt(from: c, key: .sortOrder) ?? 0
    }

    /// Decodes an optional Int, falling back to Double → Int if the LLM returns a float.
    private static func optionalInt(from c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        if let v = try? c.decodeIfPresent(Int.self, forKey: key) { return v }
        if let v = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(v) }
        return nil
    }

    /// Decodes an optional Double, falling back to Int → Double if the LLM returns an integer.
    private static func optionalDouble(from c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let v = try? c.decodeIfPresent(Double.self, forKey: key) { return v }
        if let v = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(v) }
        return nil
    }
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

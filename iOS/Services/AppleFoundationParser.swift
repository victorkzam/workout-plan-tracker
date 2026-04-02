import Foundation
import os

// MARK: - Apple Foundation Models parser (iOS 18+)
// Uses the FoundationModels framework with @Generable for guaranteed structured output.

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct GenParsedWorkoutPlan {
    @Guide(description: "A short descriptive title for the overall plan")
    var name: String

    var sessions: [GenParsedSession]
}

@available(iOS 26.0, *)
@Generable
struct GenParsedSession {
    @Guide(description: "Full session name e.g. 'Session 1 — Monday: Easy Run + Core'")
    var name: String

    @Guide(description: "Day of week e.g. 'Monday'")
    var dayLabel: String

    @Guide(description: "Estimated total session duration in minutes")
    var totalMinutes: Int

    @Guide(description: "Session type: run, cycle, strength, or mixed")
    var sessionType: String

    var blocks: [GenParsedBlock]
}

@available(iOS 26.0, *)
@Generable
struct GenParsedBlock {
    @Guide(description: "Block name e.g. 'Dynamic Warm-Up', 'Core Circuit'")
    var name: String

    @Guide(description: "Block type: warmup, run, cycle, circuit, posture, core, stretch, or cooldown")
    var blockType: String

    @Guide(description: "Number of rounds (default 1)")
    var rounds: Int

    @Guide(description: "Work interval in seconds (e.g. 45 for '45 sec on'), or null")
    var workIntervalSec: Int?

    @Guide(description: "Rest interval in seconds (e.g. 15 for '15 sec off'), or null")
    var restIntervalSec: Int?

    var exercises: [GenParsedExercise]
}

@available(iOS 26.0, *)
@Generable
struct GenParsedExercise {
    var name: String
    var instructions: String

    @Guide(description: "Exercise type: timed, reps, distance, gpsRun, or gpsCycle")
    var exerciseType: String

    @Guide(description: "Duration in seconds for timed exercises")
    var durationSec: Int?

    @Guide(description: "Number of reps")
    var reps: Int?

    @Guide(description: "Number of sets")
    var sets: Int?

    @Guide(description: "Distance in meters for distance-based exercises")
    var distanceMeters: Double?

    @Guide(description: "Minimum (faster) pace in decimal min/km e.g. 5.833 for 5:50/km")
    var paceMinPerKmMin: Double?

    @Guide(description: "Maximum (slower) pace in decimal min/km e.g. 6.167 for 6:10/km")
    var paceMinPerKmMax: Double?

    @Guide(description: "Minimum heart rate in bpm")
    var hrZoneMin: Int?

    @Guide(description: "Maximum heart rate in bpm")
    var hrZoneMax: Int?

    @Guide(description: "Heart rate zone label e.g. 'Zone 2', 'Zone 4-5'")
    var hrZoneName: String?

    @Guide(description: "RPE target on 0-10 scale")
    var rpeTarget: Double?

    @Guide(description: "Side note e.g. 'per side', 'each leg'")
    var sideNote: String?

    var sortOrder: Int
}

@available(iOS 26.0, *)
final class AppleFoundationParser {

    private let session: LanguageModelSession

    init() {
        self.session = LanguageModelSession {
            "You are a workout plan parser."
            "Parse the following workout plan text into the requested structure."
            "Identify each session, its blocks (warmup, run, cycle, circuit, posture, core, stretch, cooldown), and all exercises."
            "For running/cycling exercises set exerciseType to 'gpsRun' or 'gpsCycle'."
            "Convert pace strings like '5:50-6:10/km' to decimal min/km values (5.833 and 6.167)."
            "Include all instructional text, cues, and form notes in the instructions field."
        }
    }

    func parse(rawText: String) async throws -> ParsedWorkoutPlan {
        Logger.parser.info("On-device parse started, input length: \(rawText.count)")
        let result = try await session.respond(
            to: rawText,
            generating: GenParsedWorkoutPlan.self
        )

        Logger.parser.info("On-device parse succeeded")
        return result.content.toParsedWorkoutPlan()
    }
}

// MARK: - Conversion from @Generable types to shared ParsedWorkoutPlan

@available(iOS 26.0, *)
extension GenParsedWorkoutPlan {
    func toParsedWorkoutPlan() -> ParsedWorkoutPlan {
        ParsedWorkoutPlan(
            name: name,
            sessions: sessions.map { $0.toParsedSession() }
        )
    }
}

@available(iOS 26.0, *)
extension GenParsedSession {
    func toParsedSession() -> ParsedSession {
        ParsedSession(
            name: name,
            dayLabel: dayLabel,
            totalMinutes: totalMinutes,
            sessionType: sessionType,
            blocks: blocks.map { $0.toParsedBlock() }
        )
    }
}

@available(iOS 26.0, *)
extension GenParsedBlock {
    func toParsedBlock() -> ParsedBlock {
        ParsedBlock(
            name: name,
            blockType: blockType,
            rounds: rounds,
            workIntervalSec: workIntervalSec,
            restIntervalSec: restIntervalSec,
            exercises: exercises.map { $0.toParsedExercise() }
        )
    }
}

@available(iOS 26.0, *)
extension GenParsedExercise {
    func toParsedExercise() -> ParsedExercise {
        ParsedExercise(
            name: name,
            instructions: instructions,
            exerciseType: exerciseType,
            durationSec: durationSec,
            reps: reps,
            sets: sets,
            distanceMeters: distanceMeters,
            paceMinPerKmMin: paceMinPerKmMin,
            paceMinPerKmMax: paceMinPerKmMax,
            hrZoneMin: hrZoneMin,
            hrZoneMax: hrZoneMax,
            hrZoneName: hrZoneName,
            rpeTarget: rpeTarget,
            sideNote: sideNote,
            sortOrder: sortOrder
        )
    }
}

#endif // canImport(FoundationModels)

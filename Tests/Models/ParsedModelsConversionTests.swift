import XCTest
@testable import WorkoutTracker

@MainActor
final class ParsedModelsConversionTests: XCTestCase {

    // MARK: - ParsedWorkoutPlan → WorkoutPlan

    func test_toWorkoutPlan_correctNameAndSessionCount() {
        let parsed = ParsedWorkoutPlan(
            name: "Week 1 Plan",
            sessions: [
                ParsedSession(name: "Monday Run", dayLabel: "Day 1",
                              totalMinutes: 45, sessionType: "run", blocks: []),
                ParsedSession(name: "Wednesday Strength", dayLabel: "Day 3",
                              totalMinutes: 60, sessionType: "strength", blocks: [])
            ]
        )

        let plan = parsed.toWorkoutPlan(rawText: "raw input")

        XCTAssertEqual(plan.name, "Week 1 Plan")
        XCTAssertEqual(plan.rawText, "raw input")
        XCTAssertEqual(plan.sessions?.count, 2)
    }

    // MARK: - ParsedSession → WorkoutSession

    func test_toSession_correctTypeAndBlockCount() {
        let parsed = ParsedSession(
            name: "Speed Work",
            dayLabel: "Day 2",
            totalMinutes: 40,
            sessionType: "run",
            blocks: [
                ParsedBlock(name: "Warm-up", blockType: "warmup", rounds: 1,
                            exercises: []),
                ParsedBlock(name: "Intervals", blockType: "run", rounds: 4,
                            workIntervalSec: 180, restIntervalSec: 60, exercises: [])
            ]
        )

        let session = parsed.toSession(sortOrder: 0)

        XCTAssertEqual(session.name, "Speed Work")
        XCTAssertEqual(session.dayLabel, "Day 2")
        XCTAssertEqual(session.totalMinutes, 40)
        XCTAssertEqual(session.sessionType, .run)
        XCTAssertEqual(session.blocks?.count, 2)
    }

    // MARK: - ParsedBlock → WorkoutBlock

    func test_toBlock_correctTypeAndExerciseCount() {
        let parsed = ParsedBlock(
            name: "Core Circuit",
            blockType: "circuit",
            rounds: 3,
            workIntervalSec: 40,
            restIntervalSec: 20,
            exercises: [
                ParsedExercise(name: "Plank", instructions: "Hold", exerciseType: "timed",
                               durationSec: 40, sortOrder: 0),
                ParsedExercise(name: "Crunches", instructions: "Standard", exerciseType: "reps",
                               reps: 15, sortOrder: 1)
            ]
        )

        let block = parsed.toBlock(sortOrder: 2)

        XCTAssertEqual(block.name, "Core Circuit")
        XCTAssertEqual(block.blockType, .circuit)
        XCTAssertEqual(block.rounds, 3)
        XCTAssertEqual(block.workIntervalSec, 40)
        XCTAssertEqual(block.restIntervalSec, 20)
        XCTAssertEqual(block.sortOrder, 2)
        XCTAssertEqual(block.exercises?.count, 2)
    }

    // MARK: - ParsedExercise → Exercise

    func test_toExercise_timedType_correctDuration() {
        let parsed = ParsedExercise(
            name: "Plank", instructions: "Hold steady", exerciseType: "timed",
            durationSec: 60, sortOrder: 0
        )

        let exercise = parsed.toExercise()

        XCTAssertEqual(exercise.name, "Plank")
        XCTAssertEqual(exercise.instructions, "Hold steady")
        XCTAssertEqual(exercise.exerciseType, .timed)
        XCTAssertEqual(exercise.durationSec, 60)
        XCTAssertEqual(exercise.reps, 0)
    }

    func test_toExercise_repsType_correctReps() {
        let parsed = ParsedExercise(
            name: "Push-ups", instructions: "Full range", exerciseType: "reps",
            reps: 15, sets: 3, sortOrder: 1
        )

        let exercise = parsed.toExercise()

        XCTAssertEqual(exercise.exerciseType, .reps)
        XCTAssertEqual(exercise.reps, 15)
        XCTAssertEqual(exercise.sets, 3)
        XCTAssertEqual(exercise.durationSec, 0)
    }

    func test_toExercise_unknownType_defaultsToTimed() {
        let parsed = ParsedExercise(
            name: "Mystery Move", instructions: "", exerciseType: "unknownType",
            sortOrder: 0
        )

        let exercise = parsed.toExercise()

        XCTAssertEqual(exercise.exerciseType, .timed)
    }

    func test_toExercise_gpsRunType_preservesPaceAndHRZone() {
        let parsed = ParsedExercise(
            name: "Tempo Run", instructions: "Steady pace", exerciseType: "gpsRun",
            durationSec: 1200,
            paceMinPerKmMin: 5.5, paceMinPerKmMax: 6.0,
            hrZoneMin: 140, hrZoneMax: 160, hrZoneName: "Zone 3",
            rpeTarget: 7, sortOrder: 0
        )

        let exercise = parsed.toExercise()

        XCTAssertEqual(exercise.exerciseType, .gpsRun)
        XCTAssertEqual(exercise.paceMinPerKmMin, 5.5, accuracy: 0.01)
        XCTAssertEqual(exercise.paceMinPerKmMax, 6.0, accuracy: 0.01)
        XCTAssertEqual(exercise.hrZoneMin, 140)
        XCTAssertEqual(exercise.hrZoneMax, 160)
        XCTAssertEqual(exercise.hrZoneName, "Zone 3")
        XCTAssertEqual(exercise.rpeTarget, 7, accuracy: 0.01)
        XCTAssertTrue(exercise.hasPaceTarget)
        XCTAssertTrue(exercise.hasHRZone)
        XCTAssertTrue(exercise.hasRPE)
    }

    func test_toExercise_nilOptionals_defaultToZeroOrEmpty() {
        let parsed = ParsedExercise(
            name: "Basic", instructions: "Do it", exerciseType: "timed",
            sortOrder: 5
        )

        let exercise = parsed.toExercise()

        XCTAssertEqual(exercise.durationSec, 0)
        XCTAssertEqual(exercise.reps, 0)
        XCTAssertEqual(exercise.sets, 0)
        XCTAssertEqual(exercise.distanceMeters, 0)
        XCTAssertEqual(exercise.paceMinPerKmMin, 0)
        XCTAssertEqual(exercise.paceMinPerKmMax, 0)
        XCTAssertEqual(exercise.hrZoneMin, 0)
        XCTAssertEqual(exercise.hrZoneMax, 0)
        XCTAssertEqual(exercise.hrZoneName, "")
        XCTAssertEqual(exercise.rpeTarget, 0)
        XCTAssertEqual(exercise.sideNote, "")
        XCTAssertEqual(exercise.sortOrder, 5)
    }
}

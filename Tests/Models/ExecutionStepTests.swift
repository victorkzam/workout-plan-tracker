import XCTest
@testable import WorkoutTracker

@MainActor
final class ExecutionStepTests: XCTestCase {

    // MARK: - Helpers

    private func makeSession(blocks: [WorkoutBlock]) -> WorkoutSession {
        let session = WorkoutSession(name: "Test Session", dayLabel: "Day 1",
                                     totalMinutes: 30, sessionType: .mixed, sortOrder: 0)
        session.blocks = blocks
        return session
    }

    private func makeBlock(
        name: String = "Block",
        blockType: BlockType = .circuit,
        rounds: Int = 1,
        workIntervalSec: Int = 0,
        restIntervalSec: Int = 0,
        sortOrder: Int = 0,
        exercises: [Exercise] = []
    ) -> WorkoutBlock {
        let block = WorkoutBlock(name: name, blockType: blockType, rounds: rounds,
                                 workIntervalSec: workIntervalSec, restIntervalSec: restIntervalSec,
                                 sortOrder: sortOrder)
        block.exercises = exercises
        return block
    }

    private func makeExercise(
        name: String = "Exercise",
        type: ExerciseType = .timed,
        durationSec: Int = 30,
        reps: Int = 0,
        sortOrder: Int = 0
    ) -> Exercise {
        Exercise(name: name, instructions: "", exerciseType: type,
                 durationSec: durationSec, reps: reps, sortOrder: sortOrder)
    }

    // MARK: - Tests

    func test_flattenSteps_singleBlockSingleExercise_returnsCorrectSteps() {
        let exercise = makeExercise(name: "Push-ups", durationSec: 30)
        let block = makeBlock(exercises: [exercise])
        let session = makeSession(blocks: [block])

        let steps = ExecutionStep.flattenSteps(session: session)

        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].exercise.name, "Push-ups")
        XCTAssertEqual(steps[0].round, 1)
        XCTAssertEqual(steps[0].stepIndex, 0)
        XCTAssertFalse(steps[0].isRest)
    }

    func test_flattenSteps_multipleRounds_insertsRestBetweenRounds() {
        let ex1 = makeExercise(name: "Squats", sortOrder: 0)
        let ex2 = makeExercise(name: "Lunges", sortOrder: 1)
        let block = makeBlock(rounds: 2, workIntervalSec: 30, restIntervalSec: 15,
                              exercises: [ex1, ex2])
        let session = makeSession(blocks: [block])

        let steps = ExecutionStep.flattenSteps(session: session)

        // Per round: exercise, rest, exercise (no rest after last exercise)
        // 2 rounds x (2 exercises + 1 rest) = 6 steps
        XCTAssertEqual(steps.count, 6)

        // Round 1
        XCTAssertEqual(steps[0].exercise.name, "Squats")
        XCTAssertFalse(steps[0].isRest)
        XCTAssertEqual(steps[0].round, 1)

        XCTAssertTrue(steps[1].isRest)
        XCTAssertEqual(steps[1].round, 1)

        XCTAssertEqual(steps[2].exercise.name, "Lunges")
        XCTAssertFalse(steps[2].isRest)
        XCTAssertEqual(steps[2].round, 1)

        // Round 2
        XCTAssertEqual(steps[3].exercise.name, "Squats")
        XCTAssertEqual(steps[3].round, 2)
    }

    func test_flattenSteps_emptySession_returnsEmpty() {
        let session = makeSession(blocks: [])

        let steps = ExecutionStep.flattenSteps(session: session)

        XCTAssertTrue(steps.isEmpty)
    }

    func test_flattenSteps_mixedExerciseTypes_correctOrdering() {
        let timedEx = makeExercise(name: "Plank", type: .timed, durationSec: 60, sortOrder: 0)
        let repsEx = makeExercise(name: "Push-ups", type: .reps, durationSec: 0, reps: 10, sortOrder: 1)
        let gpsEx = makeExercise(name: "Run", type: .gpsRun, durationSec: 300, sortOrder: 2)

        let block = makeBlock(exercises: [timedEx, repsEx, gpsEx])
        let session = makeSession(blocks: [block])

        let steps = ExecutionStep.flattenSteps(session: session)

        XCTAssertEqual(steps.count, 3)
        XCTAssertEqual(steps[0].exercise.name, "Plank")
        XCTAssertEqual(steps[1].exercise.name, "Push-ups")
        XCTAssertEqual(steps[2].exercise.name, "Run")
        XCTAssertTrue(steps[2].isGPS)
        XCTAssertFalse(steps[0].isGPS)
    }

    func test_flattenSteps_blockWithNoExercises_skipsBlock() {
        let emptyBlock = makeBlock(name: "Empty", sortOrder: 0, exercises: [])
        let populatedBlock = makeBlock(
            name: "Populated", sortOrder: 1,
            exercises: [makeExercise(name: "Curl")]
        )
        let session = makeSession(blocks: [emptyBlock, populatedBlock])

        let steps = ExecutionStep.flattenSteps(session: session)

        // The empty block produces no steps; only the populated block contributes
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].exercise.name, "Curl")
    }

    func test_flattenSteps_noRestAfterLastExerciseInRound() {
        let ex1 = makeExercise(name: "A", sortOrder: 0)
        let block = makeBlock(rounds: 1, workIntervalSec: 30, restIntervalSec: 15,
                              exercises: [ex1])
        let session = makeSession(blocks: [block])

        let steps = ExecutionStep.flattenSteps(session: session)

        // Single exercise, so no rest inserted even with intervals
        XCTAssertEqual(steps.count, 1)
        XCTAssertFalse(steps[0].isRest)
    }
}

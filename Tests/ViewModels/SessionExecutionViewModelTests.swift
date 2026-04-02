import XCTest
@testable import WorkoutTracker

@MainActor
final class SessionExecutionViewModelTests: XCTestCase {

    private var mockLocation: MockLocationService!
    private var mockHealthKit: MockHealthKitService!

    override func setUp() {
        super.setUp()
        mockLocation = MockLocationService()
        mockHealthKit = MockHealthKitService()
    }

    override func tearDown() {
        mockLocation = nil
        mockHealthKit = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSession(blocks: [WorkoutBlock] = []) -> WorkoutSession {
        let session = WorkoutSession(name: "Test", dayLabel: "Day 1",
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
                                 workIntervalSec: workIntervalSec,
                                 restIntervalSec: restIntervalSec,
                                 sortOrder: sortOrder)
        block.exercises = exercises
        return block
    }

    private func makeExercise(
        name: String = "Exercise",
        type: ExerciseType = .timed,
        durationSec: Int = 30,
        sortOrder: Int = 0
    ) -> Exercise {
        Exercise(name: name, instructions: "", exerciseType: type,
                 durationSec: durationSec, sortOrder: sortOrder)
    }

    private func makeViewModel(session: WorkoutSession) -> SessionExecutionViewModel {
        SessionExecutionViewModel(
            session: session,
            locationService: mockLocation,
            healthKitService: mockHealthKit
        )
    }

    // MARK: - Init

    func test_init_flattensStepsCorrectly() {
        let ex1 = makeExercise(name: "Push-ups", sortOrder: 0)
        let ex2 = makeExercise(name: "Squats", sortOrder: 1)
        let block = makeBlock(exercises: [ex1, ex2])
        let session = makeSession(blocks: [block])

        let vm = makeViewModel(session: session)

        XCTAssertEqual(vm.steps.count, 2)
        XCTAssertEqual(vm.steps[0].exercise.name, "Push-ups")
        XCTAssertEqual(vm.steps[1].exercise.name, "Squats")
        XCTAssertEqual(vm.currentStepIndex, 0)
        XCTAssertFalse(vm.isRunning)
        XCTAssertFalse(vm.isCompleted)
    }

    func test_init_emptySession_noSteps() {
        let session = makeSession(blocks: [])
        let vm = makeViewModel(session: session)

        XCTAssertTrue(vm.steps.isEmpty)
        XCTAssertEqual(vm.totalSteps, 0)
    }

    // MARK: - Start Session

    func test_startSession_setsIsRunning() {
        let ex = makeExercise(name: "Plank", durationSec: 60)
        let block = makeBlock(exercises: [ex])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        vm.startSession()

        XCTAssertTrue(vm.isRunning)
        XCTAssertFalse(vm.isCompleted)
    }

    func test_startSession_gpsStep_startsLocationService() {
        let gpsExercise = makeExercise(name: "Run", type: .gpsRun, durationSec: 600)
        let block = makeBlock(blockType: .run, exercises: [gpsExercise])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        vm.startSession()

        XCTAssertEqual(mockLocation.startCallCount, 1)
    }

    // MARK: - Advance Step

    func test_advanceStep_incrementsIndex() {
        let ex1 = makeExercise(name: "A", sortOrder: 0)
        let ex2 = makeExercise(name: "B", sortOrder: 1)
        let block = makeBlock(exercises: [ex1, ex2])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        vm.startSession()
        XCTAssertEqual(vm.currentStepIndex, 0)

        vm.skipToNext()
        XCTAssertEqual(vm.currentStepIndex, 1)
    }

    func test_advanceStep_atLastStep_completesSession() {
        let ex = makeExercise(name: "Only")
        let block = makeBlock(exercises: [ex])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        vm.startSession()
        vm.skipToNext()

        XCTAssertTrue(vm.isCompleted)
        XCTAssertFalse(vm.isRunning)
    }

    // MARK: - Pause / Resume

    func test_pauseResume_togglesRunningState() {
        let ex = makeExercise(name: "Plank", durationSec: 120)
        let block = makeBlock(exercises: [ex])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        vm.startSession()
        XCTAssertTrue(vm.isRunning)

        vm.pauseSession()
        XCTAssertFalse(vm.isRunning)

        vm.resumeSession()
        XCTAssertTrue(vm.isRunning)
    }

    func test_pauseSession_gpsStep_pausesLocationService() {
        let gpsExercise = makeExercise(name: "Run", type: .gpsRun, durationSec: 600)
        let block = makeBlock(blockType: .run, exercises: [gpsExercise])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        vm.startSession()
        vm.pauseSession()

        XCTAssertEqual(mockLocation.pauseCallCount, 1)
    }

    func test_resumeSession_gpsStep_resumesLocationService() {
        let gpsExercise = makeExercise(name: "Run", type: .gpsRun, durationSec: 600)
        let block = makeBlock(blockType: .run, exercises: [gpsExercise])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        vm.startSession()
        vm.pauseSession()
        vm.resumeSession()

        XCTAssertEqual(mockLocation.resumeCallCount, 1)
    }

    // MARK: - Go to Previous

    func test_goToPrevious_atFirstStep_doesNothing() {
        let ex = makeExercise(name: "Only")
        let block = makeBlock(exercises: [ex])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        vm.startSession()
        vm.goToPrevious()

        XCTAssertEqual(vm.currentStepIndex, 0)
    }

    func test_goToPrevious_atSecondStep_goesBack() {
        let ex1 = makeExercise(name: "A", sortOrder: 0)
        let ex2 = makeExercise(name: "B", sortOrder: 1)
        let block = makeBlock(exercises: [ex1, ex2])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        vm.startSession()
        vm.skipToNext()
        XCTAssertEqual(vm.currentStepIndex, 1)

        vm.goToPrevious()
        XCTAssertEqual(vm.currentStepIndex, 0)
    }

    // MARK: - Computed Properties

    func test_progressFraction_calculatesCorrectly() {
        let ex1 = makeExercise(name: "A", sortOrder: 0)
        let ex2 = makeExercise(name: "B", sortOrder: 1)
        let ex3 = makeExercise(name: "C", sortOrder: 2)
        let ex4 = makeExercise(name: "D", sortOrder: 3)
        let block = makeBlock(exercises: [ex1, ex2, ex3, ex4])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        XCTAssertEqual(vm.progressFraction, 0, accuracy: 0.001)

        vm.startSession()
        vm.skipToNext()
        // index 1 out of 4 total = 0.25
        XCTAssertEqual(vm.progressFraction, 0.25, accuracy: 0.001)
    }

    func test_progressFraction_emptySteps_returnsZero() {
        let session = makeSession(blocks: [])
        let vm = makeViewModel(session: session)

        XCTAssertEqual(vm.progressFraction, 0)
    }

    func test_currentStep_returnsCorrectStep() {
        let ex = makeExercise(name: "Plank")
        let block = makeBlock(exercises: [ex])
        let session = makeSession(blocks: [block])
        let vm = makeViewModel(session: session)

        XCTAssertEqual(vm.currentStep?.exercise.name, "Plank")
    }

    func test_currentStep_emptySteps_returnsNil() {
        let session = makeSession(blocks: [])
        let vm = makeViewModel(session: session)

        XCTAssertNil(vm.currentStep)
    }
}

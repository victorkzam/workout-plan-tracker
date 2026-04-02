import XCTest
import SwiftData
@testable import WorkoutTracker

@MainActor
final class SwiftDataPersistenceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: WorkoutPlan.self, WorkoutSession.self, WorkoutBlock.self,
            Exercise.self, SessionExecution.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Create

    func test_createWorkoutPlan_persistsCorrectly() throws {
        let plan = WorkoutPlan(name: "Week 1", rawText: "raw plan text")
        context.insert(plan)
        try context.save()

        let descriptor = FetchDescriptor<WorkoutPlan>()
        let plans = try context.fetch(descriptor)

        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.name, "Week 1")
        XCTAssertEqual(plans.first?.rawText, "raw plan text")
    }

    // MARK: - Cascade Delete

    func test_deleteWorkoutPlan_cascadeDeletesSessions() throws {
        let plan = WorkoutPlan(name: "Plan", rawText: "text")
        let session = WorkoutSession(name: "Session 1", dayLabel: "Day 1",
                                     totalMinutes: 30, sessionType: .run, sortOrder: 0)
        plan.sessions = [session]
        session.plan = plan

        context.insert(plan)
        try context.save()

        // Verify session exists
        let sessionsBefore = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessionsBefore.count, 1)

        // Delete plan
        context.delete(plan)
        try context.save()

        // Session should be cascade-deleted
        let sessionsAfter = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessionsAfter.count, 0)
    }

    // MARK: - Relationships

    func test_workoutSession_blockRelationship() throws {
        let plan = WorkoutPlan(name: "Plan", rawText: "text")
        let session = WorkoutSession(name: "Session", dayLabel: "Day 1",
                                     totalMinutes: 45, sessionType: .strength, sortOrder: 0)
        let block1 = WorkoutBlock(name: "Warm-Up", blockType: .warmup, sortOrder: 0)
        let block2 = WorkoutBlock(name: "Circuit", blockType: .circuit, rounds: 3, sortOrder: 1)

        session.blocks = [block1, block2]
        block1.session = session
        block2.session = session
        plan.sessions = [session]
        session.plan = plan

        context.insert(plan)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.blocks?.count, 2)

        let sorted = fetched.first?.blocks?.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(sorted?.first?.name, "Warm-Up")
        XCTAssertEqual(sorted?.first?.blockType, .warmup)
        XCTAssertEqual(sorted?.last?.name, "Circuit")
        XCTAssertEqual(sorted?.last?.rounds, 3)
    }

    func test_exercise_properties() throws {
        let plan = WorkoutPlan(name: "Plan", rawText: "text")
        let session = WorkoutSession(name: "Session", dayLabel: "Day 1",
                                     totalMinutes: 30, sessionType: .mixed, sortOrder: 0)
        let block = WorkoutBlock(name: "Core", blockType: .core, sortOrder: 0)

        let exercise = Exercise(
            name: "Plank",
            instructions: "Hold steady",
            exerciseType: .timed,
            durationSec: 60,
            reps: 0,
            sets: 1,
            sortOrder: 0
        )

        block.exercises = [exercise]
        exercise.block = block
        session.blocks = [block]
        block.session = session
        plan.sessions = [session]
        session.plan = plan

        context.insert(plan)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Plank")
        XCTAssertEqual(fetched.first?.instructions, "Hold steady")
        XCTAssertEqual(fetched.first?.exerciseType, .timed)
        XCTAssertEqual(fetched.first?.durationSec, 60)
        XCTAssertTrue(fetched.first?.hasDuration ?? false)
        XCTAssertFalse(fetched.first?.hasReps ?? true)
    }

    // MARK: - SessionExecution

    func test_sessionExecution_persistsWithSession() throws {
        let plan = WorkoutPlan(name: "Plan", rawText: "text")
        let session = WorkoutSession(name: "Run", dayLabel: "Day 1",
                                     totalMinutes: 40, sessionType: .run, sortOrder: 0)
        plan.sessions = [session]
        session.plan = plan

        let execution = SessionExecution(session: session)
        execution.durationSeconds = 2400
        execution.totalDistanceMeters = 5000
        execution.avgPaceSecPerKm = 288
        execution.completedAt = Date()

        session.executions = [execution]

        context.insert(plan)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SessionExecution>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.durationSeconds, 2400, accuracy: 0.01)
        XCTAssertEqual(fetched.first?.totalDistanceMeters, 5000, accuracy: 0.01)
        XCTAssertTrue(fetched.first?.isCompleted ?? false)
    }

    // MARK: - Delete block cascades exercises

    func test_deleteBlock_cascadeDeletesExercises() throws {
        let plan = WorkoutPlan(name: "Plan", rawText: "text")
        let session = WorkoutSession(name: "S", dayLabel: "D1",
                                     totalMinutes: 30, sessionType: .mixed, sortOrder: 0)
        let block = WorkoutBlock(name: "Block", blockType: .circuit, sortOrder: 0)
        let exercise = Exercise(name: "Curl", instructions: "", exerciseType: .reps,
                                reps: 10, sortOrder: 0)

        block.exercises = [exercise]
        exercise.block = block
        session.blocks = [block]
        block.session = session
        plan.sessions = [session]
        session.plan = plan

        context.insert(plan)
        try context.save()

        let exercisesBefore = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercisesBefore.count, 1)

        context.delete(block)
        try context.save()

        let exercisesAfter = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercisesAfter.count, 0)
    }
}

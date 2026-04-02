import XCTest
@testable import WorkoutTracker

@MainActor
final class WorkoutParserServiceTests: XCTestCase {

    // MARK: - Token estimation / routing

    func test_parse_emptyAPIKey_resultsInFailure() async {
        let service = WorkoutParserService(openRouterAPIKey: "")

        await service.parse(rawText: "Some workout plan text that is long enough to exceed on-device limits. " +
                            String(repeating: "x", count: 20_000))

        if case .failure(let error) = service.state {
            // Cloud parser should fail with onDeviceUnavailable when key is empty
            XCTAssertTrue(error.localizedDescription.count > 0)
        } else {
            XCTFail("Expected failure state when API key is empty and text exceeds on-device limit")
        }
    }

    func test_parse_setsStateToParsingThenResult() async {
        let service = WorkoutParserService(openRouterAPIKey: "")

        // Short text should still attempt a parse and result in some final state
        await service.parse(rawText: "Short plan")

        // After parse completes, state should not be .parsing
        if case .parsing = service.state {
            XCTFail("State should not remain .parsing after parse completes")
        }
    }

    func test_state_initiallyIdle() {
        let service = WorkoutParserService(openRouterAPIKey: "test-key")

        if case .idle = service.state {
            // Expected
        } else {
            XCTFail("Initial state should be .idle")
        }
    }
}

// MARK: - PlanImportViewModel Tests (uses WorkoutParserProtocol DI)

@MainActor
final class PlanImportViewModelTests: XCTestCase {

    private var mockParser: MockWorkoutParser!
    private var viewModel: PlanImportViewModel!

    override func setUp() {
        super.setUp()
        mockParser = MockWorkoutParser()
        viewModel = PlanImportViewModel(parserService: mockParser)
    }

    override func tearDown() {
        mockParser = nil
        viewModel = nil
        super.tearDown()
    }

    func test_canParse_emptyText_returnsFalse() {
        viewModel.rawText = ""
        XCTAssertFalse(viewModel.canParse)
    }

    func test_canParse_whitespaceOnly_returnsFalse() {
        viewModel.rawText = "   \n\t  "
        XCTAssertFalse(viewModel.canParse)
    }

    func test_canParse_withText_returnsTrue() {
        viewModel.rawText = "Monday: Run 5km"
        XCTAssertTrue(viewModel.canParse)
    }

    func test_reset_clearsAllState() {
        viewModel.rawText = "Some text"
        viewModel.errorMessage = "An error"

        viewModel.reset()

        XCTAssertEqual(viewModel.rawText, "")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.parsedPlan)
    }

    func test_parseWorkoutPlan_callsParserWithRawText() async throws {
        let plan = WorkoutPlan(name: "Test", rawText: "raw")
        mockParser.parseResult = .success(plan)
        viewModel.rawText = "My workout plan"

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutPlan.self, WorkoutSession.self, WorkoutBlock.self,
            Exercise.self, SessionExecution.self,
            configurations: config
        )
        let context = ModelContext(container)

        await viewModel.parseWorkoutPlan(modelContext: context)

        XCTAssertEqual(mockParser.parseCallCount, 1)
        XCTAssertEqual(mockParser.lastRawText, "My workout plan")
    }

    func test_parseWorkoutPlan_onSuccess_setsParsedPlan() async throws {
        let plan = WorkoutPlan(name: "Parsed Plan", rawText: "raw")
        mockParser.parseResult = .success(plan)
        viewModel.rawText = "Some text"

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutPlan.self, WorkoutSession.self, WorkoutBlock.self,
            Exercise.self, SessionExecution.self,
            configurations: config
        )
        let context = ModelContext(container)

        await viewModel.parseWorkoutPlan(modelContext: context)

        XCTAssertNotNil(viewModel.parsedPlan)
        XCTAssertEqual(viewModel.parsedPlan?.name, "Parsed Plan")
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_parseWorkoutPlan_onFailure_setsErrorMessage() async throws {
        let testError = NSError(domain: "test", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Parse failed"])
        mockParser.parseResult = .failure(testError)
        viewModel.rawText = "Bad input"

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutPlan.self, WorkoutSession.self, WorkoutBlock.self,
            Exercise.self, SessionExecution.self,
            configurations: config
        )
        let context = ModelContext(container)

        await viewModel.parseWorkoutPlan(modelContext: context)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Parse failed")
        XCTAssertNil(viewModel.parsedPlan)
    }

    func test_parseWorkoutPlan_setsIsParsingFalseWhenDone() async throws {
        mockParser.parseResult = .success(WorkoutPlan(name: "P", rawText: "r"))
        viewModel.rawText = "Text"

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutPlan.self, WorkoutSession.self, WorkoutBlock.self,
            Exercise.self, SessionExecution.self,
            configurations: config
        )
        let context = ModelContext(container)

        await viewModel.parseWorkoutPlan(modelContext: context)

        XCTAssertFalse(viewModel.isParsing)
    }
}

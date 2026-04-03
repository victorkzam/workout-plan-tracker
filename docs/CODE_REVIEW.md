# Code Review: WorkoutTracker

## Summary

WorkoutTracker is a well-structured iOS 17+ / watchOS 10+ fitness app that parses free-form workout plans via AI (on-device Apple Foundation Models or OpenRouter cloud fallback), then guides users through timed/GPS workout sessions with HealthKit integration and Watch mirroring. The codebase is clean and readable at ~3,400 LOC, but has several crash-risk issues around force-unwraps in app startup, race conditions on `@Observable` state mutated from background threads, orphaned SwiftData objects from the parser, and hard singleton dependencies that block testability.

## Critical Issues

### C1. Force-unwrap crash on ModelContainer fallback initialization

- **File**: `iOS/App/WorkoutTrackerApp.swift`, line 25; `Watch/WatchApp.swift`, line 23
- **Issue**: If the primary CloudKit-backed `ModelContainer` initializer fails, the fallback uses `try!`. If the fallback also fails (e.g., disk full, schema migration conflict), the app crashes on launch with no recovery path.
- **Suggestion**: Wrap in a `do/catch`, log the error, and present an error UI or fall back to in-memory storage as a last resort:
  ```swift
  do {
      return try ModelContainer(for: schema, configurations: [localConfig])
  } catch {
      // Last resort: in-memory so the app at least launches
      let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
      return try! ModelContainer(for: schema, configurations: [memConfig])
  }
  ```

### C2. Rest Exercise objects created in `flattenSteps` are not inserted into SwiftData context

- **File**: `Shared/Models/ExecutionStep.swift`, lines 45-51
- **Issue**: `flattenSteps` creates `Exercise` objects (for rest intervals) using the `@Model` initializer but never inserts them into a `ModelContext`. These orphan `@Model` instances may exhibit undefined behavior with SwiftData -- they are unmanaged model objects that could crash when accessed if SwiftData attempts to fault them. Additionally, each call to `flattenSteps` generates new `UUID`s, so the step list is never stable across calls.
- **Suggestion**: Either (a) make `ExecutionStep` hold a lightweight value-type struct for rest info instead of an `Exercise` model object, or (b) explicitly insert rest exercises into the context and clean them up afterward.

### C3. Timer closure captures `self` (a struct's mutable state) in `SessionWatchView`

- **File**: `Watch/Views/SessionWatchView.swift`, lines 205-210
- **Issue**: `prepareLocalStep()` creates a `Timer.scheduledTimer` closure that directly reads and writes `localTimeRemaining` and calls `advanceLocal()`. In a SwiftUI `View` (which is a struct), this closure captures a copy of `self`. Mutations to `localTimeRemaining` inside the timer closure will not update the `@State` property. The timer countdown will appear frozen on the Watch.
- **Suggestion**: Refactor the local step-driving logic into an `@Observable` class (similar to `SessionExecutionViewModel` on iOS) so that timer closures can use `[weak self]` and mutations are observed correctly.

## High Severity

### H1. `@Observable` properties mutated from background threads without synchronization

- **File**: `iOS/Services/LocationService.swift`, lines 100-122
- **Issue**: `CLLocationManagerDelegate.locationManager(_:didUpdateLocations:)` is called on an arbitrary thread, but it directly mutates `@Observable` properties (`route`, `totalDistanceMeters`, `currentPaceSecPerKm`, `recentSpeeds`, `previousLocation`) without dispatching to the main thread. `@Observable` uses `withObservationTracking` which is not thread-safe. This causes undefined behavior and potential data races.
- **Suggestion**: Dispatch all property mutations to `DispatchQueue.main.async` or use `@MainActor` isolation on the class.

### H2. Same race condition in Watch `WorkoutSessionManager`

- **File**: `Watch/Services/WorkoutSessionManager.swift`, lines 190-206
- **Issue**: `locationManager(_:didUpdateLocations:)` mutates `route`, `distance`, `currentPaceSecPerKm` etc. on a background thread. The heart rate update at line 177-181 correctly dispatches to main, but GPS data does not.
- **Suggestion**: Wrap GPS location handler mutations in `DispatchQueue.main.async`.

### H3. API key embedded via Info.plist / xcconfig with no protection

- **File**: `iOS/Views/Plans/PasteImportView.swift`, line 10; `project.yml`, line 41
- **Issue**: The OpenRouter API key is read from `Bundle.main.object(forInfoDictionaryKey:)`, sourced from `Secrets.xcconfig`. If `Secrets.xcconfig` is committed to version control, the key is exposed. Even if not committed, keys in Info.plist are trivially extractable from the IPA binary.
- **Suggestion**: Use a server-side proxy for API calls, or at minimum use obfuscation and runtime retrieval from a secure keychain/config service. Add `Secrets.xcconfig` to `.gitignore` if not already done.

### H4. `WatchConnectivityManager` singleton prevents testability and creates hidden coupling

- **File**: `Shared/Services/WatchConnectivityManager.swift`, line 38
- **Issue**: `WatchConnectivityManager.shared` is a hard singleton used directly in `SessionExecutionViewModel` (line 170), `WatchSessionController` (line 64), and `WorkoutSessionManager` (line 125). This makes unit testing impossible without swizzling, and creates hidden dependencies.
- **Suggestion**: Define a protocol (e.g., `MessageSending`) and inject it into consumers via initializer parameters.

### H5. `HealthKitService` is created inline in view init, not injected

- **File**: `iOS/Views/Sessions/SessionExecutionView.swift`, lines 16-19
- **Issue**: `SessionExecutionView.init` creates concrete `LocationService()` and `HealthKitService()` instances. These are not injectable for testing and create new instances every time the view struct is recreated by SwiftUI (though `@State` mitigates repeated creation). More importantly, this tightly couples the view to concrete implementations.
- **Suggestion**: Accept these as parameters or use environment injection.

### H6. `onMessageReceived` closure on singleton is overwritten by last subscriber

- **File**: `Shared/Services/WatchConnectivityManager.swift`, line 46; `Watch/WatchApp.swift`, line 64
- **Issue**: `WatchConnectivityManager.shared.onMessageReceived` is a single closure. If multiple objects set it (e.g., `WatchSessionController` and potentially other listeners), the last one wins and previous listeners are silently lost.
- **Suggestion**: Replace with a multicast pattern (e.g., an array of closures, `NotificationCenter`, or Combine publisher).

### H7. No timeout or cancellation on OpenRouter network request

- **File**: `iOS/Services/OpenRouterParser.swift`, lines 34-50
- **Issue**: The `URLSession.shared.data(for:)` call has no timeout configured. On a slow or unresponsive network, the user will see an indefinite "Parsing..." spinner with no way to cancel.
- **Suggestion**: Set `request.timeoutInterval` (e.g., 30 seconds) and wire up `Task` cancellation to the view model so the user can cancel.

## Medium Severity

### M1. Silent `try?` swallows save errors throughout the codebase

- **File**: `iOS/ViewModels/PlanImportViewModel.swift`, line 31; `iOS/ViewModels/SessionExecutionViewModel.swift`, line 191; `iOS/Views/Plans/PlanListView.swift`, line 66
- **Issue**: `try? modelContext.save()` silently discards errors. If a save fails (constraint violation, disk full, CloudKit sync issue), the user sees no error and believes their data was saved.
- **Suggestion**: Wrap in `do/catch` and surface errors to the UI or at minimum log them.

### M2. Duplicated pace/distance formatting logic across 4+ files

- **File**: `Shared/Models/Exercise.swift` (lines 60-65), `Shared/Models/SessionExecution.swift` (lines 27-38), `iOS/Services/LocationService.swift` (lines 71-82), `iOS/Views/Components/PaceDisplay.swift` (lines 53-56), `Watch/Services/WorkoutSessionManager.swift` (lines 136-152)
- **Issue**: Pace formatting (`m:ss /km`) and distance formatting (`X.XX km` / `X m`) are reimplemented in at least 4-5 separate locations with slight variations (e.g., space before `/km` differs).
- **Suggestion**: Extract into a shared `Formatters` utility with static methods and use consistently.

### M3. Duplicated block-color mapping in 3 places

- **File**: `Shared/Models/WorkoutBlock.swift` (lines 28-38), `iOS/Views/Components/HRZoneTag.swift` (`BlockTypeBadge`, lines 74-85), `Watch/Views/SessionDetailWatchView.swift` (lines 41-52)
- **Issue**: The block-type-to-color mapping is defined three times with string-based color names in the model and `Color` values in two different views.
- **Suggestion**: Consolidate into a single computed property on `BlockType` that returns a `Color`.

### M4. Duplicated `Array.subscript(safe:)` extension

- **File**: `iOS/ViewModels/SessionExecutionViewModel.swift`, lines 214-217; `Watch/Views/SessionWatchView.swift`, lines 282-284
- **Issue**: The same safe-subscript extension is defined twice as `private`.
- **Suggestion**: Move to a single shared extension in the `Shared` module.

### M5. `LocationService` sets `allowsBackgroundLocationUpdates = true` unconditionally

- **File**: `iOS/Services/LocationService.swift`, line 26
- **Issue**: Setting `allowsBackgroundLocationUpdates = true` in `init()` means this flag is set even when no workout is active. This can trigger unnecessary App Store review scrutiny and may cause unexpected battery drain if the location manager starts updating for any reason.
- **Suggestion**: Set it to `true` only in `start()` and back to `false` in `stop()`.

### M6. `HealthKitService.startWorkoutSession` silently falls through on error

- **File**: `iOS/Services/HealthKitService.swift`, lines 55-67
- **Issue**: If `HKWorkoutSession` init or `beginCollection` throws, the error is silently caught and only `startHeartRateUpdates()` runs. The user gets no indication that HealthKit workout tracking failed (no calories/active energy will be recorded).
- **Suggestion**: Propagate the error or set an observable error state.

### ~~M6b. HealthKit read authorization missing `workoutType` — FIXED~~

- **File**: `iOS/Services/HealthKitService.swift`, line 27
- **Issue**: `typesToRead` included `HKSeriesType.workoutRoute()` but not `HKObjectType.workoutType()`. HealthKit requires read access to workouts when requesting workout routes, and threw an uncaught `NSInvalidArgumentException` that crashed the app every time the session tracker opened.
- **Fix**: Added `HKObjectType.workoutType()` to `typesToRead` (commit 53779b8).

### M7. `SessionExecution.avgHeartRate` stores only the instantaneous HR at session end

- **File**: `iOS/ViewModels/SessionExecutionViewModel.swift`, line 188
- **Issue**: `exec.avgHeartRate = healthKitService.currentHeartRate` stores whatever the heart rate happened to be at the moment `endSession` was called, not the actual average over the session.
- **Suggestion**: Accumulate HR samples over the session and compute a true average, or query HealthKit for the average over the workout time range.

### M8. `encodeRoute` uses `locationService.route` instead of the `locations` parameter

- **File**: `iOS/ViewModels/SessionExecutionViewModel.swift`, lines 194-200
- **Issue**: The method accepts a `locations` parameter but then ignores it and reads `locationService.route` directly on lines 197-198. The `guard` check also uses `locationService.route` rather than the passed argument.
- **Suggestion**: Use the `locations` parameter consistently.

### M9. `PasteImportView` navigation after parse is fragile

- **File**: `iOS/Views/Plans/PasteImportView.swift`, lines 34-42
- **Issue**: After a successful parse, navigation relies on `onChange(of: viewModel.parsedPlan)` and `navigationDestination(item:)`. But `parsedPlan` is a SwiftData `@Model` object, and its identity for navigation binding depends on the `Identifiable` conformance. If the plan's `id` changes or the view is recreated, navigation may fail silently.
- **Suggestion**: Use a simpler boolean flag or dedicated navigation state enum.

### M10. `HRZoneTag` uses `AnyView` type erasure unnecessarily

- **File**: `iOS/Views/Components/HRZoneTag.swift`, lines 8-21
- **Issue**: The body returns `AnyView(EmptyView())` or `AnyView(HStack { ... })`. This defeats SwiftUI's view diffing optimization.
- **Suggestion**: Use `@ViewBuilder` on the body or restructure with `if/else` to avoid `AnyView`.

### M11. Parser conversion does not validate enum raw values from LLM output

- **File**: `iOS/Services/ParsedModels.swift`, lines 59, 72, 91
- **Issue**: `SessionType(rawValue: sessionType) ?? .mixed`, `BlockType(rawValue: blockType) ?? .circuit`, etc. silently default when the LLM returns an unexpected string. The user has no visibility into parsing quality.
- **Suggestion**: Log or surface warnings when fallback defaults are used, so users know if the parse was incomplete.

## Low Severity

### L1. `BlockType.accentColor` returns `String` instead of `Color`

- **File**: `Shared/Models/WorkoutBlock.swift`, lines 27-38
- **Issue**: `accentColor` returns a string like `"orange"` that no caller uses directly (views use their own `Color` mappings). It is dead code.
- **Suggestion**: Remove or replace with a `Color` computed property.

### L2. `SessionWatchView` imports `HealthKit` at file scope bottom

- **File**: `Watch/Views/SessionWatchView.swift`, line 286; `iOS/Views/Sessions/GPSRunView.swift`, line 197
- **Issue**: `import HealthKit` appears at the bottom of the file instead of at the top with other imports. This is unconventional and easy to miss.
- **Suggestion**: Move imports to the top of the file.

### L3. `WatchApp.swift` has `WatchSessionController` class embedded in the app entry point

- **File**: `Watch/WatchApp.swift`, lines 44-133
- **Issue**: `WatchSessionController` is a substantial ~90-line class defined in the same file as the `@main` app struct. This reduces discoverability.
- **Suggestion**: Extract to its own file (e.g., `Watch/Services/WatchSessionController.swift`).

### L4. `SessionListWatchView` layout issue: active session link is outside the conditional flow

- **File**: `Watch/Views/SessionListWatchView.swift`, lines 11-17
- **Issue**: The `NavigationLink` for the active session and the `if plans.isEmpty` / `else` block are siblings inside the `NavigationStack`. When there is an active session and no plans, both the active session link and the empty state show simultaneously but outside a `List`, leading to inconsistent layout.
- **Suggestion**: Wrap the entire content in a single conditional structure or `List`.

### L5. `.listStyle(.carousel)` is deprecated on watchOS 10+

- **File**: `Watch/Views/SessionListWatchView.swift`, line 43
- **Issue**: `.carousel` list style was deprecated in watchOS 10. The default list style is preferred.
- **Suggestion**: Remove `.listStyle(.carousel)` or use `.automatic`.

### L6. `isPlistCompatible` check is incomplete

- **File**: `Shared/Services/WatchConnectivityManager.swift`, lines 77-80
- **Issue**: The check does not include `Array` or `Dictionary` of plist-compatible types, which are valid for `updateApplicationContext`. This means valid messages containing arrays or nested dictionaries will be silently stripped.
- **Suggestion**: Add recursive checks for `[Any]` and `[String: Any]` containing plist-compatible values.

### L7. Magic number for HR unit

- **File**: `iOS/Services/HealthKitService.swift`, line 111; `Watch/Services/WorkoutSessionManager.swift`, line 180
- **Issue**: `HKUnit(from: "count/min")` uses a string literal. While correct, it is fragile and not discoverable.
- **Suggestion**: Use `HKUnit.count().unitDivided(by: .minute())` for type safety.

### L8. Unused `currentMinPerKm` property outside `paceColor`

- **File**: `iOS/Views/Components/PaceDisplay.swift`, line 8
- **Issue**: `currentMinPerKm` is a private computed property used only in `paceColor`. It could be inlined for clarity, though this is minor.
- **Suggestion**: Keep or inline; no action strictly needed.

## Testability Blockers

### T1. `WatchConnectivityManager.shared` singleton

- **File**: `Shared/Services/WatchConnectivityManager.swift`, line 38
- **Issue**: Hard singleton used directly in `SessionExecutionViewModel`, `WatchSessionController`, and `WorkoutSessionManager`. Cannot be replaced with a mock in tests.
- **Suggestion**: Define a `protocol MessageSender { func sendMessage(_ message: [String: Any]) }` and inject via initializer.

### T2. `HKHealthStore` and `CLLocationManager` are created internally

- **File**: `iOS/Services/HealthKitService.swift`, line 7; `iOS/Services/LocationService.swift`, line 13
- **Issue**: Both services create their Apple framework dependencies internally with no protocol abstraction. Unit tests cannot run without a real HealthKit/CoreLocation stack (which requires a device).
- **Suggestion**: Wrap `HKHealthStore` and `CLLocationManager` behind protocols and inject.

### T3. `SessionExecutionViewModel` has no protocol abstraction for its dependencies

- **File**: `iOS/ViewModels/SessionExecutionViewModel.swift`, lines 27-28
- **Issue**: `locationService: LocationService` and `healthKitService: HealthKitService` are concrete types. While they are injected (good), they cannot be mocked without protocols.
- **Suggestion**: Define `LocationServiceProtocol` and `HealthKitServiceProtocol` and depend on those.

### T4. `WorkoutParserService` creates parsers internally

- **File**: `iOS/Services/WorkoutParserService.swift`, lines 57, 67
- **Issue**: `AppleFoundationParser()` and `OpenRouterParser(apiKey:)` are instantiated directly inside `performParse`. The parser service cannot be tested without making real API calls or having FoundationModels available.
- **Suggestion**: Inject parser implementations via protocol.

### T5. `PlanImportViewModel` creates `WorkoutParserService` in its init

- **File**: `iOS/ViewModels/PlanImportViewModel.swift`, line 15
- **Issue**: Concrete `WorkoutParserService` is created in the initializer. Cannot inject a mock parser for view model tests.
- **Suggestion**: Accept a protocol-typed parser service as an init parameter.

### T6. `UINotificationFeedbackGenerator` called directly in view model

- **File**: `iOS/ViewModels/SessionExecutionViewModel.swift`, lines 205-207
- **Issue**: Haptic feedback is triggered directly via UIKit. This couples the view model to UIKit and makes tests noisy.
- **Suggestion**: Abstract behind a `HapticFeedback` protocol or closure.

### T7. No SwiftData `ModelContainer` injection for tests

- **File**: `iOS/App/WorkoutTrackerApp.swift`, lines 7-27
- **Issue**: The `ModelContainer` is created as a private `let` constant in the app struct. There is no way to provide an in-memory test container for unit tests against models.
- **Suggestion**: Extract container creation to a factory that can be overridden, or ensure test targets create their own in-memory containers.

## Positive Patterns

- **Clean model layer**: The SwiftData models are well-organized with clear relationships, cascade delete rules, and computed property wrappers for raw-value enums. The separation between `@Model` types and `ParsedModels` (Codable DTOs) is a good architectural boundary.

- **Dual-parser strategy with graceful fallback**: `WorkoutParserService` routes to on-device (Apple Foundation Models) or cloud (OpenRouter) based on token estimate and availability. The `#if canImport` guards and `@available` checks are correctly applied.

- **`ExecutionStep.flattenSteps` is a clean, testable pure function**: The step-flattening logic correctly handles rounds, rest insertion, and sort ordering. It takes a session and returns a value-type array with no side effects.

- **Good use of `@Observable` macro**: The codebase uses the modern `@Observable` macro consistently instead of `ObservableObject`/`@Published`, which is appropriate for an iOS 17+ minimum deployment.

- **WatchConnectivity fallback to application context**: `WatchConnectivityManager.sendMessage` gracefully falls back to `updateApplicationContext` when the counterpart is not reachable, ensuring state eventually syncs.

- **Location accuracy filtering**: Both iOS and Watch location handlers correctly discard GPS readings with `horizontalAccuracy >= 20` or negative values, and use a 3-point rolling average for pace smoothing.

- **Well-structured view decomposition**: Views are broken into small, focused sub-views (`MetricCard`, `StatChip`, `BlockTypeBadge`, `TimerRingView`, etc.) with clear naming. The custom `FlowLayout` is a nice touch for dynamic badge arrangement.

- **XcodeGen project configuration**: Using `project.yml` instead of a `.xcodeproj` avoids merge conflicts and makes the build configuration transparent and auditable.

# Coding Standards

## Swift Style

- **Variables and functions:** `camelCase` (e.g. `currentPaceSecPerKm`, `broadcastMetrics()`).
- **Types, enums, protocols:** `PascalCase` (e.g. `WorkoutBlock`, `SessionType`, `ExerciseType`).
- **File organization:** Use `// MARK: -` sections to group related code (e.g. `// MARK: - Control`, `// MARK: - Private`).
- **One type per file** for models and services. Related small types (e.g. enums used only by that file) may live in the same file.

## Observable and Concurrency

- Use the **`@Observable` macro** for all view models and services. Do not use `ObservableObject` or `@Published`.
- Use **Swift structured concurrency** (`async/await`, `@MainActor`) for asynchronous work. Avoid `DispatchQueue.main.async` except in delegate callbacks that require it (e.g. `CLLocationManagerDelegate`).
- Mark functions that update UI state with `@MainActor`.

## Appearance

- Use **semantic system colors**: `Color(.systemBackground)`, `.primary`, `.secondary`, etc.
- Use `@Environment(\.colorScheme)` only when custom light/dark behavior is needed -- prefer letting the system handle it.
- Avoid hard-coded color literals. The codebase uses string-based color names (e.g. `BlockType.accentColor` returns `"orange"`, `"green"`) for dynamic mapping.

## Error Handling

- **No empty `catch` blocks.** Always handle or log the error. If recovery is not possible, surface the error to the user (e.g. `PlanImportViewModel.errorMessage`).
- Use `os.Logger` for diagnostic logging:
  ```swift
  import os
  private let logger = Logger(subsystem: "com.victorkzam.WorkoutTracker", category: "Parsing")
  logger.error("Failed to decode plan: \(error.localizedDescription)")
  ```
- Use per-module categories: `"Parsing"`, `"Location"`, `"HealthKit"`, `"Sync"`, etc.
- Define domain-specific error enums with `LocalizedError` conformance (see `ParserError`).

## Performance

- **Never block the main thread.** Parsing, network calls, and HealthKit queries must run asynchronously.
- Use **lazy loading** where appropriate (e.g. computed properties like `Exercise.paceDisplayString`).
- Prefer **value types** (`struct`, `enum`) over classes unless reference semantics are required (SwiftData `@Model` classes, `@Observable` services).
- GPS location updates use a `distanceFilter` of 3 meters and filter out readings with `horizontalAccuracy >= 20` to avoid processing noisy data.

## SwiftData Models

- All persistent models use the `@Model` macro.
- Store enum values as raw strings (e.g. `sessionTypeRaw: String`) with a computed property for the typed enum. This ensures SwiftData compatibility.
- Use `@Relationship(deleteRule: .cascade)` for parent-child relationships.

## Testing

- **Naming convention:** `test_methodName_condition_expectedResult`
  ```swift
  func test_parse_emptyText_returnsFailure() { ... }
  func test_flattenSteps_singleBlockTwoRounds_doublesExercises() { ... }
  ```
- All new code must include tests.
- Keep tests focused on a single behaviour per test method.

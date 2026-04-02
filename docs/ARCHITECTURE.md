# Architecture

## System Overview

WorkoutTracker is a native Swift app targeting **iOS 17+** and **watchOS 10+**. It is built with Swift 5.9, SwiftUI, and SwiftData, following an **MVVM + Service layer** architecture. All view models and services use the `@Observable` macro.

The codebase is split into three layers:

| Layer    | Path      | Purpose |
|----------|-----------|---------|
| **Shared** | `Shared/` | SwiftData models and WatchConnectivity manager -- compiled into both targets |
| **iOS**    | `iOS/`    | iPhone app: views, view models, parsing services, GPS, HealthKit |
| **Watch**  | `Watch/`  | watchOS companion: mirrors session state from iPhone, independent GPS workouts |

The Xcode project is generated from `project.yml` using XcodeGen.

## Directory Tree

```
WorkoutTracker/
├── project.yml                     # XcodeGen spec (iOS + watchOS targets)
├── Secrets.xcconfig.template       # OpenRouter API key placeholder
│
├── Shared/
│   ├── Models/
│   │   ├── WorkoutPlan.swift       # @Model -- top-level plan with raw text
│   │   ├── WorkoutSession.swift    # @Model -- single session (day), has SessionType enum
│   │   ├── WorkoutBlock.swift      # @Model -- block within a session, has BlockType enum
│   │   ├── Exercise.swift          # @Model -- individual exercise, has ExerciseType enum
│   │   ├── SessionExecution.swift  # @Model -- recorded execution (distance, pace, HR, route)
│   │   └── ExecutionStep.swift     # Value type -- flattened step for execution engine
│   ├── Protocols/
│   │   ├── WorkoutParserProtocol.swift      # Abstraction for parser testability
│   │   ├── HealthKitServiceProtocol.swift   # Abstraction for HealthKit testability
│   │   ├── LocationServiceProtocol.swift    # Abstraction for location testability
│   │   └── WatchConnectivityProtocol.swift  # Abstraction for WC testability
│   ├── Services/
│   │   └── WatchConnectivityManager.swift   # Singleton, WCSession delegate
│   └── Utilities/
│       ├── Logging.swift           # os.Logger extensions (per-module categories)
│       ├── GPSMath.swift           # Pace formatting, speed smoothing helpers
│       └── ModelContainerFactory.swift  # SwiftData container with CloudKit config
│
├── iOS/
│   ├── App/
│   │   ├── WorkoutTrackerApp.swift # @main, ModelContainer with CloudKit
│   │   └── ContentView.swift       # Root view (PlanListView)
│   ├── Services/
│   │   ├── WorkoutParserService.swift   # Routes parsing: on-device vs cloud
│   │   ├── AppleFoundationParser.swift  # FoundationModels / @Generable (iOS 26+)
│   │   ├── OpenRouterParser.swift       # OpenRouter REST, Gemini 2.5 Flash Lite
│   │   ├── ParsedModels.swift           # Intermediate Codable structs + conversion
│   │   ├── LocationService.swift        # CLLocationManager wrapper, pace smoothing
│   │   └── HealthKitService.swift       # HKWorkoutSession, live HR streaming
│   ├── ViewModels/
│   │   ├── PlanImportViewModel.swift         # Drives paste-import flow
│   │   └── SessionExecutionViewModel.swift   # Timer engine, step navigation, WC broadcast
│   └── Views/
│       ├── Plans/
│       │   ├── PlanListView.swift
│       │   ├── PlanDetailView.swift
│       │   ├── SessionDetailView.swift
│       │   └── PasteImportView.swift
│       ├── Sessions/
│       │   ├── SessionExecutionView.swift
│       │   ├── ExerciseStepView.swift
│       │   └── GPSRunView.swift
│       └── Components/
│           ├── HRZoneTag.swift
│           └── PaceDisplay.swift
│
└── Watch/
    ├── WatchApp.swift              # @main, WatchSessionController
    ├── Services/
    │   └── WorkoutSessionManager.swift  # Independent HKWorkoutSession + GPS on Watch
    └── Views/
        ├── SessionListWatchView.swift
        ├── SessionDetailWatchView.swift
        ├── SessionWatchView.swift
        └── GPSWatchView.swift
```

## Data Flow

```
User pastes free-form text
        │
        ▼
PlanImportViewModel.parseWorkoutPlan()
        │
        ▼
WorkoutParserService.parse(rawText:)
        │
        ├── estimates tokens (chars / 4.0)
        │
        ├── <= 3500 tokens + iOS 26+ ──▶ AppleFoundationParser (on-device)
        │                                  uses @Generable structs
        │
        └── otherwise ─────────────────▶ OpenRouterParser (cloud)
                                           Gemini 2.5 Flash Lite, JSON mode
        │
        ▼
ParsedWorkoutPlan (Codable structs)
        │
        ▼
.toWorkoutPlan(rawText:) conversion
        │
        ▼
SwiftData @Model objects (WorkoutPlan → WorkoutSession → WorkoutBlock → Exercise)
        │
        ▼
SwiftUI Views (PlanListView → PlanDetailView → SessionDetailView)
        │
        ▼
SessionExecutionViewModel (timer engine, step flattening via ExecutionStep)
        │
        ├── LocationService (GPS tracking)
        ├── HealthKitService (heart rate, workout recording)
        └── WatchConnectivityManager (broadcasts state to Watch)
```

## LLM Parsing Strategy

The app converts free-form workout plan text into structured data using two parsing backends:

### On-Device: Apple Foundation Models (iOS 26+)

- Uses the `FoundationModels` framework with `@Generable` structs (`GenParsedWorkoutPlan`, `GenParsedSession`, `GenParsedBlock`, `GenParsedExercise`).
- Each field is annotated with `@Guide(description:)` to steer generation.
- `LanguageModelSession` is initialized with a system prompt defining the parser role.
- Output is guaranteed to match the `@Generable` schema -- no JSON decoding needed.
- Results are converted to shared `ParsedWorkoutPlan` structs via `toParsedWorkoutPlan()`.

### Cloud: OpenRouter (Gemini 2.5 Flash Lite)

- Sends a `POST` to `https://openrouter.ai/api/v1/chat/completions` with `response_format: json_object`.
- The system prompt includes the full JSON schema and parsing rules (pace conversion, exercise type mapping, etc.).
- Response content is decoded with `JSONDecoder` into `ParsedWorkoutPlan`.
- Requires an API key stored in `Secrets.xcconfig` (set via `OPENROUTER_API_KEY`).

### Token Routing

`WorkoutParserService` estimates tokens as `rawText.count / 4.0`. If the estimate is **<= 3,500 tokens** and the device runs **iOS 26+**, it routes to the on-device parser. Otherwise it falls back to the cloud parser.

## Sync Architecture

### CloudKit (SwiftData automatic sync)

Both the iOS and watchOS targets configure `ModelContainer` with a private CloudKit database (`iCloud.com.victorkzam.WorkoutTracker`). SwiftData handles sync automatically -- plans created on iPhone appear on Watch (and vice versa) without custom sync code. If CloudKit is unavailable, both targets fall back to local-only storage.

### WatchConnectivity (real-time session state)

`WatchConnectivityManager` is a shared singleton (`@Observable`) used by both platforms:

- **iPhone to Watch:** `SessionExecutionViewModel` broadcasts step updates (exercise name, block, round, timer, GPS metrics) on every timer tick.
- **Watch to iPhone:** `WorkoutSessionManager` broadcasts GPS metrics (pace, distance, HR, elapsed time) every 5 seconds.
- **Transport:** Uses `sendMessage` for real-time delivery when reachable; falls back to `updateApplicationContext` for eventual delivery.
- **Watch-side:** `WatchSessionController` receives messages and maintains a local countdown timer so the UI stays responsive even if iPhone messages are delayed.

## Key Patterns

- **@Observable everywhere** -- all view models (`PlanImportViewModel`, `SessionExecutionViewModel`) and services (`WorkoutParserService`, `LocationService`, `HealthKitService`, `WatchConnectivityManager`, `WorkoutSessionManager`) use the `@Observable` macro.
- **@Model for persistence** -- five SwiftData model classes with `@Relationship(deleteRule: .cascade)` forming the hierarchy: `WorkoutPlan` -> `WorkoutSession` -> `WorkoutBlock` -> `Exercise`, plus `SessionExecution`.
- **ExecutionStep flattening** -- `ExecutionStep.flattenSteps(session:)` expands blocks x rounds x exercises into a linear array, inserting rest steps for interval blocks.
- **Pace smoothing** -- both `LocationService` (iOS) and `WorkoutSessionManager` (Watch) use a 3-point rolling average of raw GPS speed, filtering readings below 0.5 m/s.
- **Protocol-driven testability** -- key services are abstracted behind protocols (`WorkoutParserProtocol`, `HealthKitServiceProtocol`, `LocationServiceProtocol`, `WatchConnectivityProtocol`) defined in `Shared/Protocols/`. View models accept these protocols via initializer injection.

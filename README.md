# WorkoutTracker

Native iOS + Apple Watch workout tracker that parses LLM-generated text plans into structured sessions with step-by-step timers, GPS tracking, and HealthKit integration.

## Features

- **Paste & Parse** — paste any text workout plan; on-device AI (Apple Intelligence, iOS 18+) or Gemini 2.0 Flash Lite (cloud fallback) structures it into sessions, blocks, and exercises
- **Session Tracker** — step-by-step execution with countdown timers, exercise instructions, HR zone display, and RPE
- **GPS Tracking** — live pace, distance, and route map (MapKit) for running and cycling blocks
- **Apple Watch** — mirrors the active iPhone session with haptics; can also run sessions independently with on-Watch GPS + HR via HealthKit
- **iCloud Sync** — plans and history sync across your iPhone and Watch via CloudKit

## Requirements

- Xcode 15+
- iOS 17+ (iPhone target)
- watchOS 10+ (Apple Watch target)
- Active Apple Developer account (for HealthKit, CloudKit, and Watch)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`

## Setup

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Clone and generate the Xcode project

```bash
git clone <repo-url>
cd workout-plan-tracker
xcodegen generate
```

### 3. Configure your API key (cloud fallback only)

The app uses **Apple Foundation Models** on-device (iOS 18+) as the primary parser — no API key needed for that path.

For the cloud fallback (iOS 17 or long plans), create `Secrets.xcconfig`:

```bash
cp Secrets.xcconfig.template Secrets.xcconfig
```

Edit `Secrets.xcconfig` and set your [OpenRouter](https://openrouter.ai/keys) key:

```
OPENROUTER_API_KEY = sk-or-v1-YOUR_KEY_HERE
```

> `Secrets.xcconfig` is gitignored and will never be committed.

### 4. Configure signing

Open `WorkoutTracker.xcodeproj`, select the `WorkoutTracker` and `WorkoutTrackerWatch` targets, and set your **Team** in Signing & Capabilities.

In `project.yml`, set:
```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "YOUR_TEAM_ID"
```
Then re-run `xcodegen generate`.

### 5. Enable CloudKit

In the [CloudKit Console](https://icloud.developer.apple.com/), create a container named:
```
iCloud.com.victorkzam.WorkoutTracker
```

### 6. Run

Build and run the `WorkoutTracker` scheme on your iPhone. The Watch app is automatically pushed if a paired Watch is connected.

## Architecture

```
workout-plan-tracker/
├── Shared/                    # Shared between iOS + Watch (SwiftData models, WatchConnectivity)
│   ├── Models/                # WorkoutPlan, WorkoutSession, WorkoutBlock, Exercise, SessionExecution
│   └── Services/              # WatchConnectivityManager
├── iOS/
│   ├── App/                   # App entry point, Info.plist, entitlements
│   ├── Services/              # WorkoutParserService, AppleFoundationParser, OpenRouterParser,
│   │                          # HealthKitService, LocationService
│   ├── ViewModels/            # PlanImportViewModel, SessionExecutionViewModel
│   └── Views/
│       ├── Plans/             # PlanListView, PasteImportView, PlanDetailView, SessionDetailView
│       ├── Sessions/          # SessionExecutionView, ExerciseStepView, GPSRunView
│       └── Components/        # HRZoneTag, PaceDisplay, BlockTypeBadge
└── Watch/
    ├── WatchApp.swift         # Entry point + WatchSessionController
    ├── Services/              # WorkoutSessionManager (HKWorkoutSession + GPS)
    └── Views/                 # SessionListWatchView, SessionWatchView, GPSWatchView, …
```

## LLM Parsing

| Path | When used | Model |
|------|-----------|-------|
| On-device | iOS 18+, plan ≤ 3 500 tokens | Apple Foundation Models (`@Generable`) |
| Cloud (OpenRouter) | iOS 17, or plan > 3 500 tokens | Gemini 2.0 Flash Lite |

Both paths produce the same `ParsedWorkoutPlan` struct, which is converted to SwiftData models.

## Verification checklist

- [ ] Paste the sample half-marathon plan → 4 sessions created, Session 1 has 5 blocks
- [ ] Core circuit block: `rounds=2`, `workIntervalSec=45`, `restIntervalSec=15`
- [ ] Run block has `exerciseType=gpsRun`, pace and HR zone populated
- [ ] Start Session 1 → warm-up steps auto-advance every 30 s
- [ ] Core circuit repeats × 2 rounds with 15 s rest steps between exercises
- [ ] GPS run screen shows live pace + route polyline
- [ ] Start session on iPhone → Watch mirrors current step within 3 s
- [ ] Start GPS run from Watch → `HKWorkoutSession` records distance + HR independently
- [ ] Plan added on iPhone → appears on Watch after CloudKit sync

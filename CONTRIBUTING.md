# Contributing to WorkoutTracker

## Project Setup

1. **Clone the repository** and install [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```bash
   brew install xcodegen
   ```

2. **Create your secrets file** from the template:
   ```bash
   cp Secrets.xcconfig.template Secrets.xcconfig
   ```
   Open `Secrets.xcconfig` and add your [OpenRouter API key](https://openrouter.ai/keys). This file is gitignored and must never be committed.

3. **Generate the Xcode project and open it:**
   ```bash
   xcodegen generate
   open WorkoutTracker.xcodeproj
   ```

4. Select the `WorkoutTracker` scheme (iOS) or `WorkoutTrackerWatch` scheme (watchOS) and build.

## Commit Conventions

We use [Conventional Commits](https://www.conventionalcommits.org/). Every commit message must start with a type prefix:

| Prefix     | Use for                              |
|------------|--------------------------------------|
| `feat:`    | New feature or capability            |
| `fix:`     | Bug fix                              |
| `docs:`    | Documentation only                   |
| `test:`    | Adding or updating tests             |
| `chore:`   | Build config, dependencies, CI       |
| `refactor:`| Code restructuring with no behaviour change |

Example: `feat: add HR zone indicator to GPS run view`

## Branch Naming

- `feature/<short-description>` -- new features
- `fix/<short-description>` -- bug fixes
- `hotfix/<short-description>` -- urgent production fixes

## Pull Request Workflow

1. Create a **draft PR** from your branch.
2. Ensure **CI passes** (build + tests).
3. Mark as **Ready for Review** and request a reviewer.
4. Address feedback, then the reviewer merges.

## Code Style

Follow the guidelines in [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md). Key points:

- Use `@Observable` (not `ObservableObject` / `@Published`).
- Use `async/await` and `@MainActor` (not GCD dispatch queues).
- Organise files with `// MARK: -` sections.

## Testing

All new code must include tests. Use the naming convention `test_methodName_condition_expectedResult`.

Run the test suite:

```bash
xcodegen generate && xcodebuild test \
  -scheme WorkoutTrackerTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

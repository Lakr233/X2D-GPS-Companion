# Repository Guidelines

## Project Architecture Overview

X2D GPS Companion is an iOS application that automatically geotags photos from Hasselblad X2D cameras by monitoring the photo library and applying GPS coordinates from the device's location services.

### Core Components

**Main Application (`X2D GPS Companion/`)**
- **App/**: Application entry point with `main.swift` and `CompanionApp` struct
- **Backend/**: Core business logic organized by feature:
  - `ViewModel.swift`: Main observable state management with `@Observable` macro
  - `ViewModel+Recording.swift`: Recording start/stop functionality with permission checks
  - `ViewModel+Location.swift`: CoreLocation integration and delegate methods
  - `ViewModel+Photos.swift`: Photo library polling and GPS metadata writing
  - `ViewModel+Permissions.swift`: Permission state management
  - `ViewModel+Settings.swift`: UserDefaults-backed settings persistence
  - `LiveActivityManager.swift`: Live Activity management for background status display
  - `LocationDecoder.swift`: GPS coordinate decoding and validation
  - `CLTransfer.swift`: Chinese coordinate system transformations (WGS-84, GCJ-02, BD-09)
- **Interface/**: SwiftUI views organized by screen:
  - `ContentView.swift`: Main navigation container
  - `HomePageView.swift`: Primary interface with permissions, recording controls, and map
  - `SettingsView.swift`: User preferences configuration
  - Component views: `RecordingButton`, `PermissionRow`, `AccessBadge`, `BackgroundGradient`
- **Extension/**: Swift extensions like `Extension+ShapeStyle`
- **Resources/**: Assets, localization strings, and Info.plist

**Widget Extension (`X2D GPS Companion Widgets/`)**
- Live Activity widget for displaying recording status on lock screen/Dynamic Island
- `X2D_GPS_Companion_WidgetsLiveActivity.swift`: Widget configuration and UI
- `GPSActivityAttributes.swift`: Activity attributes and content state

**Testing (`X2D GPS CompanionTests/`)**
- XCTest-based unit tests mirroring main app structure
- `LocationConvertorTest.swift`: Location conversion validation

### Key Architectural Patterns

- **MVVM with SwiftUI**: `@Observable` view models manage state, SwiftUI views observe changes
- **Feature-based Extensions**: Core `AppViewModel` extended with focused functionality
- **Background Processing**: Uses CoreLocation background modes and Live Activities
- **Permission Management**: Granular photo and location permission states
- **Chinese Coordinate Support**: Built-in coordinate system transformations for regional compatibility

## Build, Test, and Development Commands

### Building
- `./build.sh` - Canonical build script using `xcodebuild` with Release configuration
  - Uses derived data in `./derived/` directory
  - Disables code signing for development builds
  - Supports `xcbeautify` for cleaner output if available

### Testing
- `xcodebuild test -project "X2D GPS Companion.xcodeproj" -scheme "X2D GPS Companion" -destination "platform=iOS Simulator,name=iPhone 15"` - Run unit tests
- Tests are located in `X2D GPS CompanionTests/` mirroring main app structure

### Code Quality
- `swiftformat .` - Format Swift files (install via Homebrew)
- `swiftlint` - Enforce lint rules (if configured)
- `python3 Resources/Scripts/check_translations.py [path]` - Validate translation completeness
  - Checks all localizations (en, de, fr, ja, zh-Hans) in `.xcstrings` files
  - Verifies translation state is 'translated' and values are non-empty
  - Default path: `Resources/Localizable.xcstrings`; accepts custom path as argument

## Project Structure & Module Organization
- `X2D GPS Companion/` holds the Swift sources organized by domain (`App`, `Backend`, `Interface`, `Extension`).
- `X2D GPS CompanionTests/` contains XCTest coverage; mirror the directory names from the app target when adding tests.
- `Resources/` stores assets (`Assets.xcassets`, `Localizable.xcstrings`, `InfoPlist.xcstrings`) and icons; keep localized strings here.
- `build.sh` is the canonical build entrypoint; update it if project-wide build flags change.

## Coding Style & Naming Conventions
- Follow 4-space indentation, opening braces on the same line, and single-space padding around operators.
- Types are PascalCase; properties, functions, and variables use camelCase. Use explicit argument labels in public APIs.
- Prefer value types and dependency injection; adopt `@Observable` macros and Swift concurrency where appropriate.
- Place extensions in `Type+Feature.swift` files and keep each type or extension focused on a single responsibility.

## Testing Guidelines
- Use XCTest with descriptive method names (`testFeature_whenCondition_expectOutcome`).
- Co-locate test fixtures alongside relevant tests inside `X2D GPS CompanionTests/` and avoid cross-target dependencies.
- Target new features with positive and failure-path coverage; keep tests deterministic and simulator-friendly.
- Run the full test suite via the `xcodebuild test` command before opening a pull request.

## Commit & Pull Request Guidelines
- Write present-tense commits summarizing intent (e.g., `feat: add satellite accuracy tile`).
- Commit after each logical task; avoid bundling unrelated changes.
- Pull requests should describe changes, reference related issues, and include screenshots or simulator recordings for UI updates.
- Note any follow-up work and confirm tests/build commands were run in the PR description.

## Agent-Specific Notes
- When automating tasks, respect this guide and document deviations in `FAILURE.md` if necessary.
- Use `xcrun simctl` to capture simulator logs or screenshots for validation artifacts.

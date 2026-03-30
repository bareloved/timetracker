# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Loom — a personal macOS menu bar time tracker. It monitors the frontmost app, categorizes activity via configurable rules, and writes sessions to macOS Calendar. Built with SwiftUI, targeting macOS 14+.

## Build & Run

```bash
# Build and launch (the main dev loop)
./run.sh

# Build only
swift build -c release

# Run tests
swift test
```

`run.sh` builds release, kills any running instance, copies the binary + bundle into `/Applications/Loom.app`, codesigns, and opens it. The app bundle must already exist at `/Applications/Loom.app`.

## Architecture

**Package.swift** defines executable product `Loom` with sources in `Loom/` and tests in `LoomTests/`.

### Data Flow

```
ActivityMonitor (polls every 5s)
  → SessionEngine.process(ActivityRecord)
    → CategoryConfig.resolve(bundleId, pageURL)
    → Session management (5-min switch threshold)
    → CalendarWriter (persists to EventKit)
```

### Key Services

- **SessionEngine** — Core state machine. Manages current session, tentative category switches (waits 5 min before switching), idle handling, session resume logic. Supports attaching distractions before finalizing.
- **ActivityMonitor** — Polls frontmost app every 5s via NSWorkspace. Detects idle via IOKit HID idle time. Fires `onActivity`, `onIdle`, `onIdleReturn` callbacks.
- **CalendarWriter/CalendarReader** — EventKit integration. Creates/updates events in a "Loom" calendar. Event title is `"Category — Intention"`, notes include intention and distractions with duration. Location field is unused.
- **FocusGuard** — Monitors off-category app usage during a session. After a configurable threshold, shows a popup nudging the user back. Tracks distractions (app name, duration, snoozed status) which get attached to the session on finalize.
- **BrowserTracker** — Extracts active tab URLs from browsers via Accessibility API.
- **CategoryConfigLoader** — Loads/saves `~/Library/Application Support/Loom/categories.json`. Default config bundled as resource `default-categories.json`.
- **HotkeyManager** — Global hotkey (Option+Shift+T) via CGEvent tap. Currently disabled.
- **IdleDetector** — IOKit HID-based idle time detection.
- **ToastManager** — In-app toast notification queue. Shows success/info (auto-dismiss 3s) and warning/error (persistent) banners overlaid on the main window. Max 2 visible.
- **ReminderManager** — macOS notification center integration. Handles daily session reminders and system notifications for idle stop, sleep stop, calendar write failure, sync failure, and remote session start.

### State Management

Uses Swift `@Observable` classes with `@MainActor` isolation. `AppState` (in `LoomApp.swift`) is the root orchestrator that wires services together. `MenuBarState` enum (`.tracking`, `.stoppedIdle`, `.stoppedSleep`, `.inactive`) drives menu bar icon and text. `syncError` flag overlays a warning indicator.

### Views

- **Menu Bar** (`Views/MenuBarView.swift`, `CurrentSessionView.swift`) — Dropdown with session status, timer, focus goals, start/stop controls
- **Main Window** (`Views/Window/`) — Tab-based: Today, Calendar, Stats, Settings
- **Popups** — `LaunchPopupView` (session start with category picker + intention), `FocusPopupView` (distraction nudge), `IdleReturnPanel` (resume after idle)
- **Shared Components** — `ToastOverlayView` (in-app feedback banners), `SkeletonLoadingView` (pulsing placeholder for loading states), `EmptyStateView` (unified icon + title + subtitle for empty data)

### Models

- **Session** — id, category, startTime, endTime, appsUsed, intention, trackingSpanId, eventIdentifier, distractions
- **Distraction** — appName, bundleId, url, startTime, duration, snoozed
- **CategoryRule/CategoryConfig** — App-to-category mapping with URL patterns and related apps
- **ActivityRecord** — bundleId, appName, windowTitle, pageURL, timestamp

## Key Thresholds

All set to 300 seconds (5 min): `shortSwitchThreshold`, `resumeThreshold`, `idleThreshold`.

## Runtime Permissions

The app requires **Accessibility** (window titles, browser URL extraction) and **Calendar** (event creation) permissions. Accessibility is checked via `AXIsProcessTrusted()`. The app is an LSUIElement (menu bar only, no dock icon).

## Testing

Uses Swift Testing framework (`@Suite`, `@Test`, `#expect`). Tests in `LoomTests/` cover SessionEngine logic, category resolution, colors, config loading, and Session model.

## Design System

Documented in `.design-engineer/system.md`. Warm/matte/earthy aesthetic with terracotta (#c06040) accent. Supports light/dark/system appearance via `@AppStorage("appearance")`.

<!-- GSD:project-start source:PROJECT.md -->
## Project

**Loom — Sessions List View**

A new "Sessions" tab in Loom's main window that shows tracked sessions as a browsable, expandable list organized by week. Users can navigate between days and weeks (matching the existing Calendar tab navigation), expand any session to see a detailed breakdown of apps used, and edit or delete sessions directly.

**Core Value:** Users can quickly review, inspect, and manage their tracked sessions in a structured list — the one view that ties session history, app usage detail, and session editing together.

### Constraints

- **Platform**: macOS 14+ SwiftUI only
- **Data source**: Must use the same CloudKit/SyncEngine path as Calendar tab for consistency
- **Navigation pattern**: Week/day navigation must match CalendarTabView exactly so users feel at home
- **Architecture**: Follow existing @Observable + @MainActor patterns, no new architectural patterns
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Swift 6.3 (swift-tools-version: 5.9) - All application code across all targets
- Bash - Build/release scripts (`run.sh`, `scripts/build-app.sh`, `scripts/create-dmg.sh`, `scripts/release.sh`)
## Runtime
- macOS 14+ (Sonoma) for the SPM-based executable (`Loom/`)
- macOS 14+ for the Xcode-based app (`LoomMac/`)
- iOS 17+ for the companion app (`LoomMobile/`)
- Swift Package Manager (SPM)
- Lockfile: `Package.resolved` (auto-generated by SPM)
- No third-party dependencies - all packages are Apple frameworks
## Frameworks
- SwiftUI - All UI across macOS and iOS targets
- AppKit (via `import AppKit`, `import Cocoa`) - macOS-specific window management, menu bar, NSWorkspace
- EventKit - Calendar event creation and reading
- CloudKit - Cross-device session sync between macOS and iOS
- IOKit - Hardware idle time detection via HID system
- ApplicationServices / Accessibility API (`AXUIElement*`) - Window title extraction, browser URL reading
- Carbon.HIToolbox - Keyboard event handling for global hotkeys
- CoreGraphics (`CGEvent`) - Global event tap for hotkey registration
- ServiceManagement (`SMAppService`) - Launch at login
- UniformTypeIdentifiers - App icon resolution
- Swift Testing framework (`@Suite`, `@Test`, `#expect`) - Unit tests in `LoomTests/`
- Swift Package Manager (`swift build -c release`) - SPM-based CLI build for `Loom/`
- Xcode - Project-based build for `LoomMac/` and `LoomMobile/`
- `codesign` - Code signing with Apple Development certificate
- `hdiutil` / custom DMG script - Release packaging via `scripts/create-dmg.sh`
- GitHub CLI (`gh`) - Release creation via `scripts/release.sh`
## Key Dependencies
- `EventKit` - Core persistence layer; sessions are written as calendar events
- `CloudKit` - Cross-device sync; sessions, active state, and category config
- `SwiftUI` - Entire UI layer on both platforms
- `IOKit` - Idle detection via `IORegistryEntryCreateCFProperties` on `IOHIDSystem`
- `ApplicationServices` - Accessibility API for window title + browser URL extraction
- `CoreGraphics` - Global hotkey event tap
- `ServiceManagement` - Launch-at-login registration
## Multi-Target Architecture
| Target | Build System | Platform | Path |
|--------|-------------|----------|------|
| `Loom` (SPM executable) | Swift Package Manager | macOS 14+ | `Loom/` |
| `LoomMac` (Xcode app) | Xcode | macOS 14+ | `LoomMac/LoomMac/` |
| `LoomMobile` (Xcode app) | Xcode | iOS 17+ | `LoomMobile/LoomMobile/` |
| `LoomKit` (shared library) | SPM (local package) | macOS 14+, iOS 17+ | `LoomKit/` |
- Models: `Session`, `Distraction`, `Category`, `CategoryColors` (`LoomKit/Sources/LoomKit/Models/`)
- Config: `CategoryConfigLoader` (`LoomKit/Sources/LoomKit/Config/`)
- Sync: `CloudKitManager`, `SyncEngine` (`LoomKit/Sources/LoomKit/Sync/`)
## Configuration
- No `.env` files - all config is stored in:
- `Package.swift` - SPM manifest for `Loom` executable
- `LoomKit/Package.swift` - SPM manifest for shared library
- `LoomMac/LoomMac.xcodeproj/` - Xcode project for macOS app
- `LoomMobile/LoomMobile.xcodeproj/` - Xcode project for iOS app
- `Loom/Loom.entitlements` - Entitlements for SPM build (calendars, CloudKit, push)
- `LoomMac/LoomMac/LoomMac.entitlements` - Entitlements for Xcode macOS build
- `LoomMobile/LoomMobile/LoomMobile.entitlements` - Entitlements for iOS build
- `Loom/Info.plist` - App metadata, LSUIElement=true (menu bar only), permission descriptions
## Platform Requirements
- macOS 14+ (Sonoma) with Xcode installed
- Apple Development certificate for code signing
- Provisioning profile with CloudKit + Push Notifications capabilities
- Swift 5.9+ toolchain (currently running Swift 6.3)
- macOS 14+ for desktop app
- iOS 17+ for mobile companion
- iCloud account for CloudKit sync
- System permissions: Accessibility (window titles), Calendar (event persistence)
- App installed at `/Applications/Loom.app` (the `run.sh` script copies binary there)
- DMG packaging via `scripts/create-dmg.sh`
- GitHub Releases via `scripts/release.sh` using `gh` CLI
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- PascalCase for all Swift files: `SessionEngine.swift`, `CalendarWriter.swift`, `CurrentSessionView.swift`
- Views suffixed with `View`: `MenuBarView.swift`, `CurrentSessionView.swift`, `TodayTabView.swift`
- Tab views suffixed with `TabView`: `CalendarTabView.swift`, `StatsTabView.swift`, `SettingsTabView.swift`
- Controllers suffixed with `Controller`: `FocusPopupController.swift`, `LaunchPopupController.swift`
- Service files named after their domain concept: `SessionEngine.swift`, `ActivityMonitor.swift`, `FocusGuard.swift`
- camelCase for all functions and methods
- Use imperative verbs for actions: `startSession()`, `stopTracking()`, `handleIdle()`, `resetDrift()`
- Prefix boolean queries with `is`: `isIdle()`, `isBrowser()`, `isRelated()`
- Use `on` prefix for callback closures: `onActivity`, `onIdle`, `onIdleReturn`, `onToggle`, `onStart`, `onStop`
- camelCase for all variables and properties
- Private properties have no underscore prefix (exception: `_storedMenuBarIcon` for `@AppStorage` backing)
- Boolean properties use `is` prefix: `isTracking`, `isPaused`, `isReady`, `isAuthorized`, `isPopupShowing`
- PascalCase for all types: `Session`, `Distraction`, `CategoryConfig`, `ActivityRecord`
- Enums use PascalCase names with camelCase cases: `AppTab.today`, `ConfigError.bundledConfigNotFound`
- Protocol conformances listed on the same line as the struct declaration
## Code Style
- No external formatter or linter configured (no `.swiftlint.yml`, `.swiftformat`, or `.editorconfig`)
- 4-space indentation throughout
- Opening braces on the same line as the declaration
- Single blank line between methods
- No trailing commas in parameter lists
- No linter configured. Rely on Xcode's built-in warnings and Swift compiler diagnostics.
## Import Organization
- `Loom/Models/Session.swift` contains `@_exported import LoomKit` -- this re-exports all LoomKit types to the Loom target
- Stub files in `Loom/Models/` (e.g., `Category.swift`, `Distraction.swift`, `CategoryColors.swift`) contain only comments noting the type is now provided by LoomKit
- Use `@_exported import LoomKit` in `Loom/Models/Session.swift` to make LoomKit types available without explicit imports
## Error Handling
- Errors in service methods are caught with `do/catch` and logged via `print()`, then silently continue
- No error propagation to the UI layer; no user-facing error alerts
- Example pattern used throughout:
- Use `guard` for precondition checks with early return:
- Services are optional on `AppState` (`sessionEngine: SessionEngine?`, `syncEngine: SyncEngine?`)
- Calls use optional chaining: `sessionEngine?.startSession(...)`, `syncEngine?.publishSessionStart(...)`
- Used in timer callbacks: `try? self.eventStore.save(event, span: .thisEvent)`
## Logging
- Prefix logs with bracketed context: `print("[LoomMac] starting remote polling")`, `print("[RemotePoll] activeID=...")`
- Error logs use descriptive prefix: `print("Failed to create event: \(error)")`, `print("SyncEngine: failed to publish session start: \(error)")`
- `NSLog` used in one place: `NSLog("[FocusGuard] evaluate guard failed")` in `Loom/Services/FocusGuard.swift`
- No log levels or structured logging. Use `print()` for all logging.
## Concurrency Patterns
- All service classes (`SessionEngine`, `CalendarWriter`, `ActivityMonitor`, `FocusGuard`, `AppState`) are annotated `@MainActor`
- `CloudKitManager` is `Sendable` (non-isolated) since it only performs async CloudKit calls
- `SyncEngine` is `@MainActor` and wraps `CloudKitManager`
- Timer closures use `MainActor.assumeIsolated { }` to bridge from the timer's callback context:
- Fire-and-forget `Task { }` blocks for sync operations that should not block the caller:
- `DispatchQueue.global(qos: .userInitiated).async` for Accessibility API calls (window title, browser URL)
- Results dispatched back via `DispatchQueue.main.async`
## Observable Pattern
- Use `@Observable` (Swift Observation framework), not `ObservableObject`/`@Published`
- Mark mutable state as `private(set)` for read-only external access
- Use `@ObservationIgnored` for `@AppStorage` properties to avoid observation conflicts:
## View Design Patterns
- Views receive services and data as init parameters, not through `@EnvironmentObject`
- Callbacks passed as closures: `onStart`, `onStop`, `onShowSessionPicker`, `onQuit`
- `@State private var selectedTab: AppTab = .today`
- `@State private var intentionText: String = ""`
- Use `Theme.textPrimary`, `Theme.textSecondary`, `Theme.textTertiary`, `Theme.background` from `LoomKit/Sources/LoomKit/Models/CategoryColors.swift`
- Use `CategoryColors.color(for: category)` for category-specific colors
- Use `CategoryColors.accent` for the terracotta accent color
- Always apply `.buttonStyle(.plain)` to custom-styled buttons
- Wrap clickable areas with `.contentShape(Rectangle())`
## Model Design
- Models are value types (`struct`): `Session`, `Distraction`, `CategoryRule`, `CategoryConfig`, `ActivityRecord`
- Services are reference types (`final class`): `SessionEngine`, `CalendarWriter`, `ActivityMonitor`
- Utility types are `enum` with no cases (namespace pattern): `IdleDetector`, `BrowserTracker`, `CategoryConfigLoader`, `CategoryColors`
- Models that persist use `Codable`: `Session`, `Distraction`, `CategoryRule`, `CategoryConfig`
- Custom `CodingKeys` for JSON field mapping: `default_category` -> `defaultCategory`, `category_order` -> `categoryOrder`
- `ActivityRecord` is not `Codable` (runtime-only type)
- Use `id: UUID` with default `UUID()` in init: `Session`, `Distraction`
- Enums use computed `id` from a unique property: `MenuBarIcon.id` = `label`
## MARK Comments
- Use `// MARK: -` to organize code sections within files
- Common sections: `Authorization`, `Calendar Management`, `Event Management`, `Timers`, `Core Evaluation`, `Popup`, `Reset`
- Example from `CalendarWriter.swift`: `// MARK: - Authorization`, `// MARK: - Calendar Management`, `// MARK: - Event Management`
## Module Structure
- Contains cross-platform models and sync logic shared between Mac and iOS
- Public API with `public` access on all types and members
- Located at `LoomKit/Sources/LoomKit/`
- SPM executable target, macOS-only services and views
- Depends on LoomKit via local package dependency
- Located at `Loom/`
- Xcode-native build for the Mac app (parallel to the SPM Loom target)
- Located at `LoomMac/LoomMac/`
- Xcode-native iOS companion app
- Located at `LoomMobile/LoomMobile/`
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Single root orchestrator (`AppState`) wires all services together via callbacks
- `@Observable` classes with `@MainActor` isolation for thread-safe reactive UI
- Three deployment targets sharing models through a Swift package (`LoomKit`)
- EventKit (macOS Calendar) as primary local persistence; CloudKit as cross-device sync layer
- No database -- sessions live in Calendar events and CloudKit records
## System Diagram
```
```
## Layers
- Purpose: Cross-platform models, config, sync, and design tokens
- Location: `LoomKit/Sources/LoomKit/`
- Contains: `Session`, `Distraction`, `CategoryConfig`, `CategoryRule`, `CategoryColors`, `Theme`, `SyncEngine`, `CloudKitManager`, `CategoryConfigLoader`
- Used by: All three apps (Loom, LoomMac, LoomMobile)
- Purpose: Core tracking logic, system integration, calendar persistence
- Location: `Loom/Services/` (SPM) and `LoomMac/LoomMac/Services/` (Xcode)
- Contains: `SessionEngine`, `ActivityMonitor`, `CalendarWriter`, `CalendarReader`, `FocusGuard`, `BrowserTracker`, `IdleDetector`, `HotkeyManager`, `AppIconCache`
- Depends on: LoomKit models, macOS frameworks (EventKit, AppKit, IOKit, ApplicationServices)
- Used by: `AppState` orchestrator
- Purpose: macOS-specific models not shared via LoomKit
- Location: `Loom/Models/`
- Contains: `ActivityRecord` (local-only, not synced), stub re-exports for LoomKit types (`Distraction`, `CategoryColors`)
- Purpose: Root state object that wires services together and manages app lifecycle
- Location: `Loom/LoomApp.swift` (class `AppState`, struct `LoomApp`)
- Contains: Service initialization, callback wiring, menu bar state, window management
- Depends on: All services, LoomKit
- Purpose: SwiftUI views for menu bar dropdown, main window tabs, and popups
- Location: `Loom/Views/` (menu bar + popups), `Loom/Views/Window/` (tabbed main window)
- Depends on: `AppState`, `SessionEngine`, `CalendarReader`, `CalendarWriter`
## Data Flow
- `AppState` is an `@Observable @MainActor` class, the single root state object
- `SessionEngine` is `@Observable @MainActor`, holds `currentSession` and `todaySessions`
- `SyncEngine` is `@Observable @MainActor`, holds `activeSessionID`, `activeSource`, heartbeat state
- Views observe these objects directly -- no explicit state store or reducers
- User preferences stored via `@AppStorage` (UserDefaults)
- No Combine publishers -- all reactivity through Swift Observation framework
## Key Abstractions
- Purpose: Represents a tracked time block with category, intention, apps used, and distractions
- Definition: `LoomKit/Sources/LoomKit/Models/Session.swift`
- Pattern: Value type (`struct`), `Codable` + `Identifiable`
- Persisted to: EventKit (via `CalendarWriter`) and CloudKit (via `SyncEngine`)
- Purpose: User-configurable app-to-category mapping rules with URL patterns
- Definition: `LoomKit/Sources/LoomKit/Models/Category.swift`
- Storage: `~/Library/Application Support/Loom/categories.json` (local), CloudKit `CKCategoryConfig` record (synced)
- Resolution order: primary app match -> URL pattern match -> related app match -> default category
- Purpose: Snapshot of frontmost app at a point in time
- Definition: `Loom/Models/ActivityRecord.swift`
- Pattern: Local-only value type, not persisted or synced
- Purpose: Off-category app usage tracked by FocusGuard during a session
- Definition: `LoomKit/Sources/LoomKit/Models/Distraction.swift`
- Attached to session on finalize, written into calendar event notes
## Entry Points
- Location: `Loom/LoomApp.swift` (`@main struct LoomApp`)
- Initialization: `MenuBarExtra` appears -> `.task` triggers `AppState.setup()` -> requests calendar access, loads config, creates services, wires callbacks, shows launch popup
- Two scenes: `MenuBarExtra` (always present) + `Window("Loom", id: "main")` (on demand)
- Location: `LoomMac/LoomMac/LoomApp.swift` (`@main struct LoomApp`)
- Same architecture as Loom SPM, nearly identical code
- Additional: publishes category config to CloudKit on setup
- Location: `LoomMobile/LoomMobile/LoomMobileApp.swift` (`@main struct LoomMobileApp`)
- Initialization: `ProgressView` shows -> `MobileAppState.setup()` -> sets up CloudKit subscriptions, fetches active state, loads config
- Single `WindowGroup` with `TabView` (Now, History, Settings)
## Error Handling
- Calendar operations: `try/catch` with `print("Failed to ...")`, no user notification
- CloudKit operations: `try/catch` in async contexts, errors printed, operations silently fail
- Config loading: `try/catch` with early return from `setup()` if config fails to load (only hard failure)
- No centralized error reporting or crash tracking
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->

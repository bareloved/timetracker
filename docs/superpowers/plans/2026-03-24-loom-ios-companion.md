# Loom iOS Companion App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a companion iOS app that provides remote control of Mac sessions, a manual timer, and unified session history — synced via CloudKit.

**Architecture:** Shared `LoomKit` Swift Package (models, sync, config) consumed by both the existing Mac app and a new iOS Xcode project. Mac dual-writes to Calendar + CloudKit. iOS reads/writes CloudKit only. CloudKit private database with push notification subscriptions for near-real-time sync.

**Tech Stack:** Swift 5.9, SwiftUI, CloudKit (CKContainer, CKRecord, CKSubscription), EventKit (Mac only), Swift Testing

---

## File Structure

### LoomKit/ (new shared package)

| File | Responsibility |
|------|---------------|
| `LoomKit/Package.swift` | Package manifest, platforms: macOS 14+, iOS 17+ |
| `LoomKit/Sources/LoomKit/Models/Session.swift` | Shared Session model (extracted from `Loom/Models/Session.swift`) |
| `LoomKit/Sources/LoomKit/Models/Distraction.swift` | Shared Distraction model (extracted) |
| `LoomKit/Sources/LoomKit/Models/Category.swift` | CategoryRule, CategoryConfig (extracted) |
| `LoomKit/Sources/LoomKit/Models/CategoryColors.swift` | Design tokens, category colors — `Color(light:dark:)` made cross-platform |
| `LoomKit/Sources/LoomKit/Config/CategoryConfigLoader.swift` | Cross-platform config loader (extracted, remove `Bundle.module` dependency) |
| `LoomKit/Sources/LoomKit/Sync/CloudKitManager.swift` | CKContainer setup, record CRUD, subscriptions |
| `LoomKit/Sources/LoomKit/Sync/SyncEngine.swift` | Model ↔ CKRecord conversion, active session management, heartbeat |
| `LoomKit/Sources/LoomKit/LoomKit.swift` | Public API re-exports |
| `LoomKit/Tests/LoomKitTests/SessionTests.swift` | Session model tests (migrated) |
| `LoomKit/Tests/LoomKitTests/CategoryTests.swift` | Category model tests (migrated) |
| `LoomKit/Tests/LoomKitTests/SyncEngineTests.swift` | CKRecord conversion tests |

### Modified existing files

| File | Change |
|------|--------|
| `Package.swift` | Add LoomKit as local dependency |
| `Loom/Models/Session.swift` | Replace with `import LoomKit` re-export |
| `Loom/Models/Distraction.swift` | Replace with `import LoomKit` re-export |
| `Loom/Models/Category.swift` | Replace with `import LoomKit` re-export |
| `Loom/Models/CategoryColors.swift` | Replace with `import LoomKit` re-export |
| `Loom/Models/ActivityRecord.swift` | **Stays in Loom/** — Mac-only, not shared |
| `Loom/Services/CategoryConfigLoader.swift` | Replace with `import LoomKit` re-export |
| `Loom/Services/SessionEngine.swift` | Add CloudKit sync calls alongside Calendar writes |
| `Loom/LoomApp.swift` | Initialize SyncEngine, wire CloudKit push handling |

### LoomMobile/ (new iOS project)

| File | Responsibility |
|------|---------------|
| `LoomMobile/LoomMobile.xcodeproj` | iOS Xcode project with LoomKit local package dependency |
| `LoomMobile/LoomMobile/LoomMobileApp.swift` | @main entry, AppState, tab structure |
| `LoomMobile/LoomMobile/Views/NowTabView.swift` | Active session display, start/stop controls |
| `LoomMobile/LoomMobile/Views/StartSessionSheet.swift` | Category picker, intention input, recent intentions |
| `LoomMobile/LoomMobile/Views/HistoryTabView.swift` | Week strip, daily summary bar, session list |
| `LoomMobile/LoomMobile/Views/SessionDetailView.swift` | Session detail: apps, distractions, source |
| `LoomMobile/LoomMobile/Views/SettingsTabView.swift` | Categories, appearance, about |
| `LoomMobile/LoomMobile/Services/MobileSessionEngine.swift` | iOS session management via SyncEngine |

---

## Task 1: Create LoomKit Package Scaffold

**Files:**
- Create: `LoomKit/Package.swift`
- Create: `LoomKit/Sources/LoomKit/LoomKit.swift`
- Create: `LoomKit/Tests/LoomKitTests/LoomKitTests.swift`

- [ ] **Step 1: Create LoomKit/Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LoomKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "LoomKit", targets: ["LoomKit"])
    ],
    targets: [
        .target(
            name: "LoomKit",
            path: "Sources/LoomKit"
        ),
        .testTarget(
            name: "LoomKitTests",
            dependencies: ["LoomKit"],
            path: "Tests/LoomKitTests"
        )
    ]
)
```

- [ ] **Step 2: Create placeholder source file**

Create `LoomKit/Sources/LoomKit/LoomKit.swift`:

```swift
// LoomKit — shared models, sync, and config for Loom (macOS + iOS)
```

- [ ] **Step 3: Create placeholder test file**

Create `LoomKit/Tests/LoomKitTests/LoomKitTests.swift`:

```swift
import Testing
@testable import LoomKit

@Suite("LoomKit")
struct LoomKitTests {
    @Test("Package builds")
    func packageBuilds() {
        #expect(true)
    }
}
```

- [ ] **Step 4: Verify it builds**

Run: `cd /Users/bareloved/Github/loom/LoomKit && swift build`
Expected: Build Succeeded

- [ ] **Step 5: Run tests**

Run: `cd /Users/bareloved/Github/loom/LoomKit && swift test`
Expected: All tests passed

- [ ] **Step 6: Commit**

```bash
git add LoomKit/
git commit -m "feat: create LoomKit shared package scaffold"
```

---

## Task 2: Extract Models into LoomKit

**Files:**
- Create: `LoomKit/Sources/LoomKit/Models/Session.swift`
- Create: `LoomKit/Sources/LoomKit/Models/Distraction.swift`
- Create: `LoomKit/Sources/LoomKit/Models/Category.swift`
- Create: `LoomKit/Sources/LoomKit/Models/CategoryColors.swift`
- Migrate tests: `LoomKit/Tests/LoomKitTests/SessionTests.swift`
- Migrate tests: `LoomKit/Tests/LoomKitTests/CategoryTests.swift`

- [ ] **Step 1: Copy Session.swift to LoomKit**

Copy `Loom/Models/Session.swift` → `LoomKit/Sources/LoomKit/Models/Session.swift`. Add `public` access to the struct, all properties, the init, and computed properties. Add `Codable` conformance (needed for CloudKit serialization later):

```swift
import Foundation

public struct Session: Identifiable, Codable {
    public let id: UUID
    public var category: String
    public let startTime: Date
    public var endTime: Date?
    public var appsUsed: [String]
    public var intention: String?
    public var trackingSpanId: UUID?
    public var eventIdentifier: String?
    public var source: String?  // "mac" or "ios" — set when synced via CloudKit
    public var distractions: [Distraction] = []

    public init(
        id: UUID = UUID(),
        category: String,
        startTime: Date,
        endTime: Date? = nil,
        appsUsed: [String],
        intention: String? = nil,
        trackingSpanId: UUID? = nil,
        eventIdentifier: String? = nil,
        source: String? = nil,
        distractions: [Distraction] = []
    ) {
        self.id = id
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.appsUsed = appsUsed
        self.intention = intention
        self.trackingSpanId = trackingSpanId
        self.eventIdentifier = eventIdentifier
        self.source = source
        self.distractions = distractions
    }

    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    public var primaryApp: String? {
        appsUsed.first
    }

    public var isActive: Bool {
        endTime == nil
    }

    public mutating func addApp(_ appName: String) {
        if !appsUsed.contains(appName) {
            appsUsed.append(appName)
        }
    }
}
```

- [ ] **Step 2: Copy Distraction.swift to LoomKit**

Copy `Loom/Models/Distraction.swift` → `LoomKit/Sources/LoomKit/Models/Distraction.swift`. Add `public` access and `Codable`:

```swift
import Foundation

public struct Distraction: Identifiable, Equatable, Codable {
    public let id: UUID
    public let appName: String
    public let bundleId: String
    public let url: String?
    public let startTime: Date
    public var duration: TimeInterval
    public var snoozed: Bool

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String,
        url: String? = nil,
        startTime: Date,
        duration: TimeInterval = 0,
        snoozed: Bool = false
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.url = url
        self.startTime = startTime
        self.duration = duration
        self.snoozed = snoozed
    }
}
```

- [ ] **Step 3: Copy Category.swift to LoomKit**

Copy `Loom/Models/Category.swift` → `LoomKit/Sources/LoomKit/Models/Category.swift`. Add `public` access:

```swift
import Foundation

public struct CategoryRule: Codable, Equatable {
    public var apps: [String]
    public var related: [String]?
    public var urlPatterns: [String]?

    public init(apps: [String], related: [String]? = nil, urlPatterns: [String]? = nil) {
        self.apps = apps
        self.related = related
        self.urlPatterns = urlPatterns
    }
}

public struct CategoryConfig: Codable, Equatable {
    public var categories: [String: CategoryRule]
    public var defaultCategory: String
    public var categoryOrder: [String]?

    enum CodingKeys: String, CodingKey {
        case categories
        case defaultCategory = "default_category"
        case categoryOrder = "category_order"
    }

    public init(categories: [String: CategoryRule], defaultCategory: String, categoryOrder: [String]? = nil) {
        self.categories = categories
        self.defaultCategory = defaultCategory
        self.categoryOrder = categoryOrder
    }

    public var orderedCategoryNames: [String] {
        let allKeys = Set(categories.keys)
        if let order = categoryOrder {
            let ordered = order.filter { allKeys.contains($0) }
            let missing = allKeys.subtracting(ordered).sorted()
            return ordered + missing
        }
        return allKeys.sorted()
    }

    public func category(forBundleId bundleId: String) -> String? {
        for (name, rule) in categories {
            if rule.apps.contains(bundleId) {
                return name
            }
        }
        return nil
    }

    public func isRelated(bundleId: String, toCategory category: String) -> Bool {
        guard let rule = categories[category] else { return false }
        return rule.related?.contains(bundleId) ?? false
    }

    public func resolve(bundleId: String, currentCategory: String?, pageURL: String? = nil) -> String {
        if let primary = category(forBundleId: bundleId) {
            return primary
        }
        if let url = pageURL {
            for (name, rule) in categories {
                if let patterns = rule.urlPatterns {
                    for pattern in patterns {
                        if url.localizedCaseInsensitiveContains(pattern) {
                            return name
                        }
                    }
                }
            }
        }
        if let current = currentCategory, isRelated(bundleId: bundleId, toCategory: current) {
            return current
        }
        return defaultCategory
    }
}
```

- [ ] **Step 4: Copy CategoryColors.swift to LoomKit**

Copy `Loom/Models/CategoryColors.swift` → `LoomKit/Sources/LoomKit/Models/CategoryColors.swift`. Make cross-platform by replacing `NSColor`-based `Color(light:dark:)` with a platform-conditional implementation:

```swift
import SwiftUI

public enum CategoryColors {
    private static let lightColors: [String: Color] = [
        "Coding": Color(hex: 0x7b8db8),
        "Email": Color(hex: 0xc9956a),
        "Communication": Color(hex: 0x5a9a6e),
        "Design": Color(hex: 0xa07cba),
        "Writing": Color(hex: 0xc47878),
        "Browsing": Color(hex: 0x6da89a),
        "Other": Color(hex: 0x9a958e),
    ]

    private static let darkColors: [String: Color] = [
        "Coding": Color(hex: 0x6878a0),
        "Email": Color(hex: 0xb0845e),
        "Communication": Color(hex: 0x4e8760),
        "Design": Color(hex: 0x8a6ca3),
        "Writing": Color(hex: 0xa86868),
        "Browsing": Color(hex: 0x5e9487),
        "Other": Color(hex: 0x6b665f),
    ]

    private static let lightOverflow: [Color] = [
        Color(hex: 0xc4a84e),
        Color(hex: 0x5e9487),
        Color(hex: 0x8a7560),
        Color(hex: 0x7aaa8a),
    ]

    private static let darkOverflow: [Color] = [
        Color(hex: 0xa89040),
        Color(hex: 0x4e8070),
        Color(hex: 0x746350),
        Color(hex: 0x689478),
    ]

    public static let accent = Color(hex: 0xc06040)

    public static let gray = Color(light: Color(hex: 0x9a958e), dark: Color(hex: 0x6b665f))

    public static func color(for category: String) -> Color {
        Color(light: lightColor(for: category), dark: darkColor(for: category))
    }

    private static func lightColor(for category: String) -> Color {
        if let named = lightColors[category] { return named }
        let hash = abs(category.hashValue)
        return lightOverflow[hash % lightOverflow.count]
    }

    private static func darkColor(for category: String) -> Color {
        if let named = darkColors[category] { return named }
        let hash = abs(category.hashValue)
        return darkOverflow[hash % darkOverflow.count]
    }
}

public enum Theme {
    public static let background = Color(light: Color(hex: 0xf7f5f2), dark: Color(hex: 0x242220))
    public static let backgroundSecondary = Color(light: Color(hex: 0xf2efec), dark: Color(hex: 0x1e1c1a))
    public static let border = Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.05))
    public static let borderSubtle = Color(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.04))

    public static let textPrimary = Color(light: Color(hex: 0x1a1a1a), dark: Color(hex: 0xf0ede8))
    public static let textSecondary = Color(light: Color(hex: 0x3a3a3a), dark: Color(hex: 0xc8c3bb))
    public static let textTertiary = Color(light: Color(hex: 0x9a958e), dark: Color(hex: 0x6b665f))
    public static let textQuaternary = Color(light: Color(hex: 0xb5b0a8), dark: Color(hex: 0x4a4540))

    public static let trackFill = Color(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.04))
    public static let idleSegment = Color(light: Color(hex: 0xddd9d3).opacity(0.5), dark: Color(hex: 0x363330).opacity(0.5))
}

// MARK: - Color Helpers

public extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(light: Color, dark: Color) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(dark)
            }
            return NSColor(light)
        })
        #else
        self.init(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(dark)
            }
            return UIColor(light)
        })
        #endif
    }
}
```

- [ ] **Step 5: Migrate Session tests to LoomKit**

Create `LoomKit/Tests/LoomKitTests/SessionTests.swift` — copy from `LoomTests/SessionTests.swift`, change `@testable import Loom` to `@testable import LoomKit`.

- [ ] **Step 6: Migrate Category tests to LoomKit**

Create `LoomKit/Tests/LoomKitTests/CategoryTests.swift` — copy from `LoomTests/CategoryTests.swift`, change `@testable import Loom` to `@testable import LoomKit`.

- [ ] **Step 7: Delete placeholder LoomKitTests.swift**

Delete `LoomKit/Tests/LoomKitTests/LoomKitTests.swift` (replaced by real tests).

- [ ] **Step 8: Build and test LoomKit**

Run: `cd /Users/bareloved/Github/loom/LoomKit && swift test`
Expected: All tests pass

- [ ] **Step 9: Commit**

```bash
git add LoomKit/
git commit -m "feat: extract shared models into LoomKit package"
```

---

## Task 3: Wire Mac App to Depend on LoomKit

**Files:**
- Modify: `Package.swift`
- Modify: `Loom/Models/Session.swift`
- Modify: `Loom/Models/Distraction.swift`
- Modify: `Loom/Models/Category.swift`
- Modify: `Loom/Models/CategoryColors.swift`
- Modify: `LoomTests/SessionTests.swift`
- Modify: `LoomTests/CategoryTests.swift`

- [ ] **Step 1: Update root Package.swift**

Replace `Package.swift` contents to add LoomKit as a local dependency:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Loom",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Loom",
            dependencies: [
                .product(name: "LoomKit", package: "LoomKit")
            ],
            path: "Loom",
            exclude: ["Info.plist", "Loom.entitlements"],
            resources: [
                .copy("Resources/default-categories.json"),
                .copy("Resources/AppIcon.appiconset"),
                .copy("Resources/AppIcon.icns")
            ]
        ),
        .testTarget(
            name: "LoomTests",
            dependencies: ["Loom"],
            path: "LoomTests"
        )
    ]
)

// Local package dependency
package.dependencies.append(
    .package(path: "LoomKit")
)
```

- [ ] **Step 2: Replace Mac model files with re-exports**

Replace `Loom/Models/Session.swift`:
```swift
@_exported import LoomKit
// Session is now provided by LoomKit
```

Replace `Loom/Models/Distraction.swift`:
```swift
@_exported import LoomKit
// Distraction is now provided by LoomKit
```

Replace `Loom/Models/Category.swift`:
```swift
@_exported import LoomKit
// CategoryRule, CategoryConfig are now provided by LoomKit
```

Replace `Loom/Models/CategoryColors.swift`:
```swift
@_exported import LoomKit
// CategoryColors, Theme, Color extensions are now provided by LoomKit
```

Note: Only one of these files needs `@_exported import LoomKit`. The rest can be emptied or contain just a comment. Keep one file with the `@_exported import` so all existing Loom code sees LoomKit types without changes. The simplest approach: put `@_exported import LoomKit` in `Session.swift` and make the other three files empty (or delete them — but keeping them avoids git churn in other files that may reference them).

- [ ] **Step 3: Update Mac test imports**

In `LoomTests/SessionTests.swift` and any other test files that test models now in LoomKit: the `@testable import Loom` still works because of `@_exported import`. No changes needed if `@_exported` is used. Verify by building.

- [ ] **Step 4: Build the Mac app**

Run: `cd /Users/bareloved/Github/loom && swift build -c release`
Expected: Build Succeeded

- [ ] **Step 5: Run Mac tests**

Run: `cd /Users/bareloved/Github/loom && swift test`
Expected: All tests pass

- [ ] **Step 6: Run the app to verify**

Run: `cd /Users/bareloved/Github/loom && ./run.sh`
Expected: App launches, menu bar icon appears, tracking works as before

- [ ] **Step 7: Commit**

```bash
git add Package.swift Loom/Models/
git commit -m "refactor: wire Mac app to use LoomKit for shared models"
```

---

## Task 4: Extract CategoryConfigLoader into LoomKit

**Files:**
- Create: `LoomKit/Sources/LoomKit/Config/CategoryConfigLoader.swift`
- Modify: `Loom/Services/CategoryConfigLoader.swift`
- Modify: `LoomKit/Package.swift` (add resource for default-categories.json)
- Create: `LoomKit/Sources/LoomKit/Config/Resources/default-categories.json`

- [ ] **Step 1: Copy default-categories.json into LoomKit**

Copy `Loom/Resources/default-categories.json` → `LoomKit/Sources/LoomKit/Config/Resources/default-categories.json`

- [ ] **Step 2: Update LoomKit Package.swift for resource**

Add resource to the target:

```swift
.target(
    name: "LoomKit",
    path: "Sources/LoomKit",
    resources: [
        .copy("Config/Resources/default-categories.json")
    ]
)
```

- [ ] **Step 3: Create cross-platform CategoryConfigLoader in LoomKit**

Create `LoomKit/Sources/LoomKit/Config/CategoryConfigLoader.swift`:

```swift
import Foundation

public enum CategoryConfigLoader {

    public static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Loom")
    }()

    public static let defaultConfigPath: URL = {
        appSupportDir.appendingPathComponent("categories.json")
    }()

    public static func loadDefault() throws -> CategoryConfig {
        guard let url = Bundle.module.url(forResource: "default-categories", withExtension: "json") else {
            throw ConfigError.bundledConfigNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CategoryConfig.self, from: data)
    }

    public static func load(from url: URL) throws -> CategoryConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CategoryConfig.self, from: data)
    }

    public static func loadOrCreateDefault(at url: URL? = nil) throws -> CategoryConfig {
        let target = url ?? defaultConfigPath

        if FileManager.default.fileExists(atPath: target.path) {
            return try load(from: target)
        }

        let dir = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let defaultConfig = try loadDefault()
        let data = try JSONEncoder().encode(defaultConfig)
        let pretty = try JSONSerialization.data(
            withJSONObject: try JSONSerialization.jsonObject(with: data),
            options: [.prettyPrinted, .sortedKeys]
        )
        try pretty.write(to: target)

        return defaultConfig
    }

    public static func save(_ config: CategoryConfig, to url: URL? = nil) throws {
        let target = url ?? defaultConfigPath
        let dir = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(config)
        let pretty = try JSONSerialization.data(
            withJSONObject: try JSONSerialization.jsonObject(with: data),
            options: [.prettyPrinted, .sortedKeys]
        )
        try pretty.write(to: target)
    }

    public enum ConfigError: Error {
        case bundledConfigNotFound
    }
}
```

- [ ] **Step 4: Replace Mac's CategoryConfigLoader with re-export**

Replace `Loom/Services/CategoryConfigLoader.swift`:
```swift
// CategoryConfigLoader is now provided by LoomKit via @_exported import
```

- [ ] **Step 5: Migrate CategoryConfigLoader tests to LoomKit**

Copy `LoomTests/CategoryConfigLoaderTests.swift` → `LoomKit/Tests/LoomKitTests/CategoryConfigLoaderTests.swift`, change import to `@testable import LoomKit`.

- [ ] **Step 5b: Migrate CategoryColorsTests to LoomKit**

Copy `LoomTests/CategoryColorsTests.swift` → `LoomKit/Tests/LoomKitTests/CategoryColorsTests.swift`, change import to `@testable import LoomKit`.

Note: `CalendarNotesTests.swift` stays in `LoomTests/` — it tests `CalendarWriter.buildHumanNotes()` which remains Mac-only.

- [ ] **Step 6: Build and test everything**

Run: `cd /Users/bareloved/Github/loom/LoomKit && swift test`
Expected: All LoomKit tests pass

Run: `cd /Users/bareloved/Github/loom && swift test`
Expected: All Mac tests pass

- [ ] **Step 7: Commit**

```bash
git add LoomKit/ Loom/Services/CategoryConfigLoader.swift LoomTests/
git commit -m "refactor: extract CategoryConfigLoader into LoomKit"
```

---

## Task 5: Build CloudKitManager

**Files:**
- Create: `LoomKit/Sources/LoomKit/Sync/CloudKitManager.swift`
- Create: `LoomKit/Tests/LoomKitTests/SyncRecordTests.swift`

- [ ] **Step 1: Write tests for CKRecord ↔ Session conversion**

Create `LoomKit/Tests/LoomKitTests/SyncRecordTests.swift`:

```swift
import Testing
import Foundation
@testable import LoomKit

@Suite("CloudKit Record Conversion")
struct SyncRecordTests {

    @Test("Session round-trips through record fields")
    func sessionRoundTrip() {
        let session = Session(
            category: "Coding",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            appsUsed: ["Xcode", "Terminal"],
            intention: "Build feature",
            trackingSpanId: UUID(),
            eventIdentifier: "EK-123"
        )

        let fields = CloudKitManager.sessionToFields(session, source: "mac")

        #expect(fields["category"] as? String == "Coding")
        #expect(fields["intention"] as? String == "Build feature")
        #expect(fields["source"] as? String == "mac")
        #expect((fields["appsUsed"] as? [String])?.count == 2)

        let restored = CloudKitManager.sessionFromFields(
            id: session.id,
            fields: fields
        )

        #expect(restored.category == session.category)
        #expect(restored.intention == session.intention)
        #expect(restored.appsUsed == session.appsUsed)
        #expect(restored.trackingSpanId == session.trackingSpanId)
        #expect(restored.eventIdentifier == session.eventIdentifier)
    }

    @Test("Distraction round-trips through record fields")
    func distractionRoundTrip() {
        let distraction = Distraction(
            appName: "Twitter",
            bundleId: "com.twitter.twitter",
            url: "https://twitter.com",
            startTime: Date(),
            duration: 120,
            snoozed: true
        )

        let fields = CloudKitManager.distractionToFields(distraction)

        #expect(fields["appName"] as? String == "Twitter")
        #expect(fields["url"] as? String == "https://twitter.com")
        #expect(fields["snoozed"] as? Bool == true)

        let restored = CloudKitManager.distractionFromFields(
            id: distraction.id,
            fields: fields
        )

        #expect(restored.appName == distraction.appName)
        #expect(restored.bundleId == distraction.bundleId)
        #expect(restored.url == distraction.url)
        #expect(restored.duration == distraction.duration)
        #expect(restored.snoozed == distraction.snoozed)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/bareloved/Github/loom/LoomKit && swift test`
Expected: FAIL — `CloudKitManager` not found

- [ ] **Step 3: Implement CloudKitManager**

Create `LoomKit/Sources/LoomKit/Sync/CloudKitManager.swift`:

```swift
import Foundation
import CloudKit

public final class CloudKitManager: Sendable {

    public static let containerID = "iCloud.com.bareloved.Loom"

    public static let sessionRecordType = "CKSession"
    public static let distractionRecordType = "CKDistraction"
    public static let categoryConfigRecordType = "CKCategoryConfig"
    public static let activeSessionRecordType = "CKActiveSession"

    private let container: CKContainer
    private let database: CKDatabase

    public init() {
        self.container = CKContainer(identifier: Self.containerID)
        self.database = container.privateCloudDatabase
    }

    // MARK: - Session ↔ Fields

    public static func sessionToFields(_ session: Session, source: String) -> [String: Any] {
        var fields: [String: Any] = [
            "category": session.category,
            "startTime": session.startTime,
            "appsUsed": session.appsUsed,
            "source": source,
        ]
        if let endTime = session.endTime { fields["endTime"] = endTime }
        if let intention = session.intention { fields["intention"] = intention }
        if let spanId = session.trackingSpanId { fields["trackingSpanId"] = spanId.uuidString }
        if let eventId = session.eventIdentifier { fields["eventIdentifier"] = eventId }
        return fields
    }

    public static func sessionFromFields(id: UUID, fields: [String: Any]) -> Session {
        Session(
            id: id,
            category: fields["category"] as? String ?? "Other",
            startTime: fields["startTime"] as? Date ?? Date(),
            endTime: fields["endTime"] as? Date,
            appsUsed: fields["appsUsed"] as? [String] ?? [],
            intention: fields["intention"] as? String,
            trackingSpanId: (fields["trackingSpanId"] as? String).flatMap(UUID.init),
            eventIdentifier: fields["eventIdentifier"] as? String,
            source: fields["source"] as? String
        )
    }

    // MARK: - Fetch Single Session

    public func fetchSession(id: UUID) async throws -> Session? {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            return nil
        }
        var fields: [String: Any] = [:]
        for key in record.allKeys() {
            fields[key] = record[key]
        }
        return Self.sessionFromFields(id: id, fields: fields)
    }

    // MARK: - Distraction ↔ Fields

    public static func distractionToFields(_ distraction: Distraction) -> [String: Any] {
        var fields: [String: Any] = [
            "appName": distraction.appName,
            "bundleId": distraction.bundleId,
            "startTime": distraction.startTime,
            "duration": distraction.duration,
            "snoozed": distraction.snoozed,
        ]
        if let url = distraction.url { fields["url"] = url }
        return fields
    }

    public static func distractionFromFields(id: UUID, fields: [String: Any]) -> Distraction {
        Distraction(
            id: id,
            appName: fields["appName"] as? String ?? "",
            bundleId: fields["bundleId"] as? String ?? "",
            url: fields["url"] as? String,
            startTime: fields["startTime"] as? Date ?? Date(),
            duration: fields["duration"] as? TimeInterval ?? 0,
            snoozed: fields["snoozed"] as? Bool ?? false
        )
    }

    // MARK: - CRUD Operations

    public func saveSession(_ session: Session, source: String) async throws {
        let record = CKRecord(recordType: Self.sessionRecordType,
                              recordID: CKRecord.ID(recordName: session.id.uuidString))
        let fields = Self.sessionToFields(session, source: source)
        for (key, value) in fields {
            record[key] = value as? CKRecordValue
        }
        try await database.save(record)
    }

    public func updateSession(_ session: Session, source: String) async throws {
        let recordID = CKRecord.ID(recordName: session.id.uuidString)
        let record = try await database.record(for: recordID)
        let fields = Self.sessionToFields(session, source: source)
        for (key, value) in fields {
            record[key] = value as? CKRecordValue
        }
        try await database.save(record)
    }

    public func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [Session] {
        let predicate = NSPredicate(format: "startTime >= %@ AND startTime <= %@",
                                    startDate as NSDate, endDate as NSDate)
        let query = CKQuery(recordType: Self.sessionRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        let (results, _) = try await database.records(matching: query)
        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
            var fields: [String: Any] = [:]
            for key in record.allKeys() {
                fields[key] = record[key]
            }
            return Self.sessionFromFields(id: id, fields: fields)
        }
    }

    // MARK: - Active Session

    public func updateActiveSession(sessionID: UUID?, source: String) async throws {
        let recordID = CKRecord.ID(recordName: "active")
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: Self.activeSessionRecordType, recordID: recordID)
        }

        if let sessionID {
            let sessionRecordID = CKRecord.ID(recordName: sessionID.uuidString)
            record["sessionRef"] = CKRecord.Reference(recordID: sessionRecordID, action: .none)
            record["source"] = source
        } else {
            record["sessionRef"] = nil
            record["source"] = source
        }
        record["lastHeartbeat"] = Date()

        try await database.save(record)
    }

    public func fetchActiveSession() async throws -> (sessionID: UUID?, source: String, lastHeartbeat: Date)? {
        let recordID = CKRecord.ID(recordName: "active")
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            return nil
        }

        let ref = record["sessionRef"] as? CKRecord.Reference
        let sessionID = ref.flatMap { UUID(uuidString: $0.recordID.recordName) }
        let source = record["source"] as? String ?? "unknown"
        let heartbeat = record["lastHeartbeat"] as? Date ?? Date.distantPast

        return (sessionID, source, heartbeat)
    }

    // MARK: - Category Config

    public func saveCategoryConfig(_ config: CategoryConfig) async throws {
        let recordID = CKRecord.ID(recordName: "current")
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: Self.categoryConfigRecordType, recordID: recordID)
        }

        let data = try JSONEncoder().encode(config)
        record["configJSON"] = String(data: data, encoding: .utf8)
        record["lastModified"] = Date()

        try await database.save(record)
    }

    public func fetchCategoryConfig() async throws -> CategoryConfig? {
        let recordID = CKRecord.ID(recordName: "current")
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            return nil
        }

        guard let json = record["configJSON"] as? String,
              let data = json.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(CategoryConfig.self, from: data)
    }

    // MARK: - Subscriptions

    public func setupSubscriptions() async throws {
        let sessionSub = CKQuerySubscription(
            recordType: Self.sessionRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "session-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        sessionSub.notificationInfo = CKSubscription.NotificationInfo(shouldSendContentAvailable: true)

        let activeSub = CKQuerySubscription(
            recordType: Self.activeSessionRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "active-session-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        activeSub.notificationInfo = CKSubscription.NotificationInfo(shouldSendContentAvailable: true)

        let configSub = CKQuerySubscription(
            recordType: Self.categoryConfigRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "config-changes",
            options: [.firesOnRecordUpdate]
        )
        configSub.notificationInfo = CKSubscription.NotificationInfo(shouldSendContentAvailable: true)

        try await database.save(sessionSub)
        try await database.save(activeSub)
        try await database.save(configSub)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/bareloved/Github/loom/LoomKit && swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add LoomKit/
git commit -m "feat: implement CloudKitManager with record conversion and CRUD"
```

---

## Task 6: Build SyncEngine

**Files:**
- Create: `LoomKit/Sources/LoomKit/Sync/SyncEngine.swift`

- [ ] **Step 1: Implement SyncEngine**

Create `LoomKit/Sources/LoomKit/Sync/SyncEngine.swift`:

```swift
import Foundation
import CloudKit
import Combine

@MainActor
@Observable
public final class SyncEngine {

    public private(set) var activeSessionID: UUID?
    public private(set) var activeSource: String?
    public private(set) var lastHeartbeat: Date?
    public private(set) var isStale: Bool = false

    private let cloudKit: CloudKitManager
    private let source: String // "mac" or "ios"
    private var heartbeatTimer: Timer?

    public init(source: String) {
        self.cloudKit = CloudKitManager()
        self.source = source
    }

    // MARK: - Session Lifecycle

    public func publishSessionStart(_ session: Session) async {
        do {
            try await cloudKit.saveSession(session, source: source)
            try await cloudKit.updateActiveSession(sessionID: session.id, source: source)
            activeSessionID = session.id
            activeSource = source
            startHeartbeat()
        } catch {
            print("SyncEngine: failed to publish session start: \(error)")
        }
    }

    public func publishSessionUpdate(_ session: Session) async {
        do {
            try await cloudKit.updateSession(session, source: source)
            try await cloudKit.updateActiveSession(sessionID: session.id, source: source)
        } catch {
            print("SyncEngine: failed to publish session update: \(error)")
        }
    }

    public func publishSessionStop(_ session: Session) async {
        stopHeartbeat()
        do {
            try await cloudKit.updateSession(session, source: source)
            try await cloudKit.updateActiveSession(sessionID: nil, source: source)
            activeSessionID = nil
            activeSource = nil
        } catch {
            print("SyncEngine: failed to publish session stop: \(error)")
        }
    }

    // MARK: - Remote State

    public func fetchActiveState() async {
        do {
            if let state = try await cloudKit.fetchActiveSession() {
                activeSessionID = state.sessionID
                activeSource = state.source
                lastHeartbeat = state.lastHeartbeat

                let staleness = Date().timeIntervalSince(state.lastHeartbeat)
                isStale = staleness > 120 // 2 minutes
            } else {
                activeSessionID = nil
                activeSource = nil
                isStale = false
            }
        } catch {
            print("SyncEngine: failed to fetch active state: \(error)")
        }
    }

    public func forceStopRemoteSession() async {
        stopHeartbeat()
        do {
            try await cloudKit.updateActiveSession(sessionID: nil, source: source)
            activeSessionID = nil
            activeSource = nil
        } catch {
            print("SyncEngine: failed to force stop: \(error)")
        }
    }

    public func fetchSession(by id: UUID) async -> Session? {
        do {
            return try await cloudKit.fetchSession(id: id)
        } catch {
            print("SyncEngine: failed to fetch session: \(error)")
            return nil
        }
    }

    // MARK: - History

    public func fetchSessions(from start: Date, to end: Date) async -> [Session] {
        do {
            return try await cloudKit.fetchSessions(from: start, to: end)
        } catch {
            print("SyncEngine: failed to fetch sessions: \(error)")
            return []
        }
    }

    // MARK: - Category Config Sync

    public func publishCategoryConfig(_ config: CategoryConfig) async {
        do {
            try await cloudKit.saveCategoryConfig(config)
        } catch {
            print("SyncEngine: failed to publish config: \(error)")
        }
    }

    public func fetchCategoryConfig() async -> CategoryConfig? {
        do {
            return try await cloudKit.fetchCategoryConfig()
        } catch {
            print("SyncEngine: failed to fetch config: \(error)")
            return nil
        }
    }

    // MARK: - Subscriptions

    public func setupSubscriptions() async {
        do {
            try await cloudKit.setupSubscriptions()
        } catch {
            print("SyncEngine: failed to setup subscriptions: \(error)")
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let sessionID = self.activeSessionID else { return }
                try? await self.cloudKit.updateActiveSession(sessionID: sessionID, source: self.source)
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}
```

- [ ] **Step 2: Build LoomKit**

Run: `cd /Users/bareloved/Github/loom/LoomKit && swift build`
Expected: Build Succeeded

- [ ] **Step 3: Commit**

```bash
git add LoomKit/Sources/LoomKit/Sync/SyncEngine.swift
git commit -m "feat: implement SyncEngine for session lifecycle and remote state"
```

---

## Task 7: Integrate CloudKit Sync into Mac App

**Files:**
- Modify: `Loom/Services/SessionEngine.swift`
- Modify: `Loom/LoomApp.swift`

- [ ] **Step 1: Add SyncEngine to SessionEngine**

Modify `Loom/Services/SessionEngine.swift` to accept an optional `SyncEngine` and call it alongside `CalendarWriter`:

In `init`, add `syncEngine` parameter:
```swift
private let syncEngine: SyncEngine?

init(calendarWriter: CalendarWriter?, syncEngine: SyncEngine? = nil) {
    self.calendarWriter = calendarWriter
    self.syncEngine = syncEngine
}
```

In `startSession`, after `calendarWriter?.createEvent(for: session)`:
```swift
if let syncEngine {
    Task { await syncEngine.publishSessionStart(session) }
}
```

In `stopSession`, after `calendarWriter?.finalizeEvent(for: session)`:
```swift
if let syncEngine {
    Task { await syncEngine.publishSessionStop(session) }
}
```

In `process(_:)`, after `calendarWriter?.updateCurrentEvent(session: session)`:
```swift
// CloudKit update is handled by heartbeat timer, not per-activity
```

In `handleIdle(at:)`, after `calendarWriter?.finalizeEvent(for: session)`:
```swift
if let syncEngine {
    Task { await syncEngine.publishSessionStop(session) }
}
```

- [ ] **Step 2: Wire SyncEngine in AppState**

In `Loom/LoomApp.swift`, add to `AppState`:

```swift
var syncEngine: SyncEngine?
```

In `setup()`, after creating the `SessionEngine`, initialize and wire SyncEngine:

```swift
let sync = SyncEngine(source: "mac")
self.syncEngine = sync

let engine = SessionEngine(calendarWriter: calendarWriter, syncEngine: sync)
self.sessionEngine = engine

// Setup CloudKit subscriptions
Task { await sync.setupSubscriptions() }
```

Also update `saveConfig` to sync config to CloudKit:

```swift
func saveConfig(_ newConfig: CategoryConfig) {
    do {
        try CategoryConfigLoader.save(newConfig)
        self.categoryConfig = newConfig
        if let syncEngine {
            Task { await syncEngine.publishCategoryConfig(newConfig) }
        }
    } catch {
        print("Failed to save config: \(error)")
    }
}
```

- [ ] **Step 3: Build the Mac app**

Run: `cd /Users/bareloved/Github/loom && swift build -c release`
Expected: Build Succeeded

- [ ] **Step 4: Run Mac tests**

Run: `cd /Users/bareloved/Github/loom && swift test`
Expected: All tests pass (SessionEngine tests use `nil` for syncEngine)

- [ ] **Step 5: Commit**

```bash
git add Loom/Services/SessionEngine.swift Loom/LoomApp.swift
git commit -m "feat: integrate CloudKit sync into Mac session lifecycle"
```

---

## Task 8: Create iOS Xcode Project

**Files:**
- Create: `LoomMobile/LoomMobile.xcodeproj` (via Xcode or `xcodegen`)
- Create: `LoomMobile/LoomMobile/LoomMobileApp.swift`

- [ ] **Step 1: Create project directory structure**

```bash
mkdir -p LoomMobile/LoomMobile/Views
mkdir -p LoomMobile/LoomMobile/Services
```

- [ ] **Step 2: Create LoomMobileApp.swift entry point**

Create `LoomMobile/LoomMobile/LoomMobileApp.swift`:

```swift
import SwiftUI
import LoomKit

@Observable
@MainActor
final class MobileAppState {
    var syncEngine = SyncEngine(source: "ios")
    var categoryConfig: CategoryConfig?
    var currentSession: Session?      // locally started session
    var remoteSession: Session?       // fetched from CloudKit when Mac is tracking
    var isReady = false

    func setup() async {
        await syncEngine.setupSubscriptions()
        await refreshActiveState()

        if let remoteConfig = await syncEngine.fetchCategoryConfig() {
            categoryConfig = remoteConfig
        } else {
            categoryConfig = try? CategoryConfigLoader.loadDefault()
        }

        isReady = true
    }

    func refreshActiveState() async {
        await syncEngine.fetchActiveState()
        // If there's an active remote session, fetch its details
        if let activeID = syncEngine.activeSessionID, currentSession == nil {
            remoteSession = await syncEngine.fetchSession(by: activeID)
        } else {
            remoteSession = nil
        }
    }

    func startSession(category: String, intention: String?) async {
        // Check for existing active session
        await syncEngine.fetchActiveState()
        if syncEngine.activeSessionID != nil {
            // Caller should handle this — prompt user first
            return
        }

        let session = Session(
            category: category,
            startTime: Date(),
            appsUsed: [],
            intention: intention
        )
        currentSession = session
        await syncEngine.publishSessionStart(session)
    }

    func stopSession() async {
        if var session = currentSession {
            session.endTime = Date()
            await syncEngine.publishSessionStop(session)
            currentSession = nil
        } else if syncEngine.activeSessionID != nil {
            // Remote stop
            await syncEngine.forceStopRemoteSession()
        }
    }

    func fetchSessions(for date: Date) async -> [Session] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return await syncEngine.fetchSessions(from: start, to: end)
    }
}

@main
struct LoomMobileApp: App {
    @State private var appState = MobileAppState()
    @AppStorage("appearance") private var appearance = "system"

    private var appearanceScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if appState.isReady {
                ContentView(appState: appState)
                    .preferredColorScheme(appearanceScheme)
            } else {
                ProgressView("Loading...")
                    .task { await appState.setup() }
            }
        }
    }
}

struct ContentView: View {
    let appState: MobileAppState

    var body: some View {
        TabView {
            NowTabView(appState: appState)
                .tabItem {
                    Label("Now", systemImage: "circle.fill")
                }
            HistoryTabView(appState: appState)
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
            SettingsTabView(appState: appState)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(CategoryColors.accent)
    }
}
```

- [ ] **Step 3: Create Xcode project**

The iOS project needs to be created via Xcode (File → New → Project → iOS App) at `LoomMobile/`, then add `../LoomKit` as a local Swift Package dependency. Set:
- Bundle ID: `com.bareloved.LoomMobile`
- Deployment target: iOS 17.0
- Signing: automatic with your team
- Capabilities: CloudKit with container `iCloud.com.bareloved.Loom`
- Background Modes: Remote notifications

Alternatively, use the Swift file created in Step 2 as the app entry point.

- [ ] **Step 4: Verify it builds in Xcode**

Open `LoomMobile/LoomMobile.xcodeproj`, verify it builds for iOS Simulator.
Expected: Build Succeeded (views will be placeholder)

- [ ] **Step 5: Commit**

```bash
git add LoomMobile/
git commit -m "feat: create iOS app project with LoomKit integration"
```

---

## Task 9: Build iOS Now Tab

**Files:**
- Create: `LoomMobile/LoomMobile/Views/NowTabView.swift`
- Create: `LoomMobile/LoomMobile/Views/StartSessionSheet.swift`

- [ ] **Step 1: Create NowTabView**

Create `LoomMobile/LoomMobile/Views/NowTabView.swift`:

```swift
import SwiftUI
import LoomKit

struct NowTabView: View {
    let appState: MobileAppState
    @State private var showStartSheet = false
    @State private var showStopConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if let session = appState.currentSession {
                    activeSessionView(session, source: "ios")
                } else if let remote = appState.remoteSession {
                    activeSessionView(remote, source: remote.source ?? "mac")
                } else if appState.syncEngine.activeSessionID != nil {
                    // Have an active ID but haven't fetched details yet
                    ProgressView()
                } else {
                    idleView
                }
            }
            .navigationTitle("Now")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showStartSheet) {
                StartSessionSheet(appState: appState)
            }
            .task {
                await appState.refreshActiveState()
            }
            .refreshable {
                await appState.refreshActiveState()
            }
        }
    }

    private func activeSessionView(_ session: Session, source: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Currently tracking")
                .font(.caption)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Theme.textTertiary)

            Text(session.category)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(CategoryColors.color(for: session.category))

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(timerString(from: session.startTime, now: context.date))
                    .font(.system(size: 48, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }

            if let intention = session.intention, !intention.isEmpty {
                Text(intention)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            if !session.appsUsed.isEmpty {
                HStack(spacing: 6) {
                    ForEach(session.appsUsed.prefix(5), id: \.self) { app in
                        Text(app)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(CategoryColors.color(for: session.category).opacity(0.15))
                            .foregroundStyle(CategoryColors.color(for: session.category))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            if source != "ios" {
                Text("from Mac")
                    .font(.caption2)
                    .foregroundStyle(Theme.textQuaternary)

                if appState.syncEngine.isStale {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Connection may be stale")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)

                    Button("Force Stop") {
                        Task { await appState.syncEngine.forceStopRemoteSession() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Spacer()

            Button {
                Task { await appState.stopSession() }
            } label: {
                Text("Stop Session")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(CategoryColors.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("No active session")
                .font(.title3)
                .foregroundStyle(Theme.textTertiary)

            Button {
                showStartSheet = true
            } label: {
                Text("Start Session")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(CategoryColors.accent)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func timerString(from start: Date, now: Date = Date()) -> String {
        let elapsed = Int(now.timeIntervalSince(start))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}
```

- [ ] **Step 2: Create StartSessionSheet**

Create `LoomMobile/LoomMobile/Views/StartSessionSheet.swift`:

```swift
import SwiftUI
import LoomKit

struct StartSessionSheet: View {
    let appState: MobileAppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: String = "Coding"
    @State private var intention: String = ""
    @State private var showActiveWarning = false

    private var categories: [String] {
        appState.categoryConfig?.orderedCategoryNames ?? ["Other"]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Category picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.caption)
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundStyle(Theme.textTertiary)

                            FlowLayout(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    Button {
                                        selectedCategory = cat
                                    } label: {
                                        Text(cat)
                                            .font(.subheadline)
                                            .fontWeight(selectedCategory == cat ? .semibold : .regular)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedCategory == cat
                                                    ? CategoryColors.color(for: cat).opacity(0.2)
                                                    : Theme.trackFill
                                            )
                                            .foregroundStyle(
                                                selectedCategory == cat
                                                    ? CategoryColors.color(for: cat)
                                                    : Theme.textSecondary
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(
                                                        selectedCategory == cat
                                                            ? CategoryColors.color(for: cat)
                                                            : Theme.border,
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Intention
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Intention")
                                .font(.caption)
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundStyle(Theme.textTertiary)

                            TextField("What are you working on?", text: $intention)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        Task {
                            await appState.startSession(
                                category: selectedCategory,
                                intention: intention.isEmpty ? nil : intention
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .tint(CategoryColors.accent)
                }
            }
            .alert("Session Already Active", isPresented: $showActiveWarning) {
                Button("Stop & Start New") {
                    Task {
                        await appState.stopSession()
                        await appState.startSession(
                            category: selectedCategory,
                            intention: intention.isEmpty ? nil : intention
                        )
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let source = appState.syncEngine.activeSource == "mac" ? "Mac" : "iPhone"
                Text("A session is already running on \(source). Stop it and start a new one?")
            }
            .task {
                await appState.refreshActiveState()
                if appState.syncEngine.activeSessionID != nil {
                    showActiveWarning = true
                }
            }
        }
    }
}

// Simple flow layout for category chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
```

- [ ] **Step 3: Build in Xcode**

Build the iOS target in Xcode Simulator.
Expected: Build Succeeded, Now tab renders

- [ ] **Step 4: Commit**

```bash
git add LoomMobile/LoomMobile/Views/
git commit -m "feat: implement Now tab and Start Session sheet for iOS"
```

---

## Task 10: Build iOS History Tab

**Files:**
- Create: `LoomMobile/LoomMobile/Views/HistoryTabView.swift`
- Create: `LoomMobile/LoomMobile/Views/SessionDetailView.swift`

- [ ] **Step 1: Create HistoryTabView**

Create `LoomMobile/LoomMobile/Views/HistoryTabView.swift`:

```swift
import SwiftUI
import LoomKit

struct HistoryTabView: View {
    let appState: MobileAppState
    @State private var selectedDate = Date()
    @State private var sessions: [Session] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    weekStrip
                    dailySummaryBar
                    sessionList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadSessions() }
            .onChange(of: selectedDate) {
                Task { await loadSessions() }
            }
        }
    }

    private var weekStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!

        return HStack {
            ForEach(0..<7, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDate(date, inSameDayAs: today)

                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.caption)
                            .fontWeight(isSelected ? .bold : .regular)
                            .frame(width: 28, height: 28)
                            .background(isSelected ? CategoryColors.accent : Color.clear)
                            .foregroundStyle(isSelected ? .white : (isToday ? CategoryColors.accent : Theme.textSecondary))
                            .clipShape(Circle())
                    }
                    .foregroundStyle(isSelected ? CategoryColors.accent : Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var dailySummaryBar: some View {
        let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        return VStack(alignment: .leading, spacing: 6) {
            Text("\(selectedDate.formatted(.dateTime.weekday(.wide))) — \(hours)h \(minutes)m tracked")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)

            if !sessions.isEmpty {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(sessions) { session in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(CategoryColors.color(for: session.category))
                                .frame(width: max(2, geo.size.width * session.duration / max(totalDuration, 1)))
                        }
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if sessions.isEmpty {
                    Text("No sessions")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 40)
                } else {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.category)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textPrimary)
                if let intention = session.intention, !intention.isEmpty {
                    Text(intention)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(durationString(session.duration))
                    .font(.body)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(timeRange(session))
                    .font(.caption2)
                    .foregroundStyle(Theme.textQuaternary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Theme.border.frame(height: 1)
        }
    }

    private func loadSessions() async {
        isLoading = true
        sessions = await appState.fetchSessions(for: selectedDate)
        isLoading = false
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    private func timeRange(_ session: Session) -> String {
        let start = session.startTime.formatted(date: .omitted, time: .shortened)
        let end = (session.endTime ?? Date()).formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}
```

- [ ] **Step 2: Create SessionDetailView**

Create `LoomMobile/LoomMobile/Views/SessionDetailView.swift`:

```swift
import SwiftUI
import LoomKit

struct SessionDetailView: View {
    let session: Session

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.category)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(CategoryColors.color(for: session.category))

                        if let intention = session.intention, !intention.isEmpty {
                            Text(intention)
                                .font(.body)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    // Duration
                    HStack {
                        Label {
                            Text(durationString(session.duration))
                        } icon: {
                            Image(systemName: "clock")
                        }
                        .foregroundStyle(Theme.textPrimary)

                        Spacer()

                        Text(timeRange)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textTertiary)
                    }

                    // Apps
                    if !session.appsUsed.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Apps Used")
                                .font(.caption)
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundStyle(Theme.textTertiary)

                            FlowLayout(spacing: 6) {
                                ForEach(session.appsUsed, id: \.self) { app in
                                    Text(app)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Theme.trackFill)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }

                    // Distractions
                    if !session.distractions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Distractions")
                                .font(.caption)
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundStyle(Theme.textTertiary)

                            ForEach(session.distractions) { d in
                                HStack {
                                    Text(d.appName)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text(durationString(d.duration))
                                        .foregroundStyle(Theme.textTertiary)
                                    if d.snoozed {
                                        Image(systemName: "moon.fill")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.textQuaternary)
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var timeRange: String {
        let start = session.startTime.formatted(date: .abbreviated, time: .shortened)
        let end = (session.endTime ?? Date()).formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
```

- [ ] **Step 3: Build in Xcode**

Build iOS target.
Expected: Build Succeeded

- [ ] **Step 4: Commit**

```bash
git add LoomMobile/LoomMobile/Views/
git commit -m "feat: implement History tab and Session detail for iOS"
```

---

## Task 11: Build iOS Settings Tab

**Files:**
- Create: `LoomMobile/LoomMobile/Views/SettingsTabView.swift`

- [ ] **Step 1: Create SettingsTabView**

Create `LoomMobile/LoomMobile/Views/SettingsTabView.swift`:

```swift
import SwiftUI
import LoomKit

struct SettingsTabView: View {
    let appState: MobileAppState
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    Section("Categories") {
                        if let config = appState.categoryConfig {
                            ForEach(config.orderedCategoryNames, id: \.self) { name in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(CategoryColors.color(for: name))
                                        .frame(width: 10, height: 10)
                                    Text(name)
                                        .foregroundStyle(Theme.textPrimary)
                                }
                            }
                        }
                    }

                    Section("Appearance") {
                        Picker("Theme", selection: $appearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                    }

                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
```

- [ ] **Step 2: Build in Xcode**

Build iOS target.
Expected: Build Succeeded

- [ ] **Step 3: Commit**

```bash
git add LoomMobile/LoomMobile/Views/SettingsTabView.swift
git commit -m "feat: implement Settings tab for iOS"
```

---

## Task 12: End-to-End Verification

- [ ] **Step 1: Run all LoomKit tests**

Run: `cd /Users/bareloved/Github/loom/LoomKit && swift test`
Expected: All tests pass

- [ ] **Step 2: Run all Mac app tests**

Run: `cd /Users/bareloved/Github/loom && swift test`
Expected: All tests pass

- [ ] **Step 3: Build Mac app**

Run: `cd /Users/bareloved/Github/loom && swift build -c release`
Expected: Build Succeeded

- [ ] **Step 4: Build iOS app**

Build iOS target in Xcode for Simulator.
Expected: Build Succeeded

- [ ] **Step 5: Manual test — Mac app still works**

Run: `./run.sh`
Verify: Menu bar icon appears, can start/stop sessions, calendar events created

- [ ] **Step 6: Manual test — iOS Simulator**

Run iOS app in Simulator.
Verify: All three tabs render, can navigate between them

- [ ] **Step 7: Add .superpowers to .gitignore**

```bash
echo ".superpowers/" >> .gitignore
```

- [ ] **Step 8: Final commit**

```bash
git add .gitignore
git commit -m "chore: add .superpowers to gitignore"
```

# Loom iOS Companion App — Design Spec

## Overview

A companion iOS app for the Loom macOS time tracker. Provides remote control of Mac sessions, a manual timer for standalone mobile tracking, and unified session history across both devices. Data syncs via CloudKit.

## Goals

1. **Remote control** — Start/stop Mac sessions, set intentions, pick categories from iPhone
2. **Manual timer** — Track standalone sessions on iPhone when away from Mac
3. **Review** — Browse session history and stats from both devices in one place

## Non-Goals

- Auto-tracking on iOS (no frontmost app detection — iOS doesn't allow it)
- FocusGuard / distraction nudges on iPhone
- Browser URL extraction on iOS
- Idle detection on iOS
- Screen Time API integration (entitlement gated, not worth the complexity)

## Project Structure

Option C: Separate iOS project + shared LoomKit package. Least disruption to the working Mac app.

```
loom/
  Loom/                    # existing Mac app (unchanged initially)
  LoomTests/               # existing tests
  Package.swift            # updated: adds LoomKit dependency
  run.sh                   # unchanged

  LoomKit/                 # NEW — shared Swift package
    Sources/LoomKit/
      Models/              # Session, Distraction, CategoryConfig, etc.
      Sync/                # CloudKitSync engine
      Config/              # CategoryConfigLoader (cross-platform)
    Tests/LoomKitTests/
    Package.swift

  LoomMobile/              # NEW — iOS Xcode project
    LoomMobile.xcodeproj
    LoomMobile/
      LoomMobileApp.swift  # entry point
      Views/               # iOS-specific SwiftUI views
      Services/            # iOS-specific services
```

- **LoomKit** is a local Swift Package in the repo, depended on by both Mac and iOS apps
- LoomKit targets: macOS 14+, iOS 17+
- CloudKit container: `iCloud.com.bareloved.Loom` (both apps share this container)
- Mac app continues to build via `swift build` / `run.sh`, now importing LoomKit
- iOS app is a standard Xcode project importing LoomKit as a local package dependency

## CloudKit Data Model

All records stored in the CloudKit **private database** (user's iCloud account, free tier).

### CKSession

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Record name |
| category | String | e.g., "Coding" |
| startTime | Date | Session start |
| endTime | Date? | nil = active |
| intention | String? | User-entered intent |
| appsUsed | [String] | Deduplicated app names |
| source | String | "mac" or "ios" |
| trackingSpanId | UUID? | Mac-only, for multi-span session correlation |
| eventIdentifier | String? | macOS Calendar event ID |

### CKDistraction

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Record name |
| sessionRef | CKReference | → CKSession |
| appName | String | e.g., "Twitter" |
| bundleId | String | e.g., "com.twitter.twitter" |
| url | String? | Browser URL if applicable |
| duration | Double | Seconds |
| snoozed | Bool | User snoozed FocusGuard alert |

### CKCategoryConfig

Singleton record (id = "current").

| Field | Type | Notes |
|-------|------|-------|
| id | String | "current" |
| configJSON | String | Full categories.json content |
| lastModified | Date | For conflict detection |

Syncs category setup to iOS. Editable from either device — last-write-wins.

### CKActiveSession

Singleton record (id = "active") for remote control.

| Field | Type | Notes |
|-------|------|-------|
| id | String | "active" |
| sessionRef | CKReference? | → CKSession (nil = no active session) |
| source | String | "mac" or "ios" |
| lastHeartbeat | Date | Staleness detection |

## Sync Strategy

- **CloudKit push notifications** (CKSubscription) notify each device when records change
- Mac heartbeats every 30s (aligned with existing CalendarWriter update timer)
- **Conflict resolution**: last-write-wins for singletons, append-only for sessions/distractions
- **Offline**: CloudKit queues changes locally, syncs when connectivity returns

### Mac Dual-Write

The Mac app writes to **both** macOS Calendar (EventKit) and CloudKit:
- Calendar remains the Mac's local record (user likes seeing sessions there)
- CloudKit is the shared data store for cross-device access
- `eventIdentifier` field in CKSession links back to the Calendar event

### CKActiveSession Updates

When Mac starts a session: creates CKSession record **and** updates CKActiveSession (sets sessionRef, source="mac", heartbeat). When Mac stops: finalizes CKSession endTime **and** clears CKActiveSession (sets sessionRef=nil). Same flow for iOS-initiated sessions. This ensures the Now Tab on either device always reflects the current state.

## iOS App Screens

Three tabs + session start sheet.

### Now Tab

- Shows live session status: category, timer, intention, apps used
- "from Mac" / "from iPhone" label indicating source device
- Stop Session button (works for both local and remote sessions)
- When no session active: Start Session button opens sheet

### Start Session Sheet

- Category picker (chip/pill layout, synced from CKCategoryConfig)
- Intention text field
- Recent intentions list for quick selection
- Start button — creates CKSession + updates CKActiveSession

### History Tab

- Week strip date selector (matches Mac's WeekStripView pattern)
- Daily summary bar (colored segments per category)
- Scrollable session list: category, intention, duration, time range
- Tapping a session shows detail (apps, distractions, source device)

### Settings Tab (minimal)

- Category management (view/reorder, synced from Mac)
- Appearance toggle (light/dark/system)
- About/version

## Edge Cases

### Two sessions started simultaneously
Before starting a session, both devices check CKActiveSession. If a session is already active, the user is prompted: "A session is already running on [Mac/iPhone]. Stop it and start a new one?" This prevents accidental overlapping sessions. If the user confirms, the existing session is stopped first.

### Remote stop while Mac is tracking
iPhone writes nil to CKActiveSession. Mac receives push notification, stops SessionEngine, finalizes Calendar event.

### Stale active session (Mac crash)
`lastHeartbeat` goes stale (> 2 min old). iPhone detects this and offers to force-stop the session.

### Offline edits
CloudKit queues locally. Both devices work independently offline. Sync reconciles on reconnect.

## Design System

Same warm/matte/earthy design system as the Mac app:
- Terracotta accent (#c06040)
- Category colors shared via LoomKit (dusty blue, warm clay, matte green, etc.)
- Light/dark/system appearance via @AppStorage("appearance")
- Design tokens defined in LoomKit so both platforms share them

## LoomKit Package Contents

Extracted from existing Mac app + new sync code:

### Models (extracted from Loom/Models/)
- `Session` — shared session model
- `Distraction` — shared distraction model
- `CategoryRule`, `CategoryConfig` — category definitions and resolution logic
- `CategoryColors` — design tokens and category color definitions

### Sync (new)
- `CloudKitSync` — CKContainer setup, record CRUD, subscription management
- `SyncEngine` — orchestrates sync: converts models ↔ CKRecord, handles push notifications, conflict resolution

### Config (extracted from Loom/Services/)
- `CategoryConfigLoader` — cross-platform load/save for categories.json

## Migration Path for Mac App

1. Extract shared models and config into LoomKit package
2. Update Mac app's Package.swift to depend on LoomKit
3. Add CloudKit sync to Mac's SessionEngine (dual-write alongside Calendar)
4. Mac app continues to work via `swift build` / `run.sh`

Existing Mac functionality is preserved — CloudKit is additive, Calendar remains primary on Mac.

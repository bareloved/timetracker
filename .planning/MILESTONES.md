# Milestones

## v1.0 Sessions List View (Shipped: 2026-03-28)

**Phases completed:** 2 phases, 3 plans, 6 tasks

**Key accomplishments:**

- Session.appsUsed migrated from [String] to [AppUsage] with per-poll elapsed-time duration accumulation, CloudKit JSON serialization with legacy fallback, and all 6 caller sites updated atomically
- SwiftUI Sessions tab with week navigation, card-style session rows (color strip, accordion expansion), live today merge, and per-app usage breakdown
- Right-click context menu and double-click on session cards open BackfillSheetView for editing; context menu Delete shows inline card confirmation; both mutations persist to CloudKit via SyncEngine

---

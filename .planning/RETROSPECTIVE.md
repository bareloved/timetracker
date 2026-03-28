# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Sessions List View

**Shipped:** 2026-03-28
**Phases:** 2 | **Plans:** 3

### What Was Built
- Per-app duration tracking via `AppUsage` model migration (replaced `[String]` with structured data)
- Sessions tab with week/day navigation, card-style rows, accordion expansion, and live today merge
- Edit and delete session cards with context menu, double-click edit, inline delete confirmation, CloudKit persistence

### What Worked
- Splitting Phase 1 into data model migration (plan 1) then UI (plan 2) avoided mid-UI refactors
- Reusing CalendarTabView's navigation pattern made the Sessions tab feel native immediately
- Dual CloudKit writes (JSON + legacy array) gave backward compatibility without migration complexity

### What Was Inefficient
- Nothing major for a 2-day, 2-phase milestone

### Patterns Established
- ScrollView+ForEach over native List for expandable rows on macOS (avoids DisclosureGroup bounce)
- UUID? accordion pattern for single-expansion behavior
- Elapsed-time accumulation for per-app duration (more accurate than poll counting)

### Key Lessons
1. Data model changes before UI work pays off — plan 01-01 (AppUsage migration) made plan 01-02 (Sessions tab) straightforward
2. Porting existing mutation logic verbatim (CalendarTabView's edit/delete) is faster and safer than reimplementing

### Cost Observations
- Model mix: primarily opus for planning, sonnet for execution
- Fast milestone — 2 days from planning to completion
- Notable: small scope (2 phases, 3 plans) kept context overhead minimal

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 2 | 3 | First milestone — established GSD workflow for Loom |

### Top Lessons (Verified Across Milestones)

1. Data model migrations before UI phases prevents mid-build refactors
2. Reusing existing patterns verbatim (navigation, edit/delete) is faster than reimplementing

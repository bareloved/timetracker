# Calendar Write Threshold

**Date:** 2026-03-18
**Status:** Final

## Problem

Every session creates a calendar event immediately, cluttering the calendar with short, insignificant sessions. Briefly switching to email or Slack for a few minutes shouldn't produce its own calendar event. But those short sessions are still valuable data — the user wants to see what they were actually doing, including procrastination moments.

## Design

### Two-Phase Approach

**Phase 1 — Tracking-span gate:** When tracking starts, `CalendarWriter` buffers all sessions instead of writing to EventKit. The buffer accumulates until total elapsed wall-clock time since tracking started crosses the configured threshold. If tracking stops before the threshold is met, nothing is written to the calendar.

**Phase 2 — Flush and live writing:** Once the threshold is crossed, all buffered sessions are processed and calendar writing goes live. From this point, new sessions are processed immediately as they complete (or begin, for the active session).

### Session Classification

When processing sessions (during flush or live), each session is classified:

- **Long session** (duration >= threshold): Gets its own calendar event.
- **Short session** (duration < threshold): Absorbed as an "interruption" into a neighboring long session's notes. Does not get its own calendar event.

### Absorption Rules

- Short sessions are absorbed into the **previous** long session.
- If no previous long session exists (short sessions at the start of a span), they are absorbed into the **next** long session.
- Multiple consecutive short sessions are all absorbed into the same nearest long neighbor.
- If all sessions in a span are short (tracking stops before any session reaches threshold duration), nothing is written.

### Calendar Event Format

**Title:** `Category — Intention` or just `Category` if no intention is set.

**Location:** Primary app name (first app used).

**Notes** (human-readable, no JSON):

```
Building auth flow

Apps: Xcode, Terminal, Safari

Interruptions:
  2:47 PM — Mail (3 min)
  3:15 PM — Slack (2 min)
```

The "Interruptions" section is omitted entirely if there were none. The intention line is omitted if none was set. If there are no interruptions and no intention, notes contain only the apps line:

```
Apps: Xcode, Terminal, Safari
```

Interruption lines use `primaryApp` (first app in the short session's `appsUsed`). If nil, fall back to the category name.

### Threshold Configuration

- **Values:** 5 / 10 / 15 / 20 / 30 minutes (snap slider, no free-form input)
- **Default:** 15 minutes
- **Storage:** `@AppStorage("calendarWriteThreshold")` as integer minutes
- No "off" option — minimum is 5 minutes

### Settings UI

A "Minimum session length" snap slider in the Calendar settings section. Displays the currently selected value. Snaps to discrete points: 5, 10, 15, 20, 30.

## Changes

### CalendarWriter

**New state:**

- `sessionBuffer: [Session]` — buffered sessions waiting to be processed (looked up by `session.id` via linear search; buffer is small)
- `trackingStartTime: Date?` — when the current tracking span began (set on first `createEvent` call)
- `isLive: Bool` — whether the threshold has been crossed and we're writing directly
- `pendingInterruptions: [(category: String, app: String?, start: Date, duration: TimeInterval)]` — short sessions waiting to be attached to the next long session's notes
- `activeInterruptions: [(category: String, app: String?, start: Date, duration: TimeInterval)]` — interruptions already attached to the current live event (persisted across note rebuilds)
- `lastFinalizedEventIdentifier: String?` — the identifier of the most recently finalized EKEvent, retained so `resetTracking` can attach trailing interruptions

**Modified methods:**

- `createEvent(for:)` — guards on `writeEnabled`. If not live: appends session to `sessionBuffer`, sets `trackingStartTime` if nil, starts the threshold-check timer (NOT the existing event-update timer). If live: checks session duration; if long, creates EKEvent immediately (attaching any `pendingInterruptions` to notes, moving them to `activeInterruptions`); if short, adds to `pendingInterruptions`.
- `updateCurrentEvent(session:)` — if not live: finds matching session in `sessionBuffer` by `session.id` and updates it. If not found (resume case: session was finalized then resumed), re-appends to buffer. If live and event exists: updates normally (rebuilds notes with `activeInterruptions`).
- `finalizeEvent(for:)` — if not live: finds matching session in `sessionBuffer` by `session.id`, stamps `endTime`. If live and `currentEventIdentifier` exists: finalizes the EKEvent, attaches any `pendingInterruptions` to the final notes, stores identifier in `lastFinalizedEventIdentifier`, then clears `activeInterruptions` and `currentEventIdentifier`. If live and `currentEventIdentifier` is nil (session was short/pending): check if session duration now >= threshold — if so, create+finalize as a one-shot EKEvent; if still short, it remains in `pendingInterruptions`.

**New methods:**

- `flushBuffer()` — called when threshold is crossed. Processes the buffer:
  1. Separate the last entry if it has no `endTime` (it's the active session).
  2. Classify completed sessions as long or short.
  3. Long sessions get EKEvents with absorbed short neighbors in their notes.
  4. Short sessions without a long neighbor are discarded.
  5. If there's an active session and it's long (current duration >= threshold): create its EKEvent, attach any preceding short sessions as interruptions, start the event-update timer.
  6. If the active session is short: add to `pendingInterruptions` — it will be attached to the next long session, or discarded if tracking stops.
  7. Set `isLive = true`.
- `resetTracking()` — called when tracking stops. If live and `pendingInterruptions` is non-empty and `lastFinalizedEventIdentifier` exists: load that event, rebuild its notes with the additional interruptions, save. Then clear all state: `sessionBuffer`, `trackingStartTime`, `isLive`, `pendingInterruptions`, `activeInterruptions`, `lastFinalizedEventIdentifier`.
- `createEventImmediately(for:)` — guards on `writeEnabled`. Writes a completed event to EventKit in one shot (sets start, end, saves) without threshold or buffering. Does not set `currentEventIdentifier`. Used by idle event creation and manual backfill.

**Timer behavior:**

Two distinct timer uses:
1. **Threshold-check timer** (during buffering): Ticks every 30s. Checks if elapsed time since `trackingStartTime` >= threshold. If so, calls `flushBuffer()` and transitions to the event-update timer.
2. **Event-update timer** (after going live, when an event exists): Ticks every 30s. Updates the active EKEvent's `endDate` to `Date()`. This is the existing timer behavior.

```
func timerFired():
  if not isLive:
    let elapsed = Date().timeIntervalSince(trackingStartTime)
    if elapsed >= threshold * 60:
      flushBuffer()
  else if currentEventIdentifier != nil:
    event.endDate = Date()
    save event
```

**Notes builder (replaces existing JSON-based `buildNotes`):**

```
func buildNotes(session:, interruptions:) -> String:
  var lines: [String] = []
  if let intention = session.intention, !intention.isEmpty:
    lines.append(intention)
    lines.append("")
  lines.append("Apps: " + session.appsUsed.joined(", "))
  if interruptions is not empty:
    lines.append("")
    lines.append("Interruptions:")
    for each interruption:
      let app = interruption.app ?? interruption.category
      let mins = Int(ceil(interruption.duration / 60))
      lines.append("  {time} — {app} ({mins} min)")
  return lines.joined("\n")
```

**Title builder:** `buildTitle` remains unchanged — `"Category — Intention"` or just `"Category"`.

**Time rounding:** Start/end times of EKEvents continue to use `roundDown`/`roundUp`. Interruption times in notes are displayed as-is (not rounded) since they're informational, not event boundaries.

**`weeklyStats()` note:** This method aggregates by `event.title`. Since titles now include intention (`"Coding — auth flow"`), different intentions within the same category will be counted separately. This is acceptable for now — a future improvement could parse the title to extract just the category.

### SessionEngine

**Minimal change:** When `stopSession()` is called, call `calendarWriter?.resetTracking()` after `finalizeCurrentSession()`.

No other changes. SessionEngine continues calling `createEvent`, `updateCurrentEvent`, and `finalizeEvent` as before. The buffering logic is entirely within `CalendarWriter`.

### AppState

- `createIdleEvent` uses `createEventImmediately` instead of `createEvent` + `finalizeEvent`. Guards on `writeEnabled`.

### SettingsView

Add snap slider for "Minimum session length" in calendar settings. Values: 5, 10, 15, 20, 30.

## Data Flow

```
Tracking starts
  → Sessions flow through SessionEngine as before
  → CalendarWriter buffers each session

  [While elapsed < threshold]
    → createEvent → append to buffer (by session.id)
    → updateCurrentEvent → find in buffer by session.id, update
    → finalizeEvent → find in buffer by session.id, stamp endTime
    → Timer ticks → check elapsed, not yet

  [Elapsed crosses threshold — flushBuffer()]
    → Separate active session (no endTime) from completed ones
    → Classify completed sessions as long or short
    → Long sessions → create+finalize EKEvent, attach absorbed short neighbors
    → Short sessions → become interruptions on nearest long neighbor
    → Active session if long → create EKEvent, start event-update timer
    → Active session if short → add to pendingInterruptions
    → isLive = true

  [After threshold crossed — live mode]
    → Short completed sessions → pendingInterruptions
    → Long session created → create EKEvent, attach pendingInterruptions
    → Long session updated → rebuild notes with activeInterruptions
    → Long session finalized → final notes with activeInterruptions, clear state

Tracking stops
  → If not live: buffer discarded, nothing written
  → If live: active session finalized, pending interruptions attached to last event
  → resetTracking() clears all state
```

## Edge Cases

- **Tracking stops before threshold:** Buffer discarded. Nothing written to calendar.
- **All sessions short after flush:** No long neighbor to absorb into. If there's a previously written long event, `pendingInterruptions` attach to it on `resetTracking`. If no long event was ever written, interruptions are discarded.
- **Short sessions at start of span:** During flush, if the first N sessions are short and a long session follows, the long session absorbs them.
- **Short session between two long sessions:** Absorbed into the previous long session.
- **App crash during buffering:** Buffer is in-memory only. Sessions are lost. Acceptable — same risk as before, and the threshold means it was early in the span.
- **Sleep/wake during buffering:** Idle handling finalizes the current session (buffered). On wake, new sessions continue buffering. Elapsed time keeps counting from original `trackingStartTime`.
- **Threshold changed mid-session:** Read live from `@AppStorage`. Next timer tick uses the new value.
- **Direct callers (idle events, backfill):** Use `createEventImmediately` — always write, no buffering. Respects `writeEnabled`.
- **Session resume:** SessionEngine resumes a finalized session by calling `updateCurrentEvent`. In buffer mode, `updateCurrentEvent` finds the session by `id` in the buffer and updates it (or re-appends if it was finalized). In live mode, updates the active EKEvent normally.
- **Active session at flush time is short:** Added to `pendingInterruptions`. When the next long session starts (live), it absorbs them. If tracking stops with no subsequent long session, they attach to the last written event or are discarded.
- **`writeEnabled` is false:** `createEvent` and `createEventImmediately` guard on `writeEnabled` and return early. No buffer state accumulates, so downstream `updateCurrentEvent`/`finalizeEvent` calls are naturally no-ops.
- **Short active session grows past threshold in live mode:** While active and short, `updateCurrentEvent` calls are no-ops (no event exists). If the session is eventually finalized and its duration >= threshold, `finalizeEvent` creates+finalizes it as a one-shot EKEvent. If it's finalized while still short, it stays in `pendingInterruptions`.

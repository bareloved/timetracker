# Phase 1: List & Navigation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 1-list-navigation
**Areas discussed:** Row layout, App detail view, Empty & edge states

---

## Row Layout

### Question: How should each session row be structured?

| Option | Description | Selected |
|--------|-------------|----------|
| Compact | Single line: color dot + category + intention + time + duration | |
| Two-line | Top: category + intention. Bottom: time + duration. Color strip on left | |
| Card style | Rounded card with category color background tint, info laid out inside | ✓ |

**User's choice:** Card style
**Notes:** User selected the preview showing category name, duration, intention, and time range in a card layout.

### Question: How should the category color appear on the card?

| Option | Description | Selected |
|--------|-------------|----------|
| Left strip | Thin vertical color bar on the left edge (like Google Calendar) | ✓ |
| Background tint | Subtle category color as card background fill | |
| Both | Color strip + light tint | |
| You decide | Claude picks based on design system | |

**User's choice:** Left strip
**Notes:** None

---

## App Detail View

### Question: How should the expanded detail handle appsUsed (names only, no durations)?

| Option | Description | Selected |
|--------|-------------|----------|
| Names only (v1) | Show list of app names, no duration per app | |
| Add duration data | Extend Session model to track per-app duration | ✓ |
| You decide | Claude picks pragmatic approach | |

**User's choice:** Add duration data
**Notes:** This requires extending the Session model and SessionEngine to accumulate per-app durations. Significant but desired.

### Question: How should the expanded app list appear below the card?

| Option | Description | Selected |
|--------|-------------|----------|
| Simple list | Plain text list with durations, indented below card | |
| Mini bars | Small horizontal bars proportional to duration | |
| You decide | Claude picks based on design system | ✓ |

**User's choice:** You decide
**Notes:** Claude has discretion on the visual treatment.

---

## Empty & Edge States

### Question: What should show when a day has no sessions?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal text | Simple centered "No sessions" | ✓ |
| Helpful text | "No sessions recorded" with hint about tracking | |
| You decide | Claude picks appropriate for design system | |

**User's choice:** Minimal text

### Question: What if a session has no intention set?

| Option | Description | Selected |
|--------|-------------|----------|
| Hide it | Don't show intention line, card is more compact | |
| Placeholder | Show muted "No intention" placeholder | ✓ |
| You decide | Claude picks based on what looks clean | |

**User's choice:** Placeholder

---

## Claude's Discretion

- Expanded app detail visual treatment (simple list vs mini bars)
- Tab icon for Sessions tab
- Tab placement in tab bar order

## Deferred Ideas

None

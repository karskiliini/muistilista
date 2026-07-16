# Ostoslista — simple iOS shopping list app

**Date:** 2026-07-16
**Status:** Approved by user (native SwiftUI, local only, one flat list)

## Purpose

A native iOS shopping list app for personal use: add items, check them off in
the store, clear the checked ones. No accounts, no sync, no sharing.

Background: the user has no existing shopping list app locally or on GitHub.
The closest relative is `karskiliini/muistilista` (an iOS-styled web packing
list), which informs the visual tone but shares no code.

## Decisions

| Decision | Choice | Rejected alternatives |
|---|---|---|
| App type | Native SwiftUI app | Web app / PWA; adapting muistilista |
| Persistence | SwiftData (iOS 17+) | JSON file store (iOS 15 reach), Core Data (overkill) |
| List shape | One flat list | Categories; multiple named lists |
| Sync | None — device-local only | iCloud/CloudKit, family sharing |
| Project generation | XcodeGen from `project.yml` | Hand-written pbxproj; Xcode GUI |
| UI language | Finnish | English |

## Architecture

Single-target SwiftUI app plus a unit-test target.

- `ShoppingItem` — SwiftData `@Model`: `name: String`, `isDone: Bool`,
  `createdAt: Date`. The ModelContainer persists automatically.
- `OstoslistaApp` — app entry point; owns the `ModelContainer`.
- `ShoppingListView` — the single screen:
  - Text field pinned at top ("Lisää tuote…"); return key adds the item.
    Empty/whitespace-only input is ignored; input is trimmed.
  - List below: unchecked items first (oldest first), then checked items
    greyed out with strikethrough. Tap a row to toggle checked.
  - Swipe-to-delete on any row.
  - Toolbar button "Tyhjennä ostetut" deletes all checked items; disabled
    when nothing is checked.
  - Header shows progress count, e.g. "3 / 8".
- Query/sort/mutation logic lives in small testable pure helpers
  (`ShoppingListLogic`), not inline in the view, so the unit tests don't
  need a UI host.

## Error handling

- Invalid input (empty after trimming) is silently ignored — no error UI.
- SwiftData saves are automatic; no user-facing failure states.

## Testing

- XCTest unit target covering: input trimming/rejection, sort order
  (unchecked-before-checked, then createdAt), toggle, clear-checked.
- Verification: `xcodebuild test` on an iPhone simulator, with
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (the machine's
  `xcode-select` points at CommandLineTools; changing it needs sudo, so the
  env var override is used instead).

## Tooling notes

- XcodeGen binary: `/opt/homebrew/Cellar/xcodegen/2.45.4/bin/xcodegen`
  (brew's link step fails due to a bottle version mismatch; the binary works).
- `project.yml` is committed; the generated `.xcodeproj` is regenerable.
- Deployment target: iOS 17.0.

## Feature: drag-to-set quantity (added 2026-07-16, user-approved)

Dragging a row rightward scrubs a quantity: a blue "× N" capsule appears
and N grows one step per 36 pt of horizontal drag, starting from the
item's current quantity. Dragging back left within the same gesture
lowers it; minimum 1. Lifting the finger commits. When quantity > 1 the
row permanently shows a secondary "× N" at its trailing edge; quantity 1
shows nothing. Model gains `quantity: Int = 1` (SwiftData lightweight
migration). Mapping lives in `ShoppingListLogic.quantity(start:dragWidth:)`
(unit-tested). Drags that begin leftward or mostly vertical are ignored so
swipe-to-delete and scrolling keep working.

## Out of scope (YAGNI)

Categories, multiple lists, quantities, sync, sharing, widgets, App Store
distribution. Installing on the physical iPhone is done manually via Xcode
with a personal signing team (free Apple ID: re-sign every 7 days).

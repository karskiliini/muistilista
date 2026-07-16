# Family Sharing Phase 1: Core Data Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SwiftData with Core Data (programmatic model, App Group store) with zero user-visible behavior change, as the foundation for CloudKit sharing (phases 2–3 planned separately once this ships).

**Architecture:** Programmatic `NSManagedObjectModel` (no .xcdatamodeld). `CoreDataStack` factory shared by app + widget. `ShoppingListLogic` becomes protocol-based so tests use plain fixtures. Views move from `@Query` to `@FetchRequest`; row observes the managed object.

**Tech Stack:** Core Data, SwiftUI, XcodeGen. SwiftData is removed entirely.

## Global Constraints

- All entity attributes get default values and CloudKit-safe types (Int64 for integers) — required by `NSPersistentCloudKitContainer` in Phase 2.
- Store file: App Group `group.fi.maaranen.ostoslista`, filename `OstoslistaCD.sqlite`. Old SwiftData data is not migrated (accepted one-time reset).
- Widget performs no CloudKit work in any phase; it reads the local store.
- Same simulator/device build+test commands as the base plan; every task ends green (`** TEST SUCCEEDED **`) before commit.

### Task 1: CoreDataStack + CDShoppingItem + protocol-based logic (TDD)

**Files:**
- Create: `Ostoslista/CoreDataStack.swift` (model + container factory, in-memory option for tests)
- Create: `Ostoslista/CDShoppingItem.swift` (NSManagedObject subclass + `ShoppingItemLike`)
- Modify: `Ostoslista/ShoppingListLogic.swift` (generic over `ShoppingItemLike` protocol: `isDone` + `createdAt`; `normalized`/`quantity` unchanged)
- Modify: `OstoslistaTests/ShoppingListLogicTests.swift` (fixture struct replaces SwiftData items; add CRUD test against in-memory stack)
- Delete: `Ostoslista/ShoppingItem.swift`, `Ostoslista/SharedStore.swift`

**Steps:** red (fixture-based tests fail to compile against protocol API) → implement → green → commit.

### Task 2: Port app, views, and widget to Core Data

**Files:**
- Modify: `Ostoslista/OstoslistaApp.swift` (inject `viewContext`, keep WidgetCenter reload)
- Modify: `Ostoslista/ShoppingListView.swift` (`@FetchRequest`, mutations save context)
- Modify: `Ostoslista/ShoppingRowView.swift` (`@ObservedObject var item: CDShoppingItem`)
- Modify: `OstoslistaWidget/OstoslistaWidget.swift` (count via `NSFetchRequest`)
- Modify: `project.yml` (widget sources: swap ShoppingItem/SharedStore for CDShoppingItem/CoreDataStack)

**Steps:** implement → full suite green in simulator → screenshot check → commit → device build + install.

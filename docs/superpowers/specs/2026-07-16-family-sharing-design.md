# Ostoslista family sharing (CKShare) + widget data layer

**Date:** 2026-07-16
**Status:** Approved by user (native iCloud sharing chosen over custom backend)

## Purpose

The single shopping list must be editable from several family iPhones,
each with its own Apple ID. Research confirmed SwiftData still has no
CKShare support (Apple developer forums, iOS 26 era), so the persistence
layer migrates to Core Data + `NSPersistentCloudKitContainer`, the only
Apple-supported route for cross-Apple-ID sharing without a server.

## Phases

Each phase ships a working app.

1. **Core Data migration (no behavior change).** Replace SwiftData with a
   programmatic `NSManagedObjectModel` (no .xcdatamodeld; stays reviewable
   and XcodeGen-friendly). Entity `CDShoppingItem`: `name: String` (default
   ""), `isDone: Bool` (default false), `createdAt: Date` (default now),
   `quantity: Int64` (default 1) — all with defaults for CloudKit
   compatibility later. Store lives in the App Group
   (`OstoslistaCD.sqlite`); widget reads the same store.
   `ShoppingListLogic` becomes protocol-based (`ShoppingItemLike`) so unit
   tests keep running against plain fixtures. The existing test list is
   NOT migrated — the list resets once (accepted: days-old test data).
2. **CloudKit private sync.** Swap in `NSPersistentCloudKitContainer`,
   container id `iCloud.fi.maaranen.ostoslista`, history tracking + remote
   change notifications, entitlements for iCloud/CloudKit + push.
   User's own devices sync; no sharing yet.
3. **Sharing.** Introduce `CDShoppingList` root entity (to-many to items);
   the single list is created on first launch. Toolbar share button
   creates/manages the CKShare via `ShareLink` +
   `CKShareTransferRepresentation`; invite goes out through Messages.
   Second store description with `.shared` database scope so accepted
   shares appear; `CKSharingSupported` in Info.plist and
   `acceptShareInvitations` wiring via scene delegate. Family members see
   and edit the same list.
4. **TestFlight.** App Store Connect record, archive + upload, invite the
   family as internal testers. No cables.

## Risks / constraints

- CKShare integration is notoriously fiddly; final invite/accept testing
  needs a real second device with a different Apple ID (family member).
- CloudKit requires the phone to be signed into iCloud with iCloud Drive on.
- Widget keeps reading the local store only — no CloudKit calls from the
  extension (keeps it simple and battery-friendly); it updates when the
  app next syncs and backgrounds.

## Out of scope

Multiple lists, per-member permissions beyond CloudKit defaults, Android,
conflict UI (CloudKit last-writer-wins is fine for a shopping list).

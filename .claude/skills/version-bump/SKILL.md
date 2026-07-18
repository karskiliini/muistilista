---
name: version-bump
description: Bump the app's semantic version whenever a feature, bugfix, or breaking change is COMPLETED in this project. Use ALWAYS as part of the final commit of any completed feature or fix — before committing, not after. Also use when the user asks what version the app is at or to bump the version.
---

# version-bump — semantic versioning for Ostoslista

The app shows its version bottom-right on the main screen (R21), read from
`CFBundleShortVersionString`, which comes from `MARKETING_VERSION` in
`project.yml`. That one field is the single source of truth.

## When a feature/bugfix completes

1. Read the current `MARKETING_VERSION` from `project.yml` (app target).
2. Pick the bump by what changed for the user:
   - **Major** (X.0.0) — behavior breaks or data is reset/incompatible
     (e.g. a migration that empties the list).
   - **Minor** (x.Y.0) — new user-visible capability; typically a new
     R-row in `docs/requirements.md`.
   - **Patch** (x.y.Z) — fix or polish of existing behavior; the register
     text stays the same or only gets clarified.
3. Edit `MARKETING_VERSION` in `project.yml`, run xcodegen from the
   Cellar path (`ls /opt/homebrew/Cellar/xcodegen/` for the current
   version, e.g. `/opt/homebrew/Cellar/xcodegen/2.46.0/bin/xcodegen generate`).
4. Include the version change in the SAME commit as the completed work,
   and mention the new version in the commit message (e.g. `(v1.6.0)`).

One bump per completed unit of work — if a turn ships a feature plus a
fix, bump minor once; don't stack bumps.

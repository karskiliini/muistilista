---
name: requirements
description: Keep docs/requirements.md in sync with every request made in this project. Use this skill on EVERY user prompt that asks for, changes, removes, or refines any behavior of the Ostoslista app — new features, UX tweaks, bug-fix requests that reveal an unstated expectation, platform targets, sync behavior, anything the app must do. Also use it when the user asks what the requirements are or whether something is covered. Trigger even if the user doesn't mention the word "requirement".
---

# Requirements register

`docs/requirements.md` is the single source of truth for what the Ostoslista
app must do. The register's contract: **implementing every requirement in it,
and nothing else, reproduces the application we have** (plus its planned
parts). That only stays true if every behavioral prompt lands in the register
— which is why this skill runs on every such prompt.

## Process on each prompt

1. Read `docs/requirements.md`.
2. Compare the prompt's intent against existing requirements:
   - **Covered** — mention the matching R-id in your reply; no edit needed.
   - **New behavior** — add a requirement with the next free R-number.
   - **Changed behavior** — rewrite the existing requirement to describe the
     *current* desired behavior. The register is not a changelog; git history
     remembers the old version. (The quantity-drag interaction was reshaped
     three times in one day — the requirement describes only the final form.)
   - **Removed behavior** — delete the requirement.
3. Set the status: ✅ toteutettu, 🔄 työn alla, or 📋 suunniteltu. Update the
   status when a feature ships — a register full of stale 🔄 rows stops being
   trusted.
4. Commit the register change together with the code change it belongs to.

## Writing style for requirements

- **Concise and testable.** One or two sentences. Someone should be able to
  read the requirement and check the app against it.
- **Behavior, not implementation.** "The list syncs across the owner's
  devices via their iCloud account" — not "use NSPersistentCloudKitContainer".
  Implementation details live in specs (`docs/superpowers/specs/`); the
  register says *what*, specs say *how*. Exception: name a technology when it
  IS the requirement (e.g. "distributed via TestFlight").
- **Concrete numbers when the user gave them** (36 pt per step, minimum 1).
  Vague requirements can't be verified.
- Finnish UI copy is quoted exactly ("Tyhjennä ostetut") so wording is a
  checkable requirement too.

## Completeness check

When touching the register, glance over it: does anything the app visibly
does lack a requirement? If yes, add it — gaps break the register's contract.

# Totem Coverage — Maintenance Status

**Stable baseline:** v0.1.1-beta.16, preserved on this branch. This branch is maintenance-only: critical bug fixes and compatibility/security updates, not speculative coverage-count changes. Existing `beta` and `main` branches are not modified by this status marker.

## Current limits

- Physical totem names, nameplate overlays, saved settings and dead GUID exclusions work in field logs.
- WoW Forever restricts hostile aura identity in combat and often even outside combat.
- Enemy-to-totem distance is not available through a verified safe API; nameplate visibility is **not** Earthbind range.
- Enemy observation counts are **not** counts of affected or within-range targets.
- `/tc unknown on` optionally shows visible, living hostile names with `?`; keep these clearly labeled unverified.
- No verified way to attribute a combat-fallback nameplate to this player when multiple shamans have similarly named totems.

## Experiment

Native aura widget feasibility testing is isolated in `research/native-aura` and is disabled by default. No experimental work should be merged into release branches until actual client field testing shows it works without UI taint.

**Decision:** preserve the useful physical overlays; cease advertising exact buff/debuff coverage counts.

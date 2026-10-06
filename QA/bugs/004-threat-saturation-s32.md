# Bug Report Template

Copy this file into `QA/bugs/NNN-short-slug.md` (next free number) and fill in
every field. Bug reports stay in plain professional English — the pirate speak
rule applies to CHANGELOG.md only.

## Title
[skeptic] threat_saturation on sortie 32 (HIGH)

## Version found in
22

## Severity
major

## Environment
Godot headless bot run (archetype: expert)

## Steps to reproduce
1. Run the nightly bot matrix (`--botpilot --botarchetype=expert --sortie=31`).
2. Observe the `threat_saturation` anomaly at t=18.0s in QA/reports/skepticism-2026-10-06-s31.jsonl.
3. See the skepticism report for full evidence.

## Expected
No threat_saturation anomaly — the sortie should play fair under the one-hit model.

## Actual
27 live air attackers sustained 6s — the screen is unreadable

## Suspected cause
sortie wave tables — too many simultaneous attackers

## Fix applied
(unfixed)

## Verify-fix steps (run after the nightly build)
1.
2.
3.

## Nightly build verified on
2026-10-06 / v22

## Status
open

<!-- skeptic-sig: threat_saturation|31|# live air attackers sustained #s — the screen is unreadabl -->
<!-- auto-filed by the skeptic bot; human triage required -->

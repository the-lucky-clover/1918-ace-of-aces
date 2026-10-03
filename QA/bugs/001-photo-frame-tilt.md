# Bug 001 — Flight-desk photo frames snap ~1–6° on first load

## Title
Four framed photos on the flight desk visibly rotate a few degrees ~1s after
the intro finishes playing.

## Version found in
v0 (pre-versioning baseline; fixed in v1)

## Severity
cosmetic

## Environment
Web build `1918-ace-of-aces.html` — any modern browser, desktop or mobile.

## Steps to reproduce
1. Launch 1918 and land on the splash screen.
2. Tap "Open flight desk".
3. Watch the four framed archival photos on the flight desk as the intro
   fly-in animation completes (~0.95s after the desk appears).

## Expected
The photos glide in and settle at their tilted rest angles (-2.2°, 3.5°,
4.5°, -4°) with no visible jump.

## Actual
The photos sit perfectly straight during the intro, then visibly snap to
their tilted rest angles (~1–6° each, in different directions) the moment the
`intro-play` class is removed.

## Suspected cause
The `@keyframes artifactFlyIn` `to` state forced `transform:none`, overriding
each photo's tilted rest transform for the whole intro. When the animation
(and `intro-play` class) was removed at 950ms, the photos jumped back to
their natural tilted transforms.

## Fix applied
- `1918-ace-of-aces.html`: changed the keyframe end state from
  `to{opacity:1;transform:none}` to `to{opacity:1}` so the animation ends at
  each element's natural transform.
- Bumped the `intro-play` removal timeout from 950ms to 1100ms so no element
  is caught mid-animation.

## Verify-fix steps (run after the nightly build)
1. Launch 1918, tap "Open flight desk".
2. Watch the four framed photos through the full intro.
3. Confirm each photo flies in already tilted and settles with no snap.
4. Confirm `QA/run-nightly.sh` passes `web-photo-keyframes` and
   `web-intro-timeout` (static regression guards for this bug).

## Nightly build verified on
2026-10-03 / v2 — web-photo-keyframes PASS, web-intro-timeout PASS (static);
live in-browser visual re-verification still owed.

## Status
fixed-unverified

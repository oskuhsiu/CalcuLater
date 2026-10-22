# Maximum-text Settings reveal: bounded travel correction

## Decision and boundary

The failure in run [39693320883](https://github.com/oskuhsiu/CalcuLater/actions/runs/39693320883),
attempt 1, is **XCTest helper travel exhaustion**, not boot/install failure or a
900-second timeout. The `maximumAccessibilityText` lane finished in 668.77 seconds
with exit 65, seven passing tests and one failed test. The exact failing selector
is `Calcu_LaterLayoutUITests/testSettingsSelectionPersistsAndLastOperationStaysAvailable`;
the original final assertion at helper line 88 correctly rejected an unhittable
`settings.operation.0` switch.

Evidence source: `9fc16d69b182c952f2462be6debeec59476b9b22`. This correction starts
from integrated candidate `f72f05c6b6fcab18ef56cf8e432816e8bc3b118c`. The Settings
production implementation, Settings test body and original reveal helper are
byte-for-byte identical between those two SHAs. Other integrated teaching work
is preserved. No production code, font, layout, preference, test selector,
workflow, timeout, simulator setting or assertion is changed by this correction.

## Frozen evidence and environment

- Artifact `12390892580`, `maximum-text-evidence.zip`, 257623099 bytes,
  SHA-256 `fa16c495257b68008c3c192870ada534f00c8fa766d7e341d4b2ead2593c5d84`.
  Original files and `Tests.zip` are retained unmodified outside the source tree.
- `environment.json`: arm64, macOS 15.7.9 (24G830), runner image `macos15`
  version `20260907.0337.1`, Xcode 16.4 (16F6), SDK 18.5, iOS 18.5 (22F77),
  iPhone 16. Owned simulator `E2E816D8-16B5-4F0D-B7E1-7E22DF7B3A71`.
- `scenario-configuration.json` verifies the actual system content size as
  `accessibility-extra-extra-extra-large`, changed from `large`.
- `test.json`, `test.log` and `test-summary.log` establish the command, duration,
  exact assertion, ten gestures and terminal test counts. `attachments/manifest.json`
  associates the screenshots, named hierarchies and per-test video with this test.

## Direct observations

1. The writing selection screenshot `AAEE54D7-E3DC-44AA-90E0-925E8501B35F.png`
   and hierarchy `03B44CC4-ED23-4DC8-B3F0-FCFCA7D8A897.txt` show a selected
   writing row. The test then genuinely relaunches and verifies the saved value.
   Current application PIDs change from 18174 to 18335. The reused table query
   continues to drive the current application's visible table; there is no
   evidence of a stale cross-relaunch container causing this failure.
2. Immediately after tier selection, screenshot
   `A82110A1-D697-458A-BB56-9AB322F840E0.png` shows D1/D2, not the operation
   switch. Named hierarchy `4A51448A-9EC7-4ECA-AB12-ABA267286F65.txt` records the
   table at `(0,69,393,783)` and the addition row at `(20,2829.7,353,219)`.
   The child switch reports stale `(0,-1166.3,51,31)` geometry. The existing
   containing-row fallback is therefore necessary and must not be removed.
3. `test.log` times 56.08 through 96.82 record exactly ten upward drags of
   234.9 points, with no direction reversal. That is `10 × 783 × 0.3 = 2349`
   points of requested touch travel, not guaranteed content displacement.
4. Failure screenshot `1E02DB01-D06B-41B2-8EB1-329F7A8A5A58.png` still shows the
   difficulty footer and the start of addition. Named failure hierarchy
   `658F73E6-3BB2-4FFA-B1D5-BF9EA821D357.txt` records addition row y705/h219,
   but its switch y857.3/h31 is below the 852-point screen. The row advanced
   2124.7 points, less than the requested touch travel. Row-height changes are
   also visible in the two named trees, so this difference is not attributed to
   gesture slop alone. A visible portion of the row is not a hittable switch.
5. Original per-test recording `A8557699-A752-46AA-BD77-1DF710AAC1D7.mp4`
   (1178×2556, duration 103.35 seconds) has SHA-256
   `c0ec7762c40bf65908e66ee64bda2e8e3f0df93d03db8d539095ccd8c70ebc3e`.
   Chronological decoded frame/PTS pairs reviewed after selection and each drag:
   `2905/54.003333`, `3167/58.006667`, `3381/61.301667`, `3618/65.193333`,
   `3867/69.203333`, `4161/73.905`, `4352/77.003333`, `4571/80.395`,
   `5007/87.595`, `5401/94.005`, `5775/99.991667`.
   They show steady forward traversal through D1, D2, D3, D4 and the footer,
   ending above the addition switch. There is no observed oscillation or dead
   gesture. These are real decoded frames, not assumed constant-frame-rate offsets.
6. Automatic `UI Snapshot` binary attachments repeat pre-gesture geometry across
   multiple events. They cannot establish actual per-gesture row movement. The
   named hierarchies, actual pixels and gesture log are the evidence used here.

These observations support an inadequate small-drag travel budget at the actual
AX5 row sizes. They do not establish a new production Settings layout defect or
justify shrinking accessibility text. The new gesture's native effectiveness
remains unproven until the exact patched source runs.

## Narrow correction

Only `reveal:in:down:` changes in the UI-test source:

- Retain ten attempts, finite/nonempty viewport checks, the containing-row
  fallback, current-frame direction recomputation and final strict hittability.
- A finite table-cell target wholly more than 30% of a viewport above or below
  the visible viewport gets a 50% travel cap. At the recorded height, this is
  391.5 rather than 234.9 points. The far-row theoretical ten-gesture ceiling
  is 3915 points rather than 2349, but near-target gestures still use 30%.
- Keep 30% for nearby/intersecting rows, missing/invalid geometry, non-row
  accessories without a containing row, and every non-table flow. Keep the
  24-point minimum, original 65%/35% touch starts, 0.05-second press and drag API.
  Both endpoints remain inside the viewport; a detected overshoot reverses the
  next gesture rather than persisting with the original direction hint.
- Retain `settings-reveal-scroll` string attachments after table gestures with
  attempt, identifier, viewport, row before/after, request, actual planned travel,
  cap, touch endpoints and observed target hittability. They record observations,
  not an inferred pass. No coordinate tap or `exists`-only success is added.

## Portable validation and remaining gate

Passed: 57 CI-script tests (including nine new source/arithmetic contracts),
16 evidence tests, whitespace checks, and a byte comparison proving every
existing layout test body and non-reveal helper is unchanged from the base.
The 630 generated geometry combinations include short/large viewports and both
directions. The recorded far-row and final-near-row cases select the intended
caps; non-table and invalid-geometry cases keep the old behavior.

An explicitly illustrative arithmetic model subtracts the observed mean
requested-versus-row displacement from each gesture. The old policy reproduces
the final row at y705 after ten drags; the adaptive policy uses five far and two
near drags to put the model switch inside the screen. This is **not UIKit,
Simulator reproduction or native acceptance**, and cannot guarantee real timing,
content displacement, row remeasurement or hittability.

The unchanged production C action kernel also passed its portable exhaustive
suite normally and with address/undefined-behavior sanitizers. LeakSanitizer
cannot run under this executor's tracing environment, so the successful sanitizer
run explicitly disabled leak detection. No Objective-C/XCTest compilation or
Apple Simulator execution occurred on this Linux host.

Before a later authorized native run, review this decision and retain the same
environment contract. Require the original Settings test to pass on the exact
integrated SHA at compact phone, tablet and verified AX5. Inspect the new traces
for far-to-near transition, current row movement and bounded convergence; require
real switch taps, opposite-state persistence across relaunch, all four operation
values, the final-operation guard and Done returning home. Preserve full matrix
acceptance for the other integrated teaching changes. If the same boundary fails
again, inspect retained evidence instead of increasing attempts/timeouts or
blindly repeating a full run. This record authorizes no dispatch or publication.

# Native viewport and fixture acceptance

This is a bounded correction plan, not a passing-run report.

## Observed source and failure boundaries

Source: `c948de49ad800c1711a40b8008e416716f76f309`.
Run: https://github.com/oskuhsiu/CalcuLater/actions/runs/39657409557

- Compact job `119421235753` passed inventory, build, boot and configuration.
  Three of seven selected UI flows passed. Four failed board-intersection or
  alignment checks after the inspection helper overshot its target. The native
  recording and original screenshots show the make-ten first Next was already
  fully framed before that helper moved it out of view. Packing and sharing
  inspection likewise oscillated after default-velocity, zero-endpoint-hold drags.
- A separate product defect exists before any helper action: compact `18 − 9`
  initially places part of the original eight ones below the content viewport,
  even though the full 292-point stage fits the 363-point viewport.
- Standard job `119421236082` also passed inventory, build, boot and configuration.
  All 225 component methods ran. Its first error is the test-only `GBTTestBoard`
  returning a partial `traitCollection`. UIKit raises an exception; this invalid
  trait environment contaminates later component cases, producing 99 unexpected
  failures. This is not evidence of 99 independent production defects. Of 15 UI
  flows in the separate UI runner, 13 passed and two failed the grouping-board
  intersection assertion. UI duration was 575.981 seconds, not a timeout.
- Tablet job `119421236353` passed all seven selected UI methods, with no skipped
  required methods. UI duration was 479.732 seconds. Endpoint screenshots show
  four sharing recipients with five objects each versus five packing groups of
  four, a single common remainder of three, and distinct answer units. Motion
  quality still requires decoded-frame inspection; pass counts alone do not prove it.

The original run is now terminal (failure overall). Maximum-accessibility-text
job `119421236296` passed all seven selected UI methods with no skipped required
methods, as verified in `test-execution.json`. Its scenario file confirms the
actual Simulator content size was `accessibility-extra-extra-extra-large`.
All four scenarios passed environment, build, boot and scenario configuration;
the only failing pipeline boundary was XCTest/UI acceptance in compact and standard.
The original standard archive was reconstructed by the isolated read-only recovery
run `39662535411` and verified against the original SHA-256. No Simulator rerun
was used for archive recovery.

## Three isolated corrections

1. Test fixture only: replace the unsupported `traitCollection` override with
   UIKit `traitOverrides`, retain a host window for the geometry matrix, and
   release its board clocks, override and window after each test. All original
   geometry/count assertions and motion probes remain.
2. Product only: once per visible, nonempty ten-frame presentation, frame the
   initial quantities using the same geometry already used by Next. Do not change
   the arithmetic, counters, step progression, animator or L1–L3 behavior. Later
   play, Back, Replay, foregrounding and resizing retain the child's inspection
   offset. An impossible initial fit must not cause a later surprise scroll.
3. UI inspection only: do not move a completely contained board; correct only
   the clipped edge when it fits; retain tall-board slice inspection. Use a slow
   drag with endpoint hold and record requested, bounded and measured movement.
   Preserve the existing intersection, horizontal-bound and slice assertions.

The untouched initial break-ten capture now precedes the same whole-stage fit
assertion used for first Next. Neither a reveal gesture nor Replay may repair the
viewport before that assertion. Five additional component methods check initial
framing, hidden preparation, lifecycle/inspection preservation, infeasible
geometry and unaffected simple lessons.

## Discriminating native observations

- The first grouping geometry test receives complete inherited traits, its
  Dynamic Type override reaches descendants, and later UIKit suites execute
  without the previous invalid trait environment.
- Compact initial `18 − 9` shows both full ten-frames and all eight original ones
  before inspection. The equation is still unanswered and the step remains zero.
- A fully contained make-ten first-play stage generates no inspection drag.
  Required grouping drags settle near their measured targets rather than
  alternating across them. Existing bounds assertions still pass.
- First-play, Back and Replay retain exact quantities and selected-step state;
  interrupted or resized motion never reveals a later answer.
- All selected methods actually execute. Source inventory for this correction
  is 245 standard methods (230 component, 15 UI), and seven per layout variant.

The existing Xcode 16.4 / iOS 18.5 configuration, public standard runner type,
maximum concurrency of two, 900-second test-command bound and 35-minute job bound
stay unchanged. Animations remain enabled in native UI acceptance. No simulator
reset, arbitrary post-action sleep, new dependency or blind retry is part of this
plan. Preserve the next run's original evidence even if it fails again.

## Evidence recovery limit

The standard source artifact is `12374080329`, 652,688,912 bytes, SHA-256
`a76c6e20aabb5ad20f011fdc9ea4d9df4211e018de3317a09baf1a8ed291c1d5`.
It exceeds the connector's 512 MiB download limit. The original GitHub archive
remains intact. Evidence-only recovery must preserve and verify those exact bytes
without another simulator, build or test run. This transport limitation is not
an application failure and is not a reason to rerun the tests.

## Integrated verification checkpoint (2026-10-21 21:38 UTC)

The four reviewed repair commits are integrated on top of evidence-only source
`254d401822b34183161932dc5d24c8db4ee25c77`. A separate make-ten motion defect found
in decoded native video remains open: transferred counters collide in transit and
untouched remainder counters compact. Its pending implementation is deliberately
excluded from this boundary test, as are new concept and multiplication/division
features. This run must establish the fixture and viewport corrections first.

There are no active original native jobs. The reviewed environment contract stays
Xcode 16.4 (16F6), SDK/runtime 18.5 (22F77), arm64 macos-15, unchanged devices,
max two concurrent public standard runners, and the original 900-second test
bound. The next run must record the actual image version and flag any drift from
20260907.0337.1 / macOS15.7.9 (24G830). No blanket reset, timeout change, assertion
weakening, or unrelated feature is included.

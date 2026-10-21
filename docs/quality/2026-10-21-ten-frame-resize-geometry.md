# Ten-frame descendant resize geometry

This records a narrow correction and its verification boundary, not a native
passing result. The separate countable-motion improvement is not included.

## Observed failure and retained evidence

- Repository: `oskuhsiu/CalcuLater`.
- Failing source: `fd17d7095175c8c224861b493f3c1d7c17526c79`.
- [Run 39680563952, attempt 1, standard job 119501648601](https://github.com/oskuhsiu/CalcuLater/actions/runs/39680563952/job/119501648601).
- Original artifact: `12384731702`, `native-evidence-standard-fd17d7095175c8c224861b493f3c1d7c17526c79-1`.
  Downloaded archive SHA-256 was independently checked:
  `1d2d01fb554664605a4dfd18be1f58177c6dc60a4552185fdbc15e33eef86def`.
- Evidence within that artifact: `environment.json`, `source-sha.log`,
  `build.json`, `readiness.json`, `scenario-configuration.json`, `test.json`,
  `test.log`, `test-summary.log`, `test-selection.json`, and `Tests.zip`.

Environment inventory, build, boot/readiness and scenario configuration passed.
The fingerprint remains arm64, macos-15 image `20260907.0337.1`, macOS 15.7.9
(`24G830`), Xcode 16.4 (`16F6`), SDK/runtime iOS 18.5 (`22F77`), iPhone 16,
and content size `large`. The test command exited 65 after 480.99 seconds,
within the unchanged 900-second bound; this is not a boot or test timeout.

All 230 component methods executed. The only failing method is
`LessonIntroViewTests/testResizeCancelsMotionWithoutAdvancingOrClippingAnyOfEightOriginalOnes`.
It reports six identical containment assertion failures at the original
`LessonIntroViewTests.m:133`, after the 736-to-288 width change. The original
assertion uses `CGRectContainsRect(CGRectInset(stage.bounds, -0.5, -0.5), dot)`.
There are six assertion failures in one method, not six failed methods or six
separate test runs. The xcresult summary reports 245 total methods, 244 passed,
one failed and zero skipped. `test-execution.json` was not generated because
the test command failed; source inventory is not a substitute for execution.

`GroupingTeachingBoardViewTests` now passes all 11 methods, and the separate
standard UI runner passes all 15 methods. The previous invalid-trait exception
is absent. That old fixture failure must not be reused as this diagnosis.

## Single hypothesis and source evidence

The intro's `layoutSubviews` previously read/cached the nested stage size and
called `stopPlayback` immediately after its own superclass layout. The stage is
inside a stack inside a scroll view; its final layout can occur later in the
same hierarchy traversal. A subsequent child-size change did not invalidate the
manual counter geometry. The renderer also took width from the stage but chose
side-by-side versus stacked frames from the already-resized parent.

The old source arithmetic reproduces the exact failure count: a stale stage
width of 704 with the new compact orientation yields frame x = 212 and width =
280. When the stage becomes 256 wide, only column zero of the eight original
ones is contained; the other six are outside. This is a source-supported
ordering diagnosis. The old failure artifact does not include actual dot-frame
values, so those runtime dimensions are not claimed as directly observed.

Apple's [Auto Layout Guide, Changing Constraints](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/AutolayoutPG/ModifyingConstraints.html)
describes a deferred hierarchy traversal and warns that some views remain
unlaid-out during a layout callback. It also cautions against invalidating views
outside the callback's subtree. The correction therefore does not force another
parent layout or rewrite sibling text from the stage callback.

## Discriminating correction

1. A private `CLIntroStageView` observes its own laid-out size. It caches that
   size before invoking a weakly captured owner callback. A changed stage size
   settles the selected snapshot; an unchanged stage pass does nothing.
2. The callback cancels animation/speech, prepares any missing dots, applies
   the selected state without animation and updates stage accessibility. It
   only lays out the stage's manual descendants. It does not update sibling
   labels/buttons, force layout, scroll, advance a step or reveal a later answer.
3. Existing dot creation is extracted into one idempotent helper shared by the
   callback and renderer. Dot identities, 32-point sizes and arithmetic are
   unchanged. First layout can still create dots even if the parent's earlier
   layout saw an empty stage.
4. Outer-bounds tracking remains, so height-only resizing still cancels motion
   when the fixed-height stage has not changed size.
5. Actual stage width now determines both frame orientation and positions.
   The proposed stage-height constraint still uses the parent's available width.

There is no timer, dispatch, sleep, retry, tolerance relaxation, simulator reset,
timeout/toolchain change, workflow edit, or new feature. Initial framing remains
one-shot; resizing never replaces the child's valid inspection offset.

## Regression and failure diagnostics

The original failing method is byte-identical. All 174 original assertion
invocations in this test file remain verbatim. The three added methods cover:

- Both 736/288 width directions, repeated resizing, height-only changes in both
  orientations, the 543/544 breakpoint in both directions, and width changes
  without an orientation change. The selected states are make-ten `2 + 9` step
  3 and break-ten `18 - 9` step 2.
- Actual stage/frame geometry immediately after one public layout pass, before
  any Play, Stop, Replay or second layout could conceal the problem. Assertions
  retain dot identities, quantities, 32-point size, selected step, hidden answer,
  framing count and a still-valid 32-point user-chosen scroll offset.
- Replay's recorded before-state after every resize, including the exact slot
  centers of all 11 make-ten source dots and all 18 break-ten source dots.
- A stable stage-only layout retains the same active animator and snapshot
  count, while changing the actual descendant content-width constraint from
  stage width 704 to 512 and back cancels motion without changing intro bounds.
  Those widths share the same 138-point stage height. Narration stays unchanged.

The new tests require a live animator before the interruption when Reduce Motion
is off. They do not disable animation or override accessibility preferences.
Geometry attachments retain intro/stage/scroll bounds, content size/offset,
selected step, animator, frame/annotation bounds, dot identities/frames/alpha/
crossed/selection state and recorded renderer geometry if a test fails. The
original containment helper additionally attaches this evidence on its first
out-of-stage dot. Diagnostic collection only reads state; it cannot repair it.

## Source validation and native gate

Passed on Linux:

- `git diff --check`.
- All 30 existing methods and all 174 original assertion invocations retained;
  the original failing method is byte-identical.
- Existing narrow macro-comma scanner: 116 Objective-C/header files, no hazards.
- Existing source-selector resolver: 248 required standard methods (233
  component plus 15 UI), including all 33 `LessonIntroViewTests` methods; seven
  methods in each compact/tablet/maximum-text scenario. No selector was changed.
- Independent source review of callback ownership/reentrancy, stage-only
  mutation, geometry fixtures, preserved assertions and diagnostic collection.
- A separate arithmetic control reproduces six clipped dots for the old mixed
  geometry and checks 20 final source/target arrangements at stage widths
  256/288/511/512/704 for containment and nonoverlap. This is not UIKit execution.

This host has no Apple SDK, Xcode or Simulator. Objective-C compilation, UIKit
layout/callback execution and native acceptance of this correction are not yet
verified. No new native run or publication was initiated for this repair. The
lead owns at most one planned verification after the current run is terminal.

Expected native observation: the original resize method passes unchanged; the
last recorded stage bounds match the final child bounds after one layout pass;
all added geometry/source/cancellation checks pass; initial presentation and
uninterrupted Replay still behave as before. The complete standard component/UI
selection and existing layout scenarios remain required. Keep the original
900-second test bound, 35-minute job bound, max-two public standard runners and
the frozen Xcode/runtime contract. If this same boundary fails again, inspect
the new geometry attachments rather than rerunning or adding another layout
call to the tests.

# Countable make-ten transfers

Date: 2026-10-21. Base: `9a5ad01` (`review/native-viewport-fixture-repairs`).
Its teaching implementation and tests match published `fd17d709`; the full
published tree also has separate evidence-recovery tooling and notes. This local
checkpoint does not include the separately reviewed stage-layout resize repair.

## Native defect and scope

Original native tablet video from run `39657409557`, source `c948de49`, shows
actual collisions during `2 + 9`: eight selected yellow counters follow
simultaneous straight-line spring paths, and the untouched blue remainder
compacts from its original bottom-row slot to the top-left slot. This is a
product defect despite all seven selected tablet UI cases passing.

The original 1640×2360 decoded frames `15316` and `15328` show the collision;
`15298` / `15304` are before it and `15340` is settled. Replay frames `15542`,
`15548`, `15554`, `15560`, `15572` and Back→Next frames `15608`, `15614`, `15620`,
`15626` repeat it. Use decoded frame indices, not global timestamps: the video
has PTS discontinuities. The original collision image was inspected directly.

Only `LessonIntroView.h/.m`, its existing component test file, the existing
`Calcu_LaterUITests.m` file, and this note change. There are no project, CI,
new UI-test-class, curriculum, model or publication changes.
The separately verified break-ten operation still fades only the nine crossed
units while the original eight green units stay fixed.

## Pedagogical motion

- The same actual selected dots move one at a time, in source-slot order. Nothing
  is cloned, substituted, faded out or compacted. Every untouched pink and blue
  counter retains its original location, including the eight blue remainders
  when only one unit moves in `9 + 9`.
- Wide frames retain the existing 24-point gutter and 240–280-point frame width.
  Each unit exits left through vacated source slots, turns in the gutter and
  enters its destination row from the empty right end.
- Compact make-ten reserves a left transfer lane. A unit exits left through
  vacated source slots, rises through that lane, crosses the unobstructed gap
  between frames, then enters its destination column from below. Destination
  top-row slots fill before their bottom-row slots, so this route does not pass
  through an earlier unit.
- Compact source-frame y is 184; its annotation sits two points below its
  100-point frame. The stage height is derived from that annotation's bottom
  plus four points (320 points). Moving the annotation out of the transit gap
  prevents a counter from crossing text. At the narrowest supported 288-point
  surface, frame cells are 41.6 points wide and all counters remain 32×32 points.
- Each unit moves for 0.70 seconds, with a 0.12-second initial/arrival pause.
  Leg durations are proportional to distance. The finite timeline is 0.94–6.68
  seconds; only one unit is in transit at any moment. Linear keyframes avoid
  spring overshoot at turns and destinations. No completion advances a step.
- Replay builds the selected step's own step-2 source and reuses the same paths.
  Cancel, Back, new Next, hiding, alpha, detachment, resize, background and motion
  preference changes retain the existing cancel-and-settle semantics. Reduce
  Motion immediately shows the same selected endpoint without a future answer.
- Initial framing remains one-shot. New-step framing includes every complete
  routed counter footprint as well as the source/destination scene. Replay and
  inspection offsets are not reframed. L1–L3, break-ten geometry and arithmetic
  validation are unchanged.

The UIKit animation uses the existing property animator, with linear UIView
keyframes inside its animation block. The final keyframe applies the selected
snapshot synchronously while constructing the timeline. Earlier legs already
set the other transferred dots' model centers; this is not a delayed snapshot
callback and does not schedule future work. Apple documents the underlying
[property animator](https://developer.apple.com/documentation/uikit/uiviewpropertyanimator)
and [keyframe API](https://developer.apple.com/documentation/uikit/uiview/animatekeyframes(withduration:delay:options:animations:completion:)).

## Playback lifecycle is separate from target quantities

The prior UI tests read final model-layer quantities immediately after starting
the animator. Those quantities are assigned synchronously while constructing
the animation, so they were not evidence that a transfer had actually finished.

- The public read-only `playbackGeneration`, `playbackStepIndex`, and
  `playbackState` identify the latest Next/Replay request. States distinguish
  idle, running, completed, cancelled, and reduced motion. Even a pre-layout
  request gets a unique generation and cancelled state rather than a false end.
- Completion checks the exact animator identity, active generation, requested
  generation, captured playback step, currently selected step, and running
  state. Only a matching `.end` marks completed. `.start`/`.current` settle the
  selected endpoint as cancelled. Production never forces an animator to end.
- Cancellation clears the active generation and animator identity before
  stopping it. Back, a newer Replay/Next, hide, alpha, detachment, resize, and
  background cannot let an old callback certify the new selection. There is no
  delayed step change, forced advancement, answer reveal, or scoring callback.
- Enabling Reduce Motion settles as reduced motion, not naturally completed.
  Turning it off does not automatically replay. The component preference seam
  can only opt into reduced motion and never overrides an enabled system setting.
- The progress label exposes a human-readable playback record and state. Back
  explicitly distinguishes the previous playback from the current static step.
  While running, stage quantities are prefixed with “這一步完成後” to identify
  them as the selected target, not live presentation counts. No focus change or
  automatic completion announcement is introduced.

## Authored component gates

All prior tests and geometry assertions remain. Four new methods cover:

1. All 36 valid make-ten problems at widths 288, 320, 359, 543, 544 and 736.
   Every production leg endpoint, midpoint and intervening eighth is checked
   for stage containment, text clearance and distinct 32-point units. The
   schedule must be sequential with explicit pauses; every original untouched
   position, dot identity, exact count and settled target must remain stable.
2. Next must frame the actual corridor before starting its animator, without a
   preparatory scroll, at compact and wide sizes.
3. A real paused native property animator is scrubbed to every leg midpoint for
   `2 + 9` and `9 + 9` at widths 288, 544 and 736, including the tightest
   wide gutter. A bounded presentation-commit wait replaces fixed frame sleeps. Presentation-layer positions
   must match the production schedule, every opacity must remain one, and all
   units must remain separately countable. This test is explicitly skipped when
   Reduce Motion is enabled; it is not replaced by model-layer assertions.
4. Height-only and compact/wide resize during staged Replay settle exactly step
   3, with all units present and the final equation still hidden.
Existing replay, background, Reduce Motion notification, hide, detach, Back,
initial framing, first-Next framing and all L1–L5 semantic tests continue to
apply to the new timeline. All 30 previous component selectors remain; there
are 42 unique component methods after this change. In addition to the four route
methods above, eight lifecycle regressions cover real natural completion for
both `2 + 9` and `9 + 9` (each bounded at eight seconds), stale callbacks,
wrong animator/generation/step, Back/Replay/Next, lifecycle cancellation, non-end
finishing, reduced-motion snapshots and notification changes, and pre-layout
requests. No original assertion was removed.

The paused presentation probe is unchanged: each requested midpoint has a
maximum 0.5-second render-commit wait. A midpoint failure must be investigated,
not hidden with longer sleeps, disabled animation, or model-layer substitutions.

## Authored native UI gates

The same 15 standard UI methods remain; no new method is added to that broad
selection. Two existing methods are strengthened:

- `testMakeTenCurrentNineDotsReplayBackRotateAndFinish` now waits for the exact
  new generation and selected step to report natural completion for first-play,
  Replay, and Back→Next of `2 + 9`. Each gate is at most eight seconds for the
  real 6.68-second transfer. All original count, framing, answer-hiding,
  rotation, finish, and unanswered-return assertions remain. Inspection cannot
  replace the untouched first-play gate.
- `testTenFrameVerticalComparisonAndSwipeReturnToTheOriginalQuestion` now
  selects one of nine incoming counters, actually transfers it, and completes
  a Replay of `9 + 9`, with ten counters in the first frame and eight in their
  untouched source slots. It no longer leaves after only showing step 1. The
  existing vertical-comparison, dismissal, and unanswered-return checks remain.

A separate fourth `2 + 9` Replay attempts rotation interruption after the three
complete transfers. Its retained lifecycle attachment records the previous
generation, requested fourth generation, post-rotation state, and interpretation.
XCUITest may wait for finite animations before rotating. If that generation
already completed, the result is rotation continuity only, not interruption
proof. A cancelled generation is reported distinctly; native video must locate
its interruption timing. There is no fake app timing hook or synchronization
override. Deterministic component interruption tests retain strict cancellation
and stale-callback assertions independently of UI synchronization.

## Checks completed here

Linux source-derived verification passed all 36 inputs at eight widths (288,
320, 343, 359, 543, 544, 736, 1024): 288 configurations, 3,420 continuously swept
axis-aligned legs and 112,860 sampled leg positions. Every swept 32-point
rectangle stays inside the stage and avoids every stationary counter and label.
The minimum cell width is 41.6 points. The 288×500 annotated scene still fits;
the 288×420 full-frame scene still does not fit while its complete counter/path
union does. Existing geometry assertions were not weakened to obtain this result.

`git diff --check` passes. Native compilation, authored XCTest execution,
first-play/Replay/Back video acceptance and accessibility/Reduce Motion visual
acceptance are **not run** here: Xcode and Apple Simulator are unavailable on
this Linux executor. The mathematical sweep and source review are not native
acceptance and do not establish the UIKit timeline's actual presentation.

The source-only macro-comma scanner checked 2,040 invocations in 116 source
files with zero flagged hazards. Exact assertion-call comparison retains all
174 prior component assertions and all 228 prior standard UI assertions. The
paused midpoint method byte-matches the preserved pre-lifecycle checkpoint.
These checks are not an Objective-C compiler or an XCTest execution.

A fresh read-only lifecycle review found the identity/generation/step guards
and invalidation-before-stop sound. It identified the historical/current-step
accessibility ambiguity and zero-width request identity gap; both were repaired
with regressions. The native rotation synchronization limitation above remains
explicit rather than being called a successful interruption.

## Required native acceptance

Prefer a focused native selection rather than automatically expanding the full
standard workload (the previous standard command already took about 730 seconds):

1. `Calcu LaterTests/LessonIntroViewTests`
2. `Calcu LaterUITests/Calcu_LaterUITests/testMakeTenCurrentNineDotsReplayBackRotateAndFinish`
3. `Calcu LaterUITests/Calcu_LaterUITests/testBreakTenCurrentEightOnesSurviveReplayBackgroundAndReturn`
4. `Calcu LaterUITests/Calcu_LaterUITests/testTenFrameVerticalComparisonAndSwipeReturnToTheOriginalQuestion`

These are 42 component plus three UI methods in this isolated source. The resize
repair adds three more component methods when integrated. Select the three UI
flows explicitly on compact, tablet and maximum-text devices too: the existing
nonstandard matrix currently selects only the first two ten-frame UI methods,
so it would otherwise miss the new `9 + 9` transfer. This note proposes selection;
it does not change the workflow or dispatch a run. Keep the 900-second command,
35-minute job, and maximum-two-runner bounds unchanged.

Retain first-play `2 + 9` motion before helper intervention, then separately
capture Replay and Back→Next. Decode the complete transfer, not only its settled
endpoints. At every observed phase, verify one unit in transit, stationary
untouched blue and pink units, no overlaps, no label crossing, no clipping and
no answer before the final child-controlled step. Include `9 + 9`, compact,
wide/landscape, maximum text and Reduce Motion. Recheck the known-correct
`18 − 9` crossed-unit fade, original eight green units, lifecycle interruption,
initial one-shot framing and valid inspection offset preservation.

When integrating the separate resize patch, keep its descendant-stage callback
calling cancellation before settlement and accessibility refresh afterward.
Use actual laid-out stage width for both snapshot orientation and transfer
routing. Its make-ten compact expected geometry must be recalculated for the
320-point stage, source y=184, 48-point lane reservation and x offset described
above. Break-ten stays at 292 points with source y=188. Do not delete or loosen
the resize containment assertions to resolve the different authored geometry.

A failed presentation-layer probe is an implementation/fixture investigation,
not permission to relax its count or geometry assertions. No native run is
started, rerun or published by this local checkpoint.

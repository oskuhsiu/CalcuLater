# Initial ten-frame presentation framing

Date: 2026-10-21. Base: `c948de49`.

## Verified boundary

The compact iPhone SE evidence from native run `39657409557` shows a product
framing issue before a test helper intervenes. In the untouched `18 − 9` initial
help screenshot (`31843437-402A-4A30-BDCB-89B14459755E.png`), the full ten is
visible but the persistent footer obscures most of the eight original ones.
The matching hierarchy (`90D74F65-3972-4CC7-98D9-A6F3D74B0725.txt`) places the
292-point stage at y = 282.5, inside a scroll viewport from y = 136 to 499. The
whole stage can fit in that 363-point viewport if framed.

By contrast, the untouched first-Next `2 + 9` screenshot
(`736F14AA-C734-4D5D-B7B4-435021BC5B42.png`) already places both frames above the
footer. The existing Next framing is therefore reused, not replaced. Subsequent
inspection-helper scrolling is a separate test issue and is not the basis for
this product change. Evidence was inspected as actual image pixels and hierarchy
text, not inferred from the workflow result. Run `39657409557` was still active
when this isolated change started; this branch did not publish or dispatch CI.

## Minimal change

`LessonIntroView` has one presentation-lifetime flag. On the first `play` with a
visible, attached, nonempty ten-frame surface, the selected initial state is
settled, then its actual visible scene is framed synchronously without animation.
The existing geometry-aware routine prefers annotations plus full frames, then
full frames, then all visible counters. An infeasible scene stays scrollable.

- Hidden or unattached preparation does not consume the first presentation.
- The first actual presentation consumes the flag even when nothing fits. A
  later resize is not a second opportunity to replace the child's viewport.
- Repeated `play` calls, including a controller appearance after nested help,
  cannot reframe the initial scene. Back, Replay, rotation, backgrounding,
  detachment and reattachment do not reset the flag.
- If the child has already selected a later step before the first visible
  `play`, that call does not perform initial-step framing.
- Only Next increments the step. No timer, delay, new animator or permanent
  animation disabling is introduced.
- Current-question operands, unanswered equation, dot identity, exact counts,
  original break-ten ones, full frame sizes, controls and narration remain
  unchanged. L1–L3 do not enter this presentation-framing path.

This deliberately supplements the earlier “only Next requests framing” statement
in the current-question quality note: one initial ten-frame presentation is now
also framed. All subsequent automatic framing remains exclusive to Next.

## Authored regression coverage

Five component methods were added, retaining all 25 previous methods:

1. Canonical and actual-question make/break-ten first presentation at 288×500,
   the native compact surface's 359×539 geometry, and wide-short 736×260. Visible
   frames and annotations must already fit, with correct initial quantities,
   no answer reveal, no cross-outs, full-size frames and no animator.
2. Unattached and hidden preparation must defer the one-time framing until the
   first visible presentation.
3. A valid chosen offset must survive repeated `play`, background, hiding,
   alpha changes, detach/reattach, resize, Replay and Back to step zero, with
   unchanged dot identities and all eight original ones.
4. A too-short initial viewport must not jump to a partial scene or retry
   automatic initial framing after a later enlargement.
5. L1–L3 retain the original initial offset and never use the new framing path.

Existing Next and inspection tests now compare against the legitimate initial
framing baseline rather than assuming every lesson always starts at offset zero.
The too-short Next test still rejects a new partial-scene jump. No UI-test source
or test helper was edited.

## Validation and handoff

Passed in Linux: `git diff --check`; the requested source macro audit across
116 Objective-C/header files with zero hazards; source invariants confirming
that all actions after `play`, the math snapshots, shared framing implementation
and animator implementation are byte-identical to the base. The 30 component
selectors are unique and all 25 existing selectors remain. These are source
checks, not compilation or UIKit execution.

Not run: native compilation, any new XCTest method, updated UI acceptance,
animation/video inspection of this change, VoiceOver or Reduce Motion. Xcode and
Apple Simulator are unavailable in this Linux workspace. The inspected native
screenshots establish the old defect, not acceptance of this fix.

For the next planned native acceptance run, retain the untouched `18 − 9`
first-entry screenshot before any swipe, Next or Replay. Verify both full frames
and eight original ones are above the footer whenever the scene fits. Preserve
first-Next motion checks, then independently inspect Replay/Back, nested-help
return, rotation and background return after selecting a valid offset. Check
compact, tablet and maximum-text layouts without shrinking frames or weakening
quantity/identity assertions. Integrate the separate helper correction on its
own merits. No new run or rerun is requested by this note.

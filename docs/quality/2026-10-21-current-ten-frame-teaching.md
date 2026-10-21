# Current-question ten-frame teaching

Date: 2026-10-21. Base: `5ffe8ae3e8661bf71ef33d9e62c3d4a1352774d0`.

## What changed

`LessonIntroView` is now the single countable renderer for both the canonical L1–L5 introductions and valid current L4/L5 arithmetic questions. L1–L3 retain their existing examples and meanings. No new curriculum or scoring model was introduced.

- Back, Next and “重看這步” replace the 3.2-second progression timer.
- Replay reconstructs the selected step's own before-state, then applies that step again. It does not reset to the beginning or animate from an already settled position.
- “開始練習” or “回到題目” stays available throughout. The completion callback is idempotent; the final Next action uses that same completion path.
- Resizing, hiding, detaching, backgrounding, cancellation and a Reduce Motion change settle the selected state. No animation completion advances the step or schedules a sound.
- Speech reads only the current narration. Changing a step or leaving the surface stops existing speech.
- Make-ten and break-ten both use two actual 2×5 frames, with 32-point counters. The entire diagram scrolls instead of shrinking or aggregating quantities.
- The selected make-ten dots have a second outline as well as a different color, so the split does not depend on color alone.

The actual-question route in `ExplanationViewController` owns one properly constrained teaching surface, not the previous 360-point nested visual with a duplicate footer. It does not append the full answer, full-explanation speech or whole-example replay. The optional vertical comparison remains available and its return button dismisses directly to the original practice question.

`PracticeViewController` production help routing, help-use accounting, scoring, generators and saved progress are unchanged. Its only edits are matching-lesson DEBUG fixtures.

## Arithmetic and identity contract

The explicit initializer returns `nil` for invalid input and never substitutes a canonical example. It snapshots the validated numbers and lesson kind instead of retaining the mutable problem as rendering state.

- Make-ten: `a = 2…9`, `b = 1…9`, `10 < a + b ≤ 18`, `+`, correct answer, not multi-step.
- Break-ten: `a = 11…18`, `b = 1…9`, `b > a % 10`, `-` or the equivalent Unicode minus `−`, correct answer, not multi-step.
- Bounds are checked before arithmetic, including for malformed extreme integer inputs.

Make-ten shows `a`, then all `b`, then marks `need = 10 − a` and `rest = b − need`, then transfers exactly the existing `need` dots into the first frame. Total quantity is conserved. Only the final step writes the main answer and the concluding `10 + rest = answer`.

Break-ten shows ten plus the original ones, crosses out exactly `b` dots from the ten, then removes only those crossed-out dots. The original ones never move or change identity. The final explanation combines `10 − b` and the original ones. It does not substitute the “subtract the ones first” method.

The main equation remains unanswered until the final step. Intermediate counts and the countable diagram are intentional teaching information.

## Authored verification

`LessonIntroViewTests` now has 20 component test methods. These preserve the prior useful canonical/layout coverage while replacing obsolete timer and fixed-244-point strategy expectations with the child-paced contract:

- Every one of the 36 valid make-ten pairs and 36 valid break-ten pairs, at compact 288-point and wide 736-point widths, through every step.
- Visible quantities, correct frame membership, no counter overlap/clipping, two full ten-frames, dot identity, exact transfer set and unchanged original ones.
- Invalid answers, operators, domains, multi-step input, extreme integers and defensive snapshot behavior.
- Back, Replay's actual before-state, selected-state interruption behavior, no idle advance beyond the former timer interval, short-screen scrolling, scalable narration and idempotent completion.
- The current-question controller has no separate full-answer text/replay/visual-slot constraint.

Three native acceptance flows were added to the existing `Calcu_LaterUITests` class:

1. L4 / `2 + 9`: all nine incoming dots, split eight/one, transfer, Back, Replay, rotation and completion back to the same unanswered question.
2. L5 / `18 − 9`: eight original ones, nine cross-outs from the ten, Back, Replay, background/foreground and return to the same unanswered question.
3. L4 / `9 + 9`: eighteen countable dots, secondary vertical comparison with direct return, and swipe dismissal of reopened help.

These flows keep bounded gestures and predicate/existence waits, do not disable app animations, and reuse the existing retained screenshot/hierarchy and native recording infrastructure. The diagram is explicitly brought into view before replaying the important movement for recording.

## Verification status and limits

Completed in the Linux workspace:

- `git diff --check` passes.
- A source-level arithmetic enumeration matches all 36 + 36 catalog pairs.
- A source scan finds no timer, delayed dispatch or scheduled progression in `LessonIntroView`; only the explicit Next action increments the step.
- XCTest macro arguments were checked for Objective-C literal commas; literal array arguments are parenthesized.
- Independent source review is recorded with the implementation handoff.

Not run here: native Objective-C compilation, XCTest, Simulator/UI flows, screenshot review, real animation playback, VoiceOver or Reduce Motion rendering. `xcodebuild` is unavailable in this Linux environment. Source review is not evidence of a native visual or test pass.

The current `native_quality.py` standard scenario selects `Calcu_LaterUITests`; compact/tablet/maximum-text scenarios select the separate layout class. The new three flows therefore require explicit selection or corresponding layout-owner coverage in the later matrix run. CI and the layout-test file are deliberately unchanged in this checkpoint.

Before calling the feature native-verified, run the new component and UI tests plus the existing lesson/session tests, inspect compact phone, tablet, maximum-text and Reduce Motion states, and decode the retained native video around the make-ten transfer and break-ten removal. Check that counts and the selected step remain stable after rotation/backgrounding and that completion/dismissal never selects an answer or advances the question.

## First-play viewport correction

Follow-on to `ff7ab5b`, authored on 2026-10-21. This section supersedes the earlier fixed, vertically stacked strategy-stage description, not its counting or teaching contract.

- Next updates text and finishes current layout before measuring the actual selected state and its own before-state. It synchronously frames their union before creating/starting the finite animator, so new-step motion does not depend on a preparatory swipe or Replay.
- Framing prefers the complete annotated scene, then both full frame bounds, then every visible source/destination counter if that is the only complete transformation that fits. The union includes stationary original ones and a four-point margin. If even that union cannot fit, it does not jump to just one endpoint; the unchanged full-size content remains scrollable.
- Only Next requests automatic framing. Back, Replay and interruption settlement do not override a valid user-chosen scroll offset.
- At a teaching-surface width of at least 544 points, the strategy's two full 2×5 ten-frames sit side by side with a 24-point gutter and separate annotation lanes. Each frame is 240–280 points wide and 100 points tall; the stage is 138 points tall. Narrower surfaces retain the 292-point stacked stage. All counters remain 32×32 points. L1–L3 geometry and arithmetic semantics are unchanged.
- Resizing still cancels active motion and settles the selected state. Responsive geometry does not alter dot identity, count, valid input domains, answer concealment or the original-ones invariant.

Five additional component tests (25 total) exercise real `UIScrollView`/stage geometry: compact 288×500 first Next without setup scrolling; wide 544/736×260 first Next with full frames; compact 288×420 counter-union fallback; Replay/Back offset preservation at compact and wide sizes; and a 288×360 viewport too short for the full transform. The recording subclass captures viewport geometry inside the target-state application, so the containment assertion is about framing already being in place when animation applies its target, not about a test scrolling afterward. Existing exhaustive count/identity tests also exercise the new wide geometry.

Verification in this Linux workspace: `git diff --check` passes for the owned files. A source-derived enumeration covered 2,916 make-ten/break-ten states across nine widths (including both sides of the responsive breakpoint), finding no visible counter overlap, off-frame counters or counter-size changes. A source control-flow scan confirms only Next advances the step, framing precedes animator creation, and no timer/delayed progression was added. These are source checks, not UIKit execution.

Native Objective-C compilation, component test execution, UI flows, actual animation/video review, accessibility and Reduce Motion remain unrun here because Xcode/Simulator are unavailable. Native acceptance must still verify first Next without setup swipes in compact portrait and wide landscape, followed separately by user-positioned Replay/Back and resize/background interruption. The earlier pre-scrolled Replay recordings alone are not evidence for first-play visibility.

Independent review found no blocking source issue. Its temporal-test suggestion was adopted: the recording subclass additionally observes the framing operation and asserts that no animator exists yet and exactly the target application follows. Back/Next/Replay now post the current narration as an accessibility announcement instead of requesting focus on the below-stage narration view. That removes an explicit source of VoiceOver-driven scroll jumps; actual VoiceOver behavior still requires native verification.

The native flows also retain untouched new-step captures before their helper can
scroll or replay: incoming make-ten dots, the transfer, and break-ten removal.
When the whole stage fits, a direct viewport assertion checks its first-play
vertical containment. The helper accepts the genuine 138-point wide layout, not
an obsolete 250-point minimum. These synchronized screenshots show the settled
pre-intervention position, not animation endpoints or exact timing. Shorter
viewports still require inspection of the raw native recording and both ends of
the transformation; no full visibility claim follows from partial intersection.

# Child-paced practice checkpoint

## Changes under native validation

- Shared practice state for lessons, ten-question drills, five-story rounds and
  five-question scratchpad rounds. Correct answers and worked solutions remain
  until the learner chooses the next action.
- A result distinguishes independent answers, successful retries and guided
  answers. Review repeats the actual questions that needed help. Lesson stars
  describe independent answers, separately from completion and previous best.
- Remainder teaching preserves `dividend = divisor × quotient + remainder` and
  does not assign the quotient's unit to a remainder. Inverse, two-step and
  fraction questions retain their own worked explanations.
- Balanced lesson decks cover each multiplication fact once and avoid
  replacement-heavy repetition. Drill ranges now match the visible limits.
- Candy-colored controls use readable dark text and non-color answer feedback.
  Rapid/reentrant taps cannot consume multiple answers or score twice.
- Scratchpad taps and endpoints are preserved; Clear is undoable, while a fresh
  question resets history. The mode explicitly says handwriting is self-checked,
  not recognized. One finger writes; two fingers scroll the containing page.
- Explanation sheets are scrollable, support replay/reading and adapt to content
  width. Grouping and equal-part visuals are bounded and mathematically checked.
  Story multiplication/division uses exact worked text, not a generic grouping
  picture that might contradict sharing, scaling or unit-conversion semantics.
- Continuous decorative animation no longer uses perpetual UIKit animation;
  hidden/background/reduced-motion states stop unnecessary animation/audio.

## Source review corrections

An independent review caught compact-height clipping, hidden-stack required
height conflicts, a scratchpad scroll trap, fixed teaching height, ambiguous
story grouping and stale test assumptions about accessibility labels. The
implementation was corrected before the next native run. Portable checks
verified all 36 make-ten and 36 break-ten operand combinations preserve their
displayed transformations. This is not a substitute for Simulator verification.

## Native acceptance additions

The original four tap flows remain, adapted to deliberate sheet dismissal and
child-paced answers. Explicit Debug launch fixtures add repeatable checks for
23 ÷ 4 = 5 remainder 3, the equation check, background/foreground answer
persistence, completion/retry, equal fourths, and landscape 500 − 128 borrowing.
Fixtures use the same app views and answer state as generated content and are
absent from Release builds.

Native build, screenshots, compact-device/iPad layouts, VoiceOver traversal and
real drawing interaction are still pending for this checkpoint. No visual or
accessibility pass is claimed from source review alone.

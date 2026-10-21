# Child-paced practice checkpoint

## Changes

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

## Native result and visual review

Source: `c0ba31bcc2fced10bfcee9a2e262b73332296097`.
[Native run 39626853839](https://github.com/oskuhsiu/CalcuLater/actions/runs/39626853839)
passed environment, build, Simulator boot, test, evidence export and cleanup.
Xcode 16.4 (16F6), iOS 18.5 (22F77), iPhone 16, arm64 macOS 15.7.9 (24G830),
runner image 20260907.0337.1. All 139 model/component tests and 6 native tap flows
passed, with no skipped tests. The test stage took about 148 seconds, inside the
unchanged 900-second bound. The earlier animation-idle stalls were absent.

[Evidence artifact 12358371502](https://github.com/oskuhsiu/CalcuLater/actions/runs/39626853839/artifacts/12358371502)
contains result bundles, logs, 19 actual Simulator screenshots and accessibility
hierarchies. The downloaded archive SHA-256 is
`244578529451a927c6cd16d8a6909a690f5d0e6e0d79785e504058e3f5403eb6`.
Artifacts have a seven-day retention window, so keep a downloaded archive.

Actual image inspection confirmed readable four-choice drill controls, deliberate
answer persistence, honest guided-result/retry controls, equal fourths and the
correct `5 × 4 + 3 = 23` remainder check. It also found defects that green tap
assertions missed: the long remainder story truncated to one line, and a story
question stack grew to 435 points inside a 361-point viewport. A landscape legacy
borrow hint showed only the top of a long view. These are not visual passes;
the next checkpoint adds explicit wrapping/bounds checks and replaces the large
addition/subtraction hint with inspectable vertical teaching.

Compact-device/iPad layouts, maximum Dynamic Type, full VoiceOver traversal,
actual multi-finger drawing and the new teaching animations remain pending.
Passing source/model tests is not evidence that these interactions look right.

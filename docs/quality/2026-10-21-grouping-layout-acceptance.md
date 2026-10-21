# Grouping layout acceptance: source checkpoint

Based on `b117f8c`, this adds two focused methods to the already selected
`Calcu_LaterLayoutUITests` class and repairs its shared reveal helper after
reviewing retained compact-device evidence. It changes no application code, test
selection, CI limits, device settings or animation behavior. The earlier layout matrix run
`39637261073` targets pre-grouping `84f371d`; it cannot validate these methods.

## What the native flows will check

- Sharing `23 ÷ 4`: four known recipients start empty; a child answers the optional
  prediction without auto-advance; the first round settles at one sweet each and
  19 in the common pool. Back preserves the answer to that prediction.
- Packing the same quantities: no prefilled bags; the first optional prediction
  can be skipped and remains unanswered on Back. One bag receives four sweets,
  with 19 still in the pool and no second completed bag.
- First playback is inspected before any test scroll. Both flows then traverse
  the board from its top through the common pool and lower groups, retaining
  screenshots and accessibility hierarchies. Actual successive displacements
  must leave overlapping slices. Scroll coordinates come from the actual
  viewport, with bounded gestures, not fixed screen taps.
- Replay at the selected lower portion preserves the board's screen position
  and step. Predicates wait for actual settled group/pool counts and no moving
  count, rather than assuming the real one-second motion ended when tapping did.
- The final snapshots preserve one common remainder of three sweets. Sharing
  writes five sweets per child; packing writes five bags, not five sweets. Closing
  sharing and completing packing return to the unchanged story with all answers
  enabled, unselected and explicitly marked unanswered, with no next-question
  action.

## Evidence-backed scroll-helper correction

In the compact job of `39637261073`, the existing Settings flow failed after ten
upward swipes looking for `settings.tier.3`. The retained log, failure screenshot
and hierarchy place D3 at `y = -539.5`, while the table is already at its bottom
(`100%`). This establishes overshoot in the test helper, not an intrinsically
unreachable row. The replacement keeps the ten-attempt limit, derives short
coordinate drags from the current visible viewport, and recomputes direction
from the target's current frame after every drag. An overshot row therefore
causes a downward correction. The supplied direction is only a fallback while
a virtualized target has no usable geometry. Table accessories use their
containing cell's frame for direction: the retained tree also shows a stale
offscreen switch frame outside its row. Actual hittability of the original
target, subsequent native taps and persisted-value assertions remain required;
none are skipped.

## Required evidence and limits

Run both methods in the compact iPhone SE (3rd generation), iPad (10th generation)
and verified system `accessibility-extra-extra-extra-large` matrix scenarios.
The class now contains five methods. Existing 900-second test bounds remain;
the added scrolling loops are bounded to eight attempts/slices and predicate
waits to three seconds. Native duration has not been measured.

The board intentionally exposes one accessibility element. Tests require finite,
nonempty geometry, a visible intersection and horizontal bounds, but do not
mistake hittability for visible counters or require a tall board to fit all at
once. Review `layout-15` / `layout-23` first-play viewport screenshots and the
existing unmodified native video for actual source-to-destination movement,
including before/mid/after. Review each subsequent top/lower slice for the common
pool, count labels and lower groups, and `layout-19` / `layout-27` for answer and
remainder units. Screenshots, AX values and an MP4's existence are not by
themselves proof of readable, visible or understandable animation.

Local validation is source-only: whitespace checks, AX/step-map review,
XCTest assertion-macro comma inspection/synthetic preprocessing, and bounded
gesture-coordinate checks. Independent review found no deterministic source
blocker and prompted stronger slice-overlap and unanswered-state assertions,
plus the containing-row correction for virtualized accessories.
**Native Objective-C compilation, XCTest execution, gesture behavior, video
inspection and rendered layout
acceptance remain pending** because this editing environment is Linux with no
Xcode or Apple SDK. Keep exact source SHA, run/attempt, test results and reviewed
artifacts with the eventual native evidence.

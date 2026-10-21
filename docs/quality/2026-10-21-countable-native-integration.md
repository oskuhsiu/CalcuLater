# Countable ten-frame native acceptance candidate

This is an acceptance plan, not a native pass.

## Reviewed source

- Base: published `69510a05`, whose app is the resize-only `37256a7` app.
- Counter-motion source: exact recovered `934d7ac`, integrated with the actual
  descendant-stage resize callback at `a9874e9`. Fresh independent review found
  no source integration blocker. Counter identity, unchanged remainders and the
  original resize regression remain covered.
- Original video retention: recovered tree
  `374824bee8a65c4398c82e1a8159037b6c897842`, independently reviewed and tested.
  Recordings are split into bounded, hash-verified original-byte parts, never
  transcoded. Missing recordings remain missing evidence, not a motion pass.
- Strict execution proof: `329b0aa` and its reviewed defensive follow-up use
  exact structured XCTest case results, not fragile interleaved console text.

The prior standard native run's console lost one method name when an NSLog was
inserted inside it. Read-only inspection of its existing, digest-verified result
bundle independently established all 248 selected methods Passed. No simulator,
build or test was rerun to obtain that proof:
https://github.com/oskuhsiu/CalcuLater/actions/runs/39687967408

## Explicit selection and unchanged bounds

The candidate selects 260 standard methods: 245 components and 15 UI methods.
There are 45 `LessonIntroViewTests` methods, including the three resize regressions
and 12 route/lifecycle additions. The other layouts each select eight UI methods:
five layout flows plus the 2 + 9, 18 − 9 and newly selected 9 + 9 flows.
These counts are source inventory, not evidence that any method executed.

The 9 + 9 method was already strengthened on the standard class; selecting it on
each layout adds proof of the eight untouched remainder counters. Existing native
assertions and the paused presentation-layer probe stay in place. The explicit
portable inventory guard changes from 248/7 to 260/8 for these reviewed additions.

Xcode 16.4, iOS 18.5, 900-second test stage, 35-minute job bound, public standard
macOS runners and maximum two concurrent runners are unchanged. No blanket
simulator reset, automatic rerun, animation-disable flag or timeout inflation is
introduced. All offline evidence tests run before simulator preparation.

## Required native and visual review

1. Inspect actual first-play, Replay and Back→Next video, not only endpoint AX
   quantities. For 2 + 9, eight original selected counters move one at a time;
   the one unselected counter stays in its original slot.
2. For 9 + 9, exactly one selected counter moves. All eight unselected counters
   stay in their original slots throughout the real transfer and Replay.
3. Check the presentation-layer midpoint probe, generation-qualified natural
   completion and stale-callback/cancellation component tests. Rotation that
   happens after completion is continuity evidence, not interruption evidence.
4. Inspect compact phone, iPad and actual maximum system text. Source, destination,
   counters and transfer route must be visible and countable. A conditional
   whole-stage-fit assertion or a green UI test is not enough when a viewport is
   shorter than the diagram. Any clipped real transfer remains an open defect.
5. Preserve and inspect the untouched 18 − 9 first entry, its ten plus eight
   original counters, Replay, background return and still-unanswered question.
6. Download and hash-check every original-byte video part, reassemble without
   alteration and retain the raw xcresults, screenshots and hierarchy evidence.

Actual system Reduce Motion has its own authored Settings/readback suite. That
suite is not included in this candidate, and neither component dependency
injection nor a completed static snapshot substitutes for running it.

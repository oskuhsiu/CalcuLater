# Native teaching evidence: 21–22 October

## Exact source and outcomes

[Run 39693320883](https://github.com/oskuhsiu/CalcuLater/actions/runs/39693320883)
tested `9fc16d69b182c952f2462be6debeec59476b9b22` with Xcode 16.4,
iOS 18.5, owned Simulators and the unchanged 900-second test-command bound.
It is not an acceptance result for the subsequently improved teaching source.

| Scenario | Native result | Test-command seconds |
| --- | --- | ---: |
| compact | 8 Passed, exact structured execution proof | 493.10 |
| tablet | 8 Passed, exact structured execution proof | 480.46 |
| standard | 259 Passed, 1 Failed, no skips | 862.53 |
| maximum accessibility text | 7 Passed, 1 Failed, no skips | 668.77 |

All four build, boot and actual Dynamic Type configuration stages succeeded.
The maximum-text device read back `accessibility-extra-extra-extra-large`;
the other devices read back `large`. Both failed commands finished normally
with XCTest failures, not timeout termination. Their counts are the retained
xcresult summaries, not a successful structured execution proof.

The standard failure was the actual-presentation fixture setting
`UIViewPropertyAnimator.scrubsLinearly` after pausing, which UIKit rejects.
All fifteen standard UI cases passed. The repair sets this property before
pausing and retains presentation-layer assertions rather than replacing them
with model coordinates.

The maximum-text failure was reaching `settings.operation.0` after the settings
selection/persistence checks. The original screenshots and per-gesture hierarchy
show the bounded helper stopping with the switch still below the viewport.
Its virtualized accessory initially exposed a stale frame, while the containing
table row supplied the current offscreen position. A repair must preserve that
row fallback, recompute scroll direction, and retain actual hittability and
the last-operation guard. This failed run does not prove the repair.

## Video found a defect that the endpoint UI cases missed

Chronological review of the original compact recording found that first play
and Back→Next for `2 + 9` transferred one yellow counter at a time from the
correct source slots. The untouched blue remainder stayed fixed. However,
Replay began from the already-committed destination arrangement: waiting
yellow counters were at their destinations while the active counter travelled
back toward the source-side corridor and then returned. `9 + 9` showed the
same Replay baseline error. Temporary counter overlap was visible.

This is a presentation defect, not evidence that the logical quantity was
duplicated or lost. For example, frame 9960 at PTS 385.406667 has seven arrived
yellow counters, one travelling yellow counter, two pink counters and one
blue counter: eleven units. The first backward departure begins at frame 9941,
PTS 385.105. Frame indexes are zero-based chronological decoder indexes from
the original variable-frame-rate video, not an assumed frame rate or a seek.

In 1,918 consecutive decoded frames around first play, Replay and Back→Next,
colour-region measurements confirmed the visible source/destination error.
The unchanged blue counter stayed fixed across all 1,616 inspected `2 + 9`
frames; eight original blue counters in `9 + 9` and eight green counters in
`18 − 9` also stayed fixed within the measurement tolerance. Pixel regions
are supporting visual measurements, not proof of UIKit object identity.

The repair reconstructs and commits the source before creating a new keyframe
transaction. Genuine presentation probes now inspect time zero and every
movement-leg midpoint for first play, committed-result Replay and Back→Next
at 288/544/736-point widths. They verify every waiting, arrived and unchanged
counter, its identity, opacity, size and collision clearance. The component
lane uses a real iPad host; oversized fake phone windows and skipped wide
probes are not acceptable substitutes. Native execution and chronological
video still have to establish that the transaction repair works.

## Visibility is part of the teaching contract

An earlier landscape recording showed a running ten-frame scene whose counters
were entirely below the clipped viewport while its Replay control remained
visible. The later compact landscape recording did show the complete counter
action, so these distinct cases must not be conflated.

The new gate requires the complete annotated action, including original
stationary counters and every swept route, to fit the actual window and each
clipping ancestor. An impossible fit remains static with reachable Back/Next
comparison, rather than shrinking counters, hiding quantities or calling a
static endpoint a completed animation. Manual scrolling and ancestor clipping
cancel motion; restored visibility alone never restarts it. Explicit Replay
may minimally reframe a clipped action, but preserves an already-safe offset.
These new contracts remain subject to exact-source native acceptance.

## Original recordings retained losslessly

The run artifacts contain independently hashed original-video parts and
manifests. Reassembly changes no video bytes; no transcoded preview replaces
the originals. Evidence archives include xcresults, screenshots, hierarchy,
environment, configuration, recording lifecycle and stage logs.

| Scenario | Original bytes | Original SHA-256 |
| --- | ---: | --- |
| compact | 118182515 | `9a0e8504229ee474797f3676457a31e3caa03373c969c1e0e59461d61f035fba` |
| standard | 364499621 | `b557d5f08300ab2ba616093039ff4714ddbd514a371315312c632414eb1d12fb` |
| tablet | 197575709 | `a831efa678e0f9c08993e4697115f54b24a340046b09e2003f2737666a707159` |
| maximum text | 215069500 | `693a7f679b544ecb782c2696cc4c2608ad2abcc69e795c83c62f38ebdc495fe8` |

All four downloaded archives/parts were checked against the artifact digests,
safely extracted and reassembled against their manifests. Tablet and maximum-
text recordings are retained, but this report does not claim their complete
motion has been visually audited. Actual-system Reduce Motion teaching and
Settings restoration are a separate new acceptance lane, not established by
this run's static-render unit tests or ordinary-motion videos.

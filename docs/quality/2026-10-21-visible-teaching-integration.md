# Visible teaching integration checkpoint

Status: **source integrated and audited; native build, tests and visual acceptance are not run**.

Base: `9fc16d69b182c952f2462be6debeec59476b9b22`.
Audited application/test source: `22c5161744a65c2b1491b00e03ac839dd14ee51c`.
Branch: `review/visible-teaching-integrated`.

This isolated integration retains the published countable-ten-frame changes and
adds the reviewed focused division, visible vertical exchange, concept discovery
and real-system Reduce Motion source. The active published checkout was not
modified. There was no push, workflow dispatch, main merge, deployment, device
mutation or paid-service use.

## Exact source sequence

All 13 requested source commits cherry-picked without textual conflicts. Their
individual commit boundaries and original hashes are retained in the commit
messages and the companion inventory JSON.

- Focused division, seven commits:
  `5c013ac4cd7712b38c6e343549504b1c6d7220ea`,
  `8758e194223b89c99737fb63c65a0ff7804aeeca`,
  `78ebfeff3fbe2056e26a700f077f5a709913ac40`,
  `038acb93193c46f285b3b69f0b6ef66d5b27792b`,
  `81c4f0e6d9805f73774ff85bfd3569ea2d4ce5f6`,
  `a876e6e9c102028a07079d2ee8ec38dee8938714`,
  `379b095004331f9acea3b31de12023bd3e9ca589`.
- Visible vertical exchange:
  `800ed188eeae97f29f0a2233f63b19ee903a0cf9`,
  `88ed69befdcb32e1dcfd2edb8b683ab77b615a03`.
- Concept discovery:
  `2fcfb9b13b857665e40cd7d5b5e89dafbe256eb9`,
  `b515079b4d1240347f596f404ca919d1df89f1ca`,
  `a30e5c97e7a3bbe1a043b7f63ae0f3aaa685aa70`.
- Real-system Reduce Motion acceptance:
  `de8b1bce0d186c6a77d1aadd2fa045541e1871d1`.

The shared grouping sequence combines the concept wording change with the
focused action implementation. The overlapping legacy UI suites retain their
ten-frame methods, focused grouping adaptations and visible vertical coverage.
No implementation was replaced with a whole-file copy from an older donor.

## Integration decisions

These are separate test/document corrections, not unreviewed changes to the
production teaching models or renderers:

1. `ba7f17c675eab3459ffec64bdede437bd6b0e4a0`: a focused Before comparison under
   real Reduce Motion keeps its actual `reduced-motion` lifecycle while displaying
   `動作前 · 先數一數`. The test requires that caption, exact mode, selected action,
   `看動作後` control, unchanged lesson step, every zero-before count and the common
   pool. Running, cancellation, visibility pause and completion are forbidden.
   Before inspection does not substitute for the separate static after-state
   proof following Replay.
2. `c3237f629563cc38f30df1e70602d1521d75e021`: restore baseline controller-step
   identity, nonempty concrete geometry, choice/notation horizontal bounds and
   teaching-control assertions alongside the new complete-action contract. Replay
   also explicitly retains an already-safe inspection offset when the complete
   causal exchange already fits.
3. `65e0ab267928e826852e29f189632b53dcb1de3f`: normal layout waits require the exact
   `。動態已播放完成` suffix. They no longer accept a static Reduce Motion endpoint.
   The separate Settings scenario owns actual reduced-motion acceptance.
4. `d849d3f34e87d986a306197288251c22ce7428da`: missing focused playback state is a
   failure, not a successful early return from a natural-completion helper. The
   standard suite explicitly identifies its sharing/packing action inspections;
   legitimate static remainder and multiplication inspections remain separate.
   Both helpers require `。播放完成。播放狀態：completed`.
5. `22c5161744a65c2b1491b00e03ac839dd14ee51c`: both legacy layout Replay callers
   selected division actions, so both must show the whole action and prove its
   natural end. Only then do they explicitly return to the full overview and
   assert the original inspection position. A missing mode marker cannot bypass
   the Replay check.

The original grouping numeric waits remain three seconds. Renderer completion
has a separate declared-duration bound: `0.28 + 0.82 * transfers + 0.24`, plus one
second. The vertical natural-end wait remains three seconds. No existing test
timeout was increased and no test selector was removed by these corrections.

## Baseline coverage reconciliation

The companion `2026-10-21-visible-teaching-inventory.json` records all baseline
and integrated selectors, target identities, exact source commits, added methods,
the frozen grouping selector set and the complete Objective-C source inventory.

- Baseline: 245 component methods and 21 UI methods, 266 total.
- Integrated: 302 component methods and 31 UI methods, 333 total.
- Net new: 57 component methods and 10 UI methods, 67 total.
- Unmapped missing baseline selectors: zero.
- Duplicate selectors: zero.
- All 29 frozen focused-grouping selectors are present: 25 component and 4 UI.

Two baseline selector names intentionally changed in the already reviewed
vertical donor, with explicit replacement coverage:

- `testReduceMotionStaticRenderHasSameCountsAndNoTransfers` became
  `testMotionDisabledStaticRenderHasSameCountsAndNoTransfers`. Its synthetic
  motion gate never proved the real system preference. All original static
  numeric/no-transfer checks remain, and the new Settings suite owns system proof.
- `testReplayPreservesTheChosenInspectionOffsetAndStep` became
  `testReplayRecoversTheEntireConcreteExchangeWithoutChangingTheStep`. Its old
  offset deliberately hid the causal action. Preserving that offset during
  Replay conflicts with visible playback, so the replacement requires full
  containment, unchanged snapshot and step, valid geometry and actual playback.
  `testAlreadyVisibleExchangeDoesNotMoveInspectionPosition` separately retains
  and strengthens the valid unchanged-inspection contract, including Replay.

The legacy vertical UI test's obsolete hidden-action offset checks likewise give
way to complete exchange containment before first play, after rotation and after
Replay. The old shallow 40-point board intersection is not a substitute for this
contract. Its numeric checks and question identity remain; return assertions now
cover all four enabled, unselected, unanswered choices and no next-question gate.
The grouping legacy inspection-position assertions remain after explicit return
to the same overview snapshot, rather than suppressing visible Replay.

## Header and source registration audit

- All 283 quoted local imports resolve within the application or owning test
  source directory. No conflict markers remain.
- `GroupingTeachingAction` and `GroupingPredictionFeedback` are implemented in
  `GroupingTeachingSequence.m`; their shared public header is not a missing
  implementation file. The concept model similarly implements its immutable
  example and path classes together.
- Xcode 16 filesystem-synchronized application, component-test and UI-test groups
  include the new files automatically. Their existing source membership and
  exception sets are unchanged.
- No `project.pbxproj`, `scripts/ci` source or workflow file changed. The main
  checkout still points to the exact published base above.

## Checks performed and evidence limits

- `git diff --check` passes across the integration delta and working tree.
- The supplied portable Objective-C macro scan passes: 133 source files, 3,160
  macro invocations, zero unprotected-comma hazards. This is a narrow lexical
  check, not preprocessing, compilation or Objective-C type checking.
- The existing runner's read-only `required_test_inventory` resolves every
  integrated selector and rejects no missing, duplicate or ambiguous source.
  Its unchanged current standard selection is 302 component + 15 UI methods,
  317 total. Each unchanged layout selection now resolves 6 layout + 3 ten-frame
  methods, 9 total, because the reviewed two-zero-borrow method is in that class.
- The new focused grouping, concept discovery and real-system Reduce Motion UI
  classes still need explicit, bounded runner selection by the lead. Merely being
  present in a synchronized target is not evidence that any of them executed.
- Xcode, clang and an iOS Simulator are unavailable in this executor. No native
  build, unit/component/UI test, actual UIKit/text-layout validation, system
  accessibility-setting change, screenshot review or video review occurred here.
  Prior runs on other commits do not validate this source combination.

Next gate: independently review this exact integration, wire explicit native
lanes without overlapping whole-class/method filters, then collect build, exact
selector execution and visual evidence for the final pinned commit. This
checkpoint is not merge or deployment approval.

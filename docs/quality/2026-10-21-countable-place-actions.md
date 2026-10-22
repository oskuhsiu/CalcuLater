# Countable numeric place-value actions

## Scope and integration status

This is an immutable teaching/action adapter, not a renderer or controller. It
adds no UIKit, timer, gesture, score, progress-store, answer-submission, or motion
preference dependency. No rejected renderer was restored.

Base: `9fc16d69b182c952f2462be6debeec59476b9b22`. The only prior work brought into
this branch was the exact reviewed model header and implementation/test/doc
commits `e896b0fc114fe9703f14d4b1309886177a3fb539` and
`c1e05b202ae496bf5ffb3bee1f5661885915dc53`, cherry-picked here as `1e6c2fe` and
`aa07a43`.

The supported mathematical domain is unchanged: bare numeric 0…999 × 1…9 with
product ≤999, and 0…999 ÷ 1…9. Multiplication by zero remains explicitly
unsupported by the original model; division by zero, inconsistent answers,
multi-step bridges, stories, decimals and out-of-bounds inputs do not gain a
fallback through this adapter.

The Xcode project uses `PBXFileSystemSynchronizedRootGroup` for both `Calcu Later`
and `Calcu LaterTests`, attached to their respective native targets. The only
app-folder membership exception is `Info.plist`; no new files are excluded.
Therefore the new `.c`/`.m` production files and `.m` tests are discoverable via
the existing source-membership mechanism, without changing the project file.
Actual Apple Clang compilation, linking, XCTest execution, UIKit layout and
animation acceptance have NOT run in this Linux environment. Discoverable
source membership is not native integration proof.

## Public immutable API

`MultiplicativeTeachingActionPlan` retains the exact original sequence and offers:

- `actions`, a finite ordered array of child-selectable actions.
- `actionsForSourceStepAtIndex:`, preserving source-step identity and ordering.
- `beforeSnapshotForSourceStepAtIndex:` and
  `resultSnapshotForSourceStepAtIndex:`, direct settled endpoint inspection.
- `initialSnapshot` and explicit supported/unsupported/invalid-source status.

Every action retains its exact original `sourceStep` pointer and source index,
its index/count within that step, typed input/output units, already-owned
incoming carry, a full `before` and `after` snapshot, and current-action language.
`isSourceStepComplete` means only "this is the last action in the original step";
it does not mean the child watched, understood, or mastered anything.

Every adjacent `after`/`before` pair is the same immutable Objective-C snapshot
object. Units also retain object identity across transfers. Nested arrays are
copied before publication. There is no mutable playback cursor or partially
committed animation state. Going back, selecting a settled result, cancellation,
rotation or replay cannot change a snapshot.

A snapshot's owned quantities are:

- Multiplication: one accumulator, with three place columns.
- Division: original unprocessed input, one common pool, and the known divisor's
  recipients, each with three place columns.

`carryUnits` is an annotation subset of the accumulator, containing the same
unit objects. It is never a separate owned quantity. Each typed unit has a
plan-scoped stable ID, immutable column/value (100, 10 or 1), origin kind, source
step of creation, and generated-group index where relevant.

## Exact source → action mapping

| Original source step | Adapter actions | Identity/value rule |
| --- | --- | --- |
| Observe, Predict, Verify, Completion | One inspection endpoint | No quantities move or appear. Predict expectedAnswer is never used in action language. |
| MultiplyPlace, original digit >0 | One equal-size generated group per known multiplier group | Each action creates only the original digit's count (1…9) at its original place. Inputs are empty. This is explicit generation, not a conserved transfer. |
| MultiplyPlace, original digit =0 | One zero-group inspection | No fake zero pieces, no repeated empty taps. Already-owned carry remains owned. |
| RegroupUp | One exchange per ten-bundle | Exactly ten smaller input IDs retire and one fresh adjacent-larger ID appears. The input/output ID lists are the complete 10→1 lineage. |
| BringDown | One original-digit transfer, including a truthful zero transfer | At most nine original input IDs move to the common pool without changing place or identity. This is NOT an exchange. |
| Distribute, nonzero quotient digit | One recipient per action | At most nine same-place IDs move from the one common pool to that recipient. Other recipients are untouched. Intermediate unequal counts are explicitly temporary. |
| Distribute, zero quotient digit | One zero-distribution inspection | No fake movement or recipient target, and no early written quotient. |
| RegroupDown | One exchange per remaining larger unit | Exactly one larger input ID retires and ten fresh adjacent-smaller IDs appear in the same common pool. Original next-place input stays unprocessed. |
| WriteDigit | One original write action | Only this action changes written digits, completed-column decisions and visible division work rows. A final multiplication carry annotation is cleared without generating more units. |
| InspectRemainder | One original remainder inspection | Only this action reveals the final common remainder label; zero is retained explicitly. |

Incoming multiplication carry is separately identified throughout all generated
groups. Its IDs are already in the accumulator before the first group and stay
there afterwards. They are excluded from every group's generated outputs. The
final generated group (or sole zero-group action) clears the annotation and marks
the input column processed, matching the original MultiplyPlace endpoint. There
is no extra transfer or addition of those units.

A transfer's input/output lists contain the exact same IDs. An exchange's lists
contain retired and freshly minted IDs with equal weighted value. Generation has
empty inputs and new outputs. This prevents the renderer from treating a hundred,
a ten and a one as interchangeable glyphs or pretending multiplication conserves
an input inventory that never existed.

## Reveal and language rules

Intermediate action snapshots keep the preceding source step's written state.
The last action matches the current source step's canonical written state. In
practice only WriteDigit changes digits/completed columns/work rows and only
InspectRemainder first exposes the remainder, exactly as in the original model.

A completed blank quotient column is a deliberately suppressed leading zero;
it is not the same as an unvisited or input-padding column. Interior zeros and
the zero answer are written explicitly at their original place.

Use action `title`, `instruction`, `resultExplanation`, `spokenBefore` and
`spokenAfter` for partial actions. Do NOT use `sourceStep.explanation` as a partial
action caption: the original text describes the entire step's result and can
prematurely announce a future count or carry. `spokenBefore` for a write or
remainder inspection deliberately does not announce the new written result.

Snapshot speech enumerates current owned counts, carry as an already-included
subset, every recipient's current counts, currently written digits/leading-zero
decisions, and already-revealed long-division rows using their actual place units.
It does not manufacture future rows. The accessible phrase “共同的餘數” appears
only after the canonical remainder inspection; the pool stays a common working
pool before then. Current observable counts are not hidden merely because they
can be counted to infer an answer.

## Navigation tradeoff and future rendering boundary

Splitting a large source step makes its causes inspectable, but all subactions
must NOT become mandatory taps or a mastery gate. The adapter includes direct
full settled result inspection for exactly that original source step. It does
not execute hidden subactions, advance a WriteDigit, claim unseen motion was
watched, or supply a "play every unit at once" action.

Observed across every supported input: at most 48 adapter actions in a lesson
and nine in a source step. Zeros never create repeated empty actions. A group of
up to nine units, a single 10↔1 exchange, and one recipient of up to nine units
are the causal action bounds. They are not proof that any particular screen,
font size, geometry or duration is understandable.

A future renderer/controller must independently establish whole-action
visibility: actual glyph bounds, source, destination, active pool/recipient,
labels and route must fit the real clipped viewport. It must preserve the
10↔1 relationship rather than collapse opaque sprites into the same rectangle.
It owns motion pacing, sequential piece motion if needed, live interruption and
visibility handling, reduced motion, focus, explicit before/after selection, and
user-driven navigation. This adapter intentionally sets no duration or fit
threshold and has no clock callbacks.

## Production C validation boundary

`MultiplicativeTeachingActionCore` is Foundation-free production code called by
the Objective-C wrapper. It is not a second answer generator or teaching
curriculum. It receives the canonical model's source descriptors, original
before/after quantities and bounded input metadata, performs the small identity
operations above, and rejects any mismatched source endpoint.

- Operand bounds are checked before multiplication, modulo, digit extraction or
  allocation based on user values.
- At most 23 canonical source steps; each splits into at most nine actions.
- Fixed capacities: 207 actions and 256 lifetime minted unit IDs. The plan is
  heap allocated. Capacity failure or an invalid descriptor clears exposed
  action/unit counts; partial results are never published.
- Actual exhaustive maxima: 48 actions, 186 minted unit IDs, and 170
  simultaneously owned units. These maxima are evidence from the entire current
  bounded domain, not a renderer's allowed screen density.
- Unit location and immutable place value are distinct. Carry is a boolean
  annotation on owned accumulator IDs. Retired IDs are never reused.
- Source fields unrelated to their step kind, invalid columns, or endpoint
  mismatches fail closed.

## Verification completed locally

Run:

```
python3 scripts/portable/check_multiplicative_actions.py
ASAN_OPTIONS=detect_leaks=0 python3 scripts/portable/check_multiplicative_actions.py --sanitize
```

Both production-C runs passed:

- 2,831 multiplication inputs and 9,000 division inputs.
- 299,404 actions and 598,808 before/after endpoint checks.
- Exact original endpoint mapping and action ordering.
- Typed unit ownership, unique IDs, no retired-ID resurrection, transfer identity,
  explicit exchange lineage and adjacent-place weighted equality.
- Generation alone increases total owned value; division always preserves the
  original dividend across input + common pool + all recipients.
- Incoming carry is already owned, present once, and never regenerated.
- Zero paths and invalid/bounds/descriptor/endpoint rejection.
- `-std=c11 -Wall -Wextra -Werror -pedantic` build, plus AddressSanitizer and
  UndefinedBehaviorSanitizer in the second run.

The runner's ptrace environment prevents LeakSanitizer from operating. An initial
combined run reached LeakSanitizer's fatal environment error; the successful
ASan/UBSan run disabled leak detection explicitly. No leak-check pass is claimed.

Source-only checks: `git diff --check` and a narrow Objective-C macro scan passed
(123 files, 2,297 known macro invocations, zero hazards). These are not Apple
Clang compilation. An independent source review found no blocking canonical-path
arithmetic/identity/reveal defect and identified one spoken-work-row omission;
that omission was fixed and covered by a native test assertion.

## Authored native tests, not executed here

`MultiplicativeTeachingActionTests` has 12 selectors:

1. `testEveryBoundedProblemMapsCanonicalSourceEndpoints`
2. `testNinetyNineTimesNineBuildsNineCountableGroupsBeforeEightSingleExchanges`
3. `testIncomingCarryIsOwnedOnceAndNeverIncludedInGeneratedGroups`
4. `testZeroDigitUsesOneStationaryActionAndKeepsIncomingCarry`
5. `testDivisionUsesOneCommonPoolAndOneRecipientPerAction`
6. `testHundredSplitsOneAtATimeWithoutMovingOriginalTensEarly`
7. `testWriteDigitAndWorkRowsAreNotRevealedByResultInspection`
8. `testLeadingZeroAndInteriorZeroHaveDifferentCompletedWriteStates`
9. `testCommonRemainderIsRevealedOnlyByOriginalInspection`
10. `testZeroProblemsDoNotInventUnitsOrNineEmptyActions`
11. `testInspectionReplayAndCallerMutationCannotChangeSettledSnapshots`
12. `testUnsupportedSourcesAndInvalidIndicesReturnEmptyWithoutFallback`

The first selector sweeps all 11,831 supported inputs through the actual original
Objective-C sequence factory and adapter, checking Foundation mapping, exact
source endpoints, identity continuity and reveal timing. It is distinct from the
portable kernel harness and remains native-unrun. Both the existing
`MultiplicativeTeachingSequenceTests` and these new tests should run before
native integration. No UI test, animation video or perceptual acceptance is
claimed by this model-only deliverable.

# Grouping teaching sequence contract

This is the Foundation model slice, not native UI acceptance. It depends on the explicit `GroupingStoryContext` / `WordProblem` context changes in `aaf66ab`. Existing addition/subtraction teaching is unchanged.

## Entry and eligibility

- Story: `sequenceForWordProblem:` takes the full story, never its lossy arithmetic bridge. Legacy/custom stories without supplied context get `MissingOrUnsupportedMeaning`; template IDs and wording are never classifiers.
- Bare arithmetic: `sequenceForArithmeticProblem:meaning:` requires an explicit meaning, supplies labelled generic counters, and alone may normalize `*`/`/` and calculate the division remainder from operands. It is not a story fallback.
- Default factories include optional ungraded predictions. The `includePredictions:NO` overload omits those steps without changing any mathematical action or reveal state.
- Check `status`/`isSupported` before displaying. Invalid arithmetic/flags/unit roles get `InvalidProblem`; unknown operations/absent meanings get `MissingOrUnsupportedMeaning`; valid quantities outside the drawing cap get `OutsideConcreteBounds`. Every non-supported result has no steps.
- Full story copies preserve wording, all special flags, explicit remainder, context and strategy. Fraction, missing-operand and multi-step metadata are rejected before the concrete route. Operand/result negativity, multiplication overflow, wrong product/quotient/remainder and zero divisor are rejected before numeric loops. Story answer units must match the context and its quantity role.
- Bounds: group count ≤9; group size ≤10; total ≤90; groups plus a nonzero-remainder tray ≤9. Validate final dimensions before creating groups. No truncation, resampling or swapping meanings to fit. `90÷9` fits sharing, not packing; `80÷9` fits packing, not sharing.

## Three distinct actions

- Build: `a` items per group, `b` given groups. Begin with no built groups, no product-valued pool, and `b` unopened groups. Each action creates one group of `a`.
- Share: total `a`, `b` recipients. Begin with `b` empty recipients. Each action gives exactly one item to every recipient and removes `b` from the common pool. All settled groups remain equal.
- Pack: total `a`, fixed size `b`. Begin with no completed groups, never quotient-sized empty frames. Each action removes `b` items from the pool and creates one complete group.
- Every division before/after snapshot satisfies `sum(groups) + pool = total`. A remainder belongs to the common pool, never separately to each recipient or to a completed group. Leftover counts use item units, including people counted in 人 rather than 隊.
- Zero is supported: `0×5` builds five empty given groups; `5×0` and `0×0` build none. `2÷5` sharing has five empty recipients and two unshared items; packing has no complete group and two leftovers. `0÷5` is valid; dividing by zero is not.

## UI consumption

- The selected immutable step is the canonical settled state. All arrays/strings are copied. Reading `problem` returns a fresh defensive arithmetic snapshot; reading `wordProblem` returns a fresh full story copy.
- Render `groupCountsBefore/After` and `poolCountBefore/After` exactly. `activeGroupIndices` identify groups changed by that action. `transferCount` is the TOTAL moved: group size for build/pack, recipient count for share. `unopenedGroupCount` exists only for build and describes the after-state.
- Stable item IDs: build/pack group `j`, slot `k` → `j*s+k`; sharing round `k`, recipient `j` → `k*g+j`. Division pool IDs are the unassigned suffix. No UIKit coordinates are in the model.
- Only `WriteAnswer` starts exposing `visibleAnswer`; `InspectRemainder` starts exposing division `visibleRemainder`, including zero. Snapshot `problem.answer`, sequence `remainder`, and prediction `expectedAnswer` are not display/announcement sources. Countable current objects and their current state may equal a final answer without being prefilled as the answer.
- `spokenExplanation` contains the selected state and prompt, not future steps or the prediction key. `actionTitle` describes that selected transforming step, not the subsequent action. Non-transforming steps have an empty action title and no active groups.
- Back/replay reselect immutable steps; they do not alter a sequence. Prediction checking, navigation index, score, timing and animation remain outside this model. Completion does not submit or advance a practice problem.

## Verification at this slice

- Added 10 focused native XCTest methods with a shared every-snapshot contract: multiplication facts/zero, paired `24÷4`, `23÷4`, `8÷3`, `9÷9`, `2÷5`, `0÷5`, human remainder units, boundaries/overflow, every special story flag, missing context, bare-only alias/remainder behavior, defensive copies, and optional predictions.
- Independent source review found no functional defects. Its transfer-count documentation clarification is incorporated; its finite-domain oracle also confirmed a maximum of 26 steps with predictions.
- Local checks passed: whitespace checks; 27 format-string call sites checked for argument count/type consistency; strict synthetic XCTest-macro preprocessing checked comma nesting. The latter is NOT Objective-C compilation or an Apple SDK check.
- An independent finite-domain integer/identity oracle checked 1,022 supported cases and adjacent rejection boundaries, verifying conservation, unique item identity, zero paths, factor orientation and the ≤32-step design. It validates the algorithm design, NOT execution of these Objective-C files.
- Native Objective-C compilation and XCTest execution remain unrun here because the environment has no Xcode, Apple Foundation/XCTest SDK or Objective-C compiler. Native build, XCTest, board rendering, animation interruption and accessibility evidence must be established in the integration task before acceptance.

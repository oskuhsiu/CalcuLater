# Bounded multiplicative place-value model

Status: **Unpublished model milestone only. Not integrated or natively accepted.**

Base: `c948de49ad800c1711a40b8008e416716f76f309`. This work owns only the new
`MultiplicativeTeachingSequence.h/.m`, its focused XCTest file, and this note.
Existing teaching models, renderers, controllers, story adapters, generators,
project configuration, workflows and the active main acceptance run remain unchanged.

## Scope and validation

The sole factory is explicitly for **bare arithmetic**, never a lossy
`WordProblem.toArithmeticProblem` bridge. It accepts an input quantity 0–999 and
one-digit multiplier/divisor 1–9. Multiplication results must be at most 999;
division uses integer quotient and one common remainder. `*` and `/` normalize at
this factory only. The supplied answer is checked, not used to prefill lesson UI.

- Missing input, negative values, division by zero, inconsistent answers and
  `isMultiStep` are invalid.
- Unknown operations have a separate unsupported-operation status.
- Inputs/results beyond the declared bounds have an outside-bounds status.
- A consistent `×0` problem has an explicit unsupported-zero-multiplier status.
  This milestone makes no claim that another renderer teaches it correctly.
- Input bounds are checked before arithmetic, digit extraction or allocation.
  The largest multiplication performed after these checks is 999×9.
- Invalid/unsupported results have zero columns, no operand digits, no steps and
  `operandStartColumn=NSNotFound`. Even nil input has a safe defensive problem
  snapshot. Status precedence rejects oversized data before validating its arithmetic.

All current D3 multiplication and division problems fall inside the supported
numeric domain. Neither practice routing nor generation is changed here.
Nonzero-remainder fixtures do not add remainder questions to D3.

## Frozen renderer-facing shape

The public header contains operation-specific immutable state and payload types.
Every step has its own before/after mathematical snapshots. Every collection,
including each recipient row and each index set, is copied from construction state.
`problem` returns a new defensive numeric object on each read.

The three fixed array columns are **[hundreds, tens, ones]**. A count is not
necessarily a decimal digit: the active place can contain 89 units. The renderer
must use actual place labels and must not impose the existing additive board's
20-piece cap. Fixed three-place geometry must not expose the answer's digit width.
There is deliberately no `answerStartColumn`.

Common step data includes title, explanation, current-only spoken explanation,
optional prediction, active/exchange columns, explicit written digits, completed
write decisions, visible division work rows and a separately revealed remainder.
Exactly one operation-specific payload is present.

- `visibleAnswerDigits` changes only on `WriteDigit`.
- `writtenDigit` and `writeDisposition` describe the current write decision.
- A blank completed column is a deliberately suppressed leading quotient zero;
  an unvisited blank is not such a decision. A visible zero is a real written digit.
- `expectedAnswer` exists only on `Predict`, for choice checking. Never render or
  speak it as an answer. Prediction result values may equal given operands; tests
  must not use naive digit-substring bans.
- Division work rows appear only with the corresponding `WriteDigit`. Each row's
  partial, distributed and remaining counts use that row's actual place.
- `visibleRemainder` stays nil until `InspectRemainder`, then retains the exact
  value including zero. The current common pool can be inspected before this;
  it must not be presented as a separate remainder for every recipient.
- Models carry no UIKit, timing, animation progress, scoring or child-choice state.

## Multiplication transitions

Start with a zero accumulator. Visit actual input columns from ones upwards.
For original digit `d`, multiplier `b`, and incoming accumulator/carry `c`:

1. `Predict`: ask for `d × b + c` without stating the result.
2. `MultiplyPlace`: generate exactly `d × b` units and consume the carry annotation
   once. The carry units were already owned by the accumulator.
3. `RegroupUp`, when needed: `k=floor((d × b + c)/10)` bundles of ten become `k`
   adjacent larger units. The current column retains `(d × b + c) % 10`.
4. `WriteDigit`: write this column's retained digit.
5. Above the highest input column, write a nonzero final carry directly, without
   multiplying an artificial padded zero column or multiplying the carry again.

`generatedUnitCount` excludes the carry. `incomingCarryUnitCount` is not a second
quantity to add to an already-settled after-state. `exchangeBundleCount` can be
1–8, rather than only one. `writesFinalCarry` explicitly identifies the final step.

Weighted invariant at every state:

`accumulator value = b × sum(already processed original place values)`.

Only `MultiplyPlace` increases that represented value, by exactly the original
place's product. Exchanges and writes conserve it. Final-carry writing consumes
its annotation but does not add an input column to `processedInputColumns`.

## Division transitions

The original dividend begins in `unprocessedInputCounts`; the working common pool
and the known divisor-count recipient rows begin empty. Each recipient row has
three place counts. No quotient-sized future groups are preallocated.

For each input place, highest to lowest:

1. `BringDown`: move the original units of this SAME place into the common pool.
   Any units from a preceding exchange are already there and are not added twice.
2. `Predict`: ask how many whole current-place units each recipient can receive.
3. `Distribute`: each of `b` recipients gets `q=floor(pool/b)` units. The pool loses
   `b×q`, not merely `q`. A zero distribution moves no physical pieces.
4. `WriteDigit`: write the quotient digit and record the partial subtraction row.
   Leading zeros remain blank; once the quotient starts, all subsequent zeros are
   written. A zero quotient still has one written zero in the ones column.
5. `RegroupDown`, if a higher-place remainder is positive: convert `r` larger units
   to `10r` adjacent smaller units. Leave the next original digit unprocessed.
   The next `BringDown` is a separate action.

Final inspection exposes the one common remainder and explains why another equal
whole-unit distribution is impossible. Verification reconstructs `q×b+r=a`.
No fractional pieces, decimal continuation, packing-story substitution or unit
conversion is part of this model.

Weighted invariant on every before and after snapshot:

`unprocessed + common pool + sum(all recipient quantities) = original dividend`.

Every recipient remains equal after each settled step. Local quotient digits are
0–9; partial quantities are at most 89; a retained local remainder is less than
the divisor. Original units and already regrouped units are never conflated.

## Exact fixture anchors

- `126×4`: accumulator `[0,0,24]` → `[0,2,4]`; then `[0,10,4]` → `[1,0,4]`;
  then `[5,0,4]`. Written progression `__4`, `_04`, `504`. The incoming two tens
  are added to eight new tens, not multiplied.
- `104×3`: the zero tens digit generates zero new tens and consumes one incoming
  ten, preserving `[0,1,2]` before the hundreds calculation. Result 312.
- `99×9`: the tens calculation reaches `[0,89,1]`; exchange eight hundreds and
  write the final carry directly. There are only two multiplied input columns.
- `108÷4`: suppress the hundreds quotient zero; exchange `[1,0,0]` pool into
  `[0,10,0]`; later exchange two remaining tens into `[0,0,20]` while the original
  eight ones stay unprocessed. A separate bring-down makes `[0,0,28]`. Result 27.
- `408÷4`: quotient writes `1__`, `10_`, `102`. The tens distribution transfers
  zero units and leaves all quantity snapshots unchanged.
- `109÷4`: the final pool goes from 29 ones to one common one while each recipient
  receives seven ones. Quotient 27; inspect remainder 1; verify `27×4+1=109`.
- `899÷9`: both tens and ones partial quantities reach 89. Final remainder is 8.
- Zero dividend/input, divisor/multiplier one, and upper bounds retain the same
  three-place contract without invented motion or empty zero answers.

## Tests and current evidence

Nine focused XCTest methods are authored. One bounded sweep checks all 9,000
numeric division inputs and all 2,831 supported multiplication inputs, and checks
out-of-bound products. It reports one contract diagnostic per input and uses an
inner autorelease pool. It is not a generated collection of thousands of tests.

Assertions cover before/after continuity, exact per-place transfer deltas,
conservation, carry ownership, equal recipients, every actual zero-column write,
write order, delayed reveal, preserved prior work rows, exactly one final division
remainder inspection, final verification, invalid input and defensive/deep copies.
Named fixtures separately document renderer-facing transitions and child copy.

Performed locally:

- Independent mathematical Python oracle: 2,831 multiplication and 9,000 division
  cases passed its arithmetic/conservation checks. Observed maxima: **14 multiply
  steps and 18 divide steps**, both below 24. This mirrors the mathematical plan;
  **it does not execute or compile the Objective-C model**.
- Objective-C macro comma preflight: zero hazards in the three owned source files;
  105 XCTest macro invocations checked at the time of writing.
- Repository native-test source inventory resolves all nine authored methods.
  Inventory is intent, not proof of test execution.
- Source review and `git diff --check` completed.

Not performed:

- Native compilation, XCTest execution, UIKit rendering or accessibility/motion
  acceptance. This Linux workspace has no Xcode/Foundation SDK or Objective-C
  compiler available. No dependency installation or CI dispatch was attempted.
- Any controller/renderer integration, generator/story change, publishing, merging
  or deployment. No inference of a native pass is justified by the source checks.

The project uses Xcode file-system-synchronized app and test groups, so these new
files need no manually edited project source list. Native acceptance must still
prove the compiler and the tests discover and execute them.

## Next integration constraints

A renderer should move actual countable units for every generated, distributed
or exchanged count, keep transformations inspectable at rest, and support the
existing child-controlled Next/Back/Replay/Restart pattern without auto-advancing.
Resize/background/dismiss/reduce-motion interruptions must settle on the selected
snapshot. The board must never compute an answer from the validation problem.

Keep a dedicated multiplicative renderer rather than reinterpreting additive or
small-group contracts. Preserve existing routes; any first integration should
explicitly reject nonnil `WordProblem` input. A future story adapter requires
reviewed full-story meaning and remainder metadata, not an arithmetic fallback.

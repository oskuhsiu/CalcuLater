# Real-system Reduce Motion acceptance decision

Status: **authored, not natively verified**. This is a bounded verification plan,
not a Reduce Motion pass or a report of a Settings change performed here.

## Boundary and hypothesis

The existing source guards and synthetic accessibility/component probes do not
establish that a child using the real system setting receives static teaching.
Normal-motion suites must continue requiring their exact natural-completion
states; they must not accept Reduce Motion or cancellation as `Completed`.

The new, separate `ReducedMotionTeachingUITests` uses the real Settings app and
the public teaching UI. The hypothesis is that enabling the system switch causes
every teaching renderer to retain its selected, conserved static endpoint,
including Replay, without answering the underlying practice question.

Base source: `37256a78374a3bb97c5d908de85d8a3dfa698495`.
Only a new UI test file and this decision record are changed. No existing suite,
production file, project file or CI script is edited here. Before execution the
lead must integrate the countable-ten-frame playback lifecycle and the visible
vertical/focused-grouping implementations; baseline source lacks these contracts.
The ten-frame contract was inspected in `a132881`; vertical and grouping owners
provided their frozen accessibility contracts during this implementation.

Keep the existing frozen fixtures: `carry` is **27 + 15**, `borrow` is
**500 − 128**, `make-ten-nine` is **2 + 9**, `break-ten-nine` is **18 − 9**,
and `sharing` / `packing` are the distinct **23 ÷ 4** stories. The lead explicitly
retained these fixtures rather than adding 47 + 38 / 102 − 38. The existing borrow
fixture still requires two separate exchanges through the zero tens column.

## Dedicated native selection and ownership

Run only this selector in the new `reducedMotion` scenario:

```
Calcu LaterUITests/ReducedMotionTeachingUITests/testSystemReduceMotionPreservesStaticTeachingAndUnansweredQuestions
```

The lead owns adding that scenario to the existing reviewed runner. It must use
its own iPhone 16, iOS 18.5, Xcode 16.4, verified system content size `large`, and
the existing nonparallel test invocation / 900-second command bound. This work
does not change those bounds, install anything, dispatch a run, or publish code.

Before launching Settings, the test requires all of:

- `TARGET_OS_SIMULATOR` is true.
- The actual test-runner `SIMULATOR_DEVICE_NAME` matches
  `CalcuLater-quality-[0-9]+-[0-9]+-reducedMotion`, the existing CI creation scheme.
- The actual `SIMULATOR_UDID` parses as a UUID.
- The running device reports iOS `18.5`.

Only these nonsecret ownership/version fields are attached, not the complete
process environment. Their presence in the native UI runner has **not** been
observed on this Linux host. If absent or different, this is a failed precondition
before mutation, never a skip or a fallback to a different device. The scenario's
existing environment/configuration evidence must independently corroborate the
owned UUID, runtime, device type and content size. Running the entire target on an
ordinary developer Simulator intentionally fails this test without opening Settings.

## System-setting proof and cleanup

The test launches `com.apple.Preferences` with app-local English navigation
labels, follows **Settings > Accessibility > Motion > Reduce Motion**, reads an
unambiguous `0`/`1` switch value, and records it before touching the switch. If it
was off, it taps the real switch once and requires exact `1` readback. If already
on, it retains that original state without toggling. English labels and the
corresponding Traditional Chinese labels are explicit alternatives, not substring
searches. Only known Settings, Accessibility or Motion pages are accepted.

This is Apple's documented route:
[Reduce screen motion](https://support.apple.com/en-gb/111781).
The route documentation is not evidence that our iOS 18.5 automation worked.

There is no preference-file edit, `defaults` write, private URL, accessibility
launch flag, swizzle, test-only production accessor or simulated accessibility
setting. Arithmetic fixtures only choose questions; locale arguments only choose
display language. The test does not use a fake system-setting success value.

Settings screenshots, full accessibility hierarchy and raw switch readbacks are
kept before enabling, after enabling, after the teaching flows, before cleanup and
after restoring the original value. Runtime proof in the app is required in
addition to the Settings evidence, not substituted for it.

`tearDown` attempts cleanup even after a test assertion fails. It activates the
same Settings app, resolves only the known route, reads the current switch, taps
once only if that known value differs from the original, and requires the exact
original readback. An ambiguous value or missing route produces a failure and
evidence, never another blind toggle. A killed runner may not reach teardown; the
existing job-owned Simulator disposal remains necessary. Cleanup failure cannot
produce a passing test and is distinct from the original product/route failure.

## Exact acceptance contracts

### Ten frames

- `lessonIntro.progress.value` must equal
  `第 G 次播放，第 S 小步，減少動態，直接顯示這一步` for the exact requested
  generation and selected step. Every Next/Replay requires the previous generation
  plus one. `動態播放完成`, `動態播放中`, cancellation, and a prior generation do not
  satisfy the gate.
- `lessonIntro.stage.value` derives from the displayed dots. Make-ten checks
  `2 + 9` before transfer and `10 + 1` after transfer; break-ten checks `10 + 8`,
  exactly nine crossed objects, then `1 + 8`. Each has before/after screenshots.
- The complete stage must already be contained in `lessonIntro.content`; test
  scrolling or Replay may not repair first-play framing.
- Replay keeps the selected progress label, count snapshot and stage position.
  Back reconstructs the earlier snapshot; the following Next gets its own exact
  reduced-motion generation. The final teaching answer may appear only there.
- Return through `lessonIntro.start` restores the original `lesson.problem`,
  unchanged session progress, all four enabled/hittable answers and no `session.next`.

### Vertical exchange

`verticalTeachingExchange` has a real frame for the complete concrete exchange,
not the entire board. It must be fully contained in `teaching.content` before any
test inspection. Exact values are:

```
個位 12 → 2　・　十位 2 → 3。減少動態，直接看這一步
百位 5 → 4　・　十位 0 → 10。減少動態，直接看這一步
十位 10 → 9　・　個位 0 → 10。減少動態，直接看這一步
```

These preserve the exchanged quantity: 12 ones + 2 tens = 2 ones + 3 tens;
5 hundreds = 4 hundreds + 10 tens; 10 tens = 9 tens + 10 ones. The untouched
operand and the main answer remain separate. `動態已播放完成`, `正在交換` and
`動態已暫停` are explicitly not accepted. Replay retains `teaching.progress`, the
full `verticalTeachingBoard` snapshot and exchange position, and again requires
the reduced-motion value. `答案還沒寫` must remain present at all three exchanges.
Closing returns the unchanged unanswered question and session progress.

### Focused sharing and packing

The visible `groupingTeachingBoard` is the focused renderer during a division
action; its AX frame is the complete required source/target/route/caption region.
Its value must end with exact `播放狀態：reduced-motion`. `播放完成`, `running`,
`cancelled` and `paused-visibility` cannot satisfy this runtime gate. Actual moving
quantities must be absent, and the entire causal region must be on screen.

- Every displayed recipient/bag is checked exactly once, with its expected count.
  There is exactly one common pool in the value, and group counts + pool = 23.
  Exactly one `groupingTeachingBoard` AX match is required; a hidden overview
  duplicated beside the focused renderer cannot be masked by selecting the first.
- Five sharing rounds are visited. A full round is allowed only with its exact
  `第 R 輪 · 每位再拿 1 顆` contract and complete visible frame; a split round must
  expose each `第 R 輪 · 第 N / 4 位` in order with the corresponding partial counts.
  At most 20 recipient actions are inspected. No skip-round shortcut is used.
- Packing visits exactly five bag actions. Each new bag holds four objects and
  reduces the common pool by four; it never uses the sharing interpretation.
- `grouping.compare` explicitly exposes the first action's before-state, which is
  labeled `動作前 · 先數一數` while its actual playback mode remains
  `播放狀態：reduced-motion`. The comparison button says `看動作後`, every
  before-count is checked, and no running, cancelled, paused or completed state is
  accepted. This **does not substitute for reduced-motion after-state proof**.
  Fixed-toolbar Replay restores the same selected static after-state with runtime
  reduced-motion proof. Navigation to this optional comparison is bounded and
  occurs only after untouched first-play containment has passed.
- After the five rounds/bags, the common remainder is exactly three, not a
  remainder per recipient/group. The final explanation preserves **five objects
  per child** versus **five bags**, and never changes the story's meaning.
- Returning leaves the original story, session progress and all answers untouched.

## Helper bounds and failure policy

- App launch/home readiness: at most 10 seconds. Page/control existence: at most
  5 seconds. Exact system or playback value: a predicate wait of at most 3 seconds.
- A navigation helper makes at most eight drags. Each drag is computed from the
  current element/container/window intersection, capped at 32% of that viewport.
  The trace records target before/after frames and actual touch coordinates.
  `0.05`-second touch hold and `0.2`-second endpoint hold are gesture inputs, not
  arbitrary post-action sleeps. An occluded center is a failure, not a swipe loop.
- No Settings retry/relaunch loop, device reset, animation-disabling override,
  blind coordinate click, arbitrary sleep, missing-test pass or skip is permitted.
- A first failed Settings route/readback remains its own native boundary. Inspect
  its retained screen/hierarchy before any selector change or another full run.

## Verification performed here and remaining risk

Performed on Linux:

- The existing `native_quality.required_test_methods` source inventory resolves
  the exact class selector to the one new method.
- Source contract inspection confirms fixture names and text/AX formats against
  the three original owned implementation worktrees. Comparison against the
  reconstructed production commits remains pending their recovery/integration.
- Staged diff whitespace and ownership checks pass: exactly the two new files
  named above, no production, existing-test or CI edits.
- Independent test-only source review is complete. Two nested Objective-C format
  message comma hazards in XCTest macros were fixed by hoisting the strings.
  A lexical audit of all 80 XCTest macro calls finds no remaining such hazard.
  The reviewer also checked single-board AX uniqueness, fail-closed Settings
  foreground/readback, and cleanup diagnostics. These are not compiler results.

Not performed: Apple compiler/linker checks, native Settings navigation, runtime
ownership-variable readback, system-switch propagation, device layout assertions,
test duration measurement, screenshot/video visual acceptance, or restore behavior.
`xcodebuild` is unavailable here. No native success is claimed.

Important native risks are Settings AX layout/localization changes, absent runner
ownership variables, first-launch system screens, focus/overview AX uniqueness,
and a correctly paused but not fully visible causal scene. Any one must fail
clearly. Focused snapshots and AX lifecycle fields do not by themselves prove that
all actual pixels were static; the retained continuous native recording and the
before/after screenshots still need review. Keep the original native evidence and
do not turn a red boundary into a green result by relaxing the exact gates.

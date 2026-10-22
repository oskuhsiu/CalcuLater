# Direct, child-paced concept discovery

Date: 2026-10-21. Implementation base: `c12aa64`. Contrast/completion follow-up base: `5f39e5a`.

## Scope and learner contract

`學一學` retains the exact L1–L5 titles, order, lesson routes and saved-star meaning.
A visible first-header shortcut, `看動畫，不計分`, jumps to five separately named
concept paths. The three lookup-table routes remain in their own final section.
There are no changes to teaching renderers, main-menu layout, question generators,
practice/session lengths, scoring, progress writes, or CI selection.

Every concept path owns an unanswered question page with three stages:

1. 看一個例子: read the question and optionally open its existing guided teaching.
2. 換一題想想: explicitly invite the child to think before choosing guidance.
3. 換數字探索: cycle three deliberately prepared number sets, not random practice.

Back retains the chosen exploration variation. Next never requires answering or
viewing the teaching, never marks mastery, and never awards a star. The last Next
is labelled `回到學一學`, not “passed” or “completed”. A persistent close action
is available throughout. No timer or automatic advancement is introduced.

The teaching sheet's `回到題目` is literal: default sheet dismissal returns to the
same unanswered concept page. It does not close that page, advance its stage, or
change its values. Existing optional, ungraded prediction controls remain inside
the teaching controllers. Reopening guidance starts another inspection of the
same question; Back/Next only change the question when chosen on the path page.

The shared grouping terminal instruction now invites reflection, returning to
the question or replaying, rather than promising unavailable answer choices.
Vertical completion is also neutral about answer choices and no longer implies
that a no-carry example exchanged units. These are completion-copy changes only;
mathematical snapshots, reveal order and return behavior are unchanged.

## Deliberate examples

| Route | First example | Related example | Change-number choices |
|---|---|---|---|
| Carry | 27 + 15 | 36 + 18 | 43 + 16; 43 + 17; 43 + 18 |
| Borrow, including zero | 42 − 16 | 102 − 38 | 112 − 38; 102 − 38; 203 − 57 |
| Equal groups | 3 × 2 | 3 × 3 | 4 × 3; 3 × 4; 2 × 5 |
| Equal sharing | 12 ÷ 3 | 13 ÷ 3 | 17 ÷ 4; 18 ÷ 4; 19 ÷ 4 |
| Groups of | 12 ÷ 3 | 13 ÷ 3 | 17 ÷ 4; 18 ÷ 4; 19 ÷ 4 |

The carry contrast holds 43 and the other operand's tens digit constant. Ones
sums 9, 10 and 11 distinguish no exchange, exactly one ten, and one ten plus an
extra one. The borrowing contrast changes only the first operand's tens digit:
112 first lends a ten to the ones, then borrows for the tens subtraction; 102
must first exchange a hundred into tens before lending a ten to the ones. The
repeated 102 − 38 is intentional comparison, not another random question.
Borrowing's name, summary and second-stage focus explicitly surface the zero in
the tens place. Multiplication means `b` bags of `a` sweets. Every multiplication
and division example includes a full immutable `WordProblem` and producer-owned
`GroupingStoryContext`; no meaning is inferred from an ID or prose. Sharing asks
for sweets per child (`顆`); packing asks for complete bags (`包`). Both ask about
remaining sweets (`顆`), never leftovers per recipient. The same division
operands intentionally produce different questions and pictures. The catalog
contains no scale, average, money or fraction stories.

All 25 examples are within the existing arithmetic/grouping model bounds by
source inspection. Arithmetic getters return fresh value snapshots, including
bridge flags. Stories never fall back to bare arithmetic if unsupported.

## Readability and accessibility

Rows and section headers are measured from their actual Auto Layout content,
not a fixed 100-point height. All titles/details wrap and use capped Dynamic Type;
practice stars have a separate line. Hidden measuring views inherit host traits.
Exact existing lesson title labels remain standalone static texts for the
existing L4/L5 native flows. Headers have heading traits; routes, titles, actions
and screens have stable identifiers and hints. Action targets are at least 60
points, rows at least 88. Narrow/large-text navigation stacks vertically; iPad
content is centered and width-bounded. Colors, rounded controls and the existing
lessons background are retained without new art or dependencies.

Independent source review found and prompted fixes for a convenience factory
that returned the wrong button subclass, a hidden-stack required-height conflict,
detached measurement traits, insufficient semantic assertions, and one-way test
scrolling. No outstanding source-level blocker remained in that review.

## Authored checks and remaining native work

- `ConceptLearningPathTests`: 13 methods covering all 25 fixtures, support and
  reveal order, actual regrouping, multiplication roles, distinct division units,
  full-story handoff, value isolation, discriminating contrasts, universally
  actionable completion and unchanged L1–L5.
- `ConceptLearningNavigationTests`: 4 methods covering skip/Back/variant retention,
  repeated presentation guards, actual related/changed snapshot handoff, unchanged
  raw stars **and completion** keys (including absent keys), all 13 destination
  routes, and 320/375/768/1024-point rows/headers at three text-size categories.
  The trait fixture creates fonts with the inherited traits current and checks
  actual title-font growth, not only a preferred-size-category string.
- `ConceptLearningScreenGeometryTests`: 2 methods exercising all five paths,
  every stage and variation at 320 × 568 with maximum accessibility text. They
  check actual font growth, full-text fitting, bounded/non-overlapping layout,
  individually scroll-reachable controls, persistent Close, and retention of the
  same sharing question through wide relayout and live text-size changes.
- `ConceptDiscoveryUITests`: 4 separate native flows covering all five direct
  routes, current-question return, skipped guidance, retained variations,
  background/return, both adjacent zero-borrow exchanges with Back/Replay, and
  completed sharing/packing states with correct groups, common remainder and
  answer units. Terminal Next returns to the same unanswered question. Gestures
  are bounded and reversible, with retained screenshot/hierarchy checkpoints. This new class is
  not selected by the existing native harness automatically.

Portable checks passed: owned-file/import/delimiter inventory, absence of timer,
generator and progress-store dependencies in the new concept model/controller,
and `git diff --check`. The follow-up also checks changed-file macro arguments
and verifies that both shared sequence deltas contain only text-literal changes.
These are source checks only.

**Not run: Objective-C compilation, XCTest, Simulator, actual layout/gestures,
VoiceOver, Reduce Motion or rendered animation review. Xcode is unavailable in
this Linux environment. This checkpoint is not a native pass.**

A later native iteration should select the three concept component classes and
`Calcu LaterUITests/ConceptDiscoveryUITests`, then run the existing lesson/session
regressions and L4/L5 flows unchanged. Inspect compact phone, iPad, maximum text,
VoiceOver and Reduce Motion; verify no clipping, no Auto Layout warnings, all
three table routes, and that the original five-swipe L4/L5 selection remains
reachable. Record exact build SHA, run and artifact identifiers beside results.

## Integration caution

Apply the reviewed concept commits as deltas. Do not replace the active main
checkout with this worktree's older tree. In particular, the inherited MAX macro
argument issue in GroupingTeachingBoardView is already repaired on main and is
not reintroduced or modified by this follow-up. No CI workflow or scenario
selection is changed here; the lead owns selecting the new UI class after the
currently active native run establishes its evidence.


## Fresh integration review after the native repair increments

The reconstructed concept branch is `review/concept-after-native-repairs`, with
feature deltas `2fcfb9b` and `b515079` on published base `69510a0`. This is not an
old whole-tree replacement. The acceptance-only follow-up is prepared against
countable-motion repair `a9874e9`, vertical full-exchange/lifecycle repair
`88ed69b` (including `800ed18`), and focused grouping checkpoint `81c4f0e`.
Those sibling source trees were read, not copied or modified. Integration must
apply their reviewed deltas before executing the new concept motion assertions.
The lead must record the resulting exact integrated SHA; none exists in this
branch merely because compatible test source has been authored.

### Review findings and changes

The fresh content review found no numerical or question-meaning defect in the
25 deliberate fixtures. It rechecked the 9/10/11 carry boundary, opposite exchange
orders in 112 versus 102, the fixed first-operand group size, immutable complete
stories, and different quotient units for sharing and packing. No production
concept-model/controller change was needed. The original L1–L5 titles, order,
lesson objects, star lookup, and table destinations remain unchanged. Canonical
prediction feedback was not edited; completion copy remains actionable from an
unanswered concept page as well as ordinary practice.

The previous UI acceptance could inspect a thin scroll slice and a settled
numeric snapshot. Neither establishes that the complete causal action was
visible or that playback ended naturally. It also assumed one Next per original
sharing round, which is incompatible with explicit recipient-sized actions.
The follow-up changes **concept tests and this document only**:

- Vertical first-play and Replay require the entire `verticalTeachingExchange`
  AX rectangle inside the scroll/window intersection, including the renderer's
  safety margin. The predicate must observe `動態已播放完成`. Static, paused,
  interrupted, and reduced-motion values cannot pass. Both adjacent zero-borrow
  exchanges retain their exact quantities and original-question assertions;
  rotation must retain full action geometry before Replay can repair anything.
- Focused grouping retains the public `groupingTeachingBoard` identifier. Exactly
  one board may be exposed. The test requires a full visible source/recipient/
  route/caption rectangle and the natural `播放狀態：completed` plus `播放完成`
  lifecycle marker. The hidden overview is not accepted as motion evidence.
- A full sharing round keeps its original assertion. If the renderer selects a
  recipient-sized action, each explicit `下一位` is exercised, checking every
  partial group count, the one common pool, and unchanged `grouping.progress`
  before advancing to the next recipient. Original full-round quantities,
  four-round totals, common remainder, distinct answer units, and original
  question return are still required.
- Static overview inspection is explicitly separate from action evidence. Only
  after natural completion may it scroll through all groups in overlapping
  captures. Replay must return from that inspection to the complete action,
  retaining the exact selected action, numeric values, and original step label.
- The catalog component fixture now makes the inherited traits current during
  synchronous font creation and verifies real font growth. A new destination
  test checks all five original lessons, five concept paths, and three lookup
  tables plus the existing presentation guard. Skipping, leaving, navigating,
  and opening guidance must preserve raw star and completion records.

`ConceptDiscoveryUITests` is an ordinary-motion lane. It must not be reused as a
Reduced Motion pass by accepting either lifecycle string. Real system Settings
Reduced Motion remains an independent native scenario, with its own explicit
static-state expectations. Screenshots and AX markers alone are not a rendered
animation review: retain the exact-source continuous video and inspect first
play, Replay, and interrupted/resized transitions alongside their hierarchies.

### Exact source and selector inventory

Feature production files, relative to published `69510a0`:

1. `Calcu Later/ConceptLearningPath.h`
2. `Calcu Later/ConceptLearningPath.m`
3. `Calcu Later/ConceptLearningPathViewController.h`
4. `Calcu Later/ConceptLearningPathViewController.m`
5. `Calcu Later/LessonsHomeViewController.m`
6. `Calcu Later/ArithmeticTeachingSequence.m` (completion text only)
7. `Calcu Later/GroupingTeachingSequence.m` (completion title/text only)

Component selectors contain **19 methods**, not the previous 18:

- `Calcu LaterTests/ConceptLearningPathTests` (13)
  - `testCatalogHasFiveDistinctPathsWithThreeDeliberateStages`
  - `testCuratedStageOrderIsStableRatherThanRandomPractice`
  - `testEveryExampleUsesItsSupportedTeachingRouteWithoutPrefillingAnswers`
  - `testCarryAndBorrowExamplesActuallyExerciseTheirAdvertisedRegrouping`
  - `testCarryVariationIsolatesOnesTotalsBelowAtAndAboveTen`
  - `testBorrowContrastChangesOnlyTensAndKeepsBothExchangeOrdersInspectable`
  - `testCompletionIsActionableWithoutRequiringAnAnswerChoice`
  - `testMultiplicationKeepsFirstOperandAsGroupSizeAndSecondAsGroupCount`
  - `testSameDivisionOperandsRetainDistinctSharingAndPackingQuestionsAndUnits`
  - `testCurrentQuestionAndEquationNeverContainWorkedAnswers`
  - `testEveryArithmeticReadIsIsolatedFromTheCatalogAndFullStory`
  - `testStoryArithmeticSnapshotsPreserveBridgeMetadata`
  - `testConceptCatalogDoesNotReplaceOrReorderExistingL1ThroughL5Lessons`
- `Calcu LaterTests/ConceptLearningNavigationTests` (4)
  - `testStageNavigationCanSkipGuidanceAndKeepsExplorationNumbersAfterBack`
  - `testGuidanceUsesCurrentSnapshotAndCannotAdvanceTheQuestion`
  - `testDiscoverySelectionPreservesLessonAndTableDestinationsAndPresentationGuard`
  - `testLessonsKeepThreeSectionsAllRoutesAndMeasuredRows`
- `Calcu LaterTests/ConceptLearningScreenGeometryTests` (2)
  - `testEveryPathAndAllThreeStagesFit320PointsAtMaximumAccessibilityText`
  - `testSelectedSharingQuestionSurvivesWideRelayoutAndLiveTextSizeChanges`

UI selectors contain **4 methods** and cover all five paths:

- `Calcu LaterUITests/ConceptDiscoveryUITests/testCarryDiscoveryKeepsQuestionsAcrossTeachingBackAndChangedNumbers`
- `Calcu LaterUITests/ConceptDiscoveryUITests/testBorrowingDirectlyExposesZeroRegrouping`
- `Calcu LaterUITests/ConceptDiscoveryUITests/testEqualGroupsDiscoveryDoesNotRequireOpeningTheMultiplicationTable`
- `Calcu LaterUITests/ConceptDiscoveryUITests/testSharingAndPackingKeepDifferentQuestionsForTheSameNumbers`

No source selector is silently removed or counted as a native result. The three
component files and one UI file above contain 23 methods in total. The full unit
target will include the component classes after real integration; the separate
UI class still needs an explicit lead-owned harness selection. Existing lesson,
practice-session, original L4/L5 five-swipe navigation, original feedback, and
lookup-table regressions remain required and unmodified.

### Proposed next native budget, not measured performance

Do not append these unmeasured UI flows to an already near-budget legacy lane.
A conservative first selection is two bounded lanes, retaining the existing
900-second per-test-command ceiling rather than increasing CI timeouts:

1. The three component classes plus carry, borrow, and equal-groups UI methods.
   Reserve approximately 4–7 minutes of test execution after the build.
2. The sharing/packing UI method alone. Reserve approximately 3–6 minutes after
   the build because every recipient, all-group inspection, and both terminal
   routes are intentional evidence rather than disposable overhead.

These 7–13 minutes are a planning allowance, not an observed duration or a pass
claim; build, simulator startup, recording, and artifact retention are extra.
The lead owns scheduling and any later consolidation after measured results.
The per-action lifecycle wait remains derived from the renderer: grouping is
0.28 seconds lead + 0.82 per transfer + 0.24 tail, with one second scheduling
slack; a three-transfer action is bounded at 3.98 seconds and one recipient at
2.34 seconds. Across this division method, declared natural playback is at most
36.64 seconds and total explicit lifecycle timeout allowance at most 56.64
seconds, depending on full versus split sharing. Numeric waits remain their
original three-second bounds and are not substituted for lifecycle evidence.
Vertical exchanges declare 0.88 seconds; each strict completion wait is bounded
at three seconds. UI gestures and overview traversals also retain fixed bounds.

Start with the intended ordinary-motion phone. After fixing any real failure,
run the required compact/iPad/maximum-text checks and independent system
accessibility scenarios on the same exact integrated source. Preserve all
geometry, quantity, unit, return-route, and original-answer assertions when
repairing failures; a source-only result cannot close a native acceptance gap.

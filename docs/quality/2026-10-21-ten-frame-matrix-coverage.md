# Actual-question ten-frame matrix coverage

## Selection change

The compact phone, tablet and maximum-accessibility-text scenarios retain the
entire `Calcu_LaterLayoutUITests` class, including its five existing flows:

- Story bounds and remainder explanation.
- Vertical teaching prediction, replay and landscape bounds.
- Settings persistence and the last-operation guard.
- Sharing prediction, transfer, replay and a common remainder.
- Packing with a skipped prediction, transfer, replay and distinct answer units.

Each of those scenarios additionally selects only these two methods from
`Calcu_LaterUITests`:

- `testMakeTenCurrentNineDotsReplayBackRotateAndFinish`: the actual `2 + 9`
  question, nine incoming dots, the `8 + 1` split, transfer into the ten-frame,
  replay/back, rotation and return to the original unanswered question.
- `testBreakTenCurrentEightOnesSurviveReplayBackgroundAndReturn`: the actual
  `18 − 9` question, crossing out nine from the ten while retaining the original
  eight ones, replay/back, background/resume and return unanswered.

These exact selectors and question assertions were checked against the isolated
ten-frame source at `773b467575ffa6423b88d28e151a37b8d6ebc64f` and the integrated
source at `ff7ab5b`. The worker confirmed the selectors were final. There are
seven selected UI methods per layout variant, not a second whole standard UI
suite. Standard keeps its original component-target and `Calcu_LaterUITests`
class filters; its full UI class already includes both methods, so no duplicate
method filters are added there.

## Fail-closed execution evidence

Before environment preparation and again before testing, the script resolves
every selected target, class or method against checked-out Objective-C source.
This deliberately follows the repository's current convention: a same-named
class in each `.m` test file, with zero-argument `- (void)test…` definitions.
Missing files, unresolved method filters, empty inventories, duplicate methods,
unsupported implementations and overlapping selections stop without fallback.
It is not a general Objective-C/Swift parser or a substitute for XCTest discovery;
changes to that source convention need review.

`test-selection.json` records `requiredPassedTests` and the source-inventory
origin alongside the exact `-only-testing:` arguments. This is intended coverage,
not evidence that any test ran.

After a successful xcodebuild exit, every required `Class/method` must appear in
the retained Xcode 16.4 `Test Case '-[Class method]' passed (` log format.
One passing test from the last selected class no longer certifies the scenario.
Standard additionally retains its component-suite pass requirement.
`test-execution.json` records the required, observed and missing methods, required
and missing suites, scenario, source SHA and owned Simulator UUID. Missing,
skipped, failed or unrecognized method evidence cannot pass this gate.

If xcodebuild fails, is cancelled or times out, its original exit remains
authoritative and the method-validation stage does not run. In that case
`test-execution.json` is not newly produced; inspect `test.log`, `test.json` and
the retained xcresult. Source-selection preflight errors likewise stop before
native execution rather than inventing an execution record.

## Unchanged boundaries

- `TEST_TIMEOUT = 900`; no runtime retry, replay run or new dependency.
- The same owned device, build-once/test-without-building commands and selected
  Xcode 16.4 / iOS 18.5 contract.
- Real system content-size configuration, supported-tool help checks and exact
  readback, including `accessibility-extra-extra-extra-large`.
- Original video capture/finalization, screenshot and hierarchy attachments,
  raw xcresult export, failure exits and owned-device cleanup.
- No workflow, application or XCTest source edits in this change; no publishing,
  deployment or release actions.

## Portable validation and remaining native work

The implementation was independently source-reviewed. Python syntax and diff
whitespace checks passed. Portable mocked checks exercise exact selectors,
source resolution, malformed/empty/overlapping selection failures, scenario
configuration and ownership rejection, every selected method's omission,
skipped/failed/unrecognized log lines, the component-suite requirement, preserved
native failure exits, single invocation and the original 900-second bound.
Apple commands in these checks are mocked, not executed.

The parser was also checked against retained real logs using each log's matching
source SHA and original selection:

- `7d12307ea15fc48b8d263e4bc59e0e2ae419fe20`, standard: 180 required methods,
  all 180 observed passing, with no missing or unexpected methods.
- `84f371d745b769638bd89b03e3bd7b8a3807766e`, tablet: three required methods,
  all three observed passing, with no missing or unexpected methods.

The older tablet log correctly fails today's seven-method inventory: both
grouping flows and both ten-frame methods are absent. Historical green results
do not establish execution of later additions. Standard's inventory is resolved
from source rather than a frozen method count, so new component tests remain
required without manually editing a second list.

The editing host is Linux. Native compilation and execution of the expanded
matrix, rendered compact/tablet/large-text layouts and actual ten-frame motion
remain unverified. A successful future test run or nonempty video alone will not
certify animation quality, readable teaching diagrams or VoiceOver behavior;
review the retained native evidence before making those claims.

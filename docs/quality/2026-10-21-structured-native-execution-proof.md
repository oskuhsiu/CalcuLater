# Exact structured native execution proof

## Observed boundary and evidence origin

This repairs the post-test **execution-evidence gate**, not a failed XCTest or
Simulator. The original native standard run
[39684382675, attempt 1](https://github.com/oskuhsiu/CalcuLater/actions/runs/39684382675)
used source `37256a78374a3bb97c5d908de85d8a3dfa698495`. Its unchanged
`xcodebuild test-without-building` command exited zero in 495.64 seconds. The old
console regex recognized only 247 of 248 selected methods. An NSLog was inserted
inside this passing method's console name:

`LessonIntroViewTests/testCurrentQuestionExplanationUsesTheFullSurfaceWithoutAnAnswerFooter`

The log literally split `Without` from `AnAnswerFooter` with the VoiceServices
catalog message. A better regex or the aggregate count alone would not establish
which exact method, target, device, or attempt passed.

[Read-only inspection run 39687967408](https://github.com/oskuhsiu/CalcuLater/actions/runs/39687967408)
used inspection source `69510a05d5489deb3773c269fab77c20c24af3bd`. It read the
**original pinned, digest-verified xcresult** using Xcode 16.4 build 16F6. It did
not build, create a Simulator, execute tests, retry, or change the original run.

| Evidence | Exact identity |
| --- | --- |
| Original standard artifact | `12386950633`, 430809747 bytes |
| Original artifact SHA-256 | `83d46d1460c412aa566f411f15699d034b3dc73ef3ecef7bbc8351e8847af652` |
| Original inner `Tests.zip` SHA-256 | `52f848d018e7a6f04b36ed4546db747647c08057f4dbba7ac2118db2f09d87ba` |
| Inspection artifact | `12387316908`, 19183 bytes |
| Inspection artifact SHA-256 | `09debe15658732e13b8cf996eda54850a1b3f304a0589f1b94bec3bbd2204c11` |
| Exact inspection `tests.log` SHA-256 | `5881851bcdda02a74a965781c1eaaa96f069762a0791277494a8fb0eaddd500b` |
| Owned Simulator | `9600A568-0FCE-410C-8C41-A2AE91A46836` |
| Device identity | `CalcuLater-quality-39684382675-1-standard`, arm64, iPhone 16, iOS Simulator, iOS 18.5 / 22F77 |
| Configuration | ID `1`, `Test Scheme Action` |

The inspector retained these exact command outputs and exit metadata:

```sh
xcrun xcresulttool help get test-results tests
xcrun xcresulttool get test-results tests --path build/pinned-result/Tests.xcresult
xcrun xcresulttool get test-results summary --path build/pinned-result/Tests.xcresult
```

The original inspector actually supplied the absolute checkout-local path to
that same pinned result bundle. `tests-help.log`, including its schema and node
enums, is the CLI contract reviewed for this change. The observed success tree
is exactly one Test Plan, selected Unit/UI test bundles, class Test Suites, and
leaf Test Cases. Every leaf includes `nodeIdentifier`, `nodeIdentifierURL`, name,
result, duration text, and duration in seconds.

## Discriminating change and unchanged acceptance

After and only after the original xcodebuild command succeeds, the gate retains:

```sh
xcrun xcresulttool help get test-results tests
xcrun xcresulttool get test-results tests --path build/Tests.xcresult
```

These produce `xcresult-tests-help.log/json` and `xcresult-tests.log/json` through
the existing bounded command runner. The parser does not infer execution from
source files, totals, the last suite, or console output. It requires:

1. Exact checked-out selected-source method inventory, with an unambiguous
   expected target for each `Class/method`. Missing/empty filters, overlapping
   selections, duplicate source methods or ambiguous source filenames stop.
2. Exactly one known scheme configuration and exactly the job-owned Simulator's
   full identity, compared with retained `environment.json` and `simulator.json`.
   UUID, name, architecture, model, platform, OS version and OS build must agree.
3. One plan for `Calcu Later`, exactly the selected bundles, and exactly the
   selected class suites, each once and each `Passed`. Unit and UI bundle types
   are not interchangeable.
4. Every selected method exactly once, in its expected bundle/class, with exact
   canonical `test://com.apple.xcode/...` URL, exact `Class/method` identifier,
   exact method name, and `Passed` result. Unexpected selected-tree methods,
   absent methods, duplicate cases, failed/skipped/expected-failure/unknown
   results, and nonpassing ancestors reject the result.
5. Only the reviewed successful shape. Missing/extra JSON fields, duplicate JSON
   object keys, malformed JSON, nonstandard numbers, additional plans/devices/
   configurations, unknown wrappers, and unreviewed repetition or Test Case Run
   trees fail closed. The broader types in Xcode's help are **not** silently
   supported. A new successful tree shape requires explicit evidence review.

`test-execution.json` records required target identities, every observed case,
missing/nonpassing/duplicate/unexpected results, shape diagnostics, tool failures,
and the failed phase. Original console results remain under `consoleComparison`
with `authoritative: false`; even a perfect console cannot turn missing or
invalid structured evidence green. A corrupt console cannot override exact
structured proof either. Raw `test.log` and the original result bundle remain.

The native 900-second test deadline, existing command timeout defaults, owned
process-group interruption and cancellation handling, video behavior, Simulator
ownership, configuration, build, cleanup, workflow, app and native assertions are
unchanged. There is no native rerun, retry, longer timeout, reset, missing-test
inference, or failure masking. A failed/cancelled xcodebuild never reaches the
acceptance gate's read-only probes. Tool failures/cancellation retain their original exception or
exit status, with diagnostic JSON when writable.

## Portable checks and exact archived replay

Run the portable regression suite:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/ci -v
```

28 tests passed. They cover the exact retained two-case tree excerpt (including
the console-corrupted method), generated source selections, missing/failed/
skipped/unknown cases, repeated cases and containers, wrong target/type/URL/name,
all wrong-device fields, extra configurations, unsupported schema/wrappers,
invalid JSON, source ambiguity, command failure/timeouts/cancellation, and the
zero-exit-only control flow. Mocked Xcode calls and generated cases are **portable
parser tests, not native acceptance**. The small fixture was produced only by
removing other suites/cases from the captured `tests.log`; retained fields and
values were not synthesized.

The complete archived `tests.log` was separately checked on 2026-10-21 against
the actual Objective-C source extracted with:

```sh
git archive 37256a78374a3bb97c5d908de85d8a3dfa698495 \
  'Calcu LaterTests' 'Calcu LaterUITests'
```

The original ZIP digest and source SHA in `environment.json`, `test.json` and
`test-selection.json` were verified. Its exact selected method list matched the
new target-aware source inventory. The inspection `tests.log` and help bytes
were verified against the inspection ZIP. The gate received that original full
tree, the exact old source inventory, and the owned device identity reconstructed
from the original retained environment, not from the result being evaluated.

Result: **248 unique selected methods Passed**, specifically **233 component +
15 UI**, with **zero missing, nonpassing, duplicate, unexpected, or schema
errors**. The original console still recognized only **247**, missing exactly the
method above. The original summary's 248 passed / 0 failed / 0 skipped corroborates
but does not decide this result.

AST comparison also confirmed the command runner, process signaling/interruption,
video class/context, inventory diagnostics, build, boot, configure and cleanup
implementations remain identical to base `69510a0`. A new native execution was
not performed for this change. This replay establishes exact historical method
execution on source `37256a7`; it does not retroactively make that workflow green,
claim another source passed natively, or claim live end-to-end integration of the
new gate. A subsequent independently authorized native run must exercise the
new gate on its own exact source before claiming that integration.

## 2026-10-22: Retain failed-run trees as diagnostics, not acceptance

On source `47b2ffa24a5c8641c757c7bd4606e4705b3f21ee`, `test()` still stops at
nonzero xcodebuild and never calls the proof gate. The always-run export step
already retains the raw Build/Tests bundles, attachments, summary and final
device evidence. It now attempts an additional read-only tree inspection
**after those existing exports**, only when neither `xcresult-tests.log` nor
`xcresult-tests.json` exists:

```sh
xcrun xcresulttool help get test-results tests
xcrun xcresulttool get test-results tests --path build/Tests.xcresult
```

The actual bundle argument is the absolute checkout-local path, matching the
other export commands. The existing command runner retains output unchanged in
`xcresult-tests-diagnostic-help.log` and `xcresult-tests-diagnostic.log`, with
separate `.json` command, exit-code, elapsed-time, source-SHA and scenario
metadata. These filenames deliberately differ from the acceptance evidence.
No parser runs, no console fallback occurs, and no `test-execution.json` is
created or changed. A successfully exported diagnostic tree is not a passing
native test. Failed/skipped/missing cases remain exactly as the tool reports
them; malformed, incomplete or unknown output is retained without inference.

Both inspections use the existing 120-second command bound and cleanup policy,
with `check=False`. Nonzero tool exits and timeouts remain in their metadata;
ordinary start/write errors emit warnings without discarding other evidence.
Each inspection is independent, so help failure does not prevent collecting
the tree. Existing proof attempts and existing diagnostic log/metadata pairs,
including partial pairs, are preserved rather than overwritten or retried.
Missing bundles do not trigger inspection.

The diagnostic helper temporarily latches SIGINT/SIGTERM and restores the prior
handlers. An already-captured `KeyboardInterrupt` or `SystemExit` now remains
authoritative if the runner's subsequent log/metadata writes or output printing
fail. The cancellation branch also preserves its captured interruption if
`interrupt_command()` raises a secondary ordinary error; that error remains
available as the exception context. Neither guard changes cleanup internals,
process scope or timeout policy. Ordinary write errors still raise when no
interruption was captured, and timeout cleanup failures are not reclassified as
cancellation. A cleanup error can prevent the interrupted diagnostic's own
log/metadata from being written; prior exported evidence remains, and the
interruption propagates instead of starting the next inspection.
There is no new native invocation, reset, retry, accepted inventory, proof
schema, simulator configuration, toolchain, workflow matrix or deadline change.
The 900-second native command and 35-minute job bounds remain unchanged.

All **72 portable CI tests pass**, including 15 new export regressions for
exact/mixed output, original xcodebuild failure preservation, existing/partial
proof protection, missing bundles, tool failure, timeout, disk errors and
cancellation. AST comparison confirms only `export()` and the two narrow
cancellation-preservation guards in `run()` changed among existing function/class
definitions. Flattening those guards recovers the original runner AST exactly;
all its other statements and the existing cleanup function are unchanged. The diagnostic
helper is the sole new function.
All subprocesses in these regressions are mocked. No macOS/native run or remote
write was performed, so live failed-run tree export remains to be verified on
an independently authorized native run. Partial or absent artifacts still
remain evidence gaps, never inferred passes.

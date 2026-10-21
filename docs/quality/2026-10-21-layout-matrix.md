# Native layout evidence matrix

## Verification decision

The matrix was initially prepared from the teaching checkpoint at
`f014e8c8db494f40b3b58e5aa0ab6ac1cd365286`. A later standard run on `95b3a9c`
failed before build at Simulator inventory, so the separate
[inventory-diagnosis change](2026-10-21-inventory-diagnosis.md) comes first.
Hold this matrix until that earliest boundary is understood and the standard
build/tests have native evidence. This change does not dispatch, cancel or retry
any run. A future matrix run must include the separately implemented
`Calcu_LaterLayoutUITests` class. No result for that new class is claimed here.

The four jobs use standard public-repository `macos-15` runners with Xcode 16.4
build 16F6, Simulator SDK 18.5 and the installed iOS 18.5 runtime. Each job creates
and cleans up only its own UUID. Installed device types were observed in the prior
native inventory; preparation verifies their availability again, without downloads
or toolchain fallback. Failure in one job does not cancel the other scenarios.

| Scenario | Device | System content size | Exact XCTest selection |
| --- | --- | --- | --- |
| `standard` | iPhone 16 | `large` | `Calcu LaterTests` and `Calcu LaterUITests/Calcu_LaterUITests` |
| `compact` | iPhone SE (3rd generation) | `large` | `Calcu LaterUITests/Calcu_LaterLayoutUITests` |
| `tablet` | iPad (10th generation) | `large` | `Calcu LaterUITests/Calcu_LaterLayoutUITests` |
| `maximumAccessibilityText` | iPhone 16 | `accessibility-extra-extra-extra-large` | `Calcu LaterUITests/Calcu_LaterLayoutUITests` |

Build-for-testing remains unchanged. Test-without-building uses the explicit
target/class selection above, without boilerplate launch cases. Every job keeps
the original 720-second build, 60-second boot, 180-second readiness, 900-second
test and 35-minute job bounds. No retries, animation disabling, packages,
signing/capability changes, deployment or paid larger runners are introduced.

## Real Dynamic Type, not a fixture label

After readiness, a separate configuration boundary retains the selected Xcode's
`xcrun simctl help ui`. The script requires that help to advertise `content_size`
and the exact requested size, and successfully queries the owned Simulator
before changing it. Only then does it execute:

```text
xcrun simctl ui <owned-UUID> content_size <requested-size>
xcrun simctl ui <owned-UUID> content_size
```

The second command must return the exact requested value. Missing support,
failed commands, unexpected query output or mismatched readback stop the scenario
before XCTest and retain the failing phase. There is no fallback to app launch
arguments, undocumented preference keys or a code-level text-size override.
Baseline scenarios explicitly select and verify `large` rather than assuming a
fresh Simulator's default. Tests also refuse an unverified configuration or one
recorded for a different UUID/scenario.

Apple identifies
[`accessibilityExtraExtraExtraLarge` as the largest accessibility content size](https://developer.apple.com/documentation/uikit/uicontentsizecategory/accessibilityextraextraextralarge).
Apple also directs developers to the installed
[simctl help for supported command-line options](https://developer.apple.com/videos/play/wwdc2020/10647/).
Those sources do not certify this matrix's CLI behavior: the selected Xcode's
retained help and actual setting readback are the execution-time gate. Linux
syntax checks and mocked tests cannot establish that native support.

## Evidence and limits

Artifact names contain scenario, source SHA and run attempt. Each artifact keeps
the actual host architecture, macOS/runner image, Xcode build, SDK, selected
runtime/device descriptors, UUID, scenario, requested and observed content size,
exact test-selection arguments, per-command exits and original xcresults.
`scenario-configuration.json` distinguishes verified setup from a failed or
unsupported setting. `test-selection.json` records intent, not executed-test
success. After a zero xcodebuild exit, `test-execution.json` records exact passed
method identifiers from the native XCTest log. At least one method in the selected
UI class must have passed; standard also requires its model/component suite pass.
Missing/empty classes or unrecognized log evidence fail the test step without
replacing xcodebuild's original exit. The log format was observed in the retained
Xcode 16.4 baseline, not guessed from another toolchain. Inspect the actual
xcresult and `test-summary.log` for full coverage and skipped/failing cases.

The existing original-frame video, bounded finalization, screenshots and
accessibility hierarchy attachments remain. Video-capture failure stays separate
from XCTest. A green job or nonempty MP4 is not a visual, animation, VoiceOver or
layout pass. Inspect wrapping, viewport bounds, reachable controls, teaching
exchanges and retained actual content-size evidence on every relevant scenario.

The editing host is Linux. Native compilation, the installed Xcode's actual
`simctl ui` contract, Simulator setting readback, the new XCTest class, native
video validity and rendered compact/tablet/accessibility layouts remain unrun
for this matrix until a future authorized native run.

Portable validation passed Python syntax, workflow YAML/matrix assertions, 22
scenario/ownership/configuration/execution-proof checks and the 17 existing
video/process-lifecycle checks adapted only to supply the new scenario preflight.
Apple commands were mocked in the scenario checks; video tests used local stub
processes, not Simulator recordings. Independent source review found and resolved
the empty-class execution gap and separated trigger SHA from workflow-file SHA.

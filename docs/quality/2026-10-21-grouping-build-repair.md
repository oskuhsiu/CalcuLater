# Grouping board build repair

## Failure boundary and retained evidence

[Run 39655970539](https://github.com/oskuhsiu/CalcuLater/actions/runs/39655970539),
attempt 1, tested source `1e5a9164e663594cebb9fb29bc4300d4cc1925d6`.
It is complete, not still running. No scenario reached Simulator boot or app tests.

- Standard job `119416188924`, compact `119416188219` and maximum-text
  `119416187838` passed environment preparation, then failed compilation.
- The first compiler error is `GroupingTeachingBoardView.m:339`: too many
  arguments to `MAX`. The comma in an Objective-C array literal is not protected
  by parentheses from the C preprocessor. This is a source defect, not a boot,
  animation-idle or test-timeout failure.
- Tablet job `119416187600` separately failed earlier: `simctl list --json`
  produced no inventory before its unchanged 120-second limit. It never created
  a device or built the app. This does not test the grouping source.

Downloaded original artifacts were checked against their GitHub SHA-256 digests:

| Scenario | Artifact | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| standard | [12371296647](https://github.com/oskuhsiu/CalcuLater/actions/runs/39655970539/artifacts/12371296647) | 84270 | `23ac75a65bac8c96c21536020c0d0868a5c39d4394996e956e1bfc000b49cad2` |
| compact | [12372545195](https://github.com/oskuhsiu/CalcuLater/actions/runs/39655970539/artifacts/12372545195) | 81417 | `c7de9ac53f1d93f3d4078a34aac74bb8a89544c421d9f58e2dc7fe3080698abd` |
| maximum text | [12371266872](https://github.com/oskuhsiu/CalcuLater/actions/runs/39655970539/artifacts/12371266872) | 80261 | `b2f791ec1b0351e6748e26b2345d31f824d2f2747725d64570fc030c6c1899ce` |
| tablet | [12370878536](https://github.com/oskuhsiu/CalcuLater/actions/runs/39655970539/artifacts/12370878536) | 9011 | `12176bb5a45a7aaa0497d72118ec1abd43f394d340ca5c1a3a4848add700ff85` |

## Narrow correction and next observation

Hypothesis: placing the two-title array and measured height in typed local
variables before `MAX` removes the preprocessor error without changing the
layout calculation. The correction does exactly that. It does not change any
mathematics, animation, teaching controls, acceptance assertions or timing.

Independent source preflight inspected 1,858 `MAX`/`MIN`/assertion-family macro
invocations across 116 Objective-C/header files. It found the original error
when run against the committed source and no remaining occurrence in the fixed
source. `git diff --check` also passes. These are Linux source checks, not a
native compilation pass.

The next planned acceptance run is for this corrected source, not a same-source
retry. Expected first observation: the app and test targets compile beyond the
group-title measurement. Then the unchanged native tap/quantity/layout checks
must actually execute; a later boundary failure is not a teaching pass. Preserve
all failure evidence, and stop to diagnose the new earliest boundary if it fails.

## Environment contract and separate tablet limitation

The completed hosts report Xcode 16.4 (16F6), macOS 15.7.9 (24G830), arm64 image
`20260907.0337.1`, Simulator SDK 18.5 and requested iOS 18.5 runtime. The three
hosts that reached compilation resolved available runtime 22F77 and their
requested device types. The toolchain/runtime/architecture contract matches the
previous native acceptance configuration; no dependency or signing change is
introduced. The public-repository workflow remains read-only, non-deploying,
at most two standard macOS runners, 35 minutes per job and 900 seconds for tests.

The repeated tablet inventory symptom received the previously added bounded,
read-only diagnostics. They resolved `simctl` inside Xcode 16.4, showed 43 GiB
available on the root volume, and retained a truncated process-state tail plus
CoreSimulator log entries about existing dyld caches. Those observations do not
prove a root cause, healthy service readiness, or a tablet-specific app issue.
Three other jobs on the same image completed inventory during this run.

No inventory retry, timeout increase, service reset, broad device deletion or
runtime download is justified. This source-repair verification is not a claim
to repair the tablet host. If that environment boundary recurs, retain its new
diagnostics and investigate the specific readiness boundary before any further
full-matrix attempt. Do not repeatedly dispatch a matrix just to obtain a green
tablet result.

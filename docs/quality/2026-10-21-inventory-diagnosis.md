# Simulator inventory boundary

## Observed failure

[Run 39631246787](https://github.com/oskuhsiu/CalcuLater/actions/runs/39631246787),
attempt 1, source `95b3a9c75aa6f8ce6ca845d6488a6a9070ecc01f`, stopped during
environment preparation. Xcode 16.4 (16F6), Simulator SDK 18.5 and the existing
host image were verified. `xcrun simctl list --json` produced no inventory and
hit its unchanged 120-second bound, exiting 124. No owned device was created;
build, boot, installation and app tests did not run.

The [retained artifact](https://github.com/oskuhsiu/CalcuLater/actions/runs/39631246787/artifacts/12358259884)
has workflow-reported archive SHA-256
`af6c646ccb6b5e5558e14b21c6f85e94442e9b0bbd865cc52b8b0303f6156608`.
The failure does not identify an app defect or establish a Simulator boot defect.
The pending layout matrix must not turn this unclassified host failure into
several identical full-build attempts.

## Discriminating change, not a reset

One later standard-device attempt can collect missing host evidence if inventory
fails again. The inventory command, 120-second limit, toolchain and acceptance
assertions are unchanged. Only its failure path adds:

- `xcrun --find simctl`, bounded to 10 seconds, to identify the resolved tool.
- Read-only process IDs, parent IDs, state, elapsed time and executable names,
  bounded to 10 seconds. Process arguments are deliberately excluded.
- Root-volume free space, bounded to 10 seconds.
- A filtered CoreSimulator unified-log excerpt from the preceding three minutes,
  bounded to 15 seconds, retaining at most the final 16 KiB.

Each diagnostic retains its command, own exit/status, elapsed time and output
truncation. Diagnostics do not write an unbounded temporary capture file:
a nonblocking pipe drains into a bounded 16 KiB tail, so neither live disk
capture nor memory grows with the stream. Timeout or cancellation kills only the
diagnostic's own process group and permits a five-second reap. Diagnostic errors
never replace the original inventory exit. Existing cancellation does not start
this collection; cancellation during collection is propagated after owned-child
cleanup.

The evidence distinguishes tool resolution, host/process state and disk/log
symptoms without claiming a cause in advance. No inventory retry, timeout increase,
runtime download, service reset, all-device shutdown/erase, signing change or
deployment is introduced. A repeated failure requires reviewing this new evidence
before another attempt. This commit itself does not dispatch CI.

Portable validation passed syntax and 12 failure-path checks, including original
exit preservation, command/output bounds, real local-stub timeout and SIGTERM
cleanup, KeyboardInterrupt cleanup, and unchanged existing acceptance functions.
Those checks do not establish native CoreSimulator health or macOS log access.

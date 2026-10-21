# Bounded, lossless native-video retention

## Observed boundary

Run [39657409557](https://github.com/oskuhsiu/CalcuLater/actions/runs/39657409557)
produced a 652,688,912-byte standard artifact, exceeding the connected download
tool's 536,870,912-byte limit. A separate pinned, read-only recovery retained
that exact original ZIP in bounded parts. It did not repeat the native run.
Later run [39680563952](https://github.com/oskuhsiu/CalcuLater/actions/runs/39680563952)
produced a 521,044,274-byte standard artifact, already close to the same limit.
Longer, genuinely completed teaching animations should not require discarding
native evidence or an extra simulator run merely to retrieve it.

This change separates the original MP4 from the other evidence. It does not
change any test selection, assertion, runner, simulator, recording codec,
Xcode/runtime, 900-second test deadline, 35-minute job deadline, or two-runner
concurrency bound. It performs no network request, transcoding or playback.

## Retained artifacts

The existing `native-evidence-SCENARIO-SHA-ATTEMPT` artifact still contains the
environment, readiness/configuration, per-stage logs, unmodified raw xcresult
ZIPs, screenshots/hierarchies, recording metadata and test evidence. Its only
excluded file is `native-flows.mp4`. A new `video-package-manifest.json` records
the original MP4's exact byte count/SHA-256, ordered parts, per-part byte count/
SHA-256 and public repository/run/attempt/source/scenario identity.

The original MP4 is read without modification and copied into up to eight
256-MiB parts. Each part is independently re-read and hash-verified before the
success manifest and `part_count` output are written. Each is uploaded as a
separate `native-video-SCENARIO-SHA-ATTEMPT-part-NNN` artifact, without ZIP
compression, with a duplicate manifest. A part stays safely below the connector
limit including the small ZIP/manifest overhead. The recording remains intact
on the runner throughout packaging and upload.

Only successful video parts have this size guarantee. The nonvideo main
artifact and emergency raw fallback can still exceed the connector limit and
would need a separately verified retrieval path; no universal artifact-size
claim is made.

Missing or empty recordings produce an explicit `recording-unavailable`
manifest, no parts and no playable-video claim. `record-video.json` retains the
original capture uncertainty. Packaging failure or cancellation uses an
`always()` raw-MP4 fallback upload. Failed/cancelled part uploads also trigger
the raw fallback. A packaging or upload failure remains a failed job,
not a green native result. Recordings above the bounded 2-GiB capacity fail
packaging before creating parts, so the raw fallback retains the source rather
than silently truncating it. Cancellation retention is best-effort: force
termination, runner loss or an upload outage can prevent remaining `always()`
steps. No automatic run retry or simulator reset occurs.

GitHub documents [directory-root stripping and exclusion patterns in upload-artifact](https://github.com/actions/upload-artifact),
and [status functions plus numeric string coercion in expressions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions).
The part conditions explicitly include `always()`, so a failing XCTest step
does not prevent evidence uploads. The unchanged XCTest failure still controls
the job outcome. Upload failures remain visible failures; artifact presence
must be checked after the run.

## Exact download and reassembly

1. Identify one source SHA, run, attempt and scenario. Retain the original
   GitHub artifact IDs, sizes and outer-ZIP digests before downloading.
2. Download the matching main artifact and every `native-video-...-part-NNN`
   artifact named by `video-package-manifest.json`. Verify each downloaded
   outer ZIP against its GitHub-provided digest.
3. Extract each part ZIP into a separate directory named exactly `part-000`,
   `part-001`, and so on, beneath a single chosen `parts/` directory. The ZIP
   contains `native-flows.mp4.partNNN` and `manifest.json` at its root: the
   uploaded directory name itself is stripped. Do not flatten different
   parts into one directory or merge manifests from different scenarios.
4. Reassemble offline, using the manifest from the main artifact or part zero:

   ```sh
   python3 scripts/ci/package_native_video.py reassemble \
     --manifest parts/part-000/manifest.json \
     --parts-root parts \
     --output native-flows.mp4
   ```

The reassembler validates format, ordered indices, bounded sizes, fixed safe
filenames, all part hashes and the final original hash. It refuses existing
outputs and linked parts. It writes a temporary candidate, exposes the final
file only after exact verification, and cleans up only a temporary inode that
this invocation actually created. A failed exclusive open cannot delete an
unrelated `.partial` file created by another process.

## Portable evidence, with limits

- Sixteen offline tests pass, including corruption, missing/reordered parts,
  hostile filenames, size/digest mismatch, source mutation, output protection,
  a concurrent `.partial` creation, missing/empty recordings, and simulated
  Actions ZIP-root stripping with named extraction directories.
- The actual source-fd17d709 standard recording was packaged, reassembled and
  compared byte-for-byte on Linux: 405,297,871 bytes, SHA-256
  `b5f58a89381ea12cb8ebd92888c103e89ecb37350904d5856951546062d8c640`.
  It produced parts of 268,435,456 and 136,862,415 bytes. The original recording
  was not altered. This proves this file's lossless offline roundtrip, not
  animation quality or recording startup coverage.
- Python compilation and `git diff --check` pass. Independent review identified
  the temporary-file race and cancelled-packaging fallback gap before adoption;
  both are addressed and the race has a regression test.

GitHub/macOS execution and retrieval of the new artifact layout remain unrun.
The first integrating native run must retain all expected parts, have each
artifact downloaded/hash-verified, reassemble the exact original, and preserve
the independent test and capture statuses. A nonempty MP4 or success manifest
is not visual acceptance: inspect actual decoded native frames before claiming
that a teaching exchange is countable, visible or understandable.

# Preserve oversized native evidence without another native run

## Boundary and pinned source

The failing boundary is artifact transport, not product behavior. The connected
GitHub artifact download rejects an archive larger than **536,870,912 bytes
(512 MiB)**. This change does not diagnose an XCTest assertion or turn an absent
local result into a pass.

The original artifact remains intact on GitHub. Its metadata was rechecked on
2026-10-21; this recovery is restricted to:

| Identity | Exact value |
| --- | --- |
| Repository | `oskuhsiu/CalcuLater` (public), ID `1428526887` |
| Native workflow | `.github/workflows/ios-quality.yml` |
| Source branch | `polish/48h-2026-10-21` |
| Source SHA | `c948de49ad800c1711a40b8008e416716f76f309` |
| Native run / attempt | `39657409557` / `1` |
| Artifact ID | `12374080329` |
| Artifact name | `native-evidence-standard-c948de49ad800c1711a40b8008e416716f76f309-1` |
| Original ZIP size | `652688912` bytes |
| Original ZIP SHA-256 | `a76c6e20aabb5ad20f011fdc9ea4d9df4211e018de3317a09baf1a8ed291c1d5` |
| Original expiry reported by GitHub | `2026-10-28T19:15:29Z` |

[Original native run](https://github.com/oskuhsiu/CalcuLater/actions/runs/39657409557)

## Narrow recovery contract

`.github/workflows/recover-native-evidence.yml` runs on a `polish/**` push that
changes that workflow or `scripts/evidence/**`. There is no dispatch, schedule,
workflow dependency, matrix, or automatic rerun. The job additionally refuses
private repositories, a different repository identity, and run attempts beyond
one. It is one standard `ubuntu-24.04` job with a 15-minute total bound, not a
larger/paid runner. The original source run may still be in progress; the retained
artifact is independently verified and no native run is started or cancelled.

The recovery commit must be published separately from changes matching the iOS
workflow's path filters. Do not bundle app, test, Xcode project, `scripts/ci/**`, or
`ios-quality.yml` changes into the same push. A new branch push can consider the
branch's full changes rather than only the last commit, so publish the reviewed
recovery-only commit on the existing reconciled `polish/**` branch. The recovery
workflow has its own concurrency group and `cancel-in-progress: false`.

The exact recovery commit is fetched from the public repository without
credentials. The existing official `actions/upload-artifact@v4` is the only
external action used. Python's standard library performs the download and byte
handling, with no installed packages. `GITHUB_TOKEN` is exposed only to the
recovery step and has `contents: read` and `actions: read`; the script sends it
only in authenticated GET requests to `https://api.github.com`.

Before downloading, the script verifies repository identity/public visibility,
native workflow, run/attempt, source branch/SHA, artifact name/ID, availability,
size, digest, and artifact ownership. A mismatch stops the job. The API download
must return exactly HTTP 302; authenticated requests never follow redirects.
The signed HTTPS storage URL is read in memory, restricted to GitHub Actions'
documented storage hosts, then downloaded using a new request/opener with no
Authorization header. No further redirect is followed. Tokens, response headers,
and signed storage URLs are not printed or retained. Reads are size-bounded;
storage transfer has an eight-minute deadline and 30-second socket timeout.
There is no automatic network retry.

The downloaded ZIP must match both the exact pinned size and SHA-256 before it
is split. It is not extracted, repacked, recompressed, reduced, or modified. Its
raw bytes are divided deterministically into:

| Chunk | Raw size |
| --- | ---: |
| `original.zip.part000` | 268,435,456 bytes (256 MiB) |
| `original.zip.part001` | 268,435,456 bytes (256 MiB) |
| `original.zip.part002` | 115,818,000 bytes |

The chunk stream's aggregate SHA-256 is checked again. Each part is uploaded
separately with compression level zero, a unique name containing the recovery
run ID, seven-day retention, and `overwrite: false`. Each upload's ZIP envelope
is slightly larger than its raw part, still well below the **512 MiB** connector
limit. Do not confuse the new wrapper artifact's SHA-256 with the raw part's
SHA-256 or the original ZIP's SHA-256.

A fourth small manifest artifact contains ordered part names/sizes/hashes, the
fixed source identity, `SHA256SUMS`, `ORIGINAL_SHA256SUM`, and GitHub source-run /
artifact metadata. Uploads occur only after verified splitting succeeds; a
partial upload sequence is not a completed recovery. No original artifacts are
deleted, replaced, or have retention changed. Only derivative recovery artifacts
are added; there is no deployment, release, credential change, or native execution.

## Recovery and local reassembly

1. Reconcile the current native run and branch head, review this commit, then
   publish only the recovery paths on the existing `polish/**` branch. Merely
   preparing this change locally does not recover the source artifact.
2. Confirm the resulting Ubuntu recovery job passed and record its SHA/run ID.
   Confirm all four artifacts exist, and each wrapper size is below 512 MiB.
3. Download each new wrapper artifact through the connected GitHub downloader
   and verify its returned artifact digest. Extract the wrappers into separate
   directories beneath one local directory, for example `downloaded-recovery/`.
   This extracts only the wrappers, not the original native evidence ZIP.
4. Run the offline reassembler from this reviewed checkout, replacing the
   manifest path with the actual extracted location:

   ```sh
   python3 scripts/evidence/recover_native_evidence.py reassemble \
     --manifest downloaded-recovery/manifest/manifest.json \
     --parts downloaded-recovery \
     --output native-evidence-standard-original.zip
   ```

   The recursive lookup accepts separate wrapper directories but rejects missing,
   duplicate, corrupt, or symlinked part files. The manifest cannot substitute a
   different original artifact, reorder parts, change sizes, or add traversal
   paths. The tool refuses to replace existing output or a pre-existing `.partial`
   file and only publishes the output after matching the original SHA-256 and size.
5. Only after successful final verification inspect the original native evidence
   ZIP. Record observed native test outcomes separately. Recovery success proves
   byte identity, not app correctness or native acceptance.

The manifest is deterministic and contains no recovery timestamp; rerun metadata
belongs to the enclosing GitHub recovery run. The three raw parts and manifest
may be downloaded/reassembled repeatedly without any new CI execution. If the
workflow fails, inspect its failure before any separately reviewed new attempt;
ordinary GitHub reruns are intentionally disabled. Avoid unrelated future edits
to the recovery-trigger paths until this one-source recovery is complete.

## Portable validation

```sh
python3 -m unittest discover -s scripts/evidence -p 'test_*.py' -v
python3 -m py_compile scripts/evidence/recover_native_evidence.py scripts/evidence/test_recover_native_evidence.py
git diff --check
```

Sixteen small offline tests cover fixed production identities/part boundaries,
source metadata and Actions context rejection, API-only authorization, redirect
rejection, unauthenticated storage requests, transfer size/encoding/digest
failures, deterministic lossless splitting/reassembly, malformed manifests,
missing/duplicate/corrupt/symlink parts, no overwrite, final original digest, and
recovery/native path-filter separation. Synthetic fixtures are a few hundred
bytes and do not download source artifacts or run Simulator/build/XCTest.

## Distinct future retention-only change, not included here

Keep the current native workflow, source, tools, scenarios, timeouts, assertions,
runner/device/runtime contract, and `native_quality.py` unchanged in this repair.
After retaining and inspecting the current evidence, separately review native
artifact packaging to prevent this transport boundary recurring:

- First inventory the recovered archive by file and category; do not assume a
  video, result bundle, or build archive individually fits below 512 MiB.
- Retain a small index and key logs/JSON/screenshots as directly readable evidence.
- Preserve full XCTest result bundles, build products, logs, and attachments in
  lossless archives rather than removing evidence to meet the cap.
- Package and split any large archive into raw parts no larger than 256 MiB,
  with source SHA/scenario/run/attempt, ordered part sizes/hashes, and the original
  archive size/hash. Upload every part as its own artifact, never all parts in one
  `upload-artifact` call that recreates the oversized wrapper.
- Measure wrapper overhead and keep each downloadable artifact comfortably below
  512 MiB. Add a portable reassembly/identity test before integrating the packaging
  step. Preserve failure-path evidence even when native test execution fails.
- Treat packaging/export/upload acceptance independently from XCTest success.
  Define and verify any upload fan-out explicitly, without adding native reruns,
  a paid runner, or deleting existing evidence. This proposal does not itself
  authorize or implement a native workflow change.

## Primary references

- [GitHub artifact REST API](https://docs.github.com/en/rest/actions/artifacts):
  artifact metadata/digests, Actions read permission, and short-lived 302 downloads.
- [GitHub Actions token](https://docs.github.com/en/actions/concepts/security/github_token):
  job-scoped ephemeral repository token.
- [Workflow permissions and path filters](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax):
  omitted token permissions are none; branch/path filters both apply, and new
  branch pushes have different diff semantics.
- [GitHub Actions billing](https://docs.github.com/en/actions/concepts/billing-and-usage):
  standard GitHub-hosted runners in public repositories are free.
- [GitHub Actions communication domains](https://docs.github.com/en/actions/reference/runners/self-hosted-runners#accessible-domains-by-function):
  documented artifact storage hosts.
- [Official artifact upload action](https://github.com/actions/upload-artifact/tree/v4):
  immutable artifact names, no-overwrite option, retention and compression settings.

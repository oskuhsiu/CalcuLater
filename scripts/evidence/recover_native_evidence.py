#!/usr/bin/env python3
"""Recover one pinned GitHub artifact without rebuilding or altering its bytes.

Only `recover` uses the network. `reassemble` is offline and never extracts the
original archive. No third-party Python modules are required.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

SOURCE = {
    "repository": "oskuhsiu/CalcuLater",
    "repository_id": 1428526887,
    "run_id": 39657409557,
    "run_attempt": 1,
    "source_sha": "c948de49ad800c1711a40b8008e416716f76f309",
    "source_branch": "polish/48h-2026-10-21",
    "artifact_id": 12374080329,
    "artifact_name": "native-evidence-standard-c948de49ad800c1711a40b8008e416716f76f309-1",
    "size_bytes": 652688912,
    "sha256": "a76c6e20aabb5ad20f011fdc9ea4d9df4211e018de3317a09baf1a8ed291c1d5",
}
API_ROOT = "https://api.github.com"
CHUNK_BYTES = 256 * 1024 * 1024
BUFFER_BYTES = 1024 * 1024
JSON_LIMIT = 2 * 1024 * 1024
DOWNLOAD_SECONDS = 8 * 60
ARCHIVE_NAME = "original.zip"


class RecoveryError(Exception):
    """Safe, non-secret diagnostic for a rejected recovery."""


def require(condition, message):
    if not condition:
        raise RecoveryError(message)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class GitHubReader:
    """Authenticated GETs cannot automatically follow any redirect."""

    def __init__(self, token):
        require(bool(token), "Ephemeral GITHUB_TOKEN is required.")
        self.token = token
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, path):
        require(path.startswith(f"/repos/{SOURCE['repository']}/"), "Unexpected API path.")
        require("?" not in path and "#" not in path and ".." not in path, "Unsafe API path.")
        request = urllib.request.Request(API_ROOT + path, method="GET", headers={
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "CalcuLater-pinned-evidence-recovery",
        })
        try:
            return self.opener.open(request, timeout=30)
        except urllib.error.HTTPError as error:
            # A 302 is expected only for the exact artifact /zip endpoint.
            return error
        except (urllib.error.URLError, TimeoutError, OSError):
            raise RecoveryError("GitHub API request failed; no automatic retry.") from None

    def json(self, path):
        with self.request(path) as response:
            require(response.status == 200, "GitHub metadata request did not return HTTP 200.")
            raw = response.read(JSON_LIMIT + 1)
        require(len(raw) <= JSON_LIMIT, "GitHub metadata exceeds the bounded JSON limit.")
        try:
            data = json.loads(raw)
        except (ValueError, UnicodeError):
            raise RecoveryError("GitHub metadata is not valid JSON.") from None
        require(isinstance(data, dict), "GitHub metadata must be a JSON object.")
        return data

    def download_location(self):
        path = f"/repos/{SOURCE['repository']}/actions/artifacts/{SOURCE['artifact_id']}/zip"
        with self.request(path) as response:
            require(response.status == 302, "Artifact download did not return the expected HTTP 302.")
            location = response.headers.get("Location", "")
        validate_storage_url(location)
        return location


def validate_storage_url(url):
    """Only HTTPS storage hosts documented for GitHub Actions; no further hops."""
    try:
        parsed = urllib.parse.urlsplit(url)
        valid = (parsed.scheme == "https" and parsed.port in (None, 443)
                 and not parsed.username and not parsed.password and not parsed.fragment
                 and bool(parsed.hostname)
                 and (parsed.hostname.endswith(".blob.core.windows.net")
                      or parsed.hostname == "results-receiver.actions.githubusercontent.com"))
    except ValueError:
        valid = False
    require(valid, "Artifact redirect is not an approved HTTPS GitHub Actions storage URL.")


def validate_context(environ):
    require(environ.get("GITHUB_REPOSITORY") == SOURCE["repository"], "Wrong recovery repository.")
    require(environ.get("GITHUB_EVENT_NAME") == "push", "Recovery is push-only.")
    require(environ.get("GITHUB_REF", "").startswith("refs/heads/polish/"), "Wrong recovery branch.")
    require(environ.get("GITHUB_RUN_ATTEMPT") == "1", "Recovery reruns are not enabled.")
    require(environ.get("GITHUB_API_URL") == API_ROOT, "Only the official GitHub API is allowed.")
    event_path = environ.get("GITHUB_EVENT_PATH", "")
    require(bool(event_path), "Missing GitHub push context.")
    with open(event_path, "rb") as handle:
        raw = handle.read(JSON_LIMIT + 1)
    require(len(raw) <= JSON_LIMIT, "GitHub push context exceeds the size limit.")
    try:
        event = json.loads(raw)
    except (ValueError, UnicodeError):
        raise RecoveryError("Invalid GitHub push context.") from None
    validate_repository(event.get("repository", {}))
    require(event.get("deleted") is False, "Branch-deletion events are not recoveries.")


def validate_repository(repository):
    require(isinstance(repository, dict), "Missing repository identity.")
    require(repository.get("id") == SOURCE["repository_id"]
            and repository.get("full_name") == SOURCE["repository"]
            and repository.get("private") is False,
            "Repository identity/public visibility does not match the pinned source.")


def validate_metadata(run, artifact):
    validate_repository(run.get("repository", {}))
    validate_repository(run.get("head_repository", {}))
    require(run.get("id") == SOURCE["run_id"]
            and run.get("run_attempt") == SOURCE["run_attempt"]
            and run.get("head_sha") == SOURCE["source_sha"]
            and run.get("head_branch") == SOURCE["source_branch"]
            and run.get("path") == ".github/workflows/ios-quality.yml",
            "Native source run does not match the pinned workflow/run/attempt/SHA.")
    base = f"{API_ROOT}/repos/{SOURCE['repository']}/actions/artifacts/{SOURCE['artifact_id']}"
    require(artifact.get("id") == SOURCE["artifact_id"]
            and artifact.get("name") == SOURCE["artifact_name"]
            and artifact.get("size_in_bytes") == SOURCE["size_bytes"]
            and artifact.get("digest") == "sha256:" + SOURCE["sha256"]
            and artifact.get("expired") is False
            and artifact.get("url") == base
            and artifact.get("archive_download_url") == base + "/zip",
            "Artifact identity/size/digest/availability does not match the pinned source.")
    owner = artifact.get("workflow_run", {})
    require(owner.get("id") == SOURCE["run_id"]
            and owner.get("repository_id") == SOURCE["repository_id"]
            and owner.get("head_repository_id") == SOURCE["repository_id"]
            and owner.get("head_sha") == SOURCE["source_sha"]
            and owner.get("head_branch") == SOURCE["source_branch"],
            "Artifact belongs to a different repository/run/SHA.")


def digest_file(path):
    digest = hashlib.sha256()
    size = 0
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(BUFFER_BYTES), b""):
            size += len(block)
            digest.update(block)
    return size, digest.hexdigest()


def verify_original(path):
    require(Path(path).stat().st_size == SOURCE["size_bytes"], "Original archive size mismatch.")
    require(digest_file(path) == (SOURCE["size_bytes"], SOURCE["sha256"]),
            "Original archive SHA-256 mismatch.")


def download_original(location, destination):
    validate_storage_url(location)
    # Deliberately new unauthenticated request/opener; never reuse API headers.
    request = urllib.request.Request(location, method="GET", headers={"Accept-Encoding": "identity"})
    opener = urllib.request.build_opener(NoRedirect())
    deadline = time.monotonic() + DOWNLOAD_SECONDS
    digest = hashlib.sha256()
    size = 0
    try:
        with opener.open(request, timeout=30) as response, Path(destination).open("xb") as handle:
            require(response.status == 200, "Storage download did not return HTTP 200.")
            require(response.headers.get("Content-Encoding", "identity") == "identity",
                    "Storage download must preserve original bytes.")
            length = response.headers.get("Content-Length")
            if length is not None:
                require(length == str(SOURCE["size_bytes"]), "Storage Content-Length mismatch.")
            while True:
                require(time.monotonic() <= deadline, "Artifact download exceeded its time limit.")
                block = response.read(min(BUFFER_BYTES, SOURCE["size_bytes"] - size + 1))
                if not block:
                    break
                size += len(block)
                require(size <= SOURCE["size_bytes"], "Artifact download exceeds its pinned size.")
                digest.update(block)
                handle.write(block)
    except (urllib.error.URLError, TimeoutError, OSError):
        # Never print HTTP exceptions: they can contain signed storage URLs.
        raise RecoveryError("Artifact storage download failed; no automatic retry.") from None
    require(size == SOURCE["size_bytes"] and digest.hexdigest() == SOURCE["sha256"],
            "Downloaded archive failed pinned size/SHA-256 verification.")


def chunk_layout():
    return [{"index": index, "name": f"{ARCHIVE_NAME}.part{index:03d}",
             "size_bytes": min(CHUNK_BYTES, SOURCE["size_bytes"] - offset)}
            for index, offset in enumerate(range(0, SOURCE["size_bytes"], CHUNK_BYTES))]


def split_original(archive, output):
    verify_original(archive)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    chunks = []
    with Path(archive).open("rb") as source:
        for part in chunk_layout():
            directory = output / f"part-{part['index']:03d}"
            directory.mkdir()
            destination = directory / part["name"]
            digest = hashlib.sha256()
            remaining = part["size_bytes"]
            with destination.open("xb") as handle:
                while remaining:
                    block = source.read(min(BUFFER_BYTES, remaining))
                    require(bool(block), "Original archive changed while splitting.")
                    handle.write(block)
                    digest.update(block)
                    remaining -= len(block)
            chunks.append({**part, "sha256": digest.hexdigest()})
        require(source.read(1) == b"", "Original archive grew while splitting.")
    # Detect source mutation during splitting before publishing any manifest.
    aggregate = hashlib.sha256()
    for part in chunks:
        with (output / f"part-{part['index']:03d}" / part["name"]).open("rb") as handle:
            for block in iter(lambda: handle.read(BUFFER_BYTES), b""):
                aggregate.update(block)
    require(aggregate.hexdigest() == SOURCE["sha256"], "Split content differs from the original.")
    manifest = {"format_version": 1, "source": SOURCE.copy(), "archive_name": ARCHIVE_NAME,
                "chunk_size_bytes": CHUNK_BYTES, "chunks": chunks}
    metadata = output / "manifest"
    metadata.mkdir()
    (metadata / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    (metadata / "SHA256SUMS").write_text("".join(
        f"{part['sha256']}  {part['name']}\n" for part in chunks))
    (metadata / "ORIGINAL_SHA256SUM").write_text(f"{SOURCE['sha256']}  {ARCHIVE_NAME}\n")
    return manifest


def validate_manifest(manifest):
    require(isinstance(manifest, dict) and manifest.get("format_version") == 1
            and manifest.get("source") == SOURCE and manifest.get("archive_name") == ARCHIVE_NAME
            and manifest.get("chunk_size_bytes") == CHUNK_BYTES,
            "Manifest does not identify the pinned original archive/format.")
    chunks = manifest.get("chunks")
    expected = chunk_layout()
    require(isinstance(chunks, list) and len(chunks) == len(expected), "Wrong chunk count.")
    for part, layout in zip(chunks, expected):
        require(isinstance(part, dict) and all(part.get(key) == value for key, value in layout.items()),
                "Chunk order/name/size is not the deterministic layout.")
        require(isinstance(part.get("sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", part["sha256"]),
                "Invalid chunk SHA-256.")
    return chunks


def reassemble(manifest_path, parts, output):
    manifest_path, parts, output = Path(manifest_path), Path(parts), Path(output)
    require(manifest_path.stat().st_size <= JSON_LIMIT, "Manifest exceeds the size limit.")
    chunks = validate_manifest(json.loads(manifest_path.read_text()))
    require(not output.exists(), "Refusing to replace an existing output archive.")
    inputs = []
    for part in chunks:
        matches = list(parts.rglob(part["name"]))
        require(len(matches) == 1 and matches[0].is_file() and not matches[0].is_symlink(),
                "A chunk is missing, duplicated, or not a regular file.")
        require(digest_file(matches[0]) == (part["size_bytes"], part["sha256"]),
                "Chunk size/SHA-256 mismatch.")
        inputs.append(matches[0])
    partial = output.with_name(output.name + ".partial")
    # Exclusive temporary output and atomic no-replacement publication.
    with partial.open("xb") as handle:
        try:
            for path in inputs:
                with path.open("rb") as source:
                    for block in iter(lambda: source.read(BUFFER_BYTES), b""):
                        handle.write(block)
            handle.flush()
            os.fsync(handle.fileno())
        except BaseException:
            partial.unlink()
            raise
    try:
        verify_original(partial)
        os.link(partial, output)
    finally:
        partial.unlink()
    return output


def recover(output):
    validate_context(os.environ)
    reader = GitHubReader(os.environ.get("GITHUB_TOKEN", ""))
    root = f"/repos/{SOURCE['repository']}/actions"
    run = reader.json(f"{root}/runs/{SOURCE['run_id']}")
    artifact = reader.json(f"{root}/artifacts/{SOURCE['artifact_id']}")
    validate_metadata(run, artifact)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    archive = output / ARCHIVE_NAME
    download_original(reader.download_location(), archive)
    manifest = split_original(archive, output / "packages")
    # Preserve provenance, never signed storage URLs, API tokens or raw headers.
    (output / "packages/manifest/source-metadata.json").write_text(
        json.dumps({"run": run, "artifact": artifact}, indent=2, sort_keys=True) + "\n")
    print(f"Verified {SOURCE['size_bytes']} original bytes; created {len(manifest['chunks'])} raw chunks.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    recovery = commands.add_parser("recover", help="One pinned GitHub download; Actions context required")
    recovery.add_argument("--output", type=Path, required=True)
    assembly = commands.add_parser("reassemble", help="Offline exact original ZIP reconstruction")
    assembly.add_argument("--manifest", type=Path, required=True)
    assembly.add_argument("--parts", type=Path, required=True)
    assembly.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "recover":
            recover(args.output)
        else:
            result = reassemble(args.manifest, args.parts, args.output)
            print(f"Verified original archive: {result} ({SOURCE['size_bytes']} bytes, SHA-256 {SOURCE['sha256']})")
    except RecoveryError as error:
        # RecoveryError messages are our fixed, non-secret diagnostics only.
        print(f"Recovery rejected: {error}", file=sys.stderr)
        return 1
    except (OSError, ValueError, TypeError, AttributeError):
        # Avoid a traceback or external error detail that might contain a URL/token.
        print("Recovery rejected. No verified output was published; inspect identity, inputs and connectivity.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

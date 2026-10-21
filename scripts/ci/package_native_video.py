#!/usr/bin/env python3
"""Retain the original native recording in bounded, lossless, offline parts.

No decoding, transcoding, network requests, simulator work or test retries.
The original MP4 is never modified. A manifest is not a recording-quality pass.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

CHUNK_BYTES = 256 * 1024 * 1024
MAX_PARTS = 8
BUFFER_BYTES = 1024 * 1024
VIDEO_NAME = "native-flows.mp4"
FORMAT = "CalcuLater-original-native-video-v1"


class PackageError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise PackageError(message)


def provenance(environ):
    # Deliberately allowlist public execution identity, never copy the environment.
    return {key: environ.get(key) for key in (
        "GITHUB_REPOSITORY", "GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT",
        "NATIVE_SCENARIO")}


def write_json_new(path, data):
    with Path(path).open("x", encoding="utf-8") as output:
        json.dump(data, output, indent=2)
        output.write("\n")


def file_identity(path):
    stat = path.stat()
    return stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns


def digest_file(path):
    size, digest = 0, hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(BUFFER_BYTES), b""):
            size += len(block)
            digest.update(block)
    return size, digest.hexdigest()


def package(source, output, manifest_path, environ=None, chunk_bytes=CHUNK_BYTES):
    source, output, manifest_path = Path(source), Path(output), Path(manifest_path)
    require(source.name == VIDEO_NAME, "Unexpected source filename.")
    require(type(chunk_bytes) is int and 0 < chunk_bytes <= CHUNK_BYTES, "Invalid chunk bound.")
    require(not output.exists() and not output.is_symlink(), "Package output already exists; not overwriting.")
    require(not manifest_path.exists() and not manifest_path.is_symlink(), "Manifest already exists; not overwriting.")
    require(not source.is_symlink(), "Source recording must not be a symlink.")
    result = {"format": FORMAT, "source_name": VIDEO_NAME,
              "provenance": provenance(os.environ if environ is None else environ),
              "chunk_bytes": chunk_bytes, "max_parts": MAX_PARTS,
              "source_size_bytes": 0, "source_sha256": None, "parts": [],
              "status": "recording-unavailable", "visualReviewRequired": True,
              "recordingMetadata": "record-video.json", "automaticRetryAllowed": False}
    if not source.exists():
        result["reason"] = "No original recording exists. Inspect record-video.json/log and native stage results."
        write_json_new(manifest_path, result)
        return result
    require(source.is_file(), "Source recording is not a regular file.")
    identity = file_identity(source)
    size = identity[2]
    if size == 0:
        result["reason"] = "Original recording is empty. No playable video is claimed."
        write_json_new(manifest_path, result)
        return result
    require(size <= chunk_bytes * MAX_PARTS, "Recording exceeds the bounded package capacity; retain original fallback.")
    output.mkdir(parents=True, exist_ok=False)
    full_digest = hashlib.sha256()
    count = (size + chunk_bytes - 1) // chunk_bytes
    with source.open("rb") as recording:
        for index in range(count):
            directory = output / f"part-{index:03d}"
            directory.mkdir()
            name = f"{VIDEO_NAME}.part{index:03d}"
            expected = min(chunk_bytes, size - index * chunk_bytes)
            remaining, digest = expected, hashlib.sha256()
            with (directory / name).open("xb") as part:
                while remaining:
                    block = recording.read(min(BUFFER_BYTES, remaining))
                    require(bool(block), "Recording ended before its expected size.")
                    part.write(block)
                    digest.update(block)
                    full_digest.update(block)
                    remaining -= len(block)
            result["parts"].append({"index": index, "name": name,
                                    "size_bytes": expected, "sha256": digest.hexdigest()})
        require(not recording.read(1), "Recording grew during packaging.")
    require(file_identity(source) == identity, "Recording changed during packaging.")
    result.update(status="packaged-original-bytes", source_size_bytes=size,
                  source_sha256=full_digest.hexdigest())
    # Verify disk bytes rather than trusting only the write-side hash.
    for part in result["parts"]:
        path = output / f"part-{part['index']:03d}" / part["name"]
        require(digest_file(path) == (part["size_bytes"], part["sha256"]), "Written part failed verification.")
    for part in result["parts"]:
        write_json_new(output / f"part-{part['index']:03d}" / "manifest.json", result)
    write_json_new(manifest_path, result)
    return result


def validate_manifest(data):
    require(isinstance(data, dict) and data.get("format") == FORMAT, "Unknown manifest format.")
    require(data.get("status") == "packaged-original-bytes", "Manifest has no complete original recording.")
    require(data.get("source_name") == VIDEO_NAME, "Unexpected original filename.")
    require(data.get("max_parts") == MAX_PARTS, "Unexpected package capacity.")
    chunk, size, parts = data.get("chunk_bytes"), data.get("source_size_bytes"), data.get("parts")
    require(type(chunk) is int and 0 < chunk <= CHUNK_BYTES, "Invalid chunk size.")
    require(type(size) is int and 0 < size <= chunk * MAX_PARTS, "Invalid original size.")
    require(isinstance(parts, list) and len(parts) == (size + chunk - 1) // chunk, "Invalid part count.")
    require(isinstance(data.get("source_sha256"), str)
            and re.fullmatch(r"[0-9a-f]{64}", data["source_sha256"]), "Invalid original digest.")
    for index, part in enumerate(parts):
        require(isinstance(part, dict) and type(part.get("index")) is int and part["index"] == index,
                "Parts are missing, reordered or duplicated.")
        require(part.get("name") == f"{VIDEO_NAME}.part{index:03d}", "Unsafe or unexpected part filename.")
        require(type(part.get("size_bytes")) is int
                and part["size_bytes"] == min(chunk, size - index * chunk), "Invalid part size.")
        require(isinstance(part.get("sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", part["sha256"]),
                "Invalid part digest.")


def reassemble(manifest_path, parts_root, output):
    manifest_path, parts_root, output = Path(manifest_path), Path(parts_root), Path(output)
    require(manifest_path.stat().st_size <= 64 * 1024, "Manifest exceeds its size bound.")
    with manifest_path.open(encoding="utf-8") as source:
        data = json.load(source)
    validate_manifest(data)
    require(not output.exists() and not output.is_symlink(), "Output already exists; not overwriting.")
    temporary = output.with_name(output.name + ".partial")
    require(not temporary.exists() and not temporary.is_symlink(), "Partial output already exists; not overwriting.")
    # Preflight all paths and hashes before producing any candidate output.
    paths = []
    for part in data["parts"]:
        directory = parts_root / f"part-{part['index']:03d}"
        path = directory / part["name"]
        require(not directory.is_symlink() and not path.is_symlink() and path.is_file(), "Missing or linked part.")
        require(path.stat().st_size == part["size_bytes"], "Part size mismatch.")
        require(digest_file(path) == (part["size_bytes"], part["sha256"]), "Part size/SHA-256 mismatch.")
        paths.append(path)
    owned_identity = None
    try:
        with temporary.open("xb") as result:
            stat = os.fstat(result.fileno())
            owned_identity = stat.st_dev, stat.st_ino
            for path in paths:
                with path.open("rb") as source:
                    for block in iter(lambda: source.read(BUFFER_BYTES), b""):
                        result.write(block)
        require(digest_file(temporary) == (data["source_size_bytes"], data["source_sha256"]),
                "Reassembled recording failed original size/SHA-256 verification.")
        # link() atomically refuses an output created since the preflight.
        os.link(temporary, output)
    finally:
        # An exclusive open can lose a race. Never delete somebody else's file
        # merely because it now occupies the candidate path we hoped to create.
        if owned_identity is not None and not temporary.is_symlink():
            try:
                stat = temporary.stat()
                if (stat.st_dev, stat.st_ino) == owned_identity:
                    temporary.unlink()
            except FileNotFoundError:
                pass
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("package")
    create.add_argument("--source", type=Path, required=True)
    create.add_argument("--output", type=Path, required=True)
    create.add_argument("--manifest", type=Path, required=True)
    join = commands.add_parser("reassemble")
    join.add_argument("--manifest", type=Path, required=True)
    join.add_argument("--parts-root", type=Path, required=True)
    join.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "package":
        result = package(args.source, args.output, args.manifest)
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
                output.write(f"part_count={len(result['parts'])}\n")
    else:
        result = reassemble(args.manifest, args.parts_root, args.output)
    print(json.dumps({key: result.get(key) for key in ("status", "source_size_bytes", "source_sha256")}))


if __name__ == "__main__":
    try:
        main()
    except (PackageError, OSError, ValueError) as error:
        print(f"Native video packaging failed: {error}", file=sys.stderr)
        raise SystemExit(1)

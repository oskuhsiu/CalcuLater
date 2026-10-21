#!/usr/bin/env python3
"""Read one retained xcresult. No Simulator, build, tests, retry or source mutation."""

import json
import os
from pathlib import Path, PurePosixPath
import platform
import shutil
import stat
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/evidence"))
import recover_native_evidence as recovery

# The historical recovery module is unchanged. Its bounded, authenticated GET
# and unauthenticated storage reader are reused only with this exact new pin.
SOURCE = {
    "repository": "oskuhsiu/CalcuLater", "repository_id": 1428526887,
    "run_id": 39684382675, "run_attempt": 1,
    "source_sha": "37256a78374a3bb97c5d908de85d8a3dfa698495",
    "source_branch": "polish/48h-2026-10-21",
    "artifact_id": 12386950633,
    "artifact_name": "native-evidence-standard-37256a78374a3bb97c5d908de85d8a3dfa698495-1",
    "size_bytes": 430809747,
    "sha256": "83d46d1460c412aa566f411f15699d034b3dc73ef3ecef7bbc8351e8847af652",
}
RESULT_ZIP_SIZE = 16844037
RESULT_ZIP_SHA = "52f848d018e7a6f04b36ed4546db747647c08057f4dbba7ac2118db2f09d87ba"
RESULT_EXPANDED_SIZE = 16852765
RESULT_ENTRIES = 745


def extract_result(archive, destination):
    """Only the pinned inner archive is extracted; never execute its content."""
    recovery.verify_original(archive)
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=False)
    inner = destination / "Tests.zip"
    with zipfile.ZipFile(archive) as outer:
        matches = [entry for entry in outer.infolist() if entry.filename == "Tests.zip"]
        recovery.require(len(matches) == 1 and matches[0].file_size == RESULT_ZIP_SIZE,
                         "Missing, duplicate or changed result archive.")
        with outer.open(matches[0]) as source, inner.open("xb") as output:
            shutil.copyfileobj(source, output, 1024 * 1024)
    recovery.require(recovery.digest_file(inner) == (RESULT_ZIP_SIZE, RESULT_ZIP_SHA),
                     "Inner result archive digest mismatch.")
    with zipfile.ZipFile(inner) as bundle:
        entries = bundle.infolist()
        recovery.require(len(entries) == RESULT_ENTRIES
                         and sum(entry.file_size for entry in entries) == RESULT_EXPANDED_SIZE,
                         "Unexpected result bundle bounds.")
        seen = set()
        for entry in entries:
            path = PurePosixPath(entry.filename)
            mode = entry.external_attr >> 16
            recovery.require(not path.is_absolute() and path.parts
                             and path.parts[0] == "Tests.xcresult"
                             and ".." not in path.parts and "\\" not in entry.filename
                             and entry.filename not in seen
                             and (not stat.S_IFMT(mode) or stat.S_ISREG(mode) or stat.S_ISDIR(mode)),
                             "Unsafe result bundle entry.")
            seen.add(entry.filename)
        bundle.extractall(destination)
    return destination / "Tests.xcresult"


def command(name, arguments, output):
    """Only fixed local Xcode inspection commands; preserve stdout and status."""
    try:
        completed = subprocess.run(arguments, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   text=True, timeout=120, check=False)
        code, stdout, stderr = completed.returncode, completed.stdout, completed.stderr
    except subprocess.TimeoutExpired as error:
        code = 124
        stdout, stderr = error.stdout or "", error.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode(errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode(errors="replace")
        stderr += "\nRead-only inspection timed out after120 seconds; no retry.\n"
    (output / f"{name}.json").write_text(json.dumps({"command": arguments,
        "exitCode": code, "source": SOURCE, "automaticRetryAllowed": False}, indent=2))
    (output / f"{name}.log").write_text(stdout)
    (output / f"{name}.stderr.log").write_text(stderr)
    recovery.require(code == 0, f"Read-only inspection failed at {name}.")
    return stdout


def main():
    recovery.SOURCE = SOURCE.copy()
    recovery.validate_context(os.environ)
    recovery.require(os.environ.get("GITHUB_REF") == "refs/heads/polish/48h-2026-10-21",
                     "Result inspection is restricted to the active improvement branch.")
    recovery.require(platform.system() == "Darwin", "Native Xcode inspection requires macOS.")
    output = ROOT / "build/result-inspection"
    output.mkdir(parents=True, exist_ok=False)
    version = command("xcode-version", ["xcodebuild", "-version"], output).strip()
    recovery.require(version == "Xcode 16.4\nBuild version 16F6", "Pinned Xcode version changed.")
    client = recovery.GitHubReader(os.environ.get("GITHUB_TOKEN", ""))
    run = client.json(f"/repos/{SOURCE['repository']}/actions/runs/{SOURCE['run_id']}")
    artifact = client.json(f"/repos/{SOURCE['repository']}/actions/artifacts/{SOURCE['artifact_id']}")
    recovery.validate_metadata(run, artifact)
    archive = ROOT / "build/pinned-original.zip"
    recovery.download_original(client.download_location(), archive)
    result = extract_result(archive, ROOT / "build/pinned-result")
    (output / "provenance.json").write_text(json.dumps({"source": SOURCE,
        "resultArchiveSize": RESULT_ZIP_SIZE, "resultArchiveSHA256": RESULT_ZIP_SHA,
        "inspectionSourceSHA": os.environ.get("GITHUB_SHA"),
        "buildExecuted": False, "simulatorCreated": False, "testsExecuted": False,
        "automaticRetryAllowed": False}, indent=2))
    command("tests-help", ["xcrun", "xcresulttool", "help", "get", "test-results", "tests"], output)
    command("tests", ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(result)], output)
    command("summary", ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result)], output)
    print("Retained exact structured results from the existing, digest-verified native bundle.")


if __name__ == "__main__":
    try:
        main()
    except recovery.RecoveryError as error:
        raise SystemExit(str(error)) from None

#!/usr/bin/env python3
"""One owned Simulator, separate failure boundaries, no automatic retries.

The source tree is built once, then tested without rebuilding. Logs, the exact
environment, screenshots, UI hierarchy attachments and xcresults are retained.
This script only runs on a Mac with the repository's selected Xcode/runtime.
"""
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
EVIDENCE = BUILD / "evidence"
STATE = BUILD / "simulator.json"
PROJECT = "Calcu Later.xcodeproj"
SCHEME = "Calcu Later"


def run(name, command, timeout=120):
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    print("+", " ".join(str(arg) for arg in command), flush=True)
    code = 0
    output = ""
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        output = result.stdout
        code = result.returncode
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", "replace")
        output += f"\nCOMMAND TIMEOUT after {timeout} seconds\n"
        code = 124
    (EVIDENCE / f"{name}.log").write_text(output)
    (EVIDENCE / f"{name}.json").write_text(json.dumps({
        "command": command, "exitCode": code,
        "elapsedSeconds": round(time.monotonic() - started, 2),
        "sourceSHA": os.environ.get("GITHUB_SHA"),
        "automaticRetryAllowed": False,
    }, indent=2))
    print(output, flush=True)
    if code:
        raise SystemExit(code)
    return output


def state():
    return json.loads(STATE.read_text())


def build_arguments():
    return ["xcodebuild", "-project", PROJECT, "-scheme", SCHEME,
            "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={state()['udid']}",
            "-derivedDataPath", "build/DerivedData", "-parallel-testing-enabled", "NO"]


def prepare():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    fingerprint = {
        "sourceSHA": run("source-sha", ["git", "rev-parse", "HEAD"]).strip(),
        "architecture": platform.machine(),
        "runnerImage": os.environ.get("ImageOS"),
        "runnerImageVersion": os.environ.get("ImageVersion"),
        "developerDirectory": os.environ.get("DEVELOPER_DIR"),
        "xcode": run("xcode-version", ["xcodebuild", "-version"]).strip(),
        "macOS": run("macos-version", ["sw_vers"]).strip(),
        "sdk": run("sdk-version", ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).strip(),
    }
    (EVIDENCE / "environment.json").write_text(json.dumps(fingerprint, indent=2))
    if fingerprint["xcode"] != "Xcode 16.4\nBuild version 16F6" or fingerprint["sdk"] != "18.5":
        raise SystemExit("Environment drift: review the selected Xcode/SDK before running tests.")
    inventory = json.loads(run("simulator-inventory", ["xcrun", "simctl", "list", "--json"]))
    runtime = os.environ["SIM_RUNTIME"]
    device_type = os.environ["SIM_DEVICE_TYPE"]
    if not any(item["identifier"] == runtime and item.get("isAvailable")
               for item in inventory["runtimes"]):
        raise SystemExit(f"Required installed runtime is not available: {runtime}")
    if not any(item["identifier"] == device_type for item in inventory["devicetypes"]):
        raise SystemExit(f"Required device type is not available: {device_type}")
    name = "CalcuLater-quality-" + os.environ.get("GITHUB_RUN_ID", str(os.getpid()))
    udid = run("create-simulator", ["xcrun", "simctl", "create", name, device_type, runtime]).strip()
    STATE.write_text(json.dumps({"udid": udid, "name": name, "runtime": runtime,
                                 "deviceType": device_type}, indent=2))
    shutil.copy2(STATE, EVIDENCE / STATE.name)


def build():
    run("build", build_arguments() + ["-resultBundlePath", "build/Build.xcresult",
                                     "build-for-testing"], timeout=720)


def boot():
    udid = state()["udid"]
    run("boot", ["xcrun", "simctl", "boot", udid], timeout=60)
    run("readiness", ["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=180)


def test():
    run("test", build_arguments() + ["-resultBundlePath", "build/Tests.xcresult",
                                    "-maximum-concurrent-test-simulator-destinations", "1",
                                    "test-without-building"], timeout=900)


def export():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    result = BUILD / "Tests.xcresult"
    if result.exists():
        run("export-attachments", ["xcrun", "xcresulttool", "export", "attachments",
                                  "--path", str(result), "--output-path",
                                  str(EVIDENCE / "attachments")], timeout=120)
        run("test-summary", ["xcrun", "xcresulttool", "get", "test-results", "summary",
                             "--path", str(result)], timeout=120)
    for name in ("Build", "Tests"):
        bundle = BUILD / f"{name}.xcresult"
        if bundle.exists():
            shutil.make_archive(str(EVIDENCE / name), "zip", BUILD, bundle.name)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as output:
            output.write("## Native evidence\n\nSource: " + os.environ.get("GITHUB_SHA", "local")
                         + "\n\nDownload the native-evidence artifact for the environment fingerprint, "
                         "per-stage logs, original xcresults and screenshot/hierarchy attachments. "
                         "A missing test result is not a pass.\n")


def cleanup():
    if STATE.exists():
        udid = state()["udid"]
        # Only this job's created device. Never erase or stop other simulators.
        subprocess.run(["xcrun", "simctl", "shutdown", udid], cwd=ROOT, check=False)
        run("delete-owned-simulator", ["xcrun", "simctl", "delete", udid], timeout=60)


if __name__ == "__main__":
    operations = {"prepare": prepare, "build": build, "boot": boot,
                  "test": test, "export": export, "cleanup": cleanup}
    if len(sys.argv) != 2 or sys.argv[1] not in operations:
        raise SystemExit("Usage: native_quality.py prepare|build|boot|test|export|cleanup")
    operations[sys.argv[1]]()

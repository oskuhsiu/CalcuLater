#!/usr/bin/env python3
"""One owned Simulator, separate failure boundaries, no automatic retries.

The source tree is built once, then tested without rebuilding. Logs, the exact
environment, screen recording, screenshots, UI hierarchy and xcresults are retained.
This script only runs on a Mac with the repository's selected Xcode/runtime.
"""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import platform
import re
import shutil
import selectors
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"
EVIDENCE = BUILD / "evidence"
STATE = BUILD / "simulator.json"
PROJECT = "Calcu Later.xcodeproj"
SCHEME = "Calcu Later"
TEST_TIMEOUT = 900
VIDEO_START_TIMEOUT = 10
VIDEO_STOP_TIMEOUT = 15
VIDEO_KILL_TIMEOUT = 5
TEN_FRAME_TESTS = [
    "Calcu LaterUITests/Calcu_LaterUITests/testMakeTenCurrentNineDotsReplayBackRotateAndFinish",
    "Calcu LaterUITests/Calcu_LaterUITests/testBreakTenCurrentEightOnesSurviveReplayBackgroundAndReturn",
]
LAYOUT_TESTS = ["Calcu LaterUITests/Calcu_LaterLayoutUITests"] + TEN_FRAME_TESTS
SCENARIOS = {
    "standard": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
        "contentSize": "large",
        "onlyTesting": ["Calcu LaterTests", "Calcu LaterUITests/Calcu_LaterUITests"],
    },
    "compact": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation",
        "contentSize": "large",
        "onlyTesting": LAYOUT_TESTS,
    },
    "tablet": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPad-10th-generation",
        "contentSize": "large",
        "onlyTesting": LAYOUT_TESTS,
    },
    "maximumAccessibilityText": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
        "contentSize": "accessibility-extra-extra-extra-large",
        "onlyTesting": LAYOUT_TESTS,
    },
}


def scenario():
    name = os.environ.get("NATIVE_SCENARIO", "standard")
    if name not in SCENARIOS:
        raise SystemExit(f"Unknown native scenario: {name}; no fallback tests will run.")
    return name, SCENARIOS[name]


def required_test_methods(identifiers):
    """Resolve this repository's Objective-C test selection before execution.

    Test classes live in same-named .m files with zero-argument void test methods.
    Reject missing/empty filters or overlapping selections, never fall back to
    another class. Source inventory is intent; passing XCTest lines are proof.
    """
    required = set()
    for identifier in identifiers:
        parts = identifier.split("/")
        if (not 1 <= len(parts) <= 3 or parts[0] not in ("Calcu LaterTests", "Calcu LaterUITests")
                or any(not re.fullmatch(r"[A-Za-z_]\w*", part) for part in parts[1:])):
            raise SystemExit(f"Unsupported test selection: {identifier}")
        directory = ROOT / parts[0]
        paths = (sorted(directory.rglob("*.m")) if len(parts) == 1
                 else [directory / f"{parts[1]}.m"])
        matched = set()
        for path in paths:
            if not path.is_file():
                raise SystemExit(f"Missing selected test source: {path}")
            implementations = re.findall(
                r"^@implementation\s+" + re.escape(path.stem) + r"\s*$(.*?)^@end\b",
                path.read_text(), re.MULTILINE | re.DOTALL)
            if len(implementations) != 1:
                raise SystemExit(f"Unsupported selected test implementation: {path}")
            methods = re.findall(r"^\s*-\s*\(\s*void\s*\)\s*(test\w*)\s*\{",
                                 implementations[0], re.MULTILINE)
            if not methods or len(methods) != len(set(methods)):
                raise SystemExit(f"Missing or duplicate test methods in selected source: {path}")
            matched.update(f"{path.stem}/{method}" for method in methods
                           if len(parts) < 3 or method == parts[2])
        if not matched:
            raise SystemExit(f"Selected test filter resolves to no methods: {identifier}")
        if required & matched:
            raise SystemExit(f"Overlapping selected test methods: {identifier}")
        required.update(matched)
    if not required:
        raise SystemExit("No test methods selected; no fallback tests will run.")
    return sorted(required)


def signal_owned_process(process, signum):
    """Only signal the new session we launched, never other Simulator processes."""
    try:
        os.killpg(process.pid, signum)
    except ProcessLookupError:
        pass  # Exited between poll/timeout and the signal.


def interrupt_command(process):
    # Latch the first interruption. A second cancellation must not orphan the
    # command while it closes its result bundle, or replace the original code.
    previous_handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        for sig in previous_handlers:
            signal.signal(sig, signal.SIG_IGN)
        signal_owned_process(process, signal.SIGINT)
        try:
            return process.communicate(timeout=30)[0]
        except subprocess.TimeoutExpired:
            signal_owned_process(process, signal.SIGKILL)
            try:
                return process.communicate(timeout=5)[0]
            except subprocess.TimeoutExpired as error:
                # A descendant could retain the output pipe even after the
                # owned group was killed. Do not block video finalization.
                output = error.output or b""
                if isinstance(output, bytes):
                    output = output.decode(errors="replace")
                process.stdout.close()
                return output + "\nOwned command did not finish draining after SIGKILL.\n"
    finally:
        for sig, handler in previous_handlers.items():
            signal.signal(sig, handler)


def run(name, command, timeout=120, check=True):
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    print("+", " ".join(str(arg) for arg in command), flush=True)
    code = 0
    output = ""
    interruption = None
    process = subprocess.Popen(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=timeout)
        code = process.returncode
    except subprocess.TimeoutExpired:
        # Keep the original failure bound. This grace is only for xcodebuild to
        # close its result bundle, not extra test time or an automatic retry.
        output = interrupt_command(process)
        output += f"\nCOMMAND TIMEOUT after {timeout} seconds; interrupted owned process group\n"
        code = 124
    except (KeyboardInterrupt, SystemExit) as error:
        # On cancellation, retain the interrupted command's evidence too.
        interruption = error
        output = interrupt_command(process)
        code = error.code if isinstance(error, SystemExit) and isinstance(error.code, int) else 130
        output += "\nCOMMAND CANCELLED; interrupted owned process group\n"
    (EVIDENCE / f"{name}.log").write_text(output)
    (EVIDENCE / f"{name}.json").write_text(json.dumps({
        "command": command, "exitCode": code,
        "elapsedSeconds": round(time.monotonic() - started, 2),
        "sourceSHA": os.environ.get("GITHUB_SHA"),
        "scenario": os.environ.get("NATIVE_SCENARIO", "standard"),
        "automaticRetryAllowed": False,
    }, indent=2))
    print(output, flush=True)
    if interruption is not None:
        raise interruption
    if code and check:
        raise SystemExit(code)
    return output


class NativeVideo:
    """Best-effort motion evidence, separate from XCTest's acceptance result.

    Apple documents recordVideo and Control-C finalization here:
    https://developer.apple.com/videos/play/wwdc2020/10647/
    Record the original frame stream; never alter animations or test timing.
    """

    def __init__(self, udid):
        self.path = EVIDENCE / "native-flows.mp4"
        self.log_path = EVIDENCE / "record-video.log"
        self.process = None
        self.log = None
        self.preserve_existing = False
        self.started = time.monotonic()
        self.result = {
            "command": ["xcrun", "simctl", "io", udid, "recordVideo",
                        "--codec", "h264", str(self.path)],
            "ownedSimulatorUDID": udid,
            "sourceSHA": os.environ.get("GITHUB_SHA"),
            "scenario": os.environ.get("NATIVE_SCENARIO", "standard"),
            "automaticRetryAllowed": False,
            "startupAcknowledged": False,
            "forcedKill": False,
            "status": "unavailable",
        }

    def start(self):
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        # Do not overwrite an earlier attempt or confuse it with new footage.
        if any(path.exists() for path in (self.path, self.log_path, EVIDENCE / "record-video.json")):
            self.preserve_existing = True
            raise FileExistsError("Refusing to overwrite retained video, log or metadata; "
                                  "no new recording will be made.")
        self.log = self.log_path.open("wb")
        print("+", " ".join(self.result["command"]), flush=True)
        self.process = subprocess.Popen(self.result["command"], cwd=ROOT,
                                        stdout=self.log, stderr=subprocess.STDOUT,
                                        start_new_session=True)
        # Observe simctl's acknowledgement instead of a fixed startup sleep.
        # If this tool version changes its text, retain the uncertainty and
        # still run the tests. Merely creating an MP4 is not recording readiness.
        deadline = time.monotonic() + VIDEO_START_TIMEOUT
        while self.process.poll() is None:
            if "Recording started" in self.log_path.read_text(errors="replace"):
                self.result["startupAcknowledged"] = True
                break
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            try:
                self.process.wait(timeout=min(0.1, remaining))
            except subprocess.TimeoutExpired:
                pass
        self.result["testStartOffsetSeconds"] = round(time.monotonic() - self.started, 2)

    def stop(self):
        if self.preserve_existing:
            return  # Preserve the previous attempt's UUID/SHA as well as its video.
        try:
            if self.process is not None:
                self.result["exitedBeforeTestFinished"] = self.process.poll() is not None
                if self.process.poll() is None:
                    # simctl must receive SIGINT to close the MP4 container.
                    signal_owned_process(self.process, signal.SIGINT)
                    try:
                        self.process.wait(timeout=VIDEO_STOP_TIMEOUT)
                    except subprocess.TimeoutExpired:
                        self.result["forcedKill"] = True
                        signal_owned_process(self.process, signal.SIGKILL)
                        self.process.wait(timeout=VIDEO_KILL_TIMEOUT)
                self.result["exitCode"] = self.process.returncode
                self.result["bytes"] = self.path.stat().st_size if self.path.exists() else 0
                if (self.result["exitCode"] == 0 and self.result["bytes"] > 0
                        and not self.result["forcedKill"]
                        and not self.result["exitedBeforeTestFinished"]):
                    self.result["status"] = ("recorded" if self.result["startupAcknowledged"]
                                             else "startup-unverified")
        except Exception as error:
            self.result["error"] = str(error)
        finally:
            if self.log is not None:
                self.log.close()
            self.result["elapsedSeconds"] = round(time.monotonic() - self.started, 2)
            self.result["visualReviewRequired"] = True
            (EVIDENCE / "record-video.json").write_text(json.dumps(self.result, indent=2))
            if self.result["status"] != "recorded":
                print("::warning::Native video evidence is incomplete; see record-video.json/log. "
                      "The XCTest result is unchanged.", flush=True)


@contextmanager
def record_native_video(udid):
    video = NativeVideo(udid)
    previous_handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}

    def cancel(signum, _frame):
        raise SystemExit(128 + signum)

    try:
        for sig in previous_handlers:
            signal.signal(sig, cancel)
        try:
            video.start()
        except Exception as error:
            video.result["error"] = str(error)
            print(f"::warning::Could not start native video: {error}", flush=True)
        yield
    finally:
        # Finish the MP4 even if cancellation arrives here. Do not swallow a
        # first cancellation on a successful run or replace a prior test error.
        already_failing = sys.exc_info()[0] is not None
        deferred_signals = []

        def defer_cancel(signum, _frame):
            if not deferred_signals:
                deferred_signals.append(signum)

        for sig in previous_handlers:
            signal.signal(sig, defer_cancel)
        try:
            video.stop()
        except Exception as error:
            # Even a full disk must not replace XCTest's original exit status.
            print(f"::warning::Could not save native video metadata: {error}", flush=True)
        finally:
            for sig, handler in previous_handlers.items():
                signal.signal(sig, handler)
        if deferred_signals and not already_failing:
            raise SystemExit(128 + deferred_signals[0])


def state():
    return json.loads(STATE.read_text())


def build_arguments():
    return ["xcodebuild", "-project", PROJECT, "-scheme", SCHEME,
            "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={state()['udid']}",
            "-derivedDataPath", "build/DerivedData", "-parallel-testing-enabled", "NO"]


def inventory_diagnostic(name, command, timeout):
    """Bound both collection time and live output; keep only a 16 KiB tail."""
    started = time.monotonic()
    result = {"command": command, "timeoutSeconds": timeout,
              "sourceSHA": os.environ.get("GITHUB_SHA"), "readOnly": True,
              "automaticRetryAllowed": False, "status": "unavailable"}
    process = None
    tail = b""
    total_bytes = 0
    stream_closed = False
    try:
        process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        os.set_blocking(process.stdout.fileno(), False)
        deadline = started + timeout
        with selectors.DefaultSelector() as ready:
            ready.register(process.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not ready.select(timeout=remaining):
                    raise subprocess.TimeoutExpired(command, timeout)
                chunk = os.read(process.stdout.fileno(), 16384)
                if not chunk:
                    stream_closed = True
                    process.wait(timeout=max(0, deadline - time.monotonic()))
                    break
                total_bytes += len(chunk)
                tail = (tail + chunk)[-16384:]
        result["status"] = "collected" if process.returncode == 0 else "failed"
    except subprocess.TimeoutExpired:
        result["status"] = "timed-out"
    except (KeyboardInterrupt, SystemExit):
        result["status"] = "cancelled"
        raise
    except Exception as error:
        result["error"] = str(error)
    finally:
        if process is not None:
            if not stream_closed or process.poll() is None:
                # A second cancellation cannot interrupt owned-child cleanup.
                previous = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
                try:
                    for sig in previous:
                        signal.signal(sig, signal.SIG_IGN)
                    signal_owned_process(process, signal.SIGKILL)
                    process.wait(timeout=5)
                except Exception as error:
                    result["cleanupError"] = str(error)
                finally:
                    for sig, handler in previous.items():
                        signal.signal(sig, handler)
            result["exitCode"] = process.poll()
            process.stdout.close()
        result["outputTruncated"] = total_bytes > 16384
        result["elapsedSeconds"] = round(time.monotonic() - started, 2)
        try:
            (EVIDENCE / f"{name}.log").write_bytes(tail)
            (EVIDENCE / f"{name}.json").write_text(json.dumps(result, indent=2))
        except Exception as error:
            # Evidence failure must not replace inventory failure or cancellation.
            print(f"::warning::Could not save {name}: {error}", flush=True)


def inventory_diagnostics():
    """Read-only host evidence; never retry inventory or reset services."""
    commands = [
        ("diagnostic-simctl-location", ["xcrun", "--find", "simctl"], 10),
        # comm intentionally excludes process arguments, which may contain secrets.
        ("diagnostic-process-states", ["/bin/ps", "-axo", "pid,ppid,state,etime,comm"], 10),
        ("diagnostic-disk", ["/bin/df", "-h", "/"], 10),
        ("diagnostic-coresimulator-log", ["/usr/bin/log", "show", "--last", "3m",
            "--style", "compact", "--info", "--predicate",
            'process == "CoreSimulatorService" OR subsystem BEGINSWITH "com.apple.CoreSimulator"'], 15),
    ]
    previous = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}

    def cancel(signum, _frame):
        raise SystemExit(128 + signum)

    try:
        for sig in previous:
            signal.signal(sig, cancel)
        for name, command, timeout in commands:
            inventory_diagnostic(name, command, timeout)
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def prepare():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    scenario_name, selected = scenario()
    required = required_test_methods(selected["onlyTesting"])
    runtime = os.environ["SIM_RUNTIME"]
    device_type = os.environ["SIM_DEVICE_TYPE"]
    fingerprint = {
        "scenario": scenario_name,
        "requestedRuntime": runtime,
        "requestedDeviceType": device_type,
        "requestedContentSize": selected["contentSize"],
        "onlyTesting": selected["onlyTesting"],
        "triggerSHA": os.environ.get("GITHUB_SHA"),
        "workflowSHA": os.environ.get("GITHUB_WORKFLOW_SHA"),
        "workflowRef": os.environ.get("GITHUB_WORKFLOW_REF"),
        "runID": os.environ.get("GITHUB_RUN_ID"),
        "runAttempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "job": os.environ.get("GITHUB_JOB"),
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
    (EVIDENCE / "test-selection.json").write_text(json.dumps({
        "scenario": scenario_name,
        "onlyTesting": selected["onlyTesting"],
        "arguments": [f"-only-testing:{identifier}" for identifier in selected["onlyTesting"]],
        "requiredPassedTests": required,
        "inventorySource": "checked-out Objective-C test implementations",
        "sourceSHA": fingerprint["sourceSHA"],
        "selectionIsNotExecutionEvidence": True,
    }, indent=2))
    if fingerprint["xcode"] != "Xcode 16.4\nBuild version 16F6" or fingerprint["sdk"] != "18.5":
        raise SystemExit("Environment drift: review the selected Xcode/SDK before running tests.")
    if runtime != "com.apple.CoreSimulator.SimRuntime.iOS-18-5":
        raise SystemExit("Environment drift: this matrix requires the installed iOS 18.5 runtime.")
    if device_type != selected["deviceType"]:
        raise SystemExit(f"Scenario/device mismatch: {scenario_name} requires {selected['deviceType']}.")
    try:
        inventory = json.loads(run("simulator-inventory", ["xcrun", "simctl", "list", "--json"]))
    except (Exception, SystemExit) as error:
        if isinstance(error, SystemExit) and error.code in (130, 143):
            raise  # Honor cancellation rather than starting extra diagnostic work.
        print("::warning::Simulator inventory failed before device creation. "
              "Collecting bounded read-only host evidence; inventory will not be retried.", flush=True)
        try:
            inventory_diagnostics()
        except Exception as diagnostic_error:
            print(f"::warning::Could not retain all inventory diagnostics: {diagnostic_error}", flush=True)
        raise  # The original inventory failure remains authoritative.
    selected_runtime = next((item for item in inventory["runtimes"]
                             if item["identifier"] == runtime and item.get("isAvailable")), None)
    if selected_runtime is None:
        raise SystemExit(f"Required installed runtime is not available: {runtime}")
    selected_device = next((item for item in inventory["devicetypes"]
                           if item["identifier"] == device_type), None)
    if selected_device is None:
        raise SystemExit(f"Required device type is not available: {device_type}")
    fingerprint.update({"runtime": selected_runtime, "deviceType": selected_device})
    (EVIDENCE / "environment.json").write_text(json.dumps(fingerprint, indent=2))
    name = ("CalcuLater-quality-" + os.environ.get("GITHUB_RUN_ID", str(os.getpid()))
            + "-" + os.environ.get("GITHUB_RUN_ATTEMPT", "local") + "-" + scenario_name)
    udid = run("create-simulator", ["xcrun", "simctl", "create", name, device_type, runtime]).strip()
    STATE.write_text(json.dumps({"udid": udid, "name": name, "runtime": runtime,
                                 "deviceType": device_type, "scenario": scenario_name}, indent=2))
    shutil.copy2(STATE, EVIDENCE / STATE.name)
    fingerprint["ownedSimulatorUDID"] = udid
    (EVIDENCE / "environment.json").write_text(json.dumps(fingerprint, indent=2))


def build():
    run("build", build_arguments() + ["-resultBundlePath", "build/Build.xcresult",
                                     "build-for-testing"], timeout=720)


def boot():
    udid = state()["udid"]
    run("boot", ["xcrun", "simctl", "boot", udid], timeout=60)
    run("readiness", ["xcrun", "simctl", "bootstatus", udid, "-b"], timeout=180)


def configure():
    """Require the selected tool's help and actual Simulator setting readback.

    Never substitute an app launch argument, defaults write, or source override
    for real system Dynamic Type. The selected Xcode's help is the CLI contract.
    """
    scenario_name, selected = scenario()
    owned = state()
    if owned["scenario"] != scenario_name:
        raise SystemExit("Owned Simulator belongs to another scenario; refusing to configure it.")
    query = ["xcrun", "simctl", "ui", owned["udid"], "content_size"]
    result = {"scenario": scenario_name, "ownedSimulatorUDID": owned["udid"],
              "sourceSHA": os.environ.get("GITHUB_SHA"), "status": "unverified",
              "requestedContentSize": selected["contentSize"],
              "helpCommand": ["xcrun", "simctl", "help", "ui"],
              "setCommand": query + [selected["contentSize"]], "queryCommand": query,
              "automaticRetryAllowed": False}
    phase = "tool-help"
    try:
        help_text = run("simctl-ui-help", result["helpCommand"])
        tokens = set(re.findall(r"[a-z]+(?:[_-][a-z]+)*", help_text))
        if not {"content_size", selected["contentSize"]}.issubset(tokens):
            raise SystemExit("Unsupported Dynamic Type setting in selected simctl help; "
                             "see simctl-ui-help.log. No text-size override was attempted.")
        # Query successfully before mutation, then require exact setting readback.
        phase = "query-before"
        result["before"] = run("content-size-before", query).strip()
        if not re.fullmatch(r"(?:accessibility-)?(?:extra-)*[a-z]+", result["before"]):
            raise SystemExit("Unsupported content_size query output; see content-size-before.log.")
        phase = "set"
        run("content-size-set", result["setCommand"])
        phase = "query-after"
        result["observedContentSize"] = run("content-size-after", query).strip()
        if result["observedContentSize"] != selected["contentSize"]:
            raise SystemExit("Dynamic Type readback did not match the requested setting; "
                             "see content-size-after.log. Native tests will not run.")
        result["status"] = "verified"
    except (Exception, SystemExit) as error:
        result.update({"status": "failed", "failedPhase": phase, "error": str(error)})
        print(f"::error::Scenario configuration failed at {phase}; "
              "no accessibility-size pass is claimed. See scenario-configuration.json.", flush=True)
        raise
    finally:
        (EVIDENCE / "scenario-configuration.json").write_text(json.dumps(result, indent=2))
        environment_path = EVIDENCE / "environment.json"
        fingerprint = json.loads(environment_path.read_text())
        fingerprint["contentSizeConfiguration"] = result
        environment_path.write_text(json.dumps(fingerprint, indent=2))


def test():
    scenario_name, selected = scenario()
    required = required_test_methods(selected["onlyTesting"])
    owned = state()
    configuration = json.loads((EVIDENCE / "scenario-configuration.json").read_text())
    if (configuration["status"] != "verified" or configuration["scenario"] != scenario_name
            or configuration["ownedSimulatorUDID"] != owned["udid"]
            or configuration["observedContentSize"] != selected["contentSize"]):
        raise SystemExit("Selected scenario was not verified on this owned Simulator; tests blocked.")
    # No separate replay, new Simulator, disabled animations, or automatic rerun.
    with record_native_video(owned["udid"]):
        output = run("test", build_arguments() + ["-resultBundlePath", "build/Tests.xcresult",
                                                 "-maximum-concurrent-test-simulator-destinations", "1"]
                     + [f"-only-testing:{identifier}" for identifier in selected["onlyTesting"]]
                     + ["test-without-building"], timeout=TEST_TIMEOUT)
    # This exact Objective-C XCTest line format was observed in the retained
    # Xcode 16.4 baseline. Missing/changed evidence must not turn an empty class
    # selection into a green layout job. Every selected method must pass, not
    # just one method in the last selected class. Never overwrite xcodebuild's exit.
    passed = re.findall(r"^Test Case '-\[([^\] ]+) ([^\]]+)\]' passed \(", output, re.MULTILINE)
    observed = [f"{class_name}/{method}" for class_name, method in passed]
    missing = sorted(set(required) - set(observed))
    required_suites = ["Calcu LaterTests.xctest"] if scenario_name == "standard" else []
    missing_suites = [name for name in required_suites if f"Test Suite '{name}' passed" not in output]
    verified = not missing and not missing_suites
    (EVIDENCE / "test-execution.json").write_text(json.dumps({
        "scenario": scenario_name, "ownedSimulatorUDID": owned["udid"],
        "sourceSHA": os.environ.get("GITHUB_SHA"), "onlyTesting": selected["onlyTesting"],
        "requiredPassedTests": required, "missingPassedTests": missing,
        "requiredPassedSuites": required_suites, "missingPassedSuites": missing_suites,
        "observedPassedTests": observed,
        "status": "verified" if verified else "missing-execution-evidence",
        "evidenceSource": "test.log", "automaticRetryAllowed": False,
    }, indent=2))
    if not verified:
        raise SystemExit("xcodebuild exited successfully but selected test execution was not observed. "
                         "See test-execution.json and the xcresult; a missing test is not a pass.")


def export():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    # Retain raw bundles even when a timed-out test left incomplete metadata.
    # A failed attachment export must never prevent the other evidence saving.
    for name in ("Build", "Tests"):
        bundle = BUILD / f"{name}.xcresult"
        if bundle.exists():
            shutil.make_archive(str(EVIDENCE / name), "zip", BUILD, bundle.name)
    result = BUILD / "Tests.xcresult"
    if result.exists():
        run("export-attachments", ["xcrun", "xcresulttool", "export", "attachments",
                                  "--path", str(result), "--output-path",
                                  str(EVIDENCE / "attachments")], timeout=120, check=False)
        run("test-summary", ["xcrun", "xcresulttool", "get", "test-results", "summary",
                             "--path", str(result)], timeout=120, check=False)
    if STATE.exists():
        run("final-device-state", ["xcrun", "simctl", "list", "devices", "--json"], check=False)
        if (EVIDENCE / "readiness.json").exists():
            run("final-device-screen", ["xcrun", "simctl", "io", state()["udid"],
                "screenshot", str(EVIDENCE / "final-device-screen.png")], check=False)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        scenario_name, selected = scenario()
        with open(summary, "a") as output:
            output.write("## Native evidence: " + scenario_name + "\n\nSource: "
                         + os.environ.get("GITHUB_SHA", "local")
                         + "\n\nSelected device: " + selected["deviceType"]
                         + "\n\nRequested content size: " + selected["contentSize"]
                         + "\n\nExact test selection:\n"
                         + "".join("- " + identifier + "\n" for identifier in selected["onlyTesting"])
                         + "\nSelection is not proof of execution. Check test.json, test-execution.json, test-summary.log "
                         "and the xcresult for actual results. Check scenario-configuration.json for "
                         "the retained tool help, setter and exact content-size readback. "
                         "Download this scenario's native-evidence artifact for the environment fingerprint, "
                         "per-stage logs, original xcresults, screenshot/hierarchy attachments and "
                         "native-flows.mp4 when capture succeeds. This records the unchanged acceptance stage; "
                         "record-video.json/log report startup, termination and evidence gaps separately "
                         "from test.json. A nonempty video is not a visual or animation pass: inspect "
                         "the actual teaching exchanges before claiming motion validation. "
                         "A missing test result is not a pass. Standard retains the model/component target "
                         "plus Calcu_LaterUITests; the three layout variants retain all five "
                         "Calcu_LaterLayoutUITests flows and add the actual-question 2 + 9 and "
                         "18 − 9 ten-frame methods. Every selected source method must have a "
                         "passing test.log entry; test-execution.json lists any missing methods. "
                         "Boilerplate repeated launch configurations are excluded.\n")


def cleanup():
    if STATE.exists():
        udid = state()["udid"]
        # Only this job's created device. Never erase or stop other simulators.
        subprocess.run(["xcrun", "simctl", "shutdown", udid], cwd=ROOT, check=False)
        run("delete-owned-simulator", ["xcrun", "simctl", "delete", udid], timeout=60)


if __name__ == "__main__":
    operations = {"prepare": prepare, "build": build, "boot": boot, "configure": configure,
                  "test": test, "export": export, "cleanup": cleanup}
    if len(sys.argv) != 2 or sys.argv[1] not in operations:
        raise SystemExit("Usage: native_quality.py prepare|build|boot|configure|test|export|cleanup")
    operations[sys.argv[1]]()

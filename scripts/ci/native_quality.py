#!/usr/bin/env python3
"""One owned Simulator, separate failure boundaries, no automatic retries.

The source tree is built once, then tested without rebuilding. Logs, the exact
environment, screen recording, screenshots, UI hierarchy and xcresults are retained.
This script only runs on a Mac with the repository's selected Xcode/runtime.
"""
from contextlib import contextmanager
from collections import Counter
import json
import math
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
from urllib.parse import quote

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
TEST_BUNDLE_TYPES = {
    "Calcu LaterTests": "Unit test bundle",
    "Calcu LaterUITests": "UI test bundle",
}
TEN_FRAME_TESTS = [
    "Calcu LaterUITests/Calcu_LaterUITests/testMakeTenCurrentNineDotsReplayBackRotateAndFinish",
    "Calcu LaterUITests/Calcu_LaterUITests/testBreakTenCurrentEightOnesSurviveReplayBackgroundAndReturn",
    "Calcu LaterUITests/Calcu_LaterUITests/testTenFrameVerticalComparisonAndSwipeReturnToTheOriginalQuestion",
]
LAYOUT_TESTS = ["Calcu LaterUITests/Calcu_LaterLayoutUITests"] + TEN_FRAME_TESTS
FOCUSED_GROUPING_TESTS = [
    "Calcu LaterUITests/GroupingFocusedActionUITests/testSharingFirstPlayReplayAndFourthRecipientStayFullyVisible",
    "Calcu LaterUITests/GroupingFocusedActionUITests/testPackingFirstAndFifthBagUseOneVisibleSourceToTargetRoute",
    "Calcu LaterUITests/GroupingFocusedActionUITests/testWrongCountAndContinuationCoachTheChosenQuantityWithoutAdvancing",
    "Calcu LaterUITests/GroupingFocusedActionUITests/testLandscapePausePreservesSelectionUntilExplicitReplay",
]
CONCEPT_CORE_TESTS = [
    "Calcu LaterUITests/ConceptDiscoveryUITests/testCarryDiscoveryKeepsQuestionsAcrossTeachingBackAndChangedNumbers",
    "Calcu LaterUITests/ConceptDiscoveryUITests/testBorrowingDirectlyExposesZeroRegrouping",
    "Calcu LaterUITests/ConceptDiscoveryUITests/testEqualGroupsDiscoveryDoesNotRequireOpeningTheMultiplicationTable",
]
CONCEPT_DIVISION_TESTS = [
    "Calcu LaterUITests/ConceptDiscoveryUITests/testSharingAndPackingKeepDifferentQuestionsForTheSameNumbers",
]
REDUCED_MOTION_TESTS = [
    "Calcu LaterUITests/ReducedMotionTeachingUITests/testSystemReduceMotionPreservesStaticTeachingAndUnansweredQuestions",
]
SCENARIOS = {
    "components": {
        # Real paused-presentation probes include a 736-point-wide teaching
        # surface. Use a physically fitting host, never an oversized fake window.
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPad-10th-generation",
        "contentSize": "large",
        "onlyTesting": ["Calcu LaterTests"],
    },
    "standard": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
        "contentSize": "large",
        "onlyTesting": ["Calcu LaterUITests/Calcu_LaterUITests"],
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
    "focusedGroupingCompact": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation",
        "contentSize": "large",
        "onlyTesting": FOCUSED_GROUPING_TESTS,
    },
    "focusedGroupingMaximumText": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
        "contentSize": "accessibility-extra-extra-extra-large",
        "onlyTesting": FOCUSED_GROUPING_TESTS,
    },
    "conceptCore": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
        "contentSize": "large",
        "onlyTesting": CONCEPT_CORE_TESTS,
    },
    "conceptDivision": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
        "contentSize": "large",
        "onlyTesting": CONCEPT_DIVISION_TESTS,
    },
    "conceptCoreMaximumText": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
        "contentSize": "accessibility-extra-extra-extra-large",
        "onlyTesting": CONCEPT_CORE_TESTS,
    },
    "conceptDivisionMaximumText": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
        "contentSize": "accessibility-extra-extra-extra-large",
        "onlyTesting": CONCEPT_DIVISION_TESTS,
    },
    "reducedMotion": {
        "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
        "contentSize": "large",
        "onlyTesting": REDUCED_MOTION_TESTS,
        # This is intent, not configuration proof. Only the retained Settings
        # UI readbacks and real renderer states establish the system preference.
        "systemSettingsIntent": {
            "reduceMotion": {
                "requested": "on",
                "mechanism": "Settings UI",
                "verification": "exact switch readback and real renderer state",
                "restoration": "original switch value in test teardown",
            },
        },
    },
}


def scenario():
    name = os.environ.get("NATIVE_SCENARIO", "standard")
    if name not in SCENARIOS:
        raise SystemExit(f"Unknown native scenario: {name}; no fallback tests will run.")
    return name, SCENARIOS[name]


def required_test_inventory(identifiers):
    """Resolve selected source methods to their unambiguous target bundles.

    Source inventory is intent, never execution evidence. Keep the historical
    Class/method API, but do not discard the selected source's target identity.
    """
    required = {}
    class_sources = {}
    for identifier in identifiers:
        parts = identifier.split("/")
        if (not 1 <= len(parts) <= 3 or parts[0] not in TEST_BUNDLE_TYPES
                or any(not re.fullmatch(r"[A-Za-z_]\w*", part) for part in parts[1:])):
            raise SystemExit(f"Unsupported test selection: {identifier}")
        directory = ROOT / parts[0]
        paths = (sorted(directory.rglob("*.m")) if len(parts) == 1
                 else [directory / f"{parts[1]}.m"])
        matched = {}
        for path in paths:
            if not path.is_file():
                raise SystemExit(f"Missing selected test source: {path}")
            source_key = (parts[0], path.stem)
            if source_key in class_sources and class_sources[source_key] != path:
                raise SystemExit(f"Ambiguous selected test class source: {path.stem}")
            class_sources[source_key] = path
            implementations = re.findall(
                r"^@implementation\s+" + re.escape(path.stem) + r"\s*$(.*?)^@end\b",
                path.read_text(), re.MULTILINE | re.DOTALL)
            if len(implementations) != 1:
                raise SystemExit(f"Unsupported selected test implementation: {path}")
            methods = re.findall(r"^\s*-\s*\(\s*void\s*\)\s*(test\w*)\s*\{",
                                 implementations[0], re.MULTILINE)
            if not methods or len(methods) != len(set(methods)):
                raise SystemExit(f"Missing or duplicate test methods in selected source: {path}")
            for method in methods:
                if len(parts) == 3 and method != parts[2]:
                    continue
                key = f"{path.stem}/{method}"
                if key in matched or key in required:
                    raise SystemExit(f"Overlapping or ambiguous selected test method: {key}")
                matched[key] = parts[0]
        if not matched:
            raise SystemExit(f"Selected test filter resolves to no methods: {identifier}")
        required.update(matched)
    if not required:
        raise SystemExit("No test methods selected; no fallback tests will run.")
    return dict(sorted(required.items()))


def required_test_methods(identifiers):
    return list(required_test_inventory(identifiers))


def expected_execution_device(owned, environment, scenario_name):
    """Bind result identity to the device and runtime actually inventoried."""
    if (owned["scenario"] != scenario_name or environment["scenario"] != scenario_name
            or environment["ownedSimulatorUDID"] != owned["udid"]
            or environment["deviceType"]["identifier"] != owned["deviceType"]
            or environment["runtime"]["identifier"] != owned["runtime"]):
        raise ValueError("Owned Simulator and retained environment identities disagree.")
    device = {
        "deviceId": owned["udid"], "deviceName": owned["name"],
        "architecture": environment["architecture"],
        "modelName": environment["deviceType"]["name"], "platform": "iOS Simulator",
        "osVersion": environment["runtime"]["version"],
        "osBuildNumber": environment["runtime"]["buildversion"],
    }
    if any(not isinstance(value, str) or not value for value in device.values()):
        raise ValueError("Missing owned Simulator identity; no result-device fallback is allowed.")
    return device


def structured_execution_report(raw, required, expected_device):
    """Accept only the reviewed Xcode 16.4 single-device, nonrepeated tree.

    Every identity and Passed result is checked, including container results.
    Additional/ambiguous JSON fields, wrappers, devices or configurations fail
    closed. A future schema needs review, not a console or aggregate fallback.
    """
    report = {"status": "rejected", "evidenceSource": "xcresult-tests.log",
              "requiredPassedTests": sorted(required), "requiredTestTargets": required,
              "expectedDevice": expected_device, "observedTests": [],
              "nonPassingNodes": [], "errors": []}

    def issue(path, reason):
        report["errors"].append({"path": path, "reason": reason})

    def object_shape(value, keys, path):
        if not isinstance(value, dict):
            issue(path, "Expected an object.")
            return False
        missing = set(keys) - value.keys()
        extra = value.keys() - set(keys)
        if missing or extra:
            issue(path, f"Unsupported fields: missing={sorted(missing)}, extra={sorted(extra)}.")
            return False
        return True

    def unique_object(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError(f"Duplicate JSON object field: {key}")
            value[key] = item
        return value

    def invalid_constant(value):
        raise ValueError(f"Non-JSON numeric constant: {value}")

    def url(*parts):
        return "test://com.apple.xcode/" + "/".join(quote(part, safe="") for part in (SCHEME, *parts))

    def node(value, expected_type, path, expected_name=None, expected_url=None):
        keys = {"nodeType", "name", "result"}
        if expected_type == "Test Case":
            keys.update(("nodeIdentifier", "nodeIdentifierURL", "duration", "durationInSeconds"))
        else:
            keys.add("children")
            if expected_type != "Test Plan":
                keys.add("nodeIdentifierURL")
        if not object_shape(value, keys, path):
            return False
        if value["nodeType"] != expected_type:
            issue(path, f"Unsupported node type {value['nodeType']!r}; expected {expected_type!r}.")
            return False
        if not isinstance(value["name"], str) or not value["name"]:
            issue(path, "Missing node name.")
            return False
        if expected_name is not None and value["name"] != expected_name:
            issue(path, f"Wrong node name; expected {expected_name!r}.")
        if expected_url is not None and value["nodeIdentifierURL"] != expected_url:
            issue(path, f"Wrong nodeIdentifierURL; expected {expected_url!r}.")
        if value["result"] != "Passed":
            report["nonPassingNodes"].append({"path": path, "name": value["name"],
                                              "nodeType": value["nodeType"], "result": value["result"]})
        if expected_type == "Test Case":
            duration = value["durationInSeconds"]
            if (not isinstance(value["duration"], str) or not value["duration"]
                    or type(duration) not in (int, float) or not math.isfinite(duration) or duration < 0):
                issue(path, "Invalid test-case duration fields.")
        elif not isinstance(value["children"], list) or not value["children"]:
            issue(path, "Expected nonempty children; no empty-container pass is accepted.")
            return False
        return True

    try:
        data = json.loads(raw, object_pairs_hook=unique_object, parse_constant=invalid_constant)
    except (ValueError, TypeError, RecursionError) as error:
        issue("$", f"Invalid structured JSON: {error}")
        data = None
    expected = {f"{target}/{method}" for method, target in required.items()}
    if (not required or any(target not in TEST_BUNDLE_TYPES
                           or not re.fullmatch(r"[A-Za-z_]\w*/test\w*", method)
                           for method, target in required.items())):
        issue("source", "Empty or unsupported source inventory.")
    if object_shape(data, {"devices", "testPlanConfigurations", "testNodes"}, "$"):
        report["observedDevices"] = data["devices"]
        report["observedConfigurations"] = data["testPlanConfigurations"]
        if data["devices"] != [expected_device]:
            issue("$.devices", "Expected exactly the owned Simulator's full inventoried identity.")
        if data["testPlanConfigurations"] != [{"configurationId": "1", "configurationName": "Test Scheme Action"}]:
            issue("$.testPlanConfigurations", "Unsupported/multiple test plan configurations.")
        plans = data["testNodes"]
        if not isinstance(plans, list) or len(plans) != 1:
            issue("$.testNodes", "Expected exactly one test plan.")
        elif node(plans[0], "Test Plan", "$.testNodes[0]", SCHEME):
            bundles = []
            suites = []
            for bi, bundle in enumerate(plans[0]["children"]):
                bp = f"$.testNodes[0].children[{bi}]"
                target = bundle.get("name") if isinstance(bundle, dict) else None
                if not isinstance(target, str) or target not in TEST_BUNDLE_TYPES:
                    issue(bp, "Unknown test bundle identity.")
                    continue
                bundles.append(target)
                if not node(bundle, TEST_BUNDLE_TYPES[target], bp, target, url(target)):
                    continue
                for si, suite in enumerate(bundle["children"]):
                    sp = f"{bp}.children[{si}]"
                    class_name = suite.get("name") if isinstance(suite, dict) else None
                    if not isinstance(class_name, str) or not re.fullmatch(r"[A-Za-z_]\w*", class_name):
                        issue(sp, "Invalid class identity.")
                        continue
                    suites.append(f"{target}/{class_name}")
                    if not node(suite, "Test Suite", sp, class_name, url(target, class_name)):
                        continue
                    for ci, case in enumerate(suite["children"]):
                        cp = f"{sp}.children[{ci}]"
                        method = case.get("name") if isinstance(case, dict) else None
                        if not isinstance(method, str) or not re.fullmatch(r"test\w*", method):
                            issue(cp, "Invalid test method identity.")
                            continue
                        if not node(case, "Test Case", cp, method, url(target, class_name, method)):
                            continue
                        identifier = f"{class_name}/{method}"
                        if case["nodeIdentifier"] != identifier:
                            issue(cp, f"Wrong nodeIdentifier; expected {identifier!r}.")
                        report["observedTests"].append({"identifier": f"{target}/{identifier}",
                                                        "result": case["result"], "path": cp})
            expected_bundles = set(required.values())
            if Counter(bundles) != Counter({target: 1 for target in expected_bundles}):
                issue("$.testNodes[0].children", "Missing, duplicate or unexpected test bundles.")
            expected_suites = {f"{target}/{method.split('/')[0]}" for method, target in required.items()}
            if Counter(suites) != Counter({suite: 1 for suite in expected_suites}):
                issue("suites", "Missing, duplicate or unexpected test suites.")
    observed = Counter(item["identifier"] for item in report["observedTests"])
    passed = {item["identifier"] for item in report["observedTests"] if item["result"] == "Passed"}
    report.update({
        "missingTests": sorted(expected - observed.keys()),
        "missingPassedTests": sorted(method for method, target in required.items()
                                     if f"{target}/{method}" not in passed),
        "unexpectedTests": sorted(observed.keys() - expected),
        "duplicateTests": sorted(method for method, count in observed.items() if count != 1),
        "observedPassedTests": sorted(item.split("/", 1)[1] for item in passed),
    })
    if not any(report[key] for key in ("errors", "nonPassingNodes", "missingTests",
                                      "missingPassedTests", "unexpectedTests", "duplicateTests")):
        report["status"] = "verified"
    return report


def verify_test_execution(output, required, owned, scenario_name, selected):
    """Read the current bundle only after xcodebuild succeeds; never rerun tests."""
    passed = re.findall(r"^Test Case '-\[([^\] ]+) ([^\]]+)\]' passed \(", output, re.MULTILINE)
    console = [f"{class_name}/{method}" for class_name, method in passed]
    result = {"scenario": scenario_name, "ownedSimulatorUDID": owned["udid"],
              "sourceSHA": os.environ.get("GITHUB_SHA"), "onlyTesting": selected["onlyTesting"],
              "status": "unverified", "evidenceSource": "xcresult-tests.log",
              "automaticRetryAllowed": False,
              "consoleComparison": {"evidenceSource": "test.log", "authoritative": False,
                                    "observedPassedTests": console,
                                    "missingPassedTests": sorted(set(required) - set(console)),
                                    "unexpectedPassedTests": sorted(set(console) - set(required))}}
    phase = "owned-device-identity"
    try:
        environment = json.loads((EVIDENCE / "environment.json").read_text())
        expected_device = expected_execution_device(owned, environment, scenario_name)
        phase = "tool-help"
        run("xcresult-tests-help", ["xcrun", "xcresulttool", "help", "get", "test-results", "tests"])
        phase = "structured-results"
        raw = run("xcresult-tests", ["xcrun", "xcresulttool", "get", "test-results", "tests",
                                    "--path", "build/Tests.xcresult"])
        phase = "verify-structured-results"
        result.update(structured_execution_report(raw, required, expected_device))
        if result["status"] != "verified":
            raise SystemExit("xcodebuild exited successfully but exact structured test execution "
                             "was not verified. See test-execution.json and xcresult-tests.log; "
                             "missing, failed, skipped or ambiguous results are not passes.")
    except (Exception, SystemExit, KeyboardInterrupt) as error:
        result.update({"status": "failed", "failedPhase": phase, "error": str(error)})
        raise
    finally:
        already_failing = sys.exc_info()[0] is not None
        try:
            (EVIDENCE / "test-execution.json").write_text(json.dumps(result, indent=2))
        except Exception as error:
            if not already_failing:
                raise
            print(f"::warning::Could not save test-execution.json: {error}", flush=True)


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
        try:
            output = interrupt_command(process)
        except Exception:
            # A secondary cleanup error must not turn a captured cancellation
            # into an ordinary best-effort export failure.
            raise interruption
        code = error.code if isinstance(error, SystemExit) and isinstance(error.code, int) else 130
        output += "\nCOMMAND CANCELLED; interrupted owned process group\n"
    try:
        (EVIDENCE / f"{name}.log").write_text(output)
        (EVIDENCE / f"{name}.json").write_text(json.dumps({
            "command": command, "exitCode": code,
            "elapsedSeconds": round(time.monotonic() - started, 2),
            "sourceSHA": os.environ.get("GITHUB_SHA"),
            "scenario": os.environ.get("NATIVE_SCENARIO", "standard"),
            "automaticRetryAllowed": False,
        }, indent=2))
        print(output, flush=True)
    finally:
        # An evidence-write failure must not replace cancellation already caught
        # above. Without cancellation, every existing write/error path is unchanged.
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
    required = required_test_inventory(selected["onlyTesting"])
    runtime = os.environ["SIM_RUNTIME"]
    device_type = os.environ["SIM_DEVICE_TYPE"]
    fingerprint = {
        "scenario": scenario_name,
        "requestedRuntime": runtime,
        "requestedDeviceType": device_type,
        "requestedContentSize": selected["contentSize"],
        "onlyTesting": selected["onlyTesting"],
        "systemSettingsIntent": selected.get("systemSettingsIntent", {}),
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
        "requiredPassedTests": list(required),
        "requiredTestTargets": required,
        "systemSettingsIntent": selected.get("systemSettingsIntent", {}),
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
              "statusScope": "system Dynamic Type only",
              "requestedContentSize": selected["contentSize"],
              "systemSettingsIntent": selected.get("systemSettingsIntent", {}),
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
    required = required_test_inventory(selected["onlyTesting"])
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
    # Console output can interleave NSLog inside a method name. Retain it for
    # comparison, but only the exact xcresult tree can prove selected execution.
    verify_test_execution(output, required, owned, scenario_name, selected)


def export_diagnostic_test_tree(result):
    """Retain a missing structured tree, never evaluate or replace acceptance.

    A failed xcodebuild does not reach verify_test_execution(). Inspect its
    existing bundle read-only under distinct names, after other evidence saves.
    check=False retains tool failure/timeout metadata but still raises genuine
    cancellation; only ordinary collection errors are best-effort here.
    """
    commands = (
        ("xcresult-tests-diagnostic-help", ["xcrun", "xcresulttool", "help", "get",
                                            "test-results", "tests"]),
        ("xcresult-tests-diagnostic", ["xcrun", "xcresulttool", "get", "test-results",
                                      "tests", "--path", str(result)]),
    )
    previous = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
    cancellation = None

    def cancel(signum, _frame):
        nonlocal cancellation
        if cancellation is None:
            cancellation = SystemExit(128 + signum)
        raise cancellation

    try:
        for sig in previous:
            signal.signal(sig, cancel)
        for name, command in commands:
            try:
                # Preserve successful proof and failed/partial proof attempts alike.
                # Export must not retry the gate or overwrite any retained output.
                if any((EVIDENCE / f"xcresult-tests.{suffix}").exists() for suffix in ("log", "json")):
                    return
                if any((EVIDENCE / f"{name}.{suffix}").exists() for suffix in ("log", "json")):
                    print(f"::warning::Preserving existing {name} output; no repeated inspection.", flush=True)
                    continue
                run(name, command, timeout=120, check=False)
            except Exception as error:
                # run() saves output before rethrowing cancellation. A simultaneous
                # write error must not hide that cancellation or start another probe.
                if cancellation is not None:
                    raise cancellation
                print(f"::warning::Could not retain {name}: {error}. "
                      "The original test result is unchanged.", flush=True)
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
        if cancellation is not None:
            raise cancellation


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
                         + "\nSelection is not proof of execution. Check test.json, test-execution.json, xcresult-tests.log, test-summary.log "
                         "and the xcresult for actual results. Check scenario-configuration.json for "
                         "the retained tool help, setter and exact content-size readback. "
                         "Download this scenario's native-evidence artifact for the environment fingerprint, "
                         "per-stage logs, original xcresults, screenshot/hierarchy attachments and "
                         "the video-package-manifest.json. Original native-flows.mp4 bytes are retained separately "
                         "as bounded native-video parts when capture succeeds; reassemble and verify with "
                         "scripts/ci/package_native_video.py before viewing. No transcoding occurs. "
                         "This records the unchanged acceptance stage; "
                         "record-video.json/log report startup, termination and evidence gaps separately "
                         "from test.json. A nonempty video is not a visual or animation pass: inspect "
                         "the actual teaching exchanges before claiming motion validation. "
                         "A missing test result is not a pass. Components retains the complete component target; "
                         "standard retains Calcu_LaterUITests in a separate bounded command. "
                         "The three original layout variants retain the complete "
                         "Calcu_LaterLayoutUITests class and all three actual-question ten-frame flows. "
                         "Additional bounded lanes cover focused grouping on compact/maximum text, "
                         "concept core and division on normal/maximum text, and actual system Reduce Motion. "
                         "System-setting intent is not proof: scenario-configuration verifies Dynamic Type only; "
                         "the dedicated Reduce Motion UI test must retain real Settings switch readbacks, "
                         "renderer states and restoration of the original preference. "
                         "Every selected source method must have a "
                         "unique Passed case in the expected xcresult bundle on the owned device; "
                         "test-execution.json lists missing, non-passing, duplicate and unexpected results. "
                         "xcresult-tests-help.log retains the selected tool contract; console output is "
                         "diagnostic only, never an alternative passing path. "
                         "When the proof collector did not retain a test tree, export attempts "
                         "xcresult-tests-diagnostic.log/json and xcresult-tests-diagnostic-help.log/json "
                         "from the existing bundle. These are diagnostic only: tool exit status and "
                         "partial output are retained, never promoted to test-execution.json or a pass. "
                         "Boilerplate repeated launch configurations are excluded.\n")
    # Save the existing raw bundles, attachments, summary and device evidence
    # first, so this additional best-effort inspection cannot prevent them.
    if result.exists():
        export_diagnostic_test_tree(result)


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

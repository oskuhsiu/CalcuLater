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
import shutil
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
    # No separate replay, new Simulator, disabled animations, or automatic rerun.
    with record_native_video(state()["udid"]):
        run("test", build_arguments() + ["-resultBundlePath", "build/Tests.xcresult",
                                        "-maximum-concurrent-test-simulator-destinations", "1",
                                        "-only-testing:Calcu LaterTests",
                                        "-only-testing:Calcu LaterUITests/Calcu_LaterUITests",
                                        "test-without-building"], timeout=TEST_TIMEOUT)


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
        with open(summary, "a") as output:
            output.write("## Native evidence\n\nSource: " + os.environ.get("GITHUB_SHA", "local")
                         + "\n\nDownload the native-evidence artifact for the environment fingerprint, "
                         "per-stage logs, original xcresults, screenshot/hierarchy attachments and "
                         "native-flows.mp4 when capture succeeds. This records the unchanged acceptance stage; "
                         "record-video.json/log report startup, termination and evidence gaps separately "
                         "from test.json. A nonempty video is not a visual or animation pass: inspect "
                         "the actual teaching exchanges before claiming motion validation. "
                         "A missing test result is not a pass. This acceptance run selects the model/component "
                         "test target plus Calcu_LaterUITests native flows; boilerplate repeated launch "
                         "configurations are not included.\n")


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

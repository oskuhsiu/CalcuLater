"""Portable export regressions. Every subprocess is mocked; no native execution.

Temporary bundle files and altered tree strings are test inputs, not acceptance
evidence. The unchanged parser/gate is never used to promote diagnostic output.
"""
from contextlib import nullcontext, redirect_stdout
import io
import json
from pathlib import Path
import signal
import subprocess
import tempfile
import unittest
from unittest import mock
import zipfile

import native_quality as quality


class DiagnosticExportTests(unittest.TestCase):
    HELP = "xcresult-tests-diagnostic-help"
    TREE = "xcresult-tests-diagnostic"

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.build = self.root / "build"
        self.evidence = self.build / "evidence"
        self.evidence.mkdir(parents=True)
        self.originals = {}
        for name in ("Build", "Tests"):
            path = self.build / f"{name}.xcresult" / "Data" / "record"
            path.parent.mkdir(parents=True)
            self.originals[path] = f"Portable {name} bundle placeholder\n".encode()
            path.write_bytes(self.originals[path])
        self.owned = {"udid": "portable-owned-device", "scenario": "standard"}
        self.state = self.build / "simulator.json"
        self.state.write_text(json.dumps(self.owned))
        (self.evidence / "readiness.json").write_text("{}")
        (self.evidence / "scenario-configuration.json").write_text(json.dumps({
            "status": "verified", "scenario": "standard",
            "ownedSimulatorUDID": self.owned["udid"], "observedContentSize": "large",
        }))
        self.summary = self.root / "summary.md"
        self.raw = (Path(__file__).with_name("fixtures") /
                    "xcresult-tests-xcode16.4-excerpt.json").read_text()
        self.output = io.StringIO()
        self.addCleanup(mock.patch.stopall)
        mock.patch.object(quality, "ROOT", self.root).start()
        mock.patch.object(quality, "BUILD", self.build).start()
        mock.patch.object(quality, "EVIDENCE", self.evidence).start()
        mock.patch.object(quality, "STATE", self.state).start()
        mock.patch.dict(quality.os.environ, {"GITHUB_SHA": "portable-source-sha",
                        "NATIVE_SCENARIO": "standard",
                        "GITHUB_STEP_SUMMARY": str(self.summary)}).start()
        self.real_run = quality.run
        self.calls = []
        self.failures = {}
        self.codes = {"test": 65, self.HELP: 0, self.TREE: 0}
        self.outputs = {"test": "xcodebuild failed\n", self.HELP: "captured tool help\n",
                        self.TREE: self.raw}
        self.processes = {}
        self.popen = mock.patch.object(quality.subprocess, "Popen", side_effect=self.launch).start()
        self.interrupt = mock.patch.object(quality, "interrupt_command",
                                           return_value="partial diagnostic output\n").start()
        mock.patch.object(quality, "run", side_effect=self.command).start()
        self.verify = mock.patch.object(quality, "verify_test_execution").start()
        self.parser = mock.patch.object(quality, "structured_execution_report").start()

    def launch(self, command, **kwargs):
        name = ("test" if command[0] == "xcodebuild"
                else self.HELP if command[2] == "help" else self.TREE)
        failure = self.failures.get(name)
        if isinstance(failure, OSError):
            raise failure
        process = mock.Mock(returncode=self.codes[name])
        if failure is not None:
            process.communicate.side_effect = failure
        else:
            process.communicate.return_value = (self.outputs[name], None)
        self.processes[name] = process
        return process

    def command(self, name, command, **kwargs):
        self.calls.append((name, command, kwargs))
        if name in ("test", self.HELP, self.TREE):
            return self.real_run(name, command, **kwargs)
        # The existing unrelated exports are not exercised as native commands.
        (self.evidence / f"{name}.log").write_text("Portable export placeholder\n")
        return ""

    def export(self):
        with redirect_stdout(self.output):
            quality.export()

    def metadata(self, name):
        return json.loads((self.evidence / f"{name}.json").read_text())

    def assert_original_evidence_retained(self):
        for path, original in self.originals.items():
            self.assertEqual(path.read_bytes(), original)
            with zipfile.ZipFile(self.evidence / f"{path.parents[1].stem}.zip") as archive:
                self.assertEqual(archive.read(str(path.relative_to(self.build))), original)
        ordinary = ["export-attachments", "test-summary", "final-device-state", "final-device-screen"]
        names = [name for name, _, _ in self.calls]
        for name in ordinary:
            self.assertTrue((self.evidence / f"{name}.log").is_file())
            if self.HELP in names:
                self.assertLess(names.index(name), names.index(self.HELP))
        self.assertIn("diagnostic only", self.summary.read_text())
        self.verify.assert_not_called()
        self.parser.assert_not_called()
        self.assertFalse((self.evidence / "test-execution.json").exists())

    def test_failed_xcodebuild_remains_failed_and_exports_exact_mixed_tree(self):
        # Deliberately nonpassing mock input, not a newly captured native result.
        self.outputs[self.TREE] = self.raw.replace('"result": "Passed"', '"result": "Failed"', 1)
        with mock.patch.object(quality, "required_test_inventory", return_value={"Example/testOne": "Calcu LaterTests"}), \
                mock.patch.object(quality, "build_arguments", return_value=["xcodebuild"]), \
                mock.patch.object(quality, "record_native_video", return_value=nullcontext()), \
                redirect_stdout(self.output), self.assertRaises(SystemExit) as failure:
            quality.test()
        self.assertEqual(failure.exception.code, 65)
        original_failure = (self.evidence / "test.json").read_bytes()
        self.export()
        self.assertEqual((self.evidence / "test.json").read_bytes(), original_failure)
        self.assertEqual((self.evidence / f"{self.TREE}.log").read_text(), self.outputs[self.TREE])
        self.assertEqual(self.metadata(self.TREE)["exitCode"], 0)
        self.assertEqual([name for name, _, _ in self.calls].count("test"), 1)
        self.assert_original_evidence_retained()
        diagnostic = [(name, command, options) for name, command, options in self.calls
                      if name in (self.HELP, self.TREE)]
        self.assertEqual(diagnostic, [
            (self.HELP, ["xcrun", "xcresulttool", "help", "get", "test-results", "tests"],
             {"timeout": 120, "check": False}),
            (self.TREE, ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path",
                        str(self.build / "Tests.xcresult")], {"timeout": 120, "check": False}),
        ])
        self.assertEqual(self.metadata(self.TREE)["sourceSHA"], "portable-source-sha")
        self.assertEqual(self.metadata(self.TREE)["scenario"], "standard")
        self.assertFalse(self.metadata(self.TREE)["automaticRetryAllowed"])

    def test_existing_proof_or_partial_proof_is_never_replaced_or_retried(self):
        for anchor in ("log", "json"):
            with self.subTest(anchor=anchor):
                retained = {"xcresult-tests." + anchor: b"Original gate output\n",
                            "xcresult-tests-help.log": b"Original gate help\n",
                            "xcresult-tests-help.json": b"Original help metadata\n",
                            "test-execution.json": b"Original acceptance decision\n"}
                for name, raw in retained.items():
                    (self.evidence / name).write_bytes(raw)
                self.export()
                for name, raw in retained.items():
                    self.assertEqual((self.evidence / name).read_bytes(), raw)
                    (self.evidence / name).unlink()
        self.popen.assert_not_called()
        self.verify.assert_not_called()
        self.parser.assert_not_called()

    def test_existing_diagnostic_files_are_preserved_including_partial_pairs(self):
        for name in (self.HELP, self.TREE):
            for suffix in ("log", "json"):
                with self.subTest(name=name, suffix=suffix):
                    for path in self.evidence.glob("xcresult-tests-diagnostic*"):
                        path.unlink()
                    path = self.evidence / f"{name}.{suffix}"
                    original = b"Original partial diagnostic output\n"
                    path.write_bytes(original)
                    before = self.popen.call_count
                    self.export()
                    self.assertEqual(path.read_bytes(), original)
                    self.assertEqual(self.popen.call_count, before + 1)
                    self.export()
                    self.assertEqual(self.popen.call_count, before + 1)

    def test_missing_test_bundle_does_not_start_diagnostic_or_create_proof(self):
        for path in sorted((self.build / "Tests.xcresult").rglob("*"), reverse=True):
            path.unlink() if path.is_file() else path.rmdir()
        (self.build / "Tests.xcresult").rmdir()
        self.export()
        self.popen.assert_not_called()
        self.assertTrue((self.evidence / "Build.zip").is_file())
        self.assertFalse((self.evidence / "Tests.zip").exists())
        self.assertFalse((self.evidence / "test-execution.json").exists())

    def test_nonzero_inspection_is_retained_without_gating_other_evidence(self):
        self.codes.update({self.HELP: 64, self.TREE: 74})
        self.outputs[self.TREE] = "Cannot read incomplete bundle\n"
        self.export()
        for name, code in ((self.HELP, 64), (self.TREE, 74)):
            self.assertEqual(self.metadata(name)["exitCode"], code)
        self.assertEqual((self.evidence / f"{self.TREE}.log").read_text(), self.outputs[self.TREE])
        self.assertEqual(self.popen.call_count, 2)
        self.assert_original_evidence_retained()

    def test_timeout_retains_partial_output_and_uses_existing_bounded_runner(self):
        self.failures.update({name: subprocess.TimeoutExpired("portable tool", 120)
                              for name in (self.HELP, self.TREE)})
        self.export()
        for name in (self.HELP, self.TREE):
            self.assertEqual(self.metadata(name)["exitCode"], 124)
            raw = (self.evidence / f"{name}.log").read_text()
            self.assertIn("partial diagnostic output", raw)
            self.assertIn("COMMAND TIMEOUT after 120 seconds", raw)
            self.processes[name].communicate.assert_called_once_with(timeout=120)
        self.assertEqual(self.interrupt.call_count, 2)
        self.assertEqual(self.popen.call_count, 2)
        self.assert_original_evidence_retained()

    def test_tool_start_error_does_not_mask_result_or_skip_remaining_inspection(self):
        self.failures[self.HELP] = OSError("portable missing tool")
        self.export()
        self.assertIn("Could not retain " + self.HELP, self.output.getvalue())
        self.assertEqual((self.evidence / f"{self.TREE}.log").read_text(), self.raw)
        self.assertEqual(self.popen.call_count, 2)
        self.assert_original_evidence_retained()

    def test_diagnostic_log_or_metadata_write_failure_does_not_stop_other_evidence(self):
        write_text = Path.write_text
        for suffix in ("log", "json"):
            with self.subTest(suffix=suffix):
                for path in self.evidence.glob("xcresult-tests-diagnostic*"):
                    path.unlink()

                def fail_one_write(path, text, *args, **kwargs):
                    if path.name == f"{self.HELP}.{suffix}":
                        raise OSError("portable disk failure")
                    return write_text(path, text, *args, **kwargs)

                with mock.patch.object(Path, "write_text", fail_one_write):
                    self.export()
                self.assertIn("Could not retain " + self.HELP, self.output.getvalue())
                self.assertEqual((self.evidence / f"{self.TREE}.log").read_text(), self.raw)
                if suffix == "json":
                    self.assertEqual((self.evidence / f"{self.HELP}.log").read_text(), self.outputs[self.HELP])
                self.assert_original_evidence_retained()

    def test_genuine_cancellation_is_never_swallowed_or_retried(self):
        for name in (self.HELP, self.TREE):
            for failure in (KeyboardInterrupt(), SystemExit(130), SystemExit(143)):
                with self.subTest(name=name, failure=failure):
                    for path in self.evidence.glob("xcresult-tests-diagnostic*"):
                        path.unlink()
                    self.failures = {name: failure}
                    before = self.popen.call_count
                    with self.assertRaises(type(failure)) as caught:
                        self.export()
                    self.assertIs(caught.exception, failure)
                    self.assertEqual(self.popen.call_count - before, 1 if name == self.HELP else 2)
                    self.assertEqual(self.metadata(name)["exitCode"],
                                     failure.code if isinstance(failure, SystemExit) else 130)
                    self.assertIn("COMMAND CANCELLED", (self.evidence / f"{name}.log").read_text())
                    self.assert_original_evidence_retained()

    def test_malformed_or_unknown_tree_is_retained_verbatim_not_interpreted(self):
        self.outputs[self.TREE] = 'not JSON\n{"unknown schema": true}\n'
        self.export()
        self.assertEqual((self.evidence / f"{self.TREE}.log").read_text(), self.outputs[self.TREE])
        self.assert_original_evidence_retained()

    def test_signal_cancellation_survives_simultaneous_diagnostic_write_error(self):
        write_text = Path.write_text
        previous = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
        for signum in previous:
            for suffix in ("log", "json"):
                with self.subTest(signum=signum, suffix=suffix):
                    for path in self.evidence.glob("xcresult-tests-diagnostic*"):
                        path.unlink()

                    def cancel_during_command(**_kwargs):
                        signal.getsignal(signum)(signum, None)

                    def fail_one_write(path, text, *args, **kwargs):
                        if path.name == f"{self.HELP}.{suffix}":
                            raise OSError("portable disk failure during cancellation")
                        return write_text(path, text, *args, **kwargs)

                    self.failures = {self.HELP: cancel_during_command}
                    before = self.popen.call_count
                    with mock.patch.object(Path, "write_text", fail_one_write), \
                            self.assertRaises(SystemExit) as caught:
                        self.export()
                    self.assertEqual(caught.exception.code, 128 + signum)
                    self.assertEqual(self.popen.call_count, before + 1)
                    self.assertFalse((self.evidence / f"{self.TREE}.log").exists())
                    self.assertEqual({sig: signal.getsignal(sig) for sig in previous}, previous)
                    self.assert_original_evidence_retained()

    def test_interruption_exception_survives_simultaneous_diagnostic_write_error(self):
        write_text = Path.write_text
        previous = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
        for failure in (KeyboardInterrupt(), SystemExit(130), SystemExit(143)):
            for suffix in ("log", "json"):
                with self.subTest(failure=failure, suffix=suffix):
                    for path in self.evidence.glob("xcresult-tests-diagnostic*"):
                        path.unlink()

                    def fail_one_write(path, text, *args, **kwargs):
                        if path.name == f"{self.HELP}.{suffix}":
                            raise OSError("portable disk failure during interruption")
                        return write_text(path, text, *args, **kwargs)

                    self.failures = {self.HELP: failure}
                    before = self.popen.call_count
                    with mock.patch.object(Path, "write_text", fail_one_write), \
                            self.assertRaises(type(failure)) as caught:
                        self.export()
                    self.assertIs(caught.exception, failure)
                    self.assertEqual(self.popen.call_count, before + 1)
                    self.assertFalse((self.evidence / f"{self.TREE}.log").exists())
                    self.assertEqual({sig: signal.getsignal(sig) for sig in previous}, previous)
                    self.assert_original_evidence_retained()

    def test_runner_ordinary_write_failure_still_raises_without_cancellation(self):
        write_text = Path.write_text
        for suffix in ("log", "json"):
            for exit_code in (0, 64, 124):
                with self.subTest(suffix=suffix, exit_code=exit_code):
                    failure = OSError("portable ordinary write failure")
                    self.codes[self.TREE] = exit_code

                    def fail_one_write(path, text, *args, **kwargs):
                        if path.name == f"{self.TREE}.{suffix}":
                            raise failure
                        return write_text(path, text, *args, **kwargs)

                    with mock.patch.object(Path, "write_text", fail_one_write), \
                            redirect_stdout(self.output), self.assertRaises(OSError) as caught:
                        self.real_run(self.TREE, ["xcrun", "xcresulttool", "get", "test-results",
                                                 "tests", "--path", "portable-bundle"], check=False)
                    self.assertIs(caught.exception, failure)

    def test_captured_interruption_survives_secondary_cleanup_error(self):
        previous = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
        for failure in (KeyboardInterrupt(), SystemExit(130), SystemExit(143)):
            for cleanup_error in (OSError("portable cleanup failure"), RuntimeError("portable cleanup failure")):
                with self.subTest(failure=failure, cleanup_error=cleanup_error):
                    self.failures = {self.HELP: failure}
                    self.interrupt.side_effect = cleanup_error
                    before = self.popen.call_count
                    with self.assertRaises(type(failure)) as caught:
                        self.export()
                    self.assertIs(caught.exception, failure)
                    self.assertIs(caught.exception.__context__, cleanup_error)
                    self.assertEqual(self.popen.call_count, before + 1)
                    self.assertFalse((self.evidence / f"{self.HELP}.json").exists())
                    self.assertFalse((self.evidence / f"{self.TREE}.log").exists())
                    self.assertEqual({sig: signal.getsignal(sig) for sig in previous}, previous)
                    self.assert_original_evidence_retained()

    def test_timeout_cleanup_failure_is_not_reclassified_as_cancellation(self):
        self.failures = {self.TREE: subprocess.TimeoutExpired("portable tool", 120)}
        failure = OSError("portable timeout cleanup failure")
        self.interrupt.side_effect = failure
        with redirect_stdout(self.output), self.assertRaises(OSError) as caught:
            self.real_run(self.TREE, ["xcrun", "xcresulttool", "get", "test-results",
                                     "tests", "--path", "portable-bundle"], check=False)
        self.assertIs(caught.exception, failure)


if __name__ == "__main__":
    unittest.main()

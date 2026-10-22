"""Portable execution-proof regressions. No Simulator, xcodebuild or native tests.

The two-case fixture is an exact tree excerpt from inspection run 39687967408,
not synthetic native evidence. Generated cases below exercise the parser only.
"""
from contextlib import nullcontext
import copy
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest import mock
from urllib.parse import quote

import native_quality as quality

FIXTURE = Path(__file__).with_name("fixtures") / "xcresult-tests-xcode16.4-excerpt.json"
MISSING_METHOD = "LessonIntroViewTests/testCurrentQuestionExplanationUsesTheFullSurfaceWithoutAnAnswerFooter"
CORRUPTED_CONSOLE = (
    "Test Case '-[LessonIntroViewTests testCurrentQuestionExplanationUsesTheFullSurfaceWithout"
    "2026-10-21 22:11:52.197591+0000 Calcu Later[5017:20086] [catalog] Query for "
    "com.apple.MobileAsset.VoiceServicesVocalizerVoice failed: 2\n"
    "AnAnswerFooter]' passed (0.009 seconds).\n"
)


def fixture():
    return json.loads(FIXTURE.read_text())


def inventory(data):
    return {case["nodeIdentifier"]: bundle["name"]
            for bundle in data["testNodes"][0]["children"]
            for suite in bundle["children"] for case in suite["children"]}


def owned_environment(data):
    device = data["devices"][0]
    owned = {"udid": device["deviceId"], "name": device["deviceName"], "scenario": "standard",
             "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
             "runtime": "com.apple.CoreSimulator.SimRuntime.iOS-18-5"}
    environment = {"scenario": "standard", "ownedSimulatorUDID": owned["udid"],
                   "architecture": device["architecture"],
                   "deviceType": {"identifier": owned["deviceType"], "name": device["modelName"]},
                   "runtime": {"identifier": owned["runtime"], "version": device["osVersion"],
                               "buildversion": device["osBuildNumber"]}}
    return owned, environment


def generated_tree(required):
    """Generate parser input, never a native acceptance result."""
    data = fixture()
    data["testNodes"][0]["children"] = []

    def url(*parts):
        return "test://com.apple.xcode/" + "/".join(quote(part, safe="") for part in (quality.SCHEME, *parts))

    for target in sorted(set(required.values())):
        bundle = {"name": target, "nodeType": quality.TEST_BUNDLE_TYPES[target], "result": "Passed",
                  "nodeIdentifierURL": url(target), "children": []}
        for class_name in sorted({method.split("/")[0] for method, t in required.items() if t == target}):
            suite = {"name": class_name, "nodeType": "Test Suite", "result": "Passed",
                     "nodeIdentifierURL": url(target, class_name), "children": []}
            for identifier, t in sorted(required.items()):
                if t != target or identifier.split("/")[0] != class_name:
                    continue
                method = identifier.split("/")[1]
                suite["children"].append({"name": method, "nodeIdentifier": identifier,
                    "nodeIdentifierURL": url(target, class_name, method), "nodeType": "Test Case",
                    "result": "Passed", "duration": "0.001s", "durationInSeconds": 0.001})
            bundle["children"].append(suite)
        data["testNodes"][0]["children"].append(bundle)
    return data


class StructuredTests(unittest.TestCase):
    def setUp(self):
        self.data = fixture()
        self.required = inventory(self.data)
        self.device = copy.deepcopy(self.data["devices"][0])

    def report(self, data=None):
        return quality.structured_execution_report(json.dumps(self.data if data is None else data),
                                                   self.required, self.device)

    def case(self):
        return self.data["testNodes"][0]["children"][0]["children"][0]["children"][0]

    def test_exact_captured_excerpt(self):
        result = self.report()
        self.assertEqual(result["status"], "verified")
        self.assertEqual(len(result["observedTests"]), 2)
        self.assertIn(MISSING_METHOD, result["observedPassedTests"])
        self.assertEqual(result["requiredTestTargets"][MISSING_METHOD], "Calcu LaterTests")

    def test_missing_case_is_not_inferred_from_passing_ancestors(self):
        self.data["testNodes"][0]["children"][0]["children"][0]["children"] = []
        result = self.report()
        self.assertEqual(result["status"], "rejected")
        self.assertIn(MISSING_METHOD, result["missingPassedTests"])

    def test_individual_missing_method_fails_even_with_complete_passing_containers(self):
        required = {"ExampleTests/testOne": "Calcu LaterTests", "ExampleTests/testTwo": "Calcu LaterTests"}
        data = generated_tree(required)
        data["testNodes"][0]["children"][0]["children"][0]["children"].pop(0)
        result = quality.structured_execution_report(json.dumps(data), required, self.device)
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(result["errors"], [])
        self.assertEqual(result["nonPassingNodes"], [])
        self.assertEqual(result["missingPassedTests"], ["ExampleTests/testOne"])

    def test_every_nonpassed_or_absent_case_status_is_rejected(self):
        for status in ("Failed", "Skipped", "Expected Failure", "unknown", "passed", "Not Run", None, True, {}):
            with self.subTest(status=status):
                self.case()["result"] = status
                result = self.report()
                self.assertEqual(result["status"], "rejected")
                self.assertIn(MISSING_METHOD, result["missingPassedTests"])
        del self.case()["result"]
        self.assertEqual(self.report()["status"], "rejected")

    def test_nonpassing_containers_cannot_hide_behind_passed_cases(self):
        for depth in range(3):
            with self.subTest(depth=depth):
                self.data = fixture()
                node = self.data["testNodes"][0]
                for _ in range(depth):
                    node = node["children"][0]
                node["result"] = "Failed"
                result = self.report()
                self.assertEqual(result["status"], "rejected")
                self.assertTrue(result["nonPassingNodes"])

    def test_duplicate_case_is_not_a_pass(self):
        self.data["testNodes"][0]["children"][0]["children"][0]["children"].append(copy.deepcopy(self.case()))
        result = self.report()
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(result["duplicateTests"], ["Calcu LaterTests/" + MISSING_METHOD])

    def test_duplicate_plan_bundle_and_suite_are_rejected(self):
        for level in ("plan", "bundle", "suite"):
            with self.subTest(level=level):
                self.data = fixture()
                children = self.data["testNodes"]
                if level != "plan":
                    children = children[0]["children"]
                if level == "suite":
                    children = children[0]["children"]
                children.append(copy.deepcopy(children[0]))
                self.assertEqual(self.report()["status"], "rejected")

    def test_extra_method_is_not_ignored(self):
        case = self.case()
        extra = copy.deepcopy(case)
        extra["name"] = "testUnselected"
        extra["nodeIdentifier"] = "LessonIntroViewTests/testUnselected"
        extra["nodeIdentifierURL"] = case["nodeIdentifierURL"].rsplit("/", 1)[0] + "/testUnselected"
        self.data["testNodes"][0]["children"][0]["children"][0]["children"].append(extra)
        result = self.report()
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(result["unexpectedTests"], ["Calcu LaterTests/LessonIntroViewTests/testUnselected"])

    def test_same_method_in_wrong_bundle_is_not_accepted(self):
        plan = self.data["testNodes"][0]
        suite = plan["children"][0]["children"].pop()
        for node in (suite, *suite["children"]):
            node["nodeIdentifierURL"] = node["nodeIdentifierURL"].replace("Calcu%20LaterTests/", "Calcu%20LaterUITests/")
        plan["children"][1]["children"].append(suite)
        result = self.report()
        self.assertEqual(result["status"], "rejected")
        self.assertIn(MISSING_METHOD, result["missingPassedTests"])
        self.assertIn("Calcu LaterUITests/" + MISSING_METHOD, result["unexpectedTests"])

    def test_all_identifiers_must_agree(self):
        mutations = ((0, "name", "Other Scheme"), (1, "nodeType", "UI test bundle"),
                     (1, "name", "UnknownTests"), (1, "nodeIdentifierURL", "test://other/bundle"),
                     (2, "name", "OtherClass"), (2, "nodeIdentifierURL", "test://other/suite"),
                     (3, "name", "testOther"), (3, "nodeIdentifier", "OtherClass/testOther"),
                     (3, "nodeIdentifierURL", "test://other/case"))
        for depth, field, value in mutations:
            with self.subTest(depth=depth, field=field):
                self.data = fixture()
                node = self.data["testNodes"][0]
                for _ in range(depth):
                    node = node["children"][0]
                node[field] = value
                self.assertEqual(self.report()["status"], "rejected")

    def test_each_device_field_is_owned_and_exact(self):
        for field in self.device:
            with self.subTest(field=field):
                self.data = fixture()
                self.data["devices"][0][field] = "wrong"
                self.assertEqual(self.report()["status"], "rejected")
        for value in ([], [self.device, self.device], {}, None):
            with self.subTest(devices=value):
                self.data["devices"] = value
                self.assertEqual(self.report()["status"], "rejected")

    def test_configuration_is_single_and_exact(self):
        expected = self.data["testPlanConfigurations"][0]
        for value in ([], [expected, expected], [{**expected, "configurationId": "2"}],
                      [{**expected, "configurationName": "Other"}], [{**expected, "extra": True}], None):
            with self.subTest(configurations=value):
                self.data["testPlanConfigurations"] = value
                self.assertEqual(self.report()["status"], "rejected")

    def test_missing_extra_and_wrong_typed_fields_fail_closed(self):
        for depth in range(5):
            for operation in ("missing", "extra", "children-not-array"):
                with self.subTest(depth=depth, operation=operation):
                    self.data = fixture()
                    node = self.data if depth == 0 else self.data["testNodes"][0]
                    for _ in range(max(0, depth - 1)):
                        node = node["children"][0]
                    if operation == "missing":
                        del node[next(iter(node))]
                    elif operation == "extra":
                        node["unreviewedField"] = True
                    else:
                        node["children" if depth else "testNodes"] = {}
                    self.assertEqual(self.report()["status"], "rejected")

    def test_unreviewed_node_wrappers_and_runs_fail_closed(self):
        for node_type in ("Device", "Test Plan Configuration", "Arguments", "Repetition", "Test Case Run",
                          "Failure Message", "Source Code Reference", "Attachment", "Expression", "Test Value"):
            with self.subTest(node_type=node_type):
                self.data = fixture()
                case = copy.deepcopy(self.case())
                wrapper = {"nodeType": node_type, "name": case["name"], "result": "Passed", "children": [case]}
                self.data["testNodes"][0]["children"][0]["children"][0]["children"] = [wrapper]
                self.assertEqual(self.report()["status"], "rejected")
        self.data = fixture()
        self.case()["children"] = [{"nodeType": "Test Case Run", "result": "Failed", "name": "first attempt"}]
        self.assertEqual(self.report()["status"], "rejected")

    def test_bad_json_duplicate_fields_and_nonstandard_numbers_fail_closed(self):
        raw = FIXTURE.read_text()
        for value in ("", "garbled", "[]", "null", raw + " trailing", raw.replace('"devices":', '"devices": [], "devices":', 1),
                      raw.replace('"durationInSeconds":', '"durationInSeconds": NaN, "ignored":', 1)):
            with self.subTest(raw=value[:30]):
                result = quality.structured_execution_report(value, self.required, self.device)
                self.assertEqual(result["status"], "rejected")
                self.assertTrue(result["errors"])

    def test_invalid_duration_fields_are_not_silently_accepted(self):
        for value in (None, True, "0.1", -1, float("inf"), float("nan")):
            with self.subTest(duration=value):
                self.case()["durationInSeconds"] = value
                self.assertEqual(self.report()["status"], "rejected")

    def test_empty_inventory_and_summary_counts_are_not_proof(self):
        result = quality.structured_execution_report(json.dumps(self.data), {}, self.device)
        self.assertEqual(result["status"], "rejected")
        result = quality.structured_execution_report('{"passedTests":248,"failedTests":0,"skippedTests":0}',
                                                     self.required, self.device)
        self.assertEqual(result["status"], "rejected")


class CollectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.evidence = Path(self.temp.name)
        self.data = fixture()
        self.required = inventory(self.data)
        self.owned, self.environment = owned_environment(self.data)
        (self.evidence / "environment.json").write_text(json.dumps(self.environment))
        self.addCleanup(mock.patch.stopall)
        mock.patch.object(quality, "EVIDENCE", self.evidence).start()
        self.selected = quality.SCENARIOS["standard"]

    def verify(self, console=CORRUPTED_CONSOLE):
        quality.verify_test_execution(console, self.required, self.owned, "standard", self.selected)
        return json.loads((self.evidence / "test-execution.json").read_text())

    def test_interleaved_console_does_not_overrule_exact_structured_proof(self):
        with mock.patch.object(quality, "run", side_effect=["captured tool help", json.dumps(self.data)]) as run:
            result = self.verify()
        self.assertEqual(result["status"], "verified")
        self.assertFalse(result["consoleComparison"]["authoritative"])
        self.assertIn(MISSING_METHOD, result["consoleComparison"]["missingPassedTests"])
        self.assertEqual(result["missingPassedTests"], [])
        self.assertEqual(run.call_args_list, [
            mock.call("xcresult-tests-help", ["xcrun", "xcresulttool", "help", "get", "test-results", "tests"]),
            mock.call("xcresult-tests", ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", "build/Tests.xcresult"])])

    def test_perfect_console_cannot_replace_missing_structured_result(self):
        console = "".join(f"Test Case '-[{method.replace('/', ' ')}]' passed (0.001 seconds).\n" for method in self.required)
        for raw in ("{}", "not JSON", '{"passedTests":248,"failedTests":0,"skippedTests":0}'):
            with self.subTest(raw=raw), mock.patch.object(quality, "run", side_effect=["help", raw]):
                with self.assertRaises(SystemExit):
                    self.verify(console)
                result = json.loads((self.evidence / "test-execution.json").read_text())
                self.assertEqual(result["status"], "failed")
                self.assertEqual(result["consoleComparison"]["missingPassedTests"], [])
                self.assertTrue(result["errors"])

    def test_probe_failure_timeout_and_cancellation_are_not_retried_or_masked(self):
        for phase, before in (("tool-help", []), ("structured-results", ["help"])):
            for failure in (SystemExit(64), SystemExit(124), SystemExit(130), SystemExit(143), KeyboardInterrupt(), OSError("tool absent")):
                with self.subTest(phase=phase, failure=failure), mock.patch.object(quality, "run", side_effect=before + [failure]) as run:
                    with self.assertRaises(type(failure)) as caught:
                        self.verify()
                    self.assertIs(caught.exception, failure)
                    self.assertEqual(run.call_count, len(before) + 1)
                    result = json.loads((self.evidence / "test-execution.json").read_text())
                    self.assertEqual(result["failedPhase"], phase)
                    self.assertEqual(result["status"], "failed")
                    self.assertFalse(result["automaticRetryAllowed"])

    def test_owned_environment_mismatch_blocks_probes(self):
        for change in ("udid", "scenario", "device", "runtime"):
            with self.subTest(change=change):
                environment = copy.deepcopy(self.environment)
                if change == "udid":
                    environment["ownedSimulatorUDID"] = "other"
                elif change == "scenario":
                    environment["scenario"] = "compact"
                elif change == "device":
                    environment["deviceType"]["identifier"] = "other"
                else:
                    environment["runtime"]["identifier"] = "other"
                (self.evidence / "environment.json").write_text(json.dumps(environment))
                with mock.patch.object(quality, "run") as run, self.assertRaises(ValueError):
                    self.verify()
                run.assert_not_called()

    def test_xcodebuild_nonzero_or_cancelled_never_reaches_proof_gate(self):
        configuration = {"status": "verified", "scenario": "standard", "ownedSimulatorUDID": self.owned["udid"],
                         "observedContentSize": self.selected["contentSize"]}
        (self.evidence / "scenario-configuration.json").write_text(json.dumps(configuration))
        for failure in (SystemExit(65), SystemExit(124), SystemExit(130), KeyboardInterrupt()):
            with self.subTest(failure=failure), \
                    mock.patch.object(quality, "scenario", return_value=("standard", self.selected)), \
                    mock.patch.object(quality, "required_test_inventory", return_value=self.required), \
                    mock.patch.object(quality, "state", return_value=self.owned), \
                    mock.patch.object(quality, "build_arguments", return_value=["xcodebuild"]), \
                    mock.patch.object(quality, "record_native_video", return_value=nullcontext()), \
                    mock.patch.object(quality, "run", side_effect=failure) as run, \
                    mock.patch.object(quality, "verify_test_execution") as verify:
                with self.assertRaises(type(failure)) as caught:
                    quality.test()
                self.assertIs(caught.exception, failure)
                run.assert_called_once()
                self.assertEqual(run.call_args.kwargs["timeout"], 900)
                verify.assert_not_called()

    def test_xcodebuild_success_reaches_one_structured_gate_without_native_retry(self):
        configuration = {"status": "verified", "scenario": "standard", "ownedSimulatorUDID": self.owned["udid"],
                         "observedContentSize": self.selected["contentSize"]}
        (self.evidence / "scenario-configuration.json").write_text(json.dumps(configuration))
        with mock.patch.object(quality, "scenario", return_value=("standard", self.selected)), \
                mock.patch.object(quality, "required_test_inventory", return_value=self.required), \
                mock.patch.object(quality, "state", return_value=self.owned), \
                mock.patch.object(quality, "build_arguments", return_value=["xcodebuild"]), \
                mock.patch.object(quality, "record_native_video", return_value=nullcontext()), \
                mock.patch.object(quality, "run", return_value=CORRUPTED_CONSOLE) as run, \
                mock.patch.object(quality, "verify_test_execution") as verify:
            quality.test()
        run.assert_called_once()
        self.assertEqual(run.call_args.kwargs["timeout"], 900)
        verify.assert_called_once_with(CORRUPTED_CONSOLE, self.required, self.owned, "standard", self.selected)


class SourceInventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        patch = mock.patch.object(quality, "ROOT", self.root)
        patch.start()
        self.addCleanup(patch.stop)
        self.write_source("Calcu LaterTests", "ExampleTests", ["testOne", "testTwo"])
        self.write_source("Calcu LaterUITests", "ExampleUITests", ["testTap"])

    def write_source(self, target, class_name, methods, subdir=""):
        path = self.root / target / subdir / f"{class_name}.m"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"@implementation {class_name}\n" + "".join(f"- (void){method} {{}}\n" for method in methods) + "@end\n")
        return path

    def test_target_class_and_method_filters_keep_exact_source_bundle(self):
        expected = {"ExampleTests/testOne": "Calcu LaterTests", "ExampleTests/testTwo": "Calcu LaterTests",
                    "ExampleUITests/testTap": "Calcu LaterUITests"}
        self.assertEqual(quality.required_test_inventory(["Calcu LaterTests", "Calcu LaterUITests/ExampleUITests"]), expected)
        self.assertEqual(quality.required_test_methods(["Calcu LaterTests/ExampleTests/testTwo"]), ["ExampleTests/testTwo"])

    def test_missing_empty_and_unsupported_selections_fail_without_fallback(self):
        for selected in ([], [""], ["OtherTests"], ["Calcu LaterTests/../ExampleTests"],
                         ["Calcu LaterTests/MissingTests"], ["Calcu LaterTests/ExampleTests/testAbsent"],
                         ["Calcu LaterTests/ExampleTests/testOne/extra"], ["Calcu LaterTests/1Invalid"]):
            with self.subTest(selected=selected), self.assertRaises(SystemExit):
                quality.required_test_inventory(selected)
        (self.root / "Calcu LaterTests/ExampleTests.m").write_text("@implementation ExampleTests\n@end\n")
        with self.assertRaises(SystemExit):
            quality.required_test_inventory(["Calcu LaterTests"])

    def test_overlapping_and_ambiguous_source_methods_fail(self):
        for selected in (["Calcu LaterTests", "Calcu LaterTests/ExampleTests"],
                         ["Calcu LaterTests/ExampleTests/testOne", "Calcu LaterTests/ExampleTests/testOne"]):
            with self.subTest(selected=selected), self.assertRaises(SystemExit):
                quality.required_test_inventory(selected)
        self.write_source("Calcu LaterUITests", "ExampleTests", ["testOne"])
        with self.assertRaises(SystemExit):
            quality.required_test_inventory(["Calcu LaterTests", "Calcu LaterUITests"])
        self.write_source("Calcu LaterTests", "ExampleTests", ["testThree"], "nested")
        with self.assertRaises(SystemExit):
            quality.required_test_inventory(["Calcu LaterTests"])

    def test_duplicate_method_or_implementation_fails(self):
        path = self.write_source("Calcu LaterTests", "ExampleTests", ["testOne", "testOne"])
        with self.assertRaises(SystemExit):
            quality.required_test_inventory(["Calcu LaterTests"])
        path.write_text("@implementation ExampleTests\n- (void)testOne {}\n@end\n" * 2)
        with self.assertRaises(SystemExit):
            quality.required_test_inventory(["Calcu LaterTests"])


class RepositorySelectionTests(unittest.TestCase):
    EXPECTED_COUNTS = {
        "components": 416, "standard": 15, "compact": 9, "tablet": 9, "maximumAccessibilityText": 9,
        "focusedGroupingCompact": 4, "focusedGroupingMaximumText": 4,
        "conceptCore": 4, "conceptDivision": 1,
        "conceptCoreMaximumText": 4, "conceptDivisionMaximumText": 1,
        "reducedMotion": 1,
    }

    def test_current_source_filters_round_trip_generated_schema_not_native_execution(self):
        self.assertEqual(set(quality.SCENARIOS), set(self.EXPECTED_COUNTS))
        for name, scenario in quality.SCENARIOS.items():
            with self.subTest(scenario=name):
                required = quality.required_test_inventory(scenario["onlyTesting"])
                self.assertEqual(len(required), self.EXPECTED_COUNTS[name])
                self.assertEqual(set(required.values()), {"Calcu LaterTests"}
                                 if name == "components" else {"Calcu LaterUITests"})
                data = generated_tree(required)
                result = quality.structured_execution_report(json.dumps(data), required, data["devices"][0])
                self.assertEqual(result["status"], "verified")
                self.assertEqual(len(result["observedTests"]), len(required))

    def test_all_source_methods_are_selected_except_the_unchanged_launch_boilerplate(self):
        all_source = quality.required_test_inventory(list(quality.TEST_BUNDLE_TYPES))
        selected = set()
        for scenario in quality.SCENARIOS.values():
            selected.update(quality.required_test_inventory(scenario["onlyTesting"]))
        # The original acceptance deliberately excludes repetitive launch-only
        # boilerplate, not any teaching, layout, model or user-navigation method.
        excluded = {"Calcu_LaterUITestsLaunchTests/testLaunch"}
        self.assertTrue(excluded.issubset(all_source))
        self.assertEqual(selected, set(all_source) - excluded)
        self.assertEqual(len(selected), 447)
        self.assertEqual(sum(self.EXPECTED_COUNTS.values()), 477)

    def test_preserved_baseline_and_new_ui_classes_have_exact_selection_coverage(self):
        standard = quality.required_test_inventory(quality.SCENARIOS["standard"]["onlyTesting"])
        components = quality.required_test_inventory(quality.SCENARIOS["components"]["onlyTesting"])
        self.assertFalse(set(components).intersection(standard))
        self.assertEqual(components, quality.required_test_inventory(["Calcu LaterTests"]))
        self.assertEqual(standard, quality.required_test_inventory([
            "Calcu LaterUITests/Calcu_LaterUITests"]))
        self.assertEqual(dict(components, **standard), quality.required_test_inventory([
            "Calcu LaterTests", "Calcu LaterUITests/Calcu_LaterUITests"]))
        layout = quality.required_test_inventory([
            "Calcu LaterUITests/Calcu_LaterLayoutUITests"] + quality.TEN_FRAME_TESTS)
        for name in ("compact", "tablet", "maximumAccessibilityText"):
            self.assertEqual(quality.required_test_inventory(quality.SCENARIOS[name]["onlyTesting"]), layout)
        grouping = quality.required_test_inventory(["Calcu LaterUITests/GroupingFocusedActionUITests"])
        for name in ("focusedGroupingCompact", "focusedGroupingMaximumText"):
            self.assertEqual(quality.required_test_inventory(quality.SCENARIOS[name]["onlyTesting"]), grouping)
        concept = quality.required_test_inventory(["Calcu LaterUITests/ConceptDiscoveryUITests"])
        for suffix in ("", "MaximumText"):
            core = quality.required_test_inventory(quality.SCENARIOS["conceptCore" + suffix]["onlyTesting"])
            division = quality.required_test_inventory(quality.SCENARIOS["conceptDivision" + suffix]["onlyTesting"])
            self.assertFalse(set(core).intersection(division))
            self.assertEqual(dict(core, **division), concept)

    def test_real_reduce_motion_is_selected_only_on_its_owned_settings_lane(self):
        expected = quality.required_test_inventory(["Calcu LaterUITests/ReducedMotionTeachingUITests"])
        for name, scenario in quality.SCENARIOS.items():
            selected = quality.required_test_inventory(scenario["onlyTesting"])
            if name == "reducedMotion":
                self.assertEqual(selected, expected)
                self.assertEqual(scenario["contentSize"], "large")
                intent = scenario["systemSettingsIntent"]["reduceMotion"]
                self.assertEqual(intent["mechanism"], "Settings UI")
                self.assertEqual(intent["requested"], "on")
                self.assertNotIn("verified", intent)
            else:
                self.assertFalse(set(selected).intersection(expected))
                self.assertNotIn("systemSettingsIntent", scenario)

    def test_workflow_matches_reviewed_devices_and_does_not_expand_runner_bounds(self):
        workflow = (quality.ROOT / ".github/workflows/ios-quality.yml").read_text()
        pairs = re.findall(r"^          - scenario: (\w+)\n            device_type: ([\w.-]+)$", workflow, re.MULTILINE)
        self.assertEqual(len(pairs), len(quality.SCENARIOS))
        self.assertEqual(dict(pairs), {name: value["deviceType"] for name, value in quality.SCENARIOS.items()})
        self.assertIn("max-parallel: 2", workflow)
        self.assertIn("timeout-minutes: 35", workflow)
        self.assertIn("runs-on: macos-15", workflow)
        self.assertIn("if: github.event.repository.private == false", workflow)
        self.assertIn("cancel-in-progress: false", workflow)
        self.assertEqual(quality.TEST_TIMEOUT, 900)
        maximum = {"maximumAccessibilityText", "focusedGroupingMaximumText",
                   "conceptCoreMaximumText", "conceptDivisionMaximumText"}
        compact = {"compact", "focusedGroupingCompact"}
        for name, scenario in quality.SCENARIOS.items():
            self.assertEqual(scenario["contentSize"],
                             "accessibility-extra-extra-extra-large" if name in maximum else "large")
            device = ("iPhone-SE-3rd-generation" if name in compact
                      else "iPad-10th-generation" if name in {"tablet", "components"} else "iPhone-16")
            self.assertEqual(scenario["deviceType"], "com.apple.CoreSimulator.SimDeviceType." + device)


if __name__ == "__main__":
    unittest.main()

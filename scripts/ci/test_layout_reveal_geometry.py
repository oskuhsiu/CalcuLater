"""Portable source/arithmetic contracts for the Settings reveal helper.

These do not execute UIKit/XCUITest or establish native reachability. The recorded
rectangles come from run 39693320883's named AX5 hierarchy attachments, not the
cached automatic UI Snapshot archives. A small Python model checks the selected
travel policy; source contracts below ensure its constants/conditions still match.
"""
import math
from pathlib import Path
import re
import unittest

SOURCE = (Path(__file__).resolve().parents[2]
          / "Calcu LaterUITests/Calcu_LaterLayoutUITests.m").read_text()
REVEAL = SOURCE.split("- (void)reveal:", 1)[1].split("- (void)tapHomeCard:", 1)[0]
SMALL = float(re.search(r"CGFloat travelFraction = ([0-9.]+);", REVEAL)[1])
FAR = float(re.search(r"if \(farTableRow\) travelFraction = ([0-9.]+);", REVEAL)[1])


def plan(viewport_y, height, target_y=None, target_height=None, *, table_row=True,
         down=False, adaptive=True):
    """Arithmetic model only. Returns signed request, travel, endpoints and cap."""
    distance = (-1 if down else 1) * height * SMALL
    fraction = SMALL
    valid = (target_y is not None and target_height is not None
             and math.isfinite(target_y) and math.isfinite(target_height)
             and target_height > 0)
    if valid:
        distance = target_y + target_height / 2 - (viewport_y + height / 2)
        if abs(distance) < 1:
            distance = -24 if down else 24
        far = (target_y > viewport_y + height + height * SMALL
               or target_y + target_height < viewport_y - height * SMALL)
        if adaptive and table_row and far:
            fraction = FAR
    travel = min(max(abs(distance), 24), height * fraction)
    start = viewport_y + height * (0.65 if distance > 0 else 0.35)
    end = start + (-travel if distance > 0 else travel)
    return distance, travel, start, end, fraction


class RevealSourceContractTests(unittest.TestCase):
    def test_limit_direction_and_strict_hittability_are_preserved(self):
        self.assertIn("attempt < 10 && !element.hittable", REVEAL)
        self.assertIn("distance = CGRectGetMidY(target) - CGRectGetMidY(viewport);", REVEAL)
        self.assertIn('XCTAssertTrue(element.hittable, @"A child must be able to reach %@ by scrolling."', REVEAL)
        self.assertIn("pressForDuration:0.05 thenDragToCoordinate:end", REVEAL)
        self.assertNotIn("sleep", REVEAL)
        self.assertNotIn(" tap]", REVEAL)

    def test_adaptation_requires_valid_current_table_row_geometry(self):
        contract = " ".join(REVEAL.split())
        self.assertIn("if (hasGeometry) {", contract)
        self.assertIn("BOOL farTableRow = container.elementType == XCUIElementTypeTable "
                      "&& scrollTarget.elementType == XCUIElementTypeCell "
                      "&& (CGRectGetMinY(target) > CGRectGetMaxY(viewport) + viewport.size.height * 0.3 "
                      "|| CGRectGetMaxY(target) < CGRectGetMinY(viewport) - viewport.size.height * 0.3);", contract)
        self.assertIn("[container.cells containingType:XCUIElementTypeAny identifier:element.identifier].firstMatch", contract)
        self.assertIn("if (row.exists) scrollTarget = row;", contract)
        self.assertIn("target = scrollTarget.frame;", contract)
        self.assertIn("MIN(MAX(fabs(distance), 24), viewport.size.height * travelFraction)", contract)
        self.assertIn("(distance > 0 ? 0.65 : 0.35)", contract)
        self.assertIn("startY + (distance > 0 ? -travel : travel)", contract)
        self.assertEqual((SMALL, FAR), (0.3, 0.5))

    def test_trace_records_geometry_not_an_inferred_native_pass(self):
        for key in ("attempt=", "identifier=", "viewport=", "targetBefore=", "targetAfter=",
                    "requested=", "travel=", "fraction=", "startY=", "endY=", "hittable="):
            self.assertIn(key, REVEAL)
        self.assertIn('trace.name = @"settings-reveal-scroll";', REVEAL)
        self.assertIn("trace.lifetime = XCTAttachmentLifetimeKeepAlways;", REVEAL)
        self.assertIn("Selection survives a real app relaunch.", SOURCE)
        self.assertIn("A family cannot accidentally disable every operation.", SOURCE)


class RevealArithmeticTests(unittest.TestCase):
    def test_recorded_far_addition_row_has_more_travel_without_more_attempts(self):
        # 4A51448A-9EC7-4ECA-AB12-ABA267286F65.txt: viewport y69/h783,
        # addition row y2829.7/h219. Child switch x0/y-1166.3 is not usable.
        old = plan(69, 783, 2829.7, 219, adaptive=False)
        new = plan(69, 783, 2829.7, 219)
        self.assertAlmostEqual(old[1], 234.9)
        self.assertAlmostEqual(new[1], 391.5)
        self.assertEqual(new[4], 0.5)
        self.assertGreater(new[0], 0)
        self.assertAlmostEqual(10 * old[1], 2349)
        self.assertAlmostEqual(10 * new[1], 3915)

    def test_recorded_failure_keeps_the_small_correction(self):
        # 658F73E6-3BB2-4FFA-B1D5-BF9EA821D357.txt: row y705/h219,
        # actual switch y857.3/h31 remains below the 852-point screen.
        self.assertGreater(857.3, 852)
        self.assertEqual(plan(69, 783, 705, 219), plan(69, 783, 705, 219, adaptive=False))
        self.assertEqual(plan(69, 783, 705, 219)[4], 0.3)

    def test_illustrative_measured_loss_model_fits_the_same_ten_drag_budget(self):
        # This deliberately simple model is not a Simulator reproduction. The
        # measured difference includes touch/scroll behavior AND self-sizing.
        loss = 234.9 - (2829.7 - 705) / 10

        def model(adaptive):
            row_y = 2829.7
            fractions = []
            for _ in range(10):
                distance, travel, _, _, fraction = plan(69, 783, row_y, 219, adaptive=adaptive)
                row_y -= math.copysign(max(0, travel - loss), distance)
                fractions.append(fraction)
                if row_y + 152.3 + 31 <= 852:
                    break
            return row_y, fractions

        old_y, old_fractions = model(False)
        new_y, new_fractions = model(True)
        self.assertAlmostEqual(old_y, 705)
        self.assertEqual(len(old_fractions), 10)
        self.assertEqual(new_fractions, [0.5] * 5 + [0.3] * 2)
        self.assertLess(new_y + 152.3 + 31, 852)

    def test_non_table_and_missing_geometry_keep_the_old_policy(self):
        for y in (-5000, -10, 100, 5000):
            self.assertEqual(plan(40, 627, y, 219, table_row=False),
                             plan(40, 627, y, 219, table_row=False, adaptive=False))
        for y, height in ((None, None), (float("nan"), 219), (0, 0), (0, float("inf"))):
            for down in (False, True):
                self.assertEqual(plan(40, 627, y, height, down=down),
                                 plan(40, 627, y, height, down=down, adaptive=False))

    def test_approach_boundary_and_overshoot_reverse_without_large_near_drags(self):
        for height in (45, 320, 627, 783, 1024, 1366):
            y = 40
            below = y + height * 1.3
            above_end = y - height * 0.3
            self.assertEqual(plan(y, height, below, 100)[4], SMALL)
            self.assertEqual(plan(y, height, below + 0.01, 100)[4], FAR)
            self.assertEqual(plan(y, height, above_end - 100, 100)[4], SMALL)
            self.assertEqual(plan(y, height, above_end - 100.01, 100)[4], FAR)
            # Geometry, not the original direction hint, controls a reversal.
            self.assertLess(plan(y, height, y - 110, 100, down=False)[0], 0)
            self.assertGreater(plan(y, height, y + height + 10, 100, down=True)[0], 0)
            # A tall row spanning the viewport is never a far row.
            self.assertEqual(plan(y, height, y - height, height * 3)[4], SMALL)

    def test_drag_endpoints_stay_inside_short_and_tall_viewports(self):
        for y in (-30, 0, 40, 69, 120):
            for height in (45, 160, 320, 627, 783, 1024, 1366):
                for target_y in (-5000, y - height, y, y + height / 2, y + height, 6000):
                    for target_height in (31, 219, height * 2):
                        distance, travel, start, end, _ = plan(y, height, target_y, target_height)
                        self.assertGreater(travel, 0)
                        self.assertLessEqual(travel, height * 0.5)
                        self.assertLessEqual(y, min(start, end))
                        self.assertLessEqual(max(start, end), y + height)
                        self.assertEqual(math.copysign(1, distance), math.copysign(1, start - end))


if __name__ == "__main__":
    unittest.main()

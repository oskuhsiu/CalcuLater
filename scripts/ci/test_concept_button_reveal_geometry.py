"""Portable contracts for fully visible concept controls before tapping.

The geometry checks cover clipping boundaries and bounded drag directions.
They do not establish UIKit gesture response or actual control activation.
"""
from pathlib import Path
import math
import re
import unittest

SOURCE = (Path(__file__).resolve().parents[2]
          / "Calcu LaterUITests/ConceptDiscoveryUITests.m").read_text()
REVEAL = SOURCE.split("- (void)revealConceptButton:", 1)[1].split(
    "- (XCUIElement *)element:", 1)[0]
TAP = SOURCE.split("- (void)tapConcept:", 1)[1].split(
    "- (void)revealConceptButton:", 1)[0]
FRACTION = float(re.search(r"MIN\(MAX\(fabs\(distance\), 24\), viewport.size.height \* ([0-9.]+)\)", REVEAL)[1])


def contained(viewport, target):
    x, y, width, height = viewport
    tx, ty, tw, th = target
    return (x + 8 <= tx and y + 8 <= ty
            and tx + tw <= x + width - 8 and ty + th <= y + height - 8)


def plan(viewport, target=None):
    """One measured drag request, or None for a fully visible target."""
    x, y, width, height = viewport
    if target is not None:
        _, ty, tw, th = target
        if tw > width - 16 or th > height - 16:
            raise ValueError("The complete button cannot fit the actual viewport")
        if contained(viewport, target):
            return None
        distance = ty + th / 2 - (y + height / 2)
    else:
        distance = height * FRACTION
    travel = min(max(abs(distance), 24), height * FRACTION)
    start = y + height * (0.75 if distance > 0 else 0.35)
    end = start + (-travel if distance > 0 else travel)
    return distance, travel, start, end


class ConceptButtonSourceContractTests(unittest.TestCase):
    def test_tap_is_separate_from_bounded_full_control_navigation(self):
        self.assertIn('[self revealConceptButton:button];', TAP)
        self.assertLess(TAP.index('revealConceptButton:button'), TAP.index('[button tap]'))
        self.assertEqual(TAP.count('[button tap]'), 1)
        self.assertNotIn('[button tap]', REVEAL)
        self.assertIn('attempt <= 10', REVEAL)
        self.assertLess(REVEAL.index('if (attempt == 10) break;'), REVEAL.index('pressForDuration:'))
        self.assertNotIn('sleep', REVEAL)
        self.assertNotIn('waitFor', REVEAL)

    def test_actual_full_geometry_is_required_even_if_hittable(self):
        for fragment in (
            'viewport = CGRectIntersection(scrollFrame, self.app.windows.firstMatch.frame)',
            'CGRect visibleBounds = CGRectInset(viewport, 8, 8)',
            'target = hasTarget ? [self checkedFrame:button] : CGRectZero',
            'XCTAssertLessThanOrEqual(target.size.width, visibleBounds.size.width)',
            'XCTAssertLessThanOrEqual(target.size.height, visibleBounds.size.height)',
            'if (CGRectContainsRect(visibleBounds, target))',
            'XCTAssertTrue(button.hittable',
            'XCTAssertTrue(button.exists',
            'XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, 8, 8), target)',
        ):
            self.assertIn(fragment, REVEAL)
        self.assertNotIn('if (button.hittable)', REVEAL)
        self.assertNotIn('CGRectInset(viewport, -', REVEAL)

    def test_direction_gesture_cap_and_diagnostics_use_live_measurements(self):
        self.assertEqual(FRACTION, 0.4)
        self.assertIn('CGRectGetMidY(target) - CGRectGetMidY(viewport)', REVEAL)
        self.assertIn('(distance > 0 ? 0.75 : 0.35)', REVEAL)
        self.assertIn('startY + (distance > 0 ? -travel : travel)', REVEAL)
        self.assertIn('pressForDuration:0.05 thenDragToCoordinate:end', REVEAL)
        self.assertIn('withVelocity:XCUIGestureVelocitySlow thenHoldForDuration:0.2', REVEAL)
        for key in ('attempt=', 'identifier=', 'viewport=', 'targetBefore=',
                    'targetAfter=', 'requested=', 'travel=', 'startY=', 'endY=', 'hittable='):
            self.assertIn(key, REVEAL)
        self.assertIn('trace.name = @"concept-button-reveal-scroll";', REVEAL)
        self.assertIn('trace.lifetime = XCTAttachmentLifetimeKeepAlways;', REVEAL)

    def test_changed_question_and_unrepaired_action_gates_remain(self):
        for fragment in (
            '[self checkChangedVariation:@"3 × 4 = ?"',
            '[self checkChangedVariation:@"18 ÷ 4 = ?"',
            'XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, equation)',
            '[variation containsString:@"2 / 3"]',
            'CGRectContainsRect(CGRectInset(viewport, -1, -1), frame)',
            'CGRectGetMinY(viewport) + 7',
            'CGRectGetMaxY(viewport) - 7',
        ):
            self.assertIn(fragment, SOURCE)
        self.assertEqual(len(re.findall(r'- \(void\)test\w+\s*\{', SOURCE)), 4)


class ConceptButtonArithmeticTests(unittest.TestCase):
    def test_recorded_six_point_sliver_is_not_accepted_as_visible(self):
        viewport = (0, 137, 393, 681)
        target = (16, 811.6666666667, 361, 62)
        self.assertAlmostEqual(818 - target[1], 6.3333333333)
        self.assertFalse(contained(viewport, target))
        # Session logs report this AX hit point and the same synthesized event.
        hit_y = 817.866666759
        self.assertLess(hit_y, 818)
        self.assertLess(818 - hit_y, 0.2)
        distance, travel, start, end = plan(viewport, target)
        self.assertAlmostEqual(distance, 365.1666666667)
        self.assertAlmostEqual(travel, 272.4)
        self.assertAlmostEqual(start, 647.75)
        self.assertAlmostEqual(end, 375.35)
        ideal_after = (target[0], target[1] - travel, target[2], target[3])
        self.assertTrue(contained(viewport, ideal_after))

    def test_visible_button_needs_no_navigation_and_overshoot_reverses(self):
        viewport = (0, 137, 393, 681)
        self.assertIsNone(plan(viewport, (16, 400, 361, 62)))
        self.assertLess(plan(viewport, (16, 50, 361, 62))[0], 0)
        self.assertGreater(plan(viewport, (16, 800, 361, 62))[0], 0)
        with self.assertRaises(ValueError):
            plan(viewport, (16, 145, 361, 666))
        with self.assertRaises(ValueError):
            plan(viewport, (0, 145, 393, 62))

    def test_full_control_requirement_rejects_each_clipped_edge(self):
        viewport = (0, 137, 393, 681)
        for target in ((16, 144, 361, 62), (16, 749, 361, 62),
                       (7, 300, 361, 62), (25, 300, 361, 62)):
            self.assertFalse(contained(viewport, target))
        self.assertTrue(contained(viewport, (8, 145, 377, 665)))

    def test_endpoints_remain_inside_short_and_tall_live_viewports(self):
        for y in (-30, 0, 40, 137):
            for height in (160, 320, 681, 1024):
                viewport = (0, y, 393, height)
                for target_y in (-5000, y - 100, y, y + height, 5000):
                    result = plan(viewport, (16, target_y, 361, 62))
                    if result is None:
                        continue
                    distance, travel, start, end = result
                    self.assertGreater(travel, 0)
                    self.assertLessEqual(travel, height * 0.4)
                    self.assertLessEqual(y, min(start, end))
                    self.assertLessEqual(max(start, end), y + height)
                    self.assertEqual(math.copysign(1, distance), math.copysign(1, start - end))
                self.assertAlmostEqual(plan(viewport)[1], height * 0.4)


if __name__ == '__main__':
    unittest.main()

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "MathConceptView.h"

@interface MathConceptViewTests : XCTestCase
@end

@implementation MathConceptViewTests

- (MathConceptView *)viewWithWidth:(CGFloat)width {
    return [[MathConceptView alloc] initWithFrame:CGRectMake(0, 0, width, 340)];
}

- (UIView *)diagramInView:(MathConceptView *)view {
    [view setNeedsLayout];
    [view layoutIfNeeded];
    return [view valueForKey:@"diagramView"];
}

- (NSArray<NSValue *> *)dotsInView:(MathConceptView *)view {
    return [[self diagramInView:view] valueForKey:@"dotRects"];
}

- (void)assertGeometryInsideView:(UIView *)view rects:(NSArray<NSValue *> *)rects {
    CGRect tolerantBounds = CGRectInset(view.bounds, -0.5, -0.5);
    for (NSValue *value in rects) {
        CGRect rect = value.CGRectValue;
        XCTAssertTrue(CGRectContainsRect(tolerantBounds, rect));
        XCTAssertGreaterThan(rect.size.width, 0);
        XCTAssertGreaterThan(rect.size.height, 0);
    }
}

- (void)testSmallMultiplicationHasOneDotPerObjectAndOneRowPerGroup {
    for (NSNumber *width in @[@300, @340, @720]) {
        MathConceptView *view = [self viewWithWidth:width.doubleValue];
        XCTAssertTrue([view configureWithNumber1:3 number2:4 operator:@"×" answer:12 remainder:0]);
        UIView *diagram = [self diagramInView:view];
        NSArray *dots = [diagram valueForKey:@"dotRects"];
        NSArray *groups = [diagram valueForKey:@"groupRects"];
        XCTAssertEqual(dots.count, 12u);
        XCTAssertEqual(groups.count, 4u);
        [self assertGeometryInsideView:diagram rects:dots];
        [self assertGeometryInsideView:diagram rects:groups];
        XCTAssertTrue([view.accessibilityLabel containsString:@"4 組，每組 3，總共 12"]);
    }
}

- (void)testNineTimesNineStaysCountableOnCompactSheet {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumber1:9 number2:9 operator:@"×" answer:81 remainder:0]);
    NSArray<NSValue *> *dots = [self dotsInView:view];
    XCTAssertEqual(dots.count, 81u);
    for (NSValue *value in dots) XCTAssertGreaterThanOrEqual(value.CGRectValue.size.width, 12);
    [self assertGeometryInsideView:[self diagramInView:view] rects:dots];
}

- (void)testRemainderDivisionDrawsCompleteGroupsAndLeftovers {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumber1:23 number2:4 operator:@"÷" answer:5 remainder:3]);
    UIView *diagram = [self diagramInView:view];
    NSArray *dots = [diagram valueForKey:@"dotRects"];
    NSArray *groups = [diagram valueForKey:@"groupRects"];
    NSArray<NSNumber *> *roles = [diagram valueForKey:@"dotRoles"];
    XCTAssertEqual(dots.count, 23u);
    XCTAssertEqual(groups.count, 6u); // Five full rows plus one clearly marked leftover row.
    XCTAssertEqual([[roles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 3"]] count], 3u);
    XCTAssertTrue([view.accessibilityLabel containsString:@"23 = 4 × 5 + 3"]);
    XCTAssertTrue([view.accessibilityLabel containsString:@"剩下 3，不夠再分一組"]);
    [self assertGeometryInsideView:diagram rects:dots];
}

- (void)testExactDivisionHasNoLeftoverRow {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumber1:24 number2:4 operator:@"/" answer:6 remainder:0]);
    UIView *diagram = [self diagramInView:view];
    XCTAssertEqual([[diagram valueForKey:@"dotRects"] count], 24u);
    XCTAssertEqual([[diagram valueForKey:@"groupRects"] count], 6u);
    XCTAssertTrue([view.accessibilityLabel containsString:@"剛好分完"]);
}

- (void)testQuotientZeroAndEmptyQuantitiesAreRepresentedHonestly {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumber1:2 number2:5 operator:@"÷" answer:0 remainder:2]);
    XCTAssertEqual([self dotsInView:view].count, 2u);
    XCTAssertTrue([view.accessibilityLabel containsString:@"2 = 5 × 0 + 2"]);
    XCTAssertTrue([view configureWithNumber1:0 number2:5 operator:@"×" answer:0 remainder:0]);
    XCTAssertEqual([self dotsInView:view].count, 0u);
    XCTAssertTrue([view configureWithNumber1:0 number2:5 operator:@"÷" answer:0 remainder:0]);
    XCTAssertEqual([self dotsInView:view].count, 0u);
}

- (void)testLargeMultiplicationUsesCorrectPlaceValueNotThousandsOfDots {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumber1:125 number2:4 operator:@"×" answer:500 remainder:0]);
    UIView *diagram = [self diagramInView:view];
    XCTAssertEqual([[diagram valueForKey:@"dotRects"] count], 0u);
    NSArray *lines = [diagram valueForKey:@"placeValueLines"];
    XCTAssertEqualObjects(lines, (@[@"100 × 4 = 400", @"20 × 4 = 80", @"5 × 4 = 20"]));
    XCTAssertTrue([view.accessibilityLabel containsString:@"400 + 80 + 20 = 500"]);
}

- (void)testLargeDivisionUsesBoundedLabeledNumbers {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumber1:10001 number2:3 operator:@"÷" answer:3333 remainder:2]);
    UIView *diagram = [self diagramInView:view];
    XCTAssertEqual([[diagram valueForKey:@"dotRects"] count], 0u);
    XCTAssertEqualObjects([diagram valueForKey:@"cardTitles"], (@[@"每組", @"完整組", @"剩下"]));
    XCTAssertEqualObjects([diagram valueForKey:@"cardValues"], (@[@"3", @"3333", @"2"]));
    XCTAssertTrue([view.accessibilityLabel containsString:@"10001 = 3 × 3333 + 2"]);
}

- (void)testSmallAdditionAndSubtractionKeepExactObjectCounts {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumber1:8 number2:5 operator:@"+" answer:13 remainder:0]);
    XCTAssertEqual([self dotsInView:view].count, 13u);
    XCTAssertTrue([view configureWithNumber1:12 number2:5 operator:@"−" answer:7 remainder:0]);
    XCTAssertEqual([self dotsInView:view].count, 12u); // Five of the original objects are crossed out.
    NSArray *roles = [[self diagramInView:view] valueForKey:@"dotRoles"];
    XCTAssertEqual([[roles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 2"]] count], 5u);
    XCTAssertFalse([view configureWithNumber1:20 number2:1 operator:@"+" answer:21 remainder:0]);
    XCTAssertFalse([view configureWithNumber1:21 number2:1 operator:@"−" answer:20 remainder:0]);
}

- (void)testFractionsHaveEqualAreasAndExactSelectedCount {
    for (NSNumber *width in @[@300, @720]) {
        for (NSInteger denominator = 2; denominator <= 12; denominator++) {
            MathConceptView *view = [self viewWithWidth:width.doubleValue];
            XCTAssertTrue([view configureWithNumerator:denominator - 1 denominator:denominator]);
            UIView *diagram = [self diagramInView:view];
            NSArray<NSValue *> *segments = [diagram valueForKey:@"segmentRects"];
            XCTAssertEqual(segments.count, denominator);
            XCTAssertEqual([[diagram valueForKey:@"numerator"] integerValue], denominator - 1);
            CGRect first = segments.firstObject.CGRectValue;
            CGFloat lastEdge = first.origin.x;
            for (NSValue *value in segments) {
                CGRect segment = value.CGRectValue;
                XCTAssertEqualWithAccuracy(segment.size.width, first.size.width, 0.01);
                XCTAssertEqualWithAccuracy(segment.size.height, first.size.height, 0.01);
                XCTAssertEqualWithAccuracy(segment.origin.x, lastEdge, 0.01);
                lastEdge = CGRectGetMaxX(segment);
            }
            [self assertGeometryInsideView:diagram rects:segments];
        }
    }
}

- (void)testFractionIdentificationUsesIntegerParametersIncludingOneThird {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumerator:1 denominator:3]);
    XCTAssertEqualObjects([[view valueForKey:@"equationLabel"] text], @"1/3");
    XCTAssertTrue([view.accessibilityLabel containsString:@"3 分之 1"]);
    XCTAssertTrue([view configureWithNumerator:0 denominator:3]);
    XCTAssertTrue([view configureWithNumerator:3 denominator:3]);
    XCTAssertTrue([view configureWithNumerator:1 denominator:1000]);
    XCTAssertEqual([[[self diagramInView:view] valueForKey:@"segmentRects"] count], 0u);
    XCTAssertTrue([view.accessibilityLabel containsString:@"數字卡"]);
}

- (void)testInvalidInputClearsPreviousDiagramAndDoesNotInventAnEquation {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumerator:1 denominator:3]);
    XCTAssertFalse([view configureWithNumber1:23 number2:4 operator:@"÷" answer:5 remainder:2]);
    XCTAssertEqual([self dotsInView:view].count, 0u);
    XCTAssertEqual([[[self diagramInView:view] valueForKey:@"segmentRects"] count], 0u);
    XCTAssertEqualObjects([[view valueForKey:@"equationLabel"] text], @"");
    XCTAssertFalse([view configureWithNumber1:5 number2:0 operator:@"÷" answer:0 remainder:0]);
    XCTAssertFalse([view configureWithNumber1:NSIntegerMax number2:2 operator:@"×" answer:0 remainder:0]);
    XCTAssertFalse([view configureWithNumber1:-1 number2:2 operator:@"×" answer:0 remainder:0]);
    XCTAssertFalse([view configureWithNumber1:2 number2:2 operator:@"?" answer:4 remainder:0]);
    XCTAssertFalse([view configureWithNumerator:1 denominator:0]);
    XCTAssertFalse([view configureWithNumerator:4 denominator:3]);
    XCTAssertFalse([view configureWithNumerator:-1 denominator:3]);
}

- (void)testDiagramIsOneMeaningfulAccessibilityElementNotDecorativeDots {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumber1:3 number2:4 operator:@"×" answer:12 remainder:0]);
    XCTAssertTrue(view.isAccessibilityElement);
    XCTAssertGreaterThan(view.accessibilityLabel.length, 10u);
    XCTAssertFalse([self diagramInView:view].isAccessibilityElement);
    XCTAssertTrue([self diagramInView:view].accessibilityElementsHidden);
}

- (void)testValidHugeInputsFitWithoutNegativeDiagramOrLabelFrames {
    MathConceptView *view = [self viewWithWidth:300];
    NSArray<NSArray<NSNumber *> *> *examples = @[
        @[@(NSIntegerMax), @1, @(NSIntegerMax), @0],
        @[@(NSIntegerMax), @(NSIntegerMax / 2), @2, @1],
    ];
    for (NSArray<NSNumber *> *values in examples) {
        XCTAssertTrue([view configureWithNumber1:values[0].integerValue number2:values[1].integerValue
                                       operator:@"÷" answer:values[2].integerValue remainder:values[3].integerValue]);
        CGSize fitted = [view sizeThatFits:CGSizeMake(300, CGFLOAT_MAX)];
        XCTAssertGreaterThanOrEqual(fitted.height, 340);
        view.frame = CGRectMake(0, 0, fitted.width, fitted.height);
        UIView *diagram = [self diagramInView:view];
        XCTAssertGreaterThanOrEqual(diagram.bounds.size.height, 176);
        for (UIView *child in view.subviews) XCTAssertTrue(CGRectContainsRect(view.bounds, child.frame));
        XCTAssertEqual([[diagram valueForKey:@"dotRects"] count], 0u);
        XCTAssertEqual([[diagram valueForKey:@"cardValues"] count], 3u);
    }
    XCTAssertTrue([view configureWithNumerator:NSIntegerMax - 1 denominator:NSIntegerMax]);
    CGSize fitted = [view sizeThatFits:CGSizeMake(300, CGFLOAT_MAX)];
    view.frame = CGRectMake(0, 0, fitted.width, fitted.height);
    XCTAssertGreaterThanOrEqual([self diagramInView:view].bounds.size.height, 176);
}

- (void)testFittingGrowsForLargeTextWithoutShrinkingCountableDots {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumber1:9 number2:9 operator:@"×" answer:81 remainder:0]);
    for (NSString *key in @[@"headlineLabel", @"equationLabel", @"explanationLabel"]) {
        UILabel *label = [view valueForKey:key];
        label.font = [label.font fontWithSize:label.font.pointSize * 2];
    }
    CGSize fitted = [view sizeThatFits:CGSizeMake(300, CGFLOAT_MAX)];
    XCTAssertGreaterThan(fitted.height, 340);
    view.frame = CGRectMake(0, 0, fitted.width, fitted.height);
    NSArray<NSValue *> *dots = [self dotsInView:view];
    XCTAssertEqual(dots.count, 81u);
    for (NSValue *value in dots) XCTAssertGreaterThanOrEqual(value.CGRectValue.size.width, 12);
}

- (void)testOverconstrainedEmbeddingUsesAnHonestTextFallbackInsteadOfTinyDots {
    MathConceptView *view = [self viewWithWidth:300];
    XCTAssertTrue([view configureWithNumber1:9 number2:9 operator:@"×" answer:81 remainder:0]);
    view.frame = CGRectMake(0, 0, 300, 220);
    UIView *diagram = [self diagramInView:view];
    XCTAssertEqual([[diagram valueForKey:@"dotRects"] count], 0u);
    XCTAssertTrue([[diagram valueForKey:@"compactSummary"] containsString:@"9 組，每組 9"]);
}

@end

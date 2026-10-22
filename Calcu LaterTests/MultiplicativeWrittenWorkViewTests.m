#import <XCTest/XCTest.h>
#import <QuartzCore/QuartzCore.h>
#import "MultiplicativeWrittenWorkView.h"

@interface MultiplicativeWrittenWorkViewTests : XCTestCase
@end
@implementation MultiplicativeWrittenWorkViewTests
- (MultiplicativeTeachingActionPlan *)plan:(NSInteger)a second:(NSInteger)b operation:(NSString *)operation {
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:operation
        answer:[operation isEqualToString:@"×"] ? a * b : a / b];
    return [MultiplicativeTeachingActionPlan planForSequence:[MultiplicativeTeachingSequence sequenceForArithmeticProblem:problem]];
}
- (MultiplicativeWrittenWorkView *)viewForPlan:(MultiplicativeTeachingActionPlan *)plan snapshot:(MultiplicativeTeachingActionSnapshot *)snapshot {
    MultiplicativeWrittenWorkView *view = [[MultiplicativeWrittenWorkView alloc] initWithFrame:CGRectZero];
    ArithmeticProblem *given = plan.sourceSequence.problem;
    [view configureWithNumber1:given.number1 number2:given.number2 operation:plan.sourceSequence.operation
        operandStartColumn:plan.sourceSequence.operandStartColumn snapshot:snapshot];
    CGSize size = [view sizeThatFits:CGSizeMake(375, CGFLOAT_MAX)]; view.frame = (CGRect){CGPointZero, size}; [view layoutIfNeeded];
    return view;
}
- (UILabel *)labelIn:(UIView *)view identifier:(NSString *)identifier {
    for (UIView *child in view.subviews) if ([child.accessibilityIdentifier isEqual:identifier]) return (UILabel *)child;
    return nil;
}
- (void)assertView:(MultiplicativeWrittenWorkView *)view snapshot:(MultiplicativeTeachingActionSnapshot *)snapshot {
    XCTAssertEqual(view.snapshot, snapshot);
    for (NSUInteger c = 0; c < 3; c++) {
        id value = snapshot.visibleAnswerDigits[c];
        XCTAssertEqualObjects(view.answerCellLabels[c].text, [value isKindOfClass:NSNumber.class] ? [value stringValue] : @"");
    }
    NSUInteger captions = 0;
    for (UIView *child in view.subviews) if ([child.accessibilityIdentifier hasPrefix:@"multiplicative.written.row."]
        && [child.accessibilityIdentifier hasSuffix:@".caption"]) captions++;
    XCTAssertEqual(captions, snapshot.visibleDivisionRows.count);
    UILabel *remainder = [self labelIn:view identifier:@"multiplicative.written.remainder"];
    XCTAssertEqual(remainder != nil, snapshot.visibleRemainder != nil);
}
- (void)testLeadingInteriorTrailingAndZeroAnswerCellsFollowOnlyTypedWrites {
    for (NSArray<NSNumber *> *fixture in @[@[@101, @2], @[@408, @4], @[@0, @9]]) {
        MultiplicativeTeachingActionPlan *plan = [self plan:fixture[0].integerValue second:fixture[1].integerValue operation:@"÷"];
        for (MultiplicativeTeachingAction *action in plan.actions) {
            if (action.sourceStep.kind != MultiplicativeTeachingStepKindWriteDigit
                && action.sourceStep.kind != MultiplicativeTeachingStepKindInspectRemainder) continue;
            MultiplicativeWrittenWorkView *before = [self viewForPlan:plan snapshot:action.before];
            MultiplicativeWrittenWorkView *after = [self viewForPlan:plan snapshot:action.after];
            [self assertView:before snapshot:action.before]; [self assertView:after snapshot:action.after];
            if (action.writeDisposition == MultiplicativeTeachingWriteDispositionSuppressedLeadingZero) {
                XCTAssertEqualObjects(after.answerCellLabels[(NSUInteger)action.activeColumn].text, @"");
                XCTAssertTrue([after.answerCellLabels[(NSUInteger)action.activeColumn].accessibilityLabel containsString:@"0 留白"]);
            } else if (action.writtenDigit && action.writtenDigit.integerValue == 0) {
                XCTAssertEqualObjects(after.answerCellLabels[(NSUInteger)action.activeColumn].text, @"0");
                XCTAssertFalse([before.answerCellLabels[(NSUInteger)action.activeColumn].text isEqual:@"0"]);
            }
        }
    }
}
- (void)testDivisionWorkCountsAlignToTheirRealColumnRatherThanTheOnesColumn {
    MultiplicativeTeachingActionPlan *plan = [self plan:899 second:9 operation:@"÷"];
    MultiplicativeWrittenWorkView *view = [self viewForPlan:plan snapshot:plan.actions[24].after];
    NSArray<NSArray<NSString *> *> *expected = @[@[@"8", @"9", @""], @[@"8", @"1", @""], @[@"", @"8", @""]];
    for (NSUInteger part = 0; part < 3; part++) for (NSUInteger column = 0; column < 3; column++) {
        UILabel *label = [self labelIn:view identifier:[NSString stringWithFormat:@"multiplicative.written.row.1.%lu.%lu",
            (unsigned long)part, (unsigned long)column]];
        XCTAssertNotNil(label); XCTAssertEqualObjects(label.text, expected[part][column]);
        XCTAssertEqualWithAccuracy(CGRectGetMidX(label.frame), view.columnCenters[column].doubleValue, .01);
        XCTAssertTrue(CGRectContainsRect(view.bounds, label.frame));
    }
    UILabel *caption = [self labelIn:view identifier:@"multiplicative.written.row.1.caption"];
    XCTAssertEqualObjects(caption.text, @"89 個十 − 81 個十，剩 8 個十");
    XCTAssertNil([self labelIn:view identifier:@"multiplicative.written.row.2.caption"]);
    XCTAssertNil([self labelIn:view identifier:@"multiplicative.written.remainder"]);
    [view emphasizeWrittenColumn:1];
    XCTAssertGreaterThan(view.answerCellLabels[1].layer.borderWidth, 0);
    XCTAssertFalse(CGRectIsNull([view latestWorkRowRectForColumn:1]));
    MultiplicativeWrittenWorkView *before = [self viewForPlan:plan snapshot:plan.actions[24].before];
    [before emphasizeWrittenColumn:1];
    XCTAssertTrue(CGRectIsNull([before latestWorkRowRectForColumn:1]));
    XCTAssertTrue(CGRectEqualToRect([before writtenRelationRectForColumn:1], before.answerCellLabels[1].frame));
}
- (void)testCarryIsOnlyAnIncludedAnnotationAndDirectResultDoesNotInventDigits {
    MultiplicativeTeachingActionPlan *plan = [self plan:99 second:9 operation:@"×"];
    MultiplicativeWrittenWorkView *before = [self viewForPlan:plan snapshot:plan.actions[21].before];
    UILabel *note = [self labelIn:before identifier:@"multiplicative.written.carryNote"];
    XCTAssertTrue([note.text containsString:@"已在累積區"]); XCTAssertTrue([note.text containsString:@"不再加一次"]);
    XCTAssertEqualObjects([self labelIn:before identifier:@"multiplicative.written.carry.1"].text, @"8");
    XCTAssertEqualObjects(before.answerCellLabels[0].text, @""); XCTAssertEqualObjects(before.answerCellLabels[1].text, @"");
    XCTAssertEqualObjects(before.answerCellLabels[2].text, @"1");
    MultiplicativeWrittenWorkView *result = [self viewForPlan:plan snapshot:[plan resultSnapshotForSourceStepAtIndex:6]];
    XCTAssertNil([self labelIn:result identifier:@"multiplicative.written.carryNote"]);
    XCTAssertEqualObjects(result.answerCellLabels[0].text, @""); XCTAssertEqualObjects(result.answerCellLabels[1].text, @"");
    XCTAssertEqualObjects(result.answerCellLabels[2].text, @"1");
}
@end

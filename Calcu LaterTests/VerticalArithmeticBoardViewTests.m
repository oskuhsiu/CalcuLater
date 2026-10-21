#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "VerticalArithmeticBoardView.h"
#import "ArithmeticProblem.h"

static void VABRecordPathStart(void *info, const CGPathElement *element) {
    if (element->type == kCGPathElementMoveToPoint) *((CGPoint *)info) = element->points[0];
}

@interface VerticalArithmeticBoardView (Testing)
- (BOOL)canAnimate;
- (void)animationTick:(nullable CADisplayLink *)link;
@end

@interface VABAnimationTestBoard : VerticalArithmeticBoardView
@property (nonatomic) BOOL allowMotion;
@end
@implementation VABAnimationTestBoard
- (BOOL)canAnimate { return self.allowMotion; }
@end

@interface VerticalArithmeticBoardViewTests : XCTestCase
@end
@implementation VerticalArithmeticBoardViewTests

- (ArithmeticTeachingSequence *)sequence:(NSInteger)a second:(NSInteger)b operation:(NSString *)operation {
    NSInteger answer = [operation isEqualToString:@"+"] ? a + b : a - b;
    return [ArithmeticTeachingSequence sequenceForProblem:[[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:operation answer:answer]];
}

- (VerticalArithmeticBoardView *)board {
    return [[VerticalArithmeticBoardView alloc] initWithFrame:CGRectMake(0, 0, 288, 500)];
}

- (UILabel *)label:(NSString *)identifier inView:(UIView *)view {
    if ([view.accessibilityIdentifier isEqualToString:identifier] && [view isKindOfClass:UILabel.class]) return (UILabel *)view;
    for (UIView *child in view.subviews) {
        UILabel *match = [self label:identifier inView:child];
        if (match) return match;
    }
    return nil;
}

- (NSInteger)firstIndexOfKind:(ArithmeticTeachingStepKind)kind inSequence:(ArithmeticTeachingSequence *)sequence {
    for (NSInteger i = 0; i < (NSInteger)sequence.steps.count; i++) if (sequence.steps[i].kind == kind) return i;
    return NSNotFound;
}

- (void)fitBoard:(VerticalArithmeticBoardView *)board width:(CGFloat)width {
    CGSize size = [board sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    board.frame = CGRectMake(0, 0, size.width, size.height);
    [board setNeedsLayout];
    [board layoutIfNeeded];
}

- (void)testOnlySnapshotAnswerDigitsAreRenderedIncludingBackAndReplay {
    ArithmeticTeachingSequence *sequence = [self sequence:500 second:128 operation:@"-"];
    VerticalArithmeticBoardView *board = self.board;
    for (NSInteger i = 0; i < (NSInteger)sequence.steps.count; i++) {
        XCTAssertTrue([board configureWithSequence:sequence stepIndex:i animated:NO]);
        for (NSInteger column = 0; column < sequence.columnCount; column++) {
            id digit = sequence.steps[i].visibleAnswerDigits[column];
            NSString *expected = [digit isKindOfClass:NSNumber.class] ? [digit stringValue] : @"";
            XCTAssertEqualObjects([self label:[NSString stringWithFormat:@"verticalAnswer%ld", (long)column] inView:board].text, expected);
        }
    }
    XCTAssertTrue([board showStepAtIndex:0 animated:NO]);
    for (NSInteger column = 0; column < sequence.columnCount; column++) {
        XCTAssertEqualObjects([self label:[NSString stringWithFormat:@"verticalAnswer%ld", (long)column] inView:board].text, @"");
        XCTAssertEqualObjects([self label:[NSString stringWithFormat:@"verticalWorking%ld", (long)column] inView:board].text, @"");
    }
    XCTAssertFalse([board.accessibilityValue containsString:@"372"]);
    XCTAssertTrue([board.accessibilityValue containsString:@"500 減 128"]);
    XCTAssertTrue(board.isAccessibilityElement);
    XCTAssertTrue(board.subviews.firstObject.accessibilityElementsHidden);
}

- (void)testBorrowAcrossZeroShowsTwoDifferentExchangesNotFinalRewriteImmediately {
    ArithmeticTeachingSequence *sequence = [self sequence:500 second:128 operation:@"-"];
    VerticalArithmeticBoardView *board = self.board;
    NSMutableArray<NSNumber *> *indices = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)sequence.steps.count; i++) if (sequence.steps[i].kind == ArithmeticTeachingStepKindRegroup) [indices addObject:@(i)];
    XCTAssertEqual(indices.count, 2u);
    [board configureWithSequence:sequence stepIndex:indices[0].integerValue animated:NO];
    XCTAssertEqualObjects([self label:@"verticalWorking0" inView:board].text, @"4");
    XCTAssertEqualObjects([self label:@"verticalWorking1" inView:board].text, @"10");
    XCTAssertEqualObjects([self label:@"verticalWorking2" inView:board].text, @"");
    XCTAssertEqualObjects([self label:@"verticalExchangeSource" inView:board].text, @"1 個百");
    XCTAssertEqualObjects([self label:@"verticalExchangeDestination" inView:board].text, @"10 個十");
    [board showStepAtIndex:indices[1].integerValue animated:NO];
    XCTAssertEqualObjects([self label:@"verticalWorking0" inView:board].text, @"4");
    XCTAssertEqualObjects([self label:@"verticalWorking1" inView:board].text, @"9");
    XCTAssertEqualObjects([self label:@"verticalWorking2" inView:board].text, @"10");
    [board showStepAtIndex:indices[0].integerValue animated:NO];
    XCTAssertEqualObjects([self label:@"verticalWorking1" inView:board].text, @"10");
    XCTAssertEqualObjects([self label:@"verticalWorking2" inView:board].text, @"");
}

- (void)testFiveColumnsFitNarrowWidthAndRemainAlignedAfterResize {
    ArithmeticTeachingSequence *sequence = [self sequence:10000 second:1 operation:@"-"];
    VerticalArithmeticBoardView *board = self.board;
    NSInteger index = [self firstIndexOfKind:ArithmeticTeachingStepKindRegroup inSequence:sequence];
    [board configureWithSequence:sequence stepIndex:index animated:NO];
    for (NSNumber *width in @[@288, @320, @680, @288]) {
        [self fitBoard:board width:width.doubleValue];
        UIView *grid = [board valueForKey:@"gridView"];
        XCTAssertGreaterThanOrEqual(CGRectGetMinX(grid.frame), 0);
        XCTAssertLessThanOrEqual(CGRectGetMaxX(grid.frame), CGRectGetWidth(board.bounds));
        for (NSInteger column = 0; column < 5; column++) {
            UILabel *heading = [self label:[NSString stringWithFormat:@"verticalPlace%ld", (long)column] inView:board];
            UILabel *operand = [self label:[NSString stringWithFormat:@"verticalFirst%ld", (long)column] inView:board];
            UILabel *answer = [self label:[NSString stringWithFormat:@"verticalAnswer%ld", (long)column] inView:board];
            XCTAssertEqualWithAccuracy(heading.center.x, operand.center.x, 0.1);
            XCTAssertEqualWithAccuracy(answer.center.x, operand.center.x, 0.1);
            XCTAssertGreaterThanOrEqual(CGRectGetMinX(heading.frame), 0);
            XCTAssertLessThanOrEqual(CGRectGetMaxX(heading.frame), CGRectGetWidth(grid.bounds));
        }
        UIView *content = [board valueForKey:@"contentView"];
        XCTAssertEqualWithAccuracy(CGRectGetHeight(content.bounds), CGRectGetHeight(board.bounds), 0.1);
        XCTAssertEqual(board.currentStepIndex, index);
    }
}

- (void)testOriginalOperandsAreRightAlignedWithoutZeroPadding {
    ArithmeticTeachingSequence *sequence = [self sequence:8 second:47 operation:@"+"];
    VerticalArithmeticBoardView *board = self.board;
    [board configureWithSequence:sequence stepIndex:0 animated:NO];
    XCTAssertEqualObjects([self label:@"verticalFirst0" inView:board].text, @"");
    XCTAssertEqualObjects([self label:@"verticalFirst1" inView:board].text, @"8");
    XCTAssertEqualObjects([self label:@"verticalSecond0" inView:board].text, @"4");
    XCTAssertEqualObjects([self label:@"verticalSecond1" inView:board].text, @"7");
}

- (void)testConcreteIllustrationHasBoundedUnitsAndCorrectCarryDirection {
    ArithmeticTeachingSequence *sequence = [self sequence:28 second:47 operation:@"+"];
    VerticalArithmeticBoardView *board = self.board;
    NSInteger index = [self firstIndexOfKind:ArithmeticTeachingStepKindRegroup inSequence:sequence];
    [board configureWithSequence:sequence stepIndex:index animated:NO];
    XCTAssertEqual([[board valueForKey:@"exchangeSourceUnits"] count], 10u);
    XCTAssertEqual([[board valueForKey:@"exchangeDestinationUnits"] count], 1u);
    XCTAssertEqualObjects([self label:@"verticalExchangeSource" inView:board].text, @"10 個一");
    XCTAssertEqualObjects([self label:@"verticalExchangeDestination" inView:board].text, @"1 個十");
    XCTAssertEqualObjects([self label:@"verticalWorking0" inView:board].text, @"+1");
    XCTAssertEqualObjects([self label:@"verticalAnswer1" inView:board].text, @"");
}

- (VABAnimationTestBoard *)animatedBoardForSequence:(ArithmeticTeachingSequence *)sequence {
    VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:CGRectMake(0, 0, 320, 500)];
    board.allowMotion = YES;
    NSInteger index = [self firstIndexOfKind:ArithmeticTeachingStepKindRegroup inSequence:sequence];
    [board configureWithSequence:sequence stepIndex:index animated:YES];
    return board;
}

- (void)assertCancelled:(VerticalArithmeticBoardView *)board index:(NSInteger)index {
    XCTAssertEqual([[board valueForKey:@"animatedLayers"] count], 0u);
    XCTAssertEqual([[board valueForKey:@"transientViews"] count], 0u);
    XCTAssertNil([board valueForKey:@"animationDisplayLink"]);
    XCTAssertEqual(board.currentStepIndex, index);
}

- (void)testExchangeAnimationUsesActualGridSourceAndDestinationAndStaysFinite {
    ArithmeticTeachingSequence *sequence = [self sequence:500 second:128 operation:@"-"];
    VABAnimationTestBoard *board = [self animatedBoardForSequence:sequence];
    UILabel *packet = [self label:@"verticalMovingExchange" inView:board];
    XCTAssertNotNil(packet);
    CAAnimationGroup *group = (CAAnimationGroup *)[packet.layer animationForKey:@"verticalUnitTransfer"];
    XCTAssertNotNil(group);
    XCTAssertLessThanOrEqual(group.duration, 1.0);
    CAKeyframeAnimation *travel = (CAKeyframeAnimation *)group.animations.firstObject;
    UIView *grid = [board valueForKey:@"gridView"];
    UIView *content = [board valueForKey:@"contentView"];
    NSArray<UILabel *> *labels = [board valueForKey:@"annotationLabels"];
    CGPoint source = [grid convertPoint:labels[board.currentStep.sourceColumn].center toView:content];
    CGPoint destination = [grid convertPoint:labels[board.currentStep.destinationColumn].center toView:content];
    CGPoint pathStart = CGPointZero;
    CGPathApply(travel.path, &pathStart, VABRecordPathStart);
    XCTAssertEqualWithAccuracy(pathStart.x, source.x, 0.1);
    XCTAssertEqualWithAccuracy(pathStart.y, source.y, 0.1);
    CGPoint pathEnd = CGPathGetCurrentPoint(travel.path);
    XCTAssertEqualWithAccuracy(pathEnd.x, destination.x, 0.1);
    XCTAssertEqualWithAccuracy(pathEnd.y, destination.y, 0.1);
    NSInteger index = board.currentStepIndex;
    [board cancelAnimations];
    [self assertCancelled:board index:index];
    XCTAssertEqualObjects([self label:@"verticalWorking1" inView:board].text, @"10");
}

- (void)testLifecycleCancellationKeepsOnlyCurrentSnapshot {
    ArithmeticTeachingSequence *sequence = [self sequence:500 second:128 operation:@"-"];
    VABAnimationTestBoard *board = [self animatedBoardForSequence:sequence];
    NSInteger index = board.currentStepIndex;
    board.hidden = YES;
    [self assertCancelled:board index:index];
    board.hidden = NO;
    [board showStepAtIndex:index animated:YES];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    [self assertCancelled:board index:index];
    [board showStepAtIndex:index animated:YES];
    [self fitBoard:board width:288];
    [self assertCancelled:board index:index];
    [board showStepAtIndex:index animated:YES];
    board.allowMotion = NO;
    [board animationTick:nil];
    [self assertCancelled:board index:index];
    XCTAssertEqualObjects([self label:@"verticalAnswer2" inView:board].text, @"");
    XCTAssertEqualObjects([self label:@"verticalExchangeCounts" inView:board].text, @"百位 5 → 4　・　十位 0 → 10");
}

- (void)testReduceMotionStaticRenderHasSameCountsAndNoTransfers {
    ArithmeticTeachingSequence *sequence = [self sequence:500 second:128 operation:@"-"];
    VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:CGRectMake(0, 0, 320, 500)];
    board.allowMotion = NO;
    NSInteger index = [self firstIndexOfKind:ArithmeticTeachingStepKindRegroup inSequence:sequence];
    [board configureWithSequence:sequence stepIndex:index animated:YES];
    [self assertCancelled:board index:index];
    XCTAssertEqualObjects([self label:@"verticalWorking0" inView:board].text, @"4");
    XCTAssertEqualObjects([self label:@"verticalWorking1" inView:board].text, @"10");
    XCTAssertEqual([[board valueForKey:@"exchangeDestinationUnits"] count], 10u);
}

- (void)testInvalidInputAndInvalidIndexClearEveryOldCellAndSummary {
    ArithmeticTeachingSequence *sequence = [self sequence:500 second:128 operation:@"-"];
    VABAnimationTestBoard *board = [self animatedBoardForSequence:sequence];
    XCTAssertFalse([board configureWithSequence:nil stepIndex:0 animated:YES]);
    XCTAssertNil(board.sequence);
    XCTAssertNil(board.currentStep);
    XCTAssertNil(board.accessibilityValue);
    XCTAssertFalse(board.isAccessibilityElement);
    XCTAssertEqual(board.subviews.count, 0u);
    [self assertCancelled:board index:NSNotFound];
    [board configureWithSequence:sequence stepIndex:0 animated:NO];
    XCTAssertFalse([board showStepAtIndex:sequence.steps.count animated:YES]);
    XCTAssertEqual(board.subviews.count, 0u);
}

- (void)testAnimatedWriteBeforeLayoutDoesNotIndexUnbuiltCells {
    ArithmeticTeachingSequence *sequence = [self sequence:28 second:47 operation:@"+"];
    VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:CGRectZero];
    board.allowMotion = YES;
    NSInteger index = [self firstIndexOfKind:ArithmeticTeachingStepKindWriteAnswer inSequence:sequence];
    XCTAssertTrue([board configureWithSequence:sequence stepIndex:index animated:YES]);
    [self assertCancelled:board index:index];
    [self fitBoard:board width:288];
    XCTAssertEqualObjects([self label:@"verticalAnswer1" inView:board].text, @"5");
}

- (void)testActiveAnimationDoesNotRetainDismissedBoard {
    __weak VerticalArithmeticBoardView *weakBoard;
    @autoreleasepool {
        VABAnimationTestBoard *board = [self animatedBoardForSequence:[self sequence:500 second:128 operation:@"-"]];
        weakBoard = board;
    }
    XCTAssertNil(weakBoard);
}
@end

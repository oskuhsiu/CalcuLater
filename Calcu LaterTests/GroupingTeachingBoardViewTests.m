#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "GroupingTeachingBoardView.h"
#import "WordProblem.h"

@interface GroupingTeachingBoardView (Testing)
- (BOOL)canAnimate;
- (void)renderAnimationAtProgress:(CGFloat)progress;
@end

@interface GBTTestBoard : GroupingTeachingBoardView
@property (nonatomic) BOOL allowMotion;
@end
@implementation GBTTestBoard
- (BOOL)canAnimate { return self.allowMotion; }
@end

@interface GroupingTeachingBoardViewTests : XCTestCase
@property (nonatomic, strong) NSMutableArray<GBTTestBoard *> *fixtureBoards;
@property (nonatomic, strong) UIWindow *hostWindow;
@end
@implementation GroupingTeachingBoardViewTests

- (void)setUp {
    [super setUp];
    self.fixtureBoards = [NSMutableArray array];
}
- (void)tearDown {
    // XCTest also runs teardown after an assertion/exception. Do not leave a
    // board's display link or its trait-hosting window alive for the next test.
    for (GBTTestBoard *board in self.fixtureBoards) {
        [board cancelAnimations];
        [board.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
        [board removeFromSuperview];
    }
    self.fixtureBoards = nil;
    self.hostWindow.hidden = YES;
    self.hostWindow.rootViewController = nil;
    self.hostWindow = nil;
    [super tearDown];
}

- (GroupingTeachingSequence *)storySequence:(NSInteger)a second:(NSInteger)b meaning:(GroupingStoryMeaning)meaning {
    BOOL build = meaning == GroupingStoryMeaningBuildEqualGroups;
    GroupingStoryContext *context = [[GroupingStoryContext alloc] initWithMeaning:meaning itemName:@"糖果" itemUnit:@"顆"
        groupName:meaning == GroupingStoryMeaningShareEqually ? @"個小朋友" : @"包"
        answerUnit:meaning == GroupingStoryMeaningMakeGroupsOf ? @"包" : @"顆"];
    WordProblem *story = [[WordProblem alloc] initWithStory:@"依照規則，一步一步分糖果。" templateID:@"board-fixture" grade:3
        number1:a number2:b operator:build ? @"×" : @"÷" answer:build ? a * b : a / b unit:context.answerUnit
        missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:build ? 0 : a % b number3:0 operator2:nil intermediate:0
        isFractionAnswer:NO answerNumerator:0 answerDenominator:0 groupingContext:context strategyText:@"照同一個規則分。"];
    return [GroupingTeachingSequence sequenceForWordProblem:story];
}
- (NSInteger)firstIndex:(GroupingTeachingStepKind)kind inSequence:(GroupingTeachingSequence *)sequence {
    for (NSInteger i = 0; i < (NSInteger)sequence.steps.count; i++) if (sequence.steps[i].kind == kind) return i;
    return NSNotFound;
}
- (GBTTestBoard *)board {
    return [self boardWithFrame:CGRectMake(0, 0, 288, 600)];
}
- (GBTTestBoard *)boardWithFrame:(CGRect)frame {
    GBTTestBoard *board = [[GBTTestBoard alloc] initWithFrame:frame];
    board.allowMotion = NO;
    [self.fixtureBoards addObject:board];
    return board;
}
- (void)hostBoard:(GBTTestBoard *)board {
    self.hostWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 680, 600)];
    self.hostWindow.rootViewController = [[UIViewController alloc] init];
    self.hostWindow.hidden = NO;
    // Keep the app's key window unchanged. The board's explicit test frame is
    // independent of any screen-sized frame UIKit gives the hosting controller.
    board.autoresizingMask = UIViewAutoresizingNone;
    [self.hostWindow.rootViewController.view addSubview:board];
    [self.hostWindow setNeedsLayout];
    [self.hostWindow layoutIfNeeded];
    XCTAssertEqual(board.window, self.hostWindow);
}
- (void)fit:(GroupingTeachingBoardView *)board width:(CGFloat)width {
    CGSize fitted = [board sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    board.frame = CGRectMake(0, 0, fitted.width, fitted.height);
    [board setNeedsLayout];
    [board layoutIfNeeded];
}
- (UILabel *)label:(NSString *)identifier inView:(UIView *)view {
    if ([view isKindOfClass:UILabel.class] && [view.accessibilityIdentifier isEqualToString:identifier]) return (UILabel *)view;
    for (UIView *child in view.subviews) {
        UILabel *label = [self label:identifier inView:child];
        if (label) return label;
    }
    return nil;
}
- (NSUInteger)stationaryCounterCount:(GroupingTeachingBoardView *)board {
    NSUInteger count = [[board valueForKey:@"poolCounters"] count];
    NSArray<UIView *> *groups = [board valueForKey:@"groupViews"];
    NSArray<NSArray<UIView *> *> *counters = [board valueForKey:@"groupCounters"];
    for (NSUInteger i = 0; i < groups.count; i++) for (UIView *counter in counters[i]) if (counter.superview == groups[i]) count++;
    return count;
}
- (void)assertSettled:(GroupingTeachingBoardView *)board step:(NSInteger)step {
    XCTAssertNil([board valueForKey:@"animationDisplayLink"]);
    XCTAssertEqual([[board valueForKey:@"transfers"] count], 0u);
    XCTAssertEqual(board.currentStepIndex, step);
}
- (void)assertSubviewWidths:(UIView *)view {
    for (UIView *child in view.subviews) {
        XCTAssertGreaterThanOrEqual(CGRectGetMinX(child.frame), -0.1);
        XCTAssertLessThanOrEqual(CGRectGetMaxX(child.frame), CGRectGetWidth(view.bounds) + 0.1);
        if ([child isKindOfClass:UILabel.class] && !child.hidden) {
            UILabel *label = (UILabel *)child;
            CGRect text = [label.text boundingRectWithSize:CGSizeMake(CGRectGetWidth(label.bounds), CGFLOAT_MAX)
                options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:label.font} context:nil];
            XCTAssertLessThanOrEqual(ceil(text.size.height), CGRectGetHeight(label.bounds) + 0.1);
        }
        [self assertSubviewWidths:child];
    }
}

- (void)testSharingAndPackingStartWithDifferentKnownGroups {
    GBTTestBoard *board = self.board;
    GroupingTeachingSequence *share = [self storySequence:23 second:4 meaning:GroupingStoryMeaningShareEqually];
    XCTAssertTrue([board configureWithSequence:share stepIndex:0 animated:NO]);
    [self fit:board width:288];
    XCTAssertEqual([[board valueForKey:@"groupViews"] count], 4u);
    XCTAssertEqual([[board valueForKey:@"poolCounters"] count], 23u);
    XCTAssertTrue([board.accessibilityValue containsString:@"平均分給 4 個小朋友"]);
    XCTAssertTrue([board.accessibilityValue containsString:@"第 1 個小朋友有 0 顆"]);
    XCTAssertTrue([board.accessibilityValue containsString:@"待分的糖果：23 顆"]);
    XCTAssertTrue([board.accessibilityValue containsString:@"答案還沒寫"]);
    XCTAssertTrue(CGRectIsNull(board.currentTransformationRect));
    GroupingTeachingSequence *pack = [self storySequence:23 second:4 meaning:GroupingStoryMeaningMakeGroupsOf];
    [board configureWithSequence:pack stepIndex:0 animated:NO];
    XCTAssertEqual([[board valueForKey:@"groupViews"] count], 0u);
    XCTAssertTrue([board.accessibilityValue containsString:@"已分成 0 包"]);
    XCTAssertFalse([board.accessibilityValue containsString:@"5 包"]);
    XCTAssertTrue(board.isAccessibilityElement);
    XCTAssertTrue(board.subviews.firstObject.accessibilityElementsHidden);
}

- (void)testEachPackingStepCreatesOnlyOneNewCompleteGroupAndBackRestoresPool {
    GBTTestBoard *board = self.board;
    GroupingTeachingSequence *sequence = [self storySequence:23 second:4 meaning:GroupingStoryMeaningMakeGroupsOf];
    NSInteger index = [self firstIndex:GroupingTeachingStepKindPackGroup inSequence:sequence];
    [board configureWithSequence:sequence stepIndex:index animated:NO];
    XCTAssertEqual([[board valueForKey:@"groupViews"] count], 1u);
    XCTAssertEqual([[board valueForKey:@"poolCounters"] count], 19u);
    XCTAssertEqualObjects([self label:@"groupingGroupCount0" inView:board].text, @"4 顆");
    XCTAssertTrue([board.accessibilityValue containsString:@"已分成 1 包"]);
    XCTAssertTrue([board.accessibilityValue containsString:@"答案還沒寫"]);
    XCTAssertEqual([self stationaryCounterCount:board], 23u);
    [board showStepAtIndex:0 animated:NO];
    XCTAssertEqual([[board valueForKey:@"groupViews"] count], 0u);
    XCTAssertEqual([[board valueForKey:@"poolCounters"] count], 23u);
    XCTAssertNil([self label:@"groupingRemainder" inView:board]);
}

- (void)testMultiplicationUsesKnownUnopenedGroupsWithoutPreDisplayingProduct {
    GBTTestBoard *board = self.board;
    GroupingTeachingSequence *sequence = [self storySequence:3 second:4 meaning:GroupingStoryMeaningBuildEqualGroups];
    [board configureWithSequence:sequence stepIndex:0 animated:NO];
    XCTAssertEqual([[board valueForKey:@"poolCounters"] count], 0u);
    XCTAssertEqual([[board valueForKey:@"groupViews"] count], 0u);
    XCTAssertTrue([board.accessibilityValue containsString:@"還有 4 包尚未建立"]);
    NSInteger index = [self firstIndex:GroupingTeachingStepKindBuildGroup inSequence:sequence];
    [board showStepAtIndex:index animated:NO];
    XCTAssertEqual([[board valueForKey:@"groupViews"] count], 1u);
    XCTAssertTrue([board.accessibilityValue containsString:@"已建立 1 包"]);
    XCTAssertTrue([board.accessibilityValue containsString:@"還有 3 包尚未建立"]);
    XCTAssertFalse([board.accessibilityValue containsString:@"12"]);
    XCTAssertEqual([self stationaryCounterCount:board], 3u);
    XCTAssertNil([self label:@"groupingRemainder" inView:board]);
}

- (void)testOnlyExplicitSnapshotFieldsRevealAnswerAndCommonRemainder {
    GBTTestBoard *board = self.board;
    GroupingTeachingSequence *sequence = [self storySequence:23 second:4 meaning:GroupingStoryMeaningMakeGroupsOf];
    for (NSInteger i = 0; i < (NSInteger)sequence.steps.count; i++) {
        [board configureWithSequence:sequence stepIndex:i animated:NO];
        GroupingTeachingStep *step = sequence.steps[i];
        UILabel *answer = [self label:@"groupingAnswer" inView:board];
        if (step.visibleAnswer) XCTAssertEqualObjects(answer.text, @"寫下：5 包");
        else XCTAssertEqualObjects(answer.text, @"答案還沒寫，先把數量看清楚。");
        UILabel *remainder = [self label:@"groupingRemainder" inView:board];
        if (step.visibleRemainder) XCTAssertTrue([remainder.text containsString:@"共同剩下：3 顆糖果"]);
        else XCTAssertNil(remainder);
    }
    [board showStepAtIndex:0 animated:NO];
    XCTAssertFalse([board.accessibilityValue containsString:@"寫下：5"]);
    XCTAssertNil([self label:@"groupingRemainder" inView:board]);
}

- (void)testZeroQuotientAndZeroSizeGroupRemainExplicitRatherThanInventingObjects {
    GBTTestBoard *board = self.board;
    GroupingTeachingSequence *pack = [self storySequence:3 second:4 meaning:GroupingStoryMeaningMakeGroupsOf];
    NSInteger write = [self firstIndex:GroupingTeachingStepKindWriteAnswer inSequence:pack];
    [board configureWithSequence:pack stepIndex:write animated:NO];
    XCTAssertEqual([[board valueForKey:@"groupViews"] count], 0u);
    XCTAssertEqual([[board valueForKey:@"poolCounters"] count], 3u);
    XCTAssertEqualObjects([self label:@"groupingAnswer" inView:board].text, @"寫下：0 包");
    GroupingTeachingSequence *build = [self storySequence:0 second:3 meaning:GroupingStoryMeaningBuildEqualGroups];
    NSInteger action = [self firstIndex:GroupingTeachingStepKindBuildGroup inSequence:build];
    [board configureWithSequence:build stepIndex:action animated:NO];
    XCTAssertEqual([[board valueForKey:@"groupViews"] count], 1u);
    XCTAssertEqual([self stationaryCounterCount:board], 0u);
    XCTAssertEqualObjects([self label:@"groupingGroupCount0" inView:board].text, @"0 顆");
    XCTAssertTrue(CGRectIsNull(board.currentTransformationRect));
}

- (void)testAllCounterAndLabelFramesFitCompactWideAndLargeTextWidths {
    GBTTestBoard *board = self.board;
    [self hostBoard:board];
    GroupingTeachingSequence *sequence = [self storySequence:90 second:9 meaning:GroupingStoryMeaningShareEqually];
    NSArray<NSNumber *> *steps = @[@0, @(sequence.steps.count - 1)];
    NSArray<NSString *> *categories = @[UIContentSizeCategoryLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
    for (NSString *category in categories) {
        // Override just Dynamic Type through UIKit. Replacing traitCollection
        // with a partial collection discards required inherited display traits.
        board.traitOverrides.preferredContentSizeCategory = category;
        [board setNeedsLayout];
        [board layoutIfNeeded];
        XCTAssertEqualObjects(board.traitCollection.preferredContentSizeCategory, category);
        UITraitCollection *hostTraits = self.hostWindow.rootViewController.view.traitCollection;
        XCTAssertGreaterThan(board.traitCollection.displayScale, 0);
        XCTAssertNotEqual(board.traitCollection.userInterfaceIdiom, UIUserInterfaceIdiomUnspecified);
        XCTAssertEqual(board.traitCollection.displayScale, hostTraits.displayScale);
        XCTAssertEqual(board.traitCollection.userInterfaceIdiom, hostTraits.userInterfaceIdiom);
        XCTAssertEqual(board.traitCollection.userInterfaceStyle, hostTraits.userInterfaceStyle);
        for (NSNumber *step in steps) for (NSNumber *width in @[@288, @320, @680]) {
            [board configureWithSequence:sequence stepIndex:step.integerValue animated:NO];
            [self fit:board width:width.doubleValue];
            XCTAssertEqualWithAccuracy(CGRectGetWidth(board.bounds), width.doubleValue, 0.1);
            UIView *content = [board valueForKey:@"contentView"];
            XCTAssertEqualObjects(content.traitCollection.preferredContentSizeCategory, category);
            XCTAssertLessThanOrEqual(CGRectGetHeight(content.bounds), CGRectGetHeight(board.bounds) + 0.1);
            [self assertSubviewWidths:content];
            XCTAssertEqual([self stationaryCounterCount:board], 90u);
        }
    }
    [board.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
    [board setNeedsLayout];
    [board layoutIfNeeded];
    XCTAssertEqualObjects(board.traitCollection.preferredContentSizeCategory,
        self.hostWindow.rootViewController.view.traitCollection.preferredContentSizeCategory);
}

- (void)testEstablishedGroupGeometryDoesNotJumpWhenAnotherGroupIsPrepared {
    GBTTestBoard *board = self.board;
    NSArray<GroupingTeachingSequence *> *sequences = @[
        [self storySequence:23 second:4 meaning:GroupingStoryMeaningMakeGroupsOf],
        [self storySequence:3 second:4 meaning:GroupingStoryMeaningBuildEqualGroups],
        [self storySequence:23 second:4 meaning:GroupingStoryMeaningShareEqually]
    ];
    for (GroupingTeachingSequence *sequence in sequences) for (NSNumber *width in @[@288, @680]) {
        CGRect firstGroup = CGRectNull;
        for (NSInteger i = 0; i < (NSInteger)sequence.steps.count; i++) {
            [board configureWithSequence:sequence stepIndex:i animated:NO];
            [self fit:board width:width.doubleValue];
            NSArray<UIView *> *groups = [board valueForKey:@"groupViews"];
            if (!groups.count) continue;
            CGRect frame = groups.firstObject.frame;
            if (CGRectIsNull(firstGroup)) firstGroup = frame;
            XCTAssertEqualWithAccuracy(frame.origin.x, firstGroup.origin.x, 0.1);
            XCTAssertEqualWithAccuracy(frame.origin.y, firstGroup.origin.y, 0.1);
            XCTAssertEqualWithAccuracy(frame.size.width, firstGroup.size.width, 0.1);
            XCTAssertEqualWithAccuracy(frame.size.height, firstGroup.size.height, 0.1);
        }
    }
}

- (void)testMovingSharingRoundConservesPoolGroupsAndSeparatelyCountedMovers {
    GBTTestBoard *board = self.board;
    GroupingTeachingSequence *sequence = [self storySequence:23 second:4 meaning:GroupingStoryMeaningShareEqually];
    NSInteger index = [self firstIndex:GroupingTeachingStepKindShareRound inSequence:sequence];
    [board configureWithSequence:sequence stepIndex:index animated:NO];
    [self fit:board width:288];
    CGRect focus = board.currentTransformationRect;
    XCTAssertFalse(CGRectIsNull(focus));
    XCTAssertTrue(CGRectContainsRect(board.bounds, focus));
    board.allowMotion = YES;
    [board showStepAtIndex:index animated:YES];
    XCTAssertNotNil([board valueForKey:@"animationDisplayLink"]);
    XCTAssertEqual([[board valueForKey:@"transfers"] count], 4u);
    XCTAssertEqual([self stationaryCounterCount:board], 19u);
    XCTAssertTrue([board.accessibilityValue containsString:@"待分的糖果：23 顆"]);
    NSArray *transfers = [board valueForKey:@"transfers"];
    for (id transfer in transfers) {
        UIView *counter = [transfer valueForKey:@"counter"];
        CGPoint start = [[transfer valueForKey:@"start"] CGPointValue];
        XCTAssertEqualWithAccuracy(counter.center.x, start.x, 0.1);
        XCTAssertEqualWithAccuracy(counter.center.y, start.y, 0.1);
    }
    [board renderAnimationAtProgress:0.5];
    XCTAssertTrue([board.accessibilityValue containsString:@"待分的糖果：19 顆"]);
    XCTAssertTrue([board.accessibilityValue containsString:@"第 1 個小朋友有 0 顆"]);
    XCTAssertTrue([board.accessibilityValue containsString:@"另外有 4 顆正在移動"]);
    XCTAssertEqual([self stationaryCounterCount:board] + [[board valueForKey:@"transfers"] count], 23u);
    [board renderAnimationAtProgress:1.0];
    [self assertSettled:board step:index];
    XCTAssertEqual([self stationaryCounterCount:board], 23u);
    XCTAssertEqualObjects([self label:@"groupingGroupCount0" inView:board].text, @"1 顆");
    XCTAssertTrue([board.accessibilityValue containsString:@"答案還沒寫"]);
}

- (void)testPackingAndBuildReplayUseTheirOwnSourceGeometry {
    GBTTestBoard *board = self.board;
    NSArray<GroupingTeachingSequence *> *sequences = @[
        [self storySequence:23 second:4 meaning:GroupingStoryMeaningMakeGroupsOf],
        [self storySequence:3 second:4 meaning:GroupingStoryMeaningBuildEqualGroups]
    ];
    for (GroupingTeachingSequence *sequence in sequences) {
        BOOL build = sequence.context.meaning == GroupingStoryMeaningBuildEqualGroups;
        NSInteger index = [self firstIndex:build ? GroupingTeachingStepKindBuildGroup : GroupingTeachingStepKindPackGroup inSequence:sequence];
        [board configureWithSequence:sequence stepIndex:index animated:NO];
        [self fit:board width:320];
        board.allowMotion = YES;
        for (NSInteger replay = 0; replay < 2; replay++) {
            [board showStepAtIndex:index animated:YES];
            NSArray *transfers = [board valueForKey:@"transfers"];
            XCTAssertEqual(transfers.count, build ? 3u : 4u);
            for (id transfer in transfers) {
                CGPoint start = [[transfer valueForKey:@"start"] CGPointValue];
                CGPoint end = [[transfer valueForKey:@"end"] CGPointValue];
                XCTAssertGreaterThan(end.y, start.y);
                XCTAssertTrue(CGRectContainsPoint(board.currentTransformationRect, start));
                XCTAssertTrue(CGRectContainsPoint(board.currentTransformationRect, end));
            }
            [board renderAnimationAtProgress:0.82];
            XCTAssertTrue([board.accessibilityValue containsString:@"第 1 包有"]);
            [board cancelAnimations];
            [self assertSettled:board step:index];
        }
    }
}

- (void)testCancellationAndResizeSettleOnlySelectedStepAndReleaseClock {
    GBTTestBoard *board = self.board;
    GroupingTeachingSequence *sequence = [self storySequence:23 second:4 meaning:GroupingStoryMeaningShareEqually];
    NSInteger index = [self firstIndex:GroupingTeachingStepKindShareRound inSequence:sequence];
    [board configureWithSequence:sequence stepIndex:index animated:NO];
    [self fit:board width:320];
    board.allowMotion = YES;
    for (NSInteger interruption = 0; interruption < 5; interruption++) {
        [board showStepAtIndex:index animated:YES];
        [board renderAnimationAtProgress:0.4];
        if (interruption == 0) { board.hidden = YES; board.hidden = NO; }
        else if (interruption == 1) [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
        else if (interruption == 2) [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
        else if (interruption == 3) [self fit:board width:288];
        else { board.alpha = 0; board.alpha = 1; }
        [self assertSettled:board step:index];
        XCTAssertEqual([self stationaryCounterCount:board], 23u);
        XCTAssertTrue([board.accessibilityValue containsString:@"第 1 個小朋友有 1 顆"]);
        XCTAssertTrue([board.accessibilityValue containsString:@"答案還沒寫"]);
    }
    [board showStepAtIndex:0 animated:NO];
    XCTAssertEqual([[board valueForKey:@"poolCounters"] count], 23u);
    XCTAssertEqualObjects([self label:@"groupingGroupCount0" inView:board].text, @"0 顆");
}

- (void)testDisabledMotionInvalidIndicesAndZeroWidthAreSafe {
    GBTTestBoard *board = [self boardWithFrame:CGRectZero];
    GroupingTeachingSequence *sequence = [self storySequence:23 second:4 meaning:GroupingStoryMeaningMakeGroupsOf];
    NSInteger index = [self firstIndex:GroupingTeachingStepKindPackGroup inSequence:sequence];
    XCTAssertTrue([board configureWithSequence:sequence stepIndex:index animated:YES]);
    XCTAssertNil([board valueForKey:@"animationDisplayLink"]);
    [self fit:board width:288];
    XCTAssertEqual([self stationaryCounterCount:board], 23u);
    XCTAssertFalse([board showStepAtIndex:-1 animated:YES]);
    XCTAssertNil(board.sequence);
    XCTAssertNil(board.currentStep);
    XCTAssertEqual(board.subviews.count, 0u);
    XCTAssertNil(board.accessibilityValue);
    XCTAssertFalse(board.isAccessibilityElement);
    XCTAssertTrue(CGRectIsNull(board.currentTransformationRect));
    XCTAssertFalse([board configureWithSequence:nil stepIndex:0 animated:NO]);
}
@end

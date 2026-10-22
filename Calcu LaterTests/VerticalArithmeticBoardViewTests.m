#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "VerticalArithmeticBoardView.h"
#import "ArithmeticProblem.h"

static void VABRecordPathStart(void *info, const CGPathElement *element) {
    if (element->type == kCGPathElementMoveToPoint) *((CGPoint *)info) = element->points[0];
}

static CFTimeInterval VABTimeAtOrAfterElapsed(CFTimeInterval start, CFTimeInterval elapsed) {
    CFTimeInterval candidate = start + elapsed;
    return candidate - start < elapsed ? nextafter(candidate, INFINITY) : candidate;
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
@property (nonatomic, strong) UIWindow *presentationWindow;
@property (nonatomic, strong) UIWindow *previousKeyWindow;
@property (nonatomic, strong) UIWindow *traitHostWindow;
@property (nonatomic, strong) NSMutableArray<VABAnimationTestBoard *> *traitFixtureBoards;
@end
@implementation VerticalArithmeticBoardViewTests

- (void)releasePresentationWindow {
    for (UIView *view in self.presentationWindow.rootViewController.view.subviews) {
        if ([view isKindOfClass:VerticalArithmeticBoardView.class]) [(VerticalArithmeticBoardView *)view cancelAnimations];
    }
    self.presentationWindow.hidden = YES;
    self.presentationWindow.rootViewController = nil;
    self.presentationWindow = nil;
    UIWindow *previous = self.previousKeyWindow;
    self.previousKeyWindow = nil;
    if (previous) {
        UIWindowScene *scene = previous.windowScene;
        XCTAssertNotNil(scene);
        XCTAssertFalse(previous.hidden, @"Restore the original visible key window, not a fabricated replacement.");
        XCTAssertEqual(scene.activationState, UISceneActivationStateForegroundActive);
        if (scene && !previous.hidden && scene.activationState == UISceneActivationStateForegroundActive) {
            [previous makeKeyWindow];
            XCTAssertTrue(previous.isKeyWindow);
        }
    }
}

- (void)tearDown {
    // Keep every trait fixture reachable for cleanup even if an assertion throws.
    // Let UIKit remove the override; never replace a view's inherited collection.
    for (VABAnimationTestBoard *board in self.traitFixtureBoards) {
        [board cancelAnimations];
        [board.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
        [board removeFromSuperview];
    }
    self.traitFixtureBoards = nil;
    self.traitHostWindow.hidden = YES;
    self.traitHostWindow.rootViewController = nil;
    self.traitHostWindow = nil;
    [self releasePresentationWindow];
    [super tearDown];
}

- (UIView *)traitHostView {
    if (!self.traitHostWindow) {
        UIWindowScene *foreground = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
                foreground = (UIWindowScene *)scene;
                break;
            }
        }
        XCTAssertNotNil(foreground, @"Trait propagation needs the component run's real foreground scene.");
        self.traitHostWindow = [[UIWindow alloc] initWithWindowScene:foreground];
        self.traitHostWindow.frame = foreground.coordinateSpace.bounds;
        self.traitHostWindow.rootViewController = [[UIViewController alloc] init];
        self.traitHostWindow.hidden = NO; // Do not replace the app's key window.
        [self.traitHostWindow layoutIfNeeded];
        [self.traitHostWindow.rootViewController.view layoutIfNeeded];
    }
    return self.traitHostWindow.rootViewController.view;
}

- (VABAnimationTestBoard *)traitBoardWithFrame:(CGRect)frame inView:(UIView *)host {
    VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:frame];
    if (!self.traitFixtureBoards) self.traitFixtureBoards = [NSMutableArray array];
    [self.traitFixtureBoards addObject:board];
    board.autoresizingMask = UIViewAutoresizingNone;
    [host addSubview:board];
    XCTAssertEqual(board.window, host.window);
    XCTAssertNotNil(board.window.windowScene);
    return board;
}

- (void)assertTraitsForBoard:(VABAnimationTestBoard *)board category:(UIContentSizeCategory)category {
    UITraitCollection *hostTraits = board.window.rootViewController.view.traitCollection;
    XCTAssertEqualObjects(board.traitCollection.preferredContentSizeCategory, category);
    XCTAssertGreaterThan(board.traitCollection.displayScale, 0);
    XCTAssertNotEqual(board.traitCollection.userInterfaceIdiom, UIUserInterfaceIdiomUnspecified);
    XCTAssertEqual(board.traitCollection.displayScale, hostTraits.displayScale);
    XCTAssertEqual(board.traitCollection.userInterfaceIdiom, hostTraits.userInterfaceIdiom);
    XCTAssertEqual(board.traitCollection.userInterfaceStyle, hostTraits.userInterfaceStyle);
    UIView *content = [board valueForKey:@"contentView"];
    XCTAssertEqualObjects(content.traitCollection.preferredContentSizeCategory, category);
}

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

- (void)testRegroupingFocusUsesActualSelectedGeometryWithoutFutureAnswers {
    NSArray<ArithmeticTeachingSequence *> *sequences = @[
        [self sequence:27 second:15 operation:@"+"],
        [self sequence:500 second:128 operation:@"-"]
    ];
    VerticalArithmeticBoardView *board = self.board;
    XCTAssertTrue(CGRectIsNull(board.currentTransformationRect));
    XCTAssertTrue(CGRectIsNull(board.currentConcreteTransformationRect));
    NSUInteger regroupCases = 0;
    for (ArithmeticTeachingSequence *sequence in sequences) {
        XCTAssertTrue(sequence.isValid);
        for (NSNumber *width in @[@288, @343, @680]) {
            for (NSInteger index = 0; index < (NSInteger)sequence.steps.count; index++) {
                [board configureWithSequence:sequence stepIndex:index animated:NO];
                [self fitBoard:board width:width.doubleValue];
                CGRect full = board.currentTransformationRect;
                CGRect concrete = board.currentConcreteTransformationRect;
                if (sequence.steps[index].kind != ArithmeticTeachingStepKindRegroup) {
                    XCTAssertTrue(CGRectIsNull(full));
                    XCTAssertTrue(CGRectIsNull(concrete));
                    continue;
                }
                regroupCases++;
                UIView *grid = [board valueForKey:@"gridView"];
                UIView *illustration = [board valueForKey:@"illustrationView"];
                CGRect actualGrid = [grid convertRect:grid.bounds toView:board];
                CGRect actualConcrete = [illustration convertRect:illustration.bounds toView:board];
                XCTAssertFalse(CGRectIsNull(full));
                XCTAssertFalse(CGRectIsEmpty(concrete));
                XCTAssertTrue(CGRectEqualToRect(concrete, actualConcrete));
                XCTAssertTrue(CGRectEqualToRect(full, CGRectUnion(actualGrid, actualConcrete)));
                XCTAssertTrue(CGRectContainsRect(full, actualGrid));
                XCTAssertTrue(CGRectContainsRect(full, actualConcrete));
                XCTAssertTrue(CGRectContainsRect(board.bounds, full));
                XCTAssertEqual(board.currentStepIndex, index);
                XCTAssertTrue([board.accessibilityValue containsString:@"答案還沒寫"]);
            }
        }
    }
    XCTAssertEqual(regroupCases, 9u);
    [board configureWithSequence:nil stepIndex:0 animated:NO];
    XCTAssertTrue(CGRectIsNull(board.currentTransformationRect));
    XCTAssertTrue(CGRectIsNull(board.currentConcreteTransformationRect));
}

- (void)testOnlySnapshotAnswerDigitsAreRenderedIncludingBackAndReplay {
    ArithmeticTeachingSequence *sequence = [self sequence:500 second:128 operation:@"-"];
    VerticalArithmeticBoardView *board = self.board;
    for (NSInteger i = 0; i < (NSInteger)sequence.steps.count; i++) {
        XCTAssertTrue([board configureWithSequence:sequence stepIndex:i animated:NO]);
        for (NSInteger column = 0; column < sequence.columnCount; column++) {
            id digit = sequence.steps[i].visibleAnswerDigits[column];
            NSString *expected = [digit isKindOfClass:NSNumber.class] ? [digit stringValue] : @"";
            NSString *identifier = [NSString stringWithFormat:@"verticalAnswer%ld", (long)column];
            XCTAssertEqualObjects([self label:identifier inView:board].text, expected);
        }
    }
    XCTAssertTrue([board showStepAtIndex:0 animated:NO]);
    for (NSInteger column = 0; column < sequence.columnCount; column++) {
        NSString *answerIdentifier = [NSString stringWithFormat:@"verticalAnswer%ld", (long)column];
        NSString *workingIdentifier = [NSString stringWithFormat:@"verticalWorking%ld", (long)column];
        XCTAssertEqualObjects([self label:answerIdentifier inView:board].text, @"");
        XCTAssertEqualObjects([self label:workingIdentifier inView:board].text, @"");
    }
    XCTAssertFalse([board.accessibilityValue containsString:@"372"]);
    XCTAssertTrue([board.accessibilityValue containsString:@"500 減 128"]);
    XCTAssertFalse(board.isAccessibilityElement);
    UIAccessibilityElement *summary = board.accessibilityElements.firstObject;
    XCTAssertEqualObjects(summary.accessibilityIdentifier, @"verticalTeachingBoard");
    XCTAssertEqualObjects(summary.accessibilityValue, board.accessibilityValue);
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
    [board configureWithSequence:sequence stepIndex:index animated:NO];
    [self fitBoard:board width:320];
    [board showStepAtIndex:index animated:YES];
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
    // This tests the no-motion rendering gate, not the system preference.
    // Actual Reduce Motion acceptance toggles Settings and checks runtime state.
    board.allowMotion = NO;
    [board animationTick:nil];
    [self assertCancelled:board index:index];
    XCTAssertEqualObjects([self label:@"verticalAnswer2" inView:board].text, @"");
    XCTAssertEqualObjects([self label:@"verticalExchangeCounts" inView:board].text, @"百位 5 → 4　・　十位 0 → 10");
}

- (void)testMotionDisabledStaticRenderHasSameCountsAndNoTransfers {
    ArithmeticTeachingSequence *sequence = [self sequence:500 second:128 operation:@"-"];
    VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:CGRectMake(0, 0, 320, 500)];
    // This tests the no-motion rendering gate, not the system preference.
    // Actual Reduce Motion acceptance toggles Settings and checks runtime state.
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
- (void)testConcreteOnlyPlaybackRequiresTheWholeActionAndKeepsHiddenNotationStill {
    for (ArithmeticTeachingSequence *sequence in @[[self sequence:27 second:15 operation:@"+"], [self sequence:500 second:128 operation:@"-"]]) {
        VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:CGRectMake(0, 0, 680, 600)];
        board.allowMotion = YES;
        for (NSInteger index = 0; index < (NSInteger)sequence.steps.count; index++) {
            if (sequence.steps[index].kind != ArithmeticTeachingStepKindRegroup) continue;
            [board configureWithSequence:sequence stepIndex:index animated:NO];
            [self fitBoard:board width:680];
            CGRect concrete = board.currentConcreteTransformationRect;
            NSString *snapshot = board.accessibilityValue;
            XCTAssertTrue([board playCurrentActionInVisibleRect:concrete]);
            XCTAssertTrue(board.isPlaying);
            XCTAssertTrue(CGRectEqualToRect(board.currentPlaybackRect, concrete));
            XCTAssertNil([self label:@"verticalMovingExchange" inView:board]);
            XCTAssertNil([self label:@"verticalBeforeExchange" inView:board]);
            for (UILabel *label in [board valueForKey:@"annotationLabels"]) XCTAssertEqual(label.layer.animationKeys.count, 0u);
            BOOL carry = sequence.steps[index].destinationColumn < sequence.steps[index].sourceColumn;
            XCTAssertEqual([[board valueForKey:@"exchangeSourceUnits"] count], carry ? 10u : 1u);
            XCTAssertEqual([[board valueForKey:@"exchangeDestinationUnits"] count], carry ? 1u : 10u);
            XCTAssertEqualObjects(board.accessibilityValue, snapshot);
            XCTAssertTrue([snapshot containsString:@"答案還沒寫"]);
            XCTAssertFalse([board playCurrentActionInVisibleRect:CGRectInset(concrete, 0, 1)]);
            [self assertCancelled:board index:index];
            XCTAssertFalse([board playCurrentActionInVisibleRect:CGRectInset(concrete, 1, 0)]);
            [self assertCancelled:board index:index];
            XCTAssertTrue([board playCurrentActionInVisibleRect:board.currentTransformationRect]);
            XCTAssertNotNil([self label:@"verticalMovingExchange" inView:board]);
            XCTAssertEqualObjects(board.accessibilityValue, snapshot);
            [board cancelAnimations];
        }
    }
}
- (void)testSemanticAccessibilityGeometryMatchesTheRealExchangeIncludingColumnConnection {
    ArithmeticTeachingSequence *sequence = [self sequence:500 second:128 operation:@"-"];
    NSInteger index = [self firstIndexOfKind:ArithmeticTeachingStepKindRegroup inSequence:sequence];
    VerticalArithmeticBoardView *board = self.board;
    for (NSNumber *width in @[@288, @343, @680]) {
        [board configureWithSequence:sequence stepIndex:index animated:NO];
        [self fitBoard:board width:width.doubleValue];
        NSArray *elements = board.accessibilityElements;
        XCTAssertEqual(elements.count, 2u);
        UIAccessibilityElement *exchange = elements.lastObject;
        XCTAssertEqualObjects(exchange.accessibilityIdentifier, @"verticalTeachingExchange");
        XCTAssertTrue(CGRectEqualToRect(exchange.accessibilityFrameInContainerSpace, board.currentConcreteTransformationRect));
        XCTAssertTrue([exchange.accessibilityValue containsString:@"百位 5 → 4"]);
        XCTAssertTrue([exchange.accessibilityValue containsString:@"十位 0 → 10"]);
        UILabel *counts = [self label:@"verticalExchangeCounts" inView:board];
        XCTAssertTrue(CGRectContainsRect(board.currentConcreteTransformationRect, [counts convertRect:counts.bounds toView:board]));
        XCTAssertFalse([exchange.accessibilityValue containsString:@"個位 0 → 10"]);
        XCTAssertFalse([board.accessibilityValue containsString:@"372"]);
    }
}
- (void)testNaturalDisplayLinkCompletionIsDistinctFromCancellationAndNeverAdvances {
    VABAnimationTestBoard *board = [self animatedBoardForSequence:[self sequence:500 second:128 operation:@"-"]];
    NSInteger index = board.currentStepIndex;
    NSString *snapshot = board.accessibilityValue;
    UIAccessibilityElement *exchange = board.accessibilityElements.lastObject;
    XCTAssertTrue(board.isPlaying);
    XCTAssertTrue([exchange.accessibilityValue containsString:@"正在交換"]);
    XCTestExpectation *settled = [self expectationWithDescription:@"The real finite display link completes without intervention"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateCompleted);
        XCTAssertFalse(board.isPlaying);
        [self assertCancelled:board index:index];
        XCTAssertTrue([exchange.accessibilityValue containsString:@"動態已播放完成"]);
        XCTAssertEqualObjects(board.accessibilityValue, snapshot);
        [settled fulfill];
    });
    [self waitForExpectations:@[settled] timeout:2.0];
    [board showStepAtIndex:index animated:YES];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateInterrupted);
    XCTAssertFalse([((UIAccessibilityElement *)board.accessibilityElements.lastObject).accessibilityValue containsString:@"動態已播放完成"]);
    XCTAssertEqual(board.currentStepIndex, index);
    [board showStepAtIndex:0 animated:NO];
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateStill);
    XCTAssertTrue(CGRectIsNull(board.currentActionRect));
    XCTAssertFalse([board playCurrentActionInVisibleRect:board.bounds]);
}
- (void)testCallerRectCannotAuthorizePlaybackOutsideAnActualClippingAncestor {
    ArithmeticTeachingSequence *sequence = [self sequence:27 second:15 operation:@"+"];
    VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:CGRectMake(0, 0, 320, 500)];
    board.allowMotion = YES;
    NSInteger index = [self firstIndexOfKind:ArithmeticTeachingStepKindRegroup inSequence:sequence];
    [board configureWithSequence:sequence stepIndex:index animated:NO];
    [self fitBoard:board width:320];
    CGRect action = board.currentConcreteTransformationRect;
    UIView *viewport = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, action.size.height - 1)];
    viewport.clipsToBounds = YES;
    [viewport addSubview:board];
    board.frame = CGRectOffset(board.frame, 0, -action.origin.y);
    XCTAssertFalse([board playCurrentActionInVisibleRect:action]);
    XCTAssertFalse(board.isPlaying);
    viewport.frame = CGRectMake(0, 0, 320, action.size.height);
    XCTAssertTrue([board playCurrentActionInVisibleRect:action]);
    XCTAssertTrue(board.isPlaying);
    [board cancelAnimations];
}
- (void)testOmittedLeadingZeroHasNoActionOrPlaybackToFrame {
    NSUInteger omittedColumns = 0;
    for (ArithmeticTeachingSequence *sequence in @[[self sequence:100 second:1 operation:@"-"], [self sequence:500 second:499 operation:@"-"]]) {
        VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:CGRectMake(0, 0, 320, 500)];
        board.allowMotion = YES;
        for (NSInteger index = 0; index < (NSInteger)sequence.steps.count; index++) {
            ArithmeticTeachingStep *step = sequence.steps[index];
            if (step.kind != ArithmeticTeachingStepKindWriteAnswer
                || step.visibleAnswerDigits[step.activeColumn] != NSNull.null) continue;
            omittedColumns++;
            [board configureWithSequence:sequence stepIndex:index animated:NO];
            [self fitBoard:board width:320];
            NSString *identifier = [NSString stringWithFormat:@"verticalAnswer%ld", (long)step.activeColumn];
            XCTAssertEqual([self label:identifier inView:board].text.length, 0u);
            XCTAssertTrue([step.explanation containsString:@"最左邊多出來的 0 不用寫"]);
            NSString *snapshot = board.accessibilityValue;
            XCTAssertTrue(CGRectIsNull(board.currentActionRect));
            XCTAssertTrue(CGRectIsNull(board.currentPlaybackRect));
            XCTAssertFalse([board playCurrentActionInVisibleRect:board.bounds]);
            XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateStill);
            [self assertCancelled:board index:index];
            [board showStepAtIndex:index animated:YES];
            XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateStill);
            XCTAssertEqualObjects(board.accessibilityValue, snapshot);
            [self assertCancelled:board index:index];
        }
    }
    XCTAssertEqual(omittedColumns, 3u);
}

#pragma mark - Conserved selected-column exchange material

- (NSArray<NSNumber *> *)regroupIndices:(ArithmeticTeachingSequence *)sequence {
    NSMutableArray<NSNumber *> *indices = [NSMutableArray array];
    for (NSInteger index = 0; index < (NSInteger)sequence.steps.count; index++) {
        if (sequence.steps[index].kind == ArithmeticTeachingStepKindRegroup) [indices addObject:@(index)];
    }
    return indices;
}

- (NSArray<NSArray *> *)knownExchangeCases {
    // Operands, operation, exchange ordinal, source before/after, destination
    // before/after, and the value of ONLY these two working columns.
    return @[
        @[@27, @15, @"+", @0, @12, @2, @2, @3, @32],
        @[@500, @128, @"-", @0, @5, @4, @0, @10, @500],
        @[@500, @128, @"-", @1, @10, @9, @0, @10, @100],
        @[@108, @19, @"-", @0, @1, @0, @0, @10, @100],
        @[@108, @19, @"-", @1, @10, @9, @8, @18, @108],
        @[@10, @1, @"-", @0, @1, @0, @0, @10, @10],
        @[@5, @5, @"+", @0, @10, @0, @0, @1, @10],
        @[@99, @1, @"+", @0, @10, @0, @9, @10, @100],
        @[@99, @1, @"+", @1, @10, @0, @0, @1, @100],
        @[@99, @99, @"+", @0, @18, @8, @9, @10, @108],
        @[@99, @99, @"+", @1, @19, @9, @0, @1, @190]
    ];
}

- (NSInteger)valueOfUnits:(NSArray<UIView *> *)units {
    NSInteger value = 0;
    for (UIView *unit in units) {
        NSInteger unitValue = 1;
        for (NSInteger place = 0; place < [[unit valueForKey:@"place"] integerValue]; place++) unitValue *= 10;
        value += unitValue;
    }
    return value;
}

- (NSArray<UIView *> *)retainedUnits:(VerticalArithmeticBoardView *)board {
    return [[board valueForKey:@"retainedSourceUnits"] arrayByAddingObjectsFromArray:[board valueForKey:@"retainedDestinationUnits"]];
}

- (NSArray<UIView *> *)allExchangeUnits:(VerticalArithmeticBoardView *)board {
    NSArray *changed = [[board valueForKey:@"exchangeSourceUnits"] arrayByAddingObjectsFromArray:[board valueForKey:@"exchangeDestinationUnits"]];
    return [changed arrayByAddingObjectsFromArray:[self retainedUnits:board]];
}

- (NSArray<NSValue *> *)framesOfUnits:(NSArray<UIView *> *)units {
    NSMutableArray<NSValue *> *frames = [NSMutableArray array];
    for (UIView *unit in units) [frames addObject:[NSValue valueWithCGRect:unit.frame]];
    return frames;
}

- (void)assertRetainedUnits:(NSArray<UIView *> *)original frames:(NSArray<NSValue *> *)frames inBoard:(VerticalArithmeticBoardView *)board {
    NSArray<UIView *> *current = [self retainedUnits:board];
    XCTAssertEqual(current.count, original.count);
    for (NSUInteger index = 0; index < original.count; index++) {
        UIView *unit = original[index];
        XCTAssertEqual(current[index], unit, @"Replay/cancellation must not replace an unchanged object.");
        XCTAssertTrue(CGRectEqualToRect(unit.frame, frames[index].CGRectValue));
        XCTAssertEqualWithAccuracy(unit.alpha, 1, 0.0001);
        XCTAssertEqualWithAccuracy(unit.layer.opacity, 1, 0.0001);
        XCTAssertFalse(unit.hidden);
        XCTAssertTrue(CGAffineTransformIsIdentity(unit.transform));
        XCTAssertEqual(unit.layer.animationKeys.count, 0u);
        XCTAssertFalse([[board valueForKey:@"animatedLayers"] containsObject:unit.layer]);
        XCTAssertFalse([[board valueForKey:@"transientViews"] containsObject:unit]);
    }
}

- (void)testEverySelectedExchangeIncludesExactBeforeAfterQuantitiesAndValueWithoutDoubleCountingCarry {
    for (NSArray *entry in [self knownExchangeCases]) {
        ArithmeticTeachingSequence *sequence = [self sequence:[entry[0] integerValue] second:[entry[1] integerValue] operation:entry[2]];
        NSInteger index = [self regroupIndices:sequence][[entry[3] unsignedIntegerValue]].integerValue;
        VerticalArithmeticBoardView *board = self.board;
        [board configureWithSequence:sequence stepIndex:index animated:NO];
        [self fitBoard:board width:288];
        ArithmeticTeachingStep *step = board.currentStep;
        NSArray *source = [board valueForKey:@"exchangeSourceUnits"];
        NSArray *destination = [board valueForKey:@"exchangeDestinationUnits"];
        NSArray *retainedSource = [board valueForKey:@"retainedSourceUnits"];
        NSArray *retainedDestination = [board valueForKey:@"retainedDestinationUnits"];
        XCTAssertEqualObjects(step.workingDigitsBefore[step.sourceColumn], entry[4]);
        XCTAssertEqualObjects(step.workingDigits[step.sourceColumn], entry[5]);
        XCTAssertEqualObjects(step.workingDigitsBefore[step.destinationColumn], entry[6]);
        XCTAssertEqualObjects(step.workingDigits[step.destinationColumn], entry[7]);
        XCTAssertEqual(source.count + retainedSource.count, [entry[4] unsignedIntegerValue]);
        XCTAssertEqual(retainedSource.count, [entry[5] unsignedIntegerValue]);
        XCTAssertEqual(retainedDestination.count, [entry[6] unsignedIntegerValue]);
        XCTAssertEqual(destination.count + retainedDestination.count, [entry[7] unsignedIntegerValue]);
        NSInteger unchangedValue = [self valueOfUnits:[self retainedUnits:board]];
        XCTAssertEqual([self valueOfUnits:source] + unchangedValue, [entry[8] integerValue]);
        XCTAssertEqual([self valueOfUnits:destination] + unchangedValue, [entry[8] integerValue]);
        NSArray *all = [self allExchangeUnits:board];
        XCTAssertEqual([NSSet setWithArray:all].count, all.count);
        UIView *illustration = [board valueForKey:@"illustrationView"];
        NSUInteger actualUnits = 0;
        for (UIView *view in illustration.subviews) if ([view isKindOfClass:NSClassFromString(@"VABUnitView")]) actualUnits++;
        XCTAssertEqual(actualUnits, all.count, @"No unmatched material may exist outside the four typed groups.");
        XCTAssertTrue([[self label:@"verticalExchangeScope" inView:board].text containsString:@"不是整題全部"]);
        XCTAssertTrue([[self label:@"verticalRetainedSource" inView:board].text containsString:@"不換"]);
        XCTAssertTrue([[self label:@"verticalRetainedDestination" inView:board].text containsString:@"不換"]);
        for (NSInteger column = 0; column < sequence.columnCount; column++) {
            id digit = step.visibleAnswerDigits[column];
            NSString *identifier = [NSString stringWithFormat:@"verticalAnswer%ld", (long)column];
            NSString *expected = [digit isKindOfClass:NSNumber.class] ? [digit stringValue] : @"";
            XCTAssertEqualObjects([self label:identifier inView:board].text, expected);
        }
    }
}

- (void)testZeroRetainedGroupsUseExplicitZeroLabelsAndNeverInventCounters {
    for (ArithmeticTeachingSequence *sequence in @[[self sequence:5 second:5 operation:@"+"], [self sequence:10 second:1 operation:@"-"]]) {
        VerticalArithmeticBoardView *board = self.board;
        [board configureWithSequence:sequence stepIndex:[self regroupIndices:sequence].firstObject.integerValue animated:NO];
        [self fitBoard:board width:288];
        XCTAssertEqual([self retainedUnits:board].count, 0u);
        XCTAssertTrue([[self label:@"verticalRetainedSource" inView:board].text containsString:@"0 個"]);
        XCTAssertTrue([[self label:@"verticalRetainedDestination" inView:board].text containsString:@"0 個"]);
        XCTAssertEqual([self allExchangeUnits:board].count, 11u);
        XCTAssertEqualObjects([self label:@"verticalExchangeEquals" inView:board].text, @"=");
    }
}

- (void)testUnchangedObjectsKeepIdentityPositionAndFullOpacityThroughReplayCompletionAndCancellation {
    for (NSArray *entry in [self knownExchangeCases]) {
        ArithmeticTeachingSequence *sequence = [self sequence:[entry[0] integerValue] second:[entry[1] integerValue] operation:entry[2]];
        NSInteger index = [self regroupIndices:sequence][[entry[3] unsignedIntegerValue]].integerValue;
        VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:CGRectMake(0, 0, 343, 1000)];
        board.allowMotion = YES;
        [board configureWithSequence:sequence stepIndex:index animated:NO];
        [self fitBoard:board width:343];
        NSArray<UIView *> *retained = [self retainedUnits:board];
        NSArray<NSValue *> *frames = [self framesOfUnits:retained];
        NSString *summary = board.accessibilityValue;
        for (NSInteger replay = 0; replay < 3; replay++) {
            [board showStepAtIndex:index animated:NO];
            XCTAssertFalse(board.isPlaying);
            [self assertRetainedUnits:retained frames:frames inBoard:board];
            XCTAssertTrue([board playCurrentActionInVisibleRect:board.currentConcreteTransformationRect]);
            XCTAssertTrue(board.isPlaying);
            [self assertRetainedUnits:retained frames:frames inBoard:board];
            if (replay == 0) {
                // Deterministic terminal transition. The separate real-display-link
                // test covers natural timing; this one preserves the object sample.
                [board setValue:@0 forKey:@"animationEndTime"];
                [board animationTick:nil];
                XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateCompleted);
            } else if (replay == 1) {
                [board cancelAnimations];
                XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateInterrupted);
            } else {
                [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
                XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateInterrupted);
            }
            [self assertRetainedUnits:retained frames:frames inBoard:board];
            [self assertCancelled:board index:index];
            XCTAssertEqualObjects(board.accessibilityValue, summary);
            XCTAssertEqualObjects([self label:@"verticalExchangeEquals" inView:board].text, @"=");
            XCTAssertEqualObjects([self label:@"verticalExchangeMode" inView:board].text, @"換前、換後比一比");
        }
        XCTAssertTrue([board playCurrentActionInVisibleRect:board.currentConcreteTransformationRect]);
        board.hidden = YES;
        board.hidden = NO;
        XCTAssertFalse(board.isPlaying);
        [self assertRetainedUnits:retained frames:frames inBoard:board];
        XCTAssertTrue([board playCurrentActionInVisibleRect:board.currentConcreteTransformationRect]);
        board.alpha = 0;
        board.alpha = 1;
        XCTAssertFalse(board.isPlaying);
        [self assertRetainedUnits:retained frames:frames inBoard:board];
        XCTAssertTrue([board playCurrentActionInVisibleRect:board.currentConcreteTransformationRect]);
        board.allowMotion = NO;
        [board animationTick:nil];
        [self assertRetainedUnits:retained frames:frames inBoard:board];
        [self assertCancelled:board index:index];
    }
}

- (void)testRunningUsesOneDiscreteOwnershipHandoffWithoutGatherShrinkOrCrossFade {
    for (NSArray *entry in [self knownExchangeCases]) {
        ArithmeticTeachingSequence *sequence = [self sequence:[entry[0] integerValue] second:[entry[1] integerValue] operation:entry[2]];
        NSInteger index = [self regroupIndices:sequence][[entry[3] unsignedIntegerValue]].integerValue;
        VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:CGRectMake(0, 0, 680, 1000)];
        board.allowMotion = YES;
        [board configureWithSequence:sequence stepIndex:index animated:NO];
        [self fitBoard:board width:680];
        XCTAssertTrue([board playCurrentActionInVisibleRect:board.currentConcreteTransformationRect]);
        NSArray *keys = @[@"exchangeSourceUnits", @"exchangeDestinationUnits"];
        NSArray *animationKeys = @[@"verticalConcreteGather", @"verticalConcreteExchange"];
        NSArray *expectedValues = @[@[@1, @0, @0], @[@0, @1, @1]];
        NSArray *expectedTimes = @[@0, @0.5, @1];
        CFTimeInterval sharedStart = [[board valueForKey:@"exchangeAnimationStartTime"] doubleValue];
        for (NSUInteger side = 0; side < keys.count; side++) {
            for (UIView *unit in [board valueForKey:keys[side]]) {
                XCTAssertEqual(unit.layer.animationKeys.count, 1u);
                CAKeyframeAnimation *ownership = (CAKeyframeAnimation *)[unit.layer animationForKey:animationKeys[side]];
                XCTAssertNotNil(ownership);
                XCTAssertEqualObjects(ownership.keyPath, @"opacity");
                XCTAssertEqualObjects(ownership.calculationMode, kCAAnimationDiscrete);
                XCTAssertEqualObjects(ownership.values, expectedValues[side]);
                XCTAssertEqualObjects(ownership.keyTimes, expectedTimes);
                XCTAssertFalse(ownership.removedOnCompletion);
                XCTAssertEqualObjects(ownership.fillMode, kCAFillModeForwards);
                XCTAssertEqualWithAccuracy([unit.layer convertTime:ownership.beginTime toLayer:nil], sharedStart, 0.00001);
                XCTAssertEqualWithAccuracy(ownership.duration, 0.88, 0.00001);
                XCTAssertTrue(CGAffineTransformIsIdentity(unit.transform));
            }
        }
        for (NSString *key in @[@"exchangeSourceOutline", @"exchangeDestinationOutline"]) {
            CAShapeLayer *outline = [board valueForKey:key];
            CAAnimationGroup *group = (CAAnimationGroup *)[outline animationForKey:@"verticalConcreteClosure"];
            XCTAssertNotNil(group);
            XCTAssertEqualObjects(((CABasicAnimation *)group.animations.firstObject).keyPath, @"strokeEnd");
        }
        [board cancelAnimations];
        XCTAssertTrue([board playCurrentActionInVisibleRect:board.currentTransformationRect]);
        for (UIView *transient in [board valueForKey:@"transientViews"]) {
            if (![transient.accessibilityIdentifier isEqualToString:@"verticalBeforeExchange"]) continue;
            CAKeyframeAnimation *before = (CAKeyframeAnimation *)[transient.layer animationForKey:@"verticalBeforeCount"];
            XCTAssertEqualObjects(before.calculationMode, kCAAnimationDiscrete);
            XCTAssertEqualObjects(before.values, expectedValues[0]);
            XCTAssertEqualObjects(before.keyTimes, expectedTimes);
        }
        for (UILabel *label in [board valueForKey:@"annotationLabels"]) {
            CAKeyframeAnimation *after = (CAKeyframeAnimation *)[label.layer animationForKey:@"verticalAfterCount"];
            if (!after) continue;
            XCTAssertEqualObjects(after.calculationMode, kCAAnimationDiscrete);
            XCTAssertEqualObjects(after.values, expectedValues[1]);
            XCTAssertEqualObjects(after.keyTimes, expectedTimes);
        }
        UILabel *packet = [self label:@"verticalMovingExchange" inView:board];
        CAAnimationGroup *packetGroup = (CAAnimationGroup *)[packet.layer animationForKey:@"verticalUnitTransfer"];
        XCTAssertNotNil(packetGroup);
        CAKeyframeAnimation *packetOpacity = (CAKeyframeAnimation *)packetGroup.animations.lastObject;
        XCTAssertEqualObjects(packetOpacity.calculationMode, kCAAnimationDiscrete);
        XCTAssertEqualObjects(packetOpacity.keyTimes, expectedTimes);
        XCTAssertEqualWithAccuracy(packetGroup.animations.firstObject.duration, 0.44, 0.00001);
        [board cancelAnimations];
        for (UIView *unit in [self allExchangeUnits:board]) {
            XCTAssertEqual(unit.layer.animationKeys.count, 0u);
            XCTAssertEqualWithAccuracy(unit.layer.opacity, 1, 0.0001);
        }
        XCTAssertEqual(((CAShapeLayer *)[board valueForKey:@"exchangeSourceOutline"]).animationKeys.count, 0u);
        XCTAssertEqual(((CAShapeLayer *)[board valueForKey:@"exchangeDestinationOutline"]).animationKeys.count, 0u);
    }
}

- (void)assertMeasuredExchangeGeometry:(VerticalArithmeticBoardView *)board {
    UIView *illustration = [board valueForKey:@"illustrationView"];
    CGRect action = board.currentActionRect;
    XCTAssertTrue(CGRectEqualToRect(action, board.currentConcreteTransformationRect));
    XCTAssertTrue(CGRectContainsRect(board.bounds, action));
    NSArray<UIView *> *units = [self allExchangeUnits:board];
    for (UIView *view in illustration.subviews) {
        XCTAssertTrue(CGRectContainsRect(illustration.bounds, view.frame), @"%@ must fit the real illustration.", view.accessibilityIdentifier);
        XCTAssertTrue(CGRectContainsRect(action, [view convertRect:view.bounds toView:board]));
        if ([view isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)view;
            XCTAssertFalse(label.adjustsFontSizeToFitWidth);
            CGFloat measured = [label sizeThatFits:CGSizeMake(CGRectGetWidth(label.bounds), CGFLOAT_MAX)].height;
            XCTAssertLessThanOrEqual(measured, CGRectGetHeight(label.bounds) + 1, @"%@ must fit its wrapped text.", label.accessibilityIdentifier);
        }
    }
    for (NSUInteger index = 0; index < units.count; index++) {
        UIView *unit = units[index];
        BOOL rod = [[unit valueForKey:@"place"] integerValue] == 1;
        XCTAssertEqualWithAccuracy(unit.bounds.size.width, rod ? 13 : 22, 0.001);
        XCTAssertEqualWithAccuracy(unit.bounds.size.height, rod ? 40 : 22, 0.001);
        for (NSUInteger other = index + 1; other < units.count; other++) {
            XCTAssertFalse(CGRectIntersectsRect(unit.frame, units[other].frame), @"Concrete units must not overlap, even in the labelled comparison.");
        }
        for (UIView *view in illustration.subviews) {
            if ([view isKindOfClass:UILabel.class]) XCTAssertFalse(CGRectIntersectsRect(unit.frame, view.frame));
        }
    }
    for (NSString *key in @[@"exchangeSourceOutline", @"exchangeDestinationOutline"]) {
        CAShapeLayer *outline = [board valueForKey:key];
        CGRect ink = CGRectInset(CGPathGetBoundingBox(outline.path), -outline.lineWidth / 2, -outline.lineWidth / 2);
        XCTAssertTrue(CGRectContainsRect(illustration.bounds, ink));
        for (UIView *view in illustration.subviews) {
            if ([view isKindOfClass:UILabel.class]) XCTAssertFalse(CGRectIntersectsRect(ink, view.frame), @"Outline ink must not invade %@.", view.accessibilityIdentifier);
        }
    }
    UILabel *mode = [self label:@"verticalExchangeMode" inView:board];
    NSString *rest = mode.text;
    mode.text = @"圈起這一組，再換一換";
    XCTAssertLessThanOrEqual([mode sizeThatFits:CGSizeMake(mode.bounds.size.width, CGFLOAT_MAX)].height, mode.bounds.size.height + 1);
    mode.text = rest;
}

- (void)testAllAddedUnitsAndWrappedLabelsFitCompactWideAndMaximumTextGeometry {
    for (NSArray *entry in [self knownExchangeCases]) {
        ArithmeticTeachingSequence *sequence = [self sequence:[entry[0] integerValue] second:[entry[1] integerValue] operation:entry[2]];
        NSInteger index = [self regroupIndices:sequence][[entry[3] unsignedIntegerValue]].integerValue;
        UIView *host = [self traitHostView];
        VABAnimationTestBoard *board = [self traitBoardWithFrame:CGRectMake(0, 0, 288, 1000) inView:host];
        for (NSString *category in @[UIContentSizeCategoryLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
            board.traitOverrides.preferredContentSizeCategory = category;
            [board setNeedsLayout];
            [board layoutIfNeeded];
            XCTAssertEqualObjects(board.traitCollection.preferredContentSizeCategory, category);
            [board configureWithSequence:sequence stepIndex:index animated:NO];
            [self assertTraitsForBoard:board category:category];
            CGFloat retainedFontSize = [self label:@"verticalRetainedSource" inView:board].font.pointSize;
            CGFloat countsFontSize = [self label:@"verticalExchangeCounts" inView:board].font.pointSize;
            for (NSNumber *width in @[@288, @343, @680]) {
                [self fitBoard:board width:width.doubleValue];
                [self assertMeasuredExchangeGeometry:board];
                XCTAssertFalse(board.isPlaying, @"A trait/width change must not start playback.");
                XCTAssertEqualWithAccuracy([self label:@"verticalRetainedSource" inView:board].font.pointSize, retainedFontSize, 0.001);
                XCTAssertEqualWithAccuracy([self label:@"verticalExchangeCounts" inView:board].font.pointSize, countsFontSize, 0.001);
                if ([category isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
                    XCTAssertGreaterThan([self label:@"verticalRetainedSource" inView:board].font.pointSize, 17);
                    XCTAssertGreaterThan([self label:@"verticalExchangeCounts" inView:board].font.pointSize, 18);
                }
                if (width.doubleValue == 680) {
                    // Keep the short-landscape viewport fixed. Its admission
                    // region reserves 8 pt on each edge, including the vertical
                    // margins used by the controller. Exercise normal and AX5.
                    UIView *viewport = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 680, 208)];
                    viewport.clipsToBounds = YES;
                    [host addSubview:viewport];
                    CGRect unobscured = UIEdgeInsetsInsetRect(viewport.bounds, UIEdgeInsetsMake(8, 8, 8, 8));
                    XCTAssertEqualWithAccuracy(CGRectGetWidth(unobscured), 664, 0.001);
                    XCTAssertEqualWithAccuracy(CGRectGetHeight(unobscured), 192, 0.001);
                    CGRect action = board.currentActionRect;
                    NSString *geometry = [NSString stringWithFormat:@"%@ %@ %@ exchange %@ at %@: action %@, unobscured %@",
                        entry[0], entry[2], entry[1], entry[3], category, NSStringFromCGRect(action), NSStringFromCGRect(unobscured)];
                    XCTAssertLessThanOrEqual(CGRectGetWidth(action), CGRectGetWidth(unobscured), @"%@", geometry);
                    XCTAssertLessThanOrEqual(CGRectGetHeight(action), CGRectGetHeight(unobscured), @"%@", geometry);
                    [viewport addSubview:board];
                    board.frame = CGRectOffset(board.frame, 0, CGRectGetMinY(unobscured) - action.origin.y);
                    XCTAssertTrue(CGRectContainsRect(unobscured, [board convertRect:action toView:viewport]), @"%@", geometry);
                    UIView *illustration = [board valueForKey:@"illustrationView"];
                    for (UIView *view in illustration.subviews) {
                        XCTAssertTrue(CGRectContainsRect(unobscured, [view convertRect:view.bounds toView:viewport]), @"%@ must fit the fixed 664 × 192 pt admission region. %@", view.accessibilityIdentifier, geometry);
                    }
                    board.allowMotion = YES;
                    XCTAssertTrue([board playCurrentActionInVisibleRect:[viewport convertRect:unobscured toView:board]], @"%@", geometry);
                    XCTAssertTrue(board.isPlaying);
                    XCTAssertFalse([[board valueForKey:@"playsWrittenExchange"] boolValue]);
                    XCTAssertTrue(CGRectEqualToRect(board.currentPlaybackRect, action));
                    [self assertMeasuredExchangeGeometry:board];
                    [board cancelAnimations];
                    [board removeFromSuperview];
                    [host addSubview:board];
                    [viewport removeFromSuperview];
                }
            }
        }
        [board.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
        [board removeFromSuperview];
    }
}

- (void)testActualVisibilityIncludesRetainedMaterialAndCaptionsAndRejectsCounterOnlyAdmission {
    ArithmeticTeachingSequence *sequence = [self sequence:108 second:19 operation:@"-"];
    NSInteger index = [self regroupIndices:sequence].lastObject.integerValue;
    VABAnimationTestBoard *board = [[VABAnimationTestBoard alloc] initWithFrame:CGRectMake(0, 0, 288, 1000)];
    board.allowMotion = YES;
    [board configureWithSequence:sequence stepIndex:index animated:NO];
    [self fitBoard:board width:288];
    CGRect action = board.currentActionRect;
    CGRect countersOnly = CGRectNull;
    for (UIView *unit in [self allExchangeUnits:board]) countersOnly = CGRectUnion(countersOnly, [unit convertRect:unit.bounds toView:board]);
    XCTAssertFalse([board playCurrentActionInVisibleRect:countersOnly]);
    XCTAssertFalse(board.isPlaying);
    // The animated configuration convenience path cannot evade the same gate.
    board.frame = CGRectMake(0, 0, 288, CGRectGetMaxY(action) - 1);
    [board configureWithSequence:sequence stepIndex:index animated:YES];
    XCTAssertFalse(board.isPlaying);
    [self fitBoard:board width:288];
    NSArray<UIView *> *retained = [self retainedUnits:board];
    NSArray<NSValue *> *frames = [self framesOfUnits:retained];
    UIView *viewport = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 288, action.size.height)];
    viewport.clipsToBounds = YES;
    [viewport addSubview:board];
    board.frame = CGRectOffset(board.frame, 0, -action.origin.y);
    // Board bounds include the notation, but the actual ancestor clips it.
    // Direct configuration must fall back to the fully visible concrete action.
    XCTAssertTrue([board configureWithSequence:sequence stepIndex:index animated:YES]);
    XCTAssertTrue(board.isPlaying);
    XCTAssertFalse([[board valueForKey:@"playsWrittenExchange"] boolValue]);
    XCTAssertTrue(CGRectEqualToRect(board.currentPlaybackRect, action));
    XCTAssertNil([self label:@"verticalMovingExchange" inView:board]);
    XCTAssertNil([self label:@"verticalBeforeExchange" inView:board]);
    for (UILabel *label in [board valueForKey:@"annotationLabels"]) XCTAssertEqual(label.layer.animationKeys.count, 0u);
    [self assertRetainedUnits:retained frames:frames inBoard:board];
    [board cancelAnimations];
    XCTAssertTrue([board showStepAtIndex:index animated:YES]);
    XCTAssertTrue(board.isPlaying);
    XCTAssertTrue(CGRectEqualToRect(board.currentPlaybackRect, action));
    XCTAssertTrue([board playCurrentActionInVisibleRect:action]);
    XCTAssertTrue(board.isPlaying);
    UIView *illustration = [board valueForKey:@"illustrationView"];
    for (UIView *view in illustration.subviews) XCTAssertTrue(CGRectContainsRect(viewport.bounds, [view convertRect:view.bounds toView:viewport]));
    [board cancelAnimations];
    viewport.frame = CGRectMake(0, 0, 288, action.size.height - 1);
    XCTAssertTrue([board configureWithSequence:sequence stepIndex:index animated:YES]);
    XCTAssertFalse(board.isPlaying);
    XCTAssertTrue([board showStepAtIndex:index animated:YES]);
    XCTAssertFalse(board.isPlaying);
    XCTAssertFalse([board playCurrentActionInVisibleRect:action]);
    [self assertRetainedUnits:retained frames:frames inBoard:board];
    XCTAssertEqualObjects([self label:@"verticalExchangeMode" inView:board].text, @"換前、換後比一比");
    XCTAssertEqualObjects([self label:@"verticalExchangeEquals" inView:board].text, @"=");
    for (UIView *unit in [self allExchangeUnits:board]) XCTAssertEqualWithAccuracy(unit.alpha, 1, 0.001);
    viewport.frame = CGRectMake(0, 0, 288, action.size.height);
    board.allowMotion = NO; // A rendering gate, not a claim about the system preference.
    XCTAssertTrue([board playCurrentActionInVisibleRect:action]);
    XCTAssertFalse(board.isPlaying);
    [self assertCancelled:board index:index];
    XCTAssertEqualObjects([self label:@"verticalExchangeEquals" inView:board].text, @"=");
}

- (void)flushPresentationFrame {
    [CATransaction flush];
    XCTestExpectation *frame = [self expectationWithDescription:@"Commit a native presentation frame"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [frame fulfill]; });
    [self waitForExpectations:@[frame] timeout:1];
}

- (CALayer *)assertPresentedView:(UIView *)view inWindow:(UIWindow *)window opacity:(CGFloat)expectedOpacity {
    XCTAssertNotNil(view);
    XCTAssertNotNil(window.windowScene);
    XCTAssertEqual(window.windowScene.activationState, UISceneActivationStateForegroundActive);
    XCTAssertTrue([UIApplication.sharedApplication.connectedScenes containsObject:window.windowScene]);
    XCTAssertTrue(window.isKeyWindow);
    XCTAssertFalse(window.hidden);
    XCTAssertEqual(window.rootViewController.view.window, window);
    CALayer *presented = view.layer.presentationLayer;
    XCTAssertNotNil(presented, @"A native presentation layer is required; a model-only fallback is not evidence.");
    XCTAssertEqualWithAccuracy(presented.opacity, expectedOpacity, 0.001);
    CGFloat effectiveOpacity = 1;
    BOOL reachedWindow = NO;
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        CALayer *visible = ancestor.layer.presentationLayer;
        XCTAssertNotNil(visible, @"Every ancestor must be committed to the native presentation tree.");
        XCTAssertFalse(visible.hidden);
        effectiveOpacity *= visible.opacity;
        if (ancestor == window) { reachedWindow = YES; break; }
    }
    XCTAssertTrue(reachedWindow);
    XCTAssertEqualWithAccuracy(effectiveOpacity, expectedOpacity, 0.001);
    if (expectedOpacity > 0 && presented && window.layer.presentationLayer) {
        CGRect visibleFrame = [presented convertRect:presented.bounds toLayer:window.layer.presentationLayer];
        XCTAssertTrue(CGRectContainsRect(window.bounds, visibleFrame), @"%@ must be actually visible, not merely in model bounds.", view.accessibilityIdentifier);
    }
    return presented;
}

- (void)testNativePresentationSamplesRetainOpaqueStationaryMaterialAndOneExchangedRepresentation {
    // These samples execute the real Core Animation layers in a window. A paused
    // layer clock avoids scheduler-dependent handoff sampling. They are not a
    // claim that a physical device or every encoded video frame was inspected.
    // Large media clocks need a representable on/after timestamp. A requested
    // .44 offset alone can subtract back to .439999999944 at start = 1,000,000.
    for (NSNumber *epoch in @[@1000000.0, @1000000000.0]) {
        for (NSNumber *boundary in @[@0.44, @0.88]) {
            CFTimeInterval sample = VABTimeAtOrAfterElapsed(epoch.doubleValue, boundary.doubleValue);
            XCTAssertGreaterThanOrEqual(sample - epoch.doubleValue, boundary.doubleValue);
            XCTAssertLessThan(nextafter(sample, -INFINITY) - epoch.doubleValue, boundary.doubleValue);
        }
    }
    XCTAssertTrue(UIView.areAnimationsEnabled);
    XCTAssertFalse(CATransaction.disableActions);
    if (!UIView.areAnimationsEnabled || CATransaction.disableActions) return;
    UIWindowScene *foregroundScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow && !candidate.hidden && candidate.alpha > 0) {
                foregroundScene = (UIWindowScene *)scene;
                self.previousKeyWindow = candidate;
                break;
            }
        }
        if (foregroundScene) break;
    }
    XCTAssertNotNil(foregroundScene, @"Native presentation requires a connected foreground scene with a usable key window.");
    XCTAssertNotNil(self.previousKeyWindow);
    if (!foregroundScene || !self.previousKeyWindow) return;
    CGRect sceneBounds = foregroundScene.coordinateSpace.bounds;
    BOOL finiteBounds = isfinite(sceneBounds.origin.x) && isfinite(sceneBounds.origin.y)
        && isfinite(sceneBounds.size.width) && isfinite(sceneBounds.size.height);
    XCTAssertTrue(finiteBounds);
    XCTAssertGreaterThan(sceneBounds.size.width, 0);
    XCTAssertGreaterThan(sceneBounds.size.height, 0);
    XCTAssertFalse(CGRectIsInfinite(sceneBounds));
    if (!finiteBounds || CGRectIsEmpty(sceneBounds) || CGRectIsInfinite(sceneBounds)) return;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:foregroundScene];
    self.presentationWindow = window;
    window.frame = sceneBounds;
    window.rootViewController = [UIViewController new];
    [window makeKeyAndVisible];
    [window layoutIfNeeded];
    [window.rootViewController loadViewIfNeeded];
    [window.rootViewController.view layoutIfNeeded];
    XCTAssertEqual(window.windowScene, foregroundScene);
    XCTAssertTrue([foregroundScene.windows containsObject:window]);
    XCTAssertEqual(foregroundScene.activationState, UISceneActivationStateForegroundActive);
    XCTAssertTrue(window.isKeyWindow);
    XCTAssertFalse(window.hidden);
    XCTAssertEqual(window.rootViewController.view.window, window);
    XCTAssertTrue(CGRectEqualToRect(window.frame, sceneBounds));
    XCTAssertEqualWithAccuracy(window.bounds.size.width, sceneBounds.size.width, 0.001);
    XCTAssertEqualWithAccuracy(window.bounds.size.height, sceneBounds.size.height, 0.001);
    // Include both carry chains and zero-retained carry/borrow, not only the
    // original five required exchanges. The neighbors are 1/120 s apart.
    NSArray<NSNumber *> *sampleTimes = @[@0, @0.22, @(0.44 - 1.0 / 120), @0.44,
        @(0.44 + 1.0 / 120), @0.66, @0.88, @(0.88 + 1.0 / 120)];
    for (NSArray *entry in [self knownExchangeCases]) {
        ArithmeticTeachingSequence *sequence = [self sequence:[entry[0] integerValue] second:[entry[1] integerValue] operation:entry[2]];
        NSInteger index = [self regroupIndices:sequence][[entry[3] unsignedIntegerValue]].integerValue;
        for (NSNumber *writtenNumber in @[@NO, @YES]) {
            BOOL written = writtenNumber.boolValue;
            CGFloat width = MIN(680, CGRectGetWidth(window.bounds));
            VABAnimationTestBoard *board = [self traitBoardWithFrame:CGRectMake(0, 0, width, 1000)
                inView:window.rootViewController.view];
            // Geometry has a separate AX5 gate. Do not enlarge this real window
            // or force hidden labels to paint just to obtain presentation layers.
            board.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge;
            [board setNeedsLayout];
            [board layoutIfNeeded];
            XCTAssertEqualObjects(board.traitCollection.preferredContentSizeCategory, UIContentSizeCategoryLarge);
            board.allowMotion = YES;
            [board configureWithSequence:sequence stepIndex:index animated:NO];
            [self fitBoard:board width:width];
            [self assertTraitsForBoard:board category:UIContentSizeCategoryLarge];
            CGRect action = board.currentActionRect;
            CGRect required = written ? board.currentTransformationRect : action;
            if (!written) board.frame = CGRectOffset(board.frame, 0, -action.origin.y);
            BOOL actuallyFits = CGRectContainsRect(window.bounds, [board convertRect:required toView:window]);
            XCTAssertTrue(actuallyFits, @"The native fixture must show its complete requested action; use a real portrait/tablet viewport for written playback.");
            if (!actuallyFits) { [board removeFromSuperview]; continue; } // The assertion above fails, never silently skips.
            NSArray<UIView *> *retained = [self retainedUnits:board];
            NSArray<NSValue *> *frames = [self framesOfUnits:retained];
            NSString *summary = board.accessibilityValue;
            for (NSInteger replay = 0; replay < 3; replay++) {
                [board showStepAtIndex:index animated:NO];
                XCTAssertTrue([board playCurrentActionInVisibleRect:required]);
                XCTAssertEqual([[board valueForKey:@"playsWrittenExchange"] boolValue], written);
                XCTAssertTrue(CGRectEqualToRect(board.currentPlaybackRect, required));
                CADisplayLink *displayLink = [board valueForKey:@"animationDisplayLink"];
                XCTAssertNotNil(displayLink);
                displayLink.paused = YES;
                CALayer *timeline = ((UIView *)[board valueForKey:@"contentView"]).layer;
                CFTimeInterval start = [timeline convertTime:[[board valueForKey:@"exchangeAnimationStartTime"] doubleValue] fromLayer:nil];
                timeline.speed = 0;
                NSMutableArray<UILabel *> *beforeCounts = [NSMutableArray array];
                for (UILabel *label in [board valueForKey:@"transientViews"]) {
                    if ([label.accessibilityIdentifier isEqualToString:@"verticalBeforeExchange"]) [beforeCounts addObject:label];
                }
                NSArray<UILabel *> *annotations = [board valueForKey:@"annotationLabels"];
                UILabel *sourceAfter = annotations[board.currentStep.sourceColumn];
                UILabel *destinationAfter = annotations[board.currentStep.destinationColumn];
                UILabel *packet = [self label:@"verticalMovingExchange" inView:board];
                BOOL carry = [entry[2] isEqualToString:@"+"];
                if (written) {
                    XCTAssertEqual(beforeCounts.count, 2u);
                    XCTAssertNotNil(packet);
                    XCTAssertTrue(CGRectEqualToRect(beforeCounts.firstObject.frame, sourceAfter.frame));
                    XCTAssertTrue(CGRectEqualToRect(beforeCounts.lastObject.frame, destinationAfter.frame));
                    XCTAssertEqualObjects(beforeCounts.firstObject.text, [entry[4] stringValue]);
                    XCTAssertEqualObjects(beforeCounts.lastObject.text, carry ? @"" : [entry[6] stringValue]);
                    XCTAssertEqualObjects(sourceAfter.text, [entry[5] stringValue]);
                    XCTAssertEqualObjects(destinationAfter.text, carry ? @"+1" : [entry[7] stringValue]);
                    NSInteger sourcePlace = sequence.columnCount - 1 - board.currentStep.sourceColumn;
                    NSArray *unitNames = @[@"一", @"十", @"百", @"千", @"萬"];
                    NSString *packetText = [NSString stringWithFormat:@"%ld%@", (long)([entry[4] integerValue] - [entry[5] integerValue]), unitNames[sourcePlace]];
                    XCTAssertEqualObjects(packet.text, packetText);
                    if (carry) {
                        XCTAssertEqual(board.currentStep.carryDigits[board.currentStep.sourceColumn].integerValue, 0);
                        XCTAssertEqual(board.currentStep.carryDigits[board.currentStep.destinationColumn].integerValue, 1);
                    }
                } else {
                    XCTAssertEqual(beforeCounts.count, 0u);
                    XCTAssertNil(packet);
                    for (UILabel *label in annotations) XCTAssertEqual(label.layer.animationKeys.count, 0u);
                }
                // First play includes both endpoints and the held endpoint before
                // display-link cleanup. Replay then cancels on each handoff side.
                NSUInteger sampleCount = replay == 0 ? sampleTimes.count : replay == 1 ? 3 : 5;
                for (NSNumber *time in [sampleTimes subarrayWithRange:NSMakeRange(0, sampleCount)]) {
                    CFTimeInterval requested = time.doubleValue;
                    BOOL boundary = requested == 0.44 || requested == 0.88;
                    timeline.timeOffset = boundary ? VABTimeAtOrAfterElapsed(start, requested) : start + requested;
                    CFTimeInterval actualElapsed = timeline.timeOffset - start;
                    if (boundary) {
                        // This is the first representable timestamp on/after the
                        // boundary, not a claim of mathematical exact equality.
                        XCTAssertGreaterThanOrEqual(actualElapsed, requested);
                        XCTAssertLessThan(nextafter(timeline.timeOffset, -INFINITY) - start, requested);
                    }
                    if (requested < 0.44) XCTAssertLessThan(actualElapsed, 0.44);
                    else XCTAssertGreaterThanOrEqual(actualElapsed, 0.44);
                    if (requested > 0.44) XCTAssertGreaterThan(actualElapsed, 0.44);
                    BOOL beforeHandoff = actualElapsed < 0.44;
                    [self flushPresentationFrame];
                    XCTAssertTrue(board.isPlaying);
                    [self assertRetainedUnits:retained frames:frames inBoard:board];
                    NSInteger ownedValue = 0;
                    for (UIView *unit in [self allExchangeUnits:board]) {
                        BOOL source = [[board valueForKey:@"exchangeSourceUnits"] containsObject:unit];
                        BOOL destination = [[board valueForKey:@"exchangeDestinationUnits"] containsObject:unit];
                        CGFloat expectedOpacity = source ? (beforeHandoff ? 1 : 0) : destination ? (beforeHandoff ? 0 : 1) : 1;
                        CALayer *presented = [self assertPresentedView:unit inWindow:window opacity:expectedOpacity];
                        XCTAssertEqualWithAccuracy(presented.position.x, unit.layer.position.x, 0.001);
                        XCTAssertEqualWithAccuracy(presented.position.y, unit.layer.position.y, 0.001);
                        XCTAssertTrue(CGRectEqualToRect(presented.bounds, unit.layer.bounds));
                        XCTAssertTrue(CATransform3DIsIdentity(presented.transform));
                        if (presented && window.layer.presentationLayer) {
                            CGRect actual = [presented convertRect:presented.bounds toLayer:window.layer.presentationLayer];
                            CGRect stationary = [unit convertRect:unit.bounds toView:window];
                            XCTAssertEqualWithAccuracy(actual.origin.x, stationary.origin.x, 0.001);
                            XCTAssertEqualWithAccuracy(actual.origin.y, stationary.origin.y, 0.001);
                            XCTAssertEqualWithAccuracy(actual.size.width, stationary.size.width, 0.001);
                            XCTAssertEqualWithAccuracy(actual.size.height, stationary.size.height, 0.001);
                        }
                        if (presented.opacity > 0.999) ownedValue += [self valueOfUnits:@[unit]];
                    }
                    XCTAssertEqual(ownedValue, [entry[8] integerValue]);
                    if (written) {
                        for (UILabel *before in beforeCounts) [self assertPresentedView:before inWindow:window opacity:beforeHandoff ? 1 : 0];
                        [self assertPresentedView:sourceAfter inWindow:window opacity:beforeHandoff ? 0 : 1];
                        [self assertPresentedView:destinationAfter inWindow:window opacity:beforeHandoff ? 0 : 1];
                        CALayer *moving = [self assertPresentedView:packet inWindow:window opacity:beforeHandoff ? 1 : 0];
                        if (time.doubleValue == 0) {
                            UIView *content = [board valueForKey:@"contentView"];
                            CGPoint from = [sourceAfter.superview convertPoint:sourceAfter.center toView:content];
                            XCTAssertEqualWithAccuracy(moving.position.x, from.x, 0.001);
                            XCTAssertEqualWithAccuracy(moving.position.y, from.y, 0.001);
                        }
                    }
                }
                if (replay == 0) {
                    // Resume the real deadline, without changing it or calling
                    // animationTick ourselves. The held endpoint must survive
                    // until its actual display-link cleanup restores comparison.
                    displayLink.paused = NO;
                    XCTestExpectation *completed = [[XCTNSPredicateExpectation alloc] initWithPredicate:
                        [NSPredicate predicateWithFormat:@"playbackState == %ld", (long)VerticalArithmeticPlaybackStateCompleted] object:board];
                    [self waitForExpectations:@[completed] timeout:2];
                    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateCompleted);
                } else {
                    [board cancelAnimations];
                    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateInterrupted);
                }
                timeline.speed = 1;
                timeline.timeOffset = 0;
                timeline.beginTime = 0;
                [self flushPresentationFrame];
                [self assertRetainedUnits:retained frames:frames inBoard:board];
                [self assertCancelled:board index:index];
                XCTAssertEqualObjects(board.accessibilityValue, summary);
                XCTAssertEqualObjects([self label:@"verticalExchangeMode" inView:board].text, @"換前、換後比一比");
                XCTAssertEqualObjects([self label:@"verticalExchangeEquals" inView:board].text, @"=");
                for (UIView *unit in [self allExchangeUnits:board]) {
                    [self assertPresentedView:unit inWindow:window opacity:1];
                }
                if (written) {
                    [self assertPresentedView:sourceAfter inWindow:window opacity:1];
                    [self assertPresentedView:destinationAfter inWindow:window opacity:1];
                    XCTAssertNil(packet.superview);
                    for (UILabel *before in beforeCounts) XCTAssertNil(before.superview);
                }
            }
            [board removeFromSuperview];
        }
    }
    [self releasePresentationWindow];
}

@end

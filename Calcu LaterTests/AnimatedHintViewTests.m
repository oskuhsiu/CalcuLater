#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "AnimatedHintView.h"
#import "ArithmeticProblem.h"
#import "ChildUIKit.h"

// Test cancellation deterministically, including a retained reference to an old callback.
@interface AnimatedHintView (SchedulerTests)
- (void)scheduleRevealSoundAfter:(NSTimeInterval)delay;
- (void)playRevealSound;
- (BOOL)isVisibleForReveal;
@end

@interface HintSoundRecorder : AnimatedHintView
@property (nonatomic, assign) NSUInteger revealSoundCount;
@property (nonatomic, assign) BOOL visibleForTest;
@end
@implementation HintSoundRecorder
- (BOOL)isVisibleForReveal { return self.visibleForTest; }
- (void)playRevealSound { self.revealSoundCount++; }
@end

@interface AnimatedHintViewTests : XCTestCase
@end

@implementation AnimatedHintViewTests

- (ArithmeticProblem *)addition {
    return [[ArithmeticProblem alloc] initWithNumber1:28 number2:47 operator:@"+" answer:75];
}

- (HintSoundRecorder *)hint {
    HintSoundRecorder *hint = [[HintSoundRecorder alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
    hint.visibleForTest = YES;
    return hint;
}

- (dispatch_block_t)queuedSound:(HintSoundRecorder *)hint {
    [hint scheduleRevealSoundAfter:30.0];
    NSArray<dispatch_block_t> *blocks = [hint valueForKey:@"pendingSoundBlocks"];
    return [blocks.lastObject copy];
}

- (void)testAdditionIsOneSpokenExplanationNotDisconnectedDigits {
    AnimatedHintView *hint = [[AnimatedHintView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
    [hint configureWithProblem:[self addition]];
    XCTAssertTrue(hint.isAccessibilityElement);
    XCTAssertEqualObjects(hint.accessibilityLabel, @"直式解題提示");
    XCTAssertTrue([hint.accessibilityValue containsString:@"28 加 47 等於 75"]);
    XCTAssertTrue([hint.accessibilityValue containsString:@"個位：8 加 7"]);
    XCTAssertTrue([hint.accessibilityValue containsString:@"向十位進 1"]);
    XCTAssertTrue([hint.accessibilityValue containsString:@"再加進位的 1"]);
    XCTAssertTrue(hint.subviews.firstObject.accessibilityElementsHidden);
    XCTAssertFalse([hint isVisibleForReveal]);
    XCTAssertEqual([[hint valueForKey:@"pendingSoundBlocks"] count], 0u);
}

- (void)testBorrowAcrossZeroHasMeaningfulSpokenColumnValues {
    AnimatedHintView *hint = [[AnimatedHintView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
    [hint configureWithProblem:[[ArithmeticProblem alloc] initWithNumber1:1000 number2:1 operator:@"-" answer:999]];
    XCTAssertTrue([hint.accessibilityValue containsString:@"1000 減 1 等於 999"]);
    XCTAssertTrue([hint.accessibilityValue containsString:@"先向左邊借位"]);
    XCTAssertTrue([hint.accessibilityValue containsString:@"10 減 1 是 9"]);
    XCTAssertTrue([hint.accessibilityValue containsString:@"十位：9 減 0 是 9"]);
    XCTAssertTrue([hint.accessibilityValue containsString:@"百位：9 減 0 是 9"]);
}

- (void)testCurrentVisibleRevealCanPlaySound {
    HintSoundRecorder *hint = [self hint];
    dispatch_block_t current = [self queuedSound:hint];
    current();
    XCTAssertEqual(hint.revealSoundCount, ChildUI.motionEnabled ? 1u : 0u);
    [hint cancelAnimations];
}

- (void)testCancelInvalidatesRetainedSoundBlock {
    HintSoundRecorder *hint = [self hint];
    dispatch_block_t stale = [self queuedSound:hint];
    [hint cancelAnimations];
    stale();
    XCTAssertEqual(hint.revealSoundCount, 0u);
    XCTAssertEqual([[hint valueForKey:@"pendingSoundBlocks"] count], 0u);
}

- (void)testHideInvalidatesPendingSoundsAndDoesNotReplayOnShow {
    HintSoundRecorder *hint = [self hint];
    dispatch_block_t stale = [self queuedSound:hint];
    hint.hidden = YES;
    hint.hidden = NO;
    stale();
    XCTAssertEqual(hint.revealSoundCount, 0u);
    XCTAssertEqual([[hint valueForKey:@"pendingSoundBlocks"] count], 0u);
}

- (void)testReconfigureInvalidatesPreviousQuestionsSounds {
    HintSoundRecorder *hint = [self hint];
    dispatch_block_t stale = [self queuedSound:hint];
    [hint configureWithProblem:[self addition]];
    stale();
    XCTAssertEqual(hint.revealSoundCount, 0u);
    XCTAssertTrue([hint.accessibilityValue containsString:@"28 加 47"]);
    [hint cancelAnimations];
}

- (void)testVisibilityIsCheckedAgainWhenSoundWouldPlay {
    HintSoundRecorder *hint = [self hint];
    dispatch_block_t pending = [self queuedSound:hint];
    hint.visibleForTest = NO;
    pending();
    XCTAssertEqual(hint.revealSoundCount, 0u);
    [hint cancelAnimations];
}

- (void)testBackgroundingInvalidatesPendingSound {
    HintSoundRecorder *hint = [self hint];
    dispatch_block_t stale = [self queuedSound:hint];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    stale();
    XCTAssertEqual(hint.revealSoundCount, 0u);
    XCTAssertEqual([[hint valueForKey:@"pendingSoundBlocks"] count], 0u);
}

- (void)testDetachingInvalidatesPendingSound {
    HintSoundRecorder *hint = [self hint];
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 400, 800)];
    [window addSubview:hint];
    dispatch_block_t stale = [self queuedSound:hint];
    [hint removeFromSuperview];
    stale();
    XCTAssertEqual(hint.revealSoundCount, 0u);
    XCTAssertEqual([[hint valueForKey:@"pendingSoundBlocks"] count], 0u);
}

- (void)testCancelLeavesEveryCellVisibleWithNoRevealAnimation {
    HintSoundRecorder *hint = [self hint];
    [hint configureWithProblem:[self addition]];
    NSArray<CALayer *> *animated = [[hint valueForKey:@"animatedLayers"] allObjects];
    if (ChildUI.motionEnabled) XCTAssertGreaterThan(animated.count, 0u);
    [hint cancelAnimations];
    for (CALayer *layer in animated) XCTAssertNil([layer animationForKey:@"hintReveal"]);
    UIView *grid = [hint.subviews.firstObject valueForKey:@"gridContainer"];
    for (UIView *cell in grid.subviews) {
        XCTAssertEqualWithAccuracy(cell.alpha, 1.0, 0.001);
        XCTAssertTrue(CGAffineTransformIsIdentity(cell.transform));
    }
}

- (void)testResizeCancelsSoundsForOldGridCells {
    HintSoundRecorder *hint = [self hint];
    [hint configureWithProblem:[self addition]];
    dispatch_block_t stale = [self queuedSound:hint];
    hint.bounds = CGRectMake(0, 0, 500, 400);
    [hint setNeedsLayout];
    [hint layoutIfNeeded];
    stale();
    XCTAssertEqual(hint.revealSoundCount, 0u);
    XCTAssertEqual([[hint valueForKey:@"pendingSoundBlocks"] count], 0u);
}

- (void)testUnsupportedProblemClearsOldSummaryAndPendingWork {
    HintSoundRecorder *hint = [self hint];
    [hint configureWithProblem:[self addition]];
    dispatch_block_t stale = [self queuedSound:hint];
    [hint configureWithProblem:[[ArithmeticProblem alloc] initWithNumber1:2 number2:3 operator:@"×" answer:6]];
    stale();
    XCTAssertEqual(hint.revealSoundCount, 0u);
    XCTAssertFalse(hint.isAccessibilityElement);
    XCTAssertNil(hint.accessibilityValue);
    XCTAssertEqual(hint.subviews.count, 0u);
}

- (void)testScheduledSoundDoesNotRetainDismissedHint {
    __weak HintSoundRecorder *weakHint = nil;
    @autoreleasepool {
        HintSoundRecorder *hint = [self hint];
        weakHint = hint;
        [self queuedSound:hint];
    }
    XCTAssertNil(weakHint);
}

@end

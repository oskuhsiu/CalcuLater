#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "LessonIntroView.h"
#import "Lesson.h"

@interface LessonIntroView (TeachingTests)
- (void)renderStepAnimated:(BOOL)animated;
@end

@interface CLIntroFinishObserver : NSObject <LessonIntroViewDelegate>
@property (nonatomic) NSInteger finishCount;
@end
@implementation CLIntroFinishObserver
- (void)lessonIntroDidFinish:(LessonIntroView *)introView { self.finishCount++; }
@end

@interface LessonIntroViewTests : XCTestCase
@property (nonatomic, strong) UIWindow *hostWindow;
@property (nonatomic, strong) LessonIntroView *intro;
@end

@implementation LessonIntroViewTests

- (void)tearDown {
    [self.intro stopPlayback];
    [self.intro removeFromSuperview];
    self.intro = nil;
    self.hostWindow.hidden = YES;
    self.hostWindow = nil;
    [super tearDown];
}

- (LessonIntroView *)showLessonAtIndex:(NSUInteger)index width:(CGFloat)width height:(CGFloat)height {
    [self.intro stopPlayback];
    [self.intro removeFromSuperview];
    self.hostWindow.hidden = YES;
    self.hostWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    UIViewController *host = [[UIViewController alloc] init];
    self.hostWindow.rootViewController = host;
    self.hostWindow.hidden = NO;
    // Do not let the simulator's current screen size substitute for the width
    // under test before the synthetic window has completed its first layout.
    host.view.frame = self.hostWindow.bounds;
    self.intro = [[LessonIntroView alloc] initWithLesson:[LessonCatalog addSubLessons][index]];
    self.intro.frame = host.view.bounds;
    self.intro.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host.view addSubview:self.intro];
    [host.view setNeedsLayout];
    [host.view layoutIfNeeded];
    [self.intro play];
    [self.intro layoutIfNeeded];
    return self.intro;
}

- (NSArray<UIView *> *)visibleDotsInIntro:(LessonIntroView *)intro {
    NSMutableArray *visible = [NSMutableArray array];
    for (UIView *dot in [intro valueForKey:@"dots"]) if (dot.alpha > 0.5) [visible addObject:dot];
    return visible;
}

- (void)assertVisibleDotsFitWithoutOverlapping:(LessonIntroView *)intro {
    UIView *stage = [intro valueForKey:@"stage"];
    NSArray<UIView *> *dots = [self visibleDotsInIntro:intro];
    for (NSUInteger index = 0; index < dots.count; index++) {
        XCTAssertTrue(CGRectContainsRect(CGRectInset(stage.bounds, -0.5, -0.5), dots[index].frame));
        XCTAssertGreaterThanOrEqual(dots[index].bounds.size.width, 28);
        for (NSUInteger other = index + 1; other < dots.count; other++) {
            XCTAssertFalse(CGRectIntersectsRect(dots[index].frame, dots[other].frame));
        }
    }
}

- (void)testFooterButtonsFitCompactAndWideLayouts {
    for (NSNumber *width in @[@288, @320, @343, @358, @736]) {
        LessonIntroView *intro = [self showLessonAtIndex:0 width:width.doubleValue height:420];
        UIButton *replay = [intro valueForKey:@"replayButton"];
        UIButton *start = [intro valueForKey:@"startButton"];
        CGRect replayRect = [replay.superview convertRect:replay.frame toView:intro];
        CGRect startRect = [start.superview convertRect:start.frame toView:intro];
        XCTAssertTrue(CGRectContainsRect(intro.bounds, replayRect));
        XCTAssertTrue(CGRectContainsRect(intro.bounds, startRect));
        XCTAssertFalse(CGRectIntersectsRect(replayRect, startRect));
        XCTAssertGreaterThanOrEqual(replayRect.size.height, 60);
        XCTAssertGreaterThanOrEqual(startRect.size.height, 60);
        XCTAssertEqualWithAccuracy(replayRect.size.width, startRect.size.width, 0.5);
        UIStackView *footer = [intro valueForKey:@"buttonStack"];
        if (width.doubleValue == 288) XCTAssertEqual(footer.axis, UILayoutConstraintAxisVertical);
        if (width.doubleValue == 736) XCTAssertEqual(footer.axis, UILayoutConstraintAxisHorizontal);
    }
}

- (void)testAllIntroStepsStayCountableOnSmallPhoneAndIPad {
    for (NSNumber *width in @[@288, @343, @736]) {
        for (NSUInteger lesson = 0; lesson < 5; lesson++) {
            LessonIntroView *intro = [self showLessonAtIndex:lesson width:width.doubleValue height:420];
            [intro stopPlayback];
            NSInteger lastStep = lesson == 3 ? 4 : 3;
            for (NSInteger step = 0; step <= lastStep; step++) {
                [intro setValue:@(step) forKey:@"step"];
                [intro renderStepAnimated:NO];
                [self assertVisibleDotsFitWithoutOverlapping:intro];
            }
        }
    }
}

- (void)testAdditionUsesNineActualDotsInsteadOfOverflowingSingleRow {
    LessonIntroView *intro = [self showLessonAtIndex:1 width:288 height:420];
    [intro stopPlayback];
    [intro setValue:@3 forKey:@"step"];
    [intro renderStepAnimated:NO];
    NSArray<UIView *> *dots = [self visibleDotsInIntro:intro];
    XCTAssertEqual(dots.count, 9u);
    XCTAssertNotEqualWithAccuracy(dots.firstObject.center.y, dots.lastObject.center.y, 1);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

- (void)testMakeTenTransfersExactlyTwoDotsIntoTenFrame {
    LessonIntroView *intro = [self showLessonAtIndex:3 width:288 height:420];
    [intro stopPlayback];
    [intro setValue:@1 forKey:@"step"];
    [intro renderStepAnimated:NO];
    NSArray<UIView *> *originalDots = [[intro valueForKey:@"dots"] copy];
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 13u);
    [intro setValue:@3 forKey:@"step"];
    [intro renderStepAnimated:NO];
    XCTAssertEqualObjects([intro valueForKey:@"dots"], originalDots);
    UIView *firstFrame = [intro valueForKey:@"firstFrame"];
    UIView *secondFrame = [intro valueForKey:@"secondFrame"];
    NSInteger firstCount = 0, secondCount = 0;
    for (UIView *dot in [self visibleDotsInIntro:intro]) {
        if (CGRectContainsPoint(firstFrame.frame, dot.center)) firstCount++;
        if (CGRectContainsPoint(secondFrame.frame, dot.center)) secondCount++;
    }
    XCTAssertEqual(firstCount, 10);
    XCTAssertEqual(secondCount, 3);
    XCTAssertTrue([[[intro valueForKey:@"narration"] text] containsString:@"8 + 2"]);
}

- (void)testBreakTenKeepsTheOriginalTwoAndLeavesSevenDots {
    LessonIntroView *intro = [self showLessonAtIndex:4 width:288 height:420];
    [intro stopPlayback];
    [intro setValue:@0 forKey:@"step"];
    [intro renderStepAnimated:NO];
    NSArray<UIView *> *dots = [intro valueForKey:@"dots"];
    CGPoint firstExtra = dots[10].center;
    CGPoint secondExtra = dots[11].center;
    [intro setValue:@3 forKey:@"step"];
    [intro renderStepAnimated:NO];
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 7u);
    XCTAssertTrue(CGPointEqualToPoint(dots[10].center, firstExtra));
    XCTAssertTrue(CGPointEqualToPoint(dots[11].center, secondExtra));
}

- (void)testShortScreensScrollInsteadOfShrinkingTheDiagram {
    LessonIntroView *intro = [self showLessonAtIndex:3 width:288 height:360];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIView *stage = [intro valueForKey:@"stage"];
    [scroll layoutIfNeeded];
    XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.size.height);
    XCTAssertEqualWithAccuracy(stage.bounds.size.height, 244, 0.5);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

- (void)testReplayReplacesTimerAndHiddenOrDetachedViewsCancelIt {
    LessonIntroView *intro = [self showLessonAtIndex:3 width:288 height:420];
    NSTimer *firstTimer = [intro valueForKey:@"stepTimer"];
    XCTAssertTrue(firstTimer.valid);
    [intro play];
    NSTimer *replacement = [intro valueForKey:@"stepTimer"];
    XCTAssertFalse(firstTimer.valid);
    XCTAssertNotEqual(firstTimer, replacement);
    XCTAssertTrue(replacement.valid);
    intro.hidden = YES;
    XCTAssertFalse(replacement.valid);
    XCTAssertNil([intro valueForKey:@"stepTimer"]);
    intro.hidden = NO;
    [intro play];
    NSTimer *detachedTimer = [intro valueForKey:@"stepTimer"];
    [intro removeFromSuperview];
    XCTAssertFalse(detachedTimer.valid);
    XCTAssertNil([intro valueForKey:@"stepTimer"]);
}

- (void)testExplicitStopAndBackgroundCancelPendingWork {
    LessonIntroView *intro = [self showLessonAtIndex:0 width:288 height:420];
    NSTimer *timer = [intro valueForKey:@"stepTimer"];
    [intro stopPlayback];
    XCTAssertFalse(timer.valid);
    XCTAssertNil([intro valueForKey:@"stepTimer"]);
    XCTAssertFalse([[intro valueForKey:@"playing"] boolValue]);
    [intro play];
    timer = [intro valueForKey:@"stepTimer"];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertFalse(timer.valid);
    XCTAssertNil([intro valueForKey:@"stepTimer"]);
}

- (void)testStartingTwiceOnlyFinishesOnce {
    LessonIntroView *intro = [self showLessonAtIndex:0 width:288 height:420];
    CLIntroFinishObserver *observer = [[CLIntroFinishObserver alloc] init];
    intro.delegate = observer;
    UIButton *start = [intro valueForKey:@"startButton"];
    [start sendActionsForControlEvents:UIControlEventTouchUpInside];
    [start sendActionsForControlEvents:UIControlEventTouchUpInside];
    [intro play];
    XCTAssertEqual(observer.finishCount, 1);
    XCTAssertNil([intro valueForKey:@"stepTimer"]);
}

- (void)testUnattachedPlayDoesNotScheduleLayoutPollingOrFinishTheLesson {
    LessonIntroView *intro = [[LessonIntroView alloc] initWithLesson:[LessonCatalog addSubLessons].firstObject];
    CLIntroFinishObserver *observer = [[CLIntroFinishObserver alloc] init];
    intro.delegate = observer;
    [intro play];
    XCTAssertNil([intro valueForKey:@"stepTimer"]);
    XCTAssertEqual(observer.finishCount, 0);
    [intro stopPlayback];
}

- (void)testTimerDoesNotKeepRemovedIntroAlive {
    __weak LessonIntroView *weakIntro;
    @autoreleasepool {
        LessonIntroView *intro = [self showLessonAtIndex:0 width:288 height:420];
        weakIntro = intro;
        [intro removeFromSuperview];
        self.intro = nil;
    }
    XCTAssertNil(weakIntro);
}

- (void)testGridAnnotationsStayReadableAndFullNarrationSupportsLargeText {
    LessonIntroView *intro = [self showLessonAtIndex:3 width:288 height:420];
    [intro stopPlayback];
    for (NSString *key in @[@"firstCountLabel", @"secondCountLabel"]) {
        UILabel *label = [intro valueForKey:key];
        XCTAssertFalse(label.adjustsFontForContentSizeCategory);
        XCTAssertGreaterThanOrEqual(label.font.pointSize, 18);
        XCTAssertGreaterThanOrEqual(label.bounds.size.height, label.font.lineHeight);
    }
    UILabel *narration = [intro valueForKey:@"narration"];
    XCTAssertTrue(narration.adjustsFontForContentSizeCategory);
    XCTAssertEqual(narration.numberOfLines, 0);
    narration.font = [narration.font fontWithSize:40];
    [intro setNeedsLayout];
    [intro layoutIfNeeded];
    XCTAssertGreaterThan(narration.bounds.size.height, 40);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

@end

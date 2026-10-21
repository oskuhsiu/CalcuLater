#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "LessonIntroView.h"
#import "Lesson.h"
#import "ArithmeticProblem.h"
#import "ExplanationViewController.h"

@interface LessonIntroView (TeachingTests)
- (void)renderStepAnimated:(BOOL)animated;
- (void)applyDotStateForStep:(NSInteger)step;
- (void)frameNewStepScene:(CGRect)scene frames:(CGRect)frames counters:(CGRect)counters;
@end

@interface CLIntroFinishObserver : NSObject <LessonIntroViewDelegate>
@property (nonatomic) NSInteger finishCount;
@end
@implementation CLIntroFinishObserver
- (void)lessonIntroDidFinish:(LessonIntroView *)introView { self.finishCount++; }
@end

/// Records the real renderer's snapshots, including the before-state used for
/// Replay. No substitute renderer and no globally disabled animations.
@interface CLRecordingIntroView : LessonIntroView
@property (nonatomic, strong) NSMutableArray<NSNumber *> *renderedSteps;
@property (nonatomic, strong) NSMutableArray<NSArray<NSDictionary *> *> *snapshots;
@property (nonatomic, strong) NSMutableArray<NSValue *> *viewportSnapshots;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *geometrySnapshots;
@property (nonatomic) NSUInteger framingCount;
@property (nonatomic) NSUInteger snapshotCountAtFraming;
@property (nonatomic) BOOL animatorExistedAtFraming;
@end
@implementation CLRecordingIntroView
- (void)applyDotStateForStep:(NSInteger)step {
    [super applyDotStateForStep:step];
    if (!self.renderedSteps) self.renderedSteps = [NSMutableArray array];
    if (!self.snapshots) self.snapshots = [NSMutableArray array];
    if (!self.viewportSnapshots) self.viewportSnapshots = [NSMutableArray array];
    [self.renderedSteps addObject:@(step)];
    NSMutableArray *snapshot = [NSMutableArray array];
    for (UIView *dot in [self valueForKey:@"dots"]) {
        [snapshot addObject:@{@"center": [NSValue valueWithCGPoint:dot.center],
            @"frame": [NSValue valueWithCGRect:dot.frame], @"alpha": @(dot.alpha),
            @"crossed": [dot valueForKey:@"crossedOut"]}];
    }
    [self.snapshots addObject:snapshot];
    UIScrollView *scroll = [self valueForKey:@"scrollView"];
    UIView *stage = [self valueForKey:@"stage"];
    [self.viewportSnapshots addObject:[NSValue valueWithCGRect:[scroll convertRect:scroll.bounds toView:stage]]];
    if (!self.geometrySnapshots) self.geometrySnapshots = [NSMutableArray array];
    [self.geometrySnapshots addObject:@{@"step": @(step), @"intro": [NSValue valueWithCGRect:self.bounds],
        @"stage": [NSValue valueWithCGRect:stage.bounds],
        @"firstFrame": [NSValue valueWithCGRect:[[self valueForKey:@"firstFrame"] frame]],
        @"secondFrame": [NSValue valueWithCGRect:[[self valueForKey:@"secondFrame"] frame]]}];
}
- (void)frameNewStepScene:(CGRect)scene frames:(CGRect)frames counters:(CGRect)counters {
    [super frameNewStepScene:scene frames:frames counters:counters];
    self.framingCount++;
    self.snapshotCountAtFraming = self.snapshots.count;
    self.animatorExistedAtFraming = [self valueForKey:@"stepAnimator"] != nil;
}
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

- (Lesson *)lessonAtIndex:(NSUInteger)index { return [LessonCatalog addSubLessons][index]; }
- (ArithmeticProblem *)problemA:(NSInteger)a b:(NSInteger)b make:(BOOL)make {
    return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:make ? @"+" : @"-" answer:make ? a + b : a - b];
}
- (LessonIntroView *)hostIntro:(LessonIntroView *)intro width:(CGFloat)width height:(CGFloat)height {
    [self.intro stopPlayback];
    [self.intro removeFromSuperview];
    self.hostWindow.hidden = YES;
    self.hostWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    UIViewController *host = [[UIViewController alloc] init];
    self.hostWindow.rootViewController = host;
    self.hostWindow.hidden = NO;
    // Complete synthetic-window layout before the simulator can substitute its
    // screen size for the compact/wide geometry being checked.
    host.view.frame = self.hostWindow.bounds;
    self.intro = intro;
    self.intro.frame = host.view.bounds;
    self.intro.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host.view addSubview:self.intro];
    [host.view setNeedsLayout];
    [host.view layoutIfNeeded];
    [self.intro play];
    [self.intro layoutIfNeeded];
    return self.intro;
}
- (LessonIntroView *)showLessonAtIndex:(NSUInteger)index width:(CGFloat)width height:(CGFloat)height {
    return [self hostIntro:[[LessonIntroView alloc] initWithLesson:[self lessonAtIndex:index]] width:width height:height];
}
- (LessonIntroView *)showProblemA:(NSInteger)a b:(NSInteger)b make:(BOOL)make width:(CGFloat)width {
    LessonIntroView *intro = [[LessonIntroView alloc] initWithProblem:[self problemA:a b:b make:make]
        lesson:[self lessonAtIndex:make ? 3 : 4]];
    XCTAssertNotNil(intro);
    return [self hostIntro:intro width:width height:500];
}
- (void)settleIntro:(LessonIntroView *)intro atStep:(NSInteger)step {
    [intro setValue:@(step) forKey:@"step"];
    [intro renderStepAnimated:NO];
}
- (NSArray<UIView *> *)visibleDotsInIntro:(LessonIntroView *)intro {
    NSMutableArray *visible = [NSMutableArray array];
    for (UIView *dot in [intro valueForKey:@"dots"]) if (dot.alpha > 0.5) [visible addObject:dot];
    return visible;
}
- (NSInteger)countInFrame:(NSString *)key intro:(LessonIntroView *)intro {
    UIView *frame = [intro valueForKey:key];
    NSInteger count = 0;
    for (UIView *dot in [self visibleDotsInIntro:intro]) if (CGRectContainsPoint(frame.frame, dot.center)) count++;
    return count;
}
- (NSInteger)crossedCount:(LessonIntroView *)intro {
    NSInteger count = 0;
    for (UIView *dot in [self visibleDotsInIntro:intro]) if ([[dot valueForKey:@"crossedOut"] boolValue]) count++;
    return count;
}
- (void)attachGeometryForIntro:(LessonIntroView *)intro name:(NSString *)name {
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIView *stage = [intro valueForKey:@"stage"];
    NSMutableString *trace = [NSMutableString stringWithFormat:
        @"intro=%@ stage=%@ stageFrame=%@ selectedStep=%ld animator=%@\nscroll=%@ contentSize=%@ offset=%@\n",
        NSStringFromCGRect(intro.bounds), NSStringFromCGRect(stage.bounds), NSStringFromCGRect(stage.frame),
        (long)intro.currentStepIndex, [intro valueForKey:@"stepAnimator"], NSStringFromCGRect(scroll.bounds),
        NSStringFromCGSize(scroll.contentSize), NSStringFromCGPoint(scroll.contentOffset)];
    for (NSString *key in @[@"firstFrame", @"secondFrame", @"firstCountLabel", @"secondCountLabel"]) {
        UIView *part = [intro valueForKey:key];
        [trace appendFormat:@"%@=%@ alpha=%.3f\n", key, NSStringFromCGRect(part.frame), (double)part.alpha];
    }
    for (UIView *dot in [intro valueForKey:@"dots"]) {
        [trace appendFormat:@"%@ identity=%p frame=%@ alpha=%.3f crossed=%@ selected=%@\n",
            dot.accessibilityIdentifier, (__bridge void *)dot, NSStringFromCGRect(dot.frame), (double)dot.alpha,
            [dot valueForKey:@"crossedOut"], [dot valueForKey:@"selectedForTen"]];
    }
    if ([intro isKindOfClass:CLRecordingIntroView.class]) {
        CLRecordingIntroView *recording = (CLRecordingIntroView *)intro;
        [trace appendFormat:@"framingCount=%lu\nrendered geometry=%@\n", (unsigned long)recording.framingCount,
            recording.geometrySnapshots];
    }
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:trace];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeDeleteOnSuccess;
    [self addAttachment:attachment];
}
- (void)assertVisibleDotsFitWithoutOverlapping:(LessonIntroView *)intro {
    UIView *stage = [intro valueForKey:@"stage"];
    UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
    NSArray<UIView *> *dots = [self visibleDotsInIntro:intro];
    BOOL attachedGeometry = NO;
    for (NSUInteger index = 0; index < dots.count; index++) {
        CGRect dot = dots[index].frame;
        if (!CGRectContainsRect(CGRectInset(stage.bounds, -0.5, -0.5), dot) && !attachedGeometry) {
            [self attachGeometryForIntro:intro name:@"Counter outside final stage bounds"];
            attachedGeometry = YES;
        }
        XCTAssertTrue(CGRectContainsRect(CGRectInset(stage.bounds, -0.5, -0.5), dot));
        XCTAssertTrue(CGRectContainsRect(first.frame, dot) || CGRectContainsRect(second.frame, dot));
        XCTAssertGreaterThanOrEqual(dot.size.width, 30);
        for (UILabel *label in @[[intro valueForKey:@"firstCountLabel"], [intro valueForKey:@"secondCountLabel"]]) {
            if (label.alpha > 0.5) XCTAssertFalse(CGRectIntersectsRect(dot, label.frame));
        }
        for (NSUInteger other = index + 1; other < dots.count; other++) {
            XCTAssertFalse(CGRectIntersectsRect(dot, dots[other].frame));
        }
    }
}
- (void)assertEquationHidden:(LessonIntroView *)intro a:(NSInteger)a b:(NSInteger)b make:(BOOL)make {
    NSString *expected = [NSString stringWithFormat:@"%ld %@ %ld = ?", (long)a, make ? @"+" : @"−", (long)b];
    XCTAssertEqualObjects([[intro valueForKey:@"problemLabel"] text], expected);
}

- (CGRect)counterBoundsInSnapshots:(NSArray<NSArray<NSDictionary *> *> *)snapshots {
    CGRect bounds = CGRectNull;
    for (NSArray<NSDictionary *> *snapshot in snapshots) {
        for (NSDictionary *dot in snapshot) {
            if ([dot[@"alpha"] doubleValue] > 0.01) bounds = CGRectUnion(bounds, [dot[@"frame"] CGRectValue]);
        }
    }
    return bounds;
}

- (void)assertLastTransitionIsFramedBeforeItsTargetIsApplied:(CLRecordingIntroView *)intro {
    XCTAssertGreaterThanOrEqual(intro.snapshots.count, 2u);
    if (intro.snapshots.count < 2) return;
    XCTAssertGreaterThan(intro.framingCount, 0u);
    XCTAssertFalse(intro.animatorExistedAtFraming);
    XCTAssertEqual(intro.snapshotCountAtFraming + 1, intro.snapshots.count);
    NSUInteger source = intro.snapshots.count - 2;
    XCTAssertEqual(intro.renderedSteps[source].integerValue, intro.currentStepIndex - 1);
    XCTAssertEqual(intro.renderedSteps.lastObject.integerValue, intro.currentStepIndex);
    CGRect movement = [self counterBoundsInSnapshots:@[intro.snapshots[source], intro.snapshots.lastObject]];
    // This viewport is recorded inside applyDotStateForStep:, not after the
    // animation or a test-driven scroll. Both endpoints must already fit.
    CGRect viewport = intro.viewportSnapshots.lastObject.CGRectValue;
    XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -0.5, -0.5), movement));
}

- (void)testAllFourFooterControlsFitCompactAndWideLayouts {
    for (NSNumber *width in @[@288, @320, @343, @358, @736]) {
        LessonIntroView *intro = [self showLessonAtIndex:0 width:width.doubleValue height:420];
        NSMutableArray<NSValue *> *frames = [NSMutableArray array];
        for (NSString *key in @[@"previousButton", @"nextButton", @"replayButton", @"startButton"]) {
            UIButton *button = [intro valueForKey:key];
            CGRect rect = [button.superview convertRect:button.frame toView:intro];
            XCTAssertTrue(CGRectContainsRect(intro.bounds, rect));
            XCTAssertGreaterThanOrEqual(rect.size.height, 60);
            XCTAssertGreaterThanOrEqual(rect.size.width, 60);
            for (NSValue *other in frames) XCTAssertFalse(CGRectIntersectsRect(rect, other.CGRectValue));
            [frames addObject:[NSValue valueWithCGRect:rect]];
        }
        UIStackView *footer = [intro valueForKey:@"buttonStack"];
        if (width.doubleValue == 288) XCTAssertEqual(footer.axis, UILayoutConstraintAxisVertical);
        if (width.doubleValue == 736) XCTAssertEqual(footer.axis, UILayoutConstraintAxisHorizontal);
    }
}

- (void)testAllCanonicalIntroStepsStayCountableOnSmallPhoneAndIPad {
    for (NSNumber *width in @[@288, @343, @736]) {
        for (NSUInteger lesson = 0; lesson < 5; lesson++) {
            LessonIntroView *intro = [self showLessonAtIndex:lesson width:width.doubleValue height:420];
            for (NSInteger step = 0; step < intro.numberOfSteps; step++) {
                [self settleIntro:intro atStep:step];
                [self assertVisibleDotsFitWithoutOverlapping:intro];
            }
        }
    }
}

- (void)testAdditionUsesNineActualDotsInsteadOfOverflowingSingleRow {
    LessonIntroView *intro = [self showLessonAtIndex:1 width:288 height:420];
    [self settleIntro:intro atStep:3];
    NSArray<UIView *> *dots = [self visibleDotsInIntro:intro];
    XCTAssertEqual(dots.count, 9u);
    XCTAssertNotEqualWithAccuracy(dots.firstObject.center.y, dots.lastObject.center.y, 1);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

- (void)testEveryValidMakeTenProblemConservesAllDotsAndUsesTwoTenFrames {
    for (NSNumber *width in @[@288, @736]) {
        for (NSInteger a = 2; a <= 9; a++) {
            for (NSInteger b = 11 - a; b <= 9; b++) {
                @autoreleasepool {
                    LessonIntroView *intro = [self showProblemA:a b:b make:YES width:width.doubleValue];
                    NSArray<UIView *> *identities = [[intro valueForKey:@"dots"] copy];
                    XCTAssertEqual(identities.count, (NSUInteger)(a + b));
                    XCTAssertEqualObjects([[intro valueForKey:@"firstFrame"] valueForKey:@"capacity"], @10);
                    XCTAssertEqualObjects([[intro valueForKey:@"secondFrame"] valueForKey:@"capacity"], @10);
                    NSInteger need = 10 - a, rest = b - need;
                    for (NSInteger step = 0; step < intro.numberOfSteps; step++) {
                        [self settleIntro:intro atStep:step];
                        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
                        XCTAssertEqual([self visibleDotsInIntro:intro].count, (NSUInteger)(step == 0 ? a : a + b));
                        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], step < 3 ? a : 10);
                        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], step == 0 ? 0 : step < 3 ? b : rest);
                        XCTAssertEqual([self crossedCount:intro], 0);
                        UIView *firstFrame = [intro valueForKey:@"firstFrame"];
                        for (NSInteger offset = 0; offset < b; offset++) {
                            UIView *dot = identities[a + offset];
                            if (step >= 3) XCTAssertEqual(CGRectContainsPoint(firstFrame.frame, dot.center), offset < need);
                            XCTAssertEqual([[dot valueForKey:@"selectedForTen"] boolValue], step >= 2 && offset < need);
                        }
                        if (step < intro.numberOfSteps - 1) [self assertEquationHidden:intro a:a b:b make:YES];
                        else {
                            NSString *sum = [NSString stringWithFormat:@"10 + %ld = %ld", (long)rest, (long)(a + b)];
                            XCTAssertTrue([intro.currentNarration containsString:sum]);
                        }
                        [self assertVisibleDotsFitWithoutOverlapping:intro];
                    }
                }
            }
        }
    }
}

- (void)testEveryValidBreakTenProblemRemovesOnlyCrossedDotsAndKeepsOriginalOnes {
    for (NSNumber *width in @[@288, @736]) {
        for (NSInteger a = 11; a <= 18; a++) {
            for (NSInteger b = a % 10 + 1; b <= 9; b++) {
                @autoreleasepool {
                    LessonIntroView *intro = [self showProblemA:a b:b make:NO width:width.doubleValue];
                    NSArray<UIView *> *identities = [[intro valueForKey:@"dots"] copy];
                    NSMutableArray<NSValue *> *onesPositions = [NSMutableArray array];
                    for (NSInteger i = 10; i < a; i++) [onesPositions addObject:[NSValue valueWithCGPoint:identities[i].center]];
                    XCTAssertEqualObjects([[intro valueForKey:@"secondFrame"] valueForKey:@"capacity"], @10);
                    for (NSInteger step = 0; step < intro.numberOfSteps; step++) {
                        [self settleIntro:intro atStep:step];
                        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
                        XCTAssertEqual([self visibleDotsInIntro:intro].count, (NSUInteger)(step < 2 ? a : a - b));
                        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], step < 2 ? 10 : 10 - b);
                        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], a % 10);
                        XCTAssertEqual([self crossedCount:intro], step == 1 ? b : 0);
                        for (NSInteger i = 0; i < a; i++) {
                            UIView *dot = identities[i];
                            if (i >= 10) {
                                XCTAssertEqualWithAccuracy(dot.alpha, 1, 0.001);
                                XCTAssertTrue(CGPointEqualToPoint(dot.center, onesPositions[i - 10].CGPointValue));
                                XCTAssertFalse([[dot valueForKey:@"crossedOut"] boolValue]);
                            } else {
                                BOOL removed = step >= 2 && i >= 10 - b;
                                XCTAssertEqualWithAccuracy(dot.alpha, removed ? 0 : 1, 0.001);
                            }
                        }
                        if (step < intro.numberOfSteps - 1) [self assertEquationHidden:intro a:a b:b make:NO];
                        else {
                            NSString *sum = [NSString stringWithFormat:@"%ld + %ld = %ld", (long)(10 - b), (long)(a % 10), (long)(a - b)];
                            XCTAssertTrue([intro.currentNarration containsString:sum]);
                        }
                        [self assertVisibleDotsFitWithoutOverlapping:intro];
                    }
                }
            }
        }
    }
}

- (void)testCanonicalStrategiesKeepTheFamiliarEightPlusFiveAndTwelveMinusFive {
    LessonIntroView *make = [self showLessonAtIndex:3 width:288 height:420];
    [self assertEquationHidden:make a:8 b:5 make:YES];
    [self settleIntro:make atStep:3];
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:make], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:make], 3);
    XCTAssertTrue([make.currentNarration containsString:@"8 + 2"]);
    LessonIntroView *subtract = [self showLessonAtIndex:4 width:288 height:420];
    [self assertEquationHidden:subtract a:12 b:5 make:NO];
    [self settleIntro:subtract atStep:3];
    XCTAssertEqual([self visibleDotsInIntro:subtract].count, 7u);
}

- (void)testExplicitProblemIsAValidatedValueSnapshot {
    ArithmeticProblem *problem = [self problemA:2 b:9 make:YES];
    LessonIntroView *intro = [[LessonIntroView alloc] initWithProblem:problem lesson:[self lessonAtIndex:3]];
    problem.number1 = 99; problem.number2 = 70; problem.answer = 0;
    problem.operatorSymbol = @"×"; problem.isMultiStep = YES;
    [self hostIntro:intro width:288 height:500];
    [self assertEquationHidden:intro a:2 b:9 make:YES];
    [self settleIntro:intro atStep:3];
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 11u);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
}

- (void)testInvalidExplicitInputsAreRejectedInsteadOfShowingCanonicalExamples {
    NSArray<NSArray *> *invalid = @[
        @[@2, @8, @"+", @10, @3], @[@1, @9, @"+", @10, @3], @[@10, @1, @"+", @11, @3],
        @[@9, @10, @"+", @19, @3], @[@8, @5, @"-", @3, @3], @[@8, @5, @"−", @3, @3],
        @[@8, @5, @"×", @40, @3], @[@8, @5, @"+", @12, @3], @[@8, @5, @"+", @13, @0],
        @[@10, @5, @"-", @5, @4], @[@19, @9, @"-", @10, @4], @[@18, @8, @"-", @10, @4],
        @[@11, @0, @"-", @11, @4], @[@11, @10, @"-", @1, @4], @[@12, @5, @"+", @17, @4],
        @[@12, @5, @"-", @8, @4], @[@12, @5, @"–", @7, @4], @[@(-1), @9, @"+", @8, @3],
        @[@(NSIntegerMax), @9, @"+", @0, @3], @[@(NSIntegerMin), @9, @"-", @0, @4]
    ];
    for (NSArray *row in invalid) {
        ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:[row[0] integerValue]
            number2:[row[1] integerValue] operator:row[2] answer:[row[3] integerValue]];
        Lesson *lesson = [self lessonAtIndex:[row[4] unsignedIntegerValue]];
        XCTAssertFalse([LessonIntroView supportsProblem:problem lesson:lesson]);
        LessonIntroView *intro = [[LessonIntroView alloc] initWithProblem:problem lesson:lesson];
        XCTAssertNil(intro);
    }
    ArithmeticProblem *multi = [self problemA:8 b:5 make:YES];
    multi.isMultiStep = YES;
    XCTAssertNil([[LessonIntroView alloc] initWithProblem:multi lesson:[self lessonAtIndex:3]]);
    ArithmeticProblem *unicodeMinus = [self problemA:11 b:9 make:NO];
    unicodeMinus.operatorSymbol = @"−";
    XCTAssertNotNil([[LessonIntroView alloc] initWithProblem:unicodeMinus lesson:[self lessonAtIndex:4]]);
}

- (void)testBackRestoresTransferredAndCrossedOutStatesWithoutRevealingTheAnswer {
    LessonIntroView *make = [self showProblemA:2 b:9 make:YES width:288];
    [self settleIntro:make atStep:4];
    [make goToPreviousStep];
    [self assertEquationHidden:make a:2 b:9 make:YES];
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:make], 10);
    [make goToPreviousStep];
    XCTAssertEqual(make.currentStepIndex, 2);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:make], 2);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:make], 9);
    LessonIntroView *subtract = [self showProblemA:18 b:9 make:NO width:288];
    [self settleIntro:subtract atStep:2];
    [subtract goToPreviousStep];
    XCTAssertEqual([self visibleDotsInIntro:subtract].count, 18u);
    XCTAssertEqual([self crossedCount:subtract], 9);
    [subtract goToPreviousStep];
    [subtract goToPreviousStep];
    XCTAssertEqual(subtract.currentStepIndex, 0);
    XCTAssertEqual([self crossedCount:subtract], 0);
    [self assertEquationHidden:subtract a:18 b:9 make:NO];
}

- (void)testReplayReconstructsTheSelectedStepsOwnBeforeStateAndPreservesDotIdentity {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    [self hostIntro:intro width:288 height:500];
    [self settleIntro:intro atStep:3];
    NSArray *identities = [[intro valueForKey:@"dots"] copy];
    [intro.renderedSteps removeAllObjects]; [intro.snapshots removeAllObjects]; [intro.viewportSnapshots removeAllObjects];
    [intro replayCurrentStep];
    XCTAssertEqualObjects(intro.renderedSteps, (@[@2, @3]));
    UIView *second = [intro valueForKey:@"secondFrame"];
    for (NSInteger i = 2; i < 11; i++) {
        CGPoint before = [intro.snapshots.firstObject[i][@"center"] CGPointValue];
        XCTAssertTrue(CGRectContainsPoint(second.frame, before));
    }
    XCTAssertEqual(intro.currentStepIndex, 3);
    XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
    [intro stopPlayback];
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
    [self settleIntro:intro atStep:0];
    [intro.renderedSteps removeAllObjects]; [intro.snapshots removeAllObjects]; [intro.viewportSnapshots removeAllObjects];
    [intro replayCurrentStep];
    XCTAssertEqualObjects(intro.renderedSteps, (@[@(-1), @0]));
    for (NSDictionary *dot in intro.snapshots.firstObject) XCTAssertEqualWithAccuracy([dot[@"alpha"] doubleValue], 0, 0.001);
    [intro stopPlayback];
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 2u);
}

- (void)testBreakTenReplayRestoresCrossedDotsBeforeRemovingThemAgain {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
        lesson:[self lessonAtIndex:4]];
    [self hostIntro:intro width:288 height:500];
    [self settleIntro:intro atStep:2];
    [intro.renderedSteps removeAllObjects]; [intro.snapshots removeAllObjects]; [intro.viewportSnapshots removeAllObjects];
    [intro replayCurrentStep];
    XCTAssertEqualObjects(intro.renderedSteps, (@[@1, @2]));
    NSArray<NSDictionary *> *before = intro.snapshots.firstObject;
    for (NSInteger i = 1; i < 10; i++) {
        XCTAssertTrue([before[i][@"crossed"] boolValue]);
        XCTAssertEqualWithAccuracy([before[i][@"alpha"] doubleValue], 1, 0.001);
    }
    [intro stopPlayback];
    XCTAssertEqual(intro.currentStepIndex, 2);
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 9u);
}

- (void)testFirstPresentationFramesInitialTenQuantitiesWithoutAdvancingOrRevealingFutureDots {
    for (NSValue *sizeValue in @[[NSValue valueWithCGSize:CGSizeMake(288, 500)],
        [NSValue valueWithCGSize:CGSizeMake(359, 539)], [NSValue valueWithCGSize:CGSizeMake(736, 260)]]) {
        CGSize size = sizeValue.CGSizeValue;
        for (NSNumber *make in @[@YES, @NO]) {
            for (NSNumber *current in @[@YES, @NO]) {
                NSInteger a = make.boolValue ? (current.boolValue ? 2 : 8) : (current.boolValue ? 18 : 12);
                NSInteger b = current.boolValue ? 9 : 5;
                Lesson *lesson = [self lessonAtIndex:make.boolValue ? 3 : 4];
                CLRecordingIntroView *intro = current.boolValue
                    ? [[CLRecordingIntroView alloc] initWithProblem:[self problemA:a b:b make:make.boolValue] lesson:lesson]
                    : [[CLRecordingIntroView alloc] initWithLesson:lesson];
                [self hostIntro:intro width:size.width height:size.height];
                UIScrollView *scroll = [intro valueForKey:@"scrollView"];
                UIView *stage = [intro valueForKey:@"stage"];
                CGRect viewport = [scroll convertRect:scroll.bounds toView:stage];
                for (NSString *key in @[@"firstFrame", @"secondFrame", @"firstCountLabel", @"secondCountLabel"]) {
                    UIView *part = [intro valueForKey:key];
                    if (part.alpha > 0.01) XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -0.5, -0.5), part.frame));
                }
                XCTAssertEqual(intro.framingCount, 1u);
                XCTAssertFalse(intro.animatorExistedAtFraming);
                XCTAssertNil([intro valueForKey:@"stepAnimator"]);
                XCTAssertEqual(intro.currentStepIndex, 0);
                XCTAssertEqual([self visibleDotsInIntro:intro].count, (NSUInteger)a);
                XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], make.boolValue ? a : 10);
                XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], make.boolValue ? 0 : a % 10);
                XCTAssertEqual([self crossedCount:intro], 0);
                [self assertEquationHidden:intro a:a b:b make:make.boolValue];
                for (NSString *key in @[@"firstFrame", @"secondFrame"]) {
                    UIView *frame = [intro valueForKey:key];
                    XCTAssertEqualWithAccuracy(frame.bounds.size.height, 100, 0.001);
                    XCTAssertEqualObjects([frame valueForKey:@"capacity"], @10);
                }
                [self assertVisibleDotsFitWithoutOverlapping:intro];
            }
        }
    }
}

- (void)testUnattachedAndHiddenPreparationDoNotConsumeInitialPresentationFraming {
    for (NSNumber *hidden in @[@NO, @YES]) {
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
            lesson:[self lessonAtIndex:4]];
        intro.frame = CGRectMake(0, 0, 359, 539);
        [intro play];
        XCTAssertEqual(intro.framingCount, 0u);
        intro.hidden = hidden.boolValue;
        [self hostIntro:intro width:359 height:539];
        XCTAssertEqual(intro.framingCount, hidden.boolValue ? 0u : 1u);
        intro.hidden = NO;
        [intro play];
        XCTAssertEqual(intro.framingCount, 1u);
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        UIView *stage = [intro valueForKey:@"stage"];
        UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
        CGRect viewport = [scroll convertRect:scroll.bounds toView:stage];
        XCTAssertTrue(CGRectContainsRect(viewport, CGRectUnion(first.frame, second.frame)));
    }
}

- (void)testRepeatedPresentationAndLifecycleChangesPreserveInitialSceneInspectionOffset {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
        lesson:[self lessonAtIndex:4]];
    [self hostIntro:intro width:359 height:539];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    NSArray *identities = [[intro valueForKey:@"dots"] copy];
    CGFloat chosenOffset = 32;
    [scroll setContentOffset:CGPointMake(0, chosenOffset) animated:NO];
    for (NSString *interruption in @[@"play", @"background", @"hidden", @"alpha", @"detach", @"resize", @"replay", @"back"]) {
        NSUInteger expectedFramingCount = intro.framingCount;
        if ([interruption isEqualToString:@"background"]) {
            [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
        } else if ([interruption isEqualToString:@"hidden"]) {
            intro.hidden = YES; intro.hidden = NO;
        } else if ([interruption isEqualToString:@"alpha"]) {
            intro.alpha = 0; intro.alpha = 1;
        } else if ([interruption isEqualToString:@"detach"]) {
            UIView *host = intro.superview;
            [intro removeFromSuperview]; [host addSubview:intro];
        } else if ([interruption isEqualToString:@"resize"]) {
            intro.frame = CGRectMake(0, 0, 736, 260);
        } else if ([interruption isEqualToString:@"replay"]) {
            [intro replayCurrentStep];
        } else if ([interruption isEqualToString:@"back"]) {
            [intro goToNextStep];
            expectedFramingCount++;
            [scroll setContentOffset:CGPointMake(0, chosenOffset) animated:NO];
            [intro goToPreviousStep];
        }
        [intro play];
        XCTAssertGreaterThan(scroll.contentSize.height - scroll.bounds.size.height, chosenOffset);
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
        XCTAssertEqual(intro.framingCount, expectedFramingCount);
        XCTAssertEqual(intro.currentStepIndex, 0);
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
        [self assertEquationHidden:intro a:18 b:9 make:NO];
    }
}

- (void)testTooShortInitialPresentationDoesNotRetryFramingAfterResize {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
        lesson:[self lessonAtIndex:4]];
    [self hostIntro:intro width:288 height:360];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    CGRect counters = [self counterBoundsInSnapshots:@[intro.snapshots.lastObject]];
    XCTAssertGreaterThan(counters.size.height, scroll.bounds.size.height);
    XCTAssertEqual(intro.framingCount, 1u);
    XCTAssertEqualWithAccuracy(scroll.contentOffset.y, 0, 0.001);
    intro.frame = CGRectMake(0, 0, 288, 500);
    [intro play];
    XCTAssertEqual(intro.framingCount, 1u);
    XCTAssertEqualWithAccuracy(scroll.contentOffset.y, 0, 0.001);
    XCTAssertEqual(intro.currentStepIndex, 0);
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 18u);
}

- (void)testSimpleLessonsKeepTheirOriginalPresentationViewport {
    for (NSUInteger index = 0; index < 3; index++) {
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithLesson:[self lessonAtIndex:index]];
        [self hostIntro:intro width:288 height:500];
        [intro play];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        XCTAssertEqual(intro.framingCount, 0u);
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, 0, 0.001);
        XCTAssertEqual(intro.currentStepIndex, 0);
    }
}

- (void)testCompactNextFramesBothTenFramesBeforeFirstPlayWithoutASetupScroll {
    for (NSNumber *make in @[@YES, @NO]) {
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc]
            initWithProblem:[self problemA:make.boolValue ? 2 : 18 b:9 make:make.boolValue]
            lesson:[self lessonAtIndex:make.boolValue ? 3 : 4]];
        [self hostIntro:intro width:288 height:500];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        XCTAssertEqual(intro.framingCount, 1u);
        for (NSInteger step = 1; step < intro.numberOfSteps; step++) {
            [intro goToNextStep];
            XCTAssertEqual(intro.framingCount, (NSUInteger)step + 1);
            [self assertLastTransitionIsFramedBeforeItsTargetIsApplied:intro];
            UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
            CGRect viewport = intro.viewportSnapshots.lastObject.CGRectValue;
            XCTAssertTrue(CGRectContainsRect(viewport, CGRectUnion(first.frame, second.frame)));
            for (UIView *label in @[[intro valueForKey:@"firstCountLabel"], [intro valueForKey:@"secondCountLabel"]]) {
                XCTAssertTrue(CGRectContainsRect(viewport, label.frame));
            }
            XCTAssertGreaterThan(scroll.contentOffset.y, 0);
            [self assertVisibleDotsFitWithoutOverlapping:intro];
            [intro stopPlayback];
        }
    }
}

- (void)testWideShortNextFitsBothFullTenFramesBeforeItsFirstPlay {
    for (NSNumber *width in @[@544, @736]) {
        for (NSNumber *make in @[@YES, @NO]) {
            CLRecordingIntroView *intro = [[CLRecordingIntroView alloc]
                initWithProblem:[self problemA:make.boolValue ? 9 : 18 b:9 make:make.boolValue]
                lesson:[self lessonAtIndex:make.boolValue ? 3 : 4]];
            [self hostIntro:intro width:width.doubleValue height:260];
            UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
            XCTAssertEqualWithAccuracy(first.frame.origin.y, second.frame.origin.y, 0.001);
            XCTAssertGreaterThanOrEqual(second.frame.origin.x - CGRectGetMaxX(first.frame), 24);
            XCTAssertGreaterThanOrEqual(first.bounds.size.width, 240);
            XCTAssertGreaterThanOrEqual(second.bounds.size.width, 240);
            XCTAssertEqualWithAccuracy(first.bounds.size.height, 100, 0.001);
            XCTAssertEqualWithAccuracy(second.bounds.size.height, 100, 0.001);
            XCTAssertEqualObjects([first valueForKey:@"capacity"], @10);
            XCTAssertEqualObjects([second valueForKey:@"capacity"], @10);
            for (NSInteger step = 1; step < intro.numberOfSteps; step++) {
                [intro goToNextStep];
                [self assertLastTransitionIsFramedBeforeItsTargetIsApplied:intro];
                CGRect viewport = intro.viewportSnapshots.lastObject.CGRectValue;
                XCTAssertTrue(CGRectContainsRect(viewport, CGRectUnion(first.frame, second.frame)));
                for (UIView *label in @[[intro valueForKey:@"firstCountLabel"], [intro valueForKey:@"secondCountLabel"]]) {
                    XCTAssertTrue(CGRectContainsRect(viewport, label.frame));
                }
                for (UIView *dot in [intro valueForKey:@"dots"]) {
                    XCTAssertEqualWithAccuracy(dot.bounds.size.width, 32, 0.001);
                    XCTAssertEqualWithAccuracy(dot.bounds.size.height, 32, 0.001);
                }
                [self assertVisibleDotsFitWithoutOverlapping:intro];
                [intro stopPlayback];
            }
        }
    }
}

- (void)testShortCompactNextFramesTheWholeCounterTransformationWhenAnnotationsDoNotFit {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    [self hostIntro:intro width:288 height:420];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
    XCTAssertGreaterThan(CGRectUnion(first.frame, second.frame).size.height, scroll.bounds.size.height);
    for (NSInteger step = 1; step <= 3; step++) {
        [intro goToNextStep];
        [self assertLastTransitionIsFramedBeforeItsTargetIsApplied:intro];
        [intro stopPlayback];
    }
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
}

- (void)testReplayAndBackPreserveAValidUserChosenOffsetInCompactAndWideLayouts {
    for (NSValue *sizeValue in @[[NSValue valueWithCGSize:CGSizeMake(288, 500)],
        [NSValue valueWithCGSize:CGSizeMake(736, 260)]]) {
        CGSize size = sizeValue.CGSizeValue;
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
            lesson:[self lessonAtIndex:3]];
        [self hostIntro:intro width:size.width height:size.height];
        [self settleIntro:intro atStep:3];
        [intro setNeedsLayout]; [intro layoutIfNeeded];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        [scroll layoutIfNeeded];
        CGFloat chosenOffset = 32;
        XCTAssertGreaterThan(scroll.contentSize.height - scroll.bounds.size.height, chosenOffset);
        [scroll setContentOffset:CGPointMake(0, chosenOffset) animated:NO];
        NSUInteger framingBeforeInspection = intro.framingCount;
        [intro replayCurrentStep];
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
        XCTAssertEqual(intro.framingCount, framingBeforeInspection);
        [intro layoutIfNeeded];
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
        [intro goToPreviousStep];
        [intro layoutIfNeeded];
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
        XCTAssertEqual(intro.currentStepIndex, 2);
        XCTAssertEqual(intro.framingCount, framingBeforeInspection);
        [self assertEquationHidden:intro a:2 b:9 make:YES];
    }
}

- (void)testTooShortViewportDoesNotJumpToOnlyOneEndOfTheTransformation {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    [self hostIntro:intro width:288 height:360];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    CGFloat offsetBeforeNext = scroll.contentOffset.y;
    [intro goToNextStep];
    CGRect counters = [self counterBoundsInSnapshots:@[intro.snapshots.lastObject]];
    XCTAssertGreaterThan(counters.size.height, scroll.bounds.size.height);
    XCTAssertEqualWithAccuracy(scroll.contentOffset.y, offsetBeforeNext, 0.001);
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 11u);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

- (void)testIdleBeyondTheOldTimerIntervalNeverAdvances {
    LessonIntroView *intro = [self showLessonAtIndex:3 width:288 height:500];
    [intro goToNextStep];
    NSPredicate *advanced = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [(LessonIntroView *)object currentStepIndex] != 1;
    }];
    XCTNSPredicateExpectation *unexpectedAdvance = [[XCTNSPredicateExpectation alloc] initWithPredicate:advanced object:intro];
    unexpectedAdvance.inverted = YES;
    [self waitForExpectations:@[unexpectedAdvance] timeout:3.7];
    [self assertEquationHidden:intro a:8 b:5 make:YES];
}

- (void)testStopBackgroundDetachAndReduceMotionSettleOnlyTheSelectedState {
    LessonIntroView *intro = [self showProblemA:2 b:9 make:YES width:288];
    [self settleIntro:intro atStep:3];
    for (NSString *interruption in @[@"stop", @"background", @"motion", @"hidden", @"alpha", @"detach"]) {
        [intro replayCurrentStep];
        if ([interruption isEqualToString:@"background"]) {
            [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
        } else if ([interruption isEqualToString:@"motion"]) {
            [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
        } else if ([interruption isEqualToString:@"hidden"]) intro.hidden = YES;
        else if ([interruption isEqualToString:@"alpha"]) intro.alpha = 0;
        else if ([interruption isEqualToString:@"detach"]) [intro removeFromSuperview];
        else [intro stopPlayback];
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqual(intro.currentStepIndex, 3);
        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
        [self assertEquationHidden:intro a:2 b:9 make:YES];
        intro.hidden = NO; intro.alpha = 1;
    }
}

- (void)testResizeCancelsMotionWithoutAdvancingOrClippingAnyOfEightOriginalOnes {
    LessonIntroView *intro = [self showProblemA:18 b:9 make:NO width:736];
    [self settleIntro:intro atStep:2];
    [intro replayCurrentStep];
    // Height-only changes do not alter the fixed-height stage's dimensions.
    // They must still settle the animation rather than relying on stage width.
    intro.frame = CGRectMake(0, 0, 736, 420);
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertEqual(intro.currentStepIndex, 2);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
    [intro replayCurrentStep];
    intro.frame = CGRectMake(0, 0, 288, 420);
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertEqual(intro.currentStepIndex, 2);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

- (void)testRepeatedTenFrameResizesRenderFinalChildBoundsAndPreserveReplaySourceGeometry {
    NSArray<NSValue *> *sizes = @[
        [NSValue valueWithCGSize:CGSizeMake(736, 260)], // Wide height-only.
        [NSValue valueWithCGSize:CGSizeMake(288, 260)], // Wide to compact.
        [NSValue valueWithCGSize:CGSizeMake(288, 300)], // Compact height-only.
        [NSValue valueWithCGSize:CGSizeMake(736, 300)], // Compact to wide.
        [NSValue valueWithCGSize:CGSizeMake(544, 300)], // Narrowest side-by-side.
        [NSValue valueWithCGSize:CGSizeMake(543, 300)], // Cross the exact boundary.
        [NSValue valueWithCGSize:CGSizeMake(544, 300)],
        [NSValue valueWithCGSize:CGSizeMake(320, 300)],
        [NSValue valueWithCGSize:CGSizeMake(288, 300)]  // Same orientation, new width.
    ];
    for (NSNumber *make in @[@YES, @NO]) {
        NSInteger a = make.boolValue ? 2 : 18, selectedStep = make.boolValue ? 3 : 2;
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc]
            initWithProblem:[self problemA:a b:9 make:make.boolValue]
            lesson:[self lessonAtIndex:make.boolValue ? 3 : 4]];
        [self hostIntro:intro width:736 height:300];
        [self settleIntro:intro atStep:selectedStep];
        NSArray<UIView *> *identities = [[intro valueForKey:@"dots"] copy];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        UIView *stage = [intro valueForKey:@"stage"];
        UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
        CGFloat chosenOffset = 32;
        [scroll setContentOffset:CGPointMake(0, chosenOffset) animated:NO];
        NSUInteger framingCount = intro.framingCount;
        for (NSValue *sizeValue in sizes) {
            CGSize size = sizeValue.CGSizeValue;
            [intro replayCurrentStep];
            if (!UIAccessibilityIsReduceMotionEnabled()) XCTAssertNotNil([intro valueForKey:@"stepAnimator"]);
            intro.frame = (CGRect){CGPointZero, size};
            [intro setNeedsLayout];
            [intro layoutIfNeeded];
            // Observe immediately after one public layout pass. A second
            // layout, Play, Stop or Replay here would conceal stale geometry.
            NSString *context = [NSString stringWithFormat:@"%@ resize to %@", make.boolValue ? @"make" : @"break",
                NSStringFromCGSize(size)];
            [self attachGeometryForIntro:intro name:context];
            CGFloat stageWidth = size.width - 32;
            BOOL wide = size.width >= 544;
            CGFloat frameWidth = wide ? MIN(280, (stageWidth - 32) / 2) : MIN(280, stageWidth - 8);
            CGFloat x = wide ? (stageWidth - frameWidth * 2 - 24) / 2 : (stageWidth - frameWidth) / 2;
            CGRect expectedFirst = CGRectMake(x, 34, frameWidth, 100);
            CGRect expectedSecond = CGRectMake(wide ? x + frameWidth + 24 : x, wide ? 34 : 188, frameWidth, 100);
            XCTAssertEqualWithAccuracy(stage.bounds.size.width, stageWidth, 0.001);
            XCTAssertEqualWithAccuracy(stage.bounds.size.height, wide ? 138 : 292, 0.001);
            XCTAssertTrue(CGRectEqualToRect(first.frame, expectedFirst));
            XCTAssertTrue(CGRectEqualToRect(second.frame, expectedSecond));
            XCTAssertTrue(CGRectEqualToRect([intro.geometrySnapshots.lastObject[@"stage"] CGRectValue], stage.bounds));
            XCTAssertNil([intro valueForKey:@"stepAnimator"]);
            XCTAssertEqual(intro.currentStepIndex, selectedStep);
            XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
            XCTAssertEqual([self visibleDotsInIntro:intro].count, make.boolValue ? 11u : 9u);
            XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], make.boolValue ? 10 : 1);
            XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], make.boolValue ? 1 : 8);
            XCTAssertEqual(intro.framingCount, framingCount);
            XCTAssertGreaterThan(scroll.contentSize.height - scroll.bounds.size.height, chosenOffset);
            XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
            [self assertEquationHidden:intro a:a b:9 make:make.boolValue];
            [self assertVisibleDotsFitWithoutOverlapping:intro];
            for (UIView *dot in identities) {
                XCTAssertEqualWithAccuracy(dot.bounds.size.width, 32, 0.001);
                XCTAssertEqualWithAccuracy(dot.bounds.size.height, 32, 0.001);
                if (dot.alpha > 0.5) XCTAssertTrue(CGRectContainsRect(stage.bounds, dot.frame));
            }

            NSUInteger snapshotsBeforeReplay = intro.snapshots.count;
            [intro replayCurrentStep];
            [self attachGeometryForIntro:intro name:[context stringByAppendingString:@" Replay source"]];
            XCTAssertEqual(intro.snapshots.count, snapshotsBeforeReplay + 2);
            if (intro.snapshots.count < snapshotsBeforeReplay + 2) continue;
            NSArray<NSDictionary *> *source = intro.snapshots[snapshotsBeforeReplay];
            NSDictionary *sourceGeometry = intro.geometrySnapshots[intro.geometrySnapshots.count - 2];
            XCTAssertEqualObjects(sourceGeometry[@"step"], @(selectedStep - 1));
            XCTAssertTrue(CGRectEqualToRect([sourceGeometry[@"stage"] CGRectValue], stage.bounds));
            XCTAssertTrue(CGRectEqualToRect([sourceGeometry[@"firstFrame"] CGRectValue], expectedFirst));
            XCTAssertTrue(CGRectEqualToRect([sourceGeometry[@"secondFrame"] CGRectValue], expectedSecond));
            NSInteger sourceFirstCount = make.boolValue ? 2 : 10;
            for (NSUInteger index = 0; index < source.count; index++) {
                CGRect frame = [source[index][@"frame"] CGRectValue];
                CGRect expectedFrame = index < sourceFirstCount ? expectedFirst : expectedSecond;
                NSInteger slot = index < sourceFirstCount ? index : index - sourceFirstCount;
                CGPoint center = [source[index][@"center"] CGPointValue];
                XCTAssertEqualWithAccuracy([source[index][@"alpha"] doubleValue], 1, 0.001);
                XCTAssertTrue(CGRectContainsRect(stage.bounds, frame));
                XCTAssertTrue(CGRectContainsRect(expectedFrame, frame));
                XCTAssertEqualWithAccuracy(center.x, expectedFrame.origin.x + (slot % 5 + 0.5) * frameWidth / 5, 0.001);
                XCTAssertEqualWithAccuracy(center.y, expectedFrame.origin.y + (slot / 5 + 0.5) * 50, 0.001);
            }
            XCTAssertEqual(intro.currentStepIndex, selectedStep);
            XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
            XCTAssertEqual(intro.framingCount, framingCount);
            XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
            [self assertEquationHidden:intro a:a b:9 make:make.boolValue];
        }
    }
}

- (void)testUnchangedStageLayoutDoesNotInterruptReplayOrRenderAnotherSnapshot {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    [self hostIntro:intro width:736 height:260];
    [self settleIntro:intro atStep:3];
    [intro replayCurrentStep];
    UIViewPropertyAnimator *animator = [intro valueForKey:@"stepAnimator"];
    if (!UIAccessibilityIsReduceMotionEnabled()) XCTAssertNotNil(animator);
    NSUInteger snapshotCount = intro.snapshots.count;
    UIView *stage = [intro valueForKey:@"stage"];
    [stage setNeedsLayout];
    [stage layoutIfNeeded];
    XCTAssertEqual([intro valueForKey:@"stepAnimator"], animator);
    XCTAssertEqual(intro.snapshots.count, snapshotCount);
    XCTAssertEqual(intro.currentStepIndex, 3);
    [self assertEquationHidden:intro a:2 b:9 make:YES];
}

- (void)testDescendantStageWidthChangeSettlesMotionWithoutAnIntroBoundsChange {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
        lesson:[self lessonAtIndex:4]];
    [self hostIntro:intro width:736 height:260];
    [self settleIntro:intro atStep:2];
    NSArray<UIView *> *identities = [[intro valueForKey:@"dots"] copy];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIView *stage = [intro valueForKey:@"stage"];
    NSLayoutConstraint *contentWidth = nil;
    for (NSLayoutConstraint *constraint in scroll.constraints) {
        if (constraint.firstItem == stage.superview && constraint.firstAttribute == NSLayoutAttributeWidth
            && constraint.secondItem == scroll.frameLayoutGuide && constraint.secondAttribute == NSLayoutAttributeWidth) {
            contentWidth = constraint;
            break;
        }
    }
    XCTAssertNotNil(contentWidth);
    if (!contentWidth) return;
    CGRect introBounds = intro.bounds;
    NSString *narration = intro.currentNarration;
    NSUInteger framingCount = intro.framingCount;
    [scroll setContentOffset:CGPointMake(0, 32) animated:NO];
    for (NSNumber *width in @[@512, @704]) {
        [intro replayCurrentStep];
        if (!UIAccessibilityIsReduceMotionEnabled()) XCTAssertNotNil([intro valueForKey:@"stepAnimator"]);
        contentWidth.constant = width.doubleValue - intro.bounds.size.width;
        // Lay out only the actual constraint-owning descendant subtree. The
        // intro's size is unchanged, so a parent-size observer cannot repair it.
        [scroll setNeedsLayout];
        [scroll layoutIfNeeded];
        [self attachGeometryForIntro:intro name:[NSString stringWithFormat:@"Descendant stage width %@", width]];
        XCTAssertTrue(CGRectEqualToRect(intro.bounds, introBounds));
        XCTAssertEqualWithAccuracy(stage.bounds.size.width, width.doubleValue, 0.001);
        XCTAssertTrue(CGRectEqualToRect([intro.geometrySnapshots.lastObject[@"stage"] CGRectValue], stage.bounds));
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqual(intro.currentStepIndex, 2);
        XCTAssertEqualObjects(intro.currentNarration, narration);
        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 1);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
        XCTAssertEqual(intro.framingCount, framingCount);
        XCTAssertGreaterThan(scroll.contentSize.height - scroll.bounds.size.height, 32);
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, 32, 0.001);
        [self assertEquationHidden:intro a:18 b:9 make:NO];
        [self assertVisibleDotsFitWithoutOverlapping:intro];
    }
}

- (void)testShortScreensScrollInsteadOfShrinkingEitherTenFrame {
    LessonIntroView *intro = [self showProblemA:9 b:9 make:YES width:288];
    intro.frame = CGRectMake(0, 0, 288, 360);
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    [self settleIntro:intro atStep:1];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIView *stage = [intro valueForKey:@"stage"];
    UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
    [scroll layoutIfNeeded];
    XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.size.height);
    XCTAssertGreaterThanOrEqual(first.bounds.size.height, 90);
    XCTAssertGreaterThanOrEqual(second.bounds.size.height, 90);
    XCTAssertGreaterThanOrEqual(stage.bounds.size.height, CGRectGetMaxY(second.frame));
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 18u);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

- (void)testSkippingOrFinishingTwiceOnlyCallsCompletionOnce {
    for (NSNumber *finishAtEnd in @[@NO, @YES]) {
        LessonIntroView *intro = [self showProblemA:11 b:9 make:NO width:288];
        CLIntroFinishObserver *observer = [[CLIntroFinishObserver alloc] init];
        intro.delegate = observer;
        if (finishAtEnd.boolValue) {
            [self settleIntro:intro atStep:intro.numberOfSteps - 1];
            [intro goToNextStep];
        }
        UIButton *start = [intro valueForKey:@"startButton"];
        [start sendActionsForControlEvents:UIControlEventTouchUpInside];
        [start sendActionsForControlEvents:UIControlEventTouchUpInside];
        [intro play]; [intro goToNextStep]; [intro goToPreviousStep]; [intro replayCurrentStep];
        XCTAssertEqual(observer.finishCount, 1);
        XCTAssertFalse(start.enabled);
        XCTAssertFalse([[intro valueForKey:@"previousButton"] isEnabled]);
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    }
}

- (void)testUnattachedPlayDoesNotScheduleWorkOrFinishTheLesson {
    LessonIntroView *intro = [[LessonIntroView alloc] initWithLesson:[self lessonAtIndex:0]];
    CLIntroFinishObserver *observer = [[CLIntroFinishObserver alloc] init];
    intro.delegate = observer;
    [intro play];
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertEqual(intro.currentStepIndex, 0);
    XCTAssertEqual(observer.finishCount, 0);
    [intro stopPlayback];
}

- (void)testRemovedIntroIsNotKeptAliveByPlayback {
    __weak LessonIntroView *weakIntro;
    @autoreleasepool {
        LessonIntroView *intro = [self showLessonAtIndex:0 width:288 height:420];
        [intro goToNextStep];
        weakIntro = intro;
        [intro removeFromSuperview];
        self.intro = nil;
    }
    XCTAssertNil(weakIntro);
}

- (void)testGridAnnotationsStayReadableAndFullNarrationSupportsLargeText {
    LessonIntroView *intro = [self showLessonAtIndex:3 width:288 height:420];
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
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    XCTAssertGreaterThan(narration.bounds.size.height, 40);
    XCTAssertEqualObjects(intro.currentNarration, narration.text);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

- (void)testCurrentQuestionExplanationUsesTheFullSurfaceWithoutAnAnswerFooter {
    ExplanationViewController *controller = [[ExplanationViewController alloc]
        initWithArithmeticProblem:[self problemA:2 b:9 make:YES] wordProblem:nil lesson:[self lessonAtIndex:3]];
    self.hostWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
    self.hostWindow.rootViewController = controller;
    self.hostWindow.hidden = NO;
    controller.view.frame = self.hostWindow.bounds;
    [controller.view setNeedsLayout]; [controller.view layoutIfNeeded];
    LessonIntroView *intro = [controller valueForKey:@"tenFrameTeaching"];
    self.intro = intro;
    XCTAssertNotNil(intro);
    XCTAssertGreaterThan(intro.bounds.size.height, 360);
    XCTAssertNil([controller valueForKey:@"explanation"]);
    XCTAssertNil([controller valueForKey:@"replayButton"]);
    XCTAssertNil([controller valueForKey:@"visualHeight"]);
    [self assertEquationHidden:intro a:2 b:9 make:YES];
    XCTAssertEqualObjects([[intro valueForKey:@"startButton"] titleForState:UIControlStateNormal], @"回到題目");
}

@end

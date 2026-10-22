#import <XCTest/XCTest.h>
#import "VerticalTeachingViewController.h"
#import "VerticalArithmeticBoardView.h"
#import "ArithmeticProblem.h"

@interface VerticalTeachingViewController (ViewportTesting)
- (BOOL)frameCurrentTransformation;
- (void)replay;
- (BOOL)playCurrentAction;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
@end

// Keep synthetic geometry isolated from viewDidLoad's real sheet constraints.
@interface VTViewportController : VerticalTeachingViewController
@end
@implementation VTViewportController
- (void)loadView { self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 1000)]; }
- (void)viewDidLoad {}
@end
@interface VTViewportBoard : VerticalArithmeticBoardView
@end
@implementation VTViewportBoard
- (BOOL)canAnimate { return YES; }
@end

@interface VerticalTeachingViewportTests : XCTestCase
@property (nonatomic, strong) VerticalTeachingViewController *controller;
@property (nonatomic, strong) ArithmeticTeachingSequence *sequence;
@property (nonatomic, strong) VerticalArithmeticBoardView *board;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic) NSUInteger regroupIndex;
@end

@implementation VerticalTeachingViewportTests

- (void)setUp {
    [super setUp];
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:500 number2:128 operator:@"-" answer:372];
    self.controller = [[VTViewportController alloc] initWithProblem:problem wordProblem:nil];
    [self.controller loadViewIfNeeded];
    self.sequence = [self.controller valueForKey:@"sequence"];
    self.regroupIndex = [self.sequence.steps indexOfObjectPassingTest:^BOOL(ArithmeticTeachingStep *step, NSUInteger index, BOOL *stop) {
        return step.kind == ArithmeticTeachingStepKindRegroup;
    }];
    XCTAssertTrue(self.sequence.isValid);
    XCTAssertNotEqual(self.regroupIndex, NSNotFound);

    // Isolate the viewport from sheet chrome, but use the real controller method
    // and real fitted board geometry. No replacement scrolling implementation.
    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scroll.contentSize = CGSizeMake(320, 2400);
    self.board = [[VTViewportBoard alloc] initWithFrame:CGRectMake(16, 640, 288, 500)];
    [self.scroll addSubview:self.board];
    [self.controller.view addSubview:self.scroll];
    [self.controller setValue:self.scroll forKey:@"scroll"];
    [self.controller setValue:self.board forKey:@"board"];
    [self selectStep:self.regroupIndex];
    XCTAssertEqual(self.board.currentStep.kind, ArithmeticTeachingStepKindRegroup);
    XCTAssertFalse(CGRectIsNull(self.board.currentTransformationRect));
    XCTAssertFalse(CGRectIsEmpty(self.board.currentTransformationRect));
    XCTAssertFalse(CGRectIsNull(self.board.currentConcreteTransformationRect));
    XCTAssertFalse(CGRectIsEmpty(self.board.currentConcreteTransformationRect));
}

- (void)tearDown {
    [self.board cancelAnimations];
    self.controller = nil;
    self.board = nil;
    self.scroll = nil;
    self.sequence = nil;
    [super tearDown];
}

- (void)selectStep:(NSUInteger)index {
    [self.controller setValue:@(index) forKey:@"stepIndex"];
    XCTAssertTrue([self.board configureWithSequence:self.sequence stepIndex:index animated:NO]);
    CGSize fitted = [self.board sizeThatFits:CGSizeMake(288, CGFLOAT_MAX)];
    self.board.frame = CGRectMake(16, 640, fitted.width, fitted.height);
    [self.board setNeedsLayout];
    [self.board layoutIfNeeded];
    XCTAssertEqual(self.board.currentStepIndex, (NSInteger)index);
    XCTAssertEqualObjects([self.controller valueForKey:@"currentStep"], self.board.currentStep);
}

- (void)setViewportHeight:(CGFloat)height {
    self.scroll.frame = CGRectMake(0, 0, 320, height);
    [self.scroll setContentOffset:CGPointZero animated:NO];
}

- (BOOL)viewportContainsBoardRect:(CGRect)rect {
    return CGRectContainsRect(CGRectInset(self.scroll.bounds, 0, 8),
        [self.board convertRect:rect toView:self.scroll]);
}

- (void)testFirstPlayFramesBothWrittenAndConcreteExchangeWhenTheyFit {
    CGRect full = self.board.currentTransformationRect;
    UIView *grid = [self.board valueForKey:@"gridView"];
    XCTAssertNotNil(grid);
    XCTAssertFalse(CGRectIsEmpty(grid.bounds));
    CGRect written = [grid convertRect:grid.bounds toView:self.board];
    [self setViewportHeight:full.size.height + 48];
    XCTAssertFalse([self viewportContainsBoardRect:full]);

    XCTAssertTrue([self.controller frameCurrentTransformation]);

    XCTAssertTrue([self viewportContainsBoardRect:full]);
    XCTAssertTrue([self viewportContainsBoardRect:written]);
    XCTAssertTrue([self viewportContainsBoardRect:self.board.currentConcreteTransformationRect]);
    XCTAssertGreaterThan(self.scroll.contentOffset.y, 0);
    XCTAssertEqual(self.board.currentStepIndex, (NSInteger)self.regroupIndex);
}

- (void)testShortViewportPrioritizesTheEntireConcreteExchange {
    CGRect full = self.board.currentTransformationRect;
    CGRect concrete = self.board.currentConcreteTransformationRect;
    [self setViewportHeight:concrete.size.height + 32];
    XCTAssertGreaterThan(full.size.height, self.scroll.bounds.size.height - 16);
    XCTAssertFalse([self viewportContainsBoardRect:concrete]);

    XCTAssertTrue([self.controller frameCurrentTransformation]);

    XCTAssertTrue([self viewportContainsBoardRect:concrete]);
    XCTAssertFalse([self viewportContainsBoardRect:full]);
    XCTAssertGreaterThan(self.scroll.contentOffset.y, 0);
}

- (void)testAlreadyVisibleExchangeDoesNotMoveInspectionPosition {
    CGRect full = self.board.currentTransformationRect;
    [self setViewportHeight:full.size.height + 80];
    CGRect inContent = [self.board convertRect:full toView:self.scroll];
    CGPoint inspection = CGPointMake(0, CGRectGetMinY(inContent) - 20);
    [self.scroll setContentOffset:inspection animated:NO];
    XCTAssertTrue([self viewportContainsBoardRect:full]);

    XCTAssertFalse([self.controller frameCurrentTransformation]);

    XCTAssertTrue(CGPointEqualToPoint(self.scroll.contentOffset, inspection));
    NSString *snapshot = self.board.accessibilityValue;
    [self.controller replay];
    XCTAssertTrue(CGPointEqualToPoint(self.scroll.contentOffset, inspection),
        @"Replay retains an inspection position when the complete causal action already fits.");
    XCTAssertEqual(self.board.currentStepIndex, (NSInteger)self.regroupIndex);
    XCTAssertEqualObjects([self.controller valueForKey:@"currentStep"], self.board.currentStep);
    XCTAssertEqualObjects(self.board.accessibilityValue, snapshot);
}

- (void)testReplayRecoversTheEntireConcreteExchangeWithoutChangingTheStep {
    [self setViewportHeight:self.board.currentConcreteTransformationRect.size.height + 32];
    [self.scroll setContentOffset:CGPointMake(0, 140) animated:NO];
    XCTAssertFalse([self viewportContainsBoardRect:self.board.currentConcreteTransformationRect]);
    NSString *snapshot = self.board.accessibilityValue;
    // Replaces the old unchanged-offset assertion: an offset that hides counters
    // is not successful Replay. Require semantic containment and real playback.
    [self.controller replay];
    XCTAssertTrue([self viewportContainsBoardRect:self.board.currentConcreteTransformationRect]);
    XCTAssertTrue(self.board.isPlaying);
    XCTAssertFalse([[self.board valueForKey:@"playsWrittenExchange"] boolValue]);
    XCTAssertEqual(self.board.currentStepIndex, (NSInteger)self.regroupIndex);
    XCTAssertEqualObjects([self.controller valueForKey:@"currentStep"], self.board.currentStep);
    XCTAssertFalse(CGRectIsNull(self.board.currentConcreteTransformationRect));
    XCTAssertFalse(CGRectIsEmpty(self.board.currentConcreteTransformationRect));
    XCTAssertEqualObjects(self.board.accessibilityValue, snapshot);
    XCTAssertTrue([snapshot containsString:@"答案還沒寫"]);
}
- (void)testReplayAfterPortraitToLandscapeResizeFramesCurrentActionBeforePlaying {
    [self setViewportHeight:self.board.currentTransformationRect.size.height + 48];
    [self.controller replay];
    XCTAssertTrue([self viewportContainsBoardRect:self.board.currentTransformationRect]);
    XCTAssertTrue([[self.board valueForKey:@"playsWrittenExchange"] boolValue]);
    NSString *snapshot = self.board.accessibilityValue;
    [self setViewportHeight:self.board.currentConcreteTransformationRect.size.height + 32];
    [self.controller replay];
    XCTAssertTrue([self viewportContainsBoardRect:self.board.currentConcreteTransformationRect]);
    XCTAssertFalse([[self.board valueForKey:@"playsWrittenExchange"] boolValue]);
    XCTAssertTrue(self.board.isPlaying);
    XCTAssertEqualObjects(self.board.accessibilityValue, snapshot);
    XCTAssertEqual(self.board.currentStepIndex, (NSInteger)self.regroupIndex);
}
- (void)testTooShortViewportDoesNotStartAPartiallyVisibleExchange {
    [self setViewportHeight:self.board.currentConcreteTransformationRect.size.height - 1];
    NSString *snapshot = self.board.accessibilityValue;
    XCTAssertFalse([self.controller playCurrentAction]);
    XCTAssertFalse([self viewportContainsBoardRect:self.board.currentConcreteTransformationRect]);
    XCTAssertFalse(self.board.isPlaying);
    XCTAssertEqual([[self.board valueForKey:@"animatedLayers"] count], 0u);
    XCTAssertNil([self.board valueForKey:@"animationDisplayLink"]);
    XCTAssertEqualObjects(self.board.accessibilityValue, snapshot);
}
- (void)testManualInspectionOrAProgrammaticLossOfContainmentStopsMotion {
    [self setViewportHeight:self.board.currentConcreteTransformationRect.size.height + 32];
    [self.controller replay];
    XCTAssertTrue(self.board.isPlaying);
    [self.controller scrollViewWillBeginDragging:self.scroll];
    XCTAssertFalse(self.board.isPlaying);
    XCTAssertEqual(self.board.playbackState, VerticalArithmeticPlaybackStateInterrupted);
    [self.controller replay];
    XCTAssertTrue(self.board.isPlaying);
    [self.scroll setContentOffset:CGPointZero animated:NO];
    [self.controller scrollViewDidScroll:self.scroll];
    XCTAssertFalse(self.board.isPlaying);
    XCTAssertEqual(self.board.currentStepIndex, (NSInteger)self.regroupIndex);
}

- (void)testNonRegroupAndInvalidStepsRefuseToScroll {
    [self selectStep:0];
    XCTAssertEqual(self.board.currentStep.kind, ArithmeticTeachingStepKindAlignment);
    CGPoint inspection = CGPointMake(0, 120);
    [self.scroll setContentOffset:inspection animated:NO];
    XCTAssertTrue(CGRectIsNull(self.board.currentTransformationRect));
    XCTAssertFalse([self.controller frameCurrentTransformation]);
    XCTAssertTrue(CGPointEqualToPoint(self.scroll.contentOffset, inspection));

    NSUInteger invalidIndex = self.sequence.steps.count;
    [self.controller setValue:@(invalidIndex) forKey:@"stepIndex"];
    XCTAssertFalse([self.board showStepAtIndex:invalidIndex animated:NO]);
    XCTAssertNil([self.controller valueForKey:@"currentStep"]);
    XCTAssertTrue(CGRectIsNull(self.board.currentTransformationRect));
    XCTAssertTrue(CGRectIsNull(self.board.currentConcreteTransformationRect));
    XCTAssertFalse([self.controller frameCurrentTransformation]);
    XCTAssertTrue(CGPointEqualToPoint(self.scroll.contentOffset, inspection));
}

@end

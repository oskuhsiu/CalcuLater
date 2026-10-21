#import <XCTest/XCTest.h>
#import "VerticalTeachingViewController.h"
#import "VerticalArithmeticBoardView.h"
#import "ArithmeticProblem.h"

@interface VerticalTeachingViewController (ViewportTesting)
- (BOOL)frameCurrentTransformation;
- (void)replay;
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
    self.controller = [[VerticalTeachingViewController alloc] initWithProblem:problem wordProblem:nil];
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
    self.board = [[VerticalArithmeticBoardView alloc] initWithFrame:CGRectMake(16, 640, 288, 500)];
    [self.scroll addSubview:self.board];
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
}

- (void)testReplayPreservesTheChosenInspectionOffsetAndStep {
    [self setViewportHeight:self.board.currentConcreteTransformationRect.size.height + 32];
    CGPoint inspection = CGPointMake(0, 140);
    [self.scroll setContentOffset:inspection animated:NO];
    XCTAssertFalse([self viewportContainsBoardRect:self.board.currentConcreteTransformationRect]);

    [self.controller replay];

    XCTAssertTrue(CGPointEqualToPoint(self.scroll.contentOffset, inspection));
    XCTAssertEqual(self.board.currentStepIndex, (NSInteger)self.regroupIndex);
    XCTAssertEqualObjects([self.controller valueForKey:@"currentStep"], self.board.currentStep);
    XCTAssertFalse(CGRectIsEmpty(self.board.currentConcreteTransformationRect));
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

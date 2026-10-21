#include <stdlib.h>
#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "DrawingCanvasView.h"

/// Minimal event samples exercise the canvas's public touch entry points without
/// relying on UIKit's private UITouch initializer or synthesizing system events.
@interface CanvasTouchSample : NSObject
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) NSTimeInterval timestamp;
- (CGPoint)preciseLocationInView:(UIView *)view;
@end
@implementation CanvasTouchSample
- (CGPoint)preciseLocationInView:(UIView *)view { return self.point; }
@end

@interface DrawingCanvasViewTests : XCTestCase
@end

@implementation DrawingCanvasViewTests

- (DrawingCanvasView *)canvas {
    return [[DrawingCanvasView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
}

- (CanvasTouchSample *)touchAt:(CGPoint)point time:(NSTimeInterval)time {
    CanvasTouchSample *touch = [[CanvasTouchSample alloc] init];
    touch.point = point;
    touch.timestamp = time;
    return touch;
}

- (NSSet<UITouch *> *)touchSet:(CanvasTouchSample *)touch {
    return [NSSet setWithObject:(UITouch *)(id)touch];
}

- (void)drawTap:(CGPoint)point onCanvas:(DrawingCanvasView *)canvas {
    CanvasTouchSample *touch = [self touchAt:point time:1];
    [canvas touchesBegan:[self touchSet:touch] withEvent:nil];
    [canvas touchesEnded:[self touchSet:touch] withEvent:nil];
}

- (void)testTapCreatesVisibleInkAndOneUndoableStroke {
    DrawingCanvasView *canvas = [self canvas];
    [self drawTap:CGPointMake(40, 40) onCanvas:canvas];
    XCTAssertEqual(canvas.strokeCount, 1u);
    XCTAssertTrue(canvas.canUndo);
    XCTAssertEqualObjects(canvas.accessibilityValue, @"已畫 1 筆");

    // Check rendered pixels, not just the presence of a move-only Bezier path.
    const size_t width = 200, height = 200, bytesPerRow = width * 4;
    unsigned char *pixels = calloc(height, bytesPerRow);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, bytesPerRow, space,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    XCTAssertNotEqual(context, NULL);
    if (context) {
        UIGraphicsPushContext(context);
        [canvas drawRect:canvas.bounds];
        UIGraphicsPopContext();
        NSUInteger inkPixelCount = 0;
        for (size_t i = 0; i < width * height; i++) if (pixels[i * 4 + 3] > 0) inkPixelCount++;
        XCTAssertGreaterThan(inkPixelCount, 0u);
        CGContextRelease(context);
    }
    CGColorSpaceRelease(space);
    free(pixels);
    [canvas undoLastStroke];
    XCTAssertEqual(canvas.strokeCount, 0u);
    XCTAssertFalse(canvas.canUndo);
}

- (void)testEndedTouchIncludesItsFinalPointWithoutAMoveEvent {
    DrawingCanvasView *canvas = [self canvas];
    CanvasTouchSample *touch = [self touchAt:CGPointMake(10, 20) time:1];
    [canvas touchesBegan:[self touchSet:touch] withEvent:nil];
    touch.point = CGPointMake(80, 90);
    [canvas touchesEnded:[self touchSet:touch] withEvent:nil];
    NSArray *strokes = [canvas valueForKey:@"strokes"];
    UIBezierPath *path = [strokes.firstObject valueForKey:@"path"];
    XCTAssertTrue(CGPointEqualToPoint(path.currentPoint, CGPointMake(80, 90)));
    XCTAssertTrue([[strokes.firstObject valueForKey:@"hasLine"] boolValue]);
    XCTAssertEqual(canvas.strokeCount, 1u);
}

- (void)testSecondFingerCannotAppendOrEndThePrimaryStroke {
    DrawingCanvasView *canvas = [self canvas];
    XCTAssertFalse(canvas.multipleTouchEnabled);
    CanvasTouchSample *first = [self touchAt:CGPointMake(10, 10) time:1];
    CanvasTouchSample *second = [self touchAt:CGPointMake(150, 150) time:2];
    [canvas touchesBegan:[self touchSet:first] withEvent:nil];
    [canvas touchesBegan:[self touchSet:second] withEvent:nil];
    second.point = CGPointMake(190, 190);
    [canvas touchesMoved:[self touchSet:second] withEvent:nil];
    [canvas touchesEnded:[self touchSet:second] withEvent:nil];
    first.point = CGPointMake(30, 40);
    [canvas touchesEnded:[self touchSet:first] withEvent:nil];
    NSArray *strokes = [canvas valueForKey:@"strokes"];
    UIBezierPath *path = [strokes.firstObject valueForKey:@"path"];
    XCTAssertEqual(canvas.strokeCount, 1u);
    XCTAssertTrue(CGPointEqualToPoint(path.currentPoint, CGPointMake(30, 40)));
    XCTAssertLessThanOrEqual(CGRectGetMaxX(path.bounds), 30.0);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(path.bounds), 40.0);
}

- (void)testIntentionalScrollDiscardsOnlyUnfinishedInk {
    DrawingCanvasView *canvas = [self canvas];
    [self drawTap:CGPointMake(20, 20) onCanvas:canvas];
    CanvasTouchSample *touch = [self touchAt:CGPointMake(80, 80) time:2];
    [canvas touchesBegan:[self touchSet:touch] withEvent:nil];
    [canvas cancelActiveStroke];
    [canvas touchesCancelled:[self touchSet:touch] withEvent:nil];
    [canvas touchesEnded:[self touchSet:touch] withEvent:nil];
    XCTAssertEqual(canvas.strokeCount, 1u);
    [canvas undoLastStroke];
    XCTAssertEqual(canvas.strokeCount, 0u);
    XCTAssertFalse(canvas.canUndo);
}

- (void)testSimultaneousBeginChoosesOnlyTheEarliestTouch {
    DrawingCanvasView *canvas = [self canvas];
    CanvasTouchSample *first = [self touchAt:CGPointMake(10, 10) time:1];
    CanvasTouchSample *second = [self touchAt:CGPointMake(150, 150) time:2];
    NSSet<UITouch *> *touches = [NSSet setWithObjects:(UITouch *)(id)first, (UITouch *)(id)second, nil];
    [canvas touchesBegan:touches withEvent:nil];
    first.point = CGPointMake(20, 20);
    [canvas touchesEnded:touches withEvent:nil];
    XCTAssertEqual(canvas.strokeCount, 1u);
    NSArray *strokes = [canvas valueForKey:@"strokes"];
    UIBezierPath *path = [strokes.firstObject valueForKey:@"path"];
    XCTAssertTrue(CGPointEqualToPoint(path.currentPoint, CGPointMake(20, 20)));
}

- (void)testClearIsOneUndoableActionAndEarlierStrokeUndoStillWorks {
    DrawingCanvasView *canvas = [self canvas];
    [self drawTap:CGPointMake(10, 10) onCanvas:canvas];
    [self drawTap:CGPointMake(20, 20) onCanvas:canvas];
    [canvas clearCanvas];
    XCTAssertEqual(canvas.strokeCount, 0u);
    XCTAssertTrue(canvas.canUndo);
    [canvas clearCanvas]; // Empty clear must not hide the useful undo action.
    [canvas undoLastStroke];
    XCTAssertEqual(canvas.strokeCount, 2u);
    [canvas undoLastStroke];
    XCTAssertEqual(canvas.strokeCount, 1u);
    [canvas undoLastStroke];
    XCTAssertEqual(canvas.strokeCount, 0u);
    XCTAssertFalse(canvas.canUndo);
}

- (void)testDrawingAfterClearUndoesInOrder {
    DrawingCanvasView *canvas = [self canvas];
    [self drawTap:CGPointMake(10, 10) onCanvas:canvas];
    [canvas clearCanvas];
    [self drawTap:CGPointMake(20, 20) onCanvas:canvas];
    [canvas undoLastStroke];
    XCTAssertEqual(canvas.strokeCount, 0u);
    [canvas undoLastStroke];
    XCTAssertEqual(canvas.strokeCount, 1u);
    NSArray *strokes = [canvas valueForKey:@"strokes"];
    UIBezierPath *path = [strokes.firstObject valueForKey:@"path"];
    XCTAssertTrue(CGPointEqualToPoint(path.currentPoint, CGPointMake(10, 10)));
}

- (void)testClearDuringDrawingDoesNotResurrectLateEndEvents {
    DrawingCanvasView *canvas = [self canvas];
    CanvasTouchSample *touch = [self touchAt:CGPointMake(10, 10) time:1];
    [canvas touchesBegan:[self touchSet:touch] withEvent:nil];
    touch.point = CGPointMake(40, 40);
    [canvas touchesMoved:[self touchSet:touch] withEvent:nil];
    [canvas clearCanvas];
    [canvas touchesEnded:[self touchSet:touch] withEvent:nil];
    XCTAssertEqual(canvas.strokeCount, 0u);
    [canvas undoLastStroke];
    XCTAssertEqual(canvas.strokeCount, 1u);
}

- (void)testResetRemovesPreviousQuestionUndoHistory {
    DrawingCanvasView *canvas = [self canvas];
    CanvasTouchSample *touch = [self touchAt:CGPointMake(10, 10) time:1];
    [canvas touchesBegan:[self touchSet:touch] withEvent:nil];
    [canvas resetCanvas];
    [canvas touchesEnded:[self touchSet:touch] withEvent:nil];
    [canvas undoLastStroke];
    XCTAssertEqual(canvas.strokeCount, 0u);
    XCTAssertFalse(canvas.canUndo);
    XCTAssertEqualObjects(canvas.accessibilityValue, @"空白");
}

- (void)testCancellationKeepsExistingInkWithoutAddingAnUnobservedTail {
    DrawingCanvasView *canvas = [self canvas];
    CanvasTouchSample *touch = [self touchAt:CGPointMake(10, 10) time:1];
    [canvas touchesBegan:[self touchSet:touch] withEvent:nil];
    touch.point = CGPointMake(50, 50);
    [canvas touchesMoved:[self touchSet:touch] withEvent:nil];
    touch.point = CGPointMake(100, 100);
    [canvas touchesCancelled:[self touchSet:touch] withEvent:nil];
    NSArray *strokes = [canvas valueForKey:@"strokes"];
    UIBezierPath *path = [strokes.firstObject valueForKey:@"path"];
    XCTAssertEqual(canvas.strokeCount, 1u);
    XCTAssertTrue(CGPointEqualToPoint(path.currentPoint, CGPointMake(50, 50)));
    [canvas undoLastStroke];
    XCTAssertEqual(canvas.strokeCount, 0u);
}

- (void)testScratchpadExplainsItsPurposeAndOffersOnlyAvailableActions {
    DrawingCanvasView *canvas = [self canvas];
    XCTAssertEqualObjects(canvas.accessibilityLabel, @"計算草稿板");
    XCTAssertTrue([canvas.accessibilityHint containsString:@"不會辨識或檢查答案"]);
    XCTAssertEqual(canvas.accessibilityCustomActions.count, 0u);
    [self drawTap:CGPointMake(10, 10) onCanvas:canvas];
    XCTAssertEqual(canvas.accessibilityCustomActions.count, 2u);
    [canvas clearCanvas];
    XCTAssertEqual(canvas.accessibilityCustomActions.count, 1u);
    XCTAssertEqualObjects(canvas.accessibilityCustomActions.firstObject.name, @"復原上一個動作");
}

@end

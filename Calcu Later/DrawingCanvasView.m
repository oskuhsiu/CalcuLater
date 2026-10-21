#import "DrawingCanvasView.h"

/// Once committed, a stroke is immutable. Clear history can retain it without copying paths.
@interface CLCanvasStroke : NSObject
@property (nonatomic, strong) UIBezierPath *path;
@property (nonatomic, assign) CGPoint firstPoint;
@property (nonatomic, assign) CGPoint lastPoint;
@property (nonatomic, assign) BOOL hasLine;
- (instancetype)initWithPoint:(CGPoint)point;
- (void)appendPoint:(CGPoint)point;
- (void)draw;
@end

@implementation CLCanvasStroke
- (instancetype)initWithPoint:(CGPoint)point {
    self = [super init];
    if (self) {
        _firstPoint = point;
        _lastPoint = point;
        _path = [UIBezierPath bezierPath];
        _path.lineWidth = 3.0;
        _path.lineCapStyle = kCGLineCapRound;
        _path.lineJoinStyle = kCGLineJoinRound;
        [_path moveToPoint:point];
    }
    return self;
}

- (void)appendPoint:(CGPoint)point {
    if (CGPointEqualToPoint(point, self.lastPoint)) return;
    [self.path addLineToPoint:point];
    self.lastPoint = point;
    self.hasLine = YES;
}

- (void)draw {
    if (self.hasLine) {
        [self.path stroke];
    } else {
        // A move-only path has no ink. A tap is an intentional, round pencil dot.
        CGFloat radius = self.path.lineWidth * 0.5;
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(self.firstPoint.x - radius,
                                                        self.firstPoint.y - radius,
                                                        radius * 2, radius * 2)] fill];
    }
}
@end

@interface CLCanvasUndoAction : NSObject
@property (nonatomic, assign) BOOL restoresClear;
@property (nonatomic, copy) NSArray<CLCanvasStroke *> *strokes;
@end
@implementation CLCanvasUndoAction
@end

@interface DrawingCanvasView ()
@property (nonatomic, strong) NSMutableArray<CLCanvasStroke *> *strokes;
@property (nonatomic, strong) NSMutableArray<CLCanvasUndoAction *> *undoHistory;
@property (nonatomic, strong, nullable) UITouch *activeTouch;
@property (nonatomic, strong, nullable) CLCanvasStroke *activeStroke;
@end

@implementation DrawingCanvasView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self commonInit];
    return self;
}

- (void)commonInit {
    self.backgroundColor = UIColor.clearColor;
    self.strokes = [NSMutableArray array];
    self.undoHistory = [NSMutableArray array];
    self.multipleTouchEnabled = NO;
    self.clipsToBounds = YES;
    self.contentMode = UIViewContentModeRedraw;
    self.isAccessibilityElement = YES;
    self.accessibilityIdentifier = @"scratchpad.canvas";
    self.accessibilityLabel = @"計算草稿板";
    self.accessibilityLanguage = @"zh-TW";
    self.accessibilityHint = @"可以畫圖或寫字幫助思考。這裡不會辨識或檢查答案。可用動作選單清除或復原。";
    self.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction;
    [self updateAccessibilityState];
}

- (NSUInteger)strokeCount {
    return self.strokes.count + (self.activeStroke ? 1 : 0);
}

- (BOOL)canUndo {
    return self.activeStroke != nil || self.undoHistory.count > 0;
}

#pragma mark - Single-stroke touch tracking

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.activeTouch || touches.count == 0) return;
    // UIKit normally supplies one touch because multipleTouchEnabled is NO. Choose one
    // deterministically if an event supplies more; never connect unrelated fingers' paths.
    UITouch *primary = nil;
    for (UITouch *touch in touches) {
        if (!primary || touch.timestamp < primary.timestamp) primary = touch;
    }
    self.activeTouch = primary;
    self.activeStroke = [[CLCanvasStroke alloc] initWithPoint:[primary preciseLocationInView:self]];
    [self setNeedsDisplay];
    [self updateAccessibilityState];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.activeTouch || ![touches containsObject:self.activeTouch]) return;
    [self appendSamplesForTouch:self.activeTouch event:event];
    [self setNeedsDisplay];
}

- (void)appendSamplesForTouch:(UITouch *)touch event:(UIEvent *)event {
    for (UITouch *sample in [event coalescedTouchesForTouch:touch]) {
        [self.activeStroke appendPoint:[sample preciseLocationInView:self]];
    }
    // Include the event's final position even if the coalesced array is empty/incomplete.
    [self.activeStroke appendPoint:[touch preciseLocationInView:self]];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.activeTouch || ![touches containsObject:self.activeTouch]) return;
    [self appendSamplesForTouch:self.activeTouch event:event];
    [self commitActiveStroke];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.activeTouch || ![touches containsObject:self.activeTouch]) return;
    // Keep ink already drawn when a system gesture interrupts, without a synthetic tail.
    [self commitActiveStroke];
}

- (void)commitActiveStroke {
    if (self.activeStroke) {
        [self.strokes addObject:self.activeStroke];
        CLCanvasUndoAction *action = [[CLCanvasUndoAction alloc] init];
        action.strokes = @[self.activeStroke];
        [self.undoHistory addObject:action];
    }
    self.activeStroke = nil;
    self.activeTouch = nil;
    [self setNeedsDisplay];
    [self updateAccessibilityState];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window && self.activeStroke) [self commitActiveStroke];
}

- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    if (hidden && self.activeStroke) [self commitActiveStroke];
}

#pragma mark - Drawing and history

- (void)drawRect:(CGRect)rect {
    [UIColor.systemBlueColor setStroke];
    [UIColor.systemBlueColor setFill];
    for (CLCanvasStroke *stroke in self.strokes) [stroke draw];
    [self.activeStroke draw];
}

- (void)clearCanvas {
    [self commitActiveStroke];
    if (self.strokes.count == 0) return;
    CLCanvasUndoAction *action = [[CLCanvasUndoAction alloc] init];
    action.restoresClear = YES;
    action.strokes = [self.strokes copy];
    [self.undoHistory addObject:action];
    [self.strokes removeAllObjects];
    [self setNeedsDisplay];
    [self updateAccessibilityState];
}

- (void)undoLastStroke {
    [self commitActiveStroke];
    CLCanvasUndoAction *action = self.undoHistory.lastObject;
    if (!action) return;
    if (action.restoresClear) {
        [self.strokes setArray:action.strokes];
    } else {
        [self.strokes removeObjectIdenticalTo:action.strokes.firstObject];
    }
    [self.undoHistory removeLastObject];
    [self setNeedsDisplay];
    [self updateAccessibilityState];
}

- (void)resetCanvas {
    self.activeTouch = nil;
    self.activeStroke = nil;
    [self.strokes removeAllObjects];
    [self.undoHistory removeAllObjects];
    [self setNeedsDisplay];
    [self updateAccessibilityState];
}

- (void)cancelActiveStroke {
    self.activeTouch = nil;
    self.activeStroke = nil;
    [self setNeedsDisplay];
    [self updateAccessibilityState];
}

#pragma mark - Accessibility

- (void)updateAccessibilityState {
    if (self.strokeCount > 0) {
        self.accessibilityValue = [NSString stringWithFormat:@"已畫 %lu 筆", (unsigned long)self.strokeCount];
    } else {
        self.accessibilityValue = self.canUndo ? @"空白，可以復原剛才清除的草稿" : @"空白";
    }
    NSMutableArray<UIAccessibilityCustomAction *> *actions = [NSMutableArray array];
    if (self.canUndo) {
        [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"復原上一個動作"
                                                                    target:self selector:@selector(accessibilityUndo)]];
    }
    if (self.strokeCount > 0) {
        [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"清除草稿"
                                                                    target:self selector:@selector(accessibilityClear)]];
    }
    self.accessibilityCustomActions = actions;
}

- (BOOL)accessibilityUndo {
    if (!self.canUndo) return NO;
    [self undoLastStroke];
    return YES;
}

- (BOOL)accessibilityClear {
    if (self.strokeCount == 0) return NO;
    [self clearCanvas];
    return YES;
}

@end

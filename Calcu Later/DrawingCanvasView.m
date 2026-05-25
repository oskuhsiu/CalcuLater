#import "DrawingCanvasView.h"

@interface DrawingCanvasView ()
@property (nonatomic, strong) NSMutableArray<UIBezierPath *> *paths;
/// 以 touch 指標當 key 紀錄正在進行的筆劃。UITouch 在整個觸控週期內是穩定的，安全使用。
@property (nonatomic, strong) NSMutableDictionary<NSValue *, UIBezierPath *> *activePaths;
@end

@implementation DrawingCanvasView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.paths = [NSMutableArray array];
    self.activePaths = [NSMutableDictionary dictionary];
    self.multipleTouchEnabled = YES;
}

#pragma mark - Touch handling

- (NSValue *)keyForTouch:(UITouch *)touch {
    return [NSValue valueWithNonretainedObject:touch];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint point = [touch preciseLocationInView:self];
        UIBezierPath *path = [UIBezierPath bezierPath];
        path.lineWidth = 3.0;
        path.lineCapStyle = kCGLineCapRound;
        path.lineJoinStyle = kCGLineJoinRound;
        [path moveToPoint:point];
        self.activePaths[[self keyForTouch:touch]] = path;
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        UIBezierPath *path = self.activePaths[[self keyForTouch:touch]];
        if (!path) continue;

        // coalesced touches 提供同一個 frame 中累積的中間取樣點，畫出來更順。
        NSArray<UITouch *> *coalesced = [event coalescedTouchesForTouch:touch];
        if (coalesced.count > 0) {
            for (UITouch *t in coalesced) {
                [path addLineToPoint:[t preciseLocationInView:self]];
            }
        } else {
            [path addLineToPoint:[touch preciseLocationInView:self]];
        }
    }
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self finalizeTouches:touches];
}

/// 把 cancelled 當成 ended：留住已畫的部份，不讓系統 gesture 搶 touch 時清掉筆劃。
/// 誤觸頂多多一條短筆觸，主筆劃不會斷。
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self finalizeTouches:touches];
}

- (void)finalizeTouches:(NSSet<UITouch *> *)touches {
    for (UITouch *touch in touches) {
        NSValue *key = [self keyForTouch:touch];
        UIBezierPath *path = self.activePaths[key];
        if (path) {
            [self.paths addObject:path];
            [self.activePaths removeObjectForKey:key];
        }
    }
    [self setNeedsDisplay];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    [[UIColor systemBlueColor] setStroke];
    for (UIBezierPath *path in self.paths) {
        [path stroke];
    }
    for (UIBezierPath *path in self.activePaths.allValues) {
        [path stroke];
    }
}

#pragma mark - Public

- (void)clearCanvas {
    [self.paths removeAllObjects];
    [self.activePaths removeAllObjects];
    [self setNeedsDisplay];
}

- (void)undoLastStroke {
    if (self.paths.count > 0) {
        [self.paths removeLastObject];
        [self setNeedsDisplay];
    }
}

@end

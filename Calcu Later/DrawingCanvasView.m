#import "DrawingCanvasView.h"

@interface DrawingCanvasView ()
@property (nonatomic, strong) NSMutableArray<UIBezierPath *> *paths;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIBezierPath *> *activePaths;
@end

@implementation DrawingCanvasView

- (instancetype)initWithFrame:(CGRect)frame {
	 self = [super initWithFrame:frame];
	 if (self) {
		  self.backgroundColor = [UIColor clearColor];
		  self.paths = [NSMutableArray array];
		  self.activePaths = [NSMutableDictionary dictionary];
		  self.multipleTouchEnabled = YES;
	 }
	 return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	 self = [super initWithCoder:coder];
	 if (self) {
		  self.backgroundColor = [UIColor clearColor];
		  self.paths = [NSMutableArray array];
		  self.activePaths = [NSMutableDictionary dictionary];
		  self.multipleTouchEnabled = YES;
	 }
	 return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
	 for (UITouch *touch in touches) {
		  CGPoint point = [touch locationInView:self];
		  UIBezierPath *path = [UIBezierPath bezierPath];
		  path.lineWidth = 3.0;
		  path.lineCapStyle = kCGLineCapRound;
		  path.lineJoinStyle = kCGLineJoinRound;
		  [path moveToPoint:point];
		  
		  NSNumber *touchKey = [NSNumber numberWithUnsignedInteger:(NSUInteger)touch];
		  self.activePaths[touchKey] = path;
	 }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
	 for (UITouch *touch in touches) {
		  CGPoint point = [touch locationInView:self];
		  NSNumber *touchKey = [NSNumber numberWithUnsignedInteger:(NSUInteger)touch];
		  UIBezierPath *path = self.activePaths[touchKey];
		  
		  if (path) {
				[path addLineToPoint:point];
		  }
	 }
	 [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
	 for (UITouch *touch in touches) {
		  NSNumber *touchKey = [NSNumber numberWithUnsignedInteger:(NSUInteger)touch];
		  UIBezierPath *path = self.activePaths[touchKey];
		  
		  if (path) {
				[self.paths addObject:path];
				[self.activePaths removeObjectForKey:touchKey];
		  }
	 }
	 [self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
	 for (UITouch *touch in touches) {
		  NSNumber *touchKey = [NSNumber numberWithUnsignedInteger:(NSUInteger)touch];
		  [self.activePaths removeObjectForKey:touchKey];
	 }
	 [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
	 [[UIColor systemBlueColor] setStroke];
	 
	 // Draw completed paths
	 for (UIBezierPath *path in self.paths) {
		  [path stroke];
	 }
	 
	 // Draw active paths being drawn
	 for (UIBezierPath *path in self.activePaths.allValues) {
		  [path stroke];
	 }
}

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

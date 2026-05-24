#import "AnimatedHintView.h"
#import "ViewController.h"
#import "ArithmeticProblem.h"

@interface AnimatedHintView ()
@property (nonatomic, strong) UILabel *hintLabel;
@end

@implementation AnimatedHintView

- (instancetype)initWithFrame:(CGRect)frame {
	 self = [super initWithFrame:frame];
	 if (self) {
		  self.backgroundColor = [UIColor clearColor];
		  self.hintLabel = [[UILabel alloc] initWithFrame:self.bounds];
		  self.hintLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightMedium];
		  self.hintLabel.textAlignment = NSTextAlignmentCenter;
		  self.hintLabel.numberOfLines = 0;
		  [self addSubview:self.hintLabel];
	 }
	 return self;
}

- (void)layoutSubviews {
	 [super layoutSubviews];
	 self.hintLabel.frame = self.bounds;
}

- (void)configureWithProblem:(ArithmeticProblem *)problem {
	 // For demo, just show a static animated hint text. You can expand with real animation if needed.
	 if ([problem.operatorSymbol isEqualToString:@"+"]) {
		  self.hintLabel.text = @"動畫提示：分步加法 (可擴充動畫效果)";
	 } else if ([problem.operatorSymbol isEqualToString:@"-"]) {
		  self.hintLabel.text = @"動畫提示：分步減法 (可擴充動畫效果)";
	 } else {
		  self.hintLabel.text = @"";
	 }
}

@end

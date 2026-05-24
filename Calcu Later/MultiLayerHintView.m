#import "MultiLayerHintView.h"
#import "ViewController.h"

@interface MultiLayerHintView ()
@property (nonatomic, strong) UILabel *hintLabel;
@end

@implementation MultiLayerHintView

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

// Add the method that ViewController expects
- (void)displayHintForProblem:(ArithmeticProblem *)problem {
	 [self configureWithProblem:problem];
}

- (void)configureWithProblem:(ArithmeticProblem *)problem {
	 if ([problem.operatorSymbol isEqualToString:@"+"]) {
		  NSInteger n1 = problem.number1;
		  NSInteger n2 = problem.number2;
		  NSInteger n1t = (n1/10)*10, n1o = n1%10;
		  NSInteger n2t = (n2/10)*10, n2o = n2%10;
		  NSString *hint = [NSString stringWithFormat:@"%ld + %ld = %ld\n%ld + %ld = %ld\n合計：%ld + %ld = %ld", n1t, n2t, n1t+n2t, n1o, n2o, n1o+n2o, n1t+n2t, n1o+n2o, problem.answer];
		  self.hintLabel.text = hint;
	 } else if ([problem.operatorSymbol isEqualToString:@"-"]) {
		  NSInteger n1 = problem.number1;
		  NSInteger n2 = problem.number2;
		  NSInteger n1t = (n1/10)*10, n1o = n1%10;
		  NSInteger n2t = (n2/10)*10, n2o = n2%10;
		  NSString *hint = [NSString stringWithFormat:@"%ld - %ld = %ld\n%ld - %ld = %ld\n合計：%ld + %ld = %ld", n1t, n2t, n1t-n2t, n1o, n2o, n1o-n2o, n1t-n2t, n1o-n2o, problem.answer];
		  self.hintLabel.text = hint;
	 } else {
		  self.hintLabel.text = @"";
	 }
}

@end

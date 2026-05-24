#import "StandardHintView.h"
#import "ArithmeticProblem.h"
#import "ViewController.h"

@interface StandardHintView ()
@property (nonatomic, strong) UILabel *hintLabel;
@end

@implementation StandardHintView

- (instancetype)initWithFrame:(CGRect)frame {
	 self = [super initWithFrame:frame];
	 if (self) {
		  self.backgroundColor = [UIColor clearColor];
		  self.hintLabel = [[UILabel alloc] initWithFrame:self.bounds];
		  self.hintLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightMedium];
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
	 if ([problem.operatorSymbol isEqualToString:@"+"]) {
		  NSInteger n1 = problem.number1;
		  NSInteger n2 = problem.number2;
		  NSInteger ones = (n1 % 10) + (n2 % 10);
		  NSInteger tens = (n1 / 10) + (n2 / 10) + (ones / 10);
//        NSString *hint = [NSString stringWithFormat:@"個位：%ld + %ld = %ld\n十位：%ld + %ld %@ %ld = %ld", (long)(n1%10), (long)(n2%10), (long)(n1%10+n2%10), (long)(n1/10), (long)(n2/10), (ones>=10?@"+1":""), (ones>=10?1:0), (long)tens];
//        self.hintLabel.text = hint;
	 } else if ([problem.operatorSymbol isEqualToString:@"-"]) {
		  NSInteger n1 = problem.number1;
		  NSInteger n2 = problem.number2;
		  NSInteger ones = (n1 % 10) - (n2 % 10);
		  NSInteger tens = (n1 / 10) - (n2 / 10) + (ones < 0 ? -1 : 0);
//        NSString *hint = [NSString stringWithFormat:@"個位：%ld - %ld = %ld\n十位：%ld - %ld %@ %ld = %ld", (long)(n1%10), (long)(n2%10), (long)(n1%10-n2%10), (long)(n1/10), (long)(n2/10), (ones<0?@"-1":""), (ones<0?1:0), (long)tens];
//        self.hintLabel.text = hint;
	 } else {
		  self.hintLabel.text = @"";
	 }
}

- (void)displayDivisionHint:(ArithmeticProblem *)problem {
	 NSString *hintText = [NSString stringWithFormat:@"%ld ÷ %ld = %ld",
								 (long)problem.number1, (long)problem.number2, (long)problem.answer];
	 self.hintLabel.text = hintText;
	 self.hintLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
}

@end

#import <UIKit/UIKit.h>
@class ArithmeticProblem;

@interface AnimatedHintView : UIView
- (void)configureWithProblem:(ArithmeticProblem *)problem;
@end

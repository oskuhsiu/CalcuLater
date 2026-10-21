#import <UIKit/UIKit.h>
@class ArithmeticProblem, WordProblem, Lesson;

NS_ASSUME_NONNULL_BEGIN
/// A full-height, scrollable teaching surface. It never advances the exercise.
@interface ExplanationViewController : UIViewController
- (instancetype)initWithArithmeticProblem:(ArithmeticProblem *)problem
                              wordProblem:(nullable WordProblem *)wordProblem
                                   lesson:(nullable Lesson *)lesson;
@end
NS_ASSUME_NONNULL_END

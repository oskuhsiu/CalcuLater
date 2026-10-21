#import <UIKit/UIKit.h>
@class ArithmeticProblem;
@class WordProblem;

NS_ASSUME_NONNULL_BEGIN
/// Learner-controlled quantities: build equal groups, share equally or make groups of.
/// Story meaning is never inferred from its arithmetic bridge. Predictions are ungraded.
@interface GroupingTeachingViewController : UIViewController
@property (nonatomic, copy, nullable) void (^returnToQuestion)(void);
+ (BOOL)supportsProblem:(ArithmeticProblem *)problem wordProblem:(nullable WordProblem *)wordProblem;
- (instancetype)initWithProblem:(ArithmeticProblem *)problem wordProblem:(nullable WordProblem *)wordProblem;
@end
NS_ASSUME_NONNULL_END

#import <UIKit/UIKit.h>
@class ArithmeticProblem;
@class WordProblem;

NS_ASSUME_NONNULL_BEGIN
/// A learner-controlled walkthrough. Prediction is optional and never scored;
/// every transformation can be inspected, replayed or stepped back.
@interface VerticalTeachingViewController : UIViewController
/// Optional return action when opened inside another help sheet.
@property (nonatomic, copy, nullable) void (^returnToQuestion)(void);
+ (BOOL)supportsProblem:(ArithmeticProblem *)problem wordProblem:(nullable WordProblem *)wordProblem;
- (instancetype)initWithProblem:(ArithmeticProblem *)problem wordProblem:(nullable WordProblem *)wordProblem;
@end
NS_ASSUME_NONNULL_END

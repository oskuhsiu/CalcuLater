#import <UIKit/UIKit.h>
@class ArithmeticProblem;
@class WordProblem;

NS_ASSUME_NONNULL_BEGIN
/// Optional, child-paced numeric place-value teaching. No practice submission,
/// score, mastery update, automatic advance or background playback.
@interface MultiplicativeTeachingViewController : UIViewController
@property (nonatomic, copy, nullable) void (^returnToQuestion)(void);
+ (BOOL)supportsProblem:(ArithmeticProblem *)problem wordProblem:(nullable WordProblem *)wordProblem;
- (instancetype)initWithProblem:(ArithmeticProblem *)problem wordProblem:(nullable WordProblem *)wordProblem;
@end
NS_ASSUME_NONNULL_END

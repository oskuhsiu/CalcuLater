#import "PracticeViewController.h"
NS_ASSUME_NONNULL_BEGIN
/// Five real-life stories per round, with a deliberate review/next step.
@interface WordProblemViewController : PracticeViewController
- (instancetype)initWithGrade:(NSInteger)grade;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END

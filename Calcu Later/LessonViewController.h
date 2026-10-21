#import "PracticeViewController.h"
@class Lesson;
NS_ASSUME_NONNULL_BEGIN
/// A balanced lesson deck with demonstration, practice, review and a summary.
@interface LessonViewController : PracticeViewController
- (instancetype)initWithLesson:(Lesson *)lesson;
@end
NS_ASSUME_NONNULL_END

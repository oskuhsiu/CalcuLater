#import <UIKit/UIKit.h>
@class Lesson;

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, PracticeKind) {
    PracticeKindDrill,
    PracticeKindLesson,
    PracticeKindStory,
};

/// Shared native exercise surface: finite sessions, deliberate progression,
/// readable feedback, a separate teaching sheet, and a real scratchpad layout.
@interface PracticeViewController : UIViewController
- (instancetype)initWithKind:(PracticeKind)kind lesson:(nullable Lesson *)lesson grade:(NSInteger)grade;
@end
NS_ASSUME_NONNULL_END

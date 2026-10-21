#import "LessonViewController.h"
@implementation LessonViewController
- (instancetype)initWithLesson:(Lesson *)lesson {
    return [super initWithKind:PracticeKindLesson lesson:lesson grade:1];
}
@end

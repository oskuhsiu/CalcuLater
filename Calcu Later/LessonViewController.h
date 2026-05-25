#import <UIKit/UIKit.h>

@class Lesson;

NS_ASSUME_NONNULL_BEGIN

/// 一節課的執行畫面：題目 + 選擇題 + 進度條 + 結束星星。
@interface LessonViewController : UIViewController

- (instancetype)initWithLesson:(Lesson *)lesson;

@end

NS_ASSUME_NONNULL_END

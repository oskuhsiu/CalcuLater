#import <UIKit/UIKit.h>

@class Lesson, LessonIntroView;

NS_ASSUME_NONNULL_BEGIN

@protocol LessonIntroViewDelegate <NSObject>
- (void)lessonIntroDidFinish:(LessonIntroView *)introView;
@end

/// L1-L5 開課前的「先看示範」分步動畫。
/// 顯示一個典型題目的概念視覺化，做完後使用者按「開始練習」進入答題；可隨時跳過或再看一次。
@interface LessonIntroView : UIView

@property (nonatomic, weak, nullable) id<LessonIntroViewDelegate> delegate;

- (instancetype)initWithLesson:(Lesson *)lesson;

/// 開始播放（在 addSubview 之後呼叫）。
- (void)play;

@end

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 持久化每課的「最佳答對數 / 是否完成」。
/// 用 NSUserDefaults 存，key = "lesson.<id>.stars" (0..3) 與 "lesson.<id>.completed"。
@interface LessonProgressStore : NSObject

@property (class, nonatomic, readonly) LessonProgressStore *sharedInstance;

- (NSInteger)starsForLessonID:(NSString *)lessonID;          // 0..3
- (BOOL)isCompletedLessonID:(NSString *)lessonID;
- (void)recordLessonID:(NSString *)lessonID correct:(NSInteger)correct outOf:(NSInteger)total;

@end

NS_ASSUME_NONNULL_END

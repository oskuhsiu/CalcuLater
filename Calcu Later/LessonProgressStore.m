#import "LessonProgressStore.h"

@implementation LessonProgressStore

+ (LessonProgressStore *)sharedInstance {
    static LessonProgressStore *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[LessonProgressStore alloc] init]; });
    return s;
}

- (NSInteger)starsForLessonID:(NSString *)lessonID {
    NSString *key = [NSString stringWithFormat:@"lesson.%@.stars", lessonID];
    return [[NSUserDefaults standardUserDefaults] integerForKey:key];
}

- (BOOL)isCompletedLessonID:(NSString *)lessonID {
    NSString *key = [NSString stringWithFormat:@"lesson.%@.completed", lessonID];
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (void)recordLessonID:(NSString *)lessonID correct:(NSInteger)correct outOf:(NSInteger)total {
    if (total <= 0) return;
    double rate = (double)correct / (double)total;
    NSInteger stars = 0;
    if (rate >= 0.95) stars = 3;
    else if (rate >= 0.75) stars = 2;
    else if (rate >= 0.50) stars = 1;

    NSString *starsKey = [NSString stringWithFormat:@"lesson.%@.stars", lessonID];
    NSString *doneKey = [NSString stringWithFormat:@"lesson.%@.completed", lessonID];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSInteger prev = [d integerForKey:starsKey];
    if (stars > prev) [d setInteger:stars forKey:starsKey];
    if (stars >= 1) [d setBool:YES forKey:doneKey];
    [d synchronize];
}

@end

#import <Foundation/Foundation.h>

@class ArithmeticProblem;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LessonKind) {
    LessonKindAddSimple,        // L1, L2: 10 以內加法
    LessonKindSubSimple,        // L3: 10 以內減法
    LessonKindMakeTen,          // L4: 合十法
    LessonKindBreakTen,         // L5: 破十法
    LessonKindMultiplication,   // 九九乘法（單一段）
};

/// 一課的設定資料。
@interface Lesson : NSObject

@property (nonatomic, copy, readonly) NSString *lessonID;     // 唯一 ID（持久化用）
@property (nonatomic, copy, readonly) NSString *title;        // e.g. "5 以內加法"
@property (nonatomic, copy, readonly) NSString *iconName;     // SF Symbol 名
@property (nonatomic, assign, readonly) LessonKind kind;
@property (nonatomic, assign, readonly) NSInteger questionCount;
@property (nonatomic, assign, readonly) NSInteger multiplicationFactor;  // 九九的「N 段」（1..9），其他 0

- (instancetype)initWithID:(NSString *)lessonID
                     title:(NSString *)title
                  iconName:(NSString *)iconName
                      kind:(LessonKind)kind
             questionCount:(NSInteger)count
       multiplicationFactor:(NSInteger)factor;

/// 產生一題該課的題目。
- (ArithmeticProblem *)generateProblem;

@end


/// 內建 lessons 集合。
@interface LessonCatalog : NSObject
+ (NSArray<Lesson *> *)addSubLessons;   // L1-L5
+ (NSArray<Lesson *> *)multiplicationLessons;  // 9 段
@end

NS_ASSUME_NONNULL_END

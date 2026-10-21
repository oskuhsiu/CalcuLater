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

/// 產生一整堂課的練習，題數為 questionCount。
/// 內建課程不重複出題；乘法課將 1…9 的每個乘數各練一次。
/// 加減課平均輪流抽取不同總數／被減數，避免 +0 或簡單題佔滿整堂課。
/// 重開同一 Lesson 的課程時，第一題不會接著重複上堂最後一題。
- (NSArray<ArithmeticProblem *> *)generateSessionProblems;

/// 相容舊呼叫端：依序取出同一份平衡題組，用完才產生下一份。
- (ArithmeticProblem *)generateProblem;

@end


/// 內建 lessons 集合。
@interface LessonCatalog : NSObject
+ (NSArray<Lesson *> *)addSubLessons;   // L1-L5
+ (NSArray<Lesson *> *)multiplicationLessons;  // 9 段
@end

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>

@class GroupingStoryContext;

NS_ASSUME_NONNULL_BEGIN

/// 一個應用題的「題型模板」。
///
/// 模板用 `{a}` `{b}` 佔位符代入題目文字。儲存的 minA/maxA、minB/maxB、約束條件
/// 由 `WordProblemGenerator` 在生成時遵守，確保產出有效題目（不出現負數、整除等）。
@interface WordProblemTemplate : NSObject

@property (nonatomic, copy, readonly) NSString *templateID;
@property (nonatomic, assign, readonly) NSInteger grade;          // 1 / 2 / 3
@property (nonatomic, copy, readonly) NSString *operatorSymbol;   // + − × ÷
@property (nonatomic, copy, readonly) NSString *storyPattern;     // 含 {a} {b} 的題目文字
@property (nonatomic, copy, readonly) NSString *unit;             // 答案單位

/// Explicit catalog producer metadata; nil for unclassified/custom or text-only templates.
@property (nonatomic, copy, readonly, nullable) GroupingStoryContext *groupingContext;
/// Only {a}, {b}, {c} are rendered; no answer/remainder placeholders are supported.
@property (nonatomic, copy, readonly, nullable) NSString *strategyPattern;

@property (nonatomic, assign, readonly) NSInteger minA;
@property (nonatomic, assign, readonly) NSInteger maxA;
@property (nonatomic, assign, readonly) NSInteger minB;
@property (nonatomic, assign, readonly) NSInteger maxB;

/// 減法用：是否要求 a ≥ b（避免負數答案）。
@property (nonatomic, assign, readonly) BOOL requireAGreaterEqualB;
/// 除法用：是否要求 a 為 b 的整數倍（避免有餘數）。
@property (nonatomic, assign, readonly) BOOL requireDivisible;
/// 「未知數在前」(missing addend)：模板的 operator 必為 "−"，但故事是加法情境。
/// Generator 仍以 number1−number2=answer 計算；ViewController 把等式渲染為「? + b = a」。
@property (nonatomic, assign, readonly) BOOL missingAddend;
/// 「未知數在中」(missing subtrahend)：模板的 operator 必為 "−"，等式渲染為「a − ? = b」。
@property (nonatomic, assign, readonly) BOOL missingSubtrahend;
/// 「被減數未知」(missing minuend)：模板的 operator 必為 "+"（內部加法），等式渲染為「? − number1 = number2」。
@property (nonatomic, assign, readonly) BOOL missingMinuend;
/// 除法用：是否要求 a 不為 b 的整數倍（產生餘數）。與 requireDivisible 互斥。
@property (nonatomic, assign, readonly) BOOL requireRemainder;

/// 二步驟用：第二個運算子（nil = 單步驟）。目前只支援 + / −（同優先級）。
@property (nonatomic, copy, readonly, nullable) NSString *operator2;
/// 二步驟用：c 值範圍（pattern 內以 {c} 表示）。
@property (nonatomic, assign, readonly) NSInteger minC;
@property (nonatomic, assign, readonly) NSInteger maxC;

/// 分數題：YES 時 minA/maxA 為分子範圍、minB/maxB 為分母範圍。
/// generator 會強制 a < b（真分數）；故事 pattern 內可用 {a} 代分子、{b} 代分母。
@property (nonatomic, assign, readonly) BOOL isFraction;

- (instancetype)initWithID:(NSString *)templateID
                     grade:(NSInteger)grade
                  operator:(NSString *)operatorSymbol
                   pattern:(NSString *)storyPattern
                      unit:(NSString *)unit
                      minA:(NSInteger)minA
                      maxA:(NSInteger)maxA
                      minB:(NSInteger)minB
                      maxB:(NSInteger)maxB
        requireAGreaterEqB:(BOOL)requireAGE
          requireDivisible:(BOOL)requireDiv
             missingAddend:(BOOL)missingAddend
         missingSubtrahend:(BOOL)missingSubtrahend
            missingMinuend:(BOOL)missingMinuend
          requireRemainder:(BOOL)requireRemainder
                 operator2:(nullable NSString *)operator2
                      minC:(NSInteger)minC
                      maxC:(NSInteger)maxC
                isFraction:(BOOL)isFraction;

/// Explicit teaching metadata; the original initializer always defaults it to nil.
- (instancetype)initWithID:(NSString *)templateID
                     grade:(NSInteger)grade
                  operator:(NSString *)operatorSymbol
                   pattern:(NSString *)storyPattern
                      unit:(NSString *)unit
                      minA:(NSInteger)minA
                      maxA:(NSInteger)maxA
                      minB:(NSInteger)minB
                      maxB:(NSInteger)maxB
        requireAGreaterEqB:(BOOL)requireAGE
          requireDivisible:(BOOL)requireDiv
             missingAddend:(BOOL)missingAddend
         missingSubtrahend:(BOOL)missingSubtrahend
            missingMinuend:(BOOL)missingMinuend
          requireRemainder:(BOOL)requireRemainder
                 operator2:(nullable NSString *)operator2
                      minC:(NSInteger)minC
                      maxC:(NSInteger)maxC
                isFraction:(BOOL)isFraction
           groupingContext:(nullable GroupingStoryContext *)groupingContext
           strategyPattern:(nullable NSString *)strategyPattern;

@end


@interface WordProblemCatalog : NSObject

/// 對應年級的所有題型模板（grade 1/2/3）。傳入 < 1 或 > 3 自動 clamp。
+ (NSArray<WordProblemTemplate *> *)templatesForGrade:(NSInteger)grade;

/// 全部模板（debug / 統計用）。
+ (NSArray<WordProblemTemplate *> *)allTemplates;

@end

NS_ASSUME_NONNULL_END

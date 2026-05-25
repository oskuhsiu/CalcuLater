#import <Foundation/Foundation.h>

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

@property (nonatomic, assign, readonly) NSInteger minA;
@property (nonatomic, assign, readonly) NSInteger maxA;
@property (nonatomic, assign, readonly) NSInteger minB;
@property (nonatomic, assign, readonly) NSInteger maxB;

/// 減法用：是否要求 a ≥ b（避免負數答案）。
@property (nonatomic, assign, readonly) BOOL requireAGreaterEqualB;
/// 除法用：是否要求 a 為 b 的整數倍（避免有餘數）。
@property (nonatomic, assign, readonly) BOOL requireDivisible;

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
          requireDivisible:(BOOL)requireDiv;

@end


@interface WordProblemCatalog : NSObject

/// 對應年級的所有題型模板（grade 1/2/3）。傳入 < 1 或 > 3 自動 clamp。
+ (NSArray<WordProblemTemplate *> *)templatesForGrade:(NSInteger)grade;

/// 全部模板（debug / 統計用）。
+ (NSArray<WordProblemTemplate *> *)allTemplates;

@end

NS_ASSUME_NONNULL_END

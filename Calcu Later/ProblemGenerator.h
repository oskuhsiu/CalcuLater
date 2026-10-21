#import <Foundation/Foundation.h>

@class ArithmeticProblem;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DrillTier) {
    DrillTierD1 = 1,   // 所有運算元與答案 ≤ 20
    DrillTierD2 = 2,   // 所有運算元與答案 ≤ 100
    DrillTierD3 = 3,   // 三位數練習；所有運算元與答案 ≤ 999
    DrillTierMixed = 4 // 隨機 D1-D3
};

/// Drill（刷題）區的題目產生器。依 SettingsManager 的 tier + 運算開關產生題目。
@interface ProblemGenerator : NSObject

/// 單一來源的範圍文案，供設定選單與練習頁使用。無效 tier 與出題一樣回退至 D2。
+ (NSString *)titleForTier:(DrillTier)tier;
+ (NSString *)detailForTier:(DrillTier)tier;

/// 各 tier 的上限同時約束運算元與結果；不產生負數，除法一律整除。
/// D1/D2：正整數加減、一位數乘法，以及除數為 2…9 的除法。
/// D3：兩個三位數相加減、三位數乘一位數、三位數除以一位數。
+ (ArithmeticProblem *)generateForTier:(DrillTier)tier
                       allowAddition:(BOOL)allowAdd
                    allowSubtraction:(BOOL)allowSub
                  allowMultiplication:(BOOL)allowMul
                        allowDivision:(BOOL)allowDiv;

@end

NS_ASSUME_NONNULL_END

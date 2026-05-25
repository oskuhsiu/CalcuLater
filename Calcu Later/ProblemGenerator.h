#import <Foundation/Foundation.h>

@class ArithmeticProblem;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DrillTier) {
    DrillTierD1 = 1,   // 20 以內加減 (含進退位)
    DrillTierD2 = 2,   // 100 以內加減 (進退位)
    DrillTierD3 = 3,   // 三位數以上
    DrillTierMixed = 4 // 隨機 D1-D3
};

/// Drill（刷題）區的題目產生器。依 SettingsManager 的 tier + 運算開關產生題目。
@interface ProblemGenerator : NSObject

+ (ArithmeticProblem *)generateForTier:(DrillTier)tier
                       allowAddition:(BOOL)allowAdd
                    allowSubtraction:(BOOL)allowSub
                  allowMultiplication:(BOOL)allowMul
                        allowDivision:(BOOL)allowDiv;

@end

NS_ASSUME_NONNULL_END

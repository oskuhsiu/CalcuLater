#import <Foundation/Foundation.h>

@class ArithmeticProblem;

NS_ASSUME_NONNULL_BEGIN

/// 為一道題目產生 3 個有教學意義的錯誤選項（distractor）。
///
/// 策略（§2.4）：
///   - ±1、±10 的近似計算誤差
///   - 對運算符做反（5+3 → 含 5-3=2）
///   - 個位/十位顛倒（23 ↔ 32）
///   - 多進位 / 少進位（28+7 應為 35，distractor 含 25 / 45）
///   - 篩去 < 0 或重複的答案
///
/// 同題目連續呼叫不會產生穩定相同的順序（用 arc4random 洗牌）。
@interface DistractorGenerator : NSObject

/// 回傳剛好 3 個 distractor。若內建策略產生不夠 3 個（極端題目如 0+0），會用 ±2、±5 補。
+ (NSArray<NSNumber *> *)distractorsForProblem:(ArithmeticProblem *)problem;

/// 回傳 4 個選項陣列（含正解，隨機洗牌後）。
+ (NSArray<NSNumber *> *)choicesForProblem:(ArithmeticProblem *)problem;

@end

NS_ASSUME_NONNULL_END

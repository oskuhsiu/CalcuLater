#import <UIKit/UIKit.h>

@class ArithmeticProblem;

NS_ASSUME_NONNULL_BEGIN

/// 加法直式提示 view（兒童風格）。
///
/// 排版（從上到下）：
///   row 0  : 進位帽（小圈圈圈住的進位數字）
///   row 1  : 被加數 (number1)
///   row 2  : 加號 + 加數 (number2)
///   row 3  : 分隔線
///   row 4  : 答案
///
/// 字體：SF Rounded monospaced，數字 ≥ 56pt。
/// 配色：奶油白底、深棕字、進位帽用糖果色循環。
@interface AdditionHintView : UIView

- (void)configureWithProblem:(ArithmeticProblem *)problem;

@end

NS_ASSUME_NONNULL_END

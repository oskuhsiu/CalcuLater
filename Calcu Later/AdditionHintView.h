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

/// 直式 cell（digits / carry caps / separator / strike / arrow layer）的承載 view。
/// 公開給 AnimatedHintView 做逐位 reveal 動畫使用；外部不應 mutate。
@property (nonatomic, strong, readonly) UIView *gridContainer;

/// 嘗試以這道題配置加法直式顯示。
/// 回傳 YES 表示成功配置（problem 是有效的加法題、運算元非負）。
/// 回傳 NO 表示這道題本 view 不適用（非加法、含負數等）；caller 應該不要把這個 view 顯示出來。
- (BOOL)configureWithProblem:(ArithmeticProblem *)problem;

@end

NS_ASSUME_NONNULL_END

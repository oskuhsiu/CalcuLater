#import <UIKit/UIKit.h>

@class ArithmeticProblem;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MakeBreakTenMode) {
    MakeBreakTenModeMakeTen,   // 合十法（進位加）
    MakeBreakTenModeBreakTen,  // 破十法（退位減）
};

/// 合十法 / 破十法視覺化（§2.3）。
/// 範例輸出（合十）：
///   8 + 5
///   8 + (2 + 3)
///   (8 + 2) + 3
///   10 + 3 = 13
/// 用 UILabel stack 表現分步，逐步彈出（spring fade-in）。
@interface MakeBreakTenHintView : UIView

- (instancetype)initWithFrame:(CGRect)frame mode:(MakeBreakTenMode)mode;
- (BOOL)configureWithProblem:(ArithmeticProblem *)problem;

@end

NS_ASSUME_NONNULL_END

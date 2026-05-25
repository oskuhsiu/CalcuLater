#import <UIKit/UIKit.h>

@class ArithmeticProblem;

NS_ASSUME_NONNULL_BEGIN

/// 減法直式提示 view（兒童風格）。
///
/// 排版（從上到下）：
///   row 0  : afterBorrowing（向左鄰借進來的兩位數，例如 "13"）
///   row 1  : afterLending（借出給右鄰後變成的值，若同時也借入則加柔刪除線）
///   row 2  : 原 number1 數字（被改動的位數加柔刪除線 + alpha）
///   row 3  : `-` + number2
///   row 4  : 分隔線
///   row 5  : answer
///
/// 顏色：依 BorrowInfo 的 borrowing / lendingColorIndex 取 §1.1 六色循環。
/// 刪除線：CAShapeLayer 圓角末端的柔軟線條（非 NSStrikethroughStyle）。
/// 借出箭頭：lender → 右鄰之間以小箭頭連接。
@interface SubtractionHintView : UIView

/// 直式 cell（digits / strike / arrow CAShapeLayer）的承載 view。
/// 公開給 AnimatedHintView 做逐位 reveal 動畫使用；外部不應 mutate。
@property (nonatomic, strong, readonly) UIView *gridContainer;

/// 嘗試以這道題配置減法直式顯示。
/// 回傳 YES 表示成功配置（problem 是有效的減法題、運算元非負、number1 >= number2）。
/// 回傳 NO 表示這道題本 view 不適用；caller 應該不要把這個 view 顯示出來。
- (BOOL)configureWithProblem:(ArithmeticProblem *)problem;

@end

NS_ASSUME_NONNULL_END

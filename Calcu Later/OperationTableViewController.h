#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OperationTableKind) {
    OperationTableKindAddition = 0,   // 加法表
    OperationTableKindSubtraction,    // 減法表
};

/// 加法表 / 減法表：分段列出算式（仿九九乘法表）。
/// 每段可「一次唸整段（一串）」，個別算式也可點按單獨朗讀。
///
/// 分段方式：
///   - 加法表：第 a 段＝「a 的加法」，列出 a+1 … a+9（和 2~18）。
///   - 減法表：第 a 段＝「減 a」（減數固定 a），列出 (a+1)−a … (a+9)−a
///     （被減數 2~18、差 1~9、無負數）。此為加法表的逆運算。
@interface OperationTableViewController : UIViewController
- (instancetype)initWithKind:(OperationTableKind)kind;
@end

NS_ASSUME_NONNULL_END

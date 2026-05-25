#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ArithmeticProblem : NSObject

@property (nonatomic, assign) NSInteger number1;
@property (nonatomic, assign) NSInteger number2;
@property (nonatomic, strong) NSString *operatorSymbol;
@property (nonatomic, assign) NSInteger answer;

/// 額外強制塞進 MCQ 干擾選項的「典型錯誤值」。0 表示無。
/// 用途：
///   - 二步驟題：intermediate（孩子最常見的「忘了第二步」錯誤）
///   - missingAddend / missingSubtrahend：a+b（小孩用錯方向「直接相加」的錯誤）
///   - missingMinuend：a-b 的絕對值（同樣是「用錯方向」）
///   - 有餘除法：餘數本身（孩子常把餘數誤當成商）
@property (nonatomic, assign) NSInteger auxiliaryDistractor;

/// 標示這是「多步驟題的對映 AP」(n1 op1 n2 != answer)。YES 時 DistractorGenerator
/// 的 op-specific 分支（n1-n2、n2-n1、noCarry 等）會被跳過，因為那些假設都建立在
/// 「n1 op n2 = answer 是單步驟」的前提上，對二步驟而言只會產生雜訊干擾選項。
@property (nonatomic, assign) BOOL isMultiStep;

- (instancetype)initWithNumber1:(NSInteger)number1
                        number2:(NSInteger)number2
                       operator:(NSString *)operatorSymbol
                         answer:(NSInteger)answer;

@end

NS_ASSUME_NONNULL_END
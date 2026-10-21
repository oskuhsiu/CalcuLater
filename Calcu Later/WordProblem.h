#import <Foundation/Foundation.h>

@class ArithmeticProblem;
@class GroupingStoryContext;

NS_ASSUME_NONNULL_BEGIN

/// 一道生成好的應用題：題目文字 + 對應的算式 / 答案。
/// 算式部分可橋接到既有 hint / MCQ 系統（DistractorGenerator、AnimatedHintView 等）。
@interface WordProblem : NSObject

@property (nonatomic, copy, readonly) NSString *storyText;       // 完整題目文字（含問句）
@property (nonatomic, copy, readonly) NSString *templateID;      // 模板識別，便於除錯 / 統計
@property (nonatomic, assign, readonly) NSInteger grade;         // 1 / 2 / 3
@property (nonatomic, assign, readonly) NSInteger number1;
@property (nonatomic, assign, readonly) NSInteger number2;
@property (nonatomic, copy, readonly) NSString *operatorSymbol;  // + − × ÷
@property (nonatomic, assign, readonly) NSInteger answer;
@property (nonatomic, copy, readonly) NSString *unit;            // 答案單位（顆 / 個 / 元 / 人…），UI 顯示用

/// Reviewed producer metadata only. Legacy/custom initializers leave these nil.
@property (nonatomic, copy, readonly, nullable) GroupingStoryContext *groupingContext;
/// Rendered from a catalog strategy pattern using only the given operands, not the answer.
@property (nonatomic, copy, readonly, nullable) NSString *strategyText;

/// 「未知數在前」(missing addend) 題型：等式渲染為「? + number2 = number1」，
/// 內部仍以 number1 − number2 = answer 計算，因此 DistractorGenerator / AnimatedHintView
/// 不需特殊處理（hint 會以「想想 number1 − number2」演示找出缺漏的加數）。
@property (nonatomic, assign, readonly) BOOL missingAddend;

/// 「未知數在中」(missing subtrahend) 題型：等式渲染為「number1 − ? = number2」，
/// 內部仍以 number1 − number2 = answer 計算。
/// missingAddend 與 missingSubtrahend 互斥。
@property (nonatomic, assign, readonly) BOOL missingSubtrahend;

/// 「未知數在前的減法」(missing minuend) 題型：等式渲染為「? − number1 = number2」，
/// 內部以加法計算 (op="+", answer = number1 + number2)，因 ? = subtrahend + remainder。
/// 與其他 missing* 三者互斥。
@property (nonatomic, assign, readonly) BOOL missingMinuend;

/// 有餘數除法的餘數；整除題為 0。等式渲染為「a ÷ b = q 餘 r」（r > 0 時）。
/// 題目只問商（answer = q）；完整解釋仍需保留餘數與 a = q × b + r 的驗算。
@property (nonatomic, assign, readonly) NSInteger remainder;

/// 二步驟混合題：number3 與 operator2。operator2 為 nil 表示單步驟。
/// 等式渲染為「number1 op1 number2 op2 number3 = ?」，目前僅支援同優先級運算
/// （a±b±c，避免「先乘除後加減」帶來的順序混淆，對應 G2/G3 課綱）。
@property (nonatomic, assign, readonly) NSInteger number3;
@property (nonatomic, copy, readonly, nullable) NSString *operator2;
/// 第一步的中間結果，供 textHint 解釋用（單步驟題為 0）。
@property (nonatomic, assign, readonly) NSInteger intermediate;

/// 分數答案題（識別題）：操作子無意義；以 answerNumerator / answerDenominator 表達答案。
/// MCQ 顯示「n/d」字串；equation 面板顯示「答案：?」/「答案：n/d」。
/// 對應 108 課綱 G3 N-3-9「分數初步」識別題。
@property (nonatomic, assign, readonly) BOOL isFractionAnswer;
@property (nonatomic, assign, readonly) NSInteger answerNumerator;
@property (nonatomic, assign, readonly) NSInteger answerDenominator;

- (instancetype)initWithStory:(NSString *)storyText
                   templateID:(NSString *)templateID
                        grade:(NSInteger)grade
                      number1:(NSInteger)number1
                      number2:(NSInteger)number2
                     operator:(NSString *)operatorSymbol
                       answer:(NSInteger)answer
                         unit:(NSString *)unit
                missingAddend:(BOOL)missingAddend
            missingSubtrahend:(BOOL)missingSubtrahend
               missingMinuend:(BOOL)missingMinuend
                    remainder:(NSInteger)remainder
                      number3:(NSInteger)number3
                    operator2:(nullable NSString *)operator2
                 intermediate:(NSInteger)intermediate
             isFractionAnswer:(BOOL)isFractionAnswer
              answerNumerator:(NSInteger)answerNumerator
            answerDenominator:(NSInteger)answerDenominator;

/// Explicit teaching metadata; the original full initializer remains source-compatible.
- (instancetype)initWithStory:(NSString *)storyText
                   templateID:(NSString *)templateID
                        grade:(NSInteger)grade
                      number1:(NSInteger)number1
                      number2:(NSInteger)number2
                     operator:(NSString *)operatorSymbol
                       answer:(NSInteger)answer
                         unit:(NSString *)unit
                missingAddend:(BOOL)missingAddend
            missingSubtrahend:(BOOL)missingSubtrahend
               missingMinuend:(BOOL)missingMinuend
                    remainder:(NSInteger)remainder
                      number3:(NSInteger)number3
                    operator2:(nullable NSString *)operator2
                 intermediate:(NSInteger)intermediate
             isFractionAnswer:(BOOL)isFractionAnswer
              answerNumerator:(NSInteger)answerNumerator
            answerDenominator:(NSInteger)answerDenominator
              groupingContext:(nullable GroupingStoryContext *)groupingContext
                 strategyText:(nullable NSString *)strategyText;

/// 舊版 init：不帶 missingAddend / remainder，等同於 missingAddend=NO、remainder=0。
- (instancetype)initWithStory:(NSString *)storyText
                   templateID:(NSString *)templateID
                        grade:(NSInteger)grade
                      number1:(NSInteger)number1
                      number2:(NSInteger)number2
                     operator:(NSString *)operatorSymbol
                       answer:(NSInteger)answer
                         unit:(NSString *)unit;

/// A strategy only: never reveals the computed answer, quotient, remainder or intermediate result.
- (NSString *)strategyHintText;

/// 完整的解題說明，會揭示答案，並保留特殊題型的語意與答案單位。
/// 有餘除法以 q × b + r = a 驗算，unit 只標在商的答案旁，不冒充餘數單位。
/// 可用於文字提示／答後解釋；若只想給策略而不揭答，請使用獨立的策略提示。
- (NSString *)workedExplanationText;

/// 題目面板的算式；reveal=NO 保留未知數，YES 才顯示答案。
/// 反推題的單位獨立放在「答案」句，不誤標到等號右邊的已知數。
/// 有餘除法顯示純數字 q 餘 r；商的答案單位另見 workedExplanationText。
- (NSString *)equationTextRevealingAnswer:(BOOL)reveal;

/// 轉成 ArithmeticProblem，供 DistractorGenerator 使用；answer 仍是商或最終答案。
/// 此橋接不攜帶餘數、單位與分數，特殊題型的提示請使用 workedExplanationText。
- (ArithmeticProblem *)toArithmeticProblem;

@end

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>

@class ArithmeticProblem;

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

- (instancetype)initWithStory:(NSString *)storyText
                   templateID:(NSString *)templateID
                        grade:(NSInteger)grade
                      number1:(NSInteger)number1
                      number2:(NSInteger)number2
                     operator:(NSString *)operatorSymbol
                       answer:(NSInteger)answer
                         unit:(NSString *)unit;

/// 轉成 ArithmeticProblem，便於餵給 DistractorGenerator / AnimatedHintView。
- (ArithmeticProblem *)toArithmeticProblem;

@end

NS_ASSUME_NONNULL_END

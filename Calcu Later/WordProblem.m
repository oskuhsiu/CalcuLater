#import "WordProblem.h"
#import "ArithmeticProblem.h"

@implementation WordProblem

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
                    operator2:(NSString *)operator2
                 intermediate:(NSInteger)intermediate
             isFractionAnswer:(BOOL)isFractionAnswer
              answerNumerator:(NSInteger)answerNumerator
            answerDenominator:(NSInteger)answerDenominator {
    self = [super init];
    if (self) {
        _storyText = [storyText copy];
        _templateID = [templateID copy];
        _grade = grade;
        _number1 = number1;
        _number2 = number2;
        _operatorSymbol = [operatorSymbol copy];
        _answer = answer;
        _unit = [unit copy] ?: @"";
        _missingAddend = missingAddend;
        _missingSubtrahend = missingSubtrahend;
        _missingMinuend = missingMinuend;
        _remainder = remainder;
        _number3 = number3;
        _operator2 = [operator2 copy];
        _intermediate = intermediate;
        _isFractionAnswer = isFractionAnswer;
        _answerNumerator = answerNumerator;
        _answerDenominator = answerDenominator;
    }
    return self;
}

- (instancetype)initWithStory:(NSString *)storyText
                   templateID:(NSString *)templateID
                        grade:(NSInteger)grade
                      number1:(NSInteger)number1
                      number2:(NSInteger)number2
                     operator:(NSString *)operatorSymbol
                       answer:(NSInteger)answer
                         unit:(NSString *)unit {
    return [self initWithStory:storyText templateID:templateID grade:grade
                       number1:number1 number2:number2
                      operator:operatorSymbol answer:answer unit:unit
                 missingAddend:NO missingSubtrahend:NO missingMinuend:NO
                     remainder:0
                       number3:0 operator2:nil intermediate:0
              isFractionAnswer:NO answerNumerator:0 answerDenominator:0];
}

- (ArithmeticProblem *)toArithmeticProblem {
    ArithmeticProblem *p = [[ArithmeticProblem alloc] initWithNumber1:self.number1
                                                              number2:self.number2
                                                             operator:self.operatorSymbol
                                                               answer:self.answer];
    // 為各種特殊題型塞入「最典型的孩子錯誤」當強制干擾項，
    // 確保 MCQ 的 4 個選項裡至少有一個是「教科書級的典型錯誤」。
    if (self.operator2 && self.intermediate > 0 && self.intermediate != self.answer) {
        // 二步驟：「只算第一步、忘了第二步」
        p.auxiliaryDistractor = self.intermediate;
        // 標示這是多步驟題的 AP，DistractorGenerator 不要套單步驟的 n1-n2 / noCarry 等
        // 假設 — 那些對「100+50-30=120」這種兩步驟題只會跑出 50 這種 n2 本身當干擾，
        // 既不是孩子會犯的錯也沒教學意義。
        p.isMultiStep = YES;
    } else if (self.missingAddend || self.missingSubtrahend) {
        // ?+b=a 或 a-?=b（內部 op="-"，answer=a-b）：典型錯誤「方向用反」→ a+b
        NSInteger wrong = self.number1 + self.number2;
        if (wrong > 0 && wrong != self.answer) {
            p.auxiliaryDistractor = wrong;
        }
    } else if (self.missingMinuend) {
        // ?-a=b（內部 op="+"，answer=a+b）：典型錯誤「方向用反」→ |a-b|
        NSInteger wrong = labs(self.number1 - self.number2);
        if (wrong > 0 && wrong != self.answer) {
            p.auxiliaryDistractor = wrong;
        }
    } else if (self.remainder > 0) {
        // 有餘除法 a÷b=q⋯r：典型錯誤「把餘數寫成答案」→ r
        if (self.remainder != self.answer) {
            p.auxiliaryDistractor = self.remainder;
        }
    }
    return p;
}

@end

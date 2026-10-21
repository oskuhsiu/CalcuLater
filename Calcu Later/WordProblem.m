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

- (NSString *)displayOperator:(NSString *)symbol {
    return [symbol isEqualToString:@"-"] ? @"−" : symbol;
}

- (NSString *)answerTextWithUnit {
    return self.unit.length > 0
        ? [NSString stringWithFormat:@"%ld %@", (long)self.answer, self.unit]
        : [NSString stringWithFormat:@"%ld", (long)self.answer];
}

- (NSString *)equationTextRevealingAnswer:(BOOL)reveal {
    if (self.isFractionAnswer) {
        return reveal ? [NSString stringWithFormat:@"答案：%ld/%ld",
                         (long)self.answerNumerator, (long)self.answerDenominator] : @"答案：?";
    }
    NSString *op = [self displayOperator:self.operatorSymbol];
    NSString *answer = reveal ? [self answerTextWithUnit] : @"?";
    if (self.operator2) {
        return [NSString stringWithFormat:@"%ld %@ %ld %@ %ld = %@",
                (long)self.number1, op, (long)self.number2,
                [self displayOperator:self.operator2], (long)self.number3, answer];
    }

    NSString *unknown = reveal ? [NSString stringWithFormat:@"%ld", (long)self.answer] : @"?";
    NSString *inverseEquation = nil;
    if (self.missingAddend) {
        inverseEquation = [NSString stringWithFormat:@"%@ + %ld = %ld",
                           unknown, (long)self.number2, (long)self.number1];
    } else if (self.missingSubtrahend) {
        inverseEquation = [NSString stringWithFormat:@"%ld − %@ = %ld",
                           (long)self.number1, unknown, (long)self.number2];
    } else if (self.missingMinuend) {
        inverseEquation = [NSString stringWithFormat:@"%@ − %ld = %ld",
                           unknown, (long)self.number1, (long)self.number2];
    }
    if (inverseEquation) {
        return reveal ? [NSString stringWithFormat:@"%@\n答案：%@", inverseEquation, answer] : inverseEquation;
    }
    if (reveal && self.remainder > 0 && [self.operatorSymbol isEqualToString:@"÷"]) {
        return [NSString stringWithFormat:@"%ld ÷ %ld = %ld 餘 %ld",
                (long)self.number1, (long)self.number2, (long)self.answer, (long)self.remainder];
    }
    return [NSString stringWithFormat:@"%ld %@ %ld = %@",
            (long)self.number1, op, (long)self.number2, answer];
}

- (NSString *)workedExplanationText {
    if (self.isFractionAnswer) {
        return [NSString stringWithFormat:
                @"把整個平均分成 %ld 等份\n取其中 %ld 份，就是 %ld/%ld",
                (long)self.answerDenominator, (long)self.answerNumerator,
                (long)self.answerNumerator, (long)self.answerDenominator];
    }

    NSString *answerText = [self answerTextWithUnit];
    NSString *answerLine = [@"答案：" stringByAppendingString:answerText];
    NSString *op = [self displayOperator:self.operatorSymbol];

    if (self.operator2) {
        return [NSString stringWithFormat:
                @"第一步：%ld %@ %ld = %ld\n第二步：%ld %@ %ld = %ld\n%@",
                (long)self.number1, op, (long)self.number2, (long)self.intermediate,
                (long)self.intermediate, [self displayOperator:self.operator2],
                (long)self.number3, (long)self.answer, answerLine];
    }
    if (self.missingAddend) {
        return [NSString stringWithFormat:
                @"總數減去已知的部分：%ld − %ld = %ld\n驗算：%ld + %ld = %ld\n%@",
                (long)self.number1, (long)self.number2, (long)self.answer,
                (long)self.answer, (long)self.number2, (long)self.number1, answerLine];
    }
    if (self.missingSubtrahend) {
        return [NSString stringWithFormat:
                @"原來的數量減去剩下的：%ld − %ld = %ld\n驗算：%ld − %ld = %ld\n%@",
                (long)self.number1, (long)self.number2, (long)self.answer,
                (long)self.number1, (long)self.answer, (long)self.number2, answerLine];
    }
    if (self.missingMinuend) {
        return [NSString stringWithFormat:
                @"拿走的和剩下的合起來：%ld + %ld = %ld\n驗算：%ld − %ld = %ld\n%@",
                (long)self.number1, (long)self.number2, (long)self.answer,
                (long)self.answer, (long)self.number1, (long)self.number2, answerLine];
    }
    if ([self.operatorSymbol isEqualToString:@"÷"]) {
        if (self.remainder > 0) {
            // 包、盤、隊等是商的單位，不等於剩下的糖果、球員等單位。
            // 運算列保持純數字，只在本題所問的商旁標註 unit，絕不猜餘數單位。
            return [NSString stringWithFormat:
                    @"%ld ÷ %ld = %ld 餘 %ld\n驗算：%ld × %ld + %ld = %ld\n這題只答商：%@",
                    (long)self.number1, (long)self.number2, (long)self.answer, (long)self.remainder,
                    (long)self.answer, (long)self.number2, (long)self.remainder, (long)self.number1,
                    answerText];
        }
        return [NSString stringWithFormat:
                @"%ld ÷ %ld = %ld\n驗算：%ld × %ld = %ld\n%@",
                (long)self.number1, (long)self.number2, (long)self.answer,
                (long)self.answer, (long)self.number2, (long)self.number1, answerLine];
    }
    if ([self.operatorSymbol isEqualToString:@"×"] && self.number2 >= 1 && self.number2 <= 6) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        for (NSInteger i = 0; i < self.number2; i++) {
            [parts addObject:[NSString stringWithFormat:@"%ld", (long)self.number1]];
        }
        return [NSString stringWithFormat:@"%ld × %ld\n= %@\n%@",
                (long)self.number1, (long)self.number2,
                [parts componentsJoinedByString:@" + "], answerLine];
    }
    return [NSString stringWithFormat:@"%ld %@ %ld = %ld\n%@",
            (long)self.number1, op, (long)self.number2, (long)self.answer, answerLine];
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

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
                         unit:(NSString *)unit {
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
    }
    return self;
}

- (ArithmeticProblem *)toArithmeticProblem {
    return [[ArithmeticProblem alloc] initWithNumber1:self.number1
                                              number2:self.number2
                                             operator:self.operatorSymbol
                                               answer:self.answer];
}

@end

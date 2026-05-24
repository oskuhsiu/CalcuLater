#import "ArithmeticProblem.h"

@implementation ArithmeticProblem

- (instancetype)initWithNumber1:(NSInteger)number1 
                        number2:(NSInteger)number2 
                       operator:(NSString *)operatorSymbol 
                         answer:(NSInteger)answer {
    self = [super init];
    if (self) {
        _number1 = number1;
        _number2 = number2;
        _operatorSymbol = operatorSymbol;
        _answer = answer;
    }
    return self;
}

@end
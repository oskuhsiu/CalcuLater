#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ArithmeticProblem : NSObject

@property (nonatomic, assign) NSInteger number1;
@property (nonatomic, assign) NSInteger number2;
@property (nonatomic, strong) NSString *operatorSymbol;
@property (nonatomic, assign) NSInteger answer;

- (instancetype)initWithNumber1:(NSInteger)number1 
                        number2:(NSInteger)number2 
                       operator:(NSString *)operatorSymbol 
                         answer:(NSInteger)answer;

@end

NS_ASSUME_NONNULL_END
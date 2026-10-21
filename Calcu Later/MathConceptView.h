#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Native, countable teaching diagrams for small +/−, multiplication, division,
/// and identifying a fraction of one whole. Story-specific units belong outside
/// this view. Intended for a scrollable explanation sheet, normally 340pt high.
/// Use sizeThatFits: at the sheet's actual width to accommodate larger text.
@interface MathConceptView : UIView

/// Multiplication: number1 in each group, number2 groups.
/// Division: answer full groups of number2, then remainder leftovers.
/// +/− use one dot per object and are supported only within 20.
/// Returns NO and clears stale content for unsupported or inconsistent input.
- (BOOL)configureWithNumber1:(NSInteger)number1
                    number2:(NSInteger)number2
                   operator:(NSString *)operatorSymbol
                     answer:(NSInteger)answer
                  remainder:(NSInteger)remainder;

/// Uses integer numerator/denominator, not a rounded decimal answer.
/// Supports 0 <= numerator <= denominator. Small denominators use equal segments;
/// large denominators use an explicitly labeled number representation.
- (BOOL)configureWithNumerator:(NSInteger)numerator denominator:(NSInteger)denominator;

@end

NS_ASSUME_NONNULL_END

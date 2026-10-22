#import <UIKit/UIKit.h>
#import "MultiplicativeTeachingAction.h"

NS_ASSUME_NONNULL_BEGIN
/// Static written work from one exact snapshot. It never receives a problem's
/// validation answer, an action, a prediction, or a future sequence.
@interface MultiplicativeWrittenWorkView : UIView
@property (nonatomic, strong, readonly, nullable) MultiplicativeTeachingActionSnapshot *snapshot;
@property (nonatomic, assign, readonly) CGFloat minimumReadableWidth;
@property (nonatomic, copy, readonly) NSArray<UILabel *> *answerCellLabels;
/// Three fixed real-place cell centers, also used by every visible work row.
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *columnCenters;
- (void)configureWithNumber1:(NSInteger)number1
                   number2:(NSInteger)number2
                 operation:(MultiplicativeTeachingOperation)operation
        operandStartColumn:(NSInteger)operandStartColumn
                  snapshot:(MultiplicativeTeachingActionSnapshot *)snapshot;
/// Presentation-only emphasis on a currently selected WriteDigit column. No
/// digit or row is created; every emphasized label already belongs to snapshot.
- (void)emphasizeWrittenColumn:(NSInteger)column;
- (CGRect)writtenRelationRectForColumn:(NSInteger)column;
- (CGRect)latestWorkRowRectForColumn:(NSInteger)column;
- (CGRect)latestWorkCaptionRectForColumn:(NSInteger)column;
- (CGSize)sizeThatFits:(CGSize)size;
@end
NS_ASSUME_NONNULL_END

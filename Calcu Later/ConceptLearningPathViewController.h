#import <UIKit/UIKit.h>
@class ConceptLearningPath;
NS_ASSUME_NONNULL_BEGIN
/// Unscored, child-paced questions that open existing visual teaching on demand.
@interface ConceptLearningPathViewController : UIViewController
- (instancetype)initWithPath:(ConceptLearningPath *)path;
@end
NS_ASSUME_NONNULL_END

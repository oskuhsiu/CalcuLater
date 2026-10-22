#import <Foundation/Foundation.h>
@class ArithmeticProblem, WordProblem;
NS_ASSUME_NONNULL_BEGIN
/// A curated, unanswered question. Mutable arithmetic never escapes by reference.
@interface ConceptLearningExample : NSObject
@property (nonatomic, copy, readonly) NSString *questionText;
@property (nonatomic, copy, readonly) NSString *focusText;
@property (nonatomic, copy, readonly) NSString *equationText;
/// Every read returns a fresh arithmetic snapshot, including bridge flags.
@property (nonatomic, strong, readonly) ArithmeticProblem *problem;
/// Complete immutable story, including explicit grouping roles and remainder units.
@property (nonatomic, strong, readonly, nullable) WordProblem *wordProblem;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
/// Three exploration stages, not a scored lesson, completion record or mastery claim.
@interface ConceptLearningPath : NSObject
@property (nonatomic, copy, readonly) NSString *pathID;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *summaryText;
@property (nonatomic, copy, readonly) NSString *iconName;
@property (nonatomic, strong, readonly) ConceptLearningExample *firstExample;
@property (nonatomic, strong, readonly) ConceptLearningExample *relatedExample;
/// Deliberate variations, not random practice or unrestricted unsupported inputs.
@property (nonatomic, copy, readonly) NSArray<ConceptLearningExample *> *explorationExamples;
+ (NSArray<ConceptLearningPath *> *)allPaths;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>
#import "MultiplicativeTeachingAction.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MTPPresentationPhase) {
    MTPPresentationPhaseActionSelection,
    MTPPresentationPhaseSourcePreparation,
    MTPPresentationPhaseSourceInspection
};
typedef NS_ENUM(NSInteger, MTPPresentationEndpoint) {
    MTPPresentationEndpointBefore,
    MTPPresentationEndpointAfter
};

/// Identity for one optional, anchored question. A new attempt never accepts an
/// earlier input, feedback or speech callback, even at an identical snapshot.
@interface MTPPreparationKey : NSObject
@property (nonatomic, copy, readonly) NSString *sessionID;
@property (nonatomic, assign, readonly) NSInteger predictSourceIndex;
@property (nonatomic, assign, readonly) NSInteger workSourceIndex;
@property (nonatomic, strong, readonly) MultiplicativeTeachingActionSnapshot *anchor;
@property (nonatomic, copy, readonly) NSString *attemptID;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// Immutable presentation selection, not another arithmetic model. Preparation
/// retains no action, scene, expected answer or future written metadata.
@interface MultiplicativeTeachingPresentation : NSObject
@property (nonatomic, assign, readonly) MTPPresentationPhase phase;
@property (nonatomic, copy, readonly) NSString *sessionID;
@property (nonatomic, copy, readonly) NSString *selectionID;
@property (nonatomic, assign, readonly) NSInteger sourceStepIndex;
@property (nonatomic, assign, readonly) NSInteger actionIndex; // Absolute, or NSNotFound.
@property (nonatomic, assign, readonly) MTPPresentationEndpoint endpoint;
@property (nonatomic, strong, readonly) MultiplicativeTeachingActionSnapshot *snapshot;
@property (nonatomic, strong, readonly, nullable) MultiplicativeTeachingAction *action;
@property (nonatomic, strong, readonly, nullable) MTPPreparationKey *preparationKey;
@property (nonatomic, assign, readonly) NSInteger activeColumn;
@property (nonatomic, assign, readonly, getter=isReview) BOOL review;
@property (nonatomic, copy, readonly) NSString *prompt;
@property (nonatomic, strong, readonly, nullable) MultiplicativeTeachingPresentation *returnSelection;

+ (nullable instancetype)actionInPlan:(MultiplicativeTeachingActionPlan *)plan
                          sessionID:(NSString *)sessionID
                              index:(NSInteger)index
                           endpoint:(MTPPresentationEndpoint)endpoint;
+ (nullable instancetype)preparationInPlan:(MultiplicativeTeachingActionPlan *)plan
                               sessionID:(NSString *)sessionID
                      predictSourceIndex:(NSInteger)predictSourceIndex
                                  review:(BOOL)review
                         returnSelection:(nullable MultiplicativeTeachingPresentation *)returnSelection;
+ (nullable instancetype)inspectionInPlan:(MultiplicativeTeachingActionPlan *)plan
                               sessionID:(NSString *)sessionID
                         sourceStepIndex:(NSInteger)sourceStepIndex
                                endpoint:(MTPPresentationEndpoint)endpoint
                         returnSelection:(nullable MultiplicativeTeachingPresentation *)returnSelection;
/// Same action visit, immutable canonical endpoint update after the board settles.
- (instancetype)presentationByUpdatingEndpoint:(MTPPresentationEndpoint)endpoint;
- (BOOL)acceptsPreparationKey:(nullable MTPPreparationKey *)key;
/// Parse only. No answer is consulted. Empty and malformed text remain optional.
+ (nullable NSNumber *)proposalFromText:(NSString *)text validationMessage:(NSString * _Nullable * _Nullable)message;
/// Called only after explicit valid submission. All numbers are either given,
/// already owned at the anchor, or explicitly conditional on the child's guess.
- (NSString *)feedbackForProposal:(NSInteger)proposal
                 matchesExpected:(BOOL)matchesExpected
                    givenNumber1:(NSInteger)number1
                    givenNumber2:(NSInteger)number2;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END

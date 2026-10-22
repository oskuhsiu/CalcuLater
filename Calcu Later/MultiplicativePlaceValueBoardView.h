#import <UIKit/UIKit.h>
#import "MultiplicativeTeachingAction.h"

NS_ASSUME_NONNULL_BEGIN
@class MultiplicativePlaceValueScene;

typedef NS_ENUM(NSInteger, MTPPlaceValueEndpoint) {
    MTPPlaceValueEndpointBefore,
    MTPPlaceValueEndpointAfter
};
typedef NS_ENUM(NSInteger, MTPPlaceValuePlaybackState) {
    MTPPlaceValuePlaybackStateEmpty,
    MTPPlaceValuePlaybackStateStatic,
    MTPPlaceValuePlaybackStateRunning,
    MTPPlaceValuePlaybackStateCompleted,
    MTPPlaceValuePlaybackStateStationary,
    MTPPlaceValuePlaybackStateReducedMotion,
    MTPPlaceValuePlaybackStateInsufficientSpace,
    MTPPlaceValuePlaybackStateInterrupted,
    MTPPlaceValuePlaybackStateInvalidScene
};
typedef NS_ENUM(NSInteger, MTPPlaceValueInterruptionReason) {
    MTPPlaceValueInterruptionReasonNone,
    MTPPlaceValueInterruptionReasonCancelled,
    MTPPlaceValueInterruptionReasonVisibility,
    MTPPlaceValueInterruptionReasonBackground,
    MTPPlaceValueInterruptionReasonDetached,
    MTPPlaceValueInterruptionReasonLayoutChanged,
    MTPPlaceValueInterruptionReasonMotionChanged
};

/// Fixed-scale base-ten material. The parent owns scrolling, navigation, given
/// arithmetic notation, prediction controls and any written-work view.
@interface MultiplicativePlaceValueBoardView : UIView
@property (nonatomic, strong, readonly, nullable) MultiplicativeTeachingAction *action;
@property (nonatomic, strong, readonly, nullable) MultiplicativeTeachingActionSnapshot *snapshot;
@property (nonatomic, strong, readonly, nullable) MultiplicativePlaceValueScene *scene;
@property (nonatomic, copy, readonly) NSString *sessionID;
@property (nonatomic, copy, readonly, nullable) NSString *selectionID;
@property (nonatomic, assign, readonly) MTPPlaceValueEndpoint endpoint;
@property (nonatomic, assign, readonly) MTPPlaceValuePlaybackState playbackState;
@property (nonatomic, assign, readonly) MTPPlaceValueInterruptionReason interruptionReason;
@property (nonatomic, assign, readonly) NSUInteger playbackGeneration;
@property (nonatomic, assign, readonly) NSUInteger layoutRevision;
@property (nonatomic, assign, readonly) BOOL displayingFullSnapshot;
/// Complete action paint including every phase's measured labels and swept units.
/// CGRectNull in snapshot-only mode. This is not a visibility certificate.
@property (nonatomic, assign, readonly) CGRect requiredActionRect;
@property (nonatomic, copy, readonly) NSString *statusExplanation;
@property (nonatomic, copy, readonly) NSString *spokenDescription;
/// Caller-supplied viewport is in board coordinates. Actual window, safe area,
/// every ancestor clip and known covering views are independently checked.
@property (nonatomic, copy, nullable) void (^playbackStateDidChange)(MTPPlaceValuePlaybackState state);

/// Static focus only. Does not start playback. Session distinguishes reused unit
/// IDs in another plan; selection distinguishes revisits within the same plan.
- (void)configureWithAction:(MultiplicativeTeachingAction *)action
                 sessionID:(NSString *)sessionID
               selectionID:(NSString *)selectionID
                  endpoint:(MTPPlaceValueEndpoint)endpoint;
/// Neutral current-state overview. Retains NO action or action scene. Safe for
/// Predict, Observe and direct source-result inspection. No future sequence needed.
- (void)configureWithSnapshot:(MultiplicativeTeachingActionSnapshot *)snapshot
                   sessionID:(NSString *)sessionID;
/// Every explicit play/replay creates a new before-origin transaction. Returns
/// Running only if admitted; stationary/recovery states never claim completion.
- (MTPPlaceValuePlaybackState)playInVisibleRect:(CGRect)visibleRect;
- (void)showBeforeState;
- (void)showAfterState;
- (void)cancelPlaybackWithReason:(MTPPlaceValueInterruptionReason)reason;
/// Required after parent scrolling/occlusion changes; playback also checks each tick.
- (void)recheckVisibility;
/// Focus measurement, independent of the current static-recovery overview size.
- (CGSize)requiredActionSizeThatFits:(CGSize)size;
/// Full overview/recovery may be tall. Parent scrolls without shrinking the glyphs.
- (CGSize)sizeThatFits:(CGSize)size;
@end
NS_ASSUME_NONNULL_END

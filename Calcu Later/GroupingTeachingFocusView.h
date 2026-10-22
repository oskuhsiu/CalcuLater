#import <UIKit/UIKit.h>
#import "GroupingTeachingAction.h"

NS_ASSUME_NONNULL_BEGIN
/// A bounded source-to-recipient/bag scene. It never advances a lesson/action.
/// The complete overview is a separate view of the exact selected snapshot.
@interface GroupingTeachingFocusView : UIView
@property (nonatomic, strong, readonly, nullable) GroupingTeachingAction *action;
/// settled, before, running, completed, cancelled, reduced-motion, paused-visibility
@property (nonatomic, copy, readonly) NSString *playbackState;
/// Actual currently displayed quantities, without machine-readable lifecycle tags.
@property (nonatomic, copy, readonly) NSString *spokenDescription;
@property (nonatomic, assign, readonly) NSUInteger playbackGeneration;
@property (nonatomic, assign, readonly) CGRect requiredActionRect;
@property (nonatomic, assign, readonly) NSInteger displayedPoolCount;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *displayedGroupCounts;
@property (nonatomic, assign, readonly) NSInteger inFlightCount;
@property (nonatomic, assign, readonly, getter=isShowingBeforeState) BOOL showingBeforeState;
- (void)configureWithAction:(nullable GroupingTeachingAction *)action;
/// Requires the complete causal scene inside both the supplied viewport and the
/// actual window/ancestor clipping bounds. Rechecks visibility on every tick.
/// Visible duration is .28 s lead + .82 s per serial transfer + .24 s tail.
- (BOOL)playInVisibleRect:(CGRect)visibleRect;
- (void)pauseForVisibility;
- (void)showBeforeState;
- (void)showAfterState;
- (void)cancelPlayback;
/// Excludes only optional static notes below the full source/targets/routes.
- (CGSize)requiredActionSizeThatFits:(CGSize)size;
- (CGSize)sizeThatFits:(CGSize)size;
@end
NS_ASSUME_NONNULL_END

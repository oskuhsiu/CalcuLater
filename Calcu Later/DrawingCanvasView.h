#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A free-form scratchpad, not handwriting recognition or answer submission.
@interface DrawingCanvasView : UIView
@property (nonatomic, readonly) NSUInteger strokeCount;
@property (nonatomic, readonly) BOOL canUndo;

/// Clear the drawing as one undoable action.
- (void)clearCanvas;

/// Undo the most recent stroke or restore the last cleared drawing.
- (void)undoLastStroke;

/// Start a new question with a blank canvas and no previous-question undo history.
- (void)resetCanvas;

/// Discard only the unfinished stroke when an intentional parent scroll begins.
/// Completed drawing and undo history are preserved.
- (void)cancelActiveStroke;
@end

NS_ASSUME_NONNULL_END

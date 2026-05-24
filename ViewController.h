#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

// Arithmetic problem display
@property (nonatomic, strong) UILabel *number1Label;
@property (nonatomic, strong) UILabel *operatorLabel;
@property (nonatomic, strong) UILabel *number2Label;
@property (nonatomic, strong) UILabel *answerLabel;

// Drawing canvas
@property (nonatomic, strong) UIView *drawingCanvasView;

// Action buttons
@property (nonatomic, strong) UIButton *newProblemButton;
@property (nonatomic, strong) UIButton *clearUndoButton;
@property (nonatomic, strong) UIButton *hintButton;
@property (nonatomic, strong) UIButton *settingsButton;

// Methods for updating UI and logic
- (void)generateNewProblem;
- (void)cycleHint;
- (void)showSettings;
- (void)clearOrUndoDrawing;

@end

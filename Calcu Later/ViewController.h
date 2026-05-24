//
//  ViewController.h
//  Calcu Later
//
//  Created by darkness on 2025/8/7.
//

#import <UIKit/UIKit.h>
#import "DrawingCanvasView.h"
#import "ArithmeticProblem.h"
#import "SettingsManager.h"
#import "StandardHintView.h"
#import "MultiLayerHintView.h"
#import "AnimatedHintView.h"

typedef NS_ENUM(NSInteger, HintState) {
	 HintStateNone,
	 HintStateShowAnswer,
	 HintStateStandard,
	 HintStateMultiLayer,
	 HintStateAnimatedMultiLayer
};

@interface ViewController : UIViewController

// Remove all IBOutlet declarations and IBAction methods
// All UI will be created programmatically

@end

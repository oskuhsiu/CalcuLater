//
//  ViewController.m
//  Calcu Later
//
//  Created by darkness on 2025/8/7.
//

#import "ViewController.h"
#import "DrawingCanvasView.h"
#import "StandardHintView.h"
#import "MultiLayerHintView.h"
#import "AnimatedHintView.h"
#import "ArithmeticProblem.h"

@interface ViewController ()
@property (nonatomic, strong) UILabel *problemLabel;
@property (nonatomic, strong) UILabel *answerLabel;
@property (nonatomic, strong) UIButton *problemButton;
@property (nonatomic, strong) UIButton *hintButton;
@property (nonatomic, strong) DrawingCanvasView *canvasView;
@property (nonatomic, strong) UIButton *undoButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) StandardHintView *standardHintView;
@property (nonatomic, strong) MultiLayerHintView *multiLayerHintView;
@property (nonatomic, strong) AnimatedHintView *animatedHintView;
@property (nonatomic, strong) ArithmeticProblem *currentProblem;
@property (nonatomic, assign) NSInteger currentHintType;
@end

@implementation ViewController

- (void)viewDidLoad {
	 [super viewDidLoad];
	 [self setupUI];
	 [self generateNewProblem];
}

- (void)setupUI {
	 self.view.backgroundColor = [UIColor systemBackgroundColor];
	 CGFloat width = self.view.bounds.size.width;
	 CGFloat top = 100;
	 self.problemLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, top, width-40, 60)];
	 self.problemLabel.font = [UIFont systemFontOfSize:36 weight:UIFontWeightBold];
	 self.problemLabel.textAlignment = NSTextAlignmentRight;
	 self.problemLabel.numberOfLines = 2;
	 [self.view addSubview:self.problemLabel];
	 self.answerLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, top+70, width-40, 40)];
	 self.answerLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightRegular];
	 self.answerLabel.textAlignment = NSTextAlignmentRight;
	 self.answerLabel.textColor = [UIColor systemGrayColor];
	 [self.view addSubview:self.answerLabel];
	 self.problemButton = [UIButton buttonWithType:UIButtonTypeSystem];
	 self.problemButton.frame = CGRectMake(20, top+130, (width-60)/2, 50);
	 [self.problemButton setTitle:@"新題" forState:UIControlStateNormal];
	 self.problemButton.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightMedium];
	 [self.problemButton addTarget:self action:@selector(newProblemTapped) forControlEvents:UIControlEventTouchUpInside];
	 [self.view addSubview:self.problemButton];
	 self.hintButton = [UIButton buttonWithType:UIButtonTypeSystem];
	 self.hintButton.frame = CGRectMake(40+(width-60)/2, top+130, (width-60)/2, 50);
	 [self.hintButton setTitle:@"提示" forState:UIControlStateNormal];
	 self.hintButton.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightMedium];
	 [self.hintButton addTarget:self action:@selector(hintTapped) forControlEvents:UIControlEventTouchUpInside];
	 [self.view addSubview:self.hintButton];
	 CGFloat canvasTop = top + 200;
	 CGFloat canvasHeight = self.view.bounds.size.height - canvasTop - 120;
	 self.canvasView = [[DrawingCanvasView alloc] initWithFrame:CGRectMake(20, canvasTop, width-40, canvasHeight)];
	 self.canvasView.layer.borderColor = [UIColor systemGray4Color].CGColor;
	 self.canvasView.layer.borderWidth = 2.0;
	 self.canvasView.layer.cornerRadius = 16.0;
	 [self.view addSubview:self.canvasView];
	 self.undoButton = [UIButton buttonWithType:UIButtonTypeSystem];
	 self.undoButton.frame = CGRectMake(20, CGRectGetMaxY(self.canvasView.frame) + 16, (width-60)/2, 50);
	 [self.undoButton setTitle:@"復原" forState:UIControlStateNormal];
	 self.undoButton.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightMedium];
	 [self.undoButton addTarget:self action:@selector(undoTapped) forControlEvents:UIControlEventTouchUpInside];
	 [self.view addSubview:self.undoButton];
	 self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
	 self.clearButton.frame = CGRectMake(40+(width-60)/2, CGRectGetMaxY(self.canvasView.frame) + 16, (width-60)/2, 50);
	 [self.clearButton setTitle:@"清除" forState:UIControlStateNormal];
	 self.clearButton.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightMedium];
	 [self.clearButton addTarget:self action:@selector(clearTapped) forControlEvents:UIControlEventTouchUpInside];
	 [self.view addSubview:self.clearButton];
	 self.standardHintView = [[StandardHintView alloc] initWithFrame:self.canvasView.frame];
	 self.standardHintView.hidden = YES;
	 [self.view addSubview:self.standardHintView];
	 self.multiLayerHintView = [[MultiLayerHintView alloc] initWithFrame:self.canvasView.frame];
	 self.multiLayerHintView.hidden = YES;
	 [self.view addSubview:self.multiLayerHintView];
	 self.animatedHintView = [[AnimatedHintView alloc] initWithFrame:self.canvasView.frame];
	 self.animatedHintView.hidden = YES;
	 [self.view addSubview:self.animatedHintView];
}

- (void)generateNewProblem {
	 // Generate random arithmetic problem
	 NSInteger num1 = arc4random_uniform(20) + 1;
	 NSInteger num2 = arc4random_uniform(20) + 1;
	 NSString *operator = @"+";
	 NSInteger answer = num1 + num2;
	 
	 self.currentProblem = [[ArithmeticProblem alloc] initWithNumber1:num1
																				 number2:num2
																				operator:operator
																				  answer:answer];
	 
	 self.problemLabel.text = [NSString stringWithFormat:@"%ld %@ %ld = ?",
									  (long)num1, operator, (long)num2];
	 self.answerLabel.text = [NSString stringWithFormat:@"= %ld", (long)answer];
	 
	 // Hide all hint views
	 [self hideAllHintViews];
	 self.currentHintType = 0;
}

- (void)newProblemTapped {
	 [self generateNewProblem];
}

- (void)hintTapped {
	 [self cycleHint];
}

- (void)cycleHint {
	 if (!self.currentProblem) return;
	 
	 // Hide all hint views first
	 [self hideAllHintViews];
	 
	 // Cycle through different hint types
	 self.currentHintType = (self.currentHintType + 1) % 4;
	 
	 switch (self.currentHintType) {
		  case 1:
				self.standardHintView.hidden = NO;
				[self.standardHintView configureWithProblem:self.currentProblem];
				break;
		  case 2:
				self.multiLayerHintView.hidden = NO;
				[self.multiLayerHintView configureWithProblem:self.currentProblem];
				break;
		  case 3:
				self.animatedHintView.hidden = NO;
				[self.animatedHintView configureWithProblem:self.currentProblem];
				break;
		  default:
				// No hint (all hidden)
				break;
	 }
}

- (void)hideAllHintViews {
	 self.standardHintView.hidden = YES;
	 self.multiLayerHintView.hidden = YES;
	 self.animatedHintView.hidden = YES;
}

- (void)undoTapped {
	 [self.canvasView undoLastStroke];
}

- (void)clearTapped {
	 [self.canvasView clearCanvas];
}

@end

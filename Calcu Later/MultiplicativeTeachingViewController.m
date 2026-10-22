#import "MultiplicativeTeachingViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "MultiplicativeTeachingPresentation.h"
#import "MultiplicativePlaceValueBoardView.h"
#import "MultiplicativeWrittenWorkView.h"
#import "ChildUIKit.h"
#import "SpeechManager.h"
#import <math.h>

typedef NS_ENUM(NSInteger, MTPViewingMode) { MTPViewingModeAction, MTPViewingModeWritten, MTPViewingModeOverview };
typedef NS_ENUM(NSInteger, MTPFramingResult) { MTPFramingResultAlreadyContained, MTPFramingResultMovedAndContained, MTPFramingResultCannotContain };

/// A display link holds its target; this tiny target holds only a weak-controller
/// block, so an uncommitted explicit request cannot retain the teaching screen.
@interface MTPExplicitPlaybackTick : NSObject
@property (nonatomic, copy) void (^tick)(CADisplayLink *link);
- (void)fire:(CADisplayLink *)link;
@end
@implementation MTPExplicitPlaybackTick
- (void)fire:(CADisplayLink *)link { if (self.tick) self.tick(link); }
@end

@interface MultiplicativeTeachingViewController () <UIScrollViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) MultiplicativeTeachingSequence *sequence;
@property (nonatomic, strong) MultiplicativeTeachingActionPlan *plan;
@property (nonatomic, strong) MultiplicativeTeachingPresentation *presentation;
@property (nonatomic, copy) NSString *sessionID;
@property (nonatomic, assign) NSInteger givenNumber1;
@property (nonatomic, assign) NSInteger givenNumber2;
@property (nonatomic, assign) BOOL supported;
@property (nonatomic, assign) MTPViewingMode viewingMode;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIScrollView *controlsScroll;
@property (nonatomic, strong) UILabel *questionLabel;
@property (nonatomic, strong) UILabel *headingLabel;
@property (nonatomic, strong) UILabel *noticeLabel;
@property (nonatomic, strong) UILabel *writtenNoticeLabel;
@property (nonatomic, strong) MultiplicativePlaceValueBoardView *board;
@property (nonatomic, strong) MultiplicativeWrittenWorkView *written;
@property (nonatomic, strong) UIView *preparationCard;
@property (nonatomic, strong) UILabel *promptLabel;
@property (nonatomic, strong) UILabel *preparationNoteLabel;
@property (nonatomic, strong) UITextField *proposalField;
@property (nonatomic, strong) UIButton *submitProposalButton;
@property (nonatomic, strong) UILabel *feedbackLabel;
@property (nonatomic, strong, nullable) MTPPreparationKey *activePreparationKey;
@property (nonatomic, strong, nullable) NSNumber *submittedProposal;
@property (nonatomic, strong) ChildButton *beforeButton;
@property (nonatomic, strong) ChildButton *afterButton;
@property (nonatomic, strong) ChildButton *resultButton;
@property (nonatomic, strong) ChildButton *previousButton;
@property (nonatomic, strong) ChildButton *replayButton;
@property (nonatomic, strong) ChildButton *nextButton;
@property (nonatomic, strong) ChildButton *writtenButton;
@property (nonatomic, strong) ChildButton *overviewButton;
@property (nonatomic, strong) ChildButton *moreButton;
@property (nonatomic, strong) ChildButton *returnSelectionButton;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *modeOffsets;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *returnContexts;
@property (nonatomic, assign) NSUInteger presentationGeneration;
@property (nonatomic, assign) BOOL changingPresentation;
@property (nonatomic, assign) BOOL preparingPlayback;
@property (nonatomic, assign) BOOL framingContent;
@property (nonatomic, assign) BOOL layingOutContent;
@property (nonatomic, assign) CGSize lastLayoutSize;
@property (nonatomic, assign) CGFloat keyboardTop;
@property (nonatomic, assign) BOOL keyboardDismissalInProgress;
@property (nonatomic, copy, nullable) NSDictionary *pendingKeyboardPlay;
@property (nonatomic, copy, nullable) NSDictionary *pendingPaintPlay;
@property (nonatomic, strong, nullable) CADisplayLink *playbackAdmissionLink;
@property (nonatomic, copy) NSString *lastTextCategory;
@end

@implementation MultiplicativeTeachingViewController
+ (BOOL)supportsProblem:(ArithmeticProblem *)problem wordProblem:(WordProblem *)wordProblem {
    if (wordProblem) return NO;
    MultiplicativeTeachingSequence *sequence = [MultiplicativeTeachingSequence sequenceForArithmeticProblem:problem];
    return sequence.supported && [MultiplicativeTeachingActionPlan planForSequence:sequence].supported;
}
- (instancetype)initWithProblem:(ArithmeticProblem *)problem wordProblem:(WordProblem *)wordProblem {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sessionID = NSUUID.UUID.UUIDString;
        _givenNumber1 = problem.number1; _givenNumber2 = problem.number2;
        // Never bridge an application story into a bare numeric lesson.
        if (!wordProblem) {
            _sequence = [MultiplicativeTeachingSequence sequenceForArithmeticProblem:problem];
            _plan = [MultiplicativeTeachingActionPlan planForSequence:_sequence];
            _supported = _sequence.supported && _plan.supported;
        }
        _modeOffsets = [NSMutableDictionary dictionary]; _returnContexts = [NSMutableDictionary dictionary];
        _keyboardTop = CGFLOAT_MAX;
        _presentation = _supported ? [MultiplicativeTeachingPresentation actionInPlan:_plan sessionID:_sessionID
            index:0 endpoint:MTPPresentationEndpointAfter] : nil;
    }
    return self;
}
- (void)dealloc { [self.playbackAdmissionLink invalidate]; [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (UILabel *)label:(CGFloat)size weight:(UIFontWeight)weight identifier:(NSString *)identifier {
    UILabel *label = [[UILabel alloc] init];
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:size weight:weight] compatibleWithTraitCollection:self.traitCollection];
    label.numberOfLines = 0; label.lineBreakMode = NSLineBreakByWordWrapping;
    label.adjustsFontForContentSizeCategory = YES; label.adjustsFontSizeToFitWidth = NO;
    label.textColor = ChildUI.brownText; label.accessibilityIdentifier = identifier;
    return label;
}
- (ChildButton *)button:(NSString *)title color:(UIColor *)color action:(SEL)action identifier:(NSString *)identifier {
    ChildButton *button = [ChildButton buttonWithTitle:title backgroundColor:color];
    button.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:19 weight:UIFontWeightBold] compatibleWithTraitCollection:self.traitCollection];
    button.titleLabel.numberOfLines = 0; button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.titleLabel.adjustsFontSizeToFitWidth = NO; button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    button.accessibilityIdentifier = identifier;
    if (action) [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (MultiplicativePlaceValueBoardView *)makePlaceValueBoard {
    return [[MultiplicativePlaceValueBoardView alloc] initWithFrame:CGRectZero];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"一起看數量";
    self.view.backgroundColor = ChildUI.creamBackground;
    self.scroll = [[UIScrollView alloc] init]; self.scroll.delegate = self;
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scroll.accessibilityIdentifier = @"multiplicative.content";
    [self.view addSubview:self.scroll];
    self.controlsScroll = [[UIScrollView alloc] init]; self.controlsScroll.delegate = self;
    self.controlsScroll.backgroundColor = ChildUI.creamBackground;
    self.controlsScroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.controlsScroll.accessibilityIdentifier = @"multiplicative.controls";
    [self.view addSubview:self.controlsScroll];
    self.questionLabel = [self label:27 weight:UIFontWeightBold identifier:@"multiplicative.question"];
    self.headingLabel = [self label:18 weight:UIFontWeightSemibold identifier:@"multiplicative.selection"];
    self.headingLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
    self.noticeLabel = [self label:19 weight:UIFontWeightSemibold identifier:@"multiplicative.notice"];
    self.writtenNoticeLabel = [self label:18 weight:UIFontWeightMedium identifier:@"multiplicative.writtenNotice"];
    self.board = [self makePlaceValueBoard];
    self.written = [[MultiplicativeWrittenWorkView alloc] initWithFrame:CGRectZero];
    for (UIView *view in @[self.questionLabel, self.headingLabel, self.noticeLabel, self.writtenNoticeLabel, self.board, self.written])
        [self.scroll addSubview:view];
    self.beforeButton = [self button:@"動作前" color:ChildUI.skyBlue action:@selector(showBefore) identifier:@"multiplicative.before"];
    self.afterButton = [self button:@"動作後" color:ChildUI.skyBlue action:@selector(showAfter) identifier:@"multiplicative.after"];
    self.resultButton = [self button:@"看本步結果" color:ChildUI.lavender action:@selector(inspectSourceResult) identifier:@"multiplicative.sourceResult"];
    self.previousButton = [self button:@"上一步" color:ChildUI.skyBlue action:@selector(previous) identifier:@"multiplicative.previous"];
    self.replayButton = [self button:@"重看" color:ChildUI.eggYolk action:@selector(replay) identifier:@"multiplicative.replay"];
    self.nextButton = [self button:@"下一步" color:ChildUI.mintGreen action:@selector(next) identifier:@"multiplicative.next"];
    self.writtenButton = [self button:@"看直式" color:ChildUI.skyBlue action:@selector(toggleWritten) identifier:@"multiplicative.showWritten"];
    self.overviewButton = [self button:@"看全部" color:ChildUI.skyBlue action:@selector(toggleOverview) identifier:@"multiplicative.showOverview"];
    self.moreButton = [self button:@"更多看法" color:ChildUI.lavender action:NULL identifier:@"multiplicative.more"];
    self.moreButton.showsMenuAsPrimaryAction = YES;
    self.returnSelectionButton = [self button:@"返回剛才的位置" color:ChildUI.eggYolk action:@selector(returnToSavedSelection)
        identifier:@"multiplicative.returnSelection"];
    for (UIButton *button in self.allControlButtons) [self.controlsScroll addSubview:button];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationInterrupted:)
        name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textSizeChanged:)
        name:UIContentSizeCategoryDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(motionChanged:)
        name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardChanged:)
        name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardChanged:)
        name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:)
        name:UIKeyboardDidHideNotification object:nil];
    [self renderPresentation];
}
- (NSArray<UIButton *> *)allControlButtons {
    return @[self.beforeButton, self.afterButton, self.resultButton, self.previousButton, self.replayButton,
             self.nextButton, self.writtenButton, self.overviewButton, self.moreButton, self.returnSelectionButton];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self cancelPlayback:MTPPlaceValueInterruptionReasonDetached];
    [SpeechManager.sharedInstance stop];
}
- (BOOL)isPreparingQuestion { return self.presentation.phase == MTPPresentationPhaseSourcePreparation && self.presentation != nil; }
- (NSString *)placeName { return self.presentation.activeColumn >= 0 && self.presentation.activeColumn < 3
    ? @[@"百位", @"十位", @"個位"][(NSUInteger)self.presentation.activeColumn] : @"這一步"; }
- (void)closePreparation {
    // Invalidate the complete key BEFORE resignation, speech completion or board
    // configuration can synchronously call back into the controller.
    self.activePreparationKey = nil;
    self.preparationCard.accessibilityElementsHidden = YES;
    self.proposalField.delegate = nil;
    [self.proposalField resignFirstResponder];
    self.proposalField.text = @""; self.feedbackLabel.text = @"";
    [self.preparationCard removeFromSuperview];
    self.preparationCard = nil; self.proposalField = nil; self.submitProposalButton = nil;
    self.promptLabel = nil; self.preparationNoteLabel = nil; self.feedbackLabel = nil;
    self.submittedProposal = nil;
    [SpeechManager.sharedInstance stop];
}
- (void)transitionTo:(MultiplicativeTeachingPresentation *)presentation mode:(MTPViewingMode)mode resetScroll:(BOOL)resetScroll {
    if (!presentation) return;
    self.presentationGeneration++;
    self.pendingKeyboardPlay = nil;
    [self.playbackAdmissionLink invalidate]; self.playbackAdmissionLink = nil; self.pendingPaintPlay = nil;
    self.preparingPlayback = NO;
    self.changingPresentation = YES;
    self.board.playbackStateDidChange = nil;
    [self closePreparation];
    [self.board cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonCancelled];
    self.presentation = presentation; self.viewingMode = mode;
    self.noticeLabel.text = nil;
    if (resetScroll) { [self.modeOffsets removeAllObjects]; self.framingContent = YES;
        [self.scroll setContentOffset:CGPointZero animated:NO]; self.framingContent = NO; }
    self.changingPresentation = NO;
    [self renderPresentation];
}
- (void)configureWritten {
    if (!self.presentation) return;
    [self.written configureWithNumber1:self.givenNumber1 number2:self.givenNumber2 operation:self.sequence.operation
        operandStartColumn:self.sequence.operandStartColumn snapshot:self.presentation.snapshot];
    if (self.presentation.phase == MTPPresentationPhaseActionSelection
        && self.presentation.action.sourceStep.kind == MultiplicativeTeachingStepKindWriteDigit)
        [self.written emphasizeWrittenColumn:self.presentation.action.activeColumn];
}
- (void)renderPresentation {
    if (!self.isViewLoaded) return;
    if (!self.supported || !self.presentation) {
        self.questionLabel.text = @"先回到題目看看";
        self.headingLabel.text = @"這一題不適合用這個數量圖。應用題要保留原來的意思，我們回到題目一起想。";
        self.board.hidden = YES; self.written.hidden = YES; self.writtenNoticeLabel.hidden = YES;
        for (UIButton *button in self.allControlButtons) button.hidden = button != self.nextButton;
        [self.nextButton setTitle:@"回到題目" forState:UIControlStateNormal];
        [self.view setNeedsLayout]; return;
    }
    NSString *symbol = self.sequence.operation == MultiplicativeTeachingOperationMultiplication ? @"×" : @"÷";
    self.questionLabel.text = [NSString stringWithFormat:@"%ld %@ %ld = ?", (long)self.givenNumber1, symbol, (long)self.givenNumber2];
    MultiplicativeTeachingPresentation *p = self.presentation;
    if (p.phase == MTPPresentationPhaseSourcePreparation) {
        NSString *verb = self.sequence.operation == MultiplicativeTeachingOperationMultiplication ? @"新增前" : @"分配前";
        self.headingLabel.text = [NSString stringWithFormat:@"%@，%@%@", self.placeName, verb, p.review ? @" · 回看原來的問題" : @""];
        if (![p acceptsPreparationKey:self.activePreparationKey]) [self buildPreparationCard];
    } else if (p.phase == MTPPresentationPhaseSourceInspection) {
        self.headingLabel.text = [NSString stringWithFormat:@"第 %ld 步 · %@", (long)p.sourceStepIndex + 1,
            p.endpoint == MTPPresentationEndpointBefore ? @"整步開始" : @"整步結果"];
        self.noticeLabel.text = p.endpoint == MTPPresentationEndpointBefore
            ? @"這是這一步開始時的完整數量，沒有播放動作。"
            : @"現在直接看這一步的結果，沒有播放中間動作，也沒有跳到下一個寫答案的步驟。";
    } else {
        self.headingLabel.text = [NSString stringWithFormat:@"第 %ld 步 · 第 %ld／%ld 個動作 · %@",
            (long)p.sourceStepIndex + 1, (long)p.action.indexWithinStep + 1, (long)p.action.countWithinStep,
            p.endpoint == MTPPresentationEndpointBefore ? @"動作前" : @"動作後"];
    }
    BOOL snapshotOnly = p.phase != MTPPresentationPhaseActionSelection || self.viewingMode == MTPViewingModeOverview;
    self.changingPresentation = YES;
    if (snapshotOnly) {
        self.board.playbackStateDidChange = nil;
        [self.board configureWithSnapshot:p.snapshot sessionID:self.sessionID];
    } else {
        [self bindBoardCallback];
        [self.board configureWithAction:p.action sessionID:self.sessionID selectionID:p.selectionID
            endpoint:p.endpoint == MTPPresentationEndpointBefore ? MTPPlaceValueEndpointBefore : MTPPlaceValueEndpointAfter];
    }
    self.changingPresentation = NO;
    [self configureWritten];
    self.board.hidden = self.viewingMode == MTPViewingModeWritten;
    self.written.hidden = self.viewingMode != MTPViewingModeWritten;
    self.writtenNoticeLabel.hidden = self.written.hidden;
    self.writtenNoticeLabel.text = @"只看已經寫下的內容，留白的位還不揭曉。字放大時可以左右捲動，百、十、個位仍對齊。";
    [self updateControls];
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
}
- (void)buildPreparationCard {
    [self closePreparation];
    MTPPreparationKey *key = self.presentation.preparationKey;
    self.activePreparationKey = key;
    self.preparationCard = [[UIView alloc] init]; self.preparationCard.backgroundColor = [ChildUI.eggYolk colorWithAlphaComponent:0.16];
    self.preparationCard.layer.cornerRadius = 16; self.preparationCard.accessibilityIdentifier = @"multiplicative.preparation";
    [self.scroll addSubview:self.preparationCard];
    self.preparationNoteLabel = [self label:18 weight:UIFontWeightSemibold identifier:@"multiplicative.preparation.note"];
    self.preparationNoteLabel.text = self.sequence.operation == MultiplicativeTeachingOperationDivision
        ? @"先猜一猜，也可以不填。這是完整的原來數量，還沒有分出去。"
        : @"先猜一猜，也可以不填。這是完整的原來數量，還沒有新增。";
    self.promptLabel = [self label:21 weight:UIFontWeightSemibold identifier:@"multiplicative.preparation.prompt"];
    self.promptLabel.text = self.presentation.prompt;
    self.proposalField = [[UITextField alloc] init]; self.proposalField.delegate = self;
    self.proposalField.text = @""; self.proposalField.placeholder = @"填 0 到 999，或留白";
    self.proposalField.keyboardType = UIKeyboardTypeNumberPad; self.proposalField.borderStyle = UITextBorderStyleRoundedRect;
    self.proposalField.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedMonoFontOfSize:24 weight:UIFontWeightSemibold] compatibleWithTraitCollection:self.traitCollection];
    self.proposalField.adjustsFontForContentSizeCategory = YES; self.proposalField.adjustsFontSizeToFitWidth = NO;
    self.proposalField.accessibilityLabel = @"我的猜測，選填，0 到 999 的整數";
    self.proposalField.accessibilityIdentifier = @"multiplicative.proposal";
    self.submitProposalButton = [self button:@"看看我的想法" color:ChildUI.eggYolk action:NULL identifier:@"multiplicative.submitProposal"];
    __weak typeof(self) weakSelf = self;
    __weak UITextField *weakField = self.proposalField;
    [self.submitProposalButton addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        [weakSelf submitProposalText:weakField.text ?: @"" key:key];
    }] forControlEvents:UIControlEventTouchUpInside];
    self.feedbackLabel = [self label:19 weight:UIFontWeightMedium identifier:@"multiplicative.feedback"];
    for (UIView *view in @[self.preparationNoteLabel, self.promptLabel, self.proposalField, self.submitProposalButton, self.feedbackLabel])
        [self.preparationCard addSubview:view];
}
- (void)submitProposalText:(NSString *)text key:(MTPPreparationKey *)key {
    if (![self.presentation acceptsPreparationKey:key] || ![self.presentation acceptsPreparationKey:self.activePreparationKey]) return;
    NSString *validation = nil;
    NSNumber *proposal = [MultiplicativeTeachingPresentation proposalFromText:text validationMessage:&validation];
    if (!proposal) { self.submittedProposal = nil; self.feedbackLabel.text = validation; }
    else {
        self.submittedProposal = proposal;
        // The sole expectedAnswer read in this presentation layer: an explicit,
        // valid submission against the exact stationary question's attempt key.
        NSNumber *expected = self.sequence.steps[(NSUInteger)key.predictSourceIndex].expectedAnswer;
        BOOL matches = expected && [proposal isEqualToNumber:expected];
        self.feedbackLabel.text = [self.presentation feedbackForProposal:proposal.integerValue matchesExpected:matches
            givenNumber1:self.givenNumber1 givenNumber2:self.givenNumber2];
    }
    [self.proposalField resignFirstResponder];
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    [self frameInspectionView:self.feedbackLabel];
}
- (void)bindBoardCallback {
    NSString *session = self.sessionID.copy, *selection = self.presentation.selectionID.copy;
    NSUInteger generation = self.presentationGeneration;
    __weak typeof(self) weakSelf = self;
    self.board.playbackStateDidChange = ^(MTPPlaceValuePlaybackState state) {
        [weakSelf receiveBoardState:state session:session selection:selection generation:generation];
    };
}
- (void)receiveBoardState:(MTPPlaceValuePlaybackState)state session:(NSString *)session selection:(NSString *)selection generation:(NSUInteger)generation {
    if (self.changingPresentation || state != self.board.playbackState || generation != self.presentationGeneration || ![session isEqual:self.sessionID]
        || ![selection isEqual:self.presentation.selectionID] || ![self.board.selectionID isEqual:selection]
        || ![self.board.sessionID isEqual:session] || self.presentation.phase != MTPPresentationPhaseActionSelection
        || self.board.action != self.presentation.action) return;
    MTPPresentationEndpoint endpoint = self.board.endpoint == MTPPlaceValueEndpointBefore
        ? MTPPresentationEndpointBefore : MTPPresentationEndpointAfter;
    MultiplicativeTeachingActionSnapshot *expected = endpoint == MTPPresentationEndpointBefore
        ? self.presentation.action.before : self.presentation.action.after;
    if (self.board.snapshot != expected || (state == MTPPlaceValuePlaybackStateRunning && endpoint != MTPPresentationEndpointBefore)) return;
    self.presentation = [self.presentation presentationByUpdatingEndpoint:endpoint];
    [self configureWritten];
    self.headingLabel.text = [NSString stringWithFormat:@"第 %ld 步 · 第 %ld／%ld 個動作 · %@",
        (long)self.presentation.sourceStepIndex + 1, (long)self.presentation.action.indexWithinStep + 1,
        (long)self.presentation.action.countWithinStep, endpoint == MTPPresentationEndpointBefore ? @"動作前" : @"動作後"];
    if (state == MTPPlaceValuePlaybackStateRunning) self.noticeLabel.text = nil;
    else if (state == MTPPlaceValuePlaybackStateStationary) self.noticeLabel.text = @"這一步沒有移動積木。可以比較動作前、動作後，或看目前的直式。";
    else if (state == MTPPlaceValuePlaybackStateInsufficientSpace) self.noticeLabel.text = @"畫面放不下完整動作，這次先不播放。可以比較動作前、動作後，或看全部；換好方向後，按「重看」才會播放。";
    else if (state == MTPPlaceValuePlaybackStateReducedMotion) self.noticeLabel.text = @"已開啟減少動態效果，這次不播放移動。可以比較動作前、動作後。";
    else if (state == MTPPlaceValuePlaybackStateInterrupted) self.noticeLabel.text = @"動作已停止，現在看動作後的完整數量。要再看一次，請按「重看」。";
    else if (state == MTPPlaceValuePlaybackStateInvalidScene) self.noticeLabel.text = @"這個動作先用靜態畫面比較，沒有播放。可以看動作前、動作後或全部數量。";
    else self.noticeLabel.text = nil;
    // No next action is selected here. Reentrant board layout never starts a clock.
    if (state != MTPPlaceValuePlaybackStateRunning && !self.preparingPlayback) {
        [self updateControls]; [self.view setNeedsLayout];
    }
}
- (NSInteger)firstActionIndexForSource:(NSInteger)source {
    MultiplicativeTeachingAction *action = [self.plan actionsForSourceStepAtIndex:source].firstObject;
    return action ? (NSInteger)[self.plan.actions indexOfObjectIdenticalTo:action] : NSNotFound;
}
- (void)selectActionIndex:(NSInteger)index play:(BOOL)play {
    if (index < 0 || index >= (NSInteger)self.plan.actions.count) return;
    MultiplicativeTeachingAction *action = self.plan.actions[(NSUInteger)index];
    if (action.sourceStep.kind == MultiplicativeTeachingStepKindPredict) {
        MultiplicativeTeachingPresentation *preparation = [MultiplicativeTeachingPresentation preparationInPlan:self.plan
            sessionID:self.sessionID predictSourceIndex:action.sourceStepIndex review:NO returnSelection:nil];
        if (preparation) { [self transitionTo:preparation mode:MTPViewingModeOverview resetScroll:YES]; return; }
        // An invalid optional pair cannot make the supported observation route unusable.
        NSInteger following = [self firstActionIndexForSource:action.sourceStepIndex + 1];
        if (following != NSNotFound && following > index) [self selectActionIndex:following play:play];
        return;
    }
    MultiplicativeTeachingPresentation *selection = [MultiplicativeTeachingPresentation actionInPlan:self.plan
        sessionID:self.sessionID index:index endpoint:play ? MTPPresentationEndpointBefore : MTPPresentationEndpointAfter];
    MTPViewingMode mode = action.sourceStep.kind == MultiplicativeTeachingStepKindWriteDigit
        ? MTPViewingModeWritten : MTPViewingModeAction;
    [self transitionTo:selection mode:mode resetScroll:YES];
    if (play) [self playSelectedAction];
    else if (mode == MTPViewingModeWritten) [self focusCurrentWrittenChange];
}
- (void)next {
    if (!self.supported) { [self close]; return; }
    if (self.isPreparingQuestion) { [self observeFirstAction]; return; }
    NSInteger nextIndex = self.presentation.phase == MTPPresentationPhaseSourceInspection
        ? [self firstActionIndexForSource:self.presentation.sourceStepIndex + 1] : self.presentation.actionIndex + 1;
    if (nextIndex == NSNotFound || nextIndex >= (NSInteger)self.plan.actions.count) { [self close]; return; }
    [self selectActionIndex:nextIndex play:YES];
}
- (void)observeFirstAction {
    NSInteger source = self.presentation.sourceStepIndex;
    NSInteger index = [self firstActionIndexForSource:source];
    if (index != NSNotFound) [self selectActionIndex:index play:YES];
}
- (void)previous {
    if (!self.presentation) return;
    if (self.isPreparingQuestion) {
        NSInteger previousSource = self.presentation.preparationKey.predictSourceIndex - 1;
        MultiplicativeTeachingAction *last = [self.plan actionsForSourceStepAtIndex:previousSource].lastObject;
        if (last) [self selectActionIndex:(NSInteger)[self.plan.actions indexOfObjectIdenticalTo:last] play:NO];
        return;
    }
    if (self.presentation.phase == MTPPresentationPhaseSourceInspection) {
        if (self.presentation.returnSelection) { [self returnToSavedSelection]; return; }
        NSInteger question = self.presentation.sourceStepIndex - 1;
        MultiplicativeTeachingPresentation *review = [MultiplicativeTeachingPresentation preparationInPlan:self.plan
            sessionID:self.sessionID predictSourceIndex:question review:YES returnSelection:nil];
        if (review) { [self transitionTo:review mode:MTPViewingModeOverview resetScroll:YES]; return; }
        MultiplicativeTeachingAction *last = [self.plan actionsForSourceStepAtIndex:question].lastObject;
        if (last) [self selectActionIndex:(NSInteger)[self.plan.actions indexOfObjectIdenticalTo:last] play:NO];
        return;
    }
    MultiplicativeTeachingAction *action = self.presentation.action;
    if (action.indexWithinStep == 0) {
        MultiplicativeTeachingPresentation *review = [MultiplicativeTeachingPresentation preparationInPlan:self.plan
            sessionID:self.sessionID predictSourceIndex:action.sourceStepIndex - 1 review:YES returnSelection:nil];
        if (review) { [self transitionTo:review mode:MTPViewingModeOverview resetScroll:YES]; return; }
    }
    NSInteger previousIndex = self.presentation.actionIndex - 1;
    while (previousIndex >= 0 && self.plan.actions[(NSUInteger)previousIndex].sourceStep.kind == MultiplicativeTeachingStepKindPredict) previousIndex--;
    if (previousIndex >= 0) [self selectActionIndex:previousIndex play:NO];
}
- (void)replay {
    if (!self.presentation) return;
    if (self.isPreparingQuestion) {
        MultiplicativeTeachingPresentation *reset = [MultiplicativeTeachingPresentation preparationInPlan:self.plan sessionID:self.sessionID
            predictSourceIndex:self.presentation.preparationKey.predictSourceIndex review:self.presentation.review returnSelection:self.presentation.returnSelection];
        [self transitionTo:reset mode:MTPViewingModeOverview resetScroll:YES]; return;
    }
    if (self.presentation.phase == MTPPresentationPhaseSourceInspection) { [self observeFirstAction]; return; }
    // A fresh before-origin selection; never reuse an after layout or reopen Predict.
    MultiplicativeTeachingPresentation *selection = [MultiplicativeTeachingPresentation actionInPlan:self.plan
        sessionID:self.sessionID index:self.presentation.actionIndex endpoint:MTPPresentationEndpointBefore];
    MTPViewingMode mode = selection.action.sourceStep.kind == MultiplicativeTeachingStepKindWriteDigit ? MTPViewingModeWritten : MTPViewingModeAction;
    [self transitionTo:selection mode:mode resetScroll:NO];
    [self playSelectedAction];
}
- (void)playSelectedAction {
    if (self.presentation.phase != MTPPresentationPhaseActionSelection) { self.preparingPlayback = NO; return; }
    if (self.keyboardDismissalInProgress || self.keyboardTop != CGFLOAT_MAX || self.proposalField.isFirstResponder) {
        // This is the still-pending explicit tap, not an automatic resume. Keep
        // the occupied region until DidHide and fence the request against every
        // new selection, interruption, scroll and size/text change.
        self.pendingKeyboardPlay = @{@"session":self.sessionID, @"selection":self.presentation.selectionID,
                                     @"generation":@(self.presentationGeneration)};
        self.preparingPlayback = NO;
        self.noticeLabel.text = @"先把鍵盤收好，再看這一個動作。現在停在動作前。";
        [self.view setNeedsLayout];
        return;
    }
    self.preparingPlayback = YES;
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    // Stationary writes settle through the real board contract, not an invented
    // written animation. Other actions require the complete actual paint rectangle.
    if (self.viewingMode == MTPViewingModeAction) [self frameActionRect:self.board.requiredActionRect];
    if (!self.presentation.action.inputUnits.count && !self.presentation.action.outputUnits.count) {
        [self admitPreparedPlayback:nil];
        return;
    }
    [self.playbackAdmissionLink invalidate];
    self.pendingPaintPlay = @{@"session":self.sessionID, @"selection":self.presentation.selectionID,
        @"generation":@(self.presentationGeneration), @"revision":@(self.board.layoutRevision),
        @"viewBounds":[NSValue valueWithCGRect:self.view.bounds], @"scrollBounds":[NSValue valueWithCGRect:self.scroll.bounds]};
    MTPExplicitPlaybackTick *target = [[MTPExplicitPlaybackTick alloc] init];
    __weak typeof(self) weakSelf = self;
    target.tick = ^(CADisplayLink *link) { [weakSelf admitPreparedPlayback:link]; };
    self.playbackAdmissionLink = [CADisplayLink displayLinkWithTarget:target selector:@selector(fire:)];
    [self.playbackAdmissionLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)admitPreparedPlayback:(CADisplayLink *)link {
    if (link && link != self.playbackAdmissionLink) { [link invalidate]; return; }
    NSDictionary *pending = self.pendingPaintPlay;
    [self.playbackAdmissionLink invalidate]; self.playbackAdmissionLink = nil; self.pendingPaintPlay = nil;
    if (link && (!pending || ![pending[@"session"] isEqual:self.sessionID]
        || ![pending[@"selection"] isEqual:self.presentation.selectionID]
        || [pending[@"generation"] unsignedIntegerValue] != self.presentationGeneration
        || [pending[@"revision"] unsignedIntegerValue] != self.board.layoutRevision
        || !CGRectEqualToRect([pending[@"viewBounds"] CGRectValue], self.view.bounds)
        || !CGRectEqualToRect([pending[@"scrollBounds"] CGRectValue], self.scroll.bounds)
        || self.keyboardDismissalInProgress || self.keyboardTop != CGFLOAT_MAX
        || self.presentation.phase != MTPPresentationPhaseActionSelection
        || self.presentation.endpoint != MTPPresentationEndpointBefore)) {
        self.preparingPlayback = NO;
        self.noticeLabel.text = @"畫面改變了，先停在動作前。準備好後，按「重看」才會播放。";
        [self.view setNeedsLayout]; return;
    }
    // One admission attempt after the explicit layout has had a display frame to
    // commit. Never flush CA, retry a rejected admission, or resume passively.
    CGRect visible = self.viewingMode == MTPViewingModeAction
        ? [self.scroll convertRect:self.unobscuredViewport toView:self.board] : CGRectZero;
    MTPPlaceValuePlaybackState state = [self.board playInVisibleRect:visible];
    self.preparingPlayback = NO;
    [self receiveBoardState:state session:self.sessionID selection:self.presentation.selectionID generation:self.presentationGeneration];
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    if (self.presentation.action.sourceStep.kind == MultiplicativeTeachingStepKindWriteDigit) [self focusCurrentWrittenChange];
}
- (void)saveReturnContext {
    if (!self.presentation) return;
    self.returnContexts[self.presentation.selectionID] = @{@"mode":@(self.viewingMode), @"offset":[NSValue valueWithCGPoint:self.scroll.contentOffset]};
}
- (void)inspectSourceResult {
    if (!self.presentation) return;
    [self cancelPlayback:MTPPlaceValueInterruptionReasonCancelled];
    MultiplicativeTeachingPresentation *saved = self.presentation.phase == MTPPresentationPhaseActionSelection ? self.presentation : self.presentation.returnSelection;
    [self saveReturnContext];
    MultiplicativeTeachingPresentation *inspection = [MultiplicativeTeachingPresentation inspectionInPlan:self.plan sessionID:self.sessionID
        sourceStepIndex:self.presentation.sourceStepIndex endpoint:MTPPresentationEndpointAfter returnSelection:saved];
    [self transitionTo:inspection mode:MTPViewingModeOverview resetScroll:YES];
}
- (void)selectEndpoint:(MTPPresentationEndpoint)endpoint {
    if (!self.presentation || self.isPreparingQuestion) return;
    MultiplicativeTeachingPresentation *selection;
    if (self.presentation.phase == MTPPresentationPhaseSourceInspection) selection = [MultiplicativeTeachingPresentation inspectionInPlan:self.plan
        sessionID:self.sessionID sourceStepIndex:self.presentation.sourceStepIndex endpoint:endpoint returnSelection:self.presentation.returnSelection];
    else selection = [MultiplicativeTeachingPresentation actionInPlan:self.plan sessionID:self.sessionID index:self.presentation.actionIndex endpoint:endpoint];
    [self transitionTo:selection mode:self.viewingMode resetScroll:NO];
    if (self.viewingMode == MTPViewingModeWritten) [self focusCurrentWrittenChange];
}
- (void)showBefore { [self selectEndpoint:MTPPresentationEndpointBefore]; }
- (void)showAfter { [self selectEndpoint:MTPPresentationEndpointAfter]; }
- (NSInteger)priorQuestionSource {
    if (!self.presentation) return NSNotFound;
    if (self.isPreparingQuestion) return self.presentation.preparationKey.predictSourceIndex;
    for (NSInteger source = self.presentation.sourceStepIndex - 1; source >= 0; source--) {
        if (self.sequence.steps[(NSUInteger)source].kind != MultiplicativeTeachingStepKindPredict) continue;
        if ([MultiplicativeTeachingPresentation preparationInPlan:self.plan sessionID:self.sessionID
            predictSourceIndex:source review:YES returnSelection:nil]) return source;
    }
    return NSNotFound;
}
- (void)reopenQuestion {
    NSInteger source = self.priorQuestionSource;
    if (source == NSNotFound) return;
    [self cancelPlayback:MTPPlaceValueInterruptionReasonCancelled];
    [self saveReturnContext];
    MultiplicativeTeachingPresentation *saved = self.isPreparingQuestion ? self.presentation.returnSelection : self.presentation;
    MultiplicativeTeachingPresentation *review = [MultiplicativeTeachingPresentation preparationInPlan:self.plan sessionID:self.sessionID
        predictSourceIndex:source review:YES returnSelection:saved];
    [self transitionTo:review mode:MTPViewingModeOverview resetScroll:YES];
}
- (void)returnToSavedSelection {
    MultiplicativeTeachingPresentation *saved = self.presentation.returnSelection;
    if (!saved) return;
    NSDictionary *context = self.returnContexts[saved.selectionID];
    MTPViewingMode mode = context ? [context[@"mode"] integerValue] : MTPViewingModeAction;
    // Returning is always static. Renew the action visit so old callbacks cannot
    // become valid again merely because its immutable endpoint was restored.
    MultiplicativeTeachingPresentation *restored = saved.phase == MTPPresentationPhaseActionSelection
        ? [MultiplicativeTeachingPresentation actionInPlan:self.plan sessionID:self.sessionID index:saved.actionIndex endpoint:saved.endpoint]
        : saved.phase == MTPPresentationPhaseSourceInspection
            ? [MultiplicativeTeachingPresentation inspectionInPlan:self.plan sessionID:self.sessionID sourceStepIndex:saved.sourceStepIndex
                endpoint:saved.endpoint returnSelection:saved.returnSelection]
            : [MultiplicativeTeachingPresentation preparationInPlan:self.plan sessionID:self.sessionID predictSourceIndex:saved.preparationKey.predictSourceIndex
                review:YES returnSelection:saved.returnSelection];
    [self transitionTo:restored mode:mode resetScroll:YES];
    if (context) [self restoreOffset:[context[@"offset"] CGPointValue]];
}
- (void)changeMode:(MTPViewingMode)mode {
    if (!self.presentation) return;
    [self cancelPlayback:MTPPlaceValueInterruptionReasonCancelled];
    self.modeOffsets[@(self.viewingMode)] = [NSValue valueWithCGPoint:self.scroll.contentOffset];
    self.viewingMode = mode;
    [SpeechManager.sharedInstance stop];
    [self renderPresentation];
    [self restoreOffset:[self.modeOffsets[@(mode)] CGPointValue]];
}
- (void)toggleWritten { [self changeMode:self.viewingMode == MTPViewingModeWritten
    ? (self.presentation.phase == MTPPresentationPhaseActionSelection ? MTPViewingModeAction : MTPViewingModeOverview) : MTPViewingModeWritten]; }
- (void)toggleOverview { [self changeMode:self.viewingMode == MTPViewingModeOverview && self.presentation.phase == MTPPresentationPhaseActionSelection
    ? MTPViewingModeAction : MTPViewingModeOverview]; }
- (void)restart {
    [self.returnContexts removeAllObjects];
    self.sessionID = NSUUID.UUID.UUIDString;
    MultiplicativeTeachingPresentation *start = [MultiplicativeTeachingPresentation actionInPlan:self.plan sessionID:self.sessionID
        index:0 endpoint:MTPPresentationEndpointAfter];
    [self transitionTo:start mode:MTPViewingModeAction resetScroll:YES];
}
- (void)readCurrent {
    if (!self.presentation) return;
    NSString *text;
    if (self.isPreparingQuestion) text = [NSString stringWithFormat:@"%@。%@ %@ %@", self.questionLabel.text,
        self.presentation.prompt, self.presentation.snapshot.spokenDescription, self.feedbackLabel.text ?: @""];
    else text = [NSString stringWithFormat:@"%@。%@ %@", self.questionLabel.text, self.headingLabel.text, self.presentation.snapshot.spokenDescription];
    [SpeechManager.sharedInstance speak:text];
}
- (void)close {
    [self cancelPlayback:MTPPlaceValueInterruptionReasonCancelled];
    [self closePreparation];
    if (self.returnToQuestion) self.returnToQuestion();
    else if (self.navigationController && self.navigationController.viewControllers.firstObject != self) [self.navigationController popViewControllerAnimated:YES];
    else [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)updateControls {
    for (UIButton *button in self.allControlButtons) { button.hidden = NO; button.enabled = YES; }
    BOOL preparation = self.isPreparingQuestion;
    BOOL inspection = self.presentation.phase == MTPPresentationPhaseSourceInspection;
    self.beforeButton.hidden = preparation; self.afterButton.hidden = preparation;
    [self.beforeButton setTitle:inspection ? @"整步開始" : @"動作前" forState:UIControlStateNormal];
    [self.afterButton setTitle:inspection ? @"整步結果" : @"動作後" forState:UIControlStateNormal];
    [self.resultButton setTitle:preparation ? @"直接看這一步結果" : @"看本步結果" forState:UIControlStateNormal];
    self.resultButton.hidden = inspection;
    [self.replayButton setTitle:preparation ? @"重看題目" : inspection ? @"從第一個動作看" : @"重看" forState:UIControlStateNormal];
    self.previousButton.enabled = self.presentation.sourceStepIndex > 0;
    NSString *next = @"下一步";
    if (preparation) next = @"看第一個動作";
    else if (self.presentation.phase == MTPPresentationPhaseActionSelection) {
        if (self.presentation.actionIndex + 1 >= (NSInteger)self.plan.actions.count) next = @"回到題目";
        else {
            MultiplicativeTeachingAction *following = self.plan.actions[(NSUInteger)self.presentation.actionIndex + 1];
            if (following.sourceStepIndex == self.presentation.sourceStepIndex) {
                if (following.kind == MultiplicativeTeachingActionKindGenerateGroup) next = @"下一組";
                else if (following.kind == MultiplicativeTeachingActionKindDistributeRecipient) next = @"下一份";
                else if (following.kind == MultiplicativeTeachingActionKindExchangeUp || following.kind == MultiplicativeTeachingActionKindExchangeDown) next = @"再換一組";
            }
        }
    }
    [self.nextButton setTitle:next forState:UIControlStateNormal];
    [self.writtenButton setTitle:self.viewingMode == MTPViewingModeWritten ? @"回看數量" : @"看直式" forState:UIControlStateNormal];
    [self.overviewButton setTitle:self.viewingMode == MTPViewingModeOverview && self.presentation.phase == MTPPresentationPhaseActionSelection
        ? @"看動作" : @"看全部" forState:UIControlStateNormal];
    self.returnSelectionButton.hidden = self.presentation.returnSelection == nil;
    NSString *selection = self.presentation.selectionID.copy;
    __weak typeof(self) weakSelf = self;
    NSMutableArray<UIMenuElement *> *items = [NSMutableArray array];
    if (self.priorQuestionSource != NSNotFound) [items addObject:[UIAction actionWithTitle:@"回看這一步開始的問題" image:nil identifier:nil handler:^(__kindof UIAction *action) {
        if ([weakSelf.presentation.selectionID isEqual:selection]) [weakSelf reopenQuestion];
    }]];
    [items addObject:[UIAction actionWithTitle:@"聽聽現在的數量" image:nil identifier:nil handler:^(__kindof UIAction *action) {
        if ([weakSelf.presentation.selectionID isEqual:selection]) [weakSelf readCurrent];
    }]];
    [items addObject:[UIAction actionWithTitle:@"從頭再看" image:nil identifier:nil handler:^(__kindof UIAction *action) {
        if ([weakSelf.presentation.selectionID isEqual:selection]) [weakSelf restart];
    }]];
    [items addObject:[UIAction actionWithTitle:@"回到題目" image:nil identifier:nil handler:^(__kindof UIAction *action) { [weakSelf close]; }]];
    self.moreButton.menu = [UIMenu menuWithTitle:@"只換看法，不計分" children:items];
}

#pragma mark - Independent, scrollable controls and fixed-scale content
- (CGFloat)buttonHeight:(UIButton *)button width:(CGFloat)width {
    CGSize text = [button.titleLabel sizeThatFits:CGSizeMake(MAX(1, width - 20), CGFLOAT_MAX)];
    return MAX(44, ceil(text.height) + 20);
}
- (NSArray<NSArray<UIButton *> *> *)controlRowsForWidth:(CGFloat)width {
    NSMutableArray<NSArray<UIButton *> *> *rows = [NSMutableArray array];
    NSArray *groups = @[@[self.beforeButton, self.afterButton, self.resultButton],
                        @[self.previousButton, self.replayButton, self.nextButton],
                        @[self.writtenButton, self.overviewButton, self.moreButton], @[self.returnSelectionButton]];
    BOOL vertical = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) || width < 300;
    for (NSArray<UIButton *> *group in groups) {
        NSMutableArray *visible = [NSMutableArray array];
        for (UIButton *button in group) if (!button.hidden) [visible addObject:button];
        if (vertical) { for (UIButton *button in visible) [rows addObject:@[button]]; }
        else if (visible.count) [rows addObject:visible];
    }
    return rows;
}
- (CGFloat)layoutControlsForWidth:(CGFloat)width apply:(BOOL)apply {
    CGFloat y = 8;
    for (NSArray<UIButton *> *row in [self controlRowsForWidth:width]) {
        CGFloat cellWidth = (width - 32 - (row.count - 1) * 8) / row.count;
        CGFloat height = 44;
        for (UIButton *button in row) height = MAX(height, [self buttonHeight:button width:cellWidth]);
        for (NSUInteger i = 0; i < row.count; i++) if (apply) row[i].frame = CGRectMake(16 + i * (cellWidth + 8), y, cellWidth, height);
        y += height + 8;
    }
    if (apply) self.controlsScroll.contentSize = CGSizeMake(width, y);
    return y;
}
- (CGFloat)placeLabel:(UILabel *)label atY:(CGFloat)y width:(CGFloat)width x:(CGFloat)x {
    if (label.hidden || !label.text.length) { label.frame = CGRectMake(x, y, width, 0); return y; }
    CGFloat height = ceil([label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    label.frame = CGRectMake(x, y, width, height);
    return y + height + 12;
}
- (CGFloat)layoutPreparationWidth:(CGFloat)width {
    CGFloat inside = MAX(1, width - 24), y = 12;
    y = [self placeLabel:self.preparationNoteLabel atY:y width:inside x:12];
    y = [self placeLabel:self.promptLabel atY:y width:inside x:12];
    CGFloat fieldHeight = MAX(48, ceil(self.proposalField.font.lineHeight) + 24);
    self.proposalField.frame = CGRectMake(12, y, inside, fieldHeight); y += fieldHeight + 12;
    CGFloat submitHeight = [self buttonHeight:self.submitProposalButton width:inside];
    self.submitProposalButton.frame = CGRectMake(12, y, inside, submitHeight); y += submitHeight + 12;
    y = [self placeLabel:self.feedbackLabel atY:y width:inside x:12];
    return y;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.layingOutContent) return;
    self.layingOutContent = YES;
    CGRect safe = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    CGFloat bottom = MIN(CGRectGetMaxY(safe), self.keyboardTop);
    CGFloat available = MAX(0, bottom - CGRectGetMinY(safe));
    CGFloat controlsNatural = [self layoutControlsForWidth:safe.size.width apply:NO];
    CGFloat controlsHeight = MIN(controlsNatural, available * 0.42);
    CGRect controlsFrame = CGRectMake(CGRectGetMinX(safe), bottom - controlsHeight, safe.size.width, controlsHeight);
    CGRect contentFrame = CGRectMake(CGRectGetMinX(safe), CGRectGetMinY(safe), safe.size.width,
        MAX(0, available - controlsHeight - 8));
    BOOL sizeOrTextChanged = !CGSizeEqualToSize(self.lastLayoutSize, self.view.bounds.size)
        || ![self.lastTextCategory isEqual:self.traitCollection.preferredContentSizeCategory];
    BOOL changed = sizeOrTextChanged || !CGRectEqualToRect(self.scroll.frame, contentFrame);
    if ((sizeOrTextChanged && self.pendingKeyboardPlay) || (changed && self.pendingPaintPlay)) {
        [self cancelPlayback:MTPPlaceValueInterruptionReasonLayoutChanged];
        self.noticeLabel.text = @"畫面改變了，先停在動作前。準備好後，按「重看」才會播放。";
    }
    if (changed && self.board.playbackState == MTPPlaceValuePlaybackStateRunning && !self.preparingPlayback)
        [self cancelPlayback:MTPPlaceValueInterruptionReasonLayoutChanged];
    self.lastLayoutSize = self.view.bounds.size;
    self.lastTextCategory = self.traitCollection.preferredContentSizeCategory;
    self.controlsScroll.frame = controlsFrame; [self layoutControlsForWidth:safe.size.width apply:YES];
    self.scroll.frame = contentFrame;
    CGFloat width = MAX(1, contentFrame.size.width - 32), y = 12;
    y = [self placeLabel:self.questionLabel atY:y width:width x:16];
    y = [self placeLabel:self.headingLabel atY:y width:width x:16];
    if (self.preparationCard.superview) {
        CGFloat cardHeight = [self layoutPreparationWidth:width];
        self.preparationCard.frame = CGRectMake(16, y, width, cardHeight); y += cardHeight + 16;
    }
    y = [self placeLabel:self.noticeLabel atY:y width:width x:16];
    CGFloat contentWidth = contentFrame.size.width;
    if (self.supported) {
        if (self.viewingMode == MTPViewingModeWritten) {
            y = [self placeLabel:self.writtenNoticeLabel atY:y width:width x:16];
            CGSize fitted = [self.written sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
            self.written.frame = CGRectMake(16, y, fitted.width, fitted.height);
            y += fitted.height + 16; contentWidth = MAX(contentWidth, fitted.width + 32);
        } else {
            BOOL actionFit = self.presentation.phase == MTPPresentationPhaseActionSelection
                && self.viewingMode == MTPViewingModeAction
                && (self.preparingPlayback || self.board.playbackState == MTPPlaceValuePlaybackStateRunning);
            CGSize fitted = actionFit ? [self.board requiredActionSizeThatFits:CGSizeMake(width, CGFLOAT_MAX)]
                                     : [self.board sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
            CGFloat boardWidth = MAX(width, fitted.width);
            self.board.frame = CGRectMake(16, y, boardWidth, MAX(1, fitted.height));
            y += self.board.frame.size.height + 16; contentWidth = MAX(contentWidth, boardWidth + 32);
        }
    }
    self.scroll.contentSize = CGSizeMake(contentWidth, MAX(y, contentFrame.size.height));
    [self.board setNeedsLayout]; [self.board layoutIfNeeded];
    [self.written setNeedsLayout]; [self.written layoutIfNeeded];
    self.layingOutContent = NO;
}
- (CGRect)unobscuredViewport { return UIEdgeInsetsInsetRect(self.scroll.bounds, UIEdgeInsetsMake(8, 0, 8, 0)); }
- (MTPFramingResult)frameActionRect:(CGRect)rect {
    if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) return MTPFramingResultCannotContain;
    CGRect target = [self.board convertRect:rect toView:self.scroll], viewport = self.unobscuredViewport;
    if (CGRectContainsRect(viewport, target)) return MTPFramingResultAlreadyContained;
    if (target.size.width > viewport.size.width || target.size.height > viewport.size.height || CGRectIsEmpty(viewport))
        return MTPFramingResultCannotContain;
    CGFloat x = CGRectGetMinX(target) - (viewport.size.width - target.size.width) / 2;
    CGFloat y = CGRectGetMinY(target) - (viewport.size.height - target.size.height) / 2 - 8;
    [self restoreOffset:CGPointMake(x, y)];
    target = [self.board convertRect:rect toView:self.scroll];
    return CGRectContainsRect(self.unobscuredViewport, target) ? MTPFramingResultMovedAndContained : MTPFramingResultCannotContain;
}
- (void)restoreOffset:(CGPoint)offset {
    CGFloat maxX = MAX(0, self.scroll.contentSize.width - self.scroll.bounds.size.width);
    CGFloat maxY = MAX(0, self.scroll.contentSize.height - self.scroll.bounds.size.height);
    self.framingContent = YES;
    [self.scroll setContentOffset:CGPointMake(MIN(maxX, MAX(0, offset.x)), MIN(maxY, MAX(0, offset.y))) animated:NO];
    self.framingContent = NO;
}
- (void)focusCurrentWrittenChange {
    if (self.viewingMode != MTPViewingModeWritten || self.presentation.phase != MTPPresentationPhaseActionSelection
        || self.presentation.action.sourceStep.kind != MultiplicativeTeachingStepKindWriteDigit) return;
    NSInteger column = self.presentation.action.activeColumn;
    self.noticeLabel.text = [NSString stringWithFormat:@"這一步用靜態畫面比較%@，沒有播放動畫。黃色標示是目前看的位置；可以切換「動作前／動作後」。", self.placeName];
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    CGRect relation = [self.written writtenRelationRectForColumn:column];
    CGRect row = [self.written latestWorkRowRectForColumn:column];
    CGRect target = relation;
    if (relation.size.height > self.unobscuredViewport.size.height && !CGRectIsNull(row)) target = row;
    if (target.size.height > self.unobscuredViewport.size.height && !CGRectIsNull(row)) {
        // At very large text the complete relation is ordinary static paper.
        // Focus its explicit place caption rather than hide it below old rows.
        target = [self.written latestWorkCaptionRectForColumn:column];
    }
    if (CGRectIsNull(target) || CGRectIsEmpty(target)) return;
    CGRect inScroll = [self.written convertRect:target toView:self.scroll];
    if (CGRectContainsRect(self.unobscuredViewport, inScroll)) return;
    CGFloat x = CGRectGetMinX(inScroll) - 16;
    CGFloat y = CGRectGetMinY(inScroll) - 8;
    [self restoreOffset:CGPointMake(x, y)];
}
- (void)frameInspectionView:(UIView *)view {
    if (!view || !view.superview) return;
    CGRect target = [view convertRect:view.bounds toView:self.scroll];
    if (CGRectContainsRect(self.unobscuredViewport, target)) return;
    [self restoreOffset:CGPointMake(0, CGRectGetMinY(target) - 8)];
}

#pragma mark - Interruption never resumes or advances
- (void)cancelPlayback:(MTPPlaceValueInterruptionReason)reason {
    if (self.changingPresentation || !self.board) return;
    BOOL running = self.board.playbackState == MTPPlaceValuePlaybackStateRunning;
    if (self.pendingKeyboardPlay || self.pendingPaintPlay) self.noticeLabel.text = @"已停在動作前。準備好後，按「重看」才會播放。";
    self.pendingKeyboardPlay = nil; self.pendingPaintPlay = nil;
    [self.playbackAdmissionLink invalidate]; self.playbackAdmissionLink = nil;
    self.preparingPlayback = NO;
    self.presentationGeneration++;
    self.board.playbackStateDidChange = nil;
    self.changingPresentation = YES;
    if (running) [self.board cancelPlaybackWithReason:reason];
    self.changingPresentation = NO;
    if (running && self.presentation.phase == MTPPresentationPhaseActionSelection) {
        [self receiveBoardState:self.board.playbackState session:self.sessionID selection:self.presentation.selectionID generation:self.presentationGeneration];
    }
    if (self.presentation.phase == MTPPresentationPhaseActionSelection && !self.board.displayingFullSnapshot) [self bindBoardCallback];
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView == self.scroll || self.pendingKeyboardPlay || self.pendingPaintPlay) [self cancelPlayback:MTPPlaceValueInterruptionReasonVisibility];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != self.scroll || self.framingContent || self.layingOutContent || self.changingPresentation) return;
    if (self.pendingKeyboardPlay || self.pendingPaintPlay || self.board.playbackState == MTPPlaceValuePlaybackStateRunning)
        [self cancelPlayback:MTPPlaceValueInterruptionReasonVisibility];
}
- (void)applicationInterrupted:(NSNotification *)notification {
    [self cancelPlayback:MTPPlaceValueInterruptionReasonBackground];
    [SpeechManager.sharedInstance stop];
}
- (void)motionChanged:(NSNotification *)notification {
    [self cancelPlayback:MTPPlaceValueInterruptionReasonMotionChanged];
    [self.view setNeedsLayout];
}
- (void)textSizeChanged:(NSNotification *)notification {
    [self cancelPlayback:MTPPlaceValueInterruptionReasonLayoutChanged];
    [self refreshFonts]; [self.view setNeedsLayout];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![previousTraitCollection.preferredContentSizeCategory isEqual:self.traitCollection.preferredContentSizeCategory])
        [self textSizeChanged:nil];
}
- (void)refreshFonts {
    if (!self.isViewLoaded || !self.questionLabel) return;
    NSArray<UILabel *> *labels = @[self.questionLabel, self.headingLabel, self.noticeLabel, self.writtenNoticeLabel];
    NSArray<NSNumber *> *sizes = @[@27, @18, @19, @18];
    for (NSUInteger i = 0; i < labels.count; i++) labels[i].font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:sizes[i].doubleValue weight:i == 0 ? UIFontWeightBold : UIFontWeightSemibold]
        compatibleWithTraitCollection:self.traitCollection];
    for (UIButton *button in self.allControlButtons) button.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:19 weight:UIFontWeightBold] compatibleWithTraitCollection:self.traitCollection];
    if (self.preparationCard) {
        // Keep the attempt and typed proposal while changing only readable fonts.
        self.promptLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
            scaledFontForFont:[ChildUI roundedFontOfSize:21 weight:UIFontWeightSemibold] compatibleWithTraitCollection:self.traitCollection];
        self.preparationNoteLabel.font = self.headingLabel.font;
        self.feedbackLabel.font = self.noticeLabel.font;
        self.submitProposalButton.titleLabel.font = self.nextButton.titleLabel.font;
        self.proposalField.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
            scaledFontForFont:[ChildUI roundedMonoFontOfSize:24 weight:UIFontWeightSemibold] compatibleWithTraitCollection:self.traitCollection];
    }
}
- (void)keyboardChanged:(NSNotification *)notification {
    if (!self.isViewLoaded || !self.view.window) return;
    CGRect screenFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect frame = [self.view convertRect:screenFrame fromView:nil];
    BOOL hiding = [notification.name isEqual:UIKeyboardWillHideNotification] || !CGRectIntersectsRect(frame, self.view.bounds);
    if (hiding) {
        // WillHide describes a destination, not a visibility certificate. Keep
        // the keyboard's last occupied region through its disappearance.
        self.keyboardDismissalInProgress = YES;
        if (self.pendingPaintPlay || self.board.playbackState == MTPPlaceValuePlaybackStateRunning)
            [self cancelPlayback:MTPPlaceValueInterruptionReasonLayoutChanged];
    } else {
        [self cancelPlayback:MTPPlaceValueInterruptionReasonLayoutChanged];
        self.keyboardDismissalInProgress = NO;
        self.keyboardTop = CGRectGetMinY(frame);
    }
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    if (!hiding && self.proposalField.isFirstResponder) [self frameInspectionView:self.proposalField];
}
- (void)keyboardDidHide:(NSNotification *)notification {
    self.keyboardDismissalInProgress = NO; self.keyboardTop = CGFLOAT_MAX;
    // Keep the request cancellable while the final layout detects rotation or
    // text changes. Copying it before layout would let a stale local escape.
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    NSDictionary *pending = self.pendingKeyboardPlay;
    self.pendingKeyboardPlay = nil;
    if (!pending || ![pending[@"session"] isEqual:self.sessionID]
        || ![pending[@"selection"] isEqual:self.presentation.selectionID]
        || [pending[@"generation"] unsignedIntegerValue] != self.presentationGeneration
        || self.presentation.phase != MTPPresentationPhaseActionSelection
        || self.presentation.endpoint != MTPPresentationEndpointBefore) return;
    // Only the original explicit action may finish its admission now. A real
    // visibility check still decides whether motion is permitted.
    self.noticeLabel.text = nil;
    [self playSelectedAction];
}
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField == self.proposalField && [self.presentation acceptsPreparationKey:self.activePreparationKey])
        [self frameInspectionView:textField];
}
@end

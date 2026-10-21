#import <UIKit/UIKit.h>

@class ArithmeticProblem;
@class MultipleChoiceAnswerView;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MCQResult) {
    MCQResultCorrect,
    MCQResultWrong,
};

@protocol MultipleChoiceAnswerViewDelegate <NSObject>
- (void)mcqView:(MultipleChoiceAnswerView *)view didChoose:(NSInteger)choiceValue result:(MCQResult)result;
@end

/// 2×2 grid of large, readable answer cards. Feedback never advances the question.
@interface MultipleChoiceAnswerView : UIView

@property (nonatomic, weak, nullable) id<MultipleChoiceAnswerViewDelegate> delegate;

/// NO before configuration, during wrong-answer feedback, or after locking/revealing.
/// Available cards' enabled state follows this gate. A rejected tap has no answer side effects.
@property (nonatomic, readonly, getter=isAcceptingAnswers) BOOL acceptingAnswers;

/// 用一道題配置 4 個選項。內部呼叫 DistractorGenerator。
- (void)configureWithProblem:(ArithmeticProblem *)problem;

/// Configure up to four visible choices. Missing/empty choices remain hidden and disabled.
/// An invalid correctIndex disables selection instead of silently marking another answer correct.
- (void)configureWithChoiceTitles:(NSArray<NSString *> *)titles correctIndex:(NSInteger)correctIndex;

/// Start the configured question again, clearing feedback and re-enabling only populated cards.
- (void)reset;

/// Lock input while keeping every populated card readable and preserving its feedback.
- (void)disableAllChoices;

/// Highlight the correct answer with a text/checkmark badge and lock input.
/// Does not invoke the delegate or award a correct answer.
- (void)revealCorrectChoice;

@end

NS_ASSUME_NONNULL_END

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

/// 2×2 grid of large rounded buttons. §1 視覺語言。
@interface MultipleChoiceAnswerView : UIView

@property (nonatomic, weak) id<MultipleChoiceAnswerViewDelegate> delegate;

/// 用一道題配置 4 個選項。內部呼叫 DistractorGenerator。
- (void)configureWithProblem:(ArithmeticProblem *)problem;

/// 重新啟用所有按鈕（新題時呼叫）。
- (void)reset;

/// 鎖住所有按鈕：在「答對 → 等 0.85s 換題」與「揭示答案 → 等 2.4s 換題」期間，
/// 阻止連續點擊重複觸發 delegate（會造成 correctStreak/questionIndex 多加）。
- (void)disableAllChoices;

@end

NS_ASSUME_NONNULL_END

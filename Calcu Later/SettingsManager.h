#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AnswerMode) {
    AnswerModeMultipleChoice = 0,  // 預設
    AnswerModeWriting = 1,         // 手寫草稿，自行核對（沒有手寫辨識）
};

typedef NS_ENUM(NSInteger, SettingsOperation) {
    SettingsOperationAddition = 0,
    SettingsOperationSubtraction,
    SettingsOperationMultiplication,
    SettingsOperationDivision,
};

@interface SettingsManager : NSObject

@property (class, nonatomic, readonly) SettingsManager *sharedInstance;

/// 可注入獨立 defaults；不會讀寫其他 suite 或 sharedInstance 的偏好。
- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults;

// Problem generation settings
@property (nonatomic, assign) NSInteger digits1;
@property (nonatomic, assign) NSInteger digits2;
@property (nonatomic, assign) BOOL allowNegativeResults;

// Drill tier (Phase 7 新欄位；1 = D1 / 2 = D2 / 3 = D3 / 4 = Mixed)
@property (nonatomic, assign) NSInteger drillTier;

// Operation settings
@property (nonatomic, assign) BOOL operationAddition;
@property (nonatomic, assign) BOOL operationSubtraction;
@property (nonatomic, assign) BOOL operationMultiplication;
@property (nonatomic, assign) BOOL operationDivision;

// Legacy hint preferences. Preserve saved values for compatibility, but these
// flags do not control current practice help and are not shown as settings.
@property (nonatomic, assign) BOOL hintShowAnswer;
@property (nonatomic, assign) BOOL hintStandard;
@property (nonatomic, assign) BOOL hintMultiLayer;
@property (nonatomic, assign) BOOL hintAnimated;

// Phase 4 / 7 新欄位
@property (nonatomic, assign) AnswerMode answerMode;
@property (nonatomic, assign) BOOL soundEffectsEnabled;
@property (nonatomic, assign) BOOL mascotEnabled;

/// 設定頁的運算切換入口。拒絕關閉最後一種運算；成功後立即儲存。
- (BOOL)setOperation:(SettingsOperation)operation enabled:(BOOL)enabled;
- (BOOL)isOperationEnabled:(SettingsOperation)operation;

/// 儲存前與載入時，都修復無效的題目範圍、答題模式和全關的運算。
- (void)saveSettings;
- (void)loadSettings;

@end

NS_ASSUME_NONNULL_END

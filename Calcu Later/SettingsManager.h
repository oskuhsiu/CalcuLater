#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AnswerMode) {
    AnswerModeMultipleChoice = 0,  // 預設
    AnswerModeWriting = 1,         // 手寫畫板
};

@interface SettingsManager : NSObject

@property (class, nonatomic, readonly) SettingsManager *sharedInstance;

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

// Hint settings
@property (nonatomic, assign) BOOL hintShowAnswer;
@property (nonatomic, assign) BOOL hintStandard;
@property (nonatomic, assign) BOOL hintMultiLayer;
@property (nonatomic, assign) BOOL hintAnimated;

// Phase 4 / 7 新欄位
@property (nonatomic, assign) AnswerMode answerMode;
@property (nonatomic, assign) BOOL soundEffectsEnabled;
@property (nonatomic, assign) BOOL mascotEnabled;

- (void)saveSettings;
- (void)loadSettings;

@end

NS_ASSUME_NONNULL_END

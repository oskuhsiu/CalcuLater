#import "SpeechManager.h"
#import <AVFoundation/AVFoundation.h>

@interface SpeechManager () <AVSpeechSynthesizerDelegate>
@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;
@property (nonatomic, strong, nullable) AVSpeechSynthesisVoice *zhVoice;
/// 目前正在朗讀的 utterance，當作「世代」用：被中斷的舊 utterance 之後非同步抵達的
/// didCancel / willSpeakRange 不等於 currentUtterance 時一律忽略，避免清掉新一輪高亮。
@property (nonatomic, weak, nullable) AVSpeechUtterance *currentUtterance;
@property (nonatomic, copy, nullable) void (^willSpeakRange)(NSRange);
@property (nonatomic, copy, nullable) void (^onFinish)(void);
@end

@implementation SpeechManager

+ (SpeechManager *)sharedInstance {
    static SpeechManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[SpeechManager alloc] init]; });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _synthesizer = [[AVSpeechSynthesizer alloc] init];
        _synthesizer.delegate = self;
        _zhVoice = [self bestZhVoice];
    }
    return self;
}

// 偏好順序：zh-TW Premium → zh-TW Enhanced → zh-CN Premium → zh-CN Enhanced → 系統預設 zh-TW/zh-CN。
- (AVSpeechSynthesisVoice *)bestZhVoice {
    NSArray<AVSpeechSynthesisVoice *> *voices = [AVSpeechSynthesisVoice speechVoices];
    NSArray *prefs = @[
        @[@"zh-TW", @(AVSpeechSynthesisVoiceQualityPremium)],
        @[@"zh-TW", @(AVSpeechSynthesisVoiceQualityEnhanced)],
        @[@"zh-CN", @(AVSpeechSynthesisVoiceQualityPremium)],
        @[@"zh-CN", @(AVSpeechSynthesisVoiceQualityEnhanced)],
    ];
    for (NSArray *pref in prefs) {
        NSString *langPrefix = pref[0];
        AVSpeechSynthesisVoiceQuality q = (AVSpeechSynthesisVoiceQuality)[pref[1] integerValue];
        for (AVSpeechSynthesisVoice *v in voices) {
            if ([v.language hasPrefix:langPrefix] && v.quality == q) return v;
        }
    }
    return [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-TW"]
        ?: [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
}

- (void)speak:(NSString *)text {
    [self speak:text willSpeakRange:nil onFinish:nil];
}

- (void)speak:(NSString *)text
    willSpeakRange:(void (^)(NSRange))willSpeakRange
          onFinish:(void (^)(void))onFinish {
    if (text.length == 0) return;

    // 中斷前一段：先把舊 callback 取出並清空，stop 後手動呼叫舊 onFinish 清掉舊高亮。
    // 把 currentUtterance 設為 nil，讓舊 utterance 隨後非同步抵達的 didCancel 失效，
    // 不會誤觸即將設定的新一輪 onFinish。
    void (^pendingFinish)(void) = self.onFinish;
    self.willSpeakRange = nil;
    self.onFinish = nil;
    self.currentUtterance = nil;
    [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    if (pendingFinish) pendingFinish();

    AVSpeechUtterance *u = [AVSpeechUtterance speechUtteranceWithString:text];
    u.voice = self.zhVoice;
    u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92;  // 稍慢、適合兒童
    u.pitchMultiplier = 1.05;
    u.preUtteranceDelay = 0.05;

    self.currentUtterance = u;
    self.willSpeakRange = [willSpeakRange copy];
    self.onFinish = [onFinish copy];
    [self.synthesizer speakUtterance:u];
}

- (void)stop {
    AVSpeechUtterance *cur = self.currentUtterance;
    void (^finish)(void) = self.onFinish;
    self.willSpeakRange = nil;
    self.onFinish = nil;
    self.currentUtterance = nil;
    [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    if (cur && finish) finish();
}

#pragma mark - AVSpeechSynthesizerDelegate

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
willSpeakRangeOfSpeechString:(NSRange)characterRange
                utterance:(AVSpeechUtterance *)utterance {
    if (utterance != self.currentUtterance) return;
    if (self.willSpeakRange) self.willSpeakRange(characterRange);
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
  didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    [self finishUtterance:utterance];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
  didCancelSpeechUtterance:(AVSpeechUtterance *)utterance {
    [self finishUtterance:utterance];
}

/// didFinish / didCancel 共用：只有當收尾的 utterance 仍是當前世代時才觸發 onFinish。
- (void)finishUtterance:(AVSpeechUtterance *)utterance {
    if (utterance != self.currentUtterance) return;
    void (^finish)(void) = self.onFinish;
    self.willSpeakRange = nil;
    self.onFinish = nil;
    self.currentUtterance = nil;
    if (finish) finish();
}

@end

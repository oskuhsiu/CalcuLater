#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SoundEffect) {
    SoundEffectCorrect = 0,
    SoundEffectWrong,
    SoundEffectTap,
    SoundEffectReveal,
    SoundEffectCheer,
};

/// 統一音效 + 觸覺回饋管理。
/// 音效部分使用 iOS 內建 SystemSoundID（無外部資產）；觸覺永遠播放（不耗電、無聲）。
/// 音效播放會檢查 SettingsManager.soundEffectsEnabled；觸覺不檢查。
@interface SoundManager : NSObject

@property (class, nonatomic, readonly) SoundManager *sharedInstance;

- (void)play:(SoundEffect)effect;

/// 預先 prepare haptic 引擎，可在 viewWillAppear 呼叫減少首次延遲。
- (void)prepare;

@end

NS_ASSUME_NONNULL_END

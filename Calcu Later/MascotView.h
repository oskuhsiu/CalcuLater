#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MascotEmotion) {
    MascotEmotionIdle = 0,
    MascotEmotionHappy,
    MascotEmotionThinking,
    MascotEmotionCheering,
    MascotEmotionShake,
    MascotEmotionTalking,
};

typedef NS_ENUM(NSInteger, MascotVariant) {
    MascotVariantPortrait = 0,   // teacher_1/2/3 — 小頭像、主畫面、刷題畫面
    MascotVariantDesk = 1,       // teacher_desk_1/2/3 — 教學/課程畫面，連桌子書本
};

/// 兒童陪讀吉祥物 view（老師角色）。
/// 包裝 UIImageView，提供情緒切換動畫 + 自動 idle bobbing。
@interface MascotView : UIView

- (instancetype)initWithVariant:(MascotVariant)variant;

@property (nonatomic, assign) MascotVariant variant;

/// 切換情緒。保留可讀的情緒描述；隱藏、離開畫面或「減少動態效果」時不播放動畫。
- (void)setEmotion:(MascotEmotion)emotion;

- (void)startIdleAnimation;
- (void)stopAllAnimations;

@end

NS_ASSUME_NONNULL_END

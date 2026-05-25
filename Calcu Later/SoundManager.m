#import "SoundManager.h"
#import "SettingsManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>

@interface SoundManager ()
@property (nonatomic, strong) UINotificationFeedbackGenerator *notificationFB;
@property (nonatomic, strong) UIImpactFeedbackGenerator *softFB;
@property (nonatomic, strong) UIImpactFeedbackGenerator *lightFB;
@end

@implementation SoundManager

+ (SoundManager *)sharedInstance {
    static SoundManager *shared = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ shared = [[SoundManager alloc] init]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _notificationFB = [[UINotificationFeedbackGenerator alloc] init];
        _softFB = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
        _lightFB = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }
    return self;
}

- (void)prepare {
    [self.notificationFB prepare];
    [self.softFB prepare];
    [self.lightFB prepare];
}

- (void)play:(SoundEffect)effect {
    BOOL audioOn = SettingsManager.sharedInstance.soundEffectsEnabled;
    SystemSoundID soundID = 0;

    switch (effect) {
        case SoundEffectCorrect:
            [self.notificationFB notificationOccurred:UINotificationFeedbackTypeSuccess];
            soundID = 1057;  // Tink — 乾淨短 ding
            break;
        case SoundEffectWrong:
            [self.notificationFB notificationOccurred:UINotificationFeedbackTypeWarning];
            // 不放音，避免刺耳；只靠 haptic 警告
            break;
        case SoundEffectTap:
            [self.lightFB impactOccurred];
            // 不放音，靠 haptic 即可
            break;
        case SoundEffectReveal:
            [self.softFB impactOccurred];
            soundID = 1104;  // Tock — 軟敲擊
            break;
        case SoundEffectCheer:
            [self.notificationFB notificationOccurred:UINotificationFeedbackTypeSuccess];
            soundID = 1025;  // 短鈴
            break;
    }

    if (soundID != 0 && audioOn) {
        AudioServicesPlaySystemSound(soundID);
    }
}

@end

#import <UIKit/UIKit.h>
#import "SettingsManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface SettingsViewController : UIViewController

/// 一般使用 init；可指定獨立設定來源以進行預覽或隔離測試。
- (instancetype)initWithSettingsManager:(SettingsManager *)settingsManager;

@end

NS_ASSUME_NONNULL_END

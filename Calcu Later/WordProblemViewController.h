#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 應用題答題畫面（無盡產生）。
/// 透過 SettingsManager.answerMode 決定 MCQ / 手寫。
@interface WordProblemViewController : UIViewController

- (instancetype)initWithGrade:(NSInteger)grade NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

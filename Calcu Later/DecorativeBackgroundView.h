#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BackgroundTheme) {
    BackgroundThemeMainMenu = 0,        // 雲 + 太陽 + 飄浮數字
    BackgroundThemeLessons,             // 飄浮加減乘除符號（教室便條紙感）
    BackgroundThemeDrill,               // 飄浮數字 + 小星星（練功氛圍）
    BackgroundThemeMultiplication,      // 9×9 點點格 + × 符號
    BackgroundThemeSettings,            // 齒輪暗紋（樸素）
};

/// 每個頁面的童趣背景。會自動依 bounds 放置裝飾元素，可加在 view tree 最底層。
@interface DecorativeBackgroundView : UIView

+ (instancetype)backgroundWithTheme:(BackgroundTheme)theme;

/// 插入到 vc.view 最底層並 pin 到四邊。回傳 bg view 供需要時調整。
+ (instancetype)installInViewController:(UIViewController *)vc theme:(BackgroundTheme)theme;

@end

NS_ASSUME_NONNULL_END

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 共用兒童風格設計系統（§1 視覺語言）。
/// 顏色、字體、軟陰影、按鈕等元件的單一來源。
@interface ChildUI : NSObject

#pragma mark - Colors (§1.1)

@property (class, nonatomic, readonly) UIColor *creamBackground;   // #FFF9F0
@property (class, nonatomic, readonly) UIColor *skyBackground;     // #E8F4FB
@property (class, nonatomic, readonly) UIColor *brownText;         // 深棕，數字主色
@property (class, nonatomic, readonly) UIColor *calmGreen;         // 沉穩綠，答案

@property (class, nonatomic, readonly) UIColor *pinkAccent;        // 粉紅 #FF8FA3
@property (class, nonatomic, readonly) UIColor *pumpkinOrange;     // 南瓜橘
@property (class, nonatomic, readonly) UIColor *eggYolk;           // 蛋黃
@property (class, nonatomic, readonly) UIColor *mintGreen;         // 薄荷綠
@property (class, nonatomic, readonly) UIColor *skyBlue;           // 天藍
@property (class, nonatomic, readonly) UIColor *lavender;          // 薰衣草紫

/// 6 色循環，mod size 安全處理（負數也支援）。
+ (UIColor *)candyColorAtIndex:(NSInteger)index;

#pragma mark - Fonts (§1.1)

/// SF Rounded monospaced digit font。
+ (UIFont *)roundedMonoFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;

/// SF Rounded proportional。一般文字用。
+ (UIFont *)roundedFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;

#pragma mark - Common modifiers

/// 把軟陰影掛上去：offset (0, 4)、blur 12、opacity 0.10。
+ (void)applySoftShadowOnLayer:(CALayer *)layer;

/// 答對綠 / 答錯粉（柔色）.
@property (class, nonatomic, readonly) UIColor *correctGreen;
@property (class, nonatomic, readonly) UIColor *wrongPink;

@end


#pragma mark - ChildButton

/// 兒童風格按鈕：大圓角、糖果色背景、SF Rounded 字、按下縮放動畫。
@interface ChildButton : UIButton
+ (instancetype)buttonWithTitle:(NSString *)title backgroundColor:(UIColor *)bg;
@end

NS_ASSUME_NONNULL_END

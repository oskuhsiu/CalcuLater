#import <Foundation/Foundation.h>

@class WordProblem;
@class WordProblemTemplate;

NS_ASSUME_NONNULL_BEGIN

/// 從 WordProblemCatalog 抓對應年級的模板，隨機抽一個並產生具體的應用題。
///
/// 規則：
/// - 隨機抽模板（盡量避免連兩題同模板）
/// - 在模板的 [minA, maxA] / [minB, maxB] 範圍內隨機 a / b
/// - 對減法（−）強制 a ≥ b（避免負數答案）
/// - 對除法（÷）強制 a 為 b 的整數倍（無餘數）
/// - 對加法（+）也避免 a + b 過大（≤ 999）
@interface WordProblemGenerator : NSObject

/// 主要 API。grade clamp 到 [1, 3]。
+ (WordProblem *)generateForGrade:(NSInteger)grade;

/// 同上，但禁止抽到 lastTemplateID（避免連兩題同模板）。
+ (WordProblem *)generateForGrade:(NSInteger)grade
                excludingTemplate:(nullable NSString *)lastTemplateID;

@end

NS_ASSUME_NONNULL_END

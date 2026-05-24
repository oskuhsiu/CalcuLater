#import <Foundation/Foundation.h>
#import "ArithmeticProblem.h"

NS_ASSUME_NONNULL_BEGIN

/// 減法借位的單一位數資訊。對應 Android 的 BorrowInfo data class。
/// 一個 BorrowInfo 描述 number1 在這一位的狀態：
///   - original          : 原本這一位的數字 (0-9)
///   - afterLending      : 若這一位「借給」右邊，借出後變成的值；nil 代表沒借出
///   - afterBorrowing    : 若這一位「向左邊借」之後，變成的兩位數字串（如 @"13"）；nil 代表沒借入
///   - lendingColorIndex : 借出事件對應的顏色 index（0..4 循環）；nil 代表無
///   - borrowingColorIndex: 借入事件對應的顏色 index；nil 代表無
@interface BorrowInfo : NSObject

@property (nonatomic, assign, readonly) NSInteger original;
@property (nonatomic, copy, readonly, nullable) NSNumber *afterLending;
@property (nonatomic, copy, readonly, nullable) NSString *afterBorrowing;
@property (nonatomic, copy, readonly, nullable) NSNumber *lendingColorIndex;
@property (nonatomic, copy, readonly, nullable) NSNumber *borrowingColorIndex;

- (instancetype)initWithOriginal:(NSInteger)original;

@end


/// 一道算術題的完整解答資料（含直式呈現所需的中間步驟）。
///
/// 與 Android 的 calculateCarries / calculateBorrowInfo 對應，但封裝成結構化 model。
/// HintView 只消費這個物件，不負責計算。
@interface ArithmeticSolution : NSObject

@property (nonatomic, strong, readonly) ArithmeticProblem *problem;

/// 直式對齊用的位數寬度（max(num1, num2, answer) 的位數）。
@property (nonatomic, assign, readonly) NSInteger maxLength;

/// 加法進位字串，格式與 Android 相同：
///   * 長度通常為 maxLength，每個 char 對應一個直式欄位（' ' 表無進位、'1' 表進位）。
///   * 若最高位再向左進位，字串會比 maxLength 多一個字元（最前面多一個 '1'）。
///   * 非加法運算固定回傳 @""。
@property (nonatomic, copy, readonly) NSString *carries;

/// 減法借位資訊，長度等於 maxLength（index 0 是最高位，與 Android 相同左到右排列）。
/// 非減法運算固定回傳 @[]。
@property (nonatomic, copy, readonly) NSArray<BorrowInfo *> *borrows;

/// number1 / number2 / answer 的逐位拆解（index 0 為最高位，與字串表示一致）。
/// 若位數不足 maxLength，前面以 0 補齊；負數的處理未定義。
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *digits1;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *digits2;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *answerDigits;

+ (instancetype)solutionForProblem:(ArithmeticProblem *)problem;

@end

NS_ASSUME_NONNULL_END

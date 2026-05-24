#import "AdditionHintView.h"
#import "ArithmeticProblem.h"
#import "ArithmeticSolution.h"

@interface AdditionHintView ()
@property (nonatomic, strong) UIView *gridContainer;
@property (nonatomic, strong) NSMutableArray<UIView *> *managedSubviews;
@property (nonatomic, strong) ArithmeticSolution *solution;
@end

@implementation AdditionHintView

#pragma mark - Setup

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // §1.1 奶油白底
        self.backgroundColor = [UIColor colorWithRed:1.00 green:0.98 blue:0.94 alpha:1.0];
        self.layer.cornerRadius = 24.0;
        self.layer.masksToBounds = YES;

        _gridContainer = [[UIView alloc] init];
        _gridContainer.backgroundColor = [UIColor clearColor];
        [self addSubview:_gridContainer];

        _managedSubviews = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public API

- (void)configureWithProblem:(ArithmeticProblem *)problem {
    if (![problem.operatorSymbol isEqualToString:@"+"]) {
        // 非加法：先清空，由 Phase 3 的 SubtractionHintView 接手。
        [self clearGrid];
        return;
    }

    self.solution = [ArithmeticSolution solutionForProblem:problem];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.solution) return;

    [self clearGrid];

    // ---- Geometry ---------------------------------------------------------
    // 進位字串可能比 maxLength 多 1 個字元（最高位再向左進位）。
    NSInteger carryLen = (NSInteger)self.solution.carries.length;
    NSInteger answerLen = (NSInteger)self.solution.answerDigits.count;
    NSInteger digitsLen = self.solution.maxLength;

    // 直式總欄數 = 答案位數 (含可能多一位的最高進位) 或進位列長度 取大。
    NSInteger totalCols = MAX(answerLen, MAX(carryLen, digitsLen));
    // 加號要再佔一欄（在最左邊）。
    NSInteger gridCols = totalCols + 1;

    // 5 列：carry / num1 / op+num2 / separator / answer
    NSInteger gridRows = 5;

    CGFloat availableW = CGRectGetWidth(self.bounds) - 32.0; // 左右各 16pt margin
    CGFloat availableH = CGRectGetHeight(self.bounds) - 32.0;
    CGFloat cellW = MIN(availableW / (CGFloat)gridCols, 86.0);
    CGFloat cellH = MIN(availableH / (CGFloat)gridRows, 96.0);
    cellW = MAX(cellW, 44.0);
    cellH = MAX(cellH, 56.0);

    CGFloat gridW = cellW * gridCols;
    CGFloat gridH = cellH * gridRows;

    self.gridContainer.frame = CGRectMake((CGRectGetWidth(self.bounds) - gridW) * 0.5,
                                          (CGRectGetHeight(self.bounds) - gridH) * 0.5,
                                          gridW, gridH);

    // 列號定義
    NSInteger rowCarry = 0;
    NSInteger rowNum1  = 1;
    NSInteger rowNum2  = 2;
    NSInteger rowSep   = 3;
    NSInteger rowAns   = 4;

    // 把答案 / 運算元 / 進位都靠右對齊到 gridCols。
    // 第 0 欄留給運算符；數字從第 1 欄起。
    // 對應「直式從右到左」：最右邊欄位 index 是 gridCols - 1，最左數字欄 index 是 1。

    UIFont *numberFont = [self roundedMonospacedFontOfSize:cellH * 0.62 weight:UIFontWeightSemibold];
    UIFont *carryFont = [self roundedMonospacedFontOfSize:cellH * 0.42 weight:UIFontWeightBold];
    UIFont *opFont = [self roundedMonospacedFontOfSize:cellH * 0.58 weight:UIFontWeightSemibold];
    UIColor *digitColor = [UIColor colorWithRed:0.24 green:0.18 blue:0.12 alpha:1.0]; // 深棕
    UIColor *answerColor = [UIColor colorWithRed:0.16 green:0.55 blue:0.36 alpha:1.0]; // 沉穩綠

    // 每個數的「原始字串長度」— 用來判斷 padded 後的前導 0 不要畫。
    NSInteger n1OrigLen = (NSInteger)[@(self.solution.problem.number1) stringValue].length;
    NSInteger n2OrigLen = (NSInteger)[@(self.solution.problem.number2) stringValue].length;
    NSInteger ansOrigLen = (NSInteger)[@(self.solution.problem.answer) stringValue].length;

    // ---- Row: number1 (右靠齊) -------------------------------------------
    NSInteger n1Len = (NSInteger)self.solution.digits1.count;
    NSInteger n1Skip = n1Len - n1OrigLen; // 前面這幾位是 padded 0，不畫
    for (NSInteger i = n1Skip; i < n1Len; i++) {
        NSInteger digit = self.solution.digits1[i].integerValue;
        NSInteger col = (gridCols - n1Len) + i;
        [self addDigitCellAtRow:rowNum1 col:col text:[NSString stringWithFormat:@"%ld", (long)digit]
                           font:numberFont color:digitColor cellW:cellW cellH:cellH];
    }

    // ---- Row: number2 + operator -----------------------------------------
    NSInteger n2Len = (NSInteger)self.solution.digits2.count;
    NSInteger n2Skip = n2Len - n2OrigLen;
    for (NSInteger i = n2Skip; i < n2Len; i++) {
        NSInteger digit = self.solution.digits2[i].integerValue;
        NSInteger col = (gridCols - n2Len) + i;
        [self addDigitCellAtRow:rowNum2 col:col text:[NSString stringWithFormat:@"%ld", (long)digit]
                           font:numberFont color:digitColor cellW:cellW cellH:cellH];
    }
    // 加號放在 number2 列、最左欄
    [self addDigitCellAtRow:rowNum2 col:0 text:@"+" font:opFont color:digitColor
                       cellW:cellW cellH:cellH];

    // ---- Row: carries -----------------------------------------------------
    // carries 字串左端對應「最高欄位再往左一欄」（finalCarry 情境）。
    // 因此 carries[i] 對應到的 col = (gridCols - carryLen) + i。
    for (NSInteger i = 0; i < carryLen; i++) {
        unichar c = [self.solution.carries characterAtIndex:i];
        if (c == ' ') continue;
        NSInteger col = (gridCols - carryLen) + i;
        // 顏色循環（§1.1 六色，這裡用第 0、2、4 色給進位點綴）
        NSInteger colorIdx = (carryLen - 1 - i) % 6;
        UIColor *capColor = [self candyColorAtIndex:colorIdx];
        [self addCarryCapAtRow:rowCarry col:col text:[NSString stringWithFormat:@"%C", c]
                          font:carryFont color:capColor cellW:cellW cellH:cellH];
    }

    // ---- Row: separator ---------------------------------------------------
    [self addSeparatorAtRow:rowSep fromCol:0 toCol:gridCols - 1 cellW:cellW cellH:cellH];

    // ---- Row: answer (右靠齊) ---------------------------------------------
    NSInteger ansLen = (NSInteger)self.solution.answerDigits.count;
    NSInteger ansSkip = ansLen - ansOrigLen;
    for (NSInteger i = ansSkip; i < ansLen; i++) {
        NSInteger digit = self.solution.answerDigits[i].integerValue;
        NSInteger col = (gridCols - ansLen) + i;
        [self addDigitCellAtRow:rowAns col:col text:[NSString stringWithFormat:@"%ld", (long)digit]
                           font:numberFont color:answerColor cellW:cellW cellH:cellH];
    }
}

- (void)clearGrid {
    for (UIView *v in self.managedSubviews) {
        [v removeFromSuperview];
    }
    [self.managedSubviews removeAllObjects];
}

#pragma mark - Cell builders

- (CGRect)frameForRow:(NSInteger)row col:(NSInteger)col cellW:(CGFloat)w cellH:(CGFloat)h {
    return CGRectMake(col * w, row * h, w, h);
}

- (void)addDigitCellAtRow:(NSInteger)row col:(NSInteger)col text:(NSString *)text
                     font:(UIFont *)font color:(UIColor *)color cellW:(CGFloat)w cellH:(CGFloat)h {
    UILabel *l = [[UILabel alloc] initWithFrame:[self frameForRow:row col:col cellW:w cellH:h]];
    l.text = text;
    l.textColor = color;
    l.font = font;
    l.textAlignment = NSTextAlignmentCenter;
    [self.gridContainer addSubview:l];
    [self.managedSubviews addObject:l];
}

- (void)addCarryCapAtRow:(NSInteger)row col:(NSInteger)col text:(NSString *)text
                    font:(UIFont *)font color:(UIColor *)color cellW:(CGFloat)w cellH:(CGFloat)h {
    // 「進位帽」：糖果色圓底 + 白字。視覺上像數字頭頂戴的小帽子。
    CGRect cellFrame = [self frameForRow:row col:col cellW:w cellH:h];
    // 把帽子放在 cell 的下緣（更靠近 number1 那一列）
    CGFloat capDiameter = MIN(cellFrame.size.width, cellFrame.size.height) * 0.72;
    CGRect capFrame = CGRectMake(CGRectGetMidX(cellFrame) - capDiameter * 0.5,
                                  CGRectGetMaxY(cellFrame) - capDiameter,
                                  capDiameter, capDiameter);
    UIView *cap = [[UIView alloc] initWithFrame:capFrame];
    cap.backgroundColor = color;
    cap.layer.cornerRadius = capDiameter * 0.5;
    // 軟陰影
    cap.layer.shadowColor = color.CGColor;
    cap.layer.shadowOpacity = 0.35;
    cap.layer.shadowRadius = 4.0;
    cap.layer.shadowOffset = CGSizeMake(0, 2);

    UILabel *digitLabel = [[UILabel alloc] initWithFrame:cap.bounds];
    digitLabel.text = text;
    digitLabel.font = font;
    digitLabel.textColor = [UIColor whiteColor];
    digitLabel.textAlignment = NSTextAlignmentCenter;
    [cap addSubview:digitLabel];

    [self.gridContainer addSubview:cap];
    [self.managedSubviews addObject:cap];
}

- (void)addSeparatorAtRow:(NSInteger)row fromCol:(NSInteger)c0 toCol:(NSInteger)c1
                    cellW:(CGFloat)w cellH:(CGFloat)h {
    CGFloat x = c0 * w + w * 0.15;
    CGFloat width = (c1 - c0 + 1) * w - w * 0.30;
    CGFloat y = row * h + h * 0.30;
    CGFloat thickness = 4.0;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, thickness)];
    line.backgroundColor = [UIColor colorWithRed:0.24 green:0.18 blue:0.12 alpha:1.0];
    line.layer.cornerRadius = thickness * 0.5;
    [self.gridContainer addSubview:line];
    [self.managedSubviews addObject:line];
}

#pragma mark - Style helpers

- (UIFont *)roundedMonospacedFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont *base = [UIFont monospacedDigitSystemFontOfSize:size weight:weight];
    UIFontDescriptor *desc = [base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    if (desc) {
        return [UIFont fontWithDescriptor:desc size:size];
    }
    return base;
}

- (UIColor *)candyColorAtIndex:(NSInteger)index {
    // §1.1 的 6 色循環
    static NSArray<UIColor *> *colors = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        colors = @[
            [UIColor colorWithRed:1.00 green:0.56 blue:0.64 alpha:1.0], // 粉紅
            [UIColor colorWithRed:1.00 green:0.72 blue:0.38 alpha:1.0], // 南瓜橘
            [UIColor colorWithRed:1.00 green:0.85 blue:0.24 alpha:1.0], // 蛋黃
            [UIColor colorWithRed:0.48 green:0.83 blue:0.54 alpha:1.0], // 薄荷綠
            [UIColor colorWithRed:0.37 green:0.77 blue:0.90 alpha:1.0], // 天藍
            [UIColor colorWithRed:0.71 green:0.55 blue:1.00 alpha:1.0], // 薰衣草紫
        ];
    });
    return colors[((index % colors.count) + colors.count) % colors.count];
}

@end

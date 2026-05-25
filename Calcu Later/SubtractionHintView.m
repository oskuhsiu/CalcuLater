#import "SubtractionHintView.h"
#import "ArithmeticProblem.h"
#import "ArithmeticSolution.h"
#import "ChildUIKit.h"

@interface SubtractionHintView ()
@property (nonatomic, strong, readwrite) UIView *gridContainer;
@property (nonatomic, strong) NSMutableArray<UIView *> *managedSubviews;
@property (nonatomic, strong) NSMutableArray<CALayer *> *managedLayers;
@property (nonatomic, strong) ArithmeticSolution *solution;
@end

@implementation SubtractionHintView

#pragma mark - Setup

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = ChildUI.creamBackground;
        self.layer.cornerRadius = 24.0;
        self.layer.masksToBounds = YES;

        _gridContainer = [[UIView alloc] init];
        _gridContainer.backgroundColor = [UIColor clearColor];
        [self addSubview:_gridContainer];

        _managedSubviews = [NSMutableArray array];
        _managedLayers = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public API

- (BOOL)configureWithProblem:(ArithmeticProblem *)problem {
    BOOL applicable = [problem.operatorSymbol isEqualToString:@"-"]
                       && problem.number1 >= 0
                       && problem.number2 >= 0
                       && problem.number1 >= problem.number2;
    if (!applicable) {
        self.solution = nil;
        [self clearGrid];
        return NO;
    }

    ArithmeticSolution *sol = [ArithmeticSolution solutionForProblem:problem];
    if (!sol.isValid) {
        self.solution = nil;
        [self clearGrid];
        return NO;
    }
    self.solution = sol;
    [self setNeedsLayout];
    [self layoutIfNeeded];
    return YES;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.solution) return;

    [self clearGrid];

    NSInteger digitsLen = self.solution.maxLength;
    NSInteger answerLen = (NSInteger)self.solution.answerDigits.count;
    NSInteger totalCols = MAX(answerLen, digitsLen);
    NSInteger gridCols = totalCols + 1;  // 第 0 欄留給 `-`

    // 6 列：afterBorrowing / afterLending / original / op+num2 / separator / answer
    NSInteger gridRows = 6;

    CGFloat availableW = CGRectGetWidth(self.bounds) - 32.0;
    CGFloat availableH = CGRectGetHeight(self.bounds) - 32.0;
    if (availableW <= 0 || availableH <= 0) {
        self.gridContainer.frame = CGRectZero;
        return;
    }
    CGFloat cellW = MIN(availableW / (CGFloat)gridCols, 84.0);
    CGFloat cellH = MIN(availableH / (CGFloat)gridRows, 80.0);
    cellW = MAX(cellW, 44.0);
    cellH = MAX(cellH, 48.0);

    CGFloat gridW = cellW * gridCols;
    CGFloat gridH = cellH * gridRows;

    self.gridContainer.frame = CGRectMake((CGRectGetWidth(self.bounds) - gridW) * 0.5,
                                          (CGRectGetHeight(self.bounds) - gridH) * 0.5,
                                          gridW, gridH);

    NSInteger rowAfterBorrowing = 0;
    NSInteger rowAfterLending = 1;
    NSInteger rowOriginal = 2;
    NSInteger rowOpNum2 = 3;
    NSInteger rowSep = 4;
    NSInteger rowAns = 5;

    UIFont *numberFont = [ChildUI roundedMonoFontOfSize:cellH * 0.62 weight:UIFontWeightSemibold];
    UIFont *smallFont = [ChildUI roundedMonoFontOfSize:cellH * 0.40 weight:UIFontWeightBold];
    UIFont *opFont = [ChildUI roundedMonoFontOfSize:cellH * 0.58 weight:UIFontWeightSemibold];
    UIColor *digitColor = ChildUI.brownText;
    UIColor *answerColor = ChildUI.calmGreen;

    NSInteger n1OrigLen = (NSInteger)[@(self.solution.problem.number1) stringValue].length;
    NSInteger n2OrigLen = (NSInteger)[@(self.solution.problem.number2) stringValue].length;
    NSInteger ansOrigLen = (NSInteger)[@(self.solution.problem.answer) stringValue].length;

    // ---- number1 三層 (rows 0/1/2) ----------------------------------------
    NSInteger n1Len = (NSInteger)self.solution.digits1.count;
    NSInteger n1Skip = n1Len - n1OrigLen;
    NSArray<BorrowInfo *> *borrows = self.solution.borrows;
    BOOL hasAnyBorrow = NO;
    for (BorrowInfo *b in borrows) {
        if (b.afterBorrowing || b.afterLending) { hasAnyBorrow = YES; break; }
    }

    for (NSInteger i = n1Skip; i < n1Len; i++) {
        NSInteger col = (gridCols - n1Len) + i;
        BorrowInfo *info = (i < (NSInteger)borrows.count) ? borrows[i] : nil;

        // row 0 — afterBorrowing
        if (info && info.afterBorrowing) {
            NSInteger idx = info.borrowingColorIndex.integerValue;
            UIColor *c = [ChildUI candyColorAtIndex:idx];
            [self addDigitCellAtRow:rowAfterBorrowing col:col text:info.afterBorrowing
                               font:smallFont color:c cellW:cellW cellH:cellH
                       strikethrough:NO];
        }

        // row 1 — afterLending
        if (info && info.afterLending) {
            NSInteger idx = info.lendingColorIndex.integerValue;
            UIColor *base = [ChildUI candyColorAtIndex:idx];
            UIColor *c = [base colorWithAlphaComponent:0.7];
            BOOL strike = (info.afterBorrowing != nil);
            [self addDigitCellAtRow:rowAfterLending col:col text:info.afterLending.stringValue
                               font:smallFont color:c cellW:cellW cellH:cellH
                       strikethrough:strike];
        }

        // row 2 — original
        NSInteger digit = self.solution.digits1[i].integerValue;
        BOOL changed = info && (info.afterBorrowing != nil || info.afterLending != nil);
        UIColor *origColor = changed ? [digitColor colorWithAlphaComponent:0.5] : digitColor;
        [self addDigitCellAtRow:rowOriginal col:col text:[NSString stringWithFormat:@"%ld", (long)digit]
                           font:numberFont color:origColor cellW:cellW cellH:cellH
                   strikethrough:changed];
    }

    // ---- number2 + operator (row 3) ---------------------------------------
    NSInteger n2Len = (NSInteger)self.solution.digits2.count;
    NSInteger n2Skip = n2Len - n2OrigLen;
    for (NSInteger i = n2Skip; i < n2Len; i++) {
        NSInteger digit = self.solution.digits2[i].integerValue;
        NSInteger col = (gridCols - n2Len) + i;
        [self addDigitCellAtRow:rowOpNum2 col:col text:[NSString stringWithFormat:@"%ld", (long)digit]
                           font:numberFont color:digitColor cellW:cellW cellH:cellH
                   strikethrough:NO];
    }
    [self addDigitCellAtRow:rowOpNum2 col:0 text:@"−" font:opFont color:digitColor
                       cellW:cellW cellH:cellH strikethrough:NO];

    // ---- separator (row 4) ------------------------------------------------
    [self addSeparatorAtRow:rowSep fromCol:0 toCol:gridCols - 1 cellW:cellW cellH:cellH];

    // ---- answer (row 5) ---------------------------------------------------
    NSInteger ansLen = (NSInteger)self.solution.answerDigits.count;
    NSInteger ansSkip = ansLen - ansOrigLen;
    for (NSInteger i = ansSkip; i < ansLen; i++) {
        NSInteger digit = self.solution.answerDigits[i].integerValue;
        NSInteger col = (gridCols - ansLen) + i;
        [self addDigitCellAtRow:rowAns col:col text:[NSString stringWithFormat:@"%ld", (long)digit]
                           font:numberFont color:answerColor cellW:cellW cellH:cellH
                   strikethrough:NO];
    }

    // ---- 借出箭頭 -----------------------------------------------------------
    // 每個有 afterLending 的位（j），畫一支朝右下的小箭頭指向 j+1（後者必為借入或繼續借出的位）。
    if (hasAnyBorrow) {
        for (NSInteger j = n1Skip; j < n1Len - 1; j++) {
            BorrowInfo *lender = borrows[j];
            BorrowInfo *next = borrows[j + 1];
            if (!lender.afterLending) continue;
            if (!next.afterLending && !next.afterBorrowing) continue;
            NSInteger col = (gridCols - n1Len) + j;
            NSInteger idx = lender.lendingColorIndex.integerValue;
            UIColor *arrowColor = [ChildUI candyColorAtIndex:idx];
            [self addBorrowArrowFromCol:col cellW:cellW cellH:cellH color:arrowColor];
        }
    }
}

- (void)clearGrid {
    for (UIView *v in self.managedSubviews) {
        [v removeFromSuperview];
    }
    [self.managedSubviews removeAllObjects];
    for (CALayer *l in self.managedLayers) {
        [l removeFromSuperlayer];
    }
    [self.managedLayers removeAllObjects];
}

#pragma mark - Cell builders

- (CGRect)frameForRow:(NSInteger)row col:(NSInteger)col cellW:(CGFloat)w cellH:(CGFloat)h {
    return CGRectMake(col * w, row * h, w, h);
}

- (void)addDigitCellAtRow:(NSInteger)row col:(NSInteger)col text:(NSString *)text
                     font:(UIFont *)font color:(UIColor *)color cellW:(CGFloat)w cellH:(CGFloat)h
            strikethrough:(BOOL)strike {
    CGRect frame = [self frameForRow:row col:col cellW:w cellH:h];
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.text = text;
    l.textColor = color;
    l.font = font;
    l.textAlignment = NSTextAlignmentCenter;
    [self.gridContainer addSubview:l];
    [self.managedSubviews addObject:l];

    if (strike) {
        [self addSoftStrikeOverFrame:frame color:color];
    }
}

- (void)addSoftStrikeOverFrame:(CGRect)frame color:(UIColor *)color {
    // 柔軟刪除線：rounded line cap、稍微傾斜，疊在數字垂直中線位置。
    CGFloat thickness = MAX(2.5, CGRectGetHeight(frame) * 0.06);
    CGFloat inset = CGRectGetWidth(frame) * 0.18;
    CGPoint p0 = CGPointMake(CGRectGetMinX(frame) + inset,
                              CGRectGetMidY(frame) + thickness * 0.4);
    CGPoint p1 = CGPointMake(CGRectGetMaxX(frame) - inset,
                              CGRectGetMidY(frame) - thickness * 0.4);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:p0];
    [path addLineToPoint:p1];
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.path = path.CGPath;
    layer.strokeColor = [color colorWithAlphaComponent:0.85].CGColor;
    layer.lineWidth = thickness;
    layer.lineCap = kCALineCapRound;
    layer.fillColor = [UIColor clearColor].CGColor;
    [self.gridContainer.layer addSublayer:layer];
    [self.managedLayers addObject:layer];
}

- (void)addBorrowArrowFromCol:(NSInteger)col cellW:(CGFloat)w cellH:(CGFloat)h color:(UIColor *)color {
    // 在 lender 的 row 1 (afterLending) 與 row 2 (original) 邊界之上方畫一支朝右下的小箭頭，
    // 指向右鄰位（col+1）上方的 afterBorrowing。
    CGFloat startX = (col + 1) * w - w * 0.10;
    CGFloat startY = 1 * h + h * 0.10;
    CGFloat endX = (col + 1) * w + w * 0.30;
    CGFloat endY = 0 * h + h * 0.55;

    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(startX, startY)];
    CGPoint ctrl = CGPointMake((startX + endX) * 0.5 + w * 0.05, startY - h * 0.10);
    [path addQuadCurveToPoint:CGPointMake(endX, endY) controlPoint:ctrl];

    CAShapeLayer *line = [CAShapeLayer layer];
    line.path = path.CGPath;
    line.strokeColor = color.CGColor;
    line.lineWidth = MAX(2.0, w * 0.045);
    line.lineCap = kCALineCapRound;
    line.fillColor = [UIColor clearColor].CGColor;
    [self.gridContainer.layer addSublayer:line];
    [self.managedLayers addObject:line];

    // 箭頭頭
    CGFloat headLen = MAX(7.0, w * 0.18);
    CGFloat dx = endX - ctrl.x;
    CGFloat dy = endY - ctrl.y;
    CGFloat angle = atan2(dy, dx);
    CGFloat a1 = angle + M_PI - M_PI / 6.0;
    CGFloat a2 = angle + M_PI + M_PI / 6.0;
    UIBezierPath *head = [UIBezierPath bezierPath];
    [head moveToPoint:CGPointMake(endX + headLen * cos(a1), endY + headLen * sin(a1))];
    [head addLineToPoint:CGPointMake(endX, endY)];
    [head addLineToPoint:CGPointMake(endX + headLen * cos(a2), endY + headLen * sin(a2))];
    CAShapeLayer *headLayer = [CAShapeLayer layer];
    headLayer.path = head.CGPath;
    headLayer.strokeColor = color.CGColor;
    headLayer.lineWidth = MAX(2.0, w * 0.045);
    headLayer.lineCap = kCALineCapRound;
    headLayer.lineJoin = kCALineJoinRound;
    headLayer.fillColor = [UIColor clearColor].CGColor;
    [self.gridContainer.layer addSublayer:headLayer];
    [self.managedLayers addObject:headLayer];
}

- (void)addSeparatorAtRow:(NSInteger)row fromCol:(NSInteger)c0 toCol:(NSInteger)c1
                    cellW:(CGFloat)w cellH:(CGFloat)h {
    CGFloat x = c0 * w + w * 0.15;
    CGFloat width = (c1 - c0 + 1) * w - w * 0.30;
    CGFloat y = row * h + h * 0.30;
    CGFloat thickness = 4.0;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, thickness)];
    line.backgroundColor = ChildUI.brownText;
    line.layer.cornerRadius = thickness * 0.5;
    [self.gridContainer addSubview:line];
    [self.managedSubviews addObject:line];
}

@end

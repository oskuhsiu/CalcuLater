#import "MultiplicativeWrittenWorkView.h"
#import <QuartzCore/QuartzCore.h>
#import "ChildUIKit.h"
#import <math.h>

@interface MTPWrittenLine : NSObject
@property (nonatomic, copy) NSArray<UILabel *> *cells;
@property (nonatomic, strong) UILabel *caption;
@property (nonatomic, strong) UILabel *sign;
@property (nonatomic, assign) BOOL ruleBelow;
@property (nonatomic, assign) BOOL answer;
@property (nonatomic, assign) BOOL dividend;
@property (nonatomic, assign) NSInteger rightmostColumn;
@property (nonatomic, assign) NSInteger rowIndex;
@end
@implementation MTPWrittenLine
@end

@interface MultiplicativeWrittenWorkView ()
@property (nonatomic, strong, readwrite, nullable) MultiplicativeTeachingActionSnapshot *snapshot;
@property (nonatomic, assign, readwrite) CGFloat minimumReadableWidth;
@property (nonatomic, copy, readwrite) NSArray<UILabel *> *answerCellLabels;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *columnCenters;
@property (nonatomic, assign) NSInteger number1;
@property (nonatomic, assign) NSInteger number2;
@property (nonatomic, assign) NSInteger operandStartColumn;
@property (nonatomic, assign) MultiplicativeTeachingOperation operation;
@property (nonatomic, copy) NSArray<UILabel *> *headers;
@property (nonatomic, strong) NSMutableArray<MTPWrittenLine *> *lines;
@property (nonatomic, strong) NSMutableArray<NSValue *> *rules;
@property (nonatomic, strong) UIFont *digitFont;
@property (nonatomic, strong) UIFont *textFont;
@property (nonatomic, strong) UIFont *headerFont;
@property (nonatomic, assign) CGFloat cellWidth;
@property (nonatomic, assign) CGFloat gutter;
@property (nonatomic, assign) NSInteger emphasizedColumn;
@end

@implementation MultiplicativeWrittenWorkView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.whiteColor;
        self.layer.cornerRadius = 18;
        self.accessibilityIdentifier = @"multiplicative.written";
        self.isAccessibilityElement = NO;
        _answerCellLabels = @[]; _columnCenters = @[]; _emphasizedColumn = NSNotFound;
        _lines = [NSMutableArray array]; _rules = [NSMutableArray array];
        [self updateFonts];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textSizeChanged:)
            name:UIContentSizeCategoryDidChangeNotification object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)updateFonts {
    self.digitFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle1]
        scaledFontForFont:[ChildUI roundedMonoFontOfSize:32 weight:UIFontWeightBold]
        compatibleWithTraitCollection:self.traitCollection];
    self.headerFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
        scaledFontForFont:[ChildUI roundedFontOfSize:17 weight:UIFontWeightSemibold]
        compatibleWithTraitCollection:self.traitCollection];
    self.textFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:19 weight:UIFontWeightMedium]
        compatibleWithTraitCollection:self.traitCollection];
    CGFloat headerWidth = ceil([@"百位" sizeWithAttributes:@{NSFontAttributeName:self.headerFont}].width);
    CGFloat digitWidth = ceil([@"8" sizeWithAttributes:@{NSFontAttributeName:self.digitFont}].width);
    self.cellWidth = MAX(headerWidth + 16, digitWidth + 24);
    self.gutter = MAX(38, digitWidth + 18);
    self.minimumReadableWidth = 24 + self.gutter + 3 * self.cellWidth;
}
- (void)textSizeChanged:(NSNotification *)notification { [self updateFonts]; [self rebuild]; }
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![previousTraitCollection.preferredContentSizeCategory isEqual:self.traitCollection.preferredContentSizeCategory]) {
        [self updateFonts]; [self rebuild];
    }
}
- (UILabel *)label:(NSString *)text font:(UIFont *)font identifier:(NSString *)identifier {
    UILabel *label = [[UILabel alloc] init];
    label.font = font; label.text = text; label.textColor = ChildUI.brownText;
    label.numberOfLines = 0; label.lineBreakMode = NSLineBreakByWordWrapping;
    label.adjustsFontSizeToFitWidth = NO; label.adjustsFontForContentSizeCategory = YES;
    label.accessibilityIdentifier = identifier;
    [self addSubview:label];
    return label;
}
- (MTPWrittenLine *)addCells:(NSArray<NSString *> *)texts sign:(NSString *)sign identifier:(NSString *)identifier {
    MTPWrittenLine *line = [[MTPWrittenLine alloc] init];
    NSMutableArray<UILabel *> *cells = [NSMutableArray array];
    for (NSUInteger column = 0; column < 3; column++) {
        UILabel *label = [self label:texts[column] font:self.digitFont
            identifier:[identifier stringByAppendingFormat:@".%lu", (unsigned long)column]];
        label.textAlignment = NSTextAlignmentCenter;
        label.isAccessibilityElement = label.text.length > 0;
        [cells addObject:label];
    }
    line.cells = cells;
    line.sign = [self label:sign font:self.digitFont identifier:[identifier stringByAppendingString:@".sign"]];
    line.sign.textAlignment = NSTextAlignmentCenter;
    line.sign.isAccessibilityElement = sign.length > 0;
    line.rightmostColumn = 2; line.rowIndex = NSNotFound;
    [self.lines addObject:line];
    return line;
}
- (void)addCaption:(NSString *)text identifier:(NSString *)identifier {
    MTPWrittenLine *line = [[MTPWrittenLine alloc] init];
    line.caption = [self label:text font:self.textFont identifier:identifier];
    line.cells = @[]; line.rowIndex = NSNotFound;
    [self.lines addObject:line];
}
- (NSArray<NSString *> *)cellsForNumber:(NSInteger)number endingAt:(NSInteger)column {
    NSMutableArray *cells = [@[@"", @"", @""] mutableCopy];
    NSString *digits = [NSString stringWithFormat:@"%ld", (long)number];
    NSInteger first = column - (NSInteger)digits.length + 1;
    // The frozen model guarantees a count fits its real place columns.
    if (number < 0 || first < 0 || column > 2) return cells;
    for (NSUInteger index = 0; index < digits.length; index++) {
        cells[(NSUInteger)first + index] = [digits substringWithRange:NSMakeRange(index, 1)];
    }
    return cells;
}
- (NSArray<NSString *> *)givenCells {
    NSMutableArray<NSString *> *cells = [[self cellsForNumber:self.number1 endingAt:2] mutableCopy];
    for (NSInteger column = 0; column < MIN(3, MAX(0, self.operandStartColumn)); column++) cells[(NSUInteger)column] = @"";
    return cells;
}
- (void)configureWithNumber1:(NSInteger)number1 number2:(NSInteger)number2
                 operation:(MultiplicativeTeachingOperation)operation operandStartColumn:(NSInteger)operandStartColumn
                  snapshot:(MultiplicativeTeachingActionSnapshot *)snapshot {
    self.number1 = number1; self.number2 = number2; self.operation = operation;
    self.operandStartColumn = operandStartColumn; self.snapshot = snapshot;
    self.emphasizedColumn = NSNotFound;
    [self updateFonts]; [self rebuild];
}
- (void)rebuild {
    for (UIView *view in self.subviews.copy) [view removeFromSuperview];
    [self.lines removeAllObjects]; [self.rules removeAllObjects];
    self.answerCellLabels = @[];
    if (!self.snapshot) return;
    NSMutableArray *headers = [NSMutableArray array];
    for (NSUInteger column = 0; column < 3; column++) {
        UILabel *label = [self label:@[@"百位", @"十位", @"個位"][column] font:self.headerFont
            identifier:[NSString stringWithFormat:@"multiplicative.written.column.%lu", (unsigned long)column]];
        label.textAlignment = NSTextAlignmentCenter; label.accessibilityTraits |= UIAccessibilityTraitHeader;
        [headers addObject:label];
    }
    self.headers = headers;
    NSMutableArray<NSString *> *visible = [NSMutableArray array];
    for (NSUInteger column = 0; column < 3; column++) {
        id value = self.snapshot.visibleAnswerDigits[column];
        [visible addObject:[value isKindOfClass:NSNumber.class] ? [value stringValue] : @""];
    }
    if (self.operation == MultiplicativeTeachingOperationMultiplication) {
        NSMutableArray *carry = [NSMutableArray array];
        BOOL any = NO;
        for (NSUInteger column = 0; column < 3; column++) {
            NSUInteger count = self.snapshot.carryUnits[column].count;
            [carry addObject:count ? [NSString stringWithFormat:@"%lu", (unsigned long)count] : @""];
            any |= count > 0;
        }
        if (any) {
            [self addCaption:@"換來的數量已在累積區，以下小記號不是另一份，不再加一次。"
                identifier:@"multiplicative.written.carryNote"];
            MTPWrittenLine *line = [self addCells:carry sign:@"" identifier:@"multiplicative.written.carry"];
            for (UILabel *label in line.cells) label.font = self.headerFont;
        }
        [self addCells:[self givenCells] sign:@"" identifier:@"multiplicative.written.given"];
        MTPWrittenLine *factor = [self addCells:[self cellsForNumber:self.number2 endingAt:2]
            sign:@"×" identifier:@"multiplicative.written.factor"];
        factor.ruleBelow = YES;
        MTPWrittenLine *answer = [self addCells:visible sign:@"" identifier:@"multiplicative.written.answer"];
        answer.answer = YES; self.answerCellLabels = answer.cells;
    } else {
        MTPWrittenLine *answer = [self addCells:visible sign:@"" identifier:@"multiplicative.written.answer"];
        answer.answer = YES; answer.ruleBelow = YES; self.answerCellLabels = answer.cells;
        MTPWrittenLine *dividend = [self addCells:[self givenCells]
            sign:[NSString stringWithFormat:@"%ld", (long)self.number2] identifier:@"multiplicative.written.given"];
        dividend.dividend = YES;
        for (NSUInteger rowIndex = 0; rowIndex < self.snapshot.visibleDivisionRows.count; rowIndex++) {
            MultiplicativeDivisionWorkRow *row = self.snapshot.visibleDivisionRows[rowIndex];
            NSString *unit = @[@"百", @"十", @"一"][(NSUInteger)row.column];
            [self addCaption:[NSString stringWithFormat:@"%ld 個%@ − %ld 個%@，剩 %ld 個%@",
                (long)row.partialCount, unit, (long)row.distributedCount, unit, (long)row.remainderCount, unit]
                identifier:[NSString stringWithFormat:@"multiplicative.written.row.%lu.caption", (unsigned long)rowIndex]];
            self.lines.lastObject.rowIndex = (NSInteger)rowIndex;
            self.lines.lastObject.rightmostColumn = row.column;
            NSArray<NSNumber *> *counts = @[@(row.partialCount), @(row.distributedCount), @(row.remainderCount)];
            for (NSUInteger part = 0; part < counts.count; part++) {
                MTPWrittenLine *line = [self addCells:[self cellsForNumber:counts[part].integerValue endingAt:row.column]
                    sign:part == 1 ? @"−" : @"" identifier:[NSString stringWithFormat:@"multiplicative.written.row.%lu.%lu",
                        (unsigned long)rowIndex, (unsigned long)part]];
                line.rightmostColumn = row.column; line.rowIndex = (NSInteger)rowIndex; line.ruleBelow = part == 1;
            }
        }
    }
    for (NSUInteger column = 0; column < 3; column++) {
        UILabel *label = self.answerCellLabels[column];
        NSString *place = @[@"百位", @"十位", @"個位"][column];
        label.backgroundColor = [ChildUI.skyBlue colorWithAlphaComponent:0.12];
        label.layer.cornerRadius = 8; label.layer.masksToBounds = YES;
        label.isAccessibilityElement = YES;
        label.accessibilityLabel = label.text.length
            ? [NSString stringWithFormat:@"答案%@，%@", place, label.text]
            : [self.snapshot.completedColumns containsIndex:column]
                ? [NSString stringWithFormat:@"答案%@已看過，最前面的 0 留白", place]
                : [NSString stringWithFormat:@"答案%@留白，還沒寫", place];
    }
    if (self.snapshot.visibleRemainder) [self addCaption:[NSString stringWithFormat:@"共同的餘數是 %@，不是每份各剩這麼多。",
        self.snapshot.visibleRemainder] identifier:@"multiplicative.written.remainder"];
    if (self.emphasizedColumn != NSNotFound) [self emphasizeWrittenColumn:self.emphasizedColumn];
    [self setNeedsLayout]; [self invalidateIntrinsicContentSize];
}
- (CGFloat)layoutForWidth:(CGFloat)proposed apply:(BOOL)apply {
    CGFloat width = MAX(self.minimumReadableWidth, proposed);
    CGFloat left = 12 + self.gutter;
    CGFloat cell = (width - left - 12) / 3;
    CGFloat y = 12;
    CGFloat headerHeight = ceil(self.headerFont.lineHeight) + 8;
    NSMutableArray *centers = [NSMutableArray array];
    for (NSUInteger column = 0; column < 3; column++) {
        [centers addObject:@(left + cell * (column + 0.5))];
        if (apply) self.headers[column].frame = CGRectMake(left + cell * column, y, cell, headerHeight);
    }
    if (apply) { self.columnCenters = centers; [self.rules removeAllObjects]; }
    y += headerHeight + 8;
    for (MTPWrittenLine *line in self.lines) {
        if (line.caption) {
            CGFloat height = ceil([line.caption sizeThatFits:CGSizeMake(width - 24, CGFLOAT_MAX)].height);
            if (apply) line.caption.frame = CGRectMake(12, y + 8, width - 24, height);
            y += height + 20;
            continue;
        }
        CGFloat lineHeight = ceil(self.digitFont.lineHeight) + 16;
        for (NSUInteger column = 0; column < 3; column++) {
            if (apply) line.cells[column].frame = CGRectMake(left + cell * column + 3, y, cell - 6, lineHeight);
        }
        if (apply) {
            line.sign.frame = CGRectMake(12, y, self.gutter - 8, lineHeight);
            if (line.dividend) [self.rules addObject:[NSValue valueWithCGRect:CGRectMake(left - 4, y - 5, 2, lineHeight + 5)]];
        }
        y += lineHeight + 4;
        if (line.ruleBelow) {
            if (apply) [self.rules addObject:[NSValue valueWithCGRect:CGRectMake(left - 4, y,
                cell * (line.rightmostColumn + 1) + 4, 2)]];
            y += 10;
        }
    }
    if (apply) [self setNeedsDisplay];
    return y + 12;
}
- (NSInteger)latestRowIndexForColumn:(NSInteger)column {
    MultiplicativeDivisionWorkRow *last = self.snapshot.visibleDivisionRows.lastObject;
    return last && last.column == column ? (NSInteger)self.snapshot.visibleDivisionRows.count - 1 : NSNotFound;
}
- (void)emphasizeWrittenColumn:(NSInteger)column {
    if (column < 0 || column > 2 || self.answerCellLabels.count != 3) return;
    self.emphasizedColumn = column;
    for (UILabel *label in self.answerCellLabels) {
        label.backgroundColor = [ChildUI.skyBlue colorWithAlphaComponent:0.12];
        label.layer.borderWidth = 0; label.accessibilityHint = nil;
    }
    for (MTPWrittenLine *line in self.lines) if (line.rowIndex != NSNotFound) {
        line.caption.backgroundColor = UIColor.clearColor;
        line.caption.accessibilityTraits &= ~UIAccessibilityTraitHeader;
        for (UILabel *label in line.cells) label.backgroundColor = UIColor.clearColor;
    }
    UILabel *cell = self.answerCellLabels[(NSUInteger)column];
    cell.backgroundColor = [ChildUI.eggYolk colorWithAlphaComponent:0.3];
    cell.layer.borderWidth = 2; cell.layer.borderColor = ChildUI.brownText.CGColor;
    cell.accessibilityHint = @"這是這一步比較的位，可以切換動作前和動作後。";
    NSInteger row = [self latestRowIndexForColumn:column];
    if (row == NSNotFound) return;
    for (MTPWrittenLine *line in self.lines) if (line.rowIndex == row) {
        line.caption.backgroundColor = [ChildUI.eggYolk colorWithAlphaComponent:0.2];
        line.caption.accessibilityTraits |= UIAccessibilityTraitHeader;
        for (UILabel *label in line.cells) if (label.text.length)
            label.backgroundColor = [ChildUI.eggYolk colorWithAlphaComponent:0.2];
    }
}
- (CGRect)latestWorkCaptionRectForColumn:(NSInteger)column {
    NSInteger row = [self latestRowIndexForColumn:column];
    if (row == NSNotFound) return CGRectNull;
    for (MTPWrittenLine *line in self.lines) if (line.rowIndex == row && line.caption) return line.caption.frame;
    return CGRectNull;
}
- (CGRect)latestWorkRowRectForColumn:(NSInteger)column {
    NSInteger row = [self latestRowIndexForColumn:column];
    if (row == NSNotFound) return CGRectNull;
    CGRect rect = CGRectNull;
    for (MTPWrittenLine *line in self.lines) if (line.rowIndex == row) {
        if (line.caption) rect = CGRectUnion(rect, line.caption.frame);
        for (UILabel *label in line.cells) rect = CGRectUnion(rect, label.frame);
        if (line.sign.text.length) rect = CGRectUnion(rect, line.sign.frame);
    }
    return rect;
}
- (CGRect)writtenRelationRectForColumn:(NSInteger)column {
    if (column < 0 || column > 2 || self.answerCellLabels.count != 3) return CGRectNull;
    CGRect rect = self.answerCellLabels[(NSUInteger)column].frame;
    CGRect row = [self latestWorkRowRectForColumn:column];
    return CGRectIsNull(row) ? rect : CGRectUnion(rect, row);
}
- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat width = MAX(self.minimumReadableWidth, size.width);
    return CGSizeMake(width, [self layoutForWidth:width apply:NO]);
}
- (CGSize)intrinsicContentSize { return CGSizeMake(self.minimumReadableWidth, UIViewNoIntrinsicMetric); }
- (void)layoutSubviews { [super layoutSubviews]; [self layoutForWidth:self.bounds.size.width apply:YES]; }
- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    [ChildUI.brownText setFill];
    for (NSValue *value in self.rules) UIRectFill(value.CGRectValue);
}
@end

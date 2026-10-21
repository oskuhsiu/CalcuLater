#import "MathConceptView.h"
#import "ChildUIKit.h"
#import <math.h>

// Rendering is bounded independently of the operand sizes. Numeric cards and
// place-value equations are labeled as quantities, never as sample object dots.
static const NSInteger CLMaximumDotGroups = 9;
static const NSInteger CLMaximumDotsPerGroup = 10;
static const NSInteger CLMaximumFractionSegments = 12;

typedef NS_ENUM(NSInteger, CLConceptKind) {
    CLConceptKindEmpty,
    CLConceptKindAddition,
    CLConceptKindSubtraction,
    CLConceptKindGroups,
    CLConceptKindFraction,
    CLConceptKindNumberCards,
    CLConceptKindPlaceValue,
};

typedef NS_ENUM(NSInteger, CLDotRole) {
    CLDotRoleFirst,
    CLDotRoleSecond,
    CLDotRoleRemoved,
    CLDotRoleRemainder,
};

@interface CLConceptDiagramView : UIView
@property (nonatomic) CLConceptKind kind;
@property (nonatomic) NSInteger firstNumber;
@property (nonatomic) NSInteger secondNumber;
@property (nonatomic) NSInteger groupCount;
@property (nonatomic) NSInteger groupSize;
@property (nonatomic) NSInteger remainder;
@property (nonatomic) NSInteger numerator;
@property (nonatomic) NSInteger denominator;
@property (nonatomic, copy) NSArray<NSString *> *cardTitles;
@property (nonatomic, copy) NSArray<NSString *> *cardValues;
@property (nonatomic, copy) NSArray<NSString *> *placeValueLines;
// Geometry is rebuilt on every size change. Also inspectable in native tests.
@property (nonatomic, copy) NSArray<NSValue *> *dotRects;
@property (nonatomic, copy) NSArray<NSNumber *> *dotRoles;
@property (nonatomic, copy) NSArray<NSValue *> *groupRects;
@property (nonatomic, copy) NSArray<NSValue *> *segmentRects;
@property (nonatomic, copy, nullable) NSString *compactSummary;
@end

@implementation CLConceptDiagramView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.isAccessibilityElement = NO;
        self.accessibilityElementsHidden = YES;
        self.userInteractionEnabled = NO;
        _cardTitles = @[]; _cardValues = @[]; _placeValueLines = @[];
        _dotRects = @[]; _dotRoles = @[]; _groupRects = @[]; _segmentRects = @[];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    NSMutableArray<NSValue *> *dots = [NSMutableArray array];
    NSMutableArray<NSNumber *> *roles = [NSMutableArray array];
    NSMutableArray<NSValue *> *groups = [NSMutableArray array];
    NSMutableArray<NSValue *> *segments = [NSMutableArray array];
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    self.compactSummary = nil;
    self.dotRects = @[]; self.dotRoles = @[]; self.groupRects = @[]; self.segmentRects = @[];
    if (width <= 0 || height <= 0) return;

    if (self.kind == CLConceptKindAddition || self.kind == CLConceptKindSubtraction) {
        NSInteger count = self.kind == CLConceptKindAddition ? self.firstNumber + self.secondNumber : self.firstNumber;
        NSInteger columns = MIN(10, MAX(1, count));
        NSInteger rows = MAX(1, (count + columns - 1) / columns);
        if (width < 200 || height < 74) {
            self.compactSummary = [NSString stringWithFormat:@"用數字表示：%ld %@ %ld", (long)self.firstNumber,
                                   self.kind == CLConceptKindAddition ? @"+" : @"−", (long)self.secondNumber];
            [self setNeedsDisplay];
            return;
        }
        CGFloat diameter = MIN(26, (width - 12 - (columns - 1) * 5) / columns);
        CGFloat pitch = diameter + 5;
        CGFloat startX = (width - (columns * pitch - 5)) / 2;
        CGFloat startY = (height - (rows * (diameter + 14) - 14)) / 2;
        for (NSInteger index = 0; index < count; index++) {
            CGRect dot = CGRectMake(startX + index % columns * pitch, startY + index / columns * (diameter + 14), diameter, diameter);
            [dots addObject:[NSValue valueWithCGRect:dot]];
            CLDotRole role = self.kind == CLConceptKindAddition
                ? (index < self.firstNumber ? CLDotRoleFirst : CLDotRoleSecond)
                : (index >= self.firstNumber - self.secondNumber ? CLDotRoleRemoved : CLDotRoleFirst);
            [roles addObject:@(role)];
        }
    } else if (self.kind == CLConceptKindGroups) {
        NSInteger rows = (self.groupSize > 0 ? self.groupCount : 0) + (self.remainder > 0 ? 1 : 0);
        NSInteger columns = MAX(self.groupSize, self.remainder);
        if (rows > 0 && (height < rows * 18 || width < columns * 12 + MAX(0, columns - 1) * 5 + 44)) {
            self.compactSummary = [NSString stringWithFormat:@"用數字表示：%ld 組，每組 %ld%@", (long)self.groupCount, (long)self.groupSize,
                                   self.remainder > 0 ? [NSString stringWithFormat:@"\n另外剩下 %ld", (long)self.remainder] : @""];
            [self setNeedsDisplay];
            return;
        }
        CGFloat rowHeight = MIN(34, height / MAX(1, rows));
        CGFloat diameter = MIN(24, rowHeight - 6);
        diameter = MIN(diameter, (width - 44 - MAX(0, columns - 1) * 5) / MAX(1, columns));
        diameter = MAX(1, diameter);
        CGFloat pitch = diameter + 5;
        CGFloat objectWidth = columns * pitch - 5;
        CGFloat startX = (width - objectWidth) / 2;
        CGFloat startY = (height - rows * rowHeight) / 2;
        for (NSInteger row = 0; row < rows; row++) {
            BOOL leftover = row == self.groupCount;
            NSInteger count = leftover ? self.remainder : self.groupSize;
            CGRect group = CGRectMake(MAX(1, startX - 10), startY + row * rowHeight + 1,
                                      MIN(width - 2, objectWidth + 20), rowHeight - 2);
            [groups addObject:[NSValue valueWithCGRect:group]];
            for (NSInteger column = 0; column < count; column++) {
                CGRect dot = CGRectMake(startX + column * pitch,
                                        startY + row * rowHeight + (rowHeight - diameter) / 2, diameter, diameter);
                [dots addObject:[NSValue valueWithCGRect:dot]];
                [roles addObject:@(leftover ? CLDotRoleRemainder : (row % 2 ? CLDotRoleSecond : CLDotRoleFirst))];
            }
        }
    } else if (self.kind == CLConceptKindFraction) {
        if (width < self.denominator * 18 + 4 || height < 88) {
            self.compactSummary = [NSString stringWithFormat:@"平均分成 %ld 份，選了 %ld 份", (long)self.denominator, (long)self.numerator];
            [self setNeedsDisplay];
            return;
        }
        CGFloat barWidth = MIN(420, MAX(0, width - 4));
        CGFloat barHeight = MIN(76, MAX(1, height - 38));
        CGFloat x = (width - barWidth) / 2;
        CGFloat y = (height - barHeight - 24) / 2;
        CGFloat segmentWidth = barWidth / self.denominator;
        for (NSInteger index = 0; index < self.denominator; index++) {
            [segments addObject:[NSValue valueWithCGRect:CGRectMake(x + index * segmentWidth, y, segmentWidth, barHeight)]];
        }
    }
    self.dotRects = dots; self.dotRoles = roles; self.groupRects = groups; self.segmentRects = segments;
    [self setNeedsDisplay];
}

- (void)drawText:(NSString *)text rect:(CGRect)rect size:(CGFloat)size weight:(UIFontWeight)weight {
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    UIFont *font = [ChildUI roundedMonoFontOfSize:size weight:weight];
    [text drawInRect:rect withAttributes:@{NSFontAttributeName:font,
                                         NSForegroundColorAttributeName:ChildUI.brownText,
                                         NSParagraphStyleAttributeName:paragraph}];
}

- (void)drawRect:(CGRect)rect {
    if (self.compactSummary.length > 0) {
        [self drawText:self.compactSummary rect:CGRectInset(self.bounds, 4, 2) size:18 weight:UIFontWeightMedium];
        return;
    }
    [ChildUI.brownText setStroke];
    for (NSInteger index = 0; index < self.groupRects.count; index++) {
        CGRect group = self.groupRects[index].CGRectValue;
        BOOL leftover = self.remainder > 0 && index == self.groupCount;
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:group cornerRadius:8];
        [[(leftover ? ChildUI.eggYolk : ChildUI.skyBackground) colorWithAlphaComponent:0.35] setFill];
        [path fill];
        [[ChildUI.brownText colorWithAlphaComponent:0.5] setStroke];
        path.lineWidth = 1;
        if (leftover) { CGFloat dashes[] = {4, 3}; [path setLineDash:dashes count:2 phase:0]; }
        [path stroke];
    }
    for (NSInteger index = 0; index < self.dotRects.count; index++) {
        CGRect dot = self.dotRects[index].CGRectValue;
        CLDotRole role = self.dotRoles[index].integerValue;
        UIColor *color = role == CLDotRoleSecond ? ChildUI.skyBlue : ChildUI.pinkAccent;
        if (role == CLDotRoleRemainder) color = ChildUI.eggYolk;
        if (role == CLDotRoleRemoved) color = ChildUI.creamBackground;
        [color setFill];
        [ChildUI.brownText setStroke];
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(dot, 0.75, 0.75)];
        [circle fill]; circle.lineWidth = 1.2; [circle stroke];
        if (role == CLDotRoleRemoved) {
            UIBezierPath *slash = [UIBezierPath bezierPath];
            [slash moveToPoint:CGPointMake(CGRectGetMinX(dot) + 2, CGRectGetMaxY(dot) - 2)];
            [slash addLineToPoint:CGPointMake(CGRectGetMaxX(dot) - 2, CGRectGetMinY(dot) + 2)];
            slash.lineWidth = 2; [slash stroke];
        }
    }
    for (NSInteger index = 0; index < self.segmentRects.count; index++) {
        CGRect segment = self.segmentRects[index].CGRectValue;
        BOOL selected = index < self.numerator;
        [(selected ? ChildUI.mintGreen : ChildUI.creamBackground) setFill];
        UIRectFill(segment);
        [ChildUI.brownText setStroke];
        UIBezierPath *outline = [UIBezierPath bezierPathWithRect:CGRectInset(segment, 0.5, 0.5)];
        outline.lineWidth = 1; [outline stroke];
        // A tick makes selection understandable without color alone.
        if (selected) {
            CGFloat cx = CGRectGetMidX(segment), cy = CGRectGetMidY(segment);
            CGFloat arm = MIN(8, segment.size.width * 0.22);
            UIBezierPath *tick = [UIBezierPath bezierPath];
            [tick moveToPoint:CGPointMake(cx - arm, cy)];
            [tick addLineToPoint:CGPointMake(cx - arm * 0.2, cy + arm * 0.7)];
            [tick addLineToPoint:CGPointMake(cx + arm, cy - arm * 0.7)];
            tick.lineWidth = 2.2; tick.lineCapStyle = kCGLineCapRound; [tick stroke];
        }
        [self drawText:[NSString stringWithFormat:@"%ld", (long)index + 1]
                  rect:CGRectMake(segment.origin.x, CGRectGetMaxY(segment) + 6, segment.size.width, 18)
                  size:13 weight:UIFontWeightMedium];
    }
    if (self.kind == CLConceptKindNumberCards) {
        NSInteger count = self.cardValues.count;
        BOOL stacked = NO;
        for (NSString *value in self.cardValues) if (value.length > 7) stacked = YES;
        CGFloat minimumHeight = stacked ? count * 48 : 76;
        if (self.bounds.size.height < minimumHeight) {
            [self drawText:@"用下方算式看數量" rect:CGRectInset(self.bounds, 4, 2) size:18 weight:UIFontWeightMedium];
            return;
        }
        if (stacked) {
            CGFloat rowHeight = MIN(64, self.bounds.size.height / MAX(1, count));
            CGFloat y = (self.bounds.size.height - count * rowHeight) / 2;
            for (NSInteger index = 0; index < count; index++) {
                CGRect card = CGRectMake(1, y + index * rowHeight + 2, self.bounds.size.width - 2, rowHeight - 4);
                [[[ChildUI candyColorAtIndex:index] colorWithAlphaComponent:0.35] setFill];
                [[UIBezierPath bezierPathWithRoundedRect:card cornerRadius:12] fill];
                [self drawText:self.cardTitles[index] rect:CGRectMake(8, CGRectGetMidY(card) - 12, 76, 24)
                          size:16 weight:UIFontWeightSemibold];
                NSString *value = self.cardValues[index];
                CGFloat valueWidth = MAX(1, card.size.width - 100);
                CGFloat size = MIN(24, MAX(14, valueWidth / MAX(1, value.length) * 1.55));
                [self drawText:value rect:CGRectMake(92, CGRectGetMidY(card) - 16, valueWidth, 32)
                          size:size weight:UIFontWeightBold];
            }
            return;
        }
        CGFloat gap = 8, cardWidth = (self.bounds.size.width - MAX(0, count - 1) * gap) / MAX(1, count);
        CGFloat height = MIN(112, MAX(1, self.bounds.size.height - 4));
        for (NSInteger index = 0; index < count; index++) {
            CGRect card = CGRectMake(index * (cardWidth + gap), (self.bounds.size.height - height) / 2, cardWidth, height);
            [[[ChildUI candyColorAtIndex:index] colorWithAlphaComponent:0.35] setFill];
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:card cornerRadius:16];
            [path fill];
            [[ChildUI.brownText colorWithAlphaComponent:0.35] setStroke]; path.lineWidth = 1; [path stroke];
            [self drawText:self.cardTitles[index] rect:CGRectInset(CGRectMake(card.origin.x, card.origin.y + 12, card.size.width, 24), 4, 0)
                      size:16 weight:UIFontWeightSemibold];
            NSString *value = self.cardValues[index];
            CGFloat size = MIN(28, MAX(14, (cardWidth - 12) / MAX(1, value.length) * 1.55));
            [self drawText:value rect:CGRectInset(CGRectMake(card.origin.x, card.origin.y + 42, card.size.width, height - 44), 4, 0)
                      size:size weight:UIFontWeightBold];
        }
    } else if (self.kind == CLConceptKindPlaceValue) {
        if (self.bounds.size.height < self.placeValueLines.count * 40) {
            [self drawText:[self.placeValueLines componentsJoinedByString:@"\n"]
                      rect:CGRectInset(self.bounds, 4, 2) size:18 weight:UIFontWeightMedium];
            return;
        }
        CGFloat rowHeight = MIN(52, self.bounds.size.height / MAX(1, self.placeValueLines.count));
        CGFloat y = (self.bounds.size.height - rowHeight * self.placeValueLines.count) / 2;
        for (NSInteger index = 0; index < self.placeValueLines.count; index++) {
            CGRect card = CGRectMake(1, y + rowHeight * index + 2, self.bounds.size.width - 2, rowHeight - 4);
            [[[ChildUI candyColorAtIndex:index] colorWithAlphaComponent:0.25] setFill];
            [[UIBezierPath bezierPathWithRoundedRect:card cornerRadius:12] fill];
            [self drawText:self.placeValueLines[index] rect:CGRectMake(card.origin.x + 8, CGRectGetMidY(card) - 14, card.size.width - 16, 30)
                      size:22 weight:UIFontWeightSemibold];
        }
    } else if (self.kind != CLConceptKindEmpty && !self.dotRects.count && !self.segmentRects.count) {
        [self drawText:@"沒有點點，數量是 0" rect:CGRectMake(0, (self.bounds.size.height - 28) / 2, self.bounds.size.width, 56)
                  size:20 weight:UIFontWeightSemibold];
    }
}
@end

@interface MathConceptView ()
@property (nonatomic, strong) UILabel *headlineLabel;
@property (nonatomic, strong) CLConceptDiagramView *diagramView;
@property (nonatomic, strong) UILabel *equationLabel;
@property (nonatomic, strong) UILabel *explanationLabel;
@property (nonatomic) CGFloat lastLayoutWidth;
@end

@implementation MathConceptView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) [self setup];
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) [self setup];
    return self;
}

- (UILabel *)labelWithSize:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [[UILabel alloc] init];
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
                  scaledFontForFont:[ChildUI roundedFontOfSize:size weight:weight]];
    label.adjustsFontForContentSizeCategory = YES;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = ChildUI.brownText;
    label.numberOfLines = 0;
    label.isAccessibilityElement = NO;
    return label;
}

- (void)setup {
    self.backgroundColor = ChildUI.creamBackground;
    self.layer.cornerRadius = 20;
    self.clipsToBounds = YES;
    self.isAccessibilityElement = YES;
    self.accessibilityIdentifier = @"mathConcept.diagram";
    self.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.headlineLabel = [self labelWithSize:21 weight:UIFontWeightSemibold];
    self.equationLabel = [self labelWithSize:27 weight:UIFontWeightBold];
    self.explanationLabel = [self labelWithSize:17 weight:UIFontWeightMedium];
    self.diagramView = [[CLConceptDiagramView alloc] initWithFrame:CGRectZero];
    for (UIView *view in @[self.headlineLabel, self.diagramView, self.equationLabel, self.explanationLabel]) [self addSubview:view];
    [self clearContent];
}

- (CGSize)intrinsicContentSize {
    CGFloat width = self.bounds.size.width > 0 ? self.bounds.size.width : 300;
    return CGSizeMake(UIViewNoIntrinsicMetric, [self sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat outerWidth = isfinite(size.width) && size.width > 24 ? size.width : 300;
    CGFloat width = outerWidth - 24;
    CGFloat textHeight = 0;
    for (UILabel *label in @[self.headlineLabel, self.equationLabel, self.explanationLabel]) {
        textHeight += ceil([label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    }
    // Keep dots >=12pt and leave room for all labels, also at large text sizes.
    return CGSizeMake(outerWidth, MAX(340, 176 + 44 + textHeight));
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.lastLayoutWidth != self.bounds.size.width) {
        self.lastLayoutWidth = self.bounds.size.width;
        [self invalidateIntrinsicContentSize];
    }
    CGFloat width = MAX(0, self.bounds.size.width - 24);
    CGFloat headlineHeight = ceil([self.headlineLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    CGFloat equationHeight = ceil([self.equationLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    CGFloat explanationHeight = ceil([self.explanationLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    self.headlineLabel.frame = CGRectMake(12, 12, width, headlineHeight);
    self.explanationLabel.frame = CGRectMake(12, self.bounds.size.height - 12 - explanationHeight, width, explanationHeight);
    self.equationLabel.frame = CGRectMake(12, CGRectGetMinY(self.explanationLabel.frame) - 4 - equationHeight, width, equationHeight);
    CGFloat diagramTop = CGRectGetMaxY(self.headlineLabel.frame) + 8;
    CGFloat diagramHeight = MAX(0, CGRectGetMinY(self.equationLabel.frame) - 8 - diagramTop);
    self.diagramView.frame = CGRectMake(12, diagramTop, width, diagramHeight);
    [self.diagramView setNeedsLayout];
    [self.diagramView layoutIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.headlineLabel && ![previousTraitCollection.preferredContentSizeCategory
                              isEqualToString:self.traitCollection.preferredContentSizeCategory]) {
        [self invalidateIntrinsicContentSize];
        [self setNeedsLayout];
    }
}

- (void)clearContent {
    self.diagramView.kind = CLConceptKindEmpty;
    self.diagramView.firstNumber = 0; self.diagramView.secondNumber = 0;
    self.diagramView.groupCount = 0; self.diagramView.groupSize = 0; self.diagramView.remainder = 0;
    self.diagramView.numerator = 0; self.diagramView.denominator = 0;
    self.diagramView.cardTitles = @[]; self.diagramView.cardValues = @[]; self.diagramView.placeValueLines = @[];
    self.diagramView.dotRects = @[]; self.diagramView.dotRoles = @[];
    self.diagramView.groupRects = @[]; self.diagramView.segmentRects = @[];
    self.diagramView.compactSummary = nil;
    self.headlineLabel.text = @"一起檢查這道題目";
    self.equationLabel.text = @"";
    self.explanationLabel.text = @"這裡需要正確的乘除算式、20 以內加減或分數。";
    self.accessibilityLabel = self.explanationLabel.text;
    [self.diagramView setNeedsDisplay];
    [self setNeedsLayout];
}

- (void)finishConfigurationWithSummary:(NSString *)summary {
    self.accessibilityLabel = summary;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
    [self.diagramView setNeedsLayout];
    [self.diagramView setNeedsDisplay];
}

- (void)configureNumberCardsWithTitles:(NSArray<NSString *> *)titles values:(NSArray<NSString *> *)values {
    self.diagramView.kind = CLConceptKindNumberCards;
    self.diagramView.cardTitles = titles;
    self.diagramView.cardValues = values;
}

- (BOOL)configureWithNumber1:(NSInteger)a number2:(NSInteger)b operator:(NSString *)symbol answer:(NSInteger)answer remainder:(NSInteger)remainder {
    [self clearContent];
    if (a < 0 || b < 0 || answer < 0 || remainder < 0) return NO;
    BOOL addition = [symbol isEqualToString:@"+"];
    BOOL subtraction = [symbol isEqualToString:@"−"] || [symbol isEqualToString:@"-"];
    BOOL multiplication = [symbol isEqualToString:@"×"] || [symbol isEqualToString:@"*"];
    BOOL division = [symbol isEqualToString:@"÷"] || [symbol isEqualToString:@"/"];
    if (addition || subtraction) {
        BOOL valid = addition ? (a <= 20 && b <= 20 - a && answer == a + b) : (a <= 20 && b <= a && answer == a - b);
        if (!valid || remainder != 0) return NO;
        self.diagramView.kind = addition ? CLConceptKindAddition : CLConceptKindSubtraction;
        self.diagramView.firstNumber = a; self.diagramView.secondNumber = b;
        self.headlineLabel.text = addition ? @"合起來，一起數一數" : @"拿走一些，還剩多少？";
        self.equationLabel.text = [NSString stringWithFormat:@"%ld %@ %ld = %ld", (long)a, addition ? @"+" : @"−", (long)b, (long)answer];
        self.explanationLabel.text = addition
            ? [NSString stringWithFormat:@"先有 %ld，再加 %ld，共 %ld。", (long)a, (long)b, (long)answer]
            : [NSString stringWithFormat:@"原來 %ld，劃掉 %ld，留下 %ld。", (long)a, (long)b, (long)answer];
        [self finishConfigurationWithSummary:[NSString stringWithFormat:@"%@。每個點表示一個。%@", self.equationLabel.text, self.explanationLabel.text]];
        return YES;
    }
    if (multiplication) {
        if (remainder != 0 || (b != 0 && a > NSIntegerMax / b) || a * b != answer) return NO;
        self.headlineLabel.text = [NSString stringWithFormat:@"每組 %ld，共 %ld 組", (long)a, (long)b];
        self.equationLabel.text = [NSString stringWithFormat:@"%ld × %ld = %ld", (long)a, (long)b, (long)answer];
        if (a <= CLMaximumDotsPerGroup && b <= CLMaximumDotGroups) {
            self.diagramView.kind = CLConceptKindGroups;
            self.diagramView.groupCount = b; self.diagramView.groupSize = a;
            self.explanationLabel.text = a == 0 || b == 0 ? @"沒有點點，總數就是 0。" : @"每一排是一組，每個點表示一個。";
        } else if (a > 10 && a <= 999 && b > 0 && b <= 9) {
            self.diagramView.kind = CLConceptKindPlaceValue;
            NSMutableArray<NSString *> *lines = [NSMutableArray array];
            NSMutableArray<NSString *> *parts = [NSMutableArray array];
            for (NSInteger place = 100; place >= 1; place /= 10) {
                NSInteger part = (a / place % 10) * place;
                if (part == 0) continue;
                [lines addObject:[NSString stringWithFormat:@"%ld × %ld = %ld", (long)part, (long)b, (long)(part * b)]];
                [parts addObject:[NSString stringWithFormat:@"%ld", (long)(part * b)]];
            }
            self.diagramView.placeValueLines = lines;
            self.headlineLabel.text = @"拆成百、十、個，再相乘";
            self.explanationLabel.text = [NSString stringWithFormat:@"最後合起來：%@ = %ld", [parts componentsJoinedByString:@" + "], (long)answer];
        } else {
            [self configureNumberCardsWithTitles:@[@"每組", @"組數", @"總數"]
                                          values:@[[NSString stringWithFormat:@"%ld", (long)a], [NSString stringWithFormat:@"%ld", (long)b], [NSString stringWithFormat:@"%ld", (long)answer]]];
            self.explanationLabel.text = @"數量較大，用數字卡表示，不是用點點數。";
        }
        [self finishConfigurationWithSummary:[NSString stringWithFormat:@"%ld 組，每組 %ld，總共 %ld。%@。%@", (long)b, (long)a, (long)answer, self.equationLabel.text, self.explanationLabel.text]];
        return YES;
    }
    if (division) {
        // Quotient/remainder validation avoids overflowing b * answer + remainder.
        if (b == 0 || a / b != answer || a % b != remainder) return NO;
        self.headlineLabel.text = remainder > 0
            ? [NSString stringWithFormat:@"%ld ÷ %ld = %ld 餘 %ld", (long)a, (long)b, (long)answer, (long)remainder]
            : [NSString stringWithFormat:@"%ld ÷ %ld = %ld", (long)a, (long)b, (long)answer];
        self.equationLabel.text = remainder > 0
            ? [NSString stringWithFormat:@"%ld = %ld × %ld + %ld", (long)a, (long)b, (long)answer, (long)remainder]
            : [NSString stringWithFormat:@"%ld = %ld × %ld", (long)a, (long)b, (long)answer];
        if (b <= CLMaximumDotsPerGroup && answer <= CLMaximumDotGroups - (remainder > 0 ? 1 : 0)) {
            self.diagramView.kind = CLConceptKindGroups;
            self.diagramView.groupSize = b; self.diagramView.groupCount = answer; self.diagramView.remainder = remainder;
        } else {
            [self configureNumberCardsWithTitles:@[@"每組", @"完整組", @"剩下"]
                                          values:@[[NSString stringWithFormat:@"%ld", (long)b], [NSString stringWithFormat:@"%ld", (long)answer], [NSString stringWithFormat:@"%ld", (long)remainder]]];
        }
        NSString *remainingText = remainder > 0
            ? [NSString stringWithFormat:@"剩下 %ld，不夠再分一組。", (long)remainder] : @"剛好分完，沒有剩下。";
        self.explanationLabel.text = [NSString stringWithFormat:@"每組 %ld，共 %ld 組。%@", (long)b, (long)answer, remainingText];
        NSString *representation = self.diagramView.kind == CLConceptKindGroups
            ? (remainder > 0 ? @"每個點表示一個，虛線框表示剩下的。" : @"每排是一組，每個點表示一個。")
            : @"數字卡表示每組數量、完整組數和剩下數量，不是點點圖。";
        [self finishConfigurationWithSummary:[NSString stringWithFormat:@"%@。%@。%@%@", self.headlineLabel.text, self.equationLabel.text, self.explanationLabel.text, representation]];
        return YES;
    }
    return NO;
}

- (BOOL)configureWithNumerator:(NSInteger)numerator denominator:(NSInteger)denominator {
    [self clearContent];
    if (denominator <= 0 || numerator < 0 || numerator > denominator) return NO;
    self.headlineLabel.text = @"一個整體，每份一樣大";
    self.equationLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)numerator, (long)denominator];
    self.explanationLabel.text = [NSString stringWithFormat:@"全部 %ld 等份，選了 %ld 份。\n每一份都是 1/%ld。", (long)denominator, (long)numerator, (long)denominator];
    if (denominator <= CLMaximumFractionSegments) {
        self.diagramView.kind = CLConceptKindFraction;
        self.diagramView.numerator = numerator; self.diagramView.denominator = denominator;
    } else {
        [self configureNumberCardsWithTitles:@[@"全部等份", @"選取份數"]
                                      values:@[[NSString stringWithFormat:@"%ld", (long)denominator], [NSString stringWithFormat:@"%ld", (long)numerator]]];
        self.headlineLabel.text = @"等份很多，用數字表示";
    }
    [self finishConfigurationWithSummary:[NSString stringWithFormat:@"把一個整體平均分成 %ld 份，每一份同樣大。選了 %ld 份，表示 %ld 分之 %ld。%@", (long)denominator, (long)numerator, (long)denominator, (long)numerator,
                                         denominator <= CLMaximumFractionSegments ? @"有勾勾的格子是選取的部分。" : @"這裡用數字卡表示份數。"]];
    return YES;
}
@end

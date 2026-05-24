//
//  ArithmeticSolutionTests.m
//  Calcu LaterTests
//
//  Phase 1 — 驗證 carry / borrow 演算法移植正確。
//

#import <XCTest/XCTest.h>
#import "ArithmeticProblem.h"
#import "ArithmeticSolution.h"

@interface ArithmeticSolutionTests : XCTestCase
@end

@implementation ArithmeticSolutionTests

#pragma mark - Helpers

- (ArithmeticProblem *)plus:(NSInteger)a and:(NSInteger)b {
    return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:@"+" answer:a + b];
}

- (ArithmeticProblem *)minus:(NSInteger)a sub:(NSInteger)b {
    return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:@"-" answer:a - b];
}

#pragma mark - Carry tests

- (void)testCarry_NoCarry {
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self plus:12 and:34]];
    // 12 + 34 = 46，無進位
    XCTAssertEqualObjects(s.carries, @"");
}

- (void)testCarry_SingleAtOnes {
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self plus:28 and:47]];
    // 8 + 7 = 15 → 個位產生進位給十位 → 寫在 index 0
    // 2 + 4 + 1 = 7 → 沒有再進位
    // 期望："1 "  （長度 2：index 0='1' / index 1=' '）
    XCTAssertEqualObjects(s.carries, @"1 ");
}

- (void)testCarry_ChainedCarries {
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self plus:99 and:1]];
    // 9+1=10 → 進位給 index 0；9+0+1=10 → 再多生一個 finalCarry
    // 期望："11 "
    XCTAssertEqualObjects(s.carries, @"11 ");
}

- (void)testCarry_TopOnly {
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self plus:80 and:30]];
    // 0+0=0 不進位；8+3=11 → finalCarry='1'
    // 期望："1  "（前導 1 + 兩個空白）
    XCTAssertEqualObjects(s.carries, @"1  ");
}

- (void)testCarry_DifferentLengths {
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self plus:5 and:18]];
    // 對齊後：05 + 18 = 23
    // 5+8=13 → 進位寫到 index 0 = '1'
    // 0+1+1=2 → 無新進位
    // 期望："1 "
    XCTAssertEqualObjects(s.carries, @"1 ");
}

- (void)testCarry_NotForSubtraction {
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self minus:50 sub:23]];
    XCTAssertEqualObjects(s.carries, @"");
}

#pragma mark - Borrow tests

- (void)testBorrow_NoBorrow {
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self minus:48 sub:23]];
    XCTAssertEqual(s.borrows.count, 2);
    for (BorrowInfo *b in s.borrows) {
        XCTAssertNil(b.afterBorrowing);
        XCTAssertNil(b.afterLending);
    }
}

- (void)testBorrow_SimpleSingle {
    // 50 - 27 = 23
    // 個位：0 < 7 → 借入：個位變 "10"；十位借出：5 → 4
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self minus:50 sub:27]];
    XCTAssertEqual(s.borrows.count, 2);

    BorrowInfo *tens = s.borrows[0];
    BorrowInfo *ones = s.borrows[1];

    // 十位借出
    XCTAssertEqualObjects(tens.afterLending, @(4));
    XCTAssertEqualObjects(tens.lendingColorIndex, @(0));
    XCTAssertNil(tens.afterBorrowing);

    // 個位借入
    XCTAssertEqualObjects(ones.afterBorrowing, @"10");
    XCTAssertEqualObjects(ones.borrowingColorIndex, @(0));
    XCTAssertNil(ones.afterLending);
}

- (void)testBorrow_ChainedThroughZero {
    // 102 - 38 = 64
    // 個位 2 < 8：個位借入 → "12"；十位 0 < 1（借出後變 -1）→ 變成 9 並繼續往左
    //   → 百位 1 借出 → 變 0
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self minus:102 sub:38]];
    XCTAssertEqual(s.borrows.count, 3);

    BorrowInfo *hundreds = s.borrows[0];
    BorrowInfo *tens     = s.borrows[1];
    BorrowInfo *ones     = s.borrows[2];

    // 百位：借出 1 → 變 0
    XCTAssertEqualObjects(hundreds.afterLending, @(0));
    XCTAssertEqualObjects(hundreds.lendingColorIndex, @(0));
    XCTAssertNil(hundreds.afterBorrowing);

    // 十位：原本是 0，借出途中 → 變 9
    XCTAssertEqualObjects(tens.afterLending, @(9));
    XCTAssertEqualObjects(tens.lendingColorIndex, @(0));
    XCTAssertNil(tens.afterBorrowing);

    // 個位：借入 → "12"
    XCTAssertEqualObjects(ones.afterBorrowing, @"12");
    XCTAssertEqualObjects(ones.borrowingColorIndex, @(0));
    XCTAssertNil(ones.afterLending);
}

- (void)testBorrow_MultipleEvents_ColorRotation {
    // 設計：產生兩次獨立的借位事件，驗證 colorIndex 會遞增。
    // 8132 - 4365 = 3767
    //   個位 2 < 5  → 借位事件 #0 → 十位 3 → 2，個位變 "12"
    //   十位 (借出後)2 < 6 → 借位事件 #1 → 百位 1 → 0，十位變 "12"
    //   百位 (借出後)0 < 3 → 借位事件 #2 → 千位 8 → 7，百位變 "10"
    //   千位 7 >= 4 ok
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self minus:8132 sub:4365]];
    XCTAssertEqual(s.borrows.count, 4);

    BorrowInfo *thousands = s.borrows[0];
    BorrowInfo *hundreds  = s.borrows[1];
    BorrowInfo *tens      = s.borrows[2];
    BorrowInfo *ones      = s.borrows[3];

    XCTAssertEqualObjects(ones.afterBorrowing, @"12");
    XCTAssertEqualObjects(ones.borrowingColorIndex, @(0));

    XCTAssertEqualObjects(tens.afterBorrowing, @"12");
    XCTAssertEqualObjects(tens.borrowingColorIndex, @(1));
    // 十位也被借出（為了百位的借位事件） → afterLending 必須有值
    XCTAssertEqualObjects(tens.afterLending, @(2));

    XCTAssertEqualObjects(hundreds.afterBorrowing, @"10");
    XCTAssertEqualObjects(hundreds.borrowingColorIndex, @(2));
    XCTAssertEqualObjects(hundreds.afterLending, @(0));

    // 千位只當過借出者
    XCTAssertEqualObjects(thousands.afterLending, @(7));
    XCTAssertNil(thousands.afterBorrowing);
}

- (void)testBorrow_NotForAddition {
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self plus:50 and:27]];
    XCTAssertEqualObjects(s.borrows, @[]);
}

#pragma mark - Digit decomposition

- (void)testDigits_Padding {
    // 5 + 18 = 23 → maxLength = 2 → digits1 應為 [0, 5]
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self plus:5 and:18]];
    XCTAssertEqual(s.maxLength, 2);
    NSArray *expected1 = @[@0, @5];
    NSArray *expected2 = @[@1, @8];
    NSArray *expectedA = @[@2, @3];
    XCTAssertEqualObjects(s.digits1, expected1);
    XCTAssertEqualObjects(s.digits2, expected2);
    XCTAssertEqualObjects(s.answerDigits, expectedA);
}

- (void)testDigits_AnswerLongerThanOperands {
    // 99 + 1 = 100 → answer 比 operand 長 → maxLength 應為 3
    ArithmeticSolution *s = [ArithmeticSolution solutionForProblem:[self plus:99 and:1]];
    XCTAssertEqual(s.maxLength, 3);
    NSArray *expected1 = @[@0, @9, @9];
    NSArray *expected2 = @[@0, @0, @1];
    NSArray *expectedA = @[@1, @0, @0];
    XCTAssertEqualObjects(s.digits1, expected1);
    XCTAssertEqualObjects(s.digits2, expected2);
    XCTAssertEqualObjects(s.answerDigits, expectedA);
}

@end

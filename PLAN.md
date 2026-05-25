# Calcu Later iOS — 兒童計算練習 app 完善計畫

> 目標：讓 iOS 版的「直式計算解答」追上 Android 版的水準，並把 UI 整體改造成 **5~8 歲兒童**喜愛的風格；同時補上基礎運算教學（單位數加減 / 九九乘法）與選擇題答題模式。
> 參考：Android 專案在 `CalcuLaterAndroid/`，repo `https://github.com/oskuhsiu/Calcu-Later`，DeepWiki `https://deepwiki.com/oskuhsiu/Calcu-Later`。
> 撰寫日期：2026-05-24。原 plan file 已遺失，本檔案是重新研究後的替代品。
>
> **重要前提**：目標使用者是 5~8 歲兒童。所有 UI / 文案 / 動畫 / 音效決策都要先過這個鏡頭。Android 版本是工程參考，但**視覺風格不抄 Android**，iOS 要走自己的兒童友善路線。

---

## 0. 現狀總結

### iOS 端（`Calcu Later/Calcu Later/`）

| 檔案 | 行號 | 問題 |
|------|------|------|
| `ArithmeticProblem.h` | 7-10 | 資料模型只有 `number1` / `number2` / `operatorSymbol` / `answer`，沒有進位、借位、部分積、長除法各步等中間步驟資訊。**所有直式解答的根本瓶頸。** |
| `StandardHintView.m` | 35-36, 42-43 | 加減法的提示文字被註解掉（計算邏輯存在但沒寫進 `hintLabel`）。 |
| `StandardHintView.m` | 44-46 | 乘除法無實作（回傳空字串）。 |
| `StandardHintView.m` | 49-54 | `displayDivisionHint()` 是孤立方法，`configureWithProblem:` 沒有呼叫。 |
| `AnimatedHintView.m` | 30-37 | 只顯示「可擴充動畫效果」靜態提示，無實際動畫。 |
| `MultiLayerHintView.m` | — | 是目前**唯一真的能用**的提示，但僅支援加減，且 UI 是單一 `UILabel`，無分行對齊、無顏色強調。 |
| `ViewController.m` | 98-104 | 題目產生寫死成加法（`num1 + num2`），未根據 `SettingsManager` 引入減乘除。 |
| `ViewController.m` | 123 | `cycleHint()` 用 hidden 切換 3 個 HintView，循環順序：無 → Standard → MultiLayer → Animated。三者疊在 `DrawingCanvasView` 上方。 |

### Android 端（追上的目標）

- 加法：彩色「進位數字」上方對齊、邊框高亮。
- 減法：三層借位顯示（借後值 / 貸出值刪除線 / 原值淡出+刪除線），五色循環區分位數。
- Animated 版：用 step 狀態機 + `LaunchedEffect` 逐位揭露，含 fade/scale 動畫。
- 中間資料用 `calculateCarries()` 與 `calculateBorrowInfo()` 在 Composable 內就地產生，輸出 `BorrowInfo` 陣列。
- **乘法、除法的直式步驟 Android 也尚未實作** — 所以 iOS 不必為了追平而做。

### 重要結論

1. iOS 落後最關鍵的不是動畫，是**資料模型**和**分行對齊的網格 UI**。`UILabel` + 單行文字無法重現 Android 那種「上方一排進位、下面一排被減數、再下面一排減數、底下一排借位刪除線」的視覺。
2. 既然 Android 也沒做乘除直式，本計畫**先聚焦加減**，乘除留到後期。
3. 程式碼是 ObjC 老專案，UI 用程式碼建構（看起來不是 Storyboard 主導），且作者註解中已留下「可擴充」字樣 → 重寫提示 view 的成本可接受。

---

## 1. 視覺語言（兒童友善 Design System）

這是所有 UI 階段共用的設計準則，先在這裡定義，後面各 Phase 直接引用。

### 1.1 視覺基調
- **配色**：明亮但溫和的糖果色系。建議 6 色循環（用在借位/進位的位數區分）：
  - `#FF8FA3`（粉紅）、`#FFB860`（南瓜橘）、`#FFD93D`（蛋黃）、`#7BD389`（薄荷綠）、`#5EC5E5`（天藍）、`#B68DFE`（薰衣草紫）
  - 主背景：奶油白 `#FFF9F0` 或淡天藍 `#E8F4FB`
  - 文字：深棕 `#3D2E1F`（不用純黑，較柔和）
- **形狀**：所有按鈕 / 卡片 / 容器 corner radius ≥ 16pt，大元件可到 24-32pt。沒有直角。
- **陰影**：柔軟的 soft shadow（offset 0,4；blur 12；opacity 0.08~0.12），不用銳利的線條。
- **字體**：使用 **SF Rounded** (`UIFont.systemFont(ofSize:..., weight:..., design: .rounded)`)。數字字體必須是 **monospaced rounded**（直式計算對齊要求）。
- **字級**：題目主視覺 ≥ 56pt、按鈕字 ≥ 22pt、輔助文字 ≥ 18pt。

### 1.2 互動與回饋
- **觸控區**：所有按鈕 ≥ 60×60pt，加上按下時的縮放動畫（`scale: 0.92`，spring）。
- **正向回饋**：答對時播放彈跳動畫 + 星星 / confetti 粒子 + 短促鼓勵音效。考慮加入「連續答對」勳章。
- **答錯處理**：**不要紅色叉叉**。改用溫和的搖頭動畫（左右輕晃）+ 一句鼓勵語（「再想想看！」「差一點點～」）。
- **吉祥物（mascot）**：建議引入一個簡單角色（小貓 / 小狐狸 / 小機器人之類），在角落做反應動畫。Phase 6 評估，初期可先用 SF Symbol 動物 icon 代替。
- **音效**：所有按鈕點擊 / 答對 / 答錯 / 翻頁都要有可愛音效。可關閉（設定）。

### 1.3 文案
- **口語化、簡短**：避免「進位」「借位」這類抽象名詞，可用「上樓」「跟鄰居借」之類更直觀的說法（最終文案待設計師 / 教育顧問確認）。
- **稱呼小朋友**：用「你」不要用「使用者」、「請」字儘量少用，多用「來！」「換你了～」等。
- **鼓勵勝過糾正**：永遠先肯定再引導。

### 1.4 動畫原則
- 用 **spring / bounce**，不用線性 fade。
- 每個動畫都要有「彈一下」的感覺（overshoot 約 10-15%）。
- 速度比成人 app 稍慢（讓孩子能跟上），主要動畫 0.4-0.6s。
- 直式解答的逐位揭露：每位之間延遲 0.3-0.5s，每位伴隨輕微 scale bounce。

### 1.5 無障礙
- 字級可放大（Dynamic Type 至少支援到 XL）。
- 高對比模式支援。
- 重要回饋同時用視覺 + 音效（聽障 / 視障考量）。

---

## 2. 教學模型（內容設計）

> 5~8 歲兒童的學習需要分階段，從具體到抽象。本節定義 app 的兩大主結構（教學 vs 刷題）以及各自需要的內容。

### 2.0 兩大主結構：教學 vs 刷題

> **重要架構決策**：app 不再只是「無限刷題」，主畫面要明確分成兩個入口。
> 5~6 歲（剛接觸數學）走「教學」，7~8 歲（已會基本運算、需要熟練）走「刷題」。同一個孩子也可以兩邊都用，看當下需要。

| 區塊 | 教學 (Lessons) | 刷題 (Drills) |
|------|---------------|---------------|
| 內容 | 個位數加減 (Tier 1-3) + 九九乘法表 | 進位加 / 退位減 / 直式 (Tier 4+) |
| 題量 | **有限**、有順序 | **無限隨機** |
| 目的 | 學會概念、初次接觸 | 熟練、計時、累積成就 |
| UX | 結構化（一課一課進）+ 物件圖示 + 動畫教學 | 連續答題、立即回饋、看 hint |
| 進度 | 有「完成度」（例如：99 乘法 81 題完成 X 題） | 無上限，記錄連對 / 答對率 |

主畫面草圖：
```
┌──────────────┐    ┌──────────────┐
│   📘 學一學   │    │  ✏️  練一練   │
│   (Lessons)  │    │   (Drills)   │
│              │    │              │
│ 加法 / 減法  │    │ 加減 / 進退位 │
│ 九九乘法     │    │ 直式 / 混合   │
└──────────────┘    └──────────────┘
```

### 2.1 教學區（Lessons）內容

教學區是**有限、結構化**的內容，每課固定數量題目，做完會解鎖下一課。

**加減教學**（5~7 歲）：
| 課 | 範圍 | 例題 | 教學重點 |
|----|------|------|---------|
| L1 | 5 以內加法 | 2 + 3 | 用點點 / 蘋果具象化，建立數量感 |
| L2 | 10 以內加法 | 4 + 5 | 不進位 |
| L3 | 10 以內減法 | 7 - 3 | 不退位 |
| L4 | 合十法加法 | 8 + 5 = 8+2+3 = 13 | 把第二加數拆成「補十」 + 剩餘 |
| L5 | 破十法減法 | 12 - 5 = 10-5+2 = 7 | 把被減數拆成 10 + 個位，先從 10 減 |

教學區每課含：1) 「先看示範」動畫；2) 練習 N 題（10-15 題）；3) 答對全部後給星星。

**九九乘法表**（7~8 歲）：
- 表格畫面：1×1 ~ 9×9 整齊網格，可按背的進度分組（1-3 一組、4-6 一組、7-9 一組），每組獨立解鎖。
- 練習模式：抽完整 81 題或單一段，答題用選擇題（§2.4）。
- Cell 點下去可播放朗讀「七八五十六」（音檔資產可後做）。
- 進階「直式乘法」屬於刷題區（Phase 9，且 Android 也還沒做）。

### 2.2 刷題區（Drills）內容

刷題區是 app 原本的核心 — **無限產生題目**。難度由設定控制：

| Tier | 範圍 | 例題 | 對應 UI |
|------|------|------|--------|
| D1 | 20 以內加減 (含進退位) | 17 + 8、13 - 6 | 直式 (簡化) 或選擇題 |
| D2 | 100 以內加減 (進退位) | 28 + 47、102 - 38 | **本計畫核心**：直式進位 / 借位 UI (Phase 2-3) |
| D3 | 三位數以上 | 235 + 489 | 同 D2 機制延伸 |
| D4 | 混合 (隨機 D1-D3) | 任意 | — |

刷題區每題答完就接下一題，沒有結束（除非使用者退出）；累積統計（連對、答對率）可選做。

### 2.3 合十法 / 破十法視覺化

Tier 4 與 Tier 5 不適合用直式呈現（直式對小孩來說是符號，合十/破十才是教概念）。建議用獨立的 hint view：

- **合十法**範例 `8 + 5`：
  ```
   8 + 5
       ↙↘
   8 + 2 + 3
   └─┬─┘   │
    10  +  3
       =  13
  ```
- **破十法**範例 `12 - 5`：
  ```
   12 - 5
   ↙↘
  10 + 2 - 5
  └────┬────┘
   (10 - 5) + 2
       5 + 2
       =  7
  ```
- 實作：每一步驟用動畫淡入 + 箭頭從上到下指引；可搭配吉祥物說話氣泡（§1 視覺語言）。

### 2.4 答題模式：手寫 vs 選擇題

> 借鏡小豬錢包的選擇題機制（`cash-playground/CoinLearning/Views/Practice/QuestionRendererView.swift`）。

兩種模式併存，由設定切換（家長或學童自己切）：

| 模式 | 適用 | 流程 |
|------|------|------|
| **選擇題**（新，預設） | 5~7 歲，主要族群 | 顯示題目 + 4 個選項（2×2 grid）→ 點選 → 立即回饋 → 答錯才彈出 hint |
| **手寫計算** | 7~8 歲、進階；或想練書寫 | 顯示題目 + 畫板 → 學童寫直式 / 寫答案 → 自己對答案 / 主動按「看解答」 |

**選擇題的核心好處**（使用者明確指出）：
> 學童可以用選的就知道答案正不正確，錯了才看計算教學。

**Distractor（錯誤選項）生成邏輯**（參考小豬錢包）：
- ±1、±10 的近似值（最常見的計算誤差）
- 把運算符做反（如 5+3 的 distractor 包含 5-3=2）
- 個位/十位顛倒（如 23 寫成 32）
- 多進位 / 少進位（如 28+7 應為 35，distractor 含 25、45）
- 最終隨機打亂順序

**錯題流程**：
1. 第 1 次錯：吉祥物搖頭 + 「再想想看～」+ 留在題目畫面
2. 第 2 次錯：自動彈出對應 hint（合十法 / 破十法 / 直式），按完繼續答
3. 第 3 次錯：直接給答案 + 完整教學 + 下一題

---

## 3. 重構策略

### 3.1 整體決策

- **保留 ObjC**，不重寫成 Swift（風險/收益不合算；老專案的其他部分都是 ObjC）。
- **重寫 HintView 體系**，從 3 個 `UILabel` 包裝 view 改成「網格 cell」式自繪/自排 view。建議引入一個共用 `VerticalLayoutHintView`，它接收結構化的「列陣列」（每列若干 cell，每 cell 有字、顏色、刪除線、邊框等屬性），由 view 自行排版。
- **資料與呈現分離**：擴充 `ArithmeticProblem`，或新增 `ArithmeticSolution` / `ArithmeticStep` 類別承載中間步驟。HintView 只負責畫，不負責算。
- **保持 hint 循環 UI 互動不變**（按鈕循環），但選項從 Android 的設定持久化補齊（之後階段）。

### 3.2 新類別草案

```objc
// ArithmeticSolution.h（新檔，或併入 ArithmeticProblem）

@interface CarryInfo : NSObject
@property (nonatomic, assign) NSInteger digitIndex;   // 0 = 個位
@property (nonatomic, assign) NSInteger carryValue;   // 通常 1，乘法可能更大
@end

@interface BorrowInfo : NSObject
@property (nonatomic, assign) NSInteger digitIndex;
@property (nonatomic, assign) NSInteger originalValue;  // 原本這一位的數字
@property (nonatomic, assign) NSInteger afterBorrow;    // 借完之後變成的數
@property (nonatomic, assign) NSInteger lentOut;        // 借給下位的量（通常 1，被刪除線）
@property (nonatomic, assign) NSInteger colorIndex;     // 0..4 用來上色
@end

@interface ArithmeticSolution : NSObject
@property (nonatomic, strong) ArithmeticProblem *problem;
@property (nonatomic, strong) NSArray<CarryInfo *> *carries;     // 加法用
@property (nonatomic, strong) NSArray<BorrowInfo *> *borrows;    // 減法用
@property (nonatomic, strong) NSArray<NSNumber *> *digits1;      // number1 各位 [個位, 十位, ...]
@property (nonatomic, strong) NSArray<NSNumber *> *digits2;
@property (nonatomic, strong) NSArray<NSNumber *> *answerDigits;

+ (instancetype)solutionForProblem:(ArithmeticProblem *)problem;
@end
```

### 3.3 新 HintView 草案

```
VerticalLayoutHintView (基底，畫網格)
  ├─ AdditionHintView      （加法：進位列 + 兩個加數 + 分隔線 + 答案）
  ├─ SubtractionHintView   （減法：借位三層 + 被減數 + 減數 + 分隔線 + 答案）
  ├─ AnimatedHintView      （改造後，包一個 AdditionHintView 或 SubtractionHintView，
  │                         加上 step 控制 + UIViewPropertyAnimator）
  └─（未來）MultiplicationHintView / DivisionHintView
```

Standard / MultiLayer 兩個老 class 在新體系成形後**刪除**（或保留一個 fallback）。

---

## 4. 工作階段

> 每階段視為一個獨立 PR/commit；做完一階段才動下一階段，避免一次性大爆炸。

### Phase 1 — 資料模型 ✅ **DONE** (2026-05-24)
**範圍**
- 新增 `ArithmeticSolution`、`BorrowInfo` 類別（`carries` 用 `NSString` 直接保留 Android 格式）。
- 實作 `+solutionForProblem:` 內的 carry / borrow 演算法（移植 Android 邏輯）。
- 加上 `digits1` / `digits2` / `answerDigits` / `maxLength`，方便 UI 拆位排版。
- 寫 13 個單元測試覆蓋無進位 / 單進位 / 連鎖進位 / 不同位數 / 答案比運算元多一位 / 無借位 / 單借位 / 借位穿越 0 / 多次借位 colorIndex 循環 / 拒絕跨運算符。

**Done when** — 全部達成
- ✅ `(28, 47, +)` 得到 `carries="1 "`。
- ✅ `(99, 1, +)` 得到 `carries="11 "`（含 finalCarry）。
- ✅ `(102, 38, -)` 得到正確的 `BorrowInfo[]` 序列（hundreds.afterLending=0、tens.afterLending=9、ones.afterBorrowing=@"12"）。
- ✅ 全部 13 個測試綠燈（iPhone 17 / iOS 26.5 模擬器）。

**重要發現**：
> Android 版的 `calculateBorrowInfo` 在「借位穿越 0」時有個資料一致性 bug — `effectiveDigits[j]--` 把 0 變成 -1，視覺顯示 `afterLending = '9'` 但 `effective` 陣列卡在 -1，下一次外層 loop 訪問會誤判為要再借一次。Kotlin 的 `(-1).digitToChar()` 也會 throw，所以這條 path 在 Android 應該從未真正在 prod 觸發（或是因為 Android 端的測試覆蓋不夠）。
> **iOS 端修正**：穿過 0 時 `effective[j] = 9`（數學上：借 10 進來、借 1 出去 → 9）。詳見 `ArithmeticSolution.m` 的註解。
> **TODO**：未來有機會回頭也修一下 Android 版（不影響本計畫進度）。

### Phase 2 — Addition 直式 UI（兒童風格）✅ **DONE** (2026-05-24)
**實作**：`AdditionHintView.h/.m` 取代舊的 `StandardHintView`，消費 `ArithmeticSolution` 在網格座標系統上排版，奶油白底圓角、SF Rounded monospaced 數字、深棕字、糖果色進位帽（軟陰影 + 顏色循環）、沉穩綠答案。視覺於 iPhone 17 / iOS 26.5 模擬器驗證了 4+12、28+47、99+1 三組典型場景。
**未做**：基底 `VerticalLayoutHintView` 抽出延後到 Phase 3 真的需要共用時再做（YAGNI）。
**範圍**
- 實作 `VerticalLayoutHintView` 基底（網格座標系統，**SF Rounded monospaced** 字、cell 對齊、彩色邊框、底線、軟陰影）。
- 套用 §1 視覺語言：糖果色配色、≥ 56pt 數字、圓角 cell、奶油白底。
- 實作 `AdditionHintView`：消費 `ArithmeticSolution.carries`，進位數字用糖果色 + 小圓圈圈住，視覺上像「站在數字頭頂上的小帽子」。
- 把 `ViewController` 的 hint 循環裡的「Standard 加法」換成新版 `AdditionHintView`。

**Done when**
- 兩位數加法、三位數加法、含連續進位都能正確顯示。
- 視覺通過「5~8 歲鏡頭」自我檢查：圓潤、明亮、不會讓孩子覺得「像考試卷」。
- 進位數字用色彩標示得明顯，但不刺眼。

### Phase 3 — Subtraction 直式 UI（含借位，兒童風格）✅ **DONE** (2026-05-24)
**實作**：`SubtractionHintView` 完成，三層借位（借後值、貸出值刪除線、原值淡出+刪除線）+ 6 色循環，ViewController 接上。
**已知問題**：6 列高度 ≤ 48pt 的窄場景（手機橫向）字會擠，layout fallback 把 cellH 撐到 48 最小但**沒實機驗證橫向**。
**未做**：箭頭視覺、毛筆般柔軟刪除線（目前是一般直線）。
**範圍**
- 實作 `SubtractionHintView`：三層借位 + 刪除線 + §1.1 的 6 色循環。
- 借位視覺強化兒童理解：被借走的數字旁邊畫一個小箭頭，象徵「借給隔壁」；刪除線用毛筆般的柔軟線條（非銳利直線）。
- ViewController 接上。

**Done when**
- ✅ `102 - 38`、`1000 - 1`、`50 - 27` 都能正確顯示三層借位。
- ✅ 借位顏色按位數穩定循環。

### Phase 4 — 選擇題答題模式 + Distractor 引擎 ✅ **DONE** (2026-05-24)
**實作**：`DistractorGenerator`、`MultipleChoiceAnswerView`、`QuizPhase` 狀態機與錯題遞進流程都完成，預設為選擇題模式。
**已知缺口**：
- `DistractorGenerator` 的「個位/十位顛倒」與「忘進位」邏輯只對**加減特化**，乘除仍只用 ±1/±10 fallback，對乘法可能太簡單。
- 手寫模式只有畫板和按鈕，**沒有「我寫完了 → 對答案 → 紀錄」的閉環**。
> 這是改變整個 app 主要使用流程的階段。預設模式從「手寫」改為「選擇題」，讓 5~7 歲孩子能立即得到回饋。手寫模式保留供進階使用者選。

**範圍**
- 新增 `DistractorGenerator` 類別：輸入 `ArithmeticProblem`，輸出 3 個迷惑選項。邏輯參考 §2.4：
  - ±1、±10 的近似值
  - 對運算符號做反 (5+3 含 2)
  - 個位/十位顛倒
  - 多進位 / 少進位 / 漏進位
  - 篩去 < 0 或重複的答案
- 寫單元測試：給定典型題目，確認生成的 distractor 集合都是錯誤答案、無重複、有合理難度。
- 新增 `QuizPhase` 狀態機 enum: `questioning` / `feedback(correct, choiceIndex)` / `complete`，搭配 `hintLevel` (0-3) 控制錯題遞進。
- 實作 `MultipleChoiceAnswerView`：4 個選項 2×2 grid，套 §1 視覺語言（大圓角卡片、糖果色邊框、按下 scale 0.92、答對綠 / 答錯柔色搖頭）。
- ViewController 增加「答題模式」設定（手寫 / 選擇題），預設選擇題。
- 答錯流程：
  1. 第 1 次：吉祥物搖頭 + 鼓勵文案，留在題目（不顯示 hint）。
  2. 第 2 次：自動彈出對應 hint（直式 / 合十 / 破十 → Phase 5 才補齊）。
  3. 第 3 次：揭示答案 + 完整教學 + 下一題。

**Done when**
- 預設開啟 app 就是選擇題模式。
- 4 個選項在所有題目下都有效（無重複、無負數）。
- 答錯流程的 3 級遞進可順利走完。
- 切回手寫模式時，原本的畫板與 hint 循環 UI 仍可用。

### Phase 5 — 教學區（Lessons）獨立模組 ⚠️ **PARTIAL** (2026-05-24)
**實作**：主畫面分流（學一學 / 練一練）、`LessonsHomeViewController`、`LessonViewController`、L1-L5 五課可玩、九九乘法表 9×9 網格與分段解鎖、選擇題流程、`LessonProgressStore` 完成度持久化、`MakeBreakTenHintView`（合十/破十合併實作）、**L1-L5「先看示範」開場動畫**（`LessonIntroView`，含「再看一次」/「開始練習」）。
**未做 / 缺口**：
- **L1/L2 具象圖示**：示範動畫已用彩色圓點，但 lesson 內部 hint 仍用「●」黑點，沒有彩色 SF Symbol 圖示池（蘋果、餅乾、小熊…）。
- **九九乘法朗讀音檔未做**：cell 點按播「七八五十六」（§2.1 表格規格）尚無音檔資產與播放邏輯。
- **九九乘法目前沒開場動畫**（直接進答題）— 可選做。
- **星星標準（≥50% 一星 / ≥75% 兩星 / ≥95% 三星）沒寫測試**，也沒和產品 / 教育顧問確認。
> 對應 §2.0 的「學一學」入口。原 app 只有刷題，這階段是**新增**一整個教學區塊，與刷題並列。

**範圍**
- 新增主畫面入口（教學 / 刷題 兩個大按鈕）。
- 教學區架構：`LessonsHomeViewController` → 課程列表（L1-L5 + 九九乘法）→ 單一課程 (`LessonViewController`)。
- 課程資料模型 `Lesson`：含 id、title、icon、題目產生規則、題量、解鎖條件、完成狀態（持久化到 NSUserDefaults / Core Data）。
- **L1-L5 加減課**：
  - 開場「先看示範」動畫（依課別不同，L1 可能是「兩顆蘋果 + 三顆蘋果」具象動畫；L4 是合十法逐步示範；L5 是破十法）。
  - 練習段落 10-15 題、走 §2.4 選擇題流程，答錯三次跳下一題、結束顯示星星。
  - 物件化呈現用一套小圖示（蘋果、星星、餅乾、小熊…），起步用 SF Symbols。
- **合十法 / 破十法 hint view**：`MakeTenHintView` (L4) 與 `BreakTenHintView` (L5)，視覺依 §2.3。Lessons 與 Drills 都會用到（Drills 的 Tier D1 進位加可借用 MakeTen 作為 hint 模式之一）。
- **九九乘法表模組**：
  - 表格畫面：9×9 網格、分段（1-3 / 4-6 / 7-9）解鎖。
  - 練習模式：抽單題或整段，選擇題答題。
  - 表格 cell 點按播放朗讀（音檔資產，可後做）。
- 進度與成就儲存（每課完成度、得到的星星）。

**Done when**
- 主畫面成功分流到「教學」與「刷題」。
- L1-L5 五課全部可玩、各自有示範動畫、各自有完成獎勵。
- 九九乘法表三段都可選、整段答完有獎勵。
- 完成度跨啟動持久化。

### Phase 6 — Animated 直式版（彈跳動畫）⚠️ **PARTIAL** (2026-05-24)
**實作**：`AnimatedHintView` 用 spring 逐位揭露加減直式。**揭露音效已接**（每 2 個 cell 一批播 Tock + 軟 haptic）。
**已知技術債**：
- 取 `hint.subviews.firstObject` 當 grid container（依賴內部結構），如果 `AdditionHintView` / `SubtractionHintView` 之後改變子 view 層級就會壞 — **沒有 API 邊界保護**。
**範圍**
- 把舊 `AnimatedHintView` 改造成「包裝 AdditionHintView / SubtractionHintView + step 控制」。
- 用 `UIViewPropertyAnimator` + spring damping (0.6) 做逐位 **彈跳** 揭露（不是 fade），符合 §1.4 的 Q 感原則。
- 每位揭露時搭配可愛音效（小叮咚 / 彈簧聲）。可設定關閉。
- 處理被中斷情形（使用者再次按提示按鈕跳到下一個 hint 模式時應 cancel 動畫與音效）。

**Done when**
- ✅ 加減兩種都有逐位 spring 揭露動畫。
- ❌ 揭露音效未接。

### Phase 7 — 題目產生器整合（刷題 Tier + 設定）⚠️ **PARTIAL** (2026-05-24)
**實作**：`ProblemGenerator` 重寫完成、`SettingsManager` 含 drill tier / 運算類型 / 答題模式 / 音效開關 / 吉祥物開關等選項、`SettingsViewController` UI 更新，設定能持久化。**`SoundManager` 已實作**，使用 iOS 內建 SystemSoundID + `UINotificationFeedbackGenerator`（無外部音檔資產，零配置），接上答對 / 答錯 / 揭露 / 按鈕點擊。
**已知缺口**：
- **D3 三位數題目視覺驗證缺**：MCQ 卡片字級在大數字（如 1234）上可能擠 — 沒實機/模擬器目視驗證過。
- **設定即時生效體感落差**：理論上 `viewWillAppear` 重抓 settings，但若使用者在設定頁滑動切 drillTier，下一題才會應用，可能有體感落差。
- **`SettingsViewController` 殘留死方法**：`configureProblemSettingCell:`、`showDigitPicker:` 不再被呼叫但仍存在，會出 `-Wunused-function` 之類的雜訊（但不阻擋 build）。
- **音效資產仍是系統內建**：未來想要更可愛的自製音效時，要換成 bundled `.caf` 走 `AVAudioPlayer`。
**範圍**
- 重寫 `ProblemGenerator`（取代 `ViewController.m:98-104` 寫死的 `num1 + num2`），輸入「Drill Tier」+「運算類型」，輸出 `ArithmeticProblem`。
- 實作 §2.2 的 4 個 Drill Tier (D1-D4) 的題目產生規則。
  - 教學區的題目產生規則由 Phase 5 的 `Lesson` 物件各自定義，不走這個 generator。
- 把 `SettingsManager` 對齊新需求：
  - Drill Tier 多選 (D1 20以內 / D2 100以內 / D3 三位數+ / D4 混合)
  - 運算類型開關（加 / 減 / (未來) 乘 / 除）
  - 答題模式（手寫 / 選擇題）
  - 提示模式預設（自動 / 直式 / 合十破十）
  - 音效開關
  - 吉祥物顯示開關
- 更新 `SettingsViewController` UI，套 §1 視覺語言。
- 設定只影響刷題區；教學區固定走 Phase 5 課程內部規則。

**Done when**
- 刷題區設定改變後新題目會用對應 Tier、運算子、答題模式。
- 設定能跨啟動持久化。
- 進位 / 退位刷題能讓使用者選擇 hint 是「直式」或「合十/破十」。

### Phase 8 — UI 全面兒童化（主視覺改造 + 吉祥物）⚠️ **PARTIAL** (2026-05-24)
**實作**：主畫面、題目、選擇題卡片、教學畫面、直式解答視覺已套 §1 視覺語言（糖果色、SF Rounded、圓角、軟陰影），答對 / 答錯回饋動畫。**§8.1 吉祥物決策已定**：選項 B 變體 — 採用自製「教師角色」（chibi 風格小老師，戴眼鏡、拿教鞭、抱書本），不沿用小豬豬。`teacher2.png` 切成 6 張 tile（左欄 portrait / 右欄 desk variant 各 3 frame）放入 `Assets.xcassets/Mascot/`，建立 `MascotView` 含 6 種情緒（idle / happy / thinking / cheering / shake / talking），ViewController 與 MainMenuViewController 已換掉 `hare.fill` 占位。
**未做 / 缺口**：
- **角色未命名、無故事背景**：可以後續和小孩討論取名（小老師、老師姐姐…），決定後寫進文案。
- **教師圖原檔有深色漸層背景**：目前直接用 cornerRadius 切角呈現，沒做去背。若想要乾淨剪影，需要重新生成圖或用 alpha 去背工具處理。
- **Dynamic Type / 高對比 / iPad 適配未驗證**：§1.5、§8 提到的無障礙與 iPad 大畫面排版可能在 11/13 吋上看起來空蕩或元件位置怪。
- 深色模式停用決策未明確寫進 code。
> 這原本是「次要」階段，但因目標族群是 5~8 歲，**升級為核心階段**。建議跟 Phase 4-5 並行進行，讓主畫面、選擇題卡片、基礎教學畫面與直式解答的視覺風格統一。

**範圍**
- 主畫面（題目、答題輸入、繪圖畫板、提示按鈕、設定入口）全部依 §1 視覺語言重做。
- 引入吉祥物（**策略待決定，見下方 §8.1**）。Phase 1-7 期間先用 SF Symbol 占位。
- 加入答對 / 答錯 / 連續答對的回饋動畫與音效。
- 整理 ViewController 的程式碼建構 layout，改用 Auto Layout。
- 評估深色模式（**兒童 app 通常不需要深色模式**，可能直接停用；待確認）。
- iPad 適配（大畫面下吉祥物可以更大、解答可以放更開）。
- Dynamic Type 支援（家長可能放大字級）。

**Done when**
- 整個 app 視覺風格一致，孩子打開不會覺得「像作業」。
- 試玩 5~8 歲兒童時能維持 5 分鐘以上注意力。
- 答對的回饋讓孩子想再做一題。

#### 8.1 吉祥物 / 伴讀角色（決策延後到 Phase 8 啟動時）

**參考來源**：作者另一個兒童 app「小豬錢包」(`/Users/apple/Projects/games/cash-playground`) 已有成熟的伴讀角色實作，可以參考或共用資產。

- **角色名**：錢包小豬（存錢豬擬人化）
- **資產位置**：`cash-playground/CoinLearning/Resources/Assets.xcassets/Mascot/`，6 視角 PNG（front/back/left/right/top/bottom），各含 @1x/@2x/@3x。
- **實作參考**：`cash-playground/CoinLearning/Views/Components/MascotView.swift`（SwiftUI，~150 行）。
- **情緒狀態**：5 種 — `idle`（微浮動）、`happy`（答對放大+跳）、`thinking`（傾斜）、`cheering`（過關大跳）、`talking`（說話擺動）。實作方式是位移/縮放/旋轉的參數化組合，無骨骼動畫。
- **授權**：自製美術，無外部授權限制，可自由改編。
- **平台差異**：來源是 Swift + SwiftUI，Calcu Later 是 ObjC + UIKit → 動畫邏輯需用 `UIView.animateWithDuration:` / `CAAnimation` 重寫，但圖片資產可直接用。

**待決定的角色策略**（Phase 8 啟動時再選）：
- **選項 A — 沿用同一隻錢包小豬**：最快、零美術成本，但小豬背景是錢包，搬到計算 app 會有身份違和。
- **選項 B — 同畫風新角色（推薦）**：請同位美術畫一隻「計算夥伴」（小狐 / 小貓 / 小機器人…），保留小豬錢包的畫風與動畫框架。能建立「兒童 app 家族」品牌感，但需要新的美術產出。
- **選項 C — 抽成共用模組**：把吉祥物抽成 Swift Package 或共用 asset bundle，兩個 app 都依賴；長期最乾淨但前期成本高，且要動到小豬錢包 app。

**Phase 1-7 期間的占位方案**：用 SF Symbol（例如 `figure.child`、`hare.fill`、`pawprint.fill`）放在角落，搭建好「mascot 顯示位置 + 5 種情緒切換」的程式架構，等 Phase 8 確定角色後直接換圖。

### Phase 9 — （選做）直式乘法與除法 ❌ **NOT STARTED** (2026-05-24)
**範圍**
- 乘法：部分積分行 + 進位 + 最終加總。
- 除法：長除法（商上方對齊 / 每步 multiply-down / subtract / bring-down / remainder）。
- 因為 Android 也還沒做，這部份可以反過來幫 Android 探路。

**Done when**
- 至少兩位數 × 一位數、三位數 ÷ 一位數能正確顯示。

---

## 5. 風險與注意事項

1. **`DrawingCanvasView_new.h`** 與 `.backup` 暗示之前有人在重寫畫板。動工前確認哪個是活的，避免改錯檔案。
2. **HintView 與 Canvas 的層疊**：目前是 hidden 切換，新版重寫時可考慮一個容器 view，避免三層 view 都疊在 canvas 上拖累觸控命中測試。
3. **動畫被中斷**：Phase 6 必須處理 cancel，否則切換 hint 模式時會看到殘影。
4. **i18n**：解答顯示文字若混入中英文，注意字寬不一致對齊問題 → 改用 monospace 數字字體（`UIFontDescriptorFeatureSettingsAttribute` / SF Mono）。
5. **單元測試環境**：Phase 1 已驗證 `Calcu LaterTests` target 能跑（iPhone 17 / iOS 26.5）；專案用 Xcode 16 的 `PBXFileSystemSynchronizedRootGroup`，新檔案會自動納入 target，不必改 pbxproj。
6. **Distractor 太簡單 vs 太難**：Phase 4 的 Distractor 生成需要實測，太簡單孩子會隨便選對、太難孩子會挫敗。需要試玩調整。
7. **Phase 4 / 5 範圍可能爆炸**：選擇題模式 + 基礎教學模式都是大功能，必要時可進一步拆分（例如先做 Phase 4 但只支援既有的 Tier 7 直式題目，後續再加 Tier 1-5）。

---

## 6. 與 Codex 協作的點

- **Phase 4 Distractor 邏輯**：Codex 可協助 brainstorming 各種 Tier 對應的「典型錯誤」（教育心理學）。
- **Phase 5 合十法/破十法視覺**：Codex 可協助設計動畫腳本與步驟分解。
- **Phase 6 動畫節奏**：Codex 可以協助估算每位揭露的延遲時間，並參考 Android 的 timing。
- **Phase 9 長除法演算法**：除法直式邏輯較繁複，建議 Phase 9 開工前先和 Codex 對演算法。

---

## 7. 下一步

**進度總覽 (2026-05-24)**

| Phase | 狀態 | 摘要 |
|------|------|------|
| 1 資料模型 | ✅ DONE | 13 測試綠燈、修掉 Android 借位穿 0 bug |
| 2 Addition 直式 | ✅ DONE | `AdditionHintView` 完成 |
| 3 Subtraction 直式 | ✅ DONE | 三層借位 + 6 色循環；橫向 layout 未驗證 |
| 4 選擇題 + Distractor | ✅ DONE | 預設選擇題；乘除 distractor 較弱、手寫閉環缺 |
| 5 教學區 Lessons | ⚠️ PARTIAL | L1-L5 + 九九乘法可玩；開場動畫、具象圖示、朗讀音檔缺 |
| 6 Animated 直式 | ⚠️ PARTIAL | spring 揭露完成；音效未接、API 邊界保護缺 |
| 7 ProblemGenerator + 設定 | ⚠️ PARTIAL | 主功能完成；音效播放未實作 |
| 8 兒童化 UI + 吉祥物 | ⚠️ PARTIAL | 視覺語言已套；吉祥物只是 SF Symbol 占位；無障礙 / iPad 未驗證 |
| 9 直式乘除 | ❌ NOT STARTED | 選做 |

**建議下一步優先順序**（依「影響使用者體感 × 阻擋程度」排）：
1. **吉祥物決策（§8.1 三選一）+ 補齊 5 種情緒**：目前是占位 SF Symbol，每次答題回饋都看得到，影響感受最直接。
2. **音效系統接線（Phase 6/7 共用）**：寫一個 `SoundManager` 包 `AVAudioPlayer`，接 hint 揭露、答對、答錯、按鈕。需要音檔資產（或暫用系統音）。
3. **L1-L5 開場示範動畫**：教學區現在「沒在教學」、直接抽題，違背 Phase 5 設計初衷。
4. **工程清理**：刪 `StandardHintView` / `MultiLayerHintView` / `DrawingCanvasView_new.h` / `.backup`、`SettingsViewController` 死方法；幫 `AnimatedHintView` 加 API 邊界。
5. **測試補洞**：`MakeBreakTenHintView` / `LessonViewController` / `MultiplicationTableViewController` / `MainMenuViewController` 沒測；UI 互動測試（XCUITest）整體缺。
6. **D3 三位數 MCQ 視覺驗證**、橫向 layout 驗證、Dynamic Type / iPad 驗證。
7. **手寫模式對答案閉環**（次要 — 預設使用者用選擇題）。

完整缺口清單見 §10。

---

## 10. 待補項目盤點（2026-05-24）

> 集中列出當前所有已知 gap，供下次開工挑選。已分類整理避免散落在各 phase。

### 10.1 工程清理（低風險、易做）
- 刪 `StandardHintView` 與 `MultiLayerHintView`（§3.1 計畫要刪，仍編譯進專案但已不在 hint 循環，留著當 fallback）。
- 刪 `SettingsViewController` 殘留死方法：`configureProblemSettingCell:`、`showDigitPicker:`。
- 刪 `DrawingCanvasView_new.h` 與 `.backup`（§5.1 歷史包袱）。
- ~~幫 `AnimatedHintView` 加 API 邊界保護~~ ✅ 2026-05-25 修：`AdditionHintView` / `SubtractionHintView` header 公開 `gridContainer` readonly property，`AnimatedHintView` 改用 isKindOfClass 分派而非 `subviews.firstObject`。

### 10.2 音效系統（完全未做）
- `SettingsManager.soundEffectsEnabled` 有 setting 但沒 hook：答對叮、答錯哎、彈跳聲、按鈕音都未實作。
- 需要：`SoundManager` 包 `AVAudioPlayer`、音檔資產（或先用系統音）。
- Phase 6 揭露音效、Phase 1 §1.2 按鈕音、Phase 8 答對 / 答錯回饋音都依賴此系統。

### 10.3 吉祥物（§8.1 決策延後）
- 目前用 SF Symbol `hare.fill` 占位。
- 三選一決策未做：A 沿用小豬豬 / B 同畫風新角色 / C 共用模組。
- 動畫框架只實作 idle / happy / shake 三種半，原規劃 5 種（idle / happy / thinking / cheering / talking）尚缺。

### 10.4 教學內容深度
- **L1-L5「先看示範」開場動畫缺**：每課應有開場動畫（§2.1 規格），目前抽題就直接進選擇題。
- L1/L2 具象圖示（蘋果、餅乾、小熊）只用「●」黑點，沒有彩色 SF Symbol 圖示池。
- 九九乘法朗讀音檔（§2.1 cell 點按播「七八五十六」）未做。
- 星星標準（≥50% 一星 / ≥75% 兩星 / ≥95% 三星）沒寫測試，且沒和產品 / 教育顧問確認。

### 10.5 Drill / 設定
- **手寫模式對答案閉環缺**：目前手寫只是畫板和按鈕，沒有「我寫完了 → 對答案 → 紀錄」流程。
- D3 三位數題目視覺驗證缺：MCQ 卡片字級在大數字（如 1234）上可能擠 — 沒實機 / 模擬器目視驗證。
- 設定變更即時生效體感落差：`viewWillAppear` 重抓 settings，使用者切 drillTier 下一題才生效，可能體感落差。

### 10.6 Distractor 缺口
- 乘除法的 distractor 仍依賴 ±1 / ±10 fallback — 對乘法可能太簡單。
- 「個位/十位顛倒」與「忘進位」邏輯只對加減特化。

### 10.7 無障礙 / 多尺寸（§1.5、§8 未驗證）
- Dynamic Type 至少支援到 XL：未驗證。
- 高對比模式：未驗證。
- iPad 11/13 吋大畫面排版：未驗證，可能看起來空蕩或元件位置怪。
- `SubtractionHintView` 在 6 列高度 ≤ 48pt 的窄場景（手機橫向）字會擠，layout fallback 撐到 48 最小但未實機驗證橫向。

### 10.8 測試覆蓋缺口
- `MakeBreakTenHintView`、`LessonViewController`、`MultiplicationTableViewController`、`MainMenuViewController` 沒測（連 smoke 都沒）。
- UI 互動測試（XCUITest）缺：「點 MCQ → 答對 → 換題」端到端流程未驗證。
- 視覺迴歸測試（snapshot test）整體缺。

### 10.9 文件
- PLAN.md（本檔）Phase 3-8 的「Done when」與實際決策已在本次回寫；後續每完成一階段持續更新即可。
- 沒有 demo screenshot 或試玩記錄。

### 10.10 Phase 9（選做、未開工）
- 直式乘法 hint（部分積分行 + 進位 + 最終加總）。
- 直式長除法 hint（multiply-down / subtract / bring-down / remainder）。

## 11. Bug Bash — 2026-05-25

一次性修掉 code review 找出的 10 個正確性 / 視覺 bug。Build OK。

| # | 檔案 | 問題 | 修法 |
|---|---|---|---|
| 1 | `ViewController.m` | Writing 模式對 ×/÷ 題目完全看不到提示或答案（`showHintForProblem` 與 `AnimatedHintView` 都只判 + / −，`answerLabel` 又永遠 hidden）。 | 新增 `textHintView` + `textHintLabel`：×/÷（與 fallback 情境）顯示「a × b = ans」與分解算式（重複加 / 反向乘）。 |
| 2 | `ViewController.m` / `LessonViewController.m` / `MultipleChoiceAnswerView` | 答對後 0.85s、揭示答案後 2.4s 的 `dispatch_after` 期間 MCQ 按鈕沒 disable，連點會重複觸發 delegate，Lesson 版會把 `questionIndex` 多加。 | MCQ 新增 `- (void)disableAllChoices`；兩個 VC 在 dispatch 前呼叫。`configureWithProblem` 已重設 enable。 |
| 3 | `ViewController.m:applyAnswerModeUI` | 在 writing 模式啟動後切回 MCQ：`mcq` 從未被 `configure`，4 個按鈕沒文字 / 顯示陳舊。 | `applyAnswerModeUI` 當切到 MCQ 模式且有 currentProblem 時補 `configureWithProblem`。 |
| 4 | `DecorativeBackgroundView.m` | `didBuild` guard 讓裝飾只擺一次，旋轉 / Split View / 多工切窗後太陽 / 雲 / 點陣留在舊絕對座標。 | 改用 `builtSize`，size 變動時 clear subviews + rebuild。 |
| 5 | `MultipleChoiceAnswerView.m` | `_touchUp:` 與 `_choiceTapped:` 都掛 `TouchUpInside`，`_touchUp` 0.20s spring 回 identity 會覆蓋 `_correctFeedback` 的 0.30s 放大彈跳。 | `_touchUp:` 只掛 `TouchUpOutside | TouchCancel`；`_correctFeedback` 開頭 `removeAllAnimations` 清乾淨 in-flight 縮小動畫。 |
| 6 | `AnimatedHintView.m` | 取 `hint.subviews.firstObject` 當 grid container，依賴隱性子 view 結構。 | `AdditionHintView` / `SubtractionHintView` header 公開 `gridContainer` readonly；`AnimatedHintView` 改 isKindOfClass 分派。 |
| 7 | `LessonIntroView.m` | `stage.bounds==0` 時遞迴 `dispatch_after` 重試沒上限，pathological layout 會 20Hz 永遠排程。 | 加 `layoutRetryCount` + `kIntroLayoutMaxRetries=10`（≈0.5s）；逾期 log 後呼叫 `lessonIntroDidFinish:` 結束。 |
| 8 | `ViewController.m` | `answerLabel` 永遠 hidden 但 height=28pt + top gap=8pt 撐出 36pt 死空間，小螢幕 hint 區被擠。 | `answerLabel.heightAnchor=0`；`hintHost.top` 改 anchor 到 `problemLabel.bottom + 12`。 |
| 9 | `SettingsViewController.m` | `tableView` 透明但 cell 預設不透明 systemBackground → light mode「白塊雜燴」、dark mode 對比刺眼。 | cell 半透明 white α=0.7、contentView clear，融入薰衣草背景。 |
| 10 | `LessonIntroView.m:startTapped` | `startButton` 沒 disable，0.3s 淡出期間連點兩下會跑兩次 `lessonIntroDidFinish` → 兩條入場動畫 / mcq 重 shuffle。 | `startTapped` / `startButton` + `replayButton` 立即 disable。 |

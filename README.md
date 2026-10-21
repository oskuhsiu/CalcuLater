# Calcu Later

> 給 **5～8 歲兒童**的 iOS 數學練習 app，對齊台灣 108 課綱 G1～G3。

由「梅西老師」(math 諧音) 陪著小朋友練計算：學一學（教學）、練一練（刷題）、想一想（應用題），三個主入口。視覺走兒童友善路線（糖果色、SF Rounded、大圓角、軟陰影、spring 動畫），預設用 4 選 1 選擇題快速回饋，答錯 2 次自動彈出視覺化教學。

---

## 三大主入口

| 入口 | 內容 | 適合 |
|---|---|---|
| 📘 **學一學**（Lessons） | L1～L5 加減課（5 以內 / 10 以內 / 不退位減 / 合十法 / 破十法）+ 九九乘法表（分段解鎖 + TTS 朗讀） | 5～6 歲剛接觸數學 |
| ✏️ **練一練**（Drills） | 20 以內 / 100 以內 / 三位數加減 + 直式進退位視覺化（含 spring 逐位揭露動畫） | 7～8 歲熟練計算 |
| 🤔 **想一想**（Word Problems） | 147 個應用題模板，對齊 108 課綱 G1～G3，含未知數逆推、二步驟、有餘除法、分數識別、單位換算 | 全年齡（按年級選） |

---

## 應用題：對齊 108 課綱 G1～G3

`WordProblemTemplate.m` 共 **147 個模板**，覆蓋以下課綱項目：

### 一年級（G1，42 模板）
- 100 以內加減（不進退位 + 進退位）
- 比較差量題型（「哥哥比弟弟多幾個」）
- **未知數三變體**：
  - 未知數在前（`□ + 5 = 13`）— 加法逆推
  - 未知數在中（`13 − □ = 5`）— 減法找減數
  - 被減數未知（`□ − 5 = 8`）— 減法找被減數

### 二年級（G2，50 模板）
- 1000 以內加減（含進退位）
- 九九乘法
- 量與測量：長度（公分/公尺）、時間（時/分）、重量（公斤/公克）
- 二步驟解題（`a ± b ± c`）

### 三年級（G3，55 模板）
- 10000 以內加減
- 二、三位數 × 一位數乘法
- 除法（整除 + 有餘數）
- 分數初步（真分數識別）
- 單位換算（時/分/秒、公里/公尺/公分、公斤/公克、公升/毫升）

### 題型特殊渲染
| 題型 | 等式面板顯示 | 內部計算 |
|---|---|---|
| 標準 | `28 + 47 = ?` | `a OP b = ans` |
| 未知數在前 | `? + 5 = 13` | `13 − 5 = 8` |
| 未知數在中 | `13 − ? = 5` | `13 − 5 = 8` |
| 被減數未知 | `? − 5 = 8` | `5 + 8 = 13` |
| 二步驟 | `100 − 30 − 20 = ?` | 中間結果驗證 > 0 |
| 有餘除法 | `23 ÷ 4 = 5⋯3 顆` | 只問商 |
| 分數識別 | `答案：1/4` | MCQ 走字串模式 |

---

## 工程概覽

### 平台與框架
- iOS（Objective-C + UIKit；Xcode 16 file-system synchronized groups）
- 程式建構 layout（無 Storyboard）；最小支援版本見 `Info.plist`
- 鎖定淺色模式（`UIUserInterfaceStyle = Light`，兒童 app 不需深色）

### 主要模組
```
Calcu Later/
├── 資料模型
│   ├── ArithmeticProblem        標準算式
│   ├── ArithmeticSolution       直式步驟（含 carry/borrow）
│   ├── WordProblem              應用題（含 missingAddend/Subtrahend/Minuend、二步驟、分數）
│   ├── WordProblemTemplate      題型模板 + Catalog
│   └── WordProblemGenerator     隨機抽題 + 約束驗證
│
├── 視覺化提示（HintView）
│   ├── AdditionHintView         加法直式（彩色進位帽）
│   ├── SubtractionHintView      減法直式（三層借位 + 6 色循環）
│   ├── AnimatedHintView         spring 逐位揭露 + 音效
│   └── MakeBreakTenHintView     合十法 / 破十法
│
├── 答題介面
│   ├── MultipleChoiceAnswerView 4 選 1（整數 + 字串雙模式）
│   ├── DistractorGenerator      錯誤選項生成（含 fraction 分支、auxiliary 強制干擾）
│   └── DrawingCanvasView        手寫板
│
├── 三大入口 ViewController
│   ├── MainMenuViewController
│   ├── LessonsHomeViewController + LessonViewController + LessonProgressStore
│   ├── ViewController（刷題）
│   └── WordProblemHomeViewController + WordProblemViewController
│
├── 系統
│   ├── SettingsManager / SettingsViewController
│   ├── SoundManager（SystemSoundID + UINotificationFeedbackGenerator）
│   ├── MascotView（梅西老師，6 種情緒）
│   └── ChildUIKit（共用視覺常數）
```

### 設計取捨

1. **內部 op 與顯示 op 分離**：missing minuend 內部 `op="+"` 但等式顯示為減法 — 教孩子加減互逆。
2. **二步驟只支援 + / −**（同優先級）：避開「先乘除後加減」對 G2 的認知過早。
3. **二步驟 MCQ 必含 intermediate**：透過 `ArithmeticProblem.auxiliaryDistractor` 鎖定「忘了第二步」的典型錯誤。
4. **有餘除法只問商**：餘數在等式面板顯示但不出選項，避免 distractor 邏輯混亂。
5. **分數只做識別**：MCQ 改走 `configureWithChoiceTitles:correctIndex:` 字串模式（同分母加減未做，需擴展 model）。
6. **MCQ 字串模式與整數模式並存**：`explicitCorrectIndex == NSNotFound` 時走舊整數比對；否則用 index 比對。

---

## 開發

### Build

```bash
xcodebuild -project "Calcu Later.xcodeproj" -scheme "Calcu Later" \
  -sdk iphonesimulator -configuration Debug \
  -destination 'generic/platform=iOS Simulator' build
```

### Tests

```bash
xcodebuild test -project "Calcu Later.xcodeproj" -scheme "Calcu Later" \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

主要測試套件：

| Suite | 數量 | 涵蓋 |
|---|---|---|
| `WordProblemGeneratorTests` | 12 | 各年級數值範圍、missing addend/subtrahend/minuend invariants、二步驟、有餘除法、分數真分數、MCQ 選項涵蓋率 |
| `SmokeTests` | 8 | VC 初始化、make/break ten hint configure |
| `DistractorGeneratorTests` | 6 | 干擾項唯一性、不含正解、非負 |
| `ProblemGeneratorTests` | ~10 | drill tier、運算子篩選 |
| `Calcu_LaterUITestsLaunchTests` | 4 | UI 啟動 smoke |

新增檔案會自動納入 target（Xcode 16 file-system synchronized groups），不必改 `project.pbxproj`。

---

## 設定與配置

`SettingsViewController` 從 `MainMenuViewController` 右上角進入。可調：

- **答題模式**：MCQ（預設）/ 手寫
- **刷題 Tier**：D1 (20 內) / D2 (100 內) / D3 (三位數+) / D4 (混合)
- **運算類型**：加、減（乘除 v2）
- **音效開關**、**梅西老師（吉祥物）開關**
- **Drill 提示模式**：自動 / 直式 / 合十破十

設定變更只在下次進入刷題 / 教學 / 應用題時生效（從 `MainMenuViewController` 進入時 `viewDidLoad` 必抓新值）。

---

## 角色與品牌

**梅西老師**（math 諧音）— 自製 chibi 風格小老師（戴眼鏡、拿教鞭、抱書本），6 種情緒 frame（portrait / desk 各 3 frame），對應 `MascotView.h` 的 `MascotEmotion` enum：

- `idle`（微浮動）
- `happy`（答對放大）
- `cheering`（5 連對大跳）
- `shake`（答錯柔搖頭）
- `thinking`（傾斜）
- `talking`（說話擺動）

無外部美術授權限制，可自由改編。

---

## 文件

- **`PLAN.md`** — 完整開發計畫，按 Phase 1～12 記錄已完成 / 延後 / v2 項目。每動工一階段就 update。
- **`PLAN.md` §1** — 視覺語言（Design System）：配色、字體、間距、動畫原則、無障礙準則。所有新 UI 都該先回頭看這節。
- **`CalcuLaterAndroid/`** — Android 對照版（部分直式 UI 是 iOS 的參考來源）。

---

## 已知缺口（v1 收尾 / v2 範圍）

- ❌ Dynamic Type / 高對比 / iPad 大畫面排版未實機驗證
- ❌ `SubtractionHintView` 手機橫向窄場景未驗證
- ❌ XCUITest 端到端流程缺
- ⏸ 直式乘法、長除法（v2，Android 也尚未實作）
- ⏸ 同分母分數加減（v2，model 需擴展）
- ⏸ 九九乘法自製錄音音檔（目前用 TTS 暫代）
- ⏸ 雲端 TTS 預烤梅西語音（PLAN §12 已調研，待決定）

詳細缺口清單見 `PLAN.md` §10 與 §13.4 / §16.5。

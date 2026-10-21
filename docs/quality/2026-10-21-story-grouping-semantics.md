# Story grouping semantics and contextual strategies

Date: 2026-10-21. Base: `95b3a9c`.

## Scope and contract

This change adds explicit story roles at the catalog producer. It does not add UI,
change question ranges/decks, or claim native compilation, simulator or curriculum verification.
The catalog has 171 entries at this base; the inventory below covers all 52 multiplication/division entries.

- `GroupingStoryContext` is immutable and `NSCopying`. Strings and context are copied at each handoff.
- Meanings are `BuildEqualGroups` (`size = a`, `groups = b`), `ShareEqually`
  (`total = a`, `recipients = b`, `items each = quotient`) and `MakeGroupsOf`
  (`total = a`, `size = b`, `complete groups = quotient`).
- Item name/unit, group/recipient noun and answer unit are separate. `leftoverUnit` is the item unit.
- `WordProblemTemplate` supplies context and an operand-only `strategyPattern`; the generator renders it
  into `WordProblem.strategyText` and copies the context. `strategyHintText` never computes a result.
- Existing template/problem constructors remain available and supply nil metadata, even if a caller
  uses a known catalog ID or identical Chinese prose. No runtime ID/prefix/prose inference is used.
- A text-only template gets a reviewed strategy but no grouping context. Age, conversion, price,
  measurement, comparison, average and perimeter retain their own quantity roles.
- Contextual text-only multiplication retains the original valid numerical equation and answer unit,
  but omits generic repeated addition that could contradict its roles (notably age and conversion).
- Inverse, two-step and fraction worked equations remain unchanged. Remainder explanations retain
  `q × b + r = a`, quotient-only answering and separate item-unit leftovers. In sharing, leftovers
  remain in one common pool; they are not an extra amount for each recipient.
- `toArithmeticProblem` is unchanged and does not transport story semantics. A later visual factory
  must accept the full story, validate flags/arithmetic/units, and apply size bounds before allocation.
  Nonnil metadata alone does not validate a custom problem.

The new context constructor rejects unsupported enums and empty/whitespace-only labels. At the
sequence boundary, additionally check `problem.unit == context.answerUnit`, Build/Share
`answerUnit == itemUnit`, and Pack `answerUnit == groupName`. The reviewed catalog satisfies these rules.

## Complete grouping inventory (32)

`a` and `b` are inclusive original catalog domains. No range was changed to fit a picture.
Bounds for the intended concrete route are `groups <= 9`, `size <= 10`, `total <= 90`,
and `groups + (remainder > 0 ? 1 : 0) <= 9`. The extra row is a leftover tray, not a full group.
“All/Some/None” describes eligibility within the current valid numeric domain, not whether the
metadata is meaningful. Large stories still have correct roles and exact textual explanations.

| Template | Meaning | Counter name / unit | Group or recipient | Answer unit | a; b | Concrete domain |
|---|---|---|---|---|---|---|
| `g2_mul_dumpling` | Build | 水餃 / 個 | 盤 | 個 | 2–9; 2–9 | All |
| `g2_mul_row` | Build | 學生 / 個 | 排 | 個 | 2–9; 2–9 | All |
| `g2_mul_day_page` | Build | 書 / 頁 | 天 | 頁 | 2–9; 2–9 | All |
| `g2_mul_legs_dog` | Build | 腿 / 條 | 隻狗 | 條 | 4–4; 2–9 | All |
| `g2_mul_flower` | Build | 花 / 朵 | 束 | 朵 | 3–9; 2–9 | All |
| `g2_mul_candy` | Build | 糖果 / 顆 | 盒 | 顆 | 4–9; 2–9 | All |
| `g2_mul_basket` | Build | 蘋果 / 顆 | 籃 | 顆 | 4–9; 2–9 | All |
| `g2_mul_wheel` | Build | 輪子 / 個 | 台車 | 個 | 3–4; 2–9 | All |
| `g2_mul_finger` | Build | 手指 / 根 | 隻手 | 根 | 5–5; 2–9 | All |
| `g2_mul_packet` | Build | 餅乾 / 塊 | 包 | 塊 | 3–9; 2–9 | All |
| `g2_mul_egg_box` | Build | 雞蛋 / 顆 | 盒 | 顆 | 6–9; 2–9 | All |
| `g2_mul_chair` | Build | 椅子 / 把 | 張桌子 | 把 | 2–6; 2–9 | All |
| `g2_mul_jiaozi` | Build | 貢丸 / 顆 | 碗麵 | 顆 | 2–5; 2–9 | All |
| `g3_mul_class_size` | Build | 學生 / 個 | 班 | 個 | 20–35; 3–9 | None |
| `g3_mul_box` | Build | 巧克力 / 顆 | 盒 | 顆 | 12–30; 3–9 | None |
| `g3_mul_seat` | Build | 座位 / 個 | 排 | 個 | 15–30; 4–9 | None |
| `g3_mul_school3` | Build | 蘋果 / 顆 | 箱 | 顆 | 105–320; 3–9 | None |
| `g3_mul_pages3` | Build | 書 / 頁 | 天 | 頁 | 35–120; 3–9 | None |
| `g3_mul_factory3` | Build | 玩具 / 個 | 天 | 個 | 105–320; 3–9 | None |
| `g3_div_share_candy` | Share | 糖果 / 顆 | 個小朋友 | 顆 | 12–81; 2–9 | Some |
| `g3_div_pack` | Pack | 糖果 / 顆 | 包 | 包 | 12–81; 2–9 | Some |
| `g3_div_group` | Share | 學生 / 個 | 組 | 個 | 12–81; 2–9 | Some |
| `g3_div_plate` | Pack | 水餃 / 顆 | 盤 | 盤 | 12–81; 2–9 | Some |
| `g3_div_row` | Share | 座位 / 個 | 排 | 個 | 12–81; 2–9 | Some |
| `g3_div_big_share` | Share | 產品 / 個 | 個箱子 | 個 | 60–360; 2–9 | Some |
| `g3_div_big_pack` | Pack | 水果 / 顆 | 袋 | 袋 | 60–360; 3–9 | Some |
| `g3_rem_share_candy` | Share | 糖果 / 顆 | 個小朋友 | 顆 | 13–79; 3–9 | Some |
| `g3_rem_pack` | Pack | 糖果 / 顆 | 包 | 包 | 13–79; 3–9 | Some |
| `g3_rem_plate` | Pack | 水餃 / 顆 | 盤 | 盤 | 13–79; 3–9 | Some |
| `g3_rem_team` | Pack | 球員 / 人 | 隊 | 隊 | 13–79; 3–9 | Some |
| `g3_rem_seat` | Pack | 學生 / 人 | 排 | 排 | 13–79; 3–9 | Some |
| `g3_rem_box_big` | Pack | 零件 / 個 | 盒 | 盒 | 50–280; 3–9 | Some |

The two equality defects are fixed together with their metadata:
`g3_div_group` now says “平均分成 {b} 組”; `g3_div_row` says
“排成 {b} 排，每排的座位一樣多”. Their strategies repeat the equality condition.

Counter labels are quantities, not interchangeable objects: dog counters count legs, day buckets
count read pages or produced toys, and `g2_mul_jiaozi` counts 貢丸, not water dumplings.
For the team/seat remainder stories, neutral prose such as “剩下的球員有 3 人” avoids the
unnatural unit/name concatenation “3 人球員”.

## Complete text-only inventory (20)

These remain explicitly excluded from a generic item-group board even when their numbers are small.

| Template | Quantity roles | a; b |
|---|---|---|
| `g2_mul_age` | a = 倍數；b = 弟弟歲數；answer = 哥哥歲數 | 2–5; 3–9 |
| `g2_mul_price_pen` | a = 元/枝；b = 枝；answer = 總價（元） | 5–9; 2–9 |
| `g2_mul_price_snack` | a = 元/包；b = 包；answer = 總價（元） | 6–9; 2–9 |
| `g3_mul_multiple` | a = 小華的錢；b = 倍數；answer = 小明的錢 | 15–45; 3–9 |
| `g3_mul_bag` | a = 公斤/袋；b = 袋；answer = 總重量（公斤） | 12–25; 3–9 |
| `g3_mul_ticket3` | a = 元/張；b = 張；answer = 收入（元） | 120–280; 3–8 |
| `g3_mul_week_day` | a = 週；b = 天/週；answer = 天 | 3–25; 7–7 |
| `g3_mul_hour_min` | a = 小時；b = 分鐘/小時；answer = 分鐘 | 2–9; 60–60 |
| `g3_mul_min_sec` | a = 分鐘；b = 秒/分鐘；answer = 秒 | 2–9; 60–60 |
| `g3_mul_m_cm` | a = 公尺；b = 公分/公尺；answer = 公分 | 2–9; 100–100 |
| `g3_mul_kg_g` | a = 公斤；b = 公克/公斤；answer = 公克 | 2–9; 1000–1000 |
| `g3_mul_l_ml` | a = 公升；b = 毫升/公升；answer = 毫升 | 2–9; 1000–1000 |
| `g3_mul_km_m` | a = 公里；b = 公尺/公里；answer = 公尺 | 2–9; 1000–1000 |
| `g3_mul_dozen` | a = 打；b = 枝/打；answer = 枝 | 2–9; 12–12 |
| `g3_div_multiple` | a = 小明的錢；b = 倍數；quotient = 小華的錢 | 12–81; 2–9 |
| `g3_div_min_hour` | a = 分鐘；b = 分鐘/小時；quotient = 小時 | 60–540; 60–60 |
| `g3_div_cm_m` | a = 公分；b = 公分/公尺；quotient = 公尺 | 100–900; 100–100 |
| `g3_mul_square_peri` | a = 邊長（公分）；b = 四條等長邊；answer = 周長（公分） | 5–60; 4–4 |
| `g3_div_avg_page` | a = 總頁數；b = 天；quotient = 平均每天頁數（不斷言每天實際相等） | 60–360; 2–9 |
| `g3_div_avg_money` | a = 元；b = 小朋友人數；quotient = 每人元數（不是硬幣數） | 60–360; 2–9 |

## Verification status

Passed source-level checks in this Linux workspace:

- Balanced-call comparison of all 171 base catalog declarations against `95b3a9c`: all IDs,
  arithmetic flags, constraints and numeric ranges unchanged. Only the two intended story strings changed.
- Exact 52-route inventory: 32 grouping (19 Build, 5 Share, 8 Pack), 20 text-only.
- Enumerated valid numeric domains: 13 all-eligible, 13 partly eligible, 6 never-eligible grouping templates.
- All metadata answer units match their reviewed quantity roles; strategy placeholders use only given operands.
- Arithmetic bridge byte-for-byte unchanged; `git diff --check` clean.
- Independent read-only review found no blocking catalog/arithmetic regression. Its one wording finding
  (人球員/人學生 concatenation) was corrected.

Added 10 focused `GroupingStoryContextTests` methods covering the full catalog inventory/domains,
real generator propagation, legacy/custom non-inference, immutable snapshots, corrected equality,
age/conversion decomposition, non-object roles, and all six remainder-unit cases. Existing
`WordProblemExplanationTests` retain inverse, two-step, fraction and legacy-format regression checks.

Not run here: Apple Objective-C compilation, XCTest execution, simulator/device UI, VoiceOver or
visual layout verification. `xcodebuild` and Apple SDKs are unavailable in this Linux environment.
The portable source checks are not substitutes for those native checks.

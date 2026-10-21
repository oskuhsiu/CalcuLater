# Native board-inspection gesture decision

## Scope and current status

This is a test-helper correction, not a product-layout acceptance report. It changes only board-inspection helpers in `Calcu_LaterUITests.m` and `Calcu_LaterLayoutUITests.m`. Production code, teaching/numeric tests, workflows, general Settings reveal gestures, test deadlines, and animation behavior are unchanged.

The evidence source is `c948de49ad800c1711a40b8008e416716f76f309`, run [39657409557](https://github.com/oskuhsiu/CalcuLater/actions/runs/39657409557), attempt 1, compact job `119421235753`. The earliest failed boundary is XCTest viewport inspection, not build, boot, installation, or launch. The compact result is three passed tests and four failed tests. Other matrix jobs were still active when this investigation was assigned; this change does not dispatch or publish another run.

Environment: arm64 macOS 15.7.9 (24G830), runner image `macos15` / `20260907.0337.1`, Xcode 16.4 (16F6), SDK 18.5, iOS 18.5 (22F77), iPhone SE (3rd generation), verified system content size `large`.

## Retained evidence and observations

Raw archive: `CalcuLater-native-compact-c948de4-2026-10-21.zip`, SHA-256 `00ddc67b1186897ebbf03eb71781f489144f47ec24a6830deb9bde7877d78c27`.

Original video: `native-flows.mp4`, SHA-256 `91738b4c5405a25dbe8f18de858bcf66cac1cf50b1deb6bbc2c70f6575ff93c3`. Screenshots below are original XCTest attachments from the archive's `attachments/manifest.json`, not a reconstruction. Frame measurements are in UIKit points.

1. Make-ten starts fully visible. `736F14AA-C734-4D5D-B7B4-435021BC5B42.png` and hierarchy `58204D52-7E87-4A72-A2F6-87C6D155780A.txt` show the first frame's two counters and all nine counters in the second frame. Stage: `(24, 207, 327, 292)`. Viewport: `(8, 136, 359, 363)`. The stage's bottom is exactly the viewport's bottom, 499. The old helper nevertheless tries to move its top to 144.
2. The make-ten helper performs eight alternating drags. `test.log` reports 500 pixels/second and no endpoint hold. The original synthesized event `FF54C19C-EA2E-4612-A2AB-F51D1E337345` records the first touch moving from y390.1 to y327.1, a 63-point upward path. Its last move and finger lift both occur at offset 0.176 seconds. The next event `4CD45679-F533-49A0-BC21-2003AF995D8F` moves down 81 points. This is a feedback reversal, not a retry of an unavailable element.
3. Actual video frames at offsets 293, 295, 297, 299, 301, 303, 305 and 307 seconds show the inspection oscillation. Around 293 both ten-frames are visible; subsequent alternating positions clip either the first or second frame. The failure screenshot `CED123F4-9908-4D97-AA01-5EEED24A7788.png` and hierarchy `D238A673-B19F-4901-8779-A19C264291A4.txt` end at stage y282.5. Visible height is 216.5, below the unchanged required 268.
4. Packing's untouched first-play screenshot `41A30F9F-86F3-4525-9424-B75A44DFF178.png` shows the full pool, first bag, its four counters and unit. Hierarchy `C023E005-3136-4BBD-AE80-B0204593D380.txt` has board `(16, 78.5, 343, 470)` and viewport `(0, 120, 375, 463)`. The board is slightly taller than the viewport and its upper legend is outside it, so a complete top-and-bottom inspection still needs scrolling. The original first path, event `5C209630-CADB-4E4F-BF62-9B2E06837219`, moves down 49.5 points, then the next path reverses up 149.5 points. After eight gestures, screenshot `09DB11DE-CA1A-4BB8-9BF5-8B397B3E3526.png` and hierarchy `90CC6A9A-663D-4343-9121-B80B90BBFF17.txt` show y−61.5 and a clipped pool. The top-alignment assertion correctly fails against 108. Sharing fails the same assertion at y−46.
5. Break-ten has a separate, genuine initial presentation problem. Before any helper gesture, `31843437-402A-4A30-BDCB-89B14459755E.png` already clips the lower frame, with stage y282.5, height 292, in the same y136–499 viewport. Fixing inspection does not fix or accept that first-play product behavior.

The proven defects are unnecessary movement of a fully visible make-ten stage and large oscillation during helper-driven inspection. Zero-hold release at the default velocity is a supported explanation for the overshoot, but the proposed gesture's effectiveness remains a native-verification hypothesis. The raw automatic UI Snapshot archives can retain earlier board geometry across several gestures; they are not substituted for the named explicit hierarchy attachments, actual video, and new per-gesture measurements.

## Discriminating change

- Before a board inspection gesture, read current board and viewport frames. If the entire required board is already contained, do not scroll it.
- If the board fits but one edge is clipped, request only the displacement needed to reveal that edge. For the recorded break-ten geometry this is 75.5 points upward, not the old 138.5-point top-alignment request. This merely enables inspection; it does not erase the untouched initial screenshot.
- If the board is taller than the viewport, retain top framing and the existing consecutive lower-slice inspection. Keep the original maximum of eight corrective attempts and the existing viewport-relative travel caps.
- Replace only board-inspection drags with `pressForDuration:thenDragToCoordinate:withVelocity:thenHoldForDuration:`, using `XCUIGestureVelocitySlow` and a 0.2-second endpoint touch hold. The initial press remains 0.05 seconds. The hold is part of the synthesized touch path before lift, not an arbitrary sleep after an action or an extension of any test timeout. Its native sufficiency is not yet established.
- Every actual inspection drag retains an attachment containing requested and bounded signed scroll displacement, measured board displacement, board/viewport rectangles before and after, and touch endpoints. The primary helper also records the attempt number. Thus requested travel is never treated as proof of actual movement or slice coverage.

API verification used Apple's current Objective-C [coordinate drag declaration](https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:withvelocity:thenholdforduration:)?changes=__3&language=objc) and [slow velocity constant](https://developer.apple.com/documentation/xcuiautomation/xcuigesturevelocity/slow?changes=l_5&language=objc). This confirms the method and parameter meanings, not successful compilation or execution against the pinned Xcode 16.4 SDK.

## Unchanged acceptance and verification gate

All existing assertions are retained, including minimum visible coverage, horizontal bounds, grouping top alignment, reaching the board's lower groups, actual lower-slice advancement, overlap of successive retained slices, persistent controls, and untouched first-play framing. All test methods, initial captures, Replay/Back/rotation/background actions, numeric expectations and teaching assertions are byte-for-byte unchanged by this delta.

Linux checks passed: `git diff --check`; method-scope and assertion preservation comparison against the base; five recorded/edge geometry arithmetic cases; 252 additional finite geometry combinations checking that both generated touch endpoints remain inside the measured viewport. These are source/arithmetic checks, not native tests. No Xcode or Simulator execution was performed for this delta.

Before a later authorized native verification, review the completed matrix evidence and freeze the same environment contract. Expected observations on the exact integrated SHA:

1. The contained make-ten checkpoint has no inspection scroll before Replay and preserves both full ten-frames.
2. A necessary correction makes measured progress without alternating large overshoots. If it does not, the retained requested-versus-measured traces identify that boundary; do not increase timeouts, add sleeps, weaken assertions, or blindly repeat a full run.
3. Grouping's top/lower screenshots overlap by the original minimum and actually reach the final groups/remainder. Native video must still show the counters and units, not merely a hittable accessibility element.
4. Initial break-ten first-play framing is assessed independently before any helper movement. This helper patch cannot close that product defect.

Do not mark this defect closed until the exact source/configuration passes the original assertions with retained video and hierarchies. No automatic rerun is authorized by this record.

# Native teaching checkpoint and visual follow-up

## Verified run

Source: `7d12307ea15fc48b8d263e4bc59e0e2ae419fe20`.
[Native run 39633862145](https://github.com/oskuhsiu/CalcuLater/actions/runs/39633862145)
completed environment, build, boot, tests, evidence export and owned-device cleanup.
The earlier host inventory timeout did not recur on this instrumented attempt;
no simulator reset, automatic retry or timeout increase was introduced.

- Xcode 16.4, build 16F6; iPhone 16 Simulator, iOS 18.5 / 22F77, arm64.
- 172 model/component tests and eight native tap flows: **180 passed, zero skipped**.
- Model/component execution: 6.449 s. UI flows: 294.926 s. Whole test command:
  447.83 s, within the unchanged 900-second bound.
- The drill flow includes one 61-second app relaunch/automation setup pause.
  This is not evidence of the former repeated animation-idle failure.
- UI cases cover home/settings, lesson intro and nested help return, drill
  wrong/help/correct, story reading/equation, remainder/completion/review, equal
  fractions/landscape, 27 + 15 carry participation/Back/Replay, and 500 − 128
  adjacent zero borrowing/background return. They do not certify every screen.

[Original native artifact](https://github.com/oskuhsiu/CalcuLater/actions/runs/39633862145/artifacts/12360823236):
204,021,096 bytes. SHA256:
`50602e5f7091038e809b4eedb66a8a224cdebcf4a97d2a265441906cf41253ec`.
It includes raw xcresults, exact commands/exits, screenshots with matching
accessibility trees, environment fingerprint and the original Simulator video.
The GitHub artifact expires after seven days; a separate owned archive preserves
this checkpoint. No production app, signing or public deployment was performed.

## Actual visual and motion inspection

The original native recording decodes at 1178 × 2556 with variable frame timing,
389.218333 seconds duration and 182,754,428 bytes. The recorder finalized with
exit 0 and no forced kill. Its initial startup acknowledgement was not observed
within the bounded startup window, so `record-video.json` correctly reports
`startup-unverified`; the final log contains its start/completion messages. This
is not a claim that the entire startup interval was captured.

Observed in the retained portrait screenshots and extracted real video frames:

- The carry walkthrough shows twelve ones before exchange, a ten-ones packet
  travelling toward tens, the concrete equivalence, then the carry and two ones.
  Answer places remain blank until their deliberate write step.
- Both adjacent borrowing exchanges preserve the different hundred/tens and
  tens/ones states. Their current counts, arrows and concrete panels are visible
  in portrait; this is not an immediate rewrite to the final answer.
- Prediction choices show text/symbol feedback and stay on the same step until
  the learner presses Next. Back and Replay preserve the mathematical snapshot.
- The previously clipped story now wraps within the viewport; the remainder
  explanation retains `5 × 4 + 3 = 23` and quotient-only answering.

These are inspected examples, not a blanket accessibility or visual pass.
The landscape alignment screenshot still initially shows only the place headings
below its explanation. Scrolling is available, but first-play framing at compact
height remains an explicit improvement/verification item. Inspect the new compact,
iPad and maximum-text matrix before making stronger claims.

## Defect found despite green tests

`02-settings` shows duplicate large brown and small gray section text, plus
clipped multiline option rows. The screenshot and hierarchy identified two
causes: both custom section views and UIKit title providers were active, and
legacy subtitle cells measured only about 64 pt without a complete height
constraint chain.

The subsequent source change removes duplicate title providers and uses an
explicit self-sizing title/detail stack, retaining native checkmarks/switches,
settings identifiers, automatic save and the last-operation guard. Two focused
regressions and the separate layout acceptance flows exercise the correction.
**Its new native rendering, largest text and selection-induced reflow remain
pending in the next run.** The 180-pass result above applies to the recorded
source, not this later correction or the newly added layout matrix.

## Additional motion inspection

Original decoded frame sequences were inspected for both exchanges in 500 − 128:
5 hundreds / 0 tens becomes 4 hundreds / 10 tens, then 10 tens / 0 ones becomes
9 tens / 10 ones. The moving place-value packet and the splitting concrete units
are visible between the before and settled states; the written result row remains
empty until its later explicit write steps. This is stronger evidence than an
endpoint screenshot, but it is not a child comprehension study.

The retained Simulator MP4 has discontinuous presentation timestamps. Ordinary
seek-based/resampled contact sheets can therefore select or label the wrong
moment. Inspection used decoded frames in their actual output order, retaining
frame indices and PTS within contiguous transformation sequences. Do not infer a
whole-test wall-clock timeline or exact global animation duration from this file.
The raw recording and XCTest timing remain separate evidence. The source animation
is finite; the actual reviewed motion demonstrates its transitions, not a reliable
full-video clock. Later recordings should be checked for this limitation too.

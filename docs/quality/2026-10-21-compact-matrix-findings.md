# Compact and tablet evidence, plus the next targeted corrections

Source tested: `84f371d745b769638bd89b03e3bd7b8a3807766e`.
[Native matrix run](https://github.com/oskuhsiu/CalcuLater/actions/runs/39637261073).
All executed scenarios used Xcode 16.4 / iOS 18.5. The actual `simctl ui` help,
set command and readback verified system content size `large` on the two devices.
This is not maximum-accessibility-text evidence.

## What actually ran

- iPad (10th generation): all three selected layout UI flows passed, zero skipped.
  Story/answer bounds, guided summary, prediction/Replay/landscape controls,
  Settings persistence and the last-operation guard were exercised.
- iPhone SE (3rd generation): story and teaching flows passed; the Settings flow
  failed when its helper kept swiping upward after overshooting D3. The failure
  hierarchy places D3 above the viewport and the table at its bottom. This is a
  real failing acceptance run, not proof that the app's D3 row cannot be reached.
- Maximum accessibility text and standard scenarios: neither acquired a runner;
  neither built, booted or tested this source. Their checks have no steps and
  runner ID zero. Do not count either as a pass or a Simulator failure.

Artifacts:
- [Tablet](https://github.com/oskuhsiu/CalcuLater/actions/runs/39637261073/artifacts/12363862461),
  89,335,208 bytes, SHA256
  `b4d89374b19e2a07217fe0015942c69dd8954261c867787a067494734d02c844`.
- [Compact](https://github.com/oskuhsiu/CalcuLater/actions/runs/39637261073/artifacts/12363802929),
  181,029,969 bytes, SHA256
  `30cc0cf314f32cf0d7e4ed2f6876958afe8d0a1785a820f74d747305184aa78a`.

## Visual findings, separate from test status

The new Settings rows wrap readable text on both devices without the earlier
header/footer duplication. The compact failure capture also reveals a separate
app defect: scrolled rows show through the transparent navigation bar and collide
with its title/Done control. A scoped Settings navigation appearance correction
is separate from correcting the test helper's directional overshoot.

On iPad, the carry grid and complete concrete exchange are visible in portrait and
landscape. On the compact phone, the first carry playback shows the grid but cuts
off the lower concrete units behind the fixed footer. Scrolling and Replay work,
but that does not excuse an initially hidden transformation.

The next source correction exposes the board's actual regrouping geometry. After
final layout and before animation, the controller keeps the complete written and
concrete relationship visible when it fits. In a short viewport it prioritizes the
concrete exchange region, leaving the rest scrollable. Already visible regions do
not cause an unnecessary jump. Replay still preserves the child's chosen scroll
position, and the accessibility notification does not target an offscreen heading
after an intentional framing change. The existing finite animation and model
snapshots are unchanged. Focused component checks cover selected geometry,
resize, unsupported steps and absence of future answer reveal. Five controller
viewport cases invoke the real framing/replay methods with a fitted board: full
written/concrete fit, short-viewport concrete fallback, already-visible no-op,
Replay offset preservation, and invalid/non-regroup refusal. These checks do not
replace actual sheet navigation, accessibility or before/mid/after review.

This correction still needs native compilation and before/mid/after viewport
inspection. A board larger than the viewport cannot be certified by hittability
alone; very large text can still require deliberate scrolling and Replay.

## Hosted capacity, not a timeout increase

The two unstarted jobs' actual annotations identify hosted runner acquisition
failure and macOS arm64 capacity constraints:
[maximum-text check](https://api.github.com/repos/oskuhsiu/CalcuLater/check-runs/119351058645/annotations),
[standard check](https://api.github.com/repos/oskuhsiu/CalcuLater/check-runs/119351058867/annotations).
Their observed 900-second acquisition window is not the configured 35-minute job
bound or the app's test timeout. The next matrix limits concurrent jobs to two
using GitHub's supported `max-parallel` control. This reduces simultaneous demand;
it does not guarantee available capacity. Runner, toolchain, original per-stage
timeouts and fail-fast:false remain unchanged. No paid larger runner, repeated
empty rerun, simulator reset, deployment or release is introduced.

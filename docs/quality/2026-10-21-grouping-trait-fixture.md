# Grouping board native trait fixture repair

## Evidence and single failure boundary

Source `c948de49ad800c1711a40b8008e416716f76f309` was built and tested in
[run 39657409557](https://github.com/oskuhsiu/CalcuLater/actions/runs/39657409557).
The retained standard-job log reaches compilation, boot and XCTest. Its first
component failure is
`GroupingTeachingBoardViewTests/testAllCounterAndLabelFramesFitCompactWideAndLargeTextWidths`.
At `GroupingTeachingBoardView.m:428`, UIKit throws
`NSInternalInconsistencyException`: `GBTTestBoard` returns a trait collection
containing only `PreferredContentSizeCategory = L`. The exception explicitly
identifies the unsupported `traitCollection` getter override and missing
required traits. Later failures identify the same board address and incomplete
collection, including failures while constructing unrelated UIKit components.

The component target executed 225 tests with 99 unexpected failures. This is
evidence of a poisoned test trait environment, not evidence that all 99 product
behaviors are broken. The separate UI target executed 15 tests with two failures;
this fixture change does not address those scroll-helper failures.

## Narrow correction

- Remove the test-only `traitCollection` getter and partial `testTraits` property.
- Host the geometry-matrix board under a retained window/root controller, without
  making it the app's key window. Keep explicit board widths independent of the
  host's screen-driven geometry and disable only its autoresizing mask.
- Set only `board.traitOverrides.preferredContentSizeCategory`, then force a
  normal layout pass before configuring/measuring snapshots. UIKit retains all
  other inherited traits and propagates the override to descendants.
- Assert the effective category on the board and rendered content; verify a
  nonzero display scale, specified idiom, and inherited scale/idiom/style.
  Remove the override afterward and assert the host category is restored.
- Track every fixture board, including the zero-frame case. XCTest teardown
  cancels its own display links, removes overrides and views, then hides and
  releases the host window/root controller even if a test raises an exception.

The iOS deployment target is 18.2. Apple's iOS 17 trait-override API is therefore
available without a compatibility fallback. No production code, global trait
state, global animation switch, dependencies, timing limits or CI configuration
changes. The subclass's `canAnimate` probe remains intact.

## Primary API basis

- [Apple WWDC23: Unleash the UIKit trait system](https://developer.apple.com/videos/play/wwdc2023/10057/),
  especially trait overrides and layout-time propagation: unoverridden traits
  are inherited, and a view applies changes before `layoutSubviews`.
- [UIView traitOverrides, Objective-C](https://developer.apple.com/documentation/uikit/uiview/traitoverrides-2tqxk?language=objc).
- [UITraitOverrides, Objective-C](https://developer.apple.com/documentation/uikit/uitraitoverrides-c.protocol?language=objc):
  mutable trait values and `removeTrait:` rather than overriding the trait getter.

## Source checks and pending native acceptance

Linux source checks pass: `git diff --check`; all 93 original assertion
invocations retained verbatim, with nine additional fixture assertions; all 11
test method names retained; the three motion-probe method bodies are
byte-identical. The unchanged native selector resolves all 11 tests. The narrow
macro-comma audit reports zero hazards in 102 fixture assertions and zero hazards
across 1,867 known macro invocations in 116 repository Objective-C/header files.
These checks are not Objective-C compilation, UIKit execution or native acceptance.
Independent read-only source review found no blocking issues. In particular,
the scene-less `UIWindow` host's actual trait population and newly inserted
descendants' trait propagation are runtime checks, not established Linux results;
the added assertions must pass on the intended Simulator.

Native verification still requires the exact repaired source to compile under
the existing Xcode 16.4 / iOS 18.5 contract, then run this complete fixture and the
full component target in the same test process. Expected observation: both
content categories, both snapshots and widths 288/320/680 execute all original
geometry and quantity assertions; motion/replay/cancellation checks still pass;
later suites no longer reference an invalid retained `GBTTestBoard`. If removing
the fixture exception exposes genuine layout failures, retain and diagnose those
assertions rather than weakening them. The standard end-to-end UI acceptance
remains independently required. No CI run or publication was initiated here.

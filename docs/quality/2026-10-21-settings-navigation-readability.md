# Settings navigation readability

## Native finding

Run [39637261073](https://github.com/oskuhsiu/CalcuLater/actions/runs/39637261073),
source `84f371d`, contains real compact iPhone SE (3rd generation) and iPad
(10th generation) captures. The `layout-10-settings-writing-selection.png`
captures show that the previous fix removed duplicate section text and made
option rows wrap. In the compact settings failure capture, however, a scrolled
division row is visible under the transparent navigation bar. The row title at
screen y=63 shares the band occupied by the persistent Settings title at y=58.
The bar covers y=40–96; the table starts at y=40.

The associated XCTest failure is a separate scroll-search overshoot, not proof
that this navigation overlap caused the assertion. That test correction is
outside this change.

## Scoped correction

Settings now supplies an opaque lavender appearance for all four navigation-item
states: standard, scroll edge, compact and compact scroll edge. It reuses the
existing Settings background color and brown text; the Done button is tinted
on its own item rather than mutating the navigation bar. No global appearance,
safe-area/table constraints, sheet presentation, row sizing, selection/switch
behavior or accessibility identifiers change. Apple documents these
[navigation-item appearance overrides](https://developer.apple.com/documentation/uikit/uinavigationitem/compactappearance?language=objc)
as applying only while that item is displayed.

## Validation boundary

A focused component test checks that each item appearance has an opaque color
and no blur effect, verifies the configured brown title/Done foreground, and
leaves the containing bar's configured appearance/tint unchanged. Twelve source
invariant checks and whitespace validation pass; independent source review
found no blocking issue. These are not rendered-scroll results. This Linux
editing host has no Xcode/UIKit; the new test, compilation and resulting
navigation appearance have not run here.

The next native matrix must inspect Settings after scrolling options beneath
the top bar on compact iPhone, iPad and maximum accessibility text, verify that
the title/Done remain visually isolated and usable, and confirm dismissal and
reopening still preserve settings. Retain both screenshots and hierarchy:
opaque bars may legitimately occlude offscreen rows without changing their
accessibility frames.

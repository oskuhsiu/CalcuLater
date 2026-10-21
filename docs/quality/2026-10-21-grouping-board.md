# Grouping board renderer contract

This checkpoint adds a native UIKit renderer for the explicit, immutable
`GroupingTeachingSequence` contract. It does not infer story meaning from prose,
operator symbols, template identifiers or the arithmetic answer. Apply after the
reviewed grouping context and sequence changes. Xcode's synchronized groups include
the new source and test files without project-file changes.

## What the child sees

- Build equal groups: only the groups already established are drawn. Known groups
  still to build appear as text, not product-filled boxes. The empty preparation
  area supplies one group during its own transformation.
- Share equally: all known recipients start empty. One counter travels to every
  recipient in a round. The common pool is never presented as a separate remainder
  for each recipient.
- Make groups of: only completed groups and the one current target are drawn. No
  quotient-sized collection of empty boxes is created in advance.
- A circle represents one item, with the story's item name and unit in the legend.
  Five/ten organization, numbered group captions, outlines and explicit counts do
  not depend on color alone. Groups hold at most ten counters; the common pool
  holds at most ninety.
- The written answer uses only `currentStep.visibleAnswer`; the remainder caption
  uses only `currentStep.visibleRemainder`, including an explicit zero. Back clears
  either value when its earlier snapshot has not introduced it yet.

For the same 23 ÷ 4, sharing starts with four children and ends with five items per
child; packing starts with no bags and establishes five bags of four. Both retain
three common items in the original pool. These are different representations,
with different answer units, rather than interchangeable dot diagrams.

## Finite motion and conservation

Each transformation lasts one second: 0–0.16 shows its before state, 0.16–0.82 moves
actual counter views, and 0.82–1.0 holds the after state. There is no automatic Next.
Replay reconstructs the selected step's own before state.

The after-state static pool excludes the moved items. The new destination counters
are temporarily detached and begin at exactly those missing source positions.
During travel, pool and group captions exclude the movers and an explicit moving
count accounts for them. Thus the same objects are visible throughout; no duplicate
source dots or destination placeholders inflate the quantity. Destination ordering
matches source positions horizontally to reduce crossing paths. Counts settle only
when the objects reach the groups. A zero-item group still has a visible, finite
preparation/completion change and no invented counters.

Existing groups keep their position and size as a new group is established. Grid
slots depend on width and text size, not the number of finished groups. No future
cards are rendered in those slots. Pool height reserves the known total calculated
from the selected snapshot's pool plus group counts. Caption/status reserves and
the preparation area are stable between prediction and transformation snapshots.
This prevents completed groups from jumping when a pool row disappears.

A weak display-link target prevents a retain cycle. The clock is invalidated and
movers are restored to their selected destinations on completion, resize, hidden
state, removal, app backgrounding or Reduce Motion notification. Reduce Motion
starts directly in the same settled snapshot. No test launch argument disables
production animations.

## Controller integration

1. Configure the selected sequence/index with `animated:NO`.
2. Call `sizeThatFits:` with the real available width, set the height, and lay out.
3. Optionally position the parent scroll view using `currentTransformationRect`.
4. Start with `showStepAtIndex:animated:YES`. Preserve the scroll offset for Replay.

`currentTransformationRect` is the union of the selected step's actual moving
counter source/destination frames in board coordinates. It is `CGRectNull` for
non-transforming and zero-counter steps. It never reads future groups. It may be
taller than a compact viewport; the controller must permit scrolling and deliberate
Replay, rather than claiming every transformation fits on one screen.

The board is one Static Text accessibility element with identifier
`groupingTeachingBoard`. Its current-only value states the item legend, group
count, each group's actual count, common pool and any separate moving count.
For example, the first sharing round moves from pool23/groups0 to
pool19/groups0/moving4, then pool19/groups1 each. It says the answer is not written
until the selected snapshot explicitly writes it. Child views are hidden from
accessibility to avoid duplicate dot-by-dot traversal.

## Validation and limits

Independent source review identified group resizing, pool-row layout jumps and
dynamic caption/status shifts; these were corrected. Additional readability review
removed transient faded count text.
Eleven focused XCTest methods cover sharing versus packing starts, incremental
creation, reveal order, zero quantities, width/text-size bounds, stable established
group geometry, actual movement endpoints, conservation, Back/Replay, cancellation
and invalid indices. These tests are authored but **not executed on this Linux
workspace**.

The portable coordinate/state audit passed 612 bounded counter-grid cases and
4,600 current-state transfer/conservation cases, plus source guards for reveal and
clock cleanup. This is not a UIKit rendering or Objective-C compilation result.

Required next evidence: native build/XCTest; actual before/mid/after video; compact
and iPad layouts; maximum accessibility text; first-play viewport positioning;
VoiceOver phrasing and Reduce Motion interaction. In particular, inspect whether
moving counters remain easy to follow when source rows wrap, rather than treating
endpoint assertions as proof of animation quality.

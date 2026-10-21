# Child-controlled grouping lessons

This source checkpoint connects the reviewed story metadata, immutable sequences
and native quantity board to the existing question's “看怎麼算” action. It does
not replace the story with its arithmetic bridge or infer missing story meaning.

## What is taught

- Multiplication establishes one known equal group at a time, without displaying
  the product or future filled groups in advance.
- Sharing establishes the known recipients first. Each round moves one actual
  item to every recipient, keeping the unshared items in one common pool.
- Packing establishes one complete group at a time. It never gives away the
  quotient by drawing that many empty bags before the child has grouped them.
- Both forms of division inspect whether the remaining items can support another
  complete round/group before writing the answer. A shared leftover is not
  repeated separately for every recipient; answer and remainder retain their
  different story units.

The same 23 ÷ 4 is explicitly tested as four children each receiving five sweets,
with three sweets left, and five bags of four sweets, with three sweets left.
These are intentionally different questions and different pictures. A story has
one producer-supplied meaning. Only a bare arithmetic division can offer a switch
to another valid bounded interpretation, and switching restarts the exploration.

## Child control and reveal order

The learner can try an optional, ungraded prediction, skip it to watch a model,
move back one step, replay just the selected transformation, listen to the
current explanation, or restart. A prediction never advances on its own or changes
practice scoring. Incorrect choices remain distinguishable with text/symbols,
not color alone. Back preserves that step's attempts; restart clears them.

The final written answer is absent until its explicit WriteAnswer snapshot. The
read-aloud action uses only the current step's spoken explanation. Closing or
finishing returns to the original unanswered question; it does not award a
correct answer or advance the practice session.

Every transformation is laid out before motion starts. Its first playback frames
the actual source/destination union reported by the board. Replay preserves the
learner's chosen scroll position. A transfer can still be taller than a compact
viewport; the content remains scrollable and this is not a claim that every
quantity fits on one screen. After framing, the accessibility layout notification
targets the current board rather than moving focus back to an offscreen heading.
Actual VoiceOver behavior remains to be tested.

Speech and finite motion stop on dismissal/backgrounding. The existing make-ten,
break-ten, inverse, multi-step, fraction and non-grouping story routes remain;
unsupported or unbounded grouping does not fall back to a misleading picture.

## Evidence authored, not yet executed

Four native UI flows in the existing selected `Calcu_LaterUITests` class cover:

1. Sharing 23 sweets between four children, optional participation, preserved
   attempts after Back, common remainder, answer units and background/return.
2. Packing 23 sweets four per bag, incremental group creation, reveal order,
   reconstruction check and completion back to the question.
3. Building four equal groups of three, without a prefilled product.
4. Comparing two explicitly labelled meanings of bare 12 ÷ 3.

The tests deliberately scroll the board into view, validate finite/nonempty
viewport frames, and wait for the selected transformation's actual settled
quantities after Replay. Merely finding an accessibility element or a hittable
board is not accepted as proof that its counters are visible. Screenshots and
hierarchies are retained; actual before/mid/after motion still requires inspecting
the native recording.

Independent integration review checked API selectors, exact accessibility values,
step indices, prediction behavior, routing, return paths and bounded scroll
coordinates. It found and prompted fixes for initial transfer framing, incorrect
packing-pool assertions, premature post-Replay assertions, the focus target and
vacuous empty-viewport checks. Source/whitespace checks passed on Linux.

**Native Objective-C compilation, XCTest execution, compact/tablet/large-text
rendering, real gestures, first-play visibility, VoiceOver and Reduce Motion are
not established by this source checkpoint.** Keep the native run and artifact
identifiers beside subsequent evidence rather than promoting source review to a
rendered pass.

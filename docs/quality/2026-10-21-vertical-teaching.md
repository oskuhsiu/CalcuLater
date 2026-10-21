# Child-paced vertical arithmetic

## Teaching design

The next checkpoint makes the transformation, not an answer reveal, the central
teaching activity. A valid nonnegative addition/subtraction problem gets a
sequence of immutable place-value snapshots. The learner controls every step:

1. Align ones, tens and hundreds before calculating.
2. Optionally predict a column total/difference or a one-to-ten exchange.
3. Inspect concrete units and the column calculation.
4. Exchange ten smaller units for one larger unit, or one larger unit for ten
   smaller ones. Each exchange preserves value and only crosses one adjacent
   column.
5. Write that answer digit, leaving future columns blank.
6. Connect the completed digits and return to the original unanswered question.

There is no speed requirement, countdown, automatic advance, graded prediction
or penalty for choosing a demonstration. Back restores the exact earlier
snapshot. Replay repeats the selected transformation without losing the chosen
step or scrolling away from the part being inspected. Close and the final step
both return to the question, including when teaching was opened from another
help sheet. A fixed bottom bar keeps Back, Replay and Next reachable.

For example, 27 + 15 first combines seven and five ones, then exchanges ten of
the twelve ones for one ten. 500 − 128 explicitly goes from `[5,0,0]` to
`[4,10,0]` to `[4,9,10]`; it never pretends that a zero can lend a ten directly.
Finite native Core Animation shows the transfer and splitting/gathering of
units. Cancellation, backgrounding, resizing and Reduce Motion settle on the
selected mathematical snapshot, never an inconsistent intermediate answer.

Small-set counting and dedicated make-ten/break-ten lessons keep their own
conceptual pictures, with a secondary vertical entry. Larger straight
addition/subtraction opens the vertical walkthrough directly. Inverse,
two-operation, fraction and multiplication/division stories retain their own
reasoning rather than receiving an inappropriate numerically similar picture.
Multiplication/division vertical sequences are not yet implemented.

## Related usability corrections

The previous native screenshots revealed real story truncation despite passing
tap tests. Scrolling stacks now enforce viewport width, and a multiline label
updates its preferred fitting width after layout. A deterministic story flow
checks both horizontal bounds and actual wrapped height.

Settings now visibly show selected mode and tier, persist each interaction,
protect the last enabled operation, and explain that handwriting is self-checked.
Unused hint switches no longer promise behavior that the practice screen ignores.

## Evidence status

Independent source reviews covered mathematical snapshots, board rendering,
controller routing and lifecycle. Portable arithmetic checks covered carries and
zero-chain regrouping extensively; they are not native Objective-C execution.
Focused native model/component checks and two deterministic tap flows were added
for optional prediction, no premature answer, adjacent exchanges, Back/Replay,
background/foreground persistence, completion and return. Existing native flows
remain, including the accurate remainder check and equal-part fraction diagram.

Native compilation, rendered screenshots, animation timing and small-device/
iPad/large-text bounds are pending for this checkpoint. This document does not
claim a visual or accessibility pass from source review alone.

## First native build boundary

[Run 39630648058](https://github.com/oskuhsiu/CalcuLater/actions/runs/39630648058)
verified the environment but stopped in test compilation. Three board-test
assertions contained unparenthesized Objective-C string-format commas inside
C preprocessor macro arguments. The application sources compiled; this does not
establish a runnable or visually correct app. The assertions now use local
identifier variables. Boot and test were correctly skipped, while original
build evidence export and owned-simulator cleanup succeeded. The next run is
for this discriminating source correction, not an unchanged retry.

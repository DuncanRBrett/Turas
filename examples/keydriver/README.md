# Suiderland Bank: the keydriver worked example

A small, self-contained key driver study whose right answer is known before the
module sees it. Run it to check the module works, or to see what its output
looks like, without needing a client project.

## Why this exists

Keydriver had no example of any kind. That is not a tidiness problem. Three
separate features in the module had never produced a number, and nothing caught
it, because there was nothing to run: NCA called its package with the arguments
in the wrong positions, the SHAP dummy-collapse pattern could not match any
dummy name, and fourteen pre-flight checks were never called by anything. All
three had passing tests around them.

Building this example found three more problems within minutes of its first
run. Pricing gained its Karoo Coffee example for the same reason.

## Building it

```r
source("examples/keydriver/create_keydriver_example.R")
build_keydriver_example()
```

That writes, into this folder:

| File | What it is |
|---|---|
| `Suiderland_KeyDriver_Data.xlsx` | 900 respondents |
| `Suiderland_KeyDriver_Config.xlsx` | five continuous drivers; runs clean to PASS |
| `Suiderland_KeyDriver_Config_Mixed.xlsx` | adds the categorical driver; runs to PARTIAL, on purpose |

Then run either config from `launch_turas()`, or headless.

## The true answer

The outcome is built from known standardised effects, so the correct driver
order is not a matter of opinion:

| Driver | True standardised effect |
|---|---|
| `digital_banking` | 0.80 |
| `fees_clarity` | 0.52 |
| `branch_service` | 0.34 |
| `staff_knowledge` | 0.16 |
| `product_range` | 0.05 |

A correct engine returns that order, by relative weights and by Shapley alike.

The order is guaranteed at the committed seed, which is what the test asserts.
It is not guaranteed by the design at n = 900. An independent check scored 20
seeds unweighted and weighted: relative weights and standardised betas recover
the order in all 40 runs, and the Shapley column, which computes LMG, swaps
`staff_knowledge` and `product_range` in 3 of them. Those two are 0.16 and 0.05
against an R-squared of about 0.74, so the gap between them is genuinely thin.
At seed 2026 the margins are 0.024 and 0.035 and every measure agrees, which is
why the fixture is committed at that seed rather than generated fresh. A test
that sometimes fails teaches nobody anything.

`contact_channel` carries a real effect too (App best, call centre worst), and
exists to exercise the mixed-model path rather than to be ranked.

The drivers are correlated with each other, the way a real battery always is.
That matters: it is the entire problem Johnson's relative weights exist to
solve, and an engine that ignores it will still look plausible.

## Why the mixed config runs PARTIAL

Because it should, though for one of the two reasons this file used to give.

A zero-order correlation really is undefined for a nominal driver, so the
correlation column is empty for `contact_channel` and the run says so.

The bootstrap is a different case, and the old wording here was wrong. There is
nothing about resampling that a factor breaks: resampling rows is indifferent
to column types, and `lm` fits the factor in every replicate. The limitation is
narrower and it is ours, not statistics': this bootstrap's estimators are
written for numeric drivers only, so it refuses a study that contains a factor
and the five continuous drivers lose their intervals along with it. Treat the
`how_to_fix` that says to convert the column to numeric as wrong for a nominal
driver: do not score App, branch and call centre 1, 2, 3 to get intervals. The
right fix is to the bootstrap, and it is not in this session's scope.

Both paths degrade by name and the report says which outputs are affected,
which is the picture this example is here to give: the alternative is a module
that produces numbers for things it cannot compute.

## The weighting

`weight` favours younger respondents roughly three to one, and younger
respondents rate digital banking higher and use the app more. So a weighted run
gives different numbers from an unweighted one, which is what makes this file
useful for checking the weighting fixes. The true ordering is unaffected: the
sample composition changes, not the model.

An earlier version of this file gave younger respondents their own equation to
create that contrast. Do not do that. It makes the "known" answer unknowable,
and the module correctly returned a different order, which looked like an
engine fault and was a fixture fault.

## What it does not cover

SHAP, elastic net, NCA and GAM are switched off in both configs so the example
runs in seconds. Switch them on in the Settings sheet to exercise those paths.
NCA needs a driver with a genuine ceiling to find anything; these drivers do
not have one.

# Brand simplification, Stage 3 implementation log

**Date:** 6 September 2026. Worktree `/Users/duncan/Dev/Turas-brand-simplify`,
branch `feature/brand-overview`, cut from main at 6de087ef.
Scope: the Overview. One bug fix, one layout, no numeric change.

Brief: the Stage 3 task message, against
`docs/v2_lift/HANDOVER_BRAND_SIMPLIFICATION_FOR_OPUS.md` section 4,
`modules/brand/docs/SIMPLIFICATION_IMPACT_MAP.md` section 5 and
`docs/v2_lift/NOTES_BRAND_SIMPLIFICATION_STAGE2.md`.

## Baseline, executed before the first edit

- Brand suite: `TURAS_ROOT=/Users/duncan/Dev/Turas-brand-simplify Rscript -e
  'testthat::test_dir("modules/brand/tests/testthat")'` gave
  **FAIL 0, WARN 1, SKIP 2, PASS 3047**, 89.9 s. Matches the brief.
- IPK fixture report generated and kept as the before-and-after baseline:
  `run_brand()` on `modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx`
  with `project_root` = the fixture directory, then
  `generate_brand_html_report()` to the scratchpad. Status PASS,
  **3,962,385 bytes**. Nothing was written into the repo or into any
  project folder.

## The constraint that decided the shape of the build

`modules/brand/tests/qa/reachability_check.py` is a gate on this stage, and it
asserts three things at once: the `data-subpanel` set, the `data-section` set
and the `section-<id>` set are equal between the old and the new report, and
**every JSON island's numeric content is identical**. It extracts every number
from each island's parsed JSON and compares the tuples.

So a single number added to the `brsum-data` island fails the gate. That ruled
out the obvious build, which would have computed the Overview's new content in
R and shipped it in the payload.

**Every Stage 3 derivation is therefore done in JavaScript, over the payload
that already exists.** R's share of this stage is skeleton markup, one option
attribute, and CSS. This turned out to cost nothing: everything the Overview
needs was already in the island.

Verified rather than assumed, by parsing the generated report's `brsum-data`
island:

| Needed | Already in the island |
|---|---|
| the MMS rank | `brands.<code>.focal_metrics[0].rank`, the string `"Rank 1 / 15"` |
| Mental Advantage defend / build / maintain | `cep.brands.<code>.decision` and `attrs.brands.<code>.decision`, per stimulus |
| the gap to the category average | `cep.cat_avg_pct` and `cep.brands.<code>.focal_pct` |
| the funnel by stage | `funnel.cat_avg` and `funnel.brands.<code>` |
| the target window's own wording | `funnel.stage_labels` |

The one thing not in the island is the category tab id, which a headline tile
needs to route to a destination. It rides on the category `<option>` element as
`data-cat-id` instead, derived the same way `build_br_category_panel()` derives
it. An attribute on an option is not one of the three sets the gate compares,
and it is not in an island, so it changes nothing the gate reads.

## The bug, proved before it was fixed

`heroAnchors()` in `js/brand_summary_panel.js` read `rank` off each
`snap.ma_metrics` entry. `.brsum_brand_snapshot()` in
`panels/14_summary_panel.R` writes no `rank` field on `ma_metrics` at all; it
writes the MMS rank on `focal_metrics` as `sprintf("Rank %d / %d", mms_rank,
n_brands)`. So `mms_rank` was always null, `.brsum-hero-rank` was never
emitted, and `heroHeadline()` fell through to its bare
`fname + ' in ' + catName` clause.

Proved in node against the pre-fix file, `git show HEAD:...` into the
scratchpad, with the payload shape taken from the generated report:

```
OLD mms_rank = null
OLD headline = Top Brand in Dry Seasonings & Spices. Strong on both mental
               (MPen) and physical (% bought) availability.
```

The fix normalises the rank source. `parseRank()` accepts a number,
`"Rank 1 / 15"`, `"#7 of 12"`, `"3/9"` or an object, and returns
`{ rank, of }`; anything it cannot read returns nulls and the caller renders no
rank rather than a guessed one. `focal_metrics` is the source and `ma_metrics`
is kept as a live fallback, so a payload that starts writing a rank there keeps
working. The denominator the rank was computed against wins over
`cat.n_brands`: the two diverge when a brand is in the picker but absent from
the MMS table.

Coverage is `modules/brand/tests/js/test_summary_overview.js`, run inside the
brand suite by `test_summary_overview_js.R`, asserting the clause at rank 1,
mid-table and last, plus a rank-1-of-9 case where the denominator differs from
the picker count.

## The layout, top to bottom

1. **Four headline tiles**, in `.brsum_headline_tiles()`: Mental Penetration,
   Mental Market Share, bought in the target window, Share of Category
   Requirement. Four, not the handover's six. Awareness and consideration are
   descriptive and stay on Brand and Buying.
2. **"What the numbers say"**, the old verdict generator, renamed and softened.
3. **Two Why blocks split by concept**: moments, from Category Entry Points,
   and associations, from brand attributes.
4. **"Opportunities to examine"**, replacing Protect, Build and Investigate.
5. **The analyst commentary editor**, untouched.
6. **A "How this works" drawer**, collapsed, holding the methodology callout
   and the "Which penetration is which" block.

Then the four cards the impact map calls secondary, unchanged: mental
availability, the mini funnel, word of mouth, repertoire ties. The shopper
summary and the closing strip keep their positions.

## Decisions taken, with reasons

1. **The tiles are static R markup that JS fills**, not JS-built innerHTML.
   That is the Mental Availability hero-card pattern, and it keeps the
   comparison slot in one place: `br_compare_slot()` in
   `panels/00_json_island.R` writes the element and its `data-compare-source`,
   and nothing in the JS builds a second copy of that markup. `renderHeroCard`
   therefore fills sub-elements instead of replacing the card body.
2. **Every tile's comparison is the Stage 2 slot.** All four carry
   `data-compare-source="category-average"` today, and the slot switches itself
   to `"none"` when the figure is absent, so an empty slot is distinguishable
   from a real comparison. No tile carries a hard-coded "vs category average"
   sentence.
3. **Only Mental Market Share shows a rank.** It is the only metric the payload
   ranks. A Mental Penetration rank could be computed in JS from the other
   brands' snapshots, but the R rank is taken over all `ma$mms` rows while the
   category averages beside it are masked to data-active brands, so a JS rank
   would be a different computation from the one the MA tab reports. None is
   manufactured.
4. **The bought-window tile takes its wording from the funnel's own stage
   label**, so a study whose target window is not three months reads its own
   words. It reads "Bought, past 3 months" on the IPK fixture. Its value comes
   from `focal_metrics`, which reads the funnel's `bought_target` stage, so the
   tile's label and its value share one source. `brand_summary` carries a
   second purchase figure on a different base; the "Which penetration is which"
   block in the drawer is what sets the two out side by side.
5. **Two verdict clauses that read as diagnoses are gone**: "That is a
   conversion gap" and "Punching above its mental availability on physical
   purchase". Rules over four comparisons do not earn a diagnosis. Each clause
   is now the comparison stated flat in the reader's own units, and a clause
   whose figures are missing is dropped rather than softened. Extended with
   the `is_leader` flags the payload already carries, Share of Category
   Requirement and net word of mouth. The block returns an array of sentences,
   one paragraph each, rather than one run-on line.
6. **The Why split is by concept, and the card keys do not move.** The cards
   keep `data-section="brsum-working"` and `data-section="brsum-weak"`, because
   pins, PNG capture and Excel export resolve a section by those names and
   analysts have saved work against them. The key is an identifier and the
   title is a label, which is the Stage 2 rule, and nothing derives one from
   the other. `brsum-weak` now holds "Associations this brand owns". A pin's
   title comes from the card's own `h3` (`brand_pins.js` line 93 reads
   `.br-element-title, h2, h3, .pfo-section-title`), so a pinned associations
   card is titled correctly; only the anchor string carries the old word.
7. **Inside each Why card the split is ahead of the category average against
   behind it**, and the empty column says what it found none of, by name and by
   count: "This brand is at or above the category average on every one of the
   15 attributes measured." No item is promoted across the line to fill a
   column.
8. **"Opportunities to examine" is not pinnable in Stage 3.** Giving it a
   `data-section` would add a pin anchor, and the gate asserts the anchor set
   is unchanged. `test_summary_card_pins.R` asserts seven pinnable cards, and
   that count still holds. Stage 5 gives every destination one export toolbar,
   which is the right place for this. **Owed:** if Duncan wants the block
   pinnable before Stage 5, it needs a new anchor and a rebaselined
   reachability comparison.
9. **The rule-of-thumb items use the arithmetic gap, not `advantage_pp`.**
   The Why cards display `focal_pct - cat_avg_pct`; `advantage_pp` is the MA
   engine's own metric against a model-based expected value, and on the IPK
   fixture the two disagree in sign (arithmetic gaps run +1.86 to +7.64, while
   `advantage_pp` runs -3.83 to +2.55). A fallback item that used
   `advantage_pp` would contradict the list above it on the same page.
10. **The Mental Advantage threshold figure is not printed.** `threshold_pp`
    is not in the `cep` or `attrs` blocks, and adding it would put a number in
    the island. The empty-case sentence says "sit inside its threshold" without
    the figure.
11. **The methodology callout inside the drawer renders expanded.** The drawer
    is the disclosure; a second one would make a reader click twice for the
    same thing. This is the Stage 2 precedent for a single-item Advanced
    drawer. The text is unchanged; only the `collapsed` flag moved, and
    `.brsum_educational_callout()` gained an argument with the old value as its
    default.
12. **A collapsed drawer still prints.** A printed page cannot be opened, and
    the drawer holds the bases and the definitions.

## The empty-gaps case, measured rather than assumed

On the IPK fixture the focal brand is Ina Paarman's Kitchen in Dry Seasonings
and Spices, the only deep-dive category in the summary payload, with 15 brands.
Measured off the generated report's island:

- 15 category entry points and 15 attributes. **Every arithmetic gap to the
  category average is positive**: CEPs +1.86 to +7.52pp, attributes +2.01 to
  +7.64pp, zero negatives across all 30.
- Read off the engine result directly: `defend = 0, build = 0, maintain = 15`
  for both batteries, at `threshold_pp = 5`.

So the Overview says so:

> Mental Advantage returns no defend and no build item for Ina Paarman's
> Kitchen here. All 30 measured category entry points and attributes sit inside
> its threshold, which it reads as maintain. There is no gap in this battery to
> report, and none is invented below.

and then offers two items, each tagged "Rule of thumb" and each ending "not a
model output": the largest lead as what to protect, and the smallest lead as
what to watch. The smallest-lead item checks the sign, so a genuine shortfall
reads "largest shortfall against the category average" rather than being called
a lead.

Nothing measured at all is reported as nothing measured, not as no gaps: a
category with no advantage battery, and a brand absent from the battery, both
return `measured: false` and say "Mental Advantage was not run for this
category".

## The funnel step, and the one divergence

"Opportunities" names the largest step down in the funnel. The engine already
finds it, in `.biggest_drop_for_focal()`, but reading the engine's answer would
mean putting its value in the island. So the Overview derives the step in JS
from the mini-funnel figures the page already draws: the smallest successive
ratio, skipping any step whose preceding stage is zero.

The two agree under the default conversion metric, and
`modules/brand/tests/testthat/test_summary_funnel_step.R` proves it rather than
leaving it to be inferred: three series, asserting the same `from_stage`,
`to_stage` and value as `calculate_conversions()` plus
`.biggest_drop_for_focal()`. On the fixture's own figures the step is past 12
months to past 3 months at 0.721612, which is the value the engine returned in
this session's run.

**The divergence, stated:** with `funnel.conversion_metric` set to
`"absolute_gap"` the engine's biggest drop is the largest fall in percentage
points, which can be a different step. The Overview always reports the ratio,
and says so in its own words ("which is 72% of the stage before it"), so its
sentence stays true either way; it is the engine's answer that it may then
differ from. Logged here and in the test's header comment.

## Deviations and losses, logged

- **"Opportunities to examine" carries no pin control** (decision 8). It is the
  only block on the Overview that cannot be pinned on its own. Everything in it
  is derived from figures that are pinnable elsewhere.
- **`data-section="brsum-weak"` now labels the associations card** (decision 6).
  A pin saved before this build under that anchor still resolves; it now
  captures attributes rather than under-indexers. No anchor was renamed and
  none was added.
- **`.brsum-pen-notes` moved** out of the card grid, where it was always open,
  into the collapsed drawer. `test_penetration_notes.R`'s skeleton assertion
  was updated to its new home and now also asserts it is no longer in the grid.
- **The category Overview destination still shows the Stage 2 route card.** The
  Overview built here is the Summary tab, which is what the brief said to
  extend; `brOpenSummaryFor()` is still how a category reaches it, and
  `drive_destinations.py` still reports `overview hosts=0 stub=1`.
- **The closing strip and the shopper summary were left where Stage 2 put
  them.** "Portfolio and category mini-cards stay on the Portfolio tab" was
  read as a scoping statement about what not to add, not an instruction to
  remove what is there. On the IPK fixture the closing strip renders nothing
  anyway: it needs two or more deep-dive categories and there is one.

## Executed, with the numbers

| Check | Result |
|---|---|
| Brand suite, before the first edit | FAIL 0, WARN 1, SKIP 2, PASS 3047 |
| Brand suite, at the tip | FAIL 0, WARN 1, SKIP 2, PASS 3077 |
| `node modules/brand/tests/js/test_summary_overview.js` | 101 passed, 0 failed |
| `reachability_check.py before after` | PASS. data-subpanel 5, data-section 29, section ids 13, all identical; 8 island classes, every one numerically identical |
| `drive_overview.py after.html` | 55 checks, 0 failed, no console error |
| `drive_destinations.py after.html` | 353 checks, 0 failed |
| `drive_save_roundtrip.py after.html` | 113 checks, 0 failed |
| `drive_two_categories.py after.html` | 15 checks, 0 failed |
| IPK fixture report | PASS, 3,989,976 bytes against 3,962,385 before |
| The pre-fix rank bug | reproduced in node against `git show HEAD:...`: `mms_rank = null`, bare headline |

What `drive_overview.py` asserts in a real browser, on the real bundled
JavaScript: all four tiles show a figure rather than the en dash placeholder;
every tile carries a comparison slot naming its source and none hard-codes a
"vs category average" sentence; exactly one tile carries a rank and it is the
Mental Market Share tile; **all four tile links resolve**, each landing on
`panel-cat-dss` with its named destination active and its destination button
active; "What the numbers say" renders five sentences; both Why blocks render
and name their own source; the empty-gaps sentence renders and both fallback
items are labelled rules of thumb; **the drawer starts collapsed, opens on
click**, and holds both the "Which penetration is which" block and the
methodology callout.

Also eyeballed: a headless Chrome screenshot of the Overview at 1400px, read in
this session. It caught one thing the checks could not, that the rank badge sat
between the value and the comparison line on the Mental Market Share tile and
pushed that tile's comparison out of line with the other three. The rank now
sits below the comparison.

## Adversarial pass, and the one thing it caught

The fixture has one full-depth category, so the tile routing had only ever
been driven with one option in the category picker. A picker with one item is
a picker that has not been tested, and reading `options[0]` instead of the
selection would have passed every check written so far.

`drive_overview.py` now inserts a second option ahead of the real one, carrying
an id no panel answers to, and drives both cases in the browser.

- **Reading the selection rather than the first option: it already did.** The
  real category, no longer first, still routes to `panel-cat-dss`.
- **A category with no panel of its own: it blanked the page.** Clicking a tile
  called `switchBrandTab('cat-<id>')`, which clears the active class from every
  panel before looking for its target, so an id nothing answers to left no
  panel active at all. The reader got a blank page and no error. `brsumGoTo()`
  now resolves `panel-cat-<id>` first and makes no route when there is none,
  which keeps the fix inside the Overview rather than changing Stage 2's
  navigation semantics.

The case is reachable: the picker lists the summary's deep-dive categories,
which is a different list from the config's category tabs.

This does not prove routing across two real categories. The second option
carries no data and no panel is built for it, in the same way
`drive_two_categories.py` says its clone is the same category twice. It closes
the reads-the-first-option gap and the no-such-panel gap, and no more.

## Known limits, stated rather than left to be discovered

- **The Overview was exercised on one category and one focal brand.** The IPK
  fixture has one deep-dive category, so the tile routing, the empty-gaps case
  and the funnel step were all driven against Dry Seasonings and Spices with
  Ina Paarman's Kitchen selected. The brand picker's other 14 brands were not
  each driven in the browser; the derivations behind them are covered by the
  node suite on synthetic snapshots instead.
- **The defend and build branch of "Opportunities" has not rendered in a
  browser**, because no brand in the fixture has a defend or build item. It is
  covered by the node suite, which asserts the classification, the sort order
  and the labels on a synthetic battery, but its rendered HTML has been seen
  only in that indirect sense.
- **No wave comparison exists.** The tiles carry the slot that will hold one.
  Nothing computes one.
- **The tile routing needs a category tab to route to.** A category whose id
  answers to no panel leaves the tile inert; that case is now driven in the
  browser (see the adversarial pass). A category whose id could not be derived
  at all gets no `data-cat-id` and its tiles are inert for the same reason;
  that path is read from the code, not executed, because no fixture produces
  it.
- **The example configs were not re-rendered in this stage.** The Overview is
  on the Summary tab, which every brand report carries, and the suite covers
  the skeleton; but `examples/1brand`, `examples/3cat` and `examples/9cat` were
  rendered under Stage 2, not under this build.

## What Duncan still owes

1. **A `launch_turas()` run on a real project, and an eyeball of the Overview.**
   This session generated the IPK fixture into a scratchpad only, and never
   touched OneDrive or TurasProjects.
2. **A ruling on two wordings**, both easy to change and both mine: the hero
   card is still titled "Brand at a glance", and the two Why cards are
   "Moments this brand owns" and "Associations this brand owns".
3. **A ruling on decision 8**, whether "Opportunities to examine" should be
   pinnable before Stage 5 gives it a destination toolbar.
4. Then a Fable pre-merge review, briefed as independent of this session.

**Not merged and not pushed.** Branch `feature/brand-overview`, four commits on
top of 6de087ef.

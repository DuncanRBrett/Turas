# Aggregate interactivity: design and recommendation

Fable 5.1, 4 September 2026. Answers `BRIEF_FOR_FABLE_aggregate_interactivity.md`.
Design only. No repo code was changed. The implementation brief for Opus is
`HANDOVER_AGGREGATE_INTERACTIVITY_FOR_OPUS.md` beside this file.

Every number below was measured this session on
`examples/integrated_demo/Output/tabs/report/Karoo_Demo_Crosstabs_report.html`
with the three scripts now in `docs/disclosure/experiments/` (`cube_measure.py`,
`cube_subtract.py`, `cube_size.py`). Every statement about what the engine
computes was read from the renderer files named, this session. Two limits on the
evidence are stated where they bite: the demo is unweighted (one distinct weight
value), and no node gate today runs the computed path against an R-built
microdata island.

---

## 0. Sequencing with the other two pieces of work

Three pieces of disclosure work now sit beside each other in this checkout:

1. The respondent-protection first pass, uncommitted at 00:30 to 00:48 on
   4 September: `delivery_manifest.R`, `turas_release_audit.R`, the `saveCopy`
   confirmation in `32_report.js`, and the `audienceBase()` fallback in
   `21d_disclosure.js`.
2. The build-hardening design and handover (island encoding, module stripping,
   obfuscator profile), not started.
3. This design.

This design depends on 1 and interacts with 2. The release audit whitelists
`data-micro` and `data-qual` as the respondent islands
(`.RELEASE_RESPONDENT_ISLANDS`, `turas_release_audit.R`); a new aggregate island
must be registered there as aggregate, and the manifest must gain a line for
it. Island encoding (stage 3 of the hardening handover) will encode the new
island if it carries the `data-island="v2"` marker, which it should. None of
that can start until the uncommitted files from piece 1 are committed. A
pricing session also committed in this checkout at 00:54, so the checkout is
live.

---

## 1. What was measured

### 1.1 The brief's cube counts reproduce

Four banner variables (Region 4, Gender 2, Age 5, Segment 4), 113 display rows,
600 respondents, k = 5.

| variables combined | combinations | occupied cells | cells with 0 < n < 5 | combinations with any such cell |
|---|---|---|---|---|
| 1 | 4 | 15 | 0 | 0 |
| 2 | 6 | 82 | 0 | 0 |
| 3 | 4 | 189 | 39 | 3 |
| 4 | 1 | 139 | 89 | 1 |

These match the brief's 15 / 82 / 189 / 139 and 0 / 0 / 39 / 89.

### 1.2 The unit that matters is the block, not the cell

Counting per (combination, question) block, where the base is the question's
answered base inside each cell rather than the cell's headcount:

| variables combined | blocks | blocks with a sub-k answered cell | blocks that ship |
|---|---|---|---|
| 2 | 66 | 0 | 66 |
| 3 | 44 | 27 | 17 |

So on this sample every pair ships for every question, and about two in five
triples ship, question by question.

### 1.3 Subtraction recovers a suppressed cell exactly

For Q006 in the Region by Age by Segment slice, the cell (3, 11, 12) has three
answered respondents, one each in rows 2, 3 and 4. Removing that cell and
keeping the Region by Age margin plus the other Segment cells in that margin
recovers the distribution `{2: 1, 3: 1, 4: 1}` by subtraction. Match: exact.
That slice has 78 occupied cells, 29 of them sub-k. Cell-level suppression on
its own is worthless once the margin ships, which is what the brief suspected
and what `22_model.js:663` already says.

### 1.4 Size of a cube on the demo

Serialised with the record shape in section 3, minified JSON, unweighted, k = 5:

| slices included | blocks shipped | blocks refused | bytes |
|---|---|---|---|
| order 1 | 44 | 0 | 17,155 |
| orders 1 and 2 | 110 | 0 | 99,873 |
| orders 1 to 3 | 127 | 27 | 129,293 |

The microdata island it replaces is 37,502 bytes. The order-2 cube is about
2.7 times the size of the records it protects, and about 8 percent of the
1.2 MB report. On a weighted report every sum becomes a float, so expect
roughly double.

### 1.5 What was not measured

The demo carries a single weight value, so nothing in this design about
weighted sums, effective bases or float rounding has been executed. The parity
project has a weighted configuration
(`modules/tabs/tests/fixtures/parity_project/Parity_Crosstab_Config_Weighted.xlsx`)
and is where every weighted claim must be checked. The node gate suite ran
green this session, 41 files, before any of this; it contains no test that runs
the computed path against an R-built microdata island, because
`regenerate_parity_island.R` writes only the aggregate layer.

---

## 2. Answers to the five questions

### Q1. Five statistics per cell is the right idea and the wrong unit

The engine does not have one base per cell. Reading `21_stats.js`, it has at
least five, and they differ on real questions:

| engine function | who is in the base | what accumulates |
|---|---|---|
| `tabulate` (line 340) | raw answer present, or box membership present | per category row, sum of w; base n, sum w, sum w squared |
| `netCounts` (line 390) | raw answer present only | per declared NET, sum of w over the union of members |
| `boxCounts` (line 423) | box present or answer present | per box row, sum of w |
| `indexMeans` (line 482) | score present | n, sum w, sum w squared, sum w times score, sum w times score squared |
| `seriesMeans` (line 554) | series value present, per item row | the same five, per item |
| `ratioOfTotals` (line 579) | both values present and denominator above zero | count, sum w times numerator, sum w times denominator |
| `medians` (line 517) | score present, unweighted reports only | the sorted distribution |

Three consequences.

A multi-mention NET is a union. Two members' counts do not sum to the union
because a respondent can sit in both rows, so every declared NET
(`q.net_members`) needs its own accumulator. The set of NETs is fixed at build
time, so this is cheap.

A median cannot come from sums. Precompute one scalar per cell on unweighted
reports; weighted reports already show no median under a filter
(`stats.medians` returns null when weighted).

The rest is derivable, and this is what makes the cube viable:

- Effective base is (sum w) squared over sum w squared, from two of the
  accumulators. `sigLetters` sizes every test on it.
- NET POSITIVE (`netScoreMeans`) is a mean of plus or minus 100 over the box
  base. Sum of w times score is 100 times (W plus minus W minus); sum of w
  times score squared is 10,000 times (W plus plus W minus). Both come from
  the box accumulators.
- "The rest" (Differences `restPct`, `applyCompositeSignificance`, the takeout
  cell family) is Total minus the column. Every accumulator is additive, so the
  rest is exact subtraction, no approximation.
- The takeout Welch test (`27da_takeout_stats.js:124`) takes arrays but only
  uses their moments: sum w, sum w squared, sum wx, and the centred sum of
  squares, which equals sum wx squared minus (sum wx) squared over sum w. All
  from the five.
- The KeyShare 0/100 score vector (`27fa`) is a row or NET share; its moments
  come from the row accumulators over the answered base.

Two things read the whole per-respondent vector for the full sample and are not
cell statistics at all: `robustRange` in `27d_diffs.js:144` (p5 and p95 of the
scores) and `gatherBimodality` in `27f_takeout_data.js` (a weighted histogram
per rated question). Both are full-sample, filter-independent, and become one
precomputed record per question.

One thing the brief did not list. The audience itself, everyone matching the
filter regardless of whether they answered a given question, is what the filter
bar (`26_filter.js:68`), `disclosure.audienceBase()` and the Reader's
`weightedAudience` (`24a_reader.js:31`) count. That needs a per-cell audience
record with no question condition: n, sum w, sum w squared.

So the answer to Q1 is: define the cell record as a named structure, generated
from the engine's own accumulation loops, and hold it to a parity test rather
than counting numbers. Section 3 gives the structure.

### Q2. The cut is an occupancy rule per block, not a fixed order

The brief's instinct, one-way and two-way only, is right as a default and wrong
as a rule. Section 1.2 shows 17 of 44 three-way blocks are perfectly shippable
on the demo, and on a 2,000-respondent tracker most would be. Conversely on a
250-person staff survey some two-way blocks will fail. The order is a size
lever; the safety rule is occupancy.

The rule. A block is one (variable combination, question). It ships whole or
not at all. It ships when every occupied cell's answered base for that question
is at least k. Within a shipped block, each optional record type (score,
series, ratio, the narrower net base) is present for every cell or absent from
the whole block, gated on its own base by the same k. Blocks that fail are
written as null so the renderer can say "not available at this base" instead of
computing a wrong number.

Why the banner counts as a variable. A view with one filter on A and banner B
reads cells of the A by B slice, so "one filter plus a banner" is order 2, and
"two filters on the Total column" is also order 2. The renderer must resolve
the required slice from the filter list plus the banner before it looks
anything up.

Why the rule has no cross-order leak. Cells of a coarser combination are unions
of cells of a finer one, so bases only grow as variables are dropped. If a
finer block ships, every projection of it ships too. If a finer block is
refused, no sibling cells of it exist anywhere in the file, so there is nothing
to subtract from the margin. Section 1.3 is exactly the case this prevents.

Recommended defaults: order cap 2, raisable to 3 in config, never higher. The
cap exists for file size and for the picker's honesty, not for safety.

Which variables. The declared banner groups, plus any question the analyst
lists in a new Settings key as a filter variable. Version 1 should accept only
single-response questions (a partition) and box-category banners (also a
partition). A multi-mention filter variable is a union of overlapping levels
and needs inclusion and exclusion terms for a two-row filter; it is a version 2
item and the design should say so rather than half-support it.

### Q3. The suppression rule that is defensible without emptying the report

The rule in Q2 is the suppression rule. Three additions make it complete.

First, k must be set. A cube build with `min_reporting_base` at its default of 1
protects nothing, so the build refuses (`CFG_CUBE_NEEDS_K`) rather than
shipping an unprotected cube under a safe-sounding name.

Second, the published tables must be held to the same standard. Today
`applyDisclosureSuppression` (`22_model.js:666`) blanks a sub-k column at render
time from `col.base`, and `data-agg` still carries the figures. In a client-safe
build the R side must blank those column figures before serialisation, or the
cube is held to a stricter rule than the table beside it and the margin leaks
what the cube withheld. This is a small change in `data_layer_writer.R` where
`bases` and per-row `n`/`pct` are written.

Third, be honest about the residuals, which are the same residuals every set of
published crosstabs has. A cell of exactly k in which everyone gave the same
answer discloses that answer for the group; Fréchet bounds across several
two-way slices can pin a three-way cell in degenerate cases. The standard for
this file is "no worse than a published crosstab column with base k", stated in
the manifest, not "no arithmetic inference of any kind", which no published
table meets.

What this costs on the demo at k = 5: nothing at order 2, and 27 refused
question blocks at order 3. On a small sensitive survey it costs exactly the
combinations that would have identified people, which is the point.

### Q4. Custom banners: declared variables only, and that is the whole answer

"Cross every table by" any question makes the slice set the questionnaire. There
is no safe version of that. In cube mode the picker offers only the declared
variables (banner groups plus the configured filter list), the "Cross anything"
wording goes, and a saved custom or composite banner that names an undeclared
question renders Total only, which is the existing missing-spec behaviour in
`columnsFor`.

A composite banner survives, restricted: each spotlight column must be a set of
levels of one declared variable. Its vs-the-rest test is subtraction and works
exactly. Two columns from different declared variables are fine; they are two
order-1 lookups.

The way to keep more is to declare more. A filter variable costs one order-1
slice plus one order-2 slice per other variable, and the occupancy rule gates
each of them. On the demo a fifth declared variable with four levels would add
roughly 20 KB at order 2. The analyst who knows the client will want to cut by
"store visited" declares it; the client cannot invent a cut that was not
declared.

### Q5. Alternatives considered and set aside

Synthetic microdata fitted to the margins. The engine already knows the idea
(`TR.MICRO.synthetic`, `32_report.js:379`). It keeps every feature and ships no
real person. Rejected because any filtered figure beyond the fitted margins is
invented, and a report that prints invented numbers under real labels fails the
one rule this codebase does not bend.

Noise, differential privacy, controlled rounding. Standard statistical
disclosure control, and defensible in principle. Rejected for this design
because the acceptance criterion is parity to displayed precision with the
current engine. A rounded-cube mode could be a later, softer option for
studies where an order-3 cube is wanted and k is small; it is not the first
version.

Encrypting the microdata island with a key held elsewhere. Rejected: the file
must work offline forever, so the key is in the file.

The cube stands. Its honest description is: the published crosstabs, extended
to every declared two-way (and optionally three-way) cut that clears k, in a
form the existing engine can compute from.

---

## 3. The cube

### 3.1 Island

A new `data-cube` island, parsed in `shell.boot` beside `data-micro`, held as
`TR.CUBE`, null when absent. Marked `data-island="v2"` in the template so the
hardening work encodes it. Registered in the release audit as an aggregate
island, never a respondent one.

```
{
  "schema_version": 1,
  "n": 600,                      // respondents in the study
  "k": 5,                        // the threshold the cube was cut at
  "order": 2,                    // highest combination order present
  "vars": {                      // declared variables, in slice-key order
    "Region":   { "kind": "banner", "levels": [3, 4, 5, 6] },
    "Age_Group":{ "kind": "banner", "levels": [9, 10, 11, 12, 13] },
    "Q008":     { "kind": "question", "levels": [0, 1, 2, 3] }
  },
  "questions": {                 // per question, filter-independent facts
    "Q001": { "has": ["answers", "scores", "boxes"],
              "robust_range": 9, "histogram": {"lo": 0, "counts": [ ... ]} }
  },
  "slices": {
    "Region": {                  // order 1
      "cells": { "3": { "a": [150, 150, 150] }, ... },       // audience per cell
      "Q001": { "3": { "b": [148, 148, 148], "r": {"0": 12, "1": 30, ...},
                       "x": {"11": 40, "12": 90}, "s": [148, 148, 148, 1110, 8700] },
                ... },
      "Q009": null               // refused: a cell under k for this question
    },
    "Region*Age_Group": { ... }  // order 2, key is the vars in declared order
  }
}
```

Levels for a banner variable are the zero-based `TR.AGG.columns` indices its
`banner_vars` array already uses; levels for a question variable are category
row indices, the same values a filter's `rows` carries. A cell key is the
levels joined with `|` in slice-key order. A respondent in no column of a banner
(`-1`) is not in any cell of that slice; that matches `columnsFor` today, where
such a respondent appears in Total but in no column.

Per cell records, each present only when the question carries the source:

| key | contents | mirrors |
|---|---|---|
| `a` | n, sum w, sum w squared over everyone in the cell | `stats.mask` + `weightedAudience` |
| `b` | the same three over the answered base | `tabulate` base |
| `nb` | the same three over the raw-answer base, only when it differs from `b` | `netCounts` base |
| `r` | row index to sum w | `tabulate` counts |
| `n` | NET row index to sum w over the union | `netCounts` |
| `x` | box row index to sum w | `boxCounts` |
| `s` | n, sum w, sum w squared, sum w times score, sum w times score squared | `indexMeans` |
| `m` | median scalar, unweighted reports only | `medians` |
| `sr` | item row index to the five `s` numbers | `seriesMeans` |
| `rt` | count, sum w times numerator, sum w times denominator | `ratioOfTotals` |

Sums are written with `digits = 8` like the microdata island today. Whether
that rounding ever flips a displayed figure is a question for the parity gate,
not for this document; on an unweighted report every sum is an integer.

### 3.2 Built from the microdata, in R

The cube is a pure function of the microdata list that `build_microdata()`
returns plus the data layer. It should be built from that list, in memory,
never from the survey data directly. Then the cube and the JS engine consume
byte-identical inputs, and any difference between them is an accumulation bug
rather than a mapping bug. New file `modules/tabs/lib/cube_writer.R`,
`build_cube(micro, data_layer, config_obj)`, with `serialize_cube()` beside it.
The microdata list is discarded after the cube is built in cube mode; it never
reaches `write_html_report_v2`.

### 3.3 The engine seam

`21_stats.js` keeps every public signature. Each function that walks
respondents gains a cube branch chosen once, by `TR.CUBE && !TR.MICRO`. The
shape returned is unchanged: `{base, counts, wbase, effBase}`,
`{base, n, wbase, effBase}`, `{mean, sd, k}`. Above the seam, `22_model.js`,
`27d_diffs.js`, `27f_takeout_data.js` and the views need only the routing
changes in section 4, and every existing gate above the seam keeps passing.

Three representations change in cube mode:

- `stats.mask(filters)` returns an audience spec `{cube: true, sel: {var:
  [levels]}, count}` rather than a Uint8Array. `maskCount` reads `count`.
  Nothing outside `21_stats` may index a mask; the two places that do
  (`27d_diffs.js:61`, `22_model.js:520`) are routed through a new
  `stats.restOf(col)`.
- `columnsFor` returns columns carrying `sel: {var, levels}` instead of a
  `member` array. `member: null` still means Total.
- A lookup resolves (audience spec, column spec) to the required slice, refuses
  with a typed reason when the slice is above the order cap or the block is
  null, and otherwise sums the matching cells.

The refusal reaches the user as a sentence in the filter bar and in the card,
never as a base of 0 against real figures. That is the same contract
`notRecomputable` already has for ranking questions.

### 3.4 What cube mode shows, and what it does not

Works, exactly as with microdata, subject to the block rule: filters up to the
order cap on declared variables; every declared banner under a filter; custom
banners on declared variables in both category and NET modes; composite
banners restricted to declared variables; Differences; Pattern Recognition
(its cell family is banner group versus the rest, all order 1); confidence
detail; the Reader's audience strip and passages; disclosure panels.

Refused with a message: a filter on an undeclared question; more filters than
the cap; a question whose block is null for the requested slice.

Gone: filtered qualitative views. `qual.maskFilter` needs a per-record
membership and there is none. It must return the unfiltered records only when
no filter is set and hide the filtered view otherwise, the same fail-closed
path the no-microdata build already takes at `27q_qualitative.js:209`.
Comments still k-anonymise R-side exactly as today.

Unchanged: tracking, which is built from published figures since August.

---

## 4. Direct readers of `TR.MICRO` and what each needs

Listed from the grep this session. Everything not listed reads through
`TR.stats` and needs nothing.

| file | line | reads | in cube mode |
|---|---|---|---|
| `20_data.js` | 242, 255, 364 | `boxes[q]` existence, `hasMicrodata`, hash filter validation | `questions[q].has`; a new `d2.hasComputedSource()` true for either island; hash validation also checks the variable is declared |
| `21c_confidence.js` | 239 | `n` | `TR.CUBE.n` |
| `21d_disclosure.js` | 61 | `n`, mask count | audience spec count |
| `22_model.js` | 184 to 190 | `recomputable(q)` | `questions[q].has` |
| `22_model.js` | 515 to 531 | `n`, rest arrays, `boxes` | `stats.restOf` |
| `24a_reader.js` | 33 to 38, 70, 530 | weights loop, `n` | audience record `a` |
| `26_filter.js` | 68 to 84, 200 | `n`, mask count, `boxes` for box filters | audience count; picker limited to declared variables |
| `27d_diffs.js` | 61, 80, 185 to 214 | rest arrays, `boxes`, `series`, `scores` for `robustRange` | `stats.restOf`; `questions[q].robust_range` |
| `27f_takeout_data.js` | 424, 525 | `scores`, `weights`, `banner_vars` arrays for the cell family and bimodality | cell family from order-1 slices via a `stats.momentsOf(q, col, audience)`; histogram from `questions[q].histogram` |
| `27q_qualitative.js` | 209, 1980, 2202 | mask, `banner_vars` | fail closed under a filter, as with no microdata |
| `31_selftest.js` | 28, 59 | `n` | skip the microdata cases when `TR.MICRO` is null |
| `32_report.js` | 379, 507, 513 | `synthetic`, `answers`, `n` | `_copyCarriesMicrodata()` stays false; the About page states the cube's k and order |
| callers of `d2.hasMicrodata()` | `22_model.js` 706 and 737, `24a_reader.js` 70, `25_cards.js` 509, `27d_diffs.js` 255 and 364, `26_filter.js` 58 | whether a view takes the computed path at all | every one routed to a new `d2.hasComputedSource()`, or cube mode renders published tables under a filter without saying so |

---

## 5. Configuration

Three Settings keys, all registered in `build_config_object()` in
`crosstabs_config.R` (the whitelist that silently drops unregistered keys) and
in the settings name lists near lines 808, 830 and 1725.

| key | values | default | meaning |
|---|---|---|---|
| `html_report_v2_interactivity` | `records`, `cube`, `none` | `records` | what powers live views. `records` is today's microdata island; `cube` is this design; `none` is published only |
| `html_report_v2_filter_vars` | comma-separated question codes | blank | extra declared filter variables beyond the banner groups |
| `html_report_v2_cube_order` | 1, 2 or 3 | 2 | highest combination order to precompute |

`html_report_v2_microdata = N` keeps working and means `none`. Setting it to
`N` alongside `interactivity = cube` is a config refusal, not a silent
precedence.

`cube` requires `min_reporting_base` above 1 (refusal `CFG_CUBE_NEEDS_K`), and
in `cube` and `none` modes the R side blanks sub-k published columns before
serialisation (section 2, Q3).

The delivery manifest gains one line: "Interactivity: aggregate cube, k = 5,
combinations up to 2, 110 of 110 blocks shipped. No respondent-level records."
The release audit, in a client-safe build, refuses on a populated `data-micro`
as it does now and additionally parses `data-cube` and refuses if any cell has
0 < n < k or any slice contains a partial block.

---

## 6. Acceptance criteria, restated so they can be executed

The brief's two criteria are right. They become four gates.

1. Parity. On the parity project, both configurations, for every question, every
   banner, and every filter of order 1 and 2 over the declared variables: every
   displayed percentage, mean, base and significance letter from the cube
   engine equals the one from the microdata engine. Letters exact, figures to
   displayed precision. Node gate, new file, plus the R writer's own testthat.
2. Block rule. In the built cube, no cell record has a base with 0 < n < k, no
   slice has a partial block, and every projection of a shipped block is shipped.
   R test on `serialize_cube()` output, and the same check inside the release
   audit on the finished HTML.
3. Adversary. A script given only the delivered HTML: `data-micro` parses to
   null; `data-cube` contains no array whose length equals `n`; no cell under k.
   This is the brief's reconstruction test in checkable form. It sits in the
   release audit so it runs on every client-safe build.
4. The suite. Every existing node gate and every tabs testthat file green, counts
   quoted from the run, in both `records` and `cube` modes where a test loads
   an island.

Section 1.5 is the caveat that matters: gate 1 has no harness today because the
parity fixture ships no microdata. Building that harness is the first stage of
the handover, before any engine code moves.

---

## 7. Decisions for Duncan

Decided 4 September 2026: Duncan took all five recommendations below as
written.

1. Default. This design leaves `records` as the default, matching the
   case-by-case policy from 4 September. Flipping the default to `cube` is a
   product decision for after the parity gate has run on a real weighted
   project. Recommendation: do not flip yet.
2. Order cap 3. Allowed by config, default 2. Recommendation: yes, because the
   block rule makes it safe and small trackers will want it.
3. Multi-mention filter variables. Not in version 1. Recommendation: agree,
   and say so in the settings template text.
4. Blanking sub-k published columns R-side in `cube` and `none` modes. This
   changes what `data-agg` carries on those builds only, and `none` is what
   SACS runs, so the handover gates its stage 3e on this answer.
   Recommendation: yes; without it the cube is stricter than the table beside
   it.
5. SACS. Unchanged by this design: non-interlocking banners on a `none` build
   need no cube. Once the cube exists, SACS could ship `cube` with order 1 and
   gain nothing over `none`, so leave it on `none`.

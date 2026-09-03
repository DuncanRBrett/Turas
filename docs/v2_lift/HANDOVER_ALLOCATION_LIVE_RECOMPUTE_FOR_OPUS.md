# Handover: Allocation live recompute. Shape decision and build brief

Written 2026-09-03 by the Fable session that answered section 3 of
`BRIEF_ALLOCATION_LIVE_RECOMPUTE.md`. Read that brief first; this document
does not repeat its sections 1, 2 and 4. Section 1 here is the decision, the
rest is the build. For Opus 5 at high effort. No code was written or run in
the design session: every line number below was read on `main` at `32661caf`
on 2026-09-03 and will drift as you edit.

## 0. Session rules

- `git branch --show-current` and `git rev-parse --show-toplevel` before the
  first edit. Work on a branch off `main`; Duncan merges and pushes. Never
  amend a pushed commit.
- Nothing is written into `examples/*/Output` or OneDrive. Duncan regenerates
  through `launch_turas()`. A synthetic config (the Karoo integrated demo, the
  parity fixture) may be run into the scratchpad.
- The tabs R suite and every `modules/tabs/lib/html_report_v2/tests/*_tests.mjs`
  file must be green, quoted from the run, before anything ships.
- No em dashes in any string that reaches Duncan or a client: UI labels,
  badge text, console lines, commit messages.

## 1. The decision

Nine rulings. D1 to D3 are the shape. D4 to D9 are the rules that keep the
shape honest. Proceed on all nine unless Duncan says otherwise at the start
of the session; note in the commit that they were the recommended option.

### D1. `TR.MICRO.scores` stays flat. A new island key carries the k series.

`scores[code]` is one number per respondent and six consumers assume exactly
that: the mean, median and ratio recomputes in `21_stats.js` (482, 517, 550),
the Differences scan in `27d_diffs.js` (`meanFindings`, 173), the Patterns
cell family in `27f_takeout_data.js` (`familyEligible`, 403, plus two
`micro.scores[q.code].length` reads at 442 and 535), and the R wave tracker in
`tracking_island.R` (`wave_contribution`, 241, which does `as.numeric(sc)`).
Overloading the key with an array of arrays, or with `code#row` pseudo-codes,
puts a wrong shape in front of all six at once. So `scores` is untouched, and
Allocation lives under a new key:

```
TR.MICRO.series = {
  "<qcode>": { "<rowIndex>": [ value | null, ... n entries ], ... }
}
```

### D2. Series are keyed by data-layer row index, not by label.

`rowIndex` is the zero-based position of the item's mean row in that
question's `rows[]` in the aggregates island, the same convention `boxes`,
`net_diffs` and `net_members` already use. The writer consumes the built data
layer (`build_microdata`, `microdata_writer.R:697`, is already handed it), so
the index it writes is the index the renderer reads and the two cannot drift.
Labels were rejected: an Allocation label is whatever `build_allocation_labels()`
(`allocation_processor.R:120`) resolved, DisplayText or OptionText or
`{code}_{i}`, and the data layer collapses two rows with the same label into
one (`pair_ids`, `data_layer_writer.R:781`). See D8 for what happens then.

The R writer maps a row to its data column by walking the question's mean
rows in order and pairing row j with option j, then column `{code}_j`. It
must resolve the labels through `build_allocation_labels()` and check that
the row's label equals label j before trusting the pairing; a mismatch means
the data layer reordered or dropped a row, and the question then gets no
series (D8), never a shifted one.

Values are the raw slot values as numbers, NA where the slot is blank or
non-numeric, exactly what `collect_allocation_values()` averages. Zero is a
value. No range filter applies (an Allocation has no Min_Value/Max_Value).

### D3. `answers[code]` marks who is in the base. Only when a series exists.

Today `micro_answers_for_question()` returns a full column of NA for an
Allocation (`microdata_writer.R:236`). It becomes: `MICRO_ANSWERED_UNSHOWN`
(-2) for every respondent with at least one non-NA numeric slot, NA for the
rest. That is `calculate_allocation_base()` (`question_orchestrator.R:254`)
restated per respondent, so the recomputed base under a filter is the
published base rule, and it is the unbinned-numeric convention already at
`microdata_writer.R:255`. `stats.tabulate` (`21_stats.js:340`) counts -2 in
the base and tallies nothing, which is right: an Allocation has no category
rows.

The marker is written only when the series for that question was built. If
D8 refused the series, `answers` stays all-NA, `recomputable()` stays false,
and the card keeps today's "n/a under filter" badge (`25_cards.js`, about
686). A base with blank rows under it would be worse than the badge.

### D4. `recomputable()` stays a boolean per question.

D3 already makes it true through the answers channel. Add
`TR.MICRO.series && TR.MICRO.series[q.code]` to `recomputable()`
(`22_model.js:183`) anyway, so the contract is explicit. Per-row honesty is
handled where the row is built: a mean row with no series entry renders
`null` in every cell, the same way `statValues()` (`22_model.js:41`) already
blanks a median on a weighted run. No per-row flag on the question.

### D5. Significance under filter follows the numeric mean. It is not "descriptive only".

The reader's existing rule for a headline mean under a filter, at
`22_model.js:219` to 245: recompute mean, sd and Kish effective base per
column, then `TR.stats.sigLetters(..., isMean = true, dual)`, a Welch test
with the dual 95/80 letters, the low-base threshold and the Bonferroni
divisor. R's published letters for an Allocation come from
`build_allocation_sig_row()` calling `add_significance_row(..., "mean", ...)`,
one Sig. row per option, the same family. So each Allocation item row is
tested exactly like a numeric mean, independently of its sibling rows, and
the parity fixture (D9) pins the two engines to the same letters. No new
rule, no "descriptive" caveat. The classic maxdiff report's segments panel
says "descriptive only" because its numbers are count-based
(`08_segments.R:202` works from `long_data`, not from utilities); HB shares
per respondent carry the information a test needs, which is the whole point
of the export gate in `12_tabs_export.R`.

### D6. Payload. Measured, acceptable, no new rounding rule.

Measured this session, read-only, on two generated reports:

| Report | Report bytes | Micro island bytes | n | Allocation questions | Series to add |
|---|---|---|---|---|---|
| Karoo integrated demo (`examples/integrated_demo/Output/tabs/report/`) | 1,255,689 | 37,502 | 600 | MDSHARE (10 items), CJIMP (5) | 15 |
| VAS 2026 (`Reporting/Reporting Data/Crosstabs/VAS_Crosstabs_report.html`, OneDrive) | 5,912,588 | 2,923,329 | 1,100 | WalletLoc, WalletLocPct, WalletLocTxn, WalletLocTxnPct (6 rows each), WalletSectionPct (13) | 37 |

A share or percentage at `digits = 8` serialises at about 11 bytes with its
comma. Upper bound of the addition: demo 15 x 600 x 11 = about 99 KB (8% of
the report); VAS 37 x 1,100 x 11 = about 448 KB (7.6% of the report, 15% of
the island). Keep the existing `serialize_microdata()` (`digits = 8`) and add
no rounding: the published mean is computed at full precision and the parity
fixture compares letters exactly, so a rounding rule would be a second thing
to keep in step for a few hundred kilobytes. After the build, measure both
reports again and record the numbers in the commit. Revisit only if a real
config grows by more than 15%.

### D7. Row-unaware consumers are excluded explicitly, with a test each.

These read one series per question and would silently take item 1 as "the
question" or fall over on the shape. Each is excluded in this build and
listed in section 5 as a follow-up:

- `27d_diffs.js` `meanFindings` (173) takes the first headline mean row. For a
  question carrying `series` and no `scores` it must return `[]`. Test: an
  Allocation question yields no Differences finding.
- `27f_takeout_data.js` `familyEligible` (403) reads `scores` only, so an
  Allocation stays out by construction. Test that it does, so nobody later
  "fixes" it by reading `series`.
- `tracking_island.R` `wave_contribution` (241) reads `micro$scores` only, so
  an Allocation contributes no wave metric. Test that it does not.
- `22_model.js` `applyCompositeSignificance` (487) uses `indexMeans`, which
  is null for an Allocation, so composite-banner arrows stay blank on those
  rows. Test that they do.
- `22_model.js` `attachIntervals` (389) uses `waves.scoreMap`, category based,
  so Allocation rows get no interval. Acceptable now; a series-based interval
  (z x sd / sqrt(n_eff)) is a follow-up.

### D8. Duplicate labels refuse the series, out loud.

If two options of one Allocation resolve to the same label, the data layer
has fewer mean rows than the question has columns and no row-to-column
pairing is safe. The writer then emits no series for that question and no -2
markers (D3), and prints one console line naming the question and the
duplicated label, in the boxed TURAS WARNING style `tracking_island.R` uses.
The published table is untouched. Test: a three-option Allocation with two
options labelled "Other" ships with all-NA answers and no series entry.

### D9. The island contract validates the new key, and the parity fixture carries an Allocation.

`d2.validate` (`20_data.js:137`) gains: every array under
`micro.series[code]` has length `n`, else `DATA_MICRO_SERIES`. The cross-engine
parity fixture (`modules/tabs/tests/fixtures/parity_project/`, generator
`generate_parity_project.R`, both `parity_island.json` and
`parity_island_weighted.json`) gains one Allocation question with a known
mean per column and at least one column pair that separates at 95% and one
that separates only at 80%, so `test_cross_engine_stats.R` and
`parity_stats_tests.mjs` pin R's carried letters to the JS recompute on
Allocation rows, weighted and unweighted. Regenerate the committed islands
deliberately; the README calls this a permanent gate.

## 2. Alternatives considered and why not

- **`scores[code]` becomes an array of arrays.** Breaks the six consumers in
  D1 in one move, and every one of them fails quietly (a `.length` of k, a
  `null` mean) rather than loudly.
- **Pseudo-codes `scores["MDSHARE#3"]`.** Keeps the consumers' shape but puts
  keys that are not question codes into a map that `wave_contribution` and the
  Patterns family iterate by question. They would skip them today and trip
  over them the first time someone iterates the map.
- **Series keyed by label.** Rejected in D2; labels are resolved, deduplicated
  and normalised in three places and none of them is the writer.
- **`recomputable()` per row.** Adds a flag the renderer, the xlsx export and
  the PPTX export would all have to learn. D4 gets the same honesty from a
  `null` cell.

## 3. The build, in order

Each step lands with a test that fails on the code as found and passes with
the change. Stage by verifiability; do not start step 2 until step 1's R tests
are green.

### Step 1. R writer (`microdata_writer.R`)

1. New `micro_series_for_question(dl_q, survey_data, survey_structure, n)`:
   returns NULL unless `micro_variable_type()` is "Allocation"; walks the mean
   rows, pairs them with `build_allocation_labels()` (source
   `allocation_processor.R` in the test file, as `test_microdata_numeric.R`
   sources `numeric_processor.R`), refuses on a label mismatch or duplicate
   (D8), otherwise returns a list keyed by zero-based row index of
   length-n numeric vectors.
2. `micro_answers_for_question()` Allocation branch (236): -2 / NA per D3, but
   only if the series builds; keep the full-length guarantee the two tests at
   `test_microdata_numeric.R:221` and `:230` protect. The first of those tests
   changes meaning (it asserts all-NA today); rewrite it, do not delete it.
3. `build_microdata()` (697): `out$series` when non-empty, omitted otherwise so
   every existing report's island is byte-identical.
4. Tests, in `test_microdata_numeric.R` next to the existing Allocation block:
   series values equal the slot values with zero kept; NA slot gives null;
   answers are -2 exactly where any slot is non-NA; a respondent with every
   slot NA is NA; label mismatch and duplicate label refuse (D8); the island
   omits `series` when no Allocation is present; `serialize_microdata` renders
   a series as a length-n array at n = 1.
5. Confirm `qual_quant_layer.R:194` and `run_crosstabs.R:945`, the two callers
   of `build_microdata`, need no change (they pass the built data layer).

### Step 2. Reader (`21_stats.js`, `22_model.js`, `20_data.js`)

1. `stats.seriesMeans(q, rowIndex, columns, mask)`: `weightedMeanColumn` (456)
   over `TR.MICRO.series[q.code][rowIndex]`, returning the same
   `{mean, sd, k}` per column `indexMeans` returns. Use
   `Object.prototype.hasOwnProperty.call` on the maps; question codes can be
   "constructor" (see `poison_keys_tests.mjs`).
2. `computedModel` mean branch (219): before the `if (!means)` blank-out, if
   the row has a series entry, take `seriesMeans` for its values and
   `sigLetters(..., true, dual)` for its letters, per D5. Rows without an entry
   keep today's path.
3. `recomputable()` (183) per D4. `d2.validate` (137) per D9.
4. New node suite `allocation_series_tests.mjs`, built like
   `numeric_stat_rows_tests.mjs`: a two-item Allocation with a hand-computed
   weighted mean per column; letters match a hand-computed Welch; an item row
   with no series entry renders null cells; the base equals the count of -2
   markers; a filter changes the means and the base together; the xlsx export
   (`23y_xlsx.js`) of the computed view carries the recomputed values.
5. Parity fixture per D9. Run `regenerate_parity_island.R`, then both halves
   of the gate.

### Step 3. The exclusions (D7)

One small change and one test each, in `27d_diffs.js`, `27f_takeout_data.js`
(test only), `tracking_island.R` (test only), `22_model.js` composite path
(test only). Put the four tests in the suites that already cover those files
(`diffs_tests.mjs`, `takeout_tests.mjs`, `test_tracking_island.R`,
`composite_tests.mjs`).

### Step 4. Prove it on a rendered report

1. Run the Karoo integrated demo's tabs config into the scratchpad (copy the
   config, point `Output_Folder` at the scratchpad; the demo is synthetic).
   Open the report in a browser, filter to one segment, read MDSHARE's
   recomputed means back, and compare them with the same subset's means
   computed in R from the `_tabs_shares.xlsx` DATA sheet. Screenshot the
   card with its COMPUTED badge for the commit.
2. VAS 2026 is Duncan's: he regenerates through `launch_turas()` and filters
   WalletSectionPct. Tell him which question and which filter to try.

### Step 5. Records

- `modules/tabs/lib/microdata_writer.R` header comment: add `series` to the
  documented shape.
- `BRIEF_ALLOCATION_LIVE_RECOMPUTE.md`: one line at the top pointing here.
- Measure both reports per D6 and quote the numbers in the commit.

## 4. Blindspots, and the world-class check Duncan asked for

Duncan's standard is a MaxDiff and conjoint tool that is world class,
extremely robust and user friendly, and he asked to be warned if the work
steers away. These are the places it could.

1. **The most visible gap today is the badge, not a missing panel.** In the
   Karoo demo MDSHARE and CJIMP show "n/a under filter" the moment a reader
   filters, on the two questions a client most wants to filter. This build
   closes that. Nothing in the classic report's seven panels is worth more
   to a client than a share table that stays true under any cut.

2. **Do not build a "segments" panel into the frozen MaxDiff tab.** The tab
   hides the filter bar by design (`27y_maxdiff.js` header). A copied segment
   table there would be exactly the frozen-under-filter number the brief set
   out to avoid. When the parity work (follow-ups handover, section 6)
   reaches the segments panel, it should be a pointer: "Preference shares by
   segment are question MDSHARE in the crosstabs, live under any filter."
   Same for CJIMP on the Conjoint tab.

3. **Parity with the classic segments panel is by meaning, not by number.**
   `compute_segment_scores()` is count-based; the crosstab is HB shares. The
   numbers will differ and the crosstab's are the better ones. Say so in the
   parity notes rather than chasing agreement.

4. **Head to head is exactly derivable from the series, two ways.** The
   classic figure (`utils.R:783`) is the mean over respondents of
   e^uA / (e^uA + e^uB). Because each respondent's shares are one softmax over
   all items, that equals sA / (sA + sB) per respondent, so the classic number
   is recomputable from the series to the decimal. The brief's "share_A >
   share_B exactly when u_A > u_B" gives a second statistic, the win rate.
   Both are live-filterable once `series` exists. Pick one for the panel and
   name it; showing both invites the reader to ask why they differ.

5. **Approximate shares under a filter.** When the empirical-Bayes fallback
   was allowed through (`Allow_Approx_Utilities_Export = YES`), the stamp
   lives in the QuestionText and survives a filter, so the card still says
   "approximate: count-based". Fine. But the follow-ups handover's R3
   (default the shipped config to NO) matters more once shares are live:
   letters on count-based shares under a filter look exactly like letters on
   posterior shares. Keep R3.

6. **Excluded respondents are invisible in the base.** The exports drop
   respondents with flat part-worths or all-NA utilities; they are NA in every
   slot and fall out of the base under D3, matching the published base. The
   card's n will be below the survey n and nothing on the card says why. The
   METHOD sheet does. A follow-up: carry `n_excluded` into the QuestionText or
   a card note. Not this build.

7. **Weighted studies are the untested half.** Every Allocation study so far
   (VAS 2026, the Karoo demo) is unweighted, so `TR.MICRO.weights` was all 1s
   and weighted and unweighted took the same path. The weighted parity island
   in D9 is the only place the weighted Allocation letters get checked before a
   client sees them. Do not skip it.

8. **A pre-existing oddity to check, unverified.** `published_wave_contribution()`
   (`tracking_island.R`, about 330) gates on `tracking_has_mean_row()`, and an
   Allocation has k mean rows, so on a confidential (no-microdata) build an
   Allocation may already be listed as a wave metric with no clear value. Not
   caused by this work. Read it, and if it is real, note it in the commit and
   leave it for the tracking follow-up rather than widening scope here.

9. **What "robust" means for this feature.** The failure modes that matter
   are the silent ones: a series shifted by one column (D2's label check), a
   duplicate label (D8), a base of respondents who never saw the exercise (D3
   mirrors the published rule), and a consumer that takes item 1 as the
   question (D7). Each has a named test above. A feature that refuses out loud
   on those and recomputes correctly on everything else is what world class
   looks like here; more panels are not.

## 5. Follow-ups, not this build

- Row-aware Differences findings for Allocation items (D7, `meanFindings`).
- Per-item wave tracking for Allocation questions (D7, `wave_contribution`;
  needs a per-item key in Question_Mapping).
- Series-based intervals on Allocation rows (D7, `attachIntervals`).
- Head to head and segments panels on the MaxDiff tab, built on `series`
  (section 4, items 2 and 4), as part of the parity work in
  `HANDOVER_MAXDIFF_V2_FOLLOWUPS_FOR_OPUS.md` section 6.
- `n_excluded` on the card (section 4, item 6).

## 6. Verification bar and baselines

- Tabs R suite: the brief's baseline is 5,294 pass / 0 fail / 1 skip on
  `963d66bd`. The design session did not re-run it; run it before the first
  edit and quote the fresh number.
- Node gate: run this session on `32661caf`, all 40 `*_tests.mjs` files green,
  1,003 assertions passed, 0 failed. Loop them exactly as `modules/tabs/README.md`
  shows; there is no single runner.
- Both parity islands regenerated and both halves of the gate green.
- The rendered-report proof in step 4, with the R-side subset means beside
  the browser's, in the commit message or a notes file under `docs/v2_lift/`.
- Report sizes before and after per D6.

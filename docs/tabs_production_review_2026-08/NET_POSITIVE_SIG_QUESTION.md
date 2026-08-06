# What should a NET POSITIVE row's significance letters test?

**Raised:** 2026-08-06, out of Job I-stats (finding I5) in
`FINAL_REVIEW_2026-08-06.md`.
**Status:** ANSWERED and IMPLEMENTED, 2026-08-06 — see
`NET_POSITIVE_SIG_DECISION.md` (option 3: score the respondents +100/−100/0 and
test the mean). This document is kept as the brief that framed the question;
read the decision for what was built and what it changed.
**For:** a fresh session (Fable). Brief it with THIS document only — the session
that raised it already leans one way and should not frame the answer.

---

## The question in one line

The NET POSITIVE row prints top box **minus** bottom box; its significance
letters test the **top box alone**. Should they?

## What the code does today (verified by reading, 2026-08-06)

`add_net_positive_row()` (`modules/tabs/lib/standard_processor.R:1155`) writes a
row labelled `NET POSITIVE (<top> - <bottom>)` whose value is

```
top_pct - bottom_pct      # both as % of the column's weighted base
```

`add_net_positive_significance()` (`:1064`) builds one `test_data` entry per
banner column carrying `count1` = the top-box count and `count2` = the
bottom-box count, hands it to `run_net_difference_tests()`
(`modules/tabs/lib/weighting.R:1382`), and then takes **only `$net1`**
(`:1119`, and `$net1_2` for the secondary alpha at `:1129`). `$net1` is a
two-sample z-test of the **top-box proportion** between two columns. `$net2` —
the same test on the bottom box — is computed and discarded on this path.

This is not a leftover. The other consumer of the same function,
`add_net_significance_rows()` (`:849`), uses **both** `$net1` and `$net2`
(`:922`), because there it is attaching letters to the two BoxCategory rows
themselves (`Top 2 Box`, `Bottom 2 Box`), and each of those rows genuinely IS a
column proportion. That path is correct and is not in question here. The
question is only the NET POSITIVE row, which prints a quantity neither test
describes.

The label "Option A" that the review mentions is a code comment
(`:1141`, `V9.9.5: NEW FEATURE - Net Positive Option A`) — the name the feature
was built under, not anything a reader sees.

## What that means on a deliverable

Both directions bite, on ordinary data:

- **Two columns with the same top box and different bottom boxes print
  different NET POSITIVE values and can never letter against each other.**
  A: top 60%, bottom 10% → NET +50. B: top 60%, bottom 40% → NET +20. Thirty
  points apart on the page, and the test sees two identical 60%s.
- **Two columns with the same NET POSITIVE can letter against each other.**
  A: top 60%, bottom 30% → NET +30. B: top 45%, bottom 15% → NET +30. Same
  printed number, and a 15pp top-box gap that can be significant.

A reader has no way to tell either from the report. The letters sit directly
under the NET POSITIVE value.

## Why it is not obviously a bug

The naive fix — z-test the printed difference the way two independent
proportions are tested — is **wrong**, and that is why this is a decision rather
than a repair. Top box and bottom box come from the same respondents in the same
column: they are two cells of one multinomial, negatively correlated by
construction. Their difference has a variance the independent-samples formula
does not give. Whatever replaces the current test has to account for that
correlation, or the letters will be wrong in a new and less visible way.

## The options, as they look from here

Each needs its variance written down, not just named.

1. **Leave it, and say so.** Keep the top-box test and label the row's letters
   honestly (a footnote, or a Sig-row label that says what was tested). Cheapest,
   changes no published letter, and stops the report implying something it never
   computed. Does not give the reader a test of the number they are reading.

2. **Test the net as a difference of two correlated proportions.** For one
   column, `d = p_top - p_bottom` has
   `Var(d) = (p_top + p_bottom - (p_top - p_bottom)^2) / n` under the
   multinomial (stated from recall — **derive and check it, do not take it from
   this document**), and the two columns are independent of each other, so the
   two variances add. Effective-n and the FPC substitute for `n` the same way
   they already do elsewhere. This tests the printed quantity. It changes
   published letters on every NET POSITIVE row that exists.

3. **Make the row a mean of scores.** Score top box +100, bottom box −100,
   everything else 0; the mean IS the net, and the existing weighted-t path
   tests it with no new variance formula. This is exactly what Job I-stats just
   did for NPS (`calculate_nps_score`, `nps_bucket_score` in
   `modules/tabs/lib/score_utils.R`) — worth reading as precedent, including its
   costs. Note the trap that fix surfaced: a column where every respondent is in
   one box has zero variance, and open finding **M-B** means two such columns
   test at p = 1 and draw no letter.

Option 3 has the strongest consistency argument (one mechanism for NPS and NET
POSITIVE) and the strongest tie to M-B. Option 2 is the most direct answer to
"test what is printed". Option 1 is the only one that ships no letter changes.
The session that raised this did not form a view worth passing on.

## Constraints any answer has to live inside

- **The letters are published.** Whatever changes must be diffed before/after on
  the parity fixture (`modules/tabs/tests/fixtures/parity_project/`) and noted in
  the stats pack Declaration (`modules/tabs/lib/stats_diagnostics.R`,
  the `assumptions` list — see the `NPS significance` and `Chi-square test`
  entries added by Job I-stats for the pattern). **The fixture currently has no
  NET POSITIVE row** (`show_net_positive = "FALSE"`, and Q2 declares only one
  BoxCategory), so exercising this means extending the fixture first — Q4 was
  added for NPS in the same job and is the worked example of how.
- **The machinery it must fit.** Letters restart per banner group; the
  Bonferroni divisor is that group's own `choose(k, 2)`; `significance_min_base`
  gates on the corrected effective base; dual alpha (`alpha_secondary`) needs
  both thresholds off one p-value; and as of Job I-stats a full-census column
  carries `fpc_mul = Inf` and must be excluded from pairing rather than tested.
  `weighted_z_test_proportions()` and `weighted_t_test_means()`
  (`modules/tabs/lib/weighting.R`) both already take `fpc_mul1`/`fpc_mul2`.
- **House rules.** No `stop()` — TRS refusals with boxed console output
  (`CLAUDE.md`). Write the test first and prove it fails against the pre-fix code
  by revert-run-restore. Do not push; Duncan verifies via `launch_turas()` and
  regenerates deliverables himself.
- **Baseline at handover** (local `main` @ `8a67ead4`): tabs R
  **4,160 / 0 / 0 / 0** (`testthat::test_dir("modules/tabs/tests/testthat")`),
  **29** JS suites green (27 in `modules/tabs/lib/html_report_v2/tests/` + 2 in
  `modules/tabs/tests/js/`), project-root suite 571 pass / 3 fail at its
  documented non-tabs baseline. Anything below that is a regression.

## What a useful answer contains

1. Which option, and why the other two lose.
2. The variance formula written out, with a hand-derived worked example that a
   reader can check with a calculator.
3. What it does to letters on a real table — before and after, on the parity
   fixture, extended to carry a NET POSITIVE row.
4. Whether the Declaration needs a new line, and its wording.
5. Whether the v2 JS engine needs the matching change so the two engines do not
   disagree (`modules/tabs/lib/html_report_v2/assets/js/21_stats.js`,
   `22_model.js`; the parity gate is `test_cross_engine_stats.R` +
   `parity_stats_tests.mjs`).

If the answer is option 1, items 2–3 collapse to "no letters change" and the
work is a label and a footnote.

## Related, deliberately not bundled

Job I-stats also left open whether the weighted chi-square correction should
move from the effective-base scaling it now uses to a Rao–Scott correction
(`survey::svychisq` — `survey` is already in `renv.lock` and used by
`modules/weighting`, though never by tabs). That is a separate question, it is
lower priority because `enable_chi_square` defaults to FALSE in both the template
and `build_config_object`, and it should not be answered in the same pass.

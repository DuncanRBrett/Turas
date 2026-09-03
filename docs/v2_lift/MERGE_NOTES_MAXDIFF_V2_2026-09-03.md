# MaxDiff v2 branch brought onto main: what the merge did, and what it found

Branch: `feature/maxdiff-v2-report`. Written 2026-09-03 by the Opus session
that did the merge, working from
`docs/v2_lift/HANDOVER_MAXDIFF_V2_REBASE_FOR_OPUS.md`. Everything below was
verified by execution in this session unless it says otherwise. The branch is
NOT merged to main and NOT pushed.

---

## 1. The merge

`git merge main` into the branch, in its worktree at
`.claude/worktrees/maxdiff-v2-report`. Merge base `6d3e0165`, main at
`db607112`. Commit `b9640bea`.

The handover listed 15 overlapping files. The real overlap was 23: main had
also moved on the tabs side since the branch was cut (the website demo, the
em dash purge, `show_save_copy`), which added `crosstabs_config.R`,
`generate_config_templates.R`, `24_shell.js`, `styles.css`, `template.html`,
`build_report_v2.R`, `run_crosstabs.R` and `run_tabs.R`. Only three of the 23
actually conflicted.

| Conflict | Resolution |
|---|---|
| `examples/maxdiff/Karoo_MaxDiff_Config.xlsx` | Took main's copy, the one Duncan edited in Excel to turn the HTML report on. |
| `modules/tabs/run_tabs.R` | Kept the branch's `.tabs_runner_dir` resolution, took main's em-dash-free wording of the roxygen line above it. |
| `docs/v2_lift/V2_LIFT_PROGRAM.md` | One maxdiff row carrying both statuses, both log entries in date order. |

The template workbook was regenerated from the merged script, so the binary
now carries both sides: main's `Generate_Stats_Pack = YES` and the branch's
`Generate_Tabs_Export`, `Tabs_Question_Code` and
`Allow_Approx_Utilities_Export` rows. The H6 round-trip test passes against
it.

Audited by hand, because git flags none of these: `maxdiff_island` is in both
whitelists in `crosstabs_config.R` (the `build_config_object` list and
`TABS_KNOWN_SETTINGS`); the v2 JS bundle is directory-listed and sorted, so
`27y_maxdiff.js` needs no ordering change; the MaxDiff tab is still wired in
`24_shell.js` and `data-md` is still in `template.html`; the merged JS files
pass `node --check`; the merged USER_MANUAL keeps both the F5 wording and the
B2 and C sections.

Two things the handover got wrong, both settled by reading the code. The
approx gate refuses `MODEL_APPROX_UTILITIES`, not `CALC_APPROX_UTILITIES`,
because `maxdiff_refuse()` prefixes anything off its list with `CFG_`. And
the three new OUTPUT_SETTINGS were already registered in
`get_default_output_settings()`, so the unknown-setting warning the handover
predicted for the Karoo config goes away by itself.

## 2. What the merge found

Three defects. The first two are the same kind: code written on one branch
before a ruling landed on the other, where neither side touched the other's
file, so git had nothing to flag. The third only exists because Stan works
now.

### F2 again: a refused tabs export left the run at PASS (`47d791a6`)

Steps 11b (the B2 export) and 11c (the C island) run after `run_result` is
built, and were written before review finding F2 was fixed on the correctness
branch. They recorded failures with `add_warning()` alone.

Observed before the fix, on a synthetic ANALYSIS run with
`Generate_HB_Model = NO` and `Generate_Tabs_Export = YES`: the exporter
printed its `MODEL_NO_RESPONDENT_UTILITIES` refusal in full, and the run
closed with `[TRS PASS] MAXDIFF - ANALYSIS COMPLETED SUCCESSFULLY`,
`run_result$status = "PASS"` and `results$warnings` empty. The island's
refusal branch was swallowing its refusal entirely.

`note_late()` now takes the step's own refusal code and title, so the fold-in
names the real refusal instead of a generic `MAXD_WARNING`, and all four
branches of the two steps go through it. Test:
"F2: a refused tabs export changes the verdict, it is not just a warning" in
`test_review_followups.R`. Two assertions fail against the merged code
without the change and pass with it.

### F5 one layer out: the MaxDiff tab called a heterogeneity a posterior SD (`bfe619d2`)

The v2 view was written on 2 September. Duncan's F5 ruling landed on the
correctness branch on 3 September: `HB_Utility_SD` means the spread of the
shipped individual utilities across respondents on BOTH paths, and the
precision of the population mean moved to a new `HB_Mean_SE`. The view still
switched its column label to "Posterior SD" whenever the island said Stan, so
a Stan run presented a heterogeneity as a precision.

The spread now carries one label on both paths. The island carries
`HB_Mean_SE` as `hbMeanSe`, and the view shows it as its own "Mean SE" column
with a note saying which is which. An all-missing `HB_Mean_SE` stays out of
the island rather than arriving as an array of nulls. The node gate fails two
assertions against the view as merged and passes with the change.

### A third defect, from the demo: two modules, one function name (`deeb0993`)

The integrated demo sources maxdiff first (inside `build_maxdiff_example`)
and conjoint second, into one global environment. Both define
`extract_hb_results()`, with different signatures: conjoint's takes `burnin`
and `thin`, maxdiff's takes a `CmdStanMCMC` fit. Conjoint is sourced last, so
it won, and maxdiff's Stan extraction called it.

Observed: the Stan model sampled for 471 s, then
`MAXD_HB_FAILED: HB model failed: argument "thin" is missing, with no
default`. No individual utilities, so the tabs export refused
`MODEL_NO_RESPONDENT_UTILITIES` and the script stopped on its own
missing-file check. Nobody had seen it because until 2026-09-02 every HB run
on this machine was the empirical-Bayes fallback, which never calls that
function. The F2 fix above is what made it legible: the run reported PARTIAL
with its two events instead of closing PASS.

maxdiff's is now `maxdiff_extract_hb_results()`. Renaming this side alone
fixes both orderings. `.source_trs_infrastructure()` collided the same way
and is now `.maxdiff_source_trs_infrastructure()`. A scan test asserts the
two modules share no top-level function name across their `R/` and `lib/`
trees, and fails against the code as merged, naming both.

How far this reached: `launch_turas()` spawns a separate R process per module
and sources only that module's script (`launch_turas.R` around line 884), so
the GUI never had both in one environment and production runs were not
affected. It bites any script or headless session that loads both, which is
the integrated demo and the recipe its README gives for doing this by hand on
a real project.

## 3. Verification

| Check | Result |
|---|---|
| `testthat::test_dir("modules/maxdiff/tests/testthat")` | 1084 pass, 0 fail, 1 skip, 0 error, on the final tree. The skip is "cmdstanr is installed, cannot test unavailable path". |
| `testthat::test_dir("modules/tabs/tests/testthat")` | 5255 pass, 0 fail, 1 skip, on the final tree. The skip is "tracking_island.R not sourced in this run". |
| `node modules/tabs/lib/html_report_v2/tests/maxdiff_view_tests.mjs` | 8 passed, 0 failed. |
| Karoo, Stan, export on | Exports unstamped. 400 rows summing to 100, METHOD names Stan with 4 chains. 603.6 s. |
| Karoo, `Generate_HB_Model = NO` | Refuses `MODEL_NO_RESPONDENT_UTILITIES`, verdict PARTIAL, 12.6 s. |
| Karoo, empirical-Bayes fallback | Refuses `MODEL_APPROX_UTILITIES`, verdict PARTIAL, 10.6 s. |
| Integrated demo | Completes on Stan after the collision fix. MaxDiff PASS in 858.9 s; MaxDiff tab, MDSHARE and both simulators present. |

The empirical-Bayes run hid cmdstanr with a stub package on a temporary
library path ahead of the real one, so `requireNamespace("cmdstanr")` returns
FALSE. Nothing in the renv library was touched. All Karoo runs wrote into the
session scratchpad, never into `examples/maxdiff/Output`.

## 4. The Karoo and demo runs

All three Karoo runs used a scratch copy of the shipped config with absolute
paths and an output folder in the session scratchpad. Nothing was written
into `examples/maxdiff/Output`. No run printed `MAXD_UNKNOWN_SETTINGS`, which
is the empirical version of the handover correction in section 1: the three
tabs-export settings are recognised.

### Run 1: Stan, export on, no override

`Allow_Approx_Utilities_Export = NO`, everything else as shipped. 603.6 s
end to end, of which 290.6 s was sampling on 4 chains. Verdict PASS, no
warnings. Diagnostics: 0 divergences, mean Rhat 1.000, min ESS 8675.

`Karoo_MaxDiff_Results_tabs_shares.xlsx` was written, read back from the file:

- METHOD names the estimator "Stan hierarchical Bayes", chains / iterations /
  warmup "4 / 5000 / 2000", mean R-hat 1.000, 400 respondents exported and 0
  excluded. There is no APPROXIMATE row.
- QUESTIONMAP_SNIPPET reads "MaxDiff preference shares (model-derived, Stan
  hierarchical Bayes)", Variable_Type Allocation, Columns 10. No
  "(approximate: count-based)" stamp, which is the point of the gate.
- DATA has 400 rows, `RespID` plus `MDSHARE_1` to `MDSHARE_10`, and every row
  sums to 100 within 1e-6.

This run sourced the module before the F5 island fix, so its
`_md_island.json` has no `hbMeanSe`. That is the pre-fix code, not a defect,
and it is why the integrated demo below stands as the post-fix Stan proof.

### Runs 2 and 3: the gate refuses

Both with `Allow_Approx_Utilities_Export = NO` and the slow outputs off.

- `Generate_HB_Model = NO`: refuses `MODEL_NO_RESPONDENT_UTILITIES`, verdict
  PARTIAL, the refusal in `results$warnings`, 12.6 s.
- Empirical-Bayes fallback: refuses `MODEL_APPROX_UTILITIES`, verdict
  PARTIAL, the refusal in `results$warnings`, 10.6 s.

Both verdicts are PARTIAL rather than PASS only because of the F2 fix above.
Before it they were PASS.

### The integrated demo

`Rscript examples/integrated_demo/build_integrated_demo.R <root> <scratchpad>`,
so nothing was written into `examples/integrated_demo/Output`.

The first attempt failed, and the failure is the third defect in section 2.
With the fix, the demo completes: conjoint HB on 600 respondents, maxdiff on
Stan in 858.9 s, verdict PASS, then tabs. The script's own checks report the
Conjoint tab and the MaxDiff tab present and both simulators beside the
report.

Checked in the artefacts, not the log:

- `Karoo_MaxDiff_Results_tabs_shares.xlsx` was written.
- The island says `meta.method = "stan_hb"` and carries `hbMeanSe`, values
  around 0.076 to 0.089, with a 0 for the anchor item. `hbSpread` is an order
  of magnitude larger (0.68 to 1.10), which is what the two columns meaning
  different things looks like.
- The report HTML contains `"kind":"maxdiff"`, contains `hbMeanSe` and
  "Mean SE", and contains no "Posterior SD".
- `MDSHARE` is in the report's data layer as a 10-row question with mean
  shares by banner column, titled "MaxDiff preference shares (model-derived,
  Stan hierarchical Bayes)" with no approximate stamp, which is the gate
  behaving correctly on a genuine Stan fit.

The tabs run inside the demo reported "Issues: 4". All four are preflight
notes on the synthetic survey questions, read from the Error Log sheet of
`Karoo_Demo_Crosstabs.xlsx`: three "option value(s) defined but never occur in
data" warnings on Q001 to Q003, and one Info about Bonferroni with only four
banner columns. None of them touches MDSHARE, the island or an Allocation
question.

## 5. Open, for Duncan or the reviewer

- **The shipped Karoo config disarms the D5 gate.**
  `Allow_Approx_Utilities_Export = YES` in
  `examples/maxdiff/Karoo_MaxDiff_Config.xlsx`. That was right when cmdstanr
  was absent and the example still had to produce an export. Now that Stan
  works it should be `NO`, so the shipped demo shows the gate live. Not
  changed here: the file is a binary Duncan hand-edited in Excel, and
  `create_maxdiff_example.R` would revert two of his edits if re-run
  (`Generate_HTML_Report` and `Generate_Charts` are both YES in the shipped
  file and NO in the generator).
- **TURF reaches 100% at one item on Karoo.** Duncan's eyeball note, and not
  a defect: `TURF_Threshold` is `ABOVE_MEAN`. `TOP_K` with k = 3 gives a
  curve that means something. Same binary-edit problem as above, so recorded,
  not done.
- **Chart labels truncate.** P3 from the July review, six sites in
  `04_chart_builder.R`. Under the conjoint precedent the old report is
  retirement-bound, so the fix belongs in the v2 view. The v2 view does not
  truncate: `27y_maxdiff.js` writes the whole label into a table cell and the
  `.md-table` rules in `styles.css` set no `white-space: nowrap`, no
  `text-overflow` and no fixed table layout, so a long label wraps. Read from
  the source, not confirmed in a browser.
- **`safe_numeric()` is defined by maxdiff, conjoint AND tabs.** Whichever
  module is sourced last owns it, and the three differ: maxdiff's takes the
  first element of a vector, conjoint's does `if (is.na(result))` on the
  result, which raises a condition-length error for any input longer than
  one. It predates this branch by a long way, and which one should win is a
  platform decision, so it is whitelisted in the scan test with that reason
  written down rather than renamed across 35 call sites on a merge branch.

- **The anchor item's Mean SE renders as 0.000.** The Stan fit gives the
  anchor a `HB_Mean_SE` of 0, the Excel already writes 0 there, and the new
  Mean SE column now shows it with nothing to say it is structural rather
  than a very precise estimate. Session A's choice surfacing in a new place,
  not introduced here. A reviewer should rule: NA, an en dash, or a footnote.

- **The Reader report cannot be built from a clean clone.**
  `modules/tabs/lib/reader_report/assets/template.html` is matched by `*.html`
  in `.gitignore` and has no negation, unlike
  `modules/tabs/lib/html_report_v2/assets/template.html` on line 73. The file
  exists only in Duncan's main checkout, so six tests in
  `test_reader_report.R` fail in any fresh worktree or clone with
  `IO_READER_ASSET_MISSING`. Pre-existing, nothing to do with this merge, and
  a one-line `.gitignore` negation fixes it. Not done here because it is
  outside the merge.

## 6. Next

Independent review of this branch's delta, briefed as independent, same
method as `REVIEW_FINDINGS_MAXDIFF_SESSION_A_2026-09-03.md`. Then Duncan's
`launch_turas()` eyeball and the merge. Then segment.

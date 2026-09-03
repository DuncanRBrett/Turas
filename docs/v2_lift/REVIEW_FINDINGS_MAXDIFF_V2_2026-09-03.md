# MaxDiff v2 branch: Independent Pre-merge Review Findings

**Date:** 2026-09-03. Reviewing session (Fable); did not write the code under review. `MERGE_NOTES_MAXDIFF_V2_2026-09-03.md`, `SESSION_BC_NOTES_MAXDIFF.md` and `REVIEW_FINDINGS_MAXDIFF_SESSION_A_2026-09-03.md` were read as claims to test.
**Scope:** `feature/maxdiff-v2-report` at `f106dd9b` in the worktree `.claude/worktrees/maxdiff-v2-report`, five commits on `db607112` (main, level with origin), 43 files, +3653/-897. The B2 tabs export (`R/12_tabs_export.R`), the C island (`R/13_v2_island.R`), the MaxDiff tab (`27y_maxdiff.js` and the tabs wiring), the shipped Karoo example, the integrated demo and the four merge commits. Session A's engine was not re-reviewed, except where the brief's third question (the late-event fold-in) led straight into it.
**Verification:** everything marked verified was read or executed in this session, in the worktree with renv active. Every run wrote into the session scratchpad; nothing was written into `examples/*/Output`, OneDrive or the repo. No code was changed. The branch is untouched apart from this file, which is uncommitted.

---

## 0. Verdict: BLOCK, for four small fixes in the delta

No number was wrong anywhere it was recomputed. The D5 gate holds on all three paths. The branch cannot merge as it stands because four things a client would see on the shipped example under Stan, which is the estimator Duncan's machine now runs, are wrong or missing:

1. The MaxDiff tab's provenance panel tells a Stan reader that the spread column is "the posterior SD of the population mean", while the table note under it says the opposite. F5, one layer further out again (F1 below).
2. The TURF panel is silently absent from the MaxDiff tab on the shipped Karoo example under Stan, while the Excel TURF_RESULTS sheet has the row (F2).
3. The tab links to a simulator file the shipped config never writes (F3).
4. A refused or missing simulator still closes the run `[TRS PASS]` (F4), and the fold-in that F2-of-Session-A built does not cover the main Excel deliverable either: a blocked workbook path prints "Output saved" and closes PASS with no workbook on disk (F5, pre-existing, the strongest answer to the brief's third question).

Each fix is a few lines and has a named test. Everything else is IMPORTANT-but-not-blocking, MINOR, or a ruling for Duncan.

---

## 1. Gates and runs

| Check | Result (this session) |
|---|---|
| `testthat::test_dir("modules/maxdiff/tests/testthat")` in the worktree | **1084 pass, 0 fail, 1 skip, 0 error.** Skip: "cmdstanr is installed, cannot test unavailable path". |
| `testthat::test_dir("modules/tabs/tests/testthat")` in the worktree | **5255 pass, 0 fail, 1 skip, 0 error.** Skip: "tracking_island.R not sourced in this run". Caveat: this worktree has `modules/tabs/lib/reader_report/assets/template.html` (copied 09:52 today), so the six-test packaging failure the merge notes describe did not fire here. `git check-ignore` confirms the file is untracked and matched by `.gitignore:69` (`*.html`). |
| `node modules/tabs/lib/html_report_v2/tests/maxdiff_view_tests.mjs` | **8 passed, 0 failed.** |
| The merge commit `b9640bea`, re-done mechanically with `git merge-tree db607112 5a4fc0f5` and diffed against the committed tree | Only three files differ: `V2_LIFT_PROGRAM.md` and `run_tabs.R` (the two hand-resolved conflicts, both resolved as the notes say) and the regenerated config template. Nothing else was touched by hand. |
| Karoo, shipped config, Stan (`Allow_Approx = YES` as shipped, everything on) | PASS, no warnings, 712.6 s. 0 divergences, mean Rhat 1.000, min ESS 8675. Export unstamped: QuestionText "MaxDiff preference shares (model-derived, Stan hierarchical Bayes)", METHOD rows Estimator / chains 4 / 5000 / 2000 / Mean R-hat 1.000 / 400 exported / 0 excluded, no APPROXIMATE row. DATA 400 rows, `RespID` + `MDSHARE_1..10`, every row sum exactly 100. |
| Karoo, EB fallback (cmdstanr masked), `Allow_Approx = YES` | PASS, 9.1 s. QuestionText carries "(approximate: count-based)", METHOD carries the APPROXIMATE row, console says "STAMPED approximate". |
| Karoo, EB fallback, `Allow_Approx = NO` | PARTIAL, 9.3 s. `MODEL_APPROX_UTILITIES` printed, in `results$warnings`, no export file. |
| Karoo, `Generate_HB_Model = NO` | PARTIAL, 8.5 s. `MODEL_NO_RESPONDENT_UTILITIES` printed, in `results$warnings`, no export file. |
| Hand recomputation, both estimator paths | For respondents R0001, R0200, R0400: softmax of the INDIVIDUAL_UTILS row in config item order, times 100, against the DATA row: max abs difference 1.05e-13 (Stan) and 4.3e-14 (EB). The EB INDIVIDUAL_UTILS sheet has its item columns alphabetical (DECAF, DELIVERY, ...) and the export still lands each share on the right item, because it selects by name. |
| Island arithmetic, both paths | `share` against the mean of per-respondent softmax: 4.2e-7 (Stan), 4.9e-7 (EB). `hbSpread` against the SD of INDIVIDUAL_UTILS per item: 4.5e-7 and 4.1e-7. `rescaled` against the 0-100 rescale of `hbUtility`: 1.7e-5 and 6.2e-5. Sum of shares 100 on both. Item order FRESH..REWARDS on both, the config order. |
| Stan island carries `hbMeanSe` | Yes: 0.1028, 0.1017, 0.0981, 0.0958, 0.0915, 0.0899, 0.1015, 0.0984, 0.0952, 0, within 1e-4 of ITEM_SCORES `HB_Mean_SE` (0.0915 against 0.0914 on one item, the island's `digits = 6`). `hbSpread` 0.57 to 0.79 and 0 for the last item. EB island: `hbMeanSe` absent, as designed. |
| The view, rendered in node on both real islands | Stan: column headers "Utility, Spread (SD), Mean SE"; table note says Spread is heterogeneity and Mean SE the precision. EB: "Utility, Spread (SD)", stamp panel present, note says there is no posterior. Hostile-label escaping is covered by the node gate and the tabs e2e test, both green. |

---

## 2. The brief's four questions

### Q1. Does anything reach a crosstab as a model estimate without the stamp it deserves?

Not on the three D5 paths. Stan exports unstamped, the fallback refuses by default and is stamped when let through, no utilities refuses. Both refusals now move the verdict to PARTIAL (the F2-again fix), verified above. The stamp lives in the QuestionText and the METHOD sheet, and the demo copies the QuestionText verbatim into the Survey_Structure, so it travels.

One path the gate does not see (F6): a Stan fit that sampled but did not converge. The gate keys on `model_fit$method == "cmdstanr"` alone (`12_tabs_export.R:86-90`). Divergences and R-hat are computed (`07_hb.R:482-486`) and only logged; the METHOD sheet carries mean R-hat but not the divergence count; `check_hb_convergence_auto()` (`07_hb.R:761`) is never called anywhere in the module. A divergent fit is exported unstamped with nothing in the crosstab or the island saying so. Ruling needed (section 4).

### Q2. The island contract

Absent blocks are absent, verified on the `Generate_HB_Model = NO` island (no `hbUtility`, no `discrimination`) and by the suite. Item order follows `Display_Order`, verified. Hostile labels round-trip and are escaped at embed time, verified by the tabs e2e test.

`hbMeanSe` and `hbSpread` are NOT presented as different things everywhere a reader can see them: the provenance panel contradicts the table (F1). And a present block can be treated as absent: a one-row TURF (F2).

### Q3. Is there still a path where a deliverable fails and the run reports PASS?

Yes, three. The first two were observed in runs this session; the third is from the code and the suite's excluded-respondent test, not from a run:

- A refused simulator (F4). Config with no HB and no logit but `Generate_Simulator = YES`: the console prints `[TRS INFO] MAXD_SIM_NO_UTILS`, no simulator is written, the run closes `[TRS PASS] COMPLETED SUCCESSFULLY`, `results$warnings` empty. `00_main.R:1329` assigns `sim_result$output_file` without looking at `sim_result$status`; the `MAXD_SIM_NOT_FOUND` and `MAXD_HTML_NOT_FOUND` branches (`:1333`, `:1368`) are `message()` only.
- The main Excel workbook (F5). With a directory sitting where the workbook goes (standing in for a locked or unwritable file): "Output saved: .../Karoo_MaxDiff_Results.xlsx" is printed, the island is written, the run closes `[TRS PASS]`, and there is no workbook. With the whole Output folder read-only the run went PARTIAL, but only because the island write happened to fail too; the Excel failure itself never reached the verdict.
- The tabs export's own PARTIAL (respondents excluded for missing utilities) is an INFO line, not an event. Minor; the METHOD sheet records the count.

### Q4. The Karoo config and the demo as artefacts a client might see

The Karoo run is clean and the numbers are right. Three presentation defects on the tab under Stan (F1, F2, F3). The integrated demo runs end to end with `Rscript`, and refuses at its conjoint step when the same script is `source()`d from a console (F7, pre-existing in conjoint). The demo's Stan-path artefacts were regenerated this session; see section 5 for what was and was not checked in them.

---

## 3. Findings

### CRITICAL

None. No number was wrong anywhere it was recomputed.

### IMPORTANT, blocking (in the delta)

#### F1. The Stan estimation note calls the spread a posterior SD
**File:** `modules/maxdiff/R/13_v2_island.R:237-240`
`estimation_note` for `stan_hb` reads "...the spread column is the posterior SD of the population mean." That is the definition F5 retired: on both paths `HB_Utility_SD` is the spread across respondents and the precision is `HB_Mean_SE`. The view prints this note in the provenance panel (`27y_maxdiff.js:68-71`), then the table note two lines down says "Spread (SD) is how much the item's utility varies across respondents, not the precision of the average. Mean SE is that precision". Both sentences were rendered on one page from the real Stan island in this session. The merge session's check was `grep "Posterior SD"` (capital P); the note has lower case.
**Fix:** Reword the stan_hb note to name both columns correctly (spread across respondents; Mean SE the posterior SD of the population mean). Test: extend the node gate to render a stan-method island and assert the rendered text does not match `/posterior sd of the population mean/i` outside the Mean SE sentence, or simply that the provenance panel contains "across respondents".

#### F2. A one-step TURF vanishes from the tab
**File:** `modules/maxdiff/R/13_v2_island.R:331` (`write_json(..., auto_unbox = TRUE)`), `27y_maxdiff.js:204` (`arr(t.step)`).
`auto_unbox = TRUE` writes every length-1 vector as a scalar. On the shipped Karoo example under Stan, TURF stops after one item (FRESH reaches 100% under ABOVE_MEAN), so the island carries `"step": 1, "itemId": "FRESH", "reachPct": 100`. The view's `arr()` returns null for a non-array and `turfHtml()` returns "", so the tab has no TURF panel at all, no note, nothing. Rendered in node from the real island: panels present are Item scores, Must-haves, Where respondents agree and disagree. The Excel TURF_RESULTS sheet has the row. The EB island (four steps) renders the panel. The same hazard applies to any per-row vector that can be length 1; TURF is the only one that is in practice.
**Fix:** Wrap every per-row vector in the island in `I()` so jsonlite keeps it an array (`I(num(it$Step))` and so on, in `scores`, `turf`, `anchor`, `discrimination`), or serialise with `auto_unbox = FALSE` and unbox `meta` by hand. Test in `test_v2_island.R`: a one-row `incremental_table` round-trips as `"step":[1]` and the node gate renders the TURF panel from it.

#### F3. The island names a simulator file the shipped config does not write
**File:** `modules/maxdiff/R/13_v2_island.R:276-279`; `00_main.R:1324-1330`.
`simulatorFile` is set whenever `Generate_Simulator` is on. But with `Generate_HTML_Report = YES`, step 12 embeds the simulator inside the classic HTML report and writes no standalone file. The shipped Karoo config has both on (Duncan's Excel edit turned the HTML report on), so the Stan run wrote no `_simulator.html` (verified: zero simulator files in Output) while the island says `"simulatorFile": "Karoo_MaxDiff_Results_simulator.html"` and the tab renders "Simulator: Karoo_MaxDiff_Results_simulator.html. Open it beside this report..." as a link to nothing. The island is written at step 11c, before step 12 decides.
**Fix:** Either compute the same condition as step 12 (`generate_sim && !generate_html`) in the island, or write the island after step 12 and take `results$simulator_path`. Test: `Generate_Simulator = YES` with `Generate_HTML_Report = YES` yields no `simulatorFile`.

#### F4. A refused or missing simulator leaves the run at PASS
**File:** `modules/maxdiff/R/00_main.R:1319-1337` (step 12), `:1366-1369` (HTML not found).
Observed as described under Q3. `generate_maxdiff_html_simulator()` returns `list(status = "REFUSED", ...)` on two paths (`99_simulator_main.R:86, :96`) and the caller never reads `status`. The two `_NOT_FOUND` branches are `message()` only.
**Fix:** After the call, `if (!identical(sim_result$status, "PASS")) note_late(..., code = "MAXD_SIM_REFUSED", ...)`; route both `_NOT_FOUND` branches through `note_late()`. Test: the sim_refused config above ends with `run_result$status != "PASS"` and the event named.

### IMPORTANT, not in the delta, surfaced by the brief's Q3

#### F5. A failed Excel write prints "Output saved" and the run closes PASS
**File:** `modules/maxdiff/R/09_output.R:218-246`; `00_main.R:1258-1262`.
The atomic saver is only used `if (exists("turas_save_workbook_atomic"))`. Nothing on the module's load path sources it: `.maxdiff_source_trs_infrastructure()` (`00_main.R:101-103`) loads four shared files and not `turas_save_workbook_atomic.R`; `run_maxdiff_gui.R` (the script `launch_turas()` spawns, per `launch_turas.R:120`) sources the theme, the minifier and `R/00_main.R` only. So every run, headless or GUI (GUI by reading, headless by execution), goes through the bare `openxlsx::saveWorkbook()` branch at `:242`, prints "[TRS WARNING] Saving without part reconciliation" (seen twice in every Karoo log this session, once for the results workbook and once for the stats pack), and the refusal at `:220-232` for a failed save is dead. `saveWorkbook()` on an unwritable path raises an R warning, not an error, so `:246` logs "Output saved", `output_path` is non-NULL, and the `MAXD_OUTPUT_FAILED` handler at `00_main.R:1258` (which would only `message()` anyway) is never reached. Observed: PASS, "Output saved", no workbook.
**Fix:** (a) source `turas_save_workbook_atomic.R` in `.maxdiff_source_trs_infrastructure()` so the atomic saver and its refusal are live in both the GUI and the README recipe, and so the shipped workbooks stop going through the documented broken-workbook path; (b) after the save, `if (!file.exists(output_path)) stop(...)` so the caller's handler fires; (c) that handler calls `note_late()`. Test: a directory at the workbook path ends PARTIAL with `MAXD_OUTPUT_FAILED` named. This is Session A / shared territory and outside the delta; it is listed here because the brief's Q3 asked, and because it is the deliverable that matters most.

#### F6. The D5 gate trusts "Stan ran" as "respondent-level estimates"
**File:** `modules/maxdiff/R/12_tabs_export.R:33, :86-90`; `07_hb.R:482-500`.
See Q1. Divergences and R-hat exist in `hb$diagnostics` and reach neither the METHOD sheet (mean R-hat only) nor the island's `meta`. `check_hb_convergence_auto()` is dead code.
**Fix, minimum:** add "Divergences" and "Min ESS" rows to METHOD and `nDivergences` / `meanRhat` to `meta`, so a reader can see them. **Fix, if Duncan rules so:** refuse or stamp the export when `n_divergences > 0` or `mean_rhat > 1.05`, with an override the way `Allow_Approx_Utilities_Export` works. Ruling item in section 4.

#### F7. The integrated demo refuses when source()d instead of run with Rscript
**File:** `examples/integrated_demo/build_integrated_demo.R:193-194`; cause in `modules/conjoint/R/00_main.R:31` and `:152-153` (not in the delta).
Observed both ways on a copy of the demo that quits after the conjoint step: `Rscript demo.R` gives `status PASS`; `Rscript -e 'source("demo.R")'` gives `REFUSED CONJ_ANALYSIS_FAILED: could not find function "validate_hb_config"`. The demo's own error then says "see the messages above" and, with `verbose = FALSE`, there are none. Conjoint's `.get_guard_dir()` takes `sys.frame(1)$ofile`, the outermost source frame, which is the demo script's directory when the demo is sourced; the exact chain from there to the missing function was not traced and is labelled suspected. Sourcing a script from an RStudio console is how the demo would most naturally be run.
**Fix:** In conjoint, walk frames innermost-first and match `conjoint/R/00_main.R`. Until then the demo README should say "run with Rscript; do not source() it", and the demo's failure message should print the refusal's code and message. Not blocking this merge; conjoint's file.

### MINOR

#### M1. The maxdiff guard resolver walks frames outermost-first
**File:** `modules/maxdiff/R/00_main.R:54-65`.
`for (i in seq_len(sys.nframe()))` matches the first frame whose file ends in `00_main.R`. A caller that is itself named `00_main.R` (a runbook, say) and sources the module wins, and the guard is not loaded. Observed: `Rscript -e 'source("<dir>/00_main.R")'` where that file sources the module dies with "could not find function maxdiff_refuse". Contrived, but one `rev()` fixes it, and matching `maxdiff/R/00_main.R` would be stricter. `run_tabs.R:19-34` has the same shape with a less ambiguous name.

#### M2. Documentation drift in the delta
- `examples/integrated_demo/README.md:17-18` and `build_integrated_demo.R:20`: "a couple of minutes" / "about two minutes". With cmdstanr installed the maxdiff step alone is 12 to 15 minutes (712 s for the 400-respondent Karoo run here; the notes record 859 s for the 600-respondent demo).
- `examples/maxdiff/README.md:44-52`: "This example is configured for that world" (no cmdstanr). On this machine it now fits Stan. Ties to open item 1.
- The demo README's "Doing this for a real project" recipe inherits F7.

#### M3. The reference item on the Stan path shows Spread 0.00 and Mean SE 0.000
The Stan model fixes the last item (REWARDS on Karoo, no anchor designated) at zero for every respondent, so its spread across respondents is 0, its Mean SE is 0, and the discrimination classifier, which median-splits on that spread, files it as "Low Priority" on Stan where the EB run files it as "Polarizing". The tab shows all three with nothing to say they are structural. The merge notes raise the Mean SE half of this; the spread half and the class are the same fact. Ruling item in section 4.

#### M4. The tabs export's excluded-respondent PARTIAL is an INFO line
`12_tabs_export.R:166-170, :254`. A respondent with all-NA utilities is dropped with a `[TRS INFO]` line and the export returns `status = "PARTIAL"`, which `00_main.R` never reads. The METHOD sheet records the count, so the reader can see it. Fold it into `note_late()` if Duncan wants an excluded respondent to be an event.

### OBSERVATIONS

- **Tests.** `test_tabs_export.R` and `test_v2_island.R` assert hand-checkable values (row sums, argmax alignment, order under a reversed `Display_Order`, the stamp text in the sheet). The F2-again test in `test_review_followups.R:362-417` is a real end-to-end run asserting `run_result$status != "PASS"`, not a grep. Three tests grep source text rather than behaviour ("the output stage wires both contributions in", and two in tabs `test_maxdiff_island.R`); the e2e tests beside them carry the behaviour, so these are structural guards, not vacuous.
- **Whitelists.** `maxdiff_island` is in both `build_config_object()` and `TABS_KNOWN_SETTINGS`, and in the config template generator; read in the diff and covered by a test.
- **The conjoint island** uses the same `auto_unbox = TRUE` (`17_v2_island.R:244`) and may carry the F2 hazard for any single-level block. Not checked; conjoint is merged.
- **`safe_numeric()`** (open item 4): every maxdiff call site (3: `00_main.R:1141`, `01_config.R:844, :1142`) and every conjoint call site (12, all in `01_config.R`) passes a config scalar, so today the collision is benign whichever definition wins. The demo's order (maxdiff loaded first, conjoint second) leaves conjoint's version active during the maxdiff run; a length-1 argument satisfies both. Not blocking. A module prefix on both sides when convenient.

---

## 4. The five open items in the merge notes

| # | Item | Confirm or challenge | Blocking? |
|---|---|---|---|
| 1 | Shipped Karoo config has `Allow_Approx_Utilities_Export = YES` | Confirmed as read from the workbook. Under Stan it is inert (the export was unstamped because `approximate = FALSE`, not because of the override). On a machine without cmdstanr it produces the stamped export the README describes. A choice, not a defect. If Duncan wants the shipped example to demonstrate the gate refusing, set it to NO and update `examples/maxdiff/README.md`. | No |
| 2 | TURF reaches 100% at one item on Karoo | Challenge the "not a defect" verdict: the consequence in the v2 view is F2, a silently missing panel. Fix the serialisation whatever the threshold. Separately, `TOP_K` would give a curve worth reading on this data. | F2 yes; the threshold no |
| 3 | Chart labels truncate | The v2 view does not truncate: read in `styles.css` (`.md-table` sets no `white-space`, `text-overflow` or fixed layout). Not confirmed in a browser in this session either. The classic report is retirement-bound; the shipped Karoo config still turns it on. | No |
| 4 | `safe_numeric()` defined three ways | Benign today, with the call-site evidence above. Platform decision, not this merge. | No |
| 5 | Reader template gitignored | Confirmed: untracked, matched by `.gitignore:69`, only `html_report_v2/assets/template.html` has a negation (`:73`). One-line fix on main, outside this branch. | No, but do it before the next fresh clone |

Rulings for Duncan, three: F6 (what the gate does on a non-converged Stan fit), M3 (how the reference item's zero spread, zero SE and discrimination class are shown), and open item 1 (which world the shipped example demonstrates).

---

## 5. Not verified, and why

- **The GUI.** Per the standing rule nothing was run through `launch_turas()`. F5's GUI half is from reading `run_maxdiff_gui.R:50, :375-383`, not from a GUI run.
- **The demo on the Stan path** was started in this session (`Rscript examples/integrated_demo/build_integrated_demo.R <worktree> <scratch>`) and its conjoint step passed (importance Price 34%, Origin 21%, Roast 19%, Delivery 16%, Pack size 10%). Its maxdiff Stan fit and the tabs run were still in progress when this document was written; the addendum below records what was checked once it finished.
- **The conjoint example rework** in the delta (`modules/conjoint/examples/*`, `test_integration_mnl.R`) was read for shape only. The conjoint suite was not run; the demo's conjoint run, which exercises the same module, passed.
- **The classic HTML report** written by the shipped Karoo config was not reviewed. Retirement-bound per the conjoint precedent, and outside the brief.
- **F7's exact mechanism** past `.get_guard_dir()` was not traced.

## 6. Next

1. Fix F1 to F4 on this branch with the named tests; F5 in the same batch if Duncan agrees it belongs with the F2 line of work; re-run the three suites and the Stan Karoo run.
2. Duncan's three rulings (section 4).
3. Then Duncan's `launch_turas()` eyeball on the two examples and the demo, then merge, then segment.

---

## Addendum: the integrated demo on the Stan path, checked after it finished

`Rscript examples/integrated_demo/build_integrated_demo.R <worktree> <scratch>`, cmdstanr present, exit 0. Conjoint PASS; maxdiff PASS on Stan (top items by net score FRESH, ORIGIN, DELIVERY); "Exports joined by RespID: 600 of 600 have conjoint importance, 600 of 600 have MaxDiff shares"; tabs "Issues: 4" (the same three option-never-occurs warnings on Q001 to Q003 and the Bonferroni info the merge notes record); the script reports both tabs present and both simulators beside the report.

Read from the artefacts, not the log:

- `Karoo_Demo_Crosstabs_report.html` (1.3 MB): `"kind":"maxdiff"` once, no "approximate: count-based", `hbMeanSe` present, the MDSHARE title "MaxDiff preference shares (model-derived, Stan hierarchical Bayes)" unstamped. The F1 wording ("posterior SD of the population mean") is in the shipped report, once.
- The demo's island has a two-step TURF (`step: [1, 2]`) so the TURF panel renders here; F2 bites on the shipped 400-respondent Karoo example, not on the 600-respondent demo. The demo config sets `Generate_HTML_Report = NO`, so the standalone simulator is written and F3 does not bite here either. Both defects are configuration-dependent, which is why the shipped example and the demo disagree.
- `Karoo_Demo_Crosstabs.xlsx`, Crosstabs sheet, the MDSHARE block by Customer segment (Premium n=160, Standard 231, Budget 104, New Customer 105): "A lower price per kilogram" averages 6.8 / 10.6 / 18.8 / 10.1, Budget significant against A, B and D; "Single-origin beans with the farm named" averages 24.6 / 20.0 / 11.3 / 21.2, Premium significant against B and C. The README's checkable claim holds in the crosstab.

---

## 7. Follow-ups done the same day (F1 to F5)

Duncan asked for F1 to F5 to be fixed with tests. Done in the same worktree by the reviewing session, uncommitted at the time of writing. The findings above are left as written.

| Finding | Change | Test | Verified by |
|---|---|---|---|
| F1 | `13_v2_island.R`: the stan_hb `estimationNote` now reads "Individual utilities are posterior means from the Stan model. Spread (SD) is how far those utilities vary across respondents; Mean SE is the precision of the population mean (its posterior standard deviation)." | `test_v2_island.R` "F1: the Stan note never calls the spread a posterior SD"; node gate "F1: the Stan provenance panel and the table note agree about the spread" | Stan Karoo re-run: provenance panel and table note rendered from the real island agree; `/posterior sd/i` absent from the tab. |
| F2 | `13_v2_island.R`: `write_maxdiff_island()` passes the island through `.maxdiff_island_keep_arrays()`, which wraps every per-row field of `scores`, `turf`, `anchor` and `discrimination` in `I()` so jsonlite keeps a length-1 vector an array; the blocks' named scalars and all of `meta` stay unboxed. | `test_v2_island.R` "F2: a one-step TURF is written as arrays, not scalars"; node gate "F2: a one-step TURF renders its panel" | Stan Karoo re-run: `"step": [1], "itemId": ["FRESH"], "reachPct": [100]`; the TURF panel renders; `maxItems`, `threshold`, `rescaleMethod`, `nItems` still scalars. |
| F3 | `13_v2_island.R`: `simulatorFile` is named only when `Generate_Simulator` is on AND `Generate_HTML_Report` is off, the same condition step 12 uses to write the standalone file. | `test_v2_island.R` "F3: no simulator file is named when the classic HTML report embeds it" | Stan Karoo re-run on the shipped config (HTML report on): no `simulatorFile` in the island, zero simulator files on disk. |
| F4 | `00_main.R` step 12: `sim_result$status == "REFUSED"` goes through `note_late()` as `MAXD_SIM_REFUSED`; both `_NOT_FOUND` branches go through `note_late()`. | `test_review_followups.R` "F4: a refused simulator changes the verdict" (end to end, no HB and no logit with the simulator on) | Shipped Karoo config, same settings: PARTIAL, "Simulator not produced: No utility estimates available" in `results$warnings`. Was PASS. |
| F5 | `00_main.R`: `.maxdiff_source_trs_infrastructure()` now sources `turas_save_workbook_atomic.R`, so the atomic saver and its `IO_EXCEL_SAVE_FAILED` refusal are live on the GUI path and the README recipe; the step 11 handler catches `turas_refusal` and `error` and folds both in as an event. `09_output.R`: after the save, a path with no file (or a directory) refuses `IO_EXCEL_SAVE_FAILED` instead of logging "Output saved". | `test_review_followups.R` "F5: a workbook that cannot be written changes the verdict and is not called saved" (a directory at the workbook path) | Shipped Karoo config with a directory at the workbook path: PARTIAL, `IO_EXCEL_SAVE_FAILED` printed and in `results$warnings`, no "Output saved", `output_path` NULL. Was PASS with "Output saved". The "Saving without part reconciliation" warning no longer appears in any run. |

Suites on the fixed tree, run from the worktree: maxdiff **1112 pass, 0 fail, 1 skip, 0 error** (was 1084); tabs **5255 pass, 0 fail, 1 skip, 0 error** (same tree caveat as section 1); node gate **10 passed, 0 failed** (was 8). Stan Karoo re-run 587.3 s, PASS, no warnings; shares recomputed for R0001, R0200, R0400 to 1.05e-13 as before; island share, spread and `hbMeanSe` identical to the pre-fix run. Fallback Karoo re-run: identical numbers, PASS, stamped.

Not done here: F6, F7, M1 to M4 and the three rulings, as listed above.

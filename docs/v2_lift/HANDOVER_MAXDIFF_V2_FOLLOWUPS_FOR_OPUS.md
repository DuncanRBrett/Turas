# Handover: maxdiff v2 follow-ups after the independent review

Written 2026-09-03 by the Fable session that reviewed `feature/maxdiff-v2-report`
and fixed its F1 to F5. For an Opus session at high effort (Sonnet would do for the
mechanical items). Everything here is small and specified to file and line; if a
session fails twice at the same item, escalate one tier with what it tried.

## 1. Where things stand

- `main` is at `963d66bd`, pushed to origin on 2026-09-03. It carries the whole
  maxdiff v2 branch (B2 tabs export, C island, MaxDiff tab, Karoo example,
  integrated demo, the merge, and the review's F1 to F5 fixes) at `0d964827`,
  plus a qual-reader merge and one recovered tabs preflight commit since. The
  worktree `.claude/worktrees/maxdiff-v2-report` has been removed and its branch
  deleted; there are no worktrees left.
- Duncan eyeballed on this code through `launch_turas()`: the Karoo config, the
  integrated demo and the tabs run with `maxdiff_island` all behaved. One open
  observation from that eyeball is item 9 below.
- Read first: `docs/v2_lift/REVIEW_FINDINGS_MAXDIFF_V2_2026-09-03.md`, sections
  3, 4 and 7. Treat its line numbers as approximate: F1 to F5 moved lines in
  `00_main.R`, `09_output.R` and `13_v2_island.R`.
- Suites on this tree (worktree, 2026-09-03): maxdiff 1112 / 0 / 1 skip, tabs
  5255 / 0 / 1 skip, node gate 10 / 0. Run all three from the repo root, plus the
  conjoint suite once (item 8).
- Check the branch and whether the directory is a worktree before the first edit.
  Work on a branch off main; Duncan merges and pushes. Never amend a pushed commit.

## 2. The three rulings, with the reviewer's recommendation

Duncan has not ruled yet. Proceed on the recommendation unless he says otherwise
at the start of the session; note in the commit that it was the recommended
option.

### R1. F6: a divergent or non-converged Stan fit exports unstamped
`12_tabs_export.R` gate keys on `model_fit$method == "cmdstanr"` alone.
`07_hb.R` computes `n_divergences`, `max_treedepth_exceeded`, `mean_rhat`,
`min_ess` into `hb$diagnostics` and only logs them; `check_hb_convergence_auto()`
is never called.
**Recommendation, the minimum:** add "Divergences", "Max treedepth exceeded" and
"Min ESS" rows to the tabs export METHOD sheet beside "Mean R-hat"
(`.maxdiff_tabs_method_sheet()`), and `nDivergences`, `meanRhat`, `minEss` to the
island's `meta` on the Stan path, shown in the MaxDiff tab's provenance panel as
one sentence ("0 divergences, mean R-hat 1.000, min ESS 8675"). No refusal
threshold yet; decide that after a few real fits. Tests: METHOD sheet carries the
rows on a `cmdstanr` fixture with `diagnostics` set; island `meta` carries the
three numbers; node gate renders the sentence; both absent on the EB path.

### R2. M3: the reference item shows Spread 0.00, Mean SE 0.000, class Low Priority
The Stan model fixes the last item (REWARDS on Karoo when no anchor is
designated) at zero for every respondent, so its spread across respondents and
its Mean SE are exactly 0, and `classify_item_discrimination()` files it from
that spread.
**Recommendation:** in `13_v2_island.R`, null `hbSpread` and `hbMeanSe` for the
reference item and add `meta.referenceItem` (its id); in `27y_maxdiff.js` show a
dash in those cells and one note line "REWARDS is the reference item, fixed at
zero; the other utilities are relative to it". Exclude the reference item from
the discrimination classification (or show its class as a dash) rather than
letting a structural zero decide its class. Find the reference item from
`stan_data$original_item_order` / the anchor slot, not by assuming "last in
config". Tests: island nulls exactly one item on Stan and none on EB; view shows
the dash and the note; discrimination block omits or dashes it.

### R3. The shipped Karoo config keeps `Allow_Approx_Utilities_Export = YES`
Inert under Stan (the export was unstamped because the fit was genuine). On a
machine without cmdstanr it lets the stamped export through.
**Recommendation:** set it to NO so the shipped example shows the gate refusing
where there is no posterior, and change `examples/maxdiff/README.md` ("What to
expect without cmdstanr") to describe the refusal and the override. The file is
a binary Duncan hand-edited in Excel: edit the one cell in Excel or openpyxl, never
`loadWorkbook()` + save (dimension collapse), and do not re-run
`create_maxdiff_example.R`, which would revert his other edits
(`Generate_HTML_Report`, `Generate_Charts`).

## 3. The rest, in a sensible order

4. **F7, demo refuses when source()d.** Observed both ways: `Rscript demo.R`
   passes; `Rscript -e 'source("demo.R")'` refuses at the conjoint step with
   `CONJ_ANALYSIS_FAILED: could not find function "validate_hb_config"`. Cause is
   in `modules/conjoint/R/00_main.R`: `.get_guard_dir()` at line 31 takes
   `sys.frame(1)$ofile` (the outermost frame), and the module-dir walk at ~152
   goes outermost-first. Fix: walk `rev(seq_len(sys.nframe()))` and match
   `conjoint/R/00_main[.]R$`. Until fixed, or as well, add one line to
   `examples/integrated_demo/README.md`: run with Rscript, do not source() it.
   Test: the maxdiff suite's "guard is loaded when 00_main.R is sourced from
   another script" pattern, ported to conjoint, with the caller sourced rather
   than run.
5. **M1, maxdiff resolver walks outermost-first.** `modules/maxdiff/R/00_main.R`
   `.get_script_dir_for_guard()`: `for (i in seq_len(sys.nframe()))` becomes
   `rev(...)`, and match `maxdiff/R/00_main[.]R$`. A caller itself named
   `00_main.R` that sources the module currently loses the guard. Same shape in
   `modules/tabs/run_tabs.R:19-34`. Test: a caller named `00_main.R`.
6. **M2, documentation drift.** `examples/integrated_demo/README.md` and the
   header of `build_integrated_demo.R` say "a couple of minutes"; with cmdstanr
   the maxdiff step alone is 12 to 15 minutes. `examples/maxdiff/README.md` says
   the example "is configured for that world" (no cmdstanr); rewrite with R3.
7. **M4, optional.** The tabs export returns `status = "PARTIAL"` when respondents
   with all-NA utilities are dropped; `00_main.R` step 11b never reads it. Fold
   into `note_late()` only if Duncan wants an excluded respondent to be an event.
8. **DONE 2026-09-03.** Conjoint suite run from the repo root on main at
   `963d66bd`: **986 pass, 0 fail, 0 skip, 2 warnings**, 28.9 s. Both warnings are
   `survival::coxph` "ran out of iterations and did not converge" from
   `test_utilities.R:265` and `:398`, the second of which is the deliberate
   "Handle perfect separation case" fixture. Neither is a regression. No action.
9. **Stats pack checkbox vs config.** `run_maxdiff_gui.R:286-288` defaults the
   "Generate stats pack" checkbox to unticked and `00_main.R` treats the option
   the GUI sets as the toggle, so a config saying `Generate_Stats_Pack = YES`
   silently produces no pack from the GUI (Session A's M11 made the option win on
   purpose). Duncan hit this on 2026-09-03. Recommendation: default the checkbox
   from the loaded config's value, and print one console line when the GUI's
   choice differs from the config. Keep the option as the toggle.
10. **Reader template is gitignored.** `modules/tabs/lib/reader_report/assets/template.html`
    is matched by `.gitignore:69` (`*.html`) with no negation, unlike the v2
    template on line 73. Six tests in `test_reader_report.R` fail in any fresh
    clone with `IO_READER_ASSET_MISSING`. One negation line, then `git add` the
    file. Check nothing else under `reader_report/assets` is ignored.

## 4. Parked, not for this session

- Embedding the two simulators in the v2 report (iframe of the self-contained
  simulator HTML as an island). Duncan's question on 2026-09-03; the answer was
  "keep separate for now, decide once for conjoint and maxdiff together" after
  segment. About a day across both modules.
- `safe_numeric()` defined by maxdiff, conjoint and tabs. Benign today (every
  call site passes a config scalar); platform decision.
- ~~The classic maxdiff HTML report: retirement-bound per the conjoint
  precedent.~~ **Duncan ruled otherwise on 2026-09-03: bring it up to tabs v2
  rather than retire it.** See section 6.

## 5. Verification bar

Every item lands with a test that fails on the code as found and passes with the
change, and the three suites (four with conjoint) quoted from the run. For R1 to
R3, re-run the shipped Karoo config headless on Stan into a scratch folder (about
ten minutes; the review's runner was a copy of the config with absolute paths and
`Output_Folder` in the scratchpad) and read the METHOD sheet and the island back.
Nothing is written into `examples/*/Output` or OneDrive. Duncan regenerates through
`launch_turas()`; a session does not.


## 6. The classic maxdiff report goes to v2, not to retirement

Duncan's decision, 2026-09-03. Conjoint retired its standalone report and kept
only the simulator. MaxDiff does not follow that precedent. The classic report
is to be brought up to the tabs v2 standard instead.

**What exists today.** The classic report is
`modules/maxdiff/lib/html_report/`, 6,615 lines: five R files (data transformer
1,249, table builder 751, page builder 1,900, chart builder 767, main 716) plus
`js/md_report.js` (696) and `js/md_pins.js` (536). It is switched on by
`Generate_HTML_Report`, read at `modules/maxdiff/R/00_main.R:1331`, and the
shipped Karoo config still sets it to YES.

**The gap to close.** The classic report has seven panels: overview,
preferences, items, head to head, TURF, segments, diagnostics. The v2 MaxDiff
tab (`modules/tabs/lib/html_report_v2/assets/js/27y_maxdiff.js`, 281 lines) has
four: item scores, TURF, must-haves, discrimination, plus a provenance line.
`13_v2_island.R` says in its own header comment that HB diagnostics, the
per-respondent utilities and the per-segment tables deliberately stay in the
Excel. So the work is roughly: head to head, segments, diagnostics and the
charts, plus whatever the overview and preferences panels say that the v2 tab
does not.

**Duncan answered on 2026-09-03: retire it once the tab reaches parity.** So
maxdiff lands on conjoint's end state after all, but by widening the tab first
rather than by dropping the report and losing four panels. Order matters: parity
first, retirement second, never the reverse.

**The work, in order.**

1. Widen the island. `13_v2_island.R` currently leaves HB diagnostics, the
   per-respondent utilities and the per-segment tables in the Excel on purpose;
   its header comment says so and would need rewriting. Add blocks for head to
   head, segments and diagnostics. Watch the F2 lesson: per-row fields are
   vectors, scalars in a block stay unboxed, or the panel silently vanishes.
2. Widen the tab. `27y_maxdiff.js` grows from four panels to seven. Charts are
   the open sub-question: the classic report has its own chart builder (767
   lines) and v2 has its own charting, so this is a port, not a copy.
3. Prove parity on a real config before anything is deleted. The shipped Karoo
   example runs both paths today, so run it with `Generate_HTML_Report = YES`
   and read the classic report and the widened tab side by side, panel by panel.
   Duncan does the eyeball through `launch_turas()`; a session does not.
4. Retire, following `2fdcb38f` and the conjoint precedent. `Generate_HTML_Report`
   joins `MAXDIFF_RETIRED_SETTINGS` with a message naming it, so a live config
   carrying the row is answered rather than told it looks like a typo. Delete
   `modules/maxdiff/lib/html_report/` (6,615 lines) and `test_html_report.R`.
   Turn the setting off in the shipped Karoo config, and note the same Excel
   caution as R3: edit the cell in Excel or openpyxl, never `loadWorkbook()` and
   save.

Step 4 does not start until Duncan has done step 3.

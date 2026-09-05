# Independent pre-merge review: brand v2 lift (`feature/brand-v2-lift`)

**For:** a fresh Fable session, briefed as independent of the session that did the fixing. Do not read that session's chat. Its notes are evidence to check, not conclusions to accept.
**Date written:** 2026-09-05.

## What you are reviewing

Branch `feature/brand-v2-lift`, in the worktree `/Users/duncan/Dev/Turas-brand-v2-lift`, 17 commits on top of main 3f85abb3, tip 99606092. It implements Sessions A, B and C of `docs/v2_lift/HANDOVER_BRAND_FOR_OPUS.md` against `docs/v2_lift/BRAND_PRODUCTION_REVIEW_2026-07-12.md`, plus two docs (an assessment brief and an Opus handover for the later simplification work, which are not under review for correctness of code).

The fixing session's own account is `docs/v2_lift/SESSION_NOTES_BRAND_2026-09-03.md`. Duncan has regenerated the IPK report from the branch and eyeballed it; commentary survived Save and he saw no issues. That is not a substitute for this review.

## Ground rules

- Work in the worktree above (it is already set up: `renv/library` symlinked, IPK fixture workbooks present). Do not touch `/Users/duncan/Dev/Turas`; other sessions use it.
- Prefix every R run with `TURAS_ROOT=/Users/duncan/Dev/Turas-brand-v2-lift`.
- Verdict is by execution, not by reading the diff. Every CRITICAL and HIGH claim below must be run both ways where possible: fails on main's code, passes on the branch. `git stash` or `git show main:<file>` gives you the old code.
- No merging, no pushing, no OneDrive. You may commit fixes on the branch if you find defects; say so, with hashes.
- Write findings to `docs/v2_lift/REVIEW_FINDINGS_BRAND_V2_LIFT_2026-09-05.md`, one row per finding with file:line and how it was verified, then a verdict: MERGE, MERGE AFTER FIXES (listed), or BLOCK.

## Claims to verify, in priority order

1. **C1, Dirichlet expected values.** `modules/brand/R/08c_dirichlet_norms.R`. Claim: expected penetration, buy rate, SCR and 100% loyal now come from the NBDdirichlet object's closures per brand and are finite; refusal `CALC_DIRICHLET_EXTRACT` on NA. Verify: recompute one brand independently from `NBDdirichlet::dirichlet()` with the engine's own inputs and compare to four decimals; run the IPK fixture through `run_brand()` and inspect `dirichlet_norms$expected` and the DJ flag distribution; check the 100% loyal formula (sum over n of Pn(n) times p.rj.n(n, n, j), divided by brand.pen(j)) against a hand derivation for one brand at small nstar.
2. **C2 and H3, commentary persistence.** `brand_report.js`, `brand_ma_panel.js`, `brand_audience_lens_panel.js`. Claim: one mirror of textarea value into text content on input and before Save; browser storage retired. Verify with headless Chrome on a generated report: type after the load event, dump the DOM, reload the dump, read the values back. Also check that the Section_Insights pre-fill still lands (`test_section_insights.R`) and that clearing a box and saving does not resurrect old text.
3. **H2, Kish n_eff.** `00_guard.R` (`.brand_effective_n`), `03b_funnel_metrics.R`, `09e_portfolio_extension.R`, `11_demographics.R`, `13b/13c`. Claim: every sig test and CI now uses the shared `calculate_effective_n()`; no local formula. Verify by grep for any remaining `sum(w)^2` style formula in modules/brand, and by a dispersed-weight fixture where the raw-count test is significant and the effective-n test is not. Note the funnel closures are dead in production (`00_main.R` passes `sig_tester = NULL`); confirm and record.
4. **H1, weighted category penetration.** `09h`, `09c`, `09d`. Verify weighted versus unweighted differ on a dispersed-weight fixture and that unweighted counts still travel for labels.
5. **New defect: Branded Reach wrapper self-call.** `10_branded_reach.R`. Claim: the structure wrapper used to call itself with the engine's arguments, so the element refused on any project with a MarketingReach sheet. Verify on main's file by calling `run_branded_reach()` with a structure carrying a MarketingReach data frame; then on the branch. Then `run_brand()` end to end with a MarketingReach sheet (the integration fixture has a `reach_values` switch).
6. **M3, island escaping.** `panels/00_json_island.R` and all sixteen sites. Verify a payload containing `</script><!--<script>` renders a report whose islands still parse with `JSON.parse` in Chrome and whose next island is not swallowed.
7. **M1, M8, M2, H5, M9.** Guard wired after data load; weights coerced or refused; GUI verdict helper `brand_gui_outcome()`. The GUI was never executed by the fixing session. Run `run_brand_gui.R` if you can, or at least confirm the verdict helper's use sites by reading `run_brand_gui.R` and that a PARTIAL run and a generator refusal reach the notification and Step 5.
8. **Loop-level assignment.** `00_main.R`: two `warnings_list` appends were `<<-` at loop level (one new, one pre-existing) and are now `<-`. Grep for any other loop-level `<<-` on `warnings_list` outside handler closures; each is a silent warning drop.
9. **M4 and C2, disclosure gate.** Nine sites now call `.brand_meets_min_base()`. One basis change: DoP-awareness row gate on the unweighted count. Confirm nothing else changed basis, and that `suppress_base = 0` still means never suppress.
10. **M7, base labels and the reconciliation block.** Report-layer wording. Check every new string for accuracy against the engine denominator it describes (MA MPen is over all respondents in the category sample; category usage is screener over all respondents; the norms-table penetration is over all category respondents). Check there are no em dashes in new strings.
11. **Config hygiene.** `db_importance_method` removed everywhere; MarketingReach template gained three columns; `portfolio_extension_baseline` refuses unknown values. Generate the templates and load them.
12. **Scope.** `git diff --stat main..HEAD` must touch only `modules/brand/` and `docs/v2_lift/`.

## Suites

Brand suite on the branch tip: expected 0 failures (the fixing session reported 2360 pass, 0 fail, 2 skip, 1 warn before the last small commit). Run it and quote your own tally. Three files are known to error in isolation on main too (`test_html_report.R`, `test_cat_buying_panel.R`, `test_guard_and_config.R`); they pass in the full run. Do not count those as findings unless the full run fails.

## What a BLOCK looks like

A wrong number under PASS, a claim in the notes that does not reproduce, a refusal path that silently degrades, or a report-layer change that misstates a denominator. Missing polish is a finding, not a block.

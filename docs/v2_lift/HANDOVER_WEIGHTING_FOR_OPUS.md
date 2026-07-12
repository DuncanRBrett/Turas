# Weighting Lift — Handover for Opus Implementation Session

**Date:** 2026-07-12. Written by the Fable review session for the Opus 4.8 session that will implement.
**You must read, in this order:** (1) this document; (2) `docs/v2_lift/WEIGHTING_PRODUCTION_REVIEW_2026-07-12.md` (the findings — every fix below references its IDs C1-C2, H1-H4, M1-M7). Load the `fable-method` skill. Project CLAUDE.md rules apply (TRS refusals, console-visible errors, tests before "done").
**Scope note:** this module is OUTSIDE the v2-lift report programme — there is no report/exporter/island work here. The deliverable is **correct weights in the lookup file that tabs merges back**. Do not touch `lib/html_report/` beyond what a fix mechanically requires (it was not reviewed).
**Master tracker:** `docs/v2_lift/V2_LIFT_PROGRAM.md` — add/update a weighting row when you finish.

---

## 0. Decisions — Duncan rules on these before the session starts

Fable's recommendation stated for each; Duncan may veto, and the vetoing message wins.

1. **Post-hoc trimming semantics (C1).** Recommendation: for **rim** weights, deprecate the post-hoc `apply_trimming` path entirely — refuse `apply_trimming = Y` on a rim spec with `CFG_TRIM_USE_CAP` pointing the user to `cap_weights` (which trims *inside* calibration and preserves margins — the correct mechanism already exists). For **design/cell** weights, keep post-hoc trimming but always call `rescale_after_trimming` (restore sum) and disclose in diagnostics that trimming moved weighted proportions. Alternative if Duncan wants post-hoc trim kept for rim: trim → rescale → re-run calibrate with trimmed weights as base weights (trim-and-re-rake loop), which is more code and more failure modes.
2. **Design-weight scale (H1).** Are design weights meant to gross to population (mean = pop/sample) or normalise to mean 1 / sum n? Recommendation: normalise to sum = n by default in the config pipeline (consistent with rim, sane tabs weighted-Ns), with an explicit `Grossing = YES` config option that keeps population scale and stamps it in diagnostics. Note: Kish n_eff is scale-invariant, so sig testing is unaffected either way — this is about weighted-N display and cross-method consistency.
3. **NA-weight rows in the lookup file (C2 a+b).** Recommendation: match rim's strictness — design/cell **refuse** when any respondent would get an NA weight (unmatched stratum, undefined cell, NA in a weighting variable), listing the offending values/counts, with an explicit `Allow_Unmatched = YES` opt-in that emits NA plus a prominent console disclosure and an `n_unweighted` count in diagnostics. Silent NA is the current behaviour and is the bug.
4. **Failed weight in PARTIAL mode (C2 c).** Recommendation: omit the failed weight's column from the lookup file entirely (plus loud console block naming it), rather than writing an all-NA column that collapses a tabs run. The PARTIAL run-state entry already records the failure.

---

## 1. Ground rules

- One branch: `feature/weighting-calc-correctness`, off current main. Do not merge — Duncan merges after his eyeball.
- Fix code + run suites only. **Duncan verifies via `launch_turas()` himself** — never headless-run against real project folders, never write into OneDrive.
- Suite: `Rscript -e 'testthat::test_dir("modules/weighting/tests/testthat", reporter = "summary")'`. Baseline 2026-07-12: **0 failures** (1 expected trimming-bias warning). Run before first change and after every fix.
- Every fix ships with a test that **fails on the old code**. TRS refusals only, console-visible. Log deviations; surface them in the final summary.
- Module layout: weighting uses `lib/` (not `R/`). Engines return full-length weight vectors aligned to original row order — **preserve that contract in every change**; it is what makes the positional attach at `run_weighting.R:514` safe.

## 2. Work packages (in this order)

**W1 — Trimming coherence (C1).** Implement decision §0.1. Whatever variant: after any post-hoc trim, weights must either be refused, or rescaled + margins recomputed and honestly disclosed. Kill the dead `rescale_after_trimming` or wire it in — no dead code left. Tests: config with `apply_trimming=Y` on rim → refusal (or, if Duncan picks re-rake: post-trim weights sum to n AND achieved margins within tolerance); design/cell trim → sum restored, disclosure present.

**W2 — Convergence + margin honesty (H4, enables W1's verification).** Replace hardcoded `converged = TRUE` (`rim_weights.R:413`): after calibration (and after any trimming), recompute weighted margins vs targets and set converged/quality from `max(abs(diff_pct)) < tolerance` (configurable, default e.g. 0.5pp). Off-target while bounds-constrained → PARTIAL with the worst margins named, not silent success. Tests: tight bounds + extreme targets fixture reports non-achieved margins; clean fixture still converges.

**W3 — NA-weight policy (C2 a+b).** Implement decision §0.3 in `design_weights.R` and `cell_weights.R` + preflight. Also fix the cell NA-key bug: NA in a cell variable must be detected as missing data *before* key construction, not coerced to the string `"NA"` (`cell_weights.R:113-119`). Empty target cells (H2): refuse by default (target share can't be represented), same opt-in disclosure route. Tests: NA-in-variable fixture refuses with counts; opt-in path emits NA + `n_unweighted`; empty-cell fixture refuses.

**W4 — PARTIAL output (C2 c).** Implement decision §0.4 in `run_weighting.R:502-533` + `write_weighted_data`. Test: two-weight config where one fails → lookup file contains only the surviving weight column, console names the failure.

**W5 — Design-weight normalisation (H1).** Implement decision §0.2 in the config pipeline (`run_weighting.R:397` path). Test: config-path design weights have sum ≈ n (or population under `Grossing = YES`), asserted numerically.

**W6 — ID + column integrity (H3).** In the guard/preflight: refuse duplicate respondent IDs; refuse (or warn loudly, Duncan's call — recommend refuse) when id_column was auto-defaulted to column 1 AND is non-unique; refuse `weight_name` colliding with an existing data column or the id_column (`run_weighting.R:344,514`). Tests for each refusal.

**W7 — Config/label hygiene (M3, M4, M5, M2, M1, M6).** (a) Preflight category-mismatch Warning→Error for design/cell (rim already refuses); `trimws()` both sides of all label matching, keep case-sensitive. (b) `config_loader.R:373`: after coercion, refuse if any target cell became NA that wasn't blank, naming the cell. (c) Cell keys: use a collision-safe separator (e.g. ``) or refuse category values containing the separator. (d) `validation.R:314-316`: derive DEFF/efficiency from unrounded n_eff (match `diagnostics.R`). (e) Rim core direct-API: validate targets sum ≈ 1 in `calculate_rim_weights` itself; clean refusal on duplicate target categories. (f) Cell direct-API: refuse negative/NA target_percent. Tests for each.

**W8 — Numeric test batch (§5 gaps — cheap, high value; do even if time runs short on earlier packages).** Add hand-checkable assertions: Kish on `c(1,1,3)` → n_eff = 25/11, deff = 33/25; unequal-strata design analytic values (71.4/166.7 fixture); multi-variable rim: recompute ALL achieved margins vs targets; rim-on-design g-weights = final/base numerically; NA-bearing rim data → excluded rows NA, others keep positional alignment (assert by ID); strengthen the cap test to a bound ≠ default.

## 3. What NOT to do

- No report/HTML work, no new outputs, no refactors beyond the fixes. No new dependencies (`survey` is already the engine).
- Do not "fix" rim's refuse-on-NA (M7) beyond what W3's policy requires — if Duncan wants an exclude-and-disclose option for rim missing data, that is a separate decision; note it and move on.
- Do not enable rim-on-design combined weighting (LOW finding) — engine supports it, orchestrator doesn't pass it; that's a feature decision, not a bug fix. Note it in your summary.
- Do not weaken any existing refusal to make a test pass.

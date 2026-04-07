# Phase 6 Re-Review: Conjoint + MaxDiff

**Reviewed:** 2026-04-07
**Scope:** Verify all 10 fixes from Phase 6 initial review, then full production audit for gaps
**Verdict:** CONDITIONAL PASS — 2 critical findings, 2 important, 3 minor

---

## Verification Gates

| Gate | Command | Result |
|------|---------|--------|
| Conjoint tests | `testthat::test_dir("modules/conjoint/tests/testthat", reporter = "summary")` | PASS — 545 passed, 0 failures, 12 skipped, 2 warnings (pre-existing) |
| MaxDiff tests | `testthat::test_dir("modules/maxdiff/tests/testthat", reporter = "summary")` | PASS — 750 passed, 0 failures, 5 skipped, 0 warnings |

---

## Part 1: Fix Verification Probes

### Probe 1: C1 — Conjoint formula injection (07_output.R)

**Verdict: FIXED in 07_output.R — but escape does not reach two other output files.**

`conjoint_escape_cell()`/`conjoint_escape_df()` are correctly defined at `07_output.R:31-58` using the vapply+substr pattern with all 7 OWASP prefixes (`=`, `+`, `-`, `@`, `\t`, `\r`, `\n`). NA and empty-string passthrough are correct. Applied to 22+ data frame writeData paths across all 14 Excel sheets in `07_output.R`.

However, two other files that write to Excel have **zero escape protection** — see R1 below.

### Probe 2: C2 — MaxDiff formula injection (09_output.R)

**Verdict: FIXED for core analysis sheets — but Run_Status and DESIGN sheets are unescaped.**

`maxdiff_escape_cell()`/`maxdiff_escape_df()` correctly defined at `09_output.R:31-58`. Applied to 10 core data frame paths (SUMMARY, ITEM_SCORES, SEGMENT_SCORES, INDIVIDUAL_UTILS, MODEL_DIAGNOSTICS, TURF_RESULTS, ANCHOR_ANALYSIS, ITEM_DISCRIMINATION).

The Run_Status sheet and DESIGN/DESIGN_SUMMARY sheets write user-sourced data without escape — see R1 below.

### Probe 3: C3 — Conjoint callout tryCatch + fallback

**Verdict: FIXED.**

- `03_page_builder.R:163-166`: `tryCatch()` wraps `source(callout_registry.R)` with `[CONJOINT]` error message.
- Lines 169-174: No-op fallbacks defined for both `turas_callout` and `turas_callout_html`.
- Line 962: Usage guarded with `exists()`.
- Lines 1030/1038: Usage wrapped in `tryCatch()`.
- Line 1644: Usage guarded with `exists()` and inline fallback.

All 3 usage sites are protected. No issues found.

### Probe 4: C4 — MaxDiff callout tryCatch

**Verdict: FIXED.**

- `03_page_builder.R:31-34`: `tryCatch()` wraps `source(callout_registry.R)` with `[MAXDIFF]` error message.
- Lines 37-39: No-op fallback defined for `turas_callout`.
- Lines 564, 682, 1029: All 3 usage sites wrapped in `tryCatch()`.

No issues found.

### Probe 5: C5 — Conjoint ESS threshold

**Verdict: PARTIALLY FIXED — convergence decision correct, but Excel display still uses old threshold.**

The convergence decision in `11_hierarchical_bayes.R:527` correctly uses `ess > 400` with tiered messaging (< 100 critical, 100-400 warning). However, the Excel output display is inconsistent — see R2 below.

### Probe 6: I1/I2 — GUI launcher cat() before stop()

**Verdict: FIXED.**

- Conjoint `run_conjoint_gui.R:27`: `cat(msg)` before `stop(msg, call. = FALSE)` at line 28.
- MaxDiff `run_maxdiff_gui.R:73`: `cat(msg)` before `stop(msg, call. = FALSE)` at line 74.

No other unguarded `stop()` calls in either file.

### Probe 7: I3/I4 — Stats pack HB diagnostics and model fit

**Verdict: PARTIALLY FIXED — convergence diagnostics added, but HB sampler config parameters missing.**

**Conjoint (`00_main.R:792-839`):** Added Convergence Status, ESS Range, Geweke Test, McFadden R-squared, Hit Rate, Log-Likelihood. Missing: HB burn-in, HB thin, HB chains — see N1 below.

**MaxDiff (`00_main.R:803-830`):** Added Convergence Status, R-hat Max, ESS Min, Divergences, Quality Score. Missing: HB warmup, HB chains — see N1 below.

### Probe 8: I5 — Simulator division-by-zero guard

**Verdict: FIXED for main path.**

Guard at `05_simulator.R:171-175`: `if (sum_exp_utilities < 1e-10)` returns equal shares with `message()` warning. Two per-respondent paths lack similar guards — see N2 below.

---

## Part 2: New Findings (Full Production Audit)

### R1. Formula injection escaping covers only one of three conjoint output files, and only core sheets of maxdiff

**Severity:** Critical
**Affects:** All Excel output from conjoint market simulator, Alchemer import; maxdiff Run_Status and DESIGN sheets

The C1/C2 fixes applied escape protection to the main output files (`07_output.R` and `09_output.R` core sheets) but missed other Excel-writing code paths.

**Conjoint `08_market_simulator.R`** — 6 user-sourced writeData calls with zero escape:
- Line 155: `attr` (attribute name from `config$attributes$AttributeName`)
- Line 167: `attr_levels[1]` (level name from utilities)
- Line 349: `attr` (attribute name)
- Line 456: `attr` (attribute name in sensitivity analysis)
- Line 514: `lookup_data` data frame (Attribute, Level, Key columns from config)
- Line 527: `importance_data` data frame (Attribute column from config)

No import of escape functions exists in this file. The `conjoint_escape_cell()`/`conjoint_escape_df()` closures defined in `07_output.R` are not accessible from `08_market_simulator.R`.

**Conjoint `05_alchemer_import.R`** — 2 user-sourced writeData calls with zero escape:
- Line 851: `settings_df` (setting names and values from parsed survey)
- Line 856: `attrs_df` (AttributeName, NumLevels, LevelNames from config)

**MaxDiff `09_output.R` Run_Status sheet** (lines 1115-1195) — 3 unescaped paths:
- Line 1150: `status_data` data frame (includes `run_result$module`, project name)
- Line 1182: `warnings_list` (could contain user-sourced text from TRS warning messages)
- Line 1192: `events_df` (event messages that may incorporate user-sourced data)

**MaxDiff `09_output.R` DESIGN sheets** — 6 unescaped paths across two functions:
- `write_design_sheets()` lines 1218, 1233, 1239: `design_result$design`, `design_summary$summary`, `design_summary$item_frequencies`
- `generate_design_output()` lines 1295, 1305, 1311: same data in standalone export function

Design data contains item IDs and labels sourced directly from config.

**Total unescaped user-sourced writeData calls: 17 paths.**

**Fix:** For conjoint, either move escape functions to a shared location within the module (e.g., a `utils_escape.R` sourced by both files) or replicate the inline fallback in each file. For maxdiff, apply `maxdiff_escape_df()` to Run_Status and DESIGN data frames before writeData — the functions already exist in the same file.

### R2. Zero test coverage for formula injection escape functions in both modules

**Severity:** Critical
**Affects:** Confidence that escape logic works correctly

Neither module has:
- A dedicated escape test file (e.g., `test_formula_escape.R`)
- Tests for the 7 OWASP injection vectors (`=`, `+`, `-`, `@`, `\t`, `\r`, `\n`)
- Tests for NA passthrough
- Tests for empty string passthrough
- Tests for non-character column passthrough in `escape_df()`
- Tests verifying escape functions are consistent with shared `turas_excel_escape`

This is the identical finding to Phase 3 re-review R2. Security-critical code without automated test coverage is a persistent gap.

**Fix:** Add `test_formula_escape.R` to each module's test suite. At minimum, test:
1. Each OWASP prefix gets a leading apostrophe
2. NA values pass through unchanged
3. Empty strings pass through unchanged
4. Non-character columns in data frames are untouched
5. Nested prefixes (e.g., `==cmd`) are handled
6. The inline fallback matches the shared function behavior

---

### N1. Stats pack assumptions missing HB sampler configuration parameters

**Severity:** Important
**Files:** `conjoint/R/00_main.R:821-833`, `maxdiff/R/00_main.R:817-826`
**Affects:** Stats pack completeness — auditor cannot reconstruct estimation setup

**Conjoint** includes HB Iterations but not burn-in, thin, or chains. These values are available in `model_result$hb_settings` (fields: `burnin`, `thin`; chains = 1 for bayesm).

**MaxDiff** includes HB Iterations but not warmup or chains. These values would be available from HB results (Stan uses warmup + chains).

An auditor receiving the stats pack cannot determine if convergence was assessed on a sufficient post-burn-in sample. For example: 10,000 iterations with 9,000 burn-in and thin=10 yields only 100 post-burn-in draws — the "10,000 iterations" figure alone is misleading.

**Fix:** Add burn-in/thin (conjoint) and warmup/chains (maxdiff) to the assumptions section, adjacent to HB Iterations.

### N2. Conjoint ESS threshold inconsistency between convergence code and Excel display

**Severity:** Important
**File:** `conjoint/R/07_output.R:809,854`
**Affects:** Auditor confidence in diagnostics

The C5 fix correctly raised the convergence decision threshold to ESS > 400 in `11_hierarchical_bayes.R:527`. However, the Excel output still uses the old threshold:

- Line 809: `ESS_Status = ifelse(conv$effective_sample_size > 100, "OK", "LOW")` — should be `> 400` for "OK", with a "WARNING" band for 100-400
- Line 854: Interpretation text says "ESS > 100 indicates sufficient independent draws" — should say > 400

An auditor reviewing the Excel output sees "OK" for ESS values 101-399, contradicting the convergence decision which flags these as warnings. The technique guide (`TECHNIQUE_GUIDE.md:167`) correctly states > 400.

**Fix:** Update line 809 to use the same tiered thresholds as the convergence code. Add a "WARNING" status for 100-400. Update line 854 text to match.

### N3. Conjoint simulator per-respondent logit paths lack division-by-zero guard

**Severity:** Minor
**File:** `conjoint/R/05_simulator.R:672,895`
**Affects:** Per-respondent share calculations with degenerate utilities

Two paths compute `exp_v / sum(exp_v)` per respondent without explicit guard:
- `simulate_logit_individual()` line 672
- `compute_individual_shares()` line 895 (inside `predict_shares_with_ci()`)

The log-sum-exp trick (`exp(v - max(v))`) prevents overflow but doesn't prevent NaN if all values are `-Inf` (degenerate individual HB posteriors). The main `predict_shares_logit()` at line 171 has the guard. Low practical risk.

### N4. MaxDiff guard layer lacks HB configuration parameter validation

**Severity:** Minor
**File:** `maxdiff/R/00_guard.R`
**Affects:** Early error detection for bad HB config

MaxDiff's guard has no `validate_hb_config()` function. HB iteration count, warmup, and thin parameters from config are passed to estimation without validation. Conjoint validates `iterations >= 100`, `burnin < iterations`, `thin >= 1`. MaxDiff relies on cmdstanr's own validation, which produces less helpful error messages than TRS refusals.

### N5. MaxDiff has no config template generator

**Severity:** Minor
**Affects:** Operator experience — Jess cannot generate a blank config from the module

Conjoint has a proper template generator (`R/12_config_template.R`) producing the 5-column Tabs-standard format. MaxDiff loads config via `01_config.R` but has no template generator. Operators must copy an existing config or build one from documentation.

---

## Verified Correct (Spot Checks)

| Item | Verdict | Notes |
|------|---------|-------|
| Conjoint MNL estimation via survival::clogit() | Correct | Standard conditional logit |
| Conjoint HB via bayesm::rhierMnlRwMixture() | Correct | Standard package, proper lgtdata format |
| Conjoint Geweke test: first 10% vs last 50% | Correct | Standard Geweke fractions |
| MaxDiff aggregate logit via coxph | Correct | Best-worst paired data format |
| MaxDiff HB via cmdstanr with Stan model | Correct | Multi-chain with split R-hat, bulk ESS |
| MaxDiff TURF greedy forward selection | Correct | Standard algorithm, reach + frequency |
| MaxDiff preference share rescaling | Correct | exp(u_i)/sum(exp(u_j)) verified |
| Conjoint importance formula: range/sum(ranges) | Correct | Standard CBC importance |
| Conjoint simulator availability weights | Correct | A_i * exp(U_i) / sum(A_j * exp(U_j)) |
| Conjoint RLH quality flagging at 1.5x chance | Correct | Industry standard threshold |
| Shared trs_run_status_writer.R | Note | Also lacks escape — shared infrastructure issue for Phase 10 |
| Conjoint technique guide | Production quality | All 7 required topics covered. Technically accurate. Minor gap: simulator interpretation depth |
| MaxDiff technique guide | Production quality | All 8 required topics covered. Technically accurate. No significant gaps |

---

## Statistical Correctness Assessment

### Conjoint ESS Threshold Chain

The C5 fix correctly propagates from Phase 0's finding:
- `11_hierarchical_bayes.R:527`: `ess_pass <- all(ess > 400)` — CORRECT
- `11_hierarchical_bayes.R:534`: `ess_critical <- any(ess < 100)` — CORRECT (tiered: <100 critical, 100-400 warning)
- `07_output.R:809`: `ESS_Status = ifelse(conv$effective_sample_size > 100, "OK", "LOW")` — INCONSISTENT (still uses >100)
- `TECHNIQUE_GUIDE.md:167`: ">400 good, 100-400 warning, <100 critical" — CORRECT

The convergence **decision** is correct. The convergence **display** in Excel is wrong. This means a model with ESS=150 would be correctly flagged as a convergence warning internally, but the Excel output would show "OK" — misleading for auditors.

### MaxDiff HB Convergence

MaxDiff uses cmdstanr with proper multi-chain diagnostics:
- Split R-hat < 1.01 optimal, < 1.05 warning, > 1.10 critical — CORRECT (matches Stan recommendations)
- Bulk ESS < 100 critical, < 400 warning — CORRECT
- Divergent transitions counted — CORRECT
- Quality scoring system combines all metrics — CORRECT

No issues with MaxDiff's convergence framework.

---

## Disposition

| Finding | Severity | Action | When |
|---------|----------|--------|------|
| R1: Formula escape gaps (17 paths) | Critical | Fix before merge | This branch |
| R2: Zero escape test coverage | Critical | Fix before merge | This branch |
| N1: Stats pack missing HB sampler config | Important | Fix before merge | This branch |
| N2: ESS display inconsistency | Important | Fix before merge | This branch |
| N3: Per-respondent div-by-zero | Minor | Defer | Phase 10 |
| N4: MaxDiff HB config validation | Minor | Defer | Phase 10 |
| N5: MaxDiff config template generator | Minor | Defer | Phase 10 |

**R1 and R2 must be fixed before merge.** R1 leaves 17 Excel write paths vulnerable to formula injection — the same class of issue the initial review's C1/C2 were meant to address. R2 means the escape logic has no automated verification.

**N1 and N2 should be fixed before merge.** N2 produces misleading audit output. N1 leaves stats pack incomplete for estimation reproducibility.

**N3-N5 can be deferred** to Phase 10 — low practical risk or enhancement-level items.

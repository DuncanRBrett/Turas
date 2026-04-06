# Phase 5: Pricing Review

**Reviewed:** 2026-04-07
**Scope:** modules/pricing/ (14 R/ files, 10 lib/ files, 24 test files, ~16,400 LOC prod)
**Verdict:** PASS WITH CONDITIONS — 3 critical findings, 5 important, 6 minor

---

## Verification Gates

| Gate | Command | Result |
|------|---------|--------|
| Tests | `testthat::test_dir("modules/pricing/tests/testthat")` | PASS — 0 failures, 63 warnings (all pre-existing) |
| Lint | Manual review | No blocking issues |

---

## Critical Findings

These must be fixed. Each represents a path where Turas could produce incorrect output or deliver incomplete deliverables.

### C1. No formula injection protection in any Excel output path

**Files:** `pricing/R/06_output.R` (all 62+ writeData calls), `pricing/R/00_main.R:729` (config echo)
**Affects:** All Excel output from the pricing module

The module has zero calls to `turas_excel_escape()`, zero inline escape functions, and no import of the shared escape utility. Every `writeData()` call in `06_output.R` writes data frames and character vectors directly to Excel without escaping.

User-sourced text reaching Excel unescaped includes:

- **Summary sheet** (line 121): `config$project_name`, analysis date
- **Validation sheet** (lines 463, 484, 509, 522): exclusion reasons, monotonicity action labels, warning strings
- **Segment_Comparison sheet** (lines 709, 724): segment names (from data), insight text
- **Price_Ladder sheet** (lines 738, 756, 783): tier names, ladder notes, diagnostic strings
- **Recommendation sheet** (lines 809, 832, 843, 873, 886): recommendation source, range descriptions, evidence table, risk strings, executive summary lines
- **Executive_Summary sheet** (line 886): full executive summary text split by newlines
- **Configuration sheet** (line 909): project name, data file path, currency symbol
- **WTP sheets** (lines 557, 572, 582): WTP metric labels
- **Competitive_Scenarios sheet** (line 594): scenario data frame
- **Constrained_Optimization sheet** (lines 638, 657): constraint names and values
- **NMS sheet** (lines 684, 696): NMS metric labels and data
- **VW/GG/Mon sheets**: data frames containing column names from survey data

The most dangerous vectors are **segment names** (from the survey data file, user-controlled), **project name** (from config), and **executive summary lines** (from recommendation synthesis, which incorporates config values).

No inline escape fallback is defined anywhere in the module. The shared `turas_excel_escape.R` is sourced in `00_main.R` via `.source_trs_infrastructure()` but the output module never calls it.

**Risk:** A config file with `project_name = "=IMPORTXML(...)"` or survey data with a segment label starting with `=` would execute as a formula when the Excel file is opened. This was fixed in weighting (Phase 2 C2), stats_pack_writer (Phase 0 C5), keydriver/catdriver (Phase 3 C3), and segment (Phase 4 C1).

**Fix:** Define an inline escape fallback using vapply+substr (not regex, per Phase 3 re-review R3). Apply to all character columns in data frames before `writeData()` calls and to all scalar string values written via `writeData()`. Follow the segment module pattern (`seg_escape_cell()`/`seg_escape_df()`).

### C2. HTML report callout sourcing has no tryCatch or no-op fallback

**File:** `pricing/lib/html_report/03_page_builder.R`, lines 25-26
**Affects:** HTML report generation in standalone/CLI contexts

The callout registry sourcing is a bare `source()` call:
```r
if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
  source(file.path(callout_dir, "callout_registry.R"), local = FALSE)
}
```

No `tryCatch` wraps the `source()`. No no-op fallback `turas_callout()` is defined if sourcing fails. The usage sites at lines 1791-1793 reference `turas_callout_text()` (a different function from `turas_callout()`) wrapped in individual `tryCatch()` calls — so these specific call sites are defensively coded. However, the architecture is fragile: a partial source failure or corrupted registry file would cause the entire page assembly to crash before reaching those guarded call sites.

This is the identical pattern found in confidence (Phase 2 C3), keydriver (Phase 3 C1), catdriver (Phase 3 C2), and segment (Phase 4 C3).

**Risk:** In standalone or CLI execution paths, HTML report generation fails entirely if the shared library is not found or partially loads.

**Fix:** Apply the established pattern: `tryCatch(source(...), error = function(e) message(...))` around the registry sourcing, plus a no-op fallback `turas_callout <<- function(module, key, ...) ""` after. Also add a parallel no-op for `turas_callout_text` if it does not exist.

### C3. Stats pack duration is always ~0 seconds

**File:** `pricing/R/00_main.R`, line 577
**Affects:** Stats pack diagnostic accuracy

The `start_time` parameter passed to `generate_pricing_stats_pack()` is captured at line 577:
```r
start_time = Sys.time()
```

This executes at STEP 10 of the pipeline — after all analysis (VW, GG, monadic, segmentation, ladder, synthesis, visualizations, and Excel output) is already complete. The duration calculation inside the stats pack generator (`difftime(Sys.time(), start_time)`) measures only the time to write the stats pack itself, not the full analysis duration.

Every other module captures start time at the beginning of the main function and passes it through. The pricing module does not.

**Risk:** Duncan delivers a stats pack claiming the analysis took 0.2 seconds when it actually took 45 seconds. The contractual acceptance document contains false execution metadata.

**Fix:** Capture `start_time <- Sys.time()` at the beginning of `run_pricing_analysis_from_config()` (immediately after line 166) and pass it through to the stats pack generator.

---

## Important Findings

These should be fixed soon. They affect consistency, maintainability, or robustness.

### I1. GUI launcher stop() has no cat() for Shiny console visibility

**File:** `pricing/run_pricing_gui.R`, line 41
**Affects:** Error display when required packages are missing

The `early_refuse()` function at line 26 constructs a well-formatted error message and calls `stop(msg, call. = FALSE)` at line 41. There is no preceding `cat()` output. In Shiny, the formatted error may not reach the console — `stop()` inside a Shiny reactive context produces an unformatted error.

This is the same pattern fixed in Phase 2 I4 (confidence), Phase 3 I2-I3 (keydriver/catdriver), and Phase 4 I2 (segment).

**Fix:** Add `cat(msg)` before the `stop()` call at line 41 to ensure the formatted error is visible in the Shiny console.

### I2. Stats pack missing method-specific diagnostics and expanded config echo

**File:** `pricing/R/00_main.R`, lines 633-732 (`generate_pricing_stats_pack`)
**Affects:** Contractual deliverables

The stats pack includes basic execution metadata but omits:

1. **Method-specific results** — VW price points (PMC, OPP, IDP, PME), GG optimal price and revenue index, monadic model fit (pseudo-R2, AIC, price coefficient p-value) are not included. An auditor cannot verify the analysis produced valid results without opening the main output file.
2. **Bootstrap parameters** — When confidence intervals are calculated, the number of iterations, confidence level, and failure rate are not recorded.
3. **Per-method sample sizes** — VW n_valid, GG n_respondents, monadic n_valid are not included. Only the overall validation n_valid appears.
4. **Weight diagnostics** — When weights are applied, no DEFF, effective N, or weight range is reported. Other modules (weighting Phase 2, keydriver Phase 3) include these.
5. **Config echo is limited** — Line 729 echoes only 5 fields (`analysis_method`, `currency_symbol`, `project_name`, `data_file`, `output_file`). Missing: VW column mappings, GG price sequence length, monadic model type, segmentation column, bootstrap settings, unit cost, monotonicity behavior.

By contrast, Phase 4 (segment) expanded its stats pack to include per-cluster sizes, validation metrics, method-specific parameters, and comprehensive config echo.

**Risk:** Duncan delivers a stats pack for a weighted monadic analysis that shows no model fit statistics, no weight diagnostics, and no bootstrap parameters. The contractual acceptance document is incomplete.

**Fix:** Add method-specific results section, bootstrap parameters, per-method sample sizes, weight diagnostics (when applicable), and expand the config echo to cover all method-specific settings.

### I3. write.csv in export_pricing_csv has no encoding specification

**File:** `pricing/R/06_output.R`, lines 989, 994, 1003, 1008
**Affects:** CSV output on Windows with non-default locale

Four `write.csv()` calls without `fileEncoding = "UTF-8"`. Same pattern fixed in Phase 2 I6 (weighting) and Phase 4 M9 (segment).

**Fix:** Add `fileEncoding = "UTF-8"` to all `write.csv()` calls.

### I4. Demand curve effective_n column is sum of weights, not Kish effective N

**File:** `pricing/R/04_gabor_granger.R`, line 348
**Affects:** Demand curve output interpretation

```r
demand$effective_n[i] <- sum(weights)
```

The column name `effective_n` implies the Kish effective sample size `(sum(w))^2 / sum(w^2)`, which accounts for design effect. The actual value is `sum(weights)` — the weighted count. When weights are normalized to sum to N, these are identical. When weights are un-normalized (e.g., design weights > 1), the column name is misleading.

The demand calculation itself (`purchase_intent = sum(w * r) / sum(w)`) is correct regardless of the column name.

**Risk:** Low — the column is informational, not used in downstream calculations. But an analyst reading the Excel output may interpret `effective_n = 250` as design-effect-adjusted when it's actually `sum(weights) = 250`.

**Fix:** Rename the column to `weighted_n` or add the Kish formula: `effective_n[i] <- sum(weights)^2 / sum(weights^2)`.

### I5. Config template generator stop() at infrastructure load

**File:** `pricing/lib/generate_config_templates.R`, line 24
**Affects:** Config template generation when shared infrastructure is missing

```r
stop("Cannot locate modules/shared/template_styles.R")
```

This is a developer-facing infrastructure assertion, which is acceptable per Phase 0 conventions. However, when called from the Shiny GUI (via a "Generate Template" button), this `stop()` produces an unformatted crash. The template generator is the only pricing-specific file with a bare `stop()`.

**Fix:** Add a `cat()` message before the `stop()` for Shiny console visibility, or convert to a `pricing_refuse()` call if the guard layer is loaded by this point.

---

## Minor Findings

Worth fixing when touching these files. Not urgent.

### M1. Monadic bootstrap variable name could cause confusion with log_logistic variant

**File:** `pricing/R/13_monadic.R`, lines 376-382
**Affects:** Code maintainability

The bootstrap loop uses `b_prices` as the variable name for both model fitting and prediction:
```r
b_model <- glm(b_intents ~ log(b_prices), ...)
b_pred <- predict(b_model, newdata = data.frame(b_prices = price_range), ...)
```

This works correctly because R's `predict()` applies the formula transformation (`log()`) to the new data automatically. But it's non-obvious — a maintainer might expect `data.frame(b_prices = log(price_range))` and "fix" it, breaking the prediction. A brief comment would prevent this.

### M2. Bootstrap failure rate not reported in stats pack

**File:** `pricing/R/13_monadic.R`, line 402
**Affects:** Diagnostic completeness

When bootstrap iterations fail, the code warns if < 50% succeed but doesn't record the actual success rate anywhere except console output. The stats pack should include `bootstrap_success_rate` when bootstrap CIs are calculated.

### M3. Segmented analysis for monadic hits refusal inside tryCatch

**File:** `pricing/R/00_main.R`, line 383; `pricing/R/10_segmentation.R`, line 64
**Affects:** User experience for monadic + segmentation configs

When `analysis_method = "monadic"` and segmentation is configured, `run_segmented_analysis()` receives `method = "monadic"` which triggers a refusal at `10_segmentation.R:64` (only `van_westendorp` and `gabor_granger` are supported). This refusal is caught by the `tryCatch` at line 379 and logged as a PARTIAL, which is correct behavior. However, a config-level guard should catch this earlier and produce a clearer message: "Monadic segmentation is not yet supported."

### M4. No test fixtures directory

**Scope:** `pricing/tests/`
**Affects:** Test infrastructure consistency

The pricing module has no `tests/fixtures/` directory and no golden fixture generator. All 24 test files create synthetic data inline. This is acceptable given the module's excellent test ratio (0.96), but differs from the pattern established in Phases 3-4 where golden fixtures were generated and committed.

### M5. PCHIP endpoint derivative uses h[n-2] which may be out of bounds with 2 points

**File:** `pricing/R/04_gabor_granger.R`, line 719
**Affects:** Edge case with exactly 2 price points

```r
d[n] <- pchip_endpoint_deriv(h[n-1], h[n-2], delta[n-1], delta[n-2])
```

When `n = 2`, `h[n-2] = h[0]` which is out of bounds in R (returns `numeric(0)`). The PCHIP function is only called from `interpolate_demand_curve()` which guards `length(prices) < 2`, but not `length(prices) == 2`. With exactly 2 points, the endpoint derivative computation would fail.

**Fix:** Guard `n == 2` in `pchip_interpolate()` and fall back to linear interpolation.

### M6. Multiple comparison of prices across segments not documented

**File:** `pricing/R/10_segmentation.R`
**Affects:** Interpretation of segment comparison results

Segment comparisons are made independently (each segment vs total, each segment vs each other segment) without family-wise error correction. Same pattern as Phase 4 I1 (segment profiling). This is standard market research practice but should be documented in the stats pack assumptions.

---

## Test Coverage Summary

| Metric | Pricing |
|--------|---------|
| Production files | 24 (14 R/ + 10 lib/) |
| Test files | 24 |
| File ratio (test:prod) | 1.00 |
| Production LOC | ~16,400 |
| Test LOC | ~8,300 |
| LOC ratio (test:prod) | ~0.51 |
| Tests passing | All |
| Tests skipped | 0 |
| Golden fixtures | None |

### Coverage assessment

The pricing module has the best test:file ratio in the codebase (1.00). Core analysis methods (VW, GG, monadic) each have dedicated test files with good coverage of happy paths, edge cases, and error handling. The optimization, elasticity, WTP distribution, and competitive scenarios all have dedicated test files.

HTML report generation (`03_page_builder.R`, 2,050 LOC) has a test file (`test_html_report.R`) but tests are integration-level, not unit-level. Section builder functions are not individually tested.

The test suite exercises the full pipeline end-to-end (`test_main_pipeline.R`, `test_integration.R`) which provides good regression coverage.

---

## Statistical Correctness Assessment

### Van Westendorp (03_van_westendorp.R)

Correctly delegates to `pricesensitivitymeter::psm_analysis()` with all required parameters. Interpolation steps set to 0.1 for smooth curves. NMS extension correctly detected and used when purchase intent columns are present. Bootstrap CIs use weighted resampling with percentile method — standard approach.

Validation is thorough: 8 checks covering config completeness, column presence, numeric validity, sample size (n >= 30), logical ordering (violation rate < 10%), positive prices, extreme outliers (10x median), and duplicate detection.

### Gabor-Granger (04_gabor_granger.R)

Demand curve calculation is correct: weighted purchase intent = `sum(w * response) / sum(w)`. Revenue index = `price * purchase_intent`. Profit index = `(price - unit_cost) * purchase_intent`. All correct.

Arc elasticity formula uses midpoint method: `((Q2-Q1)/Qavg) / ((P2-P1)/Pavg)`. Standard formulation, correct.

Monotonicity enforcement via cummax from high-to-low price is correct. Isotonic regression (PAVA) implementation is correct — pool adjacent violators algorithm minimizing squared error subject to monotone decreasing constraint.

PCHIP interpolation implements Fritsch-Carlson monotone cubic with harmonic mean derivatives. Correct for preserving monotonicity. Edge case concern noted in M5.

### Monadic (13_monadic.R)

Logistic regression via `glm(intent ~ price, family = binomial)` is standard. McFadden's pseudo-R2 = `1 - (residual_deviance / null_deviance)` is correct.

Bootstrap CIs correctly resample respondents (preserving within-respondent correlation), skip degenerate samples (`unique(b_intents) < 2`), and use percentile method. Success rate check at 50% threshold is reasonable.

Revenue optimization finds `which.max(price * predicted_intent)` on a fine grid — correct. Profit optimization uses `which.max((price - unit_cost) * predicted_intent)` — correct.

**Methodological note:** Survey weights are used as `glm()` weights, which in the binomial case function as prior weights (effectively frequency weights). This produces consistent coefficient estimates but may understate standard errors. The bootstrap CI approach compensates for this by using weighted resampling. This is a standard pragmatic approach in applied market research. Worth documenting in the technique guide as an assumption.

### Price-Volume Optimization (09_price_volume_optimisation.R)

Constrained optimization correctly applies feasibility masks and optimizes within the feasible set. Point elasticity uses the analytical logistic derivative `beta * p(1-p)` — correct for the logistic model. Continuous optimization via `optimize()` on interpolated demand — correct approach.

### Recommendation Synthesis (12_recommendation_synthesis.R)

Triangulation across methods uses confidence scoring based on method agreement, sample size, and validation quality. This is a proprietary heuristic, not a statistical test — appropriate for producing a single recommendation from multiple methods.

---

## TRS Compliance Summary

| Metric | Pricing |
|--------|---------|
| stop() calls in production | 0 |
| stop() calls in GUI launcher | 1 (early_refuse — I1) |
| stop() calls in infra/generator | 1 (template_styles load — I5) |
| stop() calls in tests | 0 |
| TRS refusals (pricing_refuse) | 74 hard guards |
| Guard layer | Complete (00_guard.R, 758 LOC) |
| Stats pack | Present (C3: duration bug, I2: incomplete) |
| Run state tracking | Present |
| Console output | Comprehensive |
| Formula escape | ABSENT (C1) |
| Callout fallback | ABSENT (C2) |

---

## Fix Status (2026-04-07)

All critical and important findings addressed in this session. Tests passing (Pricing: all pass, 0 skips, 63 pre-existing warnings).

| Finding | Status | What was done |
|---------|--------|---------------|
| C1: Formula injection in Excel output | FIXED | Added `pricing_escape_cell()`/`pricing_escape_df()` inline fallback using vapply+substr (not regex). Applied to all 44 writeData paths in `06_output.R` (29 data frames + 5 scalar strings + 10 additional sub-sheet writes) |
| C2: HTML callout tryCatch + fallback | FIXED | Added `tryCatch()` around `source(callout_registry.R)` with `message()` on error. Added no-op fallbacks for both `turas_callout` and `turas_callout_text` |
| C3: Stats pack duration always ~0 | FIXED | Captured `start_time <- Sys.time()` at beginning of `run_pricing_analysis_from_config()` (line 168). Stats pack now receives the real start time |
| I1: GUI launcher cat() before stop() | FIXED | Added `cat(msg)` before `stop(msg, call. = FALSE)` in `early_refuse()` for Shiny console visibility |
| I2: Stats pack incomplete | FIXED | Added method-specific results (VW price points, GG optimal price, monadic model fit), weight diagnostics, bootstrap parameters, expanded config echo with all method-specific settings |
| I3: write.csv encoding | FIXED | Added `fileEncoding = "UTF-8"` to all 4 `write.csv()` calls in `export_pricing_csv()` |
| I4: effective_n column name | FIXED | Renamed `effective_n` to `weighted_n` in `calculate_demand_curve()` to accurately reflect `sum(weights)` |
| I5: Template generator stop() | FIXED | Added `cat()` message before `stop()` in `.find_shared_template_styles()` for Shiny console visibility |
| M1-M6 | DEFERRED | All minor findings deferred to Phase 10 horizontal pass |

**Also completed:**
- Technique guide written at `modules/pricing/TECHNIQUE_GUIDE.md` covering method selection, questionnaire design, interpreting output, watchouts, and future directions

**Deferred to Phase 10 (horizontal pass):**
- M1: Monadic bootstrap variable name comment
- M2: Bootstrap failure rate in stats pack
- M3: Config-level guard for monadic + segmentation
- M4: Golden fixture infrastructure
- M5: PCHIP 2-point edge case guard
- M6: Multiple comparison documentation in segment analysis

**Next:** Re-review in fresh session to verify all fixes, then proceed to Phase 6 (Conjoint + MaxDiff).

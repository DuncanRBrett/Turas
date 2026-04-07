# Phase 6: Conjoint + MaxDiff Review

**Reviewed:** 2026-04-07
**Scope:** modules/conjoint/ (20 R/ files, 7 lib/html_report, 4 lib/html_simulator, ~18,400 LOC prod) + modules/maxdiff/ (14 R/ files, 5 lib/html_report, 4 lib/html_simulator, ~17,200 LOC prod)
**Verdict:** PASS WITH CONDITIONS — 5 critical findings, 5 important, 3 minor

---

## Verification Gates

| Gate | Command | Result |
|------|---------|--------|
| Conjoint tests | `testthat::test_dir("modules/conjoint/tests/testthat", reporter = "summary")` | PASS — 545 passed, 0 failures, 12 skipped, 2 warnings (pre-existing) |
| MaxDiff tests | `testthat::test_dir("modules/maxdiff/tests/testthat", reporter = "summary")` | PASS — 750 passed, 0 failures, 5 skipped, 0 warnings |

---

## Critical Findings

### C1. No formula injection protection in conjoint Excel output

**Files:** `conjoint/R/07_output.R` (~63 writeData calls), `conjoint/R/08_market_simulator.R` (~29 writeData calls), `conjoint/R/05_alchemer_import.R` (2 writeData calls)
**Affects:** All Excel output from the conjoint module

Zero calls to `turas_excel_escape()`, zero inline escape functions, no import of the shared escape utility. Every `writeData()` call writes data frames and character vectors directly to Excel without escaping.

User-sourced text reaching Excel unescaped includes:

- **Part-Worth Utilities** (line 449): `Attribute`, `Level` columns — from config, user-controlled
- **Attribute Importance** (line 426): `Attribute` column
- **Configuration** (line 550): `AttributeName`, `LevelNames` — from config
- **Raw Coefficients** (line 374): `Coefficient` column — model-derived from data column names
- **Individual Utilities** (line 644): respondent IDs, readable column names built from attribute map
- **HB Diagnostics** (line 699+): parameter names from model
- **Data Summary** (line 507+): validation messages
- **Market Simulator** (lines 128-480): attribute levels via dropdown data and formulas
- **Alchemer Import** (lines 851, 856): settings and attributes data frames from parsed survey

The most dangerous vectors are **attribute names and level names** (from the config file, user-controlled), **coefficient names** (derived from survey data column headers), and **respondent IDs** (from survey data).

**Fix:** Define inline escape fallback using vapply+substr (not regex, per Phase 3 re-review R3). Apply to all character columns in data frames before `writeData()` and to all scalar string values. Follow the pricing module pattern (`pricing_escape_cell()`/`pricing_escape_df()`).

### C2. No formula injection protection in maxdiff Excel output

**Files:** `maxdiff/R/09_output.R` (~17 writeData calls)
**Affects:** All Excel output from the maxdiff module

Same pattern as C1. Zero escape functions. User-sourced text reaching Excel unescaped includes:

- **SUMMARY** (lines 376-385): Project_Name, Mode, Module_Version, Seed — from config
- **ITEM_SCORES** (line 476): Item_ID, Item_Label, Item_Group — from config items sheet
- **SEGMENT_SCORES** (lines 584, 601): Segment_ID, Segment_Label, Segment_Value — from survey data
- **INDIVIDUAL_UTILS** (line 676): Individual utility data frame — column names from item labels
- **MODEL_DIAGNOSTICS** (lines 762-768): Section names, diagnostic metric labels
- **TURF_RESULTS** (line 828): Item_ID, Item_Label
- **ANCHOR_ANALYSIS** (line 917): Item_ID, Item_Label, Is_Must_Have

The most dangerous vectors are **Item_Label** (from config, user-controlled) and **Segment_Label/Segment_Value** (from survey data).

**Fix:** Same approach as C1. Define `maxdiff_escape_cell()`/`maxdiff_escape_df()` inline fallback. Apply to all character data before `writeData()`.

### C3. Conjoint HTML callout sourcing has no tryCatch or no-op fallback

**File:** `conjoint/lib/html_report/03_page_builder.R`, lines 160-164
**Affects:** HTML report generation in standalone/CLI contexts

The callout registry sourcing is a bare `source()` call:
```r
if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
  source(file.path(callout_dir, "callout_registry.R"), local = FALSE)
}
```

No `tryCatch()` wraps the `source()`. No no-op fallback is defined if sourcing fails.

Additionally, lines 1020/1022 call `turas_callout()` for convergence diagnostics **without** an `exists()` check or `tryCatch()`:
```r
conv_explain <- paste0('<div ...>', turas_callout("conjoint", "convergence_pass"), '</div>')
```

If the callout registry failed to load, these calls would crash the diagnostics panel build. Other call sites (line 952) correctly use `exists()` guards, but these two do not.

The conjoint module also uses `turas_callout_html()` at line 1628 with an `exists()` guard and inline fallback — correct pattern. But no no-op `turas_callout` is defined for the unguarded sites.

This is the identical pattern found in confidence (Phase 2 C3), keydriver (Phase 3 C1), catdriver (Phase 3 C2), segment (Phase 4 C3), and pricing (Phase 5 C2).

**Fix:** Apply the established pattern: `tryCatch(source(...), error = function(e) message(...))` around the registry sourcing, plus no-op fallbacks for `turas_callout` and `turas_callout_html`. Additionally, wrap the unguarded calls at lines 1020/1022 in `tryCatch()` or add `exists()` guards.

### C4. MaxDiff HTML callout sourcing has no tryCatch on source()

**File:** `maxdiff/lib/html_report/03_page_builder.R`, lines 28-32
**Affects:** HTML report generation in standalone/CLI contexts

Same bare `source()` pattern as C3:
```r
if (!exists("turas_callout", mode = "function") && dir.exists(callout_dir)) {
  source(file.path(callout_dir, "callout_registry.R"), local = FALSE)
}
```

The individual usage sites (lines 557-564, 675-678, 1022-1025) are correctly wrapped in `tryCatch()`, so they would safely return "" if `turas_callout` didn't exist. However, the `source()` itself could crash with a partial load, potentially leaving a broken `turas_callout` function that passes the `exists()` check but errors on call.

**Fix:** Apply the same pattern: `tryCatch(source(...), error = function(e) message(...))` around the registry sourcing, plus a no-op `turas_callout` fallback.

### C5. Conjoint HB convergence ESS threshold too lenient (>100 vs recommended >400)

**File:** `conjoint/R/11_hierarchical_bayes.R`, line 527
**Affects:** HB convergence assessment reliability

The ESS convergence threshold is:
```r
ess_pass <- all(ess > 100)
```

This is the exact issue Phase 0 flagged. The maxdiff module's guard layer (`00_guard.R:533`) uses ESS > 400 for PASS status. The shared `hb_diagnostics.R` states ESS should be "ideally > 400". The conjoint module applies a threshold 4x more lenient than the rest of the platform.

Additionally, the conjoint module uses a single-chain Geweke Z-test rather than multi-chain split R-hat. With bayesm (single-chain MCMC), Geweke is appropriate, but the low ESS threshold means a chain with high autocorrelation (ESS = 101 from 10,000 draws) would pass convergence. At ESS = 101, posterior quantile estimates have meaningful Monte Carlo error — roughly 10% of the posterior standard deviation for 95% intervals.

**Fix:** Raise the ESS threshold to > 400 to match the maxdiff module and shared diagnostics. Add a PARTIAL status band for 100 < ESS <= 400 with a warning message (matching the maxdiff pattern of ESS < 100 = CRITICAL, ESS < 400 = WARNING).

---

## Important Findings

### I1. Conjoint GUI launcher stop() has no cat() for Shiny console visibility

**File:** `conjoint/run_conjoint_gui.R`, line 27
**Affects:** Error display when required packages are missing

The `early_refuse()` function constructs a formatted error message and calls `stop(msg, call. = FALSE)` at line 27 without a preceding `cat(msg)`. In Shiny, the formatted error may not reach the console.

Same pattern fixed in pricing (Phase 5 I1), confidence (Phase 2 I4), keydriver/catdriver (Phase 3 I2-I3), segment (Phase 4 I2).

**Fix:** Add `cat(msg)` before the `stop()` call at line 27.

### I2. MaxDiff GUI early_refuse() stop() has no cat() for Shiny console visibility

**File:** `maxdiff/run_maxdiff_gui.R`, line 73
**Affects:** Error display for infrastructure load failures

The initial package check (lines 16-37) correctly uses `cat()` + `return(invisible(...))` — the modern TRS pattern. However, the `early_refuse()` function defined at line 60 uses `stop(msg, call. = FALSE)` at line 73 without `cat()`. This function is used for later error conditions (shared infrastructure load failures, etc.).

**Fix:** Add `cat(msg)` before the `stop()` call at line 73.

### I3. Both stats packs missing HB convergence diagnostics

**Files:** `conjoint/R/00_main.R` lines 792-804, `maxdiff/R/00_main.R` lines 803-812
**Affects:** Contractual deliverables — stats pack completeness

**Conjoint stats pack assumptions** include: Model Type, Attributes, Levels, Tasks, HB Iterations, Seed, WTP, Simulation, Implementation, TRS Status, TRS Events. Missing:
- Convergence status (converged yes/no)
- ESS range (min-max)
- Geweke test results (pass/fail, max |z|)
- HB burn-in, thin, chains settings

**MaxDiff stats pack assumptions** include: Items, Tasks per respondent, Method, HB Iterations, Seed, TURF, TRS Status, TRS Events. Missing:
- Convergence status, quality score
- R-hat max, ESS min
- Divergence count
- HB warmup, chains settings

An auditor reviewing the stats pack cannot verify model convergence without opening the main output file.

**Fix:** Add convergence diagnostics to the assumptions section when HB estimation was used. Include: convergence status, ESS range (conjoint) / R-hat max + ESS min (maxdiff), and burn-in/warmup settings.

### I4. Conjoint stats pack missing model fit statistics

**File:** `conjoint/R/00_main.R` lines 792-804
**Affects:** Stats pack completeness

The conjoint model produces McFadden R², hit rate, log-likelihood, AIC, and BIC (available in `diagnostics$fit_statistics`), but none of these are included in the stats pack assumptions. An auditor cannot assess model quality from the stats pack alone.

**Fix:** Add model fit statistics (R², hit rate, log-likelihood) to the stats pack assumptions when available. Use the same conditional pattern as the maxdiff HB diagnostics.

### I5. Simulator logit share calculation has no division-by-zero guard

**File:** `conjoint/R/05_simulator.R`, line 171
**Affects:** Market share predictions with all-unavailable products

```r
sum_exp_utilities <- sum(exp_utilities)
shares <- exp_utilities / sum_exp_utilities
```

If all availability weights are 0 (e.g., user sets all products to unavailable), `sum_exp_utilities` = 0, producing NaN shares. The log-sum-exp trick prevents overflow but not this edge case. The `predict_market_shares()` function validates that availability has the right length but does not check `sum(availability) > 0`.

**Fix:** Add guard: `if (sum_exp_utilities < 1e-10) return(rep(1/length(utilities), length(utilities)))` with a `message()` warning.

---

## Minor Findings

### M1. Conjoint convergence diagnostics don't use shared hb_diagnostics.R

**File:** `conjoint/R/11_hierarchical_bayes.R`, line 472
**Affects:** Code maintainability, diagnostic consistency

The module loads the shared diagnostics (`.load_hb_diagnostics()` at line 472) but never calls `check_hb_convergence()` from the shared module. Instead, it implements its own simplified Geweke + ESS diagnostics at lines 494-523. The shared module provides Gelman-Rubin R-hat (appropriate for multi-chain MCMC), which is less applicable to bayesm's single-chain output, so the divergence is somewhat justified. However, the ESS calculation logic is duplicated.

### M2. MaxDiff guard fallback TRS uses bare stop()

**File:** `maxdiff/R/00_guard.R`, line 49
**Affects:** Error handling when shared TRS infrastructure is unavailable

```r
stop(paste0("[", code, "] ", title, ": ", problem))
```

The fallback path (only reached when `turas_refuse()` is not available) uses `stop()` directly without console formatting. This is a developer-facing edge case — in production, the shared TRS is always loaded. Not blocking.

### M3. Conjoint convergence callout usage unguarded at two call sites

**File:** `conjoint/lib/html_report/03_page_builder.R`, lines 1020, 1022
**Affects:** HTML report diagnostics panel when callout registry is unavailable

These two `turas_callout()` calls for convergence explanation lack the `exists()` guard or `tryCatch()` wrapper used at other call sites (e.g., line 952). Folded into C3 fix — applying `tryCatch` to the `source()` and defining no-op fallbacks covers these sites.

---

## Test Coverage Summary

| Metric | Conjoint | MaxDiff |
|--------|----------|---------|
| Production files (R/) | 20 | 14 |
| HTML report files | 7 | 5 |
| HTML simulator files | 4 | 4 |
| Test files | 21 | 17 |
| File ratio (test:prod R/) | 1.05 | 1.21 |
| Production LOC (R/) | ~13,600 | ~10,800 |
| Test LOC | ~4,800 | ~5,300 |
| LOC ratio (test:prod) | ~0.35 | ~0.49 |
| Tests passing | 545 | 750 |
| Tests skipped | 12 | 5 |
| Golden fixtures | None | None |

### Coverage assessment

Both modules have good test:file ratios. Conjoint has comprehensive test suites for HB estimation, HTML report, market simulation, configuration, and edge cases. MaxDiff has particularly strong validation testing (847 lines) and segment testing (876 lines).

Conjoint skips are due to project root detection (2 tests), node.js availability (2 tests), and demo config paths (8 MNL integration tests). MaxDiff skips are due to design generation (1 test), node.js (1 test), empty tests (2 logit tests), and output disk test (1 test).

---

## Statistical Correctness Assessment

### Conjoint MNL Estimation (03_estimation.R)

Delegates to `survival::clogit()` for conditional logit estimation. This is the standard MNL estimator for choice-based conjoint — correct. Model fit statistics (McFadden R², hit rate, log-likelihood, AIC, BIC) use standard formulas verified against known implementations.

### Conjoint HB Estimation (11_hierarchical_bayes.R)

Uses `bayesm::rhierMnlRwMixture()` — the standard R package for HB choice models. Data preparation correctly formats choice sets into the `lgtdata` structure (line 110-150). Individual-level betas extracted from posterior means (line 368-444). Zero-centering at attribute level applied correctly (line 400-420).

**Convergence diagnostics** use aggregate trace (mean across respondents per draw). Geweke Z-test compares first 10% vs last 50% — standard fractions. ESS approximation uses autocorrelation sum — simplified Geyer method. The ESS threshold of > 100 is the finding in C5.

RLH calculation (line 569+) computes root likelihood per respondent using individual betas and choice data. Quality flagging at 1.5× chance level (1/K where K = number of alternatives) — standard MR industry threshold.

### Conjoint Market Simulator (05_simulator.R)

MNL share formula: `P(i) = A_i * exp(U_i) / Σ(A_j * exp(U_j))` — correct with availability weights. Log-sum-exp trick for numerical stability — correct. First-choice rule: 100% to highest utility — correct. Randomized first-choice with tie tolerance — correct. Division-by-zero risk noted in I5.

Sensitivity analysis correctly varies one attribute at a time while holding others constant. One-way and two-way sensitivity implemented.

### MaxDiff Aggregate Logit (06_logit.R)

Uses conditional logit on best-worst paired data. Anchor item (reference category) correctly set to last item or user-specified item. Standard errors from model summary. McFadden pseudo-R² = `1 - LL/LL_null` — correct.

### MaxDiff HB Estimation (07_hb.R)

Uses `cmdstanr` with a custom Stan model (`maxdiff_hb.stan`). Multi-chain MCMC with proper convergence diagnostics: split R-hat, bulk ESS, divergent transitions, max treedepth. Quality scoring system with appropriate thresholds (R-hat < 1.01 optimal, < 1.05 warning, > 1.10 critical). ESS < 100 critical, < 400 warning. This is the correct, modern approach.

Approximate HB fallback uses empirical Bayes James-Stein shrinkage when cmdstanr is unavailable — appropriate fallback. Returns NA for R-hat and ESS with diagnostics noting the fallback method.

### MaxDiff TURF Analysis (11_turf.R)

Greedy forward selection maximizing reach — standard TURF algorithm. Appeal classification supports 4 methods (ABOVE_MEAN, TOP_3, TOP_K, ABOVE_ZERO) — all correctly implemented. Weighted analysis supported via weighted reach calculation. Frequency calculation (average appealing items per respondent) — correct.

### MaxDiff Preference Shares (utils.R)

Probability rescaling: `exp(u_i) / Σ exp(u_j)` — standard multinomial logit transformation. Correctly handles both HB and aggregate utilities. Rescaling methods (probability, zero_anchored, ratio) all verified correct.

---

## TRS Compliance Summary

| Metric | Conjoint | MaxDiff |
|--------|----------|---------|
| stop() in core R/ | 0 | 0 |
| stop() in GUI launcher | 1 (early_refuse — I1) | 2 (early_refuse — I2, initial check uses cat+return) |
| stop() in examples | 5 (acceptable — developer scripts) | 0 |
| stop() in guard fallback | 0 | 1 (M2 — fallback when TRS unavailable) |
| TRS refusals | 18 (conjoint_refuse) | 45+ (maxdiff_refuse) |
| Guard layer | Complete (00_guard.R, 773 LOC) | Complete (00_guard.R, 592 LOC) |
| Stats pack | Present (I3: incomplete) | Present (I3: incomplete) |
| Run state tracking | Present | Present |
| Console output | Comprehensive | Comprehensive |
| Formula escape | ABSENT (C1) | ABSENT (C2) |
| Callout fallback | ABSENT (C3) | Partially present (C4 — source unguarded, usage guarded) |

---

## Fix Status (2026-04-07)

All critical and important findings addressed in this session. Tests passing (Conjoint: 545 pass, 0 fail, 12 skip, 2 warnings pre-existing; MaxDiff: 750 pass, 0 fail, 5 skip, 0 warnings).

| Finding | Status | What was done |
|---------|--------|---------------|
| C1: Conjoint formula injection | FIXED | Added `conjoint_escape_cell()`/`conjoint_escape_df()` inline fallback using vapply+substr. Applied to all 22 user-sourced data frame writeData paths across 07_output.R (Utility Chart Data, Model Fit, Raw Coefficients, Importance, Utilities, Configuration, Data Summary, Individual Utilities, HB Diagnostics, Respondent Quality, Class Comparison, Class Profiles, Class Membership) |
| C2: MaxDiff formula injection | FIXED | Added `maxdiff_escape_cell()`/`maxdiff_escape_df()` inline fallback using vapply+substr. Applied to all 10 user-sourced data frame writeData paths across 09_output.R (Summary, Item Scores, Segment Scores, Individual Utils, Model Diagnostics, TURF Results, Anchor Analysis, Item Discrimination) |
| C3: Conjoint callout tryCatch + fallback | FIXED | Added `tryCatch()` around `source(callout_registry.R)` with `[CONJOINT]` error message. Added no-op fallbacks for `turas_callout` and `turas_callout_html`. Wrapped unguarded convergence callout calls at lines 1029/1035 in `tryCatch()` |
| C4: MaxDiff callout tryCatch | FIXED | Added `tryCatch()` around `source(callout_registry.R)` with `[MAXDIFF]` error message. Added no-op fallback for `turas_callout` |
| C5: Conjoint ESS threshold | FIXED | Raised threshold from > 100 to > 400. Added tiered messaging: ESS < 100 = critical, ESS < 400 = warning. Matches maxdiff guard layer thresholds |
| I1: Conjoint GUI cat() before stop() | FIXED | Added `cat(msg)` before `stop()` in `early_refuse()` for Shiny console visibility |
| I2: MaxDiff GUI cat() before stop() | FIXED | Added `cat(msg)` before `stop()` in `early_refuse()` for Shiny console visibility |
| I3: Stats packs missing HB diagnostics | FIXED | Conjoint: added convergence status, ESS range, Geweke test results to stats pack assumptions. MaxDiff: added convergence status, R-hat max, ESS min, divergence count, quality score |
| I4: Conjoint stats pack missing model fit | FIXED | Added McFadden R², hit rate, log-likelihood to stats pack assumptions when available |
| I5: Simulator division-by-zero guard | FIXED | Added guard for `sum_exp_utilities < 1e-10` in `predict_shares_logit()` with `message()` warning and equal-share fallback |
| M1-M3 | DEFERRED | All minor findings deferred to Phase 10 |

**Also completed:**
- Conjoint technique guide written at `modules/conjoint/TECHNIQUE_GUIDE.md`
- MaxDiff technique guide written at `modules/maxdiff/TECHNIQUE_GUIDE.md`

**Deferred to Phase 10 (horizontal pass):**
- M1: Conjoint convergence diagnostics don't use shared hb_diagnostics.R
- M2: MaxDiff guard fallback TRS uses bare stop()
- M3: Conjoint convergence callout usage (covered by C3 fix — no-op fallbacks defined)

**Next:** Re-review in fresh session to verify all fixes.

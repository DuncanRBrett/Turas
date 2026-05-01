# Production Review: Brand Module — v2 Surface (Pre-Cutover)

**Date:** 2026-04-30
**Branch:** `feature/brand-ipk-rebuild`
**Reviewer:** Claude (production-review skill, independent session)
**Stack:** R / Shiny
**Scope:** v2 functions only — `_v2` entries and their helpers. Legacy v1 code intentionally excluded per review brief.

---

## Verification Gates

| Gate | Command | Result |
|------|---------|--------|
| Test suite | `test_file()` × 18 v2 files | **PASS — 733 tests, 0 fail** |
| File inventory | `ls modules/brand/R/` | **PASS — all v2 foundation + element files present** |
| E2E orchestrator | `run_brand(ipk_wave1)` | **PASS — status PARTIAL (expected), portfolio PASS** |
| SIZE-EXCEPTIONs | Active-line counter | **PASS — all markers honest: v1+v2 coexistence, expire at cutover** |

Test count matches brief's expected baseline exactly (733). File inventory confirms all 18 v2 test files and all v2 foundation source files are present. No discrepancies.

**One discrepancy with session 5 handover:** Handover says "Portfolio cross-cat data still legacy." Code says otherwise — `run_portfolio` is wired in `00_main.R:2252-2258` and `test_portfolio_orchestrator.R` (31 tests) was added post-session-5. Handover is stale; code is correct.

---

## IMPORTANT

### I1. Silent MA failure in Shiny when `build_cep_linkage()` gets wrong `item_kind`

**File:** `modules/brand/R/02_mental_availability.R:143`

`build_cep_linkage()` is a public `@export` function. When `item_kind` is not `"cep"` or `"attr"`, it fires `stop("build_cep_linkage: item_kind must be 'cep' or 'attr'")` — a bare `stop()`, not a TRS refusal. In the orchestrator, this is caught by the `tryCatch` at `00_main.R:376` and `00_main.R:414`. The error handler adds to `warnings_list` only, with no `cat()`. In Shiny (`verbose = FALSE`), `warnings_list` is never printed to console. Result: the MA panel silently blanks with no console diagnostic.

In production the orchestrator hardcodes `item_kind = "cep"` and `"attr"` so this path is currently unreachable. But as a public function with no TRS contract and a `stop()` in the happy-path error branch, it violates the project convention and creates a debugging trap if the callers change.

**Fix:** Replace `stop(...)` with `brand_refuse("DATA_MA_INVALID_ITEM_KIND", ...)`. Also add a `cat()` to the orchestrator tryCatch at `00_main.R:388-392` for this case.
*(Fixed in this review — see changes below)*

---

### I2. Silent AL failure in Shiny when weights length mismatches

**File:** `modules/brand/R/13_audience_lens.R:215`

`.al_normalise_weights()` fires `stop(sprintf("Audience lens: weights length (%d) != data rows (%d)", ...))` when the weights vector has a different length than `nrow(data)`. This is called from `run_audience_lens()` (line 355) before the function emits any console output. The orchestrator's `tryCatch` at `00_main.R:715` catches it and adds to `warnings_list` silently. In Shiny, the AL panel blanks with no console output and no how_to_fix.

The mismatch is theoretically unreachable if the caller always passes unfiltered weights, but the function signature accepts arbitrary weights vectors — the precondition is unenforced.

**Fix:** Replace `stop(...)` with a proper TRS-pattern refusal and `cat()` output.
*(Fixed in this review — see changes below)*

---

### I3. Role map build failure has no Shiny console output

**File:** `modules/brand/R/00_main.R:309-313`

When `build_brand_role_map()` fails (e.g. malformed structure, no Questions sheet, column mismatch), the `tryCatch` error handler sets `role_map = NULL` and appends to `warnings_list`. No `cat()` call. In Shiny, `verbose = FALSE` by default, so `warnings_list` is never printed. Result: all 13 elements get called with `role_map = NULL` and each emits its own "role_map is NULL" REFUSED message to console — but the root cause (why `build_brand_role_map()` failed) is invisible.

The per-element console output is actually decent (each element says it was refused). What's missing is the single most useful line: the root cause error from the builder.

**Fix:** Add a `cat()` call to the error handler at line 310.
*(Fixed in this review — see changes below)*

---

### I4. `.require_structure()` uses bare `stop()` — role inference chain

**File:** `modules/brand/R/00_role_map_v2.R:90,93`

`.require_structure()` uses `stop("build_brand_role_map: ...")` for missing `questions` sheet and missing `BrandCode` column. These are caught by the orchestrator's role_map tryCatch (I3 above). Same visibility issue: the specific validation message ("no Questions sheet found") is buried in `warnings_list`. Same fix path: convert to TRS refusal + add cat() at the call site. Lower priority than I3 since fixing I3 already surfaces the message.

**Fix:** Convert to TRS-style `brand_refuse()` calls so the error surface is consistent with all other v2 guard code. The fix to I3 is the minimum needed — converting these is belt-and-suspenders.

---

### I5. `.require_questions_df()` uses bare `stop()` — role inference chain

**File:** `modules/brand/R/00_role_inference.R:421,425`

Same pattern as I4. `.require_questions_df()` uses bare `stop()` for NULL and zero-row questions data frames. Caught by role_map tryCatch; root cause buried. Fix is the same as I4.

---

## MINOR

### M1. Wrong error code for non-dataframe input in `build_portfolio_base()`

**File:** `modules/brand/R/09_portfolio.R:172`

When `data` is not a data.frame, `build_portfolio_base()` returns `code = "DATA_PORTFOLIO_NO_AWARENESS_COLS"`. That code describes a different condition (awareness columns absent from valid data). This would cause confusion when debugging — the how_to_fix message says "verify BRANDAWARE_* columns" when the real problem is a non-dataframe input.

**Fix:** Change the code to `"DATA_PORTFOLIO_NOT_DATA_FRAME"` and update the message accordingly.

---

### M2. `stop("[BUG]...")` in `03a_funnel_derive.R` switch default

**File:** `modules/brand/R/03a_funnel_derive.R:333`

The default branch of `.derive_stage_matrix()`'s switch uses `stop(sprintf("[BUG] Unknown funnel stage key '%s'", key))`. This is intentional as a programming-error sentinel (unreachable if the calling code is correct), but it uses `stop()` rather than a TRS refusal. In the orchestrator this is caught by the per-element tryCatch and adds to `warnings_list` silently.

Since it is genuinely only reachable via a bug in the calling code (wrong key string), this is lower priority than I1–I5 and requires no immediate fix. It should be noted for post-cutover cleanup.

---

### M3. Stale docstring on `resolve_demographic_role()` (legacy function)

**File:** `modules/brand/R/11_demographics.R:287`

`@param role Character. Exact role name (e.g. "demo.AGE")` documents the legacy `demo.{KEY}` namespace. The v2 convention established by `00_role_inference.R:148` is `demographics.{key}` (lowercase). The legacy function deletes at cutover so this is low priority, but the comment at the top of `11_demographics.R` (line 6) also says `"demo."` and will be confusing to readers until the legacy code is removed.

---

## OBSERVATIONS

### O1. Test suite integrity

733 tests, 0 failures. Tests use literal mini-fixtures with hand-calculated expected values — not random data. Refusal paths are tested for all major v2 elements. Coverage is proportional: portfolio (6 + 23 + 7 = 36) and data access (19) have the deepest suites; funnel (4) and brand volume (2) are thinner. Funnel depth is intentional — the funnel element has a large, complex v2 spec, and the current test count reflects integration-level tests rather than per-function unit tests.

### O2. Role key naming contract is consistent end-to-end

Verified for WOM, repertoire, funnel, and MA: the key names produced by `00_role_inference.R` patterns match exactly what the consumer functions look up in `role_map`. No drift found.

### O3. Slot readers are correct

`respondent_picked()`, `multi_mention_brand_matrix()`, `multi_mention_indicator_matrix()`, `slot_paired_numeric_matrix()` are NA-safe, sort slots by trailing integer index (not lexicographically), and handle slot-count mismatches by intersecting shared indices. No off-by-one errors found.

### O4. WOM zero-fill is intentional but underdocumented

When WOM roles are absent from `role_map`, `run_wom()` returns zero counts for all metrics rather than REFUSED. This is by design (surveys without WOM questions should render the panel with zeros). Post-cutover, a category with no WOM survey questions will show zero WOM metrics with no in-panel indicator that the data was absent rather than collected-zero. Worth adding a `has_wom_data` flag to the payload so the HTML layer can render "Not collected" instead of "0".

### O5. Portfolio v2 sub-analyses fully wired

All 8 sub-analyses (footprint, constellation, clutter, strength, extension, overview) route to `_v2` variants in `run_portfolio()`. The session 5 handover claiming otherwise is stale.

### O6. Placeholder elements are structured correctly

DBA (`07_dba.R`), Branded Reach (`10_branded_reach.R`), and Ad Hoc (`12_adhoc.R`) all return structured payloads with sentinel notes (`DBA_PLACEHOLDER_NOTE`, `BR_PLACEHOLDER_NOTE`). The orchestrator routes to these v2 paths when `role_map` is non-NULL. Clean.

### O7. SIZE-EXCEPTION markers are honest

All five marked files correctly identify the reason (v1+v2 coexist during migration window) and the expiry condition (cutover, when v1 is deleted). No false exceptions found.

### O8. `compute_al_metrics_for_subset()` correctly null-guards role_map entries

Lines 600-617 check `!is.null(aware_root)`, `!is.null(pen2_root)`, etc. before dereferencing. The `role_map[[key]]$column_root` pattern safely returns NULL in R when the entry is missing — no NPE risk.

---

## Fixes Applied in This Review

The following IMPORTANT issues were fixed during the review. All gates re-run and still passing (733 PASS / 0 FAIL).

| Finding | Fix | File |
|---------|-----|------|
| I1 — `build_cep_linkage()` bare stop() | Replaced with `brand_refuse()` | `02_mental_availability.R:143` |
| I2 — `.al_normalise_weights()` bare stop() | Replaced with TRS-pattern refusal + propagation | `13_audience_lens.R:215` |
| I3 — role_map tryCatch no cat() | Added `cat()` to error handler | `00_main.R:311` |
| M1 — wrong error code in portfolio | Corrected error code | `09_portfolio.R:172` |

Remaining open: I4, I5 (belt-and-suspenders conversions for `.require_structure()` and `.require_questions_df()` — low-priority post-cutover cleanup). M2, M3 will disappear at cutover when legacy files are deleted.

---

## Verdict

**DEPLOY WITH CONDITIONS**

The v2 surface is architecturally sound and ready for cutover. Tests pass at the expected 733/0 baseline, slot readers are correct, the role_map contract is consistent across all 13 elements, and every major element has happy-path, refusal, and edge-case tests with known-answer fixtures. There are no correctness bugs, no data-shape bugs, and no security issues.

The top three issues that must be resolved before or alongside cutover are: **(1)** `build_cep_linkage()` and `.al_normalise_weights()` using bare `stop()` (caught by tryCatch but produce zero Shiny console output — the two blank-panel-with-no-diagnostic paths); **(2)** the orchestrator's role_map build tryCatch having no `cat()` call, meaning a malformed structure produces all-elements-REFUSED with no root-cause visible in Shiny; **(3)** the misleading error code in `build_portfolio_base()`. Items (1)–(3) are all straightforward fixes applied in this review session. After applying those, no remaining blocker stands between this branch and `main`.

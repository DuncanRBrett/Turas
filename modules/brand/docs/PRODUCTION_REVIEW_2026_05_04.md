# Production Review: Brand Module

**Date:** 2026-05-04
**Branch/Version:** `fix/brand-cold-review-fixes`
**Reviewer:** Claude (production-review skill) — independent cold review
**Language/Stack:** R / Shiny, testthat, openxlsx

---

## Verification Gates

| Gate | Command | Result |
|------|---------|--------|
| Tests | `testthat::test_dir("modules/brand/tests/testthat")` | PASS — 1651 pass, 0 fail, 2 skip (both expected) |
| Test count | `grep -rn "^test_that" … \| wc -l` | 447 test_that blocks across 43 test files |
| TRS compliance | `grep -rn "stop(" R/*.R` | See I1 — all stop() calls are fallback-only |
| Hardcoded paths | `grep -rn '"/Users/' R/*.R` | PASS — zero absolute paths |
| library() in functions | `grep -n "^library(" R/*.R` | PASS — zero |
| TODO/FIXME/HACK markers | `grep -rn "TODO\|FIXME\|HACK" R/*.R` | PASS — zero |
| Module loader whitelist | diff R/*.R vs whitelist | PASS — all 51 R/ files registered |
| Lint (lintr) | N/A | lintr not in renv — cannot run |

---

## CRITICAL

None.

---

## IMPORTANT

### I1. `AUDIENCE_LENS_SPEC_v1.md` — stale file paths throughout (Fixed in this review)

**Files:** `modules/brand/docs/AUDIENCE_LENS_SPEC_v1.md:5–9, 59, 182`

The spec was written when the Audience Lens files were numbered `11_*`. After the IPK rebuild renumbered them to `13_*`, the spec was not updated. Every source file reference pointed to non-existent paths. Additionally, the default value for `element_audience_lens` was documented as `Y` when the code (`01_config.R:120`) explicitly puts it in the `default_off` list (actual default: `N`). A developer following this spec to locate or configure the feature would find nothing at the stated paths and would unknowingly expect the feature to be on by default.

**Fix applied:** Updated all six file path references (`R/11_*` → `R/13_*`; panel path corrected; planning doc path corrected to `docs/PLANNING_AUDIENCE_LENS.md`). Corrected default from `Y` to `N` with explanatory note. Updated inline module-numbering reference from `(11, 11a–11d)` to `(13, 13a–13d)`.

---

### I2. `BRAND_CONFIG_GUIDE.md` — four shipped elements missing from operator elements table (Fixed in this review)

**File:** `modules/brand/docs/BRAND_CONFIG_GUIDE.md:118–128`

The elements table listed 8 of the 12 configured elements. Four elements that have been shipped and are toggleable in `Brand_Config.xlsx` were absent:
- `element_branded_reach` (default N — Branded Reach panel)
- `element_demographics` (default Y — Demographics panel)
- `element_adhoc` (default Y — Ad Hoc panel)
- `element_audience_lens` (default N — Audience Lens panel)

An operator reading this guide would not know these toggles exist, could not disable Demographics or Ad Hoc, and could not discover Branded Reach or Audience Lens as options.

**Fix applied:** Added all four rows with correct defaults and one-line descriptions. Verified against `01_config.R:112–121`.

---

### I3. `BRAND_REPORT_USER_GUIDE.md` — four category subtabs undocumented

**File:** `modules/brand/docs/BRAND_REPORT_USER_GUIDE.md`

The user guide documents Subtabs 1–4 (Funnel, Mental Availability, WOM, Category Buying) but omits the four subtabs added since initial publication: Branded Reach, Demographics, Ad Hoc, and Audience Lens. An end user or client receiving a report with these tabs visible has no user-guide reference for what they show or how to interact with them.

**Fix:** Write a brief section for each missing subtab following the existing Subtab N pattern: what it shows, how to read it, key interactions. Estimated effort: 1–2 hours. Not applied in this review because it requires human writing judgment on client-facing language.

---

## MINOR

### M1. Bare `stop()` in internal helpers — fallback-only, near-zero production risk

**Files:**
- `R/00_guard.R:77` — fallback when `turas_refuse()` not loaded
- `R/00_guard_role_map.R:271` — same pattern
- `R/03a_funnel_derive.R:341` — `brand_refuse()` tried first; `stop()` fallback
- `R/02b_mental_advantage.R:64,66` — internal `.ma_count_matrix()`; always called via `.ma_safe_advantage()` tryCatch wrapper
- `R/00_data_access.R:344` — same TRS-not-loaded fallback

None of these fire in normal production usage: the shared TRS library is loaded before any analysis runs, and `.ma_count_matrix` is only ever called via a tryCatch wrapper. The risk is only if the module is sourced in complete isolation from the shared library — which is not the production path.

**Observation:** The fallback pattern (`if (exists("brand_refuse")) ... else stop()`) is reasonable defensive coding. No immediate fix required, but worth noting that `.ma_count_matrix:64,66` are the only two bare stops that are not wrapped in the exists-guard idiom — they rely on the caller's tryCatch instead.

---

### M2. Four large functions missing `SIZE-EXCEPTION` comments

**Files:**
- `R/04_repertoire.R` — `run_repertoire()` 368 lines
- `R/01_config.R` — `load_brand_config()` 250 lines
- `R/07_dba.R` — `.run_dba_core()` 176 lines
- `R/08_cat_buying.R` — `run_cat_buying_frequency()` 156 lines

CLAUDE.md requires a `SIZE-EXCEPTION` comment explaining why a function exceeds 100 lines. `run_brand()` and `run_mental_availability()` both have these comments. The four above do not. Functions are structurally sound and splitting them would fragment sequential pipelines, but the absence of the comment means the next contributor doesn't know whether the size is intentional.

**Fix:** Add a `# SIZE-EXCEPTION: <reason>` comment above each function definition. One line each.

---

### M3. `%||%` null-coalescing operator defined in multiple files

The `%||%` operator is defined locally in at least four brand R files (`10_branded_reach.R:157`, `13b_al_metrics.R:490`, `05a_wom_panel_data.R:23`, `03c_funnel_panel_data.R:598`) in addition to its shared definitions in `modules/shared/lib/`. This works reliably because the module loader sources shared before brand, but it creates drift risk: the shared definition treats `length(x) == 0` as null-like, while a future local definition might differ.

**Fix:** Remove the local definitions and rely on the shared version (already guaranteed to be loaded by `00_guard.R` before any of these files run). Low priority — no functional risk today.

---

## OBSERVATIONS

### O1. Two test skips are correct and well-documented

`test_dirichlet_norms.R:268` skips when `NBDdirichlet` is installed (can't test the missing-package path without uninstalling it). `test_integration.R:342` skips on CRAN. Both skip messages explain why. No action needed.

### O2. `test_funnel.R` comment about "legacy tests scheduled for deletion" is misleading

The comment at the top of `test_funnel.R` says the legacy column-per-brand tests "remain in place but fail against the migrated code; they are scheduled for deletion." In fact, `test_funnel_transactional.R` and the other funnel test files have been fully ported to the v2 slot-indexed format and all pass. The comment describes a historical transition that is now complete — it should be removed to avoid confusing the next reader.

**Fix:** Delete or replace the stale comment block at `test_funnel.R:6–10`.

### O3. `generate_config_templates.R` loaded by module whitelist

This file is in the `R/` directory and registered in the module loader, meaning it is sourced (and its functions defined) every time `run_brand()` is called — not just when generating templates. This is by design (the templates are accessible from a running Shiny session), but it means a 1452-line config template generator is always in memory. No correctness issue; worth knowing if memory footprint ever becomes a concern.

### O4. `run_brand()` at 835 lines has an explicit SIZE-EXCEPTION

The main orchestration function is large but has a documented `SIZE-EXCEPTION` comment explaining it is a sequential pipeline that cannot be decomposed without fragmenting the flow. This is the right pattern. The existing exception comment accurately describes the architecture.

---

## Summary of fixes applied in this review

| # | File | Change |
|---|------|--------|
| I1a | `docs/AUDIENCE_LENS_SPEC_v1.md:5–8` | Corrected all six source file paths from `11_*` to `13_*` |
| I1b | `docs/AUDIENCE_LENS_SPEC_v1.md:9` | Corrected planning doc path to `docs/PLANNING_AUDIENCE_LENS.md` |
| I1c | `docs/AUDIENCE_LENS_SPEC_v1.md:59` | Corrected `element_audience_lens` default from `Y` to `N` |
| I1d | `docs/AUDIENCE_LENS_SPEC_v1.md:182` | Corrected module number reference from `11, 11a–11d` to `13, 13a–13d` |
| I2 | `docs/BRAND_CONFIG_GUIDE.md:128` | Added 4 missing element rows to operator elements table |

---

## Verdict

**DEPLOY WITH CONDITIONS**

The code itself is production-ready: 1651 tests pass, zero CRITICAL findings, TRS compliance is sound, no hardcoded paths, no silent failures in production paths, and the analytical engines have strong known-answer test coverage. The two IMPORTANT findings were both documentation-only and have been fixed in this review. One IMPORTANT finding remains open (I3: user guide missing four subtab descriptions) but does not block deployment — it is a user experience gap, not a correctness or safety issue. Before the next client presentation, I3 should be addressed.

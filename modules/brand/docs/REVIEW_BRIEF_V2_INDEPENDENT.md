# Independent Production Review — Brand IPK Rebuild (v2 surface)

**You are reviewing cold and independently.** A previous Claude session built this work. Don't assume that work is correct. Verify everything against the current code, the current tests, and your own judgment. If a claim in this brief contradicts what you find on disk, trust the disk.

Use the `anthropic-skills:duncan-production-review` skill for the standards bar. This is a brand module rebuild on the `feature/brand-ipk-rebuild` branch (31 commits ahead of `main`).

---

## What this rebuild does

The brand module's data plumbing is moving from a column-per-brand legacy shape (`BRANDAWARE_DSS_IPK = 1`) to slot-indexed parser-shape data (`BRANDAWARE_DSS_1` cells holding brand codes like `"IPK"`). It introduces a **role registry** (`role_map`) built once at orchestrator entry and threaded through every per-category element. All 13 brand elements have v2 entries; all 11 orchestrator call sites route to v2 when `role_map` is non-NULL.

The rebuild is **pre-cutover**. Both v1 (legacy) and v2 (new) code currently coexist in the same files behind `if (!is.null(role_map))` route-or-fallback branches. The cutover step (planning doc §9 step 5) deletes all v1, drops the fallbacks, and renames `_v2` → canonical.

You are asked to assess whether the v2 surface is production-ready **as if cutover had already happened**.

---

## Read these first (5 min)

- `modules/brand/docs/PLANNING_IPK_REBUILD.md` — governing planning doc
- `modules/brand/docs/HANDOVER_IPK_REBUILD_SESSION5.md` — current state, gotchas, what's pending
- `CLAUDE.md` (repo root) — project conventions, TRS pattern, Shiny error rules
- Verify the v2 file inventory below by running `ls modules/brand/R/`

---

## v2 surface to review

### Foundation
- `modules/brand/R/00_data_access.R` — slot readers (`respondent_picked`, `multi_mention_brand_matrix`, `multi_mention_indicator_matrix`, `slot_paired_numeric_matrix`, `single_response_brand_*`)
- `modules/brand/R/00_role_inference.R` — convention-first role inference (`DEMO_*` patterns, `cat_buying.*` namespace, etc.)
- `modules/brand/R/00_role_map_v2.R` — `build_brand_role_map()`
- `modules/brand/R/00_guard_v2.R` — v2 guard layer

### Element entries (review only the `_v2` functions and helpers prefixed `_v2`)
- `02_mental_availability.R` — `build_cep_linkage_v2`, `.ma_resolve_cep_labels`
- `03_funnel.R` — `run_funnel` v2 path (the legacy `funnel_cfg$cat_code` threading) plus `03a_funnel_derive.R`, `03b_funnel_metrics.R`, `03c_funnel_panel_data.R`, `03d_funnel_output.R`. **Skip `03e_funnel_legacy_adapter.R` — it deletes at cutover.**
- `04_repertoire.R` — `run_repertoire_v2`
- `05_wom.R` — `run_wom_v2`, plus `05a_wom_panel_data.R`
- `06_drivers_barriers.R` — `run_drivers_barriers_v2`
- `07_dba.R` — `run_dba_v2` (placeholder element — verify the empty-payload contract is structured)
- `09_portfolio.R` — `build_portfolio_base_v2`, `.portfolio_aware_root_v2`, `.portfolio_aware_matrix_v2`, `run_portfolio_v2`, `.compute_supporting_metrics_v2`
- `09a_portfolio_footprint.R` — `compute_footprint_matrix_v2`, `.compute_brand_awareness_pct_v2`
- `09b_portfolio_constellation.R` — `compute_constellation_v2`, `compute_constellations_per_cat_v2`
- `09c_portfolio_clutter.R` — `compute_clutter_data_v2`, `.compute_clutter_metrics_v2`
- `09d_portfolio_strength.R` — `compute_strength_map_v2`
- `09e_portfolio_extension.R` — `compute_extension_table_v2`, `compute_extension_per_brand_v2`
- `09h_portfolio_overview_data.R` — `compute_portfolio_overview_data_v2`
- `10_branded_reach.R` — `run_branded_reach_v2` (placeholder — verify contract)
- `11_demographics.R` — `demographic_question_from_role_v2`
- `12_adhoc.R` — `run_adhoc_v2`, `resolve_adhoc_role_v2` (placeholder)
- `13_audience_lens.R` — `run_audience_lens_v2`
- `13b_al_metrics.R` — v2 KPI entries

### Orchestrator (`modules/brand/R/00_main.R`)
- Step 3b — role_map build (~line 296–313)
- Step 4 — per-category dispatcher (the `if (!is.null(role_map)) run_X_v2(...) else .legacy_X_call(...)` branches). **Review the v2 branch only.**
- Step 5a — `.compute_portfolio_data` route (~line 858), `.compute_portfolio_data` body (~line 2240)
- Step 5b — `compute_portfolio_overview_data_v2` route (~line 868)
- Loader whitelist `.source_brand_module module_files` (~line 54–103)

### Tests (the v2 suite)
```
test_data_access, test_role_map_v2, test_guard_v2, test_funnel_v2,
test_brand_volume_v2, test_mental_avail_v2, test_ma_advantage_v2,
test_wom_v2, test_repertoire_v2, test_drivers_barriers_v2,
test_demographics_v2, test_portfolio_v2, test_portfolio_subanalyses_v2,
test_portfolio_orchestrator_v2, test_audience_lens_v2, test_dba_v2,
test_branded_reach_v2, test_adhoc_v2
```
Expected baseline: **733 PASS / 0 FAIL** when run together. Verify.

---

## What to IGNORE

These are scheduled for deletion at cutover (planning doc §9 step 5). Don't flag them:

1. **Legacy v1 entries inside migrated element files.** Notable bulk to ignore:
   - `run_portfolio` and `.compute_supporting_metrics` in `09_portfolio.R`
   - `run_audience_lens` + `compute_al_metrics_for_subset` + private legacy helpers in `13_audience_lens.R` (~452 lines), `13b_al_metrics.R` (~914 lines)
   - `build_cep_linkage_from_matrix` in `02_mental_availability.R`
   - All `compute_*` (non-`_v2`) inside 09a–09h
2. **Legacy fallback helpers in `00_main.R`:** `.legacy_wom_call`, `.legacy_repertoire_call`, `.legacy_drivers_barriers_call`, `.run_funnel_for_category`, `.normalize_questionmap_for_category`, `.detect_category_code`, `.strip_cat_suffix_from_qmap`, `.run_demographics_for_category`, `.demo_question_from_role`, `.run_adhoc_for_category`, `resolve_adhoc_role`, `.run_adhoc_brand_level`.
3. **Legacy files marked for deletion:** `00_role_map.R`, `00_guard_role_map.R`, `03e_funnel_legacy_adapter.R`, all legacy element tests (`test_audience_lens.R`, `test_audience_lens_audiences.R`, `test_audience_lens_metrics.R`, `test_audience_lens_classifier.R`, `test_audience_lens_panel_data.R`, plus per-element legacy tests listed in `HANDOVER_IPK_REBUILD_SESSION3.md`).
4. **Route-or-fallback branches.** `if (!is.null(role_map)) run_X_v2(...) else run_X(...)` — review the v2 branch only; the fallback gets dropped at cutover.
5. **`SIZE-EXCEPTION` markers.** Files with these markers are scheduled to come back under 300 active lines once legacy v1 is deleted. Don't flag the size of files with valid SIZE-EXCEPTION markers; do verify the marker text itself is honest about why and when the exception expires.
6. **Legacy synthetic fixture:** `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` — scheduled for deletion. The new fixture is `modules/brand/tests/fixtures/ipk_wave1/`.

### Out of scope but worth noting

These three brand elements still use legacy slot-prefix readers and don't have v2 entries. They are intentionally not migrated (they happen to work on parser-shape data, don't read `role_map`, weren't blocked):
- Cat Buying frequency (`08_cat_buying.R`)
- Brand Volume (`08b_brand_volume.R`)
- Shopper behaviour (`08e_shopper_behaviour.R`)
- Dirichlet norms (`08c_dirichlet_norms.R`)
- Buyer heaviness (`08d_buyer_heaviness.R`)

Treat them as production code in their current form. **Do not recommend migrating them as part of this review** — that's a separate decision, post-cutover.

---

## Verification commands

```bash
# Full v2 suite — expect 733 PASS / 0 FAIL
Rscript -e 'library(testthat); for (f in c("test_data_access","test_role_map_v2","test_guard_v2","test_funnel_v2","test_brand_volume_v2","test_mental_avail_v2","test_ma_advantage_v2","test_wom_v2","test_repertoire_v2","test_drivers_barriers_v2","test_demographics_v2","test_portfolio_v2","test_portfolio_subanalyses_v2","test_portfolio_orchestrator_v2","test_audience_lens_v2","test_dba_v2","test_branded_reach_v2","test_adhoc_v2")) testthat::test_file(paste0("modules/brand/tests/testthat/", f, ".R"))'

# End-to-end orchestrator on IPK Wave 1 — expect status PARTIAL with portfolio$status PASS
Rscript -e 'source("modules/brand/R/00_main.R"); res <- run_brand("modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx", verbose = FALSE); cat("status:", res$status, "  portfolio:", res$results$portfolio$status, "  constellation:", res$results$portfolio$constellation$status %||% "NULL", "\n")'

# Active-line counter for SIZE-EXCEPTION verification
Rscript -e 'count <- function(f) { l <- readLines(f, warn=FALSE); t <- trimws(l); sum(!(t=="" | grepl("^#", t))) }; for (f in list.files("modules/brand/R", "\\.R$", full.names=TRUE)) cat(sprintf("%4d  %s\n", count(f), f))' | sort -n
```

---

## What we want from you

A prioritised punch list against the v2 surface only:

- **Critical** — correctness, silent failures, security, broken tests, data-shape bugs that propagate
- **Structural** — modularity, separation of concerns, API design, role_map contract drift
- **Quality** — naming, documentation, test coverage gaps

Be especially alert to:

1. **Silent failures.** Any `_v2` function that returns `NULL` on error rather than a structured TRS refusal (`status = "REFUSED"` + `code` + `message` + `how_to_fix`). The orchestrator runs in Shiny — silent NULLs surface as blank panels with no diagnostic.
2. **role_map contract drift.** Do all v2 entries agree on (a) which keys to look up, (b) what fallbacks to apply when a key is missing, (c) what to return when role_map itself is NULL or empty? `00_role_inference.R` is the source of truth for keys; `00_role_map_v2.R` is the builder. Cross-check the consumers.
3. **Slot-aware reader correctness.** `respondent_picked()`, `multi_mention_brand_matrix()`, `multi_mention_indicator_matrix()`, `slot_paired_numeric_matrix()` are the seam between data and every element. A bug here propagates everywhere. Look for off-by-one slot indexing, NA handling, weight handling, type coercion.
4. **Test coverage gaps.** Which v2 functions don't have happy-path / edge-case / refusal tests? Which use random data without a seed? Which assert types but not values?
5. **Hidden coupling to legacy.** Any v2 function that reads from a hardcoded legacy column name (e.g. `data$BRANDAWARE_DSS_IPK`) rather than going through the slot reader / role_map?
6. **The `if (!is.null(role_map))` fallback.** When the v1 fallback is dropped at cutover, will the v2 path still cope with the same edge cases the v1 path covered? (e.g. structure with no Questions sheet, corrupt fixture, missing CategoryCode column.)

When you're done, give a one-paragraph executive answer:

> **Is this v2 surface ready to merge to main after cutover, and if not, what are the top 1–3 blockers?**

Don't trust this brief. Verify file paths exist; verify test counts match; verify what's actually `_v2` versus not. Trust the code, not the document.

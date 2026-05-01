# Post-Cutover Handover — Brand Module IPK Rebuild

**Date opened:** 2026-05-01
**Branch state at session start:** assume the IPK rebuild PR is merged into `main`. If it isn't, the URL is https://github.com/DuncanRBrett/Turas/compare/main...feature/brand-ipk-rebuild — open it first.

The IPK rebuild is **complete**. All 13 brand elements migrated from column-per-brand to slot-indexed parser-shape data, all legacy v1 entries deleted, `_v2` renamed to canonical. 1288 brand tests pass. Browser-verified by Duncan on `launch_turas`.

This is the post-merge baseline. Three pieces of work follow, in priority order. Two are major features (Audience Lens v3, Demographics rework); one is a bounded test-port suitable for a Sonnet session running in parallel.

---

## What you're inheriting

### Data architecture (final state)

- **Slot-indexed parser-shape data is the canonical shape**: `BRANDAWARE_DSS_1..N` cells holding brand codes, paired numerics in `BRANDPEN3_DSS_1..N`, etc.
- **`role_map`** is built once at orchestrator entry by `build_brand_role_map(structure, brand_config, data)` in `00_role_map.R`. Threaded through every per-category element.
- **All 13 elements** + 8 portfolio sub-analyses use `role_map`-driven slot-aware reads via `00_data_access.R` helpers (`respondent_picked`, `multi_mention_brand_matrix`, `single_response_brand_matrix`, `slot_paired_numeric_matrix`, `multi_mention_indicator_matrix`).
- **Five elements** (Cat Buying / Brand Volume / Dirichlet / Buyer Heaviness / Shopper Behaviour) bypass `role_map` and read parser-shape data directly via shape-detector helpers — see "Carry-forwards" below.

### Verification

```bash
# Full brand suite
Rscript -e 'library(testthat); for (f in list.files("modules/brand/tests/testthat", "^test_.*[.]R$", full.names = TRUE)) testthat::test_file(f)'
# Expected: 1288 PASS / 0 FAIL  (the 8 funnel-legacy test files show 0/0
#   because they error at source time; tracked separately)

# End-to-end smoke
Rscript -e 'source("modules/brand/R/00_main.R"); res <- run_brand("modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx", verbose = FALSE); cat("status:", res$status, "  portfolio:", res$results$portfolio$status, "\n")'
# Expected: status: PARTIAL  portfolio: PASS
```

Browser verification is `launch_turas()` only — never use `preview_start` for brand reports (per memory rule `feedback_launch_turas_verification.md`).

---

## What's NEXT (priority order)

### 1. Audience Lens v3 — parallel tabs (next major feature)

**Branch:** `feature/audience-lens-v3-tabs` (cut from `main` after the rebuild merges).

**Why:** the current Audience Lens panel renders a single audience at a time, with a focal-audience picker. Duncan wants **multiple audience tabs in parallel** — the same shape as the per-category tabs across the report. The 14 KPIs need to be re-shaped into per-respondent stable columns so the tabs module can drive cross-tabs natively, then the panel renders one tab per defined audience.

**Scope:**
- Refactor `compute_al_metrics_for_subset` so each KPI is built as a per-respondent indicator column on the data frame (already partially done in `13b_al_metrics.R` — `.al_metric_pct_from_logical`, `.al_metric_pct_from_attitude` are the right shape; the MA / WOM / SCR / purchase blocks aren't yet).
- Push the audience cross-tab into the tabs module (which knows how to emit weighted percentages with significance against a base).
- Replace the panel's single-tab rendering with parallel-tab navigation matching the Demographics / Cat Buying tab shells.
- Verify: every audience defined in `audience_lens.audiences` Sheet renders its own tab, with the same 14 KPIs computed independently per audience.

**Pre-existing planning:** `modules/brand/PLANNING_AUDIENCE_LENS.md` (older 6-phase plan) plus the v1 handover at `project_brand_audience_lens_v1_handover.md` in memory. Both are pre-rebuild references — review with the new architecture in mind, don't follow them blindly.

**Estimated effort:** 1–2 days. Opus-level work — design judgement matters (tabs architecture, panel-data contract).

### 2. Demographics rework (after Audience Lens v3)

**Branch:** `feature/demographics-tabs` (cut after Audience Lens v3 merges).

**Why:** same architectural shift as Audience Lens v3 — Demographics currently renders a single matrix per category with synthetic Buyer Status / Heaviness rows. Duncan wants **parallel demographic tabs** so each demographic question (age, gender, region, income, etc.) becomes its own tab with the same brand-cut + significance + chart layout.

**Scope:** mirror the Audience Lens v3 approach — per-respondent indicator columns per demographic level, tabs-module-driven cross-tabs, parallel tab rendering.

**Pre-existing planning:** none formal yet. Build a plan once Audience Lens v3 is shipped (the pattern will inform demographics directly).

**Estimated effort:** 1 day if Audience Lens v3 establishes the pattern cleanly. Opus-level for the planning + first implementation, Sonnet-level for the rest if the pattern is mechanical.

### 3. Funnel test port (Sonnet — runs in parallel, doesn't block #1 or #2)

**Branch:** `feature/funnel-test-port`.

**Why:** 8 funnel-legacy test files (~250 assertions) error at source time post-cutover because they reference deleted artefacts and pin the pre-migration `run_funnel()` signature. The `test_funnel.R` v2 covers core derive + metrics + integration but not the category-type variants (durable / service / transactional with tenure thresholds), edge cases, output writers, panel data builder, or HTML renderer.

**Full handover:** [`HANDOVER_FUNNEL_TESTS_PORT.md`](HANDOVER_FUNNEL_TESTS_PORT.md). Self-contained, Sonnet-suitable, mechanical port against the established `test_funnel.R` template.

**Estimated effort:** 1 day for Sonnet. Independent — can run in a separate session while you do Audience Lens v3.

---

## Carry-forwards from the rebuild (not blocking #1 or #2)

### The 5 intentionally-non-migrated elements

These five elements never had a `_v2` sibling because their data layer **already worked** on slot-indexed parser-shape data via shape-auto-detection helpers:

| Element | File | Reads | How it reads |
|---|---|---|---|
| Cat Buying frequency | `08_cat_buying.R` | `BRANDPEN3_{cat}` slot frequencies | Slot-aware via `.find_brand_col` matching |
| Brand Volume | `08b_brand_volume.R` | Paired `BRANDPEN2_{cat}` + `BRANDPEN3_{cat}` slots | Auto-detects column shape; works on legacy column-per-brand AND slot-indexed |
| Dirichlet norms | `08c_dirichlet_norms.R` | Consumes `brand_volume` output | No data read |
| Buyer Heaviness | `08d_buyer_heaviness.R` | Consumes `brand_volume` output | No data read |
| Shopper Behaviour | `08e_shopper_behaviour.R` | `CHANNEL_{cat}_*` + `PACK_{cat}_*` slots | Slot-aware via `.run_shopper_for_category` helper |

They bypass `role_map` and use direct shape-detection. Not "wrong" — they work on production IPK data — but architecturally inconsistent with the other 13 elements. Future cleanup (low priority, no functional bug) would migrate them to `role_map`-driven access for consistency. Until then, treat as stable production code that doesn't need touching.

### Two `_v2` wrappers kept

- `run_repertoire_v2` in `04_repertoire.R` — engine `run_repertoire` takes a pre-computed penetration matrix and is also called direct from `00_main.R` after Brand_Volume completes (the second-pass-with-frequency call). Renaming the wrapper would collide with the engine.
- `run_drivers_barriers_v2` in `06_drivers_barriers.R` — engine `run_drivers_barriers` takes pre-computed `linkage + cep_mat + pen`. Same collision shape.

Future cleanup: rename engines to `compute_repertoire_metrics` / `compute_drivers_barriers_metrics` (or move them to private with a `.run_X_engine` convention), then rename the wrappers to `run_repertoire` / `run_drivers_barriers`. Out of scope for the rebuild — flag as a separate refactor when convenient.

### Other minor carry-forwards

- `03e_funnel_legacy_adapter.R` — kept despite "legacy" in the name. Bridges the v2 funnel engine to the wide-format HTML chart/table builders (`01_data_transformer.R`, `02_table_builder.R` still call `build_funnel_legacy_wide`). Goes when those builders move off the wide format.
- 6 SIZE-EXCEPTION markers still in `00_main.R`, `09b_portfolio_constellation.R`, `02_mental_availability.R`, `13b_al_metrics.R`, `03a_funnel_derive.R`, `02a_ma_panel_data.R`. Files are still genuinely over 300 active lines for legitimate sequential-orchestration / multi-format-output reasons. Marker text mentions historic v1+v2 coexistence — could be tidied if you have spare cycles.

---

## Memory entries up to date

- [project_brand_ipk_rebuild_plan.md](../../../.claude/projects/-Users-duncan-Dev-Turas/memory/project_brand_ipk_rebuild_plan.md) — rebuild marked **COMPLETE**
- `MEMORY.md` index updated
- All other brand-related memory entries unchanged

---

## Decision when starting the next session

**If the PR has merged**: pick #1 (Audience Lens v3) and start a planning conversation. Read `modules/brand/PLANNING_AUDIENCE_LENS.md` first; review against the new architecture; spec the tabs-as-engine approach before coding.

**If the PR has NOT merged**: open it via the URL above first. Don't start #1 on a stale base.

**Sonnet-running-in-parallel option**: tell Duncan you'll spin up #3 (the funnel test port) in a separate Sonnet session. Brief is `HANDOVER_FUNNEL_TESTS_PORT.md` — it's self-contained.

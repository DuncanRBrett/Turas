# Brand IPK Rebuild — Session 2 Handover

**Date:** 2026-04-30
**Branch:** `feature/brand-ipk-rebuild`
**Status:** 15 commits ahead of `main`, 416 tests pass / 0 fail
**Pick up at:** Step 3i Portfolio sub-analyses

This handover covers everything the next session needs to continue the rebuild. The governing reference remains [PLANNING_IPK_REBUILD.md](PLANNING_IPK_REBUILD.md) — read that first if you haven't seen this work before. The earlier handover [HANDOVER_IPK_ALCHEMER_SESSION4.md](HANDOVER_IPK_ALCHEMER_SESSION4.md) covered the Alchemer programming side (IPK survey build), not this rebuild.

---

## TL;DR

Branch state: 8 of 13 elements migrated to slot-indexed v2 + Portfolio screener helper done. The remaining real work is Portfolio's 5 sub-analyses + Audience Lens. DBA / Branded Reach / Ad Hoc are placeholder elements (no data in IPK Wave 1 fixture).

After elements ship, the work is §4 (output assembly + browser verification) and §5 (cutover).

---

## What's done (15 commits)

| Commit | Step | Element | Tests added |
|---|---|---|---|
| 653d7ca | docs | Planning + handover docs | n/a |
| 4ea740d | 0b | IPK Wave 1 fixture generator | n/a |
| 1c6ce54 | 0c | Brand_Config + Survey_Structure templates | n/a |
| 25f58b8 | 1a | `00_data_access.R` — 6 helpers | 52 |
| 08792fd | 1b | Convention-first role registry (v2) | 63 |
| 626c3e7 | 1c | `00_guard_v2.R` — slot-shape + active-category | 28 |
| d013c88 | 3a | Funnel — derive + attitude decomposition | 23 |
| b5ca831 | 3b | Cat Buying — `build_brand_volume_matrix` auto-detect | 13 |
| 5559bfb | 3c | Mental Availability — `build_cep_linkage` | 24 |
| 6ed0cf8 | 3d | Mental Advantage — integration test | 37 |
| 5e543f0 | 3e | WOM — `run_wom` | 52 |
| 6016a2b | 3f | Repertoire — `run_repertoire_v2` | 32 |
| 0fe06ee | 3g | Drivers & Barriers — `run_drivers_barriers_v2` | 25 |
| 36cb937 | 3k | Demographics — `resolve_demographic_role` + `demographic_question_from_role` | 46 |
| 5a56731 | 3i.1 | Portfolio — `build_portfolio_base` (screener helper only) | 21 |

**Total: 416 tests pass / 0 fail.**

Run `git log --oneline main..HEAD` for the live list. Architectural decisions in §10 of the planning doc are still locked.

---

## What's pending (in priority order)

### 1. Step 3i Portfolio sub-analyses — heaviest remaining work

The screener-qualifier helper (`build_portfolio_base`) is done. What's left is migrating the five sub-analyses + the cross-cat overview:

| File | What it reads today | v2 swap |
|---|---|---|
| `09a_portfolio_footprint.R` | `BRANDAWARE_{cat}_{brand}` per-brand columns | `multi_mention_brand_matrix(data, paste0("BRANDAWARE_", cat_code), brand_codes)` returns logical [n_resp x n_brands] |
| `09b_portfolio_constellation.R` | same | same |
| `09c_portfolio_clutter.R` | same | same |
| `09d_portfolio_strength.R` | same | same |
| `09e_portfolio_extension.R` | same, plus a global `^BRANDAWARE_[^_]+_[^_]+$` scan for the brand universe | for the universe scan: walk `Brands` sheet across categories instead — every brand in the structure should be in the universe |
| `09h_portfolio_overview_data.R` | walks multiple categories | iterate `active_categories` from Brand_Config + call `multi_mention_brand_matrix` per category |

Suggested approach: write **one shared helper** in `09_portfolio.R` (or a new `09_portfolio_helpers.R`):

```r
#' Build the brand x respondent awareness matrix for a category
#' @keywords internal
.portfolio_aware_matrix <- function(data, cat_code, brand_codes) {
  multi_mention_brand_matrix(data, paste0("BRANDAWARE_", cat_code), brand_codes)
}
```

Then each sub-analysis calls it instead of looping `paste0("BRANDAWARE_", cat_code, "_", bc)`. Most sub-analyses also use the qualifier base — they should call `build_portfolio_base()` (already shipped).

Test pattern: hand-coded mini-fixture with 3 categories × 4 brands and known-answer expected counts; plus IPK Wave 1 integration verifying the footprint heatmap shape and constellation node count.

Per the planning doc §6, only DSS is fully populated in Wave 1. Cross-cat awareness for POS/PAS/BAK respondents will exist (those are aware-only categories in IPK Wave 1).

### 2. Step 3m Audience Lens — depends on 3f + 3k (both done)

4 files (`13_audience_lens.R`, `13a_al_audiences.R`, `13b_al_metrics.R`, `13c_al_classify.R`, `13d_al_panel_data.R` — actually 5).

Reads BRANDPEN2 (already migrated via 3f) for buyer flag + DEMO_* (already migrated via 3k) for audience segmentation. Should be a thin v2 wrapper that calls the existing analytics on slot-indexed-derived inputs.

### 3. Steps 3h DBA, 3j Branded Reach, 3l Ad Hoc — placeholder elements

The IPK Wave 1 fixture has zero columns for any of these (`grep -c '^DBA_\|^REACH_\|^ADHOC_'` returns 0 each). Per planning doc §6, all three are deferred to later waves.

For each: ensure the orchestrator's "no data" path produces a graceful `Data not yet collected for [Element]` placeholder card. The legacy guards likely already do this — verify, don't over-build.

### 4. Step 4 Output assembly + browser verification

After all element migrations, switch the orchestrator (`00_main.R`) to call the v2 entry points. This is currently the only place the legacy `run_wom`, `run_repertoire`, etc. are still called — the v2 versions are stand-alone.

Browser verification per the launch_turas memory rule: `launch_turas()` → pick IPK Brand_Config in GUI → render full report → pin every panel → export PNG of every panel → all succeed.

### 5. Step 5 Cutover

Per planning doc §9 step 5:
- Delete legacy `tests/fixtures/generate_ipk_9cat_wave1.R` and the in-flight uncommitted change to it (currently in `git status`).
- Delete legacy `00_role_map.R`, `00_guard_role_map.R`, legacy portions of `00_guard.R`.
- Delete legacy funnel tests: `test_funnel_transactional.R`, `test_funnel_durable.R`, `test_funnel_service.R`, `test_funnel_edge_cases.R`, `test_funnel_integration.R`, `test_funnel_output.R`, `test_funnel_panel_data.R`, `test_funnel_panel_table.R`, `test_funnel_nesting.R` — these use column-per-brand fixtures and are scheduled for retirement.
- Delete other legacy element tests where v2 fully supersedes (audit each before deletion).
- Update memory entry, mark planning doc Status = Complete.
- Open PR to `main`.

---

## Architecture pattern — use this for remaining migrations

The pattern established across 8 elements is consistent:

**Per-element migration =**
1. Add a `run_X(data, role_map, cat_code, brand_list, focal_brand, weights, ...)` function alongside the existing `run_X`.
2. Inside, look up roles from `role_map` and use the data-access layer:
   - Multi_Mention slot-indexed roots → `multi_mention_brand_matrix(data, root, brand_codes)`
   - Per-brand single columns → `single_response_brand_matrix(data, root, cat_code, brand_codes)`
   - Paired Multi_Mention + Continuous_Sum (BRANDPEN2 + BRANDPEN3) → `slot_paired_numeric_matrix(data, root_codes, root_values, brand_codes)`
3. Pass the resulting matrices through to the existing analytical function unchanged. Analytical functions consume tensors / matrices, not raw data — no rewrite needed.
4. Return the same list shape as legacy `run_X` so the panel data builders stay unchanged.

**Per-element tests =** new `test_X.R` file with:
1. A hand-coded slot-indexed mini-fixture with hand-calculated expected outputs.
2. An IPK Wave 1 integration test verifying end-to-end shape + invariants.

Don't try to update legacy column-per-brand tests — they're scheduled for deletion at cutover (§9 step 5a).

### Role-map keys established

| Role pattern | Source | Used by |
|---|---|---|
| `funnel.awareness.{cat}` | BRANDAWARE_{cat} | funnel, portfolio |
| `funnel.attitude.{cat}` | BRANDATT1_{cat}_{brand} (compound per-brand) | funnel, drivers/barriers |
| `funnel.penetration_long.{cat}` | BRANDPEN1_{cat} | funnel |
| `funnel.penetration_target.{cat}` | BRANDPEN2_{cat} | funnel, repertoire, drivers/barriers |
| `funnel.frequency.{cat}` | BRANDPEN3_{cat} | repertoire (paired with BRANDPEN2) |
| `mental_avail.cep.{cat}.{ITEM}` | BRANDATTR_{cat}_CEP{NN} | MA, MA Advantage, drivers/barriers |
| `mental_avail.attr.{cat}.{ITEM}` | BRANDATTR_{cat}_ATT{NN} | MA, MA Advantage |
| `wom.pos_rec.{cat}` / `wom.neg_rec.{cat}` / `wom.pos_share.{cat}` / `wom.neg_share.{cat}` | WOM_{POS|NEG}_{REC|SHARE}_{cat} | WOM |
| `wom.pos_count.{cat}` / `wom.neg_count.{cat}` | WOM_{POS|NEG}_COUNT_{cat}_{brand} (compound per-brand) | WOM |
| `cat_buying.frequency.{cat}` | CATBUY_{cat} | cat buying |
| `cat_buying.count.{cat}` | CATCOUNT_{cat} | cat buying |
| `cat_buying.channel.{cat}` | CHANNEL_{cat} | shopper behaviour |
| `cat_buying.packsize.{cat}` | PACK_{cat} | shopper behaviour |
| `screener.sq1` / `screener.sq2` | SQ1 / SQ2 (slot-indexed, category code values) | portfolio base |
| `demographics.{key}` | DEMO_{KEY} | demographics |
| `adhoc.{key}.ALL` / `adhoc.{key}.{cat}` | ADHOC_{KEY} / ADHOC_{KEY}_{cat} | ad hoc (pending) |

---

## Verification commands

Quick sanity check (run from repo root):

```bash
Rscript -e 'library(testthat); for (f in c("test_data_access","test_role_map","test_guard","test_funnel","test_brand_volume","test_mental_avail","test_ma_advantage","test_wom","test_repertoire","test_drivers_barriers","test_demographics","test_portfolio")) testthat::test_file(paste0("modules/brand/tests/testthat/", f, ".R"))'
```

Expected: 416 PASS, 0 FAIL.

Regenerate IPK fixture (deterministic):

```bash
Rscript -e 'source("modules/brand/tests/fixtures/ipk_wave1/00_generate.R"); ipk_generate_fixture()'
```

---

## Gotchas

1. **Brand module loader is whitelist-based.** Per memory, new files in `modules/brand/R/` must be added to `.source_brand_module` `module_files` list at `00_main.R:54-87` or they silently never load in production. The v2 entries added so far are inside existing files (`02_mental_availability.R`, `04_repertoire.R`, etc.) so this hasn't bitten — but if you create a new `09_portfolio_helpers.R` for the Portfolio migration, **add it to the whitelist**.

2. **Synthetic fixture rule expires at cutover.** The "do not touch synthetic data generator" memory rule applies to `tests/fixtures/generate_ipk_9cat_wave1.R`. There's an uncommitted change to it in `git status` from the prior session — leave it alone; it gets deleted at cutover (§9 step 5a). The new IPK fixture lives at `tests/fixtures/ipk_wave1/`.

3. **Legacy element tests fail against migrated code.** Expected — they use column-per-brand fixtures. Do not try to fix them. They're scheduled for deletion at cutover.

4. **Don't update the orchestrator yet.** All v2 entry points are stand-alone. The orchestrator (`00_main.R`) still calls legacy `run_wom`, `run_repertoire`, `run_demographic_question` etc. directly. The orchestrator switch happens at §4 (output assembly), once all elements are migrated. Doing it incrementally would create half-migrated state that's hard to test.

5. **Browser verification is `launch_turas()` only.** Per memory, brand reports are generated HTML, not preview-served. Don't run `preview_start` against the brand module.

---

## Files in this session's flight

- Branch is 15 commits ahead of `origin/feature/brand-ipk-rebuild` — push when ready.
- Uncommitted: `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` (legacy generator — leave alone).
- Untracked: `scripts/fetch_alchemer_reporting_values.R` (unrelated to rebuild).

Memory entry updated: `~/.claude/projects/-Users-duncan-Dev-Turas/memory/project_brand_ipk_rebuild_plan.md`.

---

*End of handover. Maintained on the rebuild branch alongside the planning doc.*

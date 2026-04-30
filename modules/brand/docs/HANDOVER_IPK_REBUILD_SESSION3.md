# Brand IPK Rebuild — Session 3 Handover

**Date:** 2026-04-30
**Branch:** `feature/brand-ipk-rebuild`
**Status:** 17 commits ahead of `main`, 527 tests pass / 0 fail
**Pick up at:** Step 3m Audience Lens

This handover continues from [HANDOVER_IPK_REBUILD_SESSION2.md](HANDOVER_IPK_REBUILD_SESSION2.md). The governing reference remains [PLANNING_IPK_REBUILD.md](PLANNING_IPK_REBUILD.md). Read either if you haven't seen this work before.

---

## TL;DR

Step 3i Portfolio sub-analyses shipped in this session — every Portfolio compute function now has a v2 entry running on slot-indexed awareness. 9 of 13 elements migrated. Remaining real work is **3m Audience Lens** (4-5 files, both upstream deps already migrated). Placeholders 3h/3j/3l are render-the-empty-state-card jobs.

After elements ship, §4 (output assembly + browser verification) and §5 (cutover) close it out.

---

## What's done in this session (1 commit, +111 tests)

| Commit | Step | Element | Tests |
|---|---|---|---|
| de7c410 | 3i.2 | Portfolio sub-analyses — `compute_footprint_matrix_v2`, `compute_constellation_v2`, `compute_constellations_per_cat_v2`, `compute_clutter_data_v2`, `compute_strength_map_v2`, `compute_extension_table_v2`, `compute_extension_per_brand_v2`, `compute_portfolio_overview_data_v2` | 111 |

**Branch state:** 17 commits ahead of `main`, **527 tests pass / 0 fail.**

Full list: `git log --oneline main..HEAD`. Architectural decisions in §10 of the planning doc are still locked.

### Key design choices in 3i.2

- **One shared helper, many callers.** [09_portfolio.R](../R/09_portfolio.R) gained `.portfolio_aware_matrix_v2(data, role_map, cat_code, brand_codes)` and `.portfolio_aware_root_v2(role_map, cat_code)`. Every v2 sub-analysis calls the helper instead of looping `paste0("BRANDAWARE_", cat, "_", brand)`. Convention fallback → `BRANDAWARE_{cat_code}` when `role_map` is NULL or missing the entry.
- **v2 contract is `(data, role_map, categories, structure, config, weights, ...)`.** Categories must carry `CategoryCode` (per the new Brand_Config schema) — no detection. Refuses `CFG_PORTFOLIO_NO_CATEGORY_CODE` when missing.
- **Brand universe walks `structure$brands$BrandCode`** instead of `^BRANDAWARE_[^_]+_[^_]+$` regex scans over data column names. This is the cleanest swap for the constellation cross-cat universe and the extension per-brand walker.
- **Zero-qualifier categories are recorded in `suppressed_cats` and skipped from the matrix.** Different from legacy v1 where a missing `SQ2_{cat}` column produced REFUSED on the base; in v2 the slot column always exists, so we test `base$n_uw == 0` instead.
- **SIZE-EXCEPTION markers** added to 09_portfolio.R, 09b, 09e, 09h. Each file holds v1 + v2 coexisting during the migration window — v1 deletion at cutover brings them back under 300 active lines.

---

## What's pending (priority order)

### 1. Step 3m Audience Lens — heaviest remaining work

5 files: `13_audience_lens.R`, `13a_al_audiences.R`, `13b_al_metrics.R`, `13c_al_classify.R`, `13d_al_panel_data.R`.

Reads:
- BRANDPEN2 (already migrated via 3f) for the buyer flag.
- DEMO_* (already migrated via 3k) for audience segmentation.

Both upstream dependencies are already v2. The migration is a thin v2 wrapper that calls `multi_mention_brand_matrix(data, "BRANDPEN2_{cat}", brand_codes)` for buyer flags and `respondent_picked(data, "DEMO_{key}", value)` (or the demographic resolver from 3k) for audiences.

**Suggested approach:** Add `run_audience_lens_v2(data, role_map, cat_code, brand_list, audiences, focal_brand, weights)` alongside the existing `run_audience_lens`. Each audience definition (from the AudienceLens sheet of Brand_Config) names a column or expression — resolve via the demographic helpers. Pass the buyer flag matrix + audience masks through to the existing analytics, which already work on tensors.

Test pattern: hand-coded mini-fixture with 3 brands × 2 audiences (e.g. "young", "old"); known-answer per-audience SCR/penetration values.

### 2. Steps 3h DBA, 3j Branded Reach, 3l Ad Hoc — placeholder elements

The IPK Wave 1 fixture has zero columns for any of these (`grep -c '^DBA_\|^REACH_\|^ADHOC_'` returns 0 each). Per planning doc §6, all three are deferred to later waves.

For each: ensure the orchestrator's "no data" path produces a graceful `Data not yet collected for [Element]` placeholder card. The legacy guards likely already do this — verify, don't over-build.

For 3l Ad Hoc specifically: the v2 role inference already maps `ADHOC_{KEY}` → `adhoc.{key}.ALL` and `ADHOC_{KEY}_{CAT}` → `adhoc.{key}.{CAT}`. Lightweight when columns appear.

### 3. Step 4 Output assembly + browser verification

After all element migrations, switch the orchestrator (`00_main.R`) to call the v2 entry points. This is currently the only place the legacy `run_wom`, `run_repertoire`, `compute_footprint_matrix`, etc. are still called — the v2 versions are stand-alone.

**Critical for Portfolio:** `run_portfolio` (in 09_portfolio.R) currently calls all six v1 compute functions. The cutover is mechanical:

```r
compute_footprint_matrix(data, categories, structure, config, weights)
# becomes
compute_footprint_matrix_v2(data, role_map, categories, structure, config, weights)
```

…and similarly for the other five. The role_map needs to be threaded into `run_portfolio`'s signature (or reachable via config).

Browser verification per the launch_turas memory rule: `launch_turas()` → pick IPK Brand_Config in GUI → render full report → pin every panel → export PNG of every panel → all succeed.

### 4. Step 5 Cutover

Per planning doc §9 step 5:
- Delete legacy `tests/fixtures/generate_ipk_9cat_wave1.R` and the in-flight uncommitted change to it (still in `git status`).
- Delete legacy `00_role_map.R`, `00_guard_role_map.R`, legacy portions of `00_guard.R`.
- Delete legacy v1 entries inside the migrated files. Specifically for portfolio: `compute_footprint_matrix`, `compute_constellation`, `compute_constellations_per_cat`, `compute_clutter_data`, `compute_strength_map`, `compute_extension_table`, `compute_extension_per_brand`, `compute_portfolio_overview_data`, `.compute_category_awareness`, `.compute_category_clutter_metrics`, `.compute_constellation_for_cat`, `.build_aware_any_mat`, `build_portfolio_base` (legacy), `.po_build_category_record`. After deletion the v2 entries lose the `_v2` suffix to become the canonical names. Remove the SIZE-EXCEPTION markers — files should be back under 300 active lines.
- Delete legacy funnel tests: `test_funnel_transactional.R`, `test_funnel_durable.R`, `test_funnel_service.R`, `test_funnel_edge_cases.R`, `test_funnel_integration.R`, `test_funnel_output.R`, `test_funnel_panel_data.R`, `test_funnel_panel_table.R`, `test_funnel_nesting.R`.
- Delete legacy portfolio tests: `test_portfolio_base.R` (covers v1 `build_portfolio_base`), `test_portfolio_clutter.R`, `test_portfolio_constellation.R`, `test_portfolio_extension.R`, `test_portfolio_footprint.R`, `test_portfolio_strength.R`, `test_portfolio_overview.R`, `test_portfolio_output.R` — all use column-per-brand fixtures.
- Audit other legacy element tests before deletion.
- Update memory entry, mark planning doc Status = Complete.
- Open PR to `main`.

---

## Architecture pattern — established across 9 elements

The pattern is consistent. **For per-element migrations:**

1. Add a `run_X_v2(data, role_map, cat_code, brand_list, focal_brand, weights, ...)` (or the equivalent wider signature where the element walks multiple categories — Portfolio uses `(data, role_map, categories, structure, config, weights)`).
2. Inside, look up roles from `role_map` and use the data-access layer:
   - Multi_Mention slot-indexed roots → `multi_mention_brand_matrix(data, root, brand_codes)` (logical) or `multi_mention_indicator_matrix(data, root, codes)` (0/1 integer).
   - Per-brand single columns → `single_response_brand_matrix(data, root, cat_code, brand_codes)`.
   - Paired Multi_Mention + Continuous_Sum (BRANDPEN2 + BRANDPEN3) → `slot_paired_numeric_matrix(data, root_codes, root_values, brand_codes)`.
   - Per-respondent option flag → `respondent_picked(data, root, option_code)`.
3. Pass the matrices to the existing analytical function unchanged. Analytical functions consume tensors / matrices, not raw data — no rewrite needed.
4. Return the same list shape as legacy `run_X` so the panel data builders stay unchanged.

**For per-element tests** (`test_X_v2.R`):
1. Hand-coded slot-indexed mini-fixture with hand-calculated expected outputs. Known-answer is mandatory — name the rows, list the slot values, hand-calculate the result before writing the assertion.
2. IPK Wave 1 integration test verifying end-to-end shape + invariants.

Don't try to update legacy column-per-brand tests — they're scheduled for deletion at cutover (§9 step 5a).

### Role-map keys established

| Role pattern | Source | Used by |
|---|---|---|
| `funnel.awareness.{cat}` | BRANDAWARE_{cat} | funnel, portfolio |
| `portfolio.awareness.{cat}` | BRANDAWARE_{cat} | portfolio (preferred over funnel.awareness for `.portfolio_aware_root_v2`) |
| `funnel.attitude.{cat}` | BRANDATT1_{cat}_{brand} (compound per-brand) | funnel, drivers/barriers |
| `funnel.penetration_long.{cat}` | BRANDPEN1_{cat} | funnel |
| `funnel.penetration_target.{cat}` | BRANDPEN2_{cat} | funnel, repertoire, drivers/barriers, audience lens |
| `funnel.frequency.{cat}` | BRANDPEN3_{cat} | repertoire (paired with BRANDPEN2) |
| `mental_avail.cep.{cat}.{ITEM}` | BRANDATTR_{cat}_CEP{NN} | MA, MA Advantage, drivers/barriers |
| `mental_avail.attr.{cat}.{ITEM}` | BRANDATTR_{cat}_ATT{NN} | MA, MA Advantage |
| `wom.pos_rec.{cat}` / `wom.neg_rec.{cat}` / `wom.pos_share.{cat}` / `wom.neg_share.{cat}` | WOM_{POS\|NEG}_{REC\|SHARE}_{cat} | WOM |
| `wom.pos_count.{cat}` / `wom.neg_count.{cat}` | WOM_{POS\|NEG}_COUNT_{cat}_{brand} (compound per-brand) | WOM |
| `cat_buying.frequency.{cat}` | CATBUY_{cat} | cat buying |
| `cat_buying.count.{cat}` | CATCOUNT_{cat} | cat buying |
| `cat_buying.channel.{cat}` | CHANNEL_{cat} | shopper behaviour |
| `cat_buying.packsize.{cat}` | PACK_{cat} | shopper behaviour |
| `screener.sq1` / `screener.sq2` | SQ1 / SQ2 (slot-indexed, category code values) | portfolio base |
| `demographics.{key}` | DEMO_{KEY} | demographics, audience lens |
| `adhoc.{key}.ALL` / `adhoc.{key}.{cat}` | ADHOC_{KEY} / ADHOC_{KEY}_{cat} | ad hoc (pending) |

---

## Verification commands

Quick sanity check (run from repo root):

```bash
Rscript -e 'library(testthat); for (f in c("test_data_access","test_role_map_v2","test_guard_v2","test_funnel_v2","test_brand_volume_v2","test_mental_avail_v2","test_ma_advantage_v2","test_wom_v2","test_repertoire_v2","test_drivers_barriers_v2","test_demographics_v2","test_portfolio_v2","test_portfolio_subanalyses_v2")) testthat::test_file(paste0("modules/brand/tests/testthat/", f, ".R"))'
```

Expected: **527 PASS, 0 FAIL.**

Regenerate IPK fixture (deterministic):

```bash
Rscript -e 'source("modules/brand/tests/fixtures/ipk_wave1/00_generate.R"); ipk_generate_fixture()'
```

---

## Gotchas (carried forward + new)

1. **Brand module loader is whitelist-based.** Per memory, new files in `modules/brand/R/` must be added to `.source_brand_module` `module_files` list at `00_main.R:54-101` or they silently never load in production. The v2 entries added so far are all inside existing files (`02_mental_availability.R`, `04_repertoire.R`, `09_portfolio.R`, `09a..09h_portfolio_*.R` etc.) so this hasn't bitten — but if 3m Audience Lens spawns a new `13e_al_v2.R` or similar, **add it to the whitelist**.

2. **Synthetic fixture rule expires at cutover.** The "do not touch synthetic data generator" memory rule applies to `tests/fixtures/generate_ipk_9cat_wave1.R`. There's still an uncommitted change to it in `git status` from session 1 — leave it alone; it gets deleted at cutover (§9 step 5a). The new IPK fixture lives at `tests/fixtures/ipk_wave1/`.

3. **Legacy element tests fail against migrated code.** Expected — they use column-per-brand fixtures. Do not try to fix them. They're scheduled for deletion at cutover.

4. **Don't update the orchestrator yet.** All v2 entry points are stand-alone. The orchestrator (`00_main.R`) still calls legacy `run_wom`, `run_repertoire`, `compute_footprint_matrix` etc. directly. The orchestrator switch happens at §4 (output assembly), once all elements are migrated. Doing it incrementally would create half-migrated state that's hard to test.

5. **Browser verification is `launch_turas()` only.** Per memory, brand reports are generated HTML, not preview-served. Don't run `preview_start` against the brand module.

6. **Portfolio v2 zero-qualifier semantics differ from v1.** Legacy v1 returned REFUSED when `SQ2_{cat}` column was absent. v2 always finds slot columns (SQ2_1..N exist for the whole study) and instead detects `base$n_uw == 0` to skip cats. If you write a test that expects v1's REFUSED-on-missing behaviour, it will fail under v2 — assert `cat %in% suppressed_cats` instead.

7. **Lift baseline in `compute_extension_table_v2` is per-cat focal awareness, not "any awareness".** When testing `lift = p_c / p_baseline`, `p_baseline` reads the focal-aware indicator from `respondent_picked(data, "BRANDAWARE_{cat}", focal_brand)` over **all 8** respondents (mode="all") for THIS category — not "focal aware in any category". Easy hand-calc trap.

---

## Files in this session's flight

- Branch is 17 commits ahead of `origin/feature/brand-ipk-rebuild` — push when ready.
- Uncommitted: `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` (legacy generator — leave alone, scheduled for cutover deletion).
- Untracked: `scripts/fetch_alchemer_reporting_values.R` (unrelated to rebuild).

Memory entry updated: `~/.claude/projects/-Users-duncan-Dev-Turas/memory/project_brand_ipk_rebuild_plan.md` reflects 17 commits / 527 tests / 9 elements migrated.

---

*End of handover. Maintained on the rebuild branch alongside the planning doc.*

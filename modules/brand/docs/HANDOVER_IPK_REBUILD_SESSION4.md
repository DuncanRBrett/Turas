# Brand IPK Rebuild — Session 4 Handover

**Date:** 2026-04-30
**Branch:** `feature/brand-ipk-rebuild`
**Status:** 18 commits ahead of `main`, 614 tests pass / 0 fail
**Pick up at:** Steps 3h DBA / 3j Branded Reach / 3l Ad Hoc (placeholder elements), then §4 output assembly

This handover continues from [HANDOVER_IPK_REBUILD_SESSION3.md](HANDOVER_IPK_REBUILD_SESSION3.md). The governing reference remains [PLANNING_IPK_REBUILD.md](PLANNING_IPK_REBUILD.md). Read either if you haven't seen this work before.

---

## TL;DR

Step 3m Audience Lens shipped this session. **10 of 13 elements migrated.** Remaining: 3h DBA, 3j Branded Reach, 3l Ad Hoc — all placeholder elements (the IPK Wave 1 fixture has zero data columns for any of them; per planning §6, all three are deferred to later waves). After those, §4 output assembly + §5 cutover close it out.

The session also captured a strategic decision on Audience Lens v2 design (see §Design decision below) and saved a tracker-friendliness rule to memory that all future brand-metric design must respect.

---

## What's done in this session (1 commit, +87 tests)

| Commit | Step | Element | Tests |
|---|---|---|---|
| 8b6d233 | 3m | Audience Lens — `run_audience_lens`, `compute_al_metrics_for_subset`, plus v2 helpers for MA, WOM, SCR, purchase freq/dist | 87 |

**Branch state:** 18 commits ahead of `main`, **614 tests pass / 0 fail.**

Full list: `git log --oneline main..HEAD`. Architectural decisions in §10 of the planning doc are still locked.

### Design decision: Option C (thin v2 wrapper)

Three options were considered for Audience Lens v2:

- **Option A** — thin v2 wrapper, like the other 9 elements. Replace column-walking with role-map lookups, KPI math stays put.
- **Option B** — Tabs-as-engine. Audiences become a banner; the 14 KPIs become a stub; Tabs does the cross-tab + sig test. 5 derived KPIs (MMS, SoM, Network Size, Branded Reach, Loyalty SCR) become pre-computed per-respondent columns. Sig logic harmonises with the rest of the report. Files shrink ~25%.
- **Option C** — Hybrid. Do A now (consistent with the established v2 pattern, unblocks cutover), schedule B as a post-cutover project (`feature/audience-lens-v3-tabs`).

**Chose C.** Doing a meaningful re-architecture mid-rebuild either stalls cutover or commits to a half-baked rewrite. Option B is a real win but it's a 1–2 day project on its own.

Memory entry [feedback_brand_metrics_tracker_friendly.md](file:///Users/duncan/.claude/projects/-Users-duncan-Dev-Turas/memory/feedback_brand_metrics_tracker_friendly.md) saved this session captures the rule that emerged from the discussion: any new brand metric/KPI must be expressible as per-respondent stable columns or simple ratios so the tracker module can lift them across waves. Audience Lens v3 will be the canonical project where this rule first gets tested.

### Key implementation notes for 3m

- **Audience parsing (13a), pair classification (13c), panel-data shaping (13d) are unchanged.** They operate on the metric output shape, not the data layer underneath, so v2 wires up with no change to those files.
- **v2 metric helpers operate on per-respondent indicators**, not on column lookups. `.al_metric_pct_from_logical(indicator, weights, keep_idx, na_means_no)` takes a pre-resolved logical vector built via `respondent_picked()` or `multi_mention_brand_matrix()`. `.al_metric_pct_from_attitude(att_vec, weights, keep_idx, codes)` operates on the focal-brand attitude column directly. This shape is the foundation for the v3 Tabs-as-engine project — these indicators are the per-respondent KPI columns the tracker would need.
- **MA block walks `mental_avail.cep.{cat}.*` roles** in the role map and builds n × B link matrices via `multi_mention_brand_matrix(data, root, brand_codes)`. Same algebra as v1 (MPen / NS / MMS / SoM); cleaner because cat_name is no longer needed for CEP discovery.
- **WOM block uses the four mention-set roles** (`wom.{pos|neg}_{rec|share}.{cat}`) — all Multi_Mention slot-indexed in the v2 shape. Per-brand WOM count roles (`wom.{pos|neg}_count.{cat}.{brand}`) are not needed for Audience Lens — net heard/said are mention-set proportions, not counts.
- **SCR / purchase freq / dist use `slot_paired_numeric_matrix(data, "BRANDPEN2_{cat}", "BRANDPEN3_{cat}", brand_codes)`** to produce an n × B numeric tensor with the focal-brand column extracted. Trivial vs the v1 column-walking.
- **Branded reach is unchanged** between v1 and v2 — it reads the `MarketingReach` sheet from `structure`, not from the role map. The IPK Wave 1 fixture has no MarketingReach sheet, so the metric returns NA with note "No MarketingReach assets configured" — expected and tested.
- **SIZE-EXCEPTION markers** added to `13_audience_lens.R` (452 lines) and `13b_al_metrics.R` (914 lines). Each holds v1 + v2 coexisting during the migration window — v1 deletion at cutover brings them back under 300 active lines.

---

## What's pending (priority order)

### 1. Steps 3h DBA, 3j Branded Reach, 3l Ad Hoc — placeholder elements

The IPK Wave 1 fixture has zero columns for any of these (`grep -c '^DBA_\|^REACH_\|^ADHOC_'` returns 0 each). Per planning doc §6, all three are deferred to later waves.

For each: ensure the orchestrator's "no data" path produces a graceful `Data not yet collected for [Element]` placeholder card. The legacy guards likely already do this — verify, don't over-build.

For 3l Ad Hoc specifically: the v2 role inference already maps `ADHOC_{KEY}` → `adhoc.{key}.ALL` and `ADHOC_{KEY}_{CAT}` → `adhoc.{key}.{CAT}`. Lightweight when columns appear.

For 3j Branded Reach: when `MarketingReach` data appears, build a `run_branded_reach` that reads asset definitions from `structure$marketing_reach` (unchanged shape — this is a survey-structure concern, not a role-map concern) and uses `respondent_picked` for any focal-brand indicator columns referenced.

For 3h DBA: when distributional data appears, follow the same role-map-driven pattern.

**Estimate:** small. Each placeholder is ~30–50 lines of "return PASS with empty payload" plus a test that verifies the empty-state contract.

### 2. Step 4 Output assembly + browser verification

After all element migrations, switch the orchestrator (`00_main.R`) to call the v2 entry points. The orchestrator currently still calls legacy `run_wom`, `run_repertoire`, `compute_footprint_matrix`, `run_audience_lens` etc. directly. The v2 versions are stand-alone.

**Critical for Audience Lens:** `run_audience_lens` (legacy) is called from `00_main.R` during the per-category loop. The cutover for AL is mechanical:

```r
run_audience_lens(data, weights, cat_brands, cat_code, cat_name,
                   focal_brand, audiences, structure, config, category_results)
# becomes
run_audience_lens(data, role_map, cat_code, cat_name, cat_brands,
                      focal_brand, audiences, structure, config, weights,
                      category_results)
```

Same return shape — pair_cards, audiences, suppressed, total, meta — so the panel-data shaper (13d) and HTML renderer don't change. Only the call site and the `weights` argument position changes.

Browser verification per the launch_turas memory rule: `launch_turas()` → pick IPK Brand_Config in GUI → render full report → pin every panel → export PNG of every panel → all succeed.

### 3. Step 5 Cutover

Per planning doc §9 step 5:
- Delete legacy `tests/fixtures/generate_ipk_9cat_wave1.R` and the in-flight uncommitted change to it (still in `git status`).
- Delete legacy `00_role_map.R`, `00_guard_role_map.R`, legacy portions of `00_guard.R`.
- Delete legacy v1 entries inside the migrated files. Specifically for audience lens: `run_audience_lens` (the function and its private helpers `.al_resolve_thresholds` is shared so keep that), `compute_al_metrics_for_subset`, `.al_metric_pct_indicator`, `.al_metric_branded_reach` (or keep — same code v2 uses), `.al_metric_ma_block`, `.al_metric_wom_block`, `.al_metric_scr`, `.al_metric_purchase_freq`, `.al_metric_purchase_dist`, `.al_first_col`. After deletion the v2 entries lose the `_v2` suffix to become the canonical names. Remove the SIZE-EXCEPTION markers — files should be back under 300 active lines (estimate: 13_audience_lens.R drops from 452→~250, 13b_al_metrics.R drops from 914→~430).
- Delete other legacy element tests (full list in HANDOVER_IPK_REBUILD_SESSION3.md §5).
- Delete legacy audience lens tests: `test_audience_lens.R`, `test_audience_lens_audiences.R`, `test_audience_lens_metrics.R`, `test_audience_lens_classifier.R`, `test_audience_lens_panel_data.R` (anything that exercises the v1 column-per-brand contract).
- Update memory entry, mark planning doc Status = Complete.
- Open PR to `main`.

### 4. Audience Lens v3 (post-cutover, separate project)

Captured here so it doesn't get lost. Branch name: `feature/audience-lens-v3-tabs`.

- Audiences become a banner stub passed to Tabs.
- The 14 KPIs become per-respondent stable columns on a working copy of the data (`KPI_FOCAL_AWARENESS`, `KPI_FOCAL_NETWORK_SIZE`, etc.). For the 5 derived KPIs (MMS, SoM, Network Size, Branded Reach, Loyalty SCR), this means computing them once at the working-copy step.
- Tabs handles the cross-tab + sig test.
- Brand becomes a thin presentation layer (audience parsing, GROW/FIX/DEFEND classifier, card render).
- Net win: 13b shrinks from ~430 to ~150 lines (KPI catalogue + KPI column builders only). Sig logic harmonises with the rest of the report. The KPI columns are tracker-portable by construction.
- Required precondition: Tabs callable as a library function from inside brand. Verify before starting.

This is genuinely a 1–2 day project. Don't roll it into the rebuild's cutover.

---

## Architecture pattern — established across 10 elements

The pattern is consistent. **For per-element migrations:**

1. Add a `run_X(data, role_map, cat_code, brand_list, focal_brand, weights, ...)` (or the equivalent wider signature where the element walks multiple categories).
2. Inside, look up roles from `role_map` and use the data-access layer:
   - Multi_Mention slot-indexed roots → `multi_mention_brand_matrix(data, root, brand_codes)` (logical) or `multi_mention_indicator_matrix(data, root, codes)` (0/1 integer).
   - Per-brand single columns → `single_response_brand_matrix(data, root, cat_code, brand_codes)` or via `role_map[[role]]$columns[[brand]]` for one column.
   - Paired Multi_Mention + Continuous_Sum (BRANDPEN2 + BRANDPEN3) → `slot_paired_numeric_matrix(data, root_codes, root_values, brand_codes)`.
   - Per-respondent option flag → `respondent_picked(data, root, option_code)`.
3. Pass the matrices to the existing analytical function unchanged. Analytical functions consume tensors / matrices, not raw data — no rewrite needed.
4. Return the same list shape as legacy `run_X` so the panel data builders stay unchanged.

**For per-element tests** (`test_X.R`):
1. Hand-coded slot-indexed mini-fixture with hand-calculated expected outputs. Known-answer is mandatory — name the rows, list the slot values, hand-calculate the result before writing the assertion.
2. IPK Wave 1 integration test verifying end-to-end shape + invariants.

Don't try to update legacy column-per-brand tests — they're scheduled for deletion at cutover (§9 step 5a).

### Role-map keys established (with this session's additions)

| Role pattern | Source | Used by |
|---|---|---|
| `funnel.awareness.{cat}` | BRANDAWARE_{cat} | funnel, portfolio, audience lens |
| `portfolio.awareness.{cat}` | BRANDAWARE_{cat} | portfolio (preferred over funnel.awareness for `.portfolio_aware_root`) |
| `funnel.attitude.{cat}` | BRANDATT1_{cat}_{brand} (compound per-brand) | funnel, drivers/barriers, audience lens |
| `funnel.penetration_long.{cat}` | BRANDPEN1_{cat} | funnel |
| `funnel.penetration_target.{cat}` | BRANDPEN2_{cat} | funnel, repertoire, drivers/barriers, audience lens |
| `funnel.frequency.{cat}` | BRANDPEN3_{cat} | repertoire (paired with BRANDPEN2), audience lens (SCR + purchase freq/dist) |
| `mental_avail.cep.{cat}.{ITEM}` | BRANDATTR_{cat}_CEP{NN} | MA, MA Advantage, drivers/barriers, audience lens |
| `mental_avail.attr.{cat}.{ITEM}` | BRANDATTR_{cat}_ATT{NN} | MA, MA Advantage |
| `wom.pos_rec.{cat}` / `wom.neg_rec.{cat}` / `wom.pos_share.{cat}` / `wom.neg_share.{cat}` | WOM_{POS\|NEG}_{REC\|SHARE}_{cat} | WOM, audience lens |
| `wom.pos_count.{cat}` / `wom.neg_count.{cat}` | WOM_{POS\|NEG}_COUNT_{cat}_{brand} (compound per-brand) | WOM |
| `cat_buying.frequency.{cat}` | CATBUY_{cat} | cat buying |
| `cat_buying.count.{cat}` | CATCOUNT_{cat} | cat buying |
| `cat_buying.channel.{cat}` | CHANNEL_{cat} | shopper behaviour |
| `cat_buying.packsize.{cat}` | PACK_{cat} | shopper behaviour |
| `screener.sq1` / `screener.sq2` | SQ1 / SQ2 (slot-indexed, category code values) | portfolio base |
| `demographics.{key}` | DEMO_{KEY} | demographics, audience lens (via filter columns, not roles) |
| `adhoc.{key}.ALL` / `adhoc.{key}.{cat}` | ADHOC_{KEY} / ADHOC_{KEY}_{cat} | ad hoc (pending) |

---

## Verification commands

Quick sanity check (run from repo root):

```bash
Rscript -e 'library(testthat); for (f in c("test_data_access","test_role_map","test_guard","test_funnel","test_brand_volume","test_mental_avail","test_ma_advantage","test_wom","test_repertoire","test_drivers_barriers","test_demographics","test_portfolio","test_portfolio_subanalyses","test_audience_lens")) testthat::test_file(paste0("modules/brand/tests/testthat/", f, ".R"))'
```

Expected: **614 PASS, 0 FAIL.**

Regenerate IPK fixture (deterministic):

```bash
Rscript -e 'source("modules/brand/tests/fixtures/ipk_wave1/00_generate.R"); ipk_generate_fixture()'
```

---

## Gotchas (carried forward + new)

1. **Brand module loader is whitelist-based.** Per memory, new files in `modules/brand/R/` must be added to `.source_brand_module` `module_files` list at `00_main.R:54-101` or they silently never load in production. The v2 entries added so far are all inside existing files (`02_mental_availability.R`, `04_repertoire.R`, `09_portfolio.R`, `09a..09h_portfolio_*.R`, `13_audience_lens.R`, `13b_al_metrics.R` etc.) so this hasn't bitten.

2. **Synthetic fixture rule expires at cutover.** The "do not touch synthetic data generator" memory rule applies to `tests/fixtures/generate_ipk_9cat_wave1.R`. There's still an uncommitted change to it in `git status` from session 1 — leave it alone; it gets deleted at cutover (§9 step 5a). The new IPK fixture lives at `tests/fixtures/ipk_wave1/`.

3. **Legacy element tests fail against migrated code.** Expected — they use column-per-brand fixtures. Do not try to fix them. They're scheduled for deletion at cutover.

4. **Don't update the orchestrator yet.** All v2 entry points are stand-alone. The orchestrator (`00_main.R`) still calls legacy `run_wom`, `run_repertoire`, `compute_footprint_matrix`, `run_audience_lens` etc. directly. The orchestrator switch happens at §4 (output assembly), once all elements are migrated.

5. **Browser verification is `launch_turas()` only.** Per memory, brand reports are generated HTML, not preview-served. Don't run `preview_start` against the brand module.

6. **Portfolio v2 zero-qualifier semantics differ from v1.** Legacy v1 returned REFUSED when `SQ2_{cat}` column was absent. v2 always finds slot columns (SQ2_1..N exist for the whole study) and instead detects `base$n_uw == 0` to skip cats. If you write a test that expects v1's REFUSED-on-missing behaviour, it will fail under v2 — assert `cat %in% suppressed_cats` instead.

7. **Lift baseline in `compute_extension_table` is per-cat focal awareness, not "any awareness".** When testing `lift = p_c / p_baseline`, `p_baseline` reads the focal-aware indicator from `respondent_picked(data, "BRANDAWARE_{cat}", focal_brand)` over **all 8** respondents (mode="all") for THIS category — not "focal aware in any category". Easy hand-calc trap.

8. **NEW — Audience Lens v2 sig power on small n.** The two-prop z + Fisher fallback is calibrated correctly, but at n=4 vs 4 even a 0.75-point gap doesn't clear alpha=0.10 (Fisher exact p≈0.143). When writing hand-calc tests against small fixtures, assert that a p-value was *computed* (not NA) rather than that `sig_flag` fires. Sig-flag-fires assertions belong in 13c classifier tests with larger fixtures or alpha=0.20.

9. **NEW — Tracker-friendliness rule.** Per memory entry [feedback_brand_metrics_tracker_friendly.md], any new brand metric/KPI must be expressible as per-respondent stable columns or simple ratios over them. Audience Lens v3 is the canonical project where this gets its first real test. Don't introduce hand-rolled aggregations bound to a single report's output structure.

---

## Files in this session's flight

- Branch is 18 commits ahead of `origin/feature/brand-ipk-rebuild` — push when ready.
- Uncommitted: `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` (legacy generator — leave alone, scheduled for cutover deletion).
- Untracked: `scripts/fetch_alchemer_reporting_values.R` (unrelated to rebuild).

Memory entries updated this session:
- `~/.claude/projects/-Users-duncan-Dev-Turas/memory/feedback_brand_metrics_tracker_friendly.md` (NEW) — tracker-friendliness rule for all future brand metric design.
- `~/.claude/projects/-Users-duncan-Dev-Turas/memory/project_brand_ipk_rebuild_plan.md` — updated to reflect 18 commits / 614 tests / 10 elements migrated.

---

*End of handover. Maintained on the rebuild branch alongside the planning doc.*

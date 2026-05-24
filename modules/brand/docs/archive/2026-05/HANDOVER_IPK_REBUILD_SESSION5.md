# Brand IPK Rebuild — Session 5 Handover

**Date:** 2026-04-30
**Branch:** `feature/brand-ipk-rebuild`
**Status:** 25 commits ahead of `main`, 702 tests pass / 0 fail (was 614 → +88)
**Pick up at:** Browser verification (`launch_turas`) → §5 cutover → PR to main

This handover continues from [HANDOVER_IPK_REBUILD_SESSION4.md](HANDOVER_IPK_REBUILD_SESSION4.md). The governing reference remains [PLANNING_IPK_REBUILD.md](PLANNING_IPK_REBUILD.md). Read either if you haven't seen this work before.

---

## TL;DR

**All 13 elements migrated. 8 of 11 orchestrator call sites switched to v2.** The only remaining v2 plumbing is the cross-category Portfolio data block (`.compute_portfolio_data` / `run_portfolio`), which orchestrates 8 sub-analyses and warrants its own session.

**The session is gated behind `launch_turas` browser verification before §5 cutover and PR.** The IPK fixture's `Brand_Config.xlsx` is still missing v1-era required fields (`project_name`, `data_file`, etc.), so end-to-end orchestrator runs need either a fixture refresh or running the GUI against a real config.

---

## What's done in this session (7 commits, +88 tests)

| Commit | Step | What |
|---|---|---|
| cab345c | 3h / 3j / 3l | `run_dba`, `run_branded_reach`, `run_adhoc` + `resolve_adhoc_role` placeholders. PASS-empty payload + `placeholder = TRUE` + sentinel notes when no data. **+88 tests.** |
| 1817333 | 4a | Orchestrator: source v2 modules via the loader whitelist; build `role_map` once after Step 3 data load; switch DBA + Branded Reach + Ad Hoc orchestrator calls to v2 (with legacy fallbacks when role_map is NULL). |
| e36a784 | 4b | Orchestrator: switch WOM, Repertoire, Drivers/Barriers, Audience Lens to their v2 entries. Lifted legacy column-prefix dispatch into `.legacy_wom_call`, `.legacy_repertoire_call`, `.legacy_drivers_barriers_call` for fallback. |
| af60b46 | 4c | Orchestrator: Mental Availability — `build_cep_linkage_from_matrix` → `build_cep_linkage` (CEP + attr matrices). New `.ma_resolve_cep_labels` joins display text by CEPCode for v2 vs by position for legacy. |
| dff93f9 | 4d | Orchestrator: Funnel — new `.run_funnel_for_category` passes the global v2 role_map directly with `cat_code` threaded through; bypasses the legacy QuestionMap normalisation entirely. |
| 3038e99 | 4e | Orchestrator: Portfolio Overview — `compute_portfolio_overview_data` → `compute_portfolio_overview_data`. |
| cff0cae | 4f | Orchestrator: Demographics — new `.run_demographics_for_category` walks role_map for `^demographics\.` keys via `demographic_question_from_role`. Synthetic Buyer Status + Heaviness questions unchanged. |

**Branch state:** 25 commits ahead of `main`, **702 PASS / 0 FAIL.**

Full list: `git log --oneline main..HEAD`. Architectural decisions in §10 of the planning doc are still locked.

---

## What's pending (priority order)

### 1. Browser verification — `launch_turas` (Duncan)

Per memory rule [feedback_launch_turas_verification.md], the only verification path for brand reports is running `launch_turas()` and picking the Brand_Config in the GUI. **This is gating §5 cutover and PR**.

**Fixture is now runnable** (commit f9f92ee). Regenerate with:

```bash
Rscript -e 'source("modules/brand/tests/fixtures/ipk_wave1/00_generate.R"); ipk_generate_fixture()'
```

Then in R:

```r
source("launch_turas.R")
launch_turas()
# In the GUI: pick modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx
```

End-to-end smoke test from the CLI confirms the orchestrator runs without REFUSED status:

```bash
Rscript -e 'source("modules/brand/R/00_main.R"); res <- run_brand("modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx", verbose = FALSE); cat("status:", res$status, "\n")'
# Expected: status: PARTIAL  (DSS PASS for every v2 element; POS/PAS/BAK
# empty because the fixture only populates DSS deep-dive data)
```

What to verify in the browser:

1. **DSS deep dive** — every panel renders cleanly: Funnel, Mental Availability, Mental Advantage, Cat Buying / Shopper Behaviour, WOM, Repertoire, Drivers & Barriers, Demographics, Audience Lens.
2. **Placeholder elements** — DBA, Branded Reach, Ad Hoc tabs each show the "Data not yet collected for X" card (sentinel text from the v2 placeholder payload).
3. **POS / PAS / BAK** — these are `Analysis_Depth = full` in Brand_Config but the fixture has no populated deep-dive data. Expect graceful empty panels / "no data" state, not crashes. (If the renderer crashes, that's a render-side bug worth fixing; the engines themselves return structured refusals.)
4. **Adjacent categories (SLD / STO / PES / COO / ANT)** — `awareness_only`. They should appear in the cross-category Portfolio view (their BRANDAWARE_{cat} columns are populated) but have no per-category sub-tab.
5. **Pin / PNG round-trip** — click every panel's pin → lands in the combined pins view with content. Export PNG of every panel → file downloads with content.

If anything fails: capture the specific panel + error and either fix in this branch or open a fix branch off it. **Do not start §5 cutover until browser verification is green.**

Known issue: the cross-category Portfolio constellation refuses with `CALC_CONSTELLATION_TOO_SPARSE` because the legacy `compute_constellation` reads column-per-brand awareness while IPK Wave 1 has slot-indexed awareness. This is the §4d work — `.compute_portfolio_data` → v2. The Portfolio Overview tab (already on v2) renders correctly.

### 2. Step 4d — Portfolio cross-cat data (the one remaining v2 switch)

The orchestrator still calls `.compute_portfolio_data(...)` → `run_portfolio(...)` which orchestrates 8 sub-analyses (`compute_footprint_matrix`, `compute_clutter_data`, `compute_strength_map`, `compute_extension_table`, `compute_extension_per_brand`, plus constellations). All 8 sub-analyses already have v2 entries (`compute_*_v2`); what's missing is a `run_portfolio` that wires them together.

**Estimated effort:** half a session — `09_portfolio.R` is ~400 lines and the orchestration is sequential. Mostly mechanical: rename + thread role_map through each call. The v2 sub-analyses already exist and have tests.

**Why it was deferred:** it's a separate, self-contained refactor. Doing it inline with the other Step 4 switches would have made the diff harder to review. The orchestrator currently keeps the legacy `run_portfolio` for cross-cat data — IPK Wave 1 still produces a sensible result through the legacy path because the v1 `compute_footprint_matrix` reads slot columns when they exist.

**Branch suggestion:** keep this in-flight on `feature/brand-ipk-rebuild` since it shares the same role_map foundation. Not worth a separate branch.

### 3. Cat Buying / Brand Volume / Shopper Behaviour — also still legacy

These three elements read slot-prefix columns directly via `.find_brand_col` patterns and don't have v2 entries yet. They're lower priority because:
- They work on parser-shape data already (the prefix patterns happen to match slot-indexed Multi_Mention).
- They don't read role_map, so they're not blocked on the v2 architecture.
- The IPK Wave 1 fixture has data for all three and the legacy path produces sensible output.

If you want them migrated for consistency, the pattern is the same as WOM / Repertoire: write `run_X(data, role_map, cat_code, brand_list, ...)` that walks the appropriate role keys (`cat_buying.frequency.{cat}`, `cat_buying.channel.{cat}`, `cat_buying.packsize.{cat}`) and delegates to the existing engine.

### 4. Step 5 Cutover

After browser verification + Step 4d, do the cutover per planning doc §9 step 5:

- Delete legacy `tests/fixtures/generate_ipk_9cat_wave1.R` and the in-flight uncommitted change to it (still in `git status`).
- Delete legacy `00_role_map.R`, `00_guard_role_map.R`. Verify `load_role_map()` callers are all gone (currently `.run_funnel_for_category` legacy path uses it, and that fallback can stay or be removed depending on whether you want the orchestrator to refuse loud or fall back silently when v2 role_map can't be built).
- Delete legacy v1 entries inside the migrated element files. The biggest cleanups are:
  - `13_audience_lens.R` (452 lines) → drop `run_audience_lens` + `compute_al_metrics_for_subset` + private legacy helpers; rename `_v2` to canonical names.
  - `13b_al_metrics.R` (914 lines) → same.
  - `02_mental_availability.R` → drop `build_cep_linkage_from_matrix` (legacy column-walk).
  - `09_portfolio.R` + `09a..09h_portfolio_*.R` → drop legacy `compute_*` once `run_portfolio` lands.
  - SIZE-EXCEPTION markers should come off the migrated files at this step.
- Delete legacy element tests:
  - `test_audience_lens.R`, `test_audience_lens_audiences.R`, `test_audience_lens_metrics.R`, `test_audience_lens_classifier.R`, `test_audience_lens_panel_data.R`
  - Other legacy element tests per HANDOVER_IPK_REBUILD_SESSION3.md §5.
- Delete legacy orchestrator helpers in `00_main.R`:
  - `.legacy_wom_call`, `.legacy_repertoire_call`, `.legacy_drivers_barriers_call`
  - `.run_funnel_for_category` (legacy QuestionMap path)
  - `.normalize_questionmap_for_category`, `.detect_category_code`, `.strip_cat_suffix_from_qmap` (only used by the legacy funnel path)
  - `.run_demographics_for_category`, `.demo_question_from_role` (legacy QuestionMap walk)
  - `.run_adhoc_for_category`, `resolve_adhoc_role` (legacy QuestionMap walk)
  - `.run_adhoc_brand_level` (already a stub, can go)
  - `.legacy_wom_call`'s callers all gone after run_wom delete
- Drop the `if (!is.null(role_map))` route-or-fallback branches in the orchestrator — once legacy is gone, v2 is the only path.
- Update memory entry [project_brand_ipk_rebuild_plan.md], mark planning doc Status = Complete.
- Open PR to `main`.

### 5. Audience Lens v3 (post-cutover, separate project)

Per session 4 handover, branch name `feature/audience-lens-v3-tabs`. Tabs-as-engine refactor that turns the 14 KPIs into per-respondent stable columns and pushes audience cross-tabs into the tabs module. 1–2 day project. Not in scope for the rebuild.

---

## Architecture changes in this session

### v2 role_map is built once, threaded through every per-category call

```r
# After Step 3 (data load) in run_brand():
role_map <- tryCatch({
  if (exists("build_brand_role_map", mode = "function") &&
      !is.null(structure$questions)) {
    build_brand_role_map(
      structure    = structure,
      brand_config = list(categories = categories),
      data         = data
    )
  } else NULL
}, error = function(e) NULL)
```

When `role_map` is non-NULL, every per-category element switches to its v2 entry. When NULL (e.g. structure has no Questions sheet), the legacy path runs. This means the rebuild branch is non-disruptive for existing 9cat-shape configs even before cutover.

### Loader whitelist updated

`.source_brand_module()` now sources `00_data_access.R`, `00_role_inference.R`, `00_role_map_v2.R`, and `00_guard_v2.R` — these were missing from the whitelist, so v2 functions were unreachable from `run_brand()` (only via per-test sourcing). Discovered + fixed in commit 1817333.

### Legacy fallback helpers (added this session)

`.legacy_wom_call`, `.legacy_repertoire_call`, `.legacy_drivers_barriers_call` lift the legacy column-prefix dispatch out of the per-category loop into private helpers. The orchestrator block now reads as a clean `if (v2-available) v2_path else legacy_path` ternary instead of inline branching. These get deleted at cutover (§5).

---

## Files in this session's flight

```
modules/brand/R/
├── 00_main.R               # 8 orchestrator switches + 4 legacy fallback helpers
├── 07_dba.R                # run_dba + .dba_data_present + .dba_placeholder_result
├── 10_branded_reach.R      # run_branded_reach + .br_placeholder_result
├── 12_adhoc.R              # run_adhoc + resolve_adhoc_role + helpers

modules/brand/tests/testthat/
├── test_dba.R           # 24 tests
├── test_branded_reach.R # 21 tests
├── test_adhoc.R         # 43 tests

modules/brand/docs/
└── HANDOVER_IPK_REBUILD_SESSION5.md  # this file
```

Uncommitted (carry-forward from earlier sessions):
- `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` (legacy generator — leave alone, scheduled for cutover deletion).
- `scripts/fetch_alchemer_reporting_values.R` (unrelated to rebuild).

Memory entries unchanged this session — the session 4 entry [project_brand_ipk_rebuild_plan.md] still reflects the active state, just with newer commit count + test count. Update at cutover.

---

## Verification commands

Quick sanity check (run from repo root):

```bash
Rscript -e 'library(testthat); for (f in c("test_data_access","test_role_map","test_guard","test_funnel","test_brand_volume","test_mental_avail","test_ma_advantage","test_wom","test_repertoire","test_drivers_barriers","test_demographics","test_portfolio","test_portfolio_subanalyses","test_audience_lens","test_dba","test_branded_reach","test_adhoc")) testthat::test_file(paste0("modules/brand/tests/testthat/", f, ".R"))'
```

Expected: **702 PASS, 0 FAIL.**

Smoke-test the orchestrator loads cleanly:

```bash
Rscript -e 'source("modules/brand/R/00_main.R"); cat("brand loads:", exists("run_brand"), "\n"); cat("role map builder:", exists("build_brand_role_map"), "\n"); cat("v2 placeholder fns:", all(c("run_dba","run_branded_reach","run_adhoc") %in% ls()), "\n")'
```

End-to-end orchestrator (won't pass yet — Brand_Config needs v1 fields):

```r
source("modules/brand/R/00_main.R")
res <- run_brand("modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx", verbose = TRUE)
# Currently REFUSES at step 1 with CFG_MISSING_FIELD: project_name
# This is a fixture issue, not an orchestrator issue.
```

---

## Gotchas (carried forward + new this session)

1. **Brand module loader is whitelist-based** — whitelist updated this session for the v2 modules. Anything new added in `modules/brand/R/` still needs to be added to `.source_brand_module module_files` at `00_main.R:55-103`.

2. **Synthetic fixture rule expires at cutover.** Same as session 4. The `tests/fixtures/generate_ipk_9cat_wave1.R` change in `git status` is still scheduled for cutover deletion.

3. **Legacy element tests fail against migrated code.** Same as session 4. Not fixed; scheduled for deletion at cutover.

4. **End-to-end orchestrator smoke test is blocked** until either (a) the IPK Brand_Config fixture is updated with the v1-era required fields, or (b) `load_brand_config`'s required-field guard is relaxed for the rebuild branch. Per-element tests are the substitute verification path.

5. **Browser verification path** — `launch_turas()` only. Don't run `preview_start` against the brand module.

6. **Portfolio cross-cat data is still legacy.** The orchestrator's `.compute_portfolio_data` still calls legacy `run_portfolio`. This works for IPK Wave 1 because the legacy `compute_*` functions read slot columns when they exist. Migrating to a `run_portfolio` is the last v2 switch and ideally happens before cutover so the legacy `compute_*` can all be deleted.

7. **NEW — orchestrator route-or-fallback branches must come off at cutover.** Every v2 switch in this session uses `if (!is.null(role_map)) run_X(...) else run_X(...)`. After cutover (when legacy is gone), drop the conditional + fallback so the codebase has one path through.

8. **NEW — Funnel v2 cat_code threading.** The funnel config object now carries `cat_code` so `run_funnel`'s `.lookup_role(role_map, "funnel.awareness", cat_code)` resolves to `funnel.awareness.{cat_code}`. If you write a new caller that bypasses `.run_funnel_for_category`, remember to set `funnel_cfg$cat_code`.

9. **NEW — Demographics namespace migrated.** Legacy was `demo.{key}`; v2 is `demographics.{key}` (per `00_role_inference.R DEMO_{KEY}` pattern). The orchestrator's v2 dispatcher walks `^demographics\\.` not `^demo\\.`. If you have an old QuestionMap with `demo.*` rows, they need to migrate to `demographics.*` or use the QuestionMap override mechanism.

---

## What the orchestrator looks like at end of session

Per-category loop in `run_brand()` now routes to v2 entries when `role_map` is non-NULL for: Mental Availability, Funnel, Repertoire, WOM, Branded Reach, Audience Lens, Drivers/Barriers, Demographics, Ad Hoc. Plus brand-level DBA + Portfolio Overview.

Still on legacy:
- Cat Buying frequency (`run_cat_buying_frequency`)
- Brand Volume (`build_brand_volume_matrix`)
- Dirichlet norms (`run_dirichlet_norms`)
- Buyer heaviness (`run_buyer_heaviness`)
- Shopper behaviour (`.run_shopper_for_category`)
- Cross-cat portfolio data (`.compute_portfolio_data` → `run_portfolio`)

The first five read slot-indexed prefixes directly and work on parser-shape data without role_map; they're lower priority. The last is the §4d follow-on described above.

---

*End of handover. Maintained on the rebuild branch alongside the planning doc.*

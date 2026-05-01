# Handover — Port legacy funnel tests to v2-shaped fixtures

**Date opened:** 2026-05-01
**Branch:** `feature/brand-ipk-rebuild` — work directly on the rebuild branch. Duncan's plan is to land the funnel test port + the rebuild together in one PR to `main`, not two separate PRs. **Do NOT branch from `main` and do NOT branch from `feature/brand-ipk-rebuild`.** Just `git pull` on `feature/brand-ipk-rebuild` and commit the funnel-port commits straight onto it.
**Recommended model:** Sonnet — bounded-scope mechanical port against an established pattern

---

## What this is

The IPK rebuild (`feature/brand-ipk-rebuild`) migrated the brand module's funnel from a column-per-brand legacy shape (`BRANDAWARE_DSS_IPK = 1`) to slot-indexed parser-shape data (`BRANDAWARE_DSS_1` cells holding brand codes). The migration happened in-place — `run_funnel()` now requires `funnel_cfg$cat_code` so it can resolve `funnel.awareness.{cat_code}` via the role registry.

Eight legacy funnel test files **were not deleted at cutover**. They are still on disk, still failing (114 failed assertions across them), and pin the pre-migration `run_funnel()` API. This is intentional and tracked — at cutover the team chose to ship the rebuild rather than delay it on a test port. Browser verification on IPK Wave 1 plus the v2 unit tests cover the catastrophic risks; the legacy tests cover granular invariants that need a proper port.

Your job: convert these eight tests to use slot-indexed fixtures and the new `cat_code`-aware API, so the funnel's granular invariants are back under test. Then delete the legacy versions.

---

## The 8 files in scope

Located in `modules/brand/tests/testthat/`:

| File | What it tests | Why it currently fails |
|---|---|---|
| `test_funnel_durable.R` | Durable category type (cars, banks) with tenure threshold; hand-calculated counts on a 10-respondent fixture | Calls `run_funnel()` without `cat_code` |
| `test_funnel_edge_cases.R` | NAs, empty data, weight mismatches, boundary values | Same |
| `test_funnel_service.R` | Service category type | Same |
| `test_funnel_transactional.R` | Transactional/FMCG category type | Same |
| `test_funnel_integration.R` | Multi-function integration of derive → metrics → output | Same |
| `test_funnel_output.R` | Excel + CSV output writers | Hooks into legacy result shape |
| `test_funnel_panel_data.R` | JSON panel payload builder | Same |
| `test_funnel_panel_table.R` | HTML panel table renderer | Same |

Total: ~250 test assertions, mostly hand-checked known-answer tests with documented expected values inline.

---

## What "v2-shaped" means here

Each fixture currently writes column-per-brand data:

```r
# Legacy: one column per brand, value = 1 if aware
data <- data.frame(
  BRANDAWARE_DSS_IPK = c(1, 1, 0, 1),
  BRANDAWARE_DSS_ROB = c(0, 1, 1, 1),
  BRANDAWARE_DSS_CART = c(1, 1, 0, 0),
  ...
)
```

Convert to slot-indexed:

```r
# v2: slot columns hold the brand codes the respondent picked
data <- data.frame(
  BRANDAWARE_DSS_1 = c("IPK", "IPK", "ROB", "IPK"),
  BRANDAWARE_DSS_2 = c("CART", "ROB", "CART", "ROB"),
  BRANDAWARE_DSS_3 = c(NA,    "CART", NA,    NA),
  ...
)
```

Same data; different shape. The hand-calculated expected counts should be **identical** since they're derived from the same underlying truth (who is aware of which brand). If they're not identical after porting, the fixture conversion is wrong.

The funnel reads this via `respondent_picked()` and friends in `modules/brand/R/00_data_access.R` — a slot-aware reader that resolves the awareness root from `role_map`. The role map needs to point to the convention root (`BRANDAWARE_DSS`).

---

## API change you need to thread

Old signature (what these tests use):
```r
run_funnel(data, funnel_cfg, brand_list, ...)
```

New signature (what these tests need):
```r
funnel_cfg$cat_code <- "DSS"   # NEW — required field
run_funnel(data, funnel_cfg, brand_list, role_map, ...)
```

`role_map` is a list keyed by `funnel.awareness.{cat_code}` etc. Easiest way to build one for a test fixture: hard-code it, e.g.

```r
role_map <- list(
  funnel.awareness.DSS = list(column_root = "BRANDAWARE_DSS",
                              variable_type = "Multi_Mention"),
  funnel.attitude.DSS  = list(column_root = "BRANDATT1_DSS",
                              variable_type = "Single_Response_Brand")
)
```

`test_funnel.R` (already in repo) shows the exact pattern — read it first; treat it as your template.

---

## Recommended approach

1. **Read the template first.** `modules/brand/tests/testthat/test_funnel.R` is the established v2 shape. Note how it sources `00_data_access.R` and `00_role_inference.R`, builds an in-memory role map, and threads `cat_code` through. Don't invent a different pattern.

2. **Port one file at a time.** Start with `test_funnel_transactional.R` since transactional is the simplest category type (no tenure threshold). Get it green, commit. Then `test_funnel_service.R` (next-simplest). Then `test_funnel_durable.R` (tenure threshold adds one extra column to the fixture). Then the four "support layer" files (output, panel_data, panel_table, edge_cases, integration).

3. **Verify hand-calculated counts unchanged.** Each legacy fixture has a comment block at the top listing the expected counts (e.g. `Aware: IPK=9 ROB=8 CART=7`). After porting the fixture, those numbers must hold. If they don't, you've made a fixture-translation error — go back, don't change the expected values to match a buggy port.

4. **Delete the legacy file once its v2 replacement is green** (rename `test_funnel_durable.R` → … well, the v2 test file already exists, so add the durable category-type tests as new `test_that()` blocks inside `test_funnel.R`). Choose: one big `test_funnel.R` or per-category-type files (`test_funnel_durable.R` etc). Either is fine; match what the rest of the v2 suite does.

5. **The IPK rebuild's Stage 6 already renamed `_v2` → canonical** (e.g. `run_funnel_v2` → `run_funnel`, `compute_extension_table_v2` → `compute_extension_table`). Function names in the codebase are now canonical. Two engines kept their `_v2` wrappers because the canonical name is held by the analytics engine they delegate to: `run_repertoire_v2` and `run_drivers_barriers_v2` — but neither matters for funnel tests.

---

## Verification gates

Before opening the PR for this work:

- [ ] All 8 legacy files deleted from `modules/brand/tests/testthat/`
- [ ] Equivalent assertions exist in `test_funnel.R` (or new per-category-type files alongside it) — every hand-calculated count from the legacy fixtures has a corresponding `expect_equal()` in the new suite
- [ ] Full brand test suite green: `Rscript -e 'library(testthat); for (f in list.files("modules/brand/tests/testthat", "^test_.*[.]R$", full.names = TRUE)) testthat::test_file(f)'` — expect 0 failures, 1288+ pass
- [ ] End-to-end smoke still PASS: `Rscript -e 'source("modules/brand/R/00_main.R"); res <- run_brand("modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx", verbose = FALSE); cat("status:", res$status, "\n")` — expect `status: PARTIAL` (DSS deep-dive PASS, others empty as before)

---

## Out of scope

- Don't refactor the funnel engine itself. The migration was done; the engine is correct and verified by browser verification. This task is **tests only**.
- Don't add new tests beyond porting the legacy coverage. If a gap exists in the legacy coverage, file it as a separate follow-up.
- Don't touch the canonical funnel source files (`03_funnel.R`, `03a-d_funnel_*.R`) — only the test files in scope.

---

## Why this was deferred

Per `HANDOVER_IPK_REBUILD_SESSION5.md` §5, the cutover plan listed deletion of the legacy element tests as a single step. For seven of the eight migrated elements (audience_lens, adhoc, branded_reach, dba, demographics, drivers_barriers, mental_availability, mental_advantage, repertoire, wom, the 8 portfolio sub-tests), the v2 test files already had equivalent or better coverage so deletion was clean. For funnel, `test_funnel.R` had only 4 high-level test blocks against the legacy 8 files' ~250 assertions. Deleting them at cutover would have been a real coverage loss with no replacement, so the team chose to ship the rebuild and port the funnel tests separately.

The cutover commit calls this gap out explicitly. Until this port lands, the brand test suite has 114 expected failures all in the funnel test files. They're easy to filter out: `[name match: ^test_funnel_(durable|edge_cases|integration|output|panel_data|panel_table|service|transactional)$]`.

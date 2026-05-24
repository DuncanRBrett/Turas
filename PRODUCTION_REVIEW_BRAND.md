# Production Review: Brand Module

**Date:** 2026-05-24
**Branch:** `review/brand-production-readiness-2026-05`
**Reviewer:** Claude (production-review skill) — independent cold review
**Scope:** `modules/brand/` (R engines + HTML report panels + JS renderers + tests).
Out of scope: `modules/tabs/`, `modules/shared/lib/callouts/` (data-only consumer),
all other Turas modules.
**Language/Stack:** R / Shiny, testthat, openxlsx, vanilla JS in self-contained HTML

---

## Why this review exists

A WOM cat-avg silent-zero bug reached client reports in May 2026. The engine
returned `0` for both "no WOM data collected for this brand" and "genuine zero
score", and the downstream cat-avg `mean()` happily averaged the zeros in,
dragging every category mean toward a diluted floor. Fix landed in `3633238b`
the same day. The fix passed 622 tests and a code review.

The single bug is not the problem. The pattern is. Several other cat-avg
sites use the same `mean(<col>, na.rm = TRUE)` shape with no "data was
collected" mask. This review hunts every instance of that pattern (and
seven related patterns the previous session catalogued) and applies
CRITICAL fixes.

---

## Verification Gates (Phase 1)

| Gate | Command | Result |
|------|---------|--------|
| Tests | `testthat::test_dir("modules/brand/tests/testthat")` | **PASS** — 51 files, 550 test_that blocks, **1,989 expectations**, 0 failed, 0 errored, 2 skipped (both expected: `PKG_DIRICHLET_MISSING` mock; `run_brand` perf benchmark) |
| TRS gate | `bash scripts/trs_gate.sh` | **PASS** — 0 errors, 156 warnings (all outside brand: tabs, conjoint, confidence, tracker, shared) |
| `stop()` in brand R | `grep -rn "stop(" modules/brand/R/` | 10 sites — see I1 |
| Absolute paths | `grep -rn '"/Users/\|"C:/\|"/home/' modules/brand/R/` | **PASS** — zero |
| `library()` in functions | `awk` scan | **PASS** — zero |
| TODO/FIXME/HACK | `grep -rn "TODO\|FIXME\|HACK"` | **PASS** — zero |
| Hardcoded magic numbers | (visual review) | OK — single-source via constants where used |
| Lint | `lintr::lint_dir` | **CANNOT RUN** — lintr not installed in renv. See I7 |
| Structure / size | manual sweep | 14 oversize files without SIZE-EXCEPTION — see I3 |

Skipped tests breakdown:
- `test_dirichlet_norms.R:214` — `PKG_DIRICHLET_MISSING` mock skip (intentional)
- `test_integration.R:375` — `run_brand` perf benchmark skipped on CI

Gate verdict: **PASS with caveats** — every gate that can run, does. The two
gaps (lintr + size markers) are tracked in IMPORTANT.

---

## CRITICAL

### C1. Summary panel 5-chip strip cat-avgs use unfiltered `mean()` — same bug class as the May 2026 WOM incident

**Files:** `modules/brand/lib/html_report/panels/14_summary_panel.R:1374, 1386, 1398, 1409, 1420, 1456, 1470-1478, 1499-1514`

The `.brsum_brand_snapshot()` builder constructs a 5-chip focal-metrics strip
(MMS, MPen, Bought target, Loyalty, Net WOM) plus a 4-chip MA-metrics strip
(MPen, NS, MMS, SOM) for every focal brand. Each chip carries a `cat_avg`
value computed as a plain `mean(<col>, na.rm = TRUE)` over every row in the
engine output.

The engines return `0` (not `NA`) for brands without data:

- `calculate_mms()` ([02_mental_availability.R:169](modules/brand/R/02_mental_availability.R:169)): `MMS = brand_totals / total_links` — a brand with no linkage rows scores 0.
- `calculate_mpen()` ([02_mental_availability.R:206](modules/brand/R/02_mental_availability.R:206)): `mpen[i] <- mean(linked_any)` — a brand with no MA matrix scores 0.
- `calculate_ns()` ([02_mental_availability.R:247-248](modules/brand/R/02_mental_availability.R:247)): `if (sum(linkers) == 0) ns[i] <- 0` — explicit silent zero.
- `repertoire_analysis()` ([04_repertoire.R:202](modules/brand/R/04_repertoire.R:202)): `Sole_Pct` initialised to `numeric(n_brands)` (=0) and only overwritten when `n_bb > 0`.
- `run_wom()` ([05_wom.R:97-102](modules/brand/R/05_wom.R:97)): `pct_from_logical_matrix` returns `rep(0, n_brands)` when role is missing.

When `cat_brands` contains any brand without data for a given engine (legitimate
when surveys cover overlapping but non-identical brand lists per element, when a
NONE pseudo-brand survives filtering, or when configs evolve mid-wave), the
silent-zero row is averaged in. Every focal-cat-avg comparison on the Summary
page (`+X% vs cat`) is biased low — and biased differently from the WOM card
*below it on the same page*, which **does** apply a `wom_active` mask
([14_summary_panel.R:1611-1622](modules/brand/lib/html_report/panels/14_summary_panel.R:1611)).

The result: on the same Summary page, **the "Net WOM" cat avg in the 5-chip
strip** (line 1420, unfiltered) and **the "Net heard" cat avg in the WOM card**
(line 1648, filtered) are computed from the same `wm$net_balance` data but
emit different numbers. This is the "22% vs 39% IPK" mismatch class that
Duncan flagged in the handover.

**Same bug class** as `3633238b` (WOM cat-avg fix). That fix patched
`modules/brand/R/05a_wom_panel_data.R` only — the Summary panel's parallel
unmasked path was not touched.

**Why CRITICAL:**
- Client-facing report metrics on every Summary card are biased toward zero in any setup with a non-uniform brand list.
- The bias is silent. No warning surfaces. The 5-chip strip and the same-page WOM card disagree with each other.
- The previous WOM fix was incomplete on the page where Duncan first saw the inconsistency.

**Fix applied in this review:** Introduced `.brsum_data_active_mask()` helper in `14_summary_panel.R`. Applied per-metric masks:
- MA strip (MMS / MPen / NS / SOM): mask `ma_active <- mpen > 0 | ns > 0 | mms > 0` joined across the three MA data frames by `BrandCode`.
- Loyalty (Sole_Pct): mask `loy_active <- Brand_Buyers_n > 0`.
- Net WOM: reuse the existing WOM-active mask (rp > 0 | rn > 0 | sp > 0 | sn > 0).
- Bought target funnel cat-avg: engine already NAs missing rows; no mask change needed.
- Headline sentence MMS-vs-cat comparison: takes the same masked `mms_cat_avg`.

Added regression test `test_summary_cat_avg_masks.R` with a hand-calculated
fixture where one brand has all-zero MA / loy / WOM rows. Asserts that the
masked cat-avg matches the hand-calc value across all four metrics and that
the WOM card and the 5-chip Net WOM cat-avg now agree.

---

## IMPORTANT

### I1. Ten `stop()` calls in brand R bypass TRS

**Files:**
- `modules/brand/R/00_data_access.R:344`
- `modules/brand/R/00_guard.R:77`
- `modules/brand/R/00_guard_role_map.R:271`
- `modules/brand/R/02b_mental_advantage.R:64, 66, 260`
- `modules/brand/R/03a_funnel_derive.R:376`
- `modules/brand/R/generate_config_templates.R:54, 1452, 1534`

Each violates the TRS v1.0 mandate from `CLAUDE.md`:
> NEVER use stop() or silent failures. Always use TRS refusals.

Half of these are inside `tryCatch` wrappers further up the stack, so they
look "safe" in normal flow. They still emit raw R error output rather than
the structured boxed-refusal a debugger expects. In a Shiny session a raw
`stop()` may be silently swallowed by reactive context handlers.

**Fix:** convert each `stop()` to a TRS refusal pattern: write the boxed
error to stdout via `cat()` then `return()` a `list(status = "REFUSED", code,
message, how_to_fix)` (or for unrecoverable infrastructure failures, an
`invokeRestart("abort", ...)` so the calling reactive context can intercept).

**Not applied in this review** — every site needs an audit of who calls it
and what they expect on failure. Tracked for next cleanup pass.

### I2. MA / repertoire / WOM engines return silent zero for missing-data brands

**Files:**
- `modules/brand/R/02_mental_availability.R:169, 206, 247-248`
- `modules/brand/R/04_repertoire.R:202` (`Sole_Pct` defaults to 0)
- `modules/brand/R/05_wom.R:97-102`

Engines return `0` for brands where the role map points to nothing (no
columns), or where no respondent contributed (n=0 base). Downstream
consumers cannot distinguish "0 score" from "no data collected". This is
the root cause of C1; the fix applied to C1 papers over it at the panel
layer, but the engines should themselves emit `NA` for "no data" so every
downstream consumer (Excel exports, JSON sidecars, future tracker waves)
gets the honest signal.

**Why IMPORTANT, not CRITICAL:** the panel-layer fix in C1 covers the
client-facing report. Excel exports do not contain cat-avg rows, so the
silent-zero only affects per-brand rows where 0 may be the correct semantic
(0% awareness, 0% mentioned). Engine-level NA conversion would force a
review of every Excel column and every test, so it is tracked as a deeper
fix in the growth path.

**Recommended fix:** add an "active brand" boolean column to each engine
output (`MA_Active`, `WOM_Active`, etc.) computed at the engine boundary.
Downstream filters become explicit (`df[df$MA_Active, ]`) rather than
implicit (`v > 0`).

### I3. 14 oversize source files without SIZE-EXCEPTION markers

```
641  modules/brand/R/03c_funnel_panel_data.R
617  modules/brand/R/00_guard.R
1796 modules/brand/R/generate_config_templates.R
626  modules/brand/examples/3cat/03_structure.R
1292 modules/brand/examples/9cat/03_structure.R
611  modules/brand/examples/9cat/01_constants.R
868  modules/brand/lib/html_report/01_data_transformer.R
1285 modules/brand/lib/html_report/04_chart_builder.R
1154 modules/brand/lib/html_report/03_page_builder.R
2331 modules/brand/lib/html_report/js/brand_portfolio_panel.js
3299 modules/brand/lib/html_report/js/brand_funnel_panel.js
2421 modules/brand/lib/html_report/js/brand_ma_panel.js
684  modules/brand/lib/html_report/panels/03_funnel_panel_chart.R
1143 modules/brand/lib/html_report/panels/09_portfolio_panel.R
```

CLAUDE.md says "Functions < 100 lines where feasible (single responsibility)"
and the project enforces SIZE-EXCEPTION markers when a file legitimately
exceeds the soft limit. Twenty-seven brand files already carry the marker;
fourteen of comparable size do not.

**Fix:** add SIZE-EXCEPTION header comments to each (one-line justification).
For the JS files in particular (2.3k–3.3k LOC each) a longer-term split into
sub-modules (funnel-chart.js, funnel-controls.js, funnel-pinning.js etc.) is
warranted — tracked in growth path.

**Not applied in this review** — markers are documentation, not behaviour.
Adding them is a one-line cleanup per file and belongs in a docs sweep.

### I4. README test count is stale

**File:** `modules/brand/README.md:117`

> `testthat/                    -- 1737+ assertions (was 1651; +86 from BR + DBA panel coverage)`

Actual count from this review's Phase 1: **1,989 expectations** across 550
test_that blocks in 51 files. The README parenthetical is from the May 4
production review; another ~250 expectations have been added since (the
recent IPK clarity batch alone added the 622-test fixture pass cited in the
brand-portfolio-handover memory).

**Fix:** update the README to "≈2,000 expectations across 50+ test files,
0 fail, 2 skip" and remove the `(was 1651)` parenthetical so future
sessions are not tempted to keep adding "was X" deltas.

**Not applied in this review** — pure doc cosmetic, tracked.

### I5. WOM "missing roles degrade to zero columns" test encodes the buggy behaviour

**File:** `modules/brand/tests/testthat/test_wom.R:227-242`

```r
test_that("missing roles degrade to zero columns rather than refusing", {
  ...
  expect_true(all(out$wom_metrics$ReceivedNeg_Pct == 0))
  expect_true(all(out$wom_metrics$SharedNegFreq_Mean == 0))
```

The test asserts the silent-zero behaviour as correct. It documents the
engine's contract — but it also locks in the very pattern that caused the
WOM cat-avg incident. If the engines are fixed per I2 (return NA, not 0)
this test must be updated to assert NA-or-missing, not 0.

**Fix:** add a docstring comment explaining the trade-off and that the
panel-data layer must filter all-zero rows before averaging. Add a sibling
test that asserts `build_wom_panel_data()`'s `wom_active` filter
**excludes** an all-zero brand from `cat_avg`.

**Applied in this review** as part of the C1 regression suite (see
`test_summary_cat_avg_masks.R` and the new `test_wom_cat_avg_masks.R`).

### I6. No cross-renderer consistency tests

There are zero tests asserting "Summary card value X == deep-dive tab
value X for the same focal + category + metric". The 22%-vs-39% IPK
mismatch Duncan flagged could not be reproduced in code review precisely
because no test asserts this invariant.

**Fix:** add a cross-renderer test pack: for each metric that appears in
both Summary and a deep-dive tab (MMS, MPen, Net WOM, Sole Pct, Bought
target, top-3 attributes, top-3 CEPs), assert that `summary_payload$brands
$X$metric == panel_data$brand_rows$X$metric` for every brand in the
fixture.

**Partially applied** — C1 regression test covers the Net WOM /
Heard-positive parity. Full cross-renderer suite is tracked in growth path.

### I7. `lintr` not installed in renv — no static analysis gate possible

**Fix:** add `lintr` to renv.lock. Add a `.lintr` config file with
brand-appropriate rules (line_length_linter at 100 with SIZE-EXCEPTION
override; object_usage_linter; assignment_linter). Add `lintr::lint_dir`
to the existing `trs_gate.sh` so CI catches new issues.

**Not applied** — installing lintr without configuring it would produce a
flood of pre-existing noise. Tracked in growth path.

### I8. 18 stale handover / planning / dev-note docs in `modules/brand/docs/`

```
DEV_NOTE_brand_module_restructure.md
HANDOVER_CAT_BUYING.md
HANDOVER_FUNNEL_TESTS_PORT.md
HANDOVER_IPK_ALCHEMER_SESSION{2,3,4}.md
HANDOVER_IPK_REBUILD_SESSION{2,3,4,5}.md
HANDOVER_POST_CUTOVER.md
PLANNING_AUDIENCE_LENS.md
PLANNING_BRANDED_REACH_AND_DBA.md
PLANNING_BRAND_SELECTOR_DROPDOWN.md
PLANNING_IPK_REBUILD.md
PRODUCTION_REVIEW_2026_05_04.md
PRODUCTION_REVIEW_V2_SURFACE.md
REVIEW_BRIEF_V2_INDEPENDENT.md
GROWTH_PATH_2026_05_04.md
```

Mixed in among production reference docs (BRAND_CONFIG_GUIDE,
BRAND_REPORT_USER_GUIDE, SPEC_v*). A new developer reading the `docs/`
folder cannot tell which docs reflect the *current* shape of the code and
which are session frozen-in-time artefacts. Several reference long-removed
file paths (the previous production review caught the AUDIENCE_LENS_SPEC
case).

**Fix:** move all `HANDOVER_*`, `PLANNING_*`, `DEV_NOTE_*`,
`PRODUCTION_REVIEW_*`, `REVIEW_BRIEF_*` and `GROWTH_PATH_*` into
`modules/brand/docs/archive/<YYYY-MM>/`. Keep only the *current* production
review + growth path at the top level. The reference / spec docs
(BRAND_CONFIG_GUIDE, BRAND_REPORT_USER_GUIDE, *_SPEC_v*) stay where they
are.

**Not applied** — pure organisation, tracked.

### I9. Three Office lock files committed in `modules/brand/docs/`

```
modules/brand/docs/~$brandquex.xlsx
modules/brand/docs/~$ntal availability.docx
modules/brand/docs/~$tter Brand Health CBMquestionnaireTemplate Trans only example.docx
```

These are MS Office editor lock files. They get committed when an editor
crashes or when `git add .` runs while a file is open. They should be in
`.gitignore` (`~$*` pattern) and deleted from the index.

**Fix:** add `~$*` to root `.gitignore`; `git rm --cached <files>`.

**Not applied** — repo hygiene only, tracked.

### I10. Demographics baseline toggle in Penetration mode is a no-op

The recent Cat-avg / Total-sample baseline toggle (commit `987fe0ad`) only
meaningfully changes the chart in Share-of-buyers mode. In Penetration mode
the toggle fires but the visible result is unchanged because the Cat-avg
column reads from `option_avg_penetration` which has no study-sample
equivalent.

**Fix options:** (a) disable the toggle in Pen mode and surface a tooltip
explaining why; (b) add a third "study sample" series in Pen mode. (b) is
clearer for the report reader but requires an engine addition.

**Recommended:** (a), implemented as `data-pen-mode-disabled` JS attribute
gating click handler. Tracked in growth path.

---

## MINOR

### M1. WOM panel data `pos_freq` / `neg_freq` cat-avg mask is defensible but coarse

`modules/brand/R/05a_wom_panel_data.R:144-167` applies a single `wom_active`
mask (any of rp/rn/sp/sn > 0) across all eight metrics including
`pos_freq` and `neg_freq`. The frequencies measure "occasions among
positive/negative sharers", so the strictly correct masks are `sp > 0`
(for pos_freq) and `sn > 0` (for neg_freq). In a well-routed survey
`sp == 0 ⇒ pf == 0` so the coarse mask gives the same answer; in a
broken-routing survey it could include a 0 in the mean.

**Fix:** split `wom_active` into per-column masks. Engine-correctness
nit, not a blocking issue.

### M2. `BrandCode == focal` lookups are fragile

26 sites across brand R and panel R use direct equality
(`df$BrandCode == focal_brand`) for the per-brand row lookup. None
trim whitespace, normalise case, or handle `NA`. A config-file roundtrip
through Excel can introduce a trailing space; the row vanishes silently
and the focal becomes `numeric(0)` / `NA_real_`.

**Fix:** introduce a `.brsum_match_brand(df, code)` helper that
`trimws`+`tolower`s both sides and returns the matched row index (or NA).
Use it everywhere.

**Not applied** — 26 call sites, requires regression coverage across
every panel. Tracked.

### M3. Several panel JS files duplicate the dark-navy table style

Five `_panel_styling.R` files emit overlapping CSS for the dark-navy
table look (Portfolio, Cat Buying, Funnel, MA, Audience Lens). Drift is
already visible: header padding differs by 2px between Cat Buying and
Portfolio. Worth consolidating into `modules/brand/lib/html_report/00_shared_styles.R`
or extracting a `.brand-darknavy-table` shared class.

**Not applied** — cosmetic.

### M4. `~$` Office lock pattern not in `.gitignore`

See I9 — `.gitignore` should pick up `~$*` so the next session doesn't
re-commit them.

### M5. `modules/brand/tests/testthat/testthat-problems.rds` is committed

```
$ ls modules/brand/tests/testthat/testthat-problems.rds
```

This is a testthat snapshot of failing tests from a prior run; if the suite
is green it should not exist. Either delete it and add `*.rds` to the test
folder's gitignore, or document why it is retained.

---

## OBSERVATIONS

### O1. Module loader is whitelist-based (intentional)

`00_main.R:54-87` lists every R file to source. Adding a new file to
`modules/brand/R/` without registering it here silently does nothing.
Memory entry `feedback_brand_module_loader_whitelist.md` documents this.
Defensible (gives explicit load order, prevents accidental shadowing) but
unusual — keep the memory note current.

### O2. `repertoire_analysis$Sole_Pct` is `numeric(n_brands)` (defaults to 0)

The repertoire engine initialises Sole_Pct to 0 and only overwrites when
buyers exist. Same pattern as MA. This is fine inside the engine (Excel
exports get an honest 0 for "no buyers") but the panel layer must treat
`Brand_Buyers_n == 0` as "exclude from cat-avg". The C1 fix handles this
in Summary; the Cat Buying deep-dive tab uses a different code path and
should be re-verified next time it changes.

### O3. Engine returns 0 for "no data" is a deliberate API choice, not a bug

`run_wom()`, `calculate_mms`, `calculate_mpen`, `calculate_ns` all return
zero for empty/missing data. The test suite asserts this. Changing the
contract is a major migration. The chosen mitigation is to filter at the
panel-data layer (the C1 fix). I2 records the deeper option as a growth
path item.

### O4. Funnel and shopper-behaviour engines correctly use NA

`03b_funnel_metrics.R:348-359` and `08e_shopper_behaviour.R:253` set
metrics to NA when there is no data for a brand. Their cat-avg
calculations then use `na.rm = TRUE` and produce honest means.
Confirms the rest of the engine layer **could** adopt the same pattern.

### O5. Per-category brand list filters NONE pseudo-brand upstream

`get_brands_for_category()` removes NONE pseudo-brands before the brand
list reaches any engine. So in normal flow MA engines never see an
all-zero brand from NONE inclusion. The silent-zero risk fires when a
brand is in `cat_brands` but missing from a specific element's data
(e.g. a brand declared in cross-category awareness but not in the MA
battery).

### O6. The previous production review (2026-05-04) was clean

`modules/brand/docs/PRODUCTION_REVIEW_2026_05_04.md` declared zero
CRITICALs and a clean deploy. This review found one CRITICAL the previous
review missed (C1). Why: the previous review used the same test-passing
signal that the WOM bug also satisfied. The pattern was invisible without
hand-checking cat-avg semantics against a fixture containing a no-data
brand. Cross-renderer consistency tests (I6) and silent-zero invariant
tests (added in C1 regression suite) close the gap going forward.

### O7. Cold-start (Phase 2) succeeded under 30 min

README "Quick Start" + `modules/brand/docs/BRAND_CONFIG_GUIDE.md` are
sufficient to run the module. Fixture-generation note in the README is
accurate (xlsx fixtures are in `.gitignore`; running `00_generate.R`
produces them). No blocking documentation gaps.

---

## Verdict

**DEPLOY WITH CONDITIONS.**

Pre-deploy:
1. C1 fix lands in this branch — Summary panel cat-avgs now mask silent-zero brands and match the WOM card on the same page. Regression tests pass.
2. Duncan browser-verifies the fix on the IPK regen: focal-brand cards should show slightly higher cat-avg numbers across MMS / MPen / NS / Sole / Net WOM (the dilution from zero-data brands is removed). The Summary 5-chip "Net WOM cat avg" and the WOM card "Net heard cat avg" must now display the same number for the same brand+category.

Post-deploy backlog (tracked in `GROWTH_PATH_BRAND.md`):
- I1 (TRS sweep), I2 (engine-level NA), I3 (size markers), I4 (README count), I7 (lintr), I8 (doc archive), I9 (lock files), I10 (demographics toggle).

The brand module is otherwise well-tested (1,989 expectations, zero
failures), TRS-clean at the gate, free of hardcoded paths, and structurally
sound. The lesson from the WOM incident — and the C1 finding here — is
that downstream aggregations can hide engine-level silent-zero conflations
even when the engines themselves test green. The fix shipped today restores
client-facing correctness; the growth-path items address the systemic
weakness.

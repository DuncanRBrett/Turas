# Brand v2 lift, implementation notes

**Date:** 2026-09-03. Fable session, branch `feature/brand-v2-lift` in a
separate worktree (`/Users/duncan/Dev/Turas-brand-v2-lift`) so a concurrent
maxdiff session in the main checkout was never touched. **Not merged, not
pushed.** Duncan merges after regenerating a real report through
`launch_turas()` and eyeballing it.

Brief: `docs/v2_lift/HANDOVER_BRAND_FOR_OPUS.md` (Sessions A, B, C) against
`docs/v2_lift/BRAND_PRODUCTION_REVIEW_2026-07-12.md`. OPUS-0 was already on
main, so Session C was unblocked.

## Deviation from the handover

One branch instead of three. The three-branch split assumed three separate
sessions; one session did A, B and C in sequence, so the commits are grouped
by session on one branch. Everything else in the handover's locked decisions
was followed.

## What was done, by finding

| ID | Fix | Commit | Proof |
|---|---|---|---|
| A0 | Docs-only commit 6c1f0e41 cherry-picked (review doc only, verified with `git show --stat`) | 38aed876 | |
| C1 | Dirichlet expected values from the package closures per brand; SCR = buyrate / wp; 100% loyal from Pn and p.rj.n; refusal `CALC_DIRICHLET_EXTRACT` on NA or out-of-range | 14feec42 | Known-answer test against a direct `NBDdirichlet::dirichlet()` call; IPK fixture run through `run_brand()`: DSS expected values finite, flags 13 on line / 1 over / 1 under |
| H1 | Portfolio category penetration weighted (overview, clutter, strength) | 1d5cea97 | Tests fail on old code (5 failures), pass on new |
| H4 | Attribution list confirmed CLOSED (module header). Out-of-domain values refuse `DATA_REACH_BRAND_CODE_UNKNOWN`; a label in the asset Brand column refuses `CFG_REACH_ASSET_BRAND_UNKNOWN`; a refused misattribution now surfaces as PARTIAL with a warning | 1923acdc | test_branded_reach.R |
| NEW | **Branded Reach never ran when configured.** The structure wrapper redefined `run_branded_reach` under the engine's name and called itself with the engine's arguments ("unused arguments"), caught by the orchestrator's tryCatch, so the element silently became REFUSED on any project with a MarketingReach sheet. Engine renamed `run_branded_reach_assets`; a test now exercises the wired path | 1923acdc | test_branded_reach.R, wrapper test |
| H5 | GUI never announces a PARTIAL run as "completed successfully"; warnings listed in console and Step 5 | 1923acdc | test_gui_outcome.R (pure verdict helper) |
| M1 | `guard_alchemer_parser_shape` wired into `run_brand()` after the data load; blank-header X columns (openxlsx names them X1..) do not count as raw-export evidence | 1923acdc | test_guard.R, test_integration.R raw-export refusal |
| M2 | Generator refusals reported as a problem naming the report, never as success | 1923acdc | test_gui_outcome.R |
| M8 | Weights coerced to numeric or refused `DATA_WEIGHT_NOT_NUMERIC` with offending values named | 1923acdc | test_integration.R (both directions) |
| M9 | GUI package guard returns a refusal instead of `stop()`; the widget arg-validation stops were left (programmer errors) | 1923acdc | GUI parses |
| M5 | Dead `db_importance_method` removed from loader, template, three examples and guide | 0da7ca39 | |
| M6 | Six live Settings keys documented; `portfolio_extension_baseline` template offered `buyers`, a value the engine never implemented (silently became `all`): template fixed to `all` / `non_buyers` and the config guard now refuses anything else | 0da7ca39 | test_guard_and_config.R |
| L1 | Reserved NONE codes documented in the guide; behaviour unchanged (every shipped project uses the single code `NONE`) | 0da7ca39 | |
| NEW | Shipped MarketingReach template lacked SeenQuestionCode, BrandQuestionCode, MediaQuestionCode, which the engine requires (13b refuses without them) | 0da7ca39 | test_config_templates.R |
| C2 + H3 | One DOM-serialisable commentary store: textarea value mirrored into text content on input/change and before Save; MA sessionStorage and Audience Lens localStorage retired | 2f17d624 | **Headless Chrome on the IPK report**: text typed into MA, funnel, generic insight and summary boxes appears inside the textareas of the dumped DOM, and reloading that dump reads it back from each box's value |
| M3 | `.br_json_island()` escapes every `<` at all sixteen islands; a test scans the panel sources for unescaped islands | 41cf42d0 | test_json_islands.R |
| H2 | Sig tests and CIs on the shared Kish n_eff via `.brand_effective_n()` (sources `modules/shared/lib/effective_n.R`, refuses if absent). Funnel rows carry `n_effective`; extension, demographics Wilson, Audience Lens classifier rewired | 063e8ed6 | test_kish_effective_n.R: dispersed-weight fixture significant on raw counts, not on n_eff |
| M4 / C2 | Nine inline min-base comparisons through `.brand_meets_min_base()` (shared `meets_min_base`). DoP-awareness row gate moved from a weighted sum to the unweighted aware count, same basis as the other gates | 7f9acbdb | test_kish_effective_n.R |
| M7 | On-face bases: MA header and tooltip (denominator is all respondents, not category buyers; engine roxygen corrected too), portfolio overview two-line headers plus per-cell unweighted n (R and JS renderers), demographics header names the within-option base, brand-performance table caption with n respondents / n buyers / window, branded-reach base label says "weighted" when weights exist, plus one **"Which penetration is which"** block per category on the Summary tab listing category usage, % category buyers and category penetration with value, base, n and definition | (this commit) | test_penetration_notes.R; Chrome-rendered IPK report shows the block |

Suites: brand full suite after Session A 2273 / 0 fail; after B 2298 / 0; after
C 2311 / 0 (2 errors from a test that sourced `11_demographics.R` without
`00_guard.R`, fixed by adding the source line). **Final full-suite tally on the
branch tip: 2346 pass, 0 fail, 0 error, 2 skip, 1 warn** (61 files). Baseline
was 2155 / 0 / 2 skip / 1 warn.

## Not adopted from v2, and why (C4)

Recorded against V2_MIGRATION_PLAN section 7's drop list, for the brand
archetype (v2-standard upgrade in place, no island, no exporter):

- AI insights: brand commentary is analyst-written by design.
- Wave tracking: belongs to the tracker module (README non-duplication).
- Workspace / story views: the brand report's own IA is the parked Rec A
  redesign, a separate design-led effort.
- Banner dual-significance letters: brand's comparison model is focal versus
  rest, not banner columns.
- Microdata recompute under a live filter: Dirichlet, TURF, MA networks and
  the funnel are not closed-form client-side.

## Deferred, with reasons

- **C3, native PPTX through the tabs v2 OOXML engine.** Not started. It is
  the one Session C item that is a build rather than a fix, and it could not
  be done to the quality bar in the same evening as A, B and the rest of C.
  `brand_pins.js` is already a thin delegating wrapper over shared TurasPins
  (OPUS-0 inventory); the screenshot PPTX path in `turas_pins_pptx.js` still
  serves brand. Scope for a dedicated session: swap `turas_pins_pptx.js`'s
  `addImage` path for `14_pptx_parts.js` / `29_export.js` with an image
  fallback for the bespoke SVG panels.
- **Funnel significance closures are dead in production.** `00_main.R`
  passes `sig_tester = NULL` to `run_funnel()`, so `.sig_row` never runs.
  They were rewired for correctness (H2) and tested, but nothing in the
  report shows them. Wiring a tester is a product decision (which test, which
  alpha), not a fix.
- **Funnel about-text `base_note` is written but never rendered** (no reader
  in the panels or JS). The Kish wording added there is inert until someone
  renders the about block.
- **Two dead renderers in the cat-buying panel**: `.cb_kpi_strip()` and
  `cb_norms_table_html()` in the panel files have no callers; the live table
  is `cb_brand_freq_scr_table_html()`. Both dead functions were given base
  labels before this was noticed; harmless, but they should be deleted in a
  tidy-up.
- **Pre-existing on main, not caused here**: generating the IPK fixture report
  prints `[BRAND HTML] Chart transform failed: missing value where TRUE/FALSE
  needed` (verified identical on untouched main); `test_html_report.R`,
  `test_cat_buying_panel.R` and `test_guard_and_config.R` error in isolation
  because they under-source, but pass in the full suite.
- **Audience Lens n_base stays unweighted for display; n_eff is used for the
  test.** The classifier's coarse mean-difference z (`z_means_approx`) is
  still the v1 simplification the file itself flags.
- The Excel output path (`99_output.R`, `10d`, `09g`) was not given the new
  base labels; only the HTML report was in scope.

## For Duncan

1. Regenerate a real brand report through `launch_turas()` and eyeball: the
   Category Buying brand-performance table caption, the Summary tab's
   "Which penetration is which" block, the Portfolio overview headers, the
   Demographics header, and Save-then-reopen with commentary typed in.
2. Note the DoP-awareness row gate basis change (weighted sum to unweighted
   count); a category with heavy weights may now flag differently.
3. Rulings still open from the review: none of the five in section 9 were
   vetoed, so the locked defaults stand.

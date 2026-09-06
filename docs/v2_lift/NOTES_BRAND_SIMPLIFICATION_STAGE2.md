# Brand simplification, Stage 2 implementation log

**Date:** 2026-09-06. Worktree `/Users/duncan/Dev/Turas-brand-simplify`,
branch `feature/brand-simplification`, rebased onto main at 5277fef2.
Scope: the five-destination shell, rehoming only. No analytical change.

Brief: `docs/v2_lift/HANDOVER_BRAND_SIMPLIFICATION_FOR_OPUS.md` section 3,
against `modules/brand/docs/SIMPLIFICATION_IMPACT_MAP.md`.

## Baseline, executed before the first edit

- Brand suite: `TURAS_ROOT=/Users/duncan/Dev/Turas-brand-simplify Rscript -e
  'testthat::test_dir("modules/brand/tests/testthat")'` gave
  **FAIL 0, WARN 1, SKIP 2, PASS 2542**, 88.9 s. Matches the brief.
- Old IPK fixture report generated and kept for the before-and-after diffs:
  `run_brand()` on `modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx`
  with `project_root` = the fixture directory, then
  `generate_brand_html_report()`. Status PASS, **3,870,211 bytes**.

## Facts established by reading the code, before the design was fixed

These decided the shape of the build.

- `js/brand_funnel_panel.js` and `js/brand_ma_panel.js` scope everything to a
  panel root found by `document.querySelectorAll('.fn-panel' / '.ma-panel')`,
  and neither file calls `getElementById` at all. The funnel and MA panel R
  files emit exactly one `id` each, the panel root.
- `js/brand_cat_buying_panel.js` does use `getElementById` for
  `cb-data-<cat>`, `cb-details-<cat>`, chart containers and one table id, so
  a whole-panel copy of the cat-buying panel would leave every copy after the
  first without its tables and charts.
- Every cross-sub-tab DOM reach in the three panel JS files is either a
  `forEach` over a possibly empty list or a `querySelector(...) || panel`
  fallback, so a host that carries only one sub-tab div does not throw.
- `js/brand_selector_dropdown.js` already keeps a category-scoped store of
  hidden brand codes (`window._brandSelectorCategoryStore`) that every
  registered panel in a category subscribes to. That is the substrate the
  comparison-set control uses; it is not reinvented.
- Panel size in the old report: the `fn` sub-panel is 153,613 bytes, `ma` is
  621,133 (of which the `ma-panel-data` island is 285,842), `rep` is 322,083.

## Decisions taken, with reasons

1. **Split the render by content, not by copying** (Duncan's ruling 1,
   option (a) in impact map section 9 item 0). Each internal tab gets its own
   `.br-subpanel` host. A host carries the panel root with a distinct id, the
   panel's own hidden sub-nav, the panel's own chrome, and only its own
   sub-tab div. The JSON island is emitted once per panel per category, in
   the primary host; other hosts carry `data-island-host` and the panel JS
   reads the payload from there. This is what option (a) describes: it says
   "no duplicated payload" and warns only about the repeated chrome.
2. **The cat-buying panel is split the same way**, one host per `data-cb-tab`.
   The impact map does not name it as a straddler, but its eight sub-tabs land
   in three different destination-and-tier slots, so it has the same problem
   as `fn` and `ma`. Logged as an extension of ruling 1 by analogy.
3. **Destination ids are short and independent of the display labels**
   (`overview`, `mental`, `buying`, `meaning`, `audience`), so renaming a
   label later touches no `data-*` value (requirement C).
4. **Main-view hosts stack; only the Advanced drawer uses an accordion.**
   Ruling 7 constrains the Advanced drawer only, and the handover says a
   destination "holds the existing sub-panels unchanged".
5. **Wrapper placement.** `section-funnel-<cat>` goes on the funnel host,
   `section-ma-<cat>` on the metrics host, `section-repertoire-<cat>` on the
   Category Context host. Nothing in the report targets `ma-<cat>` or
   `funnel-<cat>` from an `onclick`, so the first two were free choices.

## Deviations and losses, logged

- **Excel export scope for `repertoire-<cat>` narrows.** Today
  `_brExportPanel('repertoire-dss')` collects every table under
  `#section-repertoire-dss`, which is all eight cat-buying sub-tabs. After the
  split that wrapper contains the Category Context host only. Stage 5 replaces
  the per-table toolbars with one per destination main view and one per
  Advanced drawer, which restores the coverage properly. Quantified below.
- **The Overview destination has no content of its own in Stage 2.** Stage 3
  builds it. To keep five destination buttons per category without showing an
  empty destination, the Overview holds one card that switches to the Summary
  tab with this category selected. No analysis and no number is invented.

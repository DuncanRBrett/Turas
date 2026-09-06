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

## What was built

**The shell.** `build_br_category_panel()` in
`modules/brand/lib/html_report/03_page_builder.R` no longer emits the flat
`.br-subtab-nav`. It emits a header control area, five destination buttons and
five `.br-destination` containers, each with a main view and, where leaves
land there, an Advanced drawer holding a one-at-a-time accordion.

Three new top-level registries in the same file:

- `.BR_DESTINATIONS`, five entries with an `id` and a `label`. The ids are
  `overview`, `mental`, `buying`, `meaning`, `audience`.
- `.BR_LEAF_HOMES`, nineteen entries keyed on the historical `data-subtab`
  value, or `cb-` plus the `data-cb-tab` value, each naming a destination, a
  tier and an order.
- `.BR_LEAF_LABELS`, the display labels, keyed the same way.

**The split hosts.** `build_funnel_panel_html()`, `build_ma_panel_html()` and
`render_cat_buying_panel()` each gained `only_tab`, `island` and `island_host`
arguments, and the cat-buying builder also `kpi_strip`. With `only_tab` unset
every one of them emits exactly what it emitted before, so a direct caller and
the existing panel tests are unaffected. `transform_brand_panels()` in
`01_data_transformer.R` now asks each builder for one fragment per internal
sub-tab and stores them under `<element>_<cat>__<tab>` keys. A sub-tab with no
data emits no content div, and that marker is the presence test, so the gating
stays in the panel builder and is not duplicated.

`readPayload` in `brand_funnel_panel.js`, `brand_ma_panel.js` and
`brand_cat_buying_panel.js` falls back to the panel root named by
`data-island-host`. The funnel and MA panels read their category key from a
new `data-category-key` attribute instead of stripping their element id, which
a suffixed host id would otherwise have broken, and the cat-buying panel's
`BrandSelector` panelId is now the host id so seven hosts do not collide in
one registry.

**The JS.** `brand_report.js` gained `switchBrandDestination()`,
`brToggleAdvanced()`, `brToggleAdvancedItem()`, `brOpenSummaryFor()` and the
comparison-set functions. The per-host activation routine, which shows the one
matching `.br-insight-wrap` and clicks the panel's own hidden sub-tab button,
is now a shared helper that both `switchBrandDestination()` and
`switchCategorySubtab()` call. `switchCategorySubtab()` keeps its behaviour and
its route; its host selector gained `[data-internal-tab]` because one category
now renders several hosts per sub-panel.

**Requirement A, the comparison set.** One control per category, in the header,
sets the focal brand and up to five comparators. It drives each panel's own
focal select and publishes a hidden-brand set through
`BrandSelector.setCategoryHidden()`, a new entry point on the category-scoped
store `brand_selector_dropdown.js` already kept. No panel's filtering is
reimplemented and nothing is recomputed. With no comparator picked the control
makes no claim and hides nothing.

**Requirement B, wave readiness.** Two parts.

- The header is a three-slot system. Slot one is the category switcher, slot
  two the comparison set, slot three empty and reserved, so adding a period
  selector is an insertion into a container that already exists.
- Headline comparisons are slots that name their source, through the new
  `br_compare_slot()` helper in `panels/00_json_island.R`. Applied to the four
  Mental Availability hero cards, source `category-average`, and to the five
  cat-buying KPI chips, source `dirichlet-expected` on the two that have an
  expected value, `category-average` on the light-buyer index and `none` on
  the rest, which render an en dash. Nothing computes a wave comparison.

**Requirement C, labels apart from identifiers.** `id` and `label` are separate
fields on every destination and leaf, and no code derives one from the other.
`test_destination_nav.R` proves it behaviourally: it snapshots every `data-*`
value in a rendered category panel, renames every destination and leaf label,
re-renders, and asserts nothing moved.

## Executed, with the numbers

| Check | Result |
|---|---|
| Brand suite, before the first edit | FAIL 0, WARN 1, SKIP 2, PASS 2542 |
| Brand suite, at this commit | FAIL 0, WARN 1, SKIP 2, PASS 2730 |
| IPK fixture report, old | 3,870,211 bytes |
| IPK fixture report, new | 3,917,356 bytes, 1.2 percent larger |
| `tests/qa/reachability_check.py` | PASS. data-subpanel 5 values identical, data-section 29 identical, section ids 13 identical, all eight island classes present with numeric content identical |
| `tests/qa/drive_destinations.py`, headless Chrome | 43 checks, 0 failed, no console error and no uncaught exception |

The Chrome drive reached, for the fixture's one full-depth category: Overview
(the stub card), Mental Availability (4 hosts), Brand and Buying (3 main hosts
plus a 5-item Advanced drawer), Brand Meaning (2 hosts) and Audience (1 host).
It opened the drawer, expanded each accordion item and confirmed exactly one
stays open, picked two comparators and confirmed the published hidden set kept
the focal brand and both comparators visible and hid the other twelve, then
changed the focal brand and read it back off both the Mental Availability and
funnel hosts.

Two new test files: `modules/brand/tests/testthat/test_destination_nav.R`, 186
assertions in the style of the rescue tag's `test_subtab_nav_tiers.R`, and the
two scripts under `modules/brand/tests/qa/`.

`test_cat_buying_dirichlet_surfaces.R` was updated in one place: the KPI chip
no longer renders "exp 40%" because the slot now carries the label "Dirichlet
expected" and the figure alone. The JSON payload the focal switcher reads was
changed to match, so the chip does not change shape when a reader picks another
brand, which is what that test exists to protect. No number changed: the
reachability script confirms the cat-buying island's numeric content is
identical.

## Not done, and why

- **The examples/1brand, 3cat and 9cat configs were not rendered.** All three
  generators fail at `.build_questions_columns()`, a function that exists
  nowhere in the repository; the nearest is
  `.build_unified_questions_columns()` in
  `modules/brand/R/generate_config_templates.R`. The breakage is on main and
  the example files are untouched by this branch. The hidden-destination rule
  is instead asserted by unit tests that render `build_br_category_panel()`
  with the element mixes those configs represent: a full-depth category, a
  category with the funnel only, and a category with neither Mental
  Availability nor the funnel nor Word of Mouth. A separate task has been
  raised to repair the generators.
- **Stage 3, the Overview, was not started.** The Overview destination carries
  a route to the Summary tab, nothing more.
- **The intra-tab splits the impact map describes** (the Mental Advantage
  quadrant in the main view with the full matrix in Advanced, and "full
  attribute matrices" under Brand Meaning Advanced) are inside single internal
  tabs, not among the nineteen leaves. Mental Advantage is rehomed whole into
  the Mental Availability main view. Cutting into
  `build_ma_advantage_section()` is a later job.

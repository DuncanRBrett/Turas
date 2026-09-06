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

- **The `repertoire-<cat>` pin and export narrow, and this is the one place
  "nothing may be lost" is bent.** `#section-repertoire-dss` used to wrap the
  whole cat-buying panel; after the split it wraps the Category Context host
  only. Counted in the two IPK fixture reports: **9 tables and 321,923 bytes
  before, 2 tables and 61,147 bytes after**. So `_brExportPanel` on that
  anchor now carries Category Context rather than all eight sub-tabs, and
  `brTogglePin('repertoire-dss')` captures the same narrower root. Brand
  Summary, Dirichlet Norms, Loyalty Segmentation, Purchase Distribution,
  Buyer Heaviness and Duplication of Purchase have no pin or export control
  of their own until Stage 5 gives each destination main view and each
  Advanced drawer one. Every one of them is still reachable, and their
  numbers are unchanged; it is the export and pin reach that shrinks.
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

## Adversarial pass, and what it caught

Three things found by trying to break the shell rather than by reading it.

1. **The Overview route pointed at a class that does not exist.** It looked for
   `.brsum-cat-select`; the summary panel's dropdown carries `data-brsum-cat`,
   and its option values are the category display name, not the cat id. The
   route now matches on the name and keeps the id as a fallback. The Chrome
   harness gained a check that clicking the Overview card opens the Summary tab
   with this category selected, and it passes.
2. **Advanced content would have vanished from a printed report.** The print
   rules unhid `.br-panel`, `.br-subpanel` and, after this change,
   `.br-destination`, but a collapsed drawer or accordion item stays hidden
   through the `hidden` attribute. Print now unhides `.br-advanced-body` and
   `.br-adv-body` as well, so nothing is lost on paper.
3. **A destination whose only content sits in Advanced opened on a blank main
   view.** Audience with Audience Lens configured but no Demographics and no Ad
   Hoc is the real case. Its drawer now starts open, and a test covers it.

## Final numbers, all executed in this session

These were superseded by the run recorded at the end of this document.

## What Duncan still owes

Regenerate a real brand report through `launch_turas()` and eyeball the five
destinations, then a Fable pre-merge review briefed as independent of this
session. Not merged, not pushed.

## Second adversarial pass, after an independent review of this session

Five more things, three of which changed what could honestly be claimed.

1. **The island gate had a hole.** `_numbers()` in `reachability_check.py`
   fell back to harvesting digits out of any body that failed to parse as
   JSON. The whole JavaScript bundle sits in a `<script>` of its own and
   contains the literal text of island tags it builds at runtime, so the regex
   sweep found a span of source code and reported it as a second
   `fn-panel-data` payload whose digits happened to match. That bundle is a
   file this work edits, so the match was luck. `json.loads` is now mandatory:
   a body that does not parse is counted, named and excluded, and the script
   fails if the set of unparseable spans differs between the two reports.
   With the hole closed the funnel island is one payload, identical, and the
   five islands with no class attribute do parse and are identical.
2. **The old focal brand was silently promoted to a comparator.** Changing the
   focal from IPK to ROB re-enabled IPK's checkbox with `checked` still set, so
   a comparator slot was consumed without a click, out of five. The previous
   focal is now released.
3. **Requirement A was unproven for the Category Buying hosts.** The Chrome
   harness read the new focal back off the Mental Availability and funnel
   hosts only, and `setCategoryHidden` writes the shared store whether or not
   anything subscribes, so the store check would have passed with seven dead
   hosts. `data-cb-cat-code="dss"` was confirmed to match `data-group="dss"`,
   and the harness now reads the focal back off `.cb-focus-select` too. It
   passes.
4. **The test file claimed a route it did not assert.** Two tests were added:
   one reads `js/brand_report.js` and asserts `switchCategorySubtab` still
   exists and still carries the `.ma-subtab-btn`, `.fn-subtab-btn`,
   `.cb-subtab-btn` and `.br-insight-wrap[data-insight-internal-tab]`
   selectors; the other asserts the three panel sub-navs are still hidden by
   the one CSS rule rather than removed from the DOM.
5. **One harness assertion was wrong, not the code.** It expected the
   comparator count to stay at two after the focal changed to a brand that was
   one of the two comparators. Corrected to expect one.

## Known limits, stated rather than left to be discovered

- **Four elements have never rendered through the new shell with real panel
  fragments.** Branded Reach, Ad Hoc, Audience Lens and Shopper Behaviour are
  all absent from the IPK fixture, the three example generators are broken on
  main, and the unit tests use stub panel fragments. Their `.br_leaf_host`
  branches are otherwise unchanged from the code that shipped, and the
  suite's own panel-level tests still cover the panels themselves, but the
  first real render of those four inside a destination is Duncan's
  `launch_turas()` run on a project that configures them.
- **The category switcher's JavaScript has not run in a browser.**
  `brSwitchCategoryFromControl()` is exercised only by the R-side test that
  checks the dropdown renders. The fixture has one full-depth category, so the
  slot renders as static text there. The real IPK project has four, and that is
  the path Duncan will use first.
- **The comparison set does not survive Save.** A checkbox's `checked` is a
  property, not an attribute, and the Save button serialises `outerHTML`; the
  lift's mirror covers textareas only. Not asked for in Stage 2, and no
  commentary or pin is affected, but a reader will expect the picks to persist.

## Final numbers, all executed in this session

- Brand suite: **FAIL 0, WARN 1, SKIP 2, PASS 2740**, against a baseline of
  2542 with the same 0 failures. The 198 added are the new structural tests.
- IPK fixture report: 3,870,211 bytes before, **3,918,223 after**, 1.2 percent
  larger.
- `modules/brand/tests/qa/reachability_check.py`: **PASS**. data-subpanel 5
  values identical, data-section 29 identical, section ids 13 identical, and
  every JSON island that parses identical in numeric content, with the one
  unparseable span named in both reports rather than silently compared.
- `modules/brand/tests/qa/drive_destinations.py` in headless Chrome:
  **48 checks, 0 failed**, no console error and no uncaught exception.


# Stage 2 follow-up, 6 September 2026

Duncan regenerated the report and reported two things: the brand controls
are duplicated, and the Advanced click-through is not polished. Both are
fixed here. No analytical change, no new number, and nothing recomputed.

Baseline executed before the first edit, in this worktree at aff07193:
brand suite **FAIL 0, WARN 1, SKIP 2, PASS 2740**, 98.5 s. It matches the
figure the brief gave.

## Problem 1, the duplicated brand controls

### What was actually wrong, measured rather than assumed

The IPK fixture report was generated at the branch tip and driven in
headless Chrome. Sixteen per-panel `Filter brands` triggers and fifteen
per-panel focal selects were on screen alongside the header control. Every
one of the sixteen triggers did follow the header: picking three
comparators moved all of them from `(1/15)` to `(4/15)`. So the store path
worked; what shipped was a second set of controls that should never have
stayed visible.

Duncan's `(8/14)` could **not** be reproduced. The fixture carries fifteen
brands, not fourteen, so he was reading his real IPK project, which this
session does not open. What was reproduced is his `(1/11)` on Dirichlet
Norms: three views carry a brand filter that does nothing at all.

Counting the visible table rows and columns per host, before and after
picking three comparators, separated three groups.

| Group | Hosts | Behaviour |
|---|---|---|
| Narrows, by rows | fn-funnel, fn-relationship, ma-metrics, cb-brands, cb-loyalty, cb-dist, cb-heaviness, wom | 1 brand to 4 |
| Narrows, by columns | ma-ceps, ma-attributes, ma-advantage, demographics | 1 brand column to 4 |
| Does not narrow | cb-context, cb-norms, cb-dop | unchanged |

The third group is why the counts disagreed with the tables.
`bindCBBrandSelector` writes only the `brands`, `loyalty`, `dist` and
`heaviness` scopes. Before Stage 2 one cat-buying panel carried one trigger
that governed four of its eight sub-tabs; the Stage 2 split gave each of
the seven hosts its own copy, so four of those copies became inert
controls with a count on them.

### What was built

**One focal control and one brand-set control per category, in the header.
They stay two controls, deliberately.** The focal brand is a single choice
and the comparison set is many, and folding them together would put the
most important choice in the report behind a click. They sit side by side
in one slot, so a reader still has one place to go.

**Every per-panel copy is marked and hidden, not removed.** The class is
`br-header-governed`, and it sits on the trigger built by
`build_brand_selector_trigger()` and on the five focal-control wrappers:
`.fn-focus-bar`, `.wom-focus-bar`, `.cb-focus-bar`, `.demo-focal-row` and a
new `.ma-focus-pick` span inside `.ma-focus-bar`, which keeps its Cat avg
chip. The rule is `.br-header-governed { display: none !important; }` with
no ancestor, following `.fn-subnav, .ma-subnav`. A rule scoped under
`.br-destination` would have passed every count check and still shown
through in a pin or a PNG, because TurasPins re-parents the captured node
and its inliner skips values that look like defaults.

**The header now has three named states, and the trigger always reads the
live one.** `Focal only`, `Compare with N`, `All brands`. The published
hidden set matches the state in every case. Two inconsistencies that were
in the shipped code are closed by this:

- At load the header claimed nothing while the panels sat at focal only,
  except demographics which sat at all fifteen.
- `Clear comparators` published an empty hidden set, so every brand
  appeared while the badge read 0.

`All brands` is a mode rather than fifteen ticked boxes, so the
five-comparator cap from requirement A stays a real cap and a reader can
still ask for the whole category in one click.

**The opening state comes from `chip_default`.** That is the analyst's
Brand_Config setting for how much the panels show on open (`focal_only` or
`all`), so the one control inherits it rather than overriding it. It is
published on window load, not on DOMContentLoaded: `brand_report.js` is
first in the bundle and its handler runs before every panel registers,
and `categoryBrands()` is a union over registered subscribers.

**Two gaps in the header's reach, found and closed.** `setPanelFocal()`
never looked for `.demo-focal-select`, and `categoryPanels()` never matched
the WOM or demographics panel roots, so neither followed the header's focal
brand. Both now do, and the Chrome harness reads the new focal back off all
five panel kinds.

**The three views that cannot narrow now say so.** Category Context,
Dirichlet Norms and Duplication of Purchase, plus Shopper Behaviour which
the fixture does not render, each gained a closing sentence in the caption
they already had. Dirichlet Norms and Duplication of Purchase state that
every brand in the category is shown and the comparison set does not narrow
the view; Category Context states that the figures describe the category,
so the comparison set does not change them. No control was kept and
relabelled: the control on those hosts did nothing, and a relabelled dead
control is worse than none.

### Executed, with the numbers

Headless Chrome on the regenerated IPK fixture, header driven through all
three states, reading the visible brand codes off every host:

| State | Header reads | Narrowing hosts show | Whole-category hosts show |
|---|---|---|---|
| On load | Focal only | IPK | all 15 |
| Three picked | Compare with 3 | IPK, ROB, KNORR, CART | all 15 |
| All brands | All brands | all 15 | all 15 |
| Back to focal | Focal only | IPK | all 15 |

Visible control census in the category: header focal 1 of 1, header trigger
1 of 1, per-panel focal selects 0 of 15, per-panel brand filters 0 of 16.

## Problem 2, the Advanced click-through

The defect was visible in a screenshot of the Brand and Buying drawer: the
`Advanced` toggle and the `Dirichlet Norms` toggle were the same full-width
boxed bar, so neither read as the parent of the other, and under them sat
the panel's own focal and filter toolbar and then a second `Dirichlet
Norms` heading.

Five changes.

1. **The two tiers no longer look alike.** `Advanced` is a quiet section
   label, uppercase and letter-spaced above a rule, with a count of what it
   holds. The items under it are list rows, indented, with their markers at
   the far edge.
2. **A drawer that starts closed opens on its list of titles.** All items
   collapsed, so the reader sees the five analyses and picks one, and one
   click on a title expands it. Before, the first item was expanded on
   render, so opening the drawer dropped the reader into a full panel and
   the first click on that title closed it. The exception is kept: a drawer
   whose destination has no main view starts open on its first item.
3. **Opening either tier scrolls the thing that was clicked back into
   view.** Collapsing an item above the one being opened can pull the
   clicked header up by the height of a whole panel. `scroll-margin-top`
   clears the sticky `.br-tab-nav`.
4. **A drawer holding one analysis has one level of disclosure.** Its
   heading is a heading, not a second toggle, and its body is not hidden
   behind a click of its own. The `.br-adv-item[data-leaf]` wrapper is kept,
   so nothing that keys on the shape moves. Brand Meaning with Branded
   Reach configured is the real case; the IPK fixture does not produce it,
   so it is covered by a unit test rather than by the browser pass.
5. **The panel chrome inside a drawer is the focal and filter toolbar, and
   Problem 1 removed it.**

Left alone, on purpose: the accordion row and the panel's own `h3` carry
the same words. The row is the navigation label a reader needs while the
item is collapsed, and the `h3` is the panel's own title that travels with
an export or a print. Suppressing the `h3` reliably needs the destination
tier threaded into the panel builders, and the emission is not consistent
enough across the cat-buying sub-tabs to do it with a selector.

## The CSS escape sweep

Every line this branch adds to a file under `modules/brand` was scanned for
a backslash that is not doubled. Thirty-nine lines match, and all of them
are roxygen `\code{}`, an R `"\n"`, a `"–"` en dash, a Python regex or
a `sub()` backreference. The four Advanced accordion rules were the only
CSS with that shape and they were already fixed on the tip.

## Test coverage added, so the single-control rule cannot regress

`modules/brand/tests/testthat/test_single_brand_control.R`, 37 assertions.
One focal select, one trigger, one popover and one comparison slot in a
rendered header; the trigger naming its state rather than showing a bare
number; `chip_default = all` opening on all brands; the marker present at
every one of the five focal-control emission sites and on the shared
trigger; a count guard that fails if a sixth focal select is added without
a marker; the hiding rule named with no ancestor; the header reaching all
five panel kinds; the opening state published on window load; and the four
whole-category notes present.

`modules/brand/tests/qa/drive_destinations.py` now asserts identity rather
than counts. Per host, the set of visible brand codes must equal the set
the header names, in all three states, with `cb-norms` and `cb-dop`
expected to hold the whole category and `ma-advantage` checked on its
visible column count because its matrix keys columns by stimulus, not by
brand code. It also asserts exactly one visible focal control and one
visible brand-set control per category, zero visible per-panel copies, and
that the per-panel copies still exist for the header to drive.

`test_destination_nav.R` gained the drawer count, the collapsed-on-open
rule and the single-item drawer, and its old "one item expanded" assertion
was replaced.

## Final numbers, all executed in this session

- Brand suite: **FAIL 0, WARN 1, SKIP 2, PASS 2780**, against the 2740
  baseline with the same 0 failures.
- `modules/brand/tests/qa/reachability_check.py`, main's report against
  this one: **PASS**. data-subpanel 5 identical, data-section 29 identical,
  section ids 13 identical, island classes 8 identical, every parseable
  island numerically identical, the one unparseable span named in both.
- `modules/brand/tests/qa/drive_destinations.py` in headless Chrome:
  **113 checks, 0 failed**, no console error and no uncaught exception.
- IPK fixture report: 3,918,231 bytes at the tip, **3,926,103 bytes** after,
  0.2 percent larger. Generated to the session scratchpad only.

## Two things checked from the code, because nothing could execute them

- **A brand-code alias cannot split the header from the panels.** The
  header's list comes from the Brands sheet `BrandCode`, and the hidden
  set is built from the codes the panels registered, so a panel keyed on
  something else would hide only some of the brands and produce exactly the
  kind of partial count Duncan saw. `BrandCodeAlias` is the one mechanism
  that could do it, and the live IPK project uses it. It does not: the
  alias is an input-side fallback for finding a differently named data
  column, and `multi_mention_brand_matrix()` in
  `modules/brand/R/00_data_access.R` keeps the matrix keyed on the
  canonical `BrandCode` whichever column it read. That one function was
  read, not every engine.
- **A hidden control cannot come back in a pin or a PNG.** Two reasons, both
  read out of the code. `brand_pins.js` captures the first visible table,
  the chart, and the insight text, never the panel's control bar, and then
  runs `brStripInteractive` over what it captured. And where a capture does
  carry hidden content, `TurasPins._inlineCaptureStyles` in
  `modules/shared/js/turas_pins_utils.js` copies `display:none` through
  explicitly rather than skipping it as a default, which is what keeps a
  hidden brand column hidden in a captured table.

## Known limits, stated rather than left to be discovered

- **Duncan's `(8/14)` was not reproduced and is not claimed fixed by
  observation.** It came from a report this session cannot open. What is
  claimed, and shown, is that on the IPK fixture the header and every host
  agree in all three states, and that only one control of each kind is on
  screen.
- **`brApplyAllComparisonSets` has not run in a browser across more than one
  category.** The IPK fixture has one full-depth category. The function
  loops over the distinct `data-group` values it finds, and the real IPK
  project has four. This sits beside the Stage 2 note that the category
  switcher's JavaScript has not run in a browser either.
- **The Cat avg chip is now a lone control.** The Mental Availability and
  Brand Attitude focus bars held Focal brand, Filter brands and Cat avg;
  the first two are hidden, so Cat avg sits on its own above the panel
  title. It is a working control and it was left where it is rather than
  moved into the header, which is a decision about the header's contents
  and not part of removing a duplicate.
- **`styler` was not run.** The four large files this touches would be
  reformatted whole, and the churn would bury the change. The edits follow
  the surrounding style by hand.
- **The split-mode brand filter is gone from the reader's reach.** The MA
  and cat-buying popovers could hide a brand from the chart while keeping
  it in the table. The header set is unified. Nothing is lost from the
  report, only that one way of using it.
- **The demographics panel used to open showing all fifteen brands** while
  every other panel opened on the focal brand alone. It now follows
  `chip_default` with the rest. That is a deliberate behaviour change, and
  it is what makes the header's opening claim true.
- **Branded Reach, Ad Hoc, Audience Lens and Shopper Behaviour still have
  never rendered through the shell with real panel fragments.** Unchanged
  from Stage 2. The single-item drawer path is one of these, so it is
  proven by unit test and not by a browser.
- **The comparison set still does not survive Save.** Unchanged from
  Stage 2, and the three-state control adds `data-cmp-mode`, which is an
  attribute and would survive an `outerHTML` serialisation, while the
  checkbox `checked` properties would not.

## What Duncan still owes

A `launch_turas()` run on the real IPK project, where he first saw the
duplication, then the five destinations eyeballed with the header control
driven through its three states. Not merged, not pushed.


# Stage 2 follow-up, part two: Chart brands, 6 September 2026

Duncan confirmed he used the split-mode brand filter: with "Sync table and
chart" off he could hide a brand from a chart while keeping it in the table.
The Stage 2 follow-up hid the per-panel filters and took that with them. It is
back, as a control of its own rather than as a side effect of a duplicated
dropdown. He also confirmed the Demographics change is fine as it stands, and
it was left alone.

Baseline executed before the first edit, in this worktree at a362238d: brand
suite **FAIL 0, WARN 1, SKIP 2, PASS 2780**, 93.4 s. It matches the brief. The
tip's IPK fixture report was regenerated from a `git archive` of a362238d and
came to **3,926,103 bytes**, which is the figure the previous session
recorded, so the before-and-after diffs are against a reproduced baseline
rather than a remembered one.

## What was built, and why it is a deviation and not a second selection

**"Chart brands", one control per chart.** It sits beside the chart it
governs, reads `Chart brands: same as table`, and opens a checkbox list.
Unticking a brand drops it from that chart alone.

Three properties make it a deviation from the header rather than a competing
selection, and each is a mechanism rather than a rule someone has to remember.

1. **It can only narrow.** The popover is rebuilt on every open from the
   brands the header shows at that moment, and the set it publishes is the
   union of the header's hidden set and the brands unticked here. A brand the
   header excluded cannot come back into a chart through this control.
2. **Any header change resets it.** This needed no new code.
   `applyRemoteHiddenSet` in `brand_selector_dropdown.js` already writes
   `hiddenChart` from `hiddenTable` on every published set, and
   `brApplyComparisonSet` publishes on every header change. The reset is the
   substrate's own behaviour. What was added is one call at the end of
   `brApplyComparisonSet` so the controls and their notes repaint, and the
   removal of an early `return` in the all-brands branch so it runs in all
   three header states rather than two.
3. **It is neither a focal control nor a brand-set control.** It carries no
   `bs-trigger` and no `*-focus-select` class, and it selects no set of its
   own. The single-control census is untouched.

**No new store.** The per-host `BrandSelector` instance is still created in
split mode and still holds `hiddenChart`, and each panel's own
`onChange(set, "chart")` handler is the proven path that writes
`chart_visible`, `chartVisible`, `chartBrands` and `__womHiddenChart`. Two
entry points were added to the handle: `getBrands()` and `setHiddenChart()`.
The setter deliberately does not go through `emit()`, which fires `onChange`
twice for a chart-scope change, the first time with the table set. It
publishes nothing to the category store, so a chart deviation cannot reach the
header or a sibling host.

**The focal brand is locked into its own chart.** Its checkbox is disabled and
ticked. A chart without the focal brand is a category chart, and the header's
premise is focal first. A minor choice, made rather than asked.

## Where it is offered, and where it is not

The rule is: a chart, a table beside it, and a chart-only visibility map
already behind the chart. That is eight charts across six emission sites.

| Leaf | Chart-only map |
|---|---|
| fn-funnel | `__fnState.chartBrands`, slope and bar |
| ma-attributes, ma-ceps | `__maState.chartVisible.<stim>`, dot charts |
| cb-brands | `__cbState.chart_visible.brands`, bar chart |
| cb-loyalty, cb-dist, cb-heaviness | `__cbState.chart_visible.<scope>`, stacked bars |
| wom | `__womHiddenChart` |

Deliberately excluded, each for a stated reason.

- **Category Context, Dirichlet Norms, Duplication of Purchase and Shopper
  Behaviour.** Out of scope in the brief, and they do not narrow at all.
- **Demographics.** Its selector is unified mode. It never had the split, and
  Duncan said to leave it alone.
- **Brand Attitude (fn-relationship).** Its selector is unified mode too. The
  comment at `brand_funnel_panel.js` line 778 says so in as many words: the
  relationship view has no separate chart-only selection. Restoring a split
  there would be new capability, not restoration.
- **MA Metrics.** `renderMAScatter` and `renderMABarChart` both read
  `getHidden()`, the TABLE set, not `getHiddenChart()`. That is what shipped:
  in split mode those two charts followed the table column. Changing them to
  read the chart set would be a behaviour change beyond the ask. Recorded here
  as a candidate, not done.
- **Mental Advantage.** The MA selector's chart branch does not touch it; its
  matrix follows `__maAdvHiddenBrands`, written in the table branch. Same
  reasoning.

## How a deviating chart is marked, and what a capture carries

Three layers, because a reader can meet the chart on the page, in a pin card
or in a PNG.

1. **The control names its own state.** `Chart brands: 12 of 15`, in amber,
   with a border to match.
2. **A note sits above the chart.** "Chart shows 12 of the 15 brands in the
   table. Hidden from the chart: Robertsons, Knorr, Cartwright's." It is a
   plain text node with no control in it, so `brStripInteractive` leaves it
   alone while removing the control beside it, and `capturePortableHtml`
   clones it with its colour, weight and rail inlined. It is emitted by R,
   inside the chart-area element the cat-buying pin and PNG paths already
   clone, so it travels with those captures without any of them being told
   about it.
3. **A clause on the pin and PNG title.** `captureFromRoot` reads the note and
   carries `chartDeviation` on the payload as its own field.
   `brTitleWithChartDeviation()` appends it, and only when the capture
   actually includes the chart: a table pinned alone is not deviating from
   anything and must not be labelled as though it were. The four panel-local
   paths that put a chart and its table on one card were audited and wired
   individually: `cbExecutePin` and `cbExecutePng` in the cat-buying panel,
   the attributes and CEPs pin in the MA panel, the funnel drop-down pin, and
   `pinWomView`. The MA metrics, Mental Advantage, DoP and Category Context
   paths were read and left alone, because no chart they capture can deviate.

**Why the title and not the subtitle.** `subtitle` renders on a pin card but
not in the PNG, and `baseText` renders in the PNG behind a fixed "Base: "
prefix. `title` renders plainly in both, and `modules/shared` is out of scope
for this change, so the shared renderer could not be given a field of its own.

**Excel is coherent by construction and nothing was added for it.**
`_brExportPanel` walks `table` elements, and so do the panel-local `.xls`
writers. The table never deviates, so an exported sheet always matches the
header set. A test asserts the exporter reads no chart DOM, so the claim
breaks loudly if that ever changes.

## The two chart areas that ship collapsed

Brand Summary and Word of Mouth render their chart behind the panel's own
"Show chart" toggle, so their Chart brands control appears with the chart. That
is right: with no chart there is nothing to deviate. The Chrome census counts
those two separately rather than reporting them as controls that failed to
appear.

## Executed, with the numbers

| Check | Result |
|---|---|
| Brand suite, before the first edit | FAIL 0, WARN 1, SKIP 2, PASS 2780 |
| Brand suite, after | **FAIL 0, WARN 1, SKIP 2, PASS 2865** |
| `test_chart_focus.R` alone | 85 assertions, 0 failures |
| `tests/qa/reachability_check.py` | **PASS**. data-subpanel 5 identical, data-section 29 identical, section ids 13 identical, island classes 8 identical, every parseable island numerically identical, the one unparseable span named in both |
| `tests/qa/drive_destinations.py` | **259 checks, 0 failed**, no console error and no uncaught exception, against 113 before |
| `tests/qa/drive_two_categories.py` | **15 checks, 0 failed**, no console error |
| IPK fixture report | 3,926,103 bytes before, **3,946,054 after**, 0.5 percent larger |

Both reports were generated to the session scratchpad. Nothing was written
into the repo, into OneDrive or into TurasProjects, and `preview_start` was
not used.

**The control census, named rather than counted loosely.** In the fixture's
one full-depth category: header focal selects 1 of 1 visible, header brand-set
triggers 1 of 1 visible, per-panel focal selects 0 of 15 visible, per-panel
brand filters 0 of 16 visible, and Chart brands controls 8 mounted, 8 built,
6 visible beside their chart with 2 behind a Show chart toggle. The eight are
intended and are counted by name so they never read as strays.

**What the Chrome harness now proves about the split.** Per chart: the control
opens matching its table; the popover offers exactly what the header shows and
no more; the focal brand cannot be dropped; after unticking one brand the
table set is unchanged and the chart set is the table set plus that one brand;
the trigger reads "N of M" and carries the deviating style; the note is shown
and names what is missing; a capture of the chart area carries the note and
does not carry the control; and a header change clears the deviation and puts
the chart set back in step with the table set. On the three stacked-bar hosts,
where the chart rows and the table rows both key on `data-cb-brand`, the two
are read apart in the DOM rather than trusted from the state object: the chart
really drops the brand, the table really keeps it, and the chart has exactly
one row fewer.

## The two-category gap, closed as far as a clone can close it

The previous session recorded that `brApplyAllComparisonSets` had never run in
a browser across more than one category, because the IPK fixture has one
full-depth category and the three example generators are broken on main.

`modules/brand/tests/qa/drive_two_categories.py` closes part of that. It
clones the fixture's category panel in the browser under a second key, before
the panel scripts register, so both panels register real subscribers with real
tables and real charts. It passes 15 checks: two distinct groups are found and
both are driven, each header reaches only its own category's panels, the two
headers hold different states at the same time, a Chart brands deviation in
one category does not appear in the other, a header change next door does not
clear it while its own header change does, and nothing throws.

**What it does not prove, stated plainly.** The clone is the same category
twice, with the same brand list, the same numbers and the same labels. It says
nothing about two categories with different brand lists, and nothing about the
category switcher on real, differently shaped data. A genuine second
full-depth category cannot be built from this fixture without inventing survey
data, and that was not done. The loop is no longer untested; it is not yet
tested against real variety.

## Known limits, stated rather than left to be discovered

- **The four elements that have never rendered through the shell with real
  panel fragments still have not.** Branded Reach, Ad Hoc, Audience Lens and
  Shopper Behaviour are absent from the fixture. None of them is in the Chart
  brands scope, so this change adds nothing new to that gap.
- **The deviation does not survive Save.** Same reason as the comparison set:
  a checkbox's `checked` is a property, not an attribute, and the Save button
  serialises `outerHTML`. The note element's text and its
  `data-chartfocus-clause` attribute would survive, so a saved copy could show
  a note with no deviation behind it. That is a real inconsistency and it is
  the same one the comparison set already has. Not fixed here, because fixing
  it properly means giving the lift's mirror a way to serialise control state,
  which is a change to the save path rather than to this control.
- **MA Metrics and Mental Advantage charts still follow the table set.** By
  design, as above. If Duncan wants the split there it is a one-word change in
  two functions plus two more mounts, and it is a behaviour change.
- **`styler` was not run,** for the same reason as the previous session: the
  files this touches would be reformatted whole and the churn would bury the
  change.
- **One pre-existing quirk was observed and left alone.** `brExecutePin` clears
  `content.chartSvg` when the chart is not pinned but never clears
  `content.chartHtml`. It predates this work and is not touched by it.
- **`pinWomView` builds its payload with `html` and `insight` keys** where
  `TurasPins.add` reads `chartSvg`, `tableHtml` and `insightText`. That looks
  wrong and predates this work. The title clause was added there anyway, since
  the title key is honoured, but no claim is made that a WOM pin renders its
  chart today.

## What Duncan still owes

A `launch_turas()` run on the real IPK project: open a chart with several
brands showing, drop one from the chart, check the note reads right, pin it
and confirm the pin card says the chart is narrower than its table. Then the
Fable pre-merge review, briefed as independent of this session. Not merged,
not pushed.

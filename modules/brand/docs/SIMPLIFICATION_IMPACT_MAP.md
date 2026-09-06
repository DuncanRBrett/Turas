# Brand report simplification: impact map

**Date:** 2026-09-06. Stage 1 deliverable for the five-destination refactor.
**Branch:** `feature/brand-simplification`, cut from main at 7275bd66.
**Brief:** `docs/v2_lift/HANDOVER_BRAND_SIMPLIFICATION_FOR_OPUS.md` section 2,
against `docs/v2_lift/BRIEF_BRAND_SIMPLIFICATION_2026-09-04.md` and the
ChatGPT brief sections 5 to 13.

## How this was built

Every id, attribute and label below was read out of code or out of a report
this session generated. Nothing is inferred from the earlier documents.

- Source of the DOM facts: the IPK Wave 1 fixture report, generated in this
  worktree with `run_brand()` on
  `modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx`
  (`project_root` = the fixture directory) and rendered with
  `generate_brand_html_report()`. Run status PASS, 3.79 MB, no chart transform
  warning.
- Source of the structure: `modules/brand/lib/html_report/03_page_builder.R`
  (`build_br_tab_nav()` at line 137, `build_br_category_panel()` from line 481,
  the `flat_tabs` list from line 528), `modules/brand/R/01b_section_insights.R`
  (the anchor maps at lines 59 to 133), `modules/brand/R/00_main.R` (the
  element gating), and the panel files named in each row.
- The fixture carries one full-depth category, Dry Seasonings and Spices
  (`CategoryCode` DSS, `cat_id` `dss`), plus eight awareness-only categories
  that produce no category panel. Anchors are written here with the live `dss`
  suffix; the general form is `<element>-<cat_id>` where `cat_id` is the
  lower-cased CategoryCode with non-alphanumerics replaced by hyphens.
- Baseline suite before any edit: 2535 pass, 0 fail, 2 skip, 1 warn, 97.9 s.

## 1. Where the navigation lives

Three navigation layers exist today.

1. **Top-level tabs**, built by `build_br_tab_nav()`. Buttons carry
   `data-tab`; `switchBrandTab()` in `js/brand_report.js` shows
   `#panel-<tab>`. Order: Portfolio, Summary, one tab per full-depth category,
   Brand Assets, Pinned Views, About.
2. **Category sub-tabs**, built inside `build_br_category_panel()`. Buttons
   carry `data-group` (the cat_id), `data-subtab`, `data-subpanel` and
   `data-internal-tab`, and call `switchCategorySubtab()`. This is the flat bar
   the refactor replaces.
3. **Panel-internal sub-navs**, emitted by the panels themselves:
   `.fn-subnav` (funnel), `.ma-subnav` (mental availability) and `.cb-subnav`
   (category buying). The first two are hidden by
   `03_page_builder.R:1296`, `.fn-subnav, .ma-subnav { display: none !important; }`,
   and are driven by `switchCategorySubtab()` clicking the hidden buttons.
   `.cb-subnav` is visible and is the only second tier a reader sees today.

## 2. Category sub-tabs, today to new home

One row per entry in the `flat_tabs` list. All twelve possible rows are listed,
including the four that the IPK fixture does not produce. "In IPK fixture"
records whether the row rendered in the report generated this session.

| # | Today's label | data-subtab | data-subpanel | data-internal-tab | Wrapper id | data-section anchors inside | Panel R file | JS file | Config gate | In IPK fixture | New home |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Brand Funnel | `fn-funnel` | `fn` | `funnel` | `section-funnel-dss` | `funnel-dss` (wrapper plus one toolbar) | `panels/03_funnel_panel.R`, `_chart`, `_table`, `_styling` | `js/brand_funnel_panel.js` | `element_funnel` and `Analysis_Depth = full` | yes | Brand and Buying, main view, first |
| 2 | Brand Attitude | `fn-relationship` | `fn` | `relationship` | (shares `section-funnel-dss`) | `attitude-dss` | `panels/03_funnel_panel.R` (`.fn_relationship_section`) | `js/brand_funnel_panel.js` | `element_funnel` | yes | Brand Meaning, main view |
| 3 | Brand Attributes | `ma-attributes` | `ma` | `attributes` | (shares `section-ma-dss`) | `attributes-dss` | `panels/02_ma_panel.R`, `_table`, `_chart` | `js/brand_ma_panel.js` | `element_mental_avail` plus CEP rows present | yes | Brand Meaning, main view |
| 4 | Category Entry Points | `ma-ceps` | `ma` | `ceps` | (shares `section-ma-dss`) | `ceps-dss` | `panels/02_ma_panel.R`, `_table`, `_chart` | `js/brand_ma_panel.js` | `element_mental_avail` | yes | Mental Availability, main view, evidence |
| 5 | Mental Advantage | `ma-advantage` | `ma` | `advantage` | (shares `section-ma-dss`) | `advantage-dss` | `panels/02_ma_panel_advantage.R`, `_styling` | `js/brand_ma_advantage.js` | `element_mental_avail` plus `cep_advantage` or `attribute_advantage` present | yes | Mental Availability: quadrant and action list in the main view, full matrix and buyer-gap diagnostic in Advanced |
| 6 | MA Metrics | `ma-metrics` | `ma` | `metrics` | `section-ma-dss` (wrapper) | `ma-dss` (wrapper), `metrics-dss` (toolbar) | `panels/02_ma_panel.R` (`.ma_metrics_section`) | `js/brand_ma_panel.js` | `element_mental_avail` | yes | Mental Availability, main view, headline |
| 7 | Category Buying | `rep` | `rep` | (none) | `section-repertoire-dss` | `repertoire-dss` | `panels/08_cat_buying_panel.R` and four siblings | `js/brand_cat_buying_panel.js` | `element_repertoire` and `Analysis_Depth = full` | yes | Split by sub-tab, see section 3 |
| 8 | Word of Mouth | `wom` | `wom` | (none) | `section-wom-dss` | `wom-dss` | `panels/05_wom_panel.R`, `_chart`, `_styling` | `js/brand_wom_panel.js` | `element_wom` | yes | Brand Meaning, main view |
| 9 | Branded Reach | `branded_reach` | `br` | (none) | `section-branded_reach-<cat_id>` | `branded_reach-<cat_id>` | `panels/10_branded_reach_panel.R` | `js/brand_branded_reach_panel.js` | `element_branded_reach`, default off, plus at least one ad | no | Brand Meaning, Advanced |
| 10 | Demographics | `demographics` | `demo` | (none) | `section-demographics-dss` | `demographics-dss`, plus `section-demo-panel-dss-q0` to `-q6`, one per question | `panels/11_demographics_panel.R`, `_chart`, `_table` | `js/brand_demographics_panel.js` | `element_demographics`, default on | yes, 7 question cards | Audience, main view |
| 11 | Ad Hoc | `adhoc` | `ah` | (none) | `section-adhoc-<cat_id>` | `adhoc-<cat_id>` | `panels/12_adhoc_panel.R` | `js/brand_adhoc_panel.js` | `element_adhoc`, default on, plus non-placeholder questions | no, placeholder only | Audience, main view, last |
| 12 | Audience Lens | `audience_lens` | `al` | (none) | `section-audience_lens-<cat_id>` | `audience_lens-<cat_id>` | `panels/13_audience_lens_panel.R` | `js/brand_audience_lens_panel.js` | `element_audience_lens`, default off | no | Audience, Advanced |

Anchor counts in the fixture, as a check on the rehoming: `funnel-dss` appears
four times (wrapper, insight wrap, container, textarea and rendered div),
`attitude-dss`, `attributes-dss`, `advantage-dss`, `ceps-dss` and `metrics-dss`
three times each, `ma-dss` once, `repertoire-dss` six times, `wom-dss` five,
`demographics-dss` five, and each `section-demo-panel-dss-qN` three times.

## 3. Category Buying sub-sub-tabs

The panel emits its own visible `.cb-subnav`. Buttons carry `data-cb-tab`;
the matching content div is `.cb-subtab[data-cb-tab]`. None of these has its
own `data-section` anchor: the whole panel sits under `repertoire-dss`, and one
toolbar (`.br-section-toolbar.cb-toolbar-top`) carries the single pin, PNG and
Excel control for all of them.

| # | Today's label | data-cb-tab | Builder in `08_cat_buying_panel.R` | Config gate | In IPK fixture | New home |
|---|---|---|---|---|---|---|
| 1 | Category Context | `context` | `.cb_context_tab()`, plus `cb_buying_location_html()` when slot-indexed channel data exists | `element_repertoire`, needs `cat_buying_frequency` or `repertoire` | yes | Brand and Buying, main view |
| 2 | Brand Summary | `brands` | `.cb_brands_tab()` in `08_cat_buying_panel_table.R` | `element_repertoire`, needs `dirichlet_norms` | yes | Brand and Buying, main view, merged into the page as the brief asks |
| 3 | Dirichlet Norms | `norms` | `.cb_norms_tab()` (norms table, Double Jeopardy scatter, SCR bars) | `element_repertoire`, needs `dirichlet_norms` PASS | yes | Brand and Buying, Advanced |
| 4 | Loyalty Segmentation | `loyalty` | `.cb_ma_style_tab(scope = "loyalty")` | needs `buyer_heaviness`, which needs `dirichlet_norms` to have passed | yes | Brand and Buying, Advanced |
| 5 | Purchase Distribution | `dist` | `.cb_ma_style_tab(scope = "dist")` | needs `buyer_heaviness` | yes | Brand and Buying, Advanced |
| 6 | Buyer Heaviness | `heaviness` | `.cb_heaviness_tab()` | needs `buyer_heaviness` | yes | Brand and Buying, Advanced |
| 7 | Duplication of Purchase | `dop` | `.cb_dop_tab()` | needs `repertoire` | yes | Brand and Buying, Advanced |
| 8 | Shopper Behaviour | `shopper` | `cb_shopper_tab_html()` in `08_cat_buying_panel_shopper.R`; the nav button appears only when `shopper_location` or `shopper_packsize` is present | no dedicated flag, gated by result presence under `element_repertoire` | no | Audience, Advanced |

**Panel KPI strip.** `.cb_kpi_strip()` is called at `08_cat_buying_panel.R`
line 131, outside every sub-tab, immediately under the brand picker. In the
fixture it renders five chips: mean purchases per category buyer, average
brands bought per category buyer, focal SCR with its Dirichlet expected value,
focal 100 percent loyal with its expected value, and the focal light-buyer
index. The chips carry `data-kpi` and are re-hydrated by the JS focal switcher
from the `cb-panel-data` island.

New home, and this is a judgement call: **the KPI strip goes to Brand and
Buying, main view**, not Advanced. The ChatGPT brief section 7.3 names
penetration, average purchases, volume share and SCR as the headline buying
metrics, and these chips are exactly that. Only the Dirichlet Norms sub-tab,
which is the model diagnostic rather than the observed result, goes to
Advanced. Duncan's steer said Advanced was the likely home for both; the split
is proposed here with that reason and can be reversed in one line.

A second, smaller KPI strip sits inside the Buyer Heaviness sub-tab
(`data-kpi="hv-heavy"` and `hv-wbar`) and travels with it into Advanced.

## 4. Panel-internal tabs that the category bar does not expose

| Panel | Internal tab | Attribute | Reachable today | Note |
|---|---|---|---|---|
| Funnel | Summary | `data-fn-subtab-target="summary"` | **No** | `.fn_cards_section()` renders it, but no `flat_tabs` entry routes to it and `.fn-subnav` is hidden by CSS. Dead in the report as shipped. |
| Funnel | Funnel | `funnel` | yes, via `fn-funnel` | |
| Funnel | Relationship | `relationship` | yes, via `fn-relationship` | The visible label is Brand Attitude and the insight anchor is `attitude-<cat_id>`, not `relationship-<cat_id>`. |
| Mental Availability | Brand Attributes | `attributes` | yes | |
| Mental Availability | Category Entry Points | `ceps` | yes | |
| Mental Availability | Mental Advantage | `advantage` | yes | |
| Mental Availability | Headline Metrics | `metrics` | yes, via `ma-metrics` | The internal button says "Headline Metrics", the category bar says "MA Metrics", and the anchor is `metrics-<cat_id>`. Both labels already resolve to the same anchor in `.BRAND_CATEGORY_SECTION_MAP`. |

The funnel Summary cards need a ruling: rehoming has no current home to move
them from. Proposal, for Duncan: leave them unreached in Stage 2, and consider
them as a candidate for the Brand and Buying Advanced drawer in a later stage.
Do not silently switch them on as part of the shell work.

## 5. The Summary tab, which becomes the Overview

Built by `build_brand_summary_panel()` in `panels/14_summary_panel.R`, rendered
by `js/brand_summary_panel.js`, fed by the `brsum-data` JSON island. The legacy
`build_br_summary_panel()` at `03_page_builder.R:400` is only a fallback and
did not run in the fixture.

| Card | data-section | Content today | New home |
|---|---|---|---|
| Hero | `brsum-hero` | Generated headline sentence plus the focal metric strip (MMS, MPen, Bought target, Loyalty Sole, Net WOM, each with a category average) | Overview, top strip plus verdict |
| Mental availability | `brsum-mental` | MPen, Network Size, MMS, Share of Mind with category average and leader | Overview, links to Mental Availability |
| Funnel | `brsum-funnel` | Mini funnel for the focal brand with the category average | Overview, moves to the nested default with the rest |
| What is working | `brsum-working` | Top three over-indexing CEPs and attributes | Overview, the three strengths |
| Where it is weak | `brsum-weak` | Top three under-indexing CEPs and attributes | Overview, the three gaps |
| Conversation | `brsum-conversation` | Word of mouth heard and said | Overview, secondary, links to Brand Meaning |
| Repertoire ties | `brsum-repertoire` | Duplication of purchase partners and rivals | Overview, secondary, links to Brand and Buying |
| Analyst commentary | `brsum-insight` | The `.brsum-insight-editor` textarea | Overview, kept as is |

The category switcher already exists here as `.brsum-dropdown-bar`, with a
category select and a brand select. The persistent switcher that decision 4
asks for on every destination can reuse this control rather than inventing a
second one.

The panel also carries the lift's "Which penetration is which" block
(`penetration_notes` in the island, `.brsum-pen-notes` in the DOM). It becomes
the first item in the Overview's "How this works" drawer.

## 6. Top-level tabs, for context

These are outside the five-destination change but must keep working.

| Tab | data-tab | Sub-tabs | data-section anchors | Panel R file | JS file | Config gate |
|---|---|---|---|---|---|---|
| Portfolio | `portfolio` | Overview, Footprint, Competitive Set, Category Context (`pf-sub-btn` with `data-pf-subtab`, containers `#pf-subtab-<key>`) | `pf-overview`, `pf-footprint`, `pf-constellation`, `pf-clutter` | `panels/09_portfolio_panel.R` and siblings | `js/brand_portfolio_panel.js`, `js/brand_portfolio_overview.js` | `element_portfolio` |
| Summary | `summary` | none | the eight `brsum-*` above | `panels/14_summary_panel.R` | `js/brand_summary_panel.js` | always |
| Category | `cat-<cat_id>` | section 2 | section 2 | many | many | per element |
| Brand Assets | `dba` | none | (not present in the fixture) | `panels/07_dba_panel.R` and siblings | `js/brand_dba_panel.js` | `element_dba`, default off |
| Pinned Views | `pinned` | none | n/a | `03_page_builder.R` | `js/brand_pins.js` | always |
| About | `about` | none | n/a | `03_page_builder.R` | none | always |

## 7. What must not change

- **Every `data-section` value in sections 2, 3, 5 and 6.** Pins, PNG capture
  and Excel export resolve a section by
  `document.querySelectorAll('[data-section="' + sectionId + '"]')`
  (`js/brand_pins.js` lines 200 and 221), and `_brExportPanel()` in
  `js/brand_report.js` looks up `#section-<id>` first and the attribute second.
- **The wrapper ids `section-<element>-<cat_id>`**, for the same reason.
- **The Section_Insights anchors.** `test_section_insights.R` asserts
  `funnel-pos`, `attitude-pos`, `attributes-pas`, `ceps-pas`, `advantage-pas`,
  `metrics-pas`, `repertoire-dss`, `wom-bak`, `demographics-bak`, `adhoc-bak`,
  and the six `_REPORT` anchors. Those names are a config contract: analysts
  have already typed them into Section_Insights sheets.
- **The commentary selectors** `.br-insight-editor`, `.fn-insight-textarea`,
  `.ma-insight-box-text` and `.brsum-insight-editor`, in that precedence order
  (`js/brand_pins.js` lines 142 to 146).
- **The `switchCategorySubtab()` route into hidden panel buttons.** Clicking
  `.ma-subtab-btn[data-ma-subtab-target]` and
  `.fn-subtab-btn[data-fn-subtab-target]` is how the MA and funnel panels get
  their own state updates. Any new shell must keep clicking them.
- **The `.br-insight-wrap[data-insight-internal-tab]` show and hide logic.**
  Six wraps exist per category (funnel, relationship, attributes, advantage,
  ceps, metrics) and `switchCategorySubtab()` must still find them inside the
  active container.
- **Panel-native toolbars.** The funnel subpanel carries
  `fn-pin-dropdown-btn`, `fn-png-btn`, `fn-export-btn` and
  `fn-rel-export-btn`; the MA subpanel carries four each of
  `ma-pin-dropdown-btn`, `ma-png-btn` and `ma-export-btn` plus the advantage
  focal pair; the repertoire, WOM and demographics subpanels carry the shared
  `br-pin-btn`, `br-png-btn` and `br-export-btn`, and demographics adds seven
  per-question `br-pin-btn.demo-card-tool` pairs. Stage 5 consolidates the
  shared toolbars, not the panel-native ones.

## 8. Destination summary

| Destination | Main view | Advanced drawer |
|---|---|---|
| Overview | Summary panel, extended per Stage 3 | "How this works", holding the methodology text and the "Which penetration is which" block |
| Mental Availability | MA Metrics headline, Category Entry Points, Mental Advantage quadrant and action list | Full Mental Advantage matrix, buyer-gap diagnostic, MA methodology |
| Brand and Buying | Brand Funnel (nested default), Category Buying KPI strip, Category Context, Brand Summary | Dirichlet Norms, Loyalty Segmentation, Purchase Distribution, Buyer Heaviness, Duplication of Purchase |
| Brand Meaning | Brand Attitude, Brand Attributes, Word of Mouth | Branded Reach, full attribute matrices |
| Audience | Demographics, Ad Hoc | Audience Lens, Shopper Behaviour |

The reader faces nineteen places to click inside one category today: eleven of
the twelve category sub-tabs are leaves, and the twelfth, Category Buying, opens
eight more. They become five destinations, four of them with an Advanced drawer
and the Overview with a "How this works" drawer instead. Every one of the
nineteen appears exactly once in the table above.

## 9. Findings that need a ruling before Stage 2

1. **The funnel Summary cards are unreachable today.** Section 4. They need a
   home or an explicit decision to leave them dead.
2. **The Category Buying KPI strip is split from the Dirichlet Norms tab.**
   Section 3. Proposed, with a reason, rather than following the handover's
   default of putting both in Advanced.
3. **On the IPK fixture the focal brand has no under-indexers and no Defend or
   Build items.** Every CEP and attribute delta for IPK is positive, and both
   `focal_summary$defend` and `focal_summary$build` are empty, all fifteen CEPs
   and all fifteen attributes landing on "maintain". The Overview's three gaps
   and its Protect and Build actions therefore have nothing to show on this
   fixture. The mockup shows the empty state rather than inventing items; the
   Stage 3 build needs the same honesty, and a rule for what the Actions block
   says when the lists are empty.
4. **Two label mismatches**, both harmless today but worth settling while the
   nav is being rewritten: "MA Metrics" against "Headline Metrics", and "Brand
   Attitude" against the internal tab name "relationship".

# Brand report simplification: the ChatGPT brief set against the v2 lift, and a way forward

**Date:** 2026-09-04. Fable assessment for Duncan, to decide whether to commission an Opus build session.
**Inputs read this session:** the ChatGPT brief (`Turas_Brand_Simplification_Brief_for_Claude_Code.docx`), the report it reviewed (`IPK/output/brand/8844718_Brand_Config_report.html`, read only), timelaps.io (homepage, public demo, 2026 guide), the parked review `modules/brand/docs/BRAND_REPORT_V2_UPGRADE_REVIEW.md`, the Phase 1 plan on commit f72410e6, the current `03_page_builder.R`, `03a_funnel_derive.R` and the summary panel JS, and the lift branch `feature/brand-v2-lift` (notes in `SESSION_NOTES_BRAND_2026-09-03.md`).

## 1. Bottom line

The ChatGPT brief and the v2 lift are two different layers of the same product, and they do not compete.

- The **v2 lift** (done, on `feature/brand-v2-lift`, not merged) fixed what the numbers and the file do: Dirichlet norms that never computed, commentary lost on Save, unweighted penetration beside weighted cells, significance without a design effect, unescaped data islands, a Branded Reach element that never ran, and bases stated on the face of every penetration figure. None of that changed what the report looks like on first contact.
- The **ChatGPT brief** is about first contact: too many peer destinations, the analytical model exposed as navigation, three competing summaries, a funnel whose stages are not nested. It is the parked Recommendation A from June, made concrete with a five-destination model and a Timelaps benchmark. Its diagnosis is accurate against the file it reviewed; the counts are verified below.

Recommendation: yes, take it forward, as a **report-layer information-architecture refactor** that builds on the lift branch, with one gate before code (a static mockup Duncan approves) and one product decision that has to be made first (the funnel). Opus is the right model for the build, with a Fable review at the mockup gate and before merge.

## 2. What the brief gets right, verified against the file

| Brief claim | Verified |
|---|---|
| Nine peer sub-tabs per category | Yes: Brand Funnel, MA Metrics, Category Buying, Word of Mouth, Brand Attitude, Brand Attributes, Category Entry Points, Mental Advantage, Demographics, in all four categories |
| Category Buying opens six more | Yes: context, brands, loyalty, dist, heaviness, dop |
| Three competing summaries | Yes: the Summary tab, Category Buying's Brand Summary, and the MA headline cards |
| Methodology dominates | 69 insight textareas, 2,324 "significant" mentions, 40 pin, 69 PNG and 42 Excel buttons in one 6.9 MB file |
| The funnel is not nested | Yes, in every category. Focal brand, absolute % of all respondents: Baking aware 34 / prefer 48; Pasta 40 / 65; Pour Over 50 / 66; Dry Seasoning 42 / 59. The stage definition text says "Aware respondents who actively prefer the brand", which the absolute numbers contradict, because the attitude question is answered by more people than the aided-awareness pick. The panel already has a "% of aware" mode (Baking: 100 / 67 / 55 / 37) and a "% of previous stage" mode; the default is the absolute view. The payload also already carries the cumulative chain count per stage (`base_chain_filtered`), and dividing it by the base gives a genuinely nested funnel as % of all respondents with no engine change: Baking 34 / 23 / 15 / 12. |

Two things the brief could not know:

- The order it saw (Funnel, MA Metrics, Category Buying, WoM first, then the rest) is the June Slice 1 tiering: the file is dated 17 June 2026 and carries Slice 1's `br-subtab-sep` and `br-subtab-btn--appendix` markers (26 of them). Today's main renders the older order (Funnel, Attitude, Attributes, CEPs, Advantage, MA Metrics, Buying, WoM, ...). Either way the count is nine.
- The Summary tab already generates a verdict sentence from the numbers (rank by Mental Market Share plus a mental-versus-physical availability clause) and a closing strip. The Overview the brief asks for is an extension of that panel, not a new one.

## 3. What Timelaps actually is, for the benchmark

From the public demo: six sidebar sections (Funnel, Moments, Attributes, Advertising, Category, Profile), each two or three levels deep. The landing screen is four nested funnel metrics (Awareness, Consideration, Past 3 Month Buyers, Frequent Buyers) with a percentage-point gap to the competitor average and one comparison chart. Brand selection is a dropdown ("Compare to: Category Average, ..." and "Brands (max 5)"). Methodology is nearly invisible; there is an "AI Insights" label with counts. The product is a single-category continuous tracker, 4,000 or more respondents a month, priced against agency tracking.

What that means for Turas: the benchmark is comprehension speed and a nested funnel with conversion, not analytical scope. Turas has more (Mental Advantage, Dirichlet norms, Duplication of Purchase, buyer heaviness, analyst commentary, pins) and a different shape: one study can carry four categories, as IPK does. Timelaps never has to solve the four-category navigation problem; we do, and the brief's "five destinations within a category" leaves the category level as it is (a tab per category). That is the one place the brief needs a design decision it does not make.

## 4. The way forward

### Gate 0: merge the lift first

The lift branch changes engine outputs and the report's honesty; the simplification changes the report's shape. Doing the second on top of the first avoids a three-way merge on `03_page_builder.R`, `14_summary_panel.R` and the panel JS. Duncan's steps: regenerate through `launch_turas()`, eyeball, Fable pre-merge review, merge. Then the simplification branches off main.

### Stage 1: impact map and a static mockup (before any code)

June's lesson: Slice 1 (a tiered sub-tab bar) did not convince, because it was an increment on the existing shape. This time the first deliverable is a picture Duncan can react to: one HTML mockup per destination, built from the real IPK payload, showing the five destinations, the Overview, and one worked Advanced drawer. Plus a one-page impact map: every existing panel, its section id and pin anchor, its new home, and the Section_Insights anchors that must keep resolving. Fable reviews the mockup against the brief's acceptance criteria before the build starts.

Reuse from June: the Slice 1 commits (394852ad, f72410e6, ebd4ea5a) are held by the local tag `rescue/review-brand-report-v2-upgrade-2026-06`. They carry `modules/brand/docs/PHASE1_CLARITY_IMPLEMENTATION_PLAN.md` (the seam description is the start of the impact map), the pure helper `build_br_subtab_nav()` with `.BR_PRIMARY_SUBTABS` as its single source of truth, and `test_subtab_nav_tiers.R` (36 assertions). The helper's tiering idea becomes the destination grouping in Stage 2.

### Stage 2: the five-destination shell, rehoming only

Per category: Overview, Mental Availability, Brand and Buying, Brand Meaning, Audience, plus an Advanced route. Existing panels move behind these without deleting or recomputing anything. Section ids, `data-section` pin anchors and the TurasPins store keep their names, so pins, PNG and Excel keep working and old Section_Insights sheets still land. Toggled-off elements leave their destination empty or hidden; the nav shape never changes.

Mapping (from the brief, checked against the panels):

| Today | New home |
|---|---|
| Summary tab (per category) | Overview |
| MA Metrics, Category Entry Points, Mental Advantage | Mental Availability: headline cards, then CEPs, then the quadrant and action list; the full matrix and the buyer-gap diagnostic under Advanced |
| Brand Funnel, Category Buying: Category Context and Brand Summary | Brand and Buying |
| Loyalty Segmentation, Purchase Distribution, Buyer Heaviness, Duplication of Purchase | Brand and Buying, Advanced |
| Brand Attitude, Brand Attributes, Word of Mouth, Branded Reach | Brand Meaning |
| Demographics, Audience Lens, Ad Hoc | Audience (Ad Hoc stays reachable; it is study-specific) |

### Stage 3: the Overview

Extend the existing summary hero rather than start again: top strip of four to six headline numbers with the gap to category average, the generated verdict sentence, three strengths and three gaps taken from the existing over- and under-indexer cards, and three actions labelled Protect, Build, Investigate derived from the Mental Advantage quadrant and the funnel's biggest drop. Every number links to its evidence destination. The "Which penetration is which" block from the lift stays, as the first item under "How this works".

### Stage 4: the funnel decision (Duncan rules; see section 5)

### Stage 5: chrome

Significance as a toggle, default clean. One export toolbar per destination instead of per table. One commentary slot per destination plus the existing per-chart boxes only where an analyst actually writes (the Summary and the MA headline). Methodology behind a "How this works" control on each page, default collapsed, with the bases and caveats intact.

### Stage 6: QA

Every existing analytical view reachable; numbers unchanged except where the funnel decision changes them; pins, PNG, Excel, focal switching, category switching, commentary persistence and Save round-trip proved with headless Chrome as in the lift; every category configuration in the fixtures (one, three and nine categories, plus IPK's four) renders without blank destinations; brand suite green.

### Sequencing note for a multi-category study

The category tabs stay as the first choice (as today), and the five destinations are constant inside each. The alternative, a category picker inside each destination, is closer to Timelaps but hides the portfolio story that a four-category study exists to tell. Recommend: keep category tabs, add a persistent category switcher on every destination so a user can compare the same page across categories without going back up.

## 5. Decisions for Duncan, with a recommendation each

1. **The funnel.** Four options. (d) Default the visual to the nested chain as % of all respondents, which the payload already carries (`base_chain_filtered` over the base): Baking reads aware 34, prefer 23, bought 15, recent 12; awareness still compares brands, the shape narrows, the term funnel becomes honest, and no engine number changes. (a) Default to "% of aware": also nested, but it pins every brand's awareness at 100 and so loses the brand comparison at the top (Baking 100 / 67 / 55 / 37). (b) Change the engine so consideration is intersected with awareness: makes the definition text true but moves numbers in every client deliverable. (c) Rename to Brand relationship and show parallel indicators. Recommend (d), with today's absolute view and (a) kept as the analyst's toggles and the stage definition text corrected to say what each view shows. Decide before Stage 2.
2. **Mockup gate.** Approve a static mockup before the build starts. Recommend yes; it is the cheapest point to change direction and the June increment did not convince.
3. **Destination names.** The brief's five. Recommend accepting them, with one change: "Brand and Buying" rather than an ampersand, and "Audience" only if Audience Lens is folded into it.
4. **Category level.** Keep category tabs plus a persistent switcher on each destination (recommended), or category as a picker inside destinations.
5. **Advanced route.** An in-page drawer per destination (recommended, keeps evidence local) or a sixth tab.
6. **Session.** Opus for the build, Fable for the mockup review and the pre-merge review. The brief is written as an implementation brief already; the handover should add the impact map, the funnel ruling, the pin and Section_Insights anchor constraints, and the fixture list.

## 6. What not to do (the brief's list, plus two)

The brief's list stands: no deleting analyses, no copying Timelaps styling, no new statistical methods, no burying bases in tooltips, no second navigation system, no scattering evidence. Two additions: do not rebuild the summary hero from scratch, and do not touch the lift branch's engine changes; only funnel ruling (b) would put an engine change in scope, and (d) is recommended instead.

## 7. Effort and risk

Report layer only except for funnel option (b). Files: `03_page_builder.R` (tab and sub-tab shell, CSS), `brand_report.js` (nav switching), `14_summary_panel.R` and `brand_summary_panel.js` (Overview), each panel's sub-nav, `brand_pins.js` (anchor mapping). Risk is regression in what is shown, not wrong numbers; the mitigation is the impact map and the headless-Chrome QA. Two sessions of Opus work is a fair expectation: one for the mockup and shell, one for Overview, funnel, chrome and QA, with Fable at both gates.

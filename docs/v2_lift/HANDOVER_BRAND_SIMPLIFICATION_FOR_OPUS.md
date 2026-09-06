# Brand report simplification: handover for the Opus build session

**Date:** 2026-09-04. Written by the Fable assessment session for the Opus session that will build it.
**Read, in this order:** (1) this document; (2) `docs/v2_lift/BRIEF_BRAND_SIMPLIFICATION_2026-09-04.md` (the assessment and the six decisions); (3) the ChatGPT brief `~/Downloads/Turas_Brand_Simplification_Brief_for_Claude_Code.docx` (sections 5 to 13 are the spec; extract with python zipfile, the docx skill, or pandoc); (4) `docs/v2_lift/SESSION_NOTES_BRAND_2026-09-03.md` (what the lift branch changed in the report layer, so you do not undo it); (5) `modules/brand/docs/BRAND_REPORT_V2_UPGRADE_REVIEW.md` section 5 and, from the tag named below, `PHASE1_CLARITY_IMPLEMENTATION_PLAN.md`. Load the `fable-method` skill. Project CLAUDE.md rules apply.

## 0. Decisions, locked as defaults (Duncan may veto; his message wins)

1. **Funnel default is the nested chain as % of all respondents.** The payload already carries it: `base_chain_filtered / n` per stage (Baking on the IPK build: aware 34, prefer 23, bought 15, recent 12). Today's absolute view and the "% of aware" view stay as toggles. No engine change. The stage definition text is corrected to say what each view shows.
2. **A static mockup is approved before any shell code.** Stage 1 ends with Duncan's yes and a Fable review; do not start Stage 2 without both.
3. **Destination names:** Overview, Mental Availability, Brand and Buying, Brand Meaning, Audience, plus an Advanced route. Spelled out, no ampersand.
4. **Category level stays as category tabs**, with a persistent category switcher on every destination so the same page can be compared across categories.
5. **Advanced is an in-page drawer per destination**, not a sixth tab.
6. **Gate 0: build on top of the lift.** If `feature/brand-v2-lift` has been merged to main, branch off main. If it has not, branch off `feature/brand-v2-lift` and say so in your notes; do not re-do or undo its changes.

## 1. Ground rules

- Work in a git worktree of your own (`git worktree add ../Turas-brand-simplify -b feature/brand-simplification <base>`), never in the main checkout: other sessions run there. The worktree needs `renv/library` symlinked to the main checkout's library and the three IPK fixture workbooks copied in (`modules/brand/tests/fixtures/ipk_wave1/*.xlsx`, gitignored); see the lift notes for the exact steps.
- Prefix every R run with `TURAS_ROOT=<your worktree>`.
- Fix code and run suites only. **Duncan regenerates real reports through `launch_turas()` and eyeballs them.** Never run the pipeline on OneDrive projects and never write into `TurasProjects`.
- Baseline suite before the first edit: `Rscript -e 'testthat::test_dir("modules/brand/tests/testthat")'`. On the lift branch tip it is 2360 pass, 0 fail, 2 skip, 1 warn. Keep it at 0 failures at every commit.
- Report layer only: `modules/brand/lib/html_report/` and its `js/` and `panels/`. Engines under `modules/brand/R/` are not in scope except the funnel definition text in `03a_funnel_derive.R`.
- Loader traps: `99_html_report_main.R` sources every `panels/*.R` by glob, and bundles JS from an explicit list at its lines 274 to 288 plus `brand_report.js` and `brand_pins.js`; a new JS file must be added to that list. Some tests source panel files directly (`test_branded_reach.R`, `test_cat_buying_panel.R`, `test_dba_panel.R`); a new helper used by a panel must be sourced there too.
- Every new string a reader sees: plain English, no em dashes, no unexplained acronyms in navigation.
- Pins, PNG and Excel export hang off `data-section` anchors and section ids; Section_Insights pre-fill hangs off anchors tested in `test_section_insights.R`. Renaming any of those breaks saved work. Keep them.
- Keep an implementation log. Deviations logged conservatively. Final summary states what was executed to verify each claim.

## 2. Stage 1: impact map and mockup (deliverable, no shell code)

**Impact map** (`modules/brand/docs/SIMPLIFICATION_IMPACT_MAP.md`): one row per existing sub-tab and sub-sub-tab: today's label, its `data-subtab` and `data-subpanel` values, section ids and pin anchors inside it, the panel R file and JS file that render it, the config flag that toggles it, and its new home (destination, and main view or Advanced). Start from the seam description in the Phase 1 plan: `build_br_tab_nav()` and `build_br_category_panel()` in `03_page_builder.R` (the `flat_tabs` list is at its lines 497 to 560), `switchBrandTab()` and `switchCategorySubtab()` in `brand_report.js`, buttons carrying `data-group / data-subtab / data-subpanel / data-internal-tab`, and the category-buying sub-nav (`data-cb-tab`: context, brands, loyalty, dist, heaviness, dop) and MA sub-nav (`data-ma-subtab-target`: metrics, ceps, attributes, advantage).

**Mockup**: generate the IPK fixture report in your worktree (the lift session's recipe: source `modules/brand/R/00_main.R` and `modules/brand/lib/html_report/99_html_report_main.R`, `run_brand()` on `modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx`, then `generate_brand_html_report()` to a scratch path). From that real output, build one static HTML file that shows the new shell for the Dry Seasonings category: the five destinations, the Overview as specified in Stage 3, one destination with its Advanced drawer open, the category switcher, and the funnel in its new default. It can be hand-assembled from the generated markup and the report's own CSS; it does not have to be produced by the pipeline yet. Put it in the scratchpad and send it to Duncan with SendUserFile. Duncan says yes or redirects. A Fable review checks it against the ChatGPT brief's section 12 acceptance criteria.

Reuse: the June Slice 1 commits are held by the local tag `rescue/review-brand-report-v2-upgrade-2026-06`. `git show <tag>:modules/brand/lib/html_report/03_page_builder.R` has `build_br_subtab_nav()` and `.BR_PRIMARY_SUBTABS`; `git show <tag>:modules/brand/tests/testthat/test_subtab_nav_tiers.R` has 36 structural assertions. The tiering idea becomes the destination grouping.

## 3. Stage 2: the five-destination shell, rehoming only

Replace the per-category flat sub-tab bar with five destination buttons. Each destination is a container that holds the existing sub-panels unchanged. Mapping:

| Today | New home |
|---|---|
| Summary tab content for the category | Overview (Stage 3) |
| MA Metrics | Mental Availability, headline |
| Category Entry Points | Mental Availability, evidence |
| Mental Advantage | Mental Availability: quadrant and action list in the main view; full matrix and buyer-gap diagnostic in Advanced |
| Brand Funnel | Brand and Buying, first |
| Category Buying: Category Context, Brand Summary | Brand and Buying, main view (merge the Brand Summary into the page; remove it as a destination) |
| Loyalty Segmentation, Purchase Distribution, Buyer Heaviness, Duplication of Purchase | Brand and Buying, Advanced |
| Brand Attitude, Brand Attributes, Word of Mouth, Branded Reach | Brand Meaning |
| Demographics, Audience Lens, Ad Hoc | Audience (Ad Hoc last; it is study-specific) |

Rules: a destination with nothing configured is hidden, never shown empty; the nav shape is otherwise constant across categories and studies; `switchCategorySubtab()` keeps working for the internal panel tabs (it clicks hidden `.ma-subtab-btn` and `.fn-subtab-btn` buttons; keep that route); every existing section id, `data-section` anchor and TurasPins entry keeps its name; the `.br-insight-wrap[data-insight-internal-tab]` visibility logic in `switchCategorySubtab` must still find its wraps. A test in the style of `test_subtab_nav_tiers.R` asserts: five destination buttons per category, every old `data-subpanel` present exactly once under some destination, no orphan panel, hidden destinations absent when their elements are off (use the `examples/1brand`, `examples/3cat`, `examples/9cat` configs and the IPK four-category fixture).

## 4. Stage 3: the Overview

Extend `panels/14_summary_panel.R` and `js/brand_summary_panel.js`; do not start again. Already there: the hero card with `heroHeadline()` (rank by Mental Market Share plus a mental-versus-physical clause), the over- and under-indexer cards, the funnel, WOM and repertoire cards, the closing strip, the analyst commentary editor, and the lift's "Which penetration is which" block. Target layout, top to bottom:

1. Top strip: four to six headline numbers with the gap to category average (MPen, MMS, % bought in the target window, SCR, plus awareness and consideration from the nested funnel). Each links to its destination.
2. Verdict sentence (existing generator; extend the clauses, keep them derived from numbers).
3. Why: three strengths and three gaps from the existing over- and under-indexer cards (CEPs and attributes), one line each.
4. Actions: three items labelled Protect, Build, Investigate. Derive Protect from Mental Advantage "Defend" items, Build from "Build" items, Investigate from the funnel's biggest drop (`.biggest_drop_for_focal()` in `03_funnel.R` already finds it) or a below-average penetration. Rules-based, no AI.
5. Analyst commentary (existing editor, kept).
6. "How this works" drawer, collapsed: methodology text and the "Which penetration is which" block.

Portfolio and category mini-cards stay on the Portfolio tab for multi-category studies; the Overview is per category.

## 5. Stage 4: the funnel

In `js/brand_funnel_panel.js` the percentage modes live around lines 1307, 1644, 1880 and 2089 (absolute, previous, aware). Add a nested-absolute mode fed by `base_chain_filtered / base` (the cells carry `base_chain_filtered`, `base_aware_filtered`, `base_weighted`, `base_unweighted`; the meta carries `n_weighted`, `n_unweighted`, `n_effective`). Make it the default; keep absolute and "% of aware" as toggles with plain labels ("Funnel, nested", "Each measure on its own", "Of those aware"). Significance markers on the funnel are computed for the absolute view; in the nested view show none rather than the wrong ones, and say so in the "How this works" drawer. Correct `.FUNNEL_DEFAULT_DEFINITIONS` in `R/03a_funnel_derive.R` so the consideration text no longer claims a nesting the absolute view does not have (this is the one engine-file edit). Excel export and pins of the funnel table must state which view they carry. Tests: the nested numbers on the IPK fixture equal chain count over base; the default mode attribute in the emitted HTML; the definition text.

## 6. Stage 5: chrome

- Significance as a toggle, default off, one control per destination; borrow the tabs v2 `sigMode` idea, not its code.
- One export toolbar (pin, PNG, Excel) per destination main view and one per Advanced drawer, instead of one per table. The pin capture in `brand_pins.js` reads `.br-insight-editor`, `.fn-insight-textarea`, `.ma-insight-box-text` and `.brsum-insight-editor`; keep those selectors valid where boxes remain.
- Commentary boxes: one per destination plus the existing MA headline and Summary boxes. The lift's textarea mirror in `brand_report.js` persists any textarea, so removed boxes need no migration; boxes that stay keep their `data-section` so Section_Insights pre-fill still lands.
- Methodology: every explanatory block moves behind a "How this works" control, collapsed by default, text unchanged, bases and caveats intact.

## 7. Stage 6: QA (all executed, quoted in the summary)

- Brand suite, 0 failures.
- Reachability: a script that lists every `data-subpanel` and every `data-section` in the old and new IPK fixture reports and asserts the sets are equal.
- Numbers: every `application/json` island's numeric content identical before and after, except the funnel default mode field and definition text. Diff the islands, not the page.
- Headless Chrome on the new IPK report (recipe in the lift notes: type into commentary boxes, dump the DOM, reload the dump, read values back); also click through the five destinations and the Advanced drawers in Chrome and assert no empty destination and no JS console error.
- Renders for the one-, three- and nine-category example configs and the IPK four-category fixture.
- Then Duncan regenerates a real report and eyeballs; then a Fable pre-merge review, briefed as independent of this session.

## 8. Acceptance criteria (from the ChatGPT brief, section 12)

No more than five primary destinations per category. A first-time reader gets position, reasons and actions from the Overview without opening a methodology panel. MA Metrics, CEPs and Mental Advantage are not three peer destinations. Category Buying no longer shows six peer sub-tabs by default. Every current output is in a main view or reachable through Advanced. No metric relabelled in a way that misstates its computation. "Funnel" appears only on a nested view. Pinning, export, focal switching, category switching, commentary and Save keep working. Missing optional sections hide cleanly. No numeric change except the funnel default.

## 9. What not to do

No deleting analyses. No copying Timelaps styling. No new statistics. No burying bases in tooltips. No second navigation system under the old one. No engine edits beyond the funnel definition text. No rebuild of the summary hero. No merge, no push: Duncan merges after eyeball and review. Do not touch `modules/shared/` or any other module.

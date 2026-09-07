# Brand simplification, Stage 5 implementation log

**Date:** 7 September 2026. Worktree `/Users/duncan/Dev/Turas-brand-simplify`,
branch `feature/brand-chrome`, cut from main at cc34fd83.
Scope: the chrome. Significance as a toggle, one export toolbar per view, one
commentary box per destination, methodology behind a drawer. No numeric change.

Brief: the Stage 5 task message, against
`docs/v2_lift/HANDOVER_BRAND_SIMPLIFICATION_FOR_OPUS.md` section 6,
`modules/brand/docs/SIMPLIFICATION_IMPACT_MAP.md` and the Stage 2, 3 and 4
logs.

## Baseline, executed before the first edit

- Brand suite: `TURAS_ROOT=/Users/duncan/Dev/Turas-brand-simplify Rscript -e
  'testthat::test_dir("modules/brand/tests/testthat")'` gave
  **FAIL 0, WARN 1, SKIP 2, PASS 3486**, 137.8 s. Matches the brief.
- IPK fixture report generated and kept as the before baseline: `run_brand()`
  on `modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx` with
  `project_root` = the fixture directory, then `generate_brand_html_report()`
  to the scratchpad. Status PASS, **4,024,208 bytes**. Nothing was written into
  the repo or into any project folder.

## The counts, and where the brief's own numbers came from

The task message quotes 40 pin, 69 PNG and 42 Excel buttons, 69 textareas and
2,324 occurrences of "significant". **Those are not this fixture.** They come
from the assessment's reading of a real four-category IPK report, which this
session did not open. Everything below is the IPK fixture, one full-depth
category plus the Portfolio and Summary tabs, counted in headless Chrome off
the rendered DOM by the session's `count_chrome.py` and by
`tests/qa/drive_chrome.py`.

| Measure | Before | After |
|---|---|---|
| Pin controls | 29 | 25 |
| PNG controls | 21 | 17 |
| Excel controls | 20 | 16 |
| All export controls, by class and by handler | 72 | 60 |
| Commentary textareas | 21 | 14 |
| "significan" in the text of the whole document | 15 | 19 |
| "significan" in the VISIBLE text of the five destinations | 14 | 5 |
| "significan" in title and aria attributes | 0 | 4 |
| Significance markers in the DOM | 276 | 276 |
| Markers **rendered on screen** on Mental Availability | 33 | 0, and 33 with the toggle on |
| Markers **rendered on screen** on Brand Meaning | 4 | 0, and 4 with the toggle on |
| Markers in the DOM of those two destinations | 229 and 47 | unchanged |
| Destination export toolbars | 0 | 5 |
| Significance toggles | 0 | 4 |
| "How this works" drawers holding something | 0 | 5 |

Read those rows together, because two of them move the wrong way on their own.
The word count for the whole document **rises by four**, and those four are
the toggle's own label. The count in attributes rises by the same four, the
toggle's tooltip. What actually changed for a reader is the row below them:
opening every destination in turn, the word went from **14 to 5**.

The marker rows need reading carefully too, and the first draft of this log
had them wrong. **276 markers are in the DOM and 37 are on screen**, because
most of them sit inside a hidden Mental Availability sub-tab or a hidden
matrix cell. So the honest before figure is 33 on Mental Availability and 4
on Brand Meaning, measured in a browser with every destination opened and
every drawer expanded, not 229 and 47. Those 37 go to zero and come back on a
click. Nothing is deleted: the engine still computes every one of the 276 and
the toggle brings them straight back.

Brand and Buying carries no marker at all, before or after. Its funnel opens
on the nested view, which Stage 4 leaves unmarked because the marks were
computed on a different base, and the Category Buying panel has never carried
one.

The 72 to 60 needs the same care. Twenty-seven per-table controls went, and
fifteen destination-toolbar controls arrived, which is the six-toolbar shape
the brief asked for (five, once the Overview was ruled out, see decision 3).
The 45 that remain are named in decision 2, and one of them is a ruling for
Duncan.

## Decisions taken, with reasons

1. **Destination controls resolve by destination, never by `data-section`.**
   The reachability gate freezes the `data-section` set, and that set is a
   contract with the analysts who typed those names into Section_Insights
   sheets and saved pins against them. A destination is not a section. So the
   toolbar carries `data-group`, `data-destination` and `data-tier` and
   `brDestScope()` resolves the element; nothing in the new code reads or
   writes a section anchor. This is why the gate passes with the set
   unchanged rather than rebaselined.

2. **The Mental Availability, funnel, Category Buying and Summary-card
   controls stay.** The impact map section 7 lists them under "What must not
   change" and says in terms that "Stage 5 consolidates the shared toolbars,
   not the panel-native ones". They are also finer than anything replacing
   them would be: the MA pin dropdown offers six named pieces of the metrics
   sub-tab, and `brand_cat_buying_panel.js` unbinds the inline handler on the
   Category Buying toolbar and rebinds a dialog scoped to whichever of the
   eight sub-tabs is on screen. What went is the generic shared layer: the
   element toolbars on Word of Mouth and Demographics, and the twenty-one
   buttons on the seven demographics question cards.

   **This is a ruling Duncan may want to take further.** The residual 45 are
   8 Summary card pins, 5 Portfolio and Category Buying shared sets of three,
   20 Mental Availability and funnel panel-native controls, and the Pin All
   button. Removing the MA and funnel sets would take roughly 20 more per
   category and would cost the granularity above. Say the word and it is one
   place.

3. **A view with no analysis gets no toolbar, no toggle and no commentary
   box.** The category Overview is that view: Stage 3 built the Overview on
   the Summary tab and left a route card in the destination. An export control
   over a route card exports nothing, a significance toggle governs no marker,
   and a second commentary box there would compete with `brsum-insight` on the
   page it routes to. So four destinations carry the toggle and the box, not
   five, and the test says so rather than counting five and being wrong.

4. **Significance hides with CSS on the page and is stripped from captures.**
   The MA table, the funnel table and the Mental Advantage focal view all
   re-render on a focal switch, a base toggle or a brand filter. A DOM pass
   that removed markers would have to be chased after every one of them; an
   attribute on the destination survives all of it, and survives Save for free
   because it is a content attribute.

   CSS alone is wrong for a capture. TurasPins' inliner skips values it reads
   as defaults, `display: none` among them
   (`modules/shared/js/turas_pins_utils.js`, and the note in the project
   CLAUDE.md), so a marker hidden on screen comes back on a pinned card. Rather
   than edit the fourteen capture sites across five panel files, `brand_pins.js`
   wraps `TurasPins.capturePortableHtml` once, at init, and strips the markers
   from any capture whose root is inside a destination with the toggle off.
   Every pin and PNG path in the module goes through that function.
   `drive_chrome.py` checks the captured HTML, not the page.

5. **The nested funnel and the toggle agree by construction, and nothing was
   undone.** Stage 4 leaves the funnel's triangle and arrows out of the markup
   in the nested view, for the same inliner reason, because they were computed
   on a different base. So turning significance on cannot make them appear
   there. `applySigBadges()` and `applyTableSigMarkers()` are untouched. The
   funnel's own "How this works", under its base toggle, still says why the
   nested view carries no mark.

6. **Sub-anchors moved onto the leaf, which improves what an old pin
   captures.** `funnel-`, `attitude-`, `metrics-`, `ceps-`, `attributes-` and
   `advantage-<cat>` used to live only on the insight toolbar and its
   container, so `brCaptureContent('ceps-dss')` resolved onto a textarea and
   captured no table, and `_brExportPanel('ceps-dss')` alerted that there was
   nothing to export. Each now sits on a wrapper around the whole leaf, ahead
   of the toolbar in document order, so it resolves to the analysis it names.
   No anchor is renamed and none is added. Stage 3 logged the same kind of
   change for `brsum-weak`.

7. **A leaf keeps its own commentary box when, and only when, something was
   written into it.** Dropping the per-leaf boxes outright would have left an
   analyst's `ceps-pas` sentence with nowhere to render. So
   `build_br_section_toolbar()` gained `require_text`, and a leaf renders its
   box when the Section_Insights sheet authored text for that anchor **or**
   when the authored-insight number check has a marker for it. On the IPK
   fixture four such boxes render, on `ceps-dss`, `funnel-dss`,
   `repertoire-dss` and `wom-dss`, with their authored text in them. On a
   report with no authored insights there are none, and the reader writes in
   the destination's box.

   **The check marker was not seen on the fixture.** `class="br-insight-check"`
   appears zero times in the before report and zero times in the after one:
   this fixture's insights are not flagged, so no marker could be lost or
   kept. The branch is driven directly instead, by a test that builds a
   finding, asserts the marker renders inside the box under `require_text`,
   asserts the marker alone is enough to render a box, and asserts that
   nothing authored and nothing flagged renders no box at all.

8. **The destination commentary box carries no `data-section`.** It could not:
   a new anchor fails the gate, and reusing an existing one would put two
   boxes on one anchor where `brTogglePin` takes the first match. It carries
   `data-dest-note="<cat>:<destination>"` instead. **The cost, stated:** a
   Section_Insights sheet cannot pre-fill a destination box. Authored text
   still lands, on the leaf, which is where it was written. **Owed as a
   ruling** if Duncan wants destination-level pre-fill: it needs a new anchor
   name and a rebaselined reachability comparison.

9. **The pin and PNG pickers offer leaves as well as anchors.** Five Category
   Buying analyses have no `data-section` of their own, so an anchor-only
   picker would have left the Brand and Buying Advanced drawer with an Excel
   export and no pin. The picker falls back to any `[data-leaf]` host in scope
   that holds no anchor, labelled from `data-leaf-label`. On the fixture that
   turns the drawer from nothing to pin into five named analyses.

10. **Methodology is collected in the browser, not assembled in R.** The
    blocks come from fifteen builders, several nested inside fragments the
    page builder only ever sees as a string. `brCollectHowTo()` moves
    `.t-callout`, `details.ma-chart-callout`, `details.ma-adv-intro-callout`
    and `details.cb-info-callout` into the drawer at load. None of them
    carries a `data-section`, an id or a payload, so no anchor and no island
    moves with them, which was the impact map's objection to moving DOM.
    A block that shipped collapsed is opened inside the drawer: the drawer is
    the disclosure, and a second one would make a reader click twice for the
    same thing. Stage 3 decision 11 took the same view.

11. **Each Advanced drawer gets its own methodology drawer.** An explanation
    belongs in the tier that holds the analysis it explains, so the Advanced
    callouts are not sent up to the main view's.

12. **The funnel's own "How this works" under the base toggle stays where it
    is.** Stage 4 put it beside the control it explains, deliberately and
    outside `.fn-controls` so it prints. Folding it into the destination
    drawer would separate it from the toggle. Noted rather than moved.

13. **Bases stay on the face.** Handover section 9 forbids burying them, and
    nothing here moves an `n =` line, a base row or a small-base note. Only
    the explanatory prose blocks move.

14. **The Portfolio tab is not a destination and was left alone.** It has no
    destination shell, so its four shared toolbars and its own significance
    column keep working as they did. Its star column and its "significant
    after BH correction" wording are outside this stage.

15. **The toggle governs text markers, not chart encodings.** The Mental
    Advantage quadrant draws a significant bubble with a thicker outline
    (`ma-adv-q-bubble-sig`), and the funnel and MA heatmaps shade cells.
    Those are part of how the chart reads, not a badge beside a number, and
    taking them out would change the chart rather than quieten the page. They
    stay in both states. The tooltip's clause, which is text, follows the
    toggle.

## What was built

**R.** `build_br_destination_toolbar()` and `build_br_howto_drawer()` in
`03_page_builder.R`, called once per destination main view with content and
once per Advanced drawer. `build_br_section_toolbar()` gained `require_text`.
`.br_leaf_host()` gained the `.br-leaf-anchor` wrapper and `data-leaf-label`.
`.demo_panel_card_toolbar()` lost three buttons and kept its view toggles.
The funnel, Mental Availability and Word of Mouth panels lost the commentary
boxes the destination now carries. CSS and the print rules were appended to
`module_css` rather than folded into its `sprintf`, which is the pattern Stage
2 established for the 8192-character format-string cap; the drawer arrow's
`"\\25BE"` is doubled, as Stage 3's is.

**JavaScript.** `brand_report.js` gained `brDestScope`, `brSectionsIn`,
`brDestPin`, `brDestPng`, `brDestExcel`, `brToggleDestNote`,
`brToggleDestSig`, `brSigOnFor`, `brCollectHowTo` and `brToggleHowTo`, and
`_brExportPanel` was split so `_brExportRoot` is the one workbook builder both
entry points use, with sheets named from the anchor or leaf rather than an
index. `brand_pins.js` gained `brStripSigMarkers`, the one-time wrapper around
`TurasPins.capturePortableHtml`, and `brPinFrom` / `brExportPngFrom`, which
capture from an element because `brTogglePin` needs a button that mostly no
longer exists. `brand_ma_advantage.js` moved its significance clause into a
span. The funnel and MA pin dropdowns filter their own menus by what is on the
page, so neither offers an item that would pin an empty string.
`brand_wom_panel.js` stopped hiding the shared insight container.

## Executed, with the numbers

| Check | Result |
|---|---|
| Brand suite, before the first edit | FAIL 0, WARN 1, SKIP 2, PASS 3486 |
| Brand suite, at the tip | FAIL 0, WARN 1, SKIP 2, PASS 3560, 121.7 s |
| `reachability_check.py before after` | PASS. data-subpanel 5, data-section 29, section ids 13, island classes 8, all identical; every parseable island numerically identical |
| `anchor_resolution.py before after` | PASS. 41 of 41 anchors and section ids resolve, and every one to a root holding a table, a chart or a textarea |
| `drive_chrome.py after.html` | 115 checks, 0 failed, no console error |
| `drive_destinations.py after.html` | 353 checks, 0 failed |
| `drive_save_roundtrip.py after.html` | 113 checks, 0 failed |
| `drive_two_categories.py after.html` | 15 checks, 0 failed |
| `drive_overview.py after.html` | 60 checks, 0 failed |
| `drive_funnel_base.py after.html` | 99 checks, 0 failed |
| IPK fixture report | PASS, 4,044,194 bytes against 4,024,208 before, 0.5 percent larger |

The five existing drive scripts were also run against the before report in
this session and returned the same counts (353, 113, 15, 60, 99), so the
figures above are the baseline holding, not a suite that shrank. The Stage 4
log records `drive_funnel_base.py` at 95; it is 99 on this branch's base
commit as well, so the difference is work that landed on main after that log,
not anything in this stage.

`drive_chrome.py` is new. Per category and per destination it opens the view,
then:

- asserts one pin, one PNG and one Excel control per view, and that the
  toolbar resolves its own scope by calling the report's `brDestScope()`
  rather than reimplementing it;
- asks `brSectionsIn()` what the pickers would offer and checks each entry
  resolves to something capturable, by anchor where it has one;
- **pins for real** and counts the card that appears on the Pinned Views tab;
- **exports a PNG for real** and asserts no console error;
- **exports Excel for real**, with `a.click()` and `URL.createObjectURL`
  intercepted so the workbook that would have been downloaded is inspected;
- asserts the destination opens with significance off and with no marker on
  screen, that turning it on shows the markers the engine computed, and that
  a capture taken with it off carries none, checked in the captured HTML;
- types into the destination commentary box and reads it back out of the
  report's own `_brSerialiseReport()`;
- opens and closes every methodology drawer, asserts each holds at least one
  block, and asserts no explanatory block is left loose in a view;
- and checks the repertoire case by name.

On the fixture:

    dss/mental/main      anchors=5 tables=5   229 in the DOM, 0 shown off, 33 shown on
    dss/buying/main      anchors=3 tables=4
    dss/buying/advanced  anchors=5 tables=6
    dss/meaning/main     anchors=2 tables=2    47 in the DOM, 0 shown off,  4 shown on
    dss/audience/main    anchors=8 tables=7

    Brand and Buying reaches 10 tables across its two toolbars,
    against the 9 that section-repertoire-dss held before the Stage 2 split.
    All 7 Category Buying sub-tabs present sit under one of the toolbars.

## Adversarial pass, and what it caught

1. **The Advanced drawer had an Excel export and no pin.** The five Category
   Buying analyses in it carry no `data-section`, so an anchor-only picker
   offered nothing and the button alerted. The picker now falls back to leaf
   hosts. Caught by the first `drive_chrome.py` run reporting
   `dss/buying/advanced anchors=0`.

2. **The Overview destination had a toolbar over a route card.** Same run,
   `dss/overview/main anchors=0 tables=0`. A view with no analysis now gets no
   toolbar, and the drive asserts it has none rather than skipping it.

3. **A destination whose analyses are all in its Advanced drawer would have
   lost its significance toggle and its commentary box**, because the first
   fix gated the whole toolbar on the main view having leaves. Audience with
   Audience Lens configured and no Demographics is the real case and Stage 2
   already has a test for its drawer. The toolbar is now emitted whenever the
   destination has any leaf, with the export controls omitted when the main
   view has none. Covered by a unit test, because the IPK fixture does not
   produce that mix.

4. **A "How this works" that found nothing would have printed a heading over
   nothing.** The print block unhid `.br-howto[hidden]`; it no longer does,
   and only the body is unhidden.

5. **The Mental Advantage significance clause could not be reached.** It was
   concatenated into a text node, where no stylesheet hides it and no capture
   strips it. It is now a span. Its tooltip is emitted inside the panel, not
   at body level, so the destination-scoped rule does reach it; that was
   checked rather than assumed (`.ma-adv-tooltip` comes from
   `02_ma_panel_advantage.R` line 144 and `tooltipEl()` finds it with
   `panel.querySelector`).

6. **Two panel pin dialogs would have offered a dead menu item**, "Insights"
   pointing at a box this stage removed. Both filter their lists by what is
   on the page.

7. **Word of Mouth would have hidden an authored insight.** Its JS hid the
   shared insight container because the panel had its own box; with that box
   gone, a prefilled `wom-<cat>` sentence would have been in the file and off
   the page. The hiding was removed.

8. **Every category's Dirichlet Norms pin would have carried the same key and
   the same title.** The five Category Buying analyses reached through the
   leaf fallback have no anchor and no heading of their own, so a four
   category report would have produced four cards all keyed `cb-norms` and
   all titled `cb-norms`. The key is scoped to the category and the title is
   the analysis name plus the category. `TurasPins.add` was read first: it
   pushes and gives each pin its own id, so nothing was being overwritten;
   the cards were merely indistinguishable.

## Known limits, stated rather than left to be discovered

- **One category, one focal brand, one funnel.** The IPK fixture has one
  full-depth category. Everything driven in the browser was driven against
  Dry Seasonings and Spices. The multi-category case is covered by
  `drive_two_categories.py`, which clones the category, and by the unit tests
  that render other element mixes.
- **Branded Reach, Ad Hoc, Audience Lens and Shopper Behaviour have still
  never rendered through this shell with real panel fragments.** They are
  absent from the fixture and the three example generators are still broken
  on main, as Stage 2 and Stage 4 both recorded. Their toolbars and drawers
  are exercised by unit tests on stub fragments only.
- **No pinned card, PNG or workbook was opened.** `drive_chrome.py` asserts a
  pin card appears, that a PNG export runs without error, and that the
  intercepted Excel blob is non-empty and named; it does not open a PNG in a
  viewer or the workbook in Excel.
- **The significance toggle was not driven on a report where the engine
  returns a significant funnel cell.** Every `data-fn-sig-avg` on the fixture
  reads `na`, the same limit Stage 4 recorded, so Brand and Buying has no
  marker for the toggle to govern on this data. The 33 markers on screen on
  Mental Availability and the 4 on Brand Meaning are real and are what the
  toggle was driven against.
- **Nothing was run on weighted data**, and nothing here reads a weight.
- **The Portfolio tab's significance column is untouched** (decision 14).
- **The 60 export controls that remain** are counted and named, not reduced
  further. See decision 2.

## What Duncan still owes

1. **A `launch_turas()` run on a real project, and an eyeball.** This session
   generated the IPK fixture into a scratchpad only and never touched OneDrive
   or TurasProjects. Four things to look at: the toolbar at the top of each
   view, the significance toggle reading "Significance: off", the single
   commentary box per destination, and "How this works" at the foot of each
   view.
2. **A ruling on decision 2**, whether the Mental Availability and funnel
   panel-native pin, PNG and Excel controls should go as well. The impact map
   says they are out of this stage's scope; the Stage 5 brief's "one toolbar
   per destination, not one per table" reads as though they should go. Keeping
   them is what this build did, and removing them would take roughly twenty
   more controls per category at the cost of the finer pin dialogs.
3. **A ruling on decision 8**, whether a Section_Insights sheet should be able
   to pre-fill a destination commentary box. It cannot today, because that
   needs a new anchor name and a rebaselined reachability comparison.
4. Then a Fable pre-merge review, briefed as independent of this session.

**Not merged and not pushed.** Branch `feature/brand-chrome`, on top of
cc34fd83.

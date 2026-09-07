# Brand destinations: naming the tables, and giving Mental Availability an Advanced drawer

**Date:** 7 September 2026. Worktree `/Users/duncan/Dev/Turas-mal`, branch
`fix/brand-destination-labelling`, cut from main at `36f97062`.
**Scope:** two reader-facing problems Duncan found on his own regenerated
four-category report. No numeric change, no anchor change.

Brief: the task message, against
`modules/brand/docs/SIMPLIFICATION_IMPACT_MAP.md`,
`docs/v2_lift/NOTES_BRAND_SIMPLIFICATION_STAGE2.md`,
`docs/v2_lift/NOTES_BRAND_SIMPLIFICATION_STAGE5.md` and
`docs/v2_lift/REVIEW_FINDINGS_BRAND_SIMPLIFICATION.md`.

## The two problems

1. **Tables are unlabelled.** Stage 5 collected every explanatory block into
   one collapsed "How this works" drawer per view. That was right for
   methodology and wrong for orientation: a reader now meets a stack of
   tables with nothing on their face saying what each one is.
2. **Mental Availability has no Advanced drawer and should.** The impact map's
   destination summary puts the full Mental Advantage matrix, the buyer-gap
   diagnostic and the MA methodology in Advanced; today all three are in the
   main view, which is why the page reads as a list of everything.

## Baseline, executed before the first edit

- Brand suite from the repo root:
  `TURAS_ROOT=/Users/duncan/Dev/Turas-mal Rscript -e 'testthat::test_dir("modules/brand/tests/testthat")'`
  gave **FAIL 0, WARN 1, SKIP 2, PASS 3659**, 107.8 s. Matches the brief.
- The three QA reports, built with
  `modules/brand/tests/qa/generate_qa_reports.R --out <scratchpad>/before`:
  `committed.html` 4,056,423 bytes, `extras.html` 4,172,037 bytes,
  `ungated.html` 4,171,952 bytes. All three PASS. Nothing was written into
  the repository or into any project folder.

## How the labelling is measured

`modules/brand/tests/qa/count_headings.py`, added by this work. It drives the
report in headless Chrome, activates every category tab and every destination,
opens the Advanced drawer and each of its items in turn (the drawer is a
one-at-a-time accordion, so opening them all at once leaves only the last one
open), and reads the headings and tables **out of the rendered DOM**. A
heading hidden by a collapsed ancestor is not a label a reader can see, and
that distinction has already caused two bugs in this programme.

It walks each pane in document order and pairs every visible data table with
the heading that most recently preceded it. A heading already spent on an
earlier table does not name the next one, so two tables under one heading
counts the second as unnamed.

Two heading definitions are reported, because they answer different
questions. The strict count is `h1` to `h6`, which is the method Duncan used.
The wider count adds the panel-native title classes, which render as headings
on screen but are `div` elements in the markup.

### Before, on the IPK fixture

`t/h` is visible tables over visible headings, the wider definition.

| Report | Destination | main t/h | advanced t/h | pane t/h | pane t/h1-6 | unnamed |
|---|---|---|---|---|---|---|
| committed | overview | 0/1 | - | 0/1 | 0/1 | 0 |
| committed | mental | 5/8 | - | 5/8 | 5/8 | 1 |
| committed | buying | 4/5 | 5/9 | 9/14 | **9/0** | 1 |
| committed | meaning | 2/1 | - | 2/1 | 2/1 | 1 |
| committed | audience | 7/8 | - | 7/8 | 7/8 | 0 |
| extras | mental | 5/8 | - | 5/8 | 5/8 | 1 |
| extras | buying | 4/4 | 5/9 | 9/13 | **9/0** | 1 |
| extras | meaning | 2/1 | 0/4 | 2/5 | 2/4 | 1 |
| extras | audience | 8/10 | 3/7 | 11/17 | 11/12 | 0 |

The fixture reproduces Duncan's complaint. Brand and Buying carries nine
tables and **not one `h1` to `h6` heading**; its three visible labels are
`div.cb-section-title` and `div.cb-ctx-subtitle`. Brand Meaning is 2 tables
and 1 heading, which is exactly the count he reported. Audience is the one
that reads properly, as he said.

Two differences from his four-category report, recorded rather than
reconciled: he counted ten tables on Brand and Buying and one heading,
"Summary". On the fixture the funnel panel's Summary `h3` carries the
`hidden` attribute (impact map section 4, the dead sub-tab), so the harness
sees zero. His report is a different config and a different category.

The four unlabelled tables the harness names:

| Destination | Table | Today |
|---|---|---|
| mental | Brand Attributes linkage | falls under the metrics chart heading "MMS vs Share of Mind" |
| mental | Category Entry Points linkage | the same, and it is the one Duncan named |
| buying | the funnel table | no heading above it at all |
| meaning | the Brand Attitude table | no heading above it at all |

## Decisions taken, with reasons

1. **One naming pattern for every leaf, emitted in one place.** `.br_leaf_head()`
   in `03_page_builder.R` writes an `h3` carrying the leaf's display label and
   the category, plus, where the name does not say what the table holds, one
   line that does. Five elements had a hand-written `h3` each and now take the
   shared one; the funnel, Mental Availability and Category Buying leaves had
   none at all. Audience was the destination Duncan said reads properly, and
   it read properly because its leaves already had these headings.

2. **The heading comes before the toolbar, not after it.** The five elements
   that had a hand-written title emitted the toolbar first and the title
   second. A leaf whose Section_Insights sheet authored a sentence renders
   that sentence in its toolbar, so a reader would have met an analyst's
   comment before the name of the thing it is about. The head is now first
   inside the anchor wrapper on every branch, which also makes it
   unambiguously the first `.br-element-title, h2, h3` the pin picker finds.
   A test renders a category with an authored `ceps-dss` sentence and asserts
   the heading precedes it.

3. **The heading keeps `br-element-title` and the "<name>: <category>" shape.**
   `captureFromRoot()` in `js/brand_pins.js` and `sectionsIn()` in
   `js/brand_report.js` both name a pinned card from the first visible
   `.br-element-title, h2, h3` inside the anchor, and `sectionsIn()` builds
   exactly `label + ": " + category` for a leaf with no anchor. Departing from
   either would have re-opened review finding F2, where a picker offered one
   name and the card carried another. The category is therefore repeated on
   each analysis in a pane, which is noisier than a bare name and is the price
   of a pinned card that says which category it came from.

4. **The lede registry is sparse.** A leaf gets a line only where its name
   does not already say what the table holds **and** the panel prints no intro
   of its own. Category Context, Brand Summary, Duplication of Purchase,
   Branded Reach and Shopper Behaviour all print their own opening paragraph
   and have no lede; a second line above them would say the same thing twice.
   Every line was written against the table it describes, read out of a
   generated report or the builder that emits it, and the bases named in them
   were read in the engine: the loyalty split is a share of the category's
   buyers (`.bh_loyalty_segments`), the purchase and heaviness splits are
   shares of the brand's own buyers (`.bh_freq_dist`,
   `calculate_buyer_heaviness`). The funnel line is true in both gating modes,
   because on an ungated report the leaf is called Brand Stages and shows four
   separate measures (review finding F5).

5. **Panel-native titles that duplicated a leaf head were removed, not kept.**
   Category Buying printed its own name for four sub-tabs and Shopper
   Behaviour for a fifth; Mental Advantage printed a second "Mental
   Advantage". Those go. Mental Availability's headline `h3` drops to `h4` and
   now names the focal brand whose strip follows rather than repeating the
   section name, and the all-brand table below it gained its own `h4`, because
   without one it read as part of the focal strip.

6. **The sub-headings that stay became real headings.** `.cb-section-title`,
   `.cb-ctx-subtitle` and `.cb-norms-chart-title` were `div` elements that
   render as headings. They keep their class, so every rule in
   `08_cat_buying_panel_styling.R` still reaches them and nothing moves on
   screen, and the tag changes so a heading on the page is a heading in the
   markup. All three rules set font size, weight and margin explicitly, so
   the browser defaults for `h4` change nothing.

7. **"Ad Hoc" became "Ad Hoc Questions".** The label now writes the heading
   that replaced a hand-written "Ad Hoc Questions", and "Ad Hoc" alone does
   not say what the reader is looking at. A display label, so `data-leaf` and
   every anchor are untouched.

8. **Mental Advantage renders in two parts, one host each.** A sub-panel
   cannot be in two tiers at once, so the impact map's split needed a second
   host: `build_ma_advantage_section(part =)`, a new `only_tab` value
   `"advantage_detail"` in `build_ma_panel_html()`, and a twentieth leaf.
   `brand_ma_advantage.js` guards every view it renders on that view being
   present, so each host renders exactly what it holds and nothing more.

9. **Each part carries the controls that govern what it holds.** Show chart
   governs the quadrant and stays in the main view; Show counts and the Excel
   export govern the matrix and go to the drawer. A control over a view that
   is not on the page is a control that does nothing, which is what the
   Dirichlet Norms brand filter used to be.

10. **The two stimulus toggles are kept in step by a document event.** Both
   parts need the CEPs and Attributes toggle, and two independent ones would
   let the drawer show attributes under a quadrant showing CEPs with nothing
   on the page saying so. `turas:brand-ma-stim-change` carries the category,
   on the pattern of `turas:brand-focal-change`, and `drive_chrome.py` drives
   the switch in both directions.

11. **The detail leaf declares no anchor.** Its internal tab is `"advantage"`
    so `activateHost()` finds the panel's own hidden sub-tab button, and an
    explicit empty `anch` field stops the anchor being derived from it. A
    derived anchor would have been a second `advantage-<cat>`; a new
    `advantage_detail-<cat>` would have added a `data-section` value to a set
    that is a contract with the analysts who typed those names into
    Section_Insights sheets. The pin and PNG pickers reach the leaf through
    the fallback Stage 5 built for the five Category Buying analyses, and its
    Advanced toolbar gives it a pin, a PNG and an Excel of its own.

12. **The Advanced accordion toggle and the leaf head both name the item.**
    Opening "Dirichlet Norms" shows "Dirichlet Norms: Dry Seasonings &
    Spices" under it. Branded Reach already read that way. The alternative
    was to drop the heading in the Advanced tier, which would have sent every
    anchored drawer pin back to a bare leaf label with no category, or to
    hide it with CSS, which is the anti-pattern this whole exercise is about.

13. **The empty drawer stays hidden.** Both Mental Advantage leaves are gated
    on the engine returning an advantage block, so a study with CEPs and
    attributes and no advantage produces neither leaf and Mental Availability
    gets no drawer. A test renders that mix and counts the drawers per
    destination rather than asserting the report has none.

## Three QA gates changed for the split, not for a fault

- `drive_destinations.py`. `NO_BRAND_CODES` classified `ma-advantage` as
  `"columns"`, meaning "check the visible column count, one label column plus
  one per brand", because the matrix keys its columns by brand name in a `th`
  rather than by a brand-code attribute. The matrix moved, so the entry moves
  with it to `ma-advantage-detail`. What is left on `ma-advantage` is the
  quadrant and the action list, both focal-brand views. Neither carries a
  brand-coded element, **verified by running the script with the entry removed
  and finding none**, so it is now `"none"`. `NO_CHART_FOCUS` gains the detail
  leaf for the same reason the main leaf was already in it.
- `drive_chrome.py`. Its "clicking pin or PNG opens the picker or acts" check
  passed on a popover appearing or a pinned card arriving. A PNG export makes
  no card, and on a scope with one entry it opens no picker either: it goes
  straight to `brExportPngFrom`. Mental Availability's Advanced drawer is the
  first single-entry scope in the report and it is what exposed the gap. The
  harness now counts calls to that function as well.
- `drive_excel_export.py`. Its brand-filter check looked for `>name<`, a whole
  cell. The header cells carrying `data-ma-brand` read "FOCAL<name> <sort
  glyph>" on the page and the exporter writes the cell text as it stands, so a
  whole-cell match never found the focal brand in those. It passed because the
  Mental Advantage matrix, then in the same scope, had a header row holding the
  bare name. The matrix moved to the drawer's own export, so the check now
  matches the name anywhere in the workbook. That makes its other half, "a
  brand the reader hid is not in the workbook", stricter rather than looser,
  and it still passes on all three fixtures.

`count_headings.py` also changed: it fails on an unnamed table by default now
rather than needing a flag, because a gate that has to be asked to fail is
not a gate. `--allow-unnamed` is how the before baseline above was taken.

## After, on the IPK fixture

Same measure, same script, same three reports regenerated at the tip.

| Report | Destination | main t/h | advanced t/h | pane t/h | pane t/h1-6 | unnamed |
|---|---|---|---|---|---|---|
| committed | overview | 0/1 | - | 0/1 | 0/1 | 0 |
| committed | mental | 3/10 | 2/4 | 5/14 | 5/13 | 0 |
| committed | buying | 4/6 | 5/12 | 9/18 | **9/13** | 0 |
| committed | meaning | 2/2 | - | 2/2 | 2/2 | 0 |
| committed | audience | 7/8 | - | 7/8 | 7/8 | 0 |
| extras | mental | 3/10 | 2/4 | 5/14 | 5/13 | 0 |
| extras | buying | 4/5 | 5/12 | 9/17 | **9/12** | 0 |
| extras | meaning | 2/2 | 0/4 | 2/6 | 2/5 | 0 |
| extras | audience | 8/10 | 3/7 | 11/17 | 11/15 | 0 |

Before and after, side by side, on the committed fixture:

| Destination | tables | headings before | headings after | h1-h6 before | h1-h6 after | unnamed before | unnamed after |
|---|---|---|---|---|---|---|---|
| Mental Availability | 5 | 8 | 14 | 8 | 13 | 1 | 0 |
| Brand and Buying | 9 | 14 | 18 | **0** | **13** | 1 | 0 |
| Brand Meaning | 2 | 1 | 2 | 1 | 2 | 1 | 0 |
| Audience | 7 | 8 | 8 | 8 | 8 | 0 | 0 |

Mental Availability's main view went from five tables to three, because the
full matrix and the buyer-gap diagnostic moved into the Advanced drawer it
did not have before. Report sizes: 4,067,665 / 4,183,615 / 4,183,530 bytes,
against 4,056,423 / 4,172,037 / 4,171,952 before, 0.3 percent larger.

## Executed, with the numbers

| Check | Result |
|---|---|
| Brand suite, at the branch point | FAIL 0, WARN 1, SKIP 2, PASS 3659, 107.8 s |
| Brand suite, at the tip | FAIL 0, WARN 1, SKIP 2, PASS 3789, 108.7 s |
| `count_headings.py`, all three reports | 0 unnamed tables, exit 0; exit 1 on the before report |
| `test_ma_advantage_split.R` | 49 pass, 0 fail. The two parts at fragment level, which the browser drives sit above |
| `drive_chrome.py` | 142 / 167 / 169 checks, 0 failed |
| `drive_destinations.py` | 357 / 388 / 388 checks, 0 failed |
| `drive_pin_titles.py` | 63 / 96 / 96 checks, 0 failed |
| `drive_save_roundtrip.py` | 114 / 118 / 118 checks, 0 failed |
| `drive_overview.py` | 60 / 60 / 58 checks, 0 failed |
| `drive_funnel_base.py` | 99 / 99 / 79 checks, 0 failed |
| `drive_two_categories.py` | 15 / 15 / 15 checks, 0 failed |
| `drive_excel_export.py` | 304 / 339 / 340 checks, 0 failed |
| `drive_element_flags.R` | 82 / 82 / 82 checks, 0 failed, PASS |
| `reachability_check.py before after` | PASS on all three; every parseable island numerically identical |
| `anchor_resolution.py before after` | 41 of 41 and 69 of 69, PASS on all three |
| `capture_artifacts.py` | every artefact landed and parsed, 1 pre-existing defect |

The one `capture_artifacts.py` defect is the PNG that carries JPEG bytes,
recorded as gap 2 in the Stage 6 handover and unchanged by this work.

## Adversarial pass, and what it caught

1. **The Mental Advantage detail host would have taken a second commentary
   box on `advantage-<cat>`.** It shares the internal tab name with the main
   host, and the toolbar's anchor was derived from that name. `brTogglePin`
   resolves an anchor by taking the first match, so the second box would have
   been unreachable and the first would have been ambiguous. The toolbar is
   now gated on the leaf declaring an anchor.
2. **The presence test in `01_data_transformer.R` would have registered the
   detail host as the main one.** It greps for `data-ma-subtab="advantage"`,
   which both hosts emit. It tests `data-ma-adv-part="detail"` instead.
3. **`default_tab` would have hidden the detail sub-tab.** It was set from
   `only_tab`, which is `"advantage_detail"`, and the visibility rule compared
   against `"advantage"`. Both now resolve through `default_tab`.
4. **The stimulus toggles would have drifted.** Driven in both directions in
   `drive_chrome.py` rather than reasoned about.
5. **A study with Mental Availability and no advantage would have had an empty
   drawer.** Covered by a test that renders that mix, because the IPK fixture
   always has an advantage block.
6. **Two headings would have sat one under the other** on MA metrics and on
   Mental Advantage. The first drops a level and names the focal brand, the
   second goes.
7. **The all-brand metrics table read as part of the focal strip**, because
   its nearest heading was the focal brand's name. Caught by the harness's
   own table-to-heading pairing, and given its own `h4`.

## Known limits, stated rather than left to be discovered

- **One full-depth category.** The IPK fixture has one, so every browser check
  ran against Dry Seasonings and Spices. `drive_two_categories.py` clones the
  category and passes, and the unit tests render other element mixes.
- **Branded Reach, Ad Hoc, Audience Lens and Shopper Behaviour render only on
  the QA extras fixture**, two of them from invented data that is labelled as
  such. Their leaf heads and ledes were driven there and nowhere else.
- **Nothing was run weighted**, and nothing here reads a weight.
- **No `launch_turas()` run and no real project.** The three reports were
  generated into a scratchpad. Nothing was written into the repository, into
  OneDrive or into any TurasProjects folder.
- **Duncan's own four-category report was not opened.** Its counts are quoted
  from his message and the fixture's differences from them are recorded above
  rather than reconciled.
- **No pinned card, PNG or workbook was opened in a viewer.** The gates assert
  the card appears, the export runs and the intercepted workbook parses.

## What Duncan owes

1. **A `launch_turas()` run on the real four-category project, and an
   eyeball.** Four things to look at: every table now carries a name and, on
   the ones where the name is not self-explanatory, a line under it; Mental
   Availability has an Advanced drawer holding the full matrix and the
   buyer-gap view; the stimulus toggle in that drawer moves with the one above
   it; and the category is repeated on each heading in a pane, which is
   decision 2 and is the one piece of this he may want changed.
2. **A ruling on decision 12**, whether the Advanced accordion toggle and the
   leaf head under it should both name the item.

**Not merged and not pushed.** Branch `fix/brand-destination-labelling`, on
top of `36f97062`.

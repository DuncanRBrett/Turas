# The brand report's Excel export, fixed

Branch `fix/brand-excel-export`, cut from `main` at `33000b28`, in the
worktree `/Users/duncan/Dev/Turas-brand-simplify`. Not merged, not pushed.

Everything below was executed in the session that wrote it. Where something
was not run, it says so beside the claim.

## The defect

A QA session on 7 September 2026 opened an exported workbook in LibreOffice
rather than only inspecting it programmatically, and found three things wrong
with the same piece of code: the walk in `_brTablesToWorkbook` that turns a
rendered table cell into a workbook cell, in
`modules/brand/lib/html_report/js/brand_report.js`.

1. **A figure ran into the range rail beneath it.** The Brand Funnel's
   category average shows 61% with a 51 to 72 rail under it. The old walk
   took `cell.textContent`, which is `"61%51%72%"`, stripped the per cent
   signs and called `parseFloat`, which gave the number **615172**.
2. **Labels were coerced to numbers.** `parseFloat` reads a leading numeric
   prefix and discards the rest, so the portfolio footprint's "1/9" was
   written as the number 1, and a brand named "5 Roses" would be 5.
3. **The workbook carried rows the reader's brand filter had hidden.** The
   walk read every `tr` in the table whatever its display.

That extraction dates from about April 2026, five months before the
simplification programme, so all three are pre-existing rather than
regressions. The diagnosis was confirmed rather than assumed:
`.ma_catavg_cell_html()` in
`modules/brand/lib/html_report/panels/02_ma_panel_table.R` writes the figure
and the two bounds as adjacent nodes with no whitespace between them, which
is exactly what produces `615172`, and running the new node test against the
committed builder reproduces the value (below).

## What was changed

One production file: `modules/brand/lib/html_report/js/brand_report.js`. It
holds two changes: the walk, and the anchor the section buttons resolve.

### The walk asks three questions it did not ask before

**Is the reader looking at this?** `_brShown()` reads the node's own computed
display and visibility. It is deliberately blind to ancestors. A category tab
or a Category Buying sub-tab that is not on screen hides its whole subtree,
and its tables are still inside the destination the toolbar exports; an
ancestor-aware test such as `offsetParent` or `getClientRects` would drop them
and the export would fall silent on eight analyses. A node's own computed
display is unaffected by a hidden ancestor, so the test catches exactly the
three things that record a reader's choice: the brand filter's
`row.style.display`, the portfolio footprint's hidden columns, and an in-cell
count annotation the stylesheet hides until Show count is on.

**Does this read as a separate piece of text?** `_brBreaks()` says a node
that is not a plain inline run starts its own token. That is what keeps
"Prefer not to say" and its role chip apart, and a brand name apart from its
FOCAL badge, while leaving the footprint's "1" and "/9" joined as "1/9". Both
claims were checked against the stylesheets: `.demo-opt-name` and
`.demo-opt-role` are `display: block` in `11_demographics_panel.R`,
`.ma-focal-badge` is `display: inline-block` in `02_ma_panel_styling.R`, and
`.pf-fp-cats-num` and `.pf-fp-cats-of` in `09_portfolio_panel_styling.R` carry
no display at all, so they stay inline.

**Is the whole cell a number?** `_BR_NUMERIC` is anchored, so a cell is a
number only when all of it is one, thousands separators and a trailing per
cent included. "1/9" and "5 Roses" stay strings. Every number the report
formats with a thousands separator uses a comma, checked by grepping
`big.mark` across `modules/brand/lib` and `modules/brand/R`, so no real
figure is turned into text by the anchoring.

### A section anchor now resolves to the element that holds the table

Found by driving the report rather than by reading it. `data-section` names
the pin button and the insight box as well as the panel, because all three
are addressed by the same anchor name. `_brExportPanel` asked for the first
match in document order, which for the four Portfolio sub-tabs is their own
pin button, and a pin button holds no table. All four Portfolio Excel buttons
therefore said **"There is no table on this section to export"** and wrote
nothing. Probed in headless Chrome:

```
  PROBE pf-footprint resolves to BUTTON.br-pin-btn tables=0
  PROBE pf-footprint subtab tables=1
  PROBE pf-footprint click produced a workbook: false
  ALERT: There is no table on this section to export.
```

The same probe against a report generated from the committed
`brand_report.js` at `33000b28` gives the same four alerts, so it is
pre-existing. The `pf-` clause already in the function was written for this
and never ran, because the pin button had already satisfied the test above
it.

The candidates are now gathered in order of how specific they are, and the
first that actually holds a table wins. A named element with no table still
wins over nothing, so a genuinely empty section keeps its old message rather
than exporting a neighbour's numbers.

## The four decisions

### Where the range goes: its own cells, never dropped

The rail is a real measurement, so dropping it would lose data the reader can
see. It is placed by the shape it has on the page.

- **A ranged column** gets two columns beside it, named from the rail's own
  title: `Cat avg`, `Cat avg (95% CI low)`, `Cat avg (95% CI high)`. Rows in
  that column with no range get an en dash.
- **A ranged row** gets two rows underneath, named from the row they belong
  to: `Category average`, `Category average (95% CI low)`, `Category average
  (95% CI high)`.

The reason for the split is the Metrics table. Its category average is a row
with a rail in every metric column; two extra columns per metric would leave
every brand row carrying en dashes in most of them. The Brand Funnel and the
Mental Availability matrix put the category average in a column, where two
columns beside it read naturally. `_brRangePlan()` counts ranged rows against
ranged columns and picks the smaller.

The name is read from the rail's `title`, not assumed. Category Buying reuses
the same rail for one standard deviation across brands, and the Brand Summary
sheet duly says `Category avg (±1 SD across brands low)`. Calling that a
confidence interval would be a fabricated statistic.

### Hidden rows: dropped, not marked

A workbook that silently contains brands the reader filtered out is the same
class of defect as a chart disagreeing with its table, so the rows go. The
same test drops hidden columns, which is how the Mental Availability matrix
narrows, and in-cell annotations the stylesheet is hiding.

The line between a reader's choice and navigation is worth stating, because a
destination export spans tabs the reader is not looking at. A brand filter is
a choice about **content**: the reader has said these brands are the
comparison. A tab is **navigation**. The destination toolbar's contract, set
in Stage 5, is every table in the destination, and it was built precisely to
restore the reach that splitting the Category Buying panel had lost. So the
export follows the filter and ignores which tab happens to be in front.

Worth knowing when reading a fixture report: a report **opens in Focal only**,
so on the IPK fixture fourteen of the fifteen Brand Funnel rows are hidden
before anyone touches anything. `capture_artifacts.py` prints "Cape Herb &
Spice" in its dump of that table and the workbook has no such row. The dump
is not wrong and the workbook is not wrong: the dump reads `textContent`,
which is how the QA session saw `61%51%72%` in the first place, and Cape Herb
& Spice is one of the fourteen rows the reader is not being shown.

### Significance markers: chrome, all six classes together

Found by measuring rather than by reading, and a consequence of the anchored
number test rather than one of the three symptoms. Recorded in full because
it changes what a workbook contains.

A reader can turn significance markers on for a destination.
`03_page_builder.R` hides six classes when the toggle is off:
`.ma-sig`, `.ma-fv-sig`, `.ma-adv-sig`, `.ct-sig`, `.fn-sig-avg`, `.fn-sig`.
Four of them draw an arrow, and the arrow strip at the foot of
`_brVisibleText` has always removed those along with the sort arrows, so a
workbook has never carried them. The two advantage tables draw an asterisk
instead, which no glyph rule catches. With the anchored number test, "+9.4 *"
became a string while "+7.3" beside it stayed a number. Driving the real
report with significance on measured the cost: **188 number cells with the
markers off, 183 with them on**, all five in one Mental Availability table.

A column that is numeric except on its significant rows sorts its own
findings into a block at the bottom of the sheet. The alternative, a
companion column per marked column, would double the width of a matrix that
already carries one column per brand.

So all six classes are named in `_BR_CHROME`. The workbook carries the
figures; the markers are read on screen, where the toggle that draws them
lives. The count is now 188 against 188. This is a deliberate, small loss of
information, and it makes the export consistent: before it, four marker
classes were dropped and two were not, by accident of which character they
happened to use.

**This is the one judgement in this branch that Duncan may want to
overrule.** The alternative that keeps the markers is the companion column,
and it needs a decision about matrix width before it could be built.

### An absent value is an en dash

`_BR_ENDASH` is the en dash, never "n/a" and never blank, wherever the
builder has to write a cell the page has no value for: a row with no range in
a ranged column, and a bound row's cells in columns that carry no rail.

## Elsewhere: does the same shape appear on other paths?

Four other export paths write a workbook. All four were read.

| Path | File and line | Reads | Rail | Hidden rows |
|---|---|---|---|---|
| MA matrix `.xls` | `brand_ma_panel.js:2149` | data attributes | removes both rail classes with `querySelectorAll` | skips `tr.style.display === 'none'`, writes an en dash for a hidden brand |
| MA advantage `.xls` | `brand_ma_advantage.js:905` | the JSON model, not the DOM | never touches it | builds from `block.cells` |
| Funnel table `.xls` | `brand_funnel_panel.js:2010` | the JSON model | never touches it | builds from `brandCodes` |
| Relationship `.xls` | `brand_funnel_panel.js:2545` | data attributes | removes the rail from the label column | skips hidden rows and the `relHiddenBrands` set |

None of the four has the concatenation defect: each reads its numbers from an
attribute or from the payload rather than from the cell's rendered text. One
small latent difference is recorded rather than changed: the relationship
exporter at line 2509 removes the rail with
`clone.querySelector(".ma-ci-bar-wrap, .ma-ci-limits")`, which removes only
the first match, so a label cell carrying both a bar and its limits would
keep the limits. No label cell in the report carries both today, and this
branch does not touch that file.

The shared builder is reached from two entry points, `_brExportPanel` (a
section anchor) and `_brExportRoot` (a destination toolbar). **Both were
driven through their real buttons**, and it was the section pass that turned
up the four dead Portfolio buttons above. Twelve scopes hold tables and all
twelve now export: four destination main views, three Advanced drawers, four
Portfolio sub-tabs and Category Buying's repertoire section. Overview has no
Excel button by design (`build_br_destination_toolbar(with_export = FALSE)`),
confirmed by counting the buttons in the report rather than assumed.

**One thing the fix does not reach, and it is worth a follow-up.**
`_brExportRoot` takes `table.br-table` and falls back to every table only
when there are none. Very few brand tables carry `br-table`: it is on the two
generic builders in `02_table_builder.R` and one table in
`03_page_builder.R`. Every panel table uses its own class. In the fixture
report no exported scope holds a `br-table`, so the fallback runs and every
table is exported, which is why the counts below are right. A future panel
that adds one `br-table` to a destination would silently reduce that
destination's export to that one table. Recorded, not changed: it is a Stage
5 design question, not one of the three symptoms.

## Verification, all executed

### The brand suite

From the repo root, `TURAS_ROOT=/Users/duncan/Dev/Turas-brand-simplify
Rscript -e 'testthat::test_dir("modules/brand/tests/testthat")'`.

- Baseline before any edit of this session, with the previous session's
  uncommitted work already in the tree: **FAIL 0, WARN 1, SKIP 2, PASS 3607**,
  115.3s. That is the brief's stated 3593 plus the 14 assertions in the
  `test_excel_export_js.R` the previous session had written.
- At the tip: **FAIL 0, WARN 1, SKIP 2, PASS 3614**.

The suite caught one of this session's own changes. `test_chart_focus.R:428`
asserts the exact source line `_brExportRoot(panel, panelId, "this section")`,
which is how it pins the claim that neither entry point grows a walk of its
own. Renaming that variable broke it, so the variable was renamed back rather
than the assertion relaxed.

### The new node test, run against the old builder

`modules/brand/tests/js/test_excel_export.js` drives the real builder against
a stub DOM shaped like the panels' markup. Against the current builder it is
**74 passed, 0 failed**. Against the committed builder at `33000b28`, with a
one-line export grafted on so the test can reach it, it is **29 passed, 45
failed**, and the first failure reads:

```
  FAIL: the category average cell reads 61
    expected: "61"
    actual:   "615172"
```

All four changes have coverage that fails on the old behaviour: the 615172
cell, "1/9" written as the number 1, a filtered row present in the file, a
significance-marked figure turning into text, and the Portfolio anchor
resolving to a pin button.

### The new Chrome driver

`modules/brand/tests/qa/drive_excel_export.py` presses every Excel button in
a rendered report, captures the workbook the click would have downloaded, and
checks it against the cells that were on screen. It reads the workbook back
with a parser written from the file format rather than from the builder, so
a builder writing nonsense cannot also make the check agree with it. A native
`alert()` is recorded and dismissed, so a button that refuses is a reported
failure rather than a hung run.

Against the three reports `generate_qa_reports.R` builds:

| Report | checks | failed |
|---|---|---|
| committed | 302 | 0 |
| extras | 337 | 0 |
| ungated | 338 | 0 |

| Scope | tables | sheets | cells with a rail | bytes | computed styles read |
|---|---|---|---|---|---|
| dss/mental/main | 5 | 5 | 34 | 17,058 | 997 |
| dss/buying/main | 4 | 4 | 8 | 4,809 | 153 |
| dss/buying/advanced | 6 | 6 | 41 | 44,664 | 2,456 |
| dss/meaning/main | 2 | 2 | 14 | 4,540 | 185 |
| dss/meaning/advanced | 4 | 4 | 0 | 8,073 | 214 |
| dss/audience/main | 8 | 8 | 0 | 14,040 | 696 |
| dss/audience/advanced | 6 | 6 | 10 | 28,290 | 1,163 |
| section/repertoire-dss | 2 | 2 | 0 | 1,558 | 36 |
| section/pf-overview | 1 | 1 | 0 | 5,855 | 182 |
| section/pf-footprint | 1 | 1 | 0 | 32,269 | 1,608 |
| section/pf-constellation | 1 | 1 | 0 | 13,427 | 288 |
| section/pf-clutter | 1 | 1 | 0 | 3,315 | 70 |

The brand filter is driven through the reader's own control, not the API
behind it, and in both shapes the defect can take.

- **Brands as columns**, the Mental Availability matrix: Focal only leaves 2
  on screen and hides 28. No hidden brand reached the workbook and no shown
  brand was missing.
- **Brands as rows**, the Brand Funnel: All brands puts all 15 rows on screen
  and all 15 are in the workbook; Focal only leaves 1 and hides 14, and none
  of the 14 is in the workbook. A report opens in Focal only, so the check
  widens first and then narrows, which is what makes the pair mean something.

**On cost, and on what could not be measured.** The visibility test asks the
browser for a computed style per node. Headless Chrome runs this driver under
a virtual clock that does not advance during synchronous script, so a
wall-clock reading would have been a fabricated zero and none is reported.
Counting calls instead: the largest workbook reads **2,456** computed styles.
Time was not measured.

### The workbook, opened

Every one of the thirteen captured workbooks was saved with the `.xls`
extension the report gives it and handed to LibreOffice, which opened all
thirteen as Calc documents and converted them. Reading the converted
`dss_buying_main.xlsx` back out of its own `sheet1.xml` rather than through a
reader that might coerce:

| | A | B | C | D | E |
|---|---|---|---|---|---|
| 1 | Brand | Aware | Consider | Past 12 months | Past 3 months |
| 2 | Base (n=) | n=438 | n=438 | n=438 | n=438 |
| 3 | Ina Paarman's Kitchen FOCAL | 92 | 67 | 45 | 32 |
| 4 | Category average | **61** | 24 | 10 | 6 |
| 5 | Category average (95% CI low) | 51 | 17 | 5 | 2 |
| 6 | Category average (95% CI high) | 72 | 31 | 15 | 9 |

B4 is stored as a number and A4 as a shared string. That is the exact cell
the QA session found as 615172.

`section_pf_footprint.xlsx`, the sheet the Portfolio button could not write
at all until this branch, carries B2 as the **string** "9/9" and C2 as the
number 92, and its header keeps the ampersand in "dry seasonings & spices".
Both sheets were also rendered to PDF and looked at.

### Every other script under modules/brand/tests/qa/

Run against all three reports built by `generate_qa_reports.R`.

| Script | committed | extras | ungated |
|---|---|---|---|
| `drive_chrome.py` | 125, 0 failed | 150, 0 | 152, 0 |
| `drive_destinations.py` | 353, 0 | 384, 0 | 384, 0 |
| `drive_excel_export.py` | 302, 0 | 337, 0 | 338, 0 |
| `drive_funnel_base.py` | 99, 0 | 99, 0 | 79, 0 |
| `drive_overview.py` | 60, 0 | 60, 0 | 58, 0 |
| `drive_save_roundtrip.py` | 113, 0 | 117, 0 | 117, 0 |
| `drive_two_categories.py` | 15, 0 | 15, 0 | 15, 0 |
| `drive_element_flags.R` | 81, 0 | 89, 0 | not applicable |
| `capture_artifacts.py` | every artefact landed, 1 known defect | same | same |

Every tally except `drive_excel_export.py`, which is new, matches the numbers
Stage 6 recorded. That is the point of quoting them.

`capture_artifacts.py` reports the same single pre-existing defect on all
three: the PNG control writes JPEG bytes under a `.png` name, because
`TurasPins.EXPORT_QUALITY` defaults to "standard". Nothing to do with this
branch.

The two-report gates, run between a report generated from the committed
`brand_report.js` and one generated from this branch's:

- `anchor_resolution.py`: **41 of 41** on the committed fixture, **69 of 69**
  on extras, **69 of 69** on ungated. PASS on all three.
- `reachability_check.py`: **PASS** on the committed pair, every island
  numerically identical. **FAIL on the extras and ungated pairs, and not
  because of this branch.** Generating the extras report twice from the same
  unchanged code and comparing the two also fails, and the whole of the
  difference is one field: `al-panel-data` carries
  `"generated_at":"2026-09-07T12:05:37"` against
  `"generated_at":"2026-09-07T12:10:17"`. The check harvests digits out of an
  island, so a wall-clock stamp reads as a numeric change. Audience Lens only
  renders on the extras and ungated fixtures, which is why Stage 6 defined
  this gate on the committed pair alone. Recorded, not fixed.

`count_chrome.py` reports counts rather than passing or failing. The extras
and ungated counts match Stage 6 exactly. The committed report reads pin 25,
PNG 17 against the 29 and 21 in the Stage 6 table. That gap is not this
branch: running `count_chrome.py` against a committed report generated from
the `33000b28` JavaScript gives the same 25 and 17. The two pin-picker
commits that landed after the Stage 6 log was written are the likely cause,
and they are the kind of change that would move exactly those two counts.

## Deviations from the plan

1. **The significance-marker decision was not in the brief.** Found by
   driving the real report, caused by the anchored number test, and set out
   in full above so it can be reversed on its own.
2. **The Portfolio anchor fix was not in the brief either.** It is on the
   same code path and it is what "check the other entry point" turned up: a
   workbook that carries what the reader is looking at means nothing on a
   button that carries nothing at all. Four buttons, one function, its own
   node coverage.
3. **Timing was replaced by a count.** The plan was to time the builder on
   the largest destination. The virtual clock made that impossible to measure
   honestly, so computed-style reads are counted instead and no time is
   claimed.
4. **Sheet names are still written into an XML attribute unescaped.** A name
   containing `&` or `"` would produce a workbook Excel refuses to open at
   all. Every name today is a generated identifier or one of the nineteen
   entries in `.BR_LEAF_LABELS`, none of which contains either character, so
   it cannot happen now. Observed and left alone: a different defect shape,
   outside this brief.

## Files

- `modules/brand/lib/html_report/js/brand_report.js` (the fix)
- `modules/brand/tests/js/test_excel_export.js` (new, node)
- `modules/brand/tests/testthat/test_excel_export_js.R` (new, runs it in the
  suite and pins the design decisions in the source)
- `modules/brand/tests/qa/drive_excel_export.py` (new, headless Chrome)
- `docs/v2_lift/NOTES_BRAND_EXCEL_EXPORT_FIX.md` (this file)

Nothing outside `modules/brand` and `docs/v2_lift` was touched. Reports were
generated only to the session scratchpad, never to a project folder, and the
pipeline was never run on a real config.

# Pricing Session B: implementation notes

**Branch:** `feature/pricing-v2-report`, off main at `9d5b187f` (which is
`0698ffd2` plus the Session A review findings commit).
**Brief:** `HANDOVER_PRICING_V2_FOR_OPUS.md` section 4, B1 to B5.
**Rulings taken:** R1 `drop` (Session A's default, unchanged), R2 monadic is in
the tab. R3 is recorded under Deviations.

Order of work: B1, B2, B3, B5, B4. Everything but B4 is additive; B4 deletes
about 4,500 lines and breaks tests by design, so it goes last and the
definition of done (the demo's Pricing tab rendered) is reached before it
starts.

---

## B1. Island writer (DONE)

`modules/pricing/R/14_v2_island.R`: `serialize_pricing_layer()` and
`write_pricing_island()`, writing `{output}_pr_island.json` with
`meta.kind = "pricing"` and schema 1. Wired into `00_main.R` as step 8b, after
the Excel write and before the classic report, and registered in
`.source_pricing_module_files()` (the module loader is a whitelist; a new file
not listed there is never loaded in production).

Blocks: `meta`, `vw`, `gg`, `monadic`, `recommendation`. A block the run did
not produce is absent, never `{}`. Per-row vectors go through `I()` so a
one-rung ladder or a one-cell monadic still arrives as an array; `meta.methods`
too, for the same reason.

Executed: both the committed Karoo both-methods config and the monadic config,
headless into the scratchpad. The both-methods island is 6.6 KB, carries
`vw` and `gg` and no `monadic` key, and its VW curve is downsampled from 3,201
grid points to 120 with both ends kept. The monadic island carries `monadic`
only.

### Deviations

- **`method_price_cv` added to the synthesis return.** The handover asks the
  recommendation block for "the method agreement figure". The synthesis
  computed that coefficient of variation but returned only the sentence built
  from it. Rather than duplicate the formula in the island writer, the number
  is now returned from `assess_recommendation_confidence()` and surfaced as
  `synthesis$method_price_cv`. Two lines in `12_recommendation_synthesis.R`,
  no behaviour change.
- **The VW violation count is not in the island.** The engine recomputes
  violations on data the `drop` behaviour has already cleaned, so it reads
  0.0% on a run that excluded 44 respondents for violating (the Session A
  review's F5, owed to the follow-up branch). Publishing that number on a
  client-facing tab would repeat the defect at a second site, so the field
  stays out until F5 lands. The Excel Validation sheet carries the real
  figure. A test pins its absence.
- **NMS is not serialised.** The handover's `vw` block does not list it, and
  the Session A review found it broken on both paths (F3), with a refusal by
  name owed on the follow-up branch.
- **`nMethodPrices`, not `nMethods`.** The synthesis compares method price
  points (two VW points, the GG optimum, the ladder), not methods, so the
  count is named for what it is.

### Tests

`modules/pricing/tests/testthat/test_v2_island.R`, 23 tests. Every one fails
on main at `34078b33`, where the file does not exist. They cover the absence
rule, the array rule, curve downsampling, the two GG curves kept apart, arc
elasticity carried on the rung its step ends at, the provenance sentences, the
simulator-file condition, the refusal on an empty island, and an end-to-end
Karoo run whose island numbers equal the run's own headline numbers.

Pricing suite after B1, from the repo root:
`28 files, 368 tests, 1,091 passing, 0 failed, 0 skipped, 0 errors, 14 warnings`
(the Session A baseline was 27 files, 345 tests, 997 passing, same zeros).

---

## B2. Tabs side (DONE)

The maxdiff hook copied with pricing names, in every one of the seven places.
The two-place whitelist trap is real and both were done:
`pricing_island` in `build_config_object()` AND in `TABS_KNOWN_SETTINGS`
(`crosstabs_config.R`), plus the template row in
`generate_config_templates.R`, `.read_pricing_contribution()` and the
`pr_json` pass-through in `run_crosstabs.R`, `pr_json = NULL` on both
`build_report_v2.R` signatures with `pr_inlined` through `escape_island()`,
`{{DATA_PR}}` in `template.html`, and `TR.PR` plus the tab, the render
dispatch and the filter-hidden list in `24_shell.js`.

The view is `assets/js/27z_pricing.js` with its own `pr-*` block appended to
`styles.css`. Provenance panel first, then the recommended price, then Van
Westendorp (four points with intervals, and an SVG of the four curves with the
points marked), Gabor-Granger (rung table plus a demand and revenue chart with
the optimum marked) and monadic (cells against the fitted curve). Every label
goes through `esc()`; a missing value is an en dash.

### Deviations

- **The charts are drawn in the view, not through `TR.svg`.** `03_svg.js` is
  not loaded in the node gate's sandbox and the maxdiff view is likewise
  self-contained. The pricing view builds its own SVG strings with literal
  colours, which is the rule `03_svg.js` itself sets so a chart rasterises the
  same way it renders.
- **`d2.state.tab === "pricing" ||` was inserted BEFORE the cover/conjoint
  line, not appended.** `test_conjoint_island.R:105` pins the tail
  `d2.state.tab === "conjoint";` as a fixed string. Both existing island tests
  were re-run after the edit.

### Tests

`modules/tabs/lib/html_report_v2/tests/pricing_view_tests.mjs` (15 blocks) on
the maxdiff gate's pattern, and `modules/tabs/tests/testthat/test_pricing_island.R`
(44 assertions, no skips) on `test_maxdiff_island.R`'s. The R file goes further
than its model in three places: it builds `config_obj` for real rather than
grepping the source, it exercises `.read_pricing_contribution()` against a
missing file, a maxdiff island and a real one, and it builds an actual report
with and without a pricing island and asserts the two are identical.

---

## B3. Tabs export (DONE)

`modules/pricing/R/15_tabs_export.R`, wired into `00_main.R` as step 8b, with
the `FEATURE_TABS_EXPORT_PENDING` refusal in `apply_pricing_defaults()`
replaced by an id gate.

### The deviation that matters

**The July brief specified 0/1 columns. That would report zero at every
price.** A tabs Multi_Mention counts a mention by comparing each cell to the
option's `OptionText` (`calculate_row_counts()`,
`modules/tabs/lib/cell_calculator.R`), not by summing flags. Verified by
execution against that function: a label-coded grid counted 3 and 2 mentions on
a four-respondent fixture where the 0/1 grid counted 0 and 0. So a cell holds
the rung's own label ("R60.00") where the respondent would buy and is empty
otherwise, and the Options rows carry exactly those labels. The METHOD sheet
states the contract, and the integration test in `test_tabs_export.R` asserts
both directions.

Second consequence, disclosed rather than hidden: tabs reports over the banner
base while the pricing report divides by the rung's answered base. The METHOD
sheet carries the per-rung answered bases and says where the two will differ,
and the run prints a console note when any rung was not answered by everyone.

Third, and worth saying plainly because it looks like a bug: in a `both` run
the engines receive the validated data, so a respondent excluded by Van
Westendorp validation has BLANK ladder cells in the export even though they
answered the ladder. On the Karoo example that is 44 of 400. Their
`pricing_valid` is 0 and the METHOD sheet's base row explains the gap, so the
two bases can be reconciled rather than argued about.

### The second contract mismatch, caught by the demo

The Options rows must be keyed by COLUMN, not by question code. A tabs
Multi_Mention looks its options up with `^{code}_[0-9]+$` against the Options
sheet's `QuestionCode` (`question_orchestrator.R`), so each rung needs a row
keyed `GGACC_1`, `GGACC_2` and so on. The first version copied the maxdiff
Allocation shape, where every row carries the bare question code. The
integrated demo found it: tabs reported all 1,740 answers as unmatched values
and dropped the question from the report. The exporter now writes the
Multi_Mention shape, a test pins it with the reason, and the demo uses the
export's own rows as they come.

Two contract mismatches in one small feature is the argument for B5 existing
at all. Neither would have shown up in a unit test written from the brief.

### Other deviations

- **`run_gabor_granger()` now returns `gg_data`.** The exporter needs the coded
  long data the engine actually analysed, imputation included; rebuilding it
  from the raw columns would have exported something the report never used.
  One additive field.
- **The export refuses on an id mismatch.** If the ladder is keyed on a column
  other than `ID_Variable` the export stops rather than joining on row order.
- **WTP column named `{QCode}_WTP`**, from the ladder when there is one (right
  censored at the top rung, stamped) and from the Van Westendorp midpoint
  otherwise.

Tests: `modules/pricing/tests/testthat/test_tabs_export.R`, 54 assertions,
including the integration proof through tabs' own `calculate_row_counts()`.
Executed end to end on the real Karoo data: 400 rows, 356 in the pricing base,
GGACC_1 at 334 of 356 mentions, which is the 93.9% the island reports.

---

## B4. Simulator out, classic report retired (DONE)

- **New**: `modules/pricing/lib/html_simulator/` (`01_simulator_parts.R`,
  `99_simulator_main.R`, `simulator_styles.css`, `js/pricing_simulator.js`).
  `Generate_Simulator = TRUE` writes `{output}_simulator.html` and the island's
  `simulatorFile` names it.
- **Deleted**: `lib/html_report/` (5 R files, 6 JS files) and `lib/simulator/`
  (the dead fork), with `00_main.R` step 9 replaced by the simulator build.
- **Fixed on the way across**: P1c (the chart read prices from the total sample
  and intents from the selected segment, so a segment with its own grid was
  drawn against the wrong axis); P3a ("Revenue Index" named three different
  scales; it now means price times intent everywhere, "% of optimum" is its own
  row, and the chart's fitted line says it is scaled to fit); P2a (the islands
  are jsonlite plus island escaping, not a hand-rolled escaper).

### Deviations

- **`Generate_HTML_Report` is WITHDRAWN, not RETIRED.** The handover says to put
  it in `PRICING_RETIRED_SETTINGS`, but unlike conjoint's list, which announces
  and continues, pricing's list REFUSES. Retiring it there would refuse every
  config in the field, including all four committed Karoo configs and Duncan's
  own working config, over a deliverable that moved rather than a setting that
  never worked. So there is a second list, `PRICING_WITHDRAWN_SETTINGS`,
  announced in a box with what replaced it, and the run continues. The flag is
  forced to FALSE so nothing downstream believes a report exists.
- **The shipped template was regenerated** to drop the withdrawn row (md5
  1407ddda... to 926205e1...). The four committed Karoo configs were NOT
  regenerated: `examples/pricing/Karoo_Pricing_Config.xlsx` carries an
  uncommitted edit of Duncan's. They still carry the row and will print the
  withdrawal notice; the example generator no longer writes it.
- **R3 applied**: `MARKETING.md` and `METHODOLOGY_COMPARISON.md` deleted from
  `modules/pricing/docs/`, per section 7's standing recommendation. Reversible
  with one git command.
- **A defect observed, not fixed, outside this module.** The conjoint
  simulator's island escaping has the same bug this session found in its own
  copy: `99_simulator_main.R` in `modules/conjoint/lib/html_simulator/` escapes
  with `fixed = TRUE`, and with fixed matching the replacement is taken
  literally, so the JSON receives an escaped backslash and the value parses
  back as the seven-character text u003c preceded by a backslash, rather than
  as "<". Script-safe but wrong. Out of scope here; logged for Duncan.

### The test-count drop, accounted for

Deleted with the code they tested: `test_html_report.R` (408 lines),
`test_added_slides.R` (193 lines), and 18 blocks in `test_edge_cases.R` that
exercised the retired transformer, table builder, chart builder and page
builder. Rewritten rather than deleted: `test_simulator.R` (the extractors kept
their names, so the coverage moved across, plus the P1c and P3a regressions)
and `test_output_files.R` (one test of the deliverable that survived, plus a
check that the retirement is complete rather than half-done). One skip in
`test_integration.R` (the HTML data transformer) was replaced by an end-to-end
island test, so the suite has no skips at all now.

---

## B5. The integrated demo gains pricing (DONE)

`examples/integrated_demo/build_integrated_demo.R` now sources the pricing
example's functions, simulates the pricing questions on the SAME 600
respondents (section 4b), runs the module (5c), joins its export to the survey
data by respondent id, declares `GGACC` as a Multi_Mention from the export's
own QuestionMap row, and points the tabs config's `pricing_island` at the
island. The pricing simulator is copied beside the report like the other two,
so the tab's link resolves. The README lists the Pricing tab, the frozen
contract and what to look for.

The demo's tabs run must still pass without a pricing island: that is covered
by `test_pricing_island.R`, which builds a report with and without one and
asserts the two are identical.

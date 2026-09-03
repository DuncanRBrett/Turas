# Handover for Opus: aggregate interactivity (the cube)

Written by Fable 5.1, 4 September 2026, from
`DESIGN_aggregate_interactivity_FABLE.md`. Read the design first; this file is
the work order. Follow `fable-method` and the Turas CLAUDE.md. Nothing is
"fixed" until a command in your session shows it. No em dashes in any string
that reaches a console, a manifest, a report or a commit message.

The goal in one sentence: a `cube` interactivity mode in which the delivered
HTML carries no per-respondent records, the live filter, custom banners,
Differences, Pattern Recognition, confidence and the Reader all still work over
the declared variables, and every figure equals what the microdata engine
computes.

## Before the first edit

1. `git branch --show-current`, `git status --short`. As of 00:55 on
   4 September this checkout carried uncommitted work from two other sessions:
   `delivery_manifest.R` and its test, `turas_release_audit.R` and its test,
   edits to `turas_minify.R`, `import_all.R`, `21d_disclosure.js`,
   `32_report.js`, `disclosure_tests.mjs`, `saved_copy_namespace_tests.mjs`,
   `run_tabs_gui.R`, and `examples/pricing/Karoo_Pricing_Config.xlsx`. Do not
   start until those are committed. If they are still uncommitted, stop and
   say so.
2. Branch off main: `feature/aggregate-cube`.
3. Baseline, and record the counts:
   `for f in modules/tabs/lib/html_report_v2/tests/*_tests.mjs; do node "$f"; done`
   (41 files, all green on 4 September) and
   `Rscript -e 'testthat::test_dir("modules/tabs/tests/testthat")'`.
4. Read, in this order: `modules/tabs/lib/microdata_writer.R` (the header and
   `build_microdata`), `21_stats.js` in full, `22_model.js` lines 175 to 300
   and 500 to 560 and 655 to 766, `26_filter.js` lines 55 to 130 and 180 to
   260, `27d_diffs.js` lines 50 to 100 and 120 to 260,
   `27f_takeout_data.js` lines 395 to 560, `27da_takeout_stats.js` lines 120
   to 145, `24a_reader.js` lines 25 to 95, `20_data.js` lines 228 to 262 and
   340 to 383, `build_report_v2.R` lines 128 to 200, `24_shell.js` lines 60 to
   80, `crosstabs_config.R` lines 230 to 270 and 800 to 835 and 1720 to 1740.

## Stage 1. The harness first

No node gate today runs the computed path against an R-built microdata island.
Build that before anything else, so every later stage has a failing test to
turn green.

1a. `modules/tabs/tests/fixtures/parity_project/regenerate_parity_island.R`
gains two outputs per configuration: `parity_micro.json` and
`parity_micro_weighted.json`, the `serialize_microdata()` output for the same
run that writes `parity_island.json`. Keep the existing outputs byte-identical;
this is additive.

1b. New node gate `modules/tabs/lib/html_report_v2/tests/computed_parity_tests.mjs`.
Loads the same module list `parity_stats_tests.mjs` loads, installs
`parity_island.json` plus `parity_micro.json`, and for every question and
every banner group asserts `model._computedModel(q, banner, [])` equals
`model._publishedModel(q, banner)` cell by cell: base, `baseW`, `baseEff`,
`pct` and `mean` to displayed precision (`TR.fmt` decides the decimals; use the
formatted strings), and `n` exactly on unweighted. Then the weighted pair.

Significance letters in 1b follow the scope the existing cross-engine spec
already sets (`docs/tabs_production_review_2026-08/CROSS_ENGINE_STATS_SPEC.md`,
sections JS-2 and JS-3 of `parity_stats_tests.mjs`): exact for proportion
letters on the unweighted fixture; for mean rows, and for the weighted
fixture, decisions must agree outside a band around alpha and pairs inside
the band are logged, not failed, because the JS mean test is a z where R runs
a Welch t. Do not tighten that to exactness and then report a "parity bug";
the divergence is documented. The `31_selftest.js` case "filter mask +
recompute (golden vs published)" is the in-browser version of this comparison
and shows its shape. Expected: green on the current engine under that scope.
If it is not, stop and report; the cube must not be built on it.

The cube-versus-micro comparison in 1c and 3f is a different matter: both
sides are this engine, so letters there are exact, no band.

1c. The same file gains a second section that will drive stage 3: it takes a
`source` argument (`micro` or `cube`) and runs an enumerated set of views
through both, comparing cube against micro. Write the enumeration now and
skip it with a printed reason until `parity_cube.json` exists. Views: every
question, times every banner group plus `custom:<code>:cat` and
`custom:<code>:net` for each declared variable, times each of: no filter,
every single level of every declared variable, every pair of levels from two
different declared variables. On the parity fixture that is a few thousand
models; it should run in seconds in node.

## Stage 2. The R writer and the config keys

2a. `modules/tabs/lib/cube_writer.R`: `build_cube(micro, data_layer, config_obj)`
and `serialize_cube(cube)`. Pure. Consumes the list `build_microdata()`
returns, never `survey_data`. Implements the island in design section 3.1:
`vars` (banner groups from `micro$banner_vars` with their occupied column
indices as levels; question variables from `html_report_v2_filter_vars` with
category row indices as levels), `questions[q].has`, `robust_range` and
`histogram` per question with scores (mirror `robustRange` in `27d_diffs.js:144`
and `gatherBimodality` in `27f_takeout_data.js` exactly, including the
12-distinct-values rule and the zero-based scale detection), and `slices` up
to `html_report_v2_cube_order`.

The accumulators, per cell, per question, must mirror the loops in
`21_stats.js` line for line, including the base definitions:

- `a`: everyone in the cell.
- `b`: `tabulate` base, a raw answer present or a box present.
- `nb`: `netCounts` base, raw answer present, written only when it differs
  from `b`.
- `r`: sum of w per category row; an answered-unshown marker (`-2`) counts in
  `b` and in no row; a multi-mention answer counts in each of its rows.
- `n`: sum of w per NET in `q$net_members`, union semantics.
- `x`: sum of w per box row index.
- `s`, `sr`, `rt`, `m` as in the design table.

2b. The block rule, as a separate pure function `cube_block_ok(cells, k)` with
its own tests: a block ships when every occupied cell's `b[1]` is at least k;
inside a shipped block, `s`, `sr`, `rt`, `nb` and `m` are present for every
cell or absent from the block, each gated on its own count. Refused blocks are
written as `null`. Also a monotonicity test: for every shipped block of order
2 or 3, every projection of it is shipped.

2c. Config. In `crosstabs_config.R` `build_config_object()` register
`html_report_v2_interactivity` (enum `records`, `cube`, `none`; default
`records`; `html_report_v2_microdata = FALSE` maps to `none`; both set and
disagreeing is a `CFG_INTERACTIVITY_CONFLICT` refusal),
`html_report_v2_filter_vars` (character, split on comma, trimmed) and
`html_report_v2_cube_order` (integer 1 to 3, default 2). Add them to the
settings name lists near lines 808, 830 and 1725 to 1736, and to the settings
template in `generate_config_templates.R`. Validation: `cube` with
`min_reporting_base` not above 1 refuses with `CFG_CUBE_NEEDS_K`; a filter
variable that is not a single-response question with category rows, or a
box-category banner, refuses with `CFG_CUBE_FILTER_VAR`. Console box on every
refusal, as CLAUDE.md requires. Test at the `build_config_object` layer, not
with a hand-built list.

2d. `run_crosstabs.R` around lines 981 to 1030: in `cube` mode build the
microdata list, pass it to `build_cube`, serialise the cube, and pass
`micro_json = "null"` and a new `cube_json` to `write_html_report_v2`. The
microdata list must not survive past this block. Console output states the
mode, k, order, blocks shipped and refused. The delivery manifest gains the
line in design section 5; `tabs_delivery_manifest()` gains a `cube` argument.

2e. Tests: `modules/tabs/tests/testthat/test_cube_writer.R`. Hand-built micro
lists for each base-definition edge (box-only respondent, answered-unshown,
multi-mention in two rows of one NET, a null score with a present answer, a
ratio with a zero denominator), the block rule, monotonicity, refused blocks
as null, and the serialised island parsing back. Then `regenerate_parity_island.R`
also writes `parity_cube.json` and `parity_cube_weighted.json` at k = 5,
order 2, with every banner group declared and one question declared as a
filter variable.

## Stage 3. The engine seam and the routing

3a. `21_stats.js`. Add a cube branch to `mask`, `maskCount`, `columnsFor`,
`tabulate`, `netCounts`, `boxCounts`, `indexMeans`, `medians`, `seriesMeans`,
`ratioOfTotals` and `netScoreMeans`, chosen by `TR.CUBE && !TR.MICRO`. Return
shapes unchanged. Add `stats.restOf(col)` (micro: the complement Uint8Array
as `22_model.js:520` and `27d_diffs.js:61` build it today; cube: a column spec
flagged `rest`), `stats.momentsOf(q, col, audience)` returning
`{n, sw, sw2, swx, swx2}` for the takeout Welch (note that the takeout cell
family's "overall" arm skips respondents in no banner column, `cd < 0` in
`gatherCellFamily`, so its overall moments are the sum of the column cells, not
the Total audience; mirror that or the overall mean drifts), and `stats.source()` returning
`"micro"`, `"cube"` or `null`. The slice resolver: from an audience spec and a
column spec, the required variable set; refuse with `{reason: "order"}`,
`{reason: "undeclared", var}` or `{reason: "block", q}`; otherwise sum the
matching cells. Two filters on one variable intersect their level sets.

3b. Route every direct reader in design section 4. Do them one file at a
time and run that file's gate after each. `27d_diffs.js` and `22_model.js`
use `restOf`; `27f_takeout_data.js` uses `momentsOf` for the cell family and
`questions[q].histogram` for bimodality; `24a_reader.js` reads the audience
record; `26_filter.js` reads the audience count and, in cube mode, offers only
declared variables in both pickers and drops the "Cross every table by"
wording; `20_data.js` gains `d2.hasComputedSource()` and validates hash
filters against `TR.CUBE.vars`; `27q_qualitative.js` fails closed under a
filter when `TR.MICRO` is null, exactly as it does today, and says so in the
tab; `31_selftest.js` skips the microdata cases; `32_report.js` states the
cube's k and order on the About page.

The indirect readers matter as much as the direct ones. Every caller of
`TR.d2.hasMicrodata()` decides whether a view takes the computed path, and if
one is left as is, cube mode silently renders the published table under a
filter. Grep for it and route each to `d2.hasComputedSource()`; as of
4 September the callers were `22_model.js:706` (the computed-path gate in
`model.forQuestion`) and `:737` (`viewModel.filtered`), `24a_reader.js:70`,
`25_cards.js:509`, `27d_diffs.js:255` (`collectFindings`) and `:364`,
and `26_filter.js:58`. Verify the lines before relying on them. The one place
that must keep asking for microdata specifically is the qualitative filter
(`27q_qualitative.js:209`), which has no cube equivalent.

3c. Refusals in the UI. A refused slice shows one authored sentence in the
filter bar and on the card, keyed in `data-text` like every other string
(`02_text.js` conventions), never a base of 0. Wording without em dashes.
Suggested: "This cut is not available in this report. Filters combine up to
{order} variables, on the declared variables only." and "Not available for
this question at this base (fewer than {k} people in one of the groups)."

3d. Island plumbing. `template.html` gains `data-cube` with
`data-island="v2"`; `build_report_v2_html()` and `write_html_report_v2()`
gain `cube_json`; `shell.boot` parses it into `TR.CUBE`; `d2.validate` checks
`schema_version`, `n`, `k`, `vars` and that no slice value is an array of
length `n`. The release audit (`turas_release_audit.R`) registers `data-cube`
as aggregate, and in `client_safe` mode parses it and refuses
(`CFG_CLIENT_SAFE_VIOLATED`) on any cell base with 0 < n < k or any slice
with a partial block.

3e. Sub-k published columns. Duncan said yes to decision 4 on 4 September
2026 (and to all five decisions in design section 7), so this is in scope.
It changes what the `none` build carries, which is what SACS runs. In `cube`
and `none` modes with k set, `data_layer_writer.R` writes
null for every `pct`, `n` and `mean` of a column whose unweighted base is
between 1 and k minus 1, and keeps the base so the renderer's existing
suppression still labels it. Before nulling anything, read
`published_wave_contribution()` in `tracking_island.R`: tracking on a `none`
build is assembled from the published figures, so confirm it reads the Total
column only, or that a nulled banner column reaches the wave file as null
rather than as a zero. Test in `test_report_v2_bundler.R` beside the no-micro
ship test at line 144, and a tracking test if the wave file is touched.

3f. Run stage 1c for real: `parity_cube.json` through the cube branch against
`parity_micro.json` through the micro branch, both configurations. Expected:
every enumerated view identical to displayed precision, letters exact.
Refused views must be refused for the stated reason, and the enumeration must
assert that every view the block rule permits is actually served, not
silently refused.

## Stage 4. The end-to-end proof

4a. Build the Karoo integrated demo with `html_report_v2_interactivity = cube`,
`min_reporting_base = 5`, order 2, into the scratchpad, never into
`examples/` and never under `OneDrive*/TurasProjects`. Confirm from the console
output: 110 of 110 blocks shipped (the number measured on 4 September; quote
yours), the manifest line, and the release audit passing.

4b. The adversary script, in R as a testthat file reading the built HTML:
`data-micro` parses to null; no array in `data-cube` has length 600; every
cell base is 0 or at least 5; the label join from the first-look (index to
`data-agg` label) has nothing to join. Run the same three assertions on the
demo's `records` build and confirm the first and second fail there, so the test
is not green by construction.

4c. Headless render of the cube build with the probe pattern from
`docs/disclosure/experiments/build_variants.py`: open
`#tab=crosstabs&q=Q001&filter=Region:3`, dump the DOM, and compare the cell
texts under `#app` with the same URL on the `records` build. Identical. Then
`#tab=diffs` and `#tab=takeout`, the same comparison.

4d. Full suites again, counts quoted, both the node gate suite and
`testthat::test_dir("modules/tabs/tests/testthat")`, plus
`test_turas_minify.R` and `test_release_audit.R`.

## Done means

- Stage 1b green on the current engine before anything else moved, with the
  count.
- `test_cube_writer.R`, the block rule and monotonicity tests green.
- `computed_parity_tests.mjs` cube versus micro green on both parity
  configurations, with the number of views compared.
- The adversary test green on the cube build and red on the records build.
- The render comparison identical on three tabs.
- Every pre-existing gate green, counts quoted before and after.
- A note in `docs/disclosure/` with the cube byte size on the demo and on the
  parity project, the blocks shipped and refused, and anything that deviated
  from the design, under "Deviations".
- Commit on the branch, no merge, no push. Say plainly what is committed.
- `records` stays the default. Nothing in any `run_*_gui.R` changes.

## Do not

- Do not build the cube from `survey_data`. It must consume the microdata
  list, so the two engines share their inputs.
- Do not ship a cell-level suppression. The unit is the block.
- Do not add a `synthetic`, noise or rounding mode. Rejected in the design.
- Do not let `qual.maskFilter` return unfiltered records under an active
  filter. Fail closed.
- Do not weaken a parity comparison to a tolerance to get past a failure.
  Report the failure with the view that produced it.
- Do not put em dashes in any string that reaches the console, the manifest,
  a report or a commit message.
- Do not amend or rebase another session's commits.

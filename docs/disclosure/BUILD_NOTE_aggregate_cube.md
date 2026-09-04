# Build note: the aggregate cube

Opus 5, 4 September 2026. Written from
`HANDOVER_AGGREGATE_INTERACTIVITY_FOR_OPUS.md` and
`DESIGN_aggregate_interactivity_FABLE.md`. Branch `feature/aggregate-cube`,
off `main` at 9acd7b1b. Not merged, not pushed.

Every number below was measured in this session by running the thing that
produces it. Where a claim could not be executed it says so.

---

## What was built

`html_report_v2_interactivity = cube` ships a `data-cube` island of precomputed
sufficient statistics per (variable combination, question, cell) instead of the
`data-micro` island's one array position per respondent. The live filter,
custom and composite banners, Differences, Pattern Recognition, confidence
detail and the Reader all still work, on the declared variables, and every
figure equals what the microdata engine computes.

`records` stays the default. Nothing in any `run_*_gui.R` changed.

---

## Baselines and final counts

| | before | after |
|---|---|---|
| node gate files | 41, all green | 42, all green |
| tabs testthat | FAIL 0, WARN 0, SKIP 1, PASS 5468 | FAIL 0, WARN 0, SKIP 1, PASS 5627 |
| shared testthat | not recorded at start | FAIL 0, WARN 3, SKIP 5, PASS 953 |

---

## The gates, and what each one actually compared

**Stage 1, the harness.** `computed_parity_tests.mjs`, the 42nd gate file.

CP-1 and CP-2 run the COMPUTED path against a respondent island R built in the
same pipeline run as the published layer, which no gate did before. 140 cells
per configuration, at displayed precision, unweighted respondent counts exact.
Green on the engine as it stood, before anything was moved.

CP-3, proportion letters: 100 cells exact on the unweighted fixture against a
same-rule recompute of the published counts; 97 exact and 3 logged on the
weighted one.

CP-4, cube against micro: 270 enumerated views per configuration, 246 served,
24 refused, 3,724 cells compared, letters exact. The 24 refusals are exactly
the order-cap ones (two filters plus a banner is three variables, and the cap
is two), and a second test asserts every refusal names one of the three stated
reasons.

**Stage 2e, the writer.** `test_cube_writer.R`, 97 assertions on hand-built
microdata lists, one per base definition the engine has.

**Stage 4b, the adversary.** `test_cube_adversary.R` builds the same report
twice from the parity fixture, records and cube, and runs four checks over
both. The cube build passes all four; the records build fails the ones about
respondent records, so the gate is not green by construction.

**Stage 4c, the render.** `docs/disclosure/experiments/cube_render_compare.py`
renders both builds of the Karoo demo headlessly at fourteen URL states and
compares the table cells AND the whole rendered text of `#app`. Twelve
identical, two different as expected: the Report tab, where a cube build states
what it carries, and a cut above the order cap, where the cube shows

> This cut is not available in this report. Filters combine up to 2 variables,
> on the declared variables only.

and the records build computes the table.

---

## Measured on the Karoo integrated demo

Built into the scratchpad, never into `examples/` and never under
`OneDrive*/TurasProjects`. 600 respondents, four banner groups, twelve
questions, k = 5, order 2, `html_report_v2_filter_vars = Q008,Q009`.

| | records | cube |
|---|---|---|
| report file | 1,447,004 bytes | 1,813,000 bytes |
| computed island | 142,351 bytes (`data-micro`) | 208,433 bytes (`data-cube`) at four declared variables |
| `data-micro` | 600 respondents | `null` |

Blocks: with the four banner groups only, 132 of 132 shipped, none refused.
With Q008 and Q009 declared as well, 263 of 264 shipped and 1 refused, so the
block rule bites on real data rather than only in a fixture.

Cells: 1,274 cell bases on the four-variable cube, none between 1 and 4, the
smallest non-zero base 6. The longest array anywhere inside `slices` is 5, the
score accumulator.

On the parity project: cube 15,389 bytes against a micro island of 8,073, at
three declared variables on 200 respondents.

---

## Deviations from the design

Each of these is a place where the design left something open or where
following it literally would have been wrong.

**1. The order-0 slice, and the key it uses.** The Total column, "the rest"
with no filter, and every projection check all need the grand-total block. The
design's schema has no key for the empty combination. Keyed `"*"`, in the slice
map and in its single cell, because an empty string is not a usable name in an
R list or a JSON object, and `"*"` cannot collide with a real combination. A
declared variable whose name contains `"*"` is refused at config time.

**2. Questions nested under `q`.** The design puts each question's block
directly beside `cells` in a slice. A question whose code is `cells` would then
overwrite the audience record. Nested as `slices[key].q[code]`.

**3. `score_lo`, `score_hi` and `score_values` beside `robust_range`.** The
design's question record carries `robust_range` only. `meanFindings` in
`27d_diffs.js` also derives `scaleMin` and `scaleMax` from the full score
vector, and the median needs the distinct score values. All three added.

**4. The audience block is gated by the same rule as a question block, and a
refused audience refuses the whole slice.** The design gates question blocks
and is silent on the audience record. The filter bar, `disclosure.audienceBase`
and the Reader all count those cells, so shipping them while withholding the
questions would still say how many people sit in a cut of three. On the demo
this costs nothing: every order-2 audience cell clears k.

**5. Monotonicity is enforced, not asserted.** The design states "every
projection of a shipped block is shipped" as a property to test. It is not
automatic: a level whose only members fall in no column of a second variable
gives an order-2 block of empty cells that ships while its order-1 projection
is refused. So blocks are decided from order 0 upward and a block ships only
when every projection of it ships. The property is then an invariant of the
file rather than a hope, and the test checks it over a fixture where an order-2
slice actually ships.

**6. Medians.** The design says "precompute one scalar per cell". That serves
the Total column and a single banner column and nothing else: a median over a
UNION of cells cannot come from one median per cell. So a DESIGNED scale (at
most 12 distinct score values, the same rule `robustRange` uses) ships its
whole distribution per cell, which makes the median of any union exact and
discloses no more than the category counts beside it, since for a rating
question the score is a function of the category row. A continuous measure
(spend, counts) is served only where the cut resolves to a single cell, and
blanks otherwise. Never a plausible wrong number.

**7. No box partition variables in version 1.** The design allows box-category
banners as declared variables. A box grouping would be a second variable per
question, and the value is small: a hidden-scale question cannot be a declared
filter variable anyway. So a box filter is dropped in hash validation, the
picker does not offer one (`d2.boxRows` already returns empty with no
microdata), `boxCatRows` returns null, and `custom:CODE:net` on a question that
carries boxes shows Total only. All fail closed.

**8. `CFG_CUBE_FILTER_VAR` is raised where the questions are known.** The
handover puts it in `build_config_object`. That function cannot see the
questions, so it validates the shape there and the substance in
`cube_validate_filter_vars()`, called from `run_crosstabs.R` with the data
layer in hand. A rejected variable prints the TRS console box and the cube is
dropped rather than shipped half-declared.

**9. An empty picker says so.** Not in the design, and found by rendering the
demo. A cube build's picker offers the DECLARED variables only. The demo's
banner groups are not question codes, so with no `html_report_v2_filter_vars`
the picker was empty and read as a bug. It now shows one authored sentence
naming the setting that would change it. This is worth knowing before a client
build: on a cube build, a live filter needs `html_report_v2_filter_vars`.

---

## Divergences the gates LOG rather than fail

None of these is caused by the cube. Each was measured, and each has a cause
that was read in the source rather than guessed at.

**R rounds an exact half to the even neighbour; JavaScript rounds up.** Eight
cells across the two parity configurations where the figure is identical and
only the printed form differs, for example a weighted frequency of 24.5
published as 24 and rendered as 25. Pre-existing, and it affects a records
build exactly as much as a cube build.

**The weighted standard deviation.** R Bessel-corrects the weighted variance on
the SUM OF WEIGHTS (`standard_processor.R`, `sum(w*(v-m)^2) / (sum(w) - 1)`);
this engine corrects on the Kish effective base, because the same numbers size
its significance tests. Checked arithmetically: R's 81.2, times
`sqrt((neff/(neff-1)) / (sw/(sw-1)))`, is 81.80, and the engine computes 81.82.
Identical on any unweighted design. It surfaces on an NPS question because that
row prints at 0 decimals; on a 1 to 5 scale at 1 decimal it hides. **This is a
real, pre-existing disagreement between the workbook and the live report on
weighted studies, and it is worth a decision of its own.**

**Cube against micro, on a rounding boundary.** 13 weighted cells where the two
sources agree on the figure to 1e-8 and land either side of an exact half. The
cube sums each cell in R and adds the cells in the browser; the respondent
island accumulates every respondent in one pass. Counted and named with the
view, never widened into a tolerance.

**A variance formed by cancellation.** Where the true variance is zero the
engine's `(Σwx²/Σw) − mean²` reads 1.4e-6 on one source and exactly 0 on the
other. The comparison carries a 1e-5 absolute floor for that, five orders of
magnitude below the last digit any of these figures displays.

---

## One bug found and fixed, which predates this work

`release_island_body()` in `turas_release_audit.R` matched with `perl = TRUE`
and no `(?s)`, so `.` never matched a newline. Every report the template writes
puts the island JSON on its own line.

So the audit read NO island from a real deliverable. It printed
"Respondent-level island: absent" on a file carrying every respondent, and a
client-safe declaration passed instead of refusing. `turas_minify` runs that
audit on the final HTML with `refuse = TRUE`, so the enforcement committed at
9acd7b1b could not fire on a real file.

Verified before and after on a report built through `build_report_v2_html`:
before, micro present FALSE and violation FALSE on a file carrying 200
respondents; after, micro present TRUE, n 200, violation TRUE. Fixed at
9d26e60f, and the adversary gate now runs against a real built report rather
than a fixture, which is how it was found.

---

## Two things a cube build does NOT do, checked in the source

**Filtered qualitative views.** `qual.maskFilter` needs a per-respondent
membership and there is none. It fails closed, exactly as a `microdata = N`
build already does. The Qualitative TAB itself is unaffected: `d2.qualitative()`
gates it on the qual island having questions, never on microdata, so comments,
themes and sentiment all ship and are readable, with the R-side confidentiality
dials applied at build time. The theme-by-banner crosstab inside that tab also
needs per-respondent banner membership and is hidden, again as today.

**The VAS integrated report.** `build_vas_integrated_report.py` reads `micro.n`
and `micro.banner_vars` for its reconciliation checks, and its shared-audience
mechanism hands ROW INDICES from the crosstab filter bar to the eighteen
section pages. Its own comment states the contract: "That is only a set of
people if row i of the micro island is row i of the reporting dataset." A cube
has no row indices, by design. On a `none` or `cube` build it does not refuse
cleanly either: `json.loads("null")` returns None and the next line calls
`.get('n')` on it. VAS must stay on `records` until that integrator is reworked
to reconcile against the cube and hand over a declared-variable filter instead
of row indices. Nothing in the VAS project folder was touched.

Separately, and unverified against a real minified VAS build: that integrator
anchors on the literal JS string `shell.tabGroups = tabGroups`. Running terser
with this project's own flags on that pattern emits
`((...).TR.shell={}).tabGroups=function(){...}`, so the anchor does not survive
minification. It would refuse cleanly, naming the anchor.

Islands themselves are safe under minification: `turas_minify` protects every
`application/json` block verbatim, so `data-cube` survives it unchanged.

---

## Open, for Duncan

1. Should a cube build be able to filter the COMMENT list to the live audience,
   and show the theme-by-banner crosstab? It can, if the qual island carries
   each comment's banner column index for the declared variables, under the
   same k-anonymisation the demographic tags already get. That is a design
   decision about what the qual island carries, not a bug fix.
2. The weighted standard deviation divergence between R and the renderer,
   above. Neither engine is wrong; they Bessel-correct on different
   denominators, and the workbook and the report can print different SDs for
   the same weighted column.
3. Flipping the default to `cube` stays out of scope, per design section 7,
   decision 1.

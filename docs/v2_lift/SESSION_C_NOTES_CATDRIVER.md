# CatDriver Session C — implementation notes

**Branch:** `feature/catdriver-v2-report`, cut from main `56369c6b` (Sessions A
and B merged and pushed) on 2026-09-19.
**Work order:** `docs/v2_lift/HANDOVER_CATDRIVER_FOR_OPUS.md` section 4.
**Gates it was waiting on:** OPUS-0 (landed 2026-08-27) and TR.KD (landed with
keydriver Session C, 2026-09-18). Both were done; Duncan green-lit the start.

## What was built

A frozen island, `TR.CD`, and the tab that renders it.

- `modules/catdriver/R/13_v2_island.R` serialises a run and writes
  `{output}_cd_island.json` when the catdriver config's new `v2_island` setting
  is on. Off by default: a project with no tabs report has no use for it.
- `modules/tabs/lib/html_report_v2/assets/js/27j_catdriver.js` renders it.
- The tabs side gains a `catdriver_island` setting, a reader, a template slot
  (`data-cd`), a renderer gate and a tab.

Zero new row kinds, as the handover requires. The island is a separate block
because catdriver's axes are drivers by levels and drivers by subgroups, not
banner columns: an odds ratio has no base and no percentage, and a driver level
has no banner.

## Suites

| Suite | Result |
|-------|--------|
| catdriver | 22 files / 326 tests / **1,189 passing** / 0 failed / 1 skip |
| tabs (R) | 82 files / 1,808 tests / **6,213 passing** / 0 failed / 1 skip |
| node gates | **48 suites, all passing**, including the new `catdriver_view_tests.mjs` and its 16 gates |

The gate directory also holds four files that are not suites: `_text.mjs`,
`parity_engine_modules.mjs`, `pptx_visual_qa.mjs`, and `mutate_text_check.mjs`.
The last one is a policy check, and it reports one failure, in
`takeout_tests.mjs`, for asserting on wording the report author owns. That
failure is **not from this session**: it reproduces identically at `9a541ff8`,
the commit this branch was cut from. It comes from the Patterns card-base work
and is still open on main.

The tabs suite caught the one thing I had missed: `catdriver_island` was in the
config object before it was in the tabs template, and the test that binds the
two failed until it was in both. That guard is doing exactly what CLAUDE.md says
it is for.

## Verified by running it

- A real demo run wrote a real island (14 KB, seven blocks), which was then
  built into a v2 report on the **committed parity data layer** and rendered
  headless. The tab shows the provenance line, driver importance with its
  method, every odds ratio with its Wald interval and the statement that no
  bootstrap ran, the probability lift naming Churned, the subgroup matrix and
  the diagnostics drawer.
- A report built without an island still boots, carries `data-cd` as `null`,
  and leaves the renderer out of the bundle.
- A hostile driver label cannot break the island open: the escaped body holds
  no raw `<`.

## Deviations and judgment calls

1. **`v2_island` is opt-in on the catdriver side.** Writing a JSON file beside
   every workbook for projects that will never build a tabs report is noise. The
   GUI can switch it on per run through `options(turas.catdriver_island = TRUE)`
   and the config setting is the durable form.
2. **No importance interval, and therefore no whisker.** The module computes a
   chi-square share and no interval for it, so the importance panel draws bars
   only. Drawing a whisker there would mean inventing one. The odds-ratio table
   is where the intervals live, which is where the module actually has them.
3. **The audience strip changed for five tabs, not one.** It was printing the
   crosstab project's base ("n=200") directly above a panel reading "n=456".
   The frozen contribution tabs now say the filter does not apply and leave the
   base to the panel. That covers conjoint, maxdiff, pricing and keydriver as
   well, because the reason is identical and leaving four wrong to keep the
   diff small would be the wrong trade. All 53 gates still pass.
4. **Factor patterns travel.** The handover's content list did not name them,
   but the review's Phase 4 sketch did, and they are the only block on the tab
   with no model in it: the observed shares the model was fitted to. A reader
   who distrusts a coefficient can look at the counts underneath it.
5. **The classic report path is untouched.** The handover says to retire it only
   after Duncan confirms the v2 view supersedes it. It has not been retired.
6. **`27j_` not `27l_`.** The keydriver view is `27k_`; the catdriver view sorts
   just before it, so the bundle loads the two adjacent and a reader of the
   directory sees them together.

## Curated content, logged

The drop-list decision is recorded in `modules/tabs/docs/V2_MIGRATION_PLAN.md`
section 7 under "Logged choices", and the island contract is documented in
`modules/tabs/docs/11_DATA_CENTRIC_REPORT_V2.md`, beside the `TR.KD` one.

IN: importance with its method, odds ratios per level with whatever interval
exists, probability lifts with the outcome level they describe, factor patterns,
model fit with the base and the weighting statement, the subgroup comparison.

OUT, deliberately: per-level coefficient tables, the missing-data and collapse
reports, the bootstrap resample matrix, and per-respondent fitted probabilities.
The last is a decision rather than a convenience: they are model estimates of a
tabs-native outcome column with artificially reduced variance, so shipping them
as respondent data would invite a reader to cross-tabulate a model. A test
asserts the island carries no vector the length of the sample.

## Not done, not verified

- **The Shiny GUI has still not been run end to end by any session.** The tab
  was verified by building a report from R and rendering it headless.
- No client project was regenerated and nothing was written to OneDrive.
- The island has not been through `turas_minify`, so it has not been seen in a
  hardened deliverable. The renderer is stripped like every other contribution
  renderer, which the build path already tests, but a minified report carrying
  TR.CD has not been produced.
- The classic catdriver HTML report and this tab now say some of the same
  things in different places. Retiring the classic path is Duncan's call and was
  deliberately not taken.

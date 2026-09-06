# Handover: brand v2 lift review follow-ups (for Opus)

**Written:** 2026-09-06.
**Source:** the independent Fable pre-merge review, `docs/v2_lift/REVIEW_FINDINGS_BRAND_V2_LIFT_2026-09-05.md`. Read that document first; the finding IDs below (F3, F4, F10, F13, F14) are its IDs.
**Worktree:** `/Users/duncan/Dev/Turas-brand-v2-lift`. Branch `feature/brand-v2-lift`, tip `718f539e`, clean, 22 commits ahead of `origin/main`, not merged.
**Baseline to hold:** brand suite FAIL 0, WARN 1, SKIP 2, PASS 2399.

```
TURAS_ROOT=/Users/duncan/Dev/Turas-brand-v2-lift \
  Rscript -e 'testthat::test_dir("modules/brand/tests/testthat", reporter = ProgressReporter)'
```

Run it from the worktree root. The one warning is pre-existing (`max` of empty in `test_ma_panel_cat_avg_mask.R:155`) and the two skips are the baseline's.

---

## Working rules

- Do not read the fixing session's chat or the review session's chat. Work from this file, the findings document and the code.
- Before reporting any progress, audit each claim against a tool result. Report only what you can point at. If something is not verified, say so.
- If you do not know or cannot verify something, say so. A named gap is fine. Never fill in a missing number, path or fact with a plausible value.
- Delegate only genuinely independent, sizeable tracks. Never for a few reads, and never to double-check your own work.
- TRS conventions apply: no `stop()`, structured refusals, console output for Shiny visibility. See `CLAUDE.md`.
- No em dashes in any string that reaches Duncan or a client, commit messages included.
- Do not merge and do not push. Do not touch anything outside `modules/brand/` and `docs/v2_lift/`.

---

## Stage A: finish the reviewed branch

Both items land on `feature/brand-v2-lift`. Neither is visible in the IPK HTML report, so Duncan does not need to regenerate after this stage.

### A1. Blank weight cells refuse instead of warning (F3)

Duncan's decision: if a weight column has data but one or more cells are blank, refuse the run. He wants the data fixed before any numbers come out.

Current behaviour, committed by the review in `e9cd638d`: `.brand_coerce_weights()` in `modules/brand/R/00_guard.R` (around lines 214 to 236) turns blanks into 0, and `run_brand()` appends a warning naming the rows, status PARTIAL. `00_main.R:476` is the Mental Availability call that made the old NA behaviour dangerous.

What to do:

- Change the coercer to return a TRS refusal when the weight column has at least one value and at least one blank or NA cell. Pick a `DATA_*` code, name the affected row numbers in the message, and give an actionable `how_to_fix`.
- Update the M8 message so it describes the refusal, not the zero-fill. The old message claimed a behaviour the code did not have; do not repeat that mistake.
- A weight column that is entirely absent is not this case and must keep working as it does now.

**This flips a test the review wrote.** There is an integration test expecting PARTIAL with a message of the form "2 blank cell(s) ... rows 7, 120". It must now expect the refusal and its code. Update it deliberately, do not delete it, and do not report the resulting change as a regression.

### A2. Regenerate the template workbooks (F10)

Duncan's decision: none of the six workbooks in `modules/brand/templates/` are hand curated, so they become whatever the generator produces today.

- **Snapshot the six committed workbooks before you regenerate.** They are committed binaries. See the concurrent-session and binary-snapshot gotchas in `CLAUDE.md`.
- Run `generate_brand_templates(output_dir)` into `modules/brand/templates/`. The generator already saves through `turas_saveWorkbook`, so do not call `openxlsx::saveWorkbook` yourself.
- Verify by reading the regenerated files back: `Brand_Config_Template.xlsx` Settings must no longer carry `db_importance_method`, and every `MarketingReach` sheet must carry `SeenQuestionCode`, `BrandQuestionCode` and `MediaQuestionCode`.
- Rewrite `modules/brand/templates/README.md` to say what these files actually are, which is generator output. It currently claims they are copies of the IPK fixture, which is false.

### Stage A done means

Suite back at FAIL 0, PASS at or above 2399 with the A1 test updated, both changes committed on `feature/brand-v2-lift` with the co-author trailer, no merge, no push. Then stop and report. Duncan merges.

---

## Stage B: a new branch off main, after Duncan merges

Do not start Stage B until Duncan says the branch is merged. Branch off the new main.

Everything in Stage B is a defect that already exists on main. None of it was introduced by the v2 lift.

### B1. Root cause of the chart transform failure (F4)

`transform_brand_charts()` in `modules/brand/lib/html_report/01_data_transformer.R` fails on every IPK-shaped run with "missing value where TRUE/FALSE needed". Identical on main. The review made the failure visible (the generator now returns it in `$warnings` and `brand_gui_outcome()` folds it into a PARTIAL verdict) but did not fix the cause.

Find the NA comparison. Note that lines 455 to 510 of that file are where `dirichlet_norms` and `buyer_heaviness` are paired into panel data, with `dn_ok` and `bh_ok` guards. **Check whether the failing comparison is in that pairing block.** If it is, B1 and B2 are one defect and should be fixed as one.

Done means an IPK fixture run that ends PASS with no chart-transform warning, and a test that fails before the fix and passes after.

### B2. Wire up the Dirichlet renderers

Duncan's ruling: the omission is a refactor error and the renderers should be live.

Three finished renderers exist and nothing calls them, so the Dirichlet norms, the Double Jeopardy scatter and the expected-value KPI chips reach no visible surface in the HTML report. The values reach only the Excel `<CAT>_Dirichlet` sheet (`modules/brand/R/99_output.R:217`) and a dormant JSON island.

The uncalled renderers:

| Function | File | Renders |
|---|---|---|
| `.cb_kpi_strip()` | `panels/08_cat_buying_panel.R:1612` | KPI chips including observed SCR with an "exp NN%" sub-label |
| `cb_norms_table_html()` | `panels/08_cat_buying_panel_table.R:53` | Obs / Exp / Δ% grouped table across Penetration, Buy rate, SCR, 100% Loyals |
| `cb_dj_scatter_svg()` | `panels/08_cat_buying_panel_chart.R:68` | Double Jeopardy scatter with the Dirichlet expected curve, labelling off-line brands |
| `cb_scr_bars_svg()` | `panels/08_cat_buying_panel_chart.R:614` | SCR bars |

How the calls were lost: `b70ba905` (2026-04-21, "commit cat buyer updates") split the monolithic cat-buying panel into panel / chart / table / styling files. The definitions moved to the new files and the call sites were dropped in the move. That commit is an ancestor of the merge base `3f85abb3`, so this gap has been on main since April.

The original call sites, with their arguments and the sub-tab section each sat in:

```bash
git show b70ba905 -- modules/brand/lib/html_report/panels/08_cat_buying_panel.R
```

**Signatures have drifted since.** `.cb_kpi_strip()` gained a `rep` parameter, for one. Treat the old call sites as a guide to intent and placement, not as something to paste back.

What already works and must not be rebuilt:

- The engine emits everything needed. `dj_curve` comes out of `08c_dirichlet_norms.R:131`, and `norms_table` carries the Obs, Exp, Dev and `DJ_Flag` columns.
- The JS already hydrates `[data-kpi]` chips from the `cb-data-<cat>` JSON island on a focal-brand change: `js/brand_cat_buying_panel.js:1515` to `1563`. Once a strip with `data-kpi="scr"` and `data-kpi="loyal"` chips renders, the swap should work. Verify it rather than assuming it.
- `.cb_kpi_json_script()` (`08_cat_buying_panel.R:1744`) is already called at line 105 and already emits `scr_exp` and `loy_exp` per brand.

Placement is a judgement call. Say what you chose and why. The norms table and the scatter are Dirichlet diagnostics, so Category Buying is the panel; which sub-tab is yours to argue.

Done means: regenerate the IPK fixture through `run_brand()` and `generate_brand_html_report()`, then prove the surfaces are live in the generated HTML, not just present in the CSS. Specifically, `cb-norms-table` must appear as element markup and not only inside the `<style>` block, an "exp NN%" string must appear in visible page text outside the JSON island, and the DJ scatter must carry labels for the brands whose `DJ_Flag` is `over` or `under`. On the IPK fixture that is 11 on line, 3 over, 1 under, with CHK and HND among the over. Check in a browser as well as by grep. Never `preview_start` for brand work.

### B3. Panel binding flags survive a save (F13)

Panels mark themselves bound through `dataset`, so the flag serialises into a saved copy as a `data-*` attribute and the binder returns early on reopen, leaving handlers dead. Sites: `js/brand_audience_lens_panel.js:41` to `42` (`data-al-bound`, Audience Lens clear button and sub-tabs) and `js/brand_portfolio_panel.js:224` to `225` (`pfFpBound`, portfolio footprint controls). Pre-existing on main. Either bind on a JS-side flag that does not serialise, or clear the attributes before Save.

### B4. Escape the config interpolation (F14)

`lib/html_report/03_page_builder.R:998` to `1030` interpolates a section id and a colour from config into an inline script without escaping. Config-controlled, so low severity. Use the shared escape helper.

---

## Out of scope

- Em dashes across the brand report layer. There are a few hundred, most of them empty-cell placeholders. Duncan has parked this for a later cleanup pass. Do not fix them here beyond the no-new-em-dashes rule.
- The dead `cb_norms_table_html()` footer fragment and the inert funnel `base_note` / `significance_note` (F15) are tidy-up candidates, not this job, except where B2 makes the norms table live.
- Any change outside `modules/brand/` and `docs/v2_lift/`.

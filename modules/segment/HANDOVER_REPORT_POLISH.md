# HANDOVER — Segment Module: HTML Report Polish Fixes

**Date raised:** 2026-05-19
**Raised by:** Duncan / OML segmentation demo
**Branch to create:** `fix/segment-report-polish` (from `main`)
**Estimated effort:** ~3–4 hours including tests
**Severity:** Medium — labels work for tables but silently break in charts and executive summary text; table headers render in shouty uppercase that wasn't asked for and doesn't wrap. All four issues currently masked by a per-project HTML post-processor (`Demos/OML/polish_oml_report.R`) which should not be the long-term home for these fixes.

---

## TL;DR — what's broken

Four issues across two themes — label propagation and CSS:

1. **Labels sheet inside the main config workbook is documented but not wired.** Only `question_labels_file` works.
2. **Chart builder's labels guard uses the wrong type check** (`is.list(ql)`) and rejects the standard named-vector return type of `load_question_labels()`. Labels never apply to SVG charts.
3. **Executive-summary text generator doesn't accept a labels parameter** so its "top N differentiating variables" sentence emits raw column names.
4. **Table headers render in `text-transform: uppercase` and segment-name columns don't wrap.** Confirmed as never-wanted styling — strip the rule across the module and add wrap behaviour to segment-name header columns.

All four were discovered while building the OML PF segmentation demo (`Demos/OML/`). That demo currently uses a per-project HTML post-processor (`polish_oml_report.R`) to substitute friendly labels AND override the CSS — once these fixes land, the entire polish script can be retired.

---

## Reproduction case

```bash
# In an Rscript run from the Turas root (so renv hydrates):
Rscript "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/Demos/OML/run_oml_segmentation.R"

# Examine the generated report BEFORE running the polish step:
# Comment out the polish call in run_oml_segmentation.R, then:
grep -c "ATT_ADVISOR" "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/Demos/OML/output/segmentation/OML_seg_segmentation_report.html"
# Returns 4. Three of those are bugs (1 is an intentional sub-row annotation).
```

The data file's clustering columns are named `ATT_PLAN`, `ATT_ADVISOR`, etc. The config workbook has a `Labels` sheet mapping each to a friendly label ("Long-horizon planning", "Advisor trust", …). The Config sheet also has `question_labels_file = OML_Segmentation_Config.xlsx` (self-reference) so the labels load via `load_question_labels()`.

Expected: friendly labels appear everywhere in the HTML.
Actual: friendly labels appear in **table cells only**. Charts and exec-summary text show raw `ATT_*` names.

---

## Bug 1 — Labels sheet in main config workbook is not auto-loaded

**Location:** `modules/segment/R/01_config.R` → `read_segment_config()` (around lines 100–180)

**Documented behaviour:** `modules/segment/docs/06_TEMPLATE_REFERENCE.md` (the "Labels Sheet" section, ~line 118):

> This sheet provides the same functionality as the `question_labels_file` setting in the Config sheet. **If both are provided, the Labels sheet takes precedence.**

**Actual behaviour:** `read_segment_config()` auto-loads `Insights`, `About`, and `Slides` sheets from the main config workbook (each via its own `tryCatch(openxlsx::read.xlsx(config_file, sheet = "..."), ...)` block), but there is **no equivalent block for `Labels`**. The `question_labels_file` setting is the only path that reaches `load_question_labels()`.

**Fix:** Add a parallel loader for the Labels sheet inside `read_segment_config()`, immediately after the Insights/About/Slides loaders. Suggested code shape (verify exact column-name expectations against the existing label loader):

```r
# Load optional Labels sheet (variable -> human-readable label)
labels_from_sheet <- tryCatch({
  lbl <- openxlsx::read.xlsx(config_file, sheet = "Labels")
  if (!is.null(lbl) && nrow(lbl) > 0 && ncol(lbl) >= 2) {
    names(lbl)[1:2] <- c("variable", "label")
    lbl <- lbl[!is.na(lbl$variable) & !is.na(lbl$label), ]
    if (nrow(lbl) > 0) {
      vec <- as.character(lbl$label)
      names(vec) <- as.character(lbl$variable)
      cat(sprintf("  Loaded %d question labels from Labels sheet\n", length(vec)))
      vec
    } else NULL
  } else NULL
}, error = function(e) NULL)
```

Then later, where `config$question_labels` is resolved (around line 425–430), implement the documented precedence:

```r
# Order: Labels sheet (in-workbook) takes precedence over question_labels_file
if (!is.null(labels_from_sheet)) {
  config$question_labels <- labels_from_sheet
} else if (!is.null(question_labels_file) && nzchar(trimws(question_labels_file))) {
  config$question_labels <- load_question_labels(question_labels_file)
}
```

**Test:** Build a config workbook with a `Labels` sheet but **no** `question_labels_file` setting. Run segmentation. Assert `result$question_labels` (or equivalent) is populated and labels appear in the rendered HTML table.

---

## Bug 2 — Chart builder rejects named-vector labels

**Location:** `modules/segment/lib/html_report/05_chart_builder.R`

`load_question_labels()` returns a **named character vector** (see `modules/segment/R/01_config.R` lines 83–86). The chart builder, however, guards label resolution with `is.list(ql)`:

| Line | Snippet | Affected chart |
|---|---|---|
| 266 | `if (!is.null(ql) && is.list(ql)) {` | Variable-importance bar chart |
| 407 | `if (!is.null(ql) && is.list(ql)) {` | Profile heatmap |
| 1062 | `if (!is.null(ql) && is.list(ql)) {` | Golden-questions bar chart |

A named vector returns `FALSE` from `is.list()`. The guard fails, the fallback `labels <- vi$variable` (or equivalent) is used, and raw column names render in SVG.

Compare with the **table builder** (`02_table_builder.R:141`) which uses the correct idiom:

```r
if (!is.null(question_labels) && var_name %in% names(question_labels)) {
  display_label <- question_labels[var_name]
}
```

**Fix:** Change all three `is.list(ql)` checks to `length(ql) > 0` (or remove the `is.list` check entirely — `ql[[v]]` works on both named vectors and lists, so the type check adds nothing). Suggested:

```r
if (!is.null(ql) && length(ql) > 0) {
  labels <- vapply(labels, function(v) {
    lbl <- ql[[v]]
    if (!is.null(lbl) && nzchar(lbl)) lbl else v
  }, character(1), USE.NAMES = FALSE)
}
```

**Test:** Render variable importance + heatmap + golden questions with a populated `question_labels` named vector. Assert friendly labels appear in the generated SVG (`grep`-able).

**Watch for other sites:** `grep -n "is.list(ql)" modules/segment/lib/html_report/` should turn up every occurrence — fix them all in one pass.

---

## Bug 3 — Executive summary text emits raw column names

**Location:** `modules/segment/R/12_executive_summary.R` → `.summarize_differentiating_variables()` (around lines 228–271)

Current signature:

```r
.summarize_differentiating_variables <- function(profile_df, top_n = 3) {
  …
  var_parts <- paste0(top_vars, " (η²=", top_etas, ")")
  …
}
```

`top_vars` is `sorted$Variable` — raw column names. The function emits sentences like:

> The top 3 differentiating variables are: ATT_ADVISOR, ATT_DIGITAL, ATT_FEE.

**Fix:**

1. Add a `question_labels = NULL` parameter to `.summarize_differentiating_variables()`.
2. Resolve labels when building `var_parts`, matching the table-builder idiom:
   ```r
   if (!is.null(question_labels)) {
     top_vars <- vapply(top_vars, function(v) {
       if (v %in% names(question_labels)) question_labels[[v]] else v
     }, character(1), USE.NAMES = FALSE)
   }
   ```
3. Update the call site in `generate_segment_executive_summary()` (around line 82) to thread `config$question_labels` through:
   ```r
   diff_msg <- .summarize_differentiating_variables(
     profile_result$clustering_profile,
     top_n = 3,
     question_labels = config$question_labels
   )
   ```

**Cross-check `.generate_segment_descriptions()` in the same file** — it already accepts and uses `q_labels` (good). But verify the labels are reaching it correctly via the `config` argument once Bug 1 is fixed (it relies on `config$question_labels`).

**Test:** With labels loaded, render the executive summary and assert the "top differentiating variables" sentence shows friendly labels, not raw names. Easiest: snapshot the headline + key-findings strings in a testthat test.

---

## Bug 4 — Table headers are forced uppercase and segment-name columns don't wrap

**Confirmed by Duncan (2026-05-19):** "This will never be wanted as a design choice." Treat as a bug, not a style preference. Strip `text-transform: uppercase` everywhere in the segment HTML pipeline and add wrap behaviour to segment-name header columns.

### Part A — uppercase

**Location:** `modules/segment/lib/html_report/03a_page_styling.R`

Seven `text-transform: uppercase` rules to remove or change to `none`. Each is at a known line:

| Line | Class | Notes |
|---|---|---|
| 343 | `.seg-th` | Table headers — the primary offender (every table inherits this) |
| 422 | `.seg-badge` | Generic badge — used for diagnostic badges in validation/profile tables |
| 440 | `.seg-status-badge` | PASS/PARTIAL/REFUSED labels |
| 662 | `.seg-action-card-label` | Eyebrow labels on action cards ("STRENGTHS", "PAIN POINTS") |
| 712 | `.seg-fit-card-label` | Eyebrow on fit/quality cards |
| 934 | `.seg-pinned-card-label` | Eyebrow on pinned cards |

Also in `modules/segment/lib/html_report/07a_combined_builders.R:489` — equivalent rule in the multi-method comparison report.

Also in `modules/segment/lib/html_report/js/seg_pins_extras.js:218` — inline `style="text-transform:uppercase"` injected by JS for pinned panel labels. Remove the declaration from the string.

**Fix:** delete the `text-transform: uppercase;` declaration in each spot. Where letter-spacing is tuned to compensate for uppercase rendering (typically `0.3px`–`0.4px`), reduce it to `0.1px` or remove it.

### Part B — segment-name columns don't wrap

`.seg-th` already has `white-space: normal` (line 349) so wrapping is theoretically allowed, BUT segment-name columns auto-size to fit one line because there's no width constraint. Result: long names like "Self-Steering Optimisers" sprawl horizontally and push the table off-screen.

**Fix:** add a max-width and minimum cell sizing to numeric/segment header columns. Add to `.seg-th-num` (line 352) or introduce a dedicated class:

```css
.seg-th-num {
  text-align: center;
  max-width: 110px;
  min-width: 80px;
  word-wrap: break-word;
  overflow-wrap: anywhere;
  line-height: 1.25;
  padding: 10px 8px;
}
```

Tune the max-width to taste — 100–120 px tends to give a clean two-row wrap for two-to-three-word segment names. Verify across the profile table, vulnerability table, importance table, golden-questions table, and the multi-method comparison.

### Reproduction

```bash
Rscript "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/Demos/OML/run_oml_segmentation.R"
# Open the report and inspect the Segment Profiles table:
# Before fix: "WEALTH ARCHITECTS" / "SELF-STEERING OPTIMISERS" on one line each, no wrap, possibly truncated
# After fix: "Wealth Architects" / "Self-Steering Optimisers" wrapped onto two lines, mixed case
```

The OML polish script's CSS override block (`Demos/OML/polish_oml_report.R`, the `<style id="oml-polish-overrides">` injection) is a working reference implementation — use its selectors as a starting point.

### Watch for

- Any tests that assert literal uppercase text in rendered HTML — e.g. `expect_match(html, "EXECUTIVE SUMMARY")`. Update those to mixed case.
- Snapshot tests of the HTML report — they will diff; regenerate after manual review.
- The Excel exporter does NOT use these CSS rules (Excel cell formatting is independent), so no risk there.

---

## Branch + workflow

```bash
git checkout main
git pull
git checkout -b fix/segment-report-polish
```

Commit individually for traceability:
- `fix(segment): load Labels sheet from main config workbook`
- `fix(segment): chart builder accepts named-vector labels`
- `fix(segment): executive summary resolves question labels`
- `fix(segment): drop uppercase from HTML report styling`
- `fix(segment): wrap segment-name columns in profile and related tables`
- `test(segment): label propagation across tables, charts, and exec summary`

Run before PR:
```r
testthat::test_dir("modules/segment/tests/testthat")
```

And re-run the OML demo end-to-end as the integration test — `grep -c "ATT_" report.html` should return 0 (or just the intentional sub-row annotation count, whatever that is):

```bash
Rscript "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/Demos/OML/run_oml_segmentation.R"
grep -c "ATT_" "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/Demos/OML/output/segmentation/OML_seg_segmentation_report.html"
```

Once all four fixes land, **the entire `Demos/OML/polish_oml_report.R` script can be deleted** and the `source(polish_script)` call removed from `Demos/OML/run_oml_segmentation.R`. The post-processing only exists because the module surfaces these gaps.

---

## Definition of done

- [ ] Bug 1 fixed: Labels sheet inside main config workbook auto-loads, with documented precedence over `question_labels_file`
- [ ] Bug 2 fixed: chart builder applies labels to all three affected SVG charts
- [ ] Bug 3 fixed: executive summary text uses friendly labels
- [ ] Bug 4a fixed: no `text-transform: uppercase` anywhere in segment HTML CSS or inline JS-emitted styles
- [ ] Bug 4b fixed: segment-name header columns wrap on up to ~2 rows with sensible width across all five table types (profile, vulnerability, importance, golden questions, multi-method comparison)
- [ ] New tests added covering each surface (table, chart, exec summary, CSS rule absence)
- [ ] Existing segment tests still pass
- [ ] OML demo re-runs and shows zero raw `ATT_*` in the HTML (without `polish_oml_report.R` label substitution)
- [ ] OML demo re-runs and renders all table headers in mixed case with segment names wrapping (without `polish_oml_report.R` CSS overrides)
- [ ] `Demos/OML/polish_oml_report.R` deleted; `run_oml_segmentation.R` updated
- [ ] No regressions for configs that use `question_labels_file` alone (no Labels sheet)
- [ ] No regressions for configs with neither Labels sheet nor `question_labels_file` (raw names should still render gracefully)
- [ ] PR description references this handover note

---

## Files likely to change

| File | Change |
|---|---|
| `modules/segment/R/01_config.R` | Add Labels-sheet loader; implement precedence |
| `modules/segment/lib/html_report/05_chart_builder.R` | Replace `is.list(ql)` with `length(ql) > 0` in 3 places (lines 266, 407, 1062) |
| `modules/segment/R/12_executive_summary.R` | Add `question_labels` param to `.summarize_differentiating_variables()` and thread it from `generate_segment_executive_summary()` |
| `modules/segment/lib/html_report/03a_page_styling.R` | Remove 6 `text-transform: uppercase` rules (lines 343, 422, 440, 662, 712, 934); add wrap behaviour to `.seg-th-num` (line 352) |
| `modules/segment/lib/html_report/07a_combined_builders.R` | Remove `text-transform: uppercase` at line 489 |
| `modules/segment/lib/html_report/js/seg_pins_extras.js` | Remove inline `text-transform:uppercase` at line 218 |
| `modules/segment/tests/testthat/test_*` | New tests |
| `modules/segment/docs/06_TEMPLATE_REFERENCE.md` | Documentation may already be correct — verify and update only if precedence semantics changed |
| `Demos/OML/polish_oml_report.R` | **Delete** once all four bugs are fixed |
| `Demos/OML/run_oml_segmentation.R` | Remove the polish-script `source()` call |

---

## Reference: where labels currently flow correctly

For your own reference when implementing — these paths already work and can be used as the idiom to copy:

- `modules/segment/lib/html_report/02_table_builder.R:141` — table cell labels, uses `%in% names(question_labels)` ✓
- `modules/segment/lib/html_report/01_data_transformer.R:104,169` — passes labels into `html_data$question_labels` ✓
- `modules/segment/R/12_executive_summary.R::.generate_segment_descriptions()` — already accepts and uses `q_labels` ✓

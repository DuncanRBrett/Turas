# Grid Question Support — Development Spec

**Version:** 0.1 (deferred stream) **Module:** `modules/tabs` **Status:** Design captured; implementation deferred. Not scheduled.

------------------------------------------------------------------------

## 1. Context

Tabs' validator already declares `Grid_Single` and `Grid_Multi` as accepted `Variable_Type` values (`modules/tabs/lib/validation/structure_validators.R:113`, `data_validators.R:166`), but no downstream code processes them. They are paper types today — declared valid, never rendered or crosstabbed.

This spec defines what "first-class grid support" means, so when the first paying consumer needs it (likely brand Mental Availability or a brand × attribute tracking grid) it can be built against a fixed design rather than invented under pressure.

------------------------------------------------------------------------

## 2. Why grids matter

Grids appear constantly in research and currently force consumers to either:

-   Declare N separate Multi_Mentions / Single_Responses in QuestionMap (bloats the sheet, fragments output), or
-   Render bespoke matrix views inside each consuming module (duplicated effort across brand, tracker, etc.).

Known consumers (current or imminent):

| Consumer | Grid shape | Type |
|----|----|----|
| Brand MA — CEP × brand matrix | `brand_matrix` | Grid_Multi |
| Brand D&B — statement × brand ratings | `brand_matrix` | Grid_Single |
| Brand equity — BHI statements × brand | `brand_matrix` | Grid_Single |
| Ad diagnostics — statement × ad exposure | `statement_matrix` | Grid_Single |
| Tracker — standard brand attribute grid | `brand_matrix` | Grid_Single |

Out of scope for this spec (stay bespoke): Conjoint, MaxDiff, Segment clustering inputs, Keydriver / Catdriver feature matrices. Their compute semantics differ; they borrow grid *inputs* but not grid *outputs*.

------------------------------------------------------------------------

## 3. Data shape

### 3.1 Export convention

-   One row per respondent (standard Alchemer / Qualtrics shape).
-   One column per **cell** — a grid of *R* rows × *C* columns produces *R* × *C* columns in the data.
-   `Grid_Single`: each cell holds an integer or string code. Maps to an OptionMap scale (shared across all cells in the grid — single scale per grid).
-   `Grid_Multi`: each cell holds 0/1/NA.

### 3.2 ColumnPattern

QuestionMap declares the pattern explicitly:

-   `{code}_{row_code}_{col_code}` — most common (e.g. `q10_cep01_brandA`)
-   `{code}_r{row_index}c{col_index}` — numeric indices
-   Custom patterns supported via literal template matching; guard refuses loud on mismatch (`CFG_PATTERN_MISMATCH`).

### 3.3 Dimension lists

Grid rows and columns resolve against **named lists** stored in Survey_Structure. A grid declares two list references:

-   `Grid_Row_List` — name of a list sheet (e.g. `CEPs`, `Statements`). Provides row codes, labels, display order.
-   `Grid_Col_List` — name of a list sheet (e.g. `Brands`, `Ads`). Provides column codes, labels, display order.

Reusing existing list sheets (`Brands`, `CEPs`, `Assets`, `Categories`) means no new sheet types for most grids — a CEP × brand matrix points `Grid_Row_List = CEPs`, `Grid_Col_List = Brands`.

------------------------------------------------------------------------

## 4. QuestionMap schema additions

Two new columns on the Questions sheet (nullable for non-grid rows):

| Column | Purpose |
|----|----|
| `Grid_Row_List` | Name of Survey_Structure list sheet providing row codes / labels / order |
| `Grid_Col_List` | Name of Survey_Structure list sheet providing column codes / labels / order |

`OptionMapScale` continues to carry the cell scale name for `Grid_Single` (and Likert/Rating grids). Blank for `Grid_Multi`.

One QuestionMap row per grid — not per cell.

------------------------------------------------------------------------

## 5. Compute layer

### 5.1 Cell metrics

Each cell computed as a standard proportion / mean / rating:

-   `Grid_Multi` cell → % of respondents selecting this cell, with cell-specific base.
-   `Grid_Single` cell → count distribution across OptionMap positions, top-box / mean / NPS-style summaries per config.
-   Weighted and unweighted throughout.

### 5.2 Bases

-   **Row base** — respondents answering anywhere in the row (any non-NA cell). Default for row-normalised views.
-   **Column base** — respondents answering anywhere in the column. Default for column-normalised views.
-   **Cell base** — respondents with a valid cell value. Used for cell-level low-base flags.
-   **Filter base** — optional filter applied across all cells identically (e.g. aware of brand).

Low-base warn/suppress inherits tabs defaults (`warn_base = 30`, `suppress_base = 0`) unless overridden in the grid's config.

### 5.3 Significance

-   Cell vs row average (within-row comparison)
-   Cell vs column average (within-column comparison)
-   Cell vs overall grid average
-   Optional focal-cell mode (one cell flagged; rest compared to it) for reports with a designated benchmark

Reuses the existing `significance.R` two-proportion / t-test primitives. No new stats.

### 5.4 Crosstab by segment

Grid × segment produces a *third* dimension. Output structures must support it — flatten to long format on export; render as small multiples (one grid per segment) in the report layer.

------------------------------------------------------------------------

## 6. Render layer

### 6.1 Primary view — heatmap table

Rows × columns matrix, cells coloured by value with significance markers:

-   Sequential single-hue ramp by default (configurable).
-   Significance indicators: up/down arrow or letter code per tabs convention.
-   Clickable cells link to the underlying crosstab (cell × segment breakout).
-   Row totals and column totals in margin cells where meaningful.

### 6.2 Alternate — ordered dot grid

Particularly useful for `Grid_Multi` with many columns — each row plotted as a dot strip across columns, sized or coloured by value. Good for visual scan of "which brand owns each CEP".

### 6.3 Alternate — small multiples

One mini-chart per row, columns as bars. Good for 5–10 row grids.

### 6.4 Sort modes

Configurable:

-   `default` — declared display order from list sheets
-   `by_row_total_desc` — rows sorted by row mean / sum
-   `by_col_total_desc` — columns sorted similarly
-   `by_focal_col_desc` — rows sorted by the focal column (e.g. IPK)

### 6.5 Show-counts toggle

Same `show-freq` pattern as standard tabs reports. Cell renders `pct` above `N` when enabled.

------------------------------------------------------------------------

## 7. Excel / CSV outputs

### 7.1 Excel

One sheet per grid: rows × columns matrix with conditional cell formatting matching the heatmap. Metadata sheet carries question text, bases, sig method.

### 7.2 CSV

Long format, one row per cell × segment × wave:

```
grid_code, row_code, row_label, col_code, col_label, segment_code, wave,
pct_weighted, pct_unweighted, base_cell, base_row, base_col,
sig_vs_row, sig_vs_col, sig_vs_grid, warning_flag
```

Tracker concatenates across waves; onward analysis (R, Python, Tableau) consumes directly.

------------------------------------------------------------------------

## 8. Config additions

Tabs Settings sheet:

| Setting | Type | Default | Notes |
|----|----|----|----|
| `grid.default_view` | enum | `heatmap` | `heatmap` / `dot_grid` / `small_multiples` |
| `grid.sort_mode` | enum | `default` | see §6.4 |
| `grid.significance_scope` | enum | `vs_row` | `vs_row` / `vs_col` / `vs_grid` / `focal_cell` |
| `grid.warn_base` | integer | 30 | cell-level base threshold |
| `grid.suppress_base` | integer | 0 | cell-level suppression; 0 = never |
| `grid.show_row_totals` | logical | TRUE | render row margin |
| `grid.show_col_totals` | logical | FALSE | render column margin |

Per-grid overrides via a new `GridConfig` sheet keyed on grid code (optional; Settings defaults apply otherwise).

------------------------------------------------------------------------

## 9. Migration — brand MA as first consumer

When this work lands, brand Mental Availability migrates from its bespoke CEP × brand matrix renderer to the tabs grid engine:

-   MA panel calls `tabs::run_grid(grid_code = "ma.cep_matrix", …)` instead of rolling its own
-   Panel builder consumes the standard grid output contract rather than a brand-specific shape
-   Brand MA's About drawer still owns MA-specific methodology text; only the rendering switches

Brand D&B follows the same pattern for statement × brand performance grids.

Modules that stay bespoke (Conjoint, MaxDiff, Keydriver, Catdriver) are unaffected — their grid-shaped inputs remain module-internal.

------------------------------------------------------------------------

## 10. Test plan

### 10.1 Known-answer fixtures

-   **Grid_Single fixture** — 10 respondents × 3 rows × 3 columns with a 5-point OptionMap scale. Hand-calculated means, top-box, sig flags.
-   **Grid_Multi fixture** — 10 respondents × 3 rows × 3 columns binary. Hand-calculated % per cell and row/col totals.
-   **Sparse grid fixture** — one row with no responses, one column with all zeros. Validates zero-base handling.

### 10.2 Edge cases

-   Single-row grid → render as a single horizontal strip.
-   Single-column grid → render as a vertical bar.
-   Inverted OptionMap (code 1 = worst, 5 = best) remaps correctly.
-   Missing dimension list → guard refuses `CFG_GRID_LIST_MISSING`.
-   Cell pattern resolves to a non-existent column → `CFG_PATTERN_MISMATCH`.
-   Weighted parity — weights all equal 1 produce unweighted-identical output.

### 10.3 Integration

-   Brand MA migrated fixture runs through the grid engine and produces the same CEP × brand numbers as today's bespoke code (golden-file parity).
-   Cross-segment grid (grid × 3 segments) produces correct small-multiples output.

------------------------------------------------------------------------

## 11. Out of scope

-   **Ranking grids.** Different computation (rank distribution per cell); separate spec if needed.
-   **Dynamic grids.** Per-respondent row skip logic (e.g. "only rate brands you know"). Needs respondent-specific row resolution; parked.
-   **Free-text grids.** A grid of open-ended cells. Coded themes should be promoted to a standard `Grid_Multi` of theme × row; raw text stays in verbatim exports.
-   **Cross-grid comparisons.** E.g. compare one grid's cells to another grid's cells. Out of scope; users can export long CSVs and join externally.
-   **Interactive pivot / re-orient in the report.** Users pick the view at config time; panel renders one view per grid instance. Multi-view interactive pivoting is a v2 concern.

------------------------------------------------------------------------

## 12. Pre-build checklist

Before scheduling this work:

-   [ ] Confirm consumer list in §2 is still accurate — any other modules planning grid-shaped outputs by the time this builds?
-   [ ] Confirm `Grid_Row_List` / `Grid_Col_List` schema addition (§4) — naming and referenced-list approach.
-   [ ] Confirm render view set (§6) — heatmap primary, dot grid + small multiples alternates. Any others?
-   [ ] Confirm significance scope options (§5.3, §8) — vs_row / vs_col / vs_grid / focal_cell covers real use cases.
-   [ ] Confirm migration sequence (§9) — brand MA first, then brand D&B. Any earlier consumer?
-   [ ] Confirm "deferred bespoke" list (§11, §2 out-of-scope) — still accurate.

------------------------------------------------------------------------

## 13. Interim behaviour (until this lands)

-   Tabs validator **continues** to accept `Grid_Single` / `Grid_Multi` in the whitelist. Do not remove them — when Duncan next sees a project with a grid, it should not refuse at validation.
-   Consumer modules needing grid data today declare the cells as the most appropriate non-grid type (compound Multi_Mention with `brand_matrix` cardinality) and render matrix views inside their own panels — as brand MA does today.
-   This document is the reference when the first paying consumer requests native grid output. Update it when that happens; then schedule.

------------------------------------------------------------------------

**End of Grid Support Spec v0.1.**

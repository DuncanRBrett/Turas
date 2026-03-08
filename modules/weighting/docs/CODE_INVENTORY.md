# Weighting Module -- Code Inventory

## Module Overview

The Turas Weighting module provides production-ready sample weighting for survey data. It supports three weighting methods: **Design weights** (stratified sampling with population proportions), **Rim/raking weights** (iterative proportional fitting via `survey::calibrate`), and **Cell/interlocked weights** (joint distribution matching). The module features weight trimming and capping, comprehensive diagnostics (design effect, statistical efficiency), and multiple output formats including formatted Excel workbooks, CSV, and self-contained HTML reports. All parameters are driven by an Excel configuration file with structured sheets for targets, variable mappings, and advanced options.

**Quality Score:** 85/100 (Production)

------------------------------------------------------------------------

## Summary Statistics

| Metric                 | Value                 |
|------------------------|-----------------------|
| Total R Lines          | \~8,679               |
| Total JS Lines         | 64                    |
| Total Lines (all code) | \~8,743               |
| R Source Files         | 21                    |
| JS Source Files        | 1                     |
| Root Entry Points      | 2                     |
| Core Library Files     | 10                    |
| Validation Files       | 1                     |
| HTML Report Files      | 6                     |
| Weighting Methods      | 3 (Design, Rim, Cell) |
| Output Formats         | 3 (Excel, CSV, HTML)  |

------------------------------------------------------------------------

## Detailed File Inventory

### Root Entry Points

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `run_weighting.R` | 757 | Main orchestration script; provides both CLI and programmatic API interface for running the weighting pipeline end-to-end | 88/100 | Coordinates guard, config loading, validation, calculation, trimming, diagnostics, and output stages |
| `run_weighting_gui.R` | 750 | Shiny GUI with reactive UI elements, file browser for config/data selection, real-time progress tracking, and parameter overrides | 85/100 | Integrates with `launch_turas.R`; handles all user-facing interaction for the weighting workflow |

### Core Library (`lib/`)

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `00_guard.R` | 261 | TRS guard layer; validates config and data file paths, checks required Excel sheet presence, enforces parameter constraints | 93/100 | First line of defence; returns structured TRS refusals with actionable fix instructions |
| `config_loader.R` | 725 | Excel configuration parser; reads and validates General, Weights, Targets, and Advanced sheets from the config workbook | 88/100 | Comprehensive handling of multiple sheet types; translates Excel structure into internal config list |
| `validation.R` | 410 | Data validation layer; performs type checks, completeness verification, NA detection, and column existence checks against config | 90/100 | Runs after config loading but before calculation; catches data-config mismatches early |
| `design_weights.R` | 362 | Design weight calculator; computes weights from stratified sampling with known population proportions | 90/100 | Well-tested statistical method; handles single and multi-variable stratification |
| `rim_weights.R` | 655 | Rim/raking weight calculator using `survey::calibrate` for iterative proportional fitting (IPF) | 92/100 | Leverages the `survey` package for robust calibration; handles convergence monitoring and failure reporting |
| `cell_weights.R` | 437 | Cell/interlocked weight calculator; matches joint distributions across multiple variables simultaneously | 88/100 | Handles cross-tabulated target distributions; validates cell counts before calculation |
| `trimming.R` | 386 | Weight trimming and capping; supports cap method (hard limits), percentile method, and post-trim rescaling to preserve totals | 90/100 | Applies after weight calculation; ensures weights stay within acceptable bounds |
| `diagnostics.R` | 498 | Quality diagnostics engine; computes design effect (DEFF), statistical efficiency, weight distribution statistics, and convergence metrics | 90/100 | Critical for assessing weighting quality; results feed into both Excel and HTML outputs |
| `output.R` | 820 | Excel and CSV output generator; produces formatted workbooks with data sheets, weight columns, and diagnostics summary sheet | 85/100 | Largest core file; handles workbook styling, conditional formatting, and multi-sheet layout |
| `generate_config_templates.R` | 662 | Professional Excel template generator; creates pre-formatted config workbooks using shared Turas template infrastructure | 90/100 | Uses shared infrastructure for consistent template style across modules |

### Validation (`lib/validation/`)

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `preflight_validators.R` | 960 | Suite of 14 cross-referential pre-flight checks; validates target consistency, variable availability, population total alignment, and logical constraints before any calculation begins | 95/100 | Most thorough validation file in the module; catches subtle config errors that would cause misleading results |

### HTML Report (`lib/html_report/`)

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `00_html_guard.R` | 37 | Input validation for HTML report generation; checks that weighting results and config are present and well-formed | 85/100 | Lightweight guard; delegates detailed validation to upstream stages |
| `01_data_transformer.R` | 95 | Transforms weighting results into the structure expected by table and chart builders | 85/100 | Adapter layer between calculation output and report rendering |
| `02_table_builder.R` | 231 | HTML table generation; builds weight summary tables, diagnostics tables, and target-vs-achieved comparison tables | 86/100 | Produces clean, readable HTML tables with consistent styling |
| `03_page_builder.R` | 1,044 | Page template assembly; CSS stylesheet, section layout, responsive design, header/footer, and full page composition | 82/100 | Largest HTML report file; embeds CSS and page structure; could benefit from further modularisation |
| `04_html_writer.R` | 99 | Writes assembled HTML to disk as a self-contained file; handles file path resolution and overwrite logic | 88/100 | Simple and reliable; ensures output is a single portable HTML file |
| `05_chart_builder.R` | 145 | SVG chart generation; produces weight distribution histograms and efficiency gauge charts | 85/100 | Inline SVG for portability; charts are static (no JS interaction required) |
| `99_html_report_main.R` | 295 | HTML report orchestrator; coordinates guard, transform, table build, chart build, page assembly, and file writing | 88/100 | Follows standard Turas `99_*` orchestration pattern |

### JavaScript (`lib/html_report/js/`)

| File | Lines | Purpose | Quality | Notes |
|----|---:|----|---:|----|
| `weighting_navigation.js` | 64 | Client-side tab switching for multi-section HTML reports and save-to-file functionality | 82/100 | Minimal JS footprint; vanilla JavaScript with no external dependencies |

------------------------------------------------------------------------

## Architecture Diagram

```         
                         TURAS WEIGHTING MODULE
  ======================================================================

  +-----------------------+     +-----------------------+
  |   run_weighting.R     |     |  run_weighting_gui.R  |
  |  (CLI / API entry)    |     |  (Shiny GUI entry)    |
  +-----------+-----------+     +-----------+-----------+
              |                             |
              +-------------+---------------+
                            |
                            v
              +-------------+--------------+
              |        00_guard.R          |
              |  TRS input validation      |
              +-------------+--------------+
                            |
                            v
              +-------------+--------------+
              |      config_loader.R       |
              |  Parse Excel config        |
              |  (General, Weights,        |
              |   Targets, Advanced)       |
              +-------------+--------------+
                            |
                            v
              +-------------+--------------+
              |       validation.R         |
              |  Data type & completeness  |
              +-------------+--------------+
                            |
                            v
              +-------------+--------------+
              |  preflight_validators.R    |
              |  14 cross-referential      |
              |  pre-flight checks         |
              +-------------+--------------+
                            |
                            v
          +-----------------+-----------------+
          |                 |                 |
          v                 v                 v
  +-------+------+  +------+-------+  +------+-------+
  | design_      |  | rim_         |  | cell_        |
  | weights.R    |  | weights.R    |  | weights.R    |
  | (stratified) |  | (IPF/raking) |  | (interlocked)|
  +--------------+  +--------------+  +--------------+
          |                 |                 |
          +-----------------+-----------------+
                            |
                            v
              +-------------+--------------+
              |        trimming.R          |
              |  Cap / percentile / rescale|
              +-------------+--------------+
                            |
                            v
              +-------------+--------------+
              |      diagnostics.R         |
              |  DEFF, efficiency, stats   |
              +-------------+--------------+
                            |
                +-----------+-----------+
                |                       |
                v                       v
  +-------------+----------+  +--------+-----------+
  |       output.R         |  | 99_html_report_    |
  |  Excel / CSV export    |  |    main.R          |
  |  Formatted workbook    |  | HTML report        |
  |  with diagnostics      |  | orchestrator       |
  +------------------------+  +--------+-----------+
                                       |
                     +-----------+-----+-----+-----------+
                     |           |           |           |
                     v           v           v           v
              +------+--+ +-----+----+ +----+-----+ +---+------+
              |00_html  | |01_data   | |02_table  | |05_chart  |
              |guard.R  | |transform | |builder.R | |builder.R |
              +---------+ +----------+ +----------+ +----------+
                                                         |
                                              +----------+
                                              v
                                       +------+-------+
                                       |03_page      |
                                       |builder.R    |
                                       |CSS + layout |
                                       +------+------+
                                              |
                                              v
                                       +------+-------+
                                       |04_html      |
                                       |writer.R     |
                                       |Write to disk|
                                       +--------------+

  ======================================================================
   Config (Excel) --> Guard --> Config Loader --> Validation -->
   Preflight --> Calculator (design|rim|cell) --> Trimming -->
   Diagnostics --> Output (Excel/CSV + HTML Report)
  ======================================================================
```

------------------------------------------------------------------------

## Quality Scoring Criteria

Quality scores are assigned on a 0--100 scale based on six dimensions. Each file is evaluated against the criteria below, and the overall score reflects a weighted combination favouring correctness and maintainability.

| Criterion | Weight | Description |
|----|---:|----|
| **Correctness** | 25% | Statistical accuracy, algorithmic soundness, absence of known bugs. Does the code produce correct results under all tested conditions? |
| **TRS Compliance** | 20% | Adherence to the Turas Refusal System. Are all failure modes handled with structured refusals rather than `stop()` or silent failures? Are error messages specific, actionable, and console-visible? |
| **Test Coverage** | 15% | Extent of automated test coverage. Are happy paths, edge cases, error conditions, and boundary values all tested? |
| **Code Structure** | 15% | Single responsibility, function length (target \< 100 lines), logical organisation, separation of concerns. Does the file follow the standard module pattern? |
| **Documentation** | 15% | Roxygen2 headers, inline comments for non-obvious logic, clear parameter descriptions, return value documentation. |
| **Maintainability** | 10% | Readability, consistent naming, absence of hardcoded values, ease of modification. Could another developer understand and modify this code without extensive guidance? |

### Score Bands

| Range | Rating | Meaning |
|----|----|----|
| 95--100 | Exceptional | Production-hardened, comprehensive tests, exemplary documentation |
| 90--94 | Excellent | Robust, well-tested, minor improvements possible |
| 85--89 | Good | Production-ready, some areas could be strengthened |
| 80--84 | Adequate | Functional and reliable, but notable gaps in testing or documentation |
| 70--79 | Needs Work | Functional but requires attention before production hardening |
| \< 70 | At Risk | Significant issues that should be addressed before relying on this code |

### Module-Level Observations

-   **Guard and validation files (90--95):** These are the strongest components. The preflight validator at 95/100 is the highest-scoring file, reflecting its thoroughness in catching subtle configuration errors before they propagate.
-   **Core calculation files (88--92):** The statistical engines are well-implemented and benefit from leveraging established R packages (`survey::calibrate` for rim weighting). `rim_weights.R` scores highest at 92/100 due to its robust convergence handling.
-   **Config loader (88):** Comprehensive parsing of four Excel sheet types. Complexity is inherent to the task but the file remains well-organised.
-   **Output (85):** The largest core file at 820 lines. Functional and reliable, but its size suggests it could benefit from decomposition into smaller, focused output helpers.
-   **HTML report (82--88):** Functional with clean output. The page builder at 82/100 is the lowest-scoring HTML file due to its size (1,044 lines) and the amount of embedded CSS. The orchestrator and writer score well.
-   **Template generator (90):** Clean integration with the shared Turas template infrastructure; generates professional, consistent configuration templates.

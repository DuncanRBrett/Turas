# Turas Confidence Module -- Code Inventory

## Module Overview

Turas Confidence calculates confidence intervals for survey data using multiple
statistical methods. It supports four CI methods for proportions (Wilson, Margin
of Error, Bootstrap, Bayesian) and three for means (t-based, Bootstrap, Bayesian
Credible). Features include study-level diagnostics (DEFF, effective sample size,
representativeness), weighted data support, NPS analysis, and both Excel and
interactive HTML report output. All parameters are driven by Excel configuration.

---

## Summary Statistics

| Metric                        | Value       |
|-------------------------------|-------------|
| Total R source lines          | ~11,681     |
| Total JS source lines         | 71          |
| Total source lines (all)      | ~11,752     |
| R source files                | 24          |
| JS source files               | 1           |
| Total source files            | 25          |
| CI methods (proportions)      | 4           |
| CI methods (means)            | 3           |
| Preflight validation checks   | 13          |
| Output formats                | 2 (Excel, HTML) |
| Average quality score         | ~89/100     |

---

## Detailed File Inventory

### Root Entry Point

| File                   | Lines | Purpose                          | Quality | Notes                                         |
|------------------------|------:|----------------------------------|--------:|-----------------------------------------------|
| `run_confidence_gui.R` |   496 | Shiny GUI interface              |      85 | Launches interactive front-end for the module  |

### Core Analysis Pipeline (`R/`)

| File                    | Lines | Purpose                                               | Quality | Notes                                                        |
|-------------------------|------:|-------------------------------------------------------|--------:|--------------------------------------------------------------|
| `00_guard.R`            |   619 | TRS v1.0 guard layer, input validation                |      92 | Comprehensive parameter and data validation; TRS compliant   |
| `00_main.R`             | 1,077 | Main orchestration, coordinates full analysis pipeline|      90 | Central coordinator; dispatches to all pipeline stages       |
| `01_load_config.R`      |   925 | Config loading and validation from Excel              |      88 | Handles multiple config formats; validates structure          |
| `02_load_data.R`        |   503 | Survey data file I/O (CSV/XLSX)                       |      85 | Reads CSV and Excel inputs; basic data integrity checks      |
| `03_study_level.R`      |   703 | Study-level statistics (DEFF, n_eff, representativeness)|    95 | Mathematically rigorous; design effect and weighting stats   |
| `04_proportions.R`      |   669 | Proportion CI methods (Wilson, MOE, Bootstrap, Bayesian)|    94 | Four validated methods; handles edge cases well              |
| `05_means.R`            |   751 | Mean CI methods (t-based, Bootstrap, Bayesian Credible)|     93 | Three validated methods; weighted and unweighted support     |
| `07_output.R`           | 1,588 | Excel workbook generation with formatting             |      82 | Largest file in module; functional but could benefit from decomposition |
| `ci_dispatcher.R`       |   393 | CI method routing/dispatch logic                      |      92 | Clean routing; maps config to correct CI function            |
| `output_helpers.R`      |   399 | Output formatting utilities                           |      85 | Formatting and presentation helpers for Excel output         |
| `question_processor.R`  |   473 | Question data extraction and validation               |      88 | Extracts question-level data from survey frames              |
| `utils.R`               |   588 | Shared validation and utility functions               |      87 | Cross-cutting helpers used throughout the pipeline           |

### Config Template Generator (`lib/`)

| File                          | Lines | Purpose                                    | Quality | Notes                                                  |
|-------------------------------|------:|--------------------------------------------|--------:|--------------------------------------------------------|
| `generate_config_templates.R` |   677 | Professional Excel config template generation |    85 | Generates starter config workbooks with instructions   |

### Validation (`lib/validation/`)

| File                       | Lines | Purpose                                       | Quality | Notes                                                    |
|----------------------------|------:|-----------------------------------------------|--------:|----------------------------------------------------------|
| `preflight_validators.R`   |   972 | Pre-flight cross-reference validators (13 checks) | 90 | Validates config-to-data consistency before analysis runs |

### HTML Report (`lib/html_report/`)

| File                     | Lines | Purpose                                     | Quality | Notes                                                    |
|--------------------------|------:|---------------------------------------------|--------:|----------------------------------------------------------|
| `00_html_guard.R`        |    56 | Input validation for HTML report            |      85 | Lightweight guard; validates HTML generation inputs      |
| `01_data_transformer.R`  |   632 | Data transformation for HTML rendering      |      88 | Reshapes CI results into HTML-ready structures           |
| `02_table_builder.R`     |   438 | HTML table generation from CI results       |      87 | Builds formatted HTML tables with CI data                |
| `03_page_builder.R`      |   942 | HTML page assembly with navigation          |      88 | Full page layout, CSS, and interactive navigation        |
| `04_html_writer.R`       |    63 | File I/O for HTML output                    |      85 | Writes assembled HTML to disk                            |
| `05_chart_builder.R`     |   336 | SVG confidence interval chart generation    |      87 | Inline SVG charts following Turas visual style           |
| `99_html_report_main.R`  |   310 | HTML orchestration coordinator              |      88 | Coordinates the HTML report sub-pipeline                 |

### JavaScript (`lib/html_report/js/`)

| File                        | Lines | Purpose                                    | Quality | Notes                                         |
|-----------------------------|------:|--------------------------------------------|--------:|-----------------------------------------------|
| `confidence_navigation.js`  |    71 | Interactive HTML navigation and saving     |      85 | Client-side navigation for multi-section reports |

---

## Architecture Diagram

```
                         +---------------------------+
                         |   Excel Config Workbook   |
                         +-------------+-------------+
                                       |
                                       v
                         +---------------------------+
                         |   run_confidence_gui.R    |
                         |      (Shiny GUI)          |
                         +-------------+-------------+
                                       |
                                       v
                   +--------------------------------------+
                   |          00_guard.R                   |
                   |   TRS v1.0 Input Validation Layer    |
                   +------------------+-------------------+
                                      |
                          +-----------+-----------+
                          |                       |
                          v                       v
              +-----------------+     +--------------------+
              | 01_load_config  |     | preflight_         |
              |   .R            |     | validators.R       |
              | (Config Load)   |     | (13 Cross-Ref      |
              +---------+-------+     |  Checks)           |
                        |             +--------------------+
                        v
              +-----------------+
              | 02_load_data.R  |
              | (Survey Data    |
              |  File I/O)      |
              +---------+-------+
                        |
                        v
              +-----------------+
              | 03_study_level  |
              |   .R            |
              | (DEFF, n_eff,   |
              |  Representat.)  |
              +---------+-------+
                        |
                        v
              +-----------------+
              | ci_dispatcher.R |
              | (Method Router) |
              +--------+--------+
                       |
            +----------+----------+
            |                     |
            v                     v
  +-------------------+  +-------------------+
  | 04_proportions.R  |  |   05_means.R      |
  | - Wilson          |  | - t-based         |
  | - MOE             |  | - Bootstrap       |
  | - Bootstrap       |  | - Bayesian        |
  | - Bayesian        |  |   Credible        |
  +--------+----------+  +--------+----------+
           |                       |
           +----------+----------+
                      |
         +------------+------------+
         |                         |
         v                         v
  +---------------+     +----------------------+
  |  07_output.R  |     | 99_html_report_main  |
  | (Excel Report)|     |   .R                 |
  +---------------+     +----------+-----------+
                                   |
                    +--------------+--------------+
                    |              |               |
                    v              v               v
           +------------+  +------------+  +------------+
           | 01_data_   |  | 02_table_  |  | 05_chart_  |
           | transformer|  | builder.R  |  | builder.R  |
           | .R         |  +------+-----+  +------+-----+
           +------+-----+        |               |
                  |               +-------+-------+
                  v                       v
           +------------+         +------------+
           | 03_page_   |         | 04_html_   |
           | builder.R  |         | writer.R   |
           +------+-----+         +------+-----+
                  |                       |
                  v                       v
           +-----------------------------------+
           |  Self-Contained HTML Report       |
           |  (with confidence_navigation.js)  |
           +-----------------------------------+

  Supporting Files:
  +------------------+    +-------------------+    +----------------+
  | utils.R          |    | output_helpers.R  |    | question_      |
  | (Shared Utils)   |    | (Format Helpers)  |    | processor.R    |
  +------------------+    +-------------------+    +----------------+
```

---

## Quality Scoring Criteria

Each file is scored out of 100 based on six weighted dimensions:

| Criterion               | Weight | Description                                                                                      |
|--------------------------|-------:|--------------------------------------------------------------------------------------------------|
| **TRS Compliance**       |    20% | Uses structured refusals (never `stop()`); returns status/code/message/how_to_fix consistently   |
| **Statistical Rigour**   |    20% | Correct implementation of methods; handles edge cases (zero counts, single observations, NAs)    |
| **Code Clarity**         |    15% | Readable variable names, logical structure, functions under 100 lines where feasible             |
| **Error Handling**       |    15% | Validates inputs, provides actionable messages, outputs errors to console for Shiny visibility   |
| **Documentation**        |    15% | Roxygen2 headers, inline comments explaining non-obvious logic, parameter descriptions           |
| **Testability**          |    15% | Functions are decomposed for unit testing; side effects are isolated; deterministic where possible|

### Score Bands

| Band        | Range   | Interpretation                                                              |
|-------------|---------|-----------------------------------------------------------------------------|
| Excellent   | 93--100 | Production-grade, mathematically validated, comprehensive error handling     |
| Strong      | 85--92  | Reliable, well-structured, minor opportunities for improvement              |
| Adequate    | 75--84  | Functional and correct, but may benefit from decomposition or documentation |
| Needs Work  | < 75    | Requires attention before production use                                    |

### Score Distribution (This Module)

| Band        | File Count | Percentage |
|-------------|------------|------------|
| Excellent   |          3 |        12% |
| Strong      |         22 |        88% |
| Adequate    |          0 |         0% |
| Needs Work  |          0 |         0% |

**Module-wide average: ~89/100** -- The confidence module is production-ready with
strong TRS compliance and mathematically rigorous statistical implementations.
The primary improvement opportunity is decomposing `07_output.R` (1,588 lines)
into smaller, more focused output functions.

---

*Generated for Turas Analytics Platform -- The Research LampPost (Pty) Ltd*

# TURAS Conjoint Analysis Module

**Version 3.1.0** | Production-ready choice-based conjoint analysis with HB, Latent Class, WTP, and interactive HTML reporting

---

## What It Does

Runs end-to-end conjoint analysis: loads a config-driven study definition, estimates part-worth utilities from choice data, calculates attribute importance, and produces both Excel workbooks and self-contained HTML reports with an interactive market simulator.

### Estimation Methods

| Method | Config Value | Description | Package |
|--------|-------------|-------------|---------|
| **MNL (mlogit)** | `mlogit` | Aggregate multinomial logit via maximum likelihood. One set of utilities for the whole sample. Fast, robust baseline. | mlogit, dfidx |
| **Conditional Logit** | `clogit` | Cox proportional hazards trick for choice models. Used as automatic fallback when mlogit fails. | survival |
| **Auto** | `auto` | Tries mlogit first, falls back to clogit on convergence failure. Recommended default. | mlogit, survival |
| **Hierarchical Bayes** | `hb` | Individual-level utilities per respondent via MCMC (bayesm). Produces convergence diagnostics, respondent quality scores (RLH), and preference heterogeneity analysis. | bayesm, coda (optional) |
| **Latent Class** | `latent_class` | Discovers preference-based segments directly from choice data. Fits K=min..max classes, selects optimal K by BIC/AIC. Each class gets its own utility profile. | bayesm |
| **Best-Worst Scaling** | `best_worst` | Exploded logit for best-worst choice tasks (sequential or simultaneous estimation). | mlogit |
| **Rating-Based** | `rating` | OLS regression for rating-scale conjoint designs (not CBC). | base R |

### Simulation Methods

The market simulator predicts shares for user-defined product configurations:

| Method | Description |
|--------|-------------|
| **Logit** | Multinomial logit softmax: `P(i) = exp(U_i) / sum(exp(U_j))`. Smooth, probabilistic. Default. |
| **RFC (Randomized First Choice)** | Adds Gumbel error to utilities, then picks the max. Approximate share of preference. More realistic than pure logit for competitive scenarios. |
| **Purchase Likelihood** | Converts logit probabilities to purchase likelihood scores. |
| **First Choice** | Deterministic: 100% share to the highest-utility product, 0% to all others. Useful for winner-take-all scenarios. |

A configurable **scale factor** (exponent) is available in the HTML simulator for calibrating the logit model to observed market data.

---

## Quick Start

### From the Turas GUI

Launch Turas, click **Conjoint** in the module list, browse to your config file, and click **Run Analysis**.

### From R

```r
# Load the module
source("modules/conjoint/R/00_main.R")

# Run analysis (config file contains all settings and paths)
results <- run_conjoint_analysis("path/to/Conjoint_Config.xlsx")

# Access results
results$utilities     # Part-worth utilities by attribute level
results$importance    # Attribute importance scores
results$diagnostics   # Model fit statistics
results$model_result  # Full model object
```

### Override Paths

```r
results <- run_conjoint_analysis(
  config_file = "Conjoint_Config.xlsx",
  data_file   = "my_data.csv",
  output_file = "my_results.xlsx"
)
```

### Generate a Config Template

```r
source("modules/conjoint/R/00_main.R")

# Standard CBC template
generate_conjoint_config_template("My_Config.xlsx")

# Pre-filled for HB estimation
generate_conjoint_config_template("HB_Config.xlsx", method_template = "cbc_hb")

# Pre-filled for Latent Class
generate_conjoint_config_template("LC_Config.xlsx", method_template = "cbc_latent_class")
```

Available method templates: `standard_cbc`, `cbc_hb`, `cbc_latent_class`, `best_worst`.

---

## Config Excel Reference

The configuration workbook has up to four sheets. All file paths are **relative to the config file location** (or absolute).

### Sheet 1: Settings

Key-value format with columns: **Setting | Value | Required? | Description | Valid Values**. The header row is auto-detected (supports branded templates with title rows above the data).

#### File Paths & Output

| Setting | Default | Required | Description |
|---------|---------|----------|-------------|
| `data_file` | | Yes | Path to data file (.csv, .xlsx, .sav, .dta) |
| `output_file` | `conjoint_results.xlsx` | No | Output Excel workbook path |
| `data_source` | `generic` | No | `generic` (Turas format) or `alchemer` (direct Alchemer CBC import) |
| `analysis_type` | `choice` | Yes | `choice` (CBC) or `rating` (rating-based) |
| `choice_type` | `single` | No | `single`, `single_with_none`, or `best_worst` |

#### Column Mapping

| Setting | Default | Description |
|---------|---------|-------------|
| `respondent_id_column` | `resp_id` | Respondent identifier column |
| `choice_set_column` | `choice_set_id` | Choice set identifier column |
| `chosen_column` | `chosen` | Chosen indicator column (0/1) |
| `alternative_id_column` | `alternative_id` | Alternative identifier column |
| `rating_variable` | | Rating scores column (rating-based only) |

#### Estimation Method

| Setting | Default | Description |
|---------|---------|-------------|
| `estimation_method` | `auto` | `auto`, `mlogit`, `clogit`, `hb`, `latent_class`, `best_worst` |
| `confidence_level` | `0.95` | Confidence level for intervals (0.80-0.99) |
| `zero_center_utilities` | `TRUE` | Zero-center utilities within each attribute |
| `base_level_method` | `first` | Baseline level: `first` or `last` |

#### Hierarchical Bayes Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `hb_iterations` | `10000` | Total MCMC iterations (recommend 10000-50000) |
| `hb_burnin` | `5000` | Burn-in iterations to discard |
| `hb_thin` | `1` | Thinning interval (1 = keep all draws) |
| `hb_ncomp` | `1` | Number of mixture components |
| `hb_prior_variance` | `2` | Prior variance for beta coefficients |

#### Latent Class Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `latent_class_min` | `2` | Minimum number of classes to test |
| `latent_class_max` | `5` | Maximum number of classes to test |
| `latent_class_criterion` | `bic` | Selection criterion: `bic` or `aic` |

#### Interactions

| Setting | Default | Description |
|---------|---------|-------------|
| `interaction_terms` | | Comma-separated pairs, e.g. `Brand:Price, Size:Colour` |
| `auto_detect_interactions` | `FALSE` | Automatically detect significant interactions |

#### Willingness to Pay

| Setting | Default | Description |
|---------|---------|-------------|
| `wtp_price_attribute` | | Name of price attribute (leave blank to skip WTP) |
| `wtp_method` | `marginal` | `marginal` or `simulation` |
| `currency_symbol` | `$` | Currency symbol for display |

WTP is auto-computed when a price attribute is detected (either configured or auto-detected from attribute names containing "price", "cost", or "fee"). Uses the delta method for confidence intervals.

#### Market Simulator

| Setting | Default | Description |
|---------|---------|-------------|
| `generate_market_simulator` | `TRUE` | Include interactive simulator sheet in Excel |
| `simulation_method` | `logit` | `logit`, `first_choice`, or `rfc` |
| `rfc_draws` | `1000` | Number of random draws for RFC simulation |

#### HTML Report

| Setting | Default | Description |
|---------|---------|-------------|
| `generate_html_report` | `FALSE` | Generate interactive HTML analysis report |
| `generate_html_simulator` | `FALSE` | Generate standalone HTML market simulator |
| `brand_colour` | `#323367` | Primary brand hex colour |
| `accent_colour` | `#CC9900` | Accent hex colour |
| `project_name` | `Conjoint Analysis` | Project name in report header |
| `client_name` | | Client name in header |
| `company_name` | `The Research LampPost` | Company name in header |

#### HTML Report Insights

Pre-populated analyst commentary for each report panel:

| Setting | Description |
|---------|-------------|
| `insight_overview` | Overview tab insight text |
| `insight_utilities` | Utilities tab insight text |
| `insight_diagnostics` | Diagnostics tab insight text |
| `insight_simulator` | Simulator tab insight text |
| `insight_wtp` | WTP tab insight text |

#### Custom Content

| Setting | Default | Description |
|---------|---------|-------------|
| `include_custom_slides` | `FALSE` | Include custom slides panel (see Custom_Slides sheet) |
| `include_custom_images` | `FALSE` | Include custom images in slides |

#### Analyst & About

| Setting | Description |
|---------|-------------|
| `analyst_name` | Analyst name for About page |
| `analyst_email` | Contact email |
| `analyst_phone` | Contact phone |
| `closing_notes` | Closing notes (editable in HTML report) |
| `researcher_logo_base64` | Base64-encoded logo for header |

#### None Option

| Setting | Default | Description |
|---------|---------|-------------|
| `none_as_baseline` | `FALSE` | Use None option as baseline |
| `none_label` | `None` | Label for the none/no-choice option |

#### Optimizer

| Setting | Default | Description |
|---------|---------|-------------|
| `optimizer_method` | `exhaustive` | `exhaustive` or `greedy` |
| `optimizer_max_products` | `5` | Maximum products in optimizer scenarios (1-12) |

#### Alchemer Import

| Setting | Default | Description |
|---------|---------|-------------|
| `clean_alchemer_levels` | `TRUE` | Auto-clean compound Alchemer level names |
| `alchemer_response_id_column` | `ResponseID` | Response ID column in Alchemer export |
| `alchemer_set_number_column` | `SetNumber` | Set number column |
| `alchemer_card_number_column` | `CardNumber` | Card number column |
| `alchemer_score_column` | `Score` | Score column |

### Sheet 2: Attributes

Defines the conjoint attributes and their levels. Required columns:

| Column | Description |
|--------|-------------|
| `Attribute` | Attribute name (must match column names in data) |
| `Levels` | Comma-separated list of level labels |
| `NumLevels` | Number of levels for this attribute |

### Sheet 3: Design (optional)

Experimental design matrix. If omitted, the design is inferred from the data.

### Sheet 4: Custom_Slides (optional)

For adding custom slide panels to the HTML report. Each row defines one slide with title, body text, and optional image path.

---

## Output

### Excel Workbook (8-11 sheets depending on method)

| Sheet | Description | When Included |
|-------|-------------|---------------|
| Configuration | Study settings and attribute definitions | Always |
| Data Summary | Response statistics, respondent counts, selection rates | Always |
| Raw Coefficients | Model coefficients with standard errors and p-values | Always |
| Attribute Importance | Relative importance scores ranked by magnitude | Always |
| Utilities | Zero-centered part-worth utilities per attribute level | Always |
| Utility Chart Data | Chart-ready format for visualizations | Always |
| Model Fit | McFadden R-squared, AIC, BIC, hit rate, quality assessment | Always |
| Market Simulator | Interactive simulator with dropdowns and live share formulas | When `generate_market_simulator = TRUE` |
| Individual Utilities | Per-respondent part-worth utilities | HB only |
| HB Diagnostics | MCMC convergence metrics (Geweke, ESS, trace) | HB only |
| Respondent Quality | Individual RLH (root-likelihood) scores with flags | HB only |
| Class Comparison | BIC/AIC comparison across K solutions with delta columns | Latent Class only |
| Class Profiles | Class-level utility profiles | Latent Class only |
| Class Membership | Respondent-to-class assignments with probabilities | Latent Class only |

### HTML Analysis Report

A single self-contained HTML file with all analysis panels and an embedded market simulator. Generated when `generate_html_report = TRUE`.

**Report panels:**

- **Overview** -- Summary statistics, key findings, importance chart, top-level callouts
- **Utilities** -- Per-attribute utility charts (horizontal bar or dot plot), data tables, per-attribute sticky-note annotations with SVG pin icons
- **Diagnostics** -- Model fit statistics, convergence diagnostics (HB), plain-language method explanations, trust callouts, method reference guide
- **WTP** -- Willingness-to-pay bar chart with error bars, data table (shown when price attribute detected)
- **Latent Class** -- BIC comparison chart, class size donut chart, class-level importance grouped bar chart, comparison and profile tables
- **Simulator** -- Interactive market simulator with product configuration dropdowns, four simulation methods (Logit, RFC, Purchase Likelihood, First Choice), scale factor exponent for calibration, confidence intervals on simulated shares, bar chart visualization
- **Custom Slides** -- Config-driven slide panels with title, body text, and optional embedded images
- **Pinned Items** -- Collect and review pinned charts/tables from any panel
- **About** -- Analyst contact info, closing notes, branding

**Interactive features:**

- Tab-based navigation with sidebar scroll and keyboard shortcuts (arrow keys, number keys)
- PNG and CSV export from any panel
- Pin system: pin any chart or table to the Pinned Items panel for side-by-side review
- Editable insight text areas per panel
- Per-attribute sticky notes with SVG pin icons
- Help overlay (keyboard shortcut reference)
- Print-optimized CSS

### Standalone HTML Simulator

A lightweight single-page simulator (no analysis panels). Generated when `generate_html_simulator = TRUE`.

---

## File Structure

```
modules/conjoint/
  R/
    00_main.R                  Entry point, module loader, orchestration
    00_guard.R                 TRS guard layer, validation gates
    01_config.R                Config loading with autodetect headers
    02_data.R                  Data loading and validation
    03_estimation.R            MNL/clogit/auto/rating estimation
    04_utilities.R             Part-worth utilities, importance, diagnostics
    05_alchemer_import.R       Alchemer CBC direct import and config generation
    05_simulator.R             Market share prediction, sensitivity, demand curves
    06_interactions.R          Config-driven interaction effects
    07_output.R                Excel workbook writer (8-11 sheets)
    08_market_simulator.R      Interactive Excel simulator sheet
    09_none_handling.R         None/opt-out detection and handling
    10_best_worst.R            Best-worst scaling estimation
    11_hierarchical_bayes.R    Individual-level HB via bayesm MCMC
    12_config_template.R       Branded Excel config template generator
    13_latent_class.R          Latent class segmentation
    14_willingness_to_pay.R    WTP with delta-method CIs
    15_product_optimizer.R     Exhaustive/greedy product optimization
    99_helpers.R               Shared utilities, formatting, logging
  lib/
    html_report/               HTML analysis report generator
      00_html_guard.R          Input validation for HTML generation
      01_data_transformer.R    Transform conjoint results to HTML data model
      02_table_builder.R       HTML tables for each panel
      03_page_builder.R        Full page assembly (CSS, header, panels, JS)
      04_html_writer.R         Write final HTML to disk
      05_chart_builder.R       Inline SVG chart generation
      99_html_report_main.R    Top-level orchestrator
      js/                      7 JavaScript modules (navigation, export, pins,
                               charts, simulator engine, simulator UI,
                               simulator charts)
    html_simulator/            Standalone HTML simulator
      00_simulator_guard.R     Input validation
      01_simulator_data_transformer.R
      02_simulator_page_builder.R
      99_simulator_main.R      Top-level orchestrator
      js/                      3 JavaScript modules (engine, charts, UI)
  tests/
    testthat/                  Unit and integration tests (14 files)
    fixtures/                  Synthetic test data generators
  docs/
    CODE_INVENTORY.md          Complete function index (232 functions)
  examples/                    Module-level examples
  run_conjoint_gui.R           Shiny GUI launcher
```

---

## Dependencies

### Required

| Package | Purpose |
|---------|---------|
| **dplyr** | Data manipulation |
| **openxlsx** | Excel config reading and output writing (no Java dependency) |

### Required for Estimation (method-dependent)

| Package | Purpose | When Needed |
|---------|---------|-------------|
| **mlogit** | Maximum likelihood MNL estimation | `auto`, `mlogit` methods |
| **dfidx** | Data indexing for mlogit (>= 1.1-0) | `auto`, `mlogit` methods |
| **survival** | Conditional logit (clogit) estimation | `auto`, `clogit` methods |
| **bayesm** | Hierarchical Bayes MCMC and Latent Class | `hb`, `latent_class` methods |

### Optional

| Package | Purpose |
|---------|---------|
| **coda** | Enhanced MCMC convergence diagnostics (Geweke test, ESS) |
| **haven** | Import SPSS (.sav) and Stata (.dta) data files |
| **jsonlite** | JSON serialization for HTML report/simulator data |

---

## Examples

### Demo: MNL vs HB Comparison

The `examples/conjoint/v3_demo/hb_demo/` directory contains a comparison script that runs both MNL and HB estimation on the same dataset:

```r
# From the Turas root directory
source("examples/conjoint/v3_demo/hb_demo/run_hb_comparison.R")
```

This demonstrates the difference between aggregate MNL utilities and individual-level HB utilities, including convergence diagnostics and respondent quality scores. Requires the `bayesm` package.

### Demo: Standard CBC

```r
source("examples/conjoint/v3_demo/run_demo.R")
```

---

## Troubleshooting

### "Package 'bayesm' is not available"

HB and Latent Class estimation require bayesm. Install with:

```r
install.packages("bayesm")
```

### "Package 'mlogit' is not available"

MNL estimation requires mlogit and dfidx:

```r
install.packages(c("mlogit", "dfidx"))
```

### HB estimation is slow

- Default is 10,000 iterations with 5,000 burn-in. For initial testing, reduce to `hb_iterations = 5000`, `hb_burnin = 2000`.
- Production runs typically need 10,000-50,000 iterations. Monitor convergence diagnostics (Geweke p-values, ESS) to determine if more iterations are needed.

### Convergence warnings in HB output

Check the HB Diagnostics sheet (Excel) or Diagnostics panel (HTML report). The report provides plain-language explanations of each diagnostic metric. Common fixes:
- Increase `hb_iterations` (e.g., 20000-50000)
- Increase `hb_burnin` to discard more initial draws
- Check for attributes with very many levels (can slow convergence)

### "Column X not found in data"

Verify `respondent_id_column`, `choice_set_column`, `chosen_column`, and `alternative_id_column` in the Settings sheet match your data file column names exactly (case-sensitive).

### Config header not detected

The module auto-detects the header row by scanning the first 20 rows for "Setting" and "Value" columns. If your template has more than 20 rows above the header, move the header up or simplify the template.

### HTML report not generated

Set `generate_html_report = TRUE` in the Settings sheet. The report requires jsonlite:

```r
install.packages("jsonlite")
```

### WTP not appearing in output

WTP requires either:
- `wtp_price_attribute` set in config to the exact attribute name, or
- An attribute name containing "price", "cost", or "fee" (auto-detected)

The price levels must contain parseable numeric values.

### TRS refusal messages

All errors follow the Turas Refusal System (TRS) pattern. Check the console output for:
- **Code** -- Error identifier (e.g., `DATA_MISSING`, `CFG_INVALID`)
- **Message** -- What went wrong
- **How to fix** -- Actionable resolution steps

---

## Module Stats

| Metric | Value |
|--------|-------|
| Core R files | 19 |
| HTML report R files | 7 |
| HTML simulator R files | 4 |
| JavaScript modules | 10 |
| Total R functions | 232 |
| Total lines of code | ~18,800 |
| Test files | 14 |
| Quality score | 91/100 |

# Segment Module - Code Inventory

**Module:** Segmentation (Turas Platform)
**Version:** 12.0
**Last Updated:** 2026-03-08
**Quality Score:** 92/100

---

## Summary Statistics

| Category | Files | Lines of Code |
|----------|-------|---------------|
| Core Analysis (`R/`) | 23 | 14,916 |
| HTML Report Pipeline (`lib/html_report/`) | 9 | 8,094 |
| Preflight Validators (`lib/validation/`) | 1 | 798 |
| **Total Source** | **33** | **23,808** |
| Tests (`tests/testthat/`) | 14 | 3,967 |
| Documentation (`docs/`) | 9 | ~220 KB |

---

## Core Analysis Files (R/)

| File | Lines | Purpose | Quality |
|------|-------|---------|---------|
| `00_main.R` | 1,017 | Main orchestrator: exploration/final/multi-method pipelines | 90 |
| `00_guard.R` | 381 | TRS v1.1 guard framework, refusal wrapper, state management | 93 |
| `00a_guards_hard.R` | 360 | Hard guards that REFUSE: data, config, method validation | 93 |
| `00b_guards_soft.R` | 327 | Soft guards + pre/post orchestrators (PARTIAL status) | 92 |
| `01_config.R` | 498 | Config loading, validation, 40+ parameters with defaults | 90 |
| `02_data_prep.R` | 605 | Data loading, missing data handling, standardization | 88 |
| `02a_variable_selection.R` | 521 | Multi-method variable selection (variance, correlation, FA) | 88 |
| `02b_outliers.R` | 764 | Outlier detection (Z-score, Mahalanobis) and handling | 88 |
| `03_clustering.R` | 254 | Method dispatcher to kmeans/hclust/gmm | 90 |
| `03a_kmeans.R` | 529 | K-means with mini-batch for large datasets (>10k rows) | 90 |
| `03b_hclust.R` | 177 | Hierarchical clustering with linkage options | 90 |
| `03c_gmm.R` | 265 | Gaussian Mixture Models via mclust | 90 |
| `04_validation.R` | 743 | Silhouette, elbow, gap statistic, bootstrap stability | 90 |
| `05_profiling.R` | 733 | Segment profiling, means, demographics | 88 |
| `05a_profiling_stats.R` | 720 | ANOVA, effect sizes, significance testing | 88 |
| `06_rules.R` | 777 | Classification rules via decision trees (rpart) | 87 |
| `07_cards.R` | 489 | Segment action cards and narratives | 87 |
| `08_scoring.R` | 830 | Score new data against saved models | 88 |
| `09_output.R` | 1,002 | Excel export with openxlsx, TRS Run_Status sheet | 90 |
| `10_utilities.R` | 1,586 | Utilities, quick-run functions, variable importance | 85 |
| `11_lca.R` | 801 | Latent Class Analysis (mclust-based) | 87 |
| `12_executive_summary.R` | 878 | Auto-generated narrative insights | 88 |
| `13_vulnerability.R` | 659 | Segment switching/vulnerability analysis | 88 |

## HTML Report Pipeline (lib/html_report/)

| File | Lines | Purpose | Quality |
|------|-------|---------|---------|
| `00_html_guard.R` | 132 | Input validation for HTML reports | 88 |
| `01_data_transformer.R` | 224 | Results to HTML-ready data structures | 87 |
| `02_table_builder.R` | 655 | Styled HTML table generation | 86 |
| `03_page_builder.R` | 2,982 | Page layout, inline SVG, section assembly | 82 |
| `04_html_writer.R` | 98 | Write assembled HTML to file | 88 |
| `05_chart_builder.R` | 1,112 | SVG chart generation (bars, radar, heatmaps) | 86 |
| `06_exploration_report.R` | 686 | K-selection exploration HTML layout | 85 |
| `07_combined_report.R` | 1,898 | Multi-method tabbed comparison report | 85 |
| `99_html_report_main.R` | 307 | Entry point for HTML report pipeline | 88 |

## Preflight Validators (lib/validation/)

| File | Lines | Purpose | Quality |
|------|-------|---------|---------|
| `preflight_validators.R` | 798 | 15 cross-referential checks, orchestrator | 92 |

## Test Suite (tests/testthat/)

| File | Lines | Purpose |
|------|-------|---------|
| `helper-setup.R` | 59 | Shared test utilities, synthetic data generator |
| `test_guard.R` | 331 | Guard initialization, recording, summary tests |
| `test_guards_hard.R` | 256 | Hard guard validation (refusals) |
| `test_guards_soft.R` | 297 | Soft guard warnings |
| `test_clustering.R` | 279 | K-means functionality |
| `test_hclust.R` | 224 | Hierarchical clustering |
| `test_gmm.R` | 260 | Gaussian Mixture Models |
| `test_validation.R` | 291 | Metrics (silhouette, elbow) |
| `test_output.R` | 252 | Excel export functions |
| `test_html_report.R` | 389 | HTML report generation |
| `test_integration.R` | 394 | End-to-end pipeline tests |
| `test_executive_summary.R` | 406 | Narrative generation |
| `test_edge_cases.R` | 151 | Empty data, single var, edge cases |
| `test_vulnerability.R` | 378 | Switching analysis |

---

## Architecture Diagram

```
Config (Excel)
    |
    v
[01_config.R] Load & Validate (40+ parameters)
    |
    v
[preflight_validators.R] 15 Cross-Referential Checks
    |
    v
[02_data_prep.R] Load Data, Handle Missing Values
    |
    +---> [02a_variable_selection.R] Reduce Variable Set (optional)
    +---> [02b_outliers.R] Detect & Handle Outliers (optional)
    |
    v
[00b_guards_soft.R] segment_guard_pre_analysis() -- Hard + Soft Guards
    |
    v
[03_clustering.R] Method Dispatcher
    |
    +---> [03a_kmeans.R] K-Means (mini-batch for n > 10k)
    +---> [03b_hclust.R] Hierarchical (ward.D2, complete, etc.)
    +---> [03c_gmm.R] Gaussian Mixture Models (mclust)
    |
    v
[04_validation.R] Silhouette, Elbow, Gap, Bootstrap Stability
    |
    v
[00b_guards_soft.R] segment_guard_post_clustering() -- Quality Checks
    |
    v
[05_profiling.R] + [05a_profiling_stats.R] Segment Profiles & Statistics
    |
    +---> [06_rules.R] Classification Rules (rpart)
    +---> [07_cards.R] Segment Action Cards
    +---> [08_scoring.R] Score New Data
    +---> [11_lca.R] Latent Class Analysis (optional)
    +---> [12_executive_summary.R] Auto-Generated Narrative
    +---> [13_vulnerability.R] Switching Analysis
    |
    v
[09_output.R] Excel Export (openxlsx, Run_Status FIRST)
    |
    v
[lib/html_report/] Interactive HTML Report Pipeline (9 files)
```

---

## Quality Scoring Criteria

Each file is scored on 5 dimensions (20 points each, 100 max):

| Dimension | Description |
|-----------|-------------|
| **Correctness** | Logic correct, edge cases handled, no bugs |
| **Robustness** | TRS compliance, error handling, graceful degradation |
| **Documentation** | Roxygen2 docs, inline comments, clear variable names |
| **Test Coverage** | Corresponding tests exist, edge cases tested |
| **Code Style** | Consistent formatting, functions < 100 lines, no hardcoded paths |

---

## Execution Modes

| Mode | Triggered By | Output |
|------|-------------|--------|
| **Exploration** | `k_fixed` not set | K-selection report with metrics comparison |
| **Final** | `k_fixed` set, single method | Full segmentation report with profiles |
| **Multi-Method** | `method = "kmeans,hclust,gmm"` or `"all"` | Combined comparison report |

---

## Key Dependencies

| Package | Purpose | Required? |
|---------|---------|-----------|
| `openxlsx` | Excel output with formatting | Yes |
| `readxl` | Read Excel config/data | Yes |
| `writexl` | Simple Excel output (legacy) | Yes |
| `mclust` | GMM clustering | For GMM only |
| `fastcluster` | Fast hierarchical clustering | Optional |
| `rpart` | Classification rules | For rules only |
| `psych` | Factor analysis variable selection | For FA only |
| `randomForest` | Golden questions | Optional |

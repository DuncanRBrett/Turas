# Segment Module - Code Inventory

**Version:** 11.1
**Total R source code:** ~15,000 lines (core) + ~9,800 lines (HTML report) = ~24,800 lines
**Last updated:** 2026-03-19

---

## Core Pipeline (`R/` directory)

All files sourced by `R/00_main.R` in sequence. This is the active code path.

| File | Lines | Responsibility |
|------|-------|---------------|
| `00_main.R` | 1,018 | Main orchestrator: 7-step pipeline, exploration/final/multi-method modes |
| `00_guard.R` | 385 | TRS guard framework: segment_refuse(), guard state, status determination |
| `00a_guards_hard.R` | 360 | Hard guards (REFUSE): data file, clustering vars, ID, sample size, method, k range |
| `00b_guards_soft.R` | 234 | Soft guards (PARTIAL): low variance, small clusters, silhouette, outliers, missing data, correlations |
| `01_config.R` | 453 | Configuration loading and validation from Excel (Settings/Value format) |
| `02_data_prep.R` | 605 | Data loading, variable selection, missing data, outliers, standardization |
| `02a_variable_selection.R` | 521 | Variable selection: variance, correlation, factor analysis methods |
| `02b_outliers.R` | 764 | Outlier detection: Z-score and Mahalanobis methods with flag/remove handling |
| `03_clustering.R` | 254 | Method dispatcher: routes to kmeans/hclust/gmm, validates result structure |
| `03a_kmeans.R` | 529 | K-means engine: standard + mini-batch for large datasets, k-means++ init |
| `03b_hclust.R` | 177 | Hierarchical clustering: hclust/fastcluster, dendrogram extraction, cophenetic |
| `03c_gmm.R` | 265 | GMM clustering via mclust: BIC model selection, probabilities, uncertainty |
| `04_validation.R` | 743 | Validation metrics: silhouette, elbow, stability (bootstrap + simple), discriminant analysis |
| `05_profiling.R` | 733 | Segment profiling: means, ANOVA, auto-naming, demographics, chi-square tests |
| `05a_profiling_stats.R` | 534 | Enhanced profiling: significance tests, index scores, Cohen's d, variable importance |
| `06_rules.R` | 777 | Classification rules (rpart), golden questions (Random Forest), rule formatting |
| `07_cards.R` | 489 | Segment action cards: headlines, defining traits, strengths, pain points, actions |
| `08_scoring.R` | 830 | Score new respondents using saved models (with imputation parameter consistency) |
| `09_output.R` | 823 | Excel export: assignments, exploration reports, final reports (openxlsx formatted) |
| `09a_excel_styles.R` | 313 | Shared Excel style definitions: branded headers, conditional formatting, helpers |
| `10_utilities.R` | 1,827 | Utilities: config templates, package management, seed handling, quick-run helpers |
| `11_lca.R` | 801 | Latent Class Analysis via poLCA: categorical data clustering |
| `12_executive_summary.R` | 878 | Executive summary generator: headline, findings, quality, descriptions, recommendations |
| `13_vulnerability.R` | 650 | Vulnerability/switching analysis: confidence scores, switching matrix |

**Total core R:** 14,963 lines across 24 files

---

## HTML Report Pipeline (`lib/html_report/`)

Self-contained report generation system producing interactive, branded HTML with SVG charts.

| File | Lines | Responsibility |
|------|-------|---------------|
| `99_html_report_main.R` | ~200 | Main entry point: routes to final/exploration/combined builders |
| `00_html_guard.R` | ~150 | Input validation for HTML report generation |
| `01_data_transformer.R` | ~400 | Flattens segmentation results into HTML-ready data structures |
| `02_table_builder.R` | ~500 | Builds 6+ htmltools table objects (profiles, validation, rules, etc.) |
| `03_page_builder.R` | ~2,843 | Complete page assembly: CSS (2,800+ lines), section layout, navigation |
| `04_html_writer.R` | ~200 | Atomic file writer (write → rename pattern for safety) |
| `05_chart_builder.R` | ~1,111 | SVG chart generation: silhouette, sizes, importance, heatmap |
| `06_exploration_report.R` | ~400 | K-selection variant of HTML report |
| `07_combined_report.R` | ~1,949 | Multi-method comparison report builder |

### JavaScript Modules (`lib/html_report/js/`)

| File | Lines | Responsibility |
|------|-------|---------------|
| `seg_navigation.js` | ~300 | Section navigation, tab switching, report state management |
| `seg_pinned_views.js` | ~600 | Pin management: add/remove/reorder pins, section dividers, serialization |
| `seg_slide_export.js` | ~500 | PNG export at 3840x2160 (3x): layout, rendering, download |
| `seg_utils.js` | ~200 | Shared helpers: HTML escape, text wrap, blob download, insight editors |

**Total HTML report:** ~9,770 lines across 13 files

---

## Library Files (`lib/` — non-HTML)

Legacy/support library files. Most functionality has been consolidated into R/ files.

| File | Status | Notes |
|------|--------|-------|
| `segment_cards.R` | Legacy | Superseded by `R/07_cards.R` |
| `segment_config.R` | Legacy | Superseded by `R/01_config.R` |
| `segment_data_prep.R` | Legacy | Superseded by `R/02_data_prep.R` |
| `segment_export.R` | Legacy | Superseded by `R/09_output.R` |
| `segment_kmeans.R` | Legacy | Superseded by `R/03a_kmeans.R` |
| `segment_lca.R` | Legacy | Superseded by `R/11_lca.R` |
| `segment_outliers.R` | Legacy | Superseded by `R/02b_outliers.R` |
| `segment_profile.R` | Legacy | Superseded by `R/05_profiling.R` |
| `segment_profiling_enhanced.R` | Legacy | Superseded by `R/05a_profiling_stats.R` |
| `segment_rules.R` | Legacy | Superseded by `R/06_rules.R` |
| `segment_scoring.R` | Legacy | Superseded by `R/08_scoring.R` |
| `segment_utils.R` | Legacy | Superseded by `R/10_utilities.R` |
| `segment_validation.R` | Legacy | Superseded by `R/04_validation.R` |
| `segment_variable_selection.R` | Legacy | Superseded by `R/02a_variable_selection.R` |
| `segment_visualization.R` | Legacy | Chart generation (partially superseded by HTML chart_builder) |

---

## Tests (`tests/`)

| File | Coverage |
|------|----------|
| `run_tests.R` | Test runner script |
| `run_preflight.R` | Pre-flight regression test system |
| `testthat/helper-setup.R` | Test setup and fixtures |
| `testthat/test_clustering.R` | K-means, hclust, gmm clustering |
| `testthat/test_edge_cases.R` | Boundary conditions and edge cases |
| `testthat/test_executive_summary.R` | Summary generation |
| `testthat/test_gmm.R` | GMM-specific tests |
| `testthat/test_guard.R` | Guard framework |
| `testthat/test_guards_hard.R` | Hard guard validation |
| `testthat/test_guards_soft.R` | Soft guard warnings |
| `testthat/test_hclust.R` | Hierarchical clustering |
| `testthat/test_integration.R` | End-to-end integration tests |
| `testthat/test_output.R` | Excel output validation |
| `testthat/test_validation.R` | Validation metrics |
| `fixtures/generate_test_data.R` | Synthetic test data generator |

---

## R Package Dependencies

### Required (core functionality)
| Package | Min Version | Purpose |
|---------|-------------|---------|
| `stats` | (built-in) | K-means clustering, ANOVA |
| `cluster` | 2.1.0 | Silhouette analysis |
| `readxl` | 1.4.0 | Read Excel config/data files |
| `openxlsx` | 4.2.5 | Write formatted Excel output |
| `htmltools` | 0.5.0 | HTML report assembly |

### Optional (enhanced features)
| Package | Feature | Purpose |
|---------|---------|---------|
| `mclust` | GMM clustering | Gaussian Mixture Models via EM |
| `poLCA` | LCA | Latent Class Analysis |
| `rpart` | Classification rules | Decision tree segment rules |
| `randomForest` | Golden questions | Variable importance for prediction |
| `fastcluster` | Large hclust | Faster hierarchical clustering |
| `MASS` | Mahalanobis outliers | Multivariate outlier detection |
| `psych` | Factor analysis | Variable selection via factor loading |
| `haven` | SPSS data | Read .sav files |

### Minimum R Version
R 4.0.0 or higher

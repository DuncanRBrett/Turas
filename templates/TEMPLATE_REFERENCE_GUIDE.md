# TURAS Template Reference Guide

**Version:** 1.0
**Last Updated:** December 2, 2025
**Purpose:** Definitive quick-reference for all TURAS configuration templates

---

## Table of Contents

1. [Survey Structure Template](#1-survey-structure-template)
2. [Crosstab Config Template](#2-crosstab-config-template)
3. [Tracker Config Template](#3-tracker-config-template)
4. [Tracker Question Mapping Template](#4-tracker-question-mapping-template)
5. [Confidence Config Template](#5-confidence-config-template)
6. [Segment Config Template](#6-segment-config-template)
7. [Quick Reference Tables](#7-quick-reference-tables)

---

## 1. Survey Structure Template

**File:** `Survey_Structure_Template_Annotated.xlsx`
**Purpose:** Defines survey questionnaire structure for use with TurasTabs module
**Sheets:** Questions, Options, Composite_Metrics

### Sheet: Questions

| Parameter | Required | Options | Purpose | Example |
|-----------|----------|---------|---------|---------|
| `QuestionCode` | **Required** | Any unique code | Unique identifier for question | Q1, Q2a, SAT_01 |
| `QuestionText` | **Required** | Any text | Full question wording | "What is your age group?" |
| `Variable_Type` | **Required** | Single, Multiple, Rating, NPS, Grid, Numeric, Text | Question type (affects analysis) | Rating |
| `Scale_Min` | For Rating/NPS | Numeric | Minimum scale value | 1 |
| `Scale_Max` | For Rating/NPS | Numeric | Maximum scale value | 5, 10 |
| `ShowInOutput` | Optional | Y/N (default: Y) | Include in output reports | Y |

### Sheet: Options

| Parameter | Required | Options | Purpose | Example |
|-----------|----------|---------|---------|---------|
| `QuestionCode` | **Required** | Must match Questions sheet | Links to question | Q1 |
| `OptionCode` | **Required** | Numeric (1, 2, 3...) | Unique code for this option | 1 |
| `OptionText` | **Required** | Any text | Response option text | "Under 18" |
| `OptionValue` | Optional | Numeric | Numeric value for analysis | 1 |
| `ExcludeFromIndex` | Optional | Y/N (default: N) | Exclude from index calculations | Y (for "Don't know") |
| `BoxCategory` | Optional | Top2, Bottom2, Positive, Negative | Groups options for box aggregation | Top2 |

### Sheet: Composite_Metrics

| Parameter | Required | Options | Purpose | Example |
|-----------|----------|---------|---------|---------|
| `CompositeCode` | **Required** | Must start with COMP_ | Unique identifier for composite | COMP_SAT |
| `CompositeLabel` | **Required** | Any text | Display name in reports | "Overall Satisfaction" |
| `CalculationType` | **Required** | Mean, Sum, WeightedMean | How to combine source questions | Mean |
| `SourceQuestions` | **Required** | Comma-separated codes | Questions to combine | Q3,Q4,Q5 |
| `Weights` | For WeightedMean | Comma-separated numbers | Weights matching source questions | 1,2,1 |
| `ExcludeFromSummary` | Optional | Y/N (default: N) | Hide from Index_Summary sheet | N |
| `SectionLabel` | Optional | Any text | Groups composites in Index_Summary | SATISFACTION |

---

## 2. Crosstab Config Template

**File:** `Crosstab_Config_Template_Annotated.xlsx`
**Purpose:** Configures single-wave cross-tabulation analysis
**Sheets:** Settings, Banner, Stub

### Sheet: Settings

| Parameter | Required | Options | Default | Purpose |
|-----------|----------|---------|---------|---------|
| `project_name` | **Required** | Any text | - | Project name for output filename |
| `data_file` | **Required** | CSV or XLSX path | - | Path to survey data file |
| `survey_structure_file` | **Required** | XLSX path | - | Survey structure from Parser |
| `weight_variable` | Optional | Column name or blank | - | Weighting variable (blank = unweighted) |
| `decimal_separator` | **Required** | . or , | . | Decimal separator (. = US/UK, , = European) |
| `decimal_places_percent` | **Required** | 0-3 | 0 | Decimal places for percentages |
| `decimal_places_ratings` | **Required** | 0-3 | 1 | Decimal places for mean ratings |
| `decimal_places_index` | Optional | 0-3 | 1 | Decimal places for index values |
| `decimal_places_numeric` | Optional | 0-3 | 1 | Decimal places for numeric statistics |
| `show_significance` | **Required** | TRUE/FALSE, Y/N | TRUE | Display significance letters (A, B, C) |
| `alpha` | **Required** | 0.01, 0.05, 0.10 | 0.05 | Significance level (0.05 = 95% confidence) |
| `minimum_base` | **Required** | Numeric > 0 | 30 | Minimum sample size for sig testing |
| `enable_chi_square` | Optional | TRUE/FALSE | FALSE | Include chi-square test results |
| `bonferroni_correction` | Optional | TRUE/FALSE | TRUE | Apply Bonferroni correction |
| `create_index_summary` | Optional | TRUE/FALSE, Y/N | FALSE | Create Index_Summary executive sheet |
| `show_standard_deviation` | Optional | TRUE/FALSE | FALSE | Show standard deviation for ratings |
| `show_unweighted_n` | Optional | TRUE/FALSE | TRUE | Display unweighted base sizes |
| `show_effective_n` | Optional | TRUE/FALSE | TRUE | Display effective sample size (weighted) |
| `output_filename` | Optional | Filename | Crosstabs.xlsx | Output filename |
| `output_subfolder` | Optional | Folder path | output | Output subfolder |

### Sheet: Banner

| Parameter | Required | Options | Purpose | Example |
|-----------|----------|---------|---------|---------|
| `BannerID` | **Required** | Unique ID | Identifier for banner column | Total, Male, Female |
| `BannerLabel` | **Required** | Any text | Display label in output | "Male", "Age 18-34" |
| `Variable` | **Required** | Column name from data | Variable to use | Gender, Age |
| `Filter` | Optional | R expression | Filter expression | Gender==1, Age>=18 & Age<=34 |
| `Order` | Optional | Numeric | Display order | 1, 2, 3 |

### Sheet: Stub

| Parameter | Required | Options | Purpose | Example |
|-----------|----------|---------|---------|---------|
| `QuestionCode` | **Required** | From Survey_Structure | Question to analyze | Q1, Q2, COMP_SAT |
| `QuestionText` | Optional | Any text | Override question text | - |
| `Filter` | Optional | R expression | Question-specific filter | Completed==1 |
| `Order` | Optional | Numeric | Display order in output | 1, 2, 3 |

---

## 3. Tracker Config Template

**File:** `Tracker_Config_Template_Annotated.xlsx`
**Purpose:** Configures multi-wave tracking analysis
**Sheets:** Waves, TrackedQuestions, Banner, Settings

### Sheet: Waves

| Parameter | Required | Options | Purpose | Example |
|-----------|----------|---------|---------|---------|
| `WaveID` | **Required** | Short unique code | Wave identifier | W1, W2, Q1_2024 |
| `WaveName` | **Required** | Any text | Descriptive name for reports | "Wave 1 - Jan 2024" |
| `DataFile` | **Required** | CSV or XLSX path | Path to wave data file | data/wave1.csv |
| `FieldworkStart` | Optional | YYYY-MM-DD | Fieldwork start date | 2024-01-15 |
| `FieldworkEnd` | Optional | YYYY-MM-DD | Fieldwork end date | 2024-01-30 |
| `WeightVar` | Optional | Column name | Weight variable (consistent across waves) | weight |

### Sheet: TrackedQuestions

| Parameter | Required | Options | Purpose | Example |
|-----------|----------|---------|---------|---------|
| `QuestionCode` | **Required** | Standard tracking code | Question to track | Q_SAT, Q_NPS, COMP_OVERALL |

### Sheet: Banner

| Parameter | Required | Options | Purpose | Example |
|-----------|----------|---------|---------|---------|
| `BreakVariable` | **Required** | Column name | Variable for demographic breakouts | Gender, AgeGroup |
| `BreakLabel` | **Required** | Any text | Display label | "Gender", "Age Group" |

### Sheet: Settings

| Parameter | Required | Options | Default | Purpose |
|-----------|----------|---------|---------|---------|
| `project_name` | **Required** | Any text | - | Project name for output filename |
| `decimal_places_ratings` | **Required** | 0-3 | 1 | Decimal places for mean ratings |
| `show_significance` | **Required** | Y/N, TRUE/FALSE | Y | Enable significance testing |
| `alpha` | **Required** | 0.01, 0.05, 0.10 | 0.05 | Significance level |
| `minimum_base` | **Required** | Numeric > 0 | 30 | Minimum sample size for sig testing |
| `decimal_separator` | **Required** | . or , | . | Decimal separator |

---

## 4. Tracker Question Mapping Template

**File:** `Tracker_Question_Mapping_Template_Annotated.xlsx`
**Purpose:** Maps question codes across waves when they change
**Sheets:** QuestionMap

### Sheet: QuestionMap

| Parameter | Required | Options | Purpose | Example |
|-----------|----------|---------|---------|---------|
| `QuestionCode` | **Required** | Unique tracking code | Standard code for tracking | Q_SAT |
| `QuestionText` | **Required** | Any text | Question wording | "Overall satisfaction (1-10)" |
| `QuestionType` | **Required** | Rating, NPS, SingleChoice, Composite | Analysis method | Rating |
| `Wave1` | Optional | Question code or blank | Question code in Wave 1 | Q10 |
| `Wave2` | Optional | Question code or blank | Question code in Wave 2 | Q11 |
| `Wave3` | Optional | Question code or blank | Question code in Wave 3 | Q12 |
| `Wave4` | Optional | Question code or blank | Question code in Wave 4 | Q15 |
| `SourceQuestions` | For Composite only | Comma-separated codes | Source questions for composite | Q_SAT,Q_VALUE |

**Notes:**
- Add one `WaveN` column per wave in your study
- Leave blank if question not asked in that wave
- For composites, use consistent code across waves (e.g., COMP)

---

## 5. Confidence Config Template

**File:** `Confidence_Config_Template_Annotated.xlsx`
**Purpose:** Configures confidence interval analysis (MOE, Wilson, Bootstrap, Bayesian)
**Sheets:** Study_Settings, Question_Analysis

### Sheet: Study_Settings

| Parameter | Required | Options | Default | Purpose |
|-----------|----------|---------|---------|---------|
| `Data_File` | **Required** | CSV or XLSX path | - | Path to survey data file |
| `Output_File` | **Required** | XLSX path | - | Output file path |
| `Calculate_Effective_N` | **Required** | Y/N | Y | Calculate effective sample size |
| `Confidence_Level` | **Required** | 0.90, 0.95, 0.99 | 0.95 | Confidence level (95% = 0.95) |
| `DEFF` | Optional | Numeric ≥ 1.0 | 1.0 | Design effect (1.0 = simple random sample) |
| `Bootstrap_Iterations` | **Required** | 1000-10000 | 5000 | Number of bootstrap resamples |
| `Random_Seed` | Optional | Any integer | - | Random seed for reproducibility |
| `Multiple_Comparison_Adjustment` | **Required** | Y/N | N | Adjust for multiple comparisons |
| `Multiple_Comparison_Method` | If Adjustment=Y | Bonferroni, Holm, FDR | Bonferroni | Adjustment method |
| `Decimal_Separator` | **Required** | . or , | . | Decimal separator |

### Sheet: Question_Analysis

| Parameter | Required | Options | Purpose | Example |
|-----------|----------|---------|---------|---------|
| `Question_ID` | **Required** | Question code from data | Question to analyze | Q1, Q2 |
| `Statistic_Type` | **Required** | proportion, mean, nps | Type of statistic | proportion |
| `Categories` | For proportion | Comma-separated codes | Response codes to include | 1,2 or 4,5 |
| `Run_MOE` | Optional | Y/N | Calculate classic Margin of Error | Y |
| `Run_Bootstrap` | Optional | Y/N | Calculate bootstrap CI | Y |
| `Run_Credible` | Optional | Y/N | Calculate Bayesian credible interval | N |
| `Use_Wilson` | For proportion | Y/N | Use Wilson score interval | Y |
| `Prior_Mean` | For Bayesian | Numeric | Prior mean estimate | 0.65, 7.5 |
| `Prior_SD` | For Bayesian mean/nps | Numeric > 0 | Prior standard deviation | 1.2 |
| `Promoter_Codes` | For NPS | Comma-separated codes | Promoter codes | 9,10 |
| `Detractor_Codes` | For NPS | Comma-separated codes | Detractor codes | 0,1,2,3,4,5,6 |

**Analysis Method Guide:**
- **MOE**: Fast, classic ±% confidence intervals
- **Wilson**: More accurate for small samples or extreme proportions
- **Bootstrap**: Robust for complex metrics, requires 5000+ iterations
- **Bayesian**: Incorporates prior information, requires prior specification

---

## 6. Segment Config Template

**File:** `Segment_Config_Template_Annotated.xlsx`
**Purpose:** Configures k-means clustering segmentation analysis
**Sheets:** Config

### Sheet: Config

| Parameter | Required | Options | Default | Purpose |
|-----------|----------|---------|---------|---------|
| `data_file` | **Required** | CSV or XLSX path | - | Path to survey data file |
| `data_sheet` | **Required** | Sheet name | Data | Sheet name in Excel |
| `id_variable` | **Required** | Column name | - | Unique identifier for respondents |
| `clustering_vars` | **Required** | Comma-separated codes | - | Variables for clustering (5-15 recommended) |
| `profile_vars` | Optional | Comma-separated codes | - | Variables for profiling (blank = all non-clustering) |
| `method` | **Required** | kmeans | kmeans | Clustering method |
| `k_fixed` | Optional | Integer 2-10 or blank | - | Fixed k (blank = exploration mode) |
| `k_min` | For exploration | 2-10 | 3 | Minimum k to test |
| `k_max` | For exploration | 2-15 | 6 | Maximum k to test |
| `nstart` | **Required** | 1-200 | 50 | Number of random starts |
| `seed` | **Required** | Any integer | 123 | Random seed |
| `missing_data` | **Required** | listwise_deletion, mean_imputation, median_imputation, refuse | listwise_deletion | Missing value handling |
| `missing_threshold` | Optional | 0-100 | 15 | Max % missing per variable |
| `standardize` | **Required** | TRUE/FALSE | TRUE | Standardize variables (mean=0, sd=1) |
| `min_segment_size_pct` | Optional | 0-50 | 10 | Minimum segment size as % of sample |
| `outlier_detection` | Optional | TRUE/FALSE | FALSE | Enable outlier detection |
| `outlier_method` | If outlier_detection | zscore, mahalanobis | zscore | Outlier detection method |
| `outlier_threshold` | If outlier_detection | 1.0-5.0 | 3.0 | Outlier threshold |
| `outlier_min_vars` | If outlier_detection | 1-nclustering_vars | 1 | Min variables flagged for outlier status |
| `outlier_handling` | If outlier_detection | none, flag, remove | flag | How to handle outliers |
| `outlier_alpha` | For mahalanobis | 0.0001-0.1 | 0.001 | Significance level for mahalanobis |
| `variable_selection` | Optional | TRUE/FALSE | FALSE | Enable automatic variable selection |
| `variable_selection_method` | If variable_selection | variance_correlation, factor_analysis, both | variance_correlation | Selection method |
| `max_clustering_vars` | If variable_selection | 2-20 | 10 | Target number of variables after selection |
| `varsel_min_variance` | If variable_selection | 0.01-1.0 | 0.1 | Minimum variance to retain variable |
| `varsel_max_correlation` | If variable_selection | 0.5-0.95 | 0.8 | Max correlation before removing redundant |
| `k_selection_metrics` | For exploration | silhouette, elbow, gap | silhouette,elbow | Metrics for k selection (comma-separated) |
| `output_folder` | **Required** | Directory path | output/ | Output directory |
| `output_prefix` | Optional | Any text | seg_ | Prefix for output filenames |
| `create_dated_folder` | Optional | TRUE/FALSE | TRUE | Create YYYYMMDD dated subfolder |
| `segment_names` | Optional | auto or comma-separated | auto | Custom segment names |
| `save_model` | Optional | TRUE/FALSE | TRUE | Save model object (.rds) |
| `project_name` | Optional | Any text | Segmentation Analysis | Project name |
| `analyst_name` | Optional | Any text | Analyst Name | Analyst name |
| `description` | Optional | Any text | - | Project description |
| `question_labels_file` | Optional | XLSX path or blank | - | Variable labels file (2 columns: variable, label) |

**Analysis Modes:**
- **Exploration Mode**: `k_fixed` = blank. System tests k_min to k_max and recommends best k
- **Final Run Mode**: `k_fixed` = specific number (e.g., 4). System creates final segments

---

## 7. Quick Reference Tables

### Question Types (Survey Structure)

| Type | Purpose | Scale Required | Example |
|------|---------|----------------|---------|
| Single | Single-select categorical | No | "Select your age group" |
| Multiple | Multi-select categorical | No | "Select all brands you know" |
| Rating | Numeric scale | Yes (Min, Max) | "Rate satisfaction 1-10" |
| NPS | Net Promoter Score (0-10) | Yes (0, 10) | "Likelihood to recommend 0-10" |
| Grid | Matrix of rating questions | Yes (Min, Max) | "Rate each feature 1-5" |
| Numeric | Open-ended numeric | No | "Number of employees" |
| Text | Open-ended text | No | "Additional comments" |

### Composite Calculation Types

| Type | Purpose | Weights | Formula | Example Use |
|------|---------|---------|---------|-------------|
| Mean | Simple average | Not used | (Q1+Q2+Q3)/3 | Equal-weight satisfaction index |
| WeightedMean | Weighted average | Required | (Q1×W1 + Q2×W2)/ΣW | Importance-weighted satisfaction |
| Sum | Total score | Not used | Q1+Q2+Q3 | Cumulative feature usage score |

### Significance Testing

| Alpha | Confidence Level | Interpretation | Typical Use |
|-------|-----------------|----------------|-------------|
| 0.10 | 90% | Liberal (more sensitive) | Exploratory analysis |
| 0.05 | 95% | Standard | Most research |
| 0.01 | 99% | Conservative | Medical/critical decisions |

### Minimum Base Sizes

| Context | Typical Minimum | Rationale |
|---------|----------------|-----------|
| Significance testing | 30 | Statistical power requirements |
| Percentage reporting | 20 | Sampling error considerations |
| Detailed segmentation | 50-100 | Reliable profiling |
| Complex analysis | 100+ | Multivariate stability |

### Outlier Detection Methods

| Method | Threshold | Best For | Limitations |
|--------|-----------|----------|-------------|
| Z-score | 3.0 | Univariate outliers, simple | Assumes normality |
| Mahalanobis | Chi-square (α=0.001) | Multivariate outliers | Computationally intensive |

### Missing Data Handling

| Method | Pros | Cons | When to Use |
|--------|------|------|-------------|
| Listwise deletion | Simple, unbiased if MCAR | Reduces sample size | <5% missing |
| Mean imputation | Preserves sample size | Underestimates variance | 5-15% missing, exploratory |
| Median imputation | Robust to outliers | Underestimates variance | Skewed distributions |
| Refuse | Stops analysis | Forces data cleaning | Ensure data quality |

### Variable Selection Metrics

| Metric | Purpose | Typical Threshold |
|--------|---------|-------------------|
| Variance | Exclude low-variance vars | >0.1 (standardized) |
| Correlation | Remove redundant vars | <0.8 between pairs |
| Factor loading | Identify key dimensions | >0.5 on primary factor |

---

## Best Practices

### General Configuration

1. **File Paths**
   - Use relative paths when possible (relative to config file location)
   - Use forward slashes (/) for cross-platform compatibility
   - Avoid spaces in file names

2. **Naming Conventions**
   - Question codes: Uppercase, no spaces (Q1, SAT_01, COMP_OVERALL)
   - Composite codes: Start with COMP_ prefix
   - Wave IDs: Short and consistent (W1, W2 or Q1_2024, Q2_2024)

3. **Documentation**
   - Always fill in descriptive names and labels
   - Use SectionLabel to organize composite metrics
   - Document custom filters and derived metrics

### Analysis-Specific

#### Crosstabs
- Start with basic settings, add complexity gradually
- Use create_index_summary=TRUE for executive reporting
- Set minimum_base=30 for reliable significance testing
- Enable bonferroni_correction when testing many segments

#### Tracker
- Ensure weight variable has same name across all waves
- Map questions explicitly in Question_Mapping, even if codes unchanged
- Test with 2 waves before adding more
- Use banner breakouts only when needed (impacts file size)

#### Confidence Analysis
- Start with MOE only, add Bootstrap/Bayesian as needed
- Use Wilson intervals for small samples (<100)
- Set Bootstrap_Iterations=5000 for balance of speed/accuracy
- Enable Multiple_Comparison_Adjustment when analyzing >10 questions

#### Segmentation
- Run Exploration mode first to determine optimal k
- Use 5-15 clustering variables (more ≠ better)
- Always standardize=TRUE unless variables already on same scale
- Enable outlier_detection for final run to identify unusual respondents
- Set nstart=50-100 for stable results

---

## Troubleshooting

### Common Issues

**Issue:** "Configuration file not found"
- **Solution:** Check file path is correct (absolute or relative to working directory)

**Issue:** "Required setting missing"
- **Solution:** Check spelling of setting names (case-sensitive in some modules)

**Issue:** "Question code not found in data"
- **Solution:** Verify question codes match exactly between config and data file

**Issue:** "Significance letters not showing"
- **Solution:** Check show_significance=TRUE and sample sizes meet minimum_base

**Issue:** "Decimal separator not working"
- **Solution:** Excel displays based on system locale; text output uses your setting

**Issue:** "Composite shows NA in output"
- **Solution:** Check source questions have valid data; verify SourceQuestions spelling

**Issue:** "Weight variable not found"
- **Solution:** Check weight variable exists in data and spelling matches exactly

**Issue:** "Tracker: Question not found in wave"
- **Solution:** Verify question code in Question_Mapping matches data file column name

**Issue:** "Segment analysis: Too many outliers detected"
- **Solution:** Increase outlier_threshold or change outlier_method

---

## Additional Resources

### Documentation
- **USER_MANUAL.md** - Comprehensive user guide for all modules
- **MAINTENANCE.md** - Developer reference and technical documentation
- **TurasTabs_Composite_Scores_User_Manual.md** - Detailed composite scores guide
- **TurasTracker_User_Manual.md** - Complete tracker documentation
- **Index_Summary_User_Manual.md** - Index summary feature guide

### Templates
- All templates include example data (gray rows) showing typical usage
- Instructions sheet in each annotated template provides module-specific guidance
- Original templates (non-annotated) available for minimal file size

### Support
- Review troubleshooting section above
- Check module-specific documentation for detailed explanations
- Examine example data in templates for formatting guidance

---

**Version:** 1.0
**Last Updated:** December 2, 2025
**Maintained By:** TURAS Development Team
**License:** Proprietary - The Research LampPost

---

*This guide is automatically updated when templates are modified. Always refer to the latest version.*

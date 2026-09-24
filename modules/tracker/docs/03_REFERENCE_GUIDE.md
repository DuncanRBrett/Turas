---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tracker - Reference Guide

**Module Version:** 10.2 **Last Reviewed:** 24 May 2026 **Target
Audience:** Analysts, Project Managers, Technical Users

------------------------------------------------------------------------

## Table of Contents

1.  [Architecture Overview](#architecture-overview)
2.  [Data Flow](#data-flow)
3.  [Question Types](#question-types)
4.  [TrackingSpecs System](#trackingspecs-system)
5.  [Statistical Methods](#statistical-methods)
6.  [Report Formats](#report-formats)
7.  [Configuration Reference](#configuration-reference)
8.  [Glossary](#glossary)

------------------------------------------------------------------------

## Architecture Overview {#architecture-overview}

### Design Philosophy

Turas Tracker follows a modular pipeline architecture:

```         
Configuration → Wave Loading → Mapping → Validation → Calculation → Output
```

**Key Principles:** 1. **Separation of Concerns** - Each module handles
one stage 2. **Fail-Fast Validation** - Detect issues before computation
3. **Flexible Mapping** - Handle evolving questionnaires 4.
**Statistical Rigor** - Proper significance testing 5. **Multiple Output
Formats** - Serve different audiences

### Module Structure

```         
tracker/
├── run_tracker.R              # Main entry point & orchestration
├── run_tracker_gui.R          # Shiny GUI interface
└── lib/
    ├── 00_guard.R                 # TRS guard layer
    ├── constants.R                # Module constants
    ├── tracker_config_loader.R    # Load tracking configuration
    ├── wave_loader.R              # Load and weight wave data
    ├── question_mapper.R          # Map questions across waves
    ├── validation_tracker.R       # Comprehensive validation
    ├── trend_calculator.R         # Calculate trends & significance
    ├── banner_trends.R            # Banner breakout trends
    ├── formatting_utils.R         # Output formatting utilities
    ├── tracker_output.R           # Excel report generation
    └── tracker_dashboard_reports.R # Dashboard & sig matrix reports
```

### Dependency Graph

```         
run_tracker.R
├─→ tracker_config_loader.R
├─→ wave_loader.R
├─→ question_mapper.R
├─→ validation_tracker.R
│   └─→ question_mapper.R (get_question_metadata)
├─→ trend_calculator.R
│   └─→ question_mapper.R (extract_question_data)
├─→ banner_trends.R
│   └─→ trend_calculator.R (reuses calculation functions)
├─→ tracker_output.R
└─→ tracker_dashboard_reports.R
    └─→ tracker_config_loader.R (get_setting)
```

------------------------------------------------------------------------

## Data Flow {#data-flow}

### Complete Analysis Pipeline

```         
1. CONFIGURATION LOADING
   ├─ Load tracking_config.xlsx
   │  ├─ Waves sheet
   │  ├─ Settings sheet
   │  ├─ TrackedQuestions sheet
   │  └─ Banner sheet (optional)
   └─ Load question_mapping.xlsx
      └─ QuestionMap sheet

2. VALIDATION (Pre-Flight)
   ├─ Required columns exist
   ├─ No duplicate IDs
   ├─ Dates are valid
   └─ Question types recognized

3. DATA LOADING
   For each wave:
   ├─ Resolve file path
   ├─ Load CSV/Excel/SAV
   ├─ Clean data (comma decimals, DK→NA)
   ├─ Apply weighting
   └─ Calculate design effect

4. QUESTION MAPPING
   Build index:
   ├─ standard_to_wave (Q_SAT → W1 → Q10)
   ├─ wave_to_standard (W1:Q10 → Q_SAT)
   └─ question_metadata (types, TrackingSpecs)

5. VALIDATION (Post-Load)
   ├─ All waves loaded
   ├─ Weight variables exist
   ├─ Questions exist in data
   ├─ Banner variables exist
   └─ Sufficient base sizes

6. TREND CALCULATION
   For each tracked question:
   ├─ For each wave:
   │  ├─ Extract data using mapping
   │  ├─ Apply TrackingSpecs
   │  └─ Calculate metrics
   ├─ Calculate wave-to-wave changes
   ├─ Run significance tests
   └─ Generate trend indicators

7. OUTPUT GENERATION
   ├─ Determine report types
   ├─ Generate each requested format
   └─ Save Excel workbooks
```

------------------------------------------------------------------------

## Question Types {#question-types}

### Supported Types

| QuestionType | Description | Default Metric | TrackingSpecs Support |
|----|----|----|----|
| Rating | Numeric scales (1-5, 1-10) | Mean | Full |
| NPS | Net Promoter Score (0-10) | NPS score | Full |
| Single_Response | Single choice questions | \% by option | Selective |
| Multi_Mention | Select all that apply | \% per option | Full |
| Composite | Derived from other questions | Mean | Full |

### Type Normalization

The system accepts various spellings and normalizes them:

| Input                          | Normalized To |
|--------------------------------|---------------|
| Single_Response, SingleChoice  | single_choice |
| Multi_Mention, MultiChoice     | multi_choice  |
| Rating, Likert, Index, Numeric | rating        |
| NPS                            | nps           |
| Composite                      | composite     |

------------------------------------------------------------------------

## TrackingSpecs System {#trackingspecs-system}

### Overview

TrackingSpecs allows custom metric specification per question. Add a
`TrackingSpecs` column to question_mapping.xlsx.

**Syntax:** Comma-separated list of metric specifications

**Example:**

```         
TrackingSpecs: mean,top2_box,range:9-10
```

### Available Specifications

#### Rating Questions

| Spec           | Description               | Example Output    |
|----------------|---------------------------|-------------------|
| `mean`         | Average rating            | Mean: 8.2         |
| `top_box`      | \% at the top scale point | Top Box: 45%     |
| `top2_box`     | \% at the top 2 points    | Top 2 Box: 72%    |
| `top3_box`     | \% at the top 3 points    | Top 3 Box: 85%    |
| `bottom_box`   | \% at the bottom point    | Bottom Box: 5%    |
| `bottom2_box`  | \% at the bottom 2 points | Bottom 2 Box: 8%  |
| `range:X-Y`    | \% in custom range        | \% 9-10: 52%      |
| `distribution` | \% for each value         | Full distribution |

The top and bottom boxes are points on the question's scale, read from the
Index_Weight column of the wave's StructureFile. They are never read from
the answers, so a wave where nobody chose the top point shows 0%. A question
with a box spec and no scale in its StructureFile is refused with
`CFG_BOX_SCALE_UNKNOWN`; name the box with `range:X-Y` instead. Composites
have no scale points (a composite score is a row mean), so use `range:X-Y`
for them.

#### Multi-Mention Questions

**Binary Mode (0/1 data):**

| Spec         | Description                    |
|--------------|--------------------------------|
| `auto`       | Auto-detect all binary columns |
| `option:COL` | Track specific column          |
| `any`        | \% mentioning at least one     |
| `count_mean` | Mean number mentioned          |

**Category Mode (text data):**

| Spec            | Description               |
|-----------------|---------------------------|
| `category:TEXT` | Track specific text value |

#### NPS Questions

| Spec             | Description              |
|------------------|--------------------------|
| `nps_score`      | Net Promoter Score       |
| `promoters_pct`  | \% Promoters (9-10)      |
| `passives_pct`   | \% Passives (7-8)        |
| `detractors_pct` | \% Detractors (0-6)      |
| `full`           | All components (default) |

#### Composite Questions

Same as Rating after composite score calculation.

### Defaults (TrackingSpecs blank)

| Question Type   | Default Behavior |
|-----------------|------------------|
| Rating          | mean             |
| NPS             | full             |
| Single_Response | All categories   |
| Multi_Mention   | auto             |
| Composite       | mean             |

------------------------------------------------------------------------

## Statistical Methods {#statistical-methods}

Every formula below is the one in the code (`lib/statistical_core.R`,
`lib/trend_significance.R`) and is checked against an independent
calculation in `tests/testthat/test_reference_statistics.R`.

### Effective Base (Kish)

**Purpose:** The base every significance test is sized on. Weighting
spends sample, so a weighted wave of 500 tests like a smaller simple
random sample.

**Formula (over the respondents who answered):**

```         
n_eff = (sum of w)^2 / (sum of w^2)
DEFF  = n / n_eff          (n = unweighted count)
```

**Notes:** Grossing the weights to a population total leaves `n_eff`, every
share, mean and SD unchanged; only the weighted total moves. `n_eff` is not
rounded. A test runs only when both waves have `n_eff >= minimum_base`
(default 30); otherwise no arrow is shown, and the Dashboard and Sig
Matrix show an en dash for "not tested".

**Interpretation:** DEFF = 1.0: equal weights. DEFF 1.1-1.3: moderate.
DEFF 1.5-2.0: high (the effective base is a half to two thirds of the
count). DEFF above 2.0: review the weighting.

### Weighted Mean and SD

```         
mean = sum(w x) / sum(w)
SD   = sqrt( [sum(w (x - mean)^2) / sum(w)] * n_eff / (n_eff - 1) )
```

The SD is the unbiased estimator for survey (reliability) weights. It
equals `sd()` when every weight is 1, matches
`stats::cov.wt(method = "unbiased")`, and is the formula the tabs v2
Tracking tab uses. The mean's confidence interval is
`mean +/- z(1 - alpha/2) * SD / sqrt(n_eff)`.

### Z-Test for Proportions

**Use Case:** Test if percentage changed significantly between waves.

**Formula (n1, n2 are the effective bases):**

```         
p_pool = (p1 * n1 + p2 * n2) / (n1 + n2)
SE = sqrt(p_pool * (1 - p_pool) * (1/n1 + 1/n2))
z = (p2 - p1) / SE
p_value = 2 * Phi(-|z|)
```

Used for single-choice shares, top / bottom boxes, `range:` and `box:`
metrics, multi-mention options and any-mention.

### Welch T-Test for Means

**Use Case:** Test if a mean (rating or composite) changed significantly
between waves.

**Formula (n1, n2 are the effective bases, s1, s2 the SDs above):**

```         
v1 = s1^2 / n1,   v2 = s2^2 / n2
SE = sqrt(v1 + v2)
t  = (mean2 - mean1) / SE
df = (v1 + v2)^2 / (v1^2 / (n1 - 1) + v2^2 / (n2 - 1))
p_value = 2 * t_dist(-|t|, df)
```

Each wave keeps its own variance, so a wave with more spread is not
averaged with a steadier one. This matches `t.test(var.equal = FALSE)`.
The trend sheets, Trend Dashboard and Significance Matrix all run this
test (since 24 Sep 2026; it replaced a pooled-variance test). The tabs v2
Tracking tab uses the same standard error but compares it with the normal
curve instead of the t distribution, a difference of about 2.00 against
1.96 at the minimum base.

### Z-Test for NPS

NPS = 100 * (p_promoters - p_detractors), with promoters 9-10 and
detractors 0-6. Its variance is the multinomial closed form, which keeps
the negative covariance between the two shares:

```         
Var(NPS) = 10000 * ((p_p + p_d) - (p_p - p_d)^2) / n_eff
z = (NPS2 - NPS1) / sqrt(Var1 + Var2)
```

### Bases and Missing Answers

- Single choice: every non-missing answer, "don't know" included.
- Rating, NPS and composite: an option flagged `ExcludeFromIndex = Y` in
  the StructureFile (a numeric 99, or text "Don't know") is dropped from
  the mean, the NPS and the boxes.
- Multi-mention: the respondents who answered the question (any of its
  option columns holds a value); people routed past it are not in the
  base.

### Multiple Comparisons

No correction (Bonferroni, Holm, FDR) is applied; each wave pair is
tested on its own at `alpha`.

------------------------------------------------------------------------

## Report Formats {#report-formats}

### Detailed Report

**Structure:** - Summary sheet - Overview of all questions - One sheet
per question - Full trend tables - Metadata sheet - Analysis parameters

**Question Sheet Layout:**

```         
Q01: Brand Awareness (Single_Response)

                Wave 1      Wave 2      Trend
                Q1 2024     Q2 2024
Base (n=)
  Unweighted    500         500
  Weighted      500         500
  Effective     450         455

Brand A    %    45.2        48.1        ↑
Brand B    %    30.4        31.2        →
```

### Wave History Report

**Structure:** - One sheet per segment (Total, then banners) - One row
per question/metric - Columns: QuestionCode \| Question \| Type \| Wave1
\| Wave2 \| ...

**Layout:**

```         
QuestionCode | Question     | Type      | W1  | W2  | W3
Q38          | Satisfaction | Mean      | 8.2 | 8.4 | 8.6
Q38          | Satisfaction | Top 2 Box | 72  | 75  | 78
```

### Dashboard Report

**Structure:** - Executive summary with all metrics - Status indicators
(Good/Stable/Watch/Alert) - Optional significance matrices

### Significance Matrix Report

**Structure:** - One sheet per question - Matrix of all wave-pair
comparisons - Color-coded significance

------------------------------------------------------------------------

## Configuration Reference {#configuration-reference}

### tracking_config.xlsx Sheets

| Sheet            | Purpose               | Required |
|------------------|-----------------------|----------|
| Waves            | Wave definitions      | Yes      |
| Settings         | Analysis parameters   | Yes      |
| TrackedQuestions | Questions to track    | Yes      |
| Banner           | Demographic breakouts | No       |

### question_mapping.xlsx Sheets

| Sheet       | Purpose                 | Required |
|-------------|-------------------------|----------|
| QuestionMap | Question codes per wave | Yes      |

### Key Settings

| Setting | Default | Description |
|---------------------|---------------------|------------------------------|
| project_name | (required) | Project title |
| question_mapping_file | (auto-detected) | Path to question mapping file (filename, relative, or absolute) |
| report_types | detailed | Comma-separated: detailed,wave_history,dashboard,sig_matrix,tracking_crosstab |
| alpha | 0.05 | Significance level for every wave-on-wave test; reports state 1 - alpha as the confidence |
| minimum_base | 30 | Smallest effective base (Kish) that is tested; a smaller pair shows no arrow |
| decimal_places_ratings | 1 | Decimal places for means |
| decimal_places_percents | 0 | Decimal places for percentages |
| decimal_separator | . | Period or comma |
| show_significance | TRUE | Show significance indicators |

------------------------------------------------------------------------

## Glossary {#glossary}

| Term                 | Definition                                          |
|------------------------|-----------------------------------------------|
| Wave                 | A single data collection period in a tracking study |
| Banner               | Demographic breakout variable (Gender, Age, etc.)   |
| TrackingSpecs        | Custom metric specifications per question           |
| Design Effect (DEFF) | Weight variance impact on effective sample size     |
| Top Box              | Percentage at the top point(s) of the scale         |
| NPS                  | Net Promoter Score (% Promoters - % Detractors)     |
| Composite            | Derived metric combining multiple questions         |
| Multi-Mention        | Select-all-that-apply question type                 |
| Trend Indicator      | Symbol showing direction of change (↑↓→)            |
| Effective N          | Sample size adjusted for weighting                  |

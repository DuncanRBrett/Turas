---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tracker - Reference Guide

**Version:** 10.0 **Last Updated:** 22 December 2025 **Target
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
| `top_box`      | \% giving highest value   | Top Box: 45%      |
| `top2_box`     | \% giving top 2 values    | Top 2 Box: 72%    |
| `top3_box`     | \% giving top 3 values    | Top 3 Box: 85%    |
| `bottom_box`   | \% giving lowest value    | Bottom Box: 5%    |
| `bottom2_box`  | \% giving bottom 2 values | Bottom 2 Box: 8%  |
| `range:X-Y`    | \% in custom range        | \% 9-10: 52%      |
| `distribution` | \% for each value         | Full distribution |

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

### Z-Test for Proportions

**Use Case:** Test if percentage changed significantly between waves.

**Formula:**

```         
p_pool = (p₁×n₁ + p₂×n₂) / (n₁ + n₂)
SE = √(p_pool × (1 - p_pool) × (1/n₁ + 1/n₂))
z = (p₂ - p₁) / SE
p_value = 2 × Φ(-|z|)
```

**Assumptions:** - Independent samples - Sample sizes ≥ 30 recommended -
Random sampling

### Welch's T-Test for Means

**Use Case:** Test if mean rating changed significantly between waves.

**Formula:**

```         
SE = √(s₁²/n₁ + s₂²/n₂)
t = (μ₂ - μ₁) / SE
df = (s₁²/n₁ + s₂²/n₂)² / ((s₁²/n₁)²/(n₁-1) + (s₂²/n₂)²/(n₂-1))
p_value = 2 × t_dist(-|t|, df)
```

**Why Welch's:** - Doesn't assume equal variances - More robust to
unequal sample sizes

### Design Effect (DEFF)

**Purpose:** Adjust for weighting impact on effective sample size.

**Formula:**

```         
cv = σ(weights) / μ(weights)
DEFF = 1 + cv²
n_effective = n_weighted / DEFF
```

**Interpretation:** - DEFF = 1.0: No impact (equal weights) - DEFF =
1.1-1.3: Moderate (10-30% reduction) - DEFF = 1.5-2.0: High (33-50%
reduction) - DEFF \> 2.0: Very high (review weighting)

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
| report_types | detailed | Comma-separated: detailed,wave_history,dashboard,sig_matrix |
| confidence_level | 0.95 | Statistical confidence |
| min_base_size | 30 | Minimum n for sig testing |
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
| Top Box              | Percentage giving highest rating value(s)           |
| NPS                  | Net Promoter Score (% Promoters - % Detractors)     |
| Composite            | Derived metric combining multiple questions         |
| Multi-Mention        | Select-all-that-apply question type                 |
| Trend Indicator      | Symbol showing direction of change (↑↓→)            |
| Effective N          | Sample size adjusted for weighting                  |

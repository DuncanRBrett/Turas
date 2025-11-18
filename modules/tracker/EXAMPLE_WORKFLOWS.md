# Turas Tracker - Example Workflows

**Version:** 1.0
**Last Updated:** 2025-11-18
**Target Audience:** All Users

---

## Table of Contents

1. [Workflow 1: Quarterly Brand Tracking (Basic)](#workflow-1-quarterly-brand-tracking-basic)
2. [Workflow 2: Customer Satisfaction Tracking with NPS](#workflow-2-customer-satisfaction-tracking-with-nps)
3. [Workflow 3: Tracking with Question Code Changes](#workflow-3-tracking-with-question-code-changes)
4. [Workflow 4: Multi-Banner Demographic Tracking](#workflow-4-multi-banner-demographic-tracking)
5. [Workflow 5: Weighted Tracking Study](#workflow-5-weighted-tracking-study)
6. [Workflow 6: Adding New Waves to Existing Tracker](#workflow-6-adding-new-waves-to-existing-tracker)
7. [Workflow 7: Composite Metric Tracking](#workflow-7-composite-metric-tracking)
8. [Workflow 8: Integration with Turas Tabs](#workflow-8-integration-with-turas-tabs)

---

## Workflow 1: Quarterly Brand Tracking (Basic)

### Scenario

You run a quarterly brand tracking study measuring:
- Brand awareness (unaided and aided)
- Brand consideration
- Brand preference
- Purchase intent

You have 4 quarters of data and want to identify trends.

### Step 1: Organize Your Data

**Directory Structure:**
```
brand_tracking/
├── data/
│   ├── Q1_2024.csv
│   ├── Q2_2024.csv
│   ├── Q3_2024.csv
│   └── Q4_2024.csv
├── config/
│   └── tracking_config.xlsx
└── output/
```

**Q1_2024.csv (500 respondents):**
```
RespondentID,Q1_Unaided,Q2_Aided,Q3_Consideration,Q4_Preference,Q5_PurchaseIntent
1,Brand A,Brand A,Brand A,Brand A,1
2,None,Brand B,Brand B,Brand B,0
3,Brand C,Brand C,Brand C,Brand C,1
...
```

**Each Quarter Same Structure:**
- Same question codes
- Same response options
- Similar sample size (~500 per wave)

### Step 2: Create Configuration File

**config/tracking_config.xlsx**

**Sheet 1: Waves**
```
WaveID | WaveName       | DataFile      | FieldworkStart | FieldworkEnd  | WeightVariable
W1     | Q1 2024        | Q1_2024.csv   | 2024-01-01     | 2024-01-15    | NA
W2     | Q2 2024        | Q2_2024.csv   | 2024-04-01     | 2024-04-15    | NA
W3     | Q3 2024        | Q3_2024.csv   | 2024-07-01     | 2024-07-15    | NA
W4     | Q4 2024        | Q4_2024.csv   | 2024-10-01     | 2024-10-15    | NA
```

**Sheet 2: TrackedQuestions**
```
QuestionCode       | QuestionText                  | QuestionType
Q1_Unaided         | Brand Awareness (Unaided)     | proportion
Q2_Aided           | Brand Awareness (Aided)       | proportion
Q3_Consideration   | Brand Consideration           | proportion
Q4_Preference      | Brand Preference              | proportion
Q5_PurchaseIntent  | Purchase Intent (0/1)         | proportion
```

**Sheet 3: Banner**
```
BreakVariable | BreakLabel
Total         | Total
```

**Sheet 4: Settings**
```
SettingName         | SettingValue
project_name        | 2024 Brand Tracking Study
output_file         | output/Brand_Tracking_2024.xlsx
confidence_level    | 0.95
min_base_size       | 30
trend_significance  | TRUE
```

### Step 3: Run Analysis

```r
# Load Turas
source("/path/to/Turas/turas.R")
turas_load("tracker")

# Set working directory
setwd("/path/to/brand_tracking")

# Run tracker (no question mapping needed - codes consistent)
result <- run_tracker(
  tracking_config_path = "config/tracking_config.xlsx",
  question_mapping_path = NA,  # Not needed - same codes across waves
  data_dir = "data/"
)

cat("Analysis complete! Output:", result, "\n")
```

### Step 4: Interpret Results

**Brand_Tracking_2024.xlsx - Summary Sheet:**

```
2024 BRAND TRACKING - SUMMARY
Generated: 2024-10-16 10:30:00

Question                    Q1      Q2      Trend   Q3      Trend   Q4      Trend
                           2024    2024            2024            2024

Brand Awareness (Unaided)
  Brand A              %   42%     45%     →       48%     →       52%     ↑
  Brand B              %   28%     30%     →       32%     →       33%     →
  Brand C              %   18%     16%     →       14%     →       11%     ↓
  None                 %   12%     9%      →       6%      →       4%      →

Brand Preference
  Brand A              %   38%     40%     →       43%     →       47%     ↑
  Brand B              %   32%     33%     →       34%     →       35%     →
  Brand C              %   20%     18%     →       16%     ↓       13%     →

Purchase Intent       %   45%     48%     →       52%     →       56%     ↑
```

**Key Insights:**

1. **Brand A Growing:**
   - Unaided awareness: 42% → 52% over year (significant increase in Q4)
   - Preference: 38% → 47% (significant increase in Q4)
   - Clear upward momentum

2. **Brand C Declining:**
   - Unaided awareness: 18% → 11% (significant drop in Q4)
   - Preference: 20% → 13% (significant drop in Q3)
   - Concerning downward trend

3. **Brand B Stable:**
   - Metrics flat across all quarters
   - Maintaining position but not growing

4. **Purchase Intent Rising:**
   - 45% → 56% over year (significant increase in Q4)
   - Category growth or Brand A effect?

**Action Items:**
- Investigate Brand A success factors (campaigns, product changes?)
- Analyze Brand C decline (competitive pressure, quality issues?)
- Monitor Brand B - risk of stagnation

---

## Workflow 2: Customer Satisfaction Tracking with NPS

### Scenario

Monthly customer satisfaction tracking measuring:
- Overall satisfaction (1-5 scale)
- Net Promoter Score (0-10 scale)
- Service quality (1-5 scale)
- Value for money (1-5 scale)

You have 6 months of data (Jan-Jun 2024).

### Step 1: Prepare Data

**Data Structure (each month same):**

```
# satisfaction_jan.csv
CustomerID,Segment,Q1_OverallSat,Q2_NPS,Q3_ServiceQuality,Q4_Value
1001,Enterprise,5,10,5,4
1002,SMB,4,9,4,4
1003,Consumer,3,7,3,3
...
```

### Step 2: Create Configuration

**tracking_config.xlsx - Waves:**
```
WaveID | WaveName    | DataFile              | FieldworkStart | FieldworkEnd
W1     | January     | satisfaction_jan.csv  | 2024-01-01     | 2024-01-31
W2     | February    | satisfaction_feb.csv  | 2024-02-01     | 2024-02-29
W3     | March       | satisfaction_mar.csv  | 2024-03-01     | 2024-03-31
W4     | April       | satisfaction_apr.csv  | 2024-04-01     | 2024-04-30
W5     | May         | satisfaction_may.csv  | 2024-05-01     | 2024-05-31
W6     | June        | satisfaction_jun.csv  | 2024-06-01     | 2024-06-30
```

**TrackedQuestions:**
```
QuestionCode        | QuestionText                      | QuestionType
Q1_OverallSat       | Overall Satisfaction (1-5)        | rating
Q2_NPS              | Net Promoter Score (0-10)         | nps
Q3_ServiceQuality   | Service Quality (1-5)             | rating
Q4_Value            | Value for Money (1-5)             | rating
```

**Banner (for demographic analysis):**
```
BreakVariable | BreakLabel
Total         | Total
Segment       | Customer Segment
```

**Settings:**
```
SettingName          | SettingValue
project_name         | H1 2024 Customer Satisfaction Tracking
output_file          | Customer_Sat_H1_2024.xlsx
confidence_level     | 0.95
min_base_size        | 50
decimal_places_mean  | 2
```

### Step 3: Run Analysis with Banner

```r
source("/path/to/Turas/turas.R")
turas_load("tracker")

result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA,
  data_dir = "data/",
  use_banners = TRUE  # Enable banner analysis by segment
)
```

### Step 4: Interpret Results

**Customer_Sat_H1_2024.xlsx - Q2_NPS Sheet:**

```
Net Promoter Score (0-10)

TOTAL
            Jan     Feb     Trend   Mar     Trend   Apr     Trend   May     Trend   Jun     Trend
Base (n=)   1000    1000            1000            1000            1000            1000

% Promoters 35%     38%     →       42%     →       45%     →       48%     →       52%     ↑
% Passives  40%     40%     →       38%     →       35%     →       33%     →       30%     →
% Detractors 25%    22%     →       20%     →       20%     →       19%     →       18%     →
NPS Score   10      16      →       22      →       25      →       29      →       34      ↑

BY SEGMENT
                January         February        March           April           May             June
            Ent  SMB  Con   Ent  SMB  Con   Ent  SMB  Con   Ent  SMB  Con   Ent  SMB  Con   Ent  SMB  Con
Base (n=)   300  400  300   300  400  300   300  400  300   300  400  300   300  400  300   300  400  300

NPS Score   25   10   -5    28   12   0     32   15   5     35   18   8     38   22   12    42   25   15
Trend                       →    →    →     →    →    →     →    →    →     →    →    →     →    →    →
```

**Key Insights:**

1. **Overall NPS Improving:**
   - January: 10 → June: 34 (significant increase in June)
   - Consistent month-over-month improvement
   - Promoters increasing (35% → 52%), Detractors decreasing (25% → 18%)

2. **Segment Patterns:**
   - **Enterprise:** Highest NPS (42 in June), steady growth
   - **SMB:** Moderate NPS (25 in June), improving
   - **Consumer:** Lowest NPS (15 in June) but showing biggest improvement rate

3. **Detractor Reduction:**
   - Overall detractors down from 25% to 18%
   - Suggests service quality improvements effective

**Action Items:**
- Understand what drove June surge in promoters
- Focus on converting SMB passives to promoters
- Continue improving consumer experience (highest growth potential)

---

## Workflow 3: Tracking with Question Code Changes

### Scenario

Your brand tracking study restructured questionnaire between Wave 2 and Wave 3:
- Questions renumbered
- Some questions reworded slightly
- New questions added

You need to track metrics despite these changes.

### Step 1: Identify Question Changes

**Wave 1 & 2 Structure:**
```
Q1_BrandAwareness
Q2_Consideration
Q3_Preference
Q4_Satisfaction
```

**Wave 3 & 4 Structure (after restructure):**
```
Q01_Aware_Unaided    # Same as old Q1_BrandAwareness
Q02_Consideration    # Same as old Q2_Consideration
Q03_BrandPref        # Same as old Q3_Preference
Q04_OverallSat       # Same as old Q4_Satisfaction
Q05_NewMetric        # NEW question
```

### Step 2: Create Question Mapping

**question_mapping.xlsx - QuestionMap Sheet:**

```
QuestionCode        | QuestionType | QuestionText                  | W1                | W2                | W3                  | W4
Q01_BrandAwareness  | proportion   | Brand Awareness (Unaided)     | Q1_BrandAwareness | Q1_BrandAwareness | Q01_Aware_Unaided   | Q01_Aware_Unaided
Q02_Consideration   | proportion   | Brand Consideration           | Q2_Consideration  | Q2_Consideration  | Q02_Consideration   | Q02_Consideration
Q03_Preference      | proportion   | Brand Preference              | Q3_Preference     | Q3_Preference     | Q03_BrandPref       | Q03_BrandPref
Q04_Satisfaction    | rating       | Overall Satisfaction (1-5)    | Q4_Satisfaction   | Q4_Satisfaction   | Q04_OverallSat      | Q04_OverallSat
Q05_NewMetric       | rating       | New Quality Metric (1-5)      | NA                | NA                | Q05_NewMetric       | Q05_NewMetric
```

**Key Points:**
- **QuestionCode:** Standardized code used in tracking_config.xlsx
- **W1, W2, W3, W4:** Actual column names in each wave's data file
- **NA:** Question not asked in that wave

### Step 3: Create Tracking Configuration

**tracking_config.xlsx - TrackedQuestions:**

```
QuestionCode        | QuestionText                  | QuestionType
Q01_BrandAwareness  | Brand Awareness (Unaided)     | proportion
Q02_Consideration   | Brand Consideration           | proportion
Q03_Preference      | Brand Preference              | proportion
Q04_Satisfaction    | Overall Satisfaction (1-5)    | rating
Q05_NewMetric       | New Quality Metric (1-5)      | rating
```

**Note:** Use standardized QuestionCode, not wave-specific codes!

### Step 4: Run Analysis with Mapping

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = "question_mapping.xlsx",  # ← Include mapping
  data_dir = "data/"
)
```

### Step 5: Interpret Results

**Results.xlsx - Q01_BrandAwareness Sheet:**

```
Brand Awareness (Unaided)
            Wave 1      Wave 2      Trend   Wave 3      Trend   Wave 4      Trend
            Q1 2024     Q2 2024             Q3 2024             Q4 2024
Base (n=)   500         500                 500                 500

Brand A %   42%         45%         →       48%         →       52%         ↑
Brand B %   30%         32%         →       33%         →       34%         →
Brand C %   18%         16%         →       14%         →       11%         ↓

Source: Wave 1-2 from Q1_BrandAwareness, Wave 3-4 from Q01_Aware_Unaided
```

**Q05_NewMetric Sheet:**

```
New Quality Metric (1-5)
            Wave 1  Wave 2  Wave 3      Trend   Wave 4      Trend
Base (n=)   —       —       500                 500

Mean Score  —       —       3.8                 4.0         →
Std Dev     —       —       1.1                 1.0

Note: Question introduced in Wave 3
```

**Key Benefits of Mapping:**
1. **Continuous Tracking:** Trends calculated despite code changes
2. **Historical Comparison:** Can compare across restructure
3. **Flexibility:** Easy to add/remove questions between waves
4. **Documentation:** Mapping file documents all changes

---

## Workflow 4: Multi-Banner Demographic Tracking

### Scenario

Track brand metrics across multiple demographic segments:
- Gender (Male, Female)
- Age Group (18-34, 35-54, 55+)
- Region (North, South, East, West)

Identify which segments showing growth/decline.

### Step 1: Ensure Data Includes Banner Variables

**wave1.csv:**
```
RespondentID,Gender,Age_Group,Region,Q1_Awareness,Q2_Consideration,Q3_Preference
1,Male,18-34,North,Brand A,Brand A,Brand A
2,Female,35-54,South,Brand B,Brand B,Brand B
3,Male,55+,East,Brand C,Brand C,Brand C
...
```

**All waves must include:** Gender, Age_Group, Region columns with consistent values.

### Step 2: Configure Banner Analysis

**tracking_config.xlsx - Banner Sheet:**

```
BreakVariable | BreakLabel
Total         | Total
Gender        | Gender
Age_Group     | Age Group
Region        | Region
```

**Waves Sheet:**
```
WaveID | WaveName  | DataFile   | FieldworkStart | FieldworkEnd
W1     | Wave 1    | wave1.csv  | 2024-01-15     | 2024-01-30
W2     | Wave 2    | wave2.csv  | 2024-04-15     | 2024-04-30
W3     | Wave 3    | wave3.csv  | 2024-07-15     | 2024-07-30
```

**TrackedQuestions:**
```
QuestionCode     | QuestionText          | QuestionType
Q1_Awareness     | Brand Awareness       | proportion
Q2_Consideration | Brand Consideration   | proportion
Q3_Preference    | Brand Preference      | proportion
```

### Step 3: Run with Banner Analysis

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA,
  data_dir = "data/",
  use_banners = TRUE  # ← Enable banner breakouts
)
```

### Step 4: Interpret Banner Results

**Results.xlsx - Q1_Awareness_Gender Sheet:**

```
Brand Awareness - By Gender

Brand A
                    Wave 1              Wave 2              Wave 3
                Male    Female      Male    Female      Male    Female
Base (n=)       250     250         250     250         250     250

Brand A    %    48%     36%         50%     40%         58%     46%
Trend                               →       →           ↑       ↑

Brand B    %    28%     32%         30%     34%         31%     35%
Trend                               →       →           →       →
```

**Q1_Awareness_Age_Group Sheet:**

```
Brand Awareness - By Age Group

Brand A
                Wave 1                      Wave 2                      Wave 3
            18-34   35-54   55+         18-34   35-54   55+         18-34   35-54   55+
Base (n=)   180     200     120         180     200     120         180     200     120

Brand A %   52%     40%     32%         55%     42%     34%         62%     48%     38%
Trend                                   →       →       →           ↑       ↑       →
```

**Key Insights from Banner Analysis:**

1. **Gender Differences:**
   - Males consistently higher awareness of Brand A (48% vs 36%)
   - Both genders showed significant increase in Wave 3
   - Gap narrowing over time (W1: 12pt gap → W3: 12pt gap maintained)

2. **Age Pattern:**
   - Younger respondents (18-34) highest awareness (62% in W3)
   - Significant increases for 18-34 and 35-54 in Wave 3
   - 55+ segment stable (no significant change)

3. **Strategic Implications:**
   - Brand A strongest among young males
   - Growth opportunity with older demographics
   - Consider targeted campaigns for 55+ segment

---

## Workflow 5: Weighted Tracking Study

### Scenario

Your tracking study data needs weighting to match population demographics. Each wave has different weight distributions due to sampling variations.

### Step 1: Prepare Data with Weights

**wave1.csv:**
```
RespondentID,Gender,Age,Q1_Awareness,Q2_Satisfaction,Weight
1,Male,25,Brand A,5,1.2
2,Female,45,Brand B,4,0.8
3,Male,60,Brand C,3,1.5
...
```

**Weight Explanation:**
- Weight > 1.0: Under-represented in sample (upweight)
- Weight < 1.0: Over-represented in sample (downweight)
- Average weight ≈ 1.0

### Step 2: Configure Weighting

**tracking_config.xlsx - Waves Sheet:**

```
WaveID | WaveName | DataFile   | FieldworkStart | FieldworkEnd | WeightVariable
W1     | Wave 1   | wave1.csv  | 2024-01-15     | 2024-01-30   | Weight
W2     | Wave 2   | wave2.csv  | 2024-04-15     | 2024-04-30   | Weight
W3     | Wave 3   | wave3.csv  | 2024-07-15     | 2024-07-30   | Weight
W4     | Wave 4   | wave4.csv  | 2024-10-15     | 2024-10-30   | Weight
```

**Key:** Specify WeightVariable = "Weight" (column name in data)

### Step 3: Run Analysis

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA
)
```

**Tracker automatically:**
1. Loads weight column from each wave
2. Applies weights to all calculations (means, proportions)
3. Calculates Design Effect (DEFF)
4. Uses effective sample size for significance testing

### Step 4: Understand Weighted Results

**Results.xlsx - Q2_Satisfaction Sheet:**

```
Overall Satisfaction (1-5 scale)

                Wave 1      Wave 2      Trend   Wave 3      Trend   Wave 4      Trend
Base (n=)
  Unweighted    500         500                 500                 500
  Weighted      500         500                 500                 500
  Effective     450         455                 448                 452
  DEFF          1.11        1.10                1.12                1.11

Mean Score      3.8         3.9         →       4.1         ↑       4.2         →
Std Dev         1.2         1.1                 1.0                 1.0
```

**Understanding the Bases:**

- **Unweighted:** Actual number of respondents (500)
- **Weighted:** Sum of weights ≈ sample size (500)
- **Effective:** Accounts for weight variance (450)
  - Effective < Weighted due to weighting impact
  - Used for significance testing
- **DEFF:** Design Effect = Weighted / Effective ≈ 1.11
  - DEFF = 1.0: No weighting impact
  - DEFF = 1.1: Moderate impact (10% reduction in effective n)
  - DEFF > 1.5: High impact (significant efficiency loss)

**Impact on Significance:**

```
Without weighting adjustment (wrong):
  Use n = 500 → overstates significance

With DEFF adjustment (correct):
  Use n_eff = 450 → appropriate significance
```

**Wave 2 → Wave 3 trend:**
- Mean increased 3.9 → 4.1
- Significant (↑) because increase meaningful relative to effective sample sizes
- If used unweighted n=500, would be even more significant (but wrong!)

---

## Workflow 6: Adding New Waves to Existing Tracker

### Scenario

You have a tracking study with 3 waves. Wave 4 data just became available. You want to add it to the existing analysis.

### Step 1: Current Setup

**Existing Configuration:**

```
tracking_config.xlsx - Waves:
W1 | Q1 2024 | wave1.csv | 2024-01-15
W2 | Q2 2024 | wave2.csv | 2024-04-15
W3 | Q3 2024 | wave3.csv | 2024-07-15
```

**Existing Output:**
- Previous results file: Brand_Tracking_Q1-Q3_2024.xlsx
- Shows trends through Q3

### Step 2: Add New Wave

**Update tracking_config.xlsx - Waves Sheet:**

```
WaveID | WaveName | DataFile   | FieldworkStart | FieldworkEnd
W1     | Q1 2024  | wave1.csv  | 2024-01-15     | 2024-01-30
W2     | Q2 2024  | wave2.csv  | 2024-04-15     | 2024-04-30
W3     | Q3 2024  | wave3.csv  | 2024-07-15     | 2024-07-30
W4     | Q4 2024  | wave4.csv  | 2024-10-15     | 2024-10-30  ← NEW ROW
```

**Update Settings if needed:**

```
SettingName  | SettingValue
output_file  | Brand_Tracking_Full_Year_2024.xlsx  ← Updated filename
```

**No other changes needed!**
- TrackedQuestions sheet unchanged
- Banner sheet unchanged
- Question mapping unchanged (if using)

### Step 3: Verify New Wave Data

**Check wave4.csv:**

```r
# Quick validation before running full analysis
library(readr)

wave4 <- read.csv("data/wave4.csv")

# Check sample size
nrow(wave4)  # Should be similar to previous waves (e.g., ~500)

# Check column names match previous waves
names(wave4)

# Check for required questions
required_cols <- c("Q1_Awareness", "Q2_Consideration", "Q3_Preference")
all(required_cols %in% names(wave4))  # Should be TRUE
```

### Step 4: Re-run Analysis

```r
source("/path/to/Turas/turas.R")
turas_load("tracker")

# Run with updated configuration (now includes W4)
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA
)
```

**Processing Output:**

```
================================================================================
TURASTACKER - MVT PHASE 2: TREND CALCULATION & OUTPUT
================================================================================
Started: 2024-10-16 10:30:00

[1/6] LOADING CONFIGURATION
Project: Brand Tracking Study
Waves: Q1 2024, Q2 2024, Q3 2024, Q4 2024  ← Now includes Q4!

[4/6] LOADING WAVE DATA
  Loading Wave W1: Q1 2024
    Loaded 500 records
  Loading Wave W2: Q2 2024
    Loaded 500 records
  Loading Wave W3: Q3 2024
    Loaded 500 records
  Loading Wave W4: Q4 2024  ← NEW
    Loaded 500 records  ← NEW

[7/8] CALCULATING TRENDS
Processing question: Q1_Awareness
  ✓ Trend calculated
...

Analysis complete!
```

### Step 5: Review Updated Results

**Brand_Tracking_Full_Year_2024.xlsx - Summary:**

```
                    Q1      Q2      Trend   Q3      Trend   Q4      Trend
Brand A        %    42%     45%     →       48%     →       52%     ↑      ← NEW
Brand B        %    30%     32%     →       33%     →       34%     →      ← NEW
```

**Now shows:**
- All 4 quarters
- Trends Q1→Q2, Q2→Q3, Q3→Q4
- Latest quarter (Q4) highlighted

**Key Benefits:**
- No data re-entry for old waves
- Consistent methodology across all waves
- Easy to add future waves (Q1 2025, Q2 2025, ...)

---

## Workflow 7: Composite Metric Tracking

### Scenario

You want to track a "Brand Health Index" that combines multiple metrics:
- Brand Health Index = Average of (Awareness + Consideration + Preference)

Track this composite metric alongside individual metrics.

### Step 1: Define Composite in Question Mapping

**question_mapping.xlsx - QuestionMap Sheet:**

```
QuestionCode        | QuestionType | QuestionText                      | CompositeFormula        | W1    | W2    | W3
Q1_Awareness        | proportion   | Brand Awareness                   |                         | Q1    | Q1    | Q1
Q2_Consideration    | proportion   | Brand Consideration               |                         | Q2    | Q2    | Q2
Q3_Preference       | proportion   | Brand Preference                  |                         | Q3    | Q3    | Q3
COMP_BrandHealth    | composite    | Brand Health Index (Composite)    | mean(Q1,Q2,Q3)          | —     | —     | —
```

**CompositeFormula:**
- `mean(Q1,Q2,Q3)` — Average of three proportion questions
- Calculated from raw data, not from percentages in output

### Step 2: Configure Composite Tracking

**tracking_config.xlsx - TrackedQuestions:**

```
QuestionCode        | QuestionText                      | QuestionType
Q1_Awareness        | Brand Awareness                   | proportion
Q2_Consideration    | Brand Consideration               | proportion
Q3_Preference       | Brand Preference                  | proportion
COMP_BrandHealth    | Brand Health Index                | composite
```

### Step 3: Run Analysis

```r
result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = "question_mapping.xlsx",
  use_banners = FALSE
)
```

### Step 4: Interpret Composite Results

**Results.xlsx - COMP_BrandHealth Sheet:**

```
Brand Health Index
Composite of: Brand Awareness + Brand Consideration + Brand Preference

                Wave 1      Wave 2      Trend   Wave 3      Trend
Base (n=)       500         500                 500

Index Score     38          40          →       44          ↑

Component Trends:
  Awareness     42%         45%         →       48%         →
  Consideration 38%         40%         →       43%         →
  Preference    34%         35%         →       41%         ↑

Interpretation:
- Overall brand health improved significantly in Wave 3
- Driven primarily by increase in Preference
- Awareness and Consideration also positive but stable
```

**Composite vs Individual Metrics:**

| Metric | Wave 1 | Wave 2 | Wave 3 | Pattern |
|--------|--------|--------|--------|---------|
| **Awareness** | 42% | 45% | 48% | Steady increase |
| **Consideration** | 38% | 40% | 43% | Steady increase |
| **Preference** | 34% | 35% | 41% | Spike in W3 |
| **Composite (Avg)** | 38 | 40 | 44 | Accelerating growth |

**Benefits of Composite Metrics:**
1. **Single Summary Number:** Easy to communicate
2. **Trend Detection:** May be significant when components aren't
3. **Balanced View:** Combines multiple dimensions
4. **Executive Reporting:** Simple KPI for dashboards

---

## Workflow 8: Integration with Turas Tabs

### Scenario

You run Tabs module for cross-tabulation each wave, then want to track specific Tabs metrics over time using Tracker.

**Use Case:**
- Run detailed crosstabs for each wave (brand × demographics)
- Extract key metrics from Tabs output
- Track those metrics across waves

### Step 1: Run Tabs for Each Wave

**Wave 1 Analysis:**

```r
# Load Turas
source("/path/to/Turas/turas.R")
turas_load("tabs")

# Run tabs for Wave 1
setwd("/path/to/wave1_project")
tabs_result_w1 <- run_crosstabs(
  config_file = "Tabs_Config_W1.xlsx",
  survey_structure_file = "Survey_Structure.xlsx"
)
# Output: Wave1_Crosstabs.xlsx
```

**Repeat for Wave 2, Wave 3, Wave 4:**

```r
# Wave 2
setwd("/path/to/wave2_project")
tabs_result_w2 <- run_crosstabs(...)
# Output: Wave2_Crosstabs.xlsx

# Wave 3
setwd("/path/to/wave3_project")
tabs_result_w3 <- run_crosstabs(...)
# Output: Wave3_Crosstabs.xlsx
```

### Step 2: Extract Metrics from Tabs Outputs

**Create data files for Tracker from Tabs results:**

**Method 1: Manual Extraction**

From each Wave's Tabs output, extract key metrics to CSV:

**tracking_data_wave1.csv:**
```
Metric,Value
BrandA_Awareness,42
BrandB_Awareness,30
BrandC_Awareness,18
BrandA_Preference,38
BrandB_Preference,32
BrandC_Preference,20
OverallSatisfaction,3.8
NPS,15
```

**tracking_data_wave2.csv, wave3.csv, wave4.csv:** Same structure

**Method 2: Programmatic Extraction (Recommended)**

```r
# Function to extract metrics from Tabs output
extract_tabs_metrics <- function(tabs_result, wave_id) {

  # Extract Brand A awareness from Q01 result
  q01 <- tabs_result$all_results[["Q01_Awareness"]]
  brand_a_row <- q01$table[q01$table$RowLabel == "Brand A" & q01$table$RowType == "Column %", ]
  brand_a_awareness <- as.numeric(brand_a_row$Total)

  # Extract other metrics similarly...

  # Create data frame
  metrics <- data.frame(
    Metric = c("BrandA_Awareness", "BrandB_Awareness", ...),
    Value = c(brand_a_awareness, brand_b_awareness, ...)
  )

  # Write to file
  write.csv(metrics, paste0("tracking_data_", wave_id, ".csv"), row.names = FALSE)

  return(metrics)
}

# Extract for all waves
metrics_w1 <- extract_tabs_metrics(tabs_result_w1, "wave1")
metrics_w2 <- extract_tabs_metrics(tabs_result_w2, "wave2")
metrics_w3 <- extract_tabs_metrics(tabs_result_w3, "wave3")
```

### Step 3: Configure Tracker

**tracking_config.xlsx:**

**Waves:**
```
WaveID | WaveName | DataFile                  | FieldworkStart
W1     | Wave 1   | tracking_data_wave1.csv   | 2024-01-15
W2     | Wave 2   | tracking_data_wave2.csv   | 2024-04-15
W3     | Wave 3   | tracking_data_wave3.csv   | 2024-07-15
```

**TrackedQuestions:**
```
QuestionCode         | QuestionText              | QuestionType
BrandA_Awareness     | Brand A Awareness         | rating
BrandB_Awareness     | Brand B Awareness         | rating
BrandA_Preference    | Brand A Preference        | rating
OverallSatisfaction  | Overall Satisfaction      | rating
NPS                  | Net Promoter Score        | rating
```

**Note:** Using "rating" type to track the numeric values extracted from Tabs.

### Step 4: Run Tracker

```r
turas_load("tracker")

result <- run_tracker(
  tracking_config_path = "tracking_config.xlsx",
  question_mapping_path = NA
)
```

### Step 5: Unified Reporting

**Now you have:**
1. **Detailed Tabs outputs** — Wave-by-wave cross-tabulation analysis
2. **Tracker summary** — Key metrics trended over time

**Tabs Output (Wave 3):**
- Detailed breakdown: Brand A awareness by Gender, Age, Region
- Significance testing within wave
- Full crosstabs with all response options

**Tracker Output:**
- Brand A awareness trend: W1 (42%) → W2 (45%) → W3 (48%)
- Trend indicators showing significant increases
- Comparison across all waves

**Benefits:**
- **Best of both worlds:** Detail (Tabs) + Trends (Tracker)
- **Consistent methodology:** Same Survey_Structure used by both
- **Efficient workflow:** Run Tabs routinely, consolidate with Tracker

---

## Common Patterns and Tips

### Pattern 1: Quarterly Business Reviews

```r
# Run tracker before each QBR
result <- run_tracker(
  tracking_config_path = "QBR_config.xlsx",
  question_mapping_path = NA
)

# Email results to stakeholders
library(blastula)
email <- compose_email(
  body = md("# Q4 2024 Tracking Results\n\nPlease find attached the latest tracking analysis.")
) %>%
  add_attachment(result)

smtp_send(email, to = "team@company.com", ...)
```

### Pattern 2: Automated Monthly Tracking

```r
# Scheduled script (cron job / Task Scheduler)
library(lubridate)

# Current month
current_month <- format(Sys.Date(), "%Y-%m")

# Add new wave to config
# (Assumes wave data file follows naming convention)

result <- run_tracker(
  tracking_config_path = "monthly_tracking_config.xlsx",
  question_mapping_path = NA,
  output_path = paste0("output/Tracking_", current_month, ".xlsx")
)

# Auto-email results
```

### Pattern 3: Year-over-Year Comparison

```r
# Configure waves for YoY comparison
# Q1 2023, Q2 2023, Q3 2023, Q4 2023
# Q1 2024, Q2 2024, Q3 2024, Q4 2024

# Trends calculated:
# Q1 2023 → Q2 2023 → Q3 2023 → Q4 2023 → Q1 2024 → Q2 2024 ...

# Manually compare:
# Q1 2024 vs Q1 2023
# Q2 2024 vs Q2 2023
# etc.
```

### Pattern 4: Segment Deep-Dive

```r
# Run overall tracking
result_overall <- run_tracker(
  tracking_config_path = "config_overall.xlsx",
  use_banners = FALSE
)

# Run banner analysis for key segments
result_banners <- run_tracker(
  tracking_config_path = "config_banners.xlsx",
  use_banners = TRUE
)

# Compare overall vs segment trends
```

---

## Troubleshooting Workflows

### Issue: Trends Not Significant Despite Large Changes

**Example:**
```
Wave 1: 45%
Wave 2: 50%  (5 percentage point increase)
Trend: → (stable, not significant!)
```

**Cause:** Small sample sizes

**Solution:**

```r
# Check sample sizes
# If n < 100 per wave, hard to detect 5pt change

# Options:
# 1. Increase sample size in future waves
# 2. Lower confidence level (0.90 instead of 0.95)
# 3. Accept that change may not be significant
# 4. Look for trend pattern across multiple waves
```

### Issue: Missing Data in Some Waves

**Example:**
```
Question Q05 exists in Wave 3 and 4, but not Wave 1 and 2
```

**Solution:**

```r
# In question_mapping.xlsx:
QuestionCode | W1  | W2  | W3      | W4
Q05          | NA  | NA  | Q5_New  | Q5_New

# Tracker will show:
# Wave 1: — (not available)
# Wave 2: — (not available)
# Wave 3: 3.8
# Wave 4: 4.0 (trend from W3)
```

### Issue: Different Sample Sizes Across Waves

**Example:**
```
Wave 1: n=500
Wave 2: n=300  (recruitment issues)
Wave 3: n=500
```

**This is OK!** Tracker handles different sample sizes correctly in significance testing.

**But consider:**
- Why did Wave 2 have lower n?
- Fielding issues?
- Seasonal variation?
- May affect power to detect trends in/out of Wave 2

---

## Next Steps

**After mastering these workflows:**

1. **Create Templates** — Save your configurations for reuse
2. **Automate** — Schedule regular tracking runs
3. **Integrate** — Combine with Tabs, Parser, other Turas modules
4. **Customize** — Add custom composite metrics for your business
5. **Scale** — Apply to multiple tracking studies

**Additional Resources:**
- USER_MANUAL.md — Complete feature reference
- TECHNICAL_DOCUMENTATION.md — Developer guide
- QUICK_START.md — 15-minute introduction

---

**Document Version:** 1.0
**Last Updated:** 2025-11-18

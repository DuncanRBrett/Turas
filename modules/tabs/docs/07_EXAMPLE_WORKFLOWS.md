---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Tabs - Example Workflows

**Version:** 10.0 **Date:** 22 December 2025

This document walks through complete examples of common analysis
scenarios. Each workflow shows the configuration files, data setup, and
expected output.

------------------------------------------------------------------------

## Workflow 1: Basic Brand Tracking Survey

### The Scenario

You've conducted a brand tracking survey with 500 respondents. You want
to analyze brand awareness and preference, broken out by gender and age
group.

### Step 1: Prepare Your Data

Your data file looks like this:

```         
RespondentID | Weight | Gender | Age_Group | Q01_Awareness | Q02_Preference
1            | 1.2    | Male   | 18-34     | Brand A       | Brand A
2            | 0.8    | Female | 35-54     | Brand B       | Brand B
3            | 1.0    | Male   | 55+       | Brand C       | Brand C
```

### Step 2: Set Up Survey Structure

**Questions Sheet:**

| QuestionCode | QuestionText                  | Variable_Type  | Columns |
|--------------|-------------------------------|----------------|---------|
| Q01          | Which brand are you aware of? | Single_Mention | 1       |
| Q02          | Which brand do you prefer?    | Single_Mention | 1       |
| Gender       | Gender                        | Single_Mention | 1       |
| Age_Group    | Age Group                     | Single_Mention | 1       |

**Options Sheet:**

| QuestionCode | OptionText | DisplayText      | ShowInOutput | DisplayOrder |
|--------------|------------|------------------|--------------|--------------|
| Q01          | Brand A    | Brand A          | Y            | 1            |
| Q01          | Brand B    | Brand B          | Y            | 2            |
| Q01          | Brand C    | Brand C          | Y            | 3            |
| Q01          | None       | Not aware of any | Y            | 4            |
| Q02          | Brand A    | Brand A          | Y            | 1            |
| Q02          | Brand B    | Brand B          | Y            | 2            |
| Q02          | Brand C    | Brand C          | Y            | 3            |
| Gender       | Male       | Male             | Y            | 1            |
| Gender       | Female     | Female           | Y            | 2            |
| Age_Group    | 18-34      | 18-34            | Y            | 1            |
| Age_Group    | 35-54      | 35-54            | Y            | 2            |
| Age_Group    | 55+        | 55+              | Y            | 3            |

### Step 3: Configure the Analysis

**Settings Sheet:**

| Setting                     | Value                       |
|-----------------------------|-----------------------------|
| structure_file              | Survey_Structure.xlsx       |
| output_subfolder            | Crosstabs                   |
| output_filename             | Brand_Tracking_Results.xlsx |
| apply_weighting             | TRUE                        |
| weight_variable             | Weight                      |
| show_frequency              | TRUE                        |
| show_percent_column         | TRUE                        |
| enable_significance_testing | TRUE                        |
| alpha                       | 0.05                        |
| significance_min_base       | 30                          |

**Selection Sheet:**

| QuestionCode | Include | UseBanner | BannerLabel | DisplayOrder | CreateIndex |
|--------------|---------|-----------|-------------|--------------|-------------|
| Total        | N       | Y         | Total       | 1            | N           |
| Gender       | Y       | Y         | Gender      | 2            | N           |
| Age_Group    | Y       | Y         | Age         | 3            | N           |
| Q01          | Y       | N         |             |              | N           |
| Q02          | Y       | N         |             |              | N           |

### Step 4: Run the Analysis

``` r
source("turas.R")
turas_load("tabs")
result <- run_tabs_analysis("path/to/brand_tracking")
```

### Expected Output

**Q01 - Awareness Sheet:**

```         
Which brand are you aware of?
                    Total   Male    Female  18-34   35-54   55+
Base (unweighted)   500     250     250     180     200     120
Base (weighted)     500     260     240     175     195     130

Brand A             40%     44%C    36%     45%G    38%     32%
Brand B             30%     28%     32%     28%     35%     25%
Brand C             22%     20%     24%     18%     20%     30%E
Not aware of any    8%      8%      8%      9%      7%      8%

Significance: Letter indicates significantly higher than that column
C=Female, G=Age 35-54, E=18-34
```

### Key Insights

Looking at this output, you can see that Brand A has 40% total
awareness, but awareness differs by demographics - Males (44%) are
significantly more aware than Females (36%). The younger age group
(18-34) has the highest Brand A awareness at 45%.

------------------------------------------------------------------------

## Workflow 2: Customer Satisfaction with NPS

### The Scenario

You've surveyed 1,000 customers about their satisfaction. You want to
measure overall satisfaction on a 5-point scale and calculate Net
Promoter Score, broken out by customer segment.

### Step 1: Data Structure

```         
CustomerID | Segment    | Q01_Satisfaction | Q02_NPS
1          | Enterprise | 5                | 10
2          | SMB        | 4                | 8
3          | Consumer   | 3                | 6
```

### Step 2: Survey Structure

**Questions Sheet:**

| QuestionCode | QuestionText                   | Variable_Type  | Columns |
|--------------|--------------------------------|----------------|---------|
| Q01          | Overall Satisfaction (1-5)     | Rating         | 1       |
| Q02          | Likelihood to recommend (0-10) | NPS            | 1       |
| Segment      | Customer Segment               | Single_Mention | 1       |

**Options Sheet:**

| QuestionCode | OptionText | DisplayText           | ShowInOutput | Index_Weight |
|---------------|---------------|---------------|---------------|---------------|
| Q01          | 1          | Very dissatisfied (1) | Y            | 1            |
| Q01          | 2          | Dissatisfied (2)      | Y            | 2            |
| Q01          | 3          | Neutral (3)           | Y            | 3            |
| Q01          | 4          | Satisfied (4)         | Y            | 4            |
| Q01          | 5          | Very satisfied (5)    | Y            | 5            |
| Segment      | Enterprise | Enterprise            | Y            |              |
| Segment      | SMB        | SMB                   | Y            |              |
| Segment      | Consumer   | Consumer              | Y            |              |

### Step 3: Configuration

**Settings Sheet:**

| Setting                     | Value                     |
|-----------------------------|---------------------------|
| structure_file              | Survey_Structure.xlsx     |
| output_filename             | Satisfaction_Results.xlsx |
| apply_weighting             | FALSE                     |
| show_percent_column         | TRUE                      |
| enable_significance_testing | TRUE                      |
| alpha                       | 0.05                      |
| decimal_places_ratings      | 2                         |

**Selection Sheet:**

| QuestionCode | Include | UseBanner | BannerLabel | DisplayOrder | CreateIndex |
|--------------|---------|-----------|-------------|--------------|-------------|
| Total        | N       | Y         | Total       | 1            | N           |
| Segment      | Y       | Y         | Segment     | 2            | N           |
| Q01          | Y       | N         |             |              | Y           |
| Q02          | Y       | N         |             |              | Y           |

### Expected Output

**Q01 - Satisfaction Sheet:**

```         
Overall Satisfaction (1-5)
                        Total   Enterprise  SMB     Consumer
Base (n=)               1000    300         400     300

Very satisfied (5)      30%     45%SC       25%     22%
Satisfied (4)           38%     35%         42%E    35%
Neutral (3)             18%     12%         20%     24%E
Dissatisfied (2)        10%     6%          9%      14%E
Very dissatisfied (1)   4%      2%          4%      5%

Mean                    3.80    4.15SC      3.75    3.55
Top 2 Box               68%     80%SC       67%     57%
```

**Q02 - NPS Sheet:**

```         
Likelihood to recommend (0-10)
                        Total   Enterprise  SMB     Consumer
Base (n=)               1000    300         400     300

Promoters (9-10)        40%     55%SC       38%     28%
Passives (7-8)          35%     30%         38%     37%
Detractors (0-6)        25%     15%         24%     35%E

NPS Score               15      40SC        14      -7
```

### Key Insights

Enterprise customers are significantly more satisfied than SMB and
Consumer segments. The NPS score shows this clearly: Enterprise has +40,
while Consumer has -7.

------------------------------------------------------------------------

## Workflow 3: Weighted Survey Analysis

### The Scenario

Your sample over-represents urban respondents. You need to apply weights
to match the population distribution.

### Step 1: Data with Weights

```         
RespondentID | weight | Region | Q01
1            | 0.8    | Urban  | Satisfied
2            | 1.5    | Rural  | Neutral
3            | 0.9    | Urban  | Satisfied
```

Urban respondents have weights less than 1 (over-sampled), Rural
respondents have weights greater than 1 (under-sampled).

### Step 2: Configuration

**Settings Sheet:**

| Setting             | Value  |
|---------------------|--------|
| apply_weighting     | TRUE   |
| weight_variable     | weight |
| show_unweighted_n   | TRUE   |
| show_effective_n    | TRUE   |
| weight_deff_warning | 3      |

### Expected Output

```         
Q01
                    Total
Base (unweighted)   2000
Base (weighted)     2000
Effective N         1538
DEFF                1.30

Satisfied           45%
Neutral             35%
Dissatisfied        20%
```

### Understanding the Bases

The unweighted base (2000) is your actual sample count. The weighted
base (2000) is the population estimate (sum of weights). The effective N
(1538) accounts for weighting variance and tells you the true
statistical precision of your sample.

The DEFF of 1.30 means your sample is worth about 77% of its nominal
size for statistical purposes (2000 / 1.30 = 1538).

------------------------------------------------------------------------

## Workflow 4: Multi-Banner Crosstabulation

### The Scenario

You want to analyze brand preference across multiple demographic cuts
simultaneously: gender, age group, and income.

### Step 1: Configuration

**Selection Sheet:**

| QuestionCode   | Include | UseBanner | BannerLabel | DisplayOrder |
|----------------|---------|-----------|-------------|--------------|
| Total          | N       | Y         | Total       | 1            |
| Gender         | N       | Y         | Gender      | 2            |
| Age_Group      | N       | Y         | Age         | 3            |
| Income         | N       | Y         | Income      | 4            |
| Q01_Preference | Y       | N         |             |              |

This creates a banner with 10+ columns (Total, Male, Female, 18-34,
35-54, 55+, Low Income, Medium Income, High Income).

### Expected Output

```         
Which brand do you prefer?
            Total  Male  Female  18-34  35-54  55+  Low   Medium  High
Base (n=)   1500   750   750     500    600    400  600   600     300

Brand A     40%    45%C  35%     50%G   38%    30%  35%   42%     48%H
Brand B     35%    30%   40%B    28%    37%    40%  40%L  33%     30%
Brand C     25%    25%   25%     22%    25%    30%  25%   25%     22%
```

### Key Insights

Brand A is preferred by males, younger consumers, and higher-income
groups. Brand B shows the opposite pattern - preferred by females and
lower-income groups. Regional analysis shows no significant differences.

------------------------------------------------------------------------

## Workflow 5: Filtered Analysis

### The Scenario

You want to analyze satisfaction only among customers who made a
purchase, and service quality only among those who contacted support.

### Step 1: Configuration

**Selection Sheet:**

| QuestionCode     | Include | BaseFilter                   |
|------------------|---------|------------------------------|
| Q01_Satisfaction | Y       | Q_Purchased == "Yes"         |
| Q02_Service      | Y       | Q_Contacted_Support == "Yes" |
| Q03_General      | Y       |                              |

### Expected Output

```         
Q01 - Satisfaction (Among Purchasers Only)
Base Filter: Q_Purchased == "Yes"
                    Total   Male    Female
Base (n=)           800     450     350
(Full sample: 1500, Filtered: 800)

Very Satisfied      45%     48%     41%
Satisfied           35%     33%     38%
Neutral             12%     11%     14%
Dissatisfied        6%      6%      5%
Very Dissatisfied   2%      2%      2%
```

The output clearly shows that only 800 of 1500 respondents are included
in this analysis - those who answered "Yes" to the purchase question.

------------------------------------------------------------------------

## Workflow 6: Rating Scale with Top Box Analysis

### The Scenario

You have a product evaluation survey with multiple 1-5 rating scales.
You want to show both the distribution and summary metrics like Top 2
Box.

### Step 1: Survey Structure

**Questions Sheet:**

| QuestionCode | QuestionText    | Variable_Type |
|--------------|-----------------|---------------|
| Q01          | Quality         | Rating        |
| Q02          | Value for Money | Rating        |
| Q03          | Ease of Use     | Rating        |

**Options Sheet (for each question):**

| QuestionCode | OptionText | DisplayText       | Index_Weight |
|--------------|------------|-------------------|--------------|
| Q01          | 1          | Poor (1)          | 1            |
| Q01          | 2          | Below Average (2) | 2            |
| Q01          | 3          | Average (3)       | 3            |
| Q01          | 4          | Good (4)          | 4            |
| Q01          | 5          | Excellent (5)     | 5            |

### Step 2: Configuration

**Settings Sheet (relevant settings):**

| Setting                | Value |
|------------------------|-------|
| show_frequency         | TRUE  |
| show_percent_column    | TRUE  |
| decimal_places_ratings | 2     |

**Selection Sheet:**

| QuestionCode | Include | CreateIndex |
|--------------|---------|-------------|
| Q01          | Y       | Y           |
| Q02          | Y       | Y           |
| Q03          | Y       | Y           |

### Expected Output

```         
Quality Rating
                    Total   New_Customers  Returning
Base (n=)           1000    400            600

Excellent (5)       30%     25%            33%R
Good (4)            40%     42%            39%
Average (3)         20%     22%            18%
Below Average (2)   7%      8%             7%
Poor (1)            3%      3%             3%

Mean                3.87    3.78           3.93R
Top 2 Box           70%     67%            72%
Bottom 2 Box        10%     11%            10%
```

------------------------------------------------------------------------

## Workflow 7: Multi-Mention Question Analysis

### The Scenario

You asked respondents "Which features do you use?" with a
select-all-that-apply format.

### Step 1: Data Structure

Your data has columns Q10_1 through Q10_5, each containing a feature
name if selected:

```         
RespondentID | Q10_1     | Q10_2     | Q10_3     | Q10_4 | Q10_5
1            | Feature A | Feature C |           |       |
2            | Feature B | Feature D | Feature E |       |
3            | Feature A |           |           |       |
```

### Step 2: Survey Structure

**Questions Sheet:**

| QuestionCode | QuestionText               | Variable_Type | Columns |
|--------------|----------------------------|---------------|---------|
| Q10          | Which features do you use? | Multi_Mention | 5       |

**Options Sheet:**

| QuestionCode | OptionText | DisplayText | ShowInOutput |
|--------------|------------|-------------|--------------|
| Q10_1        | Feature A  | Feature A   | Y            |
| Q10_1        | Feature B  | Feature B   | Y            |
| Q10_1        | Feature C  | Feature C   | Y            |
| Q10_1        | Feature D  | Feature D   | Y            |
| Q10_1        | Feature E  | Feature E   | Y            |

### Expected Output

```         
Which features do you use? (Select all that apply)
                    Total   Enterprise  SMB     Consumer
Base (n=)           1000    300         400     300

Feature A           60%     83%SC       55%     43%
Feature B           45%     67%SC       45%     23%
Feature C           40%     60%SC       38%     23%
Feature D           30%     50%SC       25%     17%
Feature E           20%     17%         20%     23%

Average Mentions    1.95    2.77SC      1.83    1.30
```

Notice that percentages sum to more than 100% - this is expected for
multi-mention questions since each respondent can select multiple
features.

------------------------------------------------------------------------

## Workflow 8: Composite Metrics

### The Scenario

You want to calculate an Overall Satisfaction Index by averaging three
individual satisfaction questions.

### Step 1: Survey Structure

**Composite_Metrics Sheet:**

| CompositeCode | CompositeLabel             | CalculationType | SourceQuestions |
|---------------|----------------------------|-----------------|-----------------|
| COMP_SAT      | Overall Satisfaction Index | Mean            | Q01,Q02,Q03     |

### Step 2: Configuration

**Selection Sheet:**

| QuestionCode | Include | CreateIndex |
|--------------|---------|-------------|
| Q01          | Y       | Y           |
| Q02          | Y       | Y           |
| Q03          | Y       | Y           |
| COMP_SAT     | Y       | Y           |

### Expected Output

```         
Overall Satisfaction Index
Composite of: Product Quality, Service Quality, Value for Money
                    Total   Segment_A   Segment_B
Base (n=)           1000    350         400

Mean Score          3.85    4.20BC      3.75

Component Breakdown:
  Product Quality   4.00    4.30BC      3.90
  Service Quality   3.80    4.20BC      3.70
  Value for Money   3.75    4.10BC      3.65
```

------------------------------------------------------------------------

## Workflow 9: Large Dataset Processing

### The Scenario

You have a large dataset (50,000+ respondents, 200+ questions) and need
to process efficiently.

### Step 1: Optimization Tips

**Use CSV instead of Excel:**

``` r
# Slow: Excel reading
# Fast: CSV reading
```

Convert your data to CSV if it isn't already.

**Configuration for large datasets:**

| Setting              | Value |
|----------------------|-------|
| show_frequency       | FALSE |
| enable_checkpointing | TRUE  |

Disable frequencies if you only need percentages - this reduces output
size and processing time.

### Step 2: Batch Processing

For extremely large analyses, split into multiple runs:

``` r
# Run questions 1-50
config1 <- modify_config(base_config, questions = 1:50, output = "Results_Batch1.xlsx")
run_tabs_analysis(project_path, config = config1)

# Run questions 51-100
config2 <- modify_config(base_config, questions = 51:100, output = "Results_Batch2.xlsx")
run_tabs_analysis(project_path, config = config2)
```

### Expected Performance

| Dataset Size | Questions     | Banner Cols | Time         |
|--------------|---------------|-------------|--------------|
| 1,000 rows   | 50 questions  | 10 columns  | \~15 seconds |
| 10,000 rows  | 100 questions | 15 columns  | \~1 minute   |
| 50,000 rows  | 200 questions | 20 columns  | \~8 minutes  |

------------------------------------------------------------------------

## Workflow 10: Ranking Question Analysis

### The Scenario

You asked respondents to rank their top 3 preferred brands.

### Step 1: Data Structure (Position Format)

```         
RespondentID | Brand_A_Rank | Brand_B_Rank | Brand_C_Rank | Brand_D_Rank
1            | 2            | 1            | 3            |
2            | 1            |              | 2            | 3
3            |              | 2            | 1            | 3
```

Values indicate the rank position each brand received (1=first choice,
2=second, etc.).

### Step 2: Survey Structure

**Questions Sheet:**

| QuestionCode | QuestionText | Variable_Type | Ranking_Format | Ranking_Positions | Ranking_Direction |
|------------|------------|------------|------------|------------|------------|
| Brand_Ranking | Rank your top 3 brands | Ranking | Position | 3 | BestToWorst |

### Expected Output

```         
Brand Ranking
                    Total   Male    Female
Base (n=)           1000    500     500

Brand A
  1st choice        35%     40%C    30%
  2nd choice        25%     22%     28%
  3rd choice        20%     18%     22%

Brand B
  1st choice        25%     20%     30%B
  2nd choice        30%     32%     28%
  3rd choice        25%     25%     25%

Mean Ranks:
  Brand A           1.8     1.7     1.9
  Brand B           2.0     2.1     1.9
  Brand C           2.3     2.4     2.2
  Brand D           2.5     2.5     2.5
```

Lower mean rank = more preferred (1 is first choice).

------------------------------------------------------------------------

## Common Patterns

### Pattern 1: Iterative Analysis

Start broad, then narrow down to interesting segments:

``` r
# First pass: High-level analysis
# Banner: Total, Gender
result1 <- run_tabs_analysis(project, config1)

# Second pass: More detail
# Banner: Total, Gender, Age, Region
result2 <- run_tabs_analysis(project, config2)

# Third pass: Deep dive into interesting segment
# Filter: Males 18-34 only
result3 <- run_tabs_analysis(project, config3)
```

### Pattern 2: Compare Subgroups

Analyze the same questions with different filters:

``` r
# Config 1: Purchasers only
# Filter: Q_Purchased == "Yes"

# Config 2: Non-purchasers only
# Filter: Q_Purchased == "No"

# Compare the two output files
```

### Pattern 3: Summary Dashboard

Create an Index Summary with all key metrics:

1.  Define composites for each key metric area
2.  Set CreateIndex = Y for all metrics
3.  Enable create_index_summary = Y

The Index_Summary sheet becomes your executive dashboard with all scores
across segments.

------------------------------------------------------------------------

## Troubleshooting Common Issues

### No Significant Differences Found

**Possible causes:** - Sample sizes too small - Differences genuinely
not significant - Alpha level too strict

**Solutions:** - Check base sizes (need 30+ per column for reliable
testing) - Try alpha = 0.10 for more lenient testing - Verify you're
using the appropriate statistical test

### Percentages Don't Match Expectations

**For multi-mention:** Percentages can exceed 100% - this is correct.

**For single-mention:** Check that OptionText matches your data exactly.

### Output File Very Large

**Solutions:** - Set show_frequency = FALSE - Reduce decimal places -
Split into multiple output files

### Processing Takes Too Long

**Solutions:** - Convert Excel data to CSV - Reduce banner columns -
Process in batches - Disable unused features

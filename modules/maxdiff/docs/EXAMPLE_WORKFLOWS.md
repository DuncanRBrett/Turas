# Turas MaxDiff Module - Example Workflows

**Version:** 10.0
**Last Updated:** December 2025

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Example 1: Banking Features Study](#2-example-1-banking-features-study)
3. [Example 2: Product Attributes with Segments](#3-example-2-product-attributes-with-segments)
4. [Example 3: Large Item Set Study](#4-example-3-large-item-set-study)
5. [Example 4: Quick Count-Based Analysis](#5-example-4-quick-count-based-analysis)
6. [Example 5: Individual-Level Analysis with HB](#6-example-5-individual-level-analysis-with-hb)
7. [Common Scenarios](#7-common-scenarios)

---

## 1. Introduction

This document provides complete, step-by-step examples of MaxDiff studies from design to analysis. Each example includes:

- Study background and objectives
- Configuration setup
- Survey programming guidance
- Analysis and interpretation
- Deliverables

Use these as templates for your own studies.

---

## 2. Example 1: Banking Features Study

### 2.1 Study Background

**Client:** Regional bank wanting to prioritize digital banking features

**Objective:** Identify which features drive customer satisfaction

**Items:** 12 banking features
**Sample:** 300 customers, stratified by age group
**Timeline:** 2 weeks design to results

### 2.2 Step 1: Define Items

Created ITEMS sheet with 12 features:

```
Item_ID      | Item_Label                          | Item_Group
-------------|-------------------------------------|------------
FEE_LOW      | Low monthly account fees            | Pricing
FEE_NO       | No minimum balance requirement      | Pricing
RATE_HIGH    | High interest rates on savings      | Returns
RATE_CASHBACK| Cash back on debit purchases        | Returns
APP_QUALITY  | High-quality mobile app             | Digital
APP_FEATURES | Advanced mobile features            | Digital
PAY_MOBILE   | Mobile payment integration          | Digital
SUPPORT_24   | 24/7 customer support               | Service
SUPPORT_CHAT | Live chat support                   | Service
BRANCH_LOCAL | Convenient branch locations         | Access
ATM_NETWORK  | Large ATM network                   | Access
SECURITY_ADV | Advanced security features          | Trust
```

### 2.3 Step 2: Design Mode Configuration

**PROJECT_SETTINGS:**
```
Project_Name: Bank_Features_2025
Mode: DESIGN
Output_Folder: output/bank_study
Seed: 42
```

**DESIGN_SETTINGS:**
```
Items_Per_Task: 4
Tasks_Per_Respondent: 12
Num_Versions: 3
Design_Type: BALANCED
Force_Min_Pair_Balance: YES
Randomise_Task_Order: YES
Randomise_Item_Order_Within_Task: YES
```

### 2.4 Step 3: Run Design Mode

```r
setwd("/path/to/Turas")
source("modules/maxdiff/R/00_main.R")
run_maxdiff("config/bank_features_config.xlsx")
```

**Output:**
- Design file: `Bank_Features_2025_MaxDiff_Design.xlsx`
- D-efficiency: 0.94 (excellent)
- Item balance CV: 0.05 (excellent)
- Pair balance CV: 0.12 (good)

### 2.5 Step 4: Survey Programming

Programmed in Qualtrics:

1. **Version assignment:** Random number 1-3 assigned to embedded variable `Version`
2. **12 tasks:** Each task shows 4 features based on design file
3. **For each task:**
   - Display 4 features as radio button lists
   - Best question: "Which feature is MOST important to you?"
   - Worst question: "Which feature is LEAST important to you?"
   - Store position (1-4) in variables `T1_Best`, `T1_Worst`, etc.

**Testing:** Completed test responses for all 3 versions, verified randomization working

### 2.6 Step 5: Data Collection

- Fielded to 300 customers (100 per version)
- Average completion time: 4.2 minutes
- Completion rate: 87%
- Final n after data cleaning: 287

### 2.7 Step 6: Analysis Mode Configuration

Updated config file:

**PROJECT_SETTINGS:**
```
Mode: ANALYSIS
Raw_Data_File: data/bank_survey_responses.xlsx
Design_File: output/bank_study/Bank_Features_2025_MaxDiff_Design.xlsx
```

**SURVEY_MAPPING:**
```
Mapping_Type          | Value
----------------------|-------------------------
Version_Variable      | Version
Best_Column_Pattern   | T{task}_Best
Worst_Column_Pattern  | T{task}_Worst
Best_Value_Type       | ITEM_POSITION
Worst_Value_Type      | ITEM_POSITION
```

**SEGMENT_SETTINGS:**
```
Segment_ID | Segment_Name | Variable_Name | Variable_Value
-----------|--------------|---------------|----------------
AGE        | 18-34        | Age_Group     | 1
AGE        | 35-54        | Age_Group     | 2
AGE        | 55+          | Age_Group     | 3
```

**OUTPUT_SETTINGS:**
```
Generate_Count_Scores: YES
Generate_Aggregate_Logit: YES
Generate_HB_Model: NO  (skipped for speed)
Generate_Charts: YES
Score_Rescale_Method: 0_100
```

### 2.8 Step 7: Run Analysis

```r
run_maxdiff("config/bank_features_config.xlsx")
```

**Processing time:** 2 minutes

### 2.9 Results

**Top 5 Features (Rescaled 0-100):**

| Rank | Feature | Utility | Net Score |
|------|---------|---------|-----------|
| 1 | Low monthly account fees | 100 | +42% |
| 2 | No minimum balance | 87 | +35% |
| 3 | 24/7 customer support | 73 | +28% |
| 4 | High interest rates | 68 | +22% |
| 5 | Large ATM network | 58 | +15% |

**Bottom 3 Features:**

| Rank | Feature | Utility | Net Score |
|------|---------|---------|-----------|
| 10 | Advanced mobile features | 32 | -8% |
| 11 | Live chat support | 15 | -18% |
| 12 | Mobile payment integration | 0 | -25% |

**Segment Insights:**

- **18-34:** Prioritize mobile app quality and features (ranks 2nd and 3rd)
- **35-54:** Balance of pricing and service
- **55+:** Strong preference for branches and ATMs (rank 1st and 2nd)

### 2.10 Deliverables

1. **Results workbook** with all scores
2. **Utility bar chart** showing rescaled scores
3. **Segment comparison charts** for age groups
4. **PowerPoint presentation** with key findings

### 2.11 Business Impact

- Prioritized fee reduction over new digital features
- Maintained branch network (important to 55+ segment)
- Targeted mobile app improvements to younger customers
- Customer satisfaction +12% after implementation

---

## 3. Example 2: Product Attributes with Segments

### 3.1 Study Background

**Client:** Consumer electronics company

**Objective:** Understand which product attributes drive purchase decisions and how preferences vary by user type

**Items:** 15 product attributes
**Segments:** User type (Professional, Enthusiast, Casual), Price sensitivity
**Sample:** 500 respondents

### 3.2 Configuration Highlights

**ITEMS (excerpt):**
```
QUALITY_BUILD   | Premium build quality
PRICE_AFFORD    | Affordable price point
BATTERY_LONG    | Long battery life
SCREEN_QUALITY  | High-resolution display
PERFORMANCE_FAST| Fast processor
...
```

**DESIGN_SETTINGS:**
```
Items_Per_Task: 5
Tasks_Per_Respondent: 15
Num_Versions: 5
Design_Type: OPTIMAL  (for 15 items)
```

**SEGMENT_SETTINGS:**
```
Segment_ID  | Segment_Name  | Variable_Name | Variable_Value
------------|---------------|---------------|----------------
USER_TYPE   | Professional  | UserType      | 1
USER_TYPE   | Enthusiast    | UserType      | 2
USER_TYPE   | Casual        | UserType      | 3
PRICE_SENS  | High          | PriceSens     | 1
PRICE_SENS  | Medium        | PriceSens     | 2
PRICE_SENS  | Low           | PriceSens     | 3
```

### 3.3 Key Results

**Overall Rankings:**
1. Battery life (100)
2. Performance (89)
3. Build quality (76)
4. Screen quality (72)
5. Price (68)

**Segment Differences:**

| Attribute | Professional | Enthusiast | Casual |
|-----------|-------------|------------|--------|
| Performance | 1st (100) | 1st (100) | 5th (45) |
| Battery life | 2nd (92) | 3rd (78) | 1st (100) |
| Price | 8th (35) | 7th (42) | 2nd (87) |
| Build quality | 3rd (88) | 2nd (95) | 9th (22) |

**Insights:**
- Casual users are price-driven, professionals value performance
- Battery life universally important
- Opportunity for tiered product line

---

## 4. Example 3: Large Item Set Study

### 4.1 Study Background

**Client:** Government agency

**Objective:** Prioritize 30 potential policy initiatives

**Challenges:**
- Large number of items
- Need individual-level data for stakeholder mapping
- Complex segmentation by multiple factors

### 4.2 Configuration Strategy

**DESIGN_SETTINGS:**
```
Items_Per_Task: 6
Tasks_Per_Respondent: 25
Num_Versions: 10
Design_Type: OPTIMAL
Max_Design_Iterations: 50000
```

**OUTPUT_SETTINGS:**
```
Generate_HB_Model: YES
Export_Individual_Utils: YES
HB_Iterations: 8000  (increased for stability)
HB_Warmup: 3000
HB_Chains: 4
```

### 4.3 Sample Requirements

- 30 items × 6 per task = need to see ~30 items
- 25 tasks at 6 items = 150 exposures per respondent
- Each item appears ~5 times per respondent
- Target sample: 800 (minimum 600)
- Actual completes: 743

### 4.4 Analysis Approach

1. **Overall priorities** - Aggregate logit for main rankings
2. **Individual analysis** - HB for stakeholder mapping
3. **Cluster analysis** - k-means on individual utilities
4. **Segment comparisons** - By demographic and attitudinal segments

### 4.5 Processing Notes

- Design generation: 15 minutes
- HB estimation: 45 minutes (743 respondents × 30 items)
- Total analysis time: ~1 hour
- Convergence: All Rhat < 1.02 (excellent)

### 4.6 Advanced Output

Exported individual utilities and performed:
- Principal components analysis
- Cluster analysis (identified 4 preference segments)
- Correlation with demographic variables
- Priority mapping by stakeholder group

---

## 5. Example 4: Quick Count-Based Analysis

### 5.1 When to Use

- Need results immediately (client meeting in 1 hour)
- Preliminary analysis before full modeling
- Very small sample (n < 100)
- Simple prioritization needs

### 5.2 Configuration

**OUTPUT_SETTINGS:**
```
Generate_Count_Scores: YES
Generate_Aggregate_Logit: NO
Generate_HB_Model: NO
Generate_Charts: YES
Score_Rescale_Method: 0_100  (rescales net scores)
```

### 5.3 Results

Analysis completed in < 1 minute for 150 respondents × 10 items

**Output:**
- Net scores (Best% - Worst%)
- Ranks
- Best-worst diverging chart
- Segment comparisons (if defined)

**Limitations:**
- Net scores not true interval scale
- No statistical significance tests
- No individual-level data

**When sufficient:**
- Large preference differences (>20 percentage points)
- Exploratory research
- Simple prioritization
- Preliminary results for discussion

### 5.4 Follow-up

After client review, ran full analysis with logit model:
- Rankings nearly identical
- Logit provided statistical tests
- Validated count-based insights

---

## 6. Example 5: Individual-Level Analysis with HB

### 6.1 Study Background

**Client:** Streaming service

**Objective:** Segment customers by content preferences for personalized recommendations

**Approach:** Use HB individual utilities for clustering

### 6.2 Configuration

**Items:** 18 content attributes
```
CONTENT_MOVIES_NEW    | New movie releases
CONTENT_TV_ORIGINALS  | Original TV series
CONTENT_CLASSIC_FILMS | Classic film library
CONTENT_DOCUMENTARIES | Documentary content
CONTENT_SPORTS_LIVE   | Live sports
...
```

**OUTPUT_SETTINGS:**
```
Generate_HB_Model: YES
Export_Individual_Utils: YES
HB_Iterations: 10000  (higher for precise estimates)
HB_Warmup: 4000
HB_Chains: 4
```

### 6.3 HB Processing

**Sample:** 600 respondents
**Processing time:** 25 minutes
**Convergence:** All parameters Rhat < 1.03

**HB Output:**
- 600 rows (respondents) × 18 columns (items)
- Each cell = individual's utility for that content type

### 6.4 Post-Processing

Merged individual utilities with customer data:

```r
# Load individual utilities
indiv_utils <- read.xlsx("output/Streaming_Study_MaxDiff_Results.xlsx",
                         sheet = "INDIVIDUAL_UTILS")

# Load customer data
customer_data <- read.xlsx("data/customer_database.xlsx")

# Merge
analysis_data <- merge(customer_data, indiv_utils, by.x = "CustomerID", by.y = "Respondent_ID")

# Cluster analysis
library(cluster)
set.seed(42)
clusters <- kmeans(indiv_utils[, -1], centers = 5, nstart = 25)

# Add to data
analysis_data$Segment <- clusters$cluster
```

### 6.5 Segments Identified

**Segment 1 (23%): Movie Enthusiasts**
- High utility: New movies, classic films
- Low utility: TV series, documentaries
- Demographics: 18-34, male-skewed

**Segment 2 (18%): Sports Fans**
- High utility: Live sports, sports documentaries
- Low utility: Most other content
- Demographics: 25-54, 70% male

**Segment 3 (31%): Original Content Lovers**
- High utility: Original series, exclusive content
- Mid utility: Most categories
- Demographics: 25-44, balanced gender

**Segment 4 (16%): Families**
- High utility: Kids content, family movies
- Low utility: Adult-oriented content
- Demographics: 35-54, parents

**Segment 5 (12%): Documentary Viewers**
- High utility: Documentaries, educational
- Mid-high: Quality dramas
- Demographics: 35+, educated

### 6.6 Business Application

1. **Personalization algorithm** - Used utilities to weight content recommendations
2. **Content acquisition** - Prioritized based on segment sizes and gaps
3. **Marketing** - Tailored messaging by identified segment
4. **Retention** - Targeted at-risk customers with relevant content

**Results:**
- Engagement +18%
- Churn rate -12%
- Customer satisfaction +9 NPS points

---

## 7. Common Scenarios

### 7.1 Handling Missing Data

**Scenario:** Some respondents didn't complete all tasks

**Solution 1: Filter incomplete**
```
Filter_Expression: Tasks_Completed >= 10
```

**Solution 2: Use all data**
- MaxDiff handles incomplete naturally (uses tasks completed)
- HB benefits from partial data (borrows strength)
- Check minimum tasks per respondent (recommend 8+)

### 7.2 Combining Multiple Studies

**Scenario:** Ran same study in 3 markets, want combined and separate results

**Approach:**
1. **Combined analysis:**
   - Append data files
   - Add market as segment
   - Run once

2. **Separate analyses:**
   - Create 3 config files
   - Run each market independently
   - Compare manually

3. **Best practice:**
   - Combined for overall + market segments
   - Verify n per market adequate (200+)

### 7.3 Tracking Study Setup

**Scenario:** Annual tracking of brand attributes

**Configuration strategy:**
- Keep ITEMS identical across waves
- Use consistent Item_IDs
- Same design (or balanced equivalent)
- Same number of tasks
- Save config file for each wave

**Analysis approach:**
- Run each wave separately
- Export results
- Combine in Excel/R for trending
- Statistical tests between waves (t-tests on utilities)

### 7.4 Comparing Designs

**Scenario:** Unsure whether to use BALANCED or OPTIMAL design

**Approach:**
1. Generate both designs
2. Compare quality metrics:
   - D-efficiency
   - Item balance CV
   - Pair balance CV
3. Consider practical factors:
   - BALANCED easier to explain
   - OPTIMAL better for 20+ items
4. Pilot test both if critical

### 7.5 Post-Hoc Segmentation

**Scenario:** Didn't define segments in advance, found interesting pattern in data

**Solution:**
1. Add segment to original data file
2. Update SEGMENT_SETTINGS in config
3. Re-run analysis
4. Results update automatically

**Alternative (manual):**
1. Export individual utilities
2. Merge with segment variable
3. Compute segment averages manually
4. Create charts in Excel/R

### 7.6 Integration with Other Data

**Scenario:** Want to correlate MaxDiff utilities with purchase behavior

**Approach:**
1. Export INDIVIDUAL_UTILS sheet
2. Merge with behavioral data by Respondent_ID
3. Analyze correlations:
   ```r
   cor(indiv_utils$ITEM_QUALITY, customer_data$Purchase_Frequency)
   ```
4. Build predictive models
5. Identify utility thresholds for behavior

### 7.7 Dealing with Ties

**Scenario:** Two items have very similar utilities - which ranks higher?

**Analysis:**
1. Check statistical significance (logit SE)
2. Compare across segments
3. Consider practical significance (is difference meaningful?)
4. Look at count scores for validation
5. HB distribution overlap

**Reporting:**
- If not statistically different: report as tied
- If overlapping in some segments: note variability
- Focus on clear differences, not marginal rankings

### 7.8 Multi-Language Studies

**Scenario:** Same study in English and Spanish

**Configuration:**
1. **Same design** across languages
2. **Translate Item_Labels** in ITEMS sheet
3. **Keep Item_IDs** identical
4. **Separate data files** by language
5. **Language as segment** for comparison

**Validation:**
- Check equivalent utilities across languages
- Test for cultural differences
- Consider separate analyses if very different

---

## 8. Troubleshooting Real Examples

### 8.1 Example: "Respondents chose same item for best and worst"

**Situation:** Found 15 cases where best = worst

**Investigation:**
```r
# Check pattern
data %>%
  filter(T1_Best == T1_Worst) %>%
  select(RespID, CompletionTime, matches("T[0-9]"))
```

**Finding:** All were speeders (< 2 minutes completion)

**Solution:**
```
Filter_Expression: CompletionTime_Secs > 120
```

**Result:** Warning disappeared, valid n = 285

### 8.2 Example: "Very low D-efficiency (0.62)"

**Situation:** First design generated had poor efficiency

**Investigation:**
- Design_Type was RANDOM
- Only 1 version with 300 respondents
- 20 items in 10 tasks

**Solution:**
- Changed to Design_Type: OPTIMAL
- Increased to 3 versions
- Increased to 15 tasks

**Result:** D-efficiency = 0.91

### 8.3 Example: "HB model won't converge"

**Situation:** Rhat values > 1.10, warnings about divergences

**Investigation:**
- Sample size n = 85 (too small)
- 25 items (complex model)
- Default 2000 warmup iterations

**Solution 1:** Increase iterations
```
HB_Warmup: 5000
HB_Iterations: 10000
```

**Result:** Marginal improvement (Rhat still 1.08)

**Solution 2:** Use logit instead
```
Generate_HB_Model: NO
Generate_Aggregate_Logit: YES
```

**Result:** Clean convergence, stable estimates

**Lesson:** HB needs adequate sample size (200+ recommended)

---

## 9. Complete Project Template

### 9.1 Project Structure

```
ProjectName/
├── config/
│   └── maxdiff_config.xlsx
├── data/
│   ├── raw_survey_data.xlsx
│   └── customer_database.xlsx
├── design/
│   └── MaxDiff_Design.xlsx
├── output/
│   ├── MaxDiff_Results.xlsx
│   ├── charts/
│   │   ├── utility_bar.png
│   │   └── best_worst.png
│   └── log.txt
├── scripts/
│   └── post_processing.R
└── reports/
    └── MaxDiff_Analysis_Final.pptx
```

### 9.2 Workflow Checklist

**Phase 1: Design (Week 1)**
- [ ] Define research objectives
- [ ] Generate item list (qualitative research)
- [ ] Create configuration file
- [ ] Run DESIGN mode
- [ ] Review design quality
- [ ] Share design with programming team

**Phase 2: Fielding (Weeks 2-3)**
- [ ] Program survey
- [ ] Test all versions
- [ ] Soft launch (n=50)
- [ ] Review data quality
- [ ] Full launch
- [ ] Monitor daily

**Phase 3: Analysis (Week 4)**
- [ ] Export clean data
- [ ] Update config for ANALYSIS mode
- [ ] Run analysis
- [ ] Review results
- [ ] Check segment sizes
- [ ] Validate findings

**Phase 4: Reporting (Week 4)**
- [ ] Create summary slide deck
- [ ] Generate detailed report
- [ ] Prepare recommendations
- [ ] Present to stakeholders
- [ ] Archive all files

---

## 10. Additional Resources

### 10.1 Example Files

Complete working examples available in:
```
modules/maxdiff/examples/basic/
```

Generate with:
```r
source("modules/maxdiff/examples/basic/create_example_files.R")
create_example_files("path/to/output")
```

### 10.2 Further Reading

- **User Manual**: Detailed configuration reference
- **Technical Reference**: API documentation and methods
- **Authoritative Guide**: Methodology and best practices
- **Marketing Guide**: Capabilities and use cases

### 10.3 Getting Help

For questions on these examples:
1. Review configuration files carefully
2. Check error messages in log file
3. Consult troubleshooting section
4. Contact Turas development team

---

*These examples demonstrate the flexibility and power of the Turas MaxDiff module. Adapt them to your specific research needs.*

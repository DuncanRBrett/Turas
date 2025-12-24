# Turas Conjoint Module - Example Workflows

**Version:** 2.1.0
**Last Updated:** December 2025

---

## Table of Contents

1. [Workflow 1: Basic Smartphone Study](#workflow-1-basic-smartphone-study)
2. [Workflow 2: Alchemer Data Import](#workflow-2-alchemer-data-import)
3. [Workflow 3: Pricing Optimization](#workflow-3-pricing-optimization)
4. [Workflow 4: Competitive Analysis](#workflow-4-competitive-analysis)
5. [Workflow 5: Portfolio Strategy](#workflow-5-portfolio-strategy)
6. [Workflow 6: Including None Option](#workflow-6-including-none-option)
7. [Common Configurations](#common-configurations)

---

## Workflow 1: Basic Smartphone Study

### Scenario

A mobile phone manufacturer wants to understand which features drive consumer choice for their next smartphone.

### Study Design

| Element | Value |
|---------|-------|
| Attributes | 4 (Brand, Price, Storage, Battery) |
| Levels per attribute | 3 |
| Alternatives per choice set | 3 |
| Choice sets per respondent | 10 |
| Sample size | 500 respondents |

### Step 1: Prepare Data File

**File:** `smartphone_choices.csv`

```csv
resp_id,choice_set_id,alt_id,Brand,Price,Storage,Battery,chosen
1,1,1,Apple,£449,128GB,12 hours,0
1,1,2,Samsung,£599,256GB,18 hours,1
1,1,3,Google,£699,512GB,24 hours,0
1,2,1,Samsung,£449,512GB,12 hours,0
1,2,2,Google,£599,128GB,24 hours,1
1,2,3,Apple,£699,256GB,18 hours,0
...
```

### Step 2: Configure Settings Sheet

| Setting | Value |
|---------|-------|
| analysis_type | choice |
| choice_set_column | choice_set_id |
| chosen_column | chosen |
| respondent_id_column | resp_id |
| alternative_id_column | alt_id |
| data_file | data/smartphone_choices.csv |
| output_file | output/smartphone_results.xlsx |
| estimation_method | auto |
| generate_market_simulator | TRUE |
| confidence_level | 0.95 |

### Step 3: Configure Attributes Sheet

| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| Brand | 3 | Apple, Samsung, Google |
| Price | 3 | £449, £599, £699 |
| Storage | 3 | 128GB, 256GB, 512GB |
| Battery | 3 | 12 hours, 18 hours, 24 hours |

### Step 4: Run Analysis

```r
setwd("/path/to/Turas/modules/conjoint")
source("R/00_main.R")

results <- run_conjoint_analysis(
  config_file = "smartphone_config.xlsx",
  verbose = TRUE
)
```

### Step 5: Interpret Results

**Part-Worth Utilities:**
```
Brand:
  Apple:    +0.45  (most preferred)
  Samsung:  +0.12
  Google:   -0.57  (least preferred)

Price:
  £449:     +0.78  (most preferred)
  £599:     +0.23
  £699:     -1.01  (least preferred)

Storage:
  512GB:    +0.25  (most preferred)
  256GB:    +0.10
  128GB:    -0.35  (least preferred)

Battery:
  24 hours: +0.15  (most preferred)
  18 hours: +0.05
  12 hours: -0.20  (least preferred)
```

**Attribute Importance:**
```
Price:      48%  ← Most influential
Brand:      27%
Storage:    16%
Battery:     9%  ← Least influential
```

**Key Insights:**
1. Price dominates choice decisions (48% importance)
2. Apple has significant brand premium over Google
3. Storage matters more than battery life
4. Consumers willing to pay more for larger storage

---

## Workflow 2: Alchemer Data Import

### Scenario

You have collected CBC data through Alchemer and want to analyze it directly.

### Step 1: Export from Alchemer

Export your CBC data. Alchemer format includes:
- ResponseID
- SetNumber
- CardNumber
- Score (0 or 100)
- Attribute columns with prefixed level names

**Raw Alchemer Data:**
```csv
ResponseID,SetNumber,CardNumber,Price,Brand,Storage,Score
12345,1,1,Low_449,Brand_Apple,Storage_128,0
12345,1,2,Mid_599,Brand_Samsung,Storage_256,100
12345,1,3,High_699,Brand_Google,Storage_512,0
```

### Step 2: Configure for Alchemer

| Setting | Value |
|---------|-------|
| analysis_type | choice |
| data_source | alchemer |
| clean_alchemer_levels | TRUE |
| choice_set_column | SetNumber |
| chosen_column | Score |
| respondent_id_column | ResponseID |
| alternative_id_column | CardNumber |
| data_file | data/alchemer_export.csv |
| output_file | output/alchemer_results.xlsx |

### Step 3: Configure Attributes (Cleaned Names)

| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| Price | 3 | Low, Mid, High |
| Brand | 3 | Apple, Samsung, Google |
| Storage | 3 | 128, 256, 512 |

**Note:** Use the CLEANED level names, not the Alchemer prefixed versions.

### Step 4: Run Analysis

The module automatically:
1. Converts Score (0/100) to binary (0/1)
2. Cleans level name prefixes
3. Creates unique choice set IDs

```r
results <- run_conjoint_analysis("alchemer_config.xlsx")
```

---

## Workflow 3: Pricing Optimization

### Scenario

Determine the optimal price point for a new product configuration.

### Study Design

Include more price levels for finer granularity:

| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| Price | 5 | £349, £399, £449, £499, £549 |
| Brand | 2 | Our Brand, Competitor |
| Storage | 3 | 128GB, 256GB, 512GB |
| Warranty | 2 | 1 year, 2 years |

### Analysis Steps

1. **Run conjoint analysis** with the above configuration
2. **Extract price utilities** from results
3. **Calculate willingness-to-pay** for features

### Using the Market Simulator

**Test Scenario 1: Premium Pricing**
```
Product 1: Our Brand, £549, 512GB, 2 years → 32% share
Product 2: Competitor, £399, 256GB, 1 year → 68% share
```

**Test Scenario 2: Value Pricing**
```
Product 1: Our Brand, £449, 256GB, 2 years → 48% share
Product 2: Competitor, £399, 256GB, 1 year → 52% share
```

**Test Scenario 3: Match Competitor**
```
Product 1: Our Brand, £399, 256GB, 2 years → 55% share
Product 2: Competitor, £399, 256GB, 1 year → 45% share
```

### Calculating Feature Value

From utilities, calculate the price premium each feature supports:

```
Storage upgrade (128→256GB):
  Utility difference: 0.35
  Price utility per £50: 0.20
  Feature value: 0.35/0.20 × £50 = £87.50

Warranty upgrade (1→2 years):
  Utility difference: 0.15
  Feature value: 0.15/0.20 × £50 = £37.50
```

---

## Workflow 4: Competitive Analysis

### Scenario

Understand competitive positioning and predict responses to competitor actions.

### Study Design

Include competitor products as attribute levels:

| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| Brand | 4 | Our Brand, Competitor A, Competitor B, Competitor C |
| Price | 4 | £299, £349, £399, £449 |
| Feature_Level | 3 | Basic, Standard, Premium |
| Service | 3 | Basic, Enhanced, Premium |

### Competitive Scenarios

**Current Market:**
```
Product 1 (Ours):      Our Brand, £349, Standard, Enhanced → 28%
Product 2 (Comp A):    Competitor A, £299, Basic, Basic → 35%
Product 3 (Comp B):    Competitor B, £399, Premium, Premium → 22%
Product 4 (Comp C):    Competitor C, £349, Standard, Basic → 15%
```

**Scenario: Competitor A Price Increase**
```
Product 2 (Comp A):    Competitor A, £349, Basic, Basic → 30%
Our share increases:   28% → 32%
```

**Scenario: We Launch Premium Tier**
```
Product 1 (Entry):     Our Brand, £299, Basic, Basic → 20%
Product 5 (Premium):   Our Brand, £449, Premium, Premium → 18%
Combined share:        38% (up from 28%)
```

### Strategic Insights

1. Competitor A's price sensitivity creates opportunity
2. Premium segment underserved by Competitor C
3. Service quality differentiates at similar price points

---

## Workflow 5: Portfolio Strategy

### Scenario

Design a product portfolio that maximizes total market share without excessive cannibalization.

### Single Product Analysis

First, find the optimal single product:

| Configuration | Market Share |
|--------------|--------------|
| Apple, £449, 256GB | 38% |
| Apple, £599, 512GB | 32% |
| Samsung, £449, 128GB | 28% |

**Optimal single product:** Apple, £449, 256GB

### Two-Product Portfolio

Test complementary configurations:

| Portfolio | Total Share | Cannibalization |
|-----------|-------------|-----------------|
| Entry (£349) + Premium (£549) | 52% | Low |
| Entry (£349) + Mid (£449) | 48% | Moderate |
| Mid (£449) + Premium (£549) | 45% | High |

**Optimal 2-product:** Entry + Premium (52% total)

### Three-Product Portfolio

| Portfolio | Total Share | Notes |
|-----------|-------------|-------|
| Entry + Mid + Premium | 58% | Mid cannibalizes both |
| Entry (2 configs) + Premium | 55% | Entry saturation |
| Entry + Premium (2 configs) | 57% | Premium differentiation |

### Portfolio Recommendations

1. **If launching 1 product:** Mid-range at £449
2. **If launching 2 products:** Entry (£349) + Premium (£549)
3. **Avoid:** Three products with too-similar positioning

---

## Workflow 6: Including None Option

### Scenario

Understand the proportion of consumers who would opt out entirely.

### Study Design

Include a "None of these" alternative in some or all choice sets:

| Setting | Value |
|---------|-------|
| none_label | None of these |
| choice_type | single_with_none |

### Data Structure

```csv
resp_id,choice_set_id,alt_id,Brand,Price,Storage,chosen
1,1,1,Apple,£449,128GB,0
1,1,2,Samsung,£599,256GB,1
1,1,3,Google,£699,512GB,0
1,1,4,NONE,NONE,NONE,0
```

### Interpreting Results

**None Utility:** Represents the "outside good" or baseline threshold

```
None utility: -0.50

Interpretation:
  Products with total utility < -0.50 would lose to "None"
```

### Market Simulation with None

```
Product 1: Apple, £599, 256GB  → Utility: +0.80 → Share: 42%
Product 2: Samsung, £449, 128GB → Utility: +0.45 → Share: 28%
None option                    → Utility: -0.50 → Share: 30%
```

**Insight:** 30% of consumers would not buy any of these configurations at these prices.

---

## Common Configurations

### Standard CBC

```
Settings:
  analysis_type: choice
  estimation_method: auto
  generate_market_simulator: TRUE
  confidence_level: 0.95
```

### Alchemer Import

```
Settings:
  analysis_type: choice
  data_source: alchemer
  clean_alchemer_levels: TRUE
  choice_set_column: SetNumber
  chosen_column: Score
  respondent_id_column: ResponseID
```

### Fast Analysis (Skip Simulator)

```
Settings:
  analysis_type: choice
  estimation_method: clogit
  generate_market_simulator: FALSE
```

### Publication Quality

```
Settings:
  analysis_type: choice
  estimation_method: mlogit
  confidence_level: 0.95
  generate_market_simulator: TRUE
  baseline_handling: first_level_zero
```

---

## Tips for Success

### Design Phase

1. **Limit attributes to 4-6** - More creates respondent fatigue
2. **Use 3-4 levels per attribute** - Balance detail with parsimony
3. **Include realistic options** - Levels should reflect market reality
4. **Test your survey** - Run pilot with 30-50 respondents first

### Configuration Phase

1. **Match level names exactly** - Case-sensitive, no extra spaces
2. **Verify column names** - Check data file headers
3. **Use absolute paths** - Avoid working directory issues

### Analysis Phase

1. **Check model fit** - McFadden R² > 0.20 is good
2. **Verify hit rate** - Should exceed chance rate significantly
3. **Review warnings** - Address any validation issues

### Interpretation Phase

1. **Consider confidence intervals** - Wide intervals = uncertain estimates
2. **Test multiple scenarios** - Use simulator extensively
3. **Document assumptions** - Record configuration for reproducibility

---

## Complete Example Config

### Settings Sheet

| Setting | Value |
|---------|-------|
| analysis_type | choice |
| choice_set_column | choice_set_id |
| chosen_column | chosen |
| respondent_id_column | resp_id |
| alternative_id_column | alt_id |
| data_file | /path/to/data/choices.csv |
| output_file | /path/to/output/results.xlsx |
| estimation_method | auto |
| generate_market_simulator | TRUE |
| confidence_level | 0.95 |
| baseline_handling | first_level_zero |
| min_responses_per_level | 10 |

### Attributes Sheet

| AttributeName | NumLevels | LevelNames |
|---------------|-----------|------------|
| Brand | 4 | Apple, Samsung, Google, OnePlus |
| Price | 5 | £299, £399, £499, £599, £699 |
| Storage | 4 | 64GB, 128GB, 256GB, 512GB |
| Battery | 3 | 3000mAh, 4000mAh, 5000mAh |
| Display | 3 | 60Hz, 90Hz, 120Hz |

---

**End of Example Workflows**

*Turas Conjoint Module v2.1.0*
*Last Updated: December 2025*

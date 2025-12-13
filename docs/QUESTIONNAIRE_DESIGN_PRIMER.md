# Questionnaire Design Primer for Turas Analytics

**Purpose:** Ensure survey questionnaires are structured correctly for seamless analysis in Turas modules.

**Audience:** Researchers, questionnaire designers, project managers

**Prepared by:** The Research LampPost (Pty) Ltd
**Version:** 1.0
**Date:** December 2024

---

## Contents

1. [Introduction](#introduction)
2. [Conjoint Analysis](#conjoint-analysis)
3. [MaxDiff (Maximum Difference Scaling)](#maxdiff-maximum-difference-scaling)
4. [Segmentation](#segmentation)
5. [Key Driver Analysis](#key-driver-analysis)
6. [Pricing Research](#pricing-research)
   - Van Westendorp PSM
   - Gabor-Granger
7. [Crosstabulation (Tabs)](#crosstabulation-tabs)
8. [Tracking Studies](#tracking-studies)
9. [Common Pitfalls](#common-pitfalls)
10. [Quick Reference Checklist](#quick-reference-checklist)

---

## Introduction

The quality of your analysis is only as good as the data feeding it. This guide explains how to design questionnaires that produce data structures compatible with each Turas module.

### The Golden Rule

> **Design the questionnaire with the analysis in mind, not the other way around.**

Before writing a single question, ask:
- What decisions will this research inform?
- Which Turas module(s) will analyse this data?
- What data structure does that module require?

---

## Conjoint Analysis

### What It Measures
Conjoint analysis reveals how people make trade-offs between product/service features. It answers: *"Which features matter most, and how much is each feature worth?"*

### Survey Platform Requirements
Choice-Based Conjoint (CBC) requires specialised survey software:
- **Alchemer** (native Conjoint module) - Turas has direct import support
- **Sawtooth Software** - Export to CSV
- **Qualtrics** (Conjoint block) - Export to CSV

**Do NOT attempt to build conjoint manually in a standard survey tool** - the experimental design mathematics are critical.

### Questionnaire Design Requirements

#### 1. Define Attributes and Levels Carefully

| Consideration | Good Practice | Avoid |
|--------------|---------------|-------|
| Number of attributes | 4-7 attributes | >8 attributes (respondent fatigue) |
| Levels per attribute | 3-5 levels | >7 levels (estimation problems) |
| Level balance | Similar number of levels per attribute | One attribute with 10 levels, others with 2 |
| Level wording | Concrete, unambiguous | Vague terms like "good quality" |
| Price levels | Cover realistic market range | Prices outside believable range |

**Example - Well-Designed Attributes:**

| Attribute | Levels |
|-----------|--------|
| Brand | Brand A, Brand B, Brand C, Store Brand |
| Price | R49, R69, R89, R109 |
| Pack Size | 250g, 500g, 1kg |
| Origin | Local, Imported |

#### 2. Number of Choice Tasks

| Study Type | Recommended Tasks | Maximum |
|------------|-------------------|---------|
| Simple (4-5 attributes) | 10-12 tasks | 15 |
| Complex (6-7 attributes) | 8-10 tasks | 12 |
| With "None" option | 8-10 tasks | 12 |

**Respondent fatigue degrades data quality** - more tasks ≠ better data.

#### 3. Choice Task Structure

Each task should show:
- **2-4 product concepts** (3 is typical)
- **All attributes for each concept**
- **Optional: "None of these" option** (recommended for realism)

```
TASK EXAMPLE:
┌─────────────┬─────────────┬─────────────┬─────────────┐
│  Option A   │  Option B   │  Option C   │    None     │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ Brand A     │ Brand B     │ Store Brand │             │
│ R69         │ R89         │ R49         │ I would not │
│ 500g        │ 250g        │ 1kg         │ choose any  │
│ Local       │ Imported    │ Local       │ of these    │
├─────────────┼─────────────┼─────────────┼─────────────┤
│    ○        │    ○        │    ○        │     ○       │
└─────────────┴─────────────┴─────────────┴─────────────┘
Which would you choose?
```

#### 4. Data Export Requirements for Turas

Your export must include:

| Column | Description | Example |
|--------|-------------|---------|
| `resp_id` | Unique respondent identifier | R001, R002 |
| `task` | Task number (1, 2, 3...) | 1 |
| `concept` | Concept/alternative number | 1, 2, 3 |
| `chosen` | 1 if chosen, 0 if not | 1 |
| `[attribute columns]` | One column per attribute | brand, price, size |

**Long format required** - one row per concept shown, not one row per task.

#### 5. Sample Size Guidelines

| Attributes | Levels (total) | Minimum n | Recommended n |
|------------|---------------|-----------|---------------|
| 4-5 | 12-16 | 200 | 300-400 |
| 6-7 | 18-24 | 300 | 400-500 |
| With interactions | Any | 400+ | 500+ |

#### 6. Include a "None" Option When...
- Purchase is discretionary (respondent could choose not to buy)
- You need realistic market share predictions
- You want to measure price sensitivity at market level

#### 7. Prohibited Levels (Avoid These)
- **"Don't know"** as a level - breaks utility estimation
- **Overlapping levels** - "R50-R100" AND "R75-R125"
- **Implausible combinations** - ensure all concept combinations make sense

---

## MaxDiff (Maximum Difference Scaling)

### What It Measures
MaxDiff forces respondents to make trade-offs, revealing the relative importance of items on a ratio scale. It answers: *"Which items are most/least important?"*

### When to Use MaxDiff vs. Rating Scales

| Use MaxDiff When... | Use Rating Scales When... |
|---------------------|--------------------------|
| You have 8-30 items to prioritise | You have <8 items |
| You need discrimination between items | Absolute levels matter |
| Rating scale data shows "everything is important" | Items are independent |
| You need ratio-scale data | You need individual item scores |

### Questionnaire Design Requirements

#### 1. Item List Development

| Consideration | Good Practice | Avoid |
|--------------|---------------|-------|
| Number of items | 10-25 items | <8 items (use ratings) or >30 items |
| Item clarity | Short, concrete statements | Long, complex statements |
| Item independence | Each item is distinct | Overlapping concepts |
| Item balance | Mix of expected high/low importance | All similarly important items |

**Example - Well-Written Items (Product Features):**
```
- Long battery life
- Lightweight design
- Fast processing speed
- Large storage capacity
- High-resolution display
- Water resistance
- Wireless charging
- Fingerprint security
```

**Example - Poorly-Written Items:**
```
- Good quality (too vague)
- Long battery life and fast charging (double-barreled)
- The device should be able to perform multiple tasks simultaneously
  without experiencing slowdowns or crashes (too long)
```

#### 2. Task Structure

Each MaxDiff task shows a subset of items. Respondent selects:
- **BEST** (most important/preferred)
- **WORST** (least important/preferred)

```
TASK EXAMPLE:
┌─────────────────────────────────────────────┐
│ Which feature is MOST important to you?     │
│ Which feature is LEAST important to you?    │
├───────┬─────────────────────────────┬───────┤
│ BEST  │         Feature             │ WORST │
├───────┼─────────────────────────────┼───────┤
│  ○    │ Long battery life           │   ○   │
│  ○    │ Lightweight design          │   ○   │
│  ○    │ Water resistance            │   ○   │
│  ○    │ Wireless charging           │   ○   │
└───────┴─────────────────────────────┴───────┘
```

#### 3. Design Parameters

| Parameter | Recommendation | Rationale |
|-----------|---------------|-----------|
| Items per task | 4-5 items | Balance of discrimination and simplicity |
| Number of tasks | Items × 3 ÷ items_per_task | Each item appears ~3 times |
| Total tasks | 10-15 tasks | Respondent fatigue threshold |

**Example Calculation:**
- 20 items, 4 items per task
- Tasks needed: 20 × 3 ÷ 4 = 15 tasks
- Each item appears approximately 3 times

#### 4. Use Turas Design Generator

Turas MaxDiff module can generate optimal experimental designs:

```
Mode: DESIGN
Items: [list of items]
Items_Per_Task: 4
Number_Of_Tasks: 12
Design_Type: OPTIMAL
```

This ensures:
- Balanced item appearance
- Orthogonality (statistical efficiency)
- Position balance (items appear equally in each position)

#### 5. Data Export Format

| Column | Description | Example |
|--------|-------------|---------|
| `resp_id` | Respondent identifier | R001 |
| `task` | Task number | 1 |
| `item_1` through `item_4` | Items shown in task | "Battery", "Weight"... |
| `best` | Item chosen as best | "Battery" |
| `worst` | Item chosen as worst | "Weight" |

#### 6. Sample Size Guidelines

| Number of Items | Minimum n | Recommended n |
|-----------------|-----------|---------------|
| 10-15 | 150 | 200-300 |
| 16-20 | 200 | 300-400 |
| 21-30 | 300 | 400-500 |

For segment-level analysis, multiply by number of segments.

#### 7. Common MaxDiff Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Items too similar | Poor discrimination | Ensure conceptual distinctiveness |
| Mixing categories | Confuses respondents | Group similar items or separate studies |
| Leading wording | Biased results | Neutral, factual wording |
| Too many tasks | Fatigue, random responding | Max 15 tasks |

---

## Segmentation

### What It Measures
Segmentation identifies natural groupings of respondents based on their attitudes, needs, or behaviours. It answers: *"What distinct customer types exist in this market?"*

### Questionnaire Design Requirements

#### 1. Segmentation Basis Variables

These are the variables used to CREATE segments. Choose carefully:

| Good Basis Variables | Poor Basis Variables |
|---------------------|---------------------|
| Attitudes and beliefs | Demographics alone |
| Needs and motivations | Single behaviours |
| Values and priorities | Satisfaction ratings |
| Usage patterns (multiple) | Awareness questions |

**Rule:** Segment on variables that are **actionable** and **stable**.

#### 2. Scale Design for Segmentation

| Requirement | Recommendation | Rationale |
|-------------|---------------|-----------|
| Scale type | 5-7 point agreement scales | Provides variance for clustering |
| Number of items | 15-40 statements | Enough for factor structure |
| Scale anchors | Fully labelled | Consistent interpretation |
| Battery balance | Mix of positive/negative wording | Reduces acquiescence bias |

**Example Battery:**
```
How much do you agree or disagree with each statement?
(1=Strongly Disagree ... 7=Strongly Agree)

1. I always look for the lowest price
2. Quality is more important than price to me
3. I enjoy trying new brands
4. I stick with brands I know and trust
5. I do extensive research before buying
6. I often buy on impulse
... (continue with 20-30 statements)
```

#### 3. Include Profiling Variables

Beyond segmentation basis, include variables to DESCRIBE segments:

| Category | Examples |
|----------|----------|
| Demographics | Age, gender, income, education, location |
| Behaviours | Purchase frequency, channel usage, brand repertoire |
| Category usage | Heavy/medium/light user, occasions |
| Media | Channels used, social media platforms |

**These are NOT used to create segments** but to describe and target them afterward.

#### 4. Sample Size for Segmentation

| Expected Segments | Minimum Total n | Recommended |
|-------------------|-----------------|-------------|
| 3-4 segments | 300 | 500 |
| 5-6 segments | 500 | 800 |
| 7+ segments | 800+ | 1000+ |

**Rule of thumb:** Minimum 100 respondents per expected segment.

#### 5. Data Quality Considerations

| Issue | Detection | Prevention |
|-------|-----------|------------|
| Straightlining | All same response in battery | Include attention checks |
| Speeding | Completion time <1/3 median | Set minimum time thresholds |
| Contradictions | Logically inconsistent responses | Include trap questions |

Turas Segment module includes outlier detection, but prevention is better.

#### 6. Variable Preparation Tips

- **Standardise scales** - All variables should use same direction (e.g., higher = more agreement)
- **Recode if needed** - Reverse negative items before analysis
- **Handle missing data** - Decide policy upfront (listwise deletion, imputation)
- **Remove low-variance items** - Items where 90%+ give same response add noise

---

## Key Driver Analysis

### What It Measures
Key Driver Analysis identifies which attributes most influence an outcome (e.g., satisfaction, likelihood to recommend). It answers: *"What should we prioritise to improve the outcome?"*

### Questionnaire Design Requirements

#### 1. Structure: Outcome + Drivers

```
┌─────────────────────────────────────────────────────┐
│                 KEY DRIVER STRUCTURE                │
├─────────────────────────────────────────────────────┤
│  OUTCOME (Dependent Variable)                       │
│  - Overall satisfaction                             │
│  - Likelihood to recommend                          │
│  - Likelihood to repurchase                         │
├─────────────────────────────────────────────────────┤
│  DRIVERS (Independent Variables)                    │
│  - Product quality                                  │
│  - Value for money                                  │
│  - Customer service                                 │
│  - Ease of use                                      │
│  - Brand reputation                                 │
│  ... (10-20 attribute ratings)                      │
└─────────────────────────────────────────────────────┘
```

#### 2. Outcome Variable Design

| Requirement | Recommendation |
|-------------|---------------|
| Scale points | 10-point or 11-point (0-10) |
| Single item | One clear overall measure |
| Position | Ask BEFORE attribute ratings |
| Wording | Standard, validated wording |

**Standard Outcome Questions:**
```
Overall Satisfaction:
"Overall, how satisfied are you with [brand/product]?"
0 = Extremely dissatisfied ... 10 = Extremely satisfied

Net Promoter Score:
"How likely are you to recommend [brand] to a friend or colleague?"
0 = Not at all likely ... 10 = Extremely likely

Repurchase Intent:
"How likely are you to purchase [brand] again?"
0 = Definitely will not ... 10 = Definitely will
```

#### 3. Driver Variable Design

| Requirement | Recommendation | Rationale |
|-------------|---------------|-----------|
| Number of drivers | 10-25 attributes | Too few = incomplete; too many = multicollinearity |
| Scale points | Same as outcome (10-point) | Consistent scale interpretation |
| Specificity | Concrete, actionable attributes | "Helpful staff" not "Good service" |
| Coverage | All relevant touchpoints | Map customer journey |
| Independence | Distinct attributes | Avoid "fast" and "quick" |

**Example Driver Battery:**
```
How satisfied are you with each of the following?
(0=Extremely dissatisfied ... 10=Extremely satisfied)

Product Attributes:
- Product quality
- Product durability
- Range of options available
- Value for money

Service Attributes:
- Helpfulness of staff
- Speed of service
- Ease of finding products
- Checkout experience

Brand Attributes:
- Brand reputation
- Trust in the brand
- Brand innovation
```

#### 4. Question Order

```
RECOMMENDED ORDER:
1. Screening/qualification
2. OUTCOME question (overall satisfaction)
3. DRIVER questions (attribute ratings)
4. Open-ended feedback (optional)
5. Demographics
```

**Ask outcome BEFORE drivers** to get unprimed overall impression.

#### 5. Handling "Not Applicable" Responses

Some attributes may not apply to all respondents:

| Approach | Pros | Cons |
|----------|------|------|
| N/A option | Honest data | Reduces sample per attribute |
| Skip logic | Clean data | Complex programming |
| Force response | Full data | May introduce noise |

**Recommendation:** Include N/A option, handle as missing in analysis.

#### 6. Sample Size for Key Drivers

| Number of Drivers | Minimum n | Recommended n |
|-------------------|-----------|---------------|
| 10-15 | 200 | 300 |
| 16-20 | 300 | 400 |
| 21-25 | 400 | 500 |

For subgroup analysis (e.g., by segment), ensure n≥100 per subgroup.

#### 7. SHAP Analysis Considerations

If using Turas SHAP (machine learning-based) driver analysis:

- **More data is better** - SHAP benefits from n>500
- **Include potential interactions** - SHAP detects non-linear effects
- **Binary/categorical drivers OK** - Not limited to continuous scales

---

## Pricing Research

### Van Westendorp Price Sensitivity Meter (PSM)

#### What It Measures
PSM identifies the acceptable price range and optimal price point through four price perception questions.

#### The Four Questions (EXACT WORDING CRITICAL)

These questions must be asked in this order:

```
Q1: TOO CHEAP (Quality Concern)
"At what price would you consider [product] to be so cheap that
you would question its quality and not consider buying it?"
[Open numeric response]

Q2: BARGAIN (Good Value)
"At what price would you consider [product] to be a bargain -
a great buy for the money?"
[Open numeric response]

Q3: EXPENSIVE (But Would Consider)
"At what price would you consider [product] to be getting
expensive, but you still might consider buying it?"
[Open numeric response]

Q4: TOO EXPENSIVE (Would Not Buy)
"At what price would you say [product] is too expensive to
consider buying?"
[Open numeric response]
```

#### Design Requirements

| Requirement | Specification |
|-------------|--------------|
| Question type | Open numeric (not pre-coded ranges) |
| Currency | Appropriate for market (R, $, £, etc.) |
| Response validation | Ensure Q1 < Q2 < Q3 < Q4 |
| Product description | Clear, specific product shown |
| Context | Realistic purchase scenario |

#### Product Stimulus

Before asking price questions, show:
```
┌────────────────────────────────────────────────────┐
│ [PRODUCT IMAGE]                                    │
│                                                    │
│ Product: Premium Wireless Earbuds                  │
│                                                    │
│ Features:                                          │
│ • Active noise cancellation                        │
│ • 24-hour battery life                            │
│ • Water resistant (IPX4)                          │
│ • Touch controls                                   │
│                                                    │
│ Imagine you are considering purchasing this        │
│ product. Please answer the following questions     │
│ about pricing.                                     │
└────────────────────────────────────────────────────┘
```

#### Data Validation Rules

Build validation into survey to catch errors:

| Check | Rule | Action |
|-------|------|--------|
| Logical order | Q1 ≤ Q2 ≤ Q3 ≤ Q4 | Show error, request correction |
| Minimum value | >0 | Reject zero/negative |
| Maximum value | Reasonable ceiling | Flag outliers |
| Non-numeric | Numbers only | Reject text |

#### Sample Size
- **Minimum:** 100 respondents
- **Recommended:** 200-300 respondents
- **For segments:** 100+ per segment

---

### Gabor-Granger (Direct Price Demand)

#### What It Measures
Gabor-Granger measures purchase intent at specific price points to build a demand curve.

#### Question Structure

```
SCENARIO:
Imagine [product] is available at the following price.

[PRODUCT IMAGE/DESCRIPTION]
Price: R699

How likely would you be to purchase this product at this price?

○ Definitely would buy
○ Probably would buy
○ Might or might not buy
○ Probably would not buy
○ Definitely would not buy
```

#### Design Approaches

**Approach 1: Randomised Single Price**
- Each respondent sees ONE price (randomly assigned)
- Requires larger sample (n per price point)
- No order effects
- **Best for:** Realistic demand estimation

**Approach 2: Sequential Price Ladder**
- Start at mid-price, adjust based on response
- Fewer questions per respondent
- Potential anchoring effects
- **Best for:** Efficiency with smaller samples

**Approach 3: Full Price Battery**
- Each respondent rates ALL prices
- Rich individual data
- Strong order effects (randomise order)
- **Best for:** Directional insights only

#### Price Point Selection

| Consideration | Recommendation |
|---------------|---------------|
| Number of prices | 5-7 price points |
| Price range | Cover ±30-50% of expected optimal |
| Price spacing | Equal intervals (e.g., R50 increments) |
| Include anchors | Current market price, competitor prices |

**Example Price Ladder:**
```
For a product currently priced around R500:
- R350 (-30%)
- R425 (-15%)
- R500 (anchor)
- R575 (+15%)
- R650 (+30%)
- R750 (+50%)
```

#### Sample Size

| Design | Per Price Point | Total n |
|--------|-----------------|---------|
| Randomised single | 100+ | 500-700 |
| Sequential | 50+ | 200-300 |
| Full battery | 50+ | 200-300 |

---

## Crosstabulation (Tabs)

### What It Measures
Crosstabulation shows how responses to one question break down by another variable (banner), with significance testing to identify real differences.

### Questionnaire Design for Effective Tabs

#### 1. Banner Variable Design

Banners are the column headers in your crosstab (e.g., Age groups, Regions).

| Requirement | Good Practice | Avoid |
|-------------|---------------|-------|
| Mutually exclusive | Each respondent in ONE category | Overlapping categories |
| Exhaustive | All respondents classified | Missing categories |
| Meaningful groups | Analytically useful breaks | Arbitrary divisions |
| Adequate base sizes | n≥30 per banner point | Tiny cells (n<30) |

**Example - Good Banner Design (Age):**
```
Age Groups:
○ 18-24 years
○ 25-34 years
○ 35-44 years
○ 45-54 years
○ 55-64 years
○ 65+ years
```

**Avoid:**
```
Bad: "18-30, 25-40, 35-50, 45+" (overlapping!)
Bad: "Young, Middle, Old" (subjective)
```

#### 2. Response Option Design

For clear crosstabs:

| Consideration | Recommendation |
|---------------|---------------|
| Scales | Use consistent scale points across battery |
| Single vs. multi | Decide upfront (affects % calculation) |
| "Other (specify)" | Include but keep distinct from main codes |
| "Don't know" | Separate from substantive responses |
| Missing data | Have explicit handling plan |

#### 3. Net Codes and Calculations

Plan derived variables at questionnaire stage:

```
SATISFACTION QUESTION (Q5):
1 = Very dissatisfied
2 = Somewhat dissatisfied
3 = Neither satisfied nor dissatisfied
4 = Somewhat satisfied
5 = Very satisfied

PLANNED NETS:
- Top 2 Box: Codes 4+5
- Bottom 2 Box: Codes 1+2
- Net Satisfaction: Top 2 Box - Bottom 2 Box
```

#### 4. Multi-Mention Questions

For questions where respondents can select multiple answers:

```
Q: Which of these brands have you heard of? (Select all that apply)
□ Brand A
□ Brand B
□ Brand C
□ Brand D
□ None of these [EXCLUSIVE]
```

**Data structure:** One column per option (0/1 coding) OR single column with comma-separated codes.

#### 5. Weighting Considerations

Design questionnaire to capture weighting variables:
- Demographics matching census data
- Quota variables (for rim weighting)
- Any stratification variables

---

## Tracking Studies

### What It Measures
Tracking monitors how metrics change over time (waves), identifying trends and the impact of market activities.

### Questionnaire Design for Tracking

#### 1. The Cardinal Rule

> **NEVER change question wording between waves without very good reason.**

Any change makes wave-over-wave comparison invalid for that question.

#### 2. Questionnaire Consistency Checklist

| Element | Keep Consistent | Document Any Changes |
|---------|-----------------|---------------------|
| Question wording | Exact same text | Full change log |
| Response options | Same codes, same order | Mapping table |
| Scale anchors | Same labels | Explanation of change |
| Question order | Same position | Impact assessment |
| Skip logic | Same routing | Version comparison |
| Brand/product lists | Add new, never remove | Tracking of additions |

#### 3. Handling Brand List Changes

**Adding new brands:**
```
Wave 1: Brand A, Brand B, Brand C
Wave 2: Brand A, Brand B, Brand C, Brand D (new entrant)

✓ OK - Add new brands at end
✓ OK - Randomise order presentation (if doing so from start)
```

**Removing brands:**
```
DON'T remove brands that exit market - keep for comparison
DO add "No longer available" filter if needed
```

#### 4. Multi-Mention Tracking

For questions with multiple responses, track at multiple levels:

```
TRACKING METRICS:
- % mentioning each brand (individual)
- Average number of brands mentioned
- % mentioning ANY brand
- % mentioning Brand A AND Brand B (overlap)
```

#### 5. Wave Identification

Ensure wave metadata is captured:

| Variable | Purpose |
|----------|---------|
| Wave number | 1, 2, 3... |
| Wave date | Fieldwork dates |
| Wave label | "Q1 2024", "Jan 2024" |
| Sample source | Panel, intercept, etc. |

#### 6. Sample Consistency

| Factor | Recommendation |
|--------|---------------|
| Methodology | Same data collection method |
| Sample source | Same panel/source |
| Quotas | Same quota structure |
| Weighting | Same weighting approach |
| Sample size | Consistent n per wave |

#### 7. Significance Testing Considerations

Design for adequate power to detect meaningful changes:

| Change to Detect | n per Wave (approx) |
|------------------|---------------------|
| ±5 percentage points | 400 |
| ±3 percentage points | 1,000 |
| ±2 percentage points | 2,500 |

---

## Common Pitfalls

### Cross-Module Pitfalls

| Pitfall | Affected Modules | Solution |
|---------|------------------|----------|
| Inconsistent scales | All | Standardise scale points |
| Missing demographics | Tabs, Segment | Include full demo battery |
| Poor data quality | All | Attention checks, speeder flags |
| Small sample size | All | Power calculations upfront |
| Ambiguous wording | All | Cognitive testing |

### Module-Specific Pitfalls

| Module | Common Mistake | Solution |
|--------|---------------|----------|
| **Conjoint** | Too many attributes | Limit to 5-7 |
| **Conjoint** | Unrealistic prices | Research market first |
| **MaxDiff** | Similar items | Ensure distinctiveness |
| **MaxDiff** | Too many items | Max 25-30 |
| **Segment** | Demo-only segmentation | Use attitudes/needs |
| **Segment** | Too few basis variables | 15-40 statements |
| **KeyDriver** | Outcome after drivers | Outcome FIRST |
| **KeyDriver** | Overlapping drivers | Distinct attributes |
| **Van Westendorp** | Pre-coded prices | Open numeric only |
| **Gabor-Granger** | Wrong price range | Research market first |
| **Tabs** | Overlapping banners | Mutually exclusive |
| **Tracker** | Changed wording | Version control |

---

## Quick Reference Checklist

### Pre-Fielding Checklist

#### Conjoint
- [ ] 4-7 attributes defined
- [ ] 3-5 levels per attribute
- [ ] Experimental design generated
- [ ] None option included (if appropriate)
- [ ] 8-12 choice tasks
- [ ] Sample size calculated (min 200-300)

#### MaxDiff
- [ ] 10-25 distinct items
- [ ] Items clearly worded
- [ ] Optimal design generated
- [ ] 4-5 items per task
- [ ] 10-15 total tasks
- [ ] Sample size calculated (min 200)

#### Segmentation
- [ ] 15-40 basis statements
- [ ] Consistent scale used (5-7 point)
- [ ] Profiling variables included
- [ ] Quality checks included
- [ ] Sample size adequate (min 300-500)

#### Key Drivers
- [ ] Outcome question first
- [ ] 10-25 driver attributes
- [ ] Same scale for outcome and drivers
- [ ] Drivers are actionable
- [ ] N/A option if needed
- [ ] Sample size adequate (min 200-300)

#### Van Westendorp
- [ ] All 4 questions in correct order
- [ ] Open numeric response
- [ ] Validation rules programmed
- [ ] Clear product description
- [ ] Sample size adequate (min 200)

#### Gabor-Granger
- [ ] 5-7 price points
- [ ] Realistic price range
- [ ] Standard purchase intent scale
- [ ] Clear product description
- [ ] Sample design chosen (randomised/sequential)

#### Crosstabs
- [ ] Banner variables mutually exclusive
- [ ] Net codes defined
- [ ] Multi-mention handling specified
- [ ] Weighting variables captured
- [ ] Base sizes adequate (n≥30 per cell)

#### Tracking
- [ ] Base questionnaire locked
- [ ] Change log established
- [ ] Wave identifiers included
- [ ] Sample methodology consistent
- [ ] Power calculations done

---

## Appendix: Data Export Specifications

### Turas Data Format Requirements

| Module | Format | Key Columns |
|--------|--------|-------------|
| Conjoint | Long format CSV/Excel | resp_id, task, concept, chosen, [attributes] |
| MaxDiff | Wide format CSV/Excel | resp_id, task, item_1...item_n, best, worst |
| Segment | Wide format | resp_id, [basis variables], [profiling variables] |
| KeyDriver | Wide format | resp_id, outcome, [driver_1...driver_n] |
| Pricing | Wide format | resp_id, too_cheap, bargain, expensive, too_expensive |
| Tabs | Wide format | resp_id, [questions], [banners], weight |
| Tracker | Wide format per wave | resp_id, wave, [questions], weight |

---

*For technical specifications on data formatting, refer to each module's USER_MANUAL.md documentation.*

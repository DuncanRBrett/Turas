# Questionnaire Design Guide for Pricing Research

**Turas Pricing Module -- Survey Design Reference**
**Version:** 1.0
**Last Updated:** March 2026

---

## Contents

1. [Introduction](#introduction)
2. [Decision Tree: Choosing the Right Method](#decision-tree-choosing-the-right-method)
3. [Van Westendorp Price Sensitivity Meter](#van-westendorp-price-sensitivity-meter)
4. [Gabor-Granger Survey Design](#gabor-granger-survey-design)
5. [Monadic Price Testing](#monadic-price-testing)
6. [Price Point Selection](#price-point-selection)
7. [Common Mistakes and How to Avoid Them](#common-mistakes-and-how-to-avoid-them)
8. [Sample Size Guidelines](#sample-size-guidelines)
9. [Survey Platform Notes and Data Preparation](#survey-platform-notes-and-data-preparation)
10. [Appendix: Quick Reference Tables](#appendix-quick-reference-tables)

---

## Introduction

Pricing research is one of the highest-stakes areas in market research. A well-designed
pricing study provides actionable intelligence that directly impacts revenue, margin, and
competitive positioning. A poorly designed one produces numbers that look precise but
mislead.

This guide covers the practical survey design decisions you need to make before fielding
a pricing study that will be analysed with the Turas Pricing Module. It is written for
market researchers who are designing questionnaires, not for statisticians reading output.
The focus is on what to ask, how to ask it, and how to structure your data so that
analysis runs cleanly and produces trustworthy results.

**Three principles underpin every recommendation in this guide:**

1. **The quality of your output cannot exceed the quality of your input.** No analytical
   method can rescue a badly worded question or a biased sample.

2. **Respondents are answering hypothetical questions about price.** They are not
   standing in a store with money in their hand. Design your survey to minimise the gap
   between stated and actual behaviour.

3. **Every design choice involves a trade-off.** There is no universally best method.
   The right approach depends on your research objectives, product maturity, budget, and
   the decisions that will be made with the results.

---

## Decision Tree: Choosing the Right Method

### Method Overview

The Turas Pricing Module supports three core methodologies. Each answers a different
primary question:

| Method | Primary Question | Output |
|--------|-----------------|--------|
| **Van Westendorp PSM** | What price range do consumers consider acceptable? | Acceptable price range (PMC to PME), optimal price point (OPP), indifference price (IDP) |
| **Gabor-Granger** | At what price is revenue (or profit) maximised? | Demand curve, revenue curve, optimal price, price elasticity |
| **Monadic** | What is the unbiased demand function across prices? | Logistic demand curve, revenue/profit optimisation, confidence intervals |
| **Combined (VW + GG)** | What is both the acceptable range and the optimal price within it? | Triangulated recommendation with confidence scoring |

### When to Use Each Method

#### Van Westendorp PSM

**Best for:**
- New products or categories where no reference price exists
- Exploratory research to understand the boundaries of price acceptability
- Early-stage pricing decisions where you need to understand the "playing field"
- Studies where you want to understand the psychology of price perception

**Not ideal for:**
- Finding a single optimal price (use Gabor-Granger or Monadic)
- Products with well-established market prices (respondents anchor to current price)
- Situations requiring precise demand forecasting

**Typical use cases:**
- "We are launching a new subscription tier -- what price range makes sense?"
- "We are entering a new market -- what prices feel credible to consumers?"
- "How does price perception differ between customer segments?"

#### Gabor-Granger

**Best for:**
- Existing products where you want to optimise price within a known range
- Finding the revenue-maximising or profit-maximising price from a set of candidates
- Building a demand curve from discrete price points
- Studies where you want to quantify price elasticity

**Not ideal for:**
- Truly new categories where you do not know the plausible price range
- Situations requiring unbiased between-subjects measurement (use Monadic)
- Products where showing multiple prices might create anchoring effects

**Typical use cases:**
- "Should we price at $29, $39, or $49?"
- "What is the demand curve for our product?"
- "How sensitive are customers to a 10% price increase?"

#### Monadic Price Testing

**Best for:**
- Maximum statistical rigour and unbiased estimation
- Academic research or regulatory contexts requiring clean methodology
- Situations where anchoring and order effects must be eliminated
- Building a continuous demand function (not limited to discrete price points)

**Not ideal for:**
- Small total sample sizes (you need enough respondents per cell)
- Tight budgets (requires larger total sample than other methods)
- Exploratory studies where the price range is unknown

**Typical use cases:**
- "We need a defensible, unbiased demand estimate for board-level pricing decisions"
- "We want to model demand as a continuous function of price"
- "We need confidence intervals around our optimal price estimate"

#### Combined (Van Westendorp + Gabor-Granger)

**Best for:**
- Comprehensive studies where budget allows for deeper insight
- Triangulating findings across complementary methods
- Studies feeding into high-stakes pricing decisions

**Not ideal for:**
- Short surveys with strict length constraints
- Studies where respondent fatigue is a major concern
- Situations where one method clearly fits the research question

### Decision Matrix

Use this matrix to guide your method selection:

```
START HERE
    |
    v
Do you know the plausible price range?
    |
    +-- NO --> Van Westendorp (explore the range first)
    |              |
    |              +-- Then optionally follow with Gabor-Granger
    |                  in a second wave using the VW range
    |
    +-- YES --> Is eliminating order/anchoring bias critical?
                    |
                    +-- YES --> Monadic (each respondent sees one price)
                    |              |
                    |              +-- Do you have budget for 30+ per cell?
                    |                    |
                    |                    +-- NO --> Fall back to Gabor-Granger
                    |                    +-- YES --> Proceed with Monadic
                    |
                    +-- NO --> Do you want a demand curve from specific prices?
                                |
                                +-- YES --> Gabor-Granger
                                |
                                +-- NO --> Do you want both range + optimisation?
                                              |
                                              +-- YES --> Combined (VW + GG)
                                              +-- NO --> Van Westendorp
```

### Quick Selection Table

| Criterion | VW | GG | Monadic | Combined |
|-----------|----|----|---------|----------|
| New product / unknown range | Excellent | Poor | Moderate | Good |
| Existing product optimisation | Moderate | Excellent | Excellent | Excellent |
| Demand curve construction | No | Yes | Yes | Yes |
| Revenue optimisation | Indirect | Direct | Direct | Direct |
| Freedom from order effects | Yes | No | Yes | Partial |
| Survey length (minutes) | 2-3 | 3-5 | 1-2 | 5-8 |
| Minimum sample size | 200 | 150 | 150-300+ | 300 |
| Statistical rigour | Moderate | Moderate | High | High |
| Cost efficiency | High | High | Low | Low |

---

## Van Westendorp Price Sensitivity Meter

### Overview

The Van Westendorp PSM uses four price perception questions to map the boundaries
of acceptable pricing. Each respondent provides four open-ended price values, creating
cumulative distribution curves whose intersections define key price points.

### The Four Core Questions

The standard Van Westendorp PSM requires exactly four questions, always asked in a
specific conceptual order. The Turas module maps these to four configuration columns:

| # | Config Column | Concept | Standard Wording |
|---|---------------|---------|-----------------|
| 1 | `col_too_cheap` | Too Cheap | "At what price would you consider [PRODUCT] to be so cheap that you would question its quality?" |
| 2 | `col_cheap` | Cheap / Bargain | "At what price would you consider [PRODUCT] to be a bargain -- a great buy for the money?" |
| 3 | `col_expensive` | Expensive | "At what price would you consider [PRODUCT] to be starting to get expensive -- not out of the question, but you would have to think about buying it?" |
| 4 | `col_too_expensive` | Too Expensive | "At what price would you consider [PRODUCT] to be so expensive that you would never consider buying it?" |

### Question Wording Templates

#### Template A: Standard Wording (Recommended)

Use this wording for most consumer pricing studies. It is the closest to Van Westendorp's
original formulation and is well-understood by respondents.

```
Thinking about [PRODUCT DESCRIPTION], please answer the following
questions. There are no right or wrong answers -- we are interested
in your personal opinion.

Q1. At what price would you consider [PRODUCT] to be so inexpensive
    that you would have doubts about its quality?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]

Q2. At what price would you consider [PRODUCT] to be a bargain --
    a great buy for the money?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]

Q3. At what price would you consider [PRODUCT] to be getting
    expensive -- you would still consider buying it, but you
    would need to think carefully?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]

Q4. At what price would you consider [PRODUCT] to be so expensive
    that you would never consider buying it, regardless of
    its qualities?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]
```

#### Template B: Simplified Wording

Use this for studies with lower-literacy audiences, mobile-first surveys, or
categories where respondents may not be familiar with the product.

```
We would like to understand your feelings about the pricing of
[PRODUCT DESCRIPTION].

Q1. Below what price would [PRODUCT] seem "too cheap" --
    cheap enough to make you suspicious of its quality?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]

Q2. What price would make [PRODUCT] feel like a really
    good deal?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]

Q3. At what price does [PRODUCT] start to feel expensive
    to you?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]

Q4. Above what price would [PRODUCT] be completely out
    of the question for you?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]
```

#### Template C: B2B / Enterprise Wording

Use this for business-to-business or enterprise pricing studies where the buyer
is making decisions on behalf of an organisation.

```
Considering [PRODUCT/SERVICE DESCRIPTION] for your organisation's
needs, please provide your price expectations in [CURRENCY].

Q1. At what price point would you question whether [PRODUCT]
    could deliver adequate quality or reliability for your
    business requirements?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]

Q2. At what price point would you consider [PRODUCT] to
    represent strong value for the capabilities provided?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]

Q3. At what price point would [PRODUCT] require budget
    justification or additional approval within your
    organisation?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]

Q4. At what price point would [PRODUCT] be entirely
    outside your organisation's budget consideration,
    regardless of its capabilities?

    [OPEN-ENDED NUMERIC FIELD] [CURRENCY]
```

### Question Order

**Always present the questions in the order shown above** (too cheap, cheap, expensive,
too expensive). This follows the natural cognitive progression from low to high and
matches respondent expectations.

Some practitioners advocate randomising question order to reduce order effects. This is
**not recommended** for Van Westendorp because:

1. The questions have a logical sequence that aids comprehension.
2. Randomisation increases the rate of logically inconsistent responses (violations).
3. The Van Westendorp method was developed and validated with the standard order.

### Response Format

**Use open-ended numeric fields**, not drop-down menus or sliders with predefined
ranges. The point of Van Westendorp is to let respondents define the boundaries
themselves.

- Allow decimal values if relevant to your product category (e.g., $4.99).
- Set a reasonable minimum (e.g., 0 or 0.01) and maximum (e.g., 10x the expected
  highest price) to catch obvious data entry errors.
- Do not pre-populate with default values -- this creates anchoring.
- Consider adding input validation to prevent text entries, negative numbers,
  or obviously impossible values (e.g., $0.00 for a car).

### Product Description

The quality of your Van Westendorp results depends heavily on what respondents
are evaluating. Before the pricing questions, include:

1. **A clear product description** (2-3 sentences) covering what the product does,
   who it is for, and any key differentiators.
2. **A visual if possible** -- product image, mockup, or concept board.
3. **Feature specification** if relevant (e.g., subscription tier features,
   product specifications).

Do NOT:
- Show the current price or any price before the VW questions.
- Show competitor prices before the VW questions.
- Include promotional language ("amazing", "premium", "exclusive").
- Change the product description between segments if you plan to compare segments.

### NMS Extension (Newton-Miller-Smith)

The NMS extension adds purchase intent calibration to the standard Van Westendorp
analysis. It requires one or two additional questions asked after the core four.

#### When to Include NMS

Include the NMS extension when:
- You want a revenue-optimised price recommendation (not just a range)
- You need to calibrate stated price preferences against purchase likelihood
- Your study feeds into revenue forecasting models

Skip NMS when:
- You only need directional range guidance
- Survey length is tightly constrained
- Your sample size is below 200

#### NMS Question Wording

The NMS extension asks about purchase likelihood at two of the respondent's own
stated price points. These questions should appear immediately after the four
core Van Westendorp questions.

```
You indicated that [CURRENCY][Q2 RESPONSE] would be a bargain price
for [PRODUCT].

Q5a. How likely would you be to purchase [PRODUCT] at
     [CURRENCY][Q2 RESPONSE]?

     ( ) Definitely would buy
     ( ) Probably would buy
     ( ) Might or might not buy
     ( ) Probably would not buy
     ( ) Definitely would not buy

You indicated that [CURRENCY][Q3 RESPONSE] is the price where
[PRODUCT] starts to feel expensive.

Q5b. How likely would you be to purchase [PRODUCT] at
     [CURRENCY][Q3 RESPONSE]?

     ( ) Definitely would buy
     ( ) Probably would buy
     ( ) Might or might not buy
     ( ) Probably would not buy
     ( ) Definitely would not buy
```

For Turas, map these to the configuration columns:
- `col_pi_cheap` -- the purchase intent at the "bargain" price (Q5a)
- `col_pi_expensive` -- the purchase intent at the "expensive" price (Q5b)

**Scale coding:** Recode the 5-point scale to probabilities before analysis:
- Definitely would buy = 0.90 (or 0.70 in conservative models)
- Probably would buy = 0.70 (or 0.50)
- Might or might not buy = 0.50 (or 0.30)
- Probably would not buy = 0.20 (or 0.10)
- Definitely would not buy = 0.05 (or 0.02)

The exact calibration depends on your category. Established conventions exist for
FMCG (fast-moving consumer goods) vs. durable goods vs. services.

### Van Westendorp Validation Rules

The Turas module validates VW data against several quality criteria. Design your
survey to minimise failures on these checks:

| Check | Threshold | How to Prevent Failures |
|-------|-----------|------------------------|
| Logical ordering | < 10% violations | Clear question wording, show questions in order |
| Missing data rate | < 20% | Make questions required, validate on submission |
| Minimum sample | 30+ complete cases | Target 200+ total to allow for exclusions |
| Positive prices | 0 violations | Validate numeric input > 0 in survey platform |
| Extreme outliers | < 5% extreme | Set reasonable min/max bounds on input fields |
| Straight-lining | < 5% all-identical | Check for engagement; consider attention checks |

---

## Gabor-Granger Survey Design

### Overview

Gabor-Granger measures purchase intent at specific price points to construct a demand
curve. Each respondent evaluates the same set of prices, and the aggregate purchase
intent at each price creates the demand function.

### Survey Structure Options

There are two main approaches to presenting price points:

#### Sequential Presentation (Traditional)

The respondent is shown prices one at a time, either ascending or descending. If they
say "yes" at a low price, you increase; if "no" at a high price, you decrease.

**Advantages:**
- Fewer questions per respondent (can stop early)
- More natural buying decision process

**Disadvantages:**
- Strong order effects (anchor to first price seen)
- Cannot randomise without changing the method fundamentally

#### Randomised Full Presentation (Recommended)

Each respondent evaluates ALL price points, but the order is randomised. This is
the approach best supported by the Turas module.

**Advantages:**
- Eliminates order effects within respondent
- Produces data at every price point from every respondent
- More robust demand curve

**Disadvantages:**
- More questions per respondent (potential fatigue)
- Respondent may become strategic in later evaluations

**Recommendation:** Use randomised full presentation with 5-7 price points unless
you have a strong methodological reason for sequential.

### Number of Price Points

| Guideline | Recommendation |
|-----------|---------------|
| **Minimum** | 4 price points |
| **Recommended** | 5-7 price points |
| **Maximum** | 9 price points (beyond this, fatigue degrades data quality) |
| **Sweet spot** | 6 price points (good resolution, manageable respondent burden) |

**Rules of thumb:**
- 5 points: Adequate for most consumer products
- 6-7 points: Ideal for products with wide price ranges or when you need to
  detect subtle elasticity changes
- 8-9 points: Only when testing a very wide range or when precision at specific
  price thresholds matters

### Price Point Selection Strategy

See the [Price Point Selection](#price-point-selection) section below for detailed
guidance. Key principles for Gabor-Granger:

1. **Span the realistic range.** Include at least one price most respondents would
   accept and one most would reject.
2. **Even spacing is not required but is common.** Equal intervals make the demand
   curve easier to interpret. Unequal intervals are fine if you have specific prices
   you want to test.
3. **Include your current price** (if applicable) to benchmark.
4. **Round to natural price points.** Test $9.99, not $10.17. Respondents react
   differently to rounded vs. charm-priced values.

### Response Scale Options

#### Binary (Yes/No) -- Simple and Clean

```
If [PRODUCT] were priced at [PRICE], would you purchase it?

( ) Yes, I would purchase
( ) No, I would not purchase
```

**Turas config:** Set `response_type = "binary"` in the GaborGranger sheet.

**Advantages:** Simple, fast, no ambiguity in coding.
**Disadvantages:** Loses nuance; does not capture degrees of intent.

#### 5-Point Purchase Intent Scale -- Recommended

```
If [PRODUCT] were priced at [PRICE], how likely would you be
to purchase it?

( ) Definitely would purchase
( ) Probably would purchase
( ) Might or might not purchase
( ) Probably would not purchase
( ) Definitely would not purchase
```

**Turas config:** Set `response_type = "scale"` and `scale_threshold` to define
the top-box cutoff.

- `scale_threshold = 4`: Top-1-box (only "Definitely would purchase" counts)
- `scale_threshold = 3`: Top-2-box ("Definitely" + "Probably" count) -- recommended

**Advantages:** Captures intensity of intent; allows different threshold analysis.
**Disadvantages:** Slightly more cognitive load per question.

#### 7-Point Scale -- When Extra Precision Matters

```
If [PRODUCT] were priced at [PRICE], how likely would you be
to purchase it?

( ) Extremely likely       (7)
( ) Very likely             (6)
( ) Somewhat likely         (5)
( ) Neither likely nor unlikely (4)
( ) Somewhat unlikely       (3)
( ) Very unlikely           (2)
( ) Extremely unlikely      (1)
```

**Turas config:** Set `response_type = "scale"` and `scale_threshold = 5` (or
your preferred cutoff).

**Advantages:** Maximum discrimination.
**Disadvantages:** Respondent fatigue at multiple price points; overkill for most studies.

**Recommendation:** Use the 5-point purchase intent scale with top-2-box coding
(`scale_threshold = 3`). It balances nuance against respondent burden and aligns
with industry convention.

### Question Wording Template for Gabor-Granger

```
[PRODUCT DESCRIPTION AND VISUAL]

We are going to show you several possible prices for [PRODUCT].
For each price, please tell us how likely you would be to
purchase it at that price.

[RANDOMISE ORDER OF PRICE PRESENTATIONS]

---

[PRICE POINT 1: $X.XX]

If [PRODUCT] were available for [CURRENCY][PRICE], how likely
would you be to purchase it?

( ) Definitely would purchase
( ) Probably would purchase
( ) Might or might not purchase
( ) Probably would not purchase
( ) Definitely would not purchase

---

[PRICE POINT 2: $Y.YY]

If [PRODUCT] were available for [CURRENCY][PRICE], how likely
would you be to purchase it?

( ) Definitely would purchase
( ) Probably would purchase
( ) Might or might not purchase
( ) Probably would not purchase
( ) Definitely would not purchase

---

[... REPEAT FOR REMAINING PRICE POINTS ...]
```

### Data Format for Turas

Gabor-Granger data can be structured in two formats:

#### Wide Format (One Row Per Respondent) -- Recommended

Each respondent occupies one row. Each price point has its own column.

```
respondent_id | weight | intent_29 | intent_39 | intent_49 | intent_59 | intent_69
1001          | 1.0    | 5         | 4         | 3         | 2         | 1
1002          | 0.8    | 4         | 4         | 4         | 3         | 2
1003          | 1.2    | 5         | 5         | 4         | 3         | 1
```

**Turas config (GaborGranger sheet):**
- `data_format` = `wide`
- `price_sequence` = `29, 39, 49, 59, 69`
- `response_columns` = `intent_29, intent_39, intent_49, intent_59, intent_69`

#### Long Format (One Row Per Price-Response)

Each observation (respondent x price) occupies one row.

```
respondent_id | price | intent | weight
1001          | 29    | 5      | 1.0
1001          | 39    | 4      | 1.0
1001          | 49    | 3      | 1.0
1002          | 29    | 4      | 0.8
1002          | 39    | 4      | 0.8
```

**Turas config (GaborGranger sheet):**
- `data_format` = `long`
- `respondent_column` = `respondent_id`
- `price_column` = `price`
- `response_column` = `intent`

### Respondent Fatigue Considerations

Gabor-Granger asks the same question repeatedly at different prices. This creates
fatigue risk. Mitigation strategies:

1. **Limit to 5-7 price points.** Beyond 7, quality drops noticeably.
2. **Randomise price order.** Prevents systematic fatigue effects from always hitting
   the same prices late in the sequence.
3. **Use clear visual differentiation.** Make each price point visually distinct
   (e.g., different price displayed prominently) so respondents process each one
   as a fresh evaluation.
4. **Consider page breaks.** Show one price per page rather than all on one screen.
5. **Monitor completion time.** Very fast completions (< 2 seconds per price point)
   may indicate straight-lining.

### Monotonicity in Gabor-Granger

In theory, purchase intent should decrease monotonically as price increases. In
practice, individual respondents sometimes violate this (e.g., they say "yes" at
$49 but "no" at $39).

**Violation rates:**
- < 5%: Normal, expected from response noise
- 5-10%: Acceptable, flag in reporting
- 10-15%: Concerning, review question wording and data quality
- > 15%: Problematic, consider redesigning the survey

Turas provides three monotonicity handling options via `gg_monotonicity_behavior`:
- `diagnostic_only`: Report violations but do not modify data
- `smooth`: Apply isotonic regression to enforce monotonicity (default, recommended)

---

## Monadic Price Testing

### Overview

Monadic price testing is the gold standard for unbiased price sensitivity measurement.
Each respondent is randomly assigned to see ONE price and reports their purchase
intent at that price. Because respondents are not exposed to multiple prices, there
are no anchoring or order effects.

The Turas module fits a logistic regression model to the price-intent data, producing
a smooth demand curve that can be queried at any price point.

### Survey Design Principles

#### Randomisation Is Mandatory

The defining feature of monadic design is random assignment. Each respondent must be
randomly assigned to exactly one price cell. This randomisation must happen at the
survey platform level (e.g., in Alchemer, Qualtrics, SurveyMonkey, or Forsta).

**The randomisation must be:**
- Truly random (not systematic alternation like 1-2-3-1-2-3)
- Pre-determined at survey start (not based on respondent answers)
- Balanced across cells (equal probability of assignment to each cell)
- Independent of other survey variables

#### Cell Sizes

Each price cell must have enough respondents for the proportion estimate (purchase
intent at that price) to be reasonably precise.

| Cell Size | Quality | Use Case |
|-----------|---------|----------|
| < 30 | Insufficient | Do not use; Turas will warn |
| 30-49 | Minimum viable | Exploratory studies only |
| 50-99 | Good | Standard commercial research |
| 100-149 | Strong | High-stakes decisions |
| 150+ | Excellent | Regulatory or academic contexts |

**Recommendation:** Target 50+ respondents per cell for commercial studies, 100+
when confidence intervals must be narrow.

#### Number of Price Cells

| Cells | Total Sample (at n=50/cell) | Quality |
|-------|---------------------------|---------|
| 3 | 150 | Minimum; very limited curve resolution |
| 4 | 200 | Adequate for simple demand estimation |
| 5 | 250 | Good balance of resolution and cost |
| 6 | 300 | Recommended standard |
| 7 | 350 | High resolution, ideal for wide price ranges |
| 8+ | 400+ | Diminishing returns unless range is very wide |

**Recommendation:** Use 5-6 price cells for most studies. Fewer than 4 produces
an unreliable curve; more than 7 rarely justifies the additional sample cost.

#### Total Sample Size Calculation

```
Total sample = Number of cells * Target cell size

Examples:
  5 cells * 50 respondents/cell = 250 total
  6 cells * 75 respondents/cell = 450 total
  5 cells * 100 respondents/cell = 500 total
```

If you also need segment analysis, multiply by the number of segments:

```
Total with segments = Cells * Cell size * Segments

Example: 5 cells * 50/cell * 3 segments = 750 total
```

This assumes you need reliable estimates within each segment. If segment differences
are secondary, you can use total-level analysis with segment as a covariate instead.

### Question Wording Template for Monadic

```
[PRODUCT DESCRIPTION AND VISUAL]

[RESPONDENT IS RANDOMLY ASSIGNED TO SEE ONE PRICE]

---

[PRODUCT] is available for [CURRENCY][ASSIGNED PRICE].

Q1. How likely would you be to purchase [PRODUCT] at this price?

( ) Definitely would purchase
( ) Probably would purchase
( ) Might or might not purchase
( ) Probably would not purchase
( ) Definitely would not purchase
```

Or with binary format:

```
[PRODUCT] is available for [CURRENCY][ASSIGNED PRICE].

Q1. Would you purchase [PRODUCT] at this price?

( ) Yes
( ) No
```

### Screening and Qualification

Because monadic tests use between-subjects comparisons, it is critical that
cells are comparable. Key requirements:

1. **Use the same screening criteria for all cells.** Do not allow different
   qualification rates across price cells.
2. **Screen before price exposure.** The respondent should be qualified for the
   category before being assigned a price.
3. **Verify randomisation balance.** After data collection, check that cells are
   balanced on key demographics (age, gender, income). If not, apply weighting.

### Data Format for Turas

Monadic data is simple: one row per respondent with two key columns.

```
respondent_id | assigned_price | purchase_intent | age | gender | weight
1001          | 29             | 1               | 35  | F      | 1.0
1002          | 39             | 1               | 42  | M      | 0.8
1003          | 49             | 0               | 28  | F      | 1.2
1004          | 29             | 1               | 55  | M      | 1.0
1005          | 59             | 0               | 31  | F      | 0.9
```

**Turas config (Monadic sheet):**
- `price_column` = `assigned_price`
- `intent_column` = `purchase_intent`
- `intent_type` = `binary` (or `scale` if using 5-point scale)
- `scale_threshold` = `4` (if using scale; top-2-box coding)
- `model_type` = `logistic` (or `log_logistic` for log-transformed price)

### Model Type Selection

Turas supports two logistic regression specifications:

| Model | Formula | When to Use |
|-------|---------|-------------|
| `logistic` | `intent ~ price` | Default; works well when price-intent relationship is approximately linear on the logit scale |
| `log_logistic` | `intent ~ log(price)` | Better when the proportional (percentage) change in price matters more than the absolute change; common for wide price ranges |

**Guideline:** Start with `logistic`. If the price range spans more than 3x (e.g.,
$20 to $80), try `log_logistic` and compare AIC values. Lower AIC indicates better fit.

### Confidence Intervals

One of the key advantages of monadic testing is the ability to produce rigorous
confidence intervals. Turas uses bootstrap resampling (default: 1000 iterations)
to compute confidence intervals for:

- The optimal price point (revenue-maximising and profit-maximising)
- The entire demand curve (upper and lower bounds at each price)

**To enable:** Set `confidence_intervals = TRUE` in the Monadic config sheet.

A wide confidence interval on the optimal price indicates that more data is needed
or that the demand curve is relatively flat (insensitive to price) in the
revenue-maximising region. This is itself a useful finding.

---

## Price Point Selection

### How to Determine the Price Range

The most critical decision in pricing research is choosing which prices to test.
Test too narrow a range and you miss the optimal price. Test too wide and you
waste sample on obviously unacceptable prices.

#### Step 1: Establish Reference Points

Before selecting test prices, gather:

1. **Current price** (if the product exists)
2. **Competitor prices** (direct and indirect competitors)
3. **Cost floor** (minimum viable price based on unit cost and margin)
4. **Aspirational ceiling** (maximum price you would consider charging)
5. **Category norms** (what prices are typical in the category)

#### Step 2: Define the Test Range

| Method | Range Guideline |
|--------|----------------|
| Van Westendorp | No predefined range needed (respondents define it). However, set input field bounds to prevent absurd entries (e.g., $0.01 to $10,000). |
| Gabor-Granger | Test range should span from 60-70% of expected optimal price to 130-150% of expected optimal price. |
| Monadic | Same as Gabor-Granger. The range must include prices where demand is high and prices where demand is low, otherwise the logistic model cannot fit properly. |

**Example:**
If you expect the optimal price to be around $50:
- Test range: $30 to $75
- 6 price points: $30, $39, $45, $50, $59, $69

#### Step 3: Select Specific Price Points

**Even spacing approach:**
```
Range: $20 to $60, testing 5 points
Interval: ($60 - $20) / (5 - 1) = $10
Points: $20, $30, $40, $50, $60
```

**Strategic spacing approach:**
Cluster more points around the expected optimal area and fewer at the extremes.
```
Range: $20 to $60, testing 6 points
Points: $20, $35, $40, $45, $50, $60
(Denser around expected optimal of $40-$45)
```

### Granularity Guidelines

| Issue | Symptom | Remedy |
|-------|---------|--------|
| **Too few points** | Revenue curve has a sharp peak at one of the tested prices; optimal price is at the boundary | Add more points, especially near the peak |
| **Too many points** | Respondent fatigue; noisy demand curve with non-monotonic responses | Reduce to 5-7 points; consider monadic design |
| **Gaps too wide** | Miss the true optimal price between tested points | Fill in the gap with additional points in the relevant range |
| **Gaps too narrow** | Respondents cannot distinguish between adjacent prices; all get similar responses | Space points further apart; differences should be perceptible |

**Minimum perceptible difference:** As a rule of thumb, adjacent price points
should differ by at least 10-15% for respondents to perceive them as meaningfully
different. Testing $49 vs. $50 is unlikely to produce different demand responses.

### Anchoring Effects and How to Mitigate

Anchoring occurs when the first price a respondent sees influences their evaluation
of subsequent prices. This is primarily a Gabor-Granger concern (Van Westendorp and
Monadic are less susceptible).

**Mitigation strategies:**

1. **Randomise price order** (within each respondent). This is the single most
   important defence against anchoring.
2. **Do not show all prices on one screen.** Present one price per page so that
   respondents evaluate each independently.
3. **Avoid showing a reference price before the pricing section.** If you must
   provide context, describe the product without mentioning any specific price.
4. **Do not ask "How much would you pay?" before Gabor-Granger questions.** This
   creates a self-generated anchor.

### Competitive Context and Reference Pricing

Should you show competitor prices before asking pricing questions?

| Scenario | Recommendation |
|----------|---------------|
| Respondent knows the category well (e.g., coffee, petrol) | Not necessary; they already have reference prices |
| New category or unfamiliar product | Consider providing context, but do NOT show specific competitor prices |
| Competitive positioning is the research objective | Show competitor prices as part of the stimulus, but be aware this changes what you are measuring |

**If you show competitor prices:**
- Present them neutrally (table format, no highlighting)
- Show them before ALL pricing questions, not selectively
- Document that competitor prices were shown -- this affects interpretation

### Psychological Pricing Considerations

Respondents in surveys react to psychological pricing just as they do in real life.
Consider these effects when selecting price points:

| Effect | Example | Design Implication |
|--------|---------|-------------------|
| **Charm pricing** | $9.99 vs. $10.00 | If you will use charm pricing in market, test charm prices. Do not test $10 if you will charge $9.99. |
| **Round number preference** | $50 vs. $49.95 | B2B buyers often prefer round numbers. Consumer products often use charm pricing. Match your market convention. |
| **Left-digit effect** | $3.99 feels much cheaper than $4.00 | When testing around psychological thresholds, include points on both sides (e.g., $3.99 and $4.49). |
| **Price-quality inference** | Higher price = higher quality | Relevant for Van Westendorp "too cheap" question. Premium products may have a strong quality floor. |
| **Just-below pricing** | $29 vs. $30, $99 vs. $100 | Test just-below thresholds if they are plausible market prices. |

**Practical rule:** Test the prices you would actually charge. If you would never
charge $37.50, do not test it. Test $35 or $39 instead.

---

## Common Mistakes and How to Avoid Them

### Mistake 1: Testing Unrealistic Prices

**Problem:** Including prices far outside the plausible range wastes respondent
attention and can distort results. If 95% of respondents reject a price, that
data point adds little information.

**How to avoid:**
- Do desk research before fieldwork: check competitor prices, category norms,
  and internal cost constraints.
- Ensure at least one tested price achieves > 60% purchase intent and at least
  one achieves < 30%. If all prices get similar responses, your range is too
  narrow or too extreme.

### Mistake 2: Too Many Price Points (Gabor-Granger)

**Problem:** Asking purchase intent at 10+ prices leads to respondent fatigue,
straight-lining, and non-monotonic responses.

**How to avoid:**
- Limit to 5-7 price points.
- If you need more resolution, use monadic design instead (each respondent
  sees only one price).
- Monitor response quality metrics: time per question, straight-line rate,
  and monotonicity violation rate.

### Mistake 3: Too Few Price Points (Gabor-Granger / Monadic)

**Problem:** With only 2-3 price points, you cannot reliably identify the
revenue-maximising price or understand the shape of the demand curve.

**How to avoid:**
- Use at least 4 price points for Gabor-Granger.
- Use at least 4 cells for monadic testing.
- If budget constrains the number of cells, consider using Van Westendorp
  instead (which requires no predefined prices).

### Mistake 4: Order Effects in Gabor-Granger

**Problem:** Presenting prices in ascending or descending order creates
systematic bias. Respondents who see a low price first are anchored to that
level and reject higher prices more readily.

**How to avoid:**
- Randomise the order of price presentations within each respondent.
- Most survey platforms support randomisation of question blocks or loop
  iterations. Use this feature.
- Verify in your data that the randomisation worked (no systematic patterns
  in response order).

### Mistake 5: Sample Composition Issues

**Problem:** Your pricing study sample does not represent the people who
actually buy (or would buy) the product. This produces price sensitivity
estimates that are too high (if non-buyers are included) or too low (if
only loyal customers are sampled).

**How to avoid:**
- Screen for category usage or purchase intent before the pricing section.
- Use quotas to match your target market demographics.
- Apply post-stratification weights if needed.
- Report the screening criteria alongside your results.

### Mistake 6: Leading Question Wording

**Problem:** Question wording that signals the "right" answer or implies
a value judgement about the price.

**Examples of leading wording:**

```
BAD:  "Would you be willing to pay only $29 for this amazing product?"
      (Implies it is cheap and the product is great)

BAD:  "Do you think $99 is a fair price for this product?"
      ("Fair" is a loaded term -- it anchors to the idea that
       the price should be fair)

BAD:  "At $49, this product is priced below the market average.
       Would you purchase it?"
      (Provides a reference frame that biases the response)
```

**Correct neutral wording:**

```
GOOD: "If [PRODUCT] were priced at $29, how likely would you be
       to purchase it?"

GOOD: "At what price would you consider [PRODUCT] to be getting
       expensive?"
```

### Mistake 7: Not Including a "Would Not Purchase" Option

**Problem:** In Gabor-Granger with a scale, respondents who would never
buy at any price are forced to choose the lowest intent level. This inflates
the demand curve.

**How to avoid:**
- For binary response: include "No, I would not purchase."
- For scale response: ensure the bottom of the scale is clearly a
  rejection ("Definitely would not purchase").
- Consider adding a screening question: "Would you consider purchasing
  [PRODUCT] at any price?" to filter out non-buyers before pricing questions.

### Mistake 8: Inconsistent Product Description Across Cells

**Problem:** In monadic design, if different cells see slightly different
product descriptions (e.g., due to survey logic errors), the difference
in purchase intent might be caused by the description rather than the price.

**How to avoid:**
- Use identical product descriptions and visuals across all price cells.
- The ONLY thing that should vary between cells is the price.
- Test your survey logic thoroughly before launching.

### Mistake 9: Asking Van Westendorp About Products with Known Prices

**Problem:** If respondents know the current price of an existing product,
their Van Westendorp responses will cluster around that price, making the
exercise less useful for discovering the true range of acceptable prices.

**How to avoid:**
- For existing products with well-known prices, prefer Gabor-Granger or
  monadic methods.
- If you must use Van Westendorp for an existing product, consider testing
  a modified version (new feature set, new packaging, new tier) so that
  respondents evaluate something genuinely new.
- Do not remind respondents of the current price before VW questions.

### Mistake 10: Ignoring Currency and Tax Context

**Problem:** Respondents in different markets interpret prices differently
depending on whether prices typically include or exclude tax (VAT/GST).

**How to avoid:**
- Specify whether prices include or exclude tax in the question wording.
- Use the same tax-inclusive/exclusive convention your target market
  normally encounters.
- For B2B studies, clarify whether prices are ex-VAT.
- Match the currency symbol to your target market.

---

## Sample Size Guidelines

### Van Westendorp PSM

| Tier | Sample Size | Use Case |
|------|-------------|----------|
| **Minimum** | 200 completed responses | Directional guidance only; wide confidence intervals |
| **Recommended** | 300-400 completed responses | Reliable price points with reasonable precision |
| **Ideal** | 500+ completed responses | Narrow confidence intervals; robust segment analysis |

**For segment analysis:** Minimum 75 respondents per segment with complete,
valid VW data. At 300 total respondents with 4 segments, expect approximately
75 per segment -- this is the practical minimum.

**Attrition planning:** Budget for 10-15% data loss due to incomplete responses,
logical violations, and outlier exclusions. If you need 300 valid responses,
recruit 340-350.

### Gabor-Granger

| Tier | Sample Size | Use Case |
|------|-------------|----------|
| **Minimum** | 150 completed responses | Basic demand curve; limited precision |
| **Recommended** | 200-300 completed responses | Reliable demand curve and optimal price |
| **Ideal** | 400+ completed responses | Narrow confidence intervals; segment-level analysis |

**For segment analysis:** Minimum 75 per segment for reliable demand curves
within segments.

### Monadic Price Testing

Monadic requires larger total samples because respondents are split across cells.

| Cells | Min per Cell | Min Total | Recommended per Cell | Recommended Total |
|-------|-------------|-----------|---------------------|-------------------|
| 4 | 30 | 120 | 50 | 200 |
| 5 | 30 | 150 | 50 | 250 |
| 6 | 30 | 180 | 75 | 450 |
| 7 | 30 | 210 | 75 | 525 |

**For segment analysis with monadic:** The sample requirement multiplies quickly.
With 5 cells, 50 per cell, and 3 segments, you need 750 respondents. Consider
whether segment-level monadic analysis is feasible within your budget, or whether
segment analysis should be done using a different method (e.g., VW or GG).

### Combined (VW + GG)

When running both methods on the same sample, sample size requirements are
driven by the more demanding method:

- **Minimum:** 300 completed responses (meets both VW and GG minimums)
- **Recommended:** 400+ completed responses
- **For segment analysis:** 75+ per segment

### Summary Table

| Method | Minimum | Recommended | With Segments (per segment) |
|--------|---------|-------------|---------------------------|
| Van Westendorp | 200 | 300+ | 75+ |
| Gabor-Granger | 150 | 200+ | 75+ |
| Monadic | 30 per cell (120+ total) | 50+ per cell (250+ total) | 50+ per cell per segment |
| Combined VW+GG | 300 | 400+ | 75+ |

### Statistical Power Considerations

These sample sizes are guidelines based on practical experience. If you need
formal power calculations:

1. **For Van Westendorp:** The key question is whether the 95% confidence interval
   around each price point (PMC, OPP, IDP, PME) is narrow enough to be actionable.
   Bootstrap CIs narrow roughly in proportion to 1/sqrt(n).

2. **For Gabor-Granger:** The key question is whether you can detect a meaningful
   difference in purchase intent between adjacent price points. With n=200, you
   can typically detect a 10-percentage-point difference at p < 0.05.

3. **For Monadic:** The key question is whether the price coefficient in the
   logistic regression is statistically significant. With 50 per cell and 5 cells,
   you typically have adequate power to detect a meaningful price effect. Check
   the `price_coefficient_p` value in Turas output -- it should be < 0.05.

---

## Survey Platform Notes and Data Preparation

### General Best Practices for Implementation

Regardless of which survey platform you use, follow these guidelines:

1. **Validate numeric inputs.** Set minimum (e.g., 0.01) and maximum (e.g.,
   10,000) bounds on all price fields. Reject non-numeric entries at the
   platform level.

2. **Make pricing questions required.** Incomplete VW responses (e.g., answering
   3 of 4 questions) cannot be used. Configure questions as mandatory.

3. **Randomise Gabor-Granger price order.** Use your platform's randomisation
   feature to shuffle the order of price presentations.

4. **Implement monadic randomisation at the platform level.** Assign respondents
   to price cells using the platform's random assignment or quota management.

5. **Test before launch.** Complete the survey yourself at least 5 times, once
   per price cell (for monadic). Verify that randomisation works, numeric
   validation fires, and data exports correctly.

6. **Record the assigned price for monadic.** The data must include a column
   indicating which price each respondent was shown.

7. **Include a respondent ID.** Essential for data quality checks and for
   matching survey data to panel data if applicable.

### Data Format Requirements for Turas Import

Turas accepts the following file formats:

| Format | Extension | Notes |
|--------|-----------|-------|
| CSV | `.csv` | Recommended for simplicity. UTF-8 encoding preferred. |
| Excel | `.xlsx` | Use `.xlsx`, not `.xls`. |
| SPSS | `.sav` | Labels are preserved. |
| Stata | `.dta` | Version 13+ format. |
| R Data | `.rds` | Native R format. |

### Column Naming Conventions

Follow these naming conventions to make configuration straightforward:

#### Van Westendorp Columns

```
Recommended column names:
  vw_too_cheap        (or: price_too_cheap, q_too_cheap)
  vw_cheap            (or: price_bargain, q_bargain)
  vw_expensive        (or: price_expensive, q_expensive)
  vw_too_expensive    (or: price_too_expensive, q_too_expensive)

For NMS extension:
  vw_pi_cheap         (or: nms_intent_cheap)
  vw_pi_expensive     (or: nms_intent_expensive)
```

**Naming rules:**
- Use snake_case (lowercase with underscores)
- Avoid spaces, special characters, and leading numbers
- Be descriptive: `vw_too_cheap` is better than `Q7a`
- Match your column names exactly in the Turas configuration (case-sensitive)

#### Gabor-Granger Columns (Wide Format)

```
Recommended column names:
  gg_intent_29        (or: purchase_intent_29, pi_29)
  gg_intent_39        (or: purchase_intent_39, pi_39)
  gg_intent_49        (or: purchase_intent_49, pi_49)
  ...

The price value should be embedded in the column name for clarity,
but the actual price mapping is defined in the configuration, not
inferred from column names.
```

#### Monadic Columns

```
Recommended column names:
  assigned_price      (or: price_shown, monadic_price, test_price)
  purchase_intent     (or: intent, would_buy, pi)
```

#### Common Columns (All Methods)

```
respondent_id         Unique respondent identifier
weight                Case weight (if applicable)
segment               Segment assignment (if applicable)
age                   Demographic variable
gender                Demographic variable
income                Demographic variable
region                Geographic variable
```

### Data Cleaning Checklist

Before importing data into Turas, verify:

- [ ] All pricing columns contain numeric values (no text like "N/A" or "Don't know")
- [ ] "Don't know" responses are coded as a specific numeric value (e.g., -99) and
      configured in `dk_codes` in the Turas Settings sheet
- [ ] No blank rows or header rows in the middle of the data
- [ ] Column names match exactly what you will enter in the Turas configuration
- [ ] Weight variable (if used) contains positive numeric values with no missing data
- [ ] For monadic: every respondent has a value in the assigned price column
- [ ] For Gabor-Granger (wide): every respondent has values in all price columns
      (or missing values are coded consistently)
- [ ] For Van Westendorp: all four price columns are present and contain numeric values
- [ ] File is saved in a supported format (.csv, .xlsx, .sav, .dta, or .rds)

### Handling "Don't Know" Responses

If your survey includes a "Don't know" or "Prefer not to say" option on pricing
questions, code these as a specific numeric value (e.g., -99 or 999) rather than
leaving them blank. Then configure Turas to recognise these codes:

In the Settings sheet:
```
DK_Codes = -99, 999
```

Turas will recode these values to NA before analysis, ensuring they are excluded
from calculations without corrupting the numeric data.

### Platform-Specific Guidance

#### Alchemer (SurveyGizmo)

- Use "Textbox (Numeric)" question type for VW open-ended prices
- Use "Radio Button" for purchase intent scales
- Use "URL Redirect" or "Hidden Value" to assign monadic price cells
- Export as CSV (UTF-8) for cleanest import

#### Qualtrics

- Use "Text Entry (Number)" for VW price fields
- Use "Randomizer" flow element for GG price order randomisation
- Use "Randomizer" with "Evenly Present Elements" for monadic cell assignment
- Use "Embedded Data" to record the assigned price cell
- Export as CSV or SPSS (.sav)

#### SurveyMonkey

- Use "Text Box (numeric)" for VW price fields
- Use "Question Randomization" for GG price order
- Use "Random Assignment" or A/B testing for monadic cells
- Export as CSV or XLSX

#### Forsta (Confirmit)

- Use numeric open-end questions for VW prices
- Use loop with randomised iteration for GG
- Use quota control for monadic cell assignment
- Export as SPSS or CSV

---

## Appendix: Quick Reference Tables

### Method Comparison at a Glance

| Feature | Van Westendorp | Gabor-Granger | Monadic |
|---------|---------------|---------------|---------|
| Questions per respondent | 4 (+ 2 for NMS) | 5-7 | 1 |
| Open-ended vs. closed | Open-ended (numeric) | Closed (scale/binary) | Closed (scale/binary) |
| Predefined price range needed | No | Yes | Yes |
| Order effects risk | Low | Moderate (mitigate with randomisation) | None |
| Demand curve output | No (range only) | Yes | Yes |
| Revenue optimisation | Via NMS only | Direct | Direct |
| Confidence intervals | Bootstrap (optional) | Bootstrap (optional) | Bootstrap (default) |
| Minimum sample | 200 | 150 | 150-300+ |
| Statistical model | Empirical CDF intersections | Weighted proportions | Logistic regression |
| Bias risk | Low | Moderate (anchoring) | Lowest |

### Turas Configuration Sheet Summary

| Sheet | Required For | Key Settings |
|-------|-------------|--------------|
| **Settings** | All methods | `Analysis_Method`, `Data_File`, `Output_File`, `Currency_Symbol`, `Weight_Variable` |
| **VanWestendorp** | VW and Combined | `col_too_cheap`, `col_cheap`, `col_expensive`, `col_too_expensive`, `col_pi_cheap` (NMS), `col_pi_expensive` (NMS) |
| **GaborGranger** | GG and Combined | `data_format`, `price_sequence`, `response_columns`, `response_type`, `scale_threshold` |
| **Monadic** | Monadic | `price_column`, `intent_column`, `intent_type`, `scale_threshold`, `model_type` |
| **Validation** | Optional (all) | `min_completeness`, `price_min`, `price_max`, `flag_outliers` |
| **Simulator** | Optional (all) | Preset scenario definitions for interactive simulator |

### Van Westendorp Output Price Points

| Price Point | Abbreviation | Meaning |
|-------------|-------------|---------|
| Point of Marginal Cheapness | PMC | Below this, quality concerns dominate. Lower bound of acceptable range. |
| Optimal Price Point | OPP | Price where resistance to "too cheap" and "too expensive" is minimised. |
| Indifference Price Point | IDP | Price where equal proportions find it "cheap" and "expensive." The market's centre of gravity. |
| Point of Marginal Expensiveness | PME | Above this, too many people consider it too expensive. Upper bound of acceptable range. |

### Gabor-Granger Key Outputs

| Output | Definition |
|--------|-----------|
| Demand curve | Purchase intent (%) at each tested price |
| Revenue index | Price * purchase intent (relative revenue per respondent) |
| Profit index | (Price - unit cost) * purchase intent (if unit cost provided) |
| Optimal price (revenue) | Price that maximises the revenue index |
| Optimal price (profit) | Price that maximises the profit index |
| Price elasticity | Arc elasticity between adjacent price points |

### Monadic Key Outputs

| Output | Definition |
|--------|-----------|
| Logistic demand curve | Predicted purchase probability at any price in the tested range |
| Model coefficients | Intercept and price coefficient from logistic regression |
| Pseudo R-squared | McFadden's pseudo R-squared (model fit) |
| Optimal price (revenue) | Price that maximises price * predicted probability |
| Confidence intervals | Bootstrap CIs for optimal price and demand curve |
| Price elasticity | Arc elasticity computed at sampled intervals along the curve |

### Data Quality Thresholds

| Metric | Acceptable | Concerning | Problematic |
|--------|-----------|-----------|-------------|
| VW monotonicity violations | < 5% | 5-10% | > 10% |
| GG monotonicity violations | < 5% | 5-10% | > 15% |
| Missing data rate (per column) | < 5% | 5-15% | > 20% |
| Extreme outliers | < 2% | 2-5% | > 5% |
| Straight-lining (VW) | < 2% | 2-5% | > 5% |
| Monadic cell size imbalance | < 10% deviation | 10-20% | > 20% |
| Survey completion time | Plausible | Under 50% of median | Under 25% of median |

### Respondent Quality Indicators

Watch for these red flags in your data:

| Indicator | How to Detect | Action |
|-----------|--------------|--------|
| **Straight-lining (VW)** | All 4 VW responses identical | Exclude; Turas flags these automatically |
| **Speeders** | Total survey time < 1/3 of median | Review; consider exclusion |
| **Illogical VW sequences** | too_cheap > cheap, or expensive > too_expensive | Turas excludes or flags based on config |
| **Non-monotonic GG** | Purchase intent increases with price | Flag; Turas can smooth or report |
| **Extreme prices (VW)** | Prices > 10x or < 0.01x the median | Review for data entry errors |
| **Constant GG response** | Same response at every price point | Likely disengaged; consider exclusion |

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | March 2026 | Initial release covering Van Westendorp, Gabor-Granger, and Monadic methods |

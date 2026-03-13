# Pricing Methodology Comparison Guide

## Turas Pricing Module -- Method Selection & Interpretation

Version 1.0 | Turas Analytics Platform

---

## Table of Contents

1. [Overview: Why Method Selection Matters](#1-overview-why-method-selection-matters)
2. [Van Westendorp Price Sensitivity Meter (PSM)](#2-van-westendorp-price-sensitivity-meter-psm)
3. [Gabor-Granger Demand Analysis](#3-gabor-granger-demand-analysis)
4. [Monadic Price Testing (Logistic Regression)](#4-monadic-price-testing-logistic-regression)
5. [Combined Analysis (VW + GG)](#5-combined-analysis-vw--gg)
6. [Comparison Table](#6-comparison-table)
7. [Integration with Other Research](#7-integration-with-other-research)
8. [Confidence in Results](#8-confidence-in-results)

---

## 1. Overview: Why Method Selection Matters

Pricing decisions are among the highest-impact choices a business makes. A price
set 5% too high can halve unit sales; a price set 5% too low can leave
significant revenue on the table. The methodology used to arrive at a pricing
recommendation determines the type of evidence you collect, the biases you are
exposed to, and the confidence you can place in the final number.

No single pricing methodology is universally superior. Each answers a different
question:

- **Van Westendorp** asks: *"What price range do consumers consider acceptable?"*
- **Gabor-Granger** asks: *"At which specific price is revenue maximized?"*
- **Monadic testing** asks: *"What is the unbiased relationship between price
  and purchase likelihood?"*

Choosing the wrong method -- or interpreting results from the right method
incorrectly -- leads to pricing decisions built on the wrong evidence. This
guide helps market researchers select the appropriate method for their research
objective, understand what each method can and cannot tell them, and interpret
Turas outputs with confidence.

**Key principle:** The best pricing research uses triangulation. When budget and
sample size permit, running multiple methods and comparing results produces
stronger evidence than any single method alone. Turas supports this directly
through its `both` analysis mode and its recommendation synthesis engine, which
scores confidence based on cross-method agreement.

---

## 2. Van Westendorp Price Sensitivity Meter (PSM)

### 2.1 What It Measures

The Van Westendorp PSM identifies the **acceptable price range** for a product
or service by mapping consumers' perceived value boundaries. It does not predict
purchase behavior or optimize revenue. Instead, it reveals the price zone within
which the majority of consumers consider the product reasonably priced.

### 2.2 How It Works

Each respondent answers four open-ended price perception questions:

1. **Too Cheap** -- "At what price would you begin to question the quality of
   this product because it is too cheap?"
2. **Cheap / Bargain** -- "At what price would you consider this product to be
   a bargain -- a great buy for the money?"
3. **Expensive** -- "At what price would you consider this product to be getting
   expensive -- you would still consider it, but would need to think about it?"
4. **Too Expensive** -- "At what price would you consider this product to be so
   expensive that you would not consider buying it?"

Turas converts these four price distributions into cumulative distribution
functions and identifies four key intersection points:

- Cumulative "Too Cheap" vs. cumulative "Not Cheap" (inverted Cheap curve)
- Cumulative "Not Expensive" (inverted Expensive) vs. cumulative "Too Expensive"
- Two additional intersections from the crossing of the extreme curves

The `pricesensitivitymeter` R package handles the interpolation and intersection
calculations, with Turas providing validation, formatting, and extended
analytics on top.

### 2.3 Key Outputs

Turas produces the following Van Westendorp outputs:

| Output | Abbreviation | Definition |
|--------|-------------|------------|
| Point of Marginal Cheapness | **PMC** | Below this price, too many consumers doubt quality. Lower bound of the acceptable range. |
| Optimal Price Point | **OPP** | The price at which equal proportions find the product "too cheap" and "too expensive." Represents the point of least price resistance. |
| Indifference Price Point | **IDP** | The price at which equal proportions find the product "cheap" and "expensive." This is the normative or expected price. |
| Point of Marginal Expensiveness | **PME** | Above this price, too many consumers consider the product too expensive. Upper bound of the acceptable range. |
| Acceptable Price Range | PMC to PME | The full range within which a majority of consumers consider the price reasonable. |
| Optimal Price Range | OPP to IDP | The narrower zone of minimal price resistance. |

**NMS Extension (Newton-Miller-Smith):** When purchase intent data is collected
alongside the four VW questions, Turas runs the NMS extension, which calibrates
the VW curves with stated purchase probability. This produces:

- **Trial Optimal Price** -- the price maximizing trial or reach
- **Revenue Optimal Price** -- the price maximizing expected revenue (purchase
  probability multiplied by price)

The NMS extension bridges the gap between VW's perception-only output and
revenue-oriented analysis.

### 2.4 Strengths

- **Easy to implement in surveys.** Four open-ended questions require no
  predetermined price list. Respondents can answer naturally.
- **Respondent-friendly.** Questions are intuitive. Completion rates are
  typically high and respondent fatigue is low.
- **No price list required.** Unlike Gabor-Granger, VW does not require the
  researcher to decide which prices to test. Respondents define the price
  landscape themselves.
- **Good for range exploration.** VW excels at identifying the boundaries of
  consumer acceptance, especially for new or unfamiliar product categories.
- **Detects quality perception thresholds.** The "too cheap" question captures
  the floor below which consumers associate low price with low quality -- a
  signal other methods miss.
- **NMS extension adds revenue lens.** When purchase intent questions are
  included, NMS provides revenue calibration without requiring a second
  methodology.

### 2.5 Weaknesses

- **Does not predict actual purchase behavior.** VW measures price perception,
  not stated or revealed purchase intent. A price inside the acceptable range
  does not guarantee demand.
- **No revenue optimization.** Without the NMS extension, VW cannot identify
  the revenue-maximizing price. The OPP represents minimal resistance, not
  maximum revenue.
- **Sensitive to outliers.** A small number of extreme responses (very high or
  very low prices) can distort the cumulative distributions, particularly with
  small samples. Turas validates for outliers and flags cases where more than
  5% of responses are extreme.
- **Assumes monotonic distributions.** The method requires that the cumulative
  curves behave logically (e.g., the proportion saying "too cheap" should
  decrease as price rises). Violations indicate data quality issues.
- **No confidence intervals on price points (by default).** The standard VW
  analysis produces point estimates only. Turas offers optional bootstrap
  confidence intervals, but these require additional computation time.
- **Open-ended responses can be noisy.** Without price anchors, respondents
  may give inconsistent or poorly calibrated answers, especially for unfamiliar
  categories.

### 2.6 Best For

- **New product categories** where no reference prices exist and the research
  goal is to discover the viable price range
- **Early-stage pricing** before committing to specific price points for further
  testing
- **Understanding the psychology of price perception** -- where does "cheap"
  become "too cheap"? Where does "expensive" become a deal-breaker?
- **Categories where quality-price associations are strong** (luxury goods,
  professional services, health products)
- **Exploratory research** that will feed into subsequent Gabor-Granger or
  conjoint studies

### 2.7 Minimum Sample Size

- **Absolute minimum:** 100 respondents with valid responses across all four
  questions
- **Recommended:** 200+ respondents for stable intersections
- **Ideal:** 300+ respondents, especially if segment-level VW analysis is planned

Turas enforces a hard minimum of 30 complete cases and flags samples below 200
as potentially unstable.

### 2.8 Statistical Assumptions

1. **Monotonic cumulative distributions.** As price increases, the proportion
   saying "too cheap" should decrease and the proportion saying "too expensive"
   should increase. Violations suggest confused respondents or ambiguous question
   wording.
2. **Logical price ordering per respondent.** Each respondent's prices should
   follow: Too Cheap <= Cheap <= Expensive <= Too Expensive. Turas measures the
   violation rate and warns when it exceeds 10%.
3. **Representative sample.** VW results reflect the population only if the
   sample is representative. Weighting can partially correct for known biases.
4. **Continuous price perception.** VW assumes consumers have a continuous mental
   model of price acceptability, not discrete thresholds.

### 2.9 Interpretation Guidance

**Reading the PSM chart:**

The VW chart displays four curves plotted against price on the x-axis:

- "Too Cheap" (decreasing) -- proportion who find each price too cheap
- "Not Cheap" (increasing) -- proportion who do NOT find the price cheap
- "Not Expensive" (decreasing) -- proportion who do NOT find the price expensive
- "Too Expensive" (increasing) -- proportion who find each price too expensive

The four intersection points mark the PMC, OPP, IDP, and PME.

**What the intersections mean:**

- The **OPP** is NOT necessarily the price you should charge. It is the price of
  least resistance -- the point where the fewest consumers object. In practice,
  pricing at the OPP often leaves revenue on the table.
- The **IDP** is the market's expected price. Pricing above the IDP means more
  consumers find the product expensive than cheap. This can be acceptable if
  the brand positioning supports premium pricing.
- The **range width** (PME minus PMC) indicates how much pricing latitude the
  market allows. A narrow range suggests strong price consensus. A wide range
  suggests a heterogeneous market where segmentation may be valuable.
- If the OPP and IDP are close together, price sensitivity is symmetric. If
  they diverge significantly, the market has asymmetric sensitivity (typically
  more sensitive to increases than decreases).

---

## 3. Gabor-Granger Demand Analysis

### 3.1 What It Measures

Gabor-Granger directly estimates the **demand curve** by measuring stated
purchase intent at specific price points. It identifies the price that maximizes
expected revenue (or profit, when unit cost is known).

### 3.2 How It Works

Each respondent is presented with a sequence of price points and asked whether
they would purchase the product at each price. The presentation can be:

- **Sequential ascending or descending** -- prices shown in order
- **Randomized** -- prices shown in random order (reduces order effects)
- **Adaptive** -- starting from a mid-range price and branching based on responses

Responses can be:

- **Binary** -- "Would you buy at this price?" (yes/no)
- **Scaled** -- "How likely would you be to buy at this price?" (1-5 or 1-7
  scale, with top-box coding to binary)

Turas supports both wide format (one column per price point) and long format
(one row per respondent-price combination). Response coding is handled
automatically with configurable thresholds for scale-type responses.

At each price point, the proportion of respondents willing to purchase is
calculated (weighted if applicable). This creates the demand curve. Multiplying
demand by price at each point produces the revenue curve. The peak of the
revenue curve identifies the optimal price.

### 3.3 Key Outputs

| Output | Description |
|--------|------------|
| **Demand curve** | Purchase intent (proportion willing to buy) at each tested price point |
| **Revenue curve** | Expected revenue index (price multiplied by demand) at each price |
| **Profit curve** | Expected profit index ((price minus unit cost) multiplied by demand), when unit cost is configured |
| **Optimal price (revenue)** | The tested price point that maximizes expected revenue |
| **Optimal price (profit)** | The tested price point that maximizes expected profit |
| **Price elasticity** | Arc elasticity between consecutive price points, classified as elastic, inelastic, or unit elastic |
| **Confidence intervals** | Bootstrap confidence intervals for demand at each price point (optional) |

Turas also provides demand curve smoothing options (isotonic/PAVA, cumulative
maximum, LOESS) to handle noisy data while preserving the monotonicity
constraint (demand should decrease as price rises).

### 3.4 Strengths

- **Direct revenue optimization.** Gabor-Granger directly answers the question
  stakeholders care about most: "What price maximizes revenue?"
- **Easy to communicate.** The demand curve and revenue curve are intuitive
  visualizations that non-technical stakeholders understand immediately.
- **Actionable output.** The optimal price is a concrete recommendation, not
  a range to be further interpreted.
- **Supports profit optimization.** When unit cost is known, Turas calculates
  profit-maximizing price alongside revenue-maximizing price. These often differ,
  and the distinction matters.
- **Price elasticity measurement.** The demand curve directly shows how
  sensitive demand is to price changes at different price levels, helping
  identify elastic and inelastic zones.
- **Weighted analysis supported.** Turas applies respondent weights to all
  Gabor-Granger calculations, correcting for known sampling biases.

### 3.5 Weaknesses

- **Hypothetical bias.** Stated purchase intent systematically overstates actual
  purchase behavior. Respondents who say "yes, I would buy" at a given price
  often do not buy in reality. The absolute demand levels should not be taken
  at face value. The relative pattern across prices is more reliable.
- **Limited to tested prices.** The demand curve is defined only at the price
  points included in the survey. If the true optimum falls between tested
  points, it will be missed. Turas offers interpolation (linear, spline, PCHIP)
  to mitigate this, but interpolation is an estimate, not observation.
- **Order effects.** When prices are presented sequentially, earlier prices
  anchor respondent expectations. A respondent shown $10 first may react
  differently to $15 than one shown $20 first. Randomized presentation reduces
  but does not eliminate this bias.
- **Requires predefined price list.** The researcher must decide which prices
  to test before fielding the survey. If the list misses the relevant range,
  the analysis is compromised.
- **Each respondent evaluates multiple prices.** This within-subject design
  means respondents are aware they are being tested on price sensitivity, which
  can alter their behavior compared to a real purchase decision.
- **Flat or non-monotonic curves.** If demand does not decrease monotonically
  with price (e.g., due to small samples or noisy responses), the revenue
  curve may have multiple local maxima. Turas provides smoothing options to
  address this, but the underlying data quality issue remains.

### 3.6 Best For

- **Existing products** with established market presence where a specific
  optimal price is needed
- **Competitive pricing decisions** where the goal is revenue or profit
  optimization within a known competitive range
- **Price point validation** after VW has identified the acceptable range
- **Situations where revenue optimization is the primary objective** and
  stakeholders need a single number with supporting demand evidence

### 3.7 Minimum Sample Size

- **Absolute minimum:** 100 respondents
- **Recommended:** 150-200 respondents for stable demand curves
- **For segment-level analysis:** 75+ per segment

Turas warns when sample size drops below 30, as demand estimates become
unreliable at that level.

### 3.8 Statistical Assumptions

1. **Stated intent approximates actual behavior at the relative level.** While
   absolute purchase rates from Gabor-Granger are inflated, the relative
   ordering and shape of the demand curve are assumed to reflect real market
   behavior. A price that generates 60% stated intent should generate higher
   actual demand than one generating 40%.
2. **Monotone decreasing demand.** As price increases, demand should not
   increase. Violations suggest noise, order effects, or a prestige pricing
   effect (where higher price signals higher quality). Turas provides
   configurable monotonicity enforcement.
3. **Independence of responses.** Each respondent's answers are assumed to be
   independent of other respondents. This is generally satisfied with
   standard survey sampling.
4. **Representative sample.** As with VW, results generalize only if the sample
   represents the target population.

### 3.9 Interpretation Guidance

**Reading the demand curve:**

- The x-axis shows price; the y-axis shows purchase intent (0 to 1 or 0% to
  100%).
- A steep drop-off indicates high price sensitivity (elastic demand). A
  gradual slope indicates low sensitivity (inelastic demand).
- Look for the "elbow" -- the price point where demand begins to drop sharply.
  This is often a natural upper boundary for pricing.

**Reading the revenue curve:**

- Revenue is maximized where the curve peaks. This is usually NOT at the
  lowest price (where demand is highest but price is low) or the highest price
  (where price is high but demand is low).
- The revenue curve is often relatively flat near the peak, meaning several
  nearby prices produce similar revenue. This "revenue plateau" provides
  pricing flexibility.

**Revenue vs. profit trade-off:**

- The revenue-maximizing price is almost always lower than the profit-maximizing
  price (when unit cost is positive). Revenue optimization favors volume;
  profit optimization favors margin.
- If Turas shows both optimal points, the gap between them represents the
  tension between market share and margin. The right choice depends on
  business strategy.

**Elasticity zones:**

- Where arc elasticity exceeds -1.0 (elastic), a small price increase causes
  a disproportionately large demand decrease. Price increases in this zone
  are risky.
- Where arc elasticity is between 0 and -1.0 (inelastic), demand is relatively
  insensitive to price changes. There may be room to raise prices without
  significant volume loss.

---

## 4. Monadic Price Testing (Logistic Regression)

### 4.1 What It Measures

Monadic price testing measures the **unbiased relationship between price and
purchase probability** using a randomized experimental design. It is considered
the gold standard for price sensitivity measurement because it eliminates
order effects and anchoring bias entirely.

### 4.2 How It Works

The design is simple and rigorous:

1. **Randomized assignment.** Each respondent is randomly assigned to ONE price
   cell. They see only that single price.
2. **Purchase intent measurement.** The respondent reports their purchase intent,
   either as a binary yes/no or on a Likert scale (which Turas converts to
   binary using a configurable threshold).
3. **Logistic regression.** Turas fits a generalized linear model with a
   binomial family and logit link: `P(buy) = logistic(a + b * price)`. An
   optional log-logistic variant uses `log(price)` as the predictor.
4. **Demand curve prediction.** The fitted model generates a smooth, continuous
   demand curve across the full price range.
5. **Revenue and profit optimization.** Multiplying predicted demand by price
   (or price minus cost) yields the revenue (or profit) curve. The peak
   identifies the optimal price.
6. **Bootstrap confidence intervals.** Turas bootstraps the entire analysis
   (resampling respondents, refitting the model, re-optimizing) to produce
   confidence intervals for the optimal price and the demand curve.

### 4.3 Key Outputs

| Output | Description |
|--------|------------|
| **Predicted demand curve** | Smooth, model-based purchase probability across the price range |
| **Observed data by cell** | Actual purchase intent within each price cell (for model validation) |
| **Revenue curve** | Price multiplied by predicted demand |
| **Profit curve** | (Price minus unit cost) multiplied by predicted demand |
| **Optimal price (revenue)** | Price that maximizes expected revenue, with confidence interval |
| **Optimal price (profit)** | Price that maximizes expected profit, with confidence interval |
| **Model diagnostics** | Coefficients, p-values, pseudo-R-squared, AIC |
| **Price elasticity** | Arc elasticity at sampled points along the predicted curve |
| **Confidence bands** | Bootstrap lower and upper bounds for the demand curve at each price |

### 4.4 Strengths

- **Eliminates order and anchoring bias.** Because each respondent sees only
  one price, there is no comparison point to anchor against and no sequence
  effect. This is the cleanest experimental design for price testing.
- **Statistical rigor.** The logistic regression framework provides formal
  hypothesis testing (is the price coefficient significantly different from
  zero?), model fit statistics, and principled confidence intervals.
- **Confidence intervals on the optimal price.** Unlike VW and standard GG,
  monadic testing with bootstrap produces a confidence interval around the
  recommended price. This communicates uncertainty honestly to stakeholders.
- **Smooth demand curve.** The model-based curve is continuous and inherently
  monotonic (for the standard logistic form), eliminating the noise issues
  that plague empirical demand curves.
- **Works with any price range.** The continuous model can predict demand at
  prices not directly tested, as long as they fall within a reasonable
  extrapolation of the observed range.
- **Model diagnostics reveal data quality.** A non-significant price
  coefficient, low pseudo-R-squared, or poor cell balance immediately signal
  problems that would be hidden in descriptive methods.

### 4.5 Weaknesses

- **Requires larger samples.** Because each respondent contributes data at only
  one price point, you need many more respondents to achieve the same
  statistical power as a within-subject design. A study with 6 price cells
  needs at least 180 respondents (30 per cell), and 300+ (50 per cell) is
  strongly recommended.
- **Less intuitive for non-technical stakeholders.** Logistic regression,
  pseudo-R-squared, and confidence intervals can be unfamiliar to marketing
  and product teams. The results require more explanation than a simple demand
  curve.
- **Model specification matters.** The logistic model assumes a specific
  functional form for the price-demand relationship. If the true relationship
  is substantially non-logistic (e.g., has a sudden threshold effect), the
  model may fit poorly. Turas offers a log-logistic variant for non-linear
  price effects, but model selection requires judgment.
- **Hypothetical bias remains.** Like all stated preference methods, monadic
  testing still suffers from the gap between what people say they will do
  and what they actually do. The bias is less systematic than in Gabor-Granger
  (because there is no comparison anchoring), but it is not eliminated.
- **Cell imbalance can degrade estimates.** If randomization produces very
  unequal cell sizes (e.g., 80 respondents in one cell and 15 in another),
  the model estimates may be less reliable. Turas reports cell sizes and
  flags minimum cell counts below 30.
- **Cannot capture within-person trade-offs.** Because each respondent sees
  only one price, you cannot observe how the same person's intent changes
  across prices. This limits the ability to study individual-level price
  sensitivity or willingness-to-pay distributions.

### 4.6 Best For

- **High-stakes pricing decisions** where the cost of getting the price wrong
  is significant and the organization needs statistical evidence with
  quantified uncertainty
- **When statistical rigor is required** -- regulatory contexts, board
  presentations, academic research, or pricing for high-value products
- **Situations where anchoring bias is a concern** -- categories where
  consumers have strong reference prices that would contaminate a
  within-subject Gabor-Granger design
- **Products where the price-quality relationship matters** -- the absence
  of comparison points means respondents evaluate the price in isolation,
  which better simulates a real purchase decision
- **Competitive pricing studies** where you want to test your price without
  revealing that you are testing multiple prices

### 4.7 Minimum Sample Size

- **Absolute minimum per cell:** 30 respondents
- **Recommended per cell:** 50+ respondents
- **Typical study design:** 5-8 price cells
- **Total sample (minimum):** 150-240 (30 per cell x 5-8 cells)
- **Total sample (recommended):** 250-400 (50 per cell x 5-8 cells)

Turas reports cell sizes in the diagnostics output and warns when any cell
falls below 30. The bootstrap confidence interval procedure requires at least
2 unique intent levels (both "would buy" and "would not buy" respondents must
exist in the bootstrap sample).

### 4.8 Statistical Assumptions

1. **Logistic (or log-logistic) relationship.** The model assumes purchase
   probability follows the logistic function of price. This means the
   demand curve has an S-shaped (sigmoid) form when viewed on the probability
   scale. For most consumer products, this is a reasonable assumption.
2. **Independence of observations.** Each respondent's purchase intent is
   independent of all other respondents. This is satisfied by standard survey
   sampling but would be violated by, for example, group interviews.
3. **Correct model specification.** The model includes only price (or
   log-price) as a predictor. If other unmeasured variables systematically
   differ across price cells (due to randomization failures), estimates
   will be biased.
4. **Sufficient variation in both price and intent.** If all respondents at
   all prices say "yes" (or all say "no"), the model cannot estimate a
   meaningful price effect. There must be meaningful variation in the
   response variable.

### 4.9 Interpretation Guidance

**Reading model diagnostics:**

- **Price coefficient (negative expected):** A negative coefficient confirms
  that higher prices reduce purchase probability. If the coefficient is
  positive, something is wrong -- either with the data or the model
  specification.
- **Price coefficient p-value:** If p > 0.05, the price effect is not
  statistically significant at the conventional level. This means the data
  cannot distinguish the price effect from random noise. Turas flags this
  prominently. Possible causes: too few respondents, too narrow a price
  range, or genuinely inelastic demand.
- **Pseudo-R-squared (McFadden's):** Values above 0.10 indicate a meaningful
  relationship. Values above 0.20 suggest a strong price effect. Values below
  0.05 suggest the model explains very little of the variation in purchase
  intent.
- **AIC (Akaike Information Criterion):** Useful for comparing the logistic
  vs. log-logistic model specification. Lower AIC indicates better fit.

**Reading confidence intervals:**

- The confidence interval around the optimal price communicates the precision
  of the estimate. A narrow interval (e.g., $14.50 to $15.50) indicates high
  confidence. A wide interval (e.g., $10 to $20) indicates the data does not
  strongly constrain the optimal price.
- The demand curve confidence bands show where the model is most and least
  certain. Bands are typically narrowest near the center of the price range
  (where the most data exists) and widest at the extremes.
- If the confidence interval for the optimal price spans a large portion of
  the tested range, consider increasing sample size or narrowing the price
  range in a follow-up study.

---

## 5. Combined Analysis (VW + GG)

### 5.1 Why Combine Methods

Each pricing methodology has blind spots. Van Westendorp reveals the acceptable
range but cannot optimize revenue. Gabor-Granger optimizes revenue but may be
biased by order effects and cannot identify the quality-perception floor.
Combining both methods provides **triangulation** -- independent lines of
evidence that either converge (strengthening confidence) or diverge (revealing
important complexity).

Specific benefits of triangulation:

- **Validate the price range.** VW defines the acceptable range; GG identifies
  the optimal point within it. If the GG optimal falls outside the VW
  acceptable range, this is a signal worth investigating.
- **Calibrate hypothetical bias.** If VW's IDP (the market's expected price)
  differs substantially from the GG optimal, the gap provides insight into
  how much the GG demand curve may be inflated.
- **Richer stakeholder narrative.** Presenting both a range (VW) and a specific
  recommendation (GG) gives stakeholders context for the recommendation and
  flexibility for strategic decision-making.
- **Identify segment opportunities.** When segment-level VW ranges differ
  substantially but the overall GG optimal is a single point, this suggests
  a tiered pricing strategy may outperform a single price.

### 5.2 How Turas Integrates Combined Analysis

When `analysis_method` is set to `both` in the configuration, Turas:

1. **Runs Van Westendorp first** using the four price perception questions.
   Extracts PMC, OPP, IDP, PME, and (if configured) NMS revenue-optimal price.
2. **Runs Gabor-Granger second** using the price-intent data. Produces demand
   curve, revenue curve, optimal price, and elasticity.
3. **Synthesizes a unified recommendation** via the recommendation synthesis
   engine (`12_recommendation_synthesis.R`). The synthesis:
   - Collects candidate prices from both methods (VW OPP, VW IDP, VW midpoint,
     NMS revenue-optimal, GG optimal)
   - Evaluates each candidate against multiple criteria
   - Assigns a confidence score based on cross-method agreement, sample quality,
     and internal consistency
   - Produces an executive summary with a single recommended price, confidence
     level, and supporting rationale
4. **Generates a price ladder** (Good/Better/Best tier structure) using the VW
   range to define tier boundaries, informed by GG demand estimates.

### 5.3 When to Use Combined Analysis

- **When budget and sample size permit.** Combined analysis requires both VW
  questions (4 open-ended) and GG questions (purchase intent at multiple
  prices) in the same survey, which increases questionnaire length.
- **For high-stakes pricing decisions** where the cost of error justifies
  additional data collection.
- **When the product category is new or unfamiliar.** VW identifies the range;
  GG optimizes within it.
- **When stakeholders need both strategic context (range) and tactical
  recommendation (specific price).**

### 5.4 Interpreting Cross-Method Results

**Convergence (high confidence):** When the GG optimal price falls within or
near the VW optimal range (OPP to IDP), the two methods agree. This is the
ideal outcome and supports a strong recommendation.

**Divergence -- GG optimal above VW IDP:** The revenue-maximizing price is
higher than what consumers consider "normal." This can occur when:
- The product has strong differentiation or brand equity
- The sample contains a segment willing to pay a premium
- The GG demand curve is relatively inelastic in the upper range

In this case, consider whether the GG optimal is sustainable long-term or
reflects short-term willingness.

**Divergence -- GG optimal below VW OPP:** The revenue-maximizing price is
below the point of least resistance. This is unusual and suggests:
- The GG price list may not extend high enough
- Demand drops off very quickly at higher prices
- There may be strong competitive pressure anchoring prices low

**Divergence -- GG optimal outside VW acceptable range (PMC to PME):** This is
a red flag. If the revenue-maximizing price falls outside the range consumers
consider acceptable, either the VW data or the GG data (or both) may have
quality issues, or the market is genuinely complex. Investigate before acting.

---

## 6. Comparison Table

### Side-by-Side Methodology Comparison

| Dimension | Van Westendorp PSM | Gabor-Granger | Monadic (Logistic) |
|-----------|-------------------|---------------|-------------------|
| **Measurement type** | Price perception (acceptable range) | Stated purchase intent at fixed prices | Stated purchase intent at randomized single price |
| **Price range required upfront?** | No (respondents provide prices) | Yes (researcher defines price list) | Yes (researcher defines price cells) |
| **Statistical rigor** | Descriptive (intersections of CDFs) | Descriptive with optional bootstrap | Inferential (GLM with formal hypothesis tests) |
| **Ease of implementation** | High (4 simple questions) | Moderate (multiple price-intent questions) | Moderate (randomized cell assignment) |
| **Respondent burden** | Low (4 open-ended questions) | Moderate (intent at 5-10 prices) | Very low (1 price, 1 intent question) |
| **Sample size needed** | 200+ recommended | 150+ recommended | 250-400 (50+ per cell x 5-8 cells) |
| **Revenue optimization** | No (unless NMS extension used) | Yes (direct) | Yes (model-based) |
| **Profit optimization** | No | Yes (when unit cost configured) | Yes (when unit cost configured) |
| **Confidence intervals** | Optional (bootstrap) | Optional (bootstrap) | Yes (bootstrap, model-based) |
| **Bias risk** | Low (no price anchoring), but open-ended noise | Moderate (order effects, hypothetical bias) | Low (no anchoring, no order effects), hypothetical bias remains |
| **Anchoring/order effects** | None | Present (mitigated by randomization) | None (between-subject design) |
| **Quality perception floor** | Yes (Too Cheap question) | No | No |
| **Best application** | Range exploration, new categories, early-stage | Revenue optimization, existing products | High-stakes decisions, statistical rigor |
| **Key limitation** | No purchase prediction | Hypothetical bias, order effects | Large sample required |
| **Turas output types** | Price points (PMC/OPP/IDP/PME), ranges, NMS, curves, descriptives | Demand curve, revenue curve, optimal price, elasticity | Predicted demand, optimal price with CI, model diagnostics |
| **Turas config method name** | `van_westendorp` | `gabor_granger` | `monadic` |

### Quick Decision Matrix

| Your situation | Recommended method |
|---------------|-------------------|
| New product, no reference prices | Van Westendorp |
| Existing product, need optimal price | Gabor-Granger |
| High-stakes decision, need statistical proof | Monadic |
| Budget allows both, want strongest evidence | Combined (VW + GG) or VW + Monadic |
| Small sample (< 150) | Van Westendorp or Gabor-Granger |
| Large sample (400+) | Monadic or Combined |
| Need to understand price-quality threshold | Van Westendorp |
| Need demand curve for scenario planning | Gabor-Granger or Monadic |
| Board presentation requiring confidence intervals | Monadic |
| Competitive benchmarking context | Gabor-Granger |

---

## 7. Integration with Other Research

### 7.1 Pricing with Segmentation

Pricing sensitivity frequently varies by customer segment. Turas supports
segment-level pricing analysis through the `segmentation` configuration,
which runs the selected pricing method independently for each segment and
produces a comparison table.

**How to use it:**

- Define a `segment_column` in the Segmentation sheet of the configuration
- Turas runs the pricing method for the total sample and then for each segment
- The output includes segment-level price points (VW) or optimal prices (GG),
  a comparison table, and automatically generated insights

**Practical guidance:**

- Ensure each segment has sufficient sample (75+ for GG, 100+ for VW)
- If segments show substantially different acceptable ranges or optimal prices,
  consider tiered pricing or segment-specific pricing strategies
- Watch for segments where the VW acceptable range for one group overlaps
  minimally with another -- this is a strong signal for price discrimination
- Use the price ladder output (Good/Better/Best) to translate segment-level
  insights into a product-line strategy

### 7.2 Pricing with Conjoint and MaxDiff

Conjoint analysis (choice-based) and MaxDiff are available in separate Turas
modules. They provide complementary perspectives on pricing:

**Conjoint (CBC) + Pricing:**

- Conjoint measures the **utility of price relative to other product attributes**
  (features, brand, etc.). This reveals how much consumers are willing to trade
  for a lower price versus a better feature.
- Use conjoint when you need to understand price in the context of competitive
  product configurations, not in isolation.
- VW or GG results can inform the price levels used in a subsequent conjoint
  design. Running VW first to identify the acceptable range, then including
  prices within that range as conjoint levels, is a strong sequential design.

**MaxDiff + Pricing:**

- MaxDiff identifies which product attributes matter most to consumers.
  Combining MaxDiff importance rankings with pricing data reveals whether
  price-sensitive consumers value different attributes than price-insensitive
  ones.
- This is particularly useful for segment-based pricing strategies: segments
  that value premium features may tolerate higher prices, while segments
  focused on basic functionality may be highly price-sensitive.

### 7.3 Competitive Benchmarking Context

Pricing research does not occur in a vacuum. Consumers evaluate prices relative
to competitive alternatives. When interpreting Turas pricing outputs:

- **VW acceptable ranges reflect the competitive context.** If competitors
  price at $15-$20, respondents' perception of "too cheap" and "too expensive"
  will be anchored by this range. VW results should be interpreted in light
  of the current competitive landscape.
- **GG demand curves assume the current competitive set.** If a major
  competitor changes price between the survey and the pricing decision, the
  demand curve may shift.
- **Monadic designs can incorporate competitive context** by including
  competitive pricing information in the product description shown to
  respondents. This produces demand estimates conditional on the competitive
  environment.
- Consider using Turas' competitive scenario analysis (`08_competitive_scenarios.R`)
  to model how demand changes under different competitive price assumptions.

### 7.4 Longitudinal Pricing Tracking

For products with ongoing pricing decisions, the Turas tracker module can
monitor how price sensitivity evolves over time:

- Run VW or GG at regular intervals (quarterly, biannually) to track shifts in
  the acceptable range or optimal price
- Monitor whether the OPP drifts upward (consumers becoming less price
  sensitive) or downward (increasing price pressure)
- Track the width of the VW acceptable range -- narrowing range suggests
  increasing price consensus, while widening range suggests market
  fragmentation
- Compare GG demand curve slopes over time to detect changes in overall
  price elasticity

---

## 8. Confidence in Results

### 8.1 How to Assess Quality -- General Principles

No pricing analysis is perfectly reliable. The goal is to understand the
strength and limitations of the evidence before making decisions. Turas
provides multiple diagnostics to support this assessment.

**Universal quality indicators:**

- **Sample size relative to method requirements.** Is the sample large enough
  for the chosen method? Each method section above specifies minimums and
  recommendations.
- **Data quality scores.** Turas validates data before analysis and reports a
  quality score. Low quality scores indicate issues that may compromise results.
- **Internal consistency.** Do respondents give logically consistent answers?
  High rates of VW logical order violations or GG monotonicity violations
  suggest respondent confusion.
- **Cross-method agreement (when running combined).** Convergence between
  methods is the strongest indicator of a reliable result.

### 8.2 Van Westendorp Quality Assessment

| Indicator | What to look for | Concern threshold |
|-----------|-----------------|-------------------|
| Acceptable range width | Proportional to the price level | Width > 2x the OPP suggests high heterogeneity |
| Logical order violations | Too Cheap <= Cheap <= Expensive <= Too Expensive | > 10% violation rate |
| Sample consistency | Low standard deviation within each price question | SD > 50% of mean suggests noisy data |
| Extreme outlier rate | Prices > 10x or < 0.01x the median | > 5% of responses |
| NMS calibration | NMS revenue-optimal falls within the VW acceptable range | If outside, investigate PI data quality |
| OPP-IDP gap | Small gap = symmetric sensitivity; large gap = asymmetric | Review if gap > 30% of the acceptable range |
| Bootstrap CI width (if calculated) | Narrow CIs indicate stable estimates | CIs spanning > 50% of the acceptable range suggest instability |

### 8.3 Gabor-Granger Quality Assessment

| Indicator | What to look for | Concern threshold |
|-----------|-----------------|-------------------|
| Demand curve monotonicity | Demand should strictly decrease with price | Any increase (after smoothing) is suspicious |
| Demand drop-off pattern | Gradual, smooth decline | Sharp cliff (e.g., 80% to 10% between two points) suggests a design issue |
| Revenue curve shape | Single clear peak | Multiple peaks or flat top makes optimal price ambiguous |
| Monotonicity violations per respondent | Intent should not increase when price increases | > 15% of respondents show violations |
| Sample size per price point | Adequate n at each tested price | Any price point with n < 30 |
| Purchase intent range | Demand should span from high to low across tested prices | If all prices show > 80% or < 20%, the price range is too narrow |
| Bootstrap CI overlap | CIs at adjacent prices should overlap | Non-overlapping CIs at adjacent prices suggest unstable estimates |

### 8.4 Monadic Quality Assessment

| Indicator | What to look for | Concern threshold |
|-----------|-----------------|-------------------|
| Price coefficient p-value | Statistically significant negative coefficient | p > 0.05 (Turas flags this) |
| Pseudo-R-squared (McFadden) | Meaningful model fit | < 0.05 indicates very weak price effect |
| AIC comparison | Lower is better (compare logistic vs. log-logistic) | Large AIC difference (> 10) favors the lower model |
| Cell balance | Roughly equal n across price cells | Min cell / max cell < 0.5 indicates imbalance |
| Minimum cell size | Adequate respondents at each price | Any cell < 30 |
| Optimal price CI width | Narrow interval indicates precision | CI spanning > 40% of the tested range |
| Observed vs. predicted agreement | Model predictions should track observed cell intents | Systematic deviation suggests model misspecification |
| Bootstrap convergence | High proportion of successful bootstrap iterations | < 80% success rate indicates model instability |
| Demand curve CI bands | Narrower is better | Bands spanning > 30 percentage points suggest high uncertainty |

### 8.5 Combined Analysis Confidence Scoring

When Turas runs combined analysis and synthesizes a recommendation, the
confidence score reflects:

1. **Cross-method agreement (highest weight).** If the GG optimal price falls
   within or near the VW optimal range, confidence is high. Divergence lowers
   confidence.
2. **Sample quality.** Large sample with few violations scores higher than
   small sample with many issues.
3. **NMS consistency.** If NMS results are available and the NMS revenue-optimal
   agrees with GG, confidence increases further.
4. **Segment consistency.** If segment-level analyses produce similar optimal
   prices, confidence is higher than if segments diverge dramatically.
5. **Data quality scores.** Turas' validation quality score from both VW and
   GG data checks feeds into the overall confidence assessment.

The synthesis engine classifies confidence as:

- **High (75-100%):** Strong cross-method agreement, adequate samples, clean
  data. The recommendation can be acted on with confidence.
- **Moderate (50-74%):** Partial agreement or some data quality concerns. The
  recommendation is directionally correct but should be interpreted with
  caution.
- **Low (below 50%):** Significant disagreement between methods, small samples,
  or data quality issues. Recommend additional research before committing to
  a price.

---

## Appendix: Glossary of Terms

| Term | Definition |
|------|-----------|
| **Arc elasticity** | Price elasticity calculated between two discrete price points using the midpoint formula |
| **Bootstrap CI** | Confidence interval constructed by repeatedly resampling the data and re-running the analysis |
| **Cumulative distribution function (CDF)** | The proportion of respondents giving a value at or below each price point |
| **Demand curve** | The relationship between price and the proportion of consumers willing to purchase |
| **Hypothetical bias** | The tendency for stated purchase intent to overstate actual purchase behavior |
| **IDP** | Indifference Price Point -- where equal proportions find the product cheap vs. expensive |
| **Logistic regression** | A generalized linear model for binary outcomes, used in monadic testing |
| **Monotonicity** | The property that demand does not increase as price increases |
| **NMS extension** | Newton-Miller-Smith extension to VW that incorporates purchase probability |
| **OPP** | Optimal Price Point -- where equal proportions find the product too cheap vs. too expensive |
| **PAVA** | Pool Adjacent Violators Algorithm -- a method for enforcing monotonicity |
| **PMC** | Point of Marginal Cheapness -- below which too many consumers doubt quality |
| **PME** | Point of Marginal Expensiveness -- above which too many consumers refuse to buy |
| **Pseudo-R-squared** | McFadden's pseudo-R-squared, a measure of logistic model fit (0 to 1) |
| **Revenue curve** | Price multiplied by demand at each price point |
| **Revenue index** | Relative revenue calculated as price times purchase proportion |
| **Top-box coding** | Converting Likert scale responses to binary by counting the top categories as positive |
| **Triangulation** | Using multiple independent methods to strengthen conclusions |

---

## Appendix: References

- Gabor, A., & Granger, C. W. J. (1966). Price as an Indicator of Quality:
  Report on an Enquiry. *Economica*, 33(129), 43-70.
- Lipovetsky, S. (2006). Van Westendorp Price Sensitivity in Statistical
  Modeling. *International Journal of Operations and Quantitative Management*,
  12(2), 141-156.
- Newton, D., Miller, J., & Smith, P. (1993). A Market Acceptance Extension to
  Traditional Price Sensitivity Measurement. *Proceedings of the American
  Marketing Association Advanced Research Techniques Forum*.
- Van Westendorp, P. (1976). NSS Price Sensitivity Meter (PSM) -- A New
  Approach to Study Consumer Perception of Prices. *Proceedings of the ESOMAR
  Congress*, Venice.

---

*Document generated for the Turas Analytics Platform by The Research LampPost
(Pty) Ltd. For technical implementation details, see TECHNICAL_REFERENCE.md.
For usage examples and workflows, see EXAMPLE_WORKFLOWS.md.*

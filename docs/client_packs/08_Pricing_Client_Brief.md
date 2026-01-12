---
editor_options: 
  markdown: 
    wrap: 72
---

# Pricing: Price Sensitivity & Optimization

**What This Module Does** Pricing analyzes how price changes affect
purchase behavior and finds the revenue-maximizing price point. It
quantifies price elasticity, acceptable price ranges, and optimal
pricing strategy.

------------------------------------------------------------------------

## What Problem Does It Solve?

Pricing is critical but difficult: - What's the highest price customers
will accept? - How much will sales drop if we raise prices? - What price
maximizes revenue (not just volume)? - What's the "sweet spot" between
too cheap and too expensive?

**Pricing provides data-driven answers to optimize your pricing
strategy.**

------------------------------------------------------------------------

## How It Works

Common approaches the module supports:

**1. Van Westendorp Price Sensitivity Meter (PSM):** Asks four
questions: - At what price is it too expensive (wouldn't consider)? - At
what price is it getting expensive (hesitate)? - At what price is it a
bargain (great deal)? - At what price is it too cheap (question
quality)?

**2. Gabor-Granger:** Shows respondents different prices, asks purchase
intent at each

**3. Conjoint-Based Pricing:** Integrates with conjoint module for
multi-attribute pricing

The module calculates: - **Optimal price point** (revenue-maximizing) -
**Acceptable price range** (PSM range) - **Price elasticity** (% demand
change per % price change) - **Revenue curves** showing expected revenue
at each price

------------------------------------------------------------------------

## What You Get

**Van Westendorp Outputs:** - Optimal Price Point (OPP) - where "too
expensive" crosses "too cheap" - Acceptable price range - Point of
Marginal Cheapness (PMC) - Point of Marginal Expensiveness (PME) -
Graphical curves showing price sensitivity

**Elasticity Analysis:** - Price elasticity coefficient (-2.0 = 10%
price increase → 20% volume decrease) - Revenue optimization curves -
Breakeven analysis - Demand forecasting at different prices

**Excel Reports:** - Formatted price sensitivity charts - Revenue
projection tables - Competitive price benchmarking - Segment-specific
pricing insights

------------------------------------------------------------------------

## Technology Used

| Package | Why We Use It |
|---------------------------|---------------------------------------------|
| **pricesensitivitymeter** | Van Westendorp Price Sensitivity Meter analysis |
| **stats** | Logistic regression for demand curves and elasticity |
| **ggplot2** | Professional visualization of price sensitivity curves |
| **openxlsx** | Professional Excel output with charts and tables |

------------------------------------------------------------------------

## Strengths

✅ **Multiple Methods:** Supports PSM, Gabor-Granger, conjoint-based
pricing ✅ **Revenue Optimization:** Finds profit-maximizing price, not
just willingness-to-pay ✅ **Visual Outputs:** Clear graphs showing
price-demand relationships ✅ **Segment Analysis:** Different pricing
for different customer segments ✅ **Elasticity Estimates:** Quantifies
price sensitivity precisely ✅ **Scenario Testing:** Model "what if"
pricing changes

------------------------------------------------------------------------

## Limitations

⚠️ **Stated vs. Actual:** Survey responses may not match real purchase
behavior ⚠️ **Competitive Context:** Doesn't automatically account for
competitor pricing ⚠️ **Assumes Rational Decisions:** Real purchases
influenced by emotion, context ⚠️ **Static Analysis:** Doesn't capture
dynamic pricing or time-based changes ⚠️ **Category Assumptions:** Works
best for familiar product categories

------------------------------------------------------------------------

## Statistical Concepts Explained (Plain English)

### Van Westendorp Price Sensitivity Meter: The 4 Questions

The Van Westendorp method asks respondents to provide FOUR price points:

**Q1: "At what price would you consider the product to be so expensive
that you would not consider buying it?" (Too Expensive)**

**Q2: "At what price would you consider the product to be priced so low
that you would feel the quality couldn't be very good?" (Too Cheap)**

**Q3: "At what price would you consider the product starting to get
expensive, so that it is not out of the question, but you would have to
give some thought to buying it?" (Expensive)**

**Q4: "At what price would you consider the product to be a bargain—a
great buy for the money?" (Cheap/Bargain)**

**Why 4 questions instead of just asking "What price would you pay?"**

Because willingness-to-pay is a RANGE, not a single number. These 4
questions map the psychological boundaries of acceptable pricing.

------------------------------------------------------------------------

### How Van Westendorp Calculates Key Price Points (Step-by-Step)

**STEP 1: Collect the 4 prices from each respondent**

Example data (5 respondents):

| Respondent | Too Cheap | Bargain | Expensive | Too Expensive |
|------------|-----------|---------|-----------|---------------|
| 1          | \$15      | \$25    | \$40      | \$60          |
| 2          | \$18      | \$28    | \$45      | \$65          |
| 3          | \$12      | \$22    | \$38      | \$55          |
| 4          | \$20      | \$30    | \$42      | \$58          |
| 5          | \$16      | \$26    | \$43      | \$62          |

**STEP 2: Create cumulative distribution curves for each question**

For EACH price point from \$0 to \$100: - Count what % of respondents
said "too cheap" at or below this price - Count what % said "too
expensive" at or above this price - Count what % said "bargain" at or
below this price - Count what % said "expensive" at or above this price

**Example at \$30:** - Too Cheap: 80% (4 of 5 said too cheap is ≤\$30) -
Too Expensive: 0% (0 of 5 said too expensive is ≥\$30) - Bargain: 60% (3
of 5 said bargain is ≤\$30) - Expensive: 100% (all 5 said expensive is
≥\$30)

**STEP 3: Plot the 4 curves**

You now have 4 curves showing cumulative percentages: 1. **"Too Cheap"
curve** (rising from 0% to 100% as price increases) 2. **"Not Cheap"
curve** = 100% - "Bargain%" (rising, shows % who DON'T think it's a
bargain) 3. **"Not Expensive" curve** = 100% - "Expensive%" (falling,
shows % who DON'T think it's expensive) 4. **"Too Expensive" curve**
(rising from 0% to 100%)

**STEP 4: Find intersection points**

**Point of Marginal Cheapness (PMC):** - Where "Too Cheap" curve crosses
"Not Cheap" curve - Interpretation: Below this price, more people doubt
quality than see it as a bargain - Calculation: Find price where
%TooChea = %(100 - %Bargain)

**Optimal Price Point (OPP):** - Where "Too Cheap" curve crosses "Too
Expensive" curve - **This is your revenue-maximizing price** -
Interpretation: Fewest people excluded (minimal % think too cheap OR too
expensive) - Calculation: Find price where %TooCheap = %TooExpensive

**Indifference Price Point (IDP):** - Where "Not Cheap" curve crosses
"Not Expensive" curve - Interpretation: Equal resistance to price being
too high vs not a bargain - Calculation: Find price where
%(100-%Bargain) = %(100-%Expensive)

**Point of Marginal Expensiveness (PME):** - Where "Expensive" curve
crosses "Too Expensive" curve - Interpretation: Above this price, more
people absolutely reject than just hesitate - Calculation: Find price
where %Expensive = %TooExpensive

**STEP 5: Define acceptable price range**

**Acceptable Range = PMC to PME** - Lower bound (PMC): \$25 in our
example - Upper bound (PME): \$45 - **Safe pricing zone: \$25-\$45**

**Optimal Range = OPP to IDP** - Tighter range within acceptable zone -
OPP: \$32 (revenue-maximizing) - IDP: \$38 (equal psychological
resistance) - **Ideal pricing zone: \$32-\$38**

------------------------------------------------------------------------

### Worked Example: Software Subscription Pricing

**Survey Results (200 respondents):**

| Price Point | \% Too Cheap | \% Bargain | \% Expensive | \% Too Expensive |
|-------------|--------------|------------|--------------|------------------|
| \$10        | 95%          | 100%       | 0%           | 0%               |
| \$20        | 72%          | 88%        | 5%           | 0%               |
| \$30        | 38%          | 62%        | 28%          | 2%               |
| \$40        | 12%          | 35%        | 58%          | 18%              |
| \$50        | 2%           | 15%        | 82%          | 45%              |
| \$60        | 0%           | 5%         | 95%          | 72%              |

**Calculate the 4 Van Westendorp price points:**

**1. PMC (Point of Marginal Cheapness):** - Find where %TooCheap =
%(100-%Bargain) - At \$20: 72% too cheap vs 12% not bargain (72 ≠ 12) -
At \$25: 55% too cheap vs 30% not bargain (interpolate) - **PMC ≈ \$27**
(where curves cross)

**2. OPP (Optimal Price Point):** - Find where %TooCheap =
%TooExpensive - At \$30: 38% too cheap vs 2% too expensive - At \$40:
12% too cheap vs 18% too expensive - **OPP ≈ \$35** (where curves cross)

**3. IDP (Indifference Price Point):** - Find where %(100-%Bargain) =
%(100-%Expensive) - At \$30: 38% not bargain vs 72% not expensive - At
\$40: 65% not bargain vs 42% not expensive - **IDP ≈ \$37** (where
curves cross)

**4. PME (Point of Marginal Expensiveness):** - Find where %Expensive =
%TooExpensive - At \$50: 82% expensive vs 45% too expensive - At \$55:
88% expensive vs 60% too expensive - **PME ≈ \$52** (where curves cross)

**Pricing Recommendation:** - **Acceptable Range:** \$27-\$52 (won't
alienate most customers) - **Optimal Price:** \$35 (maximizes market
acceptance) - **Safe Zone:** \$32-\$40 (between OPP and IDP)

------------------------------------------------------------------------

### When Van Westendorp Fails: Critical Limitations

**1. Doesn't Account for Actual Purchase Behavior**

**The Problem:** People's stated prices often differ from actual
willingness to pay.

**Example:** - Survey says: OPP = \$35 - Real A/B test shows: Revenue
maximized at \$42 - Why? Respondents underestimated their actual
willingness to pay

**Solution:** Use Newton-Miller-Smith (NMS) extension (see below) OR
validate with purchase intent.

**2. Assumes Rational, Independent Pricing**

**The Problem:** Real purchases are influenced by: - Competitive pricing
(what alternatives cost) - Anchoring effects (what customers currently
pay) - Bundling (product + service packages)

**Example:** - Van Westendorp says: OPP = \$50 - Competitor launches at
\$45 - Now your \$50 feels expensive (not captured in survey)

**Solution:** Run competitive pricing scenarios separately.

**3. Assumes Homogeneous Market**

**The Problem:** Different segments have different price sensitivities.

**Example:** - Enterprise customers: OPP = \$199/month - Small business:
OPP = \$49/month - Combined survey: OPP = \$99 (wrong for BOTH segments)

**Solution:** Run Van Westendorp separately by segment.

**4. Order Effects in Questions**

**The Problem:** If you ask the 4 questions in order (cheap to
expensive), respondents anchor on earlier answers.

**Example:** - Asked "too cheap" first: Respondent says \$15 - Then
asked "bargain": Respondent says \$20 (influenced by the \$15) - Result:
PMC artificially low

**Solution:** Randomize question order or use "expensive" questions
first.

**5. No Revenue/Volume Trade-Off**

**The Problem:** OPP minimizes exclusion but doesn't maximize REVENUE.

**Example:** - OPP = \$40 → 1,000 customers → \$40,000 revenue - Higher
price = \$50 → 800 customers → \$40,000 revenue - **Both have same
revenue, but OPP doesn't tell you which is better**

**Solution:** Use Newton-Miller-Smith extension OR Gabor-Granger for
revenue optimization.

------------------------------------------------------------------------

### Newton-Miller-Smith (NMS) Extension: Adding Purchase Intent

**Enhancement:** Ask purchase intent at the "Cheap" and "Expensive"
price points.

**Additional Questions:**

**Q5:** "If the product cost [YOUR CHEAP PRICE], how likely would you be
to purchase it?" - Response: 1 (Definitely Not) to 5 (Definitely Yes)

**Q6:** "If the product cost [YOUR EXPENSIVE PRICE], how likely would
you be to purchase it?" - Response: 1 (Definitely Not) to 5 (Definitely
Yes)

**How NMS Improves Van Westendorp:**

Now you can calculate ACTUAL trial/revenue curves, not just acceptance
curves.

**Trial-Optimized Price:** Maximizes number of buyers (uses purchase
intent at each price)

**Revenue-Optimized Price:** Maximizes Price × Volume (uses purchase
intent × price)

**Example:**

| Price | Van Westendorp Acceptance | Purchase Intent (Top 2 Box) | Estimated Volume | Revenue |
|-------------|-----------------|-----------------|-------------|-------------|
| \$30 | 85% | 72% | 720 | \$21,600 |
| \$35 | 78% (OPP) | 65% | 650 | \$22,750 |
| \$40 | 68% | 54% | 540 | \$21,600 |
| \$45 | 52% | 38% | 380 | \$17,100 |

**Result:** Revenue-optimized price = \$35 (not necessarily same as OPP)

------------------------------------------------------------------------

### Price Elasticity: Measuring Demand Response

**What Is Price Elasticity?**

Price elasticity measures how much demand changes when price changes.

**Formula:**

```         
Elasticity = % Change in Quantity / % Change in Price
```

**Example Calculation:**

**Baseline:** - Price: \$100 - Quantity sold: 1,000 units

**After price increase:** - New price: \$110 (+10%) - New quantity: 850
units (-15%)

**Calculate elasticity:**

```         
Elasticity = -15% / +10% = -1.5
```

**Interpretation:** A 1% price increase causes a 1.5% volume decrease.

------------------------------------------------------------------------

### Elasticity Categories & What They Mean

**1. Elastic Demand (Elasticity \< -1.0)**

**Example:** Elasticity = -2.0 - 10% price increase → 20% volume
decrease - **Implication:** Price-sensitive market, increasing price
REDUCES total revenue - **Strategy:** Keep prices competitive, focus on
volume

**Product Examples:** - Consumer electronics - Fast food - Airline
tickets (economy class)

**2. Unit Elastic (Elasticity = -1.0)**

**Example:** Elasticity = -1.0 - 10% price increase → 10% volume
decrease - **Implication:** Revenue stays constant regardless of price -
**Strategy:** Price based on other factors (brand positioning, margins)

**3. Inelastic Demand (Elasticity \> -1.0)**

**Example:** Elasticity = -0.5 - 10% price increase → 5% volume
decrease - **Implication:** Price increase INCREASES total revenue -
**Strategy:** Premium pricing, maximize margins

**Product Examples:** - Insulin (medical necessity) - Luxury goods
(status symbols) - Gasoline (no close substitutes)

------------------------------------------------------------------------

### Revenue Optimization Using Elasticity

**The Revenue Formula:**

```         
Revenue = Price × Quantity
Revenue = P × Q(P)
```

Where Q(P) is demand as a function of price.

**Finding Optimal Price (Calculus Approach):**

If you know elasticity (ε), the revenue-maximizing condition is:

```         
Optimal occurs when: 1 + (1/ε) = 0
Therefore: ε = -1
```

**Practical Implication:** Revenue is maximized when demand is unit
elastic (ε = -1.0).

**Worked Example:**

**Current situation:** - Price: \$50 - Quantity: 2,000 - Elasticity:
-1.8 (elastic)

**Should you raise or lower price?**

Since ε = -1.8 (more elastic than -1.0), demand is TOO sensitive to
price.

**Test lower price:** - New price: \$45 (-10%) - Expected quantity
change: +18% (= -10% × -1.8) - New quantity: 2,000 × 1.18 = 2,360 -
**New revenue: \$45 × 2,360 = \$106,200** - **Old revenue: \$50 × 2,000
= \$100,000** - **Gain: +\$6,200**

**Conclusion:** Lower price to increase revenue when demand is elastic.

------------------------------------------------------------------------

### Interpreting the 4 Van Westendorp Curves

**Visual Representation:**

```         
100%│     Too Expensive
    │           ╱
    │         ╱
    │       ╱          Not Cheap
    │     ╱           ╱
    │   ╱  PME      ╱
 50%│ ╱    │      ╱  IDP
    │╱     │    ╱ OPP │
    │ PMC  │  ╱   │   │
    │  │   │╱    │   │
    │  │  ╱│    │   ╱  Not Expensive
  0%│  │╱  │    │ ╱
    └──┴───┴────┴─────────────
      $25 $35  $38  $52  Price
```

**Curve-by-Curve Interpretation:**

**1. "Too Cheap" Curve (rising left to right):** - Shows % who think
quality is questionable at each price - Steep rise at low prices =
strong quality concerns - Flat at high prices = no one thinks it's
suspiciously cheap

**2. "Not Cheap" (100% - Bargain %) Curve:** - Shows % who DON'T see it
as a good deal - Intersection with "Too Cheap" = PMC (marginal cheapness
point) - Above PMC: More people doubt quality than see value

**3. "Not Expensive" (100% - Expensive %) Curve:** - Shows % who DON'T
think it's getting pricey - Intersection with "Not Cheap" = IDP
(indifference point) - Below IDP: More acceptance than resistance

**4. "Too Expensive" Curve (rising left to right):** - Shows % who
absolutely won't buy at each price - Intersection with "Too Cheap" = OPP
(optimal price) - Intersection with "Expensive" = PME (marginal
expensiveness)

**Key Insight:** The GAPS between curves matter as much as the
intersections.

**Wide gap between "Too Cheap" and "Too Expensive":** → Flexible pricing
range (customers have wide acceptable range)

**Narrow gap:** → Tight pricing range (must price carefully, little room
for error)

------------------------------------------------------------------------

## Best Use Cases

**Ideal For:** - New product launch pricing - Pricing strategy
optimization for existing products - Understanding price-value
perceptions - Competitive pricing analysis - Segment-based pricing
strategies

**Not Ideal For:** - Commodity products with no differentiation - Highly
volatile markets (prices change daily) - Products with network effects
(value depends on \# users) - Luxury goods where higher price signals
quality

------------------------------------------------------------------------

## Quality & Reliability

**Quality Score:** 90/100 **Production Ready:** Yes **Error Handling:**
Good - Validates price inputs and model assumptions **Testing Status:**
Core methods tested; expanding test coverage

------------------------------------------------------------------------

## Example Outputs

**Van Westendorp Price Sensitivity:**

| Metric                  | Price Point   | Interpretation                     |
|-------------------------|---------------|------------------------------------|
| Too Cheap               | \$18          | Below this, quality concerns arise |
| Bargain                 | \$25          | Great value perception             |
| **Optimal Price (OPP)** | **\$32**      | **Revenue-maximizing price**       |
| Expensive               | \$42          | Some hesitation begins             |
| Too Expensive           | \$55          | Most won't consider                |
| **Acceptable Range**    | **\$25-\$42** | **Safe pricing zone**              |

**Price Elasticity Table:**

| Price | Demand (%) | Revenue  | Elasticity |
|-------|------------|----------|------------|
| \$25  | 100%       | \$25,000 | \-         |
| \$30  | 85%        | \$25,500 | -1.5       |
| \$32  | 78%        | \$24,960 | -1.4       |
| \$35  | 68%        | \$23,800 | -1.6       |
| \$40  | 52%        | \$20,800 | -1.8       |

→ Optimal price is \$30 (highest revenue)

------------------------------------------------------------------------

## Real-World Example

**Scenario:** SaaS subscription pricing

**Challenge:** Currently priced at \$49/month, considering price
increase

**Pricing Study:** - Van Westendorp + Purchase intent at multiple
prices - 400 respondents (current customers + prospects) - Tested
prices: \$39, \$49, \$59, \$69, \$79

**Results:** - Optimal price: \$59/month (20% increase) - Price
elasticity: -1.2 (moderately elastic) - Revenue projection: +14% at \$59
vs. current \$49 - Acceptable range: \$45-\$75 - Premium segment would
pay up to \$89

**Business Decision:** - Implement \$59 standard pricing (+\$10) -
Create \$89 premium tier with extra features - Grandfather existing
customers at \$49 for 12 months - Expected revenue lift: \$1.2M annually

------------------------------------------------------------------------

## Pricing vs. Other Modules

**Use Pricing when:** - Primary question is "What should we charge?" -
Need to understand price-value perceptions - Optimizing revenue through
price

**Use Conjoint when:** - Price is one of many features to optimize -
Need to understand feature-price trade-offs - Simulating multi-attribute
competitive scenarios

**Use MaxDiff when:** - Prioritizing features (where to invest) - Price
is not the primary focus

------------------------------------------------------------------------

## What's Next (Future Enhancements)

**Coming Soon:** - Dynamic pricing simulation - Competitive response
modeling - Integration with conjoint for bundled pricing

**Future Vision:** - Real-time price optimization algorithms - A/B test
result integration - Machine learning price prediction

------------------------------------------------------------------------

## Bottom Line

Pricing takes the guesswork out of pricing decisions with rigorous
statistical analysis of price sensitivity. Whether using Van
Westendorp's proven method or elasticity modeling, you get clear
guidance on optimal price points and acceptable ranges. The module helps
you balance volume and margin to maximize revenue.

**Think of it as:** A pricing consultant that analyzes customer
willingness-to-pay and shows you exactly where to price for maximum
revenue, backed by quantitative evidence rather than gut feel.

------------------------------------------------------------------------

*For questions or support, contact The Research LampPost (Pty) Ltd*

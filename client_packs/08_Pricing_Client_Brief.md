# Pricing: Price Sensitivity & Optimization

**What This Module Does**
Pricing analyzes how price changes affect purchase behavior and finds the revenue-maximizing price point. It quantifies price elasticity, acceptable price ranges, and optimal pricing strategy.

---

## What Problem Does It Solve?

Pricing is critical but difficult:
- What's the highest price customers will accept?
- How much will sales drop if we raise prices?
- What price maximizes revenue (not just volume)?
- What's the "sweet spot" between too cheap and too expensive?

**Pricing provides data-driven answers to optimize your pricing strategy.**

---

## How It Works

Common approaches the module supports:

**1. Van Westendorp Price Sensitivity Meter (PSM):**
Asks four questions:
- At what price is it too expensive (wouldn't consider)?
- At what price is it getting expensive (hesitate)?
- At what price is it a bargain (great deal)?
- At what price is it too cheap (question quality)?

**2. Gabor-Granger:**
Shows respondents different prices, asks purchase intent at each

**3. Conjoint-Based Pricing:**
Integrates with conjoint module for multi-attribute pricing

The module calculates:
- **Optimal price point** (revenue-maximizing)
- **Acceptable price range** (PSM range)
- **Price elasticity** (% demand change per % price change)
- **Revenue curves** showing expected revenue at each price

---

## What You Get

**Van Westendorp Outputs:**
- Optimal Price Point (OPP) - where "too expensive" crosses "too cheap"
- Acceptable price range
- Point of Marginal Cheapness (PMC)
- Point of Marginal Expensiveness (PME)
- Graphical curves showing price sensitivity

**Elasticity Analysis:**
- Price elasticity coefficient (-2.0 = 10% price increase → 20% volume decrease)
- Revenue optimization curves
- Breakeven analysis
- Demand forecasting at different prices

**Excel Reports:**
- Formatted price sensitivity charts
- Revenue projection tables
- Competitive price benchmarking
- Segment-specific pricing insights

---

## Technology Used

| Package | Why We Use It |
|---------|---------------|
| **data.table** | Fast aggregation of purchase intent data |
| **stats** | Logistic regression for demand curves |
| **openxlsx** | Professional Excel output with charts |

---

## Strengths

✅ **Multiple Methods:** Supports PSM, Gabor-Granger, conjoint-based pricing
✅ **Revenue Optimization:** Finds profit-maximizing price, not just willingness-to-pay
✅ **Visual Outputs:** Clear graphs showing price-demand relationships
✅ **Segment Analysis:** Different pricing for different customer segments
✅ **Elasticity Estimates:** Quantifies price sensitivity precisely
✅ **Scenario Testing:** Model "what if" pricing changes

---

## Limitations

⚠️ **Stated vs. Actual:** Survey responses may not match real purchase behavior
⚠️ **Competitive Context:** Doesn't automatically account for competitor pricing
⚠️ **Assumes Rational Decisions:** Real purchases influenced by emotion, context
⚠️ **Static Analysis:** Doesn't capture dynamic pricing or time-based changes
⚠️ **Category Assumptions:** Works best for familiar product categories

---

## Statistical Concepts Explained (Plain English)

**What Is Price Elasticity?**
Measures how sensitive demand is to price changes:
- **Elasticity = -1.5:** 10% price increase → 15% volume decrease
- **Elastic (< -1):** Demand very sensitive to price
- **Inelastic (> -1):** Demand less sensitive to price

**Van Westendorp Method:**
Finds the price where customer perceptions align:
- **Optimal Price Point:** Where "too expensive" = "too cheap"
- **Acceptable Range:** Between "bargain" and "expensive"

Think of it as finding where customer expectations converge.

**Revenue Maximization:**
Not the same as highest price or highest volume:
- Too low: High volume but low revenue per unit
- Too high: High margin but low volume
- Optimal: The price where Price × Volume is maximized

---

## Best Use Cases

**Ideal For:**
- New product launch pricing
- Pricing strategy optimization for existing products
- Understanding price-value perceptions
- Competitive pricing analysis
- Segment-based pricing strategies

**Not Ideal For:**
- Commodity products with no differentiation
- Highly volatile markets (prices change daily)
- Products with network effects (value depends on # users)
- Luxury goods where higher price signals quality

---

## Quality & Reliability

**Quality Score:** 90/100
**Production Ready:** Yes
**Error Handling:** Good - Validates price inputs and model assumptions
**Testing Status:** Core methods tested; expanding test coverage

---

## Example Outputs

**Van Westendorp Price Sensitivity:**

| Metric | Price Point | Interpretation |
|--------|------------|----------------|
| Too Cheap | $18 | Below this, quality concerns arise |
| Bargain | $25 | Great value perception |
| **Optimal Price (OPP)** | **$32** | **Revenue-maximizing price** |
| Expensive | $42 | Some hesitation begins |
| Too Expensive | $55 | Most won't consider |
| **Acceptable Range** | **$25-$42** | **Safe pricing zone** |

**Price Elasticity Table:**

| Price | Demand (%) | Revenue | Elasticity |
|-------|-----------|---------|-----------|
| $25 | 100% | $25,000 | - |
| $30 | 85% | $25,500 | -1.5 |
| $32 | 78% | $24,960 | -1.4 |
| $35 | 68% | $23,800 | -1.6 |
| $40 | 52% | $20,800 | -1.8 |

→ Optimal price is $30 (highest revenue)

---

## Real-World Example

**Scenario:** SaaS subscription pricing

**Challenge:** Currently priced at $49/month, considering price increase

**Pricing Study:**
- Van Westendorp + Purchase intent at multiple prices
- 400 respondents (current customers + prospects)
- Tested prices: $39, $49, $59, $69, $79

**Results:**
- Optimal price: $59/month (20% increase)
- Price elasticity: -1.2 (moderately elastic)
- Revenue projection: +14% at $59 vs. current $49
- Acceptable range: $45-$75
- Premium segment would pay up to $89

**Business Decision:**
- Implement $59 standard pricing (+$10)
- Create $89 premium tier with extra features
- Grandfather existing customers at $49 for 12 months
- Expected revenue lift: $1.2M annually

---

## Pricing vs. Other Modules

**Use Pricing when:**
- Primary question is "What should we charge?"
- Need to understand price-value perceptions
- Optimizing revenue through price

**Use Conjoint when:**
- Price is one of many features to optimize
- Need to understand feature-price trade-offs
- Simulating multi-attribute competitive scenarios

**Use MaxDiff when:**
- Prioritizing features (where to invest)
- Price is not the primary focus

---

## What's Next (Future Enhancements)

**Coming Soon:**
- Dynamic pricing simulation
- Competitive response modeling
- Integration with conjoint for bundled pricing

**Future Vision:**
- Real-time price optimization algorithms
- A/B test result integration
- Machine learning price prediction

---

## Bottom Line

Pricing takes the guesswork out of pricing decisions with rigorous statistical analysis of price sensitivity. Whether using Van Westendorp's proven method or elasticity modeling, you get clear guidance on optimal price points and acceptable ranges. The module helps you balance volume and margin to maximize revenue.

**Think of it as:** A pricing consultant that analyzes customer willingness-to-pay and shows you exactly where to price for maximum revenue, backed by quantitative evidence rather than gut feel.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*

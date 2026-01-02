# Conjoint: Choice-Based Conjoint Analysis

**What This Module Does**
Conjoint analyzes how people make trade-off decisions between product features and price. It reveals the value customers place on each feature and simulates market share for different product configurations.

---

## What Problem Does It Solve?

When designing products or services, you face trade-offs:
- How much is a premium feature worth vs. lower price?
- Which combination of features will win the most customers?
- What happens to market share if we change our offering?

**Conjoint quantifies customer preferences and simulates competitive scenarios.**

---

## How It Works

In your survey, respondents choose between product profiles with different features and prices:
- Option A: Premium brand, $50, Fast delivery
- Option B: Standard brand, $30, Standard delivery
- Option C: Budget brand, $20, Slow delivery

The module analyzes thousands of these choices to calculate:
- **Utility scores:** How much value each feature provides
- **Importance weights:** Which attributes matter most
- **Willingness-to-pay:** Dollar value of each feature
- **Market simulations:** Predicted market share for any product configuration

---

## What You Get

**Individual-Level Results:**
- Utility scores for every respondent (personalized preferences)
- Part-worth values for each feature level
- Importance weights showing priority attributes

**Aggregate Results:**
- Average utilities across all respondents
- Attribute importance rankings
- Price sensitivity estimates

**Market Simulations:**
- Predicted market share for up to 10 competitive products
- "What-if" scenarios (change price, add features)
- Optimal product configurations

**Excel Outputs:**
- Formatted utility tables
- Importance charts
- Simulation results with share predictions

---

## Technology Used

| Package | Why We Use It |
|---------|---------------|
| **ChoiceModelR** | Hierarchical Bayes estimation (gold standard for conjoint) |
| **support.CEs** | Choice experiment design and analysis |
| **mlogit** | Multinomial logit models for aggregate analysis |
| **data.table** | Fast simulation and scenario testing |

---

## Strengths

✅ **Hierarchical Bayes:** Most sophisticated conjoint method available in R
✅ **Individual-Level:** Personalized utilities for each respondent (not just averages)
✅ **Market Simulation:** Predict market share for any product configuration
✅ **Price Optimization:** Find revenue-maximizing price points
✅ **Flexible:** Works with any number of attributes and levels
✅ **Handles "None" Option:** Accounts for people choosing not to purchase
✅ **Realistic Trade-Offs:** Forces respondents to make real-world choices

---

## Limitations

⚠️ **Complex Survey Design:** Requires carefully designed choice experiments (needs expertise)
⚠️ **Sample Size:** HB models need 200+ respondents for stable estimates
⚠️ **Computation Time:** Hierarchical Bayes can take minutes to hours for large datasets
⚠️ **Assumes Rational Choice:** People choose based on utilities (doesn't capture impulse/emotion)
⚠️ **Attribute Independence:** Assumes features are independent (can be limiting)

---

## Statistical Concepts Explained (Plain English)

**What Are Utilities?**
Think of utilities as "points" or "value scores":
- Higher utility = more preferred
- Premium brand: +2.5 utility points
- Budget brand: -1.2 utility points
- Fast delivery: +1.8 utility points

Respondents choose the option with the highest total utility.

**What Is Hierarchical Bayes (HB)?**
A sophisticated method that:
- Estimates individual preferences (not just averages)
- "Borrows strength" from the group to stabilize individual estimates
- Produces more reliable results than counting methods

**Market Share Simulation:**
For any set of products, the model calculates:
1. Total utility for each product (for each person)
2. Probability of choosing each product
3. Aggregate those probabilities = predicted market share

---

## Best Use Cases

**Ideal For:**
- Product development (which features to include)
- Pricing strategy (optimal price points)
- Competitive positioning (how to configure vs. competitors)
- Feature prioritization (what to build first)
- Market entry decisions (will our concept succeed)

**Not Ideal For:**
- Brand equity measurement (use discrete choice or brand tracking)
- Very complex products (>6 attributes gets difficult for respondents)
- Emotional/aspirational products where logic doesn't apply
- Small samples (<150 respondents)

---

## Quality & Reliability

**Quality Score:** 91/100
**Production Ready:** Yes
**Error Handling:** Excellent - Validates choice data and model convergence
**Testing Status:** Comprehensive tests with known datasets

---

## Example Outputs

**Sample Attribute Importance:**

| Attribute | Importance | Interpretation |
|-----------|------------|----------------|
| Price | 38% | Most important factor in choice |
| Brand | 27% | Second most important |
| Delivery Speed | 20% | Moderate importance |
| Warranty | 15% | Least important |

**Sample Utilities (Individual):**

| Feature Level | Utility | Willingness-to-Pay |
|---------------|---------|-------------------|
| Premium Brand | +2.4 | $18.50 |
| Standard Brand | +0.3 | $2.30 |
| Budget Brand | -2.7 | Reference |
| Fast Delivery (1-day) | +1.8 | $13.85 |
| Standard Delivery (3-5 days) | -1.8 | Reference |

**Market Share Simulation:**

| Product | Brand | Price | Delivery | Predicted Share |
|---------|-------|-------|----------|----------------|
| Product A | Premium | $60 | Fast | 32% |
| Product B | Standard | $45 | Standard | 41% |
| Product C | Budget | $30 | Slow | 18% |
| None | - | - | - | 9% |

---

## Real-World Example

**Scenario:** Smartphone feature prioritization

**Question:** Which features should we include in the next model?

**Conjoint Study:**
- Attributes: Screen size, Camera quality, Battery life, Price
- Choice tasks: 12 sets of 3 options each
- Sample: 300 respondents

**Results:**
- Battery life is most important (35% importance)
- Customers will pay $120 for upgrade from 1-day to 2-day battery
- Premium camera adds 18% market share vs. standard camera
- Optimal configuration: Large screen + Premium camera + 2-day battery at $799

**Business Decision:** Prioritize battery R&D, premium camera is worth the cost

---

## What's Next (Future Enhancements)

**Coming Soon:**
- Automated optimal product finder
- Integration with pricing module
- Visual choice simulator interface

**Future Vision:**
- Real-time market share tracking dashboard
- API for integration with product management tools
- Machine learning hybrid models

---

## Bottom Line

Conjoint is your product optimization powerhouse. When you need to understand trade-offs and predict market response to different product configurations, conjoint analysis provides rigorous, individual-level insights. The hierarchical Bayes approach represents the gold standard in conjoint methodology.

**Think of it as:** A crystal ball that shows you how customers will respond to any product configuration you can imagine, backed by sophisticated statistical modeling of their actual choices.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*

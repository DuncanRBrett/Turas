# Pricing Research: Technique Guide

**Module:** Turas Pricing
**Audience:** Researchers, analysts, and clients commissioning pricing studies
**Last updated:** April 2026

---

## What pricing analysis does

Pricing analysis answers: "What should we charge?" It takes respondent-level data on price perceptions or purchase intent and produces price recommendations backed by demand curves, revenue optimisation, and confidence assessments.

The Turas Pricing module supports three complementary methodologies, each answering a different facet of the pricing question:

| Method | Primary question | Core output |
|--------|-----------------|-------------|
| **Van Westendorp PSM** | What price range do consumers consider acceptable? | Acceptable range (PMC-PME), optimal price (OPP), indifference price (IDP) |
| **Gabor-Granger** | At what price is revenue or profit maximised? | Demand curve, revenue curve, optimal price, price elasticity |
| **Monadic** | What is the unbiased demand function? | Logistic demand curve, revenue/profit optimisation, bootstrap CIs |

When two methods are run together ("both" mode), the module triangulates findings and produces a confidence-scored recommendation.

---

## When to use each method

### Van Westendorp Price Sensitivity Meter

**Use when** you need to understand the boundaries of price acceptability. VW answers: "Below what price do consumers doubt quality? Above what price do they refuse to pay?" It maps the psychology of price perception, not purchase behaviour.

**Best for:** New products with no reference price. Exploratory research. Understanding price perception across segments. Early-stage pricing where you need to know the playing field before optimising within it.

**Not for:** Finding a single optimal price (VW gives a range, not a point). Products with well-established market prices (respondents anchor to what they already pay). Precise demand forecasting.

**Sample size:** Minimum 100 respondents. VW is robust with relatively small samples because it uses all four responses per person. Below 50, the cumulative distributions are noisy and intersection points become unstable.

### Gabor-Granger

**Use when** you have a shortlist of candidate prices and want to know which maximises revenue or profit. GG constructs a demand curve by measuring purchase intent at each price point.

**Best for:** Existing products where the price range is known. Optimising price within a defined set of candidates. Quantifying price elasticity. Profit optimisation when unit cost is known.

**Not for:** Truly new categories where the plausible range is unknown (use VW first). Studies requiring unbiased between-subjects measurement (within-subject designs create anchoring). Products where showing multiple prices sequentially might distort responses.

**Sample size:** Minimum 30 respondents per price point tested. If you test 8 price points, you need at least 240 respondents. Fewer than 30 per point produces noisy demand estimates.

### Monadic price testing

**Use when** eliminating bias is paramount. Each respondent sees exactly one randomly-assigned price and reports purchase intent. The resulting logistic demand curve is unbiased by anchoring or order effects.

**Best for:** High-stakes pricing decisions requiring defensible methodology. Academic or regulatory contexts. Building a continuous (not step-function) demand curve. Producing confidence intervals around the optimal price.

**Not for:** Small samples (you need enough per cell). Tight budgets (total sample requirement is highest). Exploratory research where the price range is unknown.

**Sample size:** Minimum 30 respondents per price cell. With 6 price cells, that is 180 minimum. More cells give a smoother curve but require a proportionally larger sample. For reliable bootstrap CIs, aim for 50+ per cell.

### Combined (VW + Gabor-Granger)

**Use when** the budget allows and the decision is high-stakes. VW maps the acceptable range; GG optimises within it. The module triangulates findings across methods, scoring confidence based on agreement.

**Sample size:** Both methods' requirements apply. Plan for at least 200 respondents.

---

## Questionnaire design

Good pricing analysis starts long before the data reaches Turas. The single biggest threat to output quality is a badly designed questionnaire. These guidelines apply regardless of which method you use.

### General principles

1. **Introduce the product before asking about price.** Respondents need to know what they are evaluating. A concept description, image, or feature list should appear before any price questions. Without context, price responses are meaningless.

2. **Anchor to a realistic purchase scenario.** "Imagine you are shopping for X and you see this product on the shelf..." is better than "What would you pay for X?" The more concrete the scenario, the closer stated preferences will be to actual behaviour.

3. **Randomise where possible.** Price point order (GG), price cell assignment (monadic), and question block order should all be randomised to avoid systematic bias.

4. **Avoid price questions after satisfaction or brand equity batteries.** Respondents who just rated a brand highly will state higher willingness to pay. Pricing questions should come early in the survey or in a separate section with a context reset.

### Van Westendorp question design

VW requires exactly four open-ended price questions. The standard wording:

1. "At what price would you consider this product to be **so cheap** that you would doubt its quality?" (Too Cheap)
2. "At what price would you consider this product to be a **bargain** -- a great buy for the money?" (Cheap/Bargain)
3. "At what price would you start to think this product is **getting expensive** -- not out of the question, but you would need to think about it?" (Expensive)
4. "At what price would you consider this product to be **too expensive** to consider?" (Too Expensive)

**Question order matters.** The standard order is Too Cheap, Cheap, Expensive, Too Expensive. Some practitioners use Cheap, Too Cheap, Expensive, Too Expensive. The Turas module handles any order (mapping is via config), but be consistent within a study.

**Open-ended vs. bounded.** Open-ended numeric entry produces the richest data but allows wild values. Bounded sliders or dropdown ranges reduce noise but constrain the range. If using open-ended, plan to screen for outliers (Turas flags values >10x or <0.01x the median).

**Logical ordering violations.** A respondent who says "too cheap" > "too expensive" has misunderstood the questions or responded carelessly. Turas reports the violation rate. If it exceeds 10%, revisit the question wording. Rates of 5-8% are typical and acceptable.

**NMS extension.** If you also ask purchase probability at the "cheap" and "expensive" prices (e.g., "If this product were priced at [their cheap price], how likely would you be to buy? Definitely / Probably / Probably not / Definitely not"), the module can calculate Newton-Miller-Smith revenue-calibrated price points.

### Gabor-Granger question design

GG measures purchase intent at a series of discrete price points. Design decisions:

**Price point selection.** Choose 5-10 price points spanning the expected range. Space them to cover the likely demand curve: tighter spacing around the expected optimal, wider at the extremes. If unsure, use equal spacing.

**Presentation order.** Within a respondent, prices can be shown in ascending, descending, or random order. Ascending order is most common in practice but can create anchoring (early low prices make later prices feel expensive). Random order reduces anchoring but may confuse respondents. Descending order tends to suppress purchase intent at lower prices. Turas checks monotonicity and can smooth violations.

**Response format.** Binary ("Would you buy at this price? Yes/No") is cleanest. Scale responses ("How likely would you be to buy at this price?") provide more granularity but require top-box coding. Turas handles both via config.

**Wide vs. long data format.** In wide format, each price point gets its own column (e.g., `intent_29`, `intent_39`, `intent_49`). In long format, one column holds price and another holds intent. Turas accepts both.

### Monadic question design

In a monadic design, each respondent is randomly assigned to exactly one price cell.

**Cell assignment.** Use the survey platform's random assignment feature. Ensure balanced cells (equal probability of assignment to each price). Turas reports per-cell sample sizes and flags cells below the minimum threshold (default: 10).

**Number of cells.** More cells give a smoother demand curve but require a larger total sample. 4-6 cells is typical. Below 4, the logistic model is poorly identified. Above 10 is rarely needed unless the price range is very wide.

**Intent question.** A single binary question ("Would you buy this product at [assigned price]?") or a scale question ("How likely would you be to buy at [assigned price]?") followed by top-box coding.

**Do not reveal other prices.** The power of monadic design comes from between-subjects comparison. If respondents learn that other prices exist, the unbiasedness assumption breaks.

---

## Interpreting the output

### Van Westendorp price points

| Metric | Full name | What it means | How to use it |
|--------|-----------|---------------|---------------|
| **PMC** | Point of Marginal Cheapness | Below this price, more people think the product is "too cheap" than think it is a "bargain" | Price floor -- below this, you risk quality doubts |
| **OPP** | Optimal Price Point | Where "too cheap" and "too expensive" cumulative curves cross | The price of least resistance -- fewest people object in either direction |
| **IDP** | Indifference Price Point | Where "cheap/bargain" and "expensive" cumulative curves cross | The market's "normal" price -- equal numbers see it as cheap vs. expensive |
| **PME** | Point of Marginal Expensiveness | Above this price, more people think "too expensive" than think it is merely "expensive" | Price ceiling -- above this, you lose too many buyers |

**The acceptable range** is PMC to PME. This is the playing field. **The optimal zone** is OPP to IDP. A good price sits inside this zone.

**What if OPP > IDP?** This can happen when price curves cross in an unusual pattern. It means there is no "sweet spot" where resistance is minimised in both directions. This is a signal that respondents have inconsistent price perceptions -- review the data quality.

**NMS results.** If purchase probability data is available, the NMS extension produces a revenue-calibrated optimal price. This is more actionable than the base VW metrics because it accounts for purchase likelihood, not just price perception.

### Gabor-Granger demand and revenue curves

**The demand curve** shows the percentage of respondents who would buy at each price point. It should generally decrease with price (monotonically). If it does not, Turas applies smoothing (isotonic regression or cummax) to enforce monotonicity.

**The revenue curve** is `price x purchase_intent` at each point. The revenue-maximising price is the peak. Note: this is a revenue *index*, not an absolute revenue forecast. To forecast revenue, multiply by market size.

**The profit curve** (when unit cost is provided) is `(price - cost) x purchase_intent`. The profit-maximising price is often higher than the revenue-maximising price because higher margins compensate for some lost volume.

**Price elasticity** between adjacent price points tells you how sensitive demand is. Elasticity > 1 (elastic) means a price increase loses more in volume than it gains in margin. Elasticity < 1 (inelastic) means you can raise prices with limited volume impact.

### Monadic model output

**The logistic demand curve** is a smooth, continuous function fitted by logistic regression. Unlike GG's step function, it allows prediction at any price within the range. The shape is always sigmoidal (S-curve), which matches economic theory for most consumer goods.

**Pseudo R-squared** (McFadden's) measures how well price explains purchase intent variation. Values of 0.10-0.30 are typical and acceptable for individual-level binary data. A very low value (<0.05) suggests price has weak influence on stated purchase intent -- the product may be priced within an indifference zone.

**Price coefficient p-value.** If p > 0.05, the price effect is not statistically significant. This does not mean price does not matter -- it means your sample or price range may not be large enough to detect the effect.

**Bootstrap confidence intervals** around the optimal price quantify uncertainty. A narrow CI (e.g., optimal price $39 [36, 42]) gives high confidence. A wide CI (e.g., $39 [28, 55]) means the optimal price is poorly determined -- consider a larger sample or tighter price range.

### Recommendation synthesis

When multiple methods are available, Turas triangulates findings and produces a single recommendation with a confidence score. The confidence score reflects:

- **Method agreement.** Do VW, GG, and/or monadic point to similar prices?
- **Sample quality.** Large samples with low violation rates increase confidence.
- **Range consistency.** Does the recommendation fall within the VW acceptable range?

A confidence score above 80% means the evidence is consistent and the recommendation is actionable. Below 60% means the methods disagree or the data quality is marginal -- present the range rather than a point estimate.

---

## Common watchouts

### 1. Anchoring bias

Respondents who see a low price first (in GG or in a concept test before VW) will anchor to it and report lower willingness to pay. Randomise price order within GG. Do not show competitor prices before pricing questions.

### 2. Hypothetical bias

Stated purchase intent consistently overstates actual buying. A respondent who says "definitely would buy" at $39 might not when standing in the store. Calibrate expectations: GG purchase intent is directionally correct but not a literal forecast. Use monadic CIs rather than point estimates for decision-making.

### 3. The "both" trap

Running VW + GG in the same survey is powerful but doubles the pricing section length. If the survey is already 15+ minutes, respondent fatigue will degrade data quality. Consider whether one method suffices for your research question.

### 4. Narrow price ranges

If all GG price points are within 10% of each other, the demand curve will be nearly flat and the analysis cannot differentiate. Spread prices wide enough to capture the full demand curve -- at least a 2:1 ratio between highest and lowest price.

### 5. Sample size per segment

If you plan segmented analysis (comparing pricing across customer types), each segment needs its own minimum sample. A total of 300 respondents split across 6 segments gives only 50 per segment -- borderline for VW, insufficient for GG with 6+ price points.

### 6. Currency and rounding

Respondents think in round numbers. If your product category has conventional price points ($4.99, $9.99), do not test prices at $5.37. Use price points that reflect market conventions. The price ladder feature in Turas applies category-appropriate rounding.

### 7. Weighted analysis assumptions

When survey weights are applied, the module uses them in all calculations. For monadic analysis, weights enter the logistic regression as case weights (consistent coefficient estimates, bootstrap CIs compensate for variance). Check the stats pack for effective sample size -- heavy weighting can substantially reduce the effective N, widening confidence intervals.

---

## Where this module could go

### Competitive pricing analysis

Currently, Turas optimises price for a single product in isolation. A natural extension is modelling price in a competitive context -- how does changing our price affect share when competitors' prices are known? The competitive scenarios feature provides a basic framework; full competitive pricing simulation (similar to conjoint market simulation) would allow "what if" analysis across a competitive set.

### Conjoint-pricing integration

For products with multiple configurable features, pricing analysis alone is insufficient. Integrating with conjoint analysis would allow pricing to be evaluated in the context of feature trade-offs -- answering "What is the right price for this specific feature combination?" rather than "What is the right price for the product as a whole?"

### Dynamic pricing models

The current module assumes a static pricing decision. Extending to temporal models -- how does optimal price change over the product lifecycle, or in response to competitive moves? -- would serve clients in fast-moving categories.

### Willingness-to-pay distribution

The WTP distribution feature (currently available for VW data) could be extended to monadic data, producing a full distribution of individual-level price sensitivity. This enables fine-grained pricing strategies such as tiered pricing based on WTP percentiles.

### Price sensitivity by feature

Combining pricing data with feature ratings (from the same survey) could identify which product features justify premium pricing. This sits between pure pricing analysis and conjoint -- simpler to field, but narrower in scope.

---

## Relationship to existing documentation

This technique guide covers the "what and why" for researchers and clients. For detailed survey design instructions (question wording, data formats, platform-specific notes), see `docs/QUESTIONNAIRE_DESIGN_GUIDE.md`. For statistical methodology details and API reference, see `docs/AUTHORITATIVE_GUIDE.md` and `docs/TECHNICAL_REFERENCE.md`.

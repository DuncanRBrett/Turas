# Conjoint Analysis: Technique Guide

**Module:** Turas Conjoint
**Audience:** Researchers, analysts, and clients commissioning conjoint studies
**Last updated:** April 2026

---

## What conjoint analysis does

Conjoint analysis measures how people make trade-offs between product features. Rather than asking respondents to rate features in isolation (which inflates everything), it forces them to choose between realistic product configurations where improving one feature means giving up something on another.

The output is a set of part-worth utilities that quantify the contribution of each attribute level to overall preference, importance scores showing which attributes drive choice, and a market simulator that predicts share for any combination of product configurations.

The Turas Conjoint module supports three estimation methods:

| Method | When to use | Core output |
|--------|-------------|-------------|
| **MNL (Multinomial Logit)** | Standard projects, adequate sample, aggregate-level results | Population-level utilities, importance, model fit |
| **Hierarchical Bayes (HB)** | Individual-level utilities needed, heterogeneity matters | Per-respondent utilities, convergence diagnostics, RLH quality scores |
| **Latent Class** | Discrete segments suspected, heterogeneity with structure | Class-level utilities, class sizes, BIC-optimal K, membership probabilities |

---

## When to use it

Conjoint is appropriate when:

- You need to understand **how attributes trade off against each other** in a choice context
- The product or service can be described as a **combination of discrete attributes with defined levels** (e.g., brand, price, size, feature set)
- You want to **simulate market share** for hypothetical products that don't yet exist
- The research question is "which combination of features is most preferred?" rather than "how important is feature X in isolation?"

Conjoint is **not** appropriate when:

- Attributes cannot be varied independently (e.g., a phone's weight is constrained by its screen size)
- You have more than 6-7 attributes — respondent cognitive burden becomes excessive and utilities become noisy
- The decision is dominated by a single attribute (typically price) — simpler pricing methods are more efficient
- You need qualitative understanding of why respondents prefer certain features — conjoint quantifies preference but does not explain it

---

## Experimental design

The experimental design determines which product profiles respondents evaluate. A poor design produces unreliable utilities; a good design extracts maximum information from each choice task.

### Attributes and levels

**Number of attributes.** 4-6 is the practical sweet spot. Below 4, simpler methods (MaxDiff, rating scales) are often sufficient. Above 7, respondents cannot meaningfully process the trade-offs and utilities become noisy. If you have 10 potential attributes, prioritise the 5-6 most decision-relevant and use the others as contextual holdouts.

**Number of levels.** 3-5 levels per attribute is typical. Fewer than 3 levels means you can only estimate linear effects. More than 5 levels per attribute inflates the design size. Keep levels roughly balanced across attributes — a 2-level attribute paired with a 7-level attribute wastes design efficiency.

**Level selection.** Levels must be mutually exclusive within an attribute and collectively exhaustive of the relevant range. For price, cover the plausible market range including the extremes respondents might encounter. For categorical attributes, include all options the client might realistically offer. Avoid aspirational levels ("free," "instant delivery") that could dominate all other attributes.

### Prohibitions

Sometimes certain attribute-level combinations are impossible or implausible (e.g., "budget brand" at the premium price point). Prohibitions remove these combinations from the design. Use them sparingly — each prohibition reduces design efficiency. If you find yourself needing many prohibitions, reconsider whether the attributes are truly independent.

### Design efficiency

The module generates efficient designs using algorithmic methods that maximise the statistical information extracted per choice task. The key metrics are:

- **D-efficiency:** Measures overall statistical efficiency. Above 90% is good; above 95% is excellent. Below 80% suggests the design needs more tasks or fewer prohibitions.
- **Level balance:** Each level should appear approximately equally often across tasks. Large imbalances reduce the precision of estimates for under-represented levels.
- **Orthogonality:** Attribute levels should vary independently across tasks. Correlation between attributes in the design inflates standard errors.

### Number of tasks

8-12 tasks per respondent is standard for CBC. Fewer than 6 tasks produces unstable individual-level HB estimates. More than 15 tasks causes fatigue — response quality degrades and you get noise, not information. For MNL estimation (aggregate only), fewer tasks are acceptable because you pool across respondents.

### Number of concepts per task

3-4 concepts per task is standard. 2 concepts gives a simple A/B comparison but wastes information. 5+ concepts overwhelm respondents and increase task completion time without proportional benefit.

---

## Questionnaire design

### Task format

Each task presents a set of product profiles side by side, described by their attribute levels. The respondent selects their preferred option.

**Visual design matters.** Profiles should be presented in a consistent grid format with attributes in the same order across tasks. Use clear labels. If the product is visual (packaging, interface), include images alongside attribute descriptions. Avoid walls of text — format for scannability.

### The none option

Including a "none of these" option is strongly recommended for most CBC studies. Without it, the model forces respondents to choose even when no option is acceptable, inflating predicted share for mediocre products. The none option provides a more realistic demand estimate.

**When to include none:** Any study where the client needs realistic share predictions. Any study where respondents might genuinely decline all options in a real purchase context.

**When to omit none:** Early-stage exploratory studies where you only care about relative preference, not absolute demand. Studies with a forced-choice competitive context.

### Dual response

In dual response CBC, after selecting a preferred product, the respondent is asked whether they would actually purchase it (yes/no). This produces both relative preference (from the choice) and absolute demand (from the purchase confirmation). It is particularly useful when calibrating the market simulator to real-world purchase rates.

### Sample size for HB estimation

HB estimation requires more data per respondent (more tasks) but can work with smaller samples than MNL. Rules of thumb:

- **Minimum:** 150 respondents with 8+ tasks each. Below this, individual-level estimates are unreliable.
- **Recommended:** 300+ respondents with 10-12 tasks. This gives stable individual-level utilities and reliable convergence.
- **Large studies:** 500+ respondents. Convergence is typically fast and estimates are precise.

For MNL (aggregate only), the minimum is lower — 200 total observations (respondent x task) is sufficient for stable aggregate estimates. For latent class, plan for at least 200 respondents per class you expect to find.

---

## Interpreting the output

### Part-worth utilities

Utilities are zero-centred within each attribute. They measure the relative contribution of each level to overall preference. Key principles:

- **Within an attribute,** higher utility = more preferred. The level with utility 0 is the reference; positive values are preferred to the reference, negative values are less preferred.
- **Across attributes,** the range of utilities (max minus min within an attribute) reflects how much that attribute influences choice. Wider range = more influential.
- **Utilities are ratio-scale within an attribute** (a utility of 0.6 is twice as preferred over the reference as 0.3), but the absolute magnitude is meaningful only relative to other levels in the study.

### Importance scores

Importance is calculated as the range of utilities within an attribute divided by the sum of ranges across all attributes, expressed as a percentage. Importance scores sum to 100%.

An attribute with 40% importance drives nearly half of the choice decision. But importance does not mean the attribute is the most valued — it means the difference between the best and worst levels of that attribute has the largest impact on choice. An attribute where all levels are equally good would have 0% importance regardless of how much respondents value it.

### Model fit

- **McFadden R-squared:** 0.2-0.4 is considered good for choice models. Above 0.4 is excellent. Below 0.1 suggests the model explains little beyond chance.
- **Hit rate:** Percentage of correctly predicted choices. Random chance is 1/K (33% for 3 alternatives). Hit rates above 60% indicate the model captures meaningful preference structure.
- **Log-likelihood, AIC, BIC:** Used for model comparison. Lower AIC/BIC is better. These are most useful when comparing MNL vs HB or choosing the optimal K for latent class.

### Market simulation

The simulator predicts share for hypothetical product configurations using the MNL choice rule: the probability of choosing product i equals exp(U_i) / sum(exp(U_j)) across all products in the competitive set.

**Share of preference** (default) allocates the entire market across the defined products. It answers: "Of those who would buy one of these products, what proportion chooses each?" This is the standard for relative competitive analysis.

**First choice** assigns 100% to the highest-utility product. It approximates a winner-take-all market and overestimates the leader's share. Use for screening, not for share prediction.

### Sensitivity analysis

One-way sensitivity varies a single attribute across all its levels while holding other attributes constant. The output shows how share changes as you move from one level to another. This reveals which attribute-level changes produce the largest share swings and identifies the "threshold" levels where share drops sharply.

---

## Watchouts

### Dominant attributes

If one attribute (typically price or brand) dominates the choice process, its importance score will be very high (60%+) and the remaining attributes will appear unimportant even if respondents care about them. This is not a flaw in the methodology — it reflects genuine decision-making. But it limits what you can learn about the secondary attributes. Consider whether a separate MaxDiff exercise on non-price features would be more informative.

### Unrealistic combinations

If respondents see product configurations that could never exist in the real market (the cheapest product with the premium brand name), they may respond to the implausibility rather than to genuine preference. Use prohibitions to remove impossible combinations, and validate the design by reviewing every task for face validity.

### Lexicographic respondents

Some respondents adopt a simplifying rule: always pick the cheapest option, or always pick a specific brand. Their choices contain no trade-off information. HB estimation handles this gracefully (their individual utilities will show extreme values on one attribute and near-zero on others). RLH scores help identify these respondents — they often have high RLH (because their rule is consistent) but their utilities are not useful for market simulation.

### Number-of-levels effect

Attributes with more levels tend to appear more important, all else being equal, because the utility range is wider when there are more levels to span. This is an artefact, not a real preference difference. When comparing importance across attributes, be aware that a 5-level attribute may appear more important than a 3-level attribute partly due to this effect. Report the raw importance scores but caveat comparisons across attributes with different numbers of levels.

### HB convergence

The module reports Geweke Z-tests and effective sample size (ESS) for MCMC convergence. Both must pass for reliable individual-level utilities:

- **ESS > 400:** Sufficient for reliable posterior estimation. ESS between 100-400 produces a warning — estimates may be acceptable but lack precision. ESS below 100 is critical — results should not be trusted.
- **Geweke |z| < 1.96:** The chain has reached stationarity. Failure indicates the burn-in period was insufficient.

If convergence fails, increase iterations (double the default is a good starting point) and increase burn-in. If convergence still fails, the model may be overparameterised for the sample size.

---

## Where this module could go

### Adaptive CBC (ACBC)

ACBC pre-screens levels and adapts the design during the interview, reducing respondent burden and improving precision. It requires real-time design generation during the survey, which would integrate with the Alchemer import pipeline.

### Menu-based conjoint

For products with a build-your-own structure (insurance packages, meal configurations), menu-based conjoint lets respondents construct their ideal product rather than evaluating pre-defined profiles. This requires a different experimental design and estimation framework.

### Willingness to pay (WTP)

The module currently supports WTP estimation from conjoint utilities. Future development could include WTP confidence intervals via parametric bootstrap and WTP-based market simulation that directly prices product improvements.

### Interaction effects

Two-way interactions between attributes (e.g., brand-price interaction where premium brands are less price-sensitive) are estimable with sufficient sample size. The module supports interaction specification but the interface could be enhanced to automatically detect and recommend significant interactions.

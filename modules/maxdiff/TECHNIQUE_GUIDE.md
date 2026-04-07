# MaxDiff Analysis: Technique Guide

**Module:** Turas MaxDiff
**Audience:** Researchers, analysts, and clients commissioning MaxDiff studies
**Last updated:** April 2026

---

## What MaxDiff does

MaxDiff (Maximum Difference Scaling, also called best-worst scaling) measures the relative importance or preference of a set of items. Respondents see subsets of items and select the best and worst in each set. The resulting data produces a ratio-scale preference ranking that is more discriminating and less prone to scale-use bias than rating scales.

The output is a set of preference scores for each item (on a probability or utility scale), item rankings, and optionally individual-level utilities via Hierarchical Bayes estimation. The module also supports TURF (Total Unduplicated Reach and Frequency) analysis for portfolio optimisation.

---

## When MaxDiff beats rating scales

Rating scales ask respondents to evaluate each item independently. The result is typically a compressed distribution where most items score 7 or 8 out of 10 and the ranking is unreliable. MaxDiff forces discrimination by requiring a best and worst choice within each set.

**Use MaxDiff when:**

- You have 8-30 items and need a reliable preference ranking
- All items are measured on the same dimension (importance, appeal, relevance, purchase interest)
- Discrimination between items is the primary objective — you need to know that Item A is preferred to Item B, not just that both score "high"
- Scale-use bias is a concern (cross-cultural studies, studies where some respondents top-box everything)
- You want individual-level preference data without asking each respondent about every item

**Use rating scales instead when:**

- You have fewer than 6 items — the MaxDiff design becomes trivially small
- You need absolute measurement (how satisfied are you?) rather than relative ranking
- Items span different dimensions that are not comparable
- You need to track scores over time against a fixed benchmark

---

## Item selection

### Number of items

The practical range is 8-30 items. Below 8, the number of possible subsets is small and the design lacks the variation needed for reliable estimation. Above 30, respondents see each item relatively few times (unless you add more tasks), and the cognitive burden of processing large sets increases.

The sweet spot is 12-20 items. This allows a balanced design with 10-12 tasks per respondent while ensuring each item appears enough times for stable estimates.

### Item wording

Every item in a MaxDiff study competes directly against every other item. Wording consistency is critical:

1. **Keep items parallel in structure.** If one item says "Fast delivery" and another says "The ability to track my order in real time," the longer, more specific item will tend to be chosen as best simply because it feels more substantial. Use consistent length and specificity.

2. **Match the dimension.** All items must be evaluable on the same scale. "Importance of fast delivery" and "Satisfaction with customer service" are different dimensions and cannot be validly compared in the same exercise.

3. **Avoid double-barrelled items.** "Free delivery and easy returns" conflates two features. A respondent who values one but not the other cannot answer coherently.

4. **Test for comprehension.** If any item requires specialist knowledge, non-expert respondents will avoid selecting it as best (uncertainty suppresses choice) regardless of their true preference.

### Item groups

When items fall into natural categories (functional features, emotional benefits, service attributes), the module supports item groups for reporting. Groups do not affect estimation but are useful for aggregating results and organising the output.

---

## Questionnaire design

### Best-worst format

Each task presents a set of items (typically 4-5) and asks the respondent to select the best (most important/most preferred) and the worst (least important/least preferred). This is the standard format and the one the module assumes.

### Set size

4-5 items per set is standard. With fewer than 4, each task provides little information (only one comparison per best-worst pair). With more than 5, the cognitive burden increases and respondents may use simplifying rules (always picking the same item as worst) rather than genuine evaluation.

For studies with many items (25+), a set size of 5 helps ensure adequate item exposure with a reasonable number of tasks. For studies with fewer items (8-12), a set size of 4 is sufficient.

### Number of tasks

The number of tasks should ensure each item appears approximately the same number of times. A good rule: each item should appear in at least 3 tasks. The formula is:

**Tasks = (Items x Appearances) / Set_Size**

For 15 items, 4 per set, 3 appearances each: 15 x 3 / 4 = ~12 tasks. This is a comfortable respondent load.

The module generates balanced designs that optimise item exposure. Check the design balance diagnostic — if any item appears more than 3x as often as another, the design is unbalanced and estimates for under-represented items will be less precise.

### Design balance

A balanced design ensures each item appears approximately equally often across all tasks. The module validates balance during design generation and warns if the appearance ratio exceeds 3:1. If balance is poor, increase the number of tasks or reduce the number of items.

### Anchored vs unanchored MaxDiff

**Unanchored** (standard): Produces a relative ranking. You can say Item A is preferred to Item B, and by how much, but not whether respondents actually like either one. This is the default and the most common approach.

**Anchored:** After the MaxDiff exercise, respondents classify each item as acceptable/unacceptable (or some similar threshold question). This anchors the scale and allows you to identify items that are not just relatively best but genuinely valued. The module supports anchored analysis when anchor data is provided.

---

## Sample size for HB estimation

HB estimation produces individual-level utilities, enabling segment analysis and individual-level simulation. It requires more data than aggregate estimation but is robust with moderate samples.

- **Minimum:** 100 respondents with 10+ tasks. Below this, individual-level estimates are unstable and the posterior means will be heavily shrunk toward the population mean.
- **Recommended:** 200-300 respondents with 10-12 tasks. This gives reliable individual-level utilities and stable convergence.
- **Large studies:** 500+ respondents. Convergence is fast and per-respondent estimates are precise.

For aggregate logit (no individual-level estimates), the minimum is lower: 150 total observations (respondent x task) is sufficient for stable population-level estimates.

---

## Interpreting the output

### Preference scores

The module produces several types of scores:

- **Count scores (Best-Worst):** Simple count of times each item was selected as best minus worst, divided by times shown. Requires no model fitting. Fast and transparent but does not account for which items appeared together (a "best" against strong competitors is worth more than a "best" against weak ones).

- **Logit utilities:** Model-based estimates from aggregate conditional logit. Accounts for the competitive context of each task. The reference item (anchor) is set to zero; all other utilities are relative to it.

- **HB utilities:** Individual-level posterior means from Hierarchical Bayes estimation. These are the most informative scores — they capture both population-level patterns and individual heterogeneity. The population mean HB utilities approximate the aggregate logit utilities.

- **Rescaled scores:** Utilities transformed to a 0-100 probability scale using the multinomial logit transformation: P(i) = exp(U_i) / sum(exp(U_j)). These sum to 100% across all items and are the most intuitive for client presentations. "Item A has a 15% share of preference" is easier to interpret than "Item A has a utility of 1.23."

### Item rankings

Rankings are derived from rescaled scores. The item with the highest score is ranked #1. Ties are broken by raw utility, then by count scores.

### TURF analysis

TURF (Total Unduplicated Reach and Frequency) answers: "If I can only offer K items, which K items should I choose to appeal to the widest audience?" It uses individual-level utilities to classify each respondent's "appealing" items and then uses greedy forward selection to build the portfolio that maximises unduplicated reach.

**Reach** is the percentage of respondents for whom at least one item in the portfolio is appealing. **Frequency** is the average number of appealing items per respondent.

The appeal classification method matters:

| Method | Logic | Best for |
|--------|-------|----------|
| **ABOVE_MEAN** | Item is appealing if its utility is above the respondent's mean | Balanced classification, common default |
| **TOP_K** | Item is appealing if it's in the respondent's top K | When you have a clear idea of how many items each person would consider |
| **ABOVE_ZERO** | Item is appealing if its utility is positive (for zero-anchored scales) | Anchored MaxDiff where zero has a meaningful threshold |

The incremental reach table shows which item to add at each step and the marginal gain in reach. The first few items typically produce large gains; later additions show diminishing returns. The "elbow" in the reach curve is often a natural portfolio size.

### Portfolio optimisation

TURF is a greedy algorithm — it finds a good portfolio but not necessarily the globally optimal one. For small item sets (<15), greedy is very close to optimal. For large sets, the greedy solution is a strong approximation. The module does not guarantee global optimality, but in practice the greedy TURF portfolio is the one you would deploy.

---

## Watchouts

### Item wording effects

Because MaxDiff forces direct comparison, item wording has an outsized effect on results. An item that is worded more concretely or more positively than its competitors will be systematically overselected. Review all items for wording balance before fielding.

### Context effects

The items that appear together in a task affect choice. A moderately appealing item looks better when surrounded by weak items than when surrounded by strong ones. The logit and HB models account for this (they model the competitive context of each task), but count scores do not. For this reason, prefer model-based scores over raw counts for final reporting.

### Acquiescence and position bias

Unlike rating scales, MaxDiff is largely immune to acquiescence bias (the tendency to agree with everything). However, position bias can occur if respondents systematically select items at the top or bottom of the list. The module's balanced design randomises item positions across tasks, mitigating this effect.

### Interpreting rescaled scores

Probability-scale scores sum to 100% and look like "market share," but they are not market share in the traditional sense. They represent share of preference in a hypothetical scenario where a respondent must choose exactly one item from the full set. They are useful for relative comparison and ranking but should not be interpreted as purchase probabilities.

### HB convergence

The module uses Stan for HB estimation, which provides rigorous convergence diagnostics:

- **R-hat < 1.01:** Chains are well-mixed. R-hat between 1.01-1.05 is acceptable with caution. R-hat > 1.10 means chains have not converged — do not trust the results.
- **ESS > 400:** Sufficient effective samples for reliable posterior estimation. ESS between 100-400 produces a warning. ESS < 100 is critical.
- **Zero divergences:** Divergent transitions indicate problems with the posterior geometry. Any divergences should be investigated.
- **Quality score > 70/100:** The module produces a composite quality score summarising all diagnostics.

If convergence fails, the module falls back to approximate HB (empirical Bayes shrinkage). This produces reasonable population-level estimates but individual-level utilities are less precise than full HB.

---

## Where this module could go

### Sparse MaxDiff

In sparse MaxDiff, each respondent evaluates only a subset of all items. This is useful when the total item list is very large (50+) but each respondent needs to see only 20-25. It requires a connected design across respondents so that all items are linked through overlapping tasks.

### Dual-response MaxDiff

Combines the standard best-worst task with an acceptability follow-up (similar to anchored MaxDiff but at the task level). After selecting best and worst, the respondent rates whether each remaining item is acceptable or not. This provides more information per task and can improve individual-level estimates.

### Segment-level analysis

The module currently supports segment comparison using a pre-defined segment variable. Future development could include latent class MaxDiff, which simultaneously estimates item utilities and discovers respondent segments that differ in their preferences — analogous to latent class conjoint.

### MaxDiff with pricing

Combining MaxDiff preference scores with pricing data (willingness-to-pay per item) enables value-based portfolio optimisation: choose the K items that maximise reach subject to a total cost constraint.

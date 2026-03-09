# Turas Confidence Report — Sampling Callout Redesign Specification

## Overview

The confidence report's "About your sample" callout currently presents three generic scenarios (random, structured quota/panel, self-selected) and asks the reader to self-select. This is being replaced with a single auto-populated callout driven by a meta tag, plus a relabelling system for non-probability designs.

This spec covers:
1. New meta tag values for `turas-sampling-method`
2. Eight callout texts, one per sampling method
3. Relabelling logic for column headers and badges depending on sampling method
4. Cluster sample warning requirements

---

## 1. Meta Tag

```html
<meta name="turas-sampling-method" content="stratified">
```

**Valid values:** `random`, `stratified`, `cluster`, `census`, `panel`, `quota`, `convenience`, `not_specified`

The existing `turas-substitution` meta tag is **not needed** — non-response / substitution language is handled within each callout.

---

## 2. Callout Texts

Each callout replaces the current "About your sample" block (the element with class `ci-callout-sampling`). The callout should still use the `ci-callout-sampling` class for styling.

### `random`

> Every person in the target population had an equal chance of being selected. This is the gold standard for survey sampling, and the confidence intervals can be taken at face value. The remaining uncertainty is practical rather than statistical: people who chose not to respond may hold different views from those who did, and the way questions are worded always influences answers to some degree.

### `stratified`

> The population was divided into groups (e.g. by channel, region, or segment) and people were sampled randomly within each group. This ensures reliable results for each group, even smaller ones, but may mean some groups are deliberately oversampled relative to their true size. Within each group, the confidence intervals are trustworthy. At total level, they are conservative — if anything, slightly wider than necessary. As with any survey, people who declined to take part may differ from those who did.

### `cluster`

> The population was divided into natural groupings (e.g. branches, stores, or teams) and a selection of these groupings was sampled rather than individuals directly. This is practical and cost-effective but means that people within the same cluster tend to give similar responses, which reduces the effective sample size. The confidence intervals reported here do not adjust for this clustering effect and may therefore be narrower than they should be. Results should be treated as indicative, and differences near the margin of error interpreted with caution.

### `census`

> Everyone in the target population was invited to participate. There is no sampling error in the traditional sense — the uncertainty comes entirely from who chose to respond. If most people responded, the results closely represent the whole population. If response rates are low, the responding group may not be representative, and the confidence intervals understate the true uncertainty. The response rate is the single most important quality indicator for this type of study.

### `panel`

> Respondents were drawn from a pre-recruited research panel, usually with quotas to match the target population on key characteristics. The confidence intervals measure how stable the results are within this sample, but panel members are volunteers who have opted in to research — they are not a random cross-section of the population. These intervals are reliable for tracking changes over time and comparing subgroups, but should be read as a measure of precision rather than a guaranteed margin of error.

### `quota`

> Respondents were recruited to match the target population on selected characteristics such as age, gender, or region. Within these quotas, selection was not random — interviewers or recruiters chose who to approach. The confidence intervals describe the variability in the achieved sample and are useful for comparing groups and detecting shifts between waves. They should not be read as exact margins of error, because the non-random selection within quotas introduces uncertainty that the intervals cannot measure.

### `convenience`

> Respondents chose to take part — there was no structured selection from a defined population. The confidence intervals describe the range of results you would expect if you repeated the exercise with a similar group of volunteers, but they do not tell you how close the results are to what the broader population thinks. These results are useful for identifying patterns and priorities within the responding group. They are not generalisable without additional evidence that the respondents are representative.

### `not_specified`

> The sampling method for this study was not recorded. The confidence intervals describe the variability in the observed data and provide a useful indication of estimate precision. However, their interpretation depends on how the sample was drawn. If the sample is broadly representative of the target population, the intervals are a reasonable guide to the margin of error. If representativeness is uncertain, treat them as a measure of internal consistency rather than definitive bounds.

---

## 3. Relabelling Logic

The sampling method determines whether classical statistical language is used or whether labels are softened to reflect what the intervals actually measure for non-probability designs.

### Probability-based designs: `random`, `stratified`, `census`

Use standard labels:
- **Column headers / badge text:** "Confidence Interval", "CI Lower", "CI Upper", "CI Width"
- **Table columns:** "MOE" or "Margin of Error", "Half-Width"
- **Summary text:** "margin of error", "confidence interval"

### Non-probability designs: `panel`, `quota`, `convenience`, `not_specified`

Use softened labels:
- **Column headers / badge text:** "Stability Interval", "SI Lower", "SI Upper", "SI Width"
- **Table columns:** "Precision Estimate" instead of "MOE" / "Margin of Error"
- **Summary text:** "precision range" instead of "margin of error", "stability interval" instead of "confidence interval"

### Cluster samples: `cluster`

Use standard labels (it is a probability design) **but** append a warning. See section 4.

### Where relabelling applies

All instances in the report where these terms appear, including:
- Summary table headers
- Detail table headers
- Forest plot labels (if any text labels reference CI/MOE)
- Header badges (e.g. "95% Confidence" could become "95% Stability Interval" for non-probability designs)
- Callout text within the result summaries
- The report title/subtitle if it references "Confidence Analysis" — for non-probability designs, consider "Precision Analysis"

**The method names in the Method Notes tab stay unchanged.** The t-distribution is still called a confidence interval in the method documentation because that's describing the statistical method generically. The relabelling applies to the presentation of results, not the method reference documentation.

---

## 4. Cluster Sample Handling

Cluster samples are the one design where the reported intervals are likely to be **too narrow** (anti-conservative), because standard methods assume independent observations and clustered data violates this.

### Minimum requirement (implement now)

Add a prominent warning callout (use `ci-callout-warning` styling) in the detail view for each question when `turas-sampling-method` is `cluster`:

> **Clustering not adjusted.** These intervals assume independent observations. In a cluster sample, respondents within the same cluster (e.g. branch, store, or team) tend to respond similarly, which means the true uncertainty is larger than shown. Differences near the margin of error should be interpreted with particular caution.

### Future enhancement (not required now)

Accept an optional design effect parameter (e.g. `turas-design-effect` with a numeric value like `1.5`) and multiply standard errors by the square root of this value. This would produce correctly widened intervals for cluster samples. This is a future feature, not part of the current implementation.

---

## 5. Implementation Notes

### What changes in the R code generating the HTML

- The `turas-sampling-method` meta tag value needs to be passed through as a parameter when generating the confidence report (e.g. as an argument to the R function).
- The callout text block (currently the `ci-callout-sampling` div) is selected based on the meta tag value.
- Column headers and labels throughout the HTML are conditionally set based on whether the design is probability-based or not (see section 3).
- The cluster warning (section 4) is conditionally inserted.

### What stays the same

- All statistical calculations remain identical. The methods (t-distribution, bootstrap, Bayesian) are valid regardless of design — only the labels and interpretive framing change.
- The method documentation in the Method Notes tab is unchanged.
- The "Understanding Limitations" section (precision vs accuracy, sources of error, multiple comparisons) is unchanged — it already handles these themes generically.
- The forest plots, comparison charts, and all visualisations stay the same.

### Backward compatibility

- If `turas-sampling-method` is absent or empty, treat as `not_specified`.
- Existing reports without the tag will render with the `not_specified` callout and standard labels, which is a safe default.

---

## 6. Summary of Meta Tag Options

| Value | Design Type | Probability? | Label Style | Special Handling |
|-------|------------|-------------|-------------|-----------------|
| `random` | Simple random sample | Yes | Standard (CI/MOE) | None |
| `stratified` | Stratified random sample | Yes | Standard (CI/MOE) | None |
| `cluster` | Cluster sample | Yes | Standard (CI/MOE) | Warning about clustering |
| `census` | Full-base invite | Yes* | Standard (CI/MOE) | None |
| `panel` | Online research panel | No | Softened (SI/Precision) | None |
| `quota` | Quota sample | No | Softened (SI/Precision) | None |
| `convenience` | Self-selected / opt-in | No | Softened (SI/Precision) | None |
| `not_specified` | Unknown | Unknown | Standard (CI/MOE) | None |

*Census is technically not a sample at all, but CI language is conventional and understood.

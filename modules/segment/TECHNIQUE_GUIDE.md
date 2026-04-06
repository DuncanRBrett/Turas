---
editor_options: 
  markdown: 
    wrap: 72
---

# Segmentation Analysis: Technique Guide

**Module:** Turas Segment **Audience:** Researchers, analysts, and
clients commissioning segmentation studies **Last updated:** April 2026

------------------------------------------------------------------------

## What segmentation does

Segmentation divides a group of respondents into subgroups (segments)
that are internally similar and externally distinct. The goal is to find
natural groupings in the data that correspond to meaningfully different
attitudes, behaviours, or needs.

The output is a set of segment assignments (each respondent belongs to
one segment), a profile of each segment showing how it differs from the
others, and validation metrics that tell you whether the segments are
real or noise.

------------------------------------------------------------------------

## When to use it

Segmentation is appropriate when:

-   You have **multiple continuous variables** (typically attitude or
    behaviour ratings) measured across all respondents
-   You want to **identify distinct groups** rather than describe a
    single population
-   The sample is large enough: at minimum 50 respondents per expected
    segment, with an absolute floor of 100 total
-   You will **act on the segments** — segmentation that does not change
    strategy is wasted analysis

Segmentation is **not** appropriate when:

-   You already have a classification variable (demographics, purchase
    history) — use cross-tabulation instead
-   You want to predict an outcome — use KeyDriver or CatDriver
-   The variables are categorical rather than continuous — consider
    latent class analysis
-   Your sample is too small (under 100 respondents) — the solution will
    be unstable
-   You need a quick answer — segmentation requires careful variable
    selection, method choice, and validation

------------------------------------------------------------------------

## Questionnaire design

Good segmentation starts with good data. The variables you cluster on
determine the segments you find. Every decision at the questionnaire
stage has downstream consequences.

### What makes a good segmentation variable

The ideal clustering variable is a **continuous or quasi-continuous
rating** that measures a genuine attitude, need, or behaviour pattern.
Common choices:

-   **Attitudinal statements** ("To what extent do you agree that...")
    on a 5-point, 7-point, or 10-point scale
-   **Importance ratings** ("How important is X when choosing a
    provider?")
-   **Frequency behaviours** ("How often do you...") on a numerical
    scale
-   **Satisfaction ratings** across multiple touchpoints

The key properties are:

1.  **Variance.** If everyone gives the same answer, the variable cannot
    differentiate segments. Avoid questions where 90%+ of respondents
    pick one option.
2.  **Relevance.** The variable should relate to the research question.
    If you are segmenting insurance customers, include attitudes about
    risk and value, not about food preferences.
3.  **Independence.** Each variable should measure something different.
    If three questions all measure "price sensitivity" in slightly
    different words, they will dominate the solution and create
    "price-sensitive" vs "not price-sensitive" segments at the expense
    of other dimensions.
4.  **Common measurement.** All variables should use the same or similar
    scales. Mixing a 5-point agreement scale with a 0-10 likelihood
    scale introduces artifactual variance differences.

### How many variables

**8-20 variables** is the practical sweet spot.

-   **Fewer than 5** produces trivial two-way splits. There is not
    enough information for meaningful segmentation.
-   **More than 25** introduces noise. Many variables will be redundant,
    and the distance calculations become unreliable in high dimensions
    (the "curse of dimensionality").
-   **Between 8 and 20** gives the algorithm enough information to find
    genuine patterns without drowning in noise.

If you have 40 candidate variables, use the module's built-in variable
selection (variance thresholds, correlation filtering) to reduce to a
working set, or run a factor analysis first and cluster on factor
scores.

### Battery design

A segmentation battery is a block of questions specifically designed for
clustering. Best practice:

-   **Single scale type** across the entire battery (e.g., all 7-point
    agreement). This makes standardisation straightforward and ensures
    equal weighting.
-   **Balanced content** — include items spanning different conceptual
    dimensions. If you have five items about price and two about
    service, price will dominate.
-   **No "Don't Know" option** if possible. DK creates missing data that
    must be imputed or deleted, reducing effective sample size. A
    midpoint anchor ("Neither agree nor disagree") is usually
    preferable.
-   **Randomise item order** to prevent order effects. If the first
    three items are all about quality, primacy effects can create
    artificial correlation.
-   **Pilot the battery** on 30-50 respondents. Check variance
    distributions — items with SD \< 0.5 (on a 7-point scale) are not
    differentiating.

### Handling "Don't Know" and missing data

Turas supports three strategies for missing data:

-   **Listwise deletion** (default) — respondents missing any clustering
    variable are dropped. Safe but wastes sample. Use when missingness
    is \< 5%.
-   **Mean imputation** — missing values replaced with the variable
    mean. Simple but biases segments toward the center. Use only when
    missingness is very low.
-   **KNN imputation** — missing values replaced based on similar
    respondents' values. Better preserves natural variation but requires
    adequate sample size.

If more than 15-20% of respondents have missing data on your clustering
variables, the problem is in the questionnaire, not the analysis.

------------------------------------------------------------------------

## Method selection

Turas implements three clustering algorithms. Each has trade-offs.

### K-means

**What it does:** Partitions respondents into k groups by minimising the
total within-cluster sum of squares. Each respondent belongs to the
cluster whose centre is closest.

**Strengths:** - Fast, scales well to large samples (10,000+) - Produces
compact, spherical clusters - Results are intuitive — segments are
defined by their centre (average profile) - Most widely used in market
research segmentation

**Limitations:** - Requires you to specify k in advance (or search over
a range) - Assumes clusters are roughly spherical and equal-sized —
struggles with elongated or very unequal groups - Sensitive to initial
random starting positions (mitigated by nstart parameter) - Sensitive to
outliers — extreme values pull cluster centres

**When to use:** K-means is the default choice for most market research
segmentation. Start here unless you have a specific reason not to.

### Hierarchical clustering

**What it does:** Builds a tree (dendrogram) of nested clusters by
progressively merging the most similar respondents or groups. You cut
the tree at a chosen level to get k segments.

**Strengths:** - No need to pre-specify k — the dendrogram shows the
natural merging structure - Can detect non-spherical cluster shapes
(depending on linkage method) - Deterministic — no random starting
positions, same data always gives same result - The dendrogram is a
powerful diagnostic tool for understanding cluster structure

**Limitations:** - Does not scale well — O(n\^2) memory for the distance
matrix. Impractical above \~15,000 respondents. - Once a respondent is
assigned, the decision is never revisited (no reassignment step) -
Sensitive to the choice of linkage method

**Linkage methods:** \| Method \| Behaviour \| Best for \|
\|--------\|-----------\|----------\| \| Ward's (ward.D2) \| Minimises
variance increase at each merge \| General-purpose — tends to produce
equal-sized spherical clusters \| \| Complete \| Uses maximum distance
between cluster members \| Finding compact clusters, sensitive to
outliers \| \| Average \| Uses mean distance between all pairs \|
Moderate compromise, less affected by outliers \| \| Single \| Uses
minimum distance \| Detecting elongated or chain-shaped clusters (rarely
useful in MR) \|

**When to use:** Hierarchical clustering is useful when you want to
explore the data's natural structure without committing to a specific k.
Often used as a first step — examine the dendrogram, identify a natural
number of clusters, then run k-means at that k for a more refined
solution.

### Gaussian Mixture Models (GMM)

**What it does:** Models each cluster as a multivariate Gaussian
distribution. Assigns respondents probabilistically — each respondent
has a probability of belonging to each cluster, not just a hard
assignment.

**Strengths:** - Produces soft (probabilistic) assignments — valuable
for identifying respondents who sit between segments - Can detect
elliptical cluster shapes (not just spherical) - BIC-based model
selection provides a principled way to choose k - Handles clusters of
different sizes and shapes

**Limitations:** - Requires larger samples — needs enough data to
estimate covariance matrices (roughly 10 observations per variable per
cluster) - Can produce degenerate solutions when clusters overlap
heavily or when data is near-collinear - Slower than k-means for large
samples - More complex output (probability matrices rather than simple
assignments)

**When to use:** GMM is appropriate when you suspect clusters differ in
shape or size, when you need probabilistic assignments (e.g., to measure
how "strong" each segment membership is), or when your theoretical
framework suggests overlapping groups.

### Decision framework

| Situation | Recommended method |
|---------------------------|---------------------------------------------|
| Standard market research segmentation, n \> 200 | K-means |
| Exploratory analysis, uncertain about k | Hierarchical (then k-means) |
| Need probabilistic segment membership | GMM |
| Very large sample (n \> 15,000) | K-means (hclust not feasible) |
| Clusters may be different shapes/sizes | GMM |
| Need deterministic, reproducible results | Hierarchical |
| First-time segmentation study | K-means with exploration mode |

------------------------------------------------------------------------

## Choosing k

The number of segments is the single most consequential decision in
segmentation. Too few and you miss important distinctions. Too many and
the segments become uninterpretable or too small to act on.

### Statistical criteria

Turas computes several metrics to guide k selection:

| Metric | What it measures | How to read it |
|-----------------|----------------------------|---------------------------|
| **Silhouette coefficient** | How well each respondent fits its assigned cluster vs the next-best cluster | Range: -1 to +1. Above 0.5 is strong, 0.25-0.5 is reasonable, below 0.25 is weak |
| **Calinski-Harabasz index** | Ratio of between-cluster to within-cluster variance | Higher is better. Look for local maxima across k values |
| **Davies-Bouldin index** | Average similarity of each cluster to its most similar cluster | Lower is better. Below 1.0 indicates good separation |
| **Elbow method** | Rate of decrease in within-cluster sum of squares as k increases | Look for the "elbow" — the point where adding another cluster gives diminishing returns |
| **Gap statistic** | Compares within-cluster dispersion to that expected under a null reference distribution | Largest gap indicates the k with the most structure beyond chance |

**No single metric is definitive.** The statistical criteria are guides,
not answers. A solution with a slightly lower silhouette but more
interpretable segments is usually better.

### Practical criteria

In market research, the statistical criteria must be balanced against:

1.  **Interpretability.** Can you describe each segment in one sentence?
    If a segment has no clear identity, it may be noise.
2.  **Actionability.** Can you do something different for each segment?
    If two segments would receive the same marketing strategy, merge
    them.
3.  **Size.** Each segment must be large enough to matter. A segment
    with 3% of the market is rarely actionable. Turas enforces a
    configurable minimum segment size (default 5%).
4.  **Stability.** The same segments should appear if you split the
    sample in half and run the analysis on each half. Turas includes a
    stability check that does exactly this.

### The practical approach

1.  **Run exploration mode** — test k from 2 to 8 (or whatever range
    makes sense for your data). Review the metrics.
2.  **Identify the statistical sweet spot** — usually where silhouette
    peaks or the elbow occurs (typically 3-5 for most MR datasets).
3.  **Examine 2-3 candidate solutions** — look at the profiles. Which k
    produces the most distinct, interpretable, actionable segments?
4.  **Choose the smallest k that meets your needs.** Parsimony matters.
    Three clear segments beat five muddy ones.
5.  **Run the stability check.** If segments are unstable, consider
    reducing k or reviewing variable selection.

------------------------------------------------------------------------

## Profiling and validation

Once segments are assigned, profiling tells you who is in each segment
and validation tells you whether the segments are real.

### Profiling

Profiling compares segments on every available variable — not just the
clustering variables but demographics, behaviours, media consumption,
brand usage, and any other variable in the dataset.

Turas runs: - **ANOVA and Kruskal-Wallis tests** for continuous and
ordinal variables, with effect size measures (eta-squared for ANOVA,
epsilon-squared for Kruskal-Wallis) - **Chi-square tests** for
categorical variables (demographics, brand usage), with a flag when
expected frequencies are low - **Cohen's d pairwise comparisons** for
every pair of segments on every variable - **Index scores** showing each
segment's mean relative to the total sample (100 = average)

The profiling output is the primary deliverable for most clients. It
answers: "How do the segments differ?"

**Important caveat:** Because the clustering variables were used to
define the segments, statistical tests on those variables are circular —
the segments are *defined* as being different on these variables. The
tests are descriptive (showing *how much* they differ), not inferential.
The most valuable profiling variables are ones that were **not** used in
clustering — if segments also differ on demographics or behaviours that
were not part of the clustering input, the segments have external
validity.

### Validation metrics

-   **Silhouette plot** — shows each respondent's fit to their cluster.
    A high average silhouette (\> 0.5) means clusters are
    well-separated. Negative silhouette values indicate misassigned
    respondents.
-   **Variance explained (BSS/TSS)** — proportion of total variance
    accounted for by the cluster structure. Higher is better, but above
    \~80% may indicate overfitting (too many clusters).
-   **Stability analysis** — splits the sample and compares segment
    recovery. If the same structure appears in both halves, the solution
    is robust.

### Discriminant analysis

Turas generates discriminant rules for each segment — decision
tree-based rules that describe which variable thresholds distinguish
segments. These are invaluable for: - **Typing tools** — classifying new
respondents into existing segments without re-running the full
analysis - **Stakeholder communication** — "Segment 3 is defined by high
price sensitivity (score \> 7) and low brand loyalty (score \< 4)" -
**Validation** — if the rules are complex and non-intuitive, the
segments may not be meaningful

------------------------------------------------------------------------

## Watchouts

### Garbage in, garbage out

Clustering will always find segments, even in random data. The algorithm
will partition any dataset into k groups — the question is whether those
groups are meaningful. If your input variables are noisy, irrelevant, or
redundant, the segments will be too.

**Prevention:** Invest in variable selection. Remove low-variance items,
reduce multicollinear sets, and ensure every variable earns its place.

### Unstable solutions

K-means is sensitive to initial starting positions. Two runs with
different random seeds can produce different segments. This is not a bug
— it reveals genuine ambiguity in the data.

**Prevention:** Use a high nstart value (25+). Run the stability check.
If segments shift substantially across runs, the solution at that k is
unreliable — try a different k or review variable selection.

### Segment size imbalances

If one segment contains 60% of the sample and the others split the
remainder, the dominant segment is likely the "average" group and the
analysis has found outliers rather than genuine segments.

**Prevention:** Turas enforces a minimum segment size (default 5%).
Review the segment sizes in the stats pack. If one segment dominates,
consider whether k should be lower or whether the dominant segment
should be examined for sub-structure.

### Outlier sensitivity

K-means is particularly sensitive to outliers because cluster centres
are means, and means are pulled by extreme values. A handful of extreme
respondents can distort the entire solution.

**Prevention:** Enable outlier detection in the config (Mahalanobis
distance is the default). Review the outlier exclusion count in the
stats pack. If many respondents are flagged, investigate whether the
outlier threshold is too aggressive or whether there is a genuine data
quality issue.

### The curse of dimensionality

As the number of variables grows, Euclidean distance becomes less
discriminating — all points become roughly equidistant. Above 20-25
variables, clustering performance degrades.

**Prevention:** Use variable selection to reduce to a meaningful subset.
Consider factor analysis to compress correlated variables into
orthogonal scores.

### Over-fitting (too many segments)

With enough segments, within-cluster variance drops to near zero — but
the segments become uninterpretable and sample sizes per segment become
too small for reliable profiling.

**Prevention:** Use parsimony as a guiding principle. The elbow method
and silhouette scores help identify the point of diminishing returns.
Always ask: "Can I describe each segment? Can I act on each segment?"

------------------------------------------------------------------------

## Where this module could go

### Latent class analysis

LCA is a model-based alternative to k-means for categorical data. Where
k-means clusters on distances between continuous variables, LCA
estimates the probability of response patterns given class membership.
Turas has an experimental LCA implementation (config: `use_lca = TRUE`).

LCA is particularly useful when the input variables are genuinely
categorical (yes/no behaviours, multi-choice brand lists) rather than
continuous ratings.

### Ensemble approaches

Turas includes an ensemble mode that combines multiple clustering
methods (k-means, hierarchical, GMM) and computes consensus assignments.
This is more robust than any single method because it averages out each
method's biases.

Ensemble segmentation is worth using when the single-method solutions
disagree — if k-means and hierarchical produce similar segments,
ensemble adds computation without much benefit.

### Weighted clustering

The current module does not support survey weights in the clustering
step. This is defensible — weighted k-means is non-standard and the
statistical properties are less well understood — but it means profiling
tests use unweighted statistics even when the survey employed complex
sampling.

A future enhancement could apply weights at the profiling stage
(weighted ANOVA, weighted chi-square) while keeping the clustering
itself unweighted.

### Longitudinal segmentation

Tracking segment membership over time — do segments shift? Do
individuals move between segments? — is a natural extension for tracking
studies. This would integrate with the Tracker module to show
segment-level trends.

### Automated segment naming

Turas supports automatic segment naming based on profile patterns.
Future work could use the AI insights pipeline to generate descriptive
segment names and one-paragraph persona descriptions from the profiling
data.

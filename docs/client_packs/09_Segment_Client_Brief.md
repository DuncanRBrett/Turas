---
editor_options: 
  markdown: 
    wrap: 72
---

# Segment: Customer Segmentation & Clustering

**What This Module Does**

Segment discovers natural groups within your customer base using
statistical clustering algorithms. It identifies customers with similar
needs, behaviors, or attitudes and creates actionable segments for
targeting, strategy development, and resource allocation.

------------------------------------------------------------------------

## The Fundamental Problem: Not All Customers Are the Same

**This is THE core challenge in market strategy.**

When you treat all customers identically, you: - Waste resources on
customers unlikely to respond - Miss opportunities with high-value
subgroups - Use generic messaging that resonates with nobody - Allocate
budgets without understanding which customer groups drive value

**The question is: "How many distinct customer groups exist, and what
makes each unique?"**

------------------------------------------------------------------------

## How Segmentation Actually Works

### The Core Algorithm: K-Means Clustering

**Step-by-step example:**

You have 1,000 customers rated on 5 attitudes (1-10 scales): - Price
sensitivity - Quality importance - Brand loyalty - Innovation interest -
Service expectations

**Goal:** Find groups of similar customers.

**K-Means Process:**

1.  **Choose number of segments (k)** - Let's test k=4

2.  **Initialize:** Randomly place 4 "cluster centers" in your data
    space

3.  **Assign:** Calculate each customer's distance to each center,
    assign to nearest

    -   Customer 1: Distance to Center A = 2.3, Center B = 5.1, Center C
        = 4.7, Center D = 6.2
    -   Assign Customer 1 to Segment A (closest)

4.  **Update:** Recalculate cluster centers as the average of assigned
    customers

    -   Segment A now at mean of all customers assigned to A

5.  **Repeat steps 3-4 until** assignments stop changing (converged)

**Result:** 4 groups where customers within each group are similar,
groups are different from each other.

------------------------------------------------------------------------

## Exploration vs. Final Mode

Segment operates in two modes:

### Exploration Mode (First Run)

**You don't specify k (number of segments).**

**What happens:** - Runs clustering for k=2, 3, 4, 5, 6, 7, 8, 9, 10 -
Calculates quality metrics for each solution - Recommends optimal k
based on statistical criteria

**Output:** K Selection Report showing: - Silhouette scores (segment
separation) - Within-cluster sum of squares (compactness) -
Between-cluster sum of squares (differentiation) - Recommended k with
justification

**Example recommendation:**

```         
k=2: Too few - misses important differences
k=3: Good separation, but
k=4: RECOMMENDED - Best balance of interpretability and statistical quality
k=5: Marginal improvement, harder to action
k=6+: Over-segmentation, diminishing returns
```

------------------------------------------------------------------------

### Final Mode (After Choosing k)

**You specify k_fixed = 4 in config (based on exploration results).**

**What happens:** - Runs k-means with k=4 - Creates detailed segment
profiles - Generates business-ready outputs - Provides targeting
recommendations

**Outputs:** 1. Segment assignments for each respondent 2. Segment
profile tables (characteristics × segments) 3. Discriminating variable
analysis 4. Segment size and composition 5. Targeting recommendation
cards

------------------------------------------------------------------------

## How to Choose the Right Number of Segments

### Statistical Criteria:

**1. Silhouette Score (-1 to +1)**

Measures how well each customer fits their assigned segment vs. other
segments.

-   **+1:** Perfect fit (customer is very similar to segment, very
    different from others)
-   **0:** Borderline (could belong to multiple segments)
-   **-1:** Wrong segment (more similar to a different segment)

**Average silhouette \> 0.5 = good segmentation**

**Example:**

| k   | Avg Silhouette | Interpretation              |
|-----|----------------|-----------------------------|
| 2   | 0.62           | Good, but too simple        |
| 3   | 0.58           | Good                        |
| 4   | 0.55           | Good ← RECOMMENDED          |
| 5   | 0.51           | Acceptable                  |
| 6   | 0.45           | Fair - segments overlapping |
| 7   | 0.38           | Poor - too fragmented       |

------------------------------------------------------------------------

**2. Elbow Method (Within-Cluster Sum of Squares)**

Total distance of customers to their segment centers. Lower = tighter
segments.

**Look for the "elbow"** - where adding more segments stops helping
much.

```         
WCSS Plot:

│ 10000 ●
│
│  5000      ●
│
│  2000         ●___●___●___●___●
│                  ↑
└────────────────────────────────
   2   3   4   5   6   7   8   9
         Number of Segments (k)
```

Elbow at k=4 → diminishing returns after this point.

------------------------------------------------------------------------

**3. Business Actionability**

**Too few segments (k=2-3):** - ❌ Miss nuanced differences - ❌ Still
too broad for precise targeting

**Optimal segments (k=4-6):** - ✅ Distinct, interpretable groups - ✅
Each segment large enough to matter - ✅ Manageable for
marketing/operations

**Too many segments (k=8+):** - ❌ Over-fragmentation - ❌ Small segment
sizes (hard to target profitably) - ❌ Difficult to operationalize

------------------------------------------------------------------------

## Understanding Segment Profiles

Once you have segments, you need to understand what makes each unique:

### Example Segmentation (Retail Bank)

**4 Segments Identified:**

| Segment | Size | Key Characteristics |
|-----------------|-----------------|---------------------------------------|
| **A: Premium Optimizers** | 22% | High income, quality-focused, low price sensitivity |
| **B: Budget Conscious** | 38% | Price-driven, deal-seeking, value-oriented |
| **C: Digital Natives** | 25% | Tech-savvy, mobile-first, innovation-driven |
| **D: Traditional Savers** | 15% | Risk-averse, branch-preferring, older |

------------------------------------------------------------------------

### Discriminating Variables Analysis

**Which variables best separate the segments?**

Uses ANOVA F-statistics to rank variables:

| Variable          | F-Statistic | p-value | Importance |
|-------------------|-------------|---------|------------|
| Price sensitivity | 248.3       | \<0.001 | Highest    |
| Digital adoption  | 186.7       | \<0.001 | High       |
| Risk tolerance    | 124.5       | \<0.001 | High       |
| Branch usage      | 89.2        | \<0.001 | Medium     |
| Age               | 67.8        | \<0.001 | Medium     |
| Income            | 45.3        | \<0.001 | Low        |

**What this means:** - Price sensitivity is THE key differentiator
(highest F-stat) - Digital adoption also very important - Income matters
less than you might think

**Business insight:** Price sensitivity and digital adoption matter more
than demographics for targeting.

------------------------------------------------------------------------

### Detailed Segment Profile Example

**Segment A: Premium Optimizers (22% of sample)**

| Attribute               | Segment A | Total Sample | Index |
|-------------------------|-----------|--------------|-------|
| **Demographics**        |           |              |       |
| Avg. Age                | 42        | 45           | 93    |
| Avg. Income             | \$125K    | \$78K        | 160   |
| College degree (%)      | 78%       | 58%          | 134   |
| **Attitudes (1-10)**    |           |              |       |
| Price sensitivity       | 3.2       | 6.1          | 52    |
| Quality importance      | 9.1       | 7.3          | 125   |
| Brand loyalty           | 8.4       | 5.9          | 142   |
| Innovation interest     | 7.8       | 6.5          | 120   |
| **Behaviors**           |           |              |       |
| Avg. monthly spend      | \$850     | \$420        | 202   |
| Products owned          | 4.2       | 2.3          | 183   |
| Digital channel use (%) | 85%       | 62%          | 137   |

**Index interpretation:** - Index 100 = average - Index 160 (income) =
60% higher than average - Index 52 (price sensitivity) = 48% lower than
average (less price-sensitive)

**Segment A narrative:**

"Premium Optimizers are affluent, quality-focused customers who value
service and product excellence over price. They're digitally engaged
despite higher average age. With high product ownership and spending
levels, they're the most valuable segment. Messaging should emphasize
quality, expertise, and personalized service rather than discounts."

------------------------------------------------------------------------

## Segment Stability & Validation

### Why Validation Matters:

Just because you CAN create segments doesn't mean they're REAL.

**Two risks:** 1. **Overfitting:** Segments are artifacts of this
specific sample 2. **Instability:** Segments change dramatically with
small data changes

------------------------------------------------------------------------

### Stability Testing (Bootstrap Method)

**How it works:**

1.  Resample your data 100 times (with replacement)
2.  Run k-means on each resample
3.  Measure how consistently customers end up in the same segment

**Jaccard Similarity Score:**

Measures overlap between segment assignments across resamples.

-   **\> 0.8:** Excellent stability
-   **0.6-0.8:** Good stability
-   **0.4-0.6:** Fair stability (acceptable with caveats)
-   **\< 0.4:** Poor stability (consider different k or variables)

**Example:**

```         
Testing k=4 solution with 100 bootstrap iterations...

Average Jaccard similarity: 0.76
Interpretation: Good - segments are reasonably stable

→ Segments are robust; proceed with confidence
```

If stability is poor (\< 0.6): - Try different k (maybe k=3 is more
stable than k=4) - Review clustering variables (unstable variables
create unstable segments) - Check for outliers (extreme cases can
distort clustering)

------------------------------------------------------------------------

### Discriminant Analysis Validation

**Tests:** Can you predict segment membership from the clustering
variables?

**How it works:** - Use Linear Discriminant Analysis (LDA) - Train on
cluster assignments - Measure classification accuracy

**Interpretation:**

| Accuracy | Interpretation                                 |
|----------|------------------------------------------------|
| \> 90%   | Excellent - segments are very well separated   |
| 75-90%   | Good - segments are distinct                   |
| 60-75%   | Fair - some overlap between segments           |
| \< 60%   | Poor - segments are not clearly differentiated |

**Example:**

```         
Discriminant Analysis Results:

Classification accuracy: 87.3%

Confusion Matrix:
           Predicted
Actual     A    B    C    D
   A      89    3    5    3
   B       2  147    8    5
   C       4    6   96    4
   D       1    2    3   44

Interpretation: Good - segments are distinct
→ Segments have clear boundaries; suitable for targeting
```

------------------------------------------------------------------------

## Common Segmentation Mistakes

### Mistake 1: Including Too Many Variables

**❌ Wrong:** Include all 50 survey questions in clustering.

**Why it fails:** - High dimensionality creates noise - Variables
correlated with each other (redundancy) - Harder to interpret segments

**✓ Right:** - Select 5-10 key discriminating variables - Use factor
analysis first if you have many variables - Focus on actionable
attributes

**How to choose variables:** - Business relevance (can you target based
on this?) - Variance (does it differentiate people?) - Low correlation
(avoid redundancy)

------------------------------------------------------------------------

### Mistake 2: Not Standardizing Variables

**❌ Wrong:** Cluster on raw variables with different scales: - Income:
\$30,000 - \$200,000 (range: 170,000) - Satisfaction: 1-10 (range: 9)

**Why it fails:** Income will dominate clustering just because of scale,
even if satisfaction matters more.

**✓ Right:** Standardize all variables (mean=0, SD=1) before clustering.

**Example:**

```         
Before:
Customer 1: Income=$50K, Satisfaction=7
Customer 2: Income=$55K, Satisfaction=9

Distance ≈ 5,000 (dominated by income difference)

After standardizing:
Customer 1: Income=-0.5, Satisfaction=0.2
Customer 2: Income=-0.3, Satisfaction=1.8

Distance ≈ 1.6 (both variables contribute)
```

------------------------------------------------------------------------

### Mistake 3: Ignoring Segment Size

**❌ Wrong:** Accept k=8 solution where 3 segments have \<5% of sample.

**Why it fails:** - Too small to target profitably - Unstable (small n =
high sampling error) - Not actionable

**✓ Right:** Set minimum segment size (e.g., 10% of sample) as a
constraint.

**TurasSegment enforces this:** Config parameter `min_segment_size_pct`
(default: 5%)

------------------------------------------------------------------------

### Mistake 4: Using Segmentation Variables as Descriptors

**❌ Wrong:** "Segment A is price-sensitive" when price sensitivity was
used to CREATE the segments.

**Why it matters:** That's circular—you're just describing what you put
in.

**✓ Right:** Use clustering variables to CREATE segments, then use OTHER
variables to DESCRIBE them:

**Clustering variables (what segments are BASED on):** - Price
sensitivity - Quality importance - Innovation interest - Brand loyalty

**Descriptor variables (what segments ALSO differ on):** - Demographics
(age, income, education) - Purchase behaviors (frequency, category
preferences) - Media consumption - Psychographics

**Example:**

"We clustered on attitudes and found 4 segments. Segment A (Premium
Optimizers) not only scores low on price sensitivity (clustering
variable), but ALSO tends to be higher income, college-educated, and
prefers premium brands (descriptor variables)."

------------------------------------------------------------------------

## When Segmentation Doesn't Work

### Scenario 1: Homogeneous Market

**Data:** All customers score 6-7 on every attitude. Little variation.

**Result:** Clustering will create segments, but they're artificial—no
real groups exist.

**Red flags:** - Silhouette scores \< 0.3 - Discriminant accuracy \<
65% - Segments differ only slightly

**What to do:** Don't force segmentation. Report: "Market is relatively
homogeneous; segments not distinct enough to warrant differential
strategy."

------------------------------------------------------------------------

### Scenario 2: Sample Too Small

**Example:** - n=150 customers - Trying k=5 segments - = 30 customers
per segment

**Problem:** - Small segments (n=30) are unstable - Statistical tests
lack power - Profile estimates unreliable

**Rule of thumb:** Need at least **100-150 customers per expected
segment** for stable results.

So for k=5, need n ≥ 500-750.

------------------------------------------------------------------------

### Scenario 3: Wrong Variables

**Example:** Cluster on demographics only (age, gender, income).

**Result:** Segments exist but may not predict behavior.

**Why:** Demographics often don't drive behavior as much as attitudes,
needs, and motivations.

**Better approach:** Cluster on behaviors/attitudes, THEN describe by
demographics.

------------------------------------------------------------------------

## Segment Naming & Storytelling

After creating segments statistically, you need to NAME them for
business use.

### Good Segment Names:

**✓ Descriptive:** Captures essence of the group **✓ Memorable:** Easy
for stakeholders to remember **✓ Action-oriented:** Suggests how to
target them

**Examples:**

| Segment | Boring Name | Good Name | Even Better |
|-----------------|-------------------|-----------------|-------------------|
| A | High-income quality-seekers | Premium Buyers | The Connoisseurs |
| B | Price-sensitive budget shoppers | Deal Hunters | Smart Savers |
| C | Tech-savvy early adopters | Digital Natives | Innovation Seekers |
| D | Traditional low-risk customers | Conservative Buyers | Steady Loyalists |

------------------------------------------------------------------------

### Segment Storytelling:

Turn profile numbers into narratives:

**Example - "The Connoisseurs" (Segment A):**

"Meet Sarah, a typical Connoisseur. She's a 42-year-old professional
with a household income of \$125K. For Sarah, quality trumps price every
time—she'd rather pay more for products she trusts than risk
disappointment with cheaper alternatives. She researches extensively
before purchase, values expert advice, and expects personalized service.
She's digitally savvy but still appreciates human interaction for
complex decisions. Sarah owns 4 of our products and spends
\$850/month—she's our most valuable customer type. She responds to
messaging about craftsmanship, exclusivity, and superior performance,
but tune out discount-focused promotions."

**Contrast with "Smart Savers" (Segment B):**

"Meet David, a Smart Saver. He's a 38-year-old with a household income
of \$62K and a family of four. Every dollar matters to David, so he
actively seeks deals, compares prices, and waits for promotions. He's
brand-agnostic—whoever offers the best value wins. He uses our app to
track deals and price drops. David owns 2 of our products and spends
\$320/month. He responds to percentage-off promotions, bundle deals, and
price-match guarantees. Messages about quality or prestige don't
resonate—show him the savings."

------------------------------------------------------------------------

## Technology Used

| Package | Purpose |
|------------------------------------|------------------------------------|
| **stats::kmeans** | Core k-means clustering algorithm (fast, standard) |
| **cluster** | Silhouette analysis and advanced clustering methods |
| **MASS** | Linear discriminant analysis for validation |
| **poLCA** | Latent class analysis (model-based segmentation alternative) |
| **rpart** | Decision trees for segment profiling |
| **factoextra** | Visualization of clustering results |
| **openxlsx** | Excel output with formatted segment profiles |

**Note:** TurasSegment uses standard R clustering
packages—battle-tested, peer-reviewed algorithms, not custom/proprietary
methods.

------------------------------------------------------------------------

## Strengths

✅ **Exploration + Final workflow:** Guides you to optimal k
systematically ✅ **Statistical validation:** Stability testing and
discriminant analysis ✅ **Handles large datasets:** Mini-batch k-means
for n \> 10,000 ✅ **Rich profiling:** Discriminating variables,
indices, narratives ✅ **Business-ready outputs:** Segment cards,
targeting recommendations ✅ **Reproducible:** Seed control ensures
consistent results

------------------------------------------------------------------------

## Limitations

⚠️ **Requires adequate sample:** Need 100+ per expected segment ⚠️
**Variable selection is subjective:** Analyst judgment required ⚠️
**K-means assumptions:** Assumes spherical clusters of similar size ⚠️
**Not predictive:** Doesn't assign NEW customers to segments (need
scoring model) ⚠️ **Naming requires interpretation:** Statistical output
needs business translation

------------------------------------------------------------------------

## Real-World Impact

**Client example (anonymized):**

**Challenge:** Retail bank with 50,000 customers, treating all
similarly.

**Approach:** - Clustered on 8 banking attitude/behavior variables -
Explored k=2 through k=10 - Chose k=5 based on silhouette score and
business actionability

**Segments identified:** 1. Young Accumulators (18%) - savings-focused,
digital-first 2. Family Financiers (32%) - mortgage/education needs 3.
Wealth Builders (15%) - investment-oriented 4. Credit Reliers (23%) -
revolving credit users 5. Retirees (12%) - fixed income, risk-averse

**Business actions:** - Tailored product offerings per segment -
Segment-specific messaging in email campaigns - Adjusted branch vs.
digital channel strategy by segment

**Results (12 months post-implementation):** - Product cross-sell:
+23% - Campaign response rates: +31% - Customer satisfaction: +8 points
(NPS) - Profit per customer: +18%

**ROI:** Segmentation analysis cost: \$25K. Incremental profit first
year: \$2.1M.

------------------------------------------------------------------------

## Quality & Status

**Quality Score:** 85/100 **Production Ready:** Yes **Error Handling:**
Good (TRS-compliant validation) **Testing Status:** Core algorithms
tested; expanding validation suite

------------------------------------------------------------------------

## Bottom Line

Segment transforms undifferentiated customer data into actionable groups
with distinct needs and characteristics. Using proven clustering
algorithms with rigorous validation, it creates segments that are both
statistically sound and business-relevant. The two-mode workflow
(exploration → final) ensures you choose the right number of segments
before committing to detailed profiling.

**Think of it as:** A data scientist who discovers hidden customer
groups in your data, validates that they're real and stable, creates
detailed profiles showing how they differ, and translates statistical
output into business narratives and targeting recommendations.

The alternative to segmentation is one-size-fits-all strategy—which
means mediocre results with everyone. Segmentation enables precision
targeting, higher response rates, and better resource allocation.

------------------------------------------------------------------------

*For questions or support, contact The Research LampPost (Pty) Ltd*

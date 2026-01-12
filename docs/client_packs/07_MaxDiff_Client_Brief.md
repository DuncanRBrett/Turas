---
editor_options: 
  markdown: 
    wrap: 72
---

# MaxDiff: Maximum Difference Scaling

**What This Module Does** MaxDiff reveals preference rankings by asking
respondents to choose "most" and "least" preferred from sets of items.
It produces precise preference scores for features, messages, or brand
attributes without forcing long ranking lists. Uses conditional logit
and Bayesian estimation for robust preference measurement.

------------------------------------------------------------------------

## What Problem Does It Solve?

Traditional ranking questions are hard when you have many items (10+
options): - Respondents struggle to rank 15 features from most to least
important - Middle-ranked items get unreliable ratings - Direct ratings
suffer from scale-use bias (everyone rates everything "important")

**MaxDiff gets clean preference data through simple "best" and "worst"
choices.**

------------------------------------------------------------------------

## How It Works

Instead of ranking 15 features, respondents see sets of 4-5 items at a
time:

**Task Example:** "Which feature is MOST important? Which is LEAST
important?" - [ ] Long battery life (MOST) - [ ] 5G connectivity - [ ]
Premium camera - [ ] Large screen (LEAST)

Repeating this 10-12 times across different item combinations, the
module calculates: - **Preference scores:** How much each item is valued
(0-100 scale) - **Rankings:** Definitive order from most to least
preferred - **Gaps:** How much more valuable item #1 is vs. item #2 -
**Individual preferences:** Personal priority for each respondent (with
HB)

------------------------------------------------------------------------

## What You Get

**Aggregate Outputs:** - Preference scores (rescaled 0-100 for easy
interpretation) - Definitive rankings from most to least preferred -
Statistical significance of differences between items - Probability
scores (chance item is chosen as best)

**Individual Outputs (HB method):** - Personal preference scores for
each respondent - Individual rankings (enables segmentation) - Utility
values for each item - Uncertainty estimates (credible intervals)

**Excel Reports:** - Formatted preference tables - Ranking charts -
Comparison to population averages - Segment-level results

------------------------------------------------------------------------

## Technology Used

| Package | Why We Use It |
|---------------------------|---------------------------------------------|
| **survival::clogit** | Conditional logit for MaxDiff aggregate estimation |
| **cmdstanr** | Stan-based Hierarchical Bayes for individual-level preferences (OPTIONAL) |
| **AlgDesign** | Optimal experimental design for MaxDiff tasks |
| **openxlsx** | Professional Excel output with formatting |

**NOTE:** cmdstanr is optional. If not installed, Turas automatically
uses an empirical Bayes fallback method that provides individual-level
estimates through statistical shrinkage.

------------------------------------------------------------------------

## Strengths

✅ **More Discriminating:** Better at separating preferences than rating
scales ✅ **Less Fatigue:** Easier for respondents than ranking 15+
items ✅ **Individual-Level (HB):** Bayesian method provides
personalized preference scores ✅ **Avoids Scale Bias:** Doesn't suffer
from "everything is important" problem ✅ **Large Item Sets:** Can
handle 20-30 items efficiently ✅ **Statistical Rigor:** Significance
testing between all item pairs (aggregate) ✅ **Versatile:** Works for
features, messages, brand attributes, claims, etc. ✅ **Flexible
Installation:** Works with or without Stan (empirical Bayes fallback)

------------------------------------------------------------------------

## Limitations

⚠️ **Survey Length:** Needs 8-15 choice tasks per respondent for stable
estimates ⚠️ **Requires Careful Design:** Task sets must be balanced and
orthogonal ⚠️ **Assumes Unidimensional:** All items rated on same
underlying dimension (importance/preference) ⚠️ **Stan Computation
Time:** Full HB estimation with Stan requires setup time and
computational resources ⚠️ **Context-Dependent:** Results assume items
are evaluated independently

------------------------------------------------------------------------

## Statistical Concepts Explained (Plain English)

### What Is the Best/Worst Method?

**Traditional Rating Scales:** "Rate the importance of each feature
1-10"

**Problem:** Scale-use bias (everyone rates 8-10)

**MaxDiff Solution:** "From these 4 features, pick the MOST important
AND the LEAST important"

**Why this is better:**

1.  **Forces real trade-offs:** You can't say everything is "9 out of
    10"
2.  **More cognitive realism:** Easier to pick best/worst than assign
    ratings
3.  **Reveals true priorities:** Shows relative preference directly
4.  **Avoids response patterns:** No "agree tendency" or "midpoint bias"

**Example Comparison:**

**Rating Scale (15 smartphone features):**

```         
Battery life:     9/10
Camera quality:   9/10
5G connectivity:  8/10
Screen size:      8/10
Fast charging:    9/10
Water resistance: 8/10
...all others:    7-9/10
```

**Result:** Can't differentiate—everything is "important"

**MaxDiff (same 15 features across 12 tasks):**

```         
Battery life:     Score 100 (Rank #1)
Fast charging:    Score 87  (Rank #2)
Camera quality:   Score 71  (Rank #3)
5G connectivity:  Score 58  (Rank #4)
Screen size:      Score 44  (Rank #5)
Water resistance: Score 31  (Rank #6)
...
```

**Result:** Clear priority ranking with measurable gaps

------------------------------------------------------------------------

### Why Pick BOTH Best AND Worst?

**Picking best alone:** - Tells you top items - But middle items
unclear - Bottom items never chosen

**Picking best AND worst:** - Top items chosen as "best" - Bottom items
chosen as "worst" - Middle items: Sometimes best, sometimes worst →
reveals exact position - **2x information per task**

**Statistical benefit:**

Each task with 5 items shown: - Best choice: 1 data point (which of 5 is
best?) - Worst choice: 1 data point (which of 5 is worst?) - **Total: 2
observations per task**

With 12 tasks: - 24 observations per respondent - With 250 respondents:
6,000 observations - Enough to reliably rank 15-20 items

------------------------------------------------------------------------

### Worked Example: Task-by-Task

**Scenario:** 15 smartphone features, 12 tasks, 5 features shown per
task

**TASK 1:** Which is MOST important? Which is LEAST important?

-   [ ] Battery life ← Selected as MOST
-   [ ] Screen size
-   [ ] 5G connectivity
-   [ ] Water resistance
-   [ ] Premium camera ← Selected as LEAST

**Result recorded:** - Battery life: +1 "best" count - Premium camera:
+1 "worst" count - Other 3 items: 0 counts (shown but not selected)

**TASK 2:** - [ ] Fast charging ← Selected as MOST - [ ] Premium
camera - [ ] Lightweight design - [ ] Wireless charging ← Selected as
LEAST - [ ] Face unlock

**Result:** - Fast charging: +1 best - Wireless charging: +1 worst

**After 12 tasks, aggregate counts:**

| Feature           | Times Shown | Best Count | Worst Count | BW Score |
|-------------------|-------------|------------|-------------|----------|
| Battery life      | 12          | 8          | 0           | +8       |
| Fast charging     | 12          | 7          | 0           | +7       |
| Premium camera    | 12          | 4          | 3           | +1       |
| 5G connectivity   | 12          | 2          | 1           | +1       |
| Screen size       | 12          | 1          | 2           | -1       |
| Wireless charging | 12          | 0          | 6           | -6       |

**BW Score = Best Count - Worst Count**

This is the simplest MaxDiff output (counting method).

**But we can do better with conditional logit...**

------------------------------------------------------------------------

## Conditional Logit Model: The Math Behind MaxDiff

### What Is Conditional Logit?

**Goal:** Estimate a "utility" (preference strength) for each item.

**Model:** Probability that item *i* is chosen as BEST from set *S*:

```         
P(item i = best | set S) = exp(β_i) / [exp(β_1) + exp(β_2) + ... + exp(β_K)]
```

Where: - β_i = utility of item *i* - K = number of items in the set
(e.g., 5) - exp() = exponential function

**In plain English:** "An item's chance of being picked as best depends
on its utility relative to the other items shown in that set"

**For WORST choices:**

```         
P(item i = worst | set S) = exp(-β_i) / [exp(-β_1) + exp(-β_2) + ... + exp(-β_K)]
```

**Key difference:** NEGATIVE utility for worst (items with low utility
are more likely to be picked as worst)

------------------------------------------------------------------------

### Step-by-Step Conditional Logit Calculation

**Setup:** 4 features shown in a task

**True utilities (what we're trying to estimate):** - Battery life: β =
1.2 - Camera: β = 0.5 - 5G: β = -0.3 - Screen size: β = -0.8

**STEP 1: Calculate exp(β) for each item**

| Item         | β    | exp(β) |
|--------------|------|--------|
| Battery life | 1.2  | 3.32   |
| Camera       | 0.5  | 1.65   |
| 5G           | -0.3 | 0.74   |
| Screen size  | -0.8 | 0.45   |

**STEP 2: Sum all exp(β) values**

Sum = 3.32 + 1.65 + 0.74 + 0.45 = **6.16**

**STEP 3: Calculate probability each item is chosen as BEST**

```         
P(Battery = best) = 3.32 / 6.16 = 0.54 (54%)
P(Camera = best)  = 1.65 / 6.16 = 0.27 (27%)
P(5G = best)      = 0.74 / 6.16 = 0.12 (12%)
P(Screen = best)  = 0.45 / 6.16 = 0.07 (7%)
```

**Interpretation:** Battery has 54% chance of being picked as most
important (highest utility)

**STEP 4: Calculate probability each item is chosen as WORST**

**Use NEGATIVE utilities:**

| Item         | -β   | exp(-β) |
|--------------|------|---------|
| Battery life | -1.2 | 0.30    |
| Camera       | -0.5 | 0.61    |
| 5G           | 0.3  | 1.35    |
| Screen size  | 0.8  | 2.23    |

Sum = 0.30 + 0.61 + 1.35 + 2.23 = **4.49**

```         
P(Battery = worst) = 0.30 / 4.49 = 0.07 (7%)
P(Camera = worst)  = 0.61 / 4.49 = 0.14 (14%)
P(5G = worst)      = 1.35 / 4.49 = 0.30 (30%)
P(Screen = worst)  = 2.23 / 4.49 = 0.50 (50%)
```

**Interpretation:** Screen size has 50% chance of being picked as least
important (lowest utility)

**STEP 5: Estimation**

In reality, we DON'T know the utilities (β values)—we have to estimate
them from the data.

**Conditional logit does this using maximum likelihood:**

1.  Start with random β values
2.  Calculate predicted probabilities for all tasks
3.  Compare to actual choices (did respondent pick battery as best?)
4.  Adjust β values to maximize match between predictions and reality
5.  Repeat until convergence

**Turas uses `survival::clogit()` for this estimation.**

------------------------------------------------------------------------

### Why Conditional Logit Is Better Than Counting

**Counting method:** - Simple: BW Score = Best count - Worst count -
BUT: Doesn't account for WHICH items were in the choice set - Assumes
all tasks are equal difficulty

**Example problem:**

**Task A:** Battery vs Screen vs 5G vs Wireless charging → Battery
chosen as best

**Task B:** Battery vs Fast charging vs Camera vs Premium design →
Battery chosen as best

**Counting:** Both tasks give Battery +1 "best" count (equal weight)

**Conditional logit:** Task B was HARDER (more strong competitors) →
Winning in Task B provides MORE evidence that Battery is truly best →
Utility estimates account for this

**Result:** Conditional logit produces more accurate rankings when item
sets vary in strength.

------------------------------------------------------------------------

### One Utility to Rule Them All: Anchor Items

**Problem:** Utilities are on an arbitrary scale (could be 0-10 or -5 to
+5)

**Solution:** Fix one item's utility to 0 (anchor item)

**Example:**

**Before anchoring (arbitrary scale):** - Battery: β = 158.3 - Fast
charging: β = 157.1 - Camera: β = 156.2 - ... - Color options: β = 152.0

**After anchoring to "Color options" = 0:** - Battery: β = 6.3 - Fast
charging: β = 5.1 - Camera: β = 4.2 - ... - Color options: β = 0.0
(anchor)

**All differences stay the same:** - Battery - Camera = 158.3 - 156.2 =
2.1 ✓ - Battery - Camera = 6.3 - 4.2 = 2.1 ✓

**Anchor selection:** - Use lowest-ranked item (makes interpretation
easier) - Or designate one in advance - Choice doesn't affect rankings,
only scale

------------------------------------------------------------------------

## Preference Scores: 0-100 Rescaling

### Raw Logit Utilities vs. Preference Scores

**Problem:** Raw utilities are hard to interpret

Example utilities: - Battery life: 1.45 - Fast charging: 0.87 - Camera:
0.23 - 5G: -0.52 - Screen size: -1.18

**What does "1.45" mean?**

**Solution:** Rescale to 0-100 scale

**Formula:**

```         
Preference Score = 100 × (Utility - Min Utility) / (Max Utility - Min Utility)
```

**Step-by-step example:**

**Raw utilities:**

```         
Battery life:  1.45  (MAX)
Fast charging: 0.87
Camera:        0.23
5G:           -0.52
Screen size:  -1.18  (MIN)
```

**Calculate range:**

```         
Max = 1.45
Min = -1.18
Range = 1.45 - (-1.18) = 2.63
```

**Apply formula:**

**Battery life:**

```         
Score = 100 × (1.45 - (-1.18)) / 2.63
      = 100 × 2.63 / 2.63
      = 100
```

**Fast charging:**

```         
Score = 100 × (0.87 - (-1.18)) / 2.63
      = 100 × 2.05 / 2.63
      = 78
```

**Camera:**

```         
Score = 100 × (0.23 - (-1.18)) / 2.63
      = 100 × 1.41 / 2.63
      = 54
```

**5G:**

```         
Score = 100 × (-0.52 - (-1.18)) / 2.63
      = 100 × 0.66 / 2.63
      = 25
```

**Screen size:**

```         
Score = 100 × (-1.18 - (-1.18)) / 2.63
      = 100 × 0 / 2.63
      = 0
```

**Final ranking:**

| Rank | Feature       | Utility | Score (0-100) |
|------|---------------|---------|---------------|
| 1    | Battery life  | 1.45    | 100           |
| 2    | Fast charging | 0.87    | 78            |
| 3    | Camera        | 0.23    | 54            |
| 4    | 5G            | -0.52   | 25            |
| 5    | Screen size   | -1.18   | 0             |

**Now we can say:** - "Battery life scores 100 (most preferred)" - "Fast
charging is 78% as preferred as battery life" - "5G scores only 25 (low
priority)"

------------------------------------------------------------------------

### Interpreting Preference Scores

**✅ CORRECT Interpretations:**

1.  **Relative preference:**
    -   "Battery life (100) is 2× more preferred than Camera (54)"
    -   **Why correct:** Score differences reflect utility differences
        on a ratio scale
2.  **Priority ranking:**
    -   "Top 3 features account for 232 total score points out of 357
        (65%)"
    -   **Why correct:** Sum of scores shows concentration of preference
3.  **Gap analysis:**
    -   "Large gap between #2 (78) and #3 (54) suggests natural break"
    -   **Why correct:** Identifies meaningful priority tiers

**❌ INCORRECT Interpretations:**

1.  **Absolute preference:**
    -   "Battery life is 100% good, screen size is 0% good"
    -   **Why wrong:** Scores are RELATIVE, not absolute quality ratings
2.  **Probability interpretation:**
    -   "Battery has 100% chance of being chosen"
    -   **Why wrong:** Scores are not probabilities (though related)
3.  **Ignoring low scorers:**
    -   "Anything below 50 is useless, don't build it"
    -   **Why wrong:** All items ranked, bottom items still have value
        (just lower priority)

**Better interpretation of "low" scores:**

If Screen size scores 0: - **Correct:** "Screen size is lowest priority
among these 15 features" - **Incorrect:** "Nobody cares about screen
size"

**Context matters:** - If all 15 features are "must-haves," even rank
#15 is important - Scores show RELATIVE priority for resource
allocation - Don't automatically cut low-scoring items—consider absolute
necessity

------------------------------------------------------------------------

### Share of Preference

**Another useful metric:** What % of total preference does each item
capture?

**Formula:**

```         
Share of Preference = Item Score / Sum of All Scores
```

**Example:**

| Feature       | Score   | Share of Preference |
|---------------|---------|---------------------|
| Battery life  | 100     | 100/357 = 28.0%     |
| Fast charging | 78      | 78/357 = 21.8%      |
| Camera        | 54      | 54/357 = 15.1%      |
| 5G            | 25      | 25/357 = 7.0%       |
| Screen size   | 0       | 0/357 = 0.0%        |
| **TOTAL**     | **357** | **100.0%**          |

**Interpretation:**

"Battery life captures 28% of total preference across all 15 features"

**Business use:**

If you have \$1M development budget: - Allocate \$280K to battery
optimization (28% of budget) - Allocate \$218K to fast charging (22% of
budget) - Allocate \$151K to camera (15% of budget) - etc.

**Cumulative share:** - Top 3 features = 28% + 22% + 15% = 65% of total
preference - Top 5 features = 79% of total preference

**Pareto principle:** Often 20% of features capture 80% of preference.

------------------------------------------------------------------------

## Scale-Use Bias: The Rating Scale Problem

### The "Everyone Rates 8-10" Problem

**Scenario:** 15 banking app features rated on 1-10 importance scale

**Typical results:**

| Feature            | Mean Rating | SD  |
|--------------------|-------------|-----|
| Security features  | 9.2         | 1.1 |
| Fast login         | 8.9         | 1.3 |
| Mobile deposit     | 8.7         | 1.4 |
| Bill pay           | 8.6         | 1.5 |
| Account alerts     | 8.5         | 1.6 |
| Transfer money     | 8.4         | 1.5 |
| Check balance      | 8.3         | 1.7 |
| Find ATM           | 8.1         | 1.8 |
| Budget tools       | 7.9         | 2.0 |
| Spending insights  | 7.8         | 2.1 |
| ...all 15 features | 7.5-9.2     | \-  |

**Problem:** - Everything bunched in 7.5-9.2 range (only 1.7 point
spread!) - Standard deviations overlap completely - Can't distinguish
priorities - Which 5 features should we build first? **Unclear.**

**Why does this happen?**

1.  **Social desirability:** "I don't want to seem like I don't value
    security"
2.  **Acquiescence bias:** Tendency to agree ("Yes, that's important")
3.  **No trade-offs:** Each item rated independently
4.  **Ceiling effect:** 10-point scale but everyone uses 7-10

------------------------------------------------------------------------

### MaxDiff Solution: Forced Trade-Offs

**Same 15 features, MaxDiff approach:**

**Task 1:** Which is MOST important? Which is LEAST important? -
Security features - Bill pay - Find ATM - Budget tools - Spending
insights

**Respondent forced to choose:** - Can't rate all 5 as "9/10" - Must
pick one MOST (security) and one LEAST (spending insights)

**After 12 tasks, results:**

| Rank  | Feature              | MaxDiff Score |
|-------|----------------------|---------------|
| 1     | Security features    | 100           |
| 2     | Mobile deposit       | 83            |
| 3     | Fast login           | 79            |
| 4     | Transfer money       | 71            |
| 5     | Bill pay             | 62            |
| 6     | Account alerts       | 54            |
| 7     | Check balance        | 48            |
| 8     | Find ATM             | 39            |
| 9     | Budget tools         | 28            |
| 10    | Spending insights    | 15            |
| 11-15 | ...other features... | 0-12          |

**Now we have:** - Full 0-100 range used - Clear ranking (#1 vs #2 vs
#3) - Measurable gaps (e.g., #2 at 83 vs #10 at 15) - **Actionable
priorities:** Build #1-5 first

**Side-by-side comparison:**

| Feature           | Rating Scale   | MaxDiff       | Clarity                    |
|-----------------|-----------------------|-----------------|-----------------|
| Security          | 9.2 (rank #1)  | 100 (rank #1) | Both agree it's #1         |
| Mobile deposit    | 8.7 (rank #3)  | 83 (rank #2)  | **MaxDiff shows it's #2!** |
| Fast login        | 8.9 (rank #2)  | 79 (rank #3)  | **Rating inflated**        |
| Find ATM          | 8.1 (rank #8)  | 39 (rank #8)  | Both agree it's #8         |
| Spending insights | 7.8 (rank #10) | 15 (rank #10) | Both agree it's #10        |

**Key insight:** Rating scales get RANK ORDER roughly right, but: -
Can't differentiate top tier (security vs login vs deposit all
8.7-9.2) - Don't show SIZE of gaps (is #1 way better than #2, or
slightly better?) - MaxDiff provides finer discrimination

------------------------------------------------------------------------

## Aggregate vs. Hierarchical Bayes (HB)

### Two Estimation Approaches

**Aggregate Method (Conditional Logit):** - Estimates ONE set of
utilities for the entire population - Assumes everyone has the same
preferences (on average) - Fast computation (seconds) - Uses
`survival::clogit()`

**Hierarchical Bayes (HB) Method:** - Estimates INDIVIDUAL utilities for
each respondent - Allows preference heterogeneity (people differ) -
Slower computation (minutes) - Uses `cmdstanr` (optional) or empirical
Bayes fallback

------------------------------------------------------------------------

### When to Use Each Method

**Decision tree:**

```         
How many respondents do you have?

├─ < 100 respondents
│  └─ Use AGGREGATE (clogit)
│     - Not enough data for stable individual estimates
│     - Aggregate preferences sufficient
│
├─ 100-200 respondents
│  └─ Either method works
│     - Aggregate: Faster, simpler
│     - HB: Enables basic segmentation
│
└─ > 200 respondents
   └─ Use HB (Hierarchical Bayes)
      - Enough data for individual estimates
      - Enables segmentation by preference
      - Can identify niches
```

**Additional considerations:**

**Use Aggregate when:** - Homogeneous audience (B2B targeting one
industry) - Only need overall rankings - Fast turnaround required -
Technical audience comfortable with logit models

**Use HB when:** - Heterogeneous audience (consumer market) - Want to
segment by preferences - Need individual-level scores for targeting -
Sufficient sample size (n \> 200)

------------------------------------------------------------------------

### What HB Provides That Aggregate Doesn't

**Aggregate output:**

| Feature       | Utility | SE   | Score |
|---------------|---------|------|-------|
| Battery life  | 1.45    | 0.12 | 100   |
| Fast charging | 0.87    | 0.10 | 78    |
| Camera        | 0.23    | 0.09 | 54    |

**Interpretation:** "On average, battery life is most preferred"

**HB output:**

**Population-level:** \| Feature \| Mean Utility \| SD \| 5th %ile \|
95th %ile \|
\|---------\|--------------\|-----\|----------\|-----------\| \| Battery
life \| 1.45 \| 0.62 \| 0.43 \| 2.51 \| \| Fast charging \| 0.87 \| 0.71
\| -0.29 \| 2.15 \| \| Camera \| 0.23 \| 0.85 \| -1.18 \| 1.63 \|

**Interpretation:** "Battery utility varies widely (SD=0.62); some
people value it much more than others"

**Individual-level:**

| Respondent | Battery | Fast Charging | Camera |
|------------|---------|---------------|--------|
| 001        | 2.1     | 0.3           | -0.5   |
| 002        | 0.8     | 1.4           | 0.9    |
| 003        | 1.6     | 0.5           | 0.2    |
| ...        | ...     | ...           | ...    |

**Interpretation:** Respondent 001 strongly prefers battery; Respondent
002 prefers camera

**Segmentation possibilities:**

**Segment 1 (40% of sample): "Power users"** - Battery utility: 2.3
(very high) - Fast charging: 1.6 (high) - Camera: -0.2 (low)

**Segment 2 (35%): "Photo enthusiasts"** - Camera: 2.1 (very high) -
Screen size: 1.3 (high) - Battery: 0.4 (low)

**Segment 3 (25%): "Balanced users"** - All features: 0.5-1.0 (moderate,
similar)

**Business application:** - Segment 1: Market with "All-day battery
life" message - Segment 2: Market with "Professional-grade camera"
message - Segment 3: Market with "Complete package" message

------------------------------------------------------------------------

### Empirical Bayes: The Fallback Method

**What if you don't have cmdstanr installed?**

Turas automatically uses **empirical Bayes** as a fallback.

**How it works:**

**STEP 1: Calculate individual BW scores (counting method)**

For each respondent, count best/worst selections per item.

**Respondent 001:** \| Item \| Best \| Worst \| BW Score \|
\|------\|------\|-------\|----------\| \| Battery \| 7 \| 0 \| +7 \| \|
Camera \| 2 \| 5 \| -3 \| \| 5G \| 1 \| 3 \| -2 \|

**STEP 2: Calculate population statistics**

```         
Mean BW score for Battery across all respondents: 4.8
SD: 2.1
```

**STEP 3: Apply shrinkage**

**Problem:** Individual BW scores are noisy (only 12 tasks per person)

**Solution:** Shrink individual estimates toward population mean

**James-Stein shrinkage formula:**

```         
Shrunken estimate = Population mean + λ × (Individual score - Population mean)
```

Where λ (shrinkage factor) = 0-1: - λ = 1: No shrinkage (use raw
individual score) - λ = 0: Full shrinkage (ignore individual, use
population mean) - λ = 0.7: Typical (compromise between individual and
population)

**Example:**

**Respondent 001 Battery BW score: 7** **Population mean: 4.8**
**Shrinkage factor: 0.7**

```         
Shrunken estimate = 4.8 + 0.7 × (7 - 4.8)
                  = 4.8 + 0.7 × 2.2
                  = 4.8 + 1.54
                  = 6.34
```

**Interpretation:** - Raw individual score: 7 (possibly noisy) -
Population mean: 4.8 (ignores individual differences) - Shrunken
estimate: 6.34 (balanced compromise)

**Shrinkage is adaptive:** - Respondents with extreme scores shrunk more
toward mean - Respondents with typical scores shrunk less - Items with
high population variance allow more individual variation

**Empirical Bayes vs. Full HB (Stan):**

| Aspect                  | Empirical Bayes    | Full HB (Stan)               |
|-------------------------|--------------------|------------------------------|
| Speed                   | Fast (seconds)     | Slow (minutes)               |
| Installation            | No dependencies    | Requires cmdstanr + CmdStan  |
| Accuracy                | Good approximation | Gold standard                |
| Uncertainty             | Approximate CIs    | Full posterior distributions |
| Convergence diagnostics | None               | R-hat, ESS, divergences      |

**When empirical Bayes is sufficient:** - n \> 500 (large samples) -
Homogeneous population (low heterogeneity) - Don't need fine-grained
segmentation - Want fast results

**When to install cmdstanr for full HB:** - n \< 500 (smaller samples
benefit from Bayesian shrinkage) - Heterogeneous population (want to
capture differences) - Need rigorous uncertainty quantification - Have
time for longer computation

------------------------------------------------------------------------

## Experimental Design: Balanced Incomplete Block Designs

### Why Design Matters

**Bad design:** - Battery shown 15 times, Camera shown 5 times - Battery
always paired with weak items - Camera always paired with strong items

**Result:** Biased utilities (can't compare fairly)

**Good design:** - All items shown equal times (±1) - Each pair of items
appears together equally often - Balanced across respondents

------------------------------------------------------------------------

### Balanced Incomplete Block Design (BIBD)

**Goal:** Show each item the same number of times across all tasks.

**Example:** - 18 items total - 12 tasks per respondent - 5 items per
task

**Requirements:**

**Balance:** - Each item shown: 12 tasks × 5 items / 18 items = 3.33
times - Rounded: Each item shown 3-4 times per respondent

**Orthogonality:** - Each pair of items (e.g., Battery + Camera) appears
together roughly equal times - Prevents confounding (Battery not always
paired with weak items)

**AlgDesign package does this automatically:**

``` r
# Turas generates balanced design
design <- AlgDesign::optBlock(
  n_items = 18,
  n_tasks = 12,
  items_per_task = 5,
  criterion = "D-efficiency"
)
```

**Output:** 12 tasks with balanced item appearance

------------------------------------------------------------------------

### Example Design Matrix

**18 items, 12 tasks, 5 items per task:**

| Task | Item 1       | Item 2       | Item 3        | Item 4         | Item 5       |
|------|--------------|--------------|---------------|----------------|--------------|
| 1    | Battery      | Camera       | 5G            | Screen         | Storage      |
| 2    | Fast Charge  | Water Resist | Face Unlock   | WiFi 6         | Wireless Chg |
| 3    | Battery      | Lightweight  | Premium Build | Headphone Jack | USB-C        |
| 4    | Camera       | 5G           | Fast Charge   | Screen         | Fingerprint  |
| 5    | Water Resist | Storage      | WiFi 6        | Lightweight    | Battery      |
| ...  | ...          | ...          | ...           | ...            | ...          |
| 12   | Screen       | USB-C        | Face Unlock   | Premium Build  | 5G           |

**Check balance:**

| Item        | Times Shown |
|-------------|-------------|
| Battery     | 4           |
| Camera      | 3           |
| 5G          | 4           |
| Fast Charge | 3           |
| Screen      | 4           |
| ...         | 3-4         |

**All items appear 3-4 times ✓**

**Check pairs:**

Battery + Camera: 2 times together Battery + 5G: 2 times together
Battery + Screen: 2 times together

**All pairs appear roughly equal times ✓**

------------------------------------------------------------------------

### What Happens with Poor Design?

**Example: Unbalanced design**

| Item    | Times Shown |
|---------|-------------|
| Battery | 10          |
| Camera  | 2           |

**Problem:** - Battery has 10 chances to be chosen as best → inflated
best count - Camera has 2 chances → deflated best count - **Utilities
will be biased**

**Conditional logit accounts for "times shown" but:** - High variance
for rarely-shown items (unstable estimates) - Confidence intervals very
wide - Rankings less reliable

**Best practice:** Use AlgDesign to generate balanced designs before
fielding survey.

------------------------------------------------------------------------

## Common Pitfalls & How to Avoid Them

### Pitfall 1: "My top 3 all score 90+"

**Symptom:**

```         
Rank 1: Battery     Score 98
Rank 2: Fast charge Score 95
Rank 3: Camera      Score 92
```

**Reaction:** "These are all equally important!"

**Reality:** Scores are rescaled 0-100, top item ALWAYS = 100

**Correct interpretation:** - Look at GAPS, not absolute scores - Gap
#1→#2: 98-95 = 3 points (small gap, very close) - Gap #2→#3: 95-92 = 3
points (similar) - Gap #3→#4: 92-68 = 24 points (LARGE gap!)

**Conclusion:** Top 3 are a tight tier, then big drop to #4

**Better metric:** Share of preference - Top 3 combined: (98+95+92) =
285 out of 850 total = 33.5% - Top 3 capture only 1/3 of preference
(other 15 items matter too)

------------------------------------------------------------------------

### Pitfall 2: "Bottom items are useless"

**Symptom:**

```         
Rank 15: Color options    Score 0
Rank 14: Logo placement   Score 8
```

**Reaction:** "Nobody cares about these, cut them!"

**Reality:** - These are LOWEST priority AMONG THESE 15 ITEMS - Doesn't
mean they're worthless in isolation

**Example context:** - All 15 items are "nice-to-have" features - Even
rank #15 might be valued by 40% of customers - Just LESS valued than
battery, camera, etc.

**Better approach:** - Check raw best/worst counts - Color: Picked as
best 5 times (out of 250 respondents) - Color: Picked as worst 85
times - Interpretation: Some people DO care (5 best picks) but most
don't - Decision: Keep if cheap to implement, cut if expensive

**When low scores DO mean "cut it":** - If items are mutually exclusive
(can only build 5 of 15 features) - If all items on same dimension
(feature importance for prioritization) - Then YES, cut bottom 10, build
top 5

------------------------------------------------------------------------

### Pitfall 3: "Can I MaxDiff 100 items?"

**Theoretical limit:** Yes, math works

**Practical limit:** No, respondent fatigue

**Problems with many items:**

**30 items:** - Need \~15 tasks per respondent - Each task: Pick best +
worst from 5 items - Survey time: 5-8 minutes - **Status: Feasible**

**50 items:** - Need \~25 tasks per respondent - Survey time: 10-15
minutes - **Status: Marginal (fatigue likely)**

**100 items:** - Need \~50 tasks per respondent - Survey time: 25-35
minutes - **Status: Unacceptable (high dropout, bad data)**

**Solution for large item sets:**

**Option 1: Multiple MaxDiff exercises** - Split 100 items into 5
categories of 20 items - Run separate MaxDiff per category - Combine
with bridging items (items in multiple categories)

**Option 2: Hybrid approach** - Use MaxDiff for top-level categories (10
categories) - Use MaxDiff within each category (10 items per category) -
Two-stage prioritization

**Recommended limits:** - Ideal: 15-20 items - Maximum: 30 items -
Beyond 30: Split into multiple exercises

------------------------------------------------------------------------

### Pitfall 4: "All items are in one category"

**Bad example:** "Which luxury car brand is most preferred?" -
Mercedes - BMW - Audi - Lexus - Cadillac

**Problem:** All items on SAME dimension (luxury car preference)

**Why this breaks MaxDiff assumptions:**

MaxDiff assumes items vary on SINGLE underlying dimension: - Feature
importance: All features rated on "importance" - Brand preference: All
brands rated on "preference"

**But if items are TOO similar:** - Weak discrimination (all top brands
score 85-95) - High measurement error - Unstable rankings (brand
preference is fickle)

**Better approach:**

**MaxDiff works when items span a range:**

"Which banking app features are most important?" - Security (VERY
important) - Fast login (Important) - Bill pay (Moderately important) -
Budget tools (Nice to have) - Spending insights (Low priority)

**Wide variation → good discrimination**

**When items are too similar:**

"Which Mercedes model is most preferred?" - C-Class - E-Class -
S-Class - GLE - GLS

**All similar → use different method:** - Conjoint analysis (vary price,
features, model simultaneously) - Direct ranking (only 5 items, just ask
for ranking) - Rating scales (if fine discrimination not needed)

------------------------------------------------------------------------

## Step-by-Step Walkthrough: Complete Example

### Business Scenario

**Company:** Smartphone manufacturer

**Goal:** Prioritize features for next flagship model

**Challenge:** 15 potential features, budget for only 8

**Features:** 1. Long battery life (2-day) 2. Fast wireless charging 3.
Premium camera (108MP) 4. 5G connectivity 5. Large AMOLED screen 6.
Water resistance (IP68) 7. Lightweight design 8. Premium build
(metal/glass) 9. Face unlock 10. In-screen fingerprint 11. Headphone
jack 12. Dual SIM 13. Expandable storage 14. WiFi 6E 15. Reverse
wireless charging

------------------------------------------------------------------------

### Survey Design

**Method:** MaxDiff

**Sample:** 250 smartphone buyers (target audience)

**Design:** - 15 items total - 12 tasks per respondent - 5 items per
task - Balanced design (AlgDesign)

**Example task:**

```         
Of these features, which is MOST important for your next smartphone?
Which is LEAST important?

[ ] Long battery life         [MOST selected by respondent]
[ ] Premium camera
[ ] Water resistance
[ ] Headphone jack
[ ] WiFi 6E                    [LEAST selected by respondent]
```

------------------------------------------------------------------------

### Data Collection Results

**Total observations:** - 250 respondents × 12 tasks = 3,000 tasks -
3,000 best choices + 3,000 worst choices = 6,000 observations

**Sample data (first respondent, first 3 tasks):**

| Task | Items Shown | Best Choice | Worst Choice |
|----------------|------------------|------------------|--------------------|
| 1 | Battery, Camera, Water, Headphone, WiFi | Battery | WiFi |
| 2 | Fast Charge, 5G, Fingerprint, Storage, Dual SIM | Fast Charge | Dual SIM |
| 3 | Screen, Lightweight, Face Unlock, Premium Build, Reverse Chg | Screen | Reverse Chg |

------------------------------------------------------------------------

### Aggregate Analysis (Conditional Logit)

**Run conditional logit model:**

``` r
model <- survival::clogit(
  choice ~ item_Battery + item_FastCharge + item_Camera + ... + strata(task_id),
  data = long_data
)
```

**Output: Raw utilities**

| Feature        | Logit Utility | SE   | t-value | p-value |
|----------------|---------------|------|---------|---------|
| Battery        | 1.42          | 0.11 | 12.9    | \<0.001 |
| Fast Charge    | 0.94          | 0.10 | 9.4     | \<0.001 |
| Camera         | 0.71          | 0.09 | 7.9     | \<0.001 |
| Screen         | 0.53          | 0.09 | 5.9     | \<0.001 |
| 5G             | 0.41          | 0.09 | 4.6     | \<0.001 |
| Water Resist   | 0.28          | 0.09 | 3.1     | 0.002   |
| Fingerprint    | 0.15          | 0.09 | 1.7     | 0.089   |
| Lightweight    | 0.08          | 0.09 | 0.9     | 0.368   |
| Premium Build  | -0.05         | 0.09 | -0.6    | 0.549   |
| Face Unlock    | -0.14         | 0.09 | -1.6    | 0.110   |
| Headphone Jack | -0.29         | 0.09 | -3.2    | 0.001   |
| Storage        | -0.42         | 0.09 | -4.7    | \<0.001 |
| Dual SIM       | -0.58         | 0.10 | -5.8    | \<0.001 |
| WiFi 6E        | -0.75         | 0.10 | -7.5    | \<0.001 |
| Reverse Chg    | -1.29         | 0.11 | -11.7   | \<0.001 |

**Interpretation:** - Positive utilities: Preferred (Battery, Fast
Charge, Camera...) - Negative utilities: Less preferred (WiFi 6E,
Reverse Charging...) - All statistically significant except Lightweight,
Premium Build, Face Unlock

------------------------------------------------------------------------

### Rescale to 0-100 Preference Scores

**Range:** - Max utility: 1.42 (Battery) - Min utility: -1.29 (Reverse
Charging) - Range: 1.42 - (-1.29) = 2.71

**Apply rescaling formula:**

| Rank | Feature                   | Utility | **Score (0-100)** | Share of Preference |
|------|---------------------------|---------|-------------------|---------------------|
| 1    | Long battery life         | 1.42    | **100**           | 12.8%               |
| 2    | Fast wireless charging    | 0.94    | **82**            | 10.5%               |
| 3    | Premium camera            | 0.71    | **74**            | 9.5%                |
| 4    | Large AMOLED screen       | 0.53    | **67**            | 8.6%                |
| 5    | 5G connectivity           | 0.41    | **63**            | 8.1%                |
| 6    | Water resistance          | 0.28    | **58**            | 7.4%                |
| 7    | In-screen fingerprint     | 0.15    | **53**            | 6.8%                |
| 8    | Lightweight design        | 0.08    | **51**            | 6.5%                |
| 9    | Premium build quality     | -0.05   | **47**            | 6.0%                |
| 10   | Face unlock               | -0.14   | **44**            | 5.6%                |
| 11   | Headphone jack            | -0.29   | **37**            | 4.7%                |
| 12   | Expandable storage        | -0.42   | **32**            | 4.1%                |
| 13   | Dual SIM                  | -0.58   | **27**            | 3.5%                |
| 14   | WiFi 6E                   | -0.75   | **21**            | 2.7%                |
| 15   | Reverse wireless charging | -1.29   | **0**             | 0.0%                |
|      | **TOTAL**                 |         | **781**           | **100.0%**          |

------------------------------------------------------------------------

### Interpretation & Business Decisions

**Top Tier (Scores 70+): Must-Have Features** 1. Battery life (100) - #1
priority 2. Fast charging (82) - Strong #2 3. Camera (74) - Key
differentiator

**Share:** 32.8% of total preference **Decision:** Include all 3
(non-negotiable)

**Mid Tier (Scores 50-70): Important Features** 4. Screen (67) 5. 5G
(63) 6. Water resistance (58) 7. Fingerprint (53) 8. Lightweight (51)

**Share:** 41.8% of total preference **Decision:** Include 4-5 of these
(budget = 8 total features, have 3 from top tier, can add 5 more)

**Bottom Tier (Scores \<50): Lower Priority** 9-15. Premium build, face
unlock, headphone jack, storage, dual SIM, WiFi 6E, reverse charging

**Share:** 25.4% of total preference **Decision:** Defer to future
models or exclude

------------------------------------------------------------------------

### Final Feature Selection (Budget: 8 features)

**Selected features:** 1. Long battery life ✓ 2. Fast wireless charging
✓ 3. Premium camera ✓ 4. Large AMOLED screen ✓ 5. 5G connectivity ✓ 6.
Water resistance ✓ 7. In-screen fingerprint ✓ 8. Lightweight design ✓

**Total share of preference:** 74.6% (captured 3/4 of total preference
with 8/15 features)

**Excluded features:** - Premium build (47) - Cost too high for marginal
preference - Face unlock (44) - Have fingerprint already - Headphone
jack (37) - Declining importance - Others (32-0) - Low priority

**ROI analysis:**

If each feature costs \$50/unit to implement: - 8 features × \$50 =
\$400 added cost - Captures 74.6% of preference value - Excluded 7
features = \$350 saved - Lose only 25.4% of preference value

**Cost per preference point:** - Included features: \$400 / 74.6 =
\$5.36 per point - Excluded features: \$350 / 25.4 = \$13.78 per point

**Conclusion:** 2.6× better ROI for selected features vs. excluded ones

------------------------------------------------------------------------

## Hierarchical Bayes with Stan: Advanced Analysis

### What Is Stan?

**Stan** = Probabilistic programming language for Bayesian inference

**Key concepts:**

**Bayesian inference:** - Traditional (frequentist): Estimate fixed
parameters - Bayesian: Estimate DISTRIBUTIONS of parameters (acknowledge
uncertainty)

**Example:**

**Frequentist result:** "Battery utility = 1.42 ± 0.11 (SE)"

**Bayesian result:** "Battery utility \~ Normal(1.42, 0.11)" - Mean:
1.42 - SD: 0.11 - 95% Credible Interval: [1.20, 1.64] - Full posterior
distribution available

**Why Bayesian for MaxDiff HB?**

**Problem:** Estimate individual utilities with limited data per
person - Only 12 tasks per respondent - 15 items to estimate - **Not
enough data for stable estimates**

**Bayesian solution: Hierarchical model** - Assume individuals come from
population distribution - Estimate population mean (μ) and variance
(Σ) - Individual estimates "borrow strength" from population

**Result:** Stable individual estimates even with sparse data

------------------------------------------------------------------------

### Stan Model Specification

**Turas uses this Stan model (simplified):**

``` stan
data {
  int N;              // Number of observations
  int R;              // Number of respondents
  int J;              // Number of items
  int K;              // Items per task
  int resp[N];        // Respondent ID for each observation
  int choice[N];      // Which item was chosen (1 to K)
  int shown[N, K];    // Which items were shown (item IDs)
  int is_best[N];     // 1 if best choice, 0 if worst choice
}

parameters {
  vector[J] mu;                // Population mean utilities
  vector<lower=0>[J] tau;      // Population standard deviations
  matrix[R, J] beta_raw;       // Individual utilities (raw)
}

transformed parameters {
  matrix[R, J] beta;

  // Non-centered parameterization for efficiency
  for (r in 1:R) {
    beta[r, ] = mu' + tau .* beta_raw[r, ]';
  }
}

model {
  // Priors
  mu ~ normal(0, 3);           // Weakly informative prior on population mean
  tau ~ cauchy(0, 2.5);        // Half-Cauchy prior on population SD

  for (r in 1:R) {
    beta_raw[r, ] ~ normal(0, 1);  // Individual deviations (standardized)
  }

  // Likelihood
  for (n in 1:N) {
    vector[K] utilities;
    int r = resp[n];

    // Get utilities for items shown in this task
    for (k in 1:K) {
      utilities[k] = beta[r, shown[n, k]];
    }

    // For worst choices, negate utilities
    if (is_best[n] == 0) {
      utilities = -utilities;
    }

    // Choice follows categorical logit
    choice[n] ~ categorical_logit(utilities);
  }
}
```

**Key parts:**

1.  **Hierarchical structure:**
    -   `mu`: Population average preference
    -   `tau`: How much people differ
    -   `beta[r, j]`: Respondent r's utility for item j
2.  **Non-centered parameterization:**
    -   Improves MCMC sampling efficiency
    -   Separates population variance from individual deviations
3.  **Likelihood:**
    -   Categorical logit (softmax)
    -   Same as conditional logit but applied per-person

------------------------------------------------------------------------

### Installing cmdstanr (Optional)

**Turas works WITHOUT cmdstanr** (empirical Bayes fallback)

**But for full HB, install cmdstanr:**

**Step 1: Install cmdstanr package**

``` r
install.packages("cmdstanr",
  repos = c("https://mc-stan.org/r-packages/", getOption("repos")))
```

**Step 2: Install C++ toolchain**

**Windows:** Install Rtools

``` r
cmdstanr::check_cmdstan_toolchain()  # Check if installed
# If not, download from: https://cran.r-project.org/bin/windows/Rtools/
```

**Mac:** Install Xcode Command Line Tools

``` bash
xcode-select --install
```

**Linux:** Install g++ and make

``` bash
sudo apt-get install g++ make  # Ubuntu/Debian
```

**Step 3: Install CmdStan**

``` r
cmdstanr::install_cmdstan()
```

This downloads and compiles Stan (\~10 minutes)

**Step 4: Verify installation**

``` r
library(cmdstanr)
cmdstanr::cmdstan_path()     # Should show path
cmdstanr::cmdstan_version()  # Should show version number (e.g., "2.35.0")
```

**If installation fails:** - Check toolchain:
`cmdstanr::check_cmdstan_toolchain()` - See troubleshooting:
<https://mc-stan.org/cmdstanr/articles/cmdstanr.html>

**When to skip cmdstanr:** - Empirical Bayes is sufficient for your
needs - Don't want to install C++ compiler - Running on restricted
systems (can't install toolchains)

------------------------------------------------------------------------

### MCMC Sampling and Diagnostics

**MCMC = Markov Chain Monte Carlo**

**What it does:** Draws samples from posterior distribution

**Turas default settings:**

```         
Chains: 4 (run in parallel)
Warmup: 1,000 iterations (tuning sampler)
Sampling: 2,000 iterations (actual posterior draws)
Total: 3,000 iterations × 4 chains = 12,000 draws
```

**Diagnostics to check:**

**1. R-hat (Gelman-Rubin statistic):** - Measures convergence across
chains - **Target:** R-hat \< 1.01 - **Warning:** R-hat \> 1.05 -
**Critical:** R-hat \> 1.10

**Interpretation:** - R-hat = 1.00: Perfect convergence - R-hat = 1.05:
Chains haven't fully mixed (increase iterations) - R-hat = 1.20: Serious
convergence failure (model misspecified?)

**2. ESS (Effective Sample Size):** - MCMC draws are correlated (not
independent) - ESS = "equivalent \# of independent draws" - **Target:**
ESS \> 400 - **Warning:** ESS \< 100

**Interpretation:** - 8,000 total draws (4 chains × 2,000) with ESS =
800 - Autocorrelation reduces 8,000 draws to \~800 effective draws -
Still plenty for inference

**3. Divergences:** - Failed proposals during sampling - Indicates model
misspecification or difficult geometry - **Target:** 0 divergences -
**Warning:** Any divergences

**Fixes:** - Increase `adapt_delta` (more careful sampling, slower) -
Reparameterize model (use non-centered parameterization)

**4. Max Treedepth:** - MCMC sampler hit maximum tree depth - Indicates
sampler needs more steps - **Target:** 0 max treedepth warnings

**Turas automatically checks diagnostics:**

```         
HB CONVERGENCE DIAGNOSTICS
==============================================================

Overall Status: CONVERGED
Quality Score: 95/100

Diagnostic Summary:
  Max R-hat:      1.003 [OK]
  Min ESS:        852 [OK]
  Divergences:    0 [OK]
  Max Treedepth:  0 [OK]
```

**If convergence fails:**

Turas will warn:

```         
[TRS PARTIAL] MAXD_CONVERGENCE_ISSUES: MCMC sampling did not fully converge
Max R-hat: 1.08 (should be < 1.01)
Min ESS: 245 (should be > 400)

Recommendations:
- Increase iterations to 4,000
- Check for problematic items (very rare/common choices)
- Results may still be usable but interpret with caution
```

------------------------------------------------------------------------

### HB Results Interpretation

**Population-level output:**

| Feature     | Mean Utility | SD   | 5th %ile | 95th %ile | R-hat | ESS   |
|-------------|--------------|------|----------|-----------|-------|-------|
| Battery     | 1.45         | 0.68 | 0.43     | 2.61      | 1.00  | 1,245 |
| Fast Charge | 0.91         | 0.72 | -0.27    | 2.15      | 1.00  | 1,189 |
| Camera      | 0.68         | 0.81 | -0.65    | 2.05      | 1.00  | 1,302 |

**Reading this table:**

**Battery life:** - **Mean utility:** 1.45 (population average) -
**SD:** 0.68 (high variability—people differ a lot) - **5th
percentile:** 0.43 (even low-preference people value it somewhat) -
**95th percentile:** 2.61 (high-preference people REALLY value it) -
**R-hat:** 1.00 (perfect convergence) - **ESS:** 1,245 (plenty of
effective samples)

**Interpretation:** "Battery life is highly valued on average (1.45),
but there's substantial variation (SD=0.68). 90% of people have battery
utilities between 0.43 and 2.61."

**Contrast with Camera:** - Mean: 0.68 (lower than battery) - SD: 0.81
(EVEN MORE variable) - 5th percentile: -0.65 (some people actually
DISLIKE premium cameras!) - 95th percentile: 2.05 (photo enthusiasts
value it highly)

**Interpretation:** "Camera has lower average preference but higher
heterogeneity. Some segments don't care, others love it."

------------------------------------------------------------------------

### Segmentation Based on Individual Utilities

**Use individual utilities to segment:**

**Cluster analysis on individual utilities:**

``` r
# Extract individual utilities for all items
individual_utils <- hb_results$individual_utilities

# K-means clustering
set.seed(123)
clusters <- kmeans(individual_utils[, 2:16], centers = 3)

# Profile clusters
aggregate(individual_utils[, 2:16], by = list(Cluster = clusters$cluster), FUN = mean)
```

**Results:**

**Cluster 1 (n=92, 37%): "Power Users"** \| Feature \| Mean Utility \|
\|---------\|--------------\| \| Battery \| 2.3 (HIGH) \| \| Fast Charge
\| 1.6 (HIGH) \| \| 5G \| 1.2 (HIGH) \| \| Camera \| 0.2 (LOW) \| \|
Headphone Jack \| -0.8 (LOW) \|

**Profile:** Heavy users who value performance and battery life over
media features

**Cluster 2 (n=88, 35%): "Photo Enthusiasts"** \| Feature \| Mean
Utility \| \|---------\|--------------\| \| Camera \| 2.4 (HIGH) \| \|
Screen \| 1.8 (HIGH) \| \| Premium Build \| 1.1 (HIGH) \| \| Battery \|
0.5 (LOW) \| \| 5G \| -0.1 (LOW) \|

**Profile:** Content creators who prioritize camera and display quality

**Cluster 3 (n=70, 28%): "Pragmatists"** \| Feature \| Mean Utility \|
\|---------\|--------------\| \| All features \| 0.3-0.9 (MODERATE) \|

**Profile:** Balanced users who want complete package, no extreme
preferences

**Marketing implications:** - Cluster 1: "Never run out of power—2-day
battery life" - Cluster 2: "Professional-grade 108MP camera" - Cluster
3: "Complete flagship experience"

------------------------------------------------------------------------

## Decision Tree: MaxDiff vs. Alternatives

### When to Use MaxDiff

**START: How many items do you need to rank?**

```         
Number of items?

├─ 3-5 items
│  └─ Use DIRECT RANKING
│     - "Rank these 5 features from most to least important"
│     - Simple, no need for MaxDiff
│
├─ 6-30 items
│  └─ Use MAXDIFF ✓
│     - Optimal range for MaxDiff
│     - More reliable than rating scales
│     - Less fatigue than full ranking
│
└─ 30+ items
   └─ SPLIT or use alternative
      Option 1: Multiple MaxDiff (split into categories)
      Option 2: Kano analysis (categorize first, then MaxDiff within)
      Option 3: Conjoint (if items are attributes of same product)
```

------------------------------------------------------------------------

### Sample Size Requirements

**How many respondents do you need?**

```         
Sample size?

├─ < 100 respondents
│  └─ Use AGGREGATE method (clogit)
│     - Not enough for individual estimates
│     - Population-level preferences only
│
├─ 100-200 respondents
│  └─ Either method works
│     - Aggregate: Faster, simpler
│     - HB: Basic segmentation possible
│
└─ 200+ respondents
   └─ Use HB method ✓
      - Individual utilities stable
      - Enables segmentation
      - Captures heterogeneity
```

------------------------------------------------------------------------

### MaxDiff vs. Rating Scales

**What's your primary concern?**

```         
Main priority?

├─ Differentiation (clear rankings)
│  └─ Use MAXDIFF
│     - Forces trade-offs
│     - Avoids scale-use bias
│     - Better discrimination
│
├─ Simplicity (easy for respondents)
│  └─ Use RATING SCALES
│     - "Rate 1-10" is familiar
│     - Faster to complete
│     - But less discriminating
│
└─ Both differentiation AND tracking over time
   └─ Use BOTH
      - MaxDiff for baseline (accurate ranking)
      - Rating scales for ongoing tracking (simpler)
```

------------------------------------------------------------------------

### MaxDiff vs. Conjoint

**Nature of items?**

```         
Are items independent or part of a product?

├─ Independent items (features, messages, brands)
│  └─ Use MAXDIFF
│     Example: "Which features are most important?"
│     - Battery life
│     - Camera quality
│     - Screen size
│
└─ Attributes of same product (price × quality × brand)
   └─ Use CONJOINT
      Example: "Which smartphone would you buy?"
      - iPhone, $999, 128GB, Good camera
      - Samsung, $799, 256GB, Excellent camera
      - Google, $599, 128GB, Good camera
```

**Difference:** - **MaxDiff:** Measures importance of individual items -
**Conjoint:** Measures trade-offs between attributes (price vs. quality
vs. brand)

------------------------------------------------------------------------

## Real-World Full Example: Banking App Features

### Business Context

**Company:** Digital bank (fintech startup)

**Challenge:** - 18 potential app features identified - Development
capacity: Build 10 features for MVP launch - Need data-driven
prioritization

**Target audience:** 300 potential customers (beta testers)

------------------------------------------------------------------------

### The 18 Features

**Security & Trust:** 1. Instant fraud alerts 2. Biometric login
(fingerprint/face) 3. Virtual card numbers (for online shopping) 4.
Transaction freeze (instant card lock)

**Money Management:** 5. Spending insights (AI-powered) 6. Budget
tracking 7. Bill payment reminders 8. Savings goals

**Transactions:** 9. Instant P2P transfers 10. Mobile check deposit 11.
Scheduled payments 12. International transfers

**Convenience:** 13. ATM locator 14. Customer service chat 15. Receipt
scanning 16. Merchant cashback offers

**Advanced:** 17. Cryptocurrency wallet 18. Investment account
integration

------------------------------------------------------------------------

### MaxDiff Survey Design

**Design parameters:** - 18 items - 12 tasks per respondent - 6 items
per task - Balanced design (AlgDesign)

**Sample task:**

```         
Which feature is MOST important for your banking app?
Which is LEAST important?

[ ] Instant fraud alerts        [MOST - selected]
[ ] Budget tracking
[ ] Mobile check deposit
[ ] ATM locator
[ ] Receipt scanning
[ ] Cryptocurrency wallet        [LEAST - selected]
```

**Fielding:** - 300 respondents completed - Average completion time: 6.5
minutes - No dropouts (survey well-designed)

------------------------------------------------------------------------

### Analysis Results (Conditional Logit)

**Model fit:** - Log-likelihood: -4,821 - McFadden R²: 0.42 - 3,600
choice observations (300 respondents × 12 tasks)

**Utilities and preference scores:**

| Rank | Feature                 | Utility | Score | Share | Category     |
|------|-------------------------|---------|-------|-------|--------------|
| 1    | Instant fraud alerts    | 1.85    | 100   | 8.9%  | Security     |
| 2    | Biometric login         | 1.52    | 88    | 7.8%  | Security     |
| 3    | Mobile check deposit    | 1.28    | 81    | 7.2%  | Transactions |
| 4    | Transaction freeze      | 1.15    | 77    | 6.8%  | Security     |
| 5    | Instant P2P transfers   | 0.94    | 71    | 6.3%  | Transactions |
| 6    | Spending insights       | 0.76    | 66    | 5.9%  | Money Mgmt   |
| 7    | Budget tracking         | 0.61    | 62    | 5.5%  | Money Mgmt   |
| 8    | Bill payment reminders  | 0.49    | 58    | 5.2%  | Money Mgmt   |
| 9    | Customer service chat   | 0.35    | 55    | 4.9%  | Convenience  |
| 10   | Savings goals           | 0.21    | 51    | 4.5%  | Money Mgmt   |
| 11   | Virtual card numbers    | 0.08    | 47    | 4.2%  | Security     |
| 12   | Scheduled payments      | -0.05   | 44    | 3.9%  | Transactions |
| 13   | ATM locator             | -0.21   | 39    | 3.5%  | Convenience  |
| 14   | International transfers | -0.38   | 34    | 3.0%  | Transactions |
| 15   | Merchant cashback       | -0.55   | 29    | 2.6%  | Convenience  |
| 16   | Receipt scanning        | -0.74   | 24    | 2.1%  | Convenience  |
| 17   | Investment integration  | -0.95   | 17    | 1.5%  | Advanced     |
| 18   | Cryptocurrency wallet   | -1.37   | 0     | 0.0%  | Advanced     |

**Total:** 1,125 score points, 100.0% share

------------------------------------------------------------------------

### Key Insights

**1. Security dominates top priorities**

Top 4 features = 3 security + 1 transaction Combined share: 30.5% of
total preference

**Interpretation:** Trust and security are paramount for banking app
adoption

**2. Natural tier structure**

-   **Tier 1 (Scores 70+):** 5 features (fraud alerts, biometric, check
    deposit, freeze, P2P)
-   **Tier 2 (Scores 50-70):** 5 features (spending insights, budgets,
    bills, chat, savings)
-   **Tier 3 (Scores \<50):** 8 features (everything else)

**3. Advanced features low priority**

-   Crypto wallet: Rank #18 (0 score)
-   Investment integration: Rank #17 (17 score)

**These are "nice to have" but not MVP priorities**

**4. Big gaps reveal priorities**

-   Gap #1→#2: 100-88 = 12 points (fraud alerts clearly #1)
-   Gap #5→#6: 71-66 = 5 points (natural break between tiers)
-   Gap #10→#11: 51-47 = 4 points (top 10 vs. bottom 8)

------------------------------------------------------------------------

### Business Decision: MVP Feature Selection

**Budget:** Build 10 features for MVP

**Selection strategy:**

**Tier 1 (Must-have): Top 5** 1. Instant fraud alerts ✓ 2. Biometric
login ✓ 3. Mobile check deposit ✓ 4. Transaction freeze ✓ 5. Instant P2P
transfers ✓

**Tier 2 (Important): Choose 5 of 5** 6. Spending insights ✓ 7. Budget
tracking ✓ 8. Bill payment reminders ✓ 9. Customer service chat ✓ 10.
Savings goals ✓

**Tier 3 (Defer): 8 features postponed** 11-18. Virtual cards, scheduled
payments, ATM locator, international, cashback, receipts, investments,
crypto

**Total preference captured:** - Top 10 features: Share =
8.9+7.8+7.2+6.8+6.3+5.9+5.5+5.2+4.9+4.5 = 63.0% - Bottom 8 features:
Share = 37.0% (deferred)

**ROI analysis:**

Assume each feature costs \$120K to develop (10 features = \$1.2M
budget)

**Selected features:** - Cost: \$1.2M - Preference captured: 63.0% -
Cost per preference point: \$1.2M / 63.0 = \$19,048

**Deferred features:** - Cost: \$960K - Preference captured: 37.0% -
Cost per preference point: \$960K / 37.0 = \$25,946

**Result:** Selected features are 36% more cost-effective than deferred
ones

------------------------------------------------------------------------

### Segmentation (HB Analysis)

**Run HB model to get individual utilities:**

``` r
hb_result <- fit_hb_model(data, items, config)
```

**K-means clustering on individual utilities (3 clusters):**

**Segment 1 (n=128, 43%): "Security-First Users"** \| Feature \| Segment
Utility \| Population Utility \| Difference \|
\|---------\|-----------------\|-------------------\|------------\| \|
Fraud alerts \| 2.8 \| 1.85 \| +0.95 (much higher) \| \| Biometric login
\| 2.3 \| 1.52 \| +0.78 \| \| Transaction freeze \| 1.9 \| 1.15 \| +0.75
\| \| Spending insights \| 0.3 \| 0.76 \| -0.46 (lower) \| \| Crypto
wallet \| -1.8 \| -1.37 \| -0.43 (even lower) \|

**Profile:** - Prioritize security above all - Less interested in money
management tools - Demographics: Older (45+), higher income

**Segment 2 (n=97, 32%): "Money Managers"** \| Feature \| Segment
Utility \| Population Utility \| Difference \|
\|---------\|-----------------\|-------------------\|------------\| \|
Spending insights \| 2.1 \| 0.76 \| +1.34 (much higher!) \| \| Budget
tracking \| 1.8 \| 0.61 \| +1.19 \| \| Savings goals \| 1.5 \| 0.21 \|
+1.29 \| \| Fraud alerts \| 1.2 \| 1.85 \| -0.65 (still important but
less) \|

**Profile:** - Want financial management tools - Proactive budgeters -
Demographics: Younger (25-35), middle income

**Segment 3 (n=75, 25%): "Transactors"** \| Feature \| Segment Utility
\| Population Utility \| Difference \|
\|---------\|-----------------\|-------------------\|------------\| \|
P2P transfers \| 2.3 \| 0.94 \| +1.36 \| \| Mobile check deposit \| 2.0
\| 1.28 \| +0.72 \| \| International transfers \| 0.8 \| -0.38 \| +1.18
(huge difference!) \| \| Budget tracking \| -0.2 \| 0.61 \| -0.81 (not
interested) \|

**Profile:** - High transaction frequency - International users -
Demographics: Diverse, includes freelancers/gig workers

------------------------------------------------------------------------

### Segment-Specific Marketing Strategy

**Security-First Users (43%):** - **Headline:** "Bank with
confidence—Instant fraud protection" - **Features to highlight:** Fraud
alerts, biometric, transaction freeze - **Channels:** Financial news
sites, retirement planning forums

**Money Managers (32%):** - **Headline:** "Take control of your
finances—AI-powered insights" - **Features to highlight:** Spending
insights, budgets, savings goals - **Channels:** Personal finance blogs,
budgeting app communities

**Transactors (25%):** - **Headline:** "Move money instantly—P2P, mobile
deposit, international" - **Features to highlight:** P2P, check deposit,
international transfers - **Channels:** Freelancer forums, international
student groups

------------------------------------------------------------------------

## Bottom Line

MaxDiff is the gold standard for preference and importance measurement
when you have many items to evaluate. It produces cleaner, more
discriminating results than rating scales while being easier for
respondents than ranking tasks. The conditional logit approach provides
rigorous statistical estimation, while hierarchical Bayes (optional)
enables individual-level insights for sophisticated segmentation.

**Think of it as:** A preference microscope that reveals fine
distinctions between items that rating scales would blur together,
giving you clear, actionable priorities backed by rigorous statistical
modeling. Whether you use the fast aggregate method or advanced Bayesian
estimation, MaxDiff transforms "everything is important" into "here's
your definitive priority ranking."

------------------------------------------------------------------------

*For questions or support, contact The Research LampPost (Pty) Ltd*

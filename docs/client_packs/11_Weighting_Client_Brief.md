# Weighting: Sample Balancing & Rim Weighting

**What This Module Does**

Weighting mathematically adjusts your survey data to match known population characteristics, correcting for over/under-representation of demographic groups. It transforms a biased sample into one that accurately represents your target population.

---

## The Fundamental Problem: Samples Are Never Perfect

**Real-world example:**

Your online panel survey of 1,000 respondents:
- 64% female (actual population: 51% female)
- 48% aged 18-34 (actual population: 29%)
- 78% urban (actual population: 67%)
- 42% college degree (actual population: 28%)

**Without weighting:** Your results reflect who responded (young, urban, educated females), not the population you care about.

**With weighting:** Each respondent gets a weight that balances the sample to match reality.

---

## Understanding Weighting: The Core Concept

### What Is a Weight?

A weight is a number that tells your analysis how many "real people" each respondent represents:

- **Weight = 1.0:** This respondent represents themselves (perfectly representative)
- **Weight = 2.0:** This respondent represents 2 people (under-represented group)
- **Weight = 0.5:** This respondent represents half a person (over-represented group)

**Example:**

You surveyed 1,000 people but only 350 were male (35%) when the population is 48% male.

**Solution:** Upweight males

```
Male weight = (Target %) / (Sample %)
           = 0.48 / 0.35
           = 1.37
```

**Result:** Each male respondent now "counts as" 1.37 people in your analysis, bringing the male percentage up to 48%.

---

## Rim Weighting (Raking): Balancing Multiple Dimensions Simultaneously

**The Challenge:** You need to balance multiple demographics at once:
- Gender (Male/Female)
- Age (18-34 / 35-54 / 55+)
- Region (Urban/Suburban/Rural)
- Education (HS / Some College / College / Advanced)

**Simple weighting fails:** If you weight on gender first, then age, you'll throw off gender. If you adjust for age, you disturb gender. Like a see-saw - fixing one side unbalances the other.

**Rim weighting (raking) solves this through iterative balancing.**

---

## How Rim Weighting Works: Step-by-Step

TURAS uses `survey::calibrate()` (industry-standard method) for rim weighting.

### The Iterative Algorithm:

**Iteration 1:**
1. Weight to match GENDER targets
2. Weight to match AGE targets (disturbs gender slightly)
3. Weight to match REGION targets (disturbs gender and age slightly)
4. Weight to match EDUCATION targets (disturbs everything slightly)

**Iteration 2:**
1. Re-weight to match GENDER (fixing the disturbance)
2. Re-weight to match AGE (fixing the disturbance)
3. Re-weight to match REGION (fixing the disturbance)
4. Re-weight to match EDUCATION (fixing the disturbance)

**Repeat until convergence:** When all targets are achieved simultaneously (typically 5-10 iterations)

### Mathematical Approach:

Rim weighting finds weights `w` that satisfy:

```
Σ(w × x) = population_total
```

For ALL demographic variables simultaneously, using calibration equations:

```
survey::calibrate(
  design,
  formula = ~ Gender + Age + Region + Education,
  population = target_margins
)
```

**Convergence criterion:** Stop when all margins match targets within epsilon (e.g., 0.0001)

---

## Real Example: Rim Weighting in Action

**Sample Data (n=1,000):**

| Demographic | Sample % | Target % | Initial Weight |
|-------------|----------|----------|----------------|
| Male | 35% | 48% | 1.37 |
| Female | 65% | 52% | 0.80 |
| Age 18-34 | 48% | 29% | 0.60 |
| Age 35-54 | 32% | 38% | 1.19 |
| Age 55+ | 20% | 33% | 1.65 |
| Urban | 78% | 67% | 0.86 |
| Suburban | 15% | 22% | 1.47 |
| Rural | 7% | 11% | 1.57 |

**Problem:** Simple weighting creates conflicts.

If we weight males to 1.37 but young males (age 18-34) should be downweighted to 0.60, what do we do?

**Rim Weighting Solution (Iteration 1):**

Respondent #1: Male, Age 18-34, Urban
- Start: weight = 1.0
- Gender adjustment: × 1.37 = 1.37
- Age adjustment: × 0.60 = 0.82
- Region adjustment: × 0.86 = 0.71
- **After iteration 1: weight = 0.71**

**After Iteration 6 (Convergence):**
- All targets achieved within ±0.1%
- Final weight for Respondent #1: 0.68
- Final weight ranges: 0.42 to 2.18

**Validation:**

| Demographic | Sample % | Weighted % | Target % | Diff |
|-------------|----------|------------|----------|------|
| Male | 35.0% | 48.0% | 48.0% | 0.0% ✓ |
| Female | 65.0% | 52.0% | 52.0% | 0.0% ✓ |
| Age 18-34 | 48.0% | 29.0% | 29.0% | 0.0% ✓ |
| Age 35-54 | 32.0% | 38.0% | 38.0% | 0.0% ✓ |
| Age 55+ | 20.0% | 33.0% | 33.0% | 0.0% ✓ |
| Urban | 78.0% | 67.0% | 67.0% | 0.0% ✓ |
| Suburban | 15.0% | 22.0% | 22.0% | 0.0% ✓ |
| Rural | 7.0% | 11.0% | 11.0% | 0.0% ✓ |

**All targets achieved!**

---

## The Cost of Weighting: Design Effect (DEFF) and Effective Sample Size

**Critical Concept:** Weighting ALWAYS reduces statistical precision.

### Design Effect (DEFF):

Measures how much precision you lose from weighting:

```
DEFF = Variance_weighted / Variance_simple_random_sample
```

**Or using weights directly:**

```
DEFF = 1 + CV²
where CV = coefficient of variation of weights = SD(weights) / mean(weights)
```

**Example:**

Unweighted data:
- All weights = 1.0
- DEFF = 1.0 (no precision loss)

Weighted data:
- Weights: min=0.42, max=2.18, mean=1.0, SD=0.38
- CV = 0.38 / 1.0 = 0.38
- DEFF = 1 + 0.38² = 1 + 0.14 = 1.14

### Effective Sample Size:

```
n_eff = n / DEFF
```

**Example:**
- Original n = 1,000
- DEFF = 1.14
- **n_eff = 1,000 / 1.14 = 877**

**What this means:** Your weighted sample of 1,000 has the statistical power of only 877 unweighted respondents.

### Impact on Margin of Error:

**Unweighted (n = 1,000):**
- MOE at 50% = ±3.1%

**Weighted (n_eff = 877):**
- MOE at 50% = ±3.3%

**Precision loss = 6.5%** (acceptable)

---

## Weighting Efficiency: How Much Precision Did You Lose?

```
Efficiency = n_eff / n × 100%
```

**Efficiency Guidelines:**

| Efficiency | DEFF | Assessment |
|------------|------|------------|
| 95-100% | 1.00-1.05 | Excellent - minimal loss |
| 85-94% | 1.06-1.18 | Good - acceptable loss |
| 70-84% | 1.19-1.43 | Fair - noticeable loss |
| 50-69% | 1.45-2.00 | Poor - significant loss |
| <50% | >2.00 | Problematic - consider trimming |

**Example from above:**
- Efficiency = 877 / 1,000 = 87.7%
- Rating: **Good** - acceptable precision loss

---

## Kish's Approximation: Quick Effective n Calculation

TURAS uses **Kish's formula** for effective sample size:

```
n_eff = (Σw)² / Σ(w²)
```

**Step-by-Step Example:**

5 respondents with weights: [2.0, 1.5, 1.0, 0.8, 0.5]

1. **Sum of weights:**
   - Σw = 2.0 + 1.5 + 1.0 + 0.8 + 0.5 = 5.8

2. **Sum of squared weights:**
   - Σ(w²) = 4.0 + 2.25 + 1.0 + 0.64 + 0.25 = 8.14

3. **Calculate effective n:**
   - n_eff = 5.8² / 8.14 = 33.64 / 8.14 = **4.13**

**Result:** 5 weighted respondents = 4.13 unweighted respondents (82.6% efficiency)

**For full dataset (n=1,000):**

Weights: min=0.42, max=2.18, mean=1.0
- Σw = 1,000 (by design, sum of weights = original n)
- Σ(w²) = 1,140 (calculated from weight distribution)
- n_eff = 1,000² / 1,140 = 877

---

## Convergence: How Do You Know When Weights Are Final?

Rim weighting iterates until all targets are met. **Convergence** means the algorithm has found a stable solution.

### Convergence Criteria (survey::calibrate):

```
max(|achieved_margin - target_margin|) < epsilon
```

Where:
- `epsilon` = tolerance (default: 1e-7, extremely tight)
- Checks EVERY demographic category

**Example Convergence Check:**

**Iteration 5:**
- Gender male: 48.12% vs target 48.00% → diff = 0.12%
- Age 18-34: 28.95% vs target 29.00% → diff = 0.05%
- Urban: 67.08% vs target 67.00% → diff = 0.08%
- Max difference = 0.12% > epsilon → **Not converged**

**Iteration 6:**
- All differences < 0.01% → **Converged!**

**What TURAS does:**
- Reports convergence status
- Shows number of iterations (typically 5-10)
- Flags if convergence fails (rare, indicates incompatible targets)

### Convergence Failure:

**Possible causes:**
- Incompatible targets (e.g., want 70% male AND 70% female)
- Extreme weights required (need trimming/capping)
- Small sample with too many weighting cells

**TURAS response:**
- Returns TRS refusal: `WEIGHT_CONVERGENCE_FAILURE`
- Suggests reducing weighting variables or adjusting targets
- May recommend weight trimming

---

## When to Weight vs When NOT to Weight

### ALWAYS Weight When:

✅ **Sample doesn't match population:**
- Panel recruited sample skews young/urban/educated
- Convenience sample with known biases
- Tracking study where sample composition drifts

✅ **Client requires representativeness:**
- "Nationally representative" claims
- Need to project to population totals
- Comparing waves with different sample compositions

✅ **Known population benchmarks available:**
- Census data for demographics
- Industry data for firmographics
- Client customer database for known characteristics

### SKIP Weighting When:

❌ **Random probability sample:**
- RDD (Random Digit Dial) with good response rates
- Address-based sampling with balanced coverage
- Sample already matches population

❌ **Exploratory research:**
- Focus group follow-up (not claiming representativeness)
- Concept testing (relative preferences matter, not absolute percentages)
- Internal employee survey (census, not sample)

❌ **No reliable population targets:**
- New/emerging markets with unknown demographics
- Specialized populations without benchmarks
- Can't trust the "target" data quality

❌ **Very small samples:**
- n < 100: Weighting adds more noise than it fixes
- Precision loss outweighs bias correction

---

## Decision Tree: Should You Weight This Survey?

```
Do you have a random probability sample?
│
├─ YES → Generally DON'T weight (already representative)
│   │
│   └─ Does sample match population demographics?
│       │
│       ├─ YES → No weighting needed
│       │
│       └─ NO → Consider light weighting (but investigate why)
│
└─ NO (non-probability sample) → Does sample match population?
    │
    ├─ YES → No weighting needed
    │
    └─ NO → Do you have reliable population targets?
        │
        ├─ YES → WEIGHT IT
        │   │
        │   └─ After weighting, check:
        │       - DEFF < 2.0? → Good, proceed
        │       - DEFF > 2.0? → Consider trimming or fewer variables
        │
        └─ NO → DON'T weight (you'll make it worse)
            Report as "convenience sample, not population-representative"
```

---

## Proper Interpretation Examples

### Example 1: Successful Weighting

**Survey:** Consumer brand tracker (n=1,500, online panel)

**Before Weighting:**
- Product satisfaction: 78%
- Brand awareness: 62%
- Purchase intent: 45%

**Weighting Applied:**
- Variables: Gender, Age (4 groups), Region (urban/suburban/rural)
- Convergence: 7 iterations
- DEFF: 1.35
- n_eff: 1,111 (74% efficiency)

**After Weighting:**
- Product satisfaction: 73%
- Brand awareness: 58%
- Purchase intent: 41%

**✅ CORRECT Interpretation:**
"Results are weighted to match census demographics (gender, age, region). The unweighted sample over-represented younger, urban respondents who were more positive about the brand. After weighting, satisfaction dropped from 78% to 73%, providing a more accurate population estimate. The weighting efficiency is 74% (DEFF=1.35), meaning our effective sample size is 1,111—still sufficient for reliable estimates."

**Why this matters:** The 5-point drop (78% → 73%) reveals sample bias that weighting corrected.

---

### Example 2: Heavy Weighting (DEFF Too High)

**Survey:** Regional study (n=800)

**Weighting Applied:**
- Variables: Gender, Age (6 groups), Region (8 groups), Income (5 groups), Education (4 groups)
- Convergence: 12 iterations
- **DEFF: 2.8**
- **n_eff: 286** (36% efficiency)
- Weight range: 0.15 to 4.5

**✅ CORRECT Interpretation:**
"Weighting on five variables simultaneously resulted in high design effect (DEFF=2.8) and low efficiency (36%), reducing the effective sample from 800 to 286. This degree of precision loss is problematic and suggests the sample is poorly matched to the population or we're using too many weighting variables. Recommendation: Reduce to 3 weighting variables (gender, age, region) or increase sample size to 2,000+ for stable weights."

**What to do:**
- Trim extreme weights (cap at 3.0)
- Remove least important weighting variable(s)
- Accept that sample isn't perfectly representative

---

### Example 3: Tracking Study Wave Comparison

**Q1 Survey:**
- n = 1,200
- DEFF = 1.15
- Satisfaction = 68% (weighted)

**Q2 Survey:**
- n = 1,150
- DEFF = 1.22
- Satisfaction = 71% (weighted)

**Comparison:**
- Change: +3 points
- Standard error: ±2.9 points (accounting for DEFF in both waves)
- Z = 1.03, p = 0.30
- **Not statistically significant**

**✅ CORRECT Interpretation:**
"Satisfaction showed a numeric increase from Q1 to Q2 (68% to 71%), but after accounting for weighting efficiency in both waves (DEFF=1.15 and 1.22), this 3-point change is not statistically significant (p=0.30). While the trend is positive, we cannot distinguish it from random sampling variation. Continue monitoring in Q3 to see if the pattern persists."

**Why DEFF matters:** Without accounting for weighting, you might wrongly conclude the change is significant.

---

### Example 4: When NOT to Weight

**Survey:** B2B executive survey (n=150, LinkedIn recruitment)

**Sample Composition:**
- 68% C-suite
- 55% companies >$100M revenue
- 72% technology sector

**Known Population:**
- 15% C-suite
- 20% companies >$100M revenue
- 25% technology sector

**If we weight:**
- C-suite downweighted to 0.22 (from 68% to 15%)
- Large company downweighted to 0.36
- Tech downweighted to 0.35
- Expected DEFF > 4.0
- n_eff < 40 (catastrophic)

**✅ CORRECT Interpretation:**
"This sample is NOT population-representative and cannot be weighted without destroying statistical power (estimated n_eff < 40). Results represent the views of C-suite technology executives at large firms, not the broader business population. Report findings with this caveat clearly stated. Do not attempt to project to 'all businesses.'"

**Why NOT weighting is correct:** Sometimes admitting bias is better than pretending weights fix it.

---

## TURAS v2.0: survey::calibrate() Migration

**Important:** TURAS Weighting v2.0 uses `survey::calibrate()` instead of the legacy `anesrake` package.

### Why the Change:

| Aspect | survey::calibrate() | anesrake (legacy) |
|--------|-------------------|------------------|
| **Maintenance** | Actively maintained | Development stalled |
| **Method** | Modern calibration with weight bounds | Iterative raking |
| **Convergence** | Built-in bounds, robust | Can diverge with extreme weights |
| **Integration** | Part of survey package ecosystem | Standalone package |
| **Stability** | Tested with CRAN | Occasional issues |

### What Changed:

**Configuration (same):**
- You still specify the same targets
- You still get the same output structure
- Excel templates unchanged

**Under the Hood (improved):**
- More robust convergence
- Better handling of edge cases
- Integrated with survey design objects

**If You're Upgrading:**
- Results may differ slightly (usually < 0.5%)
- Convergence might be faster
- Extreme weight behavior improved

---

## What You Get from TURAS Weighting Module

### Excel Output Files:

**1. Weighted Dataset:**
- Original data + weight column(s)
- Ready for analysis in Tabs or other modules

**2. Weighting Summary Report:**
- Before/after comparison tables
- Achievement of targets (target % vs weighted %)
- Convergence diagnostics
- Efficiency metrics

**3. Quality Checks:**
- Weight distribution (min, max, mean, SD, percentiles)
- DEFF and effective sample size
- Extreme weight flagging
- Efficiency score

**4. Validation Output:**
- Chi-square goodness-of-fit tests
- Margin achievement by variable
- Iteration log

---

## Technology Used

| Package | Why We Use It |
|---------|---------------|
| **survey** | Rim weighting via `calibrate()` - industry standard |
| **data.table** | Fast iteration and weight calculations |
| **openxlsx** | Professional Excel output |

**Note:** v2.0 migrated from `anesrake` to `survey::calibrate()` for long-term maintainability and robustness.

---

## Strengths

✅ **Industry-Standard Method:** survey::calibrate() is the modern gold standard
✅ **Iterative Convergence:** Achieves all targets simultaneously
✅ **Efficiency Metrics:** Quantifies information loss transparently
✅ **Extreme Weight Control:** Built-in bounds prevent domination by single respondents
✅ **Validation Built-In:** Confirms targets achieved before finishing
✅ **Flexible:** Supports any demographic variables
✅ **Large Sample Efficient:** Handles 10,000+ respondents

---

## Limitations

⚠️ **Requires Target Data:** Need reliable population benchmarks (census, industry data)
⚠️ **ALWAYS Reduces Precision:** Weighting increases margin of error
⚠️ **Can't Fix Bad Sampling:** Weights correct imbalance but can't fix fundamental sampling flaws
⚠️ **Assumes Random Within Cells:** Works best when non-response is random within demographic groups
⚠️ **Complexity Limits:** 4+ weighting variables can create convergence issues or extreme weights

---

## Best Use Cases

**Ideal For:**
- Online panels (tend to skew young, female, urban)
- Any sample that doesn't match census demographics
- Pre/post campaign measurement (ensure comparable samples)
- Tracking studies (weight each wave consistently)
- National surveys requiring geographic representativeness

**Not Ideal For:**
- Random probability samples (already representative)
- Very small samples (<100) where weighting makes precision worse
- When you don't have reliable population targets
- Exploratory research where representation isn't critical

---

## Quality & Reliability

**Quality Score:** 85/100
**Production Ready:** Yes
**Error Handling:** Good - validates targets and convergence
**Testing Status:** Core algorithm tested; expanding edge case coverage

---

## What's Next (Future Enhancements)

**Phase 1 (Planned):**
- Propensity score weighting (non-response adjustment)
- Automatic target fetching from census APIs
- Interactive weight optimization (trim extremes while hitting targets)

**Phase 2 (Future):**
- Real-time weighting during data collection
- Machine learning-based weight calibration
- Integration with sample procurement for optimal targeting

---

## Key Takeaways

### Core Principles:

✓ **Weighting corrects sample imbalance** to match population
✓ **Rim weighting balances multiple dimensions** simultaneously through iteration
✓ **DEFF measures precision loss** - keep below 2.0 if possible
✓ **Effective n is what matters** for statistical power, not actual n
✓ **Convergence ensures all targets met** simultaneously

### Practical Guidelines:

✓ Always check DEFF and efficiency after weighting
✓ Flag when DEFF > 1.5 (noticeable precision loss)
✓ Consider trimming if DEFF > 2.0 (significant precision loss)
✓ Use 3-4 weighting variables maximum for stable weights
✓ Validate targets achieved before using weights

### Statistical Honesty:

✓ Weighting reduces precision - acknowledge this in reporting
✓ Heavy weighting (DEFF > 2) means your sample was poorly matched
✓ Sometimes NOT weighting (and caveating) is more honest than bad weights
✓ Always report effective n alongside actual n for weighted data

---

## Bottom Line

Weighting is your insurance policy against sample bias. When your survey respondents don't mirror the population you care about, rim weighting mathematically corrects the imbalance using industry-standard iterative algorithms (`survey::calibrate()`). TURAS ensures your results represent the true population, not just who happened to respond—while transparently reporting the precision cost through DEFF and effective sample size.

**Think of it as:** A mathematical adjustment that transforms your 1,000 biased respondents into an accurate voice for your entire target population, with built-in quality controls ensuring you haven't traded accuracy for unacceptable precision loss.

**The honest standard:** If DEFF > 2.0, you should question whether weighting is making things better or worse. TURAS shows you the numbers so you can make the right call.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*

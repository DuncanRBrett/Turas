# Weighting: Sample Balancing & Rim Weighting

**What This Module Does**
Weighting adjusts your survey data to match known population characteristics, correcting for over/under-representation of demographic groups. It ensures your sample accurately represents the target population.

---

## What Problem Does It Solve?

Survey samples rarely perfectly match the population:
- Too many women, not enough men
- Over-representation of younger respondents
- Geographic imbalance (urban vs. rural)
- Education or income skew

**Weighting mathematically corrects these imbalances so results reflect the true population.**

---

## How It Works

You provide:
- **Survey data** with demographics (age, gender, region, etc.)
- **Population targets** (what % should be male, in each age group, etc.)
- **Weighting variables** (which demographics to balance on)

The module:
1. **Calculates weights** for each respondent
2. **Balances multiple dimensions** simultaneously (age AND gender AND region)
3. **Applies efficiency checks** (prevents extreme weights)
4. **Validates results** (confirms targets are achieved)
5. **Exports weighted data** ready for analysis

**Example:**
- Your sample: 65% female, 35% male
- Population: 52% female, 48% male
- Module creates weights: Males upweighted (1.37x), Females downweighted (0.80x)

---

## What You Get

**Weight Calculations:**
- Individual weight for every respondent
- Summary statistics (min, max, mean, median weight)
- Efficiency metrics (effective sample size)
- Trimming/capping recommendations if needed

**Validation Reports:**
- Before/after comparison tables
- Achievement of targets (weighted % vs. target %)
- Chi-square goodness-of-fit tests
- Convergence diagnostics

**Quality Checks:**
- Extreme weight flagging (outliers)
- Effective sample size calculation
- Design effect estimates
- Weighting efficiency score

**Excel Outputs:**
- Weighted data file (original data + weight column)
- Weighting summary report
- Before/after demographics tables

---

## Technology Used

| Package | Why We Use It |
|---------|---------------|
| **anesrake** | Rim weighting algorithm (industry standard) |
| **survey** | Survey design objects and weighted analysis |
| **weights** | Weight calibration and diagnostics |
| **data.table** | Fast weighting iteration and convergence |

---

## Strengths

✅ **Rim Weighting:** Balances multiple dimensions simultaneously
✅ **Iterative Algorithm:** Converges to optimal solution
✅ **Efficiency Metrics:** Quantifies information loss from weighting
✅ **Extreme Weight Control:** Prevents individual respondents from dominating
✅ **Validation Built-In:** Confirms targets achieved
✅ **Flexible Targets:** Supports any demographic variables
✅ **Large Sample Efficient:** Handles datasets with 10,000+ respondents

---

## Limitations

⚠️ **Requires Target Data:** Need to know population distribution (census, industry data)
⚠️ **Reduces Effective Sample:** Weighting always increases margin of error
⚠️ **Can't Fix Bad Sampling:** Weights correct imbalance but don't fix fundamental sampling flaws
⚠️ **Assumes MCAR:** Works best when non-response is random within demographic groups
⚠️ **Multiple Dimensions Complexity:** 4+ weighting variables can create convergence issues

---

## Statistical Concepts Explained (Plain English)

**What Is a Weight?**
A number that tells the analysis how many "real people" each respondent represents:
- Weight = 1.0: Respondent represents themselves
- Weight = 2.0: Respondent represents 2 people in the population
- Weight = 0.5: Respondent represents half a person (over-represented group)

**Rim Weighting (Raking):**
Iterative process that balances multiple demographics simultaneously:
1. Weight to match age distribution
2. Then adjust to match gender (while staying close to age targets)
3. Then adjust to match region (while staying close to age and gender)
4. Repeat until all targets achieved

Like juggling—each adjustment slightly affects others, so iterate until balanced.

**Effective Sample Size:**
Weighting "costs" you precision. Formula:
- Effective n = (Σ weights)² / Σ(weights²)
- Example: n=1000 sample might have effective n=850 after weighting
- Means margin of error increases as if you had smaller sample

**Weighting Efficiency:**
Percentage of original sample information retained:
- 100% = No information loss (all weights = 1)
- 85% = Lost 15% of statistical power due to weighting
- <70% = Problematic, consider trimming extreme weights

---

## Best Use Cases

**Ideal For:**
- Online panels (tend to skew young, female, urban)
- Any sample that doesn't match census demographics
- Pre-post campaign measurement (ensure comparable samples)
- Tracking studies (weight each wave consistently)
- National surveys requiring geographic representativeness

**Not Ideal For:**
- Random probability samples (already representative)
- Very small samples (<100) where weighting makes things worse
- When you don't have reliable population targets
- Exploratory research where representation isn't critical

---

## Quality & Reliability

**Quality Score:** 85/100
**Production Ready:** Yes
**Error Handling:** Good - Validates targets and convergence
**Testing Status:** Core algorithm tested; expanding edge case coverage

---

## Example Outputs

**Weighting Summary Report:**

**Population Targets:**
| Variable | Category | Sample % | Target % | Weighted % |
|----------|----------|----------|----------|------------|
| Gender | Male | 38% | 48% | 48% ✓ |
| Gender | Female | 62% | 52% | 52% ✓ |
| Age | 18-34 | 45% | 32% | 32% ✓ |
| Age | 35-54 | 35% | 38% | 38% ✓ |
| Age | 55+ | 20% | 30% | 30% ✓ |
| Region | Urban | 72% | 65% | 65% ✓ |
| Region | Rural | 28% | 35% | 35% ✓ |

**Weighting Statistics:**
- Original sample size: 1,000
- Effective sample size: 847
- Weighting efficiency: 84.7%
- Min weight: 0.42
- Max weight: 2.18
- Mean weight: 1.00
- Convergence: Achieved in 6 iterations

**Recommendation:** Good weighting efficiency (>80%). No extreme weights detected. Safe to proceed with weighted analysis.

---

## Real-World Example

**Scenario:** National consumer survey (online panel)

**Sample Demographics (n=1,500):**
- 64% female (target: 51%)
- 48% age 18-34 (target: 29%)
- 78% urban (target: 67%)
- Education skewed high (42% college degree vs. 28% target)

**Weighting Variables:**
- Gender (male/female)
- Age (4 groups: 18-34, 35-49, 50-64, 65+)
- Region (urban/suburban/rural)
- Education (HS or less, Some college, College degree, Advanced degree)

**Weighting Results:**
- Convergence: 8 iterations
- Effective sample: 1,245 (83% efficiency)
- All targets achieved within 0.5%
- Max weight: 2.4 (capped at 3.0 per best practices)

**Impact on Results:**
| Metric | Unweighted | Weighted | Difference |
|--------|-----------|----------|------------|
| Product Satisfaction | 78% | 73% | -5 pts |
| Brand Awareness | 62% | 58% | -4 pts |
| Purchase Intent | 45% | 41% | -4 pts |

**Interpretation:** Unweighted data over-estimated positivity because younger, urban, educated respondents were over-represented and more favorable. Weighting corrected this bias.

---

## When to Weight

**Always Weight When:**
- Sample demographics don't match population
- Using non-probability samples (panels, online, convenience)
- Client requires nationally representative results
- Tracking studies (for wave-to-wave comparability)

**Can Skip Weighting When:**
- Using probability sampling (random digit dial, address-based)
- Sample closely matches population without adjustment
- Exploratory research where representation isn't critical
- Very small samples where weighting adds more noise than value

---

## What's Next (Future Enhancements)

**Coming Soon:**
- Propensity score weighting (for non-response adjustment)
- Automatic target fetching from census APIs
- Interactive weight optimization (trim extremes while hitting targets)

**Future Vision:**
- Real-time weighting during data collection
- Machine learning-based weight calibration
- Integration with sample procurement for optimal targeting

---

## Bottom Line

Weighting is your insurance policy against sample bias. When your survey respondents don't mirror the population you're trying to understand, weighting mathematically corrects the imbalance. Using industry-standard rim weighting algorithms with built-in quality controls, the module ensures your results represent the true population, not just who happened to respond to your survey.

**Think of it as:** A mathematical adjustment that ensures your 1,000 respondents accurately speak for your entire target population, correcting for the inevitable imbalances that occur in real-world sampling.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*

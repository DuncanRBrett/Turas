# Confidence: Understanding Uncertainty in Survey Estimates

**What This Module Does**

Confidence calculates precision estimates around survey percentages and means, telling you how reliable your estimates are. But understanding what these numbers mean—and when they're valid—is critical for honest reporting.

------------------------------------------------------------------------

## The Fundamental Question: Do You Have a Random Sample?

**This is the most important question for any confidence or credibility interval calculation.**

### Random Samples (Probability Samples)

**What they are:** - Every member of your target population had a *known, non-zero probability* of being selected - Examples: Random digit dialing (RDD), address-based sampling, customer database random selection - Selection was by chance, not self-selection

**What you can calculate:** - **True confidence intervals** with statistical guarantees - Can say: "We're 95% confident the true population value is between X% and Y%" - Margin of error is statistically defensible

**Why it works:** - Sampling theory provides mathematical guarantees - Repeated samples would produce estimates that vary in a predictable way - Central Limit Theorem applies

------------------------------------------------------------------------

### Non-Random Samples (Non-Probability Samples)

**What they are:** - Online panels (respondents opt-in) - Social media polls - Convenience samples - Volunteer surveys - Any sample where some people *chose* to participate

**What you CANNOT calculate:** - Traditional confidence intervals (the math doesn't apply) - True margin of error with frequency guarantees

**What you CAN calculate:** - **Descriptive precision intervals** showing variability *within* your sample - Think of them as "if this *were* a random sample, the margin would be..." - Useful for *relative* precision (comparing subgroup reliability) - **Bayesian credibility intervals** (incorporating prior information or expressing uncertainty)

**Critical distinction:** - Random sample: "95% confident the true value is 61-69%" - Non-random sample: "The estimate is 65%, and if this were random, the margin would be ±4%, but unknown biases may exist"

------------------------------------------------------------------------

## Understanding Confidence Intervals vs Credibility Intervals

### Confidence Intervals (Frequentist)

**What they are:** - Based on sampling theory and probability - **Interpretation:** "If we repeated this survey many times, 95% of the intervals calculated would contain the true population value" - The interval is random (varies across samples), the true value is fixed

**Critical misunderstanding to avoid:** - ❌ WRONG: "There's a 95% probability the true value is in this interval" - ✓ RIGHT: "We're 95% confident this interval captures the true value" (based on the method's long-run properties)

**Valid for:** Random samples only

------------------------------------------------------------------------

### Credibility Intervals (Bayesian)

**What they are:** - Based on Bayesian statistical theory - **Interpretation:** "Given our data and prior beliefs, there's a 95% probability the true value lies in this interval" - The true value is treated as a random variable with a probability distribution

**How they differ:** - Confidence intervals: frequency-based (long-run properties) - Credibility intervals: probability-based (degree of belief)

**Uses:** Prior distribution (can be uninformed/default or based on previous data)

**Valid for:** Any sample; must state prior assumptions in reporting

------------------------------------------------------------------------

## Methods Available in TURAS Confidence Module

TURAS doesn't ask you to "choose" between methods. Instead, you configure which methods to run, and TURAS calculates all of them. This lets you compare approaches and use what's appropriate for your situation.

### For Proportions (Percentages):

#### 1. Normal Approximation (Margin of Error / MOE)

**What it does:** - Uses the classic formula: p ± z × √(p(1-p)/n) - Simple, fast, widely recognized

**When TURAS uses it:** - When you enable Run_MOE = "Y" - Automatically calculated for all proportions

**Strengths:** - Industry-standard approach - Easy to communicate ("margin of error ±3%") - Fast calculation

**Weaknesses:** - Can produce impossible values (e.g., -2% to 12% for small proportions) - Poor performance when p \< 10% or p \> 90% - Underestimates uncertainty for small samples

**Example:** - n=100, 10% say "yes" - Normal approximation: 4.1% to 15.9% - Problem: Assumes normal distribution (not perfect for proportions)

**When it's appropriate:** - Large samples (n \> 100) - Moderate proportions (20% \< p \< 80%) - Client expects "traditional" margin of error

------------------------------------------------------------------------

#### 2. Wilson Score Interval (Recommended Default)

**What it does:** - Adjusts the interval calculation to avoid impossible values - Accounts for the fact that proportions must be between 0% and 100% - Produces asymmetric intervals near extremes (which is correct!)

**When TURAS uses it:** - When you enable Use_Wilson = "Y" - Can be flagged to auto-activate for extreme proportions

**Mathematical approach:** - Inverts the hypothesis test rather than using normal approximation - Creates intervals that never go below 0% or above 100%

**Example:** - n=100, 10% say "yes" - Wilson interval: 5.4% to 17.6% - Notice: Can't go negative, wider on upper side (reflecting true uncertainty)

**Strengths:** - ✅ Statistically superior to normal approximation - ✅ Works well for any sample size - ✅ Handles extreme proportions (near 0% or 100%) correctly - ✅ Recommended by professional statisticians (Agresti & Coull, 1998)

**Limitations:** - Asymmetric intervals may surprise non-technical audiences - Slightly more complex to explain than "p ± MOE"

**When it's appropriate:** - **Default choice for all random sample proportions** - Especially when n \< 100 - Especially when p \< 10% or p \> 90% - Publication-quality reporting

------------------------------------------------------------------------

#### 3. Bootstrap Interval (Resampling Method)

**What it actually does - Step by Step:**

Imagine you have n=500 survey respondents in your dataset.

**Step 1: Treat your sample as a mini-population** - Your 500 respondents become a "population" to sample from

**Step 2: Resample with replacement** - Randomly draw 500 respondents from your sample - Some people get picked multiple times, some not at all - This is "sampling with replacement" - If your data is weighted, sampling is proportional to weights - Calculate the percentage for this resample

**Step 3: Repeat many times** - Do Step 2 exactly 5,000 times (TURAS default) - You now have 5,000 different percentage estimates

**Step 4: Find percentiles** - Sort those 5,000 estimates from lowest to highest - 95% interval: Take the 2.5th percentile and 97.5th percentile - That's your bootstrap interval

**Example:** - Original sample: 35% satisfied (n=500) - After 5,000 resamples: estimates range from 31.2% to 38.7% - Bootstrap 95% interval: [31%, 39%]

**When TURAS uses it:** - When you enable Run_Bootstrap = "Y"

**What bootstrap actually shows:** - How variable your estimate would be if you repeatedly sampled from *this type of population* - For **random samples:** Approximates traditional confidence interval - For **non-random samples:** Shows sampling variability only (NOT population accuracy)

**Critical understanding:** - ✅ Bootstrap DOES show variability from resampling - ❌ Bootstrap does NOT fix selection bias - ❌ Bootstrap does NOT make non-random samples representative

**For non-random samples:** Correct interpretation: "If we repeatedly sampled from this type of panel, we'd see variation of ±4%, but unknown biases in who opted-in may exist."

**Strengths:** - No distributional assumptions required - Correctly handles complex weighting schemes - Works for any statistic (not just simple proportions) - Provides validation of other methods

**Limitations:** - Computationally intensive (takes a few seconds) - Results vary slightly between runs (random process) - Requires adequate sample size (n \> 30 minimum)

**When it's appropriate:** - Complex weighted designs - Non-random samples (for descriptive precision) - Validation of parametric methods - When theoretical assumptions unclear

------------------------------------------------------------------------

#### 4. Bayesian Credibility Interval (Prior-Based)

**What it does:** - Combines your data with prior information using Bayes' theorem - Produces a credibility interval (not a confidence interval) - Interpretation: "95% probability the true value is in this range" (given the prior)

**When TURAS uses it:** - When you enable Run_Credible = "Y" - Requires you to specify prior parameters OR uses default uninformed prior

**Two Approaches:**

##### A. Uninformed Prior (Jeffrey's Prior)

**What it assumes:** - Beta(0.5, 0.5) prior distribution - Minimal prior information - Lets the data dominate

**When to use:** - First-time measurement (no previous data) - You want Bayesian credibility interval without strong prior beliefs - Comparable to frequency-based methods but with probability interpretation

**Example:** - n=100, 10 say "yes" - Prior: Beta(0.5, 0.5) - Posterior: Beta(10.5, 90.5) - 95% credibility interval: [5.6%, 17.1%] - Interpretation: "95% probability the true proportion is between 5.6% and 17.1%"

------------------------------------------------------------------------

##### B. Informed Prior (Previous Wave Data)

**What it assumes:** - You have prior information (e.g., from last quarter's survey) - Prior is specified as: prior_mean and prior_n (effective prior sample size)

**Configuration in TURAS:**

```         
Prior_Mean = 0.42    (42% in previous wave)
Prior_N = 500        (previous wave had n=500)
```

**What TURAS does:** - Converts to Beta distribution parameters: - α₀ = 0.42 × 500 = 210 - β₀ = 0.58 × 500 = 290 - Combines with current data using Bayesian updating

**Example:** - Previous wave: 42% satisfied (n=500) - Current wave: 38% satisfied (n=300) - Posterior combines both waves - Credibility interval will be "pulled" toward 42% by the prior - Interval is narrower than current wave alone (information from both waves)

**How the prior strength works:** - **Small prior_n (e.g., 50):** Weak prior, data dominates - **Large prior_n (e.g., 1000):** Strong prior, pulls estimate toward prior_mean

**When to use:** - Tracking studies (use previous wave as prior) - Small current sample that needs "borrowing strength" - You trust the prior information

**Caution:** - Prior choice is subjective - Must explicitly state prior assumptions in reporting - Can be controversial in some settings

------------------------------------------------------------------------

## For Means (Rating Scales, Continuous Variables):

TURAS provides three approaches for means:

### 1. t-Distribution Confidence Interval (Standard Method)

**What it does:** - Uses Student's t-distribution for small to moderate samples - Accounts for uncertainty in estimating standard deviation

**Formula:** - SE = SD / √n - CI = mean ± t × SE - Where t comes from t-distribution with n-1 degrees of freedom

**For weighted data:** - Calculates weighted mean and weighted variance - Uses effective n (accounting for weight efficiency loss)

**When TURAS uses it:** - Always calculated for mean statistics (Run_MOE = "Y" for means)

**When appropriate:** - Random samples - Approximately normal distributions (or large n by CLT) - Standard industry practice

------------------------------------------------------------------------

### 2. Bootstrap Confidence Interval for Means

**Same resampling approach as for proportions, but:** - Resamples calculate the mean (not proportion) - Handles non-normal distributions - Correctly weights each resample

**When TURAS uses it:** - Run_Bootstrap = "Y" for mean statistics

**When appropriate:** - Skewed distributions - Weighted data with complex designs - Validating t-based intervals

------------------------------------------------------------------------

### 3. Bayesian Credibility Interval for Means

**What it does:** - Uses Normal-Normal conjugate prior - Combines prior beliefs about the mean with current data

**Uninformed prior:** - Very weak prior (large prior variance) - Data dominates

**Informed prior (tracking studies):**

```         
Prior_Mean = 7.2      (previous wave average satisfaction)
Prior_SD = 1.5        (prior uncertainty)
Prior_N = 500         (prior effective sample size)
```

**How it works:** - Prior and data combined using precision weighting - Higher precision (lower variance) gets more weight - Posterior mean is weighted average of prior_mean and data_mean

**When TURAS uses it:** - Run_Credible = "Y" with Prior_Mean, Prior_SD, Prior_N specified

**Example:** - Previous: mean = 7.2, SD = 1.5, n = 500 - Current: mean = 7.6, SD = 1.8, n = 300 - Posterior will be between 7.2 and 7.6 (precision-weighted) - Credibility interval narrower than using current data alone

------------------------------------------------------------------------

## Weighted Data: Critical Adjustments

**Why weights complicate uncertainty:** - Not all respondents count equally - Effective sample size \< actual sample size - Variance inflation from weighting

### Design Effect (DEFF)

**What it measures:** How much precision you lose from weighting/clustering:

```         
DEFF = Variance_weighted / Variance_simple_random_sample
```

**Example:** - Unweighted data: n=1000, MOE = ±3.1% - Weighted data: DEFF=1.5, Effective n = 667, MOE = ±3.8% - Lost 22% precision due to weighting

### Effective Sample Size

**Formula:**

```         
n_eff = n / DEFF
```

Or using Kish's formula:

```         
n_eff = (Σw)² / (n × Σw²)
```

**What TURAS does:** - Automatically calculates effective n for weighted data - Uses effective n in all interval calculations - Reports both actual n and effective n

**Weighting efficiency:**

```         
Efficiency = n_eff / n
```

-   Efficiency \< 1.0 indicates variance inflation
-   Efficiency = 0.70 means 30% loss of precision
-   TURAS reports this so you understand the cost of weighting

------------------------------------------------------------------------

## What You Get from TURAS Confidence Module

### Output Structure

For each estimate, TURAS can provide (depending on your configuration):

**Always included:** - Point estimate (the percentage or mean from your data) - Sample size (actual n) - Effective sample size (for weighted data)

**If Run_MOE = "Y":** - Normal approximation CI (lower, upper, margin of error)

**If Use_Wilson = "Y":** - Wilson score CI (lower, upper)

**If Run_Bootstrap = "Y":** - Bootstrap CI (lower, upper) - Number of bootstrap iterations used

**If Run_Credible = "Y":** - Bayesian credibility interval (lower, upper) - Posterior mean (may differ from sample mean if using informative prior) - Prior type (uninformed or informed)

**Batch Processing:** - Calculate intervals for hundreds of estimates at once - Parallel processing for bootstrap (faster computation) - Consistent method applied across all variables

------------------------------------------------------------------------

## Decision Guide: What Should I Run?

You don't have to choose just one method. TURAS calculates whichever you enable. Here's guidance:

### For Random Samples (Probability Samples):

**Minimum (always run):** - Use_Wilson = "Y" → Professional-quality confidence intervals

**Standard analysis:** - Run_MOE = "Y" → Clients expect traditional margin of error - Use_Wilson = "Y" → Statistically superior method

**Comprehensive analysis:** - Run_MOE = "Y" - Use_Wilson = "Y" - Run_Bootstrap = "Y" → Validation of parametric methods

**Tracking studies with history:** - Use_Wilson = "Y" - Run_Credible = "Y" with Prior_Mean and Prior_N from previous wave

### For Non-Random Samples (Panels, Opt-in, Convenience):

**Descriptive precision:** - Run_Bootstrap = "Y" → Shows sampling variability - Clearly caveat: "Indicative precision only; selection bias may exist"

**If you have strong prior data:** - Run_Credible = "Y" with informed prior - Interpret as Bayesian credibility, not frequency-based confidence

**What NOT to run:** - Don't present Run_MOE or Use_Wilson as "confidence intervals" for non-random samples - They show mathematical precision, not population inference validity

------------------------------------------------------------------------

## Proper Interpretation Examples

### Example 1: Random Sample with Wilson Interval

**Data:** - Random digit dial survey, n=600 - 68% support policy - 95% Wilson CI: 64.3% to 71.5%

**Correct statement:** "Based on a random sample of 600 respondents, 68% support the policy. We are 95% confident that between 64% and 72% of the population support this policy."

**Incorrect statement:** "There's a 95% probability the true value is in this range." ❌ (This is Bayesian interpretation, not frequentist confidence interval)

------------------------------------------------------------------------

### Example 2: Online Panel with Bootstrap Interval

**Data:** - Opt-in online panel, n=1,000 - 45% prefer Brand A - Bootstrap 95% interval: 42% to 48%

**Correct statement:** "In this sample of 1,000 opt-in panel members, 45% prefer Brand A. The bootstrap interval (42-48%) shows the sampling variability, indicating the estimate is fairly stable. However, as an opt-in panel, unknown selection biases may affect whether this represents the broader population."

**Incorrect statement:** "We are 95% confident that 42-48% of all consumers prefer Brand A." ❌ (Panel is not a random sample; can't make population inference)

------------------------------------------------------------------------

### Example 3: Small Random Sample with Wilson Interval

**Data:** - Random sample overall, n=500 - Subgroup (ages 18-24): n=35 - 57% awareness - Wilson 95% CI: 40.1% to 72.8%

**Correct statement:** "Among 18-24 year-olds in our random sample (n=35), awareness was 57%. However, the small subgroup size means we can only be 95% confident the true value is between 40% and 73%. This subgroup is too small for precise estimates and should be interpreted cautiously or combined with adjacent age groups."

**Why this matters:** - Wide interval (±16 points) signals unreliability - Alerts client not to over-interpret the 57% as precise

------------------------------------------------------------------------

### Example 4: Tracking Study with Bayesian Prior

**Data:** - Q1: satisfaction = 72% (n=800, random sample) - Q2: satisfaction = 68% (n=650, random sample) - Q3 (current): satisfaction = 70% (n=600, random sample)

**Configuration:**

```         
Run_Credible = "Y"
Prior_Mean = 0.69      (average of Q1 and Q2: (72+68)/2)
Prior_N = 725          (average sample size)
```

**Results:** - Current wave alone (Wilson): 66.4% to 73.6% - Bayesian credibility (with prior): 67.2% to 72.4% - Posterior mean: 69.8% (pulled slightly toward prior)

**Correct statement:** "In Q3, satisfaction was 70% (n=600). Incorporating prior information from Q1-Q2, the Bayesian 95% credibility interval is 67-72% (posterior mean: 69.8%). This suggests satisfaction has remained stable across all three quarters, with the prior data narrowing our uncertainty."

------------------------------------------------------------------------

### Example 5: Weighted National Survey

**Data:** - RDD sample n=1,200 (before weighting) - Weighted to census age/gender/region - DEFF = 2.1, n_eff = 571 - 55% approve of government performance

**Analysis:** - Wilson CI (using effective n=571): 51.0% to 59.0%

**Correct statement:** "In this nationally representative survey (n=1,200, weighted to census demographics), 55% approve of government performance. After accounting for weighting efficiency (effective n=571, DEFF=2.1), the 95% confidence interval is 51-59%. The margin of error increased from ±2.8% (if unweighted) to ±4.0% (weighted) due to precision loss from the weighting adjustment."

**Key insight:** - Always report effective n with weighted data - Acknowledge precision loss from weighting - Explain DEFF if writing for technical audiences

------------------------------------------------------------------------

## Technology Used

| Package | Why We Use It |
|----|----|
| **base R stats** | Core statistical functions (qnorm, qt, qbeta) |
| **future** and **future.apply** | Parallel processing for bootstrap |
| **openxlsx** | Professional Excel output |

------------------------------------------------------------------------

## Strengths

✅ **Multiple Methods:** Provides 4 different approaches for proportions, 3 for means ✅ **Theoretically Sound:** Uses established statistical methods with known properties ✅ **Transparent Assumptions:** Clear about when traditional CIs are valid vs. descriptive intervals ✅ **Weighted Data Support:** Properly accounts for design effects and weighting efficiency ✅ **Bayesian Option:** Credibility intervals with uninformed or informed priors ✅ **Efficient Processing:** Parallel bootstrap for large batch calculations ✅ **Educational Output:** Helps users understand precision limitations ✅ **Flexible Configuration:** Enable/disable methods based on your needs

------------------------------------------------------------------------

## Limitations

⚠️ **Cannot Fix Bad Samples:** No interval method can correct selection bias in non-random samples ⚠️ **Requires Honest Assessment:** Users must know if they have random or non-random samples ⚠️ **Prior Specification Required:** Bayesian methods require thoughtful prior selection ⚠️ **Computational Time:** Bootstrap can take several seconds for large datasets ⚠️ **Not All Statistics:** Currently supports proportions, means, and NPS (not medians, complex indices)

------------------------------------------------------------------------

## Best Use Cases

**Ideal For:** - Random samples needing defensible confidence intervals - Non-random samples where you want to show sampling precision (with caveats) - Tracking studies using previous waves as Bayesian priors - Weighted surveys needing proper effective n adjustment - Comparing precision across methods (run multiple, compare results) - Quality control on survey precision - Determining minimum sample sizes for subgroup reporting

**Not Ideal For:** - Claiming precision from biased samples without caveats - Continuous variables needing median or percentile CIs (use t-based or bootstrap for means) - Complex multivariate estimates (use regression CIs) - Real-time streaming data (this is batch-oriented)

------------------------------------------------------------------------

## Quality & Reliability

**Quality Score:** 90/100 **Production Ready:** Yes **Error Handling:** Excellent - validates inputs and handles edge cases **Testing Status:** Comprehensive test suite with known dataset validation

------------------------------------------------------------------------

## What's Next (Future Enhancements)

**Phase 1 (Planned):** - Multiple comparison corrections (Bonferroni, Holm, FDR) - Sample size calculator (inverse problem: "what n do I need?") - Automated reliability flagging (flag intervals \> ±10%)

**Phase 2 (Future):** - Median and percentile confidence intervals - Difference and ratio intervals (for comparing groups) - More prior distribution options (beyond Beta and Normal)

**Phase 3 (Vision):** - Interactive visualization of interval trade-offs - Educational mode with detailed method explanations - Integration with sample size planning tools

------------------------------------------------------------------------

## Key Takeaways

### For Random Samples:

✓ Confidence intervals have statistical guarantees ✓ Use Wilson score as default (statistically superior) ✓ Report effective n for weighted data ✓ Bootstrap validates parametric methods ✓ Bayesian credibility useful for tracking studies with priors

### For Non-Random Samples:

✓ Can only calculate *descriptive* precision intervals ✓ Bootstrap shows sampling variability (not population inference) ✓ Always caveat: "indicative precision only; selection bias may exist" ✓ Bayesian credibility requires explicit prior justification ✓ Don't present as "confidence intervals" (misleading)

### For All Samples:

✓ Wider intervals = less precision (not less accuracy) ✓ Small subgroups need large caveats ✓ Weighting reduces effective sample size ✓ Multiple methods provide validation ✓ Honesty about limitations builds credibility

------------------------------------------------------------------------

## Bottom Line

**Precision is not accuracy.**

You can have very precise estimates of a biased sample. TURAS Confidence Module calculates the right interval for your data, but **you** must honestly assess:

1.  Is this a random sample? (determines if confidence intervals are valid)
2.  Is the data weighted? (use effective n)
3.  Do I have prior information? (consider Bayesian credibility)
4.  What methods should I run? (enable appropriate flags)

**Random sample → Confidence interval (Wilson recommended) → Frequency-based inference**

**Non-random sample → Descriptive precision (Bootstrap) OR Bayesian credibility → Caveat heavily**

**Tracking study → Bayesian credibility with informed prior → Incorporate historical data**

This module calculates mathematically correct intervals. Whether they answer your research question depends on your sampling method and how you interpret the results.

**Think of it as:** The precision meter for survey estimates—showing you how much variability comes from sampling. But remember: a precise estimate of the wrong population is still wrong.

------------------------------------------------------------------------

*For questions or support, contact The Research LampPost (Pty) Ltd*

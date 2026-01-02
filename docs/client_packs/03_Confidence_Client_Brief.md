# Confidence: Confidence Interval Calculations

**What This Module Does**
Confidence calculates the margin of error around survey percentages, telling you how precise your estimates are. When you report "65% of customers are satisfied," this module tells you the true value is likely between 61% and 69% (for example).

---

## What Problem Does It Solve?

Every survey has sampling error - your sample of respondents won't perfectly match the entire population. Key questions:
- How confident can we be in this percentage?
- What's the margin of error?
- Are small sample subgroups reliable enough to report?

**This module quantifies your uncertainty precisely.**

---

## How It Works

You provide:
- A percentage (proportion) from your survey
- The sample size
- Your desired confidence level (typically 95%)
- Any sample weights (if applicable)

The module calculates:
- **Lower bound:** The lowest plausible true value
- **Upper bound:** The highest plausible true value
- **Margin of error:** How much the estimate could vary

Example: "65% ± 4%" means we're 95% confident the true value is between 61% and 69%.

---

## What You Get

**For Each Estimate:**
- Point estimate (the percentage from your data)
- Lower confidence limit
- Upper confidence limit
- Margin of error
- Effective sample size (accounting for weighting)

**Multiple Methods Available:**
- Wilson score method (recommended for most cases)
- Bootstrap method (for complex situations)
- Exact methods (for very small samples)
- Methods for weighted data

---

## Technology Used

| Package | Why We Use It |
|---------|---------------|
| **survey** | Industry-standard package for survey statistics and design effects |
| **boot** | Bootstrap resampling for complex confidence intervals |
| **binom** | Exact binomial methods for small samples |

---

## Strengths

✅ **Multiple Methods:** Chooses the right statistical method for your situation
✅ **Handles Weights:** Properly accounts for sample weighting (many tools get this wrong)
✅ **Small Samples:** Works reliably even with small subgroups
✅ **Conservative Estimates:** When in doubt, provides wider (more conservative) intervals
✅ **Design Effects:** Accounts for complex sample designs (clustering, stratification)
✅ **Fast Calculation:** Processes thousands of estimates in seconds

---

## Limitations

⚠️ **Proportions Only:** Designed for percentages/proportions, not means or other statistics
⚠️ **Simple Random Sampling Assumption:** Complex multi-stage samples may need additional specification
⚠️ **Large Sample Focus:** Some methods optimized for n>30; very small samples (<10) have limited options

---

## Statistical Methods Explained (Plain English)

**What Is a Confidence Interval?**
Imagine asking your question to 100 different random samples. In 95 of those samples, the true percentage would fall within the confidence interval. It's a measure of how much your result might vary due to sampling luck.

**Why Different Methods?**
- **Wilson Score:** Best general-purpose method, works well for most sample sizes
- **Bootstrap:** Uses computer simulation to estimate uncertainty; good for unusual situations
- **Exact Methods:** Mathematically precise but conservative; used for very small samples
- **Weighted Methods:** Account for when some respondents represent more people than others

**What Affects Interval Width?**
- **Larger samples** = Narrower intervals (more precision)
- **Percentages near 50%** = Wider intervals (more uncertainty)
- **Percentages near 0% or 100%** = Narrower intervals
- **Weighting** = Usually wider intervals (weighting adds uncertainty)

---

## Best Use Cases

**Ideal For:**
- Reporting survey results with margin of error
- Determining minimum sample sizes for subgroups
- Validating whether small subgroups are reportable
- Quality control checks on survey precision
- Client reports requiring statistical rigor

**Not Ideal For:**
- Continuous variables (means, medians) - use different statistical methods
- Very complex sample designs without proper design parameters
- Multivariate estimates (use regression confidence intervals instead)

---

## Quality & Reliability

**Quality Score:** 90/100
**Production Ready:** Yes
**Error Handling:** Excellent - Validates inputs and warns about edge cases
**Testing Status:** Well-tested against published statistical tables

---

## Example Use Cases

**Scenario 1: Headline Reporting**
"Customer satisfaction is 78% ± 3% at 95% confidence (n=400)"
→ Module calculates the ±3% margin automatically

**Scenario 2: Subgroup Reporting**
You have a subgroup with n=50. Is it reportable?
→ Module shows margin of error is ±14%, helping you decide

**Scenario 3: Weighted Data**
Your sample was weighted to match demographics
→ Module accounts for weighting, showing true effective sample size

**Scenario 4: Small Percentage**
Only 5% mentioned your brand (n=400)
→ Module correctly calculates narrow interval (3% to 8%)

---

## What's Next (Future Enhancements)

**Coming Soon:**
- Confidence intervals for means and medians
- Multi-level modeling confidence intervals
- Sample size calculators (inverse problem)

**Future Vision:**
- Automated flagging of unreliable estimates
- Interactive visualization of interval width trade-offs
- Integration with dashboard tools for real-time CI display

---

## Bottom Line

Confidence is your precision meter for survey results. It tells you how much to trust each estimate and helps you communicate uncertainty honestly to clients. Instead of reporting percentages as if they're exact, you can say "we're 95% confident the true value is between X% and Y%."

**Think of it as:** The statistical safety net that prevents you from over-interpreting random sampling variation as real findings.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*

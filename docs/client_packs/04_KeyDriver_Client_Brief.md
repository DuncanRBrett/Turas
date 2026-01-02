# KeyDriver: Correlation-Based Driver Analysis

**What This Module Does**
KeyDriver identifies which factors have the strongest relationship with your key business outcomes. It answers questions like "What drives customer satisfaction?" or "Which features matter most for purchase intent?"

---

## What Problem Does It Solve?

You measure many attributes (quality, price, service, etc.) and one key outcome (satisfaction, loyalty, NPS). But which attributes actually matter?

**KeyDriver finds the strongest relationships and ranks drivers by importance.**

---

## How It Works

You provide:
- **Outcome variable:** What you're trying to predict (e.g., overall satisfaction)
- **Driver variables:** Potential influencing factors (e.g., product quality, price, service)
- Survey data with all these measures

The module calculates:
- Correlation between each driver and the outcome
- Statistical significance of each relationship
- Relative importance rankings
- Categorization into impact zones (high/medium/low impact)

---

## What You Get

**Analysis Outputs:**
- **Correlation scores** for each driver (-1 to +1 scale)
- **Importance rankings** showing which drivers matter most
- **Statistical significance** tests for each relationship
- **Impact categorization** (High/Medium/Low impact drivers)
- **Excel report** with formatted results and visualizations

**Visual Outputs:**
- Importance-Performance matrix coordinates
- Driver ranking charts
- Scatter plot data for presentations

---

## Technology Used

| Package | Why We Use It |
|---------|---------------|
| **data.table** | Fast data processing for large datasets |
| **Hmisc** | Robust correlation calculations with proper handling of missing data |
| **openxlsx** | Professional Excel output with formatting |

---

## Strengths

✅ **Simple & Interpretable:** Correlations are easy to explain to non-technical audiences
✅ **Fast Computation:** Analyzes hundreds of drivers in seconds
✅ **Handles Missing Data:** Properly deals with "don't know" and skipped questions
✅ **Weighted Data Support:** Accounts for sample weights in correlations
✅ **Multi-Purpose:** Works for satisfaction, NPS, loyalty, purchase intent, etc.
✅ **Clear Rankings:** Definitively shows which drivers matter most

---

## Limitations

⚠️ **Correlation Not Causation:** Shows relationships, not necessarily cause-and-effect
⚠️ **Linear Relationships Only:** Assumes straight-line relationships; misses complex patterns
⚠️ **Multicollinearity Blind:** Doesn't account for drivers that overlap (e.g., "quality" and "reliability")
⚠️ **No Interaction Effects:** Can't detect when two drivers work together
⚠️ **Continuous/Ordinal Data Required:** Works best with rating scales, not categorical data

---

## Statistical Concepts Explained (Plain English)

**What Is Correlation?**
A number from -1 to +1 showing how two variables move together:
- **+1:** Perfect positive relationship (as one goes up, so does the other)
- **0:** No relationship
- **-1:** Perfect negative relationship (as one goes up, the other goes down)

**Real-World Example:**
- "Product quality" correlation with satisfaction = 0.72 (strong positive)
- "Price" correlation with satisfaction = -0.15 (weak negative)
→ Quality matters much more than price for satisfaction

**Statistical Significance:**
Did we find a real pattern, or just random noise?
- Significant: The relationship is real (p < 0.05)
- Not significant: Could just be chance; don't trust it

---

## Best Use Cases

**Ideal For:**
- Customer satisfaction drivers
- NPS driver analysis
- Brand health tracking (what drives consideration/preference)
- Product optimization (which features drive purchase intent)
- Service improvement (which touchpoints drive loyalty)

**Not Ideal For:**
- Categorical outcomes (won't buy/might buy/will buy) - use catdriver instead
- Small samples (<100 respondents) - unreliable correlations
- Non-linear relationships - use regression-based approaches
- When you need to control for multiple factors simultaneously

---

## Quality & Reliability

**Quality Score:** 93/100 (highest-scoring module)
**Production Ready:** Yes
**Error Handling:** Excellent - Clear validation of data requirements
**Testing Status:** Well-tested with regression suite

---

## Example Outputs

**Sample Findings Table:**

| Driver | Correlation | Significance | Impact |
|--------|------------|--------------|---------|
| Product Quality | 0.74 | *** | High |
| Customer Service | 0.68 | *** | High |
| Ease of Use | 0.52 | *** | Medium |
| Value for Money | 0.41 | *** | Medium |
| Brand Reputation | 0.28 | ** | Low |
| Website Design | 0.12 | ns | Low |

**How to Read This:**
- Quality and Service are your top drivers (correlations > 0.65)
- Ease of Use and Value matter moderately
- Brand and Website have limited impact on satisfaction
- Focus resources on the High impact drivers

---

## When to Use KeyDriver vs. Other Modules

**Use KeyDriver when:**
- You have rating scale data (1-10, 1-5 scales)
- You want quick, simple driver rankings
- Your audience prefers straightforward correlations

**Use catdriver instead when:**
- Your outcome is categorical (Satisfied/Neutral/Dissatisfied)
- You need to control for multiple factors simultaneously
- You want SHAP values showing individual-level driver importance

**Use pricing instead when:**
- You're specifically analyzing price sensitivity
- You need price elasticity estimates

---

## What's Next (Future Enhancements)

**Coming Soon:**
- Importance-Performance grids (automated plotting)
- Partial correlation analysis (control for overlapping drivers)
- Time-series tracking of driver importance

**Future Vision:**
- Non-linear driver detection
- Automated segmentation by different driver profiles
- Interactive dashboards with drill-down capability

---

## Bottom Line

KeyDriver is your "what matters most" analysis tool. It takes the guesswork out of prioritization by showing you exactly which factors have the strongest relationship with your business outcomes. The correlation-based approach is simple, fast, and easy to communicate to stakeholders.

**Think of it as:** A spotlight that shows you where to focus your resources by revealing which drivers have the biggest impact on the outcomes you care about.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*

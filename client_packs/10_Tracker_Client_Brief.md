# Tracker: Longitudinal Tracking & Trend Analysis

**What This Module Does**
Tracker analyzes survey data collected over time (weeks, months, years) to identify trends, seasonal patterns, and significant changes. It's designed for brand tracking, customer satisfaction monitoring, and any metric you measure repeatedly.

---

## What Problem Does It Solve?

When you run the same survey multiple times, you need to:
- Identify real trends vs. random fluctuation
- Detect significant changes that require action
- Understand seasonal patterns
- Compare performance across time periods
- Track competitive movement

**Tracker separates signal from noise in your time-series data.**

---

## How It Works

You provide:
- Multi-wave survey data (same questions asked repeatedly)
- Wave identifiers (month, quarter, year)
- Key metrics to track over time

The module:
1. **Harmonizes Data:** Ensures consistency across waves
2. **Calculates Trends:** Statistical trend detection (is it really changing?)
3. **Tests Significance:** Are changes between waves meaningful?
4. **Identifies Patterns:** Seasonality, cyclical patterns, outliers
5. **Flags Alerts:** Significant drops/increases that need attention

---

## What You Get

**Trend Analysis:**
- Time-series charts for all key metrics
- Trend direction (improving, declining, stable)
- Rate of change (% per period)
- Statistical significance of trends

**Period Comparisons:**
- Wave-to-wave changes with significance testing
- Year-over-year comparisons
- Quarter-over-quarter analysis
- Cumulative tracking

**Diagnostic Outputs:**
- Base size consistency checks
- Sample composition drift detection
- Question continuity validation
- Data quality flags

**Excel Reports:**
- Trend tables with formatted changes
- Significance markers for real changes
- Graphical trend lines
- Alert summary tables

---

## Technology Used

| Package | Why We Use It |
|---------|---------------|
| **brolgar** | Longitudinal data exploration and trend detection |
| **lme4** | Mixed-effects models for repeated measures |
| **forecast** | Time series forecasting and seasonality detection |
| **data.table** | Fast manipulation of multi-wave data |
| **survey** | Weighted trend analysis |

---

## Strengths

✅ **Multi-Wave Expertise:** Purpose-built for repeated measurement
✅ **Statistical Rigor:** Tests whether changes are real or random
✅ **Data Quality Checks:** Detects sample composition changes
✅ **Seasonal Adjustment:** Accounts for predictable patterns
✅ **Weighted Analysis:** Proper handling of sample weights over time
✅ **Automated Alerts:** Flags significant changes automatically
✅ **Flexible Aggregation:** Daily, weekly, monthly, quarterly views

---

## Limitations

⚠️ **Requires Multiple Waves:** Need at least 3-4 time points for trends
⚠️ **Question Consistency:** Works best when questions stay constant
⚠️ **Sample Size Stability:** Small waves can produce unstable trends
⚠️ **Causal Inference:** Shows what changed, not why it changed
⚠️ **Seasonal Patterns:** Needs 12+ months to detect seasonality reliably

---

## Statistical Concepts Explained (Plain English)

**What Is a Trend?**
A consistent pattern of change over time:
- **Upward trend:** Metric consistently increasing
- **Downward trend:** Metric consistently decreasing
- **Flat trend:** No consistent direction (stable)

Not every change is a trend—sometimes it's just random variation.

**Statistical Significance in Tracking:**
When we say a change is "significant," we mean:
- The change is bigger than expected from random sampling
- We're confident it's a real shift, not noise
- Typically uses 90-95% confidence level

**Example:**
- Wave 1: Satisfaction = 75%
- Wave 2: Satisfaction = 78%
- Is +3 points significant? Depends on sample size and variance.

**Seasonal Adjustment:**
Some metrics naturally vary by time of year:
- Retail sales spike in December
- Travel intent peaks in summer
Seasonal adjustment removes these predictable patterns to reveal underlying trends.

---

## Best Use Cases

**Ideal For:**
- Brand health tracking (awareness, consideration, NPS)
- Customer satisfaction monitoring (CSAT, CES, NPS)
- Market share tracking
- Advertising effectiveness (pre/post campaign)
- Competitive benchmarking over time
- Product performance tracking

**Not Ideal For:**
- One-time surveys (no time dimension)
- Very infrequent measurement (<2x per year)
- When questions change dramatically across waves
- Real-time monitoring (tracker is batch/periodic)

---

## Quality & Reliability

**Quality Score:** 85/100
**Production Ready:** Yes
**Error Handling:** Good - Validates wave consistency
**Testing Status:** Core functionality tested; expanding diagnostic suite

---

## Example Outputs

**Trend Summary Table:**

| Metric | Q1 2024 | Q2 2024 | Q3 2024 | Q4 2024 | Change Q1→Q4 | Significance |
|--------|---------|---------|---------|---------|--------------|--------------|
| Brand Awareness | 67% | 68% | 71% | 74% | +7 pts | *** |
| Consideration | 45% | 46% | 46% | 47% | +2 pts | ns |
| NPS | 32 | 35 | 38 | 41 | +9 pts | *** |
| Customer Satisfaction | 8.1 | 8.2 | 8.3 | 8.2 | +0.1 pts | ns |

**Interpretation:**
- *** = Significant upward trend (awareness, NPS improving)
- ns = Not significant (consideration, satisfaction stable)

**Alert Summary:**

| Metric | Type | Description |
|--------|------|-------------|
| NPS | 📈 Positive | +9 point increase over 12 months |
| Brand Awareness | 📈 Positive | Consistent growth every quarter |
| Market Share | 🚨 Negative | -3 point drop in Q4 (significant) |

---

## Real-World Example

**Scenario:** Telecom brand health tracking

**Setup:**
- Monthly surveys, n=500 per wave
- 24 months of data
- Key metrics: Awareness, consideration, NPS, quality perceptions

**Tracker Analysis Revealed:**
1. **Awareness growing steadily:** +2-3 points per quarter (significant trend)
2. **NPS spike in June:** Coincided with new customer service initiative
3. **Seasonal dip:** Consideration drops every December (holiday distraction)
4. **Sample drift detected:** August wave over-represented younger respondents
5. **Competitive threat:** Competitor awareness surged in Q3 (significant)

**Business Actions:**
- Awareness: Continue brand campaign (working)
- NPS: Expand customer service initiatives (proved effective)
- Seasonality: Adjust December targets to account for pattern
- Sample: Re-weight August data for comparability
- Competition: Increase competitive monitoring in Q4

**Results:** Identified $2M customer service investment was paying off (NPS lift), caught competitive threat early, corrected sample bias before reporting to stakeholders.

---

## Tracker vs. Other Modules

**Use Tracker when:**
- You have multiple waves of same survey
- Need to monitor change over time
- Want to detect trends and patterns

**Use Tabs when:**
- You have single-wave data
- Focus is on cross-sectional differences (not time)
- No trend analysis needed

**Use Segment when:**
- Identifying customer groups (not tracking metrics)
- Segmentation is the objective (time is secondary)

---

## What's Next (Future Enhancements)

**Coming Soon:**
- Automated forecasting (predict next wave)
- Advanced seasonality decomposition
- Anomaly detection (automatic outlier flagging)

**Future Vision:**
- Real-time tracking dashboards
- Automated alert notifications
- Integration with business KPI systems
- Predictive analytics (anticipate changes before they happen)

---

## Bottom Line

Tracker is your time-series analyst for repeated surveys. It transforms multiple waves of data into clear trend insights, separates real changes from random noise, and flags important shifts that need attention. With built-in data quality checks and statistical rigor, it ensures you're tracking what matters and reporting changes you can trust.

**Think of it as:** A vigilant monitor watching your key metrics over time, alerting you to significant changes, filtering out noise, and showing you the true underlying trends in your brand or customer performance.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*

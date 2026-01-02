# Tabs: Cross-Tabulation & Significance Testing

**What This Module Does**
Tabs creates professional cross-tabulation tables (crosstabs) showing how different groups answered your survey questions. It automatically tests whether differences between groups are statistically significant and exports formatted Excel reports.

---

## What Problem Does It Solve?

In market research, you need to compare responses across different audience segments:
- Do men and women answer differently?
- How do responses vary by age group or region?
- Are the differences between groups real, or just random chance?

**This module answers these questions with statistically valid tables.**

---

## How It Works

You provide:
1. **Survey data** - Your response data (usually from Alchemer or similar)
2. **Question metadata** - What each question means and how it's coded
3. **Banner specification** - Which groups you want to compare (demographics, segments, etc.)

The module creates professional tables showing:
- Percentages for each response option
- Sample sizes (number of respondents)
- Statistical significance markers (letters/symbols showing real differences)
- Weighted results (if your sample needs statistical balancing)

---

## What You Get

**Excel Output Files:**
- Cross-tabulation tables with percentages and counts
- Significance testing markers (A, B, C letters showing which groups differ)
- Net scores (Top 2 Box, Bottom 2 Box)
- Index values (showing groups that over/under-index)
- Summary statistics

**Visual Features:**
- Color-coded significance markers
- Professional formatting ready for client presentations
- Configurable decimal places and rounding

---

## Technology Used

| Package | Why We Use It |
|---------|---------------|
| **data.table** | Processes large datasets very quickly |
| **survey** | Handles weighted data and complex sample designs correctly |
| **effectsize** | Calculates standardized effect sizes for practical significance |
| **openxlsx** | Creates formatted Excel files with styling |

---

## Strengths

✅ **Statistically Rigorous:** Uses industry-standard significance tests (Z-test, Chi-square)
✅ **Handles Weighting:** Properly accounts for sample weights in all calculations
✅ **Multiple Test Methods:** Supports different significance testing approaches based on your needs
✅ **Net Calculations:** Automatically creates Top/Bottom box scores
✅ **Large Data Ready:** Efficiently processes surveys with thousands of respondents
✅ **Publication Quality:** Output is formatted and ready for client delivery

---

## Limitations

⚠️ **Single Wave Only:** Analyzes one survey wave at a time (use Tracker module for trends)
⚠️ **Pre-configured Banners:** Requires banner specification to be set up in advance
⚠️ **Standard Outputs:** Best suited for traditional crosstab formats; custom table layouts may need adjustment
⚠️ **Excel Output:** Primary output is Excel; dashboards and visualizations would be separate

---

## Statistical Methods Explained (Plain English)

**Significance Testing:**
When we say two groups are "significantly different," we mean the difference is unlikely to be due to random chance. The module uses:
- **Z-tests** for comparing proportions (percentages)
- **Chi-square tests** for overall question differences
- **Confidence intervals** to show the range of plausible values

**What the Letters Mean:**
- Groups marked with the same letter (A, B, C) are NOT significantly different from each other
- Groups with different letters ARE significantly different
- Example: If Men are marked "A" and Women are marked "B," there's a real difference

**Weighting:**
If your sample doesn't match your target population (e.g., too many young people), weights adjust the data so percentages reflect the true population.

---

## Best Use Cases

**Ideal For:**
- Standard market research surveys requiring demographic breaks
- Client deliverables needing professional formatted tables
- Large-scale surveys (500+ respondents)
- Studies requiring weighted data analysis
- Projects needing statistical validation of differences

**Not Ideal For:**
- Longitudinal tracking (use Tracker module instead)
- Small samples (<50 respondents) where significance testing is limited
- Highly customized table formats beyond standard crosstabs

---

## Quality & Reliability

**Quality Score:** 85/100
**Production Ready:** Yes
**Error Handling:** Excellent - Clear messages if data or configuration has issues
**Testing Status:** Core functionality tested; comprehensive test suite in development

---

## What's Next (Future Enhancements)

**Coming Soon:**
- Automated chart generation from tables
- More significance test options (Bonferroni correction, etc.)
- Enhanced formatting options and templates

**Future Vision:**
- Interactive dashboards linked to tables
- Real-time filtering and drill-down
- Automated insight detection (highlighting biggest differences)

---

## Bottom Line

Tabs is your workhorse for survey analysis. It takes your raw survey data and produces professional, statistically valid cross-tabulation tables that answer the key question: "How do different groups compare?" The significance testing ensures you're reporting real differences, not random noise.

**Think of it as:** A statistical analyst that creates publication-ready tables showing how every audience segment answered every question, with confidence that the differences you're reporting are real.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*

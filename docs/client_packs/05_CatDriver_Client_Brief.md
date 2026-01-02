# CatDriver: Categorical Driver Analysis

**What This Module Does**
CatDriver identifies what drives categorical outcomes like purchase decisions, satisfaction categories, or customer segments. Unlike simple correlations, it uses advanced regression models that handle real-world survey data complexity.

---

## What Problem Does It Solve?

When your outcome is categorical (Yes/No, Satisfied/Neutral/Dissatisfied, Low/Medium/High NPS), you need specialized analysis:
- What drives customers to choose "Very Satisfied" vs. "Somewhat Satisfied"?
- Which factors predict purchase (Buy vs. Don't Buy)?
- What differentiates Promoters from Detractors?

**CatDriver uses regression models designed specifically for categorical data.**

---

## How It Works

You provide:
- **Categorical outcome:** Your key metric with distinct categories
- **Driver variables:** Factors that might influence the outcome
- Survey data

The module:
1. Selects the right regression model (binary, ordinal, or multinomial)
2. Fits the model with proper handling of survey weights
3. Calculates driver importance using SHAP values (cutting-edge explainability)
4. Provides individual-level predictions showing what drives each person's response

---

## What You Get

**Statistical Outputs:**
- **Driver importance scores** (SHAP values)
- **Regression coefficients** with confidence intervals
- **Model fit statistics** (R-squared, AIC)
- **Individual predictions** for each respondent
- **Odds ratios** (how much each driver changes the odds)

**Business Outputs:**
- Rankings of most important drivers
- Predictions for "what-if" scenarios
- Segment-specific driver profiles
- Excel reports with formatted results

---

## Technology Used

| Package | Why We Use It |
|---------|---------------|
| **MASS** | Industry-standard ordinal regression (polr function) |
| **nnet** | Multinomial logistic regression for multiple outcomes |
| **logistf** | Firth correction for separation issues (prevents crashes) |
| **shapr** | SHAP values for explainable AI / driver importance |
| **survey** | Proper handling of weighted survey data |

---

## Strengths

✅ **Handles Categorical Outcomes:** Purpose-built for satisfaction scales, purchase decisions, NPS categories
✅ **Advanced Driver Importance:** Uses SHAP values (same method as modern AI models)
✅ **Robust to Problems:** Firth correction prevents model failures from separation
✅ **Multiple Model Types:** Automatically selects binary/ordinal/multinomial based on data
✅ **Individual-Level Insights:** Shows what drives each person, not just averages
✅ **Controls for Overlapping Drivers:** Unlike correlation, properly handles interrelated variables
✅ **Predictive Power:** Can forecast outcomes for new scenarios

---

## Limitations

⚠️ **Complexity:** More sophisticated than simple correlations; requires careful interpretation
⚠️ **Sample Size:** Needs adequate sample (typically 200+ for reliable results)
⚠️ **Assumes Ordinal Scale:** For ordered categories, assumes equal spacing between levels
⚠️ **Computation Time:** SHAP calculation can be slow for very large datasets (1000+ cases)
⚠️ **Technical Output:** Coefficients require statistical knowledge to interpret fully

---

## Statistical Concepts Explained (Plain English)

**What Are SHAP Values?**
SHAP (SHapley Additive exPlanations) shows how much each driver contributes to the prediction for each person. Unlike traditional regression:
- Works at individual level (not just population average)
- Accounts for interactions between drivers
- Provides consistent, fair importance scores

**Model Types:**
- **Binary Logistic:** Two outcomes (Buy/Don't Buy)
- **Ordinal Logistic:** Ordered categories (Very Unsatisfied → Very Satisfied)
- **Multinomial Logistic:** Unordered categories (Brand A vs. Brand B vs. Brand C)

**What Are Odds Ratios?**
A measure of how much a one-unit change in a driver multiplies the odds of an outcome:
- Odds ratio = 2.0: Doubling the driver doubles the odds
- Odds ratio = 0.5: Doubling the driver halves the odds
- Odds ratio = 1.0: Driver has no effect

---

## Best Use Cases

**Ideal For:**
- NPS driver analysis (Promoter/Passive/Detractor)
- Purchase intent drivers (Will buy / Might / Won't)
- Satisfaction category drivers (Very/Somewhat/Not Satisfied)
- Customer retention prediction
- Segment classification (what makes someone fit a segment)

**Not Ideal For:**
- Continuous outcomes (use standard regression)
- Very small samples (<100 respondents)
- When simple correlation analysis suffices
- Real-time applications (SHAP calculation can be slow)

---

## Quality & Reliability

**Quality Score:** 92/100 (second-highest scoring module)
**Production Ready:** Yes
**Error Handling:** Excellent - Fallback strategies prevent crashes
**Testing Status:** Comprehensive with stability tracking

---

## Example Outputs

**Sample SHAP Importance Table:**

| Driver | SHAP Importance | Direction | Interpretation |
|--------|----------------|-----------|----------------|
| Product Quality | 0.42 | + | Strongest positive driver |
| Customer Service | 0.38 | + | Second strongest driver |
| Price Satisfaction | 0.29 | + | Moderate impact |
| Brand Familiarity | 0.12 | + | Weak driver |

**Individual Prediction Example:**
Respondent #123:
- Predicted: Very Satisfied (78% probability)
- Top driver: Product Quality (+0.52)
- Second driver: Service (+0.41)
→ For this person, quality and service are pushing them toward high satisfaction

---

## When to Use CatDriver vs. Other Modules

**Use CatDriver when:**
- Outcome is categorical (not continuous)
- You need to control for multiple factors simultaneously
- You want individual-level driver importance
- You're building predictive models

**Use keydriver instead when:**
- You have continuous outcomes (1-10 scales)
- You prefer simple correlation-based approach
- Speed is priority over sophistication
- Audience prefers straightforward correlations

---

## What's Next (Future Enhancements)

**Coming Soon:**
- Random forest driver analysis (alternative to regression)
- Interaction detection (when two drivers work together)
- Automated segment profiling

**Future Vision:**
- Real-time scoring APIs
- Visual SHAP waterfall charts
- Integration with CRM systems for predictive targeting

---

## Bottom Line

CatDriver brings cutting-edge machine learning explainability (SHAP values) to traditional market research. When your outcome is categorical and you need to understand what drives it, this module provides sophisticated yet interpretable driver analysis. It's the tool for when correlation analysis isn't enough and you need regression-based insights.

**Think of it as:** An expert statistician that uses advanced models to show you exactly what drives categorical outcomes, with individual-level precision and modern AI explainability.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*

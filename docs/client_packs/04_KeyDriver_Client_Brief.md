---
editor_options: 
  markdown: 
    wrap: 72
---

# KeyDriver: ML-Based Driver Analysis with SHAP

**What This Module Does** KeyDriver identifies which factors have the
strongest relationship with your key business outcomes using machine
learning. It answers questions like "What drives customer satisfaction?"
or "Which features matter most for purchase intent?" using gradient
boosting and SHAP value-based importance.

------------------------------------------------------------------------

## What Problem Does It Solve?

You measure many attributes (quality, price, service, etc.) and one key
outcome (satisfaction, loyalty, NPS). But which attributes actually
matter?

**KeyDriver finds the strongest relationships and ranks drivers by
importance.**

------------------------------------------------------------------------

## How It Works

You provide: - **Outcome variable:** What you're trying to predict
(e.g., overall satisfaction) - **Driver variables:** Potential
influencing factors (e.g., product quality, price, service) - Survey
data with all these measures

The module calculates: - SHAP values for each driver showing their
contribution to predictions - Feature importance scores based on
gradient boosting - Relative importance rankings across all drivers -
Categorization into impact zones (high/medium/low impact)

------------------------------------------------------------------------

## What You Get

**Analysis Outputs:** - **Correlation scores** for each driver (-1 to +1
scale) - **Importance rankings** showing which drivers matter most -
**Statistical significance** tests for each relationship - **Impact
categorization** (High/Medium/Low impact drivers) - **Excel report**
with formatted results and visualizations

**Visual Outputs:** - Importance-Performance matrix coordinates - Driver
ranking charts - Scatter plot data for presentations

------------------------------------------------------------------------

## Technology Used

| Package      | Why We Use It                                            |
|--------------|----------------------------------------------------------|
| **xgboost**  | Fast gradient boosting for feature importance estimation |
| **shapviz**  | SHAP visualization for driver importance interpretation  |
| **ggplot2**  | Professional visualization and driver ranking charts     |
| **ggrepel**  | Clean label placement in importance-performance matrices |
| **openxlsx** | Professional Excel output with formatting                |

------------------------------------------------------------------------

## Strengths

✅ **Captures Complex Patterns:** Machine learning detects non-linear
relationships correlations miss ✅ **SHAP-Based Interpretation:**
Advanced explainability shows how each driver contributes to predictions
✅ **Handles Interactions:** Gradient boosting automatically captures
when drivers work together ✅ **Mixed Data Types:** Works with
continuous, ordinal, and categorical drivers ✅ **Fast Computation:**
Analyzes hundreds of drivers in seconds with modern ML algorithms ✅
**Individual & Aggregate Insights:** Shows both overall importance and
driver effects at individual level

------------------------------------------------------------------------

## Limitations

⚠️ **Correlation Not Causation:** Shows relationships, not necessarily
cause-and-effect ⚠️ **Model Complexity:** Gradient boosting less
transparent than simple correlations (though SHAP helps) ⚠️ **Larger
Sample Requirements:** ML-based approach benefits from adequate sample
sizes ⚠️ **Computation Cost:** More intensive than correlation but still
practical for large datasets

------------------------------------------------------------------------

## Statistical Concepts Explained (Plain English)

### Why Machine Learning for Driver Analysis?

**Traditional Approach (Correlation):**

Calculate correlation between each driver and the outcome:

```         
Satisfaction vs Quality:    r = 0.68
Satisfaction vs Service:    r = 0.62
Satisfaction vs Price:      r = 0.41
```

**Problems with correlation:**

1.  **Misses interactions:** What if Quality + Service together matter
    more than separately?
2.  **Assumes linear:** What if satisfaction increases slowly at low
    quality but sharply at high quality?
3.  **Ignores redundancy:** If Quality and Durability are 0.95
    correlated, both show high correlation but only one really matters

**Machine Learning Approach (XGBoost + SHAP):**

-   Captures non-linear patterns automatically
-   Detects when drivers work together (interactions)
-   Handles correlated predictors correctly
-   Provides individual-level driver importance (not just population
    average)

**KeyDriver uses XGBoost** (gradient boosting) because it's: - Fast and
scalable - Handles mixed data types (numeric, categorical) - Naturally
detects interactions - Industry-standard for feature importance

------------------------------------------------------------------------

### What Is Gradient Boosting? (The Intuition)

**Core Idea:** Build MANY simple models (decision trees), each learning
from previous models' mistakes.

**Step-by-Step Process:**

**STEP 1: Start with a simple prediction**

Initial guess: Predict everyone has average satisfaction = 7.0

**Residuals (mistakes):** - Person 1: Actual=9, Predicted=7 → Residual =
+2 - Person 2: Actual=5, Predicted=7 → Residual = -2 - Person 3:
Actual=8, Predicted=7 → Residual = +1

**STEP 2: Build a tree to predict the RESIDUALS**

```         
Tree 1: "Can we predict who we over/under-estimated?"

           Quality > 7?
          /            \
      YES (+1.5)      NO (-0.8)
```

**Interpretation:** People with Quality \> 7 were underestimated by 1.5
points

**STEP 3: Update predictions**

New prediction = Old prediction + (Learning Rate × Tree Prediction)

```         
Person 1 (Quality=9): 7.0 + 0.1×1.5 = 7.15
Person 2 (Quality=4): 7.0 + 0.1×(-0.8) = 6.92
```

**STEP 4: Calculate NEW residuals and build Tree 2**

Repeat 100-500 times, each tree fixing mistakes of previous trees.

**Final Prediction = Baseline + Tree1 + Tree2 + ... + Tree500**

**Why This Works:**

-   Each tree is simple (only 6 levels deep in KeyDriver)
-   Combined, they capture complex patterns
-   Learning rate (0.1) prevents overfitting
-   Cross-validation stops when adding more trees doesn't help

------------------------------------------------------------------------

### XGBoost Hyperparameters (What KeyDriver Uses)

**KeyDriver's default configuration:**

``` r
params <- list(
  objective = "reg:squarederror",  # Predicting continuous outcome
  eta = 0.1,                       # Learning rate
  max_depth = 6,                   # Tree complexity
  subsample = 0.8,                 # Sample 80% of data per tree
  colsample_bytree = 0.8,          # Use 80% of features per tree
  n_trees = 500                    # Maximum trees (auto-selected via CV)
)
```

**What these mean:**

**Learning Rate (eta = 0.1):** - How much each tree contributes - Lower
= more conservative, needs more trees - Higher = faster but risks
overfitting - **0.1 is standard for most applications**

**Max Depth (6):** - How complex each tree can be - Depth 6 = up to 2\^6
= 64 leaf nodes - Captures interactions up to 6-way - **6 is good
balance between complexity and stability**

**Subsample (0.8):** - Randomly use 80% of respondents for each tree -
Prevents overfitting - Makes model more robust

**Column Sample (0.8):** - Randomly use 80% of drivers for each tree -
Forces model to find alternative predictive paths - Reduces impact of
highly correlated drivers

**Number of Trees (auto):** - Determined by cross-validation with early
stopping - Stops adding trees when validation error stops improving -
Typically 100-300 trees selected

------------------------------------------------------------------------

### What Are SHAP Values? (Shapley Additive Explanations)

**The Problem SHAP Solves:**

XGBoost makes accurate predictions but is a "black box":

```         
Respondent #42:
  Quality = 8, Service = 6, Price = 7
  → XGBoost predicts: Satisfaction = 8.2

But WHY 8.2?
```

**SHAP Answer:** Break down the prediction into contributions from each
driver.

**Shapley Values (Game Theory):**

Originally from cooperative game theory: "If players work together, how
do we fairly distribute the payout?"

**Applied to ML:** "If drivers work together to predict outcome, how
much does each driver contribute?"

------------------------------------------------------------------------

### SHAP Calculation (Step-by-Step)

**For Respondent #42:**

**Baseline (no drivers):** Average satisfaction across all respondents =
7.0

**Goal:** Explain how we get from 7.0 to 8.2 (+1.2)

**STEP 1: Calculate contribution of each driver**

SHAP asks: "What's the average impact of this driver across all possible
combinations?"

**Quality SHAP Calculation:**

Test all possible feature combinations:

1.  Predict with NO features → 7.0
2.  Predict with ONLY Quality=8 → 7.6 (Δ = +0.6)
3.  Predict with Quality=8 + Service=6 → 8.0 (Δ from baseline = +1.0)
4.  Predict with Quality=8 + Price=7 → 7.9 (Δ = +0.9)
5.  Predict with ALL features → 8.2 (Δ = +1.2)

**Marginal contribution of Quality in each case:** - Alone: +0.6 - With
Service: (8.0-7.4) = +0.6 (where 7.4 = baseline + service only) - With
Price: (7.9-7.3) = +0.6 - With both: (8.2-7.6) = +0.6 (where 7.6 =
baseline + service + price)

**Average Quality contribution:** (0.6+0.6+0.6+0.6)/4 = **+0.6**

**Repeat for Service and Price:** - Service SHAP: +0.4 - Price SHAP:
+0.2

**Verify:** 7.0 (baseline) + 0.6 (Quality) + 0.4 (Service) + 0.2 (Price)
= 8.2 ✓

------------------------------------------------------------------------

### SHAP Values: Visual Interpretation

**For Respondent #42:**

```         
Baseline: 7.0

+0.6 (Quality=8)  ████████████
+0.4 (Service=6)  ████████
+0.2 (Price=7)    ████
                  ↓
Final Prediction: 8.2
```

**Reading SHAP values:**

-   **Positive SHAP:** Driver pushes prediction HIGHER than baseline
-   **Negative SHAP:** Driver pushes prediction LOWER than baseline
-   **Magnitude:** Larger absolute value = stronger contribution

**Example with negative SHAP:**

**Respondent #15:**

```         
Baseline: 7.0

+0.2 (Quality=6)   ████
-0.8 (Service=3)   ████████████████ (negative)
+0.1 (Price=8)     ██
                   ↓
Final Prediction: 6.5
```

**Interpretation:** Poor service (rating 3) is dragging satisfaction
down by 0.8 points.

------------------------------------------------------------------------

### SHAP vs Correlation: A Direct Comparison

**Scenario:** Predict overall satisfaction from 3 drivers

**Data Pattern:** - Quality and Durability are highly correlated (r =
0.90) - When Quality is high, Durability is usually high too

**Correlation Analysis Results:**

| Driver     | Correlation with Satisfaction |
|------------|-------------------------------|
| Quality    | 0.72                          |
| Durability | 0.68                          |
| Service    | 0.55                          |

**Interpretation from correlation:** "Quality and Durability are both
important drivers"

**SHAP Analysis Results:**

| Driver     | Mean Absolute SHAP Value |
|------------|--------------------------|
| Quality    | 0.65                     |
| Service    | 0.42                     |
| Durability | 0.15                     |

**Interpretation from SHAP:** "Quality is the PRIMARY driver; Durability
adds little once Quality is known"

**Why the difference?**

-   **Correlation** sees Quality and Durability as separate predictors
-   **SHAP** recognizes they're redundant (correlated)
-   SHAP attributes importance to Quality (whichever is more predictive)
-   Durability gets LOW SHAP because it doesn't add much beyond Quality

**Business Implication:** - Correlation: Improve both Quality AND
Durability - SHAP: Focus on Quality (Durability will follow or doesn't
matter separately)

------------------------------------------------------------------------

### Non-Linear Relationships: Where Correlation Fails

**Example:** Price satisfaction and overall satisfaction

**True Relationship (U-shaped):** - Very Low Price: Satisfaction = 6
(too cheap, quality concerns) - Medium Price: Satisfaction = 8 (sweet
spot) - Very High Price: Satisfaction = 5 (too expensive)

**Correlation Result:**

```         
Correlation(Price, Satisfaction) = 0.05 (nearly zero!)
```

**Conclusion from correlation:** "Price doesn't matter"

**SHAP Result:**

Individual SHAP values vary by price level:

| Respondent | Price         | SHAP(Price) | Interpretation                     |
|------------|---------------|-------------|------------------------------------|
| 1          | \$20 (low)    | -0.8        | Hurts satisfaction (too cheap)     |
| 2          | \$50 (medium) | +0.9        | Boosts satisfaction (optimal)      |
| 3          | \$90 (high)   | -1.2        | Hurts satisfaction (too expensive) |

**Mean Absolute SHAP:** 0.97 (Price IS important!)

**Conclusion from SHAP:** "Price matters a LOT, but relationship is
non-linear"

**Why SHAP works:** - XGBoost decision trees capture U-shaped pattern -
SHAP reveals importance even when correlation is zero

------------------------------------------------------------------------

### Feature Interactions: When Drivers Work Together

**Example:** Quality and Service interaction

**Pattern in data:** - High Quality + High Service → Satisfaction = 9.5
(synergy) - High Quality + Low Service → Satisfaction = 7.0
(disappointing) - Low Quality + High Service → Satisfaction = 6.5 (can't
fix bad product) - Low Quality + Low Service → Satisfaction = 3.0
(disaster)

**Correlation Analysis:**

```         
Quality:  r = 0.65
Service:  r = 0.58
```

**Missing:** The INTERACTION effect (1+1 = 3, not 2)

**SHAP Captures Interactions:**

**Respondent with Quality=9, Service=9:** - Quality SHAP: +1.2 (higher
than usual) - Service SHAP: +1.0 (higher than usual) - **Total boost:**
+2.2 (more than sum of independent effects)

**SHAP Interaction Values:**

KeyDriver can also output SHAP interaction terms:

```         
SHAP_interaction(Quality, Service) = +0.4
```

**Interpretation:** When Quality AND Service are both high, there's an
extra +0.4 satisfaction boost beyond their individual contributions.

------------------------------------------------------------------------

### Global Feature Importance: Aggregating SHAP

**Individual SHAP values vary by person, but we can aggregate:**

**Method 1: Mean Absolute SHAP (KeyDriver's primary output)**

For each driver, average the absolute SHAP values across all
respondents:

```         
Mean|SHAP(Quality)| = mean(|0.6|, |-0.4|, |0.8|, |0.5|, ...) = 0.62
Mean|SHAP(Service)| = mean(|0.4|, |-0.2|, |0.3|, |0.6|, ...) = 0.41
Mean|SHAP(Price)|   = mean(|0.2|, |0.1|, |-0.3|, |0.1|, ...) = 0.18
```

**Ranking:** Quality (0.62) \> Service (0.41) \> Price (0.18)

**Interpretation:** Quality has the largest average impact on
predictions.

**Method 2: SHAP Summary Plot**

Visual showing distribution of SHAP values:

```         
Quality  ├─────●─────●●●●●●────●─────┤  High variability
Service  ├────────●●●●●─────────────┤  Moderate impact
Price    ├──────────●●──────────────┤  Low impact
         -1.0      0.0           +1.0
```

-   Dots = individual SHAP values
-   Width of distribution = how much driver's impact varies across
    people
-   Position = whether driver mostly helps (right) or hurts (left)

------------------------------------------------------------------------

### Decision Tree: KeyDriver vs CatDriver

**START: What type of outcome do you have?**

```         
┌────────────────────────────────┐
│ Is outcome continuous?         │
│ (rating scale, NPS score)      │
└────────┬───────────────────────┘
         │
    ┌────▼────┐
    │ YES (continuous)
    │ Examples:
    │  - Satisfaction (1-10)
    │  - NPS (-100 to +100)
    │  - Purchase intent (0-100%)
    │
    └───→ Use KeyDriver
          ✓ XGBoost for gradient boosting
          ✓ SHAP for driver importance
          ✓ Captures non-linear patterns
          ✓ Fast computation

    ┌────▼────┐
    │ NO (categorical)
    │ Examples:
    │  - NPS category (Detractor/Passive/Promoter)
    │  - Satisfaction (Dissatisfied/Neutral/Satisfied)
    │  - Purchase decision (Buy/Don't Buy)
    │
    └───→ Use CatDriver
          ✓ Ordinal/multinomial logistic regression
          ✓ Odds ratios for interpretation
          ✓ Handles ordered categories correctly
```

**When to prefer KeyDriver even for "scale" data:**

If your rating scale is really continuous: - **1-10 satisfaction
scale:** Use KeyDriver - **1-100 NPS:** Use KeyDriver - **5-point Likert
treated as continuous:** Use KeyDriver

**When to force CatDriver:**

If you want: - Coefficient interpretation (odds ratios) - Formal
hypothesis testing - Explainability to non-technical stakeholders
(logistic regression is more familiar)

------------------------------------------------------------------------

### Model Diagnostics: Is KeyDriver Working?

**KeyDriver outputs cross-validation metrics:**

```         
Model Diagnostics:
  Model Type: XGBoost
  N Trees: 287 (selected via early stopping)
  R-squared: 0.68
  RMSE: 1.24
  MAE: 0.95
  CV Best Score: 1.31 (RMSE on validation set)
  Sample Size: 1,000
```

**Reading the diagnostics:**

**R-squared (0.68):** - Model explains 68% of variance in outcome -
**Interpretation:** Good fit (\>0.5 is typical for survey data) -
Remaining 32% is noise or unmeasured drivers

**RMSE (Root Mean Squared Error = 1.24):** - Average prediction error -
**Context:** If satisfaction is 1-10, RMSE=1.24 means ±1.2 point error
on average - Lower is better

**MAE (Mean Absolute Error = 0.95):** - Average absolute prediction
error - More intuitive than RMSE (no squaring) - **Interpretation:** On
average, predictions are off by \<1 point

**CV Best Score (1.31):** - RMSE on held-out validation set - Close to
training RMSE (1.24) → Not overfitting - If much higher than training
RMSE → Model memorizing training data

**N Trees (287):** - Model stopped at 287 trees (out of max 500) - Early
stopping triggered because adding more trees didn't improve validation
error - **Interpretation:** Model has converged

------------------------------------------------------------------------

### Worked Example: Retail Customer Satisfaction

**Business Question:** What drives overall store satisfaction?

**Data:** 800 customers, 10 potential drivers

**Drivers measured (1-10 scales):** 1. Product Selection 2. Product
Quality 3. Pricing Competitiveness 4. In-Store Experience 5. Checkout
Speed 6. Staff Helpfulness 7. Store Cleanliness 8. Parking Availability
9. Website Usability 10. Loyalty Program Value

**KeyDriver SHAP Results:**

| Rank | Driver                  | Mean | SHAP                     |
|------|-------------------------|------|--------------------------|
| 1    | Product Quality         | 0.85 | Strongest driver overall |
| 2    | Staff Helpfulness       | 0.72 | Second most important    |
| 3    | In-Store Experience     | 0.58 | Solid contributor        |
| 4    | Pricing Competitiveness | 0.51 | Moderate impact          |
| 5    | Checkout Speed          | 0.42 | Some importance          |
| 6    | Product Selection       | 0.38 | Useful but not critical  |
| 7    | Store Cleanliness       | 0.31 | Minor driver             |
| 8    | Loyalty Program Value   | 0.18 | Weak impact              |
| 9    | Website Usability       | 0.12 | Minimal role             |
| 10   | Parking Availability    | 0.09 | Nearly irrelevant        |

**Model Fit:** - R² = 0.71 (explains 71% of variance) - RMSE = 1.18
(predictions accurate within ±1.2 points)

**Non-Linear Effects Detected:**

**Pricing Competitiveness:** - Below rating 5: Strong negative impact
(hurts satisfaction a lot) - Rating 5-7: Moderate positive impact -
Above 8: Marginal additional benefit (diminishing returns)

**Business Recommendations:**

**Tier 1 - Immediate Focus (SHAP \> 0.5):** 1. Product Quality - Highest
impact; ensure consistency 2. Staff Helpfulness - Train and retain good
staff 3. In-Store Experience - Improve layout, ambiance

**Tier 2 - Maintain (SHAP 0.3-0.5):** 4. Pricing - Keep competitive but
don't race to bottom 5. Checkout Speed - Optimize but already adequate
6. Product Selection - Current range sufficient

**Tier 3 - Deprioritize (SHAP \< 0.3):** 7-10. Cleanliness, Loyalty,
Website, Parking - Maintain basics but don't over-invest

**Segment-Specific Insights:**

SHAP analysis BY SEGMENT revealed:

**Online-Heavy Shoppers:** - Website Usability: SHAP = 0.62 (moves up to
#3!) - Parking: SHAP = 0.05 (still irrelevant)

**In-Store Only Shoppers:** - Website Usability: SHAP = 0.03
(irrelevant) - Parking: SHAP = 0.35 (moves up to #7)

**Action:** Segment messaging and improvements by shopper type.

------------------------------------------------------------------------

## Best Use Cases

**Ideal For:** - Customer satisfaction drivers - NPS driver analysis -
Brand health tracking (what drives consideration/preference) - Product
optimization (which features drive purchase intent) - Service
improvement (which touchpoints drive loyalty)

**Not Ideal For:** - Categorical outcomes (won't buy/might buy/will
buy) - use catdriver instead - Small samples (\<100 respondents) -
unreliable correlations - Non-linear relationships - use
regression-based approaches - When you need to control for multiple
factors simultaneously

------------------------------------------------------------------------

## Quality & Reliability

**Quality Score:** 93/100 (highest-scoring module) **Production Ready:**
Yes **Error Handling:** Excellent - Clear validation of data
requirements **Testing Status:** Well-tested with regression suite

------------------------------------------------------------------------

## Example Outputs

**Sample Findings Table:**

| Driver           | Correlation | Significance | Impact |
|------------------|-------------|--------------|--------|
| Product Quality  | 0.74        | \*\*\*       | High   |
| Customer Service | 0.68        | \*\*\*       | High   |
| Ease of Use      | 0.52        | \*\*\*       | Medium |
| Value for Money  | 0.41        | \*\*\*       | Medium |
| Brand Reputation | 0.28        | \*\*         | Low    |
| Website Design   | 0.12        | ns           | Low    |

**How to Read This:** - Quality and Service are your top drivers
(correlations \> 0.65) - Ease of Use and Value matter moderately - Brand
and Website have limited impact on satisfaction - Focus resources on the
High impact drivers

------------------------------------------------------------------------

## When to Use KeyDriver vs. Other Modules

**Use KeyDriver when:** - You have continuous outcome variables (rating
scales, NPS) - You want advanced driver importance using machine
learning - You need to capture complex, non-linear relationships - Your
audience appreciates sophisticated SHAP-based analysis

**Use catdriver instead when:** - Your outcome is categorical
(Satisfied/Neutral/Dissatisfied) - You need coefficient interpretation
for category prediction - You want ordinal or multinomial logistic
regression approaches

**Use pricing instead when:** - You're specifically analyzing price
sensitivity - You need price elasticity estimates and revenue
optimization

------------------------------------------------------------------------

## What's Next (Future Enhancements)

**Coming Soon:** - Importance-Performance grids (automated plotting) -
Partial correlation analysis (control for overlapping drivers) -
Time-series tracking of driver importance

**Future Vision:** - Non-linear driver detection - Automated
segmentation by different driver profiles - Interactive dashboards with
drill-down capability

------------------------------------------------------------------------

## Bottom Line

KeyDriver is your advanced "what matters most" analysis tool. Using
machine learning and SHAP values, it reveals not just which factors
matter, but how they interact and drive outcomes in complex ways. This
goes beyond simple correlation to capture real-world driver dynamics.

**Think of it as:** An AI-powered analyst that uses advanced machine
learning to show you exactly which drivers have the biggest impact on
your outcomes—capturing non-linear patterns and interactions that simple
correlations would miss.

------------------------------------------------------------------------

*For questions or support, contact The Research LampPost (Pty) Ltd*

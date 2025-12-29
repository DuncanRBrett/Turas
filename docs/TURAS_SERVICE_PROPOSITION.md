# Turas Analytics Service
## Your White-Label Statistical Analysis Partner

---

## The Problem We Solve

You won surveys. You have data. Now you need:
- Crosstabs with significance testing
- Weighting that actually works
- Key driver analysis that clients understand
- Segmentation that's defensible
- Conjoint and MaxDiff without Sawtooth's price tag

You could license software, hire specialists, or build capability internally. Each option costs time, money, and carries risk.

**Or you could send us data and receive analysis-ready outputs.**

---

## What We Offer

Turas is a unified analytics platform purpose-built for market research. We operate it; you deliver to your clients. Your brand, our engine.

### Service Model

```
Your Data → Turas Processing → Deliverables with Your Branding
     ↑                              ↓
  You own the          You deliver to
  client relationship  your client
```

**What you send:** Data files + specifications
**What you receive:** Analysis outputs (Excel, charts, data files)
**What your client sees:** Your deliverables

---

## Module Capabilities

### Crosstabs & Banner Tables

**What it does:**
Full-featured crosstabulation with column percentages, row percentages, significance testing (z-tests, chi-square), and multi-banner support. Handles weighted and unweighted bases, effective sample sizes, and small base warnings.

**Why it matters:**
Crosstabs are the backbone of quantitative research delivery. Our system processes complex studies with hundreds of questions across dozens of banners without manual intervention.

**Technical foundation:**
- Base R statistical functions for chi-square and proportion tests
- `openxlsx` for formatted Excel output with conditional formatting
- Checkpoint system for large studies (recovers from interruptions)
- Memory management for datasets exceeding 100,000 respondents

**Output quality:**
- Automatic small base suppression and flagging
- Letter-based significance notation (A/B/C) or arrow indicators
- Consistent formatting across all tables

---

### Survey Weighting

**What it does:**
Design weights (cell weighting) and rim weights (iterative proportional fitting/raking). Includes weight trimming, convergence diagnostics, and efficiency calculations.

**Why it matters:**
Bad weights corrupt every downstream analysis. Our weighting module provides full diagnostics so you can verify the solution before applying it.

**Technical foundation:**
Built on the `survey` package by Thomas Lumley (UCLA/University of Auckland). This is the same statistical engine used by:
- US Census Bureau
- CDC National Health Surveys
- World Health Organization studies

The `survey` package has 15+ years of production use and peer-reviewed methodology. It's not experimental code—it's the R standard for complex survey analysis.

**Capabilities:**
- Multiple rim dimensions with convergence monitoring
- Weight trimming with configurable bounds
- Effective sample size calculation
- Cell-by-cell diagnostic output

---

### Key Driver Analysis

**What it does:**
Identifies which attributes drive an outcome (satisfaction, likelihood to recommend, purchase intent). Uses regression-based importance decomposition with optional SHAP (machine learning) validation.

**Why it matters:**
"What should we prioritize?" is the question behind most research. Key driver analysis answers it with statistical rigor, not gut feel.

**Technical foundation:**

*Primary method: Partial R² decomposition*
Based on Lindeman, Merenda, and Gold (1980) methodology—the established approach for relative importance in correlated predictor settings. This isn't a proprietary algorithm; it's textbook psychometrics implemented correctly.

*Secondary method: SHAP values (optional)*
Uses `xgboost` (gradient boosting) with TreeSHAP for model-agnostic importance. XGBoost is the most battle-tested ML library in production use globally, with implementations at:
- Airbnb, Uber, and major tech companies
- Kaggle competition winners (used in majority of winning solutions)
- Financial risk modeling at major banks

When regression and SHAP agree, you have high confidence. When they diverge, you have a conversation worth having with your client.

**Output includes:**
- Ranked importance scores (normalized to 100%)
- Performance scores (mean ratings per driver)
- Importance-Performance quadrant chart
- Statistical significance of each driver

---

### Categorical Driver Analysis

**What it does:**
Key driver analysis for categorical outcomes—binary (yes/no), ordinal (satisfaction scales), or multinomial (brand choice). Uses logistic regression with proper effect coding.

**Why it matters:**
Standard key driver analysis assumes a continuous outcome. When your dependent variable is "Did they churn: Yes/No" or "Which brand did they choose," you need categorical methods.

**Technical foundation:**
- Binary outcomes: Base R `glm()` with logit link
- Ordinal outcomes: `MASS::polr()` (proportional odds model)
- Multinomial outcomes: `nnet::multinom()`

These are established R packages maintained by the R Core Team and Brian Ripley (Oxford). They've been stable for 20+ years.

**Methodological rigor:**
- Canonical coefficient-to-level mapping (no string parsing hacks)
- Rare level handling with deterministic collapsing
- Per-variable missing data strategies
- Optional bootstrap confidence intervals

---

### Segmentation

**What it does:**
K-means clustering with systematic evaluation of segment solutions. Includes exploration mode (test K=2 through K=8) and final mode (apply chosen solution). Outputs segment profiles, discriminating variables, and assignment scores.

**Why it matters:**
Bad segmentation is worse than no segmentation—it gives false confidence in fictional customer groups. Our module enforces methodological discipline: you see fit statistics, you evaluate stability, you make an informed choice.

**Technical foundation:**
- `stats::kmeans()` — Base R implementation, numerically stable
- Silhouette analysis for cluster quality
- Gap statistic for optimal K selection
- Discriminant analysis for segment profiling

**Advanced options:**
- Latent Class Analysis via `poLCA` package (categorical clustering)
- Outlier detection and handling
- Segment scoring for new respondent classification
- Rule-based segment assignment for operational deployment

---

### MaxDiff Analysis

**What it does:**
Maximum Difference Scaling—respondents choose "best" and "worst" from item sets, producing ratio-scaled preference scores. Supports both aggregate analysis and individual-level Hierarchical Bayes estimation.

**Why it matters:**
MaxDiff solves the "everything is important" problem. By forcing tradeoffs, it reveals true priorities. Individual-level HB allows segmentation on preferences.

**Technical foundation:**

*Aggregate analysis:*
Uses conditional logistic regression via `survival::clogit()`. The survival package is maintained by Terry Therneau at Mayo Clinic and has 30+ years of development. It's the foundation of most clinical trial analysis in R.

*Hierarchical Bayes (optional):*
Uses `cmdstanr` (Stan probabilistic programming language). Stan is developed by the Stan Development Team including Andrew Gelman (Columbia) and is the academic standard for Bayesian inference. It's used in:
- Pharmaceutical clinical trials
- Sports analytics (538, major leagues)
- Tech industry A/B testing at scale

**Capabilities:**
- Design generation (balanced incomplete block designs)
- Aggregate logit with rescaling to 0-100
- Individual-level HB utilities
- Preference share simulation

**Honest positioning:**
Our MaxDiff handles standard projects well. For complex designs with prohibitions, conditional display, or alternative-specific attributes, Sawtooth remains the specialist. We cover 80% of MaxDiff use cases at a fraction of the cost.

---

### Conjoint Analysis

**What it does:**
Choice-Based Conjoint (CBC) analysis using multinomial logit. Calculates part-worth utilities and attribute importance from discrete choice data.

**Why it matters:**
Conjoint is how you build pricing models, optimize product configurations, and simulate market scenarios. It's essential for product development and pricing research.

**Technical foundation:**
- Primary: `mlogit` package by Yves Croissant (University of the Reunion)
- Fallback: `survival::clogit()` for conditional logit estimation

The `mlogit` package is the R standard for discrete choice modeling, implementing the methodology from Kenneth Train's textbook "Discrete Choice Methods with Simulation" (UC Berkeley).

**Capabilities:**
- Part-worth utility estimation
- Zero-centered utilities for interpretation
- Attribute importance calculation
- Direct import from Alchemer CBC exports

**Honest positioning:**
Like MaxDiff, our conjoint covers standard CBC designs. Sawtooth's ACBC (Adaptive CBC), menu-based conjoint, and volumetric conjoint are beyond our current scope.

---

### Pricing Research

**What it does:**
Van Westendorp Price Sensitivity Meter (PSM) and Gabor-Granger demand curve analysis. Includes segment-level analysis, price ladder generation, and recommendation synthesis.

**Why it matters:**
Pricing is high-stakes. Getting it wrong costs real money. Our module provides the established methodologies with clear documentation of assumptions.

**Technical foundation:**
- `pricesensitivitymeter` package for Van Westendorp PSM
- Newton-Miller-Smith (NMS) extension for purchase probability adjustment
- Custom Gabor-Granger implementation for demand curves

The Van Westendorp methodology dates to 1976 and is industry-standard for early-stage pricing exploration. We implement it correctly, including the NMS extension that adjusts for hypothetical purchase intent inflation.

**Output includes:**
- Acceptable price range (point of marginal cheapness to marginal expensiveness)
- Optimal price point (intersection method)
- Indifference price point
- Revenue-maximizing price (Gabor-Granger)
- Segment-level price sensitivity comparison
- Price ladder recommendations (Good/Better/Best)

---

### Tracker Analysis

**What it does:**
Longitudinal analysis across survey waves. Calculates trends, tests for significant wave-over-wave changes, and generates tracking dashboards.

**Why it matters:**
Tracking studies are recurring revenue, but they're operationally complex. Question codes change, response options evolve, and sample compositions shift. Our module handles the messy reality of multi-wave data.

**Capabilities:**
- Multi-wave data alignment with question mapping
- Significance testing for trend changes (proportions and means)
- Banner-level trend analysis (track by segment over time)
- Automated dashboard generation
- Wave-over-wave and baseline comparison

---

### Confidence Interval Calculator

**What it does:**
Calculates confidence intervals for survey estimates, properly accounting for design effects (DEFF) and effective sample sizes.

**Why it matters:**
Most survey tools report confidence intervals as if the data were simple random samples. For weighted, clustered, or stratified designs, this understates uncertainty—sometimes dramatically. Our module gets it right.

**Technical foundation:**
Design effect calculations based on Kish (1965)—the foundational text for survey sampling. We calculate effective sample sizes and adjust confidence intervals accordingly.

**Output includes:**
- Point estimates with proper CIs
- Design effect estimates
- Effective sample size by question
- Flagging for estimates with high uncertainty

---

## Why R? Why These Packages?

### The Case for R

R is the lingua franca of statistical computing. It's:
- **Free and open source** — No licensing games, no vendor lock-in
- **Academically validated** — Methods are published and peer-reviewed
- **Industry standard** — Used by Google, Facebook, Pfizer, FDA, and major research institutions
- **Continuously improved** — Active development with 20,000+ packages on CRAN

### Package Selection Criteria

Every R package in Turas was chosen based on:

1. **CRAN publication** — Passed R's quality checks
2. **Active maintenance** — Recent updates, responsive maintainers
3. **Established use** — Years of production deployment
4. **Academic foundation** — Methods tied to published research

### Package Provenance

| Package | Maintainer/Origin | Production Use |
|---------|-------------------|----------------|
| `survey` | Thomas Lumley (UCLA) | US Census, CDC, WHO |
| `survival` | Terry Therneau (Mayo Clinic) | Clinical trials worldwide |
| `mlogit` | Yves Croissant (academic) | Discrete choice research |
| `xgboost` | DMLC (distributed ML community) | Tech industry ML at scale |
| `cmdstanr` | Stan Development Team (Columbia) | Pharma, sports analytics, tech |
| `openxlsx` | Philipp Schauberger | Enterprise R deployments |
| `MASS` | Brian Ripley (Oxford) | R Core Team maintained |

These aren't obscure packages. They're the established tools used by statisticians worldwide.

---

## Quality Assurance

### Error Handling Philosophy

Turas implements a "no silent failures" policy. Every analysis run produces one of four outcomes:

| Status | Meaning |
|--------|---------|
| **PASS** | Analysis completed successfully |
| **PARTIAL** | Analysis completed with degraded output (documented) |
| **REFUSE** | Analysis could not proceed (reason explained) |
| **ERROR** | Unexpected failure (diagnostic information captured) |

When something goes wrong, you get a structured message explaining:
- What happened
- Why it matters
- How to fix it

No cryptic error codes. No silent data corruption. No outputs that look fine but aren't.

### Data Integrity

All Excel outputs use atomic file writes:
1. Write to temporary file
2. Verify file integrity
3. Rename to final location

If the process is interrupted, you get either a complete file or no file—never a corrupted partial output.

---

## Service Tiers

### Standard Turnaround

| Analysis Type | Typical Turnaround |
|---------------|-------------------|
| Crosstabs | Same-day to next-day |
| Weighting | Same-day |
| Key Drivers | 2-3 business days |
| Segmentation | 3-5 business days |
| MaxDiff/Conjoint | 3-5 business days |
| Pricing | 2-3 business days |
| Tracker Wave | 1-2 business days |

### What's Included

- Analysis outputs in Excel and/or CSV
- Methodology documentation for your client appendix
- Quality-checked results with diagnostic flags reviewed
- One round of revisions per deliverable
- Your branding (or no branding, as you prefer)

### What's Not Included

- Raw R code or scripts
- Software access
- Training on methodology
- Client-facing presentations (though we can discuss)

---

## Why Partner With Us

### For Agency Researchers

You're selling strategy and insight. Data processing is necessary but not differentiating. Let us handle the statistical machinery while you focus on interpretation and client relationships.

**You get:**
- Capacity without headcount
- Consistent quality across projects
- Access to advanced methods without specialist hiring
- Lower cost than software licensing + analyst time

### For Boutique Firms

You compete on expertise, not infrastructure. Statistical software licenses and IT overhead drain resources from what matters—client work.

**You get:**
- Enterprise-grade analytics without enterprise costs
- Flexibility to take on projects outside your current capability
- Backup capacity for peak periods
- Focus on your differentiation, not plumbing

### For In-House Teams

Your stakeholders want answers, not analysis plans. When specialized projects arise, you need reliable partners who understand research methodology.

**You get:**
- On-demand specialist capability
- Consistent methodology across studies
- Documentation that satisfies internal governance
- No long-term commitment

---

## Getting Started

### What We Need From You

1. **Data file** — SPSS (.sav), Excel, or CSV
2. **Specifications** — What analysis, what variables, what banners
3. **Timeline** — When you need deliverables
4. **Branding requirements** — Your logo, colors, formatting preferences

### What Happens Next

1. We review specifications and confirm scope
2. We process through Turas
3. We quality-check outputs
4. You receive deliverables
5. You deliver to your client

---

## Contact

[Your contact information here]

---

*Turas: Reliable analytics infrastructure for market research professionals.*

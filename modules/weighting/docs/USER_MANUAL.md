# Turas Weighting Module — User Manual

**Version:** 3.0
**Last Updated:** March 2026
**Target Audience:** Market Researchers, Data Analysts, Survey Managers

---

## Table of Contents

1. [What This Module Does](#1-what-this-module-does)
2. [Before You Start — Know Your Data](#2-before-you-start--know-your-data)
3. [Choosing Your Weighting Method](#3-choosing-your-weighting-method)
4. [Setting Up Your Configuration File](#4-setting-up-your-configuration-file)
5. [Running the Analysis](#5-running-the-analysis)
6. [Understanding Your Output](#6-understanding-your-output)
7. [Understanding Diagnostics](#7-understanding-diagnostics)
8. [Interpreting the HTML Report](#8-interpreting-the-html-report)
9. [Troubleshooting](#9-troubleshooting)
10. [Decision Flowcharts](#10-decision-flowcharts)
11. [Complete Worked Example](#11-complete-worked-example)
12. [Quick Reference Tables](#12-quick-reference-tables)

---

## 1. What This Module Does

The Weighting module calculates **survey weights** to correct sample biases so your data accurately represents the target population.

In almost every survey, some groups are over-represented and others under-represented. Weighting adjusts for this by assigning a multiplier (a "weight") to each respondent. Under-represented respondents get a weight greater than 1; over-represented respondents get a weight less than 1.

### Three Weighting Methods

| Method | When to Use | How It Works |
|--------|-------------|--------------|
| **Design** | Stratified samples with known population sizes | Weight = population share / sample share per stratum |
| **Rim (Raking)** | Multiple demographics need simultaneous adjustment | Iteratively adjusts to match marginal distributions |
| **Cell (Interlocked)** | Joint distribution matters (e.g., age × gender) | Weight = target proportion / observed proportion per cell |

All three methods can be combined in a single run, producing multiple weight columns.

### When to Use This Module

- Your sample demographics don't match the target population
- You used stratified sampling and need to correct for unequal selection probabilities
- You need weighted survey data for downstream analysis (tabs, tracking, driver analysis)

### When NOT to Use This Module

- **Census data** — If everyone in the population was sampled, no weighting needed
- **Very small samples** (n < 50) — Weighting amplifies noise in small samples
- **Severely biased samples** — If entire population segments are missing, weighting can't fix that
- **Exploratory analysis** — Sometimes unweighted data is more appropriate for initial exploration

---

## 2. Before You Start — Know Your Data

Before configuring anything, answer these questions:

### Question 1: What population should your sample represent?

You need to be specific. "Adults in South Africa" is a population. "Online shoppers aged 18-65" is a population. Your weighting targets must come from a known source for this population (census data, industry stats, client specifications).

### Question 2: What format is your data?

Supported formats:
- `.csv` — Comma-separated values (most common)
- `.xlsx` — Excel workbooks
- `.sav` — SPSS data files (requires `haven` package)

### Question 3: Do you have population statistics?

You need **target percentages or population counts** for the variables you want to weight on. These typically come from:
- Census data (Stats SA, US Census Bureau, etc.)
- Panel book specifications
- Client-provided targets
- Industry benchmarks

**If you don't have population statistics, you cannot weight.** This module calculates weights, it doesn't estimate what the population looks like.

### Question 4: How many variables need adjustment?

| Number of Variables | Recommended Method |
|--------------------|--------------------|
| 1 variable (e.g., just Region) | **Design** weights |
| 2–5 variables (e.g., Age, Gender, Region) | **Rim** weights |
| 2–3 variables where the joint distribution matters | **Cell** weights |
| 1 stratification variable + 2–5 demographics | **Design + Rim** (combined) |

### Question 5: Are there empty cells in your cross-tabulation?

If you're considering cell weighting, check: does every combination of your weighting variables have at least one respondent? If not, cell weighting is impossible — use rim weighting instead.

### Question 6: What is your minimum sample size per category?

Categories with fewer than 20 respondents can produce extreme weights. Consider collapsing small categories before weighting (e.g., combine "18-24" and "25-34" into "18-34").

### Question 7: Are there missing values in your weighting variables?

Respondents with `NA` in any weighting variable are **excluded** from that weight's calculation. Check your data for completeness before weighting.

---

## 3. Choosing Your Weighting Method

### Design Weights

**Best for:**
- Stratified samples where you deliberately over/under-sampled specific groups
- B2B surveys sampled by company size
- Regional studies with geographic stratification

**How it works:** If the North region is 35% of the population but only 20% of your sample, respondents from the North get a weight of 35/20 = 1.75.

**Pros:** Simple, deterministic, no iteration needed.
**Cons:** Corrects for only one stratification variable at a time.

### Rim Weights (Raking)

**Best for:**
- Online panels needing demographic adjustment
- Quota samples that didn't perfectly match targets
- Any survey where multiple demographics need correction simultaneously

**How it works:** Iteratively adjusts weights so that the weighted marginal distributions match your targets for each variable. Uses `survey::calibrate()` internally.

**Pros:** Corrects multiple variables simultaneously. Widely used in market research.
**Cons:** Can produce extreme weights if sample is far from targets. May not converge with too many variables.

**Key pitfalls:**
- Don't use more than ~5 rim variables — convergence becomes unstable
- Check that no category has fewer than ~20 respondents
- Always review the design effect (DEFF > 2.0 means your effective sample is halved)

### Cell Weights (Interlocked)

**Best for:**
- When the joint distribution matters (e.g., young males are specifically under-represented)
- When rim weighting doesn't adequately correct because biases are concentrated in specific cells

**How it works:** Calculates the weight for each unique combination of variables. Weight = target proportion / observed proportion for that cell.

**Pros:** Precisely matches the joint distribution. No iteration.
**Cons:** Every cell must have at least one respondent. Sparse cells produce extreme weights.

**Key pitfalls:**
- With 3+ variables the number of cells explodes (5 ages × 2 genders × 4 regions = 40 cells)
- Empty cells make cell weighting impossible — use rim instead
- Very small cells (n < 5) produce very high weights

### Decision Table

| Your Situation | Recommended Method |
|---|---|
| Stratified sample, one variable | Design |
| Online panel, 2–5 demographics to match | Rim |
| Specific age × gender cells are off | Cell |
| Stratified sample + demographic adjustment | Design + Rim (combined run) |
| Many variables (>5) | Rim, but collapse categories first |
| Some cells are empty | Rim (not Cell) |
| You want the joint distribution perfect | Cell (if all cells populated) |

---

## 4. Setting Up Your Configuration File

The config file is an Excel workbook (`.xlsx`). You can generate a template:

```r
source("modules/weighting/lib/generate_config_templates.R")
generate_all_weighting_templates("my_project/")
```

### General Sheet (Required)

Key-value format with `Setting` and `Value` columns:

| Setting | Example Value | Required | Description |
|---------|--------------|----------|-------------|
| `project_name` | Brand Health 2026 | **Yes** | Project identifier |
| `data_file` | data/survey.csv | **Yes** | Path to input data |
| `output_file` | output/weighted.csv | No | Path for weighted data output |
| `save_diagnostics` | Y | No | Generate diagnostics workbook |
| `diagnostics_file` | output/diagnostics.xlsx | If save_diagnostics=Y | Diagnostics path |
| `html_report` | Y | No | Generate HTML report |
| `html_report_file` | output/report.html | No | HTML report path (auto if blank) |
| `brand_colour` | #1e3a5f | No | Brand hex colour for HTML report |
| `accent_colour` | #2aa198 | No | Accent hex colour |
| `researcher_name` | Jane Smith | No | Researcher name in report header |
| `client_name` | Acme Corp | No | Client name in report header |
| `logo_file` | assets/logo.png | No | Logo for HTML report (PNG/JPG/SVG) |

All file paths are **relative to the config file location** (or absolute).

### Weight_Specifications Sheet (Required)

One row per weight to calculate:

| weight_name | method | apply_trimming | trim_method | trim_value |
|-------------|--------|----------------|-------------|------------|
| design_wt | design | N | | |
| demo_wt | rim | Y | cap | 5 |
| cell_wt | cell | N | | |

- `weight_name` — Unique name for the weight column added to your data
- `method` — `design`, `rim`, `rake`, or `cell`
- `apply_trimming` — `Y` or `N`
- `trim_method` — `cap` (absolute maximum) or `percentile` (percentile range)
- `trim_value` — For cap: maximum weight (e.g., 5). For percentile: upper percentile (e.g., 95)

### Design_Targets Sheet (Required if method = "design")

| weight_name | stratum_variable | stratum_category | population_size |
|-------------|-----------------|------------------|-----------------|
| design_wt | Region | North | 250000 |
| design_wt | Region | South | 180000 |
| design_wt | Region | East | 120000 |
| design_wt | Region | West | 150000 |

### Rim_Targets Sheet (Required if method = "rim" or "rake")

| weight_name | variable | category | target_percent |
|-------------|----------|----------|----------------|
| demo_wt | Gender | Male | 48.5 |
| demo_wt | Gender | Female | 51.5 |
| demo_wt | Age | 18-34 | 30.0 |
| demo_wt | Age | 35-54 | 40.0 |
| demo_wt | Age | 55+ | 30.0 |

**Rules:**
- `target_percent` values must sum to 100 for each variable (0.5% tolerance)
- Category names must match your data exactly (case-sensitive)
- Maximum ~5 rim variables recommended

### Cell_Targets Sheet (Required if method = "cell")

| weight_name | Gender | Age | target_percent |
|-------------|--------|-----|----------------|
| cell_wt | Male | 18-34 | 14.5 |
| cell_wt | Male | 35-54 | 19.4 |
| cell_wt | Male | 55+ | 14.6 |
| cell_wt | Female | 18-34 | 15.5 |
| cell_wt | Female | 35-54 | 20.6 |
| cell_wt | Female | 55+ | 15.4 |

**Rules:**
- All `target_percent` values must sum to 100 (0.5% tolerance)
- Every combination of variable levels must have a row
- Every combination must appear in your data (no empty cells)

### Advanced_Settings Sheet (Optional)

Fine-tune rim weight calculation:

| weight_name | max_iterations | convergence_tolerance | force_convergence |
|-------------|---------------|----------------------|-------------------|
| demo_wt | 100 | 0.001 | N |

- `max_iterations` — Maximum raking iterations (default: 50)
- `convergence_tolerance` — Stopping threshold (default: 0.01)
- `force_convergence` — `Y` to accept non-converged weights (not recommended)

### Notes Sheet (Optional)

| Section | Note |
|---------|------|
| Assumptions | Population data sourced from Census 2021 |
| Methodology | Rim weighting chosen over cell due to sparse cells |
| Data Quality | 3 records excluded due to missing age |

Notes appear in the HTML report and Excel diagnostics.

---

## 5. Running the Analysis

### From the Turas GUI

1. Launch Turas (`source("launch_turas.R"); launch_turas()`)
2. Click **Weighting** in the module list
3. Browse to your project folder and select your config file
4. Click **Calculate Weights**
5. Progress is shown in real-time; results appear when complete

### From R Script

```r
source("modules/weighting/run_weighting.R")
result <- run_weighting("path/to/Weight_Config.xlsx")

if (result$status == "PASS") {
  cat("Weights calculated successfully!\n")
  cat("Output:", result$output_file, "\n")
}
```

### From Command Line

```bash
Rscript modules/weighting/run_weighting.R path/to/Weight_Config.xlsx
```

### Generating a Config Template

```r
source("modules/weighting/lib/generate_config_templates.R")
generate_all_weighting_templates("my_project/")
```

This creates a professional Excel template with dropdown validation, colour-coded sections, and help text.

---

## 6. Understanding Your Output

### Weighted Data File

Your original data with weight column(s) added. If you configured `output_file = "output/weighted.csv"`, the file is saved there. The `result$data` object also contains the weighted data in memory.

### Excel Diagnostics Workbook

If `save_diagnostics = Y`, generates an Excel workbook with:
- **Summary** sheet — Overview of all weights with key metrics
- **Per-weight detail** sheets — Detailed diagnostics per weight
- **Configuration** sheet — Full config used for reproducibility
- **Notes** sheet — Your methodology notes
- **Run_Status** sheet — TRS execution log

### HTML Report

If `html_report = Y`, generates a self-contained interactive HTML report with:
- **Summary tab** — All weights with diagnostic metrics
- **Weight Details tab** — Per-weight distribution charts and diagnostics
- **Method Notes tab** — Your methodology notes

The HTML report can be combined with other Turas reports via the Report Hub.

---

## 7. Understanding Diagnostics

Every weight run produces these diagnostic metrics:

| Metric | Good | Acceptable | Poor | What It Means |
|--------|------|------------|------|---------------|
| **DEFF** | < 1.5 | 1.5–2.0 | > 2.0 | How much variance increases due to weighting. DEFF=2 means you need 2× the sample for the same precision. |
| **Efficiency** | > 70% | 50–70% | < 50% | 1/DEFF as a percentage. Higher is better. |
| **CV** | < 0.5 | 0.5–1.0 | > 1.0 | Coefficient of variation of weights. Lower = more uniform. |
| **Max Weight** | < 3 | 3–5 | > 5 | Largest individual weight. Very high = one respondent counts as many. |

### What These Mean in Practice

- **DEFF of 2.0** means your 1,000-respondent survey has the precision of a 500-respondent unweighted survey
- **Efficiency of 50%** means half your sample size is "lost" to weighting variance
- **Max weight of 8** means one respondent counts as 8 people — that's a lot of influence for one person

### When to Apply Trimming

Apply trimming (`apply_trimming = Y`) when:
- Max weight exceeds 5
- Design effect exceeds 2.0
- A small number of respondents have disproportionate influence

**Cap method:** Sets a hard maximum (e.g., `trim_value = 5` means no weight exceeds 5).
**Percentile method:** Trims to a percentile range (e.g., `trim_value = 95` caps at the 95th percentile).

**Trade-off:** Trimming introduces a small bias (weighted distribution won't perfectly match targets) but reduces variance. This is almost always a good trade-off.

---

## 8. Interpreting the HTML Report

The HTML report has three tabs:

### Summary Tab
Shows all calculated weights with key diagnostic metrics (DEFF, efficiency, CV, weight range). Traffic-light colour coding: green = good, amber = acceptable, red = poor.

### Weight Details Tab
Per-weight breakdown showing:
- Weight distribution histogram
- Before/after comparison of weighted vs. unweighted margins
- Detailed metrics table

### Method Notes Tab
Your methodology notes from the Notes sheet, displayed for documentation and audit purposes.

The report is fully self-contained — no external dependencies, works offline, can be emailed as an attachment.

---

## 9. Troubleshooting

### "Category 'X' not found in data"

**Code:** `DATA_CATEGORY_MISMATCH`

Category names in your targets must match your data **exactly** (case-sensitive). "Male" in targets but "male" in data will fail. Check both your data and your target sheets.

### "Target percentages do not sum to 100"

**Code:** `CFG_TARGET_SUM`

Target percentages must sum to 100 for each variable (0.5% tolerance). Double-check your arithmetic. Common issue: rounding errors in percentages.

### "Rim weighting did not converge"

**Code:** `CALC_CONVERGENCE`

The iterative process didn't reach a stable solution. Options:
1. Reduce the number of rim variables (max 5 recommended)
2. Collapse small categories
3. Increase `max_iterations` in Advanced_Settings (try 200)
4. Reduce `convergence_tolerance` (try 0.05 instead of 0.01)
5. Check that your sample isn't severely different from targets

### "Empty cell in cell weighting"

**Code:** `DATA_EMPTY_CELL`

At least one combination of your cell variables has zero respondents. Solutions:
1. Switch to rim weighting instead
2. Collapse categories to eliminate empty cells
3. Remove the empty combination from targets (not recommended)

### "Missing values in weighting variable"

**Code:** `DATA_MISSING_VALUES` (warning)

Respondents with NA in a weighting variable are excluded from that weight. If many respondents are excluded, check your data quality. Consider imputing missing values before weighting.

### "Data file not found"

**Code:** `IO_FILE_NOT_FOUND`

Check the `data_file` path in your General sheet. Paths are relative to the config file location. Use forward slashes (/) not backslashes.

### Console errors not visible in Shiny

Check the R console/terminal where the Shiny app was launched. All errors are output to the console in a boxed format. Never rely solely on the Shiny UI for error messages.

---

## 10. Decision Flowcharts

### Choosing a Weighting Method

```
START: How many variables need adjustment?
  │
  ├─ ONE variable
  │    └─ Is it a stratification variable with known population sizes?
  │         ├─ YES → Use DESIGN weights
  │         └─ NO  → Use RIM weights (single variable)
  │
  ├─ TWO to FIVE variables
  │    └─ Does the joint distribution matter?
  │         ├─ YES → Are all cells populated?
  │         │    ├─ YES → Use CELL weights
  │         │    └─ NO  → Use RIM weights
  │         └─ NO  → Use RIM weights
  │
  └─ MORE than five variables
       └─ Collapse categories, then use RIM weights
```

### Choosing Trimming Settings

```
START: Run weights without trimming first. Check diagnostics.
  │
  ├─ DEFF < 1.5 and Max Weight < 3
  │    └─ No trimming needed ✓
  │
  ├─ DEFF 1.5–2.0 or Max Weight 3–5
  │    └─ Consider trimming (optional)
  │         └─ Use CAP method, trim_value = 5
  │
  └─ DEFF > 2.0 or Max Weight > 5
       └─ Trimming recommended
            ├─ Few extreme weights → CAP method (trim_value = 4 or 5)
            └─ Many high weights → PERCENTILE method (trim_value = 95)
```

---

## 11. Complete Worked Example

### Scenario

You have an online consumer panel survey (n=500) for a South African brand health study. Your panel skews young and male. You need the data to represent the SA adult population by age, gender, and province (LSM available).

### Step 1: Decide on Method

- 3 variables (Age, Gender, Province) → **Rim weights**
- Joint distribution not critical → Rim is appropriate
- No empty cells in cross-tab → Cell would also work, but Rim is simpler

### Step 2: Prepare Targets

From Stats SA Census data:
- Gender: Male 48.5%, Female 51.5%
- Age: 18-34 35%, 35-54 35%, 55+ 30%
- Province: Gauteng 26%, KZN 19%, WC 12%, Other 43%

### Step 3: Create Config File

Use the template generator, then fill in the General and Rim_Targets sheets.

### Step 4: Run

```r
source("modules/weighting/run_weighting.R")
result <- run_weighting("Brand_Health_Config.xlsx")
```

### Step 5: Check Diagnostics

Output shows DEFF = 1.8, Max Weight = 4.2, Efficiency = 56%.

**Interpretation:** DEFF of 1.8 is acceptable but not great. Effective sample = 500 / 1.8 = 278. Max weight of 4.2 means the most extreme respondent counts as 4.2 people.

**Decision:** Apply cap trimming at 4.0 to reduce the max weight.

### Step 6: Re-run with Trimming

Update Weight_Specifications: `apply_trimming = Y`, `trim_method = cap`, `trim_value = 4`.

Re-run. DEFF drops to 1.6, Max Weight = 4.0, Efficiency = 63%. This is acceptable.

---

## 12. Quick Reference Tables

### All Configuration Fields

| Sheet | Field | Required | Default | Description |
|-------|-------|----------|---------|-------------|
| General | project_name | Yes | — | Project identifier |
| General | data_file | Yes | — | Input data path |
| General | output_file | No | — | Weighted data output path |
| General | save_diagnostics | No | N | Generate diagnostics workbook |
| General | diagnostics_file | Conditional | — | Diagnostics output path |
| General | html_report | No | N | Generate HTML report |
| General | html_report_file | No | Auto | HTML report path |
| General | brand_colour | No | #1e3a5f | Primary hex colour |
| General | accent_colour | No | #2aa198 | Accent hex colour |
| General | researcher_name | No | — | Report header name |
| General | client_name | No | — | Client name in header |
| General | logo_file | No | — | Logo image path |
| Weight_Specs | weight_name | Yes | — | Unique weight column name |
| Weight_Specs | method | Yes | — | design, rim, rake, or cell |
| Weight_Specs | apply_trimming | No | N | Y to enable trimming |
| Weight_Specs | trim_method | If trimming | — | cap or percentile |
| Weight_Specs | trim_value | If trimming | — | Max weight or percentile |
| Advanced | max_iterations | No | 50 | Max raking iterations |
| Advanced | convergence_tolerance | No | 0.01 | Convergence threshold |
| Advanced | force_convergence | No | N | Accept non-converged |

### Diagnostic Thresholds

| Metric | Good | Acceptable | Poor | Formula |
|--------|------|------------|------|---------|
| DEFF | < 1.5 | 1.5–2.0 | > 2.0 | n / ESS where ESS = (Σw)² / Σ(w²) |
| Efficiency | > 70% | 50–70% | < 50% | 1 / DEFF × 100 |
| CV | < 0.5 | 0.5–1.0 | > 1.0 | SD(weights) / mean(weights) |
| Max Weight | < 3 | 3–5 | > 5 | max(weights) |

### Method Comparison

| Feature | Design | Rim | Cell |
|---------|--------|-----|------|
| Variables | 1 | 2–5 | 2–3 |
| Iteration | No | Yes | No |
| Joint distribution | No | Marginals only | Yes |
| Handles empty cells | N/A | Yes | No |
| Convergence risk | None | Moderate | None |
| Typical use | Stratified samples | Online panels | When joint matters |

---

## Dependencies

| Package | Version | Purpose | Required |
|---------|---------|---------|----------|
| `readxl` | 1.4.5 | Read Excel config files | Yes |
| `survey` | 4.4.8 | Rim weight calibration via `calibrate()` | Yes |
| `openxlsx` | 4.2.8 | Write Excel output (diagnostics, weighted data) | Yes |
| `haven` | 2.5.5 | Read SPSS `.sav` data files | Optional |
| `htmltools` | 0.5.8.1 | Assemble self-contained HTML reports | If html_report=Y |
| `base64enc` | 0.1.3 | Embed logo images as base64 in HTML | If logo used |

**R version:** 4.5.1 or later recommended. Tested on R 4.0+.

---

## Weighting Primer — Why, When, and Watchouts

### Why Weight at All?

In an ideal world, every survey would be a perfectly representative random sample of the target population. In practice, this almost never happens:

- **Online panels** skew young, urban, and tech-savvy
- **Telephone surveys** under-represent mobile-only households
- **Stratified samples** deliberately over-sample small segments for analysis
- **Non-response** is rarely random — certain demographic groups are harder to reach

Weighting corrects these biases by assigning a multiplier to each respondent. A respondent from an under-represented group gets a weight > 1 (they "count more"), while an over-represented respondent gets a weight < 1.

### The Core Trade-Off

Weighting **reduces bias** (your estimates better represent the population) but **increases variance** (your estimates become less precise). This trade-off is captured by the design effect (DEFF):

- **DEFF = 1.0** → No variance cost (all weights equal)
- **DEFF = 1.5** → Moderate cost (effective sample = actual / 1.5)
- **DEFF = 2.0** → High cost (effective sample halved)

There is no universal "right" DEFF. The acceptable level depends on your sample size, the magnitude of the bias, and how the data will be used. As a rule of thumb: a DEFF under 2.0 is standard in market research; above 3.0 warrants serious review.

### Sample Design Considerations

Your weighting approach should follow from your sample design, not the other way around:

| Sample Design | Typical Approach |
|---|---|
| **Simple random sample** | May not need weighting if response is balanced |
| **Stratified random sample** | Design weights to correct for deliberate over/under-sampling |
| **Quota sample** | Rim weights to adjust for quota shortfalls |
| **Online panel** | Rim weights on demographics; watch for DEFF |
| **Convenience / snowball** | Weighting can help but cannot fully fix selection bias |
| **Multi-stage cluster** | Design weights + possible rim adjustment; consider complex survey design |

**Key point:** Weighting cannot manufacture information that was never collected. If entire population segments are absent from your sample, no amount of weighting will fix that. Weighting adjusts proportions — it cannot create data for groups that are completely missing.

### Practical Workarounds

**Combining small categories:** If a category has very few respondents (< 20), consider merging it with a related category before weighting. For example:
- Combine "18–24" and "25–34" into "18–34"
- Combine "Eastern Cape" + "Northern Cape" + "Free State" into "Other provinces"
- Combine "Retired" + "Unemployed" into "Not employed"

Then adjust your target percentages to match the combined categories.

**Handling missing data in weighting variables:** Respondents with NA in a weighting variable are excluded from that weight calculation. Options:
1. **Impute** the missing values before weighting (e.g., assign the modal category)
2. **Exclude** the records with NA from the weighted analysis
3. **Create a separate "Missing" category** in your targets (only if you know the population proportion of non-responders, which you usually don't)

**Dealing with non-convergence (rim weights):** If rim weighting doesn't converge:
1. Reduce the number of rim variables (max 5)
2. Collapse categories with few respondents
3. Increase `max_iterations` to 200
4. Relax `convergence_tolerance` to 0.05
5. Check whether your sample is fundamentally too different from the targets

**Weight stacking (combined methods):** You can run design weights first, then apply rim weighting using the design weights as base weights. This corrects for both stratification and demographic biases. Configure multiple weights in the Weight_Specifications sheet — they are calculated in order.

---

## File Paths and Portability

All paths in the config file are resolved relative to the config file's location:

```
my_project/
  Weight_Config.xlsx      ← config file here
  data/
    survey.csv            ← data_file = "data/survey.csv"
  output/
    weighted.csv          ← output_file = "output/weighted.csv"
```

You can move the entire project folder anywhere (OneDrive, Dropbox, another computer) and it works without changes. Absolute paths are also supported.

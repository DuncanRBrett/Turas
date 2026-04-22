# Category Buying Panel — v3 Spec (count-based, post-BRANDPEN3 clarification)

**Supersedes:** `CAT_BUYING_SPEC_v2.md` (v2 assumed ordinal scale / imputation — obsolete).
**Audience:** next coding session, fresh context.
**Branch:** `feature/brand-report-nav-2layer`.
**Precedent patterns to mirror:** `FUNNEL_SPEC_v2.md`, `panels/03_funnel_panel*.R`, `panels/02_ma_panel*.R`.

---

## 1. Corrected data contract — what we actually have

### 1.1 Per-respondent columns for the focal category (filtered as `cat_data`)

The **longer** and **target** timeframe lengths are both **configurable per project** — they are not hard-coded. See §1.4 for the config fields. For the IPK worked example: longer = **12 months**, target = **3 months**.

| Column | Role | Type | Definition | Population rule |
|---|---|---|---|---|
| `BRANDAWARE_{CAT}_{BRAND}` | `funnel.awareness.aware` | 0/1 | Aware of brand | All screened respondents |
| `BRANDPEN1_{CAT}_{BRAND}` | `funnel.transactional.bought_long` | 0/1 | Bought in the **longer timeframe** (IPK example: last 12m; length is config-driven) | Aware respondents |
| `BRANDPEN2_{CAT}_{BRAND}` | `funnel.transactional.bought_target` | 0/1 | Bought in the **target timeframe** (IPK example: last 3m; length is config-driven) | Subset of BRANDPEN1 buyers |
| `BRANDPEN3_{CAT}_{BRAND}` | `funnel.transactional.frequency` | **Numeric** | **How many times have you bought this brand in the target timeframe.** Actual integer count, or midpoint of a stated range (e.g., "2–5 times" → 3.5). Same window as BRANDPEN2. | Populated for BRANDPEN2 buyers only; `NA` or `0` elsewhere |
| `CATBUY_{CAT}` | `cat_buying.frequency` | Single-select 1–5 | Stated category frequency scale (several/week, once/week, few/month, monthly-or-less, never) | All focal respondents |
| `CATCOUNT_{CAT}` | (secondary, if present) | Numeric | Stated total category-purchase count in a stated window | All focal respondents, if asked |
| `Weight` | system.weight | Numeric | Respondent weight (1.0 in IPK dev sample) | All respondents |

### 1.2 Key implication

Because `BRANDPEN3` is a per-brand purchase count in the **same target timeframe** as `BRANDPEN2`, every Dirichlet-family metric is **directly observable** — no equal-share imputation, no scale-direction games. This is the important correction vs v2.

### 1.3 Configurable timeframes

Two new config fields (read in `modules/brand/R/01_config.R` alongside `wom_timeframe` at line 148):

| Config field | Type | Default | Purpose |
|---|---|---|---|
| `target_timeframe_months` | Integer | `3` | Length in months of the BRANDPEN2 / BRANDPEN3 target window. All rate conversions (monthly / annualised KPIs) divide by this. |
| `longer_timeframe_months` | Integer | `12` | Length in months of the BRANDPEN1 longer window. Used for funnel labelling and panel subtitles; Dirichlet itself is computed on the target window only. |

Validation in `01_config.R`:

- Must be positive integer after `as.integer()`.
- `target_timeframe_months < longer_timeframe_months` — TRS-refuse `CFG_TIMEFRAME_INVALID` if not.
- Surface both values in the guard layer (`00_guard.R`) so a mismatch is caught once, not at every element.

Also add to the three existing category config templates and the `Brand_Config.xlsx` template — two new cells under the "Parameters" block, labelled e.g., *"Target timeframe (months)"* and *"Longer timeframe (months)"*, with the defaults 3 and 12 prefilled.

**Everywhere** the spec refers to "3 months" or "12 months" below, that is the IPK worked-example value, not a hard-coded assumption. Every function signature that needs the window length takes it as an argument sourced from config — never a literal.

### 1.4 Fixture needs regenerating before this work starts

`modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` currently populates `BRANDPEN3` via `wsample(1:5, ...)` — that emits an ordinal 1–5, not a count. The generator must be updated to emit realistic non-negative integer counts (or midpoints) for 3m buyers before any testing against this spec is meaningful. See §9.

---

## 2. Canonical derivations

Let respondents be indexed `i`, brands `j`. All over respondents in `cat_data` (focal category). Let `w_i` be the respondent weight (default 1). Let `T_target` = `config$target_timeframe_months` (IPK example: 3) and `T_long` = `config$longer_timeframe_months` (IPK example: 12). BRANDPEN3 counts are in the `T_target` window. All Dirichlet maths operates on the target window; `T_long` is used only for funnel labelling and panel subtitles.

### 2.1 Per-respondent quantities

| Quantity | Symbol | Formula | Notes |
|---|---|---|---|
| Brand bought flag (target) | `b_{ij}` | `BRANDPEN2_{cat}_{j}[i]` (coerced to {0,1}) | Primary penetration used by Dirichlet |
| Brand purchases (count) | `x_{ij}` | `BRANDPEN3_{cat}_{j}[i]`, coerced: `NA → 0`, negative → 0 | See §5.4 for integrity checks |
| Respondent category volume | `m_i` | `Σ_j x_{ij}` | Source of truth for Dirichlet |
| Category buyer flag | `buyer_i` | `m_i > 0` (equivalently `Σ_j b_{ij} > 0`) | See §5.3 for reconciliation |
| Repertoire size | `r_i` | `Σ_j b_{ij}` | Existing; retained |
| Respondent SCR for brand j | `scr_{ij}` | `x_{ij} / m_i` if `m_i > 0` else `NA` | Direct, no imputation |

### 2.2 Category-level quantities (over buyers, weighted)

| Quantity | Symbol | Formula |
|---|---|---|
| Category penetration | `b` | `Σ_i w_i · buyer_i / Σ_i w_i` |
| Category mean purchases per buyer | `M` | `Σ_i w_i · m_i · buyer_i / Σ_i w_i · buyer_i` |
| Category purchase rate per month (per buyer) | `M / T_target` | monthly equivalent, for KPI chips |
| Category purchase rate annualised (per buyer) | `M × 12 / T_target` | annualised equivalent, for Dirichlet robustness checks |

### 2.3 Brand-level quantities

| Quantity | Symbol | Formula |
|---|---|---|
| Brand penetration | `b_j` | `Σ_i w_i · b_{ij} / Σ_i w_i` |
| Brand buy rate (among buyers) | `w_j` | `Σ_i w_i · x_{ij} · b_{ij} / Σ_i w_i · b_{ij}` |
| Brand volume | `V_j` | `Σ_i w_i · x_{ij}` |
| Brand market share | `s_j` | `V_j / Σ_k V_k` |
| Brand SCR (buyers' mean share) | `SCR_j` | `Σ_i w_i · scr_{ij} · b_{ij} / Σ_i w_i · b_{ij}` |
| 100%-loyal flag | `loyal_{ij}` | `b_{ij} = 1 ∧ r_i = 1` (equivalently `x_{ij} = m_i > 0`) |
| 100%-loyal % of brand buyers | `L_j` | `Σ_i w_i · loyal_{ij} / Σ_i w_i · b_{ij}` |

### 2.4 Buyer heaviness (category-level tertiles)

Over buyers only: rank by `m_i` (weighted). Split into three weight-equal groups (tertiles). Brand j's heavy/medium/light buyer composition = distribution of j's buyers across the three tertiles. Natural Monopoly Index = `(light_share_brand_j / light_share_category) × 100`.

Tertiles computed directly from `m_i`. When `m_i` has heavy ties (common with midpoint-of-range responses), break ties by pushing weight to the next tertile to keep buckets within ±5 percentage points of one-third. Document this in the function.

### 2.5 Duplication-of-Purchase expected values

Observed duplication (existing): `obs_D_{ij}` = % of brand i buyers who also buy brand j.

Expected under DoP law: `exp_D_{ij} = D × b_j` where D is fit by OLS of off-diagonal `obs_D_{ij}` on `b_j`, no intercept, one D per category. Deviation: `dev_{ij} = obs_D_{ij} − exp_D_{ij}` (percentage points).

---

## 3. Dirichlet benchmark inputs

The `NBDdirichlet` package (CRAN) takes:
- `cat.pen` = `b` (§2.2)
- `cat.buyrate` = `M / b` (purchases per category buyer — already what we compute)
- `brand.share` = vector of `s_j` (§2.3)
- `brand.pen.obs` (optional, for comparison) = vector of `b_j`
- `brand.buyrate.obs` (optional) = vector of `w_j`

Outputs we read: expected `b_j`, `w_j`, `SCR_j`, `% 100%-loyal`. Compute deviations as `(obs − exp) / exp × 100`. Flag `|dev| > 20%` as `over` / `under`.

Must add `NBDdirichlet` to `renv.lock` via `renv::install("NBDdirichlet")` → `renv::snapshot()`.

**TRS-refuse**, do not silently substitute, if the package is unavailable (`PKG_DIRICHLET_MISSING`).

---

## 4. The six panel outputs — now all directly observable

| # | Output | Formula source | Input columns |
|---|---|---|---|
| 1 | Double Jeopardy scatter (penetration × SCR, Dirichlet-fitted curve) | `b_j`, `SCR_j`, expected curve from §3 | BRANDPEN2 + BRANDPEN3 |
| 2 | Dirichlet norms table (observed vs expected per brand) | §2.3 observed, §3 expected | BRANDPEN2 + BRANDPEN3 |
| 3 | SCR as headline loyalty KPI + 100%-loyal % | `SCR_j`, `L_j` | BRANDPEN2 + BRANDPEN3 |
| 4 | DoP deviation heatmap | §2.5 | BRANDPEN2 only |
| 5 | Buyer-base heaviness stacked bars + NMI | §2.4 | BRANDPEN2 + BRANDPEN3 (m_i) |
| 6 | Brand buy rate profile (`w_j` vs `M/b`) | §2.3 | BRANDPEN2 + BRANDPEN3 |

Every output sits on real counts. No imputation anywhere.

---

## 5. Data quality rules (TRS refusals + PARTIAL flags)

### 5.1 Column availability
For a given category, require: `BRANDPEN2_{cat}_{brand}` for every brand **and** `BRANDPEN3_{cat}_{brand}` for every brand. If any brand is missing BRANDPEN3 → TRS refusal `DATA_BRANDPEN3_MISSING` listing the offending brands. Do not fall back to ordinal interpretation.

### 5.2 Type coercion
`BRANDPEN3` may arrive as integer, numeric (midpoint), or character (midpoint written as text from some exports). Coercion path: `as.numeric(trimws(as.character(x)))`. Failures become `NA`. Count of failed coercions recorded in `context`.

### 5.3 Buyer / count reconciliation
Four cases per respondent × brand:
- `BRANDPEN2 = 1 ∧ BRANDPEN3 > 0` → valid buyer with count. Use as-is.
- `BRANDPEN2 = 1 ∧ (BRANDPEN3 = 0 ∨ NA)` → inconsistency. Policy: treat as buyer with `x_{ij} = 1` (minimum possible count). Log per-category count of inconsistencies; if > 10% of buyers affected → return `PARTIAL` with warning.
- `BRANDPEN2 = 0 ∧ BRANDPEN3 > 0` → inconsistency. Policy: treat as buyer (trust the positive count). Log count. If > 5% affected → `PARTIAL`.
- `BRANDPEN2 = 0 ∧ (BRANDPEN3 = 0 ∨ NA)` → non-buyer of this brand. Use as-is.

Reconciled buyer flag `b_{ij}` = `(BRANDPEN2 = 1) ∨ (BRANDPEN3 > 0)`.

### 5.4 Outlier handling
Respondents with `m_i > 99th percentile × 3` (per category, over buyers) are winsorised: cap `m_i` at the 99th percentile × 3. Scale `x_{ij}` proportionally so `Σ_j x_{ij} = capped m_i` and per-respondent SCR is preserved. Log count of winsorised respondents. Never drop respondents silently.

### 5.5 Category reconciliation with CATBUY
Compute `M_brand = mean(m_i | buyer_i)` from BRANDPEN3 and `M_stated = mean of cat_buy_scale monthly equivalent × T_target | buyer_i` from CATBUY. Both are expressed over the same `T_target` window, making them comparable. Report both in the norms table footer (example text with IPK values, `T_target = 3`):

> "Category mean purchases per buyer over the last 3 months — BRANDPEN3: 4.2; CATBUY stated scale: 3.8. Dirichlet uses BRANDPEN3 (direct measurement)."

Footer text is templated on `T_target` so it reads correctly for any project. This is a data-quality transparency feature, not a failure mode.

### 5.6 Share sanity
`Σ_j s_j` must equal 1 exactly by construction. If numerical drift > 1e-6 → bug, TRS-refuse `CALC_SHARE_NORMALISATION`.

### 5.7 Minimum brand count
Dirichlet is undefined with fewer than 2 brands; returns unstable estimates with fewer than 4. Refuse below 2 brands (`DATA_SINGLE_BRAND`); emit `PARTIAL` with warning below 4.

---

## 6. Files to create / modify

### 6.1 New R files

| Path | Purpose | Key exports |
|---|---|---|
| `modules/brand/R/08b_brand_volume.R` | Per-respondent `m_i`, `x_{ij}`, reconciliation (§5.3), winsorisation (§5.4) | `build_brand_volume_matrix()` |
| `modules/brand/R/08c_dirichlet_norms.R` | Observed metrics (§2.3), Dirichlet call (§3), deviation table | `run_dirichlet_norms()` |
| `modules/brand/R/08d_buyer_heaviness.R` | Tertile split, per-brand heaviness, NMI | `run_buyer_heaviness()` |

### 6.2 Modified R files

| Path | Change |
|---|---|
| `modules/brand/R/00_main.R` | (a) Register new sources in the load block (~line 71). (b) After `run_cat_buying_frequency()` (~line 451), build the volume matrix then call the three new elements in sequence. (c) Pass volume matrix into `run_repertoire()` as `frequency_matrix`. (d) Store outputs on `cat_result$brand_volume`, `cat_result$dirichlet_norms`, `cat_result$buyer_heaviness`. |
| `modules/brand/R/04_repertoire.R` | Fix the scale-direction bug in the existing `share_of_requirements` block (lines 237–271) — with BRANDPEN3 as counts, the existing formula is correct; delete the defensive `if (is.null(frequency_matrix))` no-op path and ensure SCR is always computed when counts are provided. Add `dop_expected_matrix`, `dop_deviation_matrix`, `dop_D_coefficient` as §2.5. |
| `modules/brand/R/99_output.R` | New Excel sheets + CSV files per full-depth category: `dirichlet_{CAT}`, `market_share_{CAT}`, `buyer_heaviness_{CAT}`, `dop_deviation_{CAT}`. TRS-refuse with visible console box on missing inputs — do not silently skip. |

### 6.3 New HTML panel files (follow `panels/03_funnel_panel*.R` pattern)

| Path | Purpose |
|---|---|
| `modules/brand/lib/html_report/panels/08_cat_buying_panel.R` | Panel assembler |
| `modules/brand/lib/html_report/panels/08_cat_buying_panel_chart.R` | SVG charts (DJ scatter, heaviness stack, w-bar bars, DoP heatmap) |
| `modules/brand/lib/html_report/panels/08_cat_buying_panel_table.R` | Norms table, DoP deviation, market share |
| `modules/brand/lib/html_report/panels/08_cat_buying_panel_styling.R` | Panel CSS |

### 6.4 Modified HTML files

| Path | Change |
|---|---|
| `01_data_transformer.R` | Extend the Category Buying branch (~lines 77–203) to package `cat_result$dirichlet_norms`, `cat_result$buyer_heaviness`, and the DoP deviation outputs for the panel. |
| `02_table_builder.R` | Extend `build_cat_buying_tables()` to accept and render the three new tables. Keep legacy tables as the collapsed "Descriptive detail" section. |
| `03_page_builder.R` | Replace the inline block (lines ~352 onwards) with a call to `render_cat_buying_panel()`. Tab definition on line 276 unchanged. |

---

## 7. Function signatures

### 7.1 `build_brand_volume_matrix()`

```r
build_brand_volume_matrix(
  cat_data,          # data frame filtered to focal category
  cat_brands,        # data frame with BrandCode column (order defines matrix cols)
  pen_target_prefix, # "BRANDPEN2" (resolved from structure)
  freq_prefix,       # "BRANDPEN3"
  winsor_mult = 3,
  verbose     = FALSE
)
```

Returns:

```r
list(
  status              = "PASS" | "PARTIAL" | "REFUSED",
  code                = ...,                 # only on REFUSED
  message             = ...,                 # only on REFUSED
  pen_mat             = matrix,              # n_resp × n_brands, 0/1, reconciled
  x_mat               = matrix,              # n_resp × n_brands, numeric counts
  m_vec               = numeric(n_resp),     # Σ_j x_{ij} post-winsor
  reconciliation      = list(
    pen_yes_count_no  = integer(1),
    pen_no_count_yes  = integer(1),
    winsorised_n      = integer(1),
    coercion_failures = integer(1)
  ),
  warnings            = character()          # populated for PARTIAL
)
```

Refusal codes: `DATA_NO_CAT_DATA`, `DATA_BRANDPEN2_MISSING`, `DATA_BRANDPEN3_MISSING`, `DATA_ALL_NA`, `DATA_WEIGHTS_MISMATCH`.

### 7.2 `run_dirichlet_norms()`

```r
run_dirichlet_norms(
  pen_mat,              # from 7.1
  x_mat,                # from 7.1
  m_vec,                # from 7.1
  brand_codes,
  focal_brand      = NULL,
  weights          = NULL,
  target_months,        # REQUIRED. From config$target_timeframe_months. No default. Used for
                        # chart labels, KPI chip formatting, and footer text. Maths are
                        # period-agnostic; this parameter never multiplies a rate internally.
  longer_months    = NULL  # Optional. From config$longer_timeframe_months. Only used in the
                           # panel subtitle ("Target: last N months; Longer: last M months").
)
```

Returns:

```r
list(
  status           = ...,
  target_months    = integer(1),   # echoed back from input, for downstream labels
  longer_months    = integer(1),   # echoed back; NA if not provided
  category_metrics = list(
    penetration            = numeric(1),    # b
    mean_purchases         = numeric(1),    # M
    n_buyers               = integer(1),
    n_respondents          = integer(1)
  ),
  market_shares    = data.frame(BrandCode, Volume, Share_Pct),
  observed = data.frame(
    BrandCode, Penetration_Pct, BuyRate, SCR_Pct,
    Pct100Loyal, Brand_Buyers_n
  ),
  expected = data.frame(
    BrandCode, Penetration_Pct_Exp, BuyRate_Exp,
    SCR_Pct_Exp, Pct100Loyal_Exp
  ),
  norms_table = data.frame(    # joined obs + exp + dev, for the panel table
    BrandCode,
    Penetration_Obs_Pct, Penetration_Exp_Pct, Penetration_Dev_Pct,
    BuyRate_Obs,         BuyRate_Exp,         BuyRate_Dev_Pct,
    SCR_Obs_Pct,         SCR_Exp_Pct,         SCR_Dev_Pct,
    Pct100Loyal_Obs,     Pct100Loyal_Exp,     Pct100Loyal_Dev_Pct,
    DJ_Flag              # "over" | "under" | "on_line"  based on |SCR dev| >= 20
  ),
  dj_curve = list(       # for the scatter overlay
    x_grid = numeric(),
    y_fit_scr = numeric(),
    y_fit_w   = numeric(),
    method    = "NBDdirichlet"
  ),
  metrics_summary = list(
    focal_brand       = character(1),
    focal_scr_obs     = numeric(1),
    focal_scr_exp     = numeric(1),
    focal_pen_obs     = numeric(1),
    focal_pen_exp     = numeric(1),
    focal_loyal_obs   = numeric(1),
    focal_loyal_exp   = numeric(1),
    n_brands          = integer(1)
  )
)
```

Refusal codes: `DATA_NO_VOLUME`, `DATA_SINGLE_BRAND`, `CALC_DIRICHLET_FAILED` (include underlying error in `context`), `PKG_DIRICHLET_MISSING`, `CALC_SHARE_NORMALISATION`.

### 7.3 `run_buyer_heaviness()`

```r
run_buyer_heaviness(
  pen_mat,             # from 7.1
  m_vec,               # from 7.1
  brand_codes,
  focal_brand = NULL,
  weights     = NULL
)
```

Returns:

```r
list(
  status             = ...,
  tertile_bounds     = list(light = c(0, q33), medium = c(q33, q67), heavy = c(q67, Inf)),
  category_buyer_mix = data.frame(Tier, Pct, n),
  brand_heaviness    = data.frame(
    BrandCode, Heavy_Pct, Medium_Pct, Light_Pct,
    WBar_Brand, WBar_Category, WBar_Gap,
    NaturalMonopolyIndex,   # (brand_light_share / category_light_share) * 100
    Brand_Buyers_n
  ),
  metrics_summary    = list(
    focal_brand   = character(1),
    focal_nmi     = numeric(1),
    focal_wbar    = numeric(1),
    focal_wbar_gap= numeric(1)
  )
)
```

Refusal codes: `DATA_NO_BUYERS`, `DATA_ALL_SAME_M` (all buyers have identical `m_i` → tertiles undefined, emit `PARTIAL` with single-tier output instead).

### 7.4 Extension to `run_repertoire()`

Keep existing signature. Add:

- When `frequency_matrix` is non-NULL (now always true for full categories), ensure `share_of_requirements` computes correctly — with `x_{ij}` as counts, the existing formula is mathematically right. Verify with a manual test.
- Compute `dop_D_coefficient`: fit `obs_D_{ij} ~ 0 + b_j` via OLS over off-diagonal cells. Return as `numeric(1)`.
- Compute `dop_expected_matrix` = `D × b_j` broadcast across rows.
- Compute `dop_deviation_matrix` = `obs − exp` in percentage points.
- Preserve `crossover_matrix` unchanged.

---

## 8. HTML panel layout

Order top → bottom:

1. **KPI strip** (single row of chips)
   - "% Category buyers" (existing)
   - "Mean purchases per buyer (target timeframe)" — new, uses `M`
   - "Focal SCR" — `SCR_focal` with Dirichlet expected in brackets, e.g., `34% (exp 38%)`
   - "Focal 100%-loyal" — `L_focal` with expected in brackets
   - "Focal NMI" — sparkline-style arrow vs 1.0

2. **Double Jeopardy scatter** (hero chart, full-width ~480px tall)
   - Default y = SCR. Toggle to y = w.
   - Points: all brands; focal highlighted.
   - Overlay: Dirichlet-expected curve from `dj_curve`.
   - Tooltip: brand, pen, SCR obs, SCR exp, dev%.
   - Brand labels for points with `|dev| ≥ 20`.

3. **Dirichlet norms table**
   - Grouped headers: Penetration | Buy rate | SCR | 100% Loyals.
   - Each group: Obs / Exp / Δ%. Δ cells shaded green (+) / red (−) when `|Δ| ≥ 20`.
   - Focal row bolded.
   - Footer cites Goodhardt, Ehrenberg & Chatfield 1984 and notes `M` reconciliation (§5.5).

4. **Two-column row**
   - Left: Buyer heaviness stacked bars, one per brand, sorted focal-first then by share. Dotted reference lines at category-mix positions.
   - Right: Buy-rate profile — horizontal bar per brand with reference line at `M/b`.

5. **DoP deviation heatmap**
   - Diverging colour: green (positive), white (on law), red (negative).
   - Raw observed % shown as subscript.
   - Toggle: "Show raw duplication" reverts to existing observed matrix.
   - Callout below flags partition candidates (≥ 3 brands with shared positive deviations > 10pp).

6. **Collapsible "Descriptive detail"** (existing frequency bars, repertoire size, brand repertoire profile — demoted, not removed).

### 8.1 Toggles

- Period toggle (none — target timeframe is fixed per project via config; the panel subtitle reads the values dynamically, e.g., for IPK: *"Target timeframe: last 3 months · Longer timeframe: last 12 months"*. Subtitle string templated on `target_months` + `longer_months`).
- DJ y-axis toggle (SCR | w) — default SCR.
- DoP heatmap toggle (Deviation | Observed) — default Deviation.
- Base toggle (% total / % aware) is **hidden** on this panel (all metrics are among buyers or among aware-and-buyer).

### 8.2 Accessibility

Every chart gets a plain-language summary paragraph above it, screen-reader friendly and usable by the AI annotation layer. Follow `03c_funnel_panel_data.R` pattern.

---

## 9. Fixture regeneration

**Prerequisite for testing.** Update `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` so `BRANDPEN3` emits realistic purchase counts for BRANDPEN2 buyers, not the current `wsample(1:5, ...)` ordinal.

Parameterise the generator (constants at file head, not magic numbers in function bodies):

```r
# IPK worked-example windows — these must match the config defaults in §1.3
TARGET_TIMEFRAME_MONTHS <- 3    # BRANDPEN2 + BRANDPEN3 window
LONGER_TIMEFRAME_MONTHS <- 12   # BRANDPEN1 window

# BRANDPEN3 = count of purchases in the last TARGET_TIMEFRAME_MONTHS months.
# Rate chosen so a realistic category mean M ≈ 4-5 purchases per buyer over 3 months
# (CPG ambient grocery). Scale proportionally if the window is changed.
# For focal brand (IPK): negbin with mean ~ 6, theta ~ 2
# For other brands:      negbin with mean ~ 3, theta ~ 1.5
# Clamp to integer, floor 1 (a BRANDPEN2 buyer bought at least once in the window).
```

This must:

- Produce a realistic Double Jeopardy gradient (leaders with higher penetration AND modestly higher buy rate).
- Produce positive duplication coefficient D (buyers overlap per the law).
- Keep counts within plausible bounds for the chosen window (`< 10 × TARGET_TIMEFRAME_MONTHS` as a soft cap).
- Be seed-stable.
- If the window constants change, all downstream rate distributions rescale proportionally — no hand-tuned numbers tied to 3 months.

Re-emit all `ipk_9cat_wave1.xlsx` 1,200-row blocks with the new BRANDPEN3 values. Existing screener / awareness / attitude / CEP / attribute data preserved.

---

## 10. Tests

Directory: `modules/brand/tests/testthat/`. Target: ~70 new tests, zero regressions against current 812.

### 10.1 `test_brand_volume.R` (~20 tests)
- Happy path: pen_mat + x_mat shapes match expected.
- Reconciliation: each of the four cases in §5.3 produces expected behaviour; counts logged correctly.
- Winsorisation at 99th percentile × 3; per-respondent SCR preserved post-winsor.
- NA / character coercion.
- Missing BRANDPEN3 columns → `DATA_BRANDPEN3_MISSING`.
- Weighted vs unweighted parity when weights ≡ 1.

### 10.2 `test_dirichlet_norms.R` (~25 tests)
- Textbook reproduction: seed a synthetic 5-brand category with known b, M, s, and confirm Dirichlet expected values match `NBDdirichlet::dirichlet()` called directly. (Coder verifies the numbers against the package vignette.)
- Deviation flags: construct known-under and known-over brands, confirm `DJ_Flag` classification.
- Observed SCR exactly matches manual calculation on a 3-respondent × 3-brand fixture.
- Share normalisation: `Σ_j s_j == 1` asserted.
- TRS refusals: each code in §7.2.
- Weighted path.
- `PKG_DIRICHLET_MISSING` simulated (mock `requireNamespace` → FALSE).

### 10.3 `test_buyer_heaviness.R` (~15 tests)
- Tertile counts sum to n_buyers (± tie-break tolerance).
- NMI = 1.0 for a brand with buyer mix identical to category mix.
- Empty brand (no buyers) → row present with NA, not dropped.
- `DATA_ALL_SAME_M` → `PARTIAL` with single-tier output.
- Weighted path; tertile boundaries under weights.

### 10.4 `test_dop_expected.R` (~10 tests)
- D coefficient fitted correctly on a constructed pair-wise matrix.
- Deviation matrix sign matches handcrafted deviations.
- Partition detection: 3 brands with shared +15pp deviation flagged.

### 10.5 `test_cat_buying_panel.R` (~10 tests)
- Panel HTML contract: required `data-*` attributes and section ids.
- DJ y-axis toggle switches both chart + axis label in DOM.
- DoP heatmap toggle switches table.
- Graceful degradation: when any of the three element outputs is `REFUSED`, panel shows a refusal block and still renders the remaining sections.

### 10.6 Regression
Re-run the full brand suite. Baseline 812 + 70 new = 882 target. Zero failures.

---

## 11. Excel / CSV outputs

Per full-depth category, emit:

| Sheet / CSV | Source | Columns |
|---|---|---|
| `dirichlet_{CAT}` | `norms_table` | BrandCode + all obs/exp/dev columns + DJ_Flag |
| `market_share_{CAT}` | `market_shares` | BrandCode, Volume, Share_Pct |
| `buyer_heaviness_{CAT}` | `brand_heaviness` | BrandCode, Heavy/Med/Light %, WBar, NMI, n |
| `dop_deviation_{CAT}` | `dop_deviation_matrix` | BrandCode column + one numeric col per partner brand |

If any upstream element is `REFUSED`, write a short refusal sheet (`dirichlet_{CAT}_REFUSED`) carrying code + message + how_to_fix — do not skip silently.

---

## 12. Conventions reminders

- TRS everywhere. No `stop()`. Every refusal echoed to console via the `handle_error()` box pattern in `CLAUDE.md`.
- `cat_data` vs `data`: this work is strictly per-category → use `cat_data`. Do not touch Portfolio.
- Weights threaded through every function; `sum(weights, na.rm=TRUE) <= 0` → `weights <- NULL` (match `08_cat_buying.R:84`).
- Roxygen2 on every exported function; `@references` citing Ehrenberg, Sharp, Romaniuk as appropriate.
- Each new file declares `<MODULE>_VERSION <- "1.0"` and emits the startup message (suppressed under `TESTTHAT=true`).
- Follow the layout of `08_cat_buying.R` for file shape.

---

## 13. Acceptance checklist

- [ ] `target_timeframe_months` and `longer_timeframe_months` added to `01_config.R` defaults (3 and 12), validated in guard layer, and exposed in the `Brand_Config.xlsx` template
- [ ] Every function signature that needs the window length receives it via arguments sourced from config — no hard-coded months anywhere
- [ ] Fixture regenerated with count-based BRANDPEN3, using the parameterised `TARGET_TIMEFRAME_MONTHS` / `LONGER_TIMEFRAME_MONTHS` constants (§9)
- [ ] `NBDdirichlet` added to `renv.lock`
- [ ] `build_brand_volume_matrix()` returns reconciled pen_mat + x_mat + m_vec, with reconciliation counts
- [ ] `cat_result$brand_volume`, `cat_result$dirichlet_norms`, `cat_result$buyer_heaviness` populated for every full-depth category
- [ ] `run_repertoire()` now computes `share_of_requirements` correctly + returns `dop_expected_matrix`, `dop_deviation_matrix`, `dop_D_coefficient`
- [ ] Panel rebuilt to match §8 (Duncan reviews layout before CSS polish)
- [ ] Norms table deviations match a hand-computed textbook case
- [ ] DJ scatter has Dirichlet-expected overlay, focal highlighted, toggles working
- [ ] DoP deviation heatmap + partition callout working
- [ ] Buyer heaviness stacks + w-bar profile rendering
- [ ] Excel + CSV outputs present for all four new artefacts per full category
- [ ] Console-visible TRS refusals on every failure path
- [ ] Test count ≥ 882, zero regressions
- [ ] `project_brand_module.md` memory updated

---

## 14. Out of scope

- No wave-on-wave growth quadrant (needs tracker integration).
- No Pareto volume curve (defer; nice-to-have only).
- No MA × DJ cross-view (defer).
- No changes to Funnel, MA, WOM, Portfolio panels.
- No re-implementation of Dirichlet maths — always use `NBDdirichlet`.
- No removal of existing descriptive charts — they move to a collapsible section.

---

## 15. Honest limitations to document in the panel footer

- "Dirichlet expected values assume category is stationary over the target timeframe. Growing / declining categories produce systematic deviations."
- "BRANDPEN3 is stated recall, subject to telescoping (over-reporting) and omission (under-reporting). Winsorisation at 99th percentile × 3 mitigates extreme outliers but does not correct systematic bias."
- "When respondents give a range, the midpoint is used — this introduces modest loss of variance."
- "For categories with < 4 brands, Dirichlet estimates are flagged as PARTIAL."
- "The target timeframe (window for BRANDPEN2 + BRANDPEN3) and longer timeframe (window for BRANDPEN1) are project-configurable. Figures in this panel are expressed over the windows declared in the project config — IPK example: 3 months and 12 months."

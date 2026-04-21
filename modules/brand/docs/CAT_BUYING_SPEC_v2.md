# Category Buying Panel — v2 Spec (Dirichlet-grounded)

> **SUPERSEDED on 2026-04-21 by `CAT_BUYING_SPEC_v3.md`.**
> v2 was written assuming BRANDPEN3 was an ordinal share-of-choice scale and specified equal-share SCR imputation. That is wrong for the real IPK questionnaire, where BRANDPEN3 is a **purchase count (or midpoint-of-range)** per brand over the target timeframe. v3 uses direct observed metrics throughout. **Do not work from this file.**

**Audience:** next coding session (fresh context).
**Branch to work on:** `feature/brand-report-nav-2layer` (current working branch).
**Precedent files to mirror:** `FUNNEL_SPEC_v2.md` (spec style), `panels/03_funnel_panel*.R` (panel split pattern), `panels/02_ma_panel*.R`.
**Do not code ahead of alignment with Duncan on Section 9 (panel layout).** Everything else can proceed straight from the spec.

---

## 1. Why we are doing this

The Category Buying panel (currently renders `run_cat_buying_frequency()` + the repertoire outputs) is descriptive only — distribution bars, sole/dual/multi, crossover matrix. It does not benchmark, diagnose, or tell a brand-growth story. The rebuild turns it into a **diagnostic panel anchored in Ehrenberg-Bass / NBD-Dirichlet theory**, so TRL can point at any chart and cite a reference.

**Literature anchor (cite in panel footnote):**
- Ehrenberg, Uncles & Goodhardt (2004), *Understanding brand performance measures: using Dirichlet benchmarks*, Journal of Business Research.
- Sharp, B. (2010). *How Brands Grow*. Oxford.
- Romaniuk, J. & Sharp, B. (2016). *How Brands Grow, Part 2*. Oxford.
- Goodhardt, Ehrenberg & Chatfield (1984). *The Dirichlet: a comprehensive model of buying behaviour*. JRSS A.

## 2. Scope (six additions)

| # | Addition | Status | Theory anchor |
|---|----------|--------|--------------|
| 1 | **Double Jeopardy scatter** (penetration × buy rate, fitted DJ curve) | NEW | Ehrenberg 1969, Sharp 2010 Ch.2 |
| 2 | **Dirichlet norms table** (observed vs expected penetration, w, SCR, 100% loyals) | NEW | Goodhardt et al. 1984 |
| 3 | **Share of Category Requirements (SCR)** — elevate to KPI, fix for non-TRANS | EXTEND | Ehrenberg 1988 |
| 4 | **Duplication-of-Purchase deviation heatmap** (observed vs expected, partitions flagged) | EXTEND | Romaniuk & Sharp 2016 Ch.7 |
| 5 | **Buyer-base heaviness composition** (heavy/med/light category buyer decomp per brand) | NEW | Sharp 2010 Ch.6 (Natural Monopoly) |
| 6 | **Buy-rate profile** — brand buyers' category buy-rate vs category mean (w-bar view) | NEW | Kennedy & Ehrenberg 2001 |

**Out of scope this session:** wave-on-wave growth quadrant (needs tracker integration — park), Pareto volume curve (nice-to-have, defer), MA×DJ cross-view (defer). Do not spec or scaffold these.

## 3. Files to create / modify

### New files
| Path | Purpose |
|------|---------|
| `modules/brand/R/08b_dirichlet_norms.R` | Dirichlet benchmark engine + DJ fitted curve |
| `modules/brand/R/08c_buyer_heaviness.R` | Heavy/med/light category-buyer tertile split; per-brand composition + w-bar |
| `modules/brand/lib/html_report/panels/08_cat_buying_panel.R` | Panel HTML assembler (follow `03_funnel_panel.R` structure) |
| `modules/brand/lib/html_report/panels/08_cat_buying_panel_chart.R` | SVG chart builders (DJ scatter, heaviness stack, w-bar bar) |
| `modules/brand/lib/html_report/panels/08_cat_buying_panel_table.R` | HTML tables (Dirichlet norms, DoP deviation) |
| `modules/brand/lib/html_report/panels/08_cat_buying_panel_styling.R` | Panel-scoped CSS |
| `modules/brand/tests/testthat/test_dirichlet_norms.R` | Unit tests for `08b_` |
| `modules/brand/tests/testthat/test_buyer_heaviness.R` | Unit tests for `08c_` |
| `modules/brand/tests/testthat/test_cat_buying_panel.R` | HTML panel contract tests |

### Modified files
| Path | Change |
|------|--------|
| `modules/brand/R/00_main.R` | After line ~439 (`cat_result$cat_buying_frequency <- …`), add calls that populate `cat_result$dirichlet_norms`, `cat_result$buyer_heaviness`. Load order: register `08b_dirichlet_norms.R` and `08c_buyer_heaviness.R` in the source list near line 71. |
| `modules/brand/R/04_repertoire.R` | Add `dop_expected_matrix` and `dop_deviation_matrix` alongside existing `crossover_matrix` (§6.4). Preserve existing outputs. |
| `modules/brand/lib/html_report/01_data_transformer.R` | Extend the cat-buying branch (around line 77–203) to pipe the new outputs into the panel's chart/table payload. |
| `modules/brand/lib/html_report/02_table_builder.R` | `build_cat_buying_tables()` gains `dirichlet_norms` and `dop_deviation` arguments. Keep existing tables as lower sections. |
| `modules/brand/lib/html_report/03_page_builder.R` | Replace the inline Category Buying block (lines ~352–onwards) with a single call to `render_cat_buying_panel()` (the new panel file). Keep the tab definition on line 276 unchanged. |
| `modules/brand/R/99_output.R` | Excel: add sheets `dirichlet_norms_{CAT}` and `buyer_heaviness_{CAT}`. CSV: emit parallel files. TRS-refuse on missing inputs (do not silently skip — WOM output bug lesson). |

## 4. Dependency

Use `NBDdirichlet` (CRAN, stable, maintained by Feng & Rossi). Add via `renv::install("NBDdirichlet")` then `renv::snapshot()`. It implements the closed-form Dirichlet expectations and is the standard reference implementation cited in Kantar/Nielsen work. **Do not re-implement the Dirichlet math** — we want defensibility, not novelty in the maths layer.

Fallback: if `NBDdirichlet` is unavailable at runtime, the engine must TRS-refuse with `PKG_DIRICHLET_MISSING` and clear `how_to_fix` instructing `renv::install("NBDdirichlet")`. Never silently substitute an ad-hoc implementation.

## 5. Data inputs available (do not recompute)

From the orchestrator, per category (`cat_data`):

- `pen_mat` — n_resp × n_brands binary penetration (already built for `run_repertoire`)
- `cat_buying_frequency` output (from §6.1 of existing code) — includes `distribution`, `mean_freq`, `pct_buyers`, and the per-respondent scale codes available on the raw column
- Raw `cat_buy_scale` codes (accessible via `data[[freq_col]]` inside the orchestrator)
- `weights` — respondent weights (1.0 in dev sample, must still thread through)
- `focal_brand` — the focal brand code for the category
- Brand codes + labels

## 6. Data contracts — new outputs

All functions return TRS-compliant lists. `status` ∈ {`PASS`, `PARTIAL`, `REFUSED`}. Follow the `run_cat_buying_frequency()` conventions in `08_cat_buying.R:52-197` for error codes and refusal shape.

### 6.1 `run_dirichlet_norms()` — new, in `08b_dirichlet_norms.R`

**Signature**
```r
run_dirichlet_norms(
  pen_mat,               # n_resp × n_brands binary matrix
  brand_codes,           # character vector, same order as columns
  cat_buy_scale_codes,   # raw scale codes per respondent (length n_resp)
  option_map,            # OptionMap slice for cat_buy_scale
  focal_brand = NULL,
  weights     = NULL,
  period      = "annual" # "monthly" | "quarterly" | "annual"; default annual
)
```

**Method**
1. **Category mean purchases per buyer (M)**: map scale codes → monthly rates via `.CAT_BUY_SCALE_WEIGHTS` (same constant as `08_cat_buying.R:18-24`); weighted mean over buyers only; scale to period.
2. **Category penetration (b)**: share of respondents where `rowSums(pen_mat) > 0`, weighted.
3. **Market shares (s_j)**: for each brand, `share_j = Σ_respondents (pen_j × cat_freq_monthly) / Σ_respondents (Σ_brands pen × cat_freq_monthly)`. Weighted. This is the *volume-weighted* share, which is what the Dirichlet expects. Do **not** use raw penetration as share — document this clearly in the function roxygen.
4. Call `NBDdirichlet::dirichlet(cat.pen = b, cat.buyrate = M/b, brand.share = s, brand.pen.obs = observed_pen, brand.buyrate.obs = observed_w)` (consult CRAN vignette for exact argument names at implementation time).
5. Extract expected values: `bj_exp`, `wj_exp`, `SCR_exp`, `pct_100_loyal_exp`.
6. Compute deviations: `dev_pct = (observed − expected) / expected × 100`. Flag `|dev| > 20%` as `over`/`under`.

**Output**
```r
list(
  status = "PASS",
  period = "annual",
  category_metrics = list(
    penetration = b,          # 0–1
    mean_purchases_per_buyer = M,
    n_buyers = ..., n_respondents = ...
  ),
  market_shares = data.frame(  # volume-weighted
    BrandCode, Share_Pct
  ),
  norms_table = data.frame(
    BrandCode,
    Penetration_Obs_Pct, Penetration_Exp_Pct, Penetration_Dev_Pct,
    BuyRate_Obs,         BuyRate_Exp,         BuyRate_Dev_Pct,
    SCR_Obs_Pct,         SCR_Exp_Pct,         SCR_Dev_Pct,
    Pct100Loyal_Obs,     Pct100Loyal_Exp,     Pct100Loyal_Dev_Pct,
    DJ_Flag  # "over" | "under" | "on_line"  based on SCR deviation
  ),
  dj_curve = list(            # for the scatter overlay (§7.2)
    x_grid = numeric(),       # penetration grid 0.01..max(b)
    y_fit  = numeric(),       # predicted SCR or w on DJ line
    method = "dirichlet"      # identifier for chart label
  ),
  metrics_summary = list(     # for AI annotations
    focal_brand = ...,
    focal_scr_obs = ..., focal_scr_exp = ...,
    focal_pen_obs = ..., focal_pen_exp = ...,
    n_brands = ...
  )
)
```

**TRS refusals (minimum set)**
- `DATA_NO_PENETRATION` — `pen_mat` null/empty (copy pattern from `04_repertoire.R:47`)
- `DATA_NO_BUYERS` — zero category buyers
- `DATA_SINGLE_BRAND` — fewer than 2 brands (Dirichlet undefined)
- `CFG_SCALE_MISSING` — `option_map` lacks `cat_buy_scale` rows
- `CALC_DIRICHLET_FAILED` — `NBDdirichlet` call errored; include the underlying message in `context`
- `PKG_DIRICHLET_MISSING` — package not installed

**Sanity checks (PARTIAL rather than REFUSED)**
- `Σ s_j` deviates from 1 by > 0.01 → warn, normalise, return PARTIAL
- Expected penetration > 1 for any brand → warn, clamp to 0.99, return PARTIAL

### 6.2 `compute_scr_from_freq()` — new helper in `08b_dirichlet_norms.R`

Current `share_of_requirements` in `run_repertoire()` only fires when `frequency_matrix` is non-null (TRANS categories). IPK is non-TRANS. So we need an **imputed SCR** from the category scale:

```r
compute_scr_from_freq(pen_mat, cat_buy_scale_codes, brand_codes,
                     option_map, weights = NULL)
```

**Method** — for each respondent i: total category purchases `m_i` from scale mapping; allocate evenly across their bought brands (absent brand-level frequency data, equal-share is the standard assumption, per Ehrenberg & Uncles 1999). Then SCR_j = Σ_i (allocated_j_i) / Σ_i m_i over buyers of j, weighted.

**Output**
```r
data.frame(BrandCode, SCR_Pct, n_buyers, method = "equal_share_imputation")
```

Document the imputation in roxygen — `@note` field. The panel footnote must say "SCR imputed via equal-share allocation (Ehrenberg & Uncles 1999); direct SCR requires brand-level purchase frequency data."

### 6.3 `run_buyer_heaviness()` — new, in `08c_buyer_heaviness.R`

**Signature**
```r
run_buyer_heaviness(
  pen_mat, brand_codes, cat_buy_scale_codes, option_map,
  focal_brand = NULL, weights = NULL,
  tertile_method = "frequency"   # "frequency" | "quantile"
)
```

**Method**
1. Compute per-respondent monthly buy rate (same mapping as §6.1).
2. Split buyers into Heavy/Medium/Light tertiles. Default method = `"frequency"`: group by scale level (e.g., several/week = Heavy, once/week + few/month = Medium, monthly-or-less = Light). Fallback method = `"quantile"` based on imputed monthly frequency.
3. For each brand: decompose buyers into the three tiers. Also compute **w-bar_j** = mean category buy rate among brand j's buyers, and the gap vs overall category w-bar.
4. Compute **Natural Monopoly Index** = share of brand's buyers who are Light ÷ share of category's buyers who are Light. Leaders > 1.0, niches < 1.0.

**Output**
```r
list(
  status = "PASS",
  tertile_method = "frequency",
  tertile_bounds = list(heavy = c(...), medium = c(...), light = c(...)),
  category_buyer_mix = data.frame(Tier, Pct, n),
  brand_heaviness = data.frame(
    BrandCode, Heavy_Pct, Medium_Pct, Light_Pct,
    WBar_Brand, WBar_Category, WBar_Gap,
    NaturalMonopolyIndex,
    Brand_Buyers_n
  ),
  metrics_summary = list(focal_brand = ..., focal_nmi = ..., ...)
)
```

### 6.4 `04_repertoire.R` — extend crossover output

Add two matrices alongside existing `crossover_matrix` (which is the observed-duplication cross-tab).

**Expected duplication** under the Duplication-of-Purchase Law:
```
E(D_ij) = D × b_j
```
where `D` is a category-specific scalar fitted by OLS regression of observed off-diagonal `crossover_matrix[i,j]` on partner brand penetration `b_j`, no intercept. Standard Ehrenberg-Bass recipe.

**Deviation matrix**: `dop_deviation[i,j] = (observed_ij − expected_ij)`, in percentage points. Positive = partition above the law (functional/emotional cluster).

**New return fields** in `run_repertoire()`:
```r
dop_D_coefficient   = numeric(1),   # fitted D
dop_expected_matrix = data.frame(BrandCode, <brand cols>),
dop_deviation_matrix = data.frame(BrandCode, <brand cols>)
```

Leave `crossover_matrix` unchanged (it is load-bearing for the existing heatmap and tests).

## 7. Chart specs

All charts = pure SVG, no external libs. Follow the style in `04_chart_builder.R` (viewBox, inline `<style>`, `br-chart-*` class naming).

### 7.1 KPI strip — extend existing
Keep existing "% Category buyers" and "Mean buy rate" chips. **Add:**
- SCR (focal brand) — labelled "Share of requirements (focal)" with tiny bracket showing Dirichlet expected value. Format: `34% (exp. 38%)`.
- Mean repertoire size (already in repertoire summary; surface here).
- Natural Monopoly Index (focal) — single-value chip with sparkline-style arrow vs 1.0.

### 7.2 Double Jeopardy scatter (HERO — top of panel)
- x = penetration (%) — log scale optional, default linear
- y = SCR (%) — **primary DJ metric**. Option (in panel footer toggle) to switch y = `w` (buy rate).
- Points = brands; focal brand highlighted; label each point with brand code.
- Overlay: fitted curve from `dirichlet_norms$dj_curve`.
- Annotate brands `>20%` off the curve: "over-performer" / "under-performer".
- Tooltip: brand, penetration, SCR obs, SCR exp, deviation.
- Size: full-width, ~480px tall.

### 7.3 Dirichlet norms table (below scatter)
Tabular. Columns grouped under headers: *Penetration*, *Buy rate*, *SCR*, *100% Loyals*. Each group = Obs / Exp / Δ%. Deviation cells shaded green (+) / red (−) if `|Δ%| > 20`. Row for focal brand bolded. Footer: "Expected values from NBD-Dirichlet (Goodhardt, Ehrenberg & Chatfield 1984). SCR imputed per §6.2."

### 7.4 DoP deviation heatmap (replaces existing crossover table)
Re-skin the current `crossover_matrix` render to show `dop_deviation_matrix` instead of raw percentages. Cells shaded on a diverging scale: green (positive deviation), white (on law), red (negative). Raw observed % shown as small subscript. Keep the observed matrix available in a secondary view toggle ("Show raw duplication"). Partition candidates (clusters of ≥ 3 brands with shared positive deviations) flagged in a callout below.

### 7.5 Buyer-base heaviness stacked bar
One horizontal stacked bar per brand: Heavy / Medium / Light segments, sum = 100%. Sort by focal brand first, then by market share descending. Dotted vertical line at the category mix position for each tier (shows over/under-indexing). NMI value on the right.

### 7.6 Buy-rate profile (w-bar bars)
Horizontal bar per brand: `WBar_Brand` with a vertical reference line at `WBar_Category`. Bars to the right of the line = brand attracts heavier category buyers; left = attracts lighter. Pairs conceptually with 7.5 but surfaces the continuous metric.

## 8. Panel layout (Section requiring Duncan's sign-off before coding)

Proposed order top-to-bottom:
1. KPI strip (§7.1)
2. Double Jeopardy scatter (§7.2) — hero
3. Dirichlet norms table (§7.3)
4. Two-column: Buyer heaviness (§7.5) | Buy-rate profile (§7.6)
5. DoP deviation heatmap (§7.4) + partition callout
6. (Existing) Frequency distribution bars + repertoire size + brand repertoire profile — demoted to a collapsible "Descriptive detail" section at the bottom. Keep available but stop leading with them.

**Open question for Duncan:** should the DJ scatter's default y-axis be SCR (loyalty) or w (buy rate)? Academia is split; SCR is more popular in Romaniuk/Sharp, w in Ehrenberg original. Default proposed = SCR; toggle to w.

## 9. HTML/JS behaviour

- Base toggle (% total / % aware) **does not apply** to this panel — all metrics are among category buyers. Hide the toggle on this tab; do not just disable it silently.
- Period toggle (monthly / quarterly / annual) for the norms table + w/SCR metrics. Default = annual. Implement via `data-period` attribute on the table body and JS swap, following the MA tab toggle pattern in `panels/02_ma_panel.R`.
- Tooltips: reuse the `br-tooltip` class pattern from `04_chart_builder.R`.
- Accessibility: every chart needs a text summary paragraph above it (screen-reader + AI-annotation friendly). Copy pattern from `03c_funnel_panel_data.R`.

## 10. Excel / CSV outputs (`99_output.R`)

**New sheets per full-depth category:**
- `dirichlet_{CAT}` — the `norms_table` from §6.1
- `market_share_{CAT}` — volume-weighted shares
- `buyer_heaviness_{CAT}` — `brand_heaviness` from §6.3
- `dop_deviation_{CAT}` — `dop_deviation_matrix`

**Required: TRS-refuse with visible console output** if any of these outputs are missing from `cat_result`. Do **not** silently skip (reference the existing WOM output bug as the failure mode to avoid — `project_brand_module.md` §Priority 2).

## 11. Tests

Follow the module's `testthat` layout (`modules/brand/tests/testthat/`). Use or extend fixtures in `tests/fixtures/generate_ipk_9cat_wave1.R`.

### `test_dirichlet_norms.R` (minimum ~25 tests)
- Happy path: synthetic 5-brand category, check `norms_table` row count, column names, deviation signs.
- Reproduces a published textbook example (e.g., Ehrenberg 1988 toothpaste data — coder to verify numbers against source).
- TRS refusals: each code in §6.1.
- Weighted vs unweighted consistency (uniform weights → identical to unweighted within 1e-6).
- Missing `NBDdirichlet` package → `PKG_DIRICHLET_MISSING`.
- `PARTIAL` path: shares summing to 0.98 → normalised, status = `PARTIAL`, `warnings` populated.

### `test_buyer_heaviness.R` (minimum ~15 tests)
- Tertile boundaries correct under both methods.
- Focal brand NMI computation.
- Weighted path.
- Empty brand (zero buyers) — row present with NA, not dropped.

### `test_cat_buying_panel.R` (minimum ~10 tests)
- Panel HTML contract: required `data-*` attributes present.
- Period toggle renders all three period variants into the DOM.
- No JS console errors expected (assert via HTML string grep for known error-producing patterns).
- Panel degrades gracefully when `dirichlet_norms$status == "REFUSED"` — shows refusal message, descriptive section still renders.

Re-run the whole brand test suite after changes: target ≥ 812 pass (current baseline), plus the new tests. No regressions allowed.

## 12. Conventions — reminders

- **TRS everywhere**: no `stop()`, no `warning()` without a structured return. Copy the `handle_error()` console-box pattern from `CLAUDE.md` for any user-facing refusal in `00_main.R`.
- **`cat_data` vs `data`**: all six additions are per-category → use `cat_data`. Do not touch Portfolio.
- **Attitude base convention** does not apply here (we are in buyer-only land).
- **Weights thread**: every new function must accept `weights` and pass it through. `sum(weights, na.rm = TRUE) <= 0` triggers `weights <- NULL` (match `08_cat_buying.R:84`).
- **Roxygen2** on every exported function; `@references` section pointing at the literature anchor.
- **Version constants**: each new file declares `<MODULE>_VERSION <- "1.0"` and emits the loaded-message (suppressed under `TESTTHAT=true`) — match the pattern at `08_cat_buying.R:14` and `:204-207`.

## 13. Acceptance checklist

- [ ] `NBDdirichlet` added to `renv.lock`
- [ ] New R files created, sourced by `00_main.R`
- [ ] `cat_result$dirichlet_norms` and `cat_result$buyer_heaviness` populated for every full-depth category
- [ ] `04_repertoire.R` returns `dop_expected_matrix`, `dop_deviation_matrix`, `dop_D_coefficient` in addition to existing fields
- [ ] Panel reorganised per §8 (pending Duncan sign-off on that section)
- [ ] All charts render for IPK sample, focal brand highlighted, tooltips populated
- [ ] Period toggle works
- [ ] Excel + CSV outputs include the four new sheets/files per category
- [ ] TRS refusals produce console boxes and structured returns (no silent skips)
- [ ] Test suite: all previously passing tests still pass + ~50 new tests all pass
- [ ] Panel footer cites Ehrenberg/Sharp/Romaniuk/Goodhardt
- [ ] Update `project_brand_module.md` memory with the new state

## 14. What this session must NOT do

- Do not touch the Funnel, MA, WOM, or Portfolio panels.
- Do not re-implement Dirichlet maths from scratch — use `NBDdirichlet`.
- Do not remove the existing descriptive charts (they move, they do not disappear).
- Do not remove `share_of_requirements` field from `run_repertoire()` — another module may depend on it.
- Do not alter `cat_buy_scale` mappings or the `.CAT_BUY_SCALE_WEIGHTS` constant — reuse from `08_cat_buying.R`.
- Do not add TRANS-category frequency logic (out of scope; IPK is non-TRANS).

## 15. Post-session handover note to write

At end of session, update `/Users/duncan/.claude/projects/-Users-duncan-Dev-Turas/memory/project_brand_module.md`:
- Bump test count
- Mark Category Buying panel as **v2 (Dirichlet-grounded)**
- List new files under §Key files
- Note the `NBDdirichlet` dependency

Also spawn a follow-up memory for the growth-quadrant + Pareto + MA×DJ ideas that were deferred — they are on the roadmap, not lost.

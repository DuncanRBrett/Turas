# Brand Module — Funnel Element Spec v2

**Version:** 2.0 (draft, supersedes `Funnel.docx`) **Scope:** Single-category brand funnel as a derived view on shared CBM batteries. **Applies to:** `modules/brand/R/03_funnel.R` + HTML panel + Excel/CSV outputs. **Status:** Design spec — nothing implemented against it yet.

------------------------------------------------------------------------

## 1. Purpose

Produce an honest, richly-annotated diagnostic of where a brand gains or loses people relative to competitors — from awareness through consideration, buying, and brand preference. Stages are derived from core CBM data (no dedicated funnel questions).

Supports three category types: transactional (FMCG), durable, service. Stage shape adapts by type. Visualisation contract is type-agnostic.

------------------------------------------------------------------------

## 2. Scope — v1 vs deferred

### In v1 (this spec)

-   Three category-type funnel shapes: transactional (up to 5 stages), durable (up to 4), service (up to 4).
-   **Nested-funnel derivation** — every stage is a subset of the previous.
-   **Four view layers:** metric cards, competitive table, shape chart, consideration detail.
-   **Attitude decomposition** with segment-emphasis interaction (click Love / Reject / etc. to highlight).
-   **Global brand selection** via chip picker + quick-select helpers, persisted to pin state.
-   **Significance testing** on focal-vs-competitor + focal-vs-category-average (reuses tabs module).
-   **Weighted and unweighted bases** on every view.
-   **Low-base warning** (configurable threshold); optional suppression (off by default).
-   **Small-multiples alternate view** for the shape chart.
-   **Show-counts toggle** — same pattern as tabs (`show-freq` CSS class, driven by the user-visible control `Show counts` in the panel chrome). When enabled, every card and table cell displays the underlying weighted N below the %. Default off. Pin state persists the toggle.
-   **Excel** (3 analytic sheets + metadata) + **CSV** (long format) outputs, with ClientCode and QuestionText on every row.

### Deferred to v1.1

-   **Segment overlay** — per-segment small-multiples funnel. Data structures carry segment flags; UI deferred.
-   **Tracker wave-over-wave UI** — data structures carry wave labels; UI is one-wave in v1.
-   **Confidence intervals** — omitted by decision (panel sampling is non-probability; MoE is pretence).

------------------------------------------------------------------------

## 3. Stage derivation

### 3.1 Transactional (up to 5 stages)

| \# | Stage | Default label | Derivation |
|----|----|----|----|
| 1 | Aware | Aware | `funnel.awareness = 1` |
| 2 | Consideration | Consideration | `aware = 1` AND `attitude ∈ {love, prefer, ambivalent}` |
| 3 | Bought | Bought | prev stage AND `bought_long = 1` — omitted if role absent |
| 4 | Frequent | Frequent | prev stage AND `bought_target = 1` — omitted if role absent |
| 5 | Preferred | Preferred | prev stage AND `frequency` = argmax across all brands for that respondent (ties counted — all tied brands flagged as Preferred) |

Stages 3–5 collapse individually when their roles are absent. Minimum funnel = stages 1–2.

### 3.2 Durable (up to 4 stages)

| \# | Stage | Default label | Derivation |
|----|----|----|----|
| 1 | Aware | Aware | `funnel.awareness = 1` |
| 2 | Consideration | Consideration | `aware = 1` AND attitude positive |
| 3 | Current owner | Current owner | prev stage AND `current_owner = brand` |
| 4 | Long-tenured | Long-tenured owner | prev stage AND `tenure ≥ tenure_threshold` — omitted if role absent or threshold not set |

### 3.3 Service (up to 4 stages)

| \# | Stage | Default label | Derivation |
|----|----|----|----|
| 1 | Aware | Aware | `funnel.awareness = 1` |
| 2 | Consideration | Consideration | `aware = 1` AND attitude positive |
| 3 | Current customer | Current customer | prev stage AND `current_customer = brand` |
| 4 | Long-tenured | Long-tenured customer | prev stage AND `tenure ≥ tenure_threshold` — omitted if absent |

Prior-brand data (`funnel.service.prior_brand`) is **not** rendered as a funnel stage. About drawer notes: *"prior-brand data available — see Repertoire"* when the role is populated.

### 3.4 Nesting invariant

For every brand B and every stage S \> 1: `count(B, S) ≤ count(B, S-1)`.

Nested by construction: each stage's derivation ANDs the previous stage's boolean matrix. Guard test enforces on every run. On violation, refuse with `CALC_NESTING_VIOLATED` and a diagnostic showing the offending (brand, stage, count) tuple.

### 3.5 "Preferred" ties

A respondent whose max frequency is tied across multiple brands is counted as Preferred for **all** tied brands. Brand-level Preferred percentages can therefore sum to \>100% across the category. This is documented in the About drawer:

> *Preferred includes ties. Respondents whose purchase frequency is equal-highest across multiple brands are counted for each of those brands. Preferred percentages can sum above 100% across the category as a result.*

------------------------------------------------------------------------

## 4. Config schema additions

### 4.1 `Brand_Config.xlsx` — Settings sheet

| Setting | Type | Default | Notes |
|----|----|----|----|
| `category.type` | enum | `transactional` | `transactional` / `durable` / `service` |
| `funnel.conversion_metric` | enum | `ratio` | `ratio` = % of % (default); `absolute_gap` = percentage-point drop |
| `funnel.warn_base` | integer | 75 | Show warning indicator when stage base \< this |
| `funnel.suppress_base` | integer | 0 | Suppress metric when stage base \< this; 0 = never suppress |
| `funnel.tenure_threshold` | string | (empty) | Ordinal value from the tenure OptionMap; required if durable/service loyalty stage wanted |
| `funnel.stage_labels_override` | string | (empty) | Optional JSON — override default stage labels for this project |
| `funnel.significance_level` | numeric | 0.05 | Significance test alpha |

### 4.2 `Survey_Structure.xlsx`

Funnel populates roles per §4 of the Role Registry. Minimum roles for any funnel:

-   `funnel.awareness` (required)
-   `funnel.attitude` (required)
-   At least one of the category-type-specific penetration roles

------------------------------------------------------------------------

## 5. Function inventory — `modules/brand/R/03_funnel.R`

File target: ≤ 300 active lines. Current state will exceed: split into two files.

### 5.1 Public entry point

``` r
run_funnel(
  data,
  role_map,
  brand_list,
  config,
  weights = NULL,
  sig_tester = NULL
)
```

| Arg | Purpose |
|----|----|
| `data` | Survey data frame (respondent rows × coded columns) |
| `role_map` | Named list — role → column spec (column name(s), pattern, option_map). Built by the config loader from Survey_Structure. |
| `brand_list` | Data frame with BrandCode, BrandName, DisplayOrder |
| `config` | Named list of funnel.\* Settings values |
| `weights` | Optional numeric respondent weights |
| `sig_tester` | Closure from tabs module for two-proportion z-tests; NULL = no sig testing |

**Returns** structured list:

``` r
list(
  status,                    # "PASS" | "PARTIAL" | "REFUSED"
  stages,                    # ordered data frame: brand × stage × pct + base
  conversions,               # brand × stage-transition × metric
  attitude_decomposition,    # brand × 5 attitude positions (% of aware base)
  sig_results,               # focal vs each competitor + focal vs cat avg, per stage
  base_warnings,             # per brand-stage cell — none/warn/suppress
  metrics_summary,           # condensed list for AI callouts + About
  warnings,                  # accumulator for PARTIAL status
  meta                       # category_type, focal_brand, wave, n_weighted, n_unweighted
)
```

### 5.2 Internal functions (each ≤ 50 active lines)

| Function | Purpose |
|----|----|
| `derive_funnel_stages(data, role_map, category_type, brand_list)` | Returns ordered list of per-respondent × per-brand logical matrices, one per stage, with stage labels. Applies nesting. |
| `calculate_stage_metrics(stage_matrices, weights, warn_base, suppress_base)` | Weighted % per brand per stage + base sizes + warning flags. |
| `calculate_conversions(stage_metrics, method)` | Ratio or absolute-gap per stage transition. |
| `calculate_attitude_decomposition(attitude_matrix, awareness_matrix, option_map, weights)` | 5-position proportions per brand with aware base as denominator. |
| `run_significance_tests(stage_metrics, focal_brand, sig_tester, alpha)` | Focal-vs-competitor + focal-vs-category-average per stage. |
| `validate_nesting(stage_matrices)` | Enforces §3.4 invariant. Refuses loud on violation. |
| `build_metrics_summary(stages, conversions, decomposition, focal_brand)` | Condensed named list for auto-generated headline text + AI callouts. |

### 5.3 File split

If line budget is tight:

```         
03_funnel.R              # run_funnel() public entry + build_metrics_summary()
03a_funnel_derive.R      # derive_funnel_stages + validate_nesting
03b_funnel_metrics.R     # calculate_stage_metrics + _conversions + _attitude_decomposition + _significance_tests
```

------------------------------------------------------------------------

## 6. HTML data contract

`build_funnel_panel_data(result)` returns a named list consumed by the HTML panel builder:

``` r
list(
  meta = list(
    category_type, focal_brand_code, focal_brand_name, category_label,
    wave_label, n_weighted, n_unweighted, stage_count, stage_labels
  ),

  cards = list(
    # one entry per stage — focal brand + category average
    list(
      stage_index, stage_label,
      focal_pct, focal_base_weighted, focal_base_unweighted,
      cat_avg_pct, cat_avg_base,
      sig_vs_avg,            # "higher" | "lower" | "not_sig" | "na"
      warning_flag,          # "none" | "warn" | "suppress"
      question_text,         # from QuestionMap
      question_text_short
    )
  ),

  table = list(
    # rows = stages, columns = brands (including category_average column)
    stage_labels,
    brand_codes,
    brand_names,
    cells = list(
      # one per (stage × brand)
      pct, base_weighted, base_unweighted,
      sig_vs_focal,          # "higher" | "lower" | "not_sig" | "focal" | "na"
      warning_flag
    )
  ),

  shape_chart = list(
    # series-per-brand for slope chart
    focal_series,            # list(stage_labels, pct_values, base_values)
    competitor_series,       # list of per-brand series
    category_avg_series,
    category_band,           # min/max envelope across all brands
    stage_positions,
    default_view             # "slope" | "small_multiples"
  ),

  consideration_detail = list(
    # per brand, 5 attitude segments as % of aware base
    brands = list(
      list(
        brand_code, brand_name, aware_base,
        segments = list(love, prefer, ambivalent, reject, no_opinion),
        segment_labels         # from OptionMap ClientLabel
      )
    ),
    emphasis_state = "all",  # "all" | "love" | "prefer" | "ambivalent" | "reject" | "no_opinion"
    sort_mode = "default"    # "default" | "by_emphasised_desc"
  ),

  config = list(
    chip_picker = list(
      default_selection,     # focal + top N by awareness
      all_brands,
      quick_select_modes     # "top_awareness" | "top_buying" | "clear" | "all"
    ),
    conversion_metric,       # "ratio" | "absolute_gap"
    warn_base, suppress_base,
    show_counts = FALSE      # toggle state; drives `show-freq` class on the panel root.
                             # Every cards and table cell already carries base_weighted
                             # / base_unweighted so the UI can render "N = ..." without
                             # a re-query.
  ),

  about = list(
    question_texts,          # per-role client wording from QuestionMap
    methodology_note,        # nested-funnel callout (canonical text, §9.3)
    base_note,               # weighted vs unweighted explanation
    significance_note,       # panel-sampling disclosure (canonical text, §8.3)
    ties_note,               # Preferred ties explanation (canonical text, §3.5)
    prior_brand_note         # service only, when role present
  )
)
```

------------------------------------------------------------------------

## 7. Outputs — Excel + CSV

### 7.1 Excel (`funnel_{category_code}.xlsx`)

| Sheet | Content |
|----|----|
| `Stage_Matrix` | Rows = brands; columns = stages; values = weighted %. Base row beneath. ClientCode + QuestionText in header cells. |
| `Conversions` | Rows = brands; columns = stage transitions (e.g. `Aware→Consideration`); values = ratio or gap per config. |
| `Attitude_Decomposition` | Rows = brands; columns = 5 attitude positions (% of aware base) + aware base size. |
| `Metadata` | Category type, focal brand, wave, base sizes, significance method note, config settings used. |

### 7.2 CSV (`funnel_{category_code}_long.csv`)

Long format, one row per brand × stage × wave:

```         
brand_code, brand_name, stage_index, stage_label,
pct_weighted, pct_unweighted, base_weighted, base_unweighted,
warning_flag, sig_vs_focal, sig_vs_cat_avg,
wave_label, category_code, client_code, question_text
```

One CSV per category. Tracker concatenates across waves.

------------------------------------------------------------------------

## 8. Significance testing

### 8.1 Test

Two-proportion z-test from tabs module (`modules/tabs/lib/significance.R`).

### 8.2 Pairs tested

-   **Focal vs each competitor** at each stage (one test per stage per competitor).
-   **Focal vs category average (excluding focal)** at each stage.
-   **No all-pairs matrix** — too noisy, not the primary diagnostic.

### 8.3 Alpha

-   Default 95% (α = 0.05), configurable via `funnel.significance_level`.

### 8.4 Panel disclosure — canonical text

About drawer carries verbatim:

> *Significance tests compare observed proportions between brands using a two-proportion z-test. Panel sampling is non-probability; margin of error is not reported. Results show whether observed differences exceed sampling variation under standard assumptions.*

------------------------------------------------------------------------

## 9. Low-base handling

### 9.1 Thresholds

-   `funnel.warn_base` (default 75) — metric rendered with warning indicator + tooltip.
-   `funnel.suppress_base` (default 0, off) — metric hidden, "—" shown when base below threshold.
-   Both configurable. Default behaviour: lenient — show all values with flags.

### 9.2 Per-stage application

Applied to each stage's base independently, not to total sample size. A brand with total n=200 but Preferred n=15 gets the Preferred metric flagged while earlier stages pass.

### 9.3 Nested-funnel methodology — canonical text

About drawer carries verbatim:

> *Funnel stages are nested: each stage is a subset of the previous. A respondent is counted in "Consideration" only if they also selected the brand at Awareness. This ensures every stage is a true subset of the one before and that conversion ratios are honest. Stages derive from: Awareness (QuestionText), Attitude codes 1–3 (QuestionText), and buying questions per the study's category type.*

QuestionText values substituted from QuestionMap.

------------------------------------------------------------------------

## 10. Test plan

### 10.1 Known-answer fixtures

Three synthetic 10-respondent fixtures, each hand-calculated in `funnel_known_answers.xlsx`:

-   **Transactional fixture** — 10 respondents × 3 brands, covering all 5 stages, including one Preferred tie case. Expected values pre-computed by hand.
-   **Durable fixture** — 10 respondents × 3 brands with `current_owner` + `tenure` covering threshold edge cases (= threshold, \< threshold, missing tenure).
-   **Service fixture** — 10 respondents × 3 brands with `current_customer` + `prior_brand`. Validates prior-brand is About-only, not a stage.

Tests assert **exact** values from the hand calculations.

### 10.2 Edge case tests

-   Zero awareness for a brand → 0% at every stage; no division errors in conversions.
-   All aware, none positive → Consideration = 0; conversions defined as 0.
-   Fabricated nesting violation → guard refuses with diagnostic.
-   Missing optional role → stage omitted; rest of funnel renders; About lists what's missing.
-   Missing required role → guard refuses loud at config-load, not run time.
-   OptionMap omits Ambivalent → Consideration = Love + Prefer only; About explains.
-   Inverted attitude scale (1 = no_opinion, 5 = love) → correctly remapped; same results.
-   Preferred ties → all tied brands counted; brand-level sum \> 100% documented.
-   All brand codes contain non-ASCII → no encoding failures.
-   Weights all equal 1 → weighted results match unweighted exactly.
-   Weights sum to zero → guard refuses loud.
-   `suppress_base` set to 50 → metrics with base 30–49 show "—"; 50–74 show with warn; 75+ clean.

### 10.3 Integration tests

-   Full `run_brand()` against the 1Brand synthetic example end-to-end.
-   IPK multi-category fixture — per-category funnel with focal-category routing.
-   Weighted / unweighted parity — design weights produce expected ratios.
-   Cross-module: significance-testing call returns expected structure from tabs module.

### 10.4 Coverage

100% of public functions. Every error path tested. Minimum 35 test cases across fixtures + edge cases + integration.

------------------------------------------------------------------------

## 11. Breaking changes

The existing `03_funnel.R` and its 62 tests are replaced wholesale.

| Old | New |
|----|----|
| `run_funnel(data, brands, awareness_prefix, attitude_prefix, penetration_prefix, ...)` | `run_funnel(data, role_map, brand_list, config, weights, sig_tester)` |
| 4-stage only (Aware / Positive / Bought / Primary) | 3–5 stages by category type |
| Single penetration prefix | Three category-type-specific role sets |
| Primary = attitude code 1 | Preferred = frequency argmax with ties |
| No nesting | Strict nesting (validated) |
| No CIs no sig testing wired | Sig testing wired, CIs explicitly out |

Existing tests are ported, not preserved. No deprecation adapter (module still in build).

------------------------------------------------------------------------

## 12. File structure

```         
modules/brand/R/
├── 03_funnel.R                       # public entry + metrics summary
├── 03a_funnel_derive.R               # stage derivation per category type
├── 03b_funnel_metrics.R              # metrics + conversions + attitude decomposition + significance

modules/brand/lib/html_report/panels/
├── 03_funnel_panel.R                 # consumes build_funnel_panel_data() output

modules/brand/tests/testthat/
├── test_funnel_transactional.R       # hand-calculated transactional fixture
├── test_funnel_durable.R             # hand-calculated durable fixture
├── test_funnel_service.R             # hand-calculated service fixture
├── test_funnel_nesting.R             # nesting invariant + guard refusals
├── test_funnel_edge_cases.R          # optional roles, inverted scales, ties, base rules
├── test_funnel_integration.R         # end-to-end via run_brand()

modules/brand/tests/fixtures/
├── funnel_transactional_10resp.csv
├── funnel_durable_10resp.csv
├── funnel_service_10resp.csv
├── funnel_known_answers.xlsx         # hand-calculated expected values
```

------------------------------------------------------------------------

## 13. Pre-build review checklist

Please confirm before I write any code:

-   [ ] Stage derivation tables (§3.1–3.3) match your mental model for each category type.
-   [ ] Config settings (§4.1) — names and defaults acceptable.
-   [ ] Function signature (§5.1) — `run_funnel(data, role_map, brand_list, config, weights, sig_tester)` — shape is right.
-   [ ] Internal decomposition (§5.2) — seven internal functions at the right granularity.
-   [ ] HTML data contract (§6) — fields cover all four layers; structure is what the panel builder needs.
-   [ ] Excel (§7.1) — 3 analytic sheets + metadata is the right split.
-   [ ] CSV (§7.2) — long format columns cover what tracker + onward analysis needs.
-   [ ] Significance testing (§8) — focal-vs-competitor + focal-vs-cat-avg scope is right (no all-pairs).
-   [ ] Low-base handling (§9) — per-stage application with warn default 75 / no suppression default is correct.
-   [ ] Canonical About texts (§3.5, §8.4, §9.3) — wording is acceptable for client-facing reports.
-   [ ] Test fixture granularity (§10.1) — 10 respondents × 3 brands × 3 category types with hand-calculated expected values is the right level.
-   [ ] File split (§12) — splitting derivation + metrics into separate files meets the 300-line budget without over-fragmenting.

------------------------------------------------------------------------

**End of Funnel spec v2.0.**

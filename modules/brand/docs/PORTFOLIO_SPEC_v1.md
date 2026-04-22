# Brand Module — Portfolio Mapping Element Spec v1

**Version:** 1.0 (draft, supersedes `portfolio.docx`)
**Scope:** Cross-category portfolio analysis built from category-buying (13m/3m) + cross-category awareness data collected *before* the focal category deep-dive.
**Applies to:** `modules/brand/R/00_main.R` (existing `.compute_portfolio_data` skeleton), new `09_portfolio*.R` files, new HTML panel, Excel/CSV outputs.
**Status:** Design spec — skeleton exists (00_main.R:849–945), analyses net-new.

------------------------------------------------------------------------

## 1. Purpose

Turn the up-front "which categories did you buy in?" + "which brands are you aware of in those categories?" screens into a first-class strategic deliverable. Answers four client questions that focal-only studies cannot:

1. **Where is my brand strong vs weak across the categories I play in?**
2. **Who are my real competitors in the consumer's head (not the category book's)?**
3. **How crowded is each category, and where is there still mental room?**
4. **Which adjacent categories give me permission to extend?**

All analyses are grounded in *revealed awareness conditioned on being a category buyer* — a denominator that makes every metric defensible.

------------------------------------------------------------------------

## 2. Scope — v1 vs deferred

### In v1

- **Five analyses** (§4): Footprint Heatmap, Competitive Constellation, Clutter Quadrant, Portfolio Strength Map, Permission-to-Extend Table.
- **Supporting metrics** (§5): Awareness Set Size, Repertoire Depth, Awareness Efficiency Ratio, Co-purchase matrix.
- **New top-level "Portfolio" tab** — already reserved in nav (`03_page_builder.R:106–107`), gated by `element_portfolio = Y`.
- **Four subtabs inside Portfolio:** Footprint / Competitive Set / Category Context / Extension Opportunities.
- **Weighted and unweighted bases** on every chart.
- **Low-base suppression** at configurable `min_base` (default 30 unweighted).
- **TurasPin integration** — every chart pinnable; constellation node click and quadrant dot click both pin-addressable.
- **Show-counts toggle** — mirrors funnel/MA panel pattern.
- **Excel** (5 analytic sheets + metadata) + **CSV** (long format) outputs.

### Deferred to v1.1

- **Segment overlay** — same shape as funnel deferral; data carries segment flags, UI single-segment in v1.
- **Tracker wave-over-wave** — portfolio shift analysis; data carries wave labels, UI single-wave.
- **TURF on categories** — reach optimisation across categories (e.g. "smallest portfolio covering 80% of buyers").
- **Price-tier overlay** — requires `price_tier` role not yet in role registry.
- **Statistical significance** on co-awareness edges — needs bootstrap; deferred for performance reasons.
- **Cross-panel brand filter via constellation node click** — in v1, a node click re-centres the constellation only. Filtering the whole Portfolio tab to the clicked brand is deferred (see §12 Q5).

### Explicitly out of scope

- Any analysis requiring purchase-at-brand level for non-focal categories (we only have awareness, not brand purchase, cross-category).
- Hypothetical-extension questions ("would you buy focal brand if it launched in category X?") — not collected; we infer from revealed awareness.

------------------------------------------------------------------------

## 3. Inputs

### 3.1 Required data columns

| Column pattern | Semantic | Source |
|---|---|---|
| `SQ1_{cat_code}` | Bought in long window (13m) — 1/0 | Up-front screener, all respondents × all categories |
| `SQ2_{cat_code}` | Bought in short window (3m) — 1/0 | Up-front screener, all respondents × all categories |
| `BRANDAWARE_{cat_code}_{brand_code}` | Aware of brand in category — 1/0 | Cross-category awareness battery, **SQ1-gated** |
| `{weight_variable}` | Survey weight | Config-driven |
| `{respondent_id_col}` | Respondent ID | Config-driven |

**Authoritative data fixture:** `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` (1,200 respondents, 4 focal × 300). Lines 177–198 define the cross-category awareness logic:

> All respondents answer brand awareness for every category — not just focal. For non-focal categories, awareness is **gated on `SQ1_{cat} = 1`** (the respondent qualified as a buyer in that category); non-qualifiers receive `0`, not `NA`.

**Denominator rule (load-bearing):** every rate in §4 uses the set of **SQ1 qualifiers** for the relevant category as its denominator. This avoids the common pitfall of deflating awareness rates with structural zeros from non-qualifiers. Guard against this via `build_portfolio_base()` — one helper, reused by every analysis.

**Do NOT use** the legacy generator at `examples/9cat/04_data.R` for portfolio testing. That generator produces `n = 400` with awareness only for focal-assigned respondents and does not reflect the real questionnaire design. Tests must use the 1,200-row fixture above.

Detection: use existing `.detect_category_code()` (`00_main.R:763–783`) and `get_brands_for_category()` (`01_config.R:364–371`). Do not re-invent.

### 3.2 Required config keys

Already in `01_config.R` schema — no schema changes needed:

- `element_portfolio` — Y/N gate (default N)
- `cross_category_awareness` — **must be Y** (TRS refuse if N and element_portfolio = Y)
- `focal_brand` — brand code, required for focal-centric views
- `focal_assignment` — drives which respondents are in the portfolio base
- Categories sheet — `Analysis_Depth` column; portfolio uses **all** rows regardless of depth

### 3.3 New config keys (additive, all optional)

| Key | Default | Purpose |
|---|---|---|
| `portfolio_min_base` | 30 | Unweighted cell suppression threshold |
| `portfolio_cooccur_min_pairs` | 20 | Minimum co-occurrence count to draw an edge in constellation |
| `portfolio_timeframe` | "3m" | "3m" (SQ2) or "13m" (SQ1) — default anchor; user can toggle in panel chrome (§12 Q1) |
| `portfolio_extension_baseline` | "all" | "all" \| "non_buyers" — denominator for permission-to-extend lift |
| `focal_home_category` | "" (auto) | Optional override; blank = auto-detect by highest `A(focal, c)` (§12 Q2) |

All defaults chosen so running with no new config gives a sensible report.

------------------------------------------------------------------------

## 4. Analyses

### 4.1 Footprint Heatmap

**Question:** Across which categories is each brand known, and at what strength?

**Derivation:**

Let `A(b, c)` = % of buyers of category `c` (per `portfolio_timeframe`) who are aware of brand `b`, weighted.

    A(b, c) = sum_{i in buyers(c)} w_i * aware(i, b, c) / sum_{i in buyers(c)} w_i

**Matrix:** brands (rows) × categories (cols). Sort rows by total footprint (sum across cats). Sort cols by category size.

**Chart:** `build_heat_strip()` (`04_chart_builder.R:272`) — **already exists**, reuse directly. Cell colour = awareness %, 0–100% ramp. Focal brand row highlighted.

**Defensibility:** Denominator is category buyers, not total sample. A brand with 80% awareness among category buyers and 10% among non-buyers is a strong brand in that category — this metric captures that correctly.

**Edge cases:**
- Category with <`portfolio_min_base` buyers → column suppressed, note in About drawer.
- Brand absent from a category (not in QuestionMap) → cell shows `—` not `0%`. Rationale: not-asked ≠ not-aware.

### 4.2 Competitive Constellation (Co-Awareness Network)

**Question:** Who are focal brand's real competitors in the consumer's head?

**Derivation:**

For every pair `(b1, b2)`, compute Jaccard similarity across the *union of their category awareness universes*:

    J(b1, b2) = |{i : aware(i, b1, any cat) AND aware(i, b2, any cat)}|
              / |{i : aware(i, b1, any cat) OR  aware(i, b2, any cat)}|

Use weighted counts.

Threshold edges below `portfolio_cooccur_min_pairs` raw co-occurrences (suppress noise on small brands).

**Chart:** Force-directed network — **net-new**. Create `build_network()` in `04_chart_builder.R`. SVG, inline, no JS physics (pre-computed layout via simple force simulation in R using `igraph::layout_with_fr` if available, else deterministic fallback).

- **Nodes:** one per brand. Size = total aware respondents. Colour = focal / focal's own portfolio / competitor (reuse `colour_focal`, `colour_focal_accent`, `colour_competitor` from config).
- **Edges:** width ∝ Jaccard. Top-N edges only (`portfolio_edge_top_n`, default 40) to keep readable.
- **Interaction:** click a node → re-centres the view and pins "competitive set for brand X". Pin-addressable.

**Defensibility:** Jaccard on revealed-awareness co-occurrence, not attribute ratings. Transparently formula-based, reproducible. Method note in About drawer.

**Edge cases:**
- Fewer than 3 brands in universe → refuse `CALC_CONSTELLATION_TOO_SPARSE`, fall back to footprint only.
- Focal brand has <`portfolio_min_base` aware respondents → chart renders without focal highlight and About drawer notes the limitation.

### 4.3 Clutter Quadrant

**Question:** Where is each category on the crowded-vs-open and focal-strong-vs-weak map?

**Derivation:**

For each category `c`:
- `x_c` = mean number of brands a buyer is aware of in `c` (awareness set size, weighted mean).
- `y_c` = focal brand's share of awareness in `c` = `A(focal, c) / sum_b A(b, c)`.

Plot one dot per category. Reference lines at category-median x and at `y = 1 / k_c` where `k_c` = number of brands in category (the "fair share" line).

**Four quadrants** (relative to medians / fair-share):
- **Dominant:** low clutter, focal strong
- **Contested:** high clutter, focal strong
- **Niche Opportunity:** low clutter, focal weak
- **Forgotten / Wrong Battle:** high clutter, focal weak

**Chart:** `build_scatter()` (`04_chart_builder.R:150`) — **already exists with quadrant support**, reuse. Dot size = category penetration in sample. Label every dot with category name.

**Defensibility:** Every input is a survey-observed rate with a clear formula. Quadrant labels are interpretive — always print the underlying numbers beside the chart (small table).

**Edge cases:**
- Focal brand absent from a category → plot at y=0 with explicit "not in category" annotation.
- Awareness set size computed only over respondents who qualified as buyers of the category.

### 4.4 Portfolio Strength Map

**Question:** For brands in multiple categories, which categories are strongholds vs under-leveraged?

**Derivation:**

For the focal brand (or any brand with ≥2 categories):
- `x_c` = category penetration in total sample (unweighted n of SQ1/SQ2 buyers ÷ n_total)
- `y_c` = `A(brand, c)` — awareness among category buyers
- bubble size = absolute weighted n of aware-buyers

**Chart:** Bubble scatter — **net-new**. Add `build_bubble_scatter()` to `04_chart_builder.R`. Essentially `build_scatter()` with variable-radius points — either extend existing scatter or create a thin wrapper.

Diagonal reference line at `y = x` conceptually flags "expected" performance if awareness scaled with category participation; above-line = earning, below-line = under-earning.

**Interaction:** Brand selector at top of panel — chip picker reusing funnel/MA pattern. Default = focal brand. Switching brand re-renders only this chart.

**Defensibility:** Both axes are raw survey rates. The "expected" diagonal is the only interpretive layer — about drawer explains it is a visual aid, not a statistical prediction.

**Edge cases:**
- Brand in only one category → chart replaced with single-category callout card.
- Weighted and unweighted bubble sizes both available; default weighted, toggleable.

### 4.5 Permission-to-Extend Table

**Question:** Which adjacent categories give focal brand the strongest invitation to extend?

**Derivation:**

For each category `c` *not* focal's home:

    lift(c) = P(aware of focal | bought c) / P(aware of focal | baseline)

where baseline is controlled by `portfolio_extension_baseline`:
- `"all"` — all respondents in sample
- `"non_buyers"` — respondents who did NOT buy focal's home category (purer adjacency signal)

Sort categories descending by lift. Show columns: Category | Buyers of c (n) | % aware of focal among buyers | Lift vs baseline | Significance flag.

**Chart:** Table via `02_table_builder.R`. Bar-in-cell for lift magnitude.

**Defensibility:** Lift is a ratio of two observed rates. Significance flag uses a simple two-proportion z-test (borrow from tabs module) with an FDR correction across categories (Benjamini–Hochberg).

**Edge cases:**
- Focal brand has no "home" category defined → prompt in Settings; all categories treated as potential extensions.
- `n < portfolio_min_base` buyers in a category → row still shown but lift greyed and flagged "low base".

------------------------------------------------------------------------

## 5. Supporting metrics

Shown as a hero-strip at top of Portfolio tab (KPI cards, mirroring funnel panel pattern).

| Metric | Formula | Card label |
|---|---|---|
| Avg awareness set size | Mean over respondents of `sum_b aware(i, b, c_focal)`, weighted | "In focal category, buyers typically know N brands" |
| Focal footprint breadth | Count of categories where focal has `A(focal, c) > 0` | "Focal brand is known in N of K categories" |
| Focal awareness efficiency | `share_of_awareness(focal, cat_focal) / category_penetration(cat_focal)` | "Earning N× its category presence" |
| Mean repertoire depth | Mean over respondents of count of categories bought in (per `portfolio_timeframe`) | "Respondents shop N categories on average" |

------------------------------------------------------------------------

## 6. Data structures

### 6.1 Extended `.compute_portfolio_data()` output

Current (00_main.R:924–944) returns a shallow per-category summary. Extend to:

    list(
      focal_brand = character,
      timeframe = "3m" | "13m",
      n_total = integer,
      n_weighted = numeric,
      bases = list(
        per_category = data.frame(cat, n_buyers_uw, n_buyers_w, n_aware_total_uw, n_aware_total_w),
        per_brand = data.frame(brand, n_aware_uw, n_aware_w, n_categories_present)
      ),
      footprint_matrix = matrix[brand x category] of awareness %,   # 4.1
      constellation = list(                                         # 4.2
        nodes = data.frame(brand, n_aware_w, is_focal),
        edges = data.frame(b1, b2, jaccard, cooccur_n),
        layout = data.frame(brand, x, y)                            # pre-computed
      ),
      clutter = data.frame(                                         # 4.3
        cat, awareness_set_size_mean, focal_share_of_aware,
        cat_penetration, quadrant
      ),
      strength = list(                                              # 4.4
        per_brand = list(brand_code = data.frame(cat, cat_pen, brand_aware, aware_n_w))
      ),
      extension = data.frame(                                       # 4.5
        cat, n_buyers_uw, focal_aware_pct, lift, p_value, p_adj,
        low_base_flag
      ),
      supporting = list(                                            # §5
        avg_awareness_set_size_focal_cat = numeric,
        focal_footprint_breadth = integer,
        focal_awareness_efficiency = numeric,
        mean_repertoire_depth = numeric
      ),
      suppressions = list(
        low_base_cats = character,
        dropped_brands = character,
        dropped_edges = integer
      )
    )

### 6.2 Panel data payload

New file: `R/09_portfolio_panel_data.R` with `build_portfolio_panel_data(portfolio_result, config, structure)`. Returns a JSON-safe list embedded in `<script type="application/json">` by the panel HTML builder. Shape mirrors existing `build_ma_panel_data()` (`R/02a_ma_panel_data.R:46–150+`).

------------------------------------------------------------------------

## 7. Panel architecture

### 7.1 Tab insertion

Enable the reserved slot in `03_page_builder.R:106–107`. No nav code changes — already wired. Gate by `element_portfolio = Y`.

### 7.2 Subtab layout (within Portfolio tab)

Four subtabs, reusing MA/funnel sub-nav CSS idiom:

1. **Footprint** — hero strip + heatmap (§4.1)
2. **Competitive Set** — constellation network (§4.2) + ranked co-awareness table
3. **Category Context** — clutter quadrant (§4.3) + per-category context table
4. **Extension** — portfolio strength map (§4.4) + permission-to-extend table (§4.5)

Each subtab has its own pin button and about drawer. Subtab state is pin-addressable (mirrors funnel's `fn-subtab` pattern in `03_funnel_panel.R:121–127`).

### 7.3 JS

New file: `lib/html_report/js/brand_portfolio_panel.js`. Responsibilities:
- Subtab switching
- Brand chip picker (strength map)
- Node-click handling on constellation → re-centre + pin
- Show-counts toggle
- TurasPin adapter hooks (`.br-pin-btn`, via `brand_pins.js`)

No charting libraries — SVG is emitted inline by the R builders.

------------------------------------------------------------------------

## 8. File inventory

### To create

| File | Purpose |
|---|---|
| `R/09_portfolio.R` | Orchestrator — `run_portfolio()` wrapping existing skeleton |
| `R/09a_portfolio_footprint.R` | §4.1 footprint matrix computation |
| `R/09b_portfolio_constellation.R` | §4.2 Jaccard + layout |
| `R/09c_portfolio_clutter.R` | §4.3 quadrant data |
| `R/09d_portfolio_strength.R` | §4.4 per-brand strength |
| `R/09e_portfolio_extension.R` | §4.5 lift + significance |
| `R/09f_portfolio_panel_data.R` | JSON payload builder |
| `R/09g_portfolio_output.R` | Excel + CSV writer |
| `lib/html_report/panels/09_portfolio_panel.R` | HTML panel assembler |
| `lib/html_report/panels/09_portfolio_panel_chart.R` | Chart wrappers |
| `lib/html_report/panels/09_portfolio_panel_table.R` | Table wrappers |
| `lib/html_report/panels/09_portfolio_panel_styling.R` | Panel-scoped CSS |
| `lib/html_report/js/brand_portfolio_panel.js` | Interactivity |
| `modules/brand/tests/testthat/test_portfolio_*.R` | Unit + integration tests |

### To modify

| File | Change |
|---|---|
| `R/00_main.R:849–945` | Replace `.compute_portfolio_data` body with a thin wrapper that calls `run_portfolio()`; preserve output key for backwards compat on downstream code |
| `R/00_guard.R` | Add portfolio-specific guards (cross_category_awareness = Y check) |
| `R/01_config.R` | Add the four new config keys (§3.3) with defaults + validation |
| `lib/html_report/99_html_report_main.R` | Source new panel files |
| `lib/html_report/04_chart_builder.R` | Add `build_network()`, `build_bubble_scatter()` — reuse heat_strip, scatter as-is |
| `R/99_output.R` | Wire portfolio Excel/CSV sheets into main output bundle |
| `docs/ROLE_REGISTRY.md` | Document awareness-set role usage, link to this spec |

### Net-new chart builders (§4 flagged them)

- `build_network()` — force-directed, inline SVG. Uses `igraph::layout_with_fr` if present, else a deterministic circular layout as fallback. Must run without igraph (graceful degradation).
- `build_bubble_scatter()` — wrapper over `build_scatter()` with variable-radius support.

------------------------------------------------------------------------

## 9. TRS refusals

New error codes:

| Code | Condition |
|---|---|
| `CFG_PORTFOLIO_AWARENESS_OFF` | `element_portfolio = Y` but `cross_category_awareness = N` |
| `CFG_PORTFOLIO_NO_CATEGORIES` | No categories with detectable `cat_code` |
| `DATA_PORTFOLIO_NO_AWARENESS_COLS` | Zero `BRANDAWARE_*` columns in data despite config |
| `DATA_PORTFOLIO_TIMEFRAME_MISSING` | `portfolio_timeframe = "3m"` but no `SQ2_*` columns (same for 13m/SQ1) |
| `CALC_CONSTELLATION_TOO_SPARSE` | Fewer than 3 brands with aware respondents |
| `CALC_EXTENSION_NO_FOCAL_AWARENESS` | Focal brand has zero aware respondents across all cats |

Each refusal follows existing TRS pattern (`status`, `code`, `message`, `how_to_fix`, `context`) and is routed through the console-visible error formatter from `CLAUDE.md`.

------------------------------------------------------------------------

## 10. Outputs

### 10.1 Excel (portfolio sheets added to main workbook)

| Sheet | Content |
|---|---|
| `Portfolio_Footprint` | Long-format: brand × cat × awareness % × n_buyers_w × n_aware_w |
| `Portfolio_Constellation` | Edges: b1, b2, jaccard, cooccur_n (sorted desc) |
| `Portfolio_Clutter` | One row per cat: cat, set_size_mean, focal_share, cat_pen, quadrant |
| `Portfolio_Strength` | Long: brand × cat × cat_pen × brand_aware_pct × n_aware_w |
| `Portfolio_Extension` | One row per cat: cat, n_buyers, focal_aware_pct, lift, p_value, p_adj |
| `Portfolio_Meta` | Config used, bases, suppressions, timestamp, wave, focal_brand |

Every row carries `ClientCode` + `QuestionText` where relevant (established Turas pattern).

### 10.2 CSV (long format)

One CSV per sheet above, same columns. Written to `{output_dir}/portfolio/` subdir.

------------------------------------------------------------------------

## 11. Acceptance criteria

The next coding session is done when **all** of these pass:

1. **Unit tests** cover each of `09a`–`09e` with synthetic fixtures; minimum 80% line coverage on new R files.
2. **Integration test** runs `run_brand()` end-to-end on the 9-cat example with `element_portfolio = Y` and produces a non-empty Portfolio tab.
3. **TRS tests** — each refusal code in §9 has a test that triggers it with a crafted input.
4. **Nesting / structural tests** — Footprint matrix cell `A(b, c)` ∈ [0,1], Jaccard ∈ [0,1], lift > 0.
5. **Rendering test** — HTML report loads in a browser (preview_start), Portfolio tab switches between all four subtabs, chip picker changes the strength map, clicking a constellation node re-centres and pins.
6. **TurasPin round-trip** — pinning a constellation view, exporting pins, re-importing, and reopening yields the same view (node centred, subtab active, chip selected).
7. **Low-base suppression** — forcing `portfolio_min_base = 99999` suppresses all cells with clear messaging; no crashes.
8. **Performance** — on a 5,000-respondent × 10-category × 12-brand fixture, `run_portfolio()` completes in ≤3s on a developer laptop.
9. **Excel + CSV outputs** — all six sheets present, row counts match in-memory structures.
10. **Graceful degradation without igraph** — `build_network()` falls back to deterministic circular layout with a one-line About note.

------------------------------------------------------------------------

## 12. Decisions (Duncan, 2026-04-21)

All five previously-open questions are now resolved. The coder implements these verbatim — no re-litigation.

### Q1. Timeframe default

**Decision:** default anchor = **`3m` (SQ2)**. Panel chrome exposes a single toggle `[3m | 13m]` that re-runs all portfolio analyses on the selected base. No side-by-side duplication — the toggle is the unified view-switcher.

- Config key: `portfolio_timeframe` default `"3m"` (already in §3.3).
- Pin state must persist the toggle so pinned views round-trip correctly.
- Rationale: 3m filters to the active-buyer universe, which is what portfolio strategy speaks to. 13m is a secondary lens for low-incidence categories, surfaced via toggle not default.

### Q2. Focal home category

**Decision:** **auto-detect** by default, with optional explicit override.

- Auto-detect rule: home category = the cat with the highest `A(focal, c)` among cats where focal is present. Ties broken by highest `cat_penetration`.
- New optional config key: `focal_home_category` (default blank). If set, it overrides auto-detect. Validation: must match a `cat_code` in the Categories sheet.
- Add `focal_home_category` to the config schema alongside the four keys in §3.3 (so it becomes **five** new config keys — update §3.3 table in the coder's mental model).
- Home cat is surfaced in the About drawer: "Home category: POS (auto-detected from highest focal awareness)" or "Home category: DSS (configured)".

### Q3. Permission-to-extend significance

**Decision:** **hybrid test** — two-prop z-test by default, auto-fallback to **Fisher's exact** when any 2×2 cell has expected count < 5 (standard small-sample rule). Benjamini–Hochberg FDR correction applied across categories regardless of which test produced each p-value.

- Test choice per row is recorded in the output (`test_used` column in `Portfolio_Extension`).
- About drawer documents the fallback rule.
- No config knob — rule is fixed.

### Q4. Constellation layout engine

**Decision:** **pure-R implementation, no igraph.** `igraph` is not in `renv.lock` and adding a heavyweight dependency for one chart fails the CLAUDE.md dependency-justification bar.

- Implement a deterministic Fruchterman–Reingold layout in pure base R, ~50–80 lines. Seed from `set.seed(42L)` inside the function so runs are reproducible.
- Soft-detect igraph: `if (requireNamespace("igraph", quietly = TRUE))` — if present, prefer `igraph::layout_with_fr` for layout quality; if absent, use the pure-R implementation. No user-visible difference in behaviour.
- About drawer notes which engine rendered: "Layout: igraph Fruchterman–Reingold" or "Layout: Turas pure-R Fruchterman–Reingold".
- Do **not** add `igraph` to `renv.lock`. It stays an optional enhancement.

### Q5. Node-click pin semantics

**Decision:** **re-centred view only for v1.** Clicking a constellation node re-centres the layout on that brand and pins the re-centred view. It does NOT filter the whole Portfolio panel to that brand.

- Cross-panel brand filtering is a richer interaction but materially expands Phase 4 scope. Explicitly deferred to v1.1.
- Add to §2 "Deferred to v1.1" list: *"Cross-panel brand filter via constellation node click — currently re-centres the constellation only."*
- Pin payload for constellation = `{ subtab: "constellation", centred_brand: "IPK" }`. Nothing more.

------------------------------------------------------------------------

## 13. References

- Existing skeleton: `modules/brand/R/00_main.R:849–945` (`.compute_portfolio_data`)
- Category code detection: `modules/brand/R/00_main.R:763–783`
- Brand resolution: `modules/brand/R/01_config.R:364–371`
- Panel pattern to mirror: `modules/brand/R/02a_ma_panel_data.R:46`, `modules/brand/lib/html_report/panels/02_ma_panel.R`
- Nav slot: `modules/brand/lib/html_report/03_page_builder.R:106–114`
- Chart builders: `modules/brand/lib/html_report/04_chart_builder.R` (heat_strip:272, scatter:150)
- TurasPin adapter: `modules/brand/lib/html_report/js/brand_pins.js`
- Funnel spec (style reference): `modules/brand/docs/FUNNEL_SPEC_v2.md`
- **Authoritative data fixture (1,200 respondents):** `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R:177–198`

------------------------------------------------------------------------

## 14. Instructions for the coding session

Read this whole section before writing a single line of code.

### 14.0 Preconditions (do these first, in order)

1. **Read this spec end to end.** Especially §3.1 (denominator rule), §4 (analyses), §8 (file inventory), §9 (TRS refusals), §11 (acceptance criteria). If anything is unclear, stop and ask Duncan before coding — do not guess.
2. **Read CLAUDE.md** at the repo root. TRS refusals (no `stop()`), console-visible error formatter, 80% test coverage minimum, styler formatting, roxygen2 on exports. These are non-negotiable.
3. **Verify the fixture exists and produces the shape the spec claims.** Source `modules/brand/tests/fixtures/generate_ipk_9cat_wave1.R` (or use the already-generated `.xlsx` it points to at `OUT_PATH`). Load the workbook, confirm: `nrow == 1200`, columns `SQ1_DSS..SQ1_ANT`, `SQ2_*`, and `BRANDAWARE_{cat}_{brand}` for all 9 cats × their brand lists exist. If any are missing, stop and flag.
4. **Create a branch from the current working branch** (`feature/brand-report-nav-2layer` as of this writing; confirm via `git status`). Branch name: `feature/brand-portfolio`. Do not merge to main until Duncan reviews.
5. **Do NOT use `examples/9cat/04_data.R`** for testing. It's the wrong design (400-respondent, focal-only awareness). Tests must use the 1,200-row fixture per §3.1.
6. **Read §12 — every question is now answered.** No guessing. Implement verbatim:
   - Q1: anchor = 3m, panel exposes `[3m | 13m]` toggle, pin state persists.
   - Q2: auto-detect home cat by max `A(focal, c)`, tie-break on cat penetration; optional `focal_home_category` config override.
   - Q3: two-prop z-test default, auto-fallback to Fisher's exact when any expected cell count < 5; BH correction always applied; `test_used` column in output.
   - Q4: pure-R Fruchterman–Reingold (seeded). Soft-detect igraph; use it if present, else pure-R. Do NOT add igraph to `renv.lock`.
   - Q5: node click re-centres constellation only. No cross-panel brand filter in v1.

### 14.1 Build order (phases with commit points)

Each phase ends with a commit. Do not merge phases into single commits — Duncan reviews phase-by-phase.

#### Phase 1 — Base helper + config scaffolding
**Goal:** the denominator and config plumbing that every analysis depends on.

- Create `R/09_portfolio.R` with stub `run_portfolio(data, categories, structure, config, weights)` that returns a TRS-shaped list with `status = "PASS"` and empty payloads.
- Create `build_portfolio_base(data, cat_code, timeframe, weights)` helper — returns `list(idx = logical vector of qualifiers, n_uw, n_w)`. **This is the single source of truth for the denominator rule in §3.1.** Every analysis calls it; no analysis recomputes the SQ1/SQ2 mask inline.
- Add the four config keys from §3.3 to `R/01_config.R` (defaults + validation).
- Add TRS refusals `CFG_PORTFOLIO_AWARENESS_OFF`, `CFG_PORTFOLIO_NO_CATEGORIES`, `DATA_PORTFOLIO_NO_AWARENESS_COLS`, `DATA_PORTFOLIO_TIMEFRAME_MISSING` to `R/00_guard.R` (per §9) — each with the CLAUDE.md console formatter.
- Tests: `test_portfolio_base.R` — verify base helper returns expected counts on the 1,200-row fixture for every cat × timeframe combination.

**Verify:** `testthat::test_dir("modules/brand/tests/testthat", filter = "portfolio_base")` passes. Commit: `feat(brand): portfolio scaffolding + base helper + TRS guards`.

#### Phase 2 — Analysis A (Footprint) + Analysis C (Clutter)
**Goal:** the two analyses that reuse existing chart builders. Prove the panel wiring end-to-end on the simpler cases first.

- `R/09a_portfolio_footprint.R` — `compute_footprint_matrix()` per §4.1. Output: matrix [brand × cat] of awareness %, plus parallel bases matrix. Denominators via `build_portfolio_base()`.
- `R/09c_portfolio_clutter.R` — `compute_clutter_data()` per §4.3. Output: data.frame with `cat, awareness_set_size_mean, focal_share_of_aware, cat_penetration, quadrant`.
- `R/09f_portfolio_panel_data.R` — skeleton of `build_portfolio_panel_data()` with only Footprint + Clutter subtabs populated. Mirror the shape of `R/02a_ma_panel_data.R:46`.
- `lib/html_report/panels/09_portfolio_panel.R` — HTML emitter, two subtabs active (Footprint, Category Context). Uses `build_heat_strip()` (`04_chart_builder.R:272`) and `build_scatter()` (`:150`) — **do not** create new chart builders in this phase.
- `lib/html_report/js/brand_portfolio_panel.js` — subtab switching only. No constellation JS yet.
- Enable the reserved Portfolio tab at `lib/html_report/03_page_builder.R:106–107` behind `element_portfolio = Y`.
- Tests: unit tests on both compute functions + an integration test that runs `run_brand()` on the 1,200-row fixture and asserts the Portfolio tab HTML contains both charts.

**Verify:**
1. `testthat::test_dir("modules/brand/tests/testthat", filter = "portfolio_(footprint|clutter)")` passes.
2. Open the generated HTML in `preview_start`, navigate to Portfolio, confirm heatmap renders and quadrant renders. **Do not ask Duncan to check — verify yourself via `preview_snapshot` + `preview_screenshot`.**

Commit: `feat(brand): portfolio footprint + clutter analyses`.

#### Phase 3 — Analysis D (Strength Map) + Analysis E (Permission)
**Goal:** the two focal-centric analyses that together form the "Extension" subtab.

- `R/09d_portfolio_strength.R` — `compute_strength_map()` per §4.4. Per-brand data structure. Default brand = focal.
- `R/09e_portfolio_extension.R` — `compute_extension_table()` per §4.5. Two-prop z-test with Benjamini–Hochberg adjustment (unless Duncan answered Q3 differently). Borrow z-test helper from `modules/tabs/` — do not reinvent.
- New chart builder: `build_bubble_scatter()` in `lib/html_report/04_chart_builder.R`. Thin wrapper over `build_scatter()` with variable-radius support. Add unit test.
- Extend `build_portfolio_panel_data()` + HTML emitter for the Extension subtab (strength map + permission table).
- Chip picker JS for brand selection on strength map — mirror MA panel's chip picker pattern.
- Tests: unit tests on both compute functions + TRS refusal tests for `CALC_EXTENSION_NO_FOCAL_AWARENESS`.

**Verify:** preview the HTML, click through brand chips on the strength map, confirm the bubble chart updates. Confirm the permission table renders with significance flags.

Commit: `feat(brand): portfolio strength map + permission-to-extend`.

#### Phase 4 — Analysis B (Constellation) — the hard one
**Goal:** the net-new network chart. Save for last because the graph layout is the riskiest piece.

- `R/09b_portfolio_constellation.R` — `compute_constellation()` per §4.2. Jaccard across brand pairs. Pre-compute layout in R.
- New chart builder: `build_network()` in `04_chart_builder.R`. **Must work without igraph.** If `requireNamespace("igraph", quietly = TRUE)`, use `igraph::layout_with_fr`; else fallback to deterministic circular layout with a one-line note in the About drawer. Add unit test for the fallback path (force the non-igraph branch).
- Extend `build_portfolio_panel_data()` + HTML emitter for the Competitive Set subtab.
- Node-click JS: re-centre the view (per Q5 default). Pin-addressable via existing `brand_pins.js` adapter.
- TRS refusal test for `CALC_CONSTELLATION_TOO_SPARSE`.

**Verify:** preview the constellation, click a non-focal node, confirm it re-centres. Pin the view, export pins, re-import, reopen — confirm round-trip (per §11 criterion 6).

Commit: `feat(brand): portfolio competitive constellation`.

#### Phase 5 — Outputs + supporting metrics + about drawer
**Goal:** ship-ready polish.

- Hero-strip KPI cards (§5) at the top of the Portfolio tab.
- `R/09g_portfolio_output.R` — Excel + CSV writers per §10. Six sheets, `ClientCode`/`QuestionText` on every row.
- Wire into `R/99_output.R`.
- About drawer copy for each subtab: formula, denominators, suppressions, limitations. Factual, no marketing language.
- Update `docs/ROLE_REGISTRY.md` with awareness-set role note linking back to this spec.

**Verify:** open the Excel, confirm all 6 sheets present with correct row counts (matches in-memory structures). Run a full `run_brand()` with `portfolio_min_base = 99999` and confirm graceful suppression.

Commit: `feat(brand): portfolio outputs + supporting metrics + docs`.

#### Phase 6 — Acceptance pass
Run every item in §11 explicitly. Do not skip any. Produce a short checklist report in the PR description mapping each criterion to the evidence (file path, test name, screenshot). Performance test (§11 criterion 8) on the 1,200-row fixture — report actual runtime.

Commit (if any fixes): `fix(brand): portfolio acceptance pass`.

PR title: `feat(brand): portfolio mapping element (v1)`. Link PR body to this spec.

### 14.2 Hard rules for the session

- **Denominator rule is inviolable.** Every rate uses `build_portfolio_base()`. No inline SQ1/SQ2 filtering anywhere else. A grep for `SQ1_` or `SQ2_` in new code should return only the helper.
- **Never use `stop()`.** TRS refusals only, with console formatter.
- **Never claim something works without verifying.** Duncan's standing rule: read the file, run the test, screenshot the preview. No "this should work" or "I believe this is correct" — only "I ran X and got Y".
- **Do not use `examples/9cat/04_data.R`** anywhere — not in tests, not in examples, not in docs. If you need a synthetic dataset for testing, the 1,200-row fixture is authoritative.
- **Do not touch** unrelated files. If you spot a bug outside the portfolio scope, flag it as a spawn-task but do not fix it in this PR.
- **Respect the file layout convention.** Module uses `R/` subdir with `lib/html_report/` for rendering. Follow suit.
- **Style + docs.** Every new exported function gets roxygen2. Every new file ends with `styler::style_file()` clean. Run `roxygen2::roxygenise()` before each commit.

### 14.3 Definition of done

All ten acceptance criteria in §11 pass, PR is up, PR description links to this spec, PR description contains the checklist from Phase 6. Duncan reviews.

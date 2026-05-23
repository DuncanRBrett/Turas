# Duplication of Awareness — Portfolio Module

Branch: `feature/portfolio-duplication-of-awareness`
Owner: Duncan
Status: planning complete, build in progress
Created: 2026-05-23

## 1. Problem Statement

The Portfolio module currently surfaces three views of cross-brand awareness:

- **Footprint** — a brand × category matrix of *univariate* awareness % (where is each brand known).
- **Competitive Set / Constellation** — a per-category co-awareness network using Jaccard similarity, with a closest-rivals side-list.
- **Category Context (Clutter)** — share-of-awareness and set-size scatter.

None of these answer the *pairwise, asymmetric, benchmarked* question of:
"Inside a single category, of the people aware of brand A, what percentage are
also aware of brand B — and is that more or less than Sharp's Duplication Law
would predict given each brand's awareness penetration?"

That is the awareness analogue of the Repertoire module's
**Duplication of Purchase** table, which is the standard Ehrenberg / Sharp
artefact for diagnosing competitive structure. Without it, Portfolio's
competitive context views are visually clear but lack the quantitative
benchmark that lets a reader say "X over-shares awareness with Y" or
"Z is a partition — its awares are less likely than expected to know
anyone else".

## 2. Landscape & Approach

**What exists:**
- `modules/brand/R/04_repertoire.R` lines 162–298 — the Duplication of Purchase
  implementation. Produces observed crossover matrix, Sharp's D coefficient
  via no-intercept OLS over off-diagonal cells, expected matrix (D × b_j),
  deviation matrix (obs − exp).
- `modules/brand/R/09b_portfolio_constellation.R` — already builds the
  per-category brand × respondent awareness matrix via
  `.portfolio_aware_matrix()`. Computes Jaccard for the constellation graph.

**Approach chosen:**
Mirror the Duplication of Purchase methodology exactly, substituting
*awareness penetration* a_j for *brand penetration* b_j. Reuse the existing
`.portfolio_aware_matrix()` helper so we are not recomputing awareness sets.

**Why not Jaccard:** Jaccard is symmetric — it loses the directionality that
makes Duplication of Purchase so diagnostic (Pr(B|A) ≠ Pr(A|B) when
penetrations differ). Sharp's law (D × penetration) is the published
benchmark; Jaccard has no equivalent.

## 3. Objectives

1. Add a per-category Duplication of Awareness table to the Portfolio
   Competitive Set sub-tab, with view toggle: **Observed / Expected /
   Deviation**.
2. The category picker (existing chips) drives both the constellation chart
   and the new matrix.
3. Methodology must mirror Duplication of Purchase exactly, so tracker
   comparisons across modules behave consistently.
4. Include a Sharp's D coefficient summary line per category.
5. Suppression: any category with fewer than the configured minimum effective
   base or fewer than 2 brands is flagged and skipped, matching the
   constellation's existing rules.
6. Engine is unit-tested with a hand-verifiable fixture (4 brands, ~10
   respondents) where D, observed, expected and deviation can all be
   recalculated on paper.

## 4. Requirements

**What it must do:**
- For each measured category C with ≥ 2 brands and an adequate base, produce:
  - `observed[i,j]` = weighted P(aware of j | aware of i) × 100
  - `D` = Σ(obs × a) / Σ(a²) over off-diagonal cells (i ≠ j)
  - `expected[i,j]` = D × a_j
  - `deviation[i,j]` = obs[i,j] − expected[i,j] in percentage points
  - Awareness penetration vector `a` (used for D, also surfaced in headers)
  - Base sizes (n aware per row)
- Surface in the HTML report under Competitive Set, below the constellation,
  with the same category chips driving it.
- Excel export of the matrix.
- Pin to Views + PNG export hooks (standard portfolio toolbar).

**Quality standards:**
- TRS refusals — no `stop()`.
- All errors visible to console + Shiny notification.
- Test coverage of every error condition.
- Engine file ≤ 300 active lines.
- Renderer file ≤ 300 active lines.
- Function size ≤ 50 active lines.

**Constraints:**
- Must reuse `.portfolio_aware_matrix()` — do not duplicate awareness column
  resolution.
- Must register in `modules/brand/R/00_main.R` `.source_brand_module`
  whitelist (silent-load gotcha per memory).
- Must not break the existing constellation panel.

## 5. Design

**Engine file**: `modules/brand/R/09b_portfolio_dop_awareness.R`

Public entry:

```r
compute_dop_awareness_per_cat(
  data, structure, role_map, weights = NULL,
  min_effective_base = 30
) -> list(
  status        = "PASS" | "PARTIAL" | "REFUSED",
  per_cat       = list(<cat_code> = list(
    cat_code, cat_label, brand_codes, brand_names,
    awareness_pcts, D, n_aware_per_brand,
    observed_matrix, expected_matrix, deviation_matrix
  )),
  suppressed    = data.frame(cat, reason),
  meta          = list(method = "Sharp / Ehrenberg D law on awareness")
)
```

**Panel data**: `09f_portfolio_panel_data.R` gets a new `dop_awareness` block
mirroring the per-cat shape, plus an `about` entry.

**HTML render**: new renderer at
`modules/brand/lib/html_report/panels/09_portfolio_dop_aware_table.R`,
invoked from `.pf_constellation_subtab()` *below* the existing constellation
chart. Dark-navy table style matching `.po_*` patterns. JS hooks
`pf-dopa-*` in `brand_portfolio_panel.js`:
- `pf-dopa-view` button group: `observed | expected | deviation`
- Re-renders matrix in place when view or category changes
- Shares the existing category-chip event so chips stay single-source-of-truth

**Reading guide** (paragraph under the matrix):

> Each cell shows what % of brand row's *awares* are also aware of brand
> column. The Observed view is what we saw. The Expected view is what
> Sharp's Duplication Law predicts based on each brand's awareness
> penetration. The Deviation view (observed − expected) is the diagnostic
> signal: positive cells = brands that over-share awareness (rivals);
> negative cells = brands whose awares are less likely than expected to know
> the partner (partition brands).

## 6. Growth Path

- Same engine can be applied to *Consideration* and *Preference* funnel
  stages — a duplication-of-X family.
- D values across waves become a tracker metric (single number per
  category per wave).
- Audience Lens cuts: D for high-frequency buyers vs low-frequency buyers
  reveals when the heavy-buyer competitive set is structurally different.

## 7. Risks

- **Small-base cells**: when n_aware_i is small, the observed row is noisy.
  Flag rows with n_aware_i < threshold visually (greyed cell text), do not
  drop.
- **Single-brand category**: skip with reason in `suppressed`.
- **All-aware brand**: a brand at 100% awareness will have D × a = D, and
  every other brand's awares trivially also know it. This is correct
  behaviour but worth a callout note.
- **Performance**: O(n_brands²) per category. n_brands ≤ ~15 in real
  configs; trivial.

## 8. Quality Checklist

- [ ] Engine returns TRS-shaped result, no stop().
- [ ] Hand-verifiable test fixture in `tests/fixtures/dop_aware/`.
- [ ] All public functions documented with roxygen.
- [ ] Whitelist updated in 00_main.R.
- [ ] File size < 300 active lines.
- [ ] No magic numbers — `min_effective_base` and base-flag threshold via
      config.
- [ ] All errors `cat()`-printed for Shiny console visibility.
- [ ] Browser-verified via `launch_turas()` IPK 9-cat run.
- [ ] Full brand test suite green.

## 9. Next Steps

1. Build engine (`09b_portfolio_dop_awareness.R`) + tests.
2. Wire into `run_portfolio()` and panel data.
3. Build HTML renderer + JS view-toggle.
4. Browser verify with IPK 9-cat.
5. Commit per pillar 8 (atomic commits).

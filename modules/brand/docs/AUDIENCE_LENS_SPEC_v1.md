# Audience Lens — Spec v1

**Status:** Shipped on `feature/brand-audience-lens`
**Module:** `modules/brand/`
**Source files:** `R/13_audience_lens.R`, `R/13a_al_audiences.R`,
  `R/13b_al_metrics.R`, `R/13c_al_classify.R`, `R/13d_al_panel_data.R`,
  `lib/html_report/panels/13_audience_lens_panel.R`,
  `lib/html_report/js/brand_audience_lens_panel.js`
**Planning doc:** `modules/brand/docs/PLANNING_AUDIENCE_LENS.md`

---

## What it does

Adds a per-category **Audience Lens** tab to the brand health report. The tab
answers the client question *"how does our focal brand perform among defined
sub-populations?"* without combinatorial blowup. Three internal sub-tabs:

1. **Banner table** — total + every audience, all 14 KPIs side-by-side.
2. **Per-audience cards** — deck-ready single-audience scorecards with delta vs
   total per metric.
3. **Pair scorecards** — buyer-vs-non-buyer (or any two-arm comparison)
   side-by-side with auto-classified GROW / FIX / DEFEND chips.

Each card has a per-card pin + PNG button (via the shared `TurasPins` library
and `brand_pins.js`).

---

## Configuration

Two pieces:

### 1. Survey_Structure.xlsx → AudienceLens sheet

| Column          | Required | Notes                                                                                         |
| --------------- | -------- | --------------------------------------------------------------------------------------------- |
| `Category`      | yes      | `ALL` (project-level shared audience) or a category code (e.g. `DSS`).                        |
| `AudienceID`    | yes      | Unique within the Category scope. Referenced from `Brand_Config!Categories!AudienceLens_Use`. |
| `AudienceLabel` | yes      | Display label shown in column headers and card titles.                                        |
| `PairID`        | no       | Two rows sharing the same PairID become a buyer-vs-non-buyer pair.                            |
| `PairRole`      | no       | `A` or `B`. Required when PairID is set.                                                      |
| `FilterColumn`  | yes      | Data column to test (must exist in the data file).                                            |
| `FilterOp`      | yes      | `==` `!=` `<` `>` `<=` `>=` `in` `not_in` `is_na` `not_na`                                    |
| `FilterValue`   | sometimes | Literal (or comma-separated for `in` / `not_in`). Blank for `is_na`/`not_na`.                 |

### 2. Brand_Config.xlsx → Categories sheet

Adds one column:

| Column             | Required | Notes |
| ------------------ | -------- | ----- |
| `AudienceLens_Use` | no       | Comma-separated `AudienceID` values from the AudienceLens sheet, or a `PairID` (pulls both members in), or `ALL_AVAILABLE` to use every audience scoped to this category. Blank = no Audience Lens tab for this category. |

### 3. Brand_Config.xlsx → Settings sheet (optional thresholds)

| Setting                       | Default | Notes                                                                                                                |
| ----------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| `element_audience_lens`       | `N`     | Master toggle. `N` skips the engine entirely. Must be set to `Y` explicitly to enable.                               |
| `audience_lens_max`           | `6`     | Ceiling on audiences per category (pairs count as one). Triggers `CFG_AUDIENCE_CEILING_EXCEEDED` if exceeded.        |
| `audience_lens_warn_base`     | `100`   | Below this unweighted base, the audience renders with a yellow `low base` badge.                                     |
| `audience_lens_suppress_base` | `50`    | Below this unweighted base, the audience is suppressed entirely (kept in the meta block but not rendered).           |
| `audience_lens_alpha`         | `0.10`  | Significance level for vs-Total / pair tests (default 90%).                                                          |
| `audience_lens_gap_threshold` | `0.10`  | Minimum buyer/non-buyer gap (proportion points) before a GROW or DEFEND chip can fire.                               |

---

## The 14 KPIs

| Group                | Metric                | Kind  | Notes                                       |
| -------------------- | --------------------- | ----- | ------------------------------------------- |
| Funnel & Equity      | Aided awareness       | %     |                                             |
|                      | Consideration         | %     | Attitude codes 1 (love) or 2 (prefer).      |
|                      | P3M usage             | %     |                                             |
|                      | Brand love            | %     | Attitude code 1 only.                       |
|                      | Branded reach         | %     | Romaniuk: correct attribution / eligible.   |
| Mental Availability  | MPen                  | %     | % of subset who linked focal to ≥1 CEP.     |
|                      | Network size          | num   | Mean # focal-CEP links per respondent.      |
|                      | MMS                   | ratio | Focal links / total brand-CEP links.        |
|                      | SoM                   | ratio | Focal-link density across all CEPs.         |
| Word of Mouth        | Net heard             | net   | Net positive minus net negative recall.     |
|                      | Net said              | net   | Net positive minus net negative shared.     |
| Loyalty & Behaviour  | Loyalty (SCR)         | %     | Brand-buyer base — N/A on non-buyer side.   |
|                      | Purchase distribution | dist  | Headline = % heavy buyers (top tercile).    |
|                      | Purchase frequency    | num   | Mean times bought per period.               |

The catalogue is exposed as `audience_lens_metric_catalog()` for tests and
extensions.

---

## GROW / FIX / DEFEND classification

Applied only to **pair rows** (single-audience cards don't get chips). Order of
precedence in the classifier:

1. **DEFEND** — buyers ≫ non-buyers (gap ≥ threshold, sig) AND buyers > total.
   Strong position; protect against competitive erosion.
2. **GROW** — buyers ≫ non-buyers (gap ≥ threshold, sig) but does NOT lead
   total. Recruitment lever — close the mental gap among non-buyers.
3. **FIX** — buyers strictly underperform total (no significant pair gap).
   Retention/satisfaction risk.
4. **(no chip)** — neither condition fires.

When a metric is N/A on the non-buyer side (loyalty / distribution /
frequency), the pair row never gets a chip.

---

## Methodological notes

### Pair Z-test framing (head off pushback)

Every respondent is independently classified as either a focal-brand buyer
(PairRole A) or a non-buyer (PairRole B). The two arms are mutually exclusive
and exhaustive, but no within-pair pairing exists at the respondent level —
there is no respondent who is *both*. The test is therefore a
**two-INDEPENDENT-proportions z-test**, not a paired-sample test. This is the
standard framing for buyer/non-buyer comparisons in Romaniuk's work.

The classifier wraps `.al_sig_two_props()` which:
- Uses the standard pooled-variance two-proportion z when expected counts ≥5.
- Falls back to Fisher's exact when expected counts <5.
- For non-proportion metrics (means, nets, ratios), uses a coarse
  difference-of-means z. This is intentionally conservative for v1 — small
  samples won't trip the sig flag for mean-based metrics.

### Mental Availability metrics

The lens follows Romaniuk's canonical four (MPen, NS, MMS, SoM) and refuses
to invent a composite. Per Romaniuk's guidance ("MPen is most interesting for
non-buyers"), the per-audience card uses MPen as the single MA representative
on the headline scorecard, while the banner table shows all four.

### Brand-buyer-base metrics

Loyalty (SCR), purchase distribution, and purchase frequency are defined on
focal-brand buyers only. The non-buyer side of any pair audience renders an
N/A cell (greyed) with a † footnote, never a blank or zero.

---

## Base-size discipline

| Base                                | Treatment                                                |
| ----------------------------------- | -------------------------------------------------------- |
| n ≥ `warn_base` (default 100)       | Show normally.                                           |
| `suppress_base` ≤ n < `warn_base`   | Show with visible `low base` badge under column header.  |
| n < `suppress_base` (default 50)    | Audience suppressed entirely; appears in meta only.      |
| Buyer-base metric on non-buyer side | N/A cell with † footnote: "Defined on brand buyers only" |

When ALL declared audiences fall below the suppression threshold, the engine
returns `status = "PARTIAL"` with code `DATA_ALL_AUDIENCES_SUPPRESSED` and the
panel renders a single message instead of the cards.

---

## TRS error codes

| Code                                  | When                                                                  |
| ------------------------------------- | --------------------------------------------------------------------- |
| `DATA_MISSING`                        | Empty data frame passed to `run_audience_lens()`.                     |
| `CFG_FOCAL_BRAND_MISSING`             | `focal_brand` not set in Brand_Config.                                |
| `CFG_AUDIENCE_LENS_SHEET_MISSING`     | Categories!AudienceLens_Use is set but the AudienceLens sheet is absent. |
| `CFG_AUDIENCE_CEILING_EXCEEDED`       | More than `audience_lens_max` audiences declared for a category.      |
| `CFG_AUDIENCE_FILTER_OP_INVALID`      | Unknown FilterOp.                                                     |
| `CFG_AUDIENCE_FILTER_VALUE_MISSING`   | Op needs a value but FilterValue is blank.                            |
| `CFG_AUDIENCE_PAIR_INCOMPLETE`        | A PairID has ≠2 member rows.                                          |
| `CFG_AUDIENCE_PAIR_ROLE_INVALID`      | Pair members do not have PairRole A and B.                            |
| `DATA_AUDIENCE_FILTER_COL_MISSING`    | FilterColumn not in the data file.                                    |
| `DATA_ALL_AUDIENCES_SUPPRESSED`       | Every declared audience falls below `suppress_base`.                  |
| `CALC_AUDIENCE_LENS_ERROR`            | Engine crashed while computing metrics; surfaced as a warning.        |

All refusals print a Shiny-visible boxed message to console.

---

## Implementation notes

- **Whitelist loader gotcha** — every new R file in `modules/brand/R/` must
  be added to `.source_brand_module()` at `00_main.R:54-87`. The five new
  files (13, 13a–13d) are registered there. Adding more without updating
  the list = silent load failure.
- **TurasPins inliner gotcha** — all layout-critical CSS uses `!important`
  and avoids `.al-panel`-ancestor selectors so the inliner can faithfully
  reproduce cards in pinned + PNG output. Card-level `data-pin-as-table`
  attribute tells `brand_pins.js` to capture the inner table directly.
- **Verification path** — `launch_turas()` → GUI → pick the 9cat config →
  inspect the generated HTML and PNGs. Brand reports are NOT
  preview-served; do not run `preview_start`.

---

## v2 roadmap

The `schema_version: 1` field on the panel JSON payload reserves room for
the v2 additions:

- Comparator brand alongside focal (~1 week post-v1).
- Wave-on-wave trend per audience.
- Custom audience expressions (analyst-defined filters with TRS-validated parser).
- Category-behavioural audiences (heavy / medium / light category buyers).
- Analyst-overrideable insight text.
- Audience-level Excel export.

v3 (pull-driven only): cross-category lens, audience portfolios, AI-generated
insights, predictive audience suggestion.

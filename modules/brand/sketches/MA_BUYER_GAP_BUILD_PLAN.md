# Build plan — MA Focal-Brand View (replaces standalone Drivers & Barriers page)

**Branch:** `feat/brand-exec-summary` (continue) — split to `feat/brand-ma-focal-view` if it gets larger than ~6 commits.
**Author:** session 2026-05-03
**Companion:** `ma_buyer_gap_mockup.html` (this folder).

---

## 1. Decision

The originally-planned **Drivers & Barriers** HTML page is **dropped**. In its place:

- A **Focal Brand View** lives inside the existing **Mental Advantage** sub-tab of the MA panel.
- It pairs **MA score** (market-relative, existing) with **Buyer gap** (% buyers minus % non-buyers, new column) per stimulus, plus a derived **Read** label.
- Same view works for **CEP** and **Brand Attribute** stimulus sets via a stimulus toggle (already present in the MA Advantage sub-tab).
- The existing D&B engine (`R/06_drivers_barriers.R`) is **kept** — it still feeds Excel sheets (`*_Importance`, `*_IxP`, `*_CompAdv`, `*_Rejection`) and CSV outputs. The "page" we're not building is purely the HTML panel that hadn't been started.

### Why
- Buyer-gap is the methodological core of what clients call "drivers & barriers". The existing D&B engine's `calculate_differential_importance()` already computes it.
- A separate page would duplicate the CEP/attribute matrix already on screen and force users to flip back-and-forth between MA and D&B for the same brand.
- Co-locating MA + buyer-gap exposes the joint reading that gives the analysis its value (real strength vs fame gap vs buyer edge vs delivery problem).
- Avoids a buyer/non-buyer cut on every other brand page (per the brand non-duplication principle).

---

## 2. Engine — reuse, don't rebuild

The math we need already exists at [06_drivers_barriers.R:43](../R/06_drivers_barriers.R) (`calculate_differential_importance`).

**New (small) wrapper:** `R/02c_ma_focal_view.R`

Returns a per-stimulus data frame with everything the panel needs in one shape:

```
calculate_ma_focal_view(linkage_tensor, codes, focal_brand, pen, weights = NULL,
                        ma_advantage = NULL, ma_significant = NULL,
                        ma_threshold_pp = 5, gap_threshold_pp = 5,
                        min_base = 30) -> data.frame
```

Columns returned:
- `Code`, `Label` (label is filled by panel-data layer; engine returns Code only)
- `MA_Score` (pp, copied from `ma_advantage` when supplied)
- `MA_Significant` (logical, copied)
- `Buyer_Pct`, `NonBuyer_Pct`, `Buyer_Gap` (pp; from `calculate_differential_importance`)
- `Gap_Z`, `Gap_Significant` (two-proportion z, |z| > 1.96)
- `N_Buyer`, `N_NonBuyer` (unweighted; weighted base in a sibling pair if weights supplied)
- `Below_Min_Base` (logical — TRUE when either base < `min_base`)
- `Read_Label` (one of `STRENGTH`, `FAME_GAP`, `BUYER_EDGE`, `FLAT`, `WEAK`, `FIX_OR_DROP`)

**Read-label classifier** — pure function in same file, easy to unit-test. **Locked at four labels** plus suppression states:

| MA score             | Buyer gap                   | Label         |
|----------------------|-----------------------------|---------------|
| ≥ +ma_thr            | ≥ +gap_thr                  | STRENGTH      |
| ≥ +ma_thr            | < +gap_thr (incl. negative) | FAME_GAP      |
| within ±ma_thr       | ≥ +gap_thr                  | BUYER_EDGE    |
| ≤ −ma_thr            | any                         | WEAK          |
| within ±ma_thr       | within ±gap_thr             | (no chip — empty cell) |
| any                  | base < min_base             | INSUFFICIENT (suppressed) |

Rationale for collapsing: FLAT carries no action read so we just leave the chip blank; FIX_OR_DROP is identical action to WEAK so they merge. Four labels = four chip colours.

---

## 3. Panel data — append `focal_view` block to advantage payload

File: `R/02b_ma_advantage_data.R`.

Where the per-stimulus block is currently built, attach a parallel `focal_view` list:

```
adv$focal_view$ceps        <- list(
  base_buy = N, base_nonbuy = N, base_buy_w = wN, base_nonbuy_w = wN,
  rows = data.frame(...)   # one row per CEP, columns above + Label
)
adv$focal_view$attributes  <- list( ... )
```

Inputs needed:
- The existing CEP and attribute linkage tensors (already in `ma_result`).
- The focal brand's penetration vector — needs to be plumbed in via `build_ma_panel_data(...)`. The cleanest route is a new optional argument `focal_pen` (numeric 0/1, length n_resp).
- Source: `00_main.R` already calls `multi_mention_brand_matrix(data, pen_entry$column_root, focal_brand)` for D&B at L389 — same call site computes it once and passes it to both D&B and `build_ma_panel_data`.

---

## 4. HTML — `02_ma_panel_advantage.R`

Insert a new view block under the existing Mental Advantage views layout:

```
[ controls bar | chip row ]
[ matrix | strategic quadrant | actions ]   ← existing
[ FOCAL BRAND VIEW table ]                   ← NEW
[ insight box | about | intro callout ]
```

Default state: hidden until a focal brand is selected (always true in current Brand reports → effectively always shown). The stimulus toggle (CEP / Attribute) re-fetches the matching `focal_view` block.

Table columns (per the mockup):
1. Stimulus label
2. MA score (pp, with `*` when significant)
3. Buyer gap (pp, with `*` when significant)
4. Read label (chip)

Sort: by MA score desc by default; clicking a column header re-sorts. Min-base cells render as grey "—" with a footer note.

---

## 5. Styling — `02_ma_panel_advantage_styling.R`

Two cell colour ramps:
- `.ma-fv-ma-pos-{1,2,3}` / `.ma-fv-ma-neg-{1,2,3}` — green/red, mirrors current MA matrix (consistency).
- `.ma-fv-gap-pos-{1,2,3}` / `.ma-fv-gap-neg-{1,2,3}` — **blue/red** to break visual confusion with the MA column.

Read-label chips: pill background colour by label class. Chip palette to be picked from existing brand callout palette so we're not introducing new hues.

---

## 6. JS — `brand_ma_advantage.js`

- New renderer `renderFocalView(payload, stim)` reading `panel.advantage.focal_view[stim].rows`.
- Hook to existing stimulus toggle so flipping CEP↔Attribute also re-renders the focal-view table.
- Pin/PNG: v1 leaves capture to the **existing** advantage-section PNG button + Pin dropdown (the focal view is a child of `.ma-advantage-section`, so it's captured as part of the whole sub-tab). Dedicated per-stim pin buttons can be added in v2 if clients ask for the focal table standalone — defer until requested.

---

## 7. Significance & base-size guards

- Significance: two-proportion z, `z = (p_buy - p_nonbuy) / sqrt( p_pool*(1-p_pool) * (1/n_buy + 1/n_nonbuy) )`. Use **unweighted** Ns for the test; weighted percentages in display.
- Min base: `min_base = 30` per side. Below that, `Buyer_Pct`/`NonBuyer_Pct`/`Buyer_Gap`/`Gap_Significant` are NA and the row's gap cell renders as "—" with a tooltip explaining the suppression.
- Footer caveat: "Buyer gap = % of {focal} P3M buyers (n = X) linking the stimulus, minus % of non-buyers (n = Y). Significance: 95% two-proportion z. Cells suppressed below n=30."

---

## 8. Callout text

Update `brand.drivers_barriers` (or rename to `brand.ma_focal_view`) in `modules/shared/lib/callouts/callouts.json`:

> The Focal Brand View pairs each stimulus's market-relative Mental Advantage with the buyer-gap (the difference between {focal}'s buyers and non-buyers in associating the stimulus). High-MA + high-gap = buyer-validated competitive strength. High-MA + flat gap = a fame the brand isn't living up to (delivery gap). Flat MA + high gap = an attribute buyers know about that the broader market doesn't yet — an awareness opportunity. Negative on both = drop from comms or rebuild.

Existing `brand.drivers_barriers` callout (if currently used for the Excel D&B sheets, low risk) can stay; the new one targets the focal view.

---

## 9. Tests

### New: `tests/testthat/test_ma_focal_view.R`
- Engine output shape (column names, types).
- Buyer gap math against hand-calculated 2×2 table on the IPK fixture.
- Two-proportion z math against `prop.test()`.
- Min-base suppression: under-base rows have NA gap and `Below_Min_Base = TRUE`.
- Read-label classifier truth table (one row per cell of the table in §2).

### Extend: `tests/testthat/test_ma_advantage_data.R` (new) or add to existing MA panel data tests
- `build_ma_panel_data` returns `advantage$focal_view$ceps` and `advantage$focal_view$attributes`.
- When `focal_pen` is NULL, `focal_view = NULL` (graceful fallback).

### Existing: keep `test_drivers_barriers.R` running unchanged
- The engine functions reused there are untouched.

### Smoke
- Run full brand test suite. Target: zero new failures.

---

## 10. Wire-up

Source order in `00_main.R`:

```
.source_brand_module("02_mental_availability.R")
.source_brand_module("02b_mental_advantage.R")
.source_brand_module("02c_ma_focal_view.R")        # NEW — register here
.source_brand_module("02a_ma_panel_data.R")
.source_brand_module("02b_ma_advantage_data.R")
```

Add `02c_ma_focal_view.R` to the loader whitelist (the brand loader is whitelist-based — files not listed silently never load).

In the per-category orchestration block where `build_ma_panel_data()` is called, compute `focal_pen` once via `multi_mention_brand_matrix(data, pen_root, focal_brand)` and pass it through.

---

## 11. Things explicitly **not** changing

- `06_drivers_barriers.R` — left in place; engine still runs; Excel + CSV outputs unchanged.
- `element_drivers_barriers` config flag — left in place; semantics now "produce D&B Excel/CSV outputs", which is what it already does.
- The MA matrix view itself — IPK column values remain identical; the focal view is **additive**, not replacing the matrix.
- Any other brand page — no buyer/non-buyer cuts added elsewhere. Anyone wanting that runs tabs.

---

## 12. Page-polish queue impact

Drivers & Barriers comes off the page-polish queue. New ordered queue:

1. ~~Drivers & Barriers~~ (replaced by this build)
2. Branded Reach
3. Demographics
4. Audience Lens
5. Ad Hoc
6. DBA

---

## 13. Definition of done

- [ ] Engine wrapper + classifier + tests landed.
- [ ] Panel data carries `focal_view` for both stimulus sets.
- [ ] HTML/CSS/JS render the focal-view table on the MA Advantage sub-tab.
- [ ] Stimulus toggle (CEP↔Attribute) swaps the focal-view rows.
- [ ] Pin/PNG round-trip works for the focal-view section.
- [ ] Min-base suppression visible in fixture (force a tiny brand to verify).
- [ ] Brand test suite green (no new failures vs `feat/brand-exec-summary` baseline).
- [ ] Verified in `launch_turas()` against IPK Wave 1 fixture by Duncan.
- [ ] README updated — D&B noted as Excel/CSV-only deliverable; HTML lives on MA panel.
- [ ] Memory updated: project_brand_page_polish_handover.md picks up Branded Reach as next.

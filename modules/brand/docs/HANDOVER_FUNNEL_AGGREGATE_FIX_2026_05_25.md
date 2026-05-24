# Handover — Brand Funnel: aggregate engine + cumulative-chain toggles

**Branch:** `feature/brand-section-insights`
**Tip:** `65f49fb5 fix(brand/funnel): '% of previous' toggle now walks cumulative chain too`
**Date:** 2026-05-25
**Status:** Engine correct. JS partially wired. UI still shows wrong values for "% of aware" because at least two JS code paths bypass the engine-supplied conditional rate. Category-average row is also wrong (computes its own aggregate ratio rather than averaging the per-brand cumulative-chain rates).

Duncan caught two prior errors in this session and explicitly asked for a fresh-session handover. **Do not trust prior session reasoning — re-verify everything against code + data before claiming anything.**

---

## The spec (from the panel explainer + Duncan's clarifications)

The Brand Funnel ships its own explainer text in the panel — that text is the source of truth. Re-read it before changing anything (it lives in `modules/brand/lib/html_report/panels/03_funnel_panel_*.R` / the funnel-panel JS).

Three base toggles, three measures:

| Toggle | What it means | Engine field |
|---|---|---|
| **% of total** | Raw count at this stage / total focal-cat sample. Each stage independent — no chaining. The "aggregate counts" view the explainer describes. | `cell.pct_absolute` |
| **% of previous** | Cumulative-chain count at this stage / cumulative-chain count at the immediately previous stage. | `cell.pct_nested` |
| **% of aware** | Cumulative-chain count at this stage / cumulative-chain count at the aware stage. | `cell.pct_aware` |

"Cumulative chain" = walk through the per-respondent stage matrices, ANDing each new stage into the running cumulative matrix:

```
cum[1] = stage[1] matrix (aware)
cum[k] = cum[k-1] AND stage[k] matrix
```

Both filtered toggles describe the funnel as a respondent journey and live in [0, 1] by construction. The headline `pct_absolute` stays raw aggregate.

This combines the explainer's "aggregate counts" view (% total) with a respondent-journey view (% previous / % aware) that always nests properly.

---

## What's working — the engine

`modules/brand/R/03b_funnel_metrics.R::calculate_stage_metrics`

The engine now produces three columns per (stage, brand):

- `pct_weighted` (raw aggregate — % of total sample)
- `pct_nested_filtered` (cumulative-chain ratio vs immediately previous stage)
- `pct_aware_filtered` (cumulative-chain ratio vs aware)

Plus `base_aware_filtered` (aware count, the denominator for `pct_aware_filtered`).

Verified on IPK Wave 1 — `Rscript -e 'source("modules/brand/R/00_main.R"); res <- run_brand("/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/8844718_Brand_Config.xlsx", verbose=FALSE)'`:

```
IPK Pour Over Sauces:
                  pct_total   pct_prev   pct_aware
  aware              50%       100%       100%
  consideration      67%        85%        85%
  bought_long        44%        70%        60%
  bought_target      36%        84%        51%
```

These are the correct values per spec. The JSON payload embedded in the report also has them — confirmed by extracting the `fn-panel-data` script block.

The panel-data builder (`modules/brand/R/03c_funnel_panel_data.R`) reads these into each `cell` object as `pct_absolute`, `pct_nested`, `pct_aware`. Verified by inspecting the rendered JSON.

---

## What's broken — the JS

`modules/brand/lib/html_report/js/brand_funnel_panel.js`

There are **multiple** functions in this file that compute the "value for the active mode". I only updated one (`cellValueForMode` ~line 28840). The others still use the OLD pattern:

```js
if (mode === "aware") {
  if (stageIdx === 0) return 1.0;
  var ap = brandAwarePct[brandCode] || avgAwarePct;
  if (ap && ap > 0 && obj.pct_absolute != null) return obj.pct_absolute / ap;  // <— BROKEN
  return obj.pct_absolute;
}
```

Grepping the source file:

```
modules/brand/lib/html_report/js/brand_funnel_panel.js:1004:
  if (ap && ap > 0 && obj.pct_absolute != null) return obj.pct_absolute / ap;
modules/brand/lib/html_report/js/brand_funnel_panel.js:1641:
  if (ap && ap > 0 && obj.pct_absolute != null) return obj.pct_absolute / ap;
```

Line 1004 is inside `pickMiniPct` — the **mini-funnel cards** renderer.
Line 1641 is inside `pickPct` — the **main table** renderer.

Both need the same treatment as `cellValueForMode`:

```js
if (mode === "aware") {
  if (obj.pct_aware != null) return obj.pct_aware;
  // legacy fallback
  if (stageIdx === 0) return 1.0;
  return null;
}
```

Same for the `previous` branch: `obj.pct_nested` now carries the cumulative-chain value (engine field renamed semantics), but verify each `pickPct` / `pickMiniPct` reads it as-is rather than re-computing from `pct_absolute`.

---

## What's almost certainly broken too — category-average row

The `Category average` row in the screenshot reads **68%** for past-3-months in % of aware view. That's not the average of the per-brand cumulative-chain values; it's the aggregate `sum(past3m counts) / sum(aware counts)` across brands. Under the user's spec it should be the mean of `pct_aware_filtered` across brands (or weighted, depending on the convention the rest of the table uses).

The avg row is built in `03b_funnel_metrics.R::.avg_all_brands_row` (or similar) and emitted into `panel_data$table$avg_all_brands`. The JS reads it via `avgMap`. Verify the avg row also carries `pct_aware_filtered` / `pct_nested_filtered`, then make sure the JS picks those instead of recomputing.

Search for `avgAwarePct` and `avgMap` in `brand_funnel_panel.js` to find every site.

---

## Also wrong — the count display

Screenshot shows past-3-months IPK as **n=107 (150)** in % of aware mode. The 107 is the raw past-3m count and 150 is the aware count. Under the cumulative-chain interpretation the count should be **n=76 (150)** — the count of respondents who were aware AND positive AND bought-12m AND bought-3m.

The display code lives near `cellCountStr` at ~line 1656 in the funnel JS. It reads `c.base_unweighted` which is the raw stage base. The engine also produces `base_aware_filtered` (the aware count) — but you may want a third field, `base_cumulative_filtered` per (stage, brand), so the displayed count reflects the cumulative-chain numerator in the filtered views.

If you add that field in the engine, the cell payload + JS need wiring. Suggested name: `cum_count_chain` or `pct_aware_count`.

---

## IPK Wave 1 — expected values (for verification)

These are the hand-calculated ground truth from the raw data. The engine produces these. The JS does **not** display these on the % aware toggle right now.

### Cumulative chain (per brand, per category)

For each category and each brand, the cumulative count at stage k =
count of respondents where:
- (stage 1: aware) AND
- (stage 2: positive attitude — top-2 of the 6-level scale) AND
- (stage 3: BRANDPEN1 — past 12 months) AND
- (stage 4: BRANDPEN2 — past 3 months)

For IPK, with focal-cat sample sizes:

| Category | n | Aware | + Positive | + Past 12m | + Past 3m |
|---|---:|---:|---:|---:|---:|
| Pour-Over Sauces | 300 | 150 | 128 | 90 | 76 |
| Pasta Sauces | 300 | 120 | (verify) | (verify) | (verify) |
| Dry Seasonings | 350 | 144 | (verify — uses different attitude column convention) | (verify) | (verify) |
| Baking Mixes | 250 | 80 | (verify) | (verify) | (verify) |

(Verify the other categories with the same script pattern below.)

### Expected display values

For IPK Pour-Over Sauces, the three views should show:

| Stage | % total | % previous | % aware |
|---|---:|---:|---:|
| Aware | 50% (150) | 100% (150) | 100% (150) |
| Prefer | 67% (202) | 85% (128/150) | 85% (128/150) |
| Past 12 months | 44% (131) | 70% (90/128) | 60% (90/150) |
| Past 3 months | 36% (107) | 84% (76/90) | 51% (76/150) |

The screenshot at the time of handover shows:
- % total: correct (50% / 67% / 44% / 36%) ✓
- % previous: correct (100% / 85% / 70% / 84%) ✓
- **% aware: WRONG (100% / 135% / 87% / 71%)** — should be 100% / 85% / 60% / 51%

The 135% / 87% / 71% values are the OLD `pct_absolute / brand_aware_pct` aggregate-ratio computation that survives in `pickPct` (line 1641) and `pickMiniPct` (line 1004).

---

## Verification commands

After making the JS fix:

### 1. Brand suite

```bash
cd /Users/duncan/Dev/Turas
Rscript -e 'Sys.setenv(TESTTHAT="true"); res <- testthat::test_dir("modules/brand/tests/testthat", reporter = "minimal", stop_on_failure = FALSE); df <- as.data.frame(res); cat(sprintf("\n--TOTAL: pass=%d fail=%d skip=%d--\n", sum(df$passed), sum(df$failed), sum(df$skipped)))'
```

Should be 2153 / 0 (or thereabouts) after the JS fix.

### 2. Engine values for IPK

```r
source("modules/brand/R/00_main.R")
res <- run_brand("/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/8844718_Brand_Config.xlsx", verbose = FALSE)
for (cn in c("Pour Over Sauces","Pasta sauces","Dry Seasoning and Spices","Baking Mixes")) {
  cr <- res$results$categories[[cn]]
  ipk <- cr$funnel$stages[cr$funnel$stages$brand_code == "IPK",
                          c("stage_key","pct_weighted","pct_nested_filtered","pct_aware_filtered")]
  cat(sprintf("\n=== IPK %s ===\n", cn))
  print(ipk, row.names = FALSE)
}
```

POS should show the table above.

### 3. JSON payload in rendered HTML

```python
import re, json
with open("/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/output/brand/8844718_Brand_Config_report.html") as f:
    html = f.read()
idx = html.find('id="fn-pos"')
m = re.search(r'<script[^>]*class="fn-panel-data"[^>]*>(.*?)</script>', html[idx:idx+200000], re.DOTALL)
payload = json.loads(m.group(1))
ipk_cells = [c for c in payload['table']['cells'] if c['brand_code'] == 'IPK']
for c in ipk_cells:
    print(f"  {c['stage_key']:15s} pct_abs={c['pct_absolute']:.4f} pct_nested={c['pct_nested']} pct_aware={c['pct_aware']}")
```

Cells already carry the correct values. Confirms it's a JS-render bug, not an engine bug.

### 4. Browser verification — Duncan only

After the JS fix is committed and `run_brand()` regenerates the report, Duncan opens `launch_turas()` in his Shiny app and switches the funnel base toggles for IPK Pour-Over Sauces. Confirms the three views show:

- % total: 50 / 67 / 44 / 36
- % previous: 100 / 85 / 70 / 84
- % aware: 100 / 85 / 60 / 51

If category-average is fixed too, the avg row should also be sensible (each toggle's avg row sums of cumulative-chain values across all brands).

---

## What's been done already (commits on `feature/brand-section-insights`)

```
65f49fb5 fix(brand/funnel): '% of previous' toggle now walks cumulative chain too
a7e096b4 fix(brand/funnel): '% of aware' base now filters to aware respondents
8ff804ab Merge fix/funnel-aggregate-stages — aggregate funnel matches explainer
c09949fa fix(brand): Portfolio overview 'bought' now matches Funnel exactly
0c819fc8 feat(brand): consolidate to one pin per sub-tab (Section_Insights v1.2)
548e2568 fix(brand): width:100%% CSS bug in v1.1 toolbar styles + regression test
06a7d00b feat(brand): per-sub-tab insights, wider editor, polish (Section_Insights v1.1)
2e182166 feat(brand): Section_Insights — analyst insights that survive report re-runs
```

The funnel rewrite landed in `8ff804ab` (cumulative-AND removed from engine). `a7e096b4` added `pct_aware_filtered` to the engine + fixed `cellValueForMode`. `65f49fb5` added `pct_nested_filtered` similarly.

**The unfinished work is purely on the JS rendering side.** Engine is correct.

The Section_Insights work (anchored insights from the config workbook) is also on this branch but unrelated — don't touch unless you're sure.

---

## What the prior session got wrong (so you don't repeat it)

1. **Claimed the funnel was a "strict nested funnel by design"** — that contradicted the explainer the report ships with. Code did the AND but the explainer says aggregate. Should have read explainer first.
2. **Invented a "reconciliation case B" explanation** for the Portfolio vs Funnel bought discrepancy. Was wrong — there were zero case_b rows in the data. Duncan caught it.
3. **Pattern-matched four numbers** to claim the engine was doing nested intersection. The math coincidence was real but the engine code was the only source of truth. Should have read code, not data.
4. **Fixed only one of three JS code paths** for the aware toggle (the current bug being handed over). Should have grepped for every site computing the active-mode value.

Duncan's principle, repeated several times in the session: **report data as recorded. Do not force a nest that does not exist.** That's what the engine does now; the JS just needs to render it.

---

## Suggested order of work for the fresh session

1. Read the funnel panel's own explainer text (in the panel R / JS) so you know what the funnel claims to be.
2. Run the verification commands above to confirm the engine state.
3. Grep `brand_funnel_panel.js` for every site that touches the active-mode value (search: `pct_absolute / ap`, `pickPct`, `pickMiniPct`, `cellValueForMode`, `avgAwarePct`, `mode === "aware"`, `pctMode === "aware"`).
4. Update each site to read `cell.pct_aware` / `cell.pct_nested` directly. Leave a legacy fallback that pins stage-1 to 1.0 if those fields are missing.
5. Investigate the category-average row separately — it has its own computation path in `.avg_all_brands_row` (R) + `avgMap` (JS). Likely also needs cumulative-chain treatment.
6. Investigate the count display string in `cellCountStr` — the cumulative-chain numerator (e.g. 76 for IPK POS past-3m on % aware) should probably be what's shown, not the raw stage base (107). Decide with Duncan whether the displayed n changes per toggle.
7. Regenerate the IPK report via `run_brand()` and verify the three views via the JSON payload trick.
8. Hand to Duncan for `launch_turas()` browser verification.
9. Commit. Keep commit message factual; describe what was changed, not the journey.

---

## Other context that may help

- The Section_Insights config workbook on IPK has insights anchored to funnel sub-tabs by name. Some of them quote specific funnel numbers (e.g. "50% aware → 25% primary buyer"). Those numbers are written against `% of total` so they remain correct.
- The Portfolio panel's "% who bought" column was a separate investigation in this session. It uses `pen_mat_raw` (BRANDPEN2 unreconciled) and matches the funnel's `bought_target` raw count. Don't touch unless something's broken.
- Brand report verification convention: Duncan only verifies via `launch_turas()` in the Shiny app. Never claim something works on the rendered HTML without him browser-testing first.
- Tests live in `modules/brand/tests/testthat/`. Run with `Rscript -e 'Sys.setenv(TESTTHAT="true"); testthat::test_dir("modules/brand/tests/testthat", reporter = "minimal", stop_on_failure = FALSE)'`.

---

## If something seems impossible

Stop and ask Duncan. Don't invent an explanation. The session that wrote this handover did exactly that and burned trust. The data is in OneDrive at `/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/8844718_data.xlsx`; read it directly with `openxlsx::read.xlsx()` if a number doesn't add up.

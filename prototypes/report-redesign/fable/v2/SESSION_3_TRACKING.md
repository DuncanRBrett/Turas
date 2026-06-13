# Session 3 — Tracking in the data-centric report v2 (build plan)

**Goal:** light up the v2 report's built-in Tracking tab (Summary / Explorer /
Visualise) on a real project's wave history, starting with **CCS (4 waves)**.
**Branch:** continue `feature/tabs-json-data-layer` (or a fresh
`feature/tabs-tracking` off it).
**Status:** investigated 2026-06-13; NOT built. This plan is grounded in the
real CCS tracker data + the v2 `waves` island shape (both inspected).

## The architecture (read first — resolves the "different model" worry)

There are TWO trackers; do not conflate them:
- **Classic tracker module** (`modules/tracker/`) — standalone, its own
  `Tracking_Config.xlsx` + `Question_Mapping.xlsx`, deep wave analysis, own
  reports. **Stays as-is.**
- **v2 report's Tracking tab** — built INTO the renderer (27t/27u/27v +
  `22w_waves.js`). Reads ONE data island, `data-prev` = the `waves` payload,
  and lights up. Does NOT run the classic module's code.

"Building in the tracker" = **feed the renderer's Tracking tab a `waves`
island**. The bundler currently inlines `data-prev` as `null` (Tracking tab
hidden). This session produces a real `waves` island and inlines it.

## The data (CCS, real)

**Source — the classic tracker report embeds it as JSON** (no scraping):
`…/CCPB/CCS/Crosswave/02_Report/CCS_Tracker_TrackingCrosstab_20260609.html`,
`<script id="hm-explorer-data" type="application/json">`:
```
{ waves: ["Wave22".."Wave25"],
  waveLabels: ["Wave 22 - Oct 2024", … "Wave 25 - May 2026"],
  segments: ["Total"],
  thresholds: { pct:{green:70,amber:50}, mean5/mean10:{8.5,7}, nps:{30,0}, … },
  metrics: [ { id, label, name, type:"nps|mean|pct", section, sortOrder,
               data: { Total: { Wave22:{value,display,change_prev,change_base,
                                          sig_prev,sig_base,n}, … } } }, … ] }  // 14 metrics
```
CCS also has the analyst inputs already: `Crosswave/CCS Tracking_Config.xlsx`
and `Crosswave/CCS Question_Mapping.xlsx`.

**Target — the v2 `waves` island** (`data/sacap_waves.json` shape):
```
{ schema_version, match_report,
  waves: [ { wave, year, segments,
             questions: [ { code, title, base, title_norm, match_key,
                            rows: { <rowkey>: {label, n, pct} },  // DISTRIBUTION
                            stats: { … } } ] } ] }
```
The renderer matches wave questions to the live (agg) questions by
`match_key` / normalised title, and derives the trend.

## The core mismatch (the design decision)

- Tracker `hm-explorer-data` = **one summary value per metric per wave**
  (NPS score, mean, top-box %). Metric-centric.
- v2 `waves` island = **per-wave distributions** (rows of pct per category),
  wave-centric; the renderer derives the headline metric from them.

**Two ways to bridge — pick one (Duncan's call):**

1. **Tracker emits the `waves` island (summary-carried).** Transpose
   metric→wave; put each metric's per-wave value in the wave question's
   `stats` (e.g. `{nps: +30}` / `{mean: 7.4}` / `{net: 33}`), leave `rows`
   empty. **First confirm `22w_waves.js` can drive Summary/Explorer/Visualise
   from `stats`-only waves (no distribution).** If it needs distributions,
   either (a) extend the wave engine to accept a direct per-wave metric, or
   (b) use option 2. Lowest effort if the engine cooperates; reuses the
   tracker's existing question-matching + sig.
2. **Re-run tabs per wave for full distributions.** Run the tabs v2 writer on
   each wave's raw data → 4× `_data.json` (full distributions) → assemble the
   `waves` island via a Waves-config sheet + the question-map. Highest
   fidelity (matches the proven SACAP shape exactly; Explorer/recompute all
   work), but needs each wave's raw data (check `Crosswave/01_Data`, which
   looked empty — the tracker config points at the real source) and a
   per-wave run.

**Recommendation:** spike option 1 first (it's a transpose + an engine check)
because the tracker already has matched, sig-tested values; fall back to
option 2 if the engine demands distributions or Explorer fidelity matters.

## Known wrinkles

- **Twice-yearly waves.** CCS waves are Oct 2024 / May 2025 / Oct 2025 / May
  2026 — two share calendar year 2025. The wave engine keys the trend x-axis
  on `year`; it must key on wave index/label (or a decimal year) or the two
  2025 waves collide. Verify + adjust in `22w_waves.js` / `23za_trend.js`.
- **Metric types.** Map tracker `type` (nps/mean/pct) to the renderer's metric
  handling + thresholds. The tracker even ships `thresholds` — reuse them
  (consistent with the dashboard-threshold parity work).
- **NPS / mean significance** is already computed by the tracker
  (`sig_prev`/`sig_base`); prefer carrying it over recomputing.

## Wiring

- **Inliner:** `build_report_v2_html` currently hardcodes `{{DATA_PREV}}` =
  `"null"`. Add a `prev_json` param; when present, inline it (with the same
  `</` escaping as the agg island). `write_html_report_v2` gains the param.
- **run_crosstabs Step 4d:** when a Waves source is configured, build the
  `waves` island and pass it to `write_html_report_v2`.
- **Config:** a Waves/source pointer in the tabs Settings (path to the wave
  source — a tracker report, or prior `_data.json`s + the question-map).

## Verify (numbers must be right)

- Build a CCS v2 report WITH the waves island; open in browser.
- Tracking tab appears; Summary/Explorer/Visualise show all 4 waves.
- Spot-check known values against the tracker report, e.g. **NPS metric_1
  Total: Wave22 = +30, Wave25 = +7** (a real −23 drop); a mean metric's
  per-wave values; the twice-yearly waves sit in order on the trend x-axis.
- Confirm the agg (current-wave) numbers still match the published report.

## Decisions for Duncan
1. Bridge option 1 (tracker emits summary `waves`) vs option 2 (re-run tabs
   per wave for full distributions)?
2. Source going forward: read the classic tracker's output, or have tabs
   reassemble from prior-wave `_data.json`s? (Long term, forward-built waves
   each emit `_data.json`; CCS history is a one-time backfill from the tracker
   report.)

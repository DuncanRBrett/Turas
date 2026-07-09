# V2 Report — Aggregate-Wave Tracking (design & build plan)

**Status:** Design approved (direction), pre-build. Maps verified against code 2026-07-08.
**Goal:** Show a full historical trend (e.g. CCPB 2011→2025) plus the live current
wave in the tabs **v2 report's Tracking tab**, where the historical waves are
**pre-computed aggregates** (value + base, no microdata) and significance stays
honest. Reusable for any tracker Duncan takes over.

---

## 1. The key finding — the engine already supports this

The v2 wave engine (`html_report_v2/assets/js/22w_waves.js`) reads a prior wave's
value from **any of three shapes**, not just microdata:

| shape | fields (per wave-question) | used for |
|-------|----------------------------|----------|
| microdata | `scores[]` (+ `weights[]`) | mean/NPS, current wave's SD |
| **computed totals** | `stats{mean\|index\|nps, sd?}`, `seg_stats{}`, `base`, `bases{}` | **mean/NPS history (value-only)** |
| **proportion rows** | `rows{ norm(label): {pct, n?, seg{}} }`, `base`, `bases{}` | **proportion/NET history** |

`score_type` is written by R but **never read by JS** — the renderer decides
mean-vs-proportion from the *current* question's row kind + label.

**Honest significance is already how it works** (`22w_waves.js`):
- mean: `meanLevel` → Welch `meanZ(value, sd, n, …)`; **returns "no test" when sd
  is missing** (→ historical means, which have no recorded SD, plot untested).
- proportion: `propLevel` → pooled `propZ(x, base, …)`, count `x = value/100*base`
  when no `n` given (→ real test wherever a base exists).
- both gate on effective base ≥ `low_base_threshold` (default 30).

So no renderer change is needed for aggregate values or proportions. An R
assembler for the value-only + proportion shapes **already exists**:
`tracker_segment_contributions()` (`tracking_segment_bridge.R`) — and its schema
is locked by `tests/testthat/test_tracking_segment_bridge.R`.

## 2. The only real gap

`tracker_segment_contributions()` takes the classic tracker's `trend_results`,
which are computed *from per-respondent microdata* (`compute_segment_trends()`).
Historical aggregates have **no microdata** — only value + base per metric per
wave. So the gap is a **writer that emits the same, tested island shapes from a
pre-computed values table** (the exact file the tracker-module aggregate feature
already produces: `metric_id, wave, metric_type, value, base, sd`).

## 3. How tracking wires into a run (verified)

`run_crosstabs.R:793-819`, active when `html_report_v2_tracking = TRUE`:
1. `load_question_mapping(question_mapping)` — canonical `QuestionCode` + `Wave*`
   columns + `TrackingSpecs`; `detect_wave_column()` finds the current wave's column.
2. `wave_contribution()` builds the **current** wave from microdata (mean/NPS).
3. writes the current wave's `*_wave.json` sidecar (forward path).
4. `read_wave_contributions(waves_source, self)` reads **prior** waves' sidecars.
5. `build_tracking_island()` + `serialize_tracking_island()` → the `data-prev` blob.
6. Tab shows **iff the island has > 1 wave**. Failures are swallowed (report still builds).

The current wave's proportion values come **live from `TR.AGG`** (the crosstab),
so proportions need no current-wave island contribution — only the *prior* waves
must carry them. Matching is by `match_key = tracking_norm(canonical code)`
(current wave keys via the mapping), and proportion rows match the current
question's category/NET row by `tracking_norm(label)`.

## 4. Build stages (each ends green)

1. **Reusable writer.** `aggregate_wave_sidecars()` (new, in a tabs lib file):
   input = a long values table (`metric_id, wave, metric_type, value, base, sd`) +
   the canonical mapping (for match_key + per-proportion tracked category label) +
   `waves_meta`; output = one island wave-contribution per wave, in the EXACT
   shapes `tracker_segment_contributions()` emits (mean/NPS → `stats` incl. `index`
   dual-label + `sd` when present; proportion → `rows{norm(category):{pct,n}}`),
   `current = FALSE`. Unit tests lock the shapes (mirror
   `test_tracking_segment_bridge.R`), incl. honest fields: `sd` carried when
   present / omitted when blank; blank base → no `n`. **No renderer/engine change.**
2. **CCPB data.** A v2-format `Question_Mapping` (canonical code + `Wave2026`
   column = 2026 data codes + `TrackingSpecs`), and generate the 2011→2025
   sidecars from the values file (2025 carries real base + sd). Verify they
   round-trip through `read_wave_contributions()`.
3. **Wire + run.** Set config: `html_report_v2_tracking=TRUE`, `waves_source=<sidecars>`,
   `question_mapping=<v2 mapping>`, `wave=W2026`, `wave_order=2026`. Re-run the 2026
   tabs report → the Tracking tab lights up 2011→2026. Verify in the produced HTML:
   the `data-prev` island carries the waves; spot-check values vs history; confirm
   honest sig (proportions tested where base exists; historical means untested).
4. **Guardrails.** Full tabs suite green — R testthat (esp. `test_tracking_*`,
   `test_report_v2_bundler`) + the `.mjs` renderer suites. Adversarial: category-label
   matching, mean with/without sd, the >1-wave gate, `waves_source` used raw.

## 5. Reusability

Stage 1's writer is general — any tracker's aggregate values table → v2 tracking
sidecars — so a future tracker Duncan takes over needs only a values table + a
canonical mapping, not microdata. It is the v2 twin of the tracker-module
aggregate-wave-ingest, and consumes the same values-file format.

## 6. Do-not-break list (from the tests)

- `test_tracking_segment_bridge.R:119-122,140` — exact question field sets.
- `wave_trends.mjs:40-46` — microdata schema.
- `test_report_v2_bundler.R:138` — empty island inlines as `null`.
- `run_crosstabs.R:808` — the >1-wave gate.
- `waves_source` is consumed **raw** (no path resolution), unlike `question_mapping`.

# Segment report v2 — build plan (WIP)

Branch: `feature/segment-report-v2`. Status: **Phase 0 complete.** This is the
first advanced module to adopt the data-centric report pattern from tabs/tracker
v2. Scope is the **HTML/presentation layer only** — the segmentation statistics
are not touched.

## Locked decisions (greenlit by Duncan, 2026-06-15)

1. **Approach: vendor the generic v2 core into `modules/segment`, build
   segment-native views on top — then a committed "extraction" phase** promotes
   the proven-generic core into a shared cross-module platform for the rest of
   the roadmap (conjoint → maxdiff → keydriver → catdriver → brand). Rationale:
   the shared boundary is then drawn from *two* real consumers (crosstabs +
   segments), not guessed from one. The only failure mode (copy drift) is
   controlled by a 0-drift gate, exactly as tabs vendors from the prototype today.
2. **Ambition: parity + new data-centric interactivity**, plus the single
   highest-value IA improvement from a full redesign — **reader-in ordering**
   (segments/personas first; diagnostics demoted to a "Quality" tab). Revisit
   going further after the Profiles vertical slice is live and clickable.
3. **The classic report stays.** v2 is a NEW, opt-in, flag-gated output
   (mirror `html_report_v2 = FALSE` default from tabs). If v2 isn't ready,
   classic still ships.

## Architecture: classic vs v2

- **Classic (today):** R assembles the entire HTML as strings server-side
  (`lib/html_report/`: 74 KB section builders, 43 KB hand-written SVG charts,
  29 KB CSS via `gsub`). Charts are frozen at build time; interactivity is
  scroll-nav + pins + insight editing only. Already uses shared `TurasPins`.
- **v2 (target):** R emits a JSON **data layer**; a vendored client engine
  renders + lets the user explore in-browser. Live filtering, on-the-fly
  significance, dynamic charts/heatmaps, deep-linkable state, self-test gate.

## The data-layer mapping (the crux)

The v2 renderer hard-requires only `agg.questions[]` + `agg.columns[]`
(`20_data.js:105` `d2.validate`); microdata/waves/insights all degrade
gracefully. A **segment profile table is itself a crosstab**:

| v2 crosstab concept | Segmentation analogue |
|---|---|
| `columns` (banner) | the segments (+ Total) |
| `questions` / `rows` | profile variables (means / z-scores / index) |
| significance letters | segment-vs-overall or segment-vs-segment tests |
| dashboard gauges | segment scorecards / quality at-a-glance |
| filter (microdata) | filter profiles by a demographic (optional island) |

The profile matrix, variable importance and overview map onto the **reusable**
render/heatmap/chart/export primitives. The non-crosstab artifacts —
validation diagnostics, classification rules, persona cards, vulnerability,
k-exploration — get **segment-native views** inside the reused shell.

## Reuse map

- **Reuse as-is (engine plumbing):** `00_namespace`, `01_format`, `03_svg`,
  `13_zip`, `14_pptx_parts`, `styles.css`, `template.html`, the build/inliner
  pipeline, `28_insights`, `30_story`, `32_report`, `31_selftest` (harness),
  shared `turas_pins*`.
- **Reuse with light retarget:** `24_shell` (tab list + routing), `29_export`
  (PNG + native PPTX from a generic view model), `23_render` / `23z_charts`
  (table + chart from a model), `27u_summary` (KPI card pattern).
- **Build new for segmentation:** the data-layer writer (`build_dl_segments`,
  profile matrix, diagnostics, rules, cards) and the views — Overview & sizes,
  Profiles + explorer, Quality & validation, Classification rules, Segment
  cards, k-exploration.

## Parity checklist (locked from the Phase 0 baseline)

Baseline: `tools/generate_baseline.R` → PASS, 1.10 MB, k=3 / n=300 /
silhouette 0.464; self-contained (9 `<script>`, 2 `<style>`), shared `TurasPins`.

Report tabs: **Analysis · Pinned Views · Slides · About**

Analysis sections to reach parity on:
- [ ] Executive Summary
- [ ] Segment Overview (sizes)
- [ ] Cluster Validation
- [ ] Segment Distinctiveness (overlap)
- [ ] Variable Importance
- [ ] Golden Questions
- [ ] Segment Profiles  ← **vertical-slice target**
- [ ] Segment Vulnerability
- [ ] Classification Rules (see open issue)
- [ ] GMM Membership (gmm method only)
- [ ] Interpretation Guide
- [ ] Pins → PNG / PPTX export (via shared TurasPins or v2 exporter)

Also modes to cover later: **exploration** (k-selection) and **combined**
(multi-method) — currently separate builder paths.

## Phase plan

- **Phase 0 — Reference + lock.** DONE. Baseline generated on the synthetic
  fixture; parity checklist + IA locked.
- **Phase 1 — Platform bring-up.** DONE. Vendored the assembled v2 engine
  (29 JS + `styles.css` + `template.html`) into `assets/` from
  `modules/tabs/lib/html_report_v2/assets/` (provenance + 0-drift note in
  `assets/README.md`); ported the bundler to `build_report_v2.R` (`seg_*` fns,
  segment asset dir).
- **Phase 2 — Data-layer writer.** DONE (first cut). `data_layer_writer.R`
  `build_segment_data_layer()` maps the profile onto the v2 `agg` contract
  (segments → columns, variables → mean-row questions) — pure re-presentation,
  no stats recomputed. Verified: passes the REAL engine `d2.validate` (ok=true)
  AND the full engine resolves the correct view-model means in node (q1 Total
  5.31 / Seg1 2.90 / Seg2 7.97 / Seg3 5.00 == profile). R gate
  `tests/testthat/test_data_layer_writer.R` (21/0); `tools/build_report_v2.R`
  builds a self-contained `segment_report_v2.html` (0.41 MB) on the fixture.
  NOTE: this first cut renders through the existing (crosstab-flavoured)
  Dashboard/Crosstabs views; sig is empty (no false claims); a "Segment sizes"
  question + diagnostics are deferred to the native views.
- **Phase 3 — Native views (first cut DONE).** Added a backward-compatible
  `TR.app` seam to `24_shell.js` (tab list / default tab / route precedence —
  the one documented engine edit, see `assets/README.md`) and a segment-native
  module `js/40_segment_app.js` (kept OUT of the vendored `assets/js/`). The
  report now opens reader-in: **Overview** (segment scorecards — size + top
  over/under-indexing variables) → **Profiles** (variables × segments heatmap,
  shaded vs the overall mean) → **Report** (engine metadata tab). Verified
  headless in node (seam registers; both views render expected content). Gates:
  `test_report_v2_bundler.R`. STILL TODO in Phase 3: per-segment explorer +
  variable-importance view, interactivity (click-to-drill), pin → PNG → PPTX,
  and an in-browser boot check (Duncan's launch step).
- **Phase 4 — Fan out** the remaining views (Quality/validation, sizes,
  vulnerability, golden questions) + exploration/combined modes.
- **Phase 5 — Parity, gates, review.** Self-test cases, golden tests, the
  PowerPoint "Edit Data" round-trip test, production review, merge + GUI checkbox.
- **Phase 6 — Extraction.** Promote the proven-generic core into a shared
  platform module consumed by tabs + segment (reconciling any tabs/tracker
  fixes Duncan has flagged).

## Open issues / decisions

- **Vendoring source-of-truth (Phase 1 first task):** copy the generic JS from
  the prototype (`prototypes/report-redesign/fable/...`, the canonical origin
  tabs vendors from) so there is ONE origin and a 0-drift gate — not from tabs'
  vendored copy. Confirm the prototype still holds these files.
- **Bug found (analytics, out of scope here):** `generate_segment_rules()`
  throws `subscript out of bounds` on the 10-var / 3-cluster fixture, so the
  Rules section silently drops in the classic report too. Flagged separately.
- Duncan has flagged unrelated issues in tabs/tracker v2; the Phase 6 extraction
  is where those reconcile with the shared core.

## Regenerate the baseline

```
TURAS_ROOT=/Users/duncan/Dev/Turas \
  Rscript modules/segment/lib/html_report_v2/tools/generate_baseline.R
# → writes the current (classic) report to a temp dir; prints the path + size.
```

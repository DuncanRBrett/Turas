# HANDOVER — Tracker Integration into the v2 Data-Centric Report

> **STATUS: COMPLETE incl. explorer parity (2026-06-12).** Round 4 (Totals
> tracking, flagship pin, composites) PLUS round 5 (per-segment workspace:
> Summary scorecard / Metrics / Segments / Visualise absorbing the tracker
> module's explorer_view + metrics_view + summary builder) shipped on
> `feature/report-data-layer`. Gates: 22 v2 + 21 v1, all green;
> browser-verified after tab-bouncing with cache-busting and computed
> styles; in-browser selftest 11/11. See README "Round 4" + "Round 5".
> **Remaining manual step for Duncan:** open `tests/tmp/v2_exhibit.pptx`
> and `tests/tmp/v2_segpin.pptx` in PowerPoint — "Edit Data" must open
> Excel on BOTH charts of slide 2 in each.
> **Known limits for the production review:** means/indexes/NPS show
> direction only (published totals carry no spread — the real pipeline
> will t-test means per trend_significance.R); annotations and compare-
> across-questions overlays are noted as Visualise stretch items; built
> report is 1.90 MB of its 2 MB budget (per-segment data costs ~0.6 MB).
> **Next phase (sequence revised 2026-06-12):** confidence module
> integration FIRST — see `HANDOVER_CONFIDENCE_INTEGRATION.md` — so the
> statistical layer is complete before the one full production review
> (`duncan-production-review`); then the remaining advanced modules.

**For:** a fresh session. Read this cold; it is self-contained.
**Mission:** replace the v2 report's basic Tracking tab with full tracker-module
functionality (15+ waves), then redesign composites around it. After this
phase, Duncan runs a full production review (`duncan-production-review`),
and only then do the advanced modules (confidence first, then segmentation,
conjoint, maxdiff, key driver, catdriver, brand) get this look and feel.
**Touch nothing in live Turas modules.** Build inside
`prototypes/report-redesign/fable/v2/` only.

---

## 1. What exists (all committed on `feature/report-data-layer`)

`prototypes/report-redesign/fable/v2/sacap_report_v2.html` — a 0.95 MB
single-file recreation of the real 7.0 MB SACAP 2025 crosstabs report:

- **Data layer** (4 JSON islands): `data-agg` (published 2025 tables, exact),
  `data-micro` (synthetic respondents powering live filters/custom banners),
  `data-prev` (2024 wave Totals), `data-verify` (microdata fit report),
  `user-state` (annotations embedded by "Save copy").
- **Tabs:** Dashboard (gauges + heatmap w/ banner picker, Excel export, pin),
  Crosstabs (the full workspace), Differences, Tracking (basic — your target),
  Story (pins/dividers/present/native PPTX), Report (exec summary, added
  slides, about).
- **Engine modules** (`src/js/2x_*.js`): 20 state/hash, 21 stats (masks,
  tabulate, pooled-z mirroring `modules/tabs/lib/weighting.R`, dual 95/80),
  22 view model (published-vs-computed merge + 2024 deltas + row ops),
  23 render (tables/matrix/clipboard), 23y xlsx writer, 23z chart types
  (bar/column/stacked/pie/dot + `repel()` label declutter), 24 shell,
  25 crosstabs UI, 26 filters, 27 views, 28 insights, 29 export (PNG +
  **native PPTX chart objects**: c:chartSpace + embedded xlsx via the
  extended packager in `../src/js/14_pptx_parts.js`), 30 story, 31 selftest,
  32 report tab + save-copy.
- **Pipeline:** `pipeline/extract_2025_html.py` (rendered report → data
  layer; NET decomposition incl. NET POSITIVE diffs), `extract_2024_xlsx.py`
  (workbook → wave totals; **must call `ws.reset_dimensions()`** — the
  workbooks ship broken dimension records), `generate_microdata.py` (seeded;
  campus crosses exact, hill-climb repair for other banners).

### Build + gates (run before AND after every change)

```bash
cd prototypes/report-redesign/fable/v2
Rscript build.R                    # → sacap_report_v2.html
node tests/run_tests_v2.mjs        # 14 tests incl. golden parity + python pptx check
node ../tests/run_tests.mjs        # v1 prototype gate (21) — shared 14_pptx_parts must stay green
```

Browser check: `preview_start` name `report-prototype-fable` (port 8775,
serves `fable/`), open `/v2/sacap_report_v2.html`. **Always cache-bust**
(`?v=<random>`) — stale loads have repeatedly masqueraded as bugs.

---

## 2. The mission: full tracking

### Source intel

- **Tracker module:** `modules/tracker/lib/` — 47 files, ~28k lines.
  Key reading: `trend_calculator.R` (stats), `wave_loader.R`,
  `question_mapper.R` (cross-wave question matching),
  `html_report/js/explorer_view.js` + `metrics_view.js` (the views to
  absorb), `03c_summary_builder.R`.
- **Reference report:** `/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/Turas/examples/tracker/full_test/CCS_tracking_crosstab.html`
  (557 KB). Structure: tabs Summary/Explorer/Visualise/Added Slides/Pinned;
  per-metric rows carry `data-seg-data` JSON — per wave, per segment:
  `{value, display, change_prev, change_base, sig_prev, sig_base, n}` —
  rendered as column-per-wave + SVG sparkline + Δ column. It is already
  half data-centric; map that JSON shape into this report's data layer.
- **Real multi-wave data:** SACAP crosstab workbooks exist for **all of
  2018–2025** at `…/DB Files/Projects/SACAP/Student_Annual/03_Waves/Student_Annual-<YEAR>/04_Analysis/Crosstabs/`.
  The 2024 extractor parses that format; generalise it and run per year.
  Question codes SHIFT between waves — match by normalised title
  (`TR.model.norm`, mirrored in the pipeline) + row label; 2025 has 13
  questions with no history (must degrade gracefully, already does).

### Required functionality

1. **Waves array, not a single prev:** `data-prev` becomes
   `{waves: [{wave, questions…}]}`; `attachDeltas` gains per-wave values;
   support 15+ waves (Duncan has projects that long).
2. **Tracking tab = tracker parity:** metric rows (key metrics default,
   config `project.tracking`) with column-per-wave values, **sparkline**,
   Δ vs previous AND vs baseline, sig flags on both (reuse `stats.propZ`),
   per-wave bases, drill-down to the question, search/section filter/sort
   (basic versions exist).
3. **Crosstab integration:** per-question wave strip (mini trend chart +
   per-wave table row) when history exists; line chart type already exists
   for dot — add a proper `line` chart over waves.
4. **The flagship pin (Duncan's words):** "distribution of ratings on a
   question in chart and then a line chart with rating per wave below" —
   a two-panel exhibit, pinnable, present-able, exporting to PPTX as TWO
   native chart objects on one slide (the packager already supports
   multiple charts per slide: rels rId2+k — verify with the python gate).
5. **Composite redesign (PARKED, do it here):** the old per-section index
   composite was removed from the Story actions (code kept for back-compat).
   Requirements from Duncan: mix tracker trend vs this-wave distribution;
   chart AND/OR table; allow cross-section (any questions, not just one
   category). Design it as the same exhibit builder as (4).
6. **Tracking config:** `project.tracking = {enabled, default_scope,
   waves: [...]}` — no history → tab hides (works today); scope "key"
   (NPS/index/rating NETs) vs "all" (works today).

### Definition of done

- All gates green + new known-answer tests (multi-wave delta maths,
  baseline-vs-prev sig, sparkline geometry, wave matching rates per year).
- Golden parity stays exact for 2025 published tables.
- Browser-verified **after tab-bouncing** and with cache-busting; computed
  styles, not just attributes/properties (see §3).
- PPTX with two-chart slide passes `tests/verify_pptx.py` + a manual
  PowerPoint open (chart objects: "Edit Data" must open Excel).
- README + this handover updated; commits atomic with the trailer
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

## 3. Hard-won engineering guardrails (each one cost a real bug)

1. **Duplicate listeners:** every tab render must build a FRESH wrapper
   element and attach listeners to it (`host.replaceChildren(wrap)`);
   document-level listeners need singleton guards; internal re-renders must
   target `tabhost`, never a stale wrapper. Symptom when violated: toggles
   "do nothing" after switching tabs (even number of handler firings).
2. **`[hidden]` vs CSS:** `styles.css` has `[hidden]{display:none!important}`.
   Keep it. Any author `display:` rule otherwise defeats the hidden
   attribute — this single bug caused three rounds of "the panel won't
   close". **Verify visibility by `getComputedStyle`, never by property.**
3. **Panels:** the columns panel has TWO triggers (controls bar + chart
   toolbar) sharing one `#colmenu`; the document closer ignores
   `.pinwrap, [data-act="columns"]` and detached (`!isConnected`) targets
   (in-panel re-renders detach the clicked checkbox mid-bubble).
4. **Chart columns are selected by LABEL** (`state.chartColLabels`), never
   by index — hiding table columns must not shift chart series.
5. **Chart rows:** `chartRows()` honours `model.chartKind`
   (detail/summary/both), excludes `diff` rows (NET POSITIVE), falls back
   so charts are never empty; the Rows dropdown disables when no NETs.
6. **Small-segment labels:** use `render.repel()` (1-D declutter) for
   callouts — stacked bars put <7% labels above the bar with leader ticks;
   pies put small slices outside, repelled per side. Reuse for sparkline
   end-labels.
7. **Sig methodology:** mirror `weighting.R` exactly — pooled z, α=.05
   (+.20 lowercase when dual), expected counts ≥5 both sides, bases <30
   excluded and ⚠-flagged. Published letters are shown verbatim in
   published views; engine letters only in computed views.
8. **Microdata is SYNTHETIC** (fitted; campus crosses exact, others ≈1.8pp).
   Tracking comparisons vs prior waves use published wave Totals — keep it
   that way; do not "filter" history that doesn't have microdata.
9. **jsonlite/renv:** run R from the repo root or `v2/` (renv autoloads);
   in throwaway worktrees set `RENV_PATHS_LIBRARY=/Users/duncan/Dev/Turas/renv/library`.
10. **Repo `.gitignore` ignores `*.html`** — `prototypes/report-redesign/.gitignore`
    re-includes it (`!*.html`); built artifacts ARE committed deliberately.

## 4. Context for later phases (not this session)

- Production path: tabs emits the JSON data layer + this renderer behind a
  config switch; config/survey-structure/data files unchanged; microdata
  embedding optional per project with anonymity threshold.
- Tabs bug status: suite green (1,859/0) on
  `fix/tabs-stats-pack-and-numeric-zero-base` — **not merged to main yet**.
- Sig-letter agreement vs published file ≈90% (engine slightly less
  conservative on borderline cells) — documented in README; revisit in the
  production review with the real R pipeline, not extracted counts.

# SACAP Report v2 — Full Data-Centric Recreation

The real SACAP 2025 Annual Student Survey crosstabs report, recreated end-to-end
on the data-centric architecture — **0.87 MB instead of 7.0 MB** — with every
analytical feature of the live report plus the capabilities the render-centric
design could never offer. Built entirely inside `prototypes/`; **no live Turas
code touched**.

Open **`sacap_report_v2.html`** in any browser. No server, no installs, works
offline. Append `#selftest` to run the in-browser verification panel.

## What's in it

**Real data.** All 79 questions / 598 rows / 35 banner columns extracted from
the published 2025 report (`pipeline/extract_2025_html.py`), plus the real
**2018–2024 wave history** from all seven prior-year workbooks
(`pipeline/extract_waves.py`). Cross-wave question matching is by normalised
title with a reviewable alias map (`pipeline/wave_title_aliases.json`, the
tracker module's question-mapper pattern) — match rates 90% (2024) / 87%
(2023) / 76% (2022) tapering to 48% (2018), the rest being genuinely new or
restructured questions. History values are always **published wave Totals**;
the synthetic microdata never filters prior waves.

**Feature parity with the live report** — categorised sidebar + search, five
banner groups per question, sig letters, heatmap shading, counts toggle,
low-base flags, NETs and Index rows, per-question analyst insight editor,
About/methodology.

**What the live report cannot do:**

| Feature | How |
|---|---|
| **Filter the whole report** ("Online students only") | every table/dashboard recomputes live from embedded respondent-level microdata, with correct bases and significance |
| **Custom banners** — cross anything by anything | `+ Custom…` on the banner strip |
| **Full tracking workspace, 2018–2025** | Four tracker-parity views under Tracking: **Summary** (threshold-banded KPI scorecard with sparklines, sig up/down/stable pulse bar, significant-changes cards across Total + segments, metric × segment significance heatmap), **Metrics** (every tracked metric column-per-wave for Total or any banner segment), **Segments** (one metric across every tracked segment, tick → visualise), **Visualise** (multi-series wave chart: absolute / vs previous / vs baseline, 95% CI bands from published bases, value-label modes, wave chips, y-axis override, low-base warnings, insight note, Excel + pin-to-story) |
| **Per-segment history** | wave workbooks' banner columns extracted and matched to 2025 banner columns (Campus 2020-2022+2024; Intensity + Course 2024); NETs/Index recompute per segment where waves published categories only |
| **Δ + trend** on every tracked question | delta chips on the Total column (vs the latest matched wave) plus a **wave strip** under the table: per-wave bases and the headline metrics with sparklines |
| **Trend chart type** | "Trend · waves" in the chart picker — line over waves for any tracked question |
| **Two-panel trend exhibit** (the flagship pin) | 📈 in the pin menu: this-wave distribution chart + trend-over-waves below; presents full-screen and exports as **two native editable chart objects on one PPTX slide** |
| **Cross-section composites** | Story → "+ Composite exhibit…": any tracked questions, each contributing its headline metric (Index/NPS → NET → NET POSITIVE) as a bar and a trend series, plus a metric-by-wave table |
| **Findings** tab | deterministic ranking of significant banner gaps, deep-linked |
| **Story tab** | pins capture the exact view (banner+filter), commentary attached, reorder, **Present mode** (full-screen, arrow keys) |
| **Native PPTX export** | story → real editable PowerPoint (text + tables, no screenshots), built by ~29 KB of in-file code, not 0.94 MB of PptxGenJS |
| **Shareable views** | full state (tab/question/banner/filter) lives in the URL hash |
| **Published/Computed honesty** | unfiltered standard views show the published numbers **verbatim** with a PUBLISHED badge; anything recomputed is badged COMPUTED |

## The microdata (read this bit)

The respondent-level file is **synthetic** — generated (`pipeline/generate_microdata.py`,
seeded) to fit the published tables. Verified at build + test time:

- Total and **Campus-banner crosses exact** for every question (2,562 cells, 0 mismatches; golden-parity gate).
- Other banner crosses approximated: **mean |error| 1.8pp** on healthy-base cells (p90 4.5pp); low-base cells are noisier and are flagged ⚠ anyway.
- Significance recomputation matches the published ▲ letters in ~90% of cells using the production formula (pooled z, α=.05, expected-count ≥5 precondition from `modules/tabs/lib/weighting.R`); the engine is slightly less conservative on borderline cells.

**In production this layer disappears:** Turas generates the report *from* the
real respondent data, so it would embed real (anonymised, threshold-suppressed)
microdata and every filtered cross would be exact. The synthetic layer exists
only because this prototype works backwards from a rendered HTML file.

## Build + verify

```bash
cd prototypes/report-redesign/fable/v2
python3 pipeline/extract_2025_html.py "<2025 report.html>" data/sacap_2025.json
python3 pipeline/extract_waves.py --aliases pipeline/wave_title_aliases.json \
    data/sacap_2025.json data/sacap_waves.json \
    2018="<2018 crosstabs.xlsx>" ... 2024="<2024 crosstabs.xlsx>"
python3 pipeline/generate_microdata.py data/sacap_2025.json data/sacap_microdata.json data/microdata_verification.json
Rscript build.R                  # -> sacap_report_v2.html (1.25 MB)
node tests/run_tests_v2.mjs      # 19 tests incl. golden parity + 2-chart pptx gate
```

The wave extractor reads the Total column of each workbook's Crosstabs sheet
(`ws.reset_dimensions()` is mandatory — the workbooks ship broken dimension
records) and, unlike the retired single-wave extractor, also captures the
NET-style `Column %`-only rows (NETs, NET POSITIVE, Detractor/Passive/
Promoter) and the Index / Average / Score stat rows.

Browser-verified end-to-end (Chromium): boot, dashboard (32 gauges + heatmap
grid), banner switching incl. 17-column Course, NET-expansion filters
(Online campus → n=561, and Q008's filtered Total base lands exactly on the
published 191), custom banner, What Moved (real findings: WIL "Excellent"
−38pp, financial statements "Yes" −22pp), story pinning, native PPTX bytes
python-validated, 8/8 in-browser selftests.

## Production path (no live code touched yet)

1. **Emit the data layer from tabs** — a JSON writer alongside the existing
   Excel/HTML writers (values, counts, bases, sig, nets, index scores; plus
   anonymised microdata behind a config flag with a suppression threshold).
2. **Ship this renderer** as the new HTML report, old path intact behind a
   config switch; golden-file tests R↔JS like this prototype's parity gate.
3. Retire the per-cell HTML generator + PptxGenJS + html2canvas when trusted.

## Known limitations

- PowerPoint open test is manual (structure is machine-validated): build the
  story deck and double-click it — gate files are `tests/tmp/v2_story.pptx`
  and `tests/tmp/v2_exhibit.pptx` (the two-chart exhibit slide; "Edit Data"
  on each chart must open Excel).
- Insights/pins persist in `localStorage` per browser; the export/import JSON
  sidecar is the durable path.
- 8 questions are new in 2025 and correctly show "new in 2025" (no history).
- The sig engine is ~90% letter-identical to the published report (documented
  above); published views always show published letters, so nothing a client
  sees in the default view differs from the report of record.
- Wave comparisons are always against the full published wave Totals,
  including when a 2025-side filter is active (noted in the UI).
- The cross-wave alias map contains two analyst judgment calls (the Student
  Support & Development Team renames) — documented in
  `pipeline/wave_title_aliases.json` `_judgment_calls`; review them before
  presenting long trends on those metrics.
- Index values for waves whose workbooks omit Index rows (2021, 2024) are
  recomputed from the published distributions via the 2025 index weights —
  exact to ±0.5 of the published convention.

## Round 3 additions (Duncan's 30-item review)

Crosstabs: hide/show rows (✕ on row labels) and columns; detail-vs-summary row
scope toggles; sortable column headers (desc → asc → original); chart types
(bar / column / stacked / pie / dot plot) with multi-column selection;
dual significance (UPPERCASE 95% / lowercase 80%, the tabs convention);
explainers moved to a footer; collapsible sidebar + per-category collapse;
sequential prev/next; banner-specific analyst insights; a context strip that
keeps filters and custom banners visibly labelled on screen, pins and exports.
Custom banners offer **summary groupings** (NETs — e.g. Promoter/Passive/
Detractor) or detail categories.

Dashboard: heatmap by any banner (own picker), Excel export (real .xlsx via
the in-file writer), pin-to-story. Differences: banner picker + sortable +
named "higher than" columns. Tracking: scope toggle, search, section filter,
sortable.

Story: section dividers, composite exhibits (all index metrics of a section),
heatmap pins, per-item PNG; PPTX slides carry the insight as a bottom callout
band and the chart as ONE grouped editable object (p:grpSp).

Report tab: Background & method, Executive summary, Added slides (text blocks
or imported images ≤1.5 MB each — e.g. qual slides saved as pictures), About
(analyst, contact, disclaimers) + auto-generated methodology.

**Save copy** (header): clones the report into a single .html with all
insights, story items and report sections embedded — recipients open it with
every annotation intact, no installs.

## Round 4 — tracker integration (2018–2025)

Replaces the basic single-prev-wave tracking with tracker-module parity:

- **Data:** `pipeline/extract_waves.py` + `wave_title_aliases.json` →
  `data/sacap_waves.json` (7 waves, per-year match report embedded).
- **Engine:** `22w_waves.js` — per-row trend series from published wave
  Totals; Δ vs latest matched wave AND vs baseline with pooled-z sig on both
  (published counts when present, low-base excluded); NET member-sum,
  NET POSITIVE plus−minus and Index-recompute fallbacks for waves published
  without those rows.
- **Tracking tab** (`27t_tracking.js`): column-per-wave values with bases in
  tooltips, sparklines, Δ prev / Δ first, drill-down, search/section/sort,
  key-vs-all scope, top-200 cap with count note.
- **Crosstabs:** wave strip under tracked questions (per-wave bases +
  headline metrics + sparklines + "full trend chart ↗"), new "Trend · waves"
  chart type (`23za_trend.js`).
- **Exhibits** (`30x_exhibit.js`): the flagship two-panel pin (distribution
  + trend, TWO native chart objects on one PPTX slide) and the cross-section
  composite builder that replaced the parked per-section composite (old item
  kind kept for back-compat with saved pins).
- **Gates:** 19 v2 tests — multi-wave known answers against workbook ground
  truth (2022 registration NET 83 / Index 82), baseline-vs-prev sig flags,
  sparkline geometry, per-year match-rate floors, two-chart PPTX validation.

## Round 5 — tracker explorer parity (per-segment workspace)

Round 4 tracked published Totals only; round 5 absorbs the tracker module's
explorer functionality (`modules/tracker/lib/html_report/js/explorer_view.js`
/ `metrics_view.js` / `03c_summary_builder.R` were inventoried first):

- **Data:** the wave extractor now reads every banner-segment column that
  maps onto a 2025 banner column (`segment_aliases` in the alias file;
  Campus 2020-2022 + 2024, Intensity/Course 2024; 2018/2019/2023 were
  published Total-only). Per-segment cells store Column % + per-segment
  bases; counts derive as round(pct × base).
- **Engine** (`22w_waves.js`): `waves.series(q,row,ri,segment)` +
  `waves.cellsFor(points)` produce the tracker cell shape — per wave:
  value, base, change vs previous, change vs baseline, pooled-z sig on
  both, low-base excluded. `waves.segments()` registers tracked segments.
- **Workspace** (`27t/27u/27v`): Summary / Metrics / Segments / Visualise
  (see the feature table above). Published figures everywhere — report
  filters deliberately do not apply inside Tracking.
- **Pins:** any Visualise view pins to the story as a two-chart native
  PPTX exhibit (current-wave by segment + trend by segment + optional
  metric-by-wave table).
- **Honesty rule:** means/indexes/NPS scores carry direction only — the
  published wave totals have no spread, so only proportion metrics are
  significance-tested (the production path with real microdata will t-test
  means exactly as `modules/tracker/lib/trend_significance.R` does).
- **Gates:** 22 v2 tests; new known answers — per-segment NPS (Cape Town
  2020 = 35, current = the published campus cell verbatim), 2021 NET via
  member-sum (CT 87, base 36), per-year segment coverage, segment-pin
  PPTX with one series per pinned segment.

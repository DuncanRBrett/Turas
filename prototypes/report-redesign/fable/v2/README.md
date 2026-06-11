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
the published 2025 report (`pipeline/extract_2025_html.py`), plus the real 2024
wave from the prior-year workbook (66/79 questions matched by title for
year-on-year tracking).

**Feature parity with the live report** — categorised sidebar + search, five
banner groups per question, sig letters, heatmap shading, counts toggle,
low-base flags, NETs and Index rows, per-question analyst insight editor,
About/methodology.

**What the live report cannot do:**

| Feature | How |
|---|---|
| **Filter the whole report** ("Online students only") | every table/dashboard recomputes live from embedded respondent-level microdata, with correct bases and significance |
| **Custom banners** — cross anything by anything | `+ Custom…` on the banner strip |
| **Δ vs 2024** on every tracked row | chips on the Total column; bold = significant change |
| **What Moved** tab | every tracked row ranked by year-on-year change, significance first |
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
python3 pipeline/extract_2024_xlsx.py "<2024 crosstabs.xlsx>" data/sacap_2024.json
python3 pipeline/generate_microdata.py data/sacap_2025.json data/sacap_microdata.json data/microdata_verification.json
Rscript build.R                  # -> sacap_report_v2.html (0.87 MB)
node tests/run_tests_v2.mjs      # 14 tests incl. golden parity; exit 0 = green
```

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
  story deck and double-click it — the gate file is `tests/tmp/v2_story.pptx`.
- Insights/pins persist in `localStorage` per browser; the export/import JSON
  sidecar is the durable path.
- 13 questions are new in 2025 and correctly show "new in 2025" (no deltas).
- The sig engine is ~90% letter-identical to the published report (documented
  above); published views always show published letters, so nothing a client
  sees in the default view differs from the report of record.
- 2024 comparisons are always against the full published 2024 wave, including
  when a 2025-side filter is active (noted in the UI).

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

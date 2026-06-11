# Turas Data-Centric Report — Fable Prototype

Built blind to SPEC.md §6. One data layer, one fixed renderer, single
self-contained HTML file. **No PptxGenJS anywhere** — the PowerPoint export is
a ~29 KB in-house OOXML writer that produces *native, editable* slides.

## Open it

| File | What it is | Size |
|------|------------|------|
| `turas_report.html` | Demo report — 8 questions, 4 banner columns, 3 waves | **127 KB** |
| `turas_report_scale.html` | SACAP-scale benchmark — 139 questions, **26,700 cells**, 10 banner columns | **548 KB** |

Double-click either file. No server, no installs, no network. Append
`#selftest` to the URL to run the in-browser known-answer suite (a 12/12
panel renders at the top).

The real SACAP report with the same cell count is **7.0 MB** — the scale
build is **7.6% of that size (13× smaller)**, far under the spec's ≤3 MB
stretch target, *with* the native PPTX exporter included.

## What to try

1. **Browse** — sidebar nav + search; every card = chart + trend (if waved) + full sig-tested table.
2. **Banner chips** — click an age group on Q1: the chart re-renders for that column on a stable axis; the trend highlights that column in gold.
3. **⧉ Compose** (top bar) — tick Q3 + Q4 (+Q5), Compose view. Percentage rows share one axis; trended questions get aligned wave strips. This is the cross-question view the old render-centric report could never do — it is computed from data, not glued from pictures.
4. **Copy table** — paste into PowerPoint/Word/Excel: it arrives as a real, editable, brand-styled table (rich HTML + TSV flavours).
5. **Copy chart / PNG** — hi-res (3×) PNG assembled as pure SVG from data. No html2canvas, no DOM screenshots, no CSS-variable resolution.
6. **+ Deck → Download .pptx** — native PowerPoint: real text boxes, real `a:tbl` tables, bars drawn as individually editable rounded-rectangle shapes, brand colours in the theme. Open the file and click any bar — you can move, recolour and retype everything.

## Architecture

```
build.R                  assembles template + CSS + 18 JS modules + data JSON → one HTML file
src/template.html        skeleton with {{TOKENS}}
src/styles.css           design system (brand-themed via CSS vars set from data)
src/js/
  00 namespace+constants     01 formatting        02 data layer + validator
  03 svg primitives          04 bar charts        05 stacked/NPS/trend charts
  06 table builders          07 cards             08 app shell
  09 wiring (lazy render)    10 composer          11 PNG export
  12 clipboard export        13 zip writer        14 pptx package parts
  15 pptx slide builders     16 deck              17 selftest
data/demo_data.json      synthetic demo (hand-computed, internally consistent)
data/generate_scale_data.R   seeded SACAP-scale generator
tests/run_tests.mjs      21-test verification gate (node, zero deps)
tests/verify_pptx.py     structural PPTX validation (zip + XML + native table)
```

Modules 00–06 and 13–15 are **pure** (string in, string out, no DOM) so the
same code unit-tests in node, renders in the page, rasterises to PNG and
feeds the PPTX builder. Charts carry literal colours — an exported SVG never
needs CSS-variable resolution (a recurring pin-export bug in the live code).

### Data schema (criterion 7: swap the JSON, get a new report)

```jsonc
{
  "project":  { "name", "client", "wave", "fieldwork", "brand_colour",
                "accent_colour", "sig_note",
                "export": { "pptx": true },          // Tier B toggle per project
                "format": { "percent_decimals": 0 } },
  "banner":   { "label", "columns": [...], "letters": ["T","A","B",...] },
  "sections": [ { "id", "title", "questions": ["q1", ...] } ],
  "questions": [ {
      "id", "code", "title",
      "type": "single | multi | scale | nps | numeric",
      "banner": [...],                                // optional per-question override
      "base_label", "bases": [...],                   // per banner column
      "rows":  [ { "label", "values": [...], "sig": ["","C",...], "format": "pct" } ],
      "stats": [ { "label", "values": [...], "sig": [...], "format": "dec1|pct|int|nps" } ],
      "scale": { "min": 1, "max": 5 },
      "meta":  { "waves": { "stat", "format", "labels": [...],
                            "series": [ { "column", "values": [...] } ] } }
  } ]
}
```

The scale build proves genericity: different project, different brand colour
(navy → green, re-themed everywhere including the PPTX theme), 10-column
banner, 139 questions — zero renderer changes.

### Robustness

- The validator **accumulates every error** (TRS-style codes: `DATA_ROW_LEN`,
  `DATA_Q_DUP_ID`, …) and refuses with a full on-page + console listing.
- Every chart renders inside a try/catch: a broken chart shows an inline
  notice; **the table always still renders** (criterion 8). Covered by a test.
- Lazy rendering: card shells appear instantly; bodies fill as you scroll
  (IntersectionObserver) **and** via a progressive background queue, so every
  card renders even where the observer never fires (printing, odd embeds).

### Dual-tier export

- **Tier A (always, in-file):** clipboard rich-HTML table (pastes editable into
  Office) + TSV; hi-res PNG built as pure SVG from data.
- **Tier B (per-project toggle `project.export.pptx`, in-file):** a deck tray;
  download builds a native .pptx via the in-house writer — `13_zip.js`
  (CRC-32 + stored-entry ZIP) + `14/15_pptx_*.js` (OOXML parts + slides).
  **~29 KB of readable source replaces the 0.94 MB PptxGenJS bundle**, so the
  toggle is no longer a size decision.
- **Tier C (Turas-side):** unchanged path — the same `tables.matrix` model is
  exactly what `officer` needs; not part of this standalone prototype.

## Scorecard (SPEC §5)

| # | Criterion | Result |
|---|-----------|--------|
| 1 | Smaller | 548 KB at SACAP scale vs 7.0 MB real — 13× smaller |
| 2 | Self-contained | zero external requests; build refuses if any `src/href="http…"` appears; tested |
| 3 | Offline | pure file:// rendering, no fetches (open with Wi-Fi off) |
| 4 | Any browser | vanilla ES5-style JS, SVG, CSS vars + color-mix; verified in Chromium; no exotic APIs beyond ClipboardItem (which has fallbacks) |
| 5 | Cross-question | composer: shared-% axis bars + aligned wave strips, from data |
| 6 | Native export | .pptx with real text/tables/shape-bars; python-validated `a:tbl` present; no images |
| 7 | Generic | scale report = same renderer + different JSON, zero code change |
| 8 | Robust | per-slot error containment; validator accumulates; tested |

## Verification gates

```bash
cd prototypes/report-redesign/fable
Rscript data/generate_scale_data.R     # regen synthetic scale data (seeded)
Rscript build.R                        # → turas_report.html
Rscript build.R --data data/scale_data.json --out turas_report_scale.html
node tests/run_tests.mjs               # 21 tests, exit 0 = green
```

`run_tests.mjs` runs the shared known-answer suite (identical cases to the
in-browser `#selftest`), validates the demo data, round-trips a deck through
the PPTX writer and validates the package with python (`zipfile` + XML parse +
native-table check), checks built artifacts are self-contained and within
size targets, and enforces the 300-active-line structure rule.

## What was verified, and how

- 21/21 node tests green; 12/12 in-browser selftests green (Chromium).
- Browser-verified live: all cards render (8/8 demo; 26.5k cells reach the
  DOM at scale with zero errors), chip switching, search, composer mount,
  deck building a 3-slide PPTX in-page, PNG rasterisation producing a 504 KB
  3×-scale blob.
- PPTX validated structurally (zip CRCs, required parts, well-formed XML,
  slide count, native `a:tbl`).

## Known limitations / honest risks

- **PowerPoint open test is manual.** The package passes structural
  validation, but "opens clean in PowerPoint/Keynote with zero repairs" needs
  a human double-click on `tests/tmp/test_deck.pptx` (regenerate via tests)
  or any downloaded deck. This is the single most important manual check.
- Firefox/Safari were not in the automated loop — the code avoids anything
  engine-specific (no foreignObject, no OffscreenCanvas) and clipboard has
  fallbacks, but criterion 4 deserves a 2-minute manual open in each.
- Background fill of all 139 scale cards takes ~30–60 s in a *hidden* tab
  (browser timer throttling); scrolling renders what you look at instantly.
- Numbers in `scale_data.json` are random (seeded) — they demonstrate volume,
  not statistical coherence; `demo_data.json` is hand-computed and coherent.
- Composite trend strips align waves by position when wave labels differ
  (noted in the output).

## What Duncan should check by hand

1. Open both HTML files offline; click around; run `#selftest`.
2. Copy table → paste into PowerPoint **and** Excel.
3. Build a deck (2 questions + 1 composite) → download → open in PowerPoint:
   confirm no repair prompt, then click a bar and a table cell to confirm
   they are editable shapes/tables, not pictures.
4. Open the scale report and judge scroll/search feel at 139 questions.

# HTML Report Enhancements Plan

## Overview
Three enhancements to the HTML tabs report. All changes stay within the existing modular architecture, use only pre-calculated data from `table_data`, and maintain the single-file HTML output.

---

## Enhancement 1: Multi-Column Charts

**Goal:** Charts show selectable columns (not just Total). A separate "chart column picker" independent of the table column chips — so you can have a table with Total + all campuses, but a chart showing just Total + one selected campus.

### What changes

**07_chart_builder.R** — Modify `build_question_chart()`:
- Extract data for ALL internal keys (not just `total_key`) from `table_data`
- Embed all column data as a JSON blob in a `data-chart-data` attribute on the chart wrapper div
- Initial SVG still renders Total only (default)
- For **stacked bars** (box categories): one stacked bar per selected column, labelled with column name on the left, shared legend at bottom
- For **horizontal bars** (single response): grouped bars per category — one bar per selected column, colour-differentiated
- Each bar/group gets `data-col-key` attributes for JS toggling

**03_page_builder.R** — Add chart column picker UI + JS:
- Chart column chip bar inside each `.chart-wrapper` (appears when charts are toggled on)
- Chips default to Total only (others off)
- Clicking a chip triggers JS to rebuild the SVG from the embedded JSON data — no R recalculation
- JS functions: `buildChartChips()`, `toggleChartColumn()`, `rebuildChartSVG()`
- Completely independent of table column visibility

**Key constraint:** All values from pre-computed `table_data`. JS reads the embedded JSON and builds SVG elements. Zero recalculation.

### SVG Layouts

**Stacked bars (ordinal/box categories):**
```
          Total  ████████████████████████████████  (Negative | Neutral | Positive)
         Online  ████████████████████████████████
            Jhb  ████████████████████████████████
                 ● Negative (23%)  ● Neutral (31%)  ● Positive (46%)
```

**Horizontal bars (single response):**
```
  Very Satisfied  ████████████████  68%  Total
                  ██████████████    62%  Online
       Satisfied  ████████████      55%  Total
                  ██████████        48%  Online
```

---

## Enhancement 2: Key Insight Comment

**Goal:** Optional editable text area per question. Hybrid: config seeds comments, inline editing for tweaks before print/export.

### What changes

**Config integration:**
- `config_obj$comments` — optional named list: `list(Q001 = "Brand X leads...", Q003 = "...")`
- If absent, just an "Add Insight" button per question

**03_page_builder.R** — Add insight area:
- `build_insight_area(q_code, comment_text)` helper function
- Placed between chart-wrapper and table-actions in `build_question_containers()`
- If config has a comment → callout visible with pre-filled text, button says "Edit Insight"
- If no config comment → hidden callout, button says "+ Add Insight"
- `contenteditable` div for inline editing; persists in DOM for session
- CSS: subtle callout (brand-colour left border, light background)
- JS: `toggleInsight(qCode)` show/hide; placeholder via `::before` pseudo-element
- Print CSS: shows callout if it has content, hides buttons

**99_html_report_main.R** — Pass `config_obj$comments` to `build_html_page()`

---

## Enhancement 3: Slide Export (PNG)

**Goal:** "Export Slide" button → presentation-quality PNG with question title, base, chart, key metrics (mean/index/NPS if available), and insight.

### What changes

**03_page_builder.R** — Add export slide button + JS:
- "Export Slide" button in `.table-actions` (visible when chart is on)
- JS function `exportSlidePNG(qCode)`:
  1. Build entire slide as **pure SVG** (proven approach from existing `exportChartPNG`)
  2. Fixed viewBox (960×540, 16:9 ratio)
  3. Layout:
     - Title: question code + text (top)
     - Meta: base size (below title)
     - Chart: clone visible SVG from chart-wrapper
     - Metrics strip: scan table for mean/index/NPS rows, extract values from visible columns
     - Insight: wrapped text at bottom (if present)
  4. Render SVG → canvas at 3x → download PNG

### Metrics extraction (JS, from DOM):
- Scan `.ct-row-mean` rows in visible table
- Read `.ct-label-col` text (Mean, Index, NPS Score, etc.) and cell `data-sort-val` values
- Only include metrics that exist for this question
- All pre-calculated — just reading from the table DOM

### Slide Layout
```
┌──────────────────────────────────────────────────────────┐
│  Q001 — How satisfied are you with our service?          │
│  Base: n=1,000                                           │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  [Chart - stacked bars or horizontal bars]               │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  NET Positive: 67%  |  Mean: 7.2  |  Index: 7.4         │
├──────────────────────────────────────────────────────────┤
│  Brand X leads in satisfaction, driven by campus students │
└──────────────────────────────────────────────────────────┘
```

---

## Files Modified

| File | Enhancement | Changes |
|------|-------------|---------|
| `07_chart_builder.R` | 1 | Multi-column data extraction, embed JSON, multi-bar SVG builders |
| `03_page_builder.R` | 1, 2, 3 | Chart column picker, insight area, slide export — all UI+CSS+JS |
| `99_html_report_main.R` | 2 | Pass `comments` config through to page builder |

**No new files.** All additions are functions within existing modules.

## Implementation Order

1. **Enhancement 2** (key insight) — smallest, self-contained, needed by Enhancement 3
2. **Enhancement 1** (multi-column charts) — core chart improvement, foundational for slide export
3. **Enhancement 3** (slide export) — builds on both 1 and 2

## Principles
- **Pre-calculated only** — all values from `table_data`, zero recalculation
- **Zero new R dependencies** — pure SVG, vanilla JS, inline CSS
- **Single file HTML** — everything embedded, no external resources
- **Lean & modular** — small helper functions, no bloat
- **Graceful degradation** — no chart data → no chart picker; no comments → just "Add Insight" button; no metrics rows → slide skips metrics strip

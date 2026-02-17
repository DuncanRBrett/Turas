# HTML Report Enhancement Plan — Round 2

## Overview

15 improvements organised into 4 implementation phases. Each phase is self-contained
and testable before moving to the next, so we never break working functionality.

---

## Phase 1: Bug Fixes & Regressions (Items 1, 3, 4, 5, 7)

These are functional issues that need fixing regardless of any visual polish.

### 1.1 — Chart-table sort sync regression (Item #1)

**Root cause found:** The R-side chart builder (`07_chart_builder.R` line 311-315) wraps
each horizontal bar in `<g class="chart-bar-group" data-bar-label="..." data-bar-index="...">`.
However, `rebuildChartSVG()` is called on `DOMContentLoaded` by `initChartColumnPickers()`,
which replaces the R-generated SVG with JS-generated SVG from `buildMultiHorizontalSVG()`.
The JS version renders flat elements — no `<g>` wrapper, no `data-bar-label`, no `data-bar-index`.
So `sortChartBars()` finds zero `g.chart-bar-group` elements and silently returns.

**Fix:** Add `<g class="chart-bar-group" data-bar-label="..." data-bar-index="...">` wrappers
to **both** `buildMultiHorizontalSVG()` and `buildMultiStackedSVG()` in the JS chart picker code.
Each category group of bars gets wrapped so `sortChartBars()` can find and reorder them.

**Files:** `03_page_builder.R` (JS functions around lines 1654-1764)

**Risk:** Low — additive change, wrapping existing elements in `<g>` tags.

---

### 1.2 — Chart label truncation on right side (Item #3)

**Analysis:** The JS `buildMultiHorizontalSVG()` calculates `chartW = 680` and dynamically
widens it if `barAreaW < 200`. However, the **value label** (`pctText`) and **column name**
(for multi-column mode) are positioned at `labelW + barW + 8`, which can exceed the SVG
viewBox width when bars are near 100%. The SVG has `overflow: hidden` by default.

Similarly, in multi-column mode, the column name text after the percentage can run off the
right edge: `afterPct = labelW + barW + 8 + pctText.length * 7 + 6`.

**Fix:**
- Increase right-side padding in the viewBox calculation (add ~60px margin)
- Clip value text positioning to stay within viewBox bounds
- Same adjustment needed in R-side `build_horizontal_bars_svg()` for consistency

**Files:** `03_page_builder.R` (JS), `07_chart_builder.R` (R)

**Risk:** Low — adjusting spacing calculations.

---

### 1.3 — Key metric title centred above metric box (Item #4)

**Analysis:** In the stacked bar chart, the priority metric header label is positioned at
`text-anchor="end"` aligned to the right edge. The user wants it centred directly above
the metric value pill/box.

**Fix:** Calculate the metric box centre X position and use `text-anchor="middle"` with
that X coordinate for the header label.

**Files:** `03_page_builder.R` (`buildMultiStackedSVG` around line 1529-1531), and the
R-side equivalent in `07_chart_builder.R`.

**Risk:** Low — positioning adjustment.

---

### 1.4 — Slide export text truncation + colour key (Item #5)

**Analysis:** The slide export renders title text as a single SVG `<text>` element. SVG
text doesn't wrap — if the question title is longer than the slide width (960px), it gets
clipped. Same issue for insight text and metrics.

Additionally, the stacked bar chart has no colour key on the slide (the legend is part of
the chart SVG but may not be visible depending on chart type).

**Fix:**
- **Text wrapping:** Implement SVG `<tspan>` line-wrapping for title and insight text.
  Estimate character width (~7px at font-size 16) and split at word boundaries when
  text would exceed `W - 2*pad` pixels. Adjust subsequent Y positions accordingly.
- **Colour key:** Ensure the legend from the chart SVG clone is preserved when embedding
  in the slide. The chart clone already includes it, so this should work — verify and fix
  if the legend is being cut off by the viewBox.

**Files:** `03_page_builder.R` (`exportSlidePNG` function, lines 1885-2048)

**Risk:** Medium — SVG text wrapping requires careful height recalculation.

---

### 1.5 — Don't duplicate mean on slide if shown in chart (Item #7)

**Analysis:** The slide shows:
1. The chart SVG (which already includes priority metric pills for mean/index)
2. A separate "metrics strip" below the chart (extracted from table `ct-row-mean` rows)

When mean is the priority metric, it appears twice — once in the chart pill and once in
the metrics strip below.

**Fix:** In `exportSlidePNG()`, detect if the chart already displays a priority metric
(check `data-chart-data` JSON for `priority_metric.label`). If so, filter that metric
from the `metrics[]` array before rendering the strip. Only show metrics in the strip
that are NOT already visible in the chart.

**Files:** `03_page_builder.R` (`exportSlidePNG`, around lines 1912-1922)

**Risk:** Low — filtering logic before rendering.

---

## Phase 2: Branding & Visual Polish (Items 8, 9, 11, 12, 13)

Professional appearance improvements using the TRL brand palette.

### 2.1 — TRL brand colour scheme (Item #8)

**Extracted from TRL Logo Colours_RGB.pptx:**

| Role           | Hex       | RGB             |
|----------------|-----------|-----------------|
| Near-Black     | `#030303` | 3, 3, 3         |
| Dark Navy      | `#323367` | 50, 51, 103     |
| Gold           | `#CC9900` | 204, 153, 0     |
| Burnt Orange   | `#E56B33` | 229, 107, 51    |

**Proposed usage:**
- **Primary brand:** Dark Navy `#323367` — header background, active states, brand accents
- **Accent/highlight:** Gold `#CC9900` — active tab indicators, selected states, badges
- **Secondary accent:** Burnt Orange `#E56B33` — hover states, secondary highlights
- **Text:** Near-Black `#030303` — headings and primary body text

**Important:** The current system uses `brand_colour` from config (default `#0d8a8a` teal).
We should NOT hardcode TRL colours — instead, update the **default** brand_colour and add
a configurable **accent_colour** option. The TRL colours become the new defaults but any
client can override them in their Settings sheet.

**Implementation:**
- Add `accent_colour` config field (default: Gold `#CC9900`)
- Update CSS colour variables to use brand + accent
- Update chart colour palette generation to start from brand_colour
- Keep everything configurable

**Files:** `config_loader.R`, `03_page_builder.R` (CSS), `06_dashboard_builder.R` (CSS)

**Risk:** Medium — touching CSS across multiple files. Test thoroughly.

---

### 2.2 — Professional colour/font consistency (Item #9)

**Current state:** Mix of hardcoded colours throughout CSS (`#1a2744`, `#374151`, `#64748b`,
`#f8f9fa`, etc.). Font stack is consistent (`-apple-system, BlinkMacSystemFont, Segoe UI,
Roboto, sans-serif`).

**Fix:**
- Define a semantic colour palette at the top of `build_css()` using CSS custom properties:
  ```css
  :root {
    --ct-brand: #323367;
    --ct-accent: #CC9900;
    --ct-text-primary: #1e293b;
    --ct-text-secondary: #64748b;
    --ct-bg-surface: #ffffff;
    --ct-bg-muted: #f8f9fa;
    --ct-border: #e2e8f0;
  }
  ```
- Replace hardcoded colour values with CSS variables throughout
- Ensure consistent font sizing: 11px data, 13px labels, 16px headings

**Files:** `03_page_builder.R` (CSS section)

**Risk:** Medium — many replacements, but purely visual. Side-by-side testing needed.

---

### 2.3 — Logo in report banner (Item #11)

**Analysis:** `TRL Logo.png` is 1340x944px, 395KB (527KB base64). This is far too large
to embed in every HTML report.

**Solution:**
1. Create a small optimised version (~32px height, ~45px width) as base64 PNG
   OR use an SVG version if available
2. Embed in the header-left div, before the brand text
3. Use a config option `logo_base64` that can be overridden

**Note:** We need to create a resized version. Options:
- Ask Duncan to provide a small version (~4-8KB)
- Generate one programmatically using R's `magick` package (if available)
- Use a simple SVG placeholder that can be swapped

**Recommendation:** Add a `logo_path` config option. At report generation time, read the
image, resize to max 40px height, convert to base64, and embed. If `magick` isn't available,
fall back to a simple text logo. If no logo_path specified, show no logo.

**Files:** `config_loader.R`, `03_page_builder.R` (`build_header`), `99_html_report_main.R`

**Risk:** Low-Medium — need to handle image processing gracefully. The `magick` package
may not be installed (use `requireNamespace` check).

---

### 2.4 — Config whitelabel logo option (Item #12)

This is effectively the same as 2.3 — the `logo_path` config field handles both:
- Default: TRL logo (or no logo)
- Whitelabel: client's own logo file path in Settings sheet

**Config fields to add:**
- `logo_path` — file path to logo image (default: NULL = no logo)
- `company_name` — already exists (default: "The Research Lamppost")

**Files:** `config_loader.R` (add `logo_path` field)

---

### 2.5 — Optional client label (Item #13)

**Current header structure:**
```
[Brand label: "Company · Turas Analytics"]
[Project Title]
[Meta: "Interactive Crosstab Explorer · n=X · Y Questions"]
```

**Enhancement:** Add optional `client_name` field. When set, display as:
```
[Brand label: "Company · Turas Analytics"]
[Project Title]
[Client: "Prepared for ClientName"]     <-- NEW (subtle, right-aligned or below title)
[Meta: ...]
```

**Config fields to add:**
- `client_name` — client/organisation name (default: NULL = hidden)

**Files:** `config_loader.R`, `03_page_builder.R` (`build_header`)

**Risk:** Low — additive change to header.

---

## Phase 3: Chart Intelligence (Items 2, 10)

Smarter chart behaviour.

### 3.1 — Row greying / exclude from chart (Item #2)

**Concept:** Allow users to click a row in the table to toggle it grey, which excludes that
category from the chart. Similar to dashboard metric exclusion.

**Implementation:**
- Add a toggle icon or click handler on `ct-label-col` cells for category rows
- Toggled rows get `ct-row-excluded` class (greyed out visually)
- When chart is rebuilt, filter out excluded labels
- Store exclusion state in a JS object keyed by table ID + label
- Exclusions reset when switching banner groups (consistent with sort reset)

**UI approach:** Small "eye" icon appears on hover in the label column. Click
toggles exclusion. Greyed row has `opacity: 0.35` and strikethrough text.

**Files:** `03_page_builder.R` (CSS + JS), `02_table_builder.R` (add icon element)

**Risk:** Medium — new interactive feature. Needs thorough testing with sort + column toggle.

---

### 3.2 — Semantic chart colours (Item #10)

**Concept:** For satisfaction-type scales, use colour semantics:
- Red/negative end: "Very Dissatisfied", "Poor", "Strongly Disagree"
- Green/positive end: "Very Satisfied", "Excellent", "Strongly Agree"
- Neutral/grey: middle categories

**Implementation approach:**
- This is already partially implemented in `07_chart_builder.R` via `get_semantic_colour()`
- The R-side builder assigns colours based on category position in the scale
- The JS chart picker also needs this logic for rebuilt charts
- Need to verify the colour mapping is working correctly and extend if needed

**Colour palette for semantic scales:**
- Strong negative: `#dc2626` (red-600)
- Moderate negative: `#f97316` (orange-500)
- Neutral: `#94a3b8` (slate-400)
- Moderate positive: `#22c55e` (green-500)
- Strong positive: `#16a34a` (green-600)

**Config option:** `semantic_colours: TRUE/FALSE` (default TRUE for Likert/ordinal questions)
The system should auto-detect ordinal scales vs nominal categories and only apply semantic
colours to ordinal scales.

**Files:** `07_chart_builder.R`, `03_page_builder.R` (JS colour logic)

**Risk:** Medium — auto-detection of scale type needs to be reliable. False positives
(applying semantic colours to nominal categories) would look wrong.

---

## Phase 4: Advanced Features (Items 6, 14, 15)

### 4.1 — Save insights to HTML file (Item #6)

**Concept:** Export a standalone HTML file containing all insights, organised by question.
Must work cross-browser and cross-OS — open in any browser, print nicely.

**Implementation options:**

**Option A — Minimal HTML string download (Recommended):**
- JavaScript collects all insight editors' text content
- Builds a simple, self-contained HTML string with inline CSS
- Downloads via `Blob` + `downloadBlob()` (same pattern as CSV/Excel export)
- Clean formatting: question code, question text, insight text, separator
- Includes project title, date, base info in header

**Option B — JSON export:**
- Export as JSON file that can be re-imported
- More machine-readable but less user-friendly

**Recommendation:** Option A. It's consistent with existing export patterns, works offline,
opens in any browser, and prints cleanly. JSON could be added later as a secondary format.

**Files:** `03_page_builder.R` (new JS function + button in controls area)

**Risk:** Low — follows existing export patterns.

---

### 4.2 — Alternative chart types (Item #14)

**User note:** "probably for a future phase"

**Agreed — defer to future phase.** Current stacked bar + horizontal bar cover the core
use cases well. When ready, candidates include:
- Donut/pie charts (for single-response with few categories)
- Line charts (for tracking data when tracker module integrates)
- Grouped bar charts (already partially there with multi-column horizontal bars)

**No action this round.**

---

### 4.3 — Tooltips / help system (Item #15)

**User context:** Shared Perplexity analysis. Wants to discuss options — concerned that
too much help could confuse rather than clarify.

**Recommendation: "First-time help overlay" approach:**
- A single "?" button in the header/controls area
- Clicking it shows a semi-transparent overlay highlighting key interactive elements
  with short labels: "Click to sort", "Toggle columns", "Add insight", etc.
- Dismisses on click/ESC
- Remembers dismissal in `localStorage` (shows automatically on first visit, optional after)
- Lightweight: ~50 lines of JS, ~30 lines of CSS

**Why this approach:**
- **Non-intrusive:** Doesn't add persistent tooltips that clutter the UI
- **Discoverable:** Users who need help can find the "?" button
- **One-time:** After first view, stays out of the way
- **Simple:** No tooltip library, no complex positioning logic
- **Cross-browser:** Pure CSS overlay + JS toggle

**Alternative considered:** Per-element tooltips on hover. Rejected because:
- Adds visual noise
- Positioning is fragile across screen sizes
- Many elements to annotate
- Can interfere with click targets

**Files:** `03_page_builder.R` (CSS + JS + button in header)

**Risk:** Low — completely additive, toggle-based.

---

## Implementation Order

```
Phase 1 (Bug Fixes)        <-- Do first, highest value
  1.1 Sort sync regression
  1.2 Label truncation
  1.3 Metric title centering
  1.4 Slide text wrapping + colour key
  1.5 Slide mean deduplication

Phase 2 (Branding)         <-- Do second, visual polish
  2.1 Brand colour scheme
  2.2 CSS custom properties + consistency
  2.3 Logo in banner
  2.4 Whitelabel config (part of 2.3)
  2.5 Client label

Phase 3 (Chart Intelligence) <-- Do third, new features
  3.1 Row exclusion from charts
  3.2 Semantic chart colours

Phase 4 (Advanced)          <-- Do last
  4.1 Insight export to HTML
  4.3 Help overlay
  4.2 Alternative charts --> DEFERRED
```

## Questions for Duncan

1. **Brand colours (Item #8):** Should Dark Navy `#323367` replace the current teal
   `#0d8a8a` as the default brand_colour? Or should we keep teal as default and only
   switch to navy when TRL logo is used?

2. **Logo (Item #11):** Can you provide a small version of the logo (~40px height)?
   Or should I attempt to resize programmatically using the `magick` R package?

3. **Semantic colours (Item #10):** Should semantic colours be opt-in (config flag) or
   auto-detected based on question type? Auto-detection risks false positives on scales
   where red/green semantics don't apply (e.g., frequency scales: "Daily, Weekly, Monthly").

4. **Help overlay (Item #15):** The "?" button overlay approach — does this feel right?
   Or would you prefer a different approach (e.g., a separate "Guide" page/tab)?

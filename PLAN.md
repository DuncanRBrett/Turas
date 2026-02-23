# Plan: Report Hub Module (`modules/report_hub/`)

## Overview

A new module that combines multiple Turas HTML reports (currently Tracker and Tabs/Crosstabs) into a single unified interactive report using DOM merge. The combined report preserves the full interactivity of each source report while adding a front page, cross-referencing, and a unified pinned views system with section dividers.

**Guiding principle:** Lightweight, bulletproof, works on all modern browsers. Zero external dependencies — everything vanilla JS/CSS embedded in a single self-contained HTML file.

---

## Architecture: DOM Merge with JS Namespacing

### How It Works

1. R parses each source HTML file
2. Extracts content panels, CSS, and JS
3. Wraps each report's JS in an IIFE namespace (`TrackerReport`, `TabsReport`)
4. Prefixes DOM IDs per report (e.g., `tracker--tab-summary`, `tabs--tab-crosstabs`)
5. Builds a unified shell with two-tier navigation
6. Creates a shared `ReportHub` manager that both report namespaces feed into (pinned views, cross-refs)
7. Generates the Overview front page from extracted metadata
8. Writes out a single self-contained HTML file

### JS Namespace Strategy

Each source report's JS gets wrapped in an IIFE module:

```javascript
var TrackerReport = (function() {
  // All tracker globals become private
  var pinnedViews = [];
  var activeSegments = {};
  // Functions reference namespaced DOM IDs
  return {
    togglePin: function(metricId) { ... },
    switchTab: function(tabName) { ... },
    init: function() { ... }
  };
})();
```

Shared code lives in a `ReportHub` namespace:

```javascript
var ReportHub = {
  pinnedViews: [],       // Unified pin store
  sections: [],          // Section dividers
  crossRefs: {},         // Tracker <-> Crosstab mapping
  switchReport: function(reportKey) { ... },
  addPin: function(source, pinObj) { ... },
  renderPinnedCards: function() { ... }
};
```

### Identified Conflicts (from analysis)

**Critical name collisions requiring namespacing:**
- `pinnedViews` (global array — both modules)
- `togglePin()` (different signatures)
- `renderPinnedCards()` (different card structures)
- `downloadBlob()` (different signatures: 2 vs 3 params)
- `saveReportHTML()`, `printReport()`, `toggleHelpOverlay()` (different implementations)
- `escapeHtml()`, `exportSlidePNG()`, `exportChartPNG()` (both define these)

**DOM ID collisions:**
- `pinned-cards-container`, `pinned-empty-state`, `pinned-views-data`, `pin-count-badge`, `header-date-badge`

All resolved by IIFE wrapping + ID prefixing.

---

## Navigation Structure

```
┌──────────────────────────────────────────────────────────────────┐
│  [Logo]  Project Title — Combined Report                         │
│          Prepared by Company Name                                │
├──────────────────────────────────────────────────────────────────┤
│  Overview │ Tracker │ Crosstabs │ 📌 Pinned (3)                  │  Level 1
├──────────────────────────────────────────────────────────────────┤
│  (Tracker selected → Level 2 appears:)                           │
│  Summary │ Metrics by Segment │ Segment Overview                 │
│                                                                  │
│  (Crosstabs selected → Level 2 appears:)                         │
│  Summary │ Crosstabs                                             │
├──────────────────────────────────────────────────────────────────┤
│  [Content area — full width, scrollable]                         │
└──────────────────────────────────────────────────────────────────┘
```

Level 1 switches which report is visible. Level 2 switches within that report (reusing existing tab logic). The Pinned tab and Overview are always at Level 1.

---

## File Structure

```
modules/report_hub/
├── 00_guard.R                    # Input validation
├── 00_main.R                     # Main orchestration: combine_reports()
├── 01_html_parser.R              # Parse source HTML files, extract components
├── 02_namespace_rewriter.R       # Prefix DOM IDs, wrap JS in IIFEs
├── 03_front_page_builder.R       # Build Overview/front page
├── 04_navigation_builder.R       # Build two-tier navigation shell
├── 05_pinned_merger.R            # Unified pinned views system
├── 06_cross_reference.R          # Cross-reference links between reports
├── 07_page_assembler.R           # Assemble final HTML
├── 08_html_writer.R              # Write output file
├── js/
│   ├── hub_navigation.js         # Level 1 tab switching, Level 2 delegation
│   ├── hub_pinned.js             # Unified PinnedViewManager with sections
│   └── hub_cross_ref.js          # Cross-reference link navigation
├── assets/
│   └── hub_styles.css            # Shell styles (nav, front page, unified pinned)
├── tests/
│   └── testthat/
│       ├── test_html_parser.R
│       ├── test_namespace_rewriter.R
│       ├── test_cross_reference.R
│       └── test_integration.R
└── README.md
```

---

## Phase 1: Core Shell (Foundation)

**Goal:** Two reports loading side-by-side in a unified shell with working navigation. No JS errors.

### 1.1 — `00_guard.R` — Input validation
- Each report path exists and is readable
- Files contain valid HTML (`<html>` tag present)
- Detect report type from `<meta name="turas-report-type">` (tracker) or presence of `tab-crosstabs` panel (tabs)
- No duplicate report keys
- TRS refusals for all failures

### 1.2 — `01_html_parser.R` — Parse source HTML
- Extract all `<style>` blocks (CSS)
- Extract all `<script>` blocks (JS), separating:
  - Executable JS (functions/logic)
  - Data blocks (`pinned-views-data` JSON, `BANNER_GROUPS_JSON`, etc.)
- Extract header HTML (logo, title, metadata badges)
- Extract content panels (the `tab-panel` divs)
- Extract footer HTML
- Return structured list: `list(css, js, data_scripts, content_panels, header, footer, metadata)`

### 1.3 — `02_namespace_rewriter.R` — Rewrite to avoid conflicts
- Prefix all `id="X"` attributes in content HTML with report key (e.g., `tracker--`)
- Rewrite JS string literals: `getElementById('X')` → `getElementById('tracker--X')`
- Rewrite JS string literals: `querySelector('#X')` → `querySelector('#tracker--X')`
- Wrap each report's full JS in an IIFE: `var TrackerReport = (function() { ... return { publicAPI }; })();`
- Remap inline `onclick="switchReportTab(...)"` to use namespaced function
- Route pin-related functions to `ReportHub.addPin()` instead of internal pin stores
- Prefix CSS selectors that target IDs (`#pinned-cards-container` etc.)

### 1.4 — `04_navigation_builder.R` — Build navigation HTML
- Level 1 nav bar: report tabs + Pinned tab (with badge)
- Level 2 nav bars: one per report (hidden until that report is active)
- Same visual style as existing `.report-tabs` CSS
- Overview tab is first, always visible

### 1.5 — `07_page_assembler.R` — Assemble final HTML
- Single `<!DOCTYPE html>` document
- `<meta name="turas-report-type" content="hub"/>`
- Merged `<style>` blocks (shared first, then per-report scoped)
- Unified header (from config or extracted from first report)
- Level 1 navigation
- Report panels: each wrapped in `<div id="{key}--report-panel" class="hub-panel">`
- Unified pinned panel
- All `<script>` blocks: hub JS first, then namespaced report JS
- Initialization: `DOMContentLoaded` calls each report's `init()`, then `ReportHub.init()`

### 1.6 — `08_html_writer.R` — Write output file
- Standard write with encoding handling
- Return TRS-compliant result

### 1.7 — `js/hub_navigation.js` — Navigation controller
- `ReportHub.switchReport(key)` — show/hide report panels, show/hide Level 2 nav, update active states
- URL hash support: `#tracker`, `#crosstabs`, `#pinned` for deep linking
- Keyboard: left/right arrows to cycle Level 1 tabs (when focus is on nav)
- Handle edge case: if only 1 report, skip Level 1 nav entirely

### 1.8 — `assets/hub_styles.css` — Shell styles
- Two-tier navigation styling
- `.hub-panel { display: none; }` / `.hub-panel.active { display: block; }`
- Front page card layout
- Print: current panel only, or pinned views only
- Responsive: stack nav on small screens

**Phase 1 tests:**
- HTML parser extracts correct components from real tracker + tabs HTML
- Namespace rewriter prefixes IDs without corrupting HTML structure
- Navigation switching shows/hides correct panels
- No JS console errors when both reports are loaded

---

## Phase 2: Unified Pinned Views with Sections

**Goal:** Single pinned tab collecting pins from both reports. Section dividers for narrative structure.

### 2.1 — `05_pinned_merger.R` — Server-side pin preparation
- Parse `pinned-views-data` JSON from each source report
- Tag each pin with `source: "tracker"` or `source: "tabs"`
- Merge into single array (ordered by timestamp)
- Generate unified `<script id="hub-pinned-data" type="application/json">` block

### 2.2 — `js/hub_pinned.js` — Unified PinnedViewManager

**Data structure:**
```javascript
ReportHub.pinnedItems = [
  { type: "section", title: "Brand Health", id: "sec-1234" },
  { type: "pin", source: "tracker", id: "pin-5678", ...pinData },
  { type: "pin", source: "tabs", id: "pin-9012", ...pinData },
  { type: "section", title: "Purchase Intent", id: "sec-3456" },
  { type: "pin", source: "tracker", id: "pin-7890", ...pinData },
];
```

**Features:**
- Pin cards show source badge: "📈 Tracker" or "📋 Crosstabs"
- Section dividers render as full-width banners with editable title
- "Add Section" button in toolbar
- Reorder pins AND sections freely — sections don't constrain pins
- Pins from both reports can live under any section
- Each pin has independent editable insight area
- Remove pin updates source report's pin button state
- Export: all pins + section dividers as sequenced PNGs
- Print: one page per pin, section dividers as page headers
- Save: serializes unified pin data + sections to JSON store

### 2.3 — Namespace rewriter pin intercept
- Tracker's `togglePin()` / `pinMetricView()` → rewrite to call `ReportHub.addPin("tracker", ...)`
- Tabs' `togglePin()` / `captureCurrentView()` → rewrite to call `ReportHub.addPin("tabs", ...)`
- Both modules' `updatePinBadge()` → `ReportHub.updatePinBadge()`
- `savePinnedData()` → `ReportHub.savePinnedData()`
- `hydratePinnedViews()` → `ReportHub.hydratePinnedViews()`

**Phase 2 tests:**
- Pins from tracker appear with correct badge
- Pins from tabs appear with correct badge
- Section dividers render and are editable
- Reordering works across sources
- Pin count badge reflects total from both sources
- Save/hydrate preserves all pins, sections, and their order

---

## Phase 3: Front Page (Overview)

**Goal:** Auto-generated overview with report index and combined summary. Editable where needed.

### 3.1 — `03_front_page_builder.R`

**Metadata extraction** — Pull from source reports:
- Project title, company name, logo (from header HTML)
- Tracker: n metrics, n waves, n segments, wave labels
- Tabs: n questions, total n, fieldwork dates

**Report index cards:**
- One card per included report
- Icon + label + key stats
- "View Report →" button (navigates to that Level 1 tab)
- Brand colour accent on card border

**Combined summary area:**
- Pull existing editable text from each report's Summary tab
- Display as labelled sections: "Tracker Summary", "Crosstabs Summary"
- Both editable (contenteditable divs)
- Persisted on save

**Project metadata strip:**
- Auto-populated row of badges: client, fieldwork, waves, total n
- Extracted from source reports

**Phase 3 tests:**
- Front page renders correct metadata from both reports
- Report index cards navigate to correct tabs
- Editable text persists across save/reload

---

## Phase 4: Cross-Referencing

**Goal:** Navigate seamlessly from tracker metric to corresponding crosstab question and back.

### 4.1 — `06_cross_reference.R` — Build cross-reference map

**Primary: user-provided mapping** (most reliable):
```r
cross_refs = list(
  list(tracker_code = "Q_SAT", tabs_code = "Q12"),
  list(tracker_code = "Q_NPS", tabs_code = "Q15")
)
```

**Fallback: auto-match** (when `auto_cross_ref = TRUE`):
- Extract question text from both reports' HTML (from data attributes or visible text)
- Fuzzy string matching on question text (base R `agrepl()` or Levenshtein distance)
- Only accept matches above a high similarity threshold (>0.85)
- Log matches to console so user can verify

**Output:** JSON lookup embedded in page:
```json
{ "tracker::Q_SAT": "tabs::Q12", "tabs::Q12": "tracker::Q_SAT" }
```

### 4.2 — Inject cross-reference links
- In tracker metric panels: subtle "See in Crosstabs →" link button near title (only if mapping exists)
- In crosstab question containers: subtle "See Trend →" link button near title (only if mapping exists)
- Data attribute: `data-xref-target="tabs::Q12"`

### 4.3 — `js/hub_cross_ref.js` — Navigation handler
- `ReportHub.navigateTo(target)` — parse target string, switch Level 1 tab, then navigate within report
- For tracker targets: call `TrackerReport.selectMetric(metricId)` + switch to Metrics by Segment
- For tabs targets: call `TabsReport.selectQuestion(index)` + switch to Crosstabs tab
- Brief highlight animation (yellow flash → fade) on target element

**Phase 4 tests:**
- Cross-ref links appear only where mapping exists
- Clicking link navigates to correct report + question/metric
- No errors when target doesn't exist
- Auto-match produces reasonable results on SACAP data

---

## API Design

```r
combine_reports <- function(
  reports,
  output_file,
  title = NULL,
  subtitle = NULL,
  cross_refs = NULL,
  auto_cross_ref = FALSE,
  overview_text = NULL
)
```

**`reports`** — list of report specs:
```r
list(
  list(path = "path/to/tracker.html"),
  list(path = "path/to/crosstabs.html", label = "Crosstabs 2025")
)
```
Label and key auto-detected from `<meta>` tags if not provided.

**Example usage:**
```r
combine_reports(
  reports = list(
    list(path = "tracker_report.html"),
    list(path = "crosstabs_report.html")
  ),
  output_file = "SACAP_Combined_Report.html",
  title = "SACAP Annual Climate Survey",
  cross_refs = list(
    list(tracker_code = "Q_SAT", tabs_code = "Q12"),
    list(tracker_code = "Q_NPS", tabs_code = "Q15")
  )
)
```

---

## Key Design Decisions

1. **No external dependencies** — All CSS/JS inline. Vanilla JS only. No CDN, no frameworks.
2. **Report type auto-detection** — `<meta name="turas-report-type">` for tracker. For tabs, detect by `tab-crosstabs` panel. Will add `turas-report-type` meta to tabs module too.
3. **CSS scoping** — Both reports share the same design tokens (font stack, colour variables). Common CSS extracted once; report-specific CSS scoped by parent panel class.
4. **Save Report** — Serializes everything: all content, unified pins, sections, cross-refs, editable text. Reopening restores full state.
5. **Print** — Two modes: print current report (Level 2 context) or print Pinned Views (curated presentation).
6. **Single report fallback** — If only one report provided, the hub still works with simplified nav (no Level 1 tabs).

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| JS namespace conflicts missed during rewriting | Comprehensive collision list already built. Test with real SACAP reports. |
| Regex-based ID rewriting is fragile | Target known patterns only. Validate with `node --check` on extracted JS. |
| Large combined file size | CSS deduplication. Accept ~30-50% larger than sum of parts due to shell overhead. |
| Performance with two reports in DOM | Only active panel is `display: block`. Inactive panels don't repaint. |
| Cross-ref mapping breaks on code changes | User-provided mapping is authoritative. Auto-match warns, never silent. |
| Browser compat | Vanilla JS only. Same browser targets as existing reports (Chrome, FF, Safari, Edge). |

---

## Implementation Order

```
Phase 1: Core Shell           ~1,500 lines (8 R files + 1 JS + 1 CSS)
Phase 2: Unified Pinned Views ~500 lines  (1 R file + 1 JS)
Phase 3: Front Page           ~300 lines  (1 R file)
Phase 4: Cross-Referencing    ~300 lines  (1 R file + 1 JS)
                              ─────────
Total estimated:              ~2,600 lines + tests
```


4. **Help overlay (Item #15):** The "?" button overlay approach — does this feel right?
Each phase is independently testable against the real SACAP HTML files.

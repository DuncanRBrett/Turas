# Turas Hub App — Development Specification v2

**Version:** 2.0
**Date:** 22 March 2026
**Author:** Duncan Brett / The Research LampPost (Pty) Ltd
**Status:** Specification — approved for development

---

## 1. Executive Summary

The Turas Hub App is a Shiny-native working environment for analysts to browse, annotate, and curate findings across multiple Turas HTML reports. It runs as a panel within the existing Turas Shiny launcher — one entry point, one process, one port.

It complements the existing single-file Report Hub (which remains the client deliverable) by removing the constraints of embedding everything in one HTML file.

**Key distinctions:**

| Artefact | Audience | Purpose |
|----------|----------|---------|
| **Individual HTML reports** | End clients | Self-contained, no install, open in any browser. The product. |
| **Single-file combined hub** | End clients (3+ reports) | Optional combined deliverable generated via `combine_reports()` |
| **Hub App** | Analysts (Duncan, Jess, team) | Working environment: browse, pin, annotate, compare, export decks |

Clients never see the Hub App. They receive standalone HTML files.

---

## 2. Problem Statement

The single-file Report Hub works well as a deliverable but has limitations as a working environment:

1. **No live CSS fidelity on pins** — pinned tables lose styling outside their report's CSS context
2. **File size grows with pins** — every pinned SVG/table adds to the HTML file
3. **No cross-project search** — each hub file is self-contained
4. **No PowerPoint export** — pins export as PNG only; analysts need slides
5. **Memory pressure** — all report HTML is base64-encoded in the DOM simultaneously
6. **No collaboration** — the file is a snapshot

The Hub App solves these by loading reports directly from the filesystem via Shiny's static file serving.

---

## 3. Architecture

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Shiny App (single process)                   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Existing Turas Launcher                   │   │
│  │  Module grid: Tabs, Tracker, MaxDiff, Conjoint, ...  │   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐   │   │
│  │  │            Hub App Panel                        │   │   │
│  │  │                                                 │   │   │
│  │  │  ┌───────────┐ ┌──────────┐ ┌──────────────┐  │   │   │
│  │  │  │ Project   │ │ Report   │ │ Pin Board /  │  │   │   │
│  │  │  │ Browser   │ │ Viewer   │ │ Export Mgr   │  │   │   │
│  │  │  └───────────┘ └──────────┘ └──────────────┘  │   │   │
│  │  └────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  R-side services:                                           │
│  ├── addResourcePath() — serve report HTML files            │
│  ├── officer — PowerPoint generation from pins              │
│  ├── combine_reports() — generate single-file hub           │
│  └── JSON sidecar I/O — read/write .turas_pins.json        │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Why Shiny-Native (Not Plumber)

| Consideration | Shiny-native | Plumber |
|---------------|-------------|---------|
| Entry point | Single app, single port | Two servers, two ports |
| Docker deployment | One process | Process orchestration needed |
| Jess's experience | One URL, one app | Must understand two services |
| CORS / iframe | Same origin via `addResourcePath()` | Same origin (both work) |
| Reactivity | Native Shiny reactives | Must poll or use WebSocket |
| Future migration | Can extract to Plumber later | Already separate |

**Decision:** Shiny-native. If a standalone API is ever needed, the R service functions are portable to Plumber without rewriting.

### 3.3 Technology Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Server** | Shiny (existing) | Already running; single entry point |
| **Report serving** | `addResourcePath()` | Same-origin iframe loading, no CORS |
| **Frontend** | Vanilla HTML/CSS/JS | Consistent with all Turas reports; no build step |
| **State** | IndexedDB (browser) + JSON sidecar files | Pins persist across sessions; sidecars sync to OneDrive |
| **PPTX export** | officer (R package) | Mature, well-tested, CRAN |
| **Hub generation** | combine_reports() (existing) | Already production-tested |

### 3.4 Report Serving Strategy

Reports are served via Shiny's `addResourcePath()`:

```r
# R-side: register project directory as a static path
addResourcePath("hub-reports", project_dir)

# Frontend: load report in iframe
iframe.src = "/hub-reports/Tracker_Report.html"
```

This gives:
- Same origin (no CORS issues)
- Full CSS/JS fidelity (report loads identically to standalone)
- No base64 encoding overhead
- Direct filesystem access from R side for exports

---

## 4. Report Integration

### 4.1 Pin Interception (v1 — No Module Changes)

The existing `hub_pinned.js` and `hub_navigation.js` already implement two complementary pin interception strategies. These work with current reports as-is:

**Strategy 1: MutationObserver on pin stores**
- Watches for changes to known pin store elements in each iframe
- Auto-discovers: `pinned-views-data`, `seg-pinned-views-data`, `cd-pinned-views-data`, `kd-pinned-views-data`, `md-pinned-views-data`, `cj-pinned-views-data`, `pr-pinned-views-data`
- Fallback: any element ID matching `*-pinned-views-data`
- Triggers when report's `savePinnedData()` updates the store

**Strategy 2: Function monkey-patching**
- Wraps known module pin functions (e.g., `cdPinSection`, `kdPinSection`)
- Catches pins from modules that update arrays without triggering DOM changes
- Polls for function availability with timeout (handles async module init)

**Bridge injection (after iframe loads):**
1. Injects `window.pinToHub` callback into iframe
2. Hides report header (hub provides unified header)
3. Makes report nav strips sticky
4. Inlines computed styles on captured table HTML

**Module coverage (v1):**

| Module | Pin Store ID | Status |
|--------|-------------|--------|
| Tabs | `pinned-views-data` | Working |
| Tracker | `pinned-views-data` | Working |
| Confidence | `pinned-views-data` | Working |
| Segment | `seg-pinned-views-data` | Ready (pattern exists) |
| CatDriver | `cd-pinned-views-data` | Ready (pattern exists) |
| KeyDriver | `kd-pinned-views-data` | Ready (pattern exists) |
| MaxDiff | `md-pinned-views-data` | Ready (pattern exists) |
| Conjoint | `cj-pinned-views-data` | Ready (pattern exists) |
| Pricing | `pr-pinned-views-data` | Ready (pattern exists) |
| Weighting | Fallback pattern | Ready (auto-discovery) |

**Why this matters for fast rollout:** The pin interception is already module-agnostic. Any report that stores pins in an element matching `*-pinned-views-data` works automatically. New modules plug in with zero Hub App changes.

### 4.2 Report Contract (v1.1 — Future Upgrade)

When stability allows, add a formal API to each report:

```js
window.TurasReportAPI = {
  version: "1.0",
  onPin: function(callback) { /* subscribe to pin events */ },
  getMetadata: function() { /* return report type, title, generated date */ },
  getPins: function() { /* return current pin array */ }
}
```

This replaces MutationObserver with explicit callbacks. Implementation:
- Add a thin JS shim to the shared report template (not per-module)
- Reports that have it use the API; reports that don't fall back to MutationObserver
- Roll out module by module without breaking anything

**Not blocking v1.** The existing interception works. This is a robustness upgrade.

---

## 5. Feature Specification

### 5.1 Project Browser

**Purpose:** Navigate between projects and their reports.

| ID | Requirement |
|----|------------|
| F1 | Scan configurable root directories for project folders |
| F2 | Detect projects by: folder containing `.html` with `<meta name="turas-report-type">` OR folder containing `*_Report_Hub_Config.xlsx` |
| F3 | Display projects as cards: name, report count, last modified, total size |
| F4 | Support local drives and OneDrive paths |
| F5 | Add/remove project root directories in preferences |
| F6 | Search bar to filter projects by name |
| F7 | Remember last-opened project across sessions |

### 5.2 Report Viewer

**Purpose:** View individual reports with full fidelity.

| ID | Requirement |
|----|------------|
| F8 | Load reports in iframes via `addResourcePath()` (same origin, no CORS) |
| F9 | Reports render identically to standalone — same CSS, JS, interactivity |
| F10 | Tab bar for switching between reports (matches single-file hub UX) |
| F11 | Bridge injection: hide report headers, sticky navs |
| F12 | Lazy-load iframes on first tab activation |
| F13 | LRU eviction: max 5 active iframes, unload least recently used |
| F14 | Support all current and future Turas report types |
| F15 | Loading indicator while iframe initialises |

### 5.3 Pin Board

**Purpose:** Curate findings from across reports.

| ID | Requirement |
|----|------------|
| F16 | Central pin board tab (same position as single-file hub) |
| F17 | Pin capture via existing MutationObserver + monkey-patch mechanisms |
| F18 | Source report badge on each pin (e.g., "Brand Tracker", "Crosstabs") |
| F19 | Pinned charts: full SVG with resolved CSS variables |
| F20 | Pinned tables: render in hidden iframe with source CSS, capture as high-res PNG (3x) |
| F21 | Each pin: title, subtitle, chart, table, editable insight text |
| F22 | Drag-and-drop reordering |
| F23 | Section dividers for narrative structure |
| F24 | Markdown in insights: **bold**, *italic*, ## headings, > blockquotes, - bullets |
| F25 | Pin count badge on tab |
| F26 | Delete pin with confirmation |

### 5.4 Persistence

| ID | Requirement |
|----|------------|
| F27 | Pins stored in IndexedDB for fast UI |
| F28 | Pins backed up to `{project}/.turas_pins.json` sidecar file |
| F29 | Annotations backed up to `{project}/.turas_annotations.json` |
| F30 | JSON sidecars are source of truth; IndexedDB is cache |
| F31 | Auto-save on every change (debounced 500ms) |
| F32 | Sidecar files include version number and last_modified timestamp |
| F33 | Persist across browser sessions, app restarts, cache clears |

**Sidecar schema:**

```json
{
  "version": 1,
  "last_modified": "2026-03-22T14:30:00Z",
  "turas_version": "1.0",
  "pins": [
    {
      "id": "pin-1711100000-abc12",
      "type": "pin",
      "source": "tracker",
      "sourceLabel": "Brand Health Tracker",
      "title": "Q05 - Overall Satisfaction",
      "subtitle": "Top-2 box score by segment",
      "insightText": "## Key Finding\n\nSatisfaction dropped **3pp**...",
      "chartSvg": "<svg ...>...</svg>",
      "tableHtml": "<table ...>...</table>",
      "tablePng": "data:image/png;base64,...",
      "pngDataUrl": "data:image/png;base64,...",
      "pinMode": "all",
      "timestamp": 1711100000000
    }
  ],
  "sections": [
    {
      "id": "section-1711100000-xyz",
      "type": "section",
      "title": "Brand Performance",
      "position": 0
    }
  ]
}
```

### 5.5 Export Manager

| ID | Requirement |
|----|------------|
| F34 | **Export to PowerPoint (.pptx)** via `officer` R package |
| F35 | PPTX: title slide with project name, date, branding |
| F36 | PPTX: one slide per pin (title, chart image, table, insight text) |
| F37 | PPTX: section dividers become section header slides |
| F38 | PPTX: branded template with configurable colours and logo |
| F39 | **Export individual pin as PNG** (3x resolution, SVG-native) |
| F40 | **Export all pins as PNGs** (ZIP download) |
| F41 | **Generate single-file hub** via existing `combine_reports()` |
| F42 | Export progress indicator |

**PPTX table rendering tiers:**

| Tier | Method | When |
|------|--------|------|
| A | Native PPTX table via `officer::body_add_table()` | Simple tables (no merged cells, basic styling) |
| B | Styled HTML rendered by officer | Moderate complexity |
| C | PNG fallback (high-res raster) | Complex tables with merged cells, heavy styling |

Auto-detect tier based on table complexity. User doesn't choose.

### 5.6 Cross-Project Search (v1.1)

| ID | Requirement |
|----|------------|
| F43 | Full-text search across pin titles, insights, report metadata |
| F44 | Results show: project name, report name, pin title, matching snippet |
| F45 | Click result to open project and navigate to pin/report |
| F46 | R-side builds search index on disk; browser caches subset |

**Deferred to v1.1.** Not blocking initial release.

### 5.7 Preferences

| ID | Requirement |
|----|------------|
| F47 | Configurable project root directories |
| F48 | Default brand colour and accent colour |
| F49 | Default logo path for exports |
| F50 | Stored in `~/.turas/hub_app_config.json` |

---

## 6. Frontend Structure

```
modules/report_hub/app/
├── hub_app_ui.R              # Shiny UI definition for hub panel
├── hub_app_server.R          # Shiny server logic
├── hub_app_services.R        # R-side service functions
│                              # (project scanning, PPTX export, sidecar I/O)
├── static/
│   ├── index.html            # Hub App HTML shell (loaded in Shiny iframe or panel)
│   ├── css/
│   │   └── hub_app.css       # App styles (extends hub_styles.css)
│   └── js/
│       ├── app.js            # App initialisation, routing
│       ├── project_browser.js # Project listing and navigation
│       ├── report_viewer.js  # Iframe management, bridge injection
│       ├── pin_board.js      # Pin display, drag-drop, editing
│       ├── export_manager.js # PNG export triggers, PPTX request to R
│       ├── state.js          # IndexedDB wrapper, sidecar sync via Shiny
│       └── utils.js          # Shared utilities
└── templates/
    └── hub_pptx_template.pptx  # Branded PowerPoint template for officer
```

**No build step.** All JS is vanilla ES5/ES6, loaded directly. Consistent with all Turas reports.

**Reuse from existing hub:**
- `hub_pinned.js` — pin capture, SVG compression, rendering logic
- `hub_navigation.js` — bridge injection, MutationObserver, iframe management
- `hub_id_resolver.js` — namespace resolution
- `hub_styles.css` — colour tokens, card styling, typography

These are adapted (not copied wholesale) — the Hub App loads reports from filesystem instead of base64, but the pin/bridge/rendering logic is the same.

---

## 7. Shiny Integration

### 7.1 Launch Flow

The Hub App appears as a panel within the existing Turas launcher, not a separate app:

```r
# In launch_turas.R — add Hub App to the module grid
# When user selects "Hub App":
#   1. Switch to hub panel (same Shiny session)
#   2. Register project directories via addResourcePath()
#   3. Frontend JS takes over for browsing/viewing/pinning
#   4. R-side handles: file scanning, PPTX export, sidecar I/O
```

### 7.2 Communication: Frontend ↔ R

| Direction | Mechanism | Use Case |
|-----------|-----------|----------|
| R → Browser | `session$sendCustomMessage()` | Project list, export progress, sidecar data |
| Browser → R | `Shiny.setInputValue()` | Export requests, sidecar saves, project selection |
| Static files | `addResourcePath()` | Report HTML served to iframes |

### 7.3 Resource Path Management

```r
# When user opens a project:
shiny::addResourcePath(
  prefix = "hub-project",
  directoryPath = project_path
)

# Reports load as:
# http://localhost:port/hub-project/Tracker_Report.html
# Same origin as Shiny app — no CORS, full iframe DOM access
```

### 7.4 Docker Compatibility

Single Shiny process means Docker deployment is unchanged:
- One `Dockerfile`, one `EXPOSE` port
- No process orchestration
- No port discovery
- Jess runs Docker container, opens browser, sees Turas with Hub App included

---

## 8. Compatibility with Single-File Hub

The Hub App and single-file hub share code and data formats:

```
Hub App                          Single-File Hub
────────                         ───────────────
.turas_pins.json    ──export──►  combine_reports()  ──►  Combined.html
.turas_annotations  ──────────►  (embeds pins as         (self-contained
                                  hub-pinned-data)        deliverable)

Combined.html       ──import──►  Hub App reads pins
(existing file)                  from hub-pinned-data
                                 and populates pin board
```

**Import:** When opening a project containing a `*_Combined_*.html` file, the Hub App can extract existing pins from the `hub-pinned-data` element.

**Export:** The "Generate Hub File" button calls `combine_reports()` with the current project's reports and injects pin board data.

**Shared JS logic:** Pin capture, SVG compression, bridge injection, and rendering code is shared between the Hub App and single-file hub. Changes propagate to both.

---

## 9. Fast Module Rollout

### 9.1 Why This Is Already Mostly Solved

The pin interception system is **module-agnostic by design:**

1. MutationObserver auto-discovers any element matching `*-pinned-views-data`
2. Bridge injection (header hiding, sticky navs) works on any Turas report
3. Metadata extraction reads standard `<meta>` tags all reports share
4. SVG compression and table capture work on any HTML content

**A new module's report works in the Hub App if it:**
- Has a `<meta name="turas-report-type" content="...">` tag
- Stores pins in an element with ID matching `*-pinned-views-data`
- Uses the standard Turas report header/nav structure

All existing modules already do this (or will, as they follow the shared template).

### 9.2 Module Onboarding Checklist

When a new module produces HTML reports, verify:

- [ ] Report has `<meta name="turas-report-type">` tag
- [ ] Pin store element ID matches `*-pinned-views-data` pattern
- [ ] Report header uses standard structure (for bridge hiding)
- [ ] Report nav uses standard structure (for sticky injection)
- [ ] Open report in Hub App, pin a view, verify it appears on pin board

**Expected effort per module: < 1 hour** (verification only, no code changes if template is followed).

### 9.3 Module Status Matrix

| Module | HTML Report | Pin Store | Hub-Ready |
|--------|:-----------:|:---------:|:---------:|
| Tabs | Yes | Yes | v1 |
| Tracker | Yes | Yes | v1 |
| Confidence | Yes | Yes | v1 |
| Segment | Yes | Yes | v1 (verify) |
| CatDriver | Yes | Yes | v1 (verify) |
| KeyDriver | Yes | Yes | v1 (verify) |
| MaxDiff | Yes | Yes | v1 (verify) |
| Conjoint | Yes | Yes | v1 (verify) |
| Pricing | Yes | Yes | v1 (verify) |
| Weighting | Planned | — | When report exists |
| AlchemerParser | N/A (no report) | — | N/A |

---

## 10. Development Phases

### Phase 1: Core Viewer (3-4 days)

**Goal:** Browse projects, view reports in iframes, bridge injection working.

- [ ] Hub App panel in Shiny launcher (UI shell)
- [ ] Project scanner: find HTML reports in configured directories
- [ ] Project browser: cards with name, report count, last modified
- [ ] Report viewer: iframe loading via `addResourcePath()`
- [ ] Tab bar for switching between reports
- [ ] Bridge injection: header hiding, sticky navs
- [ ] Lazy-load iframes, LRU eviction (max 5)
- [ ] Loading indicators

**Deliverable:** Can browse projects and view all reports with full fidelity.

### Phase 2: Pin Board (3-4 days)

**Goal:** Pin from reports, curate on pin board, persist across sessions.

- [ ] Pin interception from iframes (reuse existing MutationObserver logic)
- [ ] Pin board UI: cards with source badges, titles, charts, tables, insights
- [ ] Section dividers
- [ ] Drag-and-drop reordering
- [ ] Markdown insight editing (double-click to edit, blur to save)
- [ ] IndexedDB persistence
- [ ] JSON sidecar file backup (via Shiny `session$sendCustomMessage` → R-side write)
- [ ] Pin count badge
- [ ] High-fidelity table rendering (hidden iframe + source CSS + canvas capture)

**Deliverable:** Full pin workflow from any report, persisted across sessions.

### Phase 3: Export (2-3 days)

**Goal:** Export pins to PowerPoint, PNG, and single-file hub.

- [ ] PNG export per pin (existing SVG-native approach, 3x resolution)
- [ ] PNG export all pins (ZIP)
- [ ] PowerPoint export via `officer`:
  - [ ] Branded template (`hub_pptx_template.pptx`)
  - [ ] Title slide
  - [ ] One slide per pin (chart + table + insight)
  - [ ] Section header slides from dividers
  - [ ] Table tier detection (native → HTML → PNG fallback)
- [ ] Generate single-file hub via `combine_reports()`
- [ ] Export progress indicator

**Deliverable:** Client-ready PowerPoint decks and hub files from pin board.

### Phase 4: Polish & Rollout (2-3 days)

**Goal:** Verify all modules, preferences, error handling, Jess-readiness.

- [ ] Verify every report type loads and pins correctly (module matrix above)
- [ ] Preferences panel (project roots, brand colours, logo)
- [ ] Import pins from existing single-file hubs
- [ ] Error handling: missing reports, corrupt JSON, export failures
- [ ] Console logging (TRS-compliant, visible in Shiny console)
- [ ] Cross-browser testing: Chrome, Safari, Edge, Firefox
- [ ] Performance testing: 10 reports, 50+ pins

**Deliverable:** Production-ready Hub App.

### Phase 5: Search & Enhancements (v1.1, separate)

- [ ] Cross-project search
- [ ] Import from existing `.turas_pins.json` files
- [ ] Batch operations on pins
- [ ] Dark mode (if requested)

**Total estimated effort: 10-14 days for v1**

---

## 11. Error Handling

All errors follow TRS conventions and output to console:

```r
# R-side (in hub_app_services.R)
scan_project_dir <- function(dir_path) {
  if (!dir.exists(dir_path)) {
    cat("\n=== TURAS HUB ERROR ===\n")
    cat("Code: IO_DIR_NOT_FOUND\n")
    cat("Path:", dir_path, "\n")
    cat("Fix: Check the directory exists and is accessible\n")
    cat("========================\n\n")
    return(list(status = "REFUSED", code = "IO_DIR_NOT_FOUND"))
  }
  # ...
}
```

```js
// Frontend (in app.js)
function handleError(context, error) {
  console.error(`[Hub App] ${context}:`, error);
  showNotification(`Error: ${context}`, 'error');
}
```

**Failure modes and recovery:**

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Missing report file | File not found when loading iframe | Show placeholder card, log to console |
| Corrupt sidecar JSON | JSON parse fails | Restore from IndexedDB cache, warn user |
| IndexedDB unavailable | Feature detection on init | Fall back to sidecar-only (R-side read/write) |
| Export failure (PPTX) | officer throws error | Partial export + error report, log details |
| Iframe load timeout | 10s timeout | Show retry button, suggest checking file path |

---

## 12. Security

- Shiny binds to `127.0.0.1` (localhost only) — no network access
- No authentication needed (local use only)
- `addResourcePath()` scoped to configured project directories only
- No directory traversal: R-side validates all paths against allowed roots
- Report HTML served read-only (no write access)
- Docker deployment: single container, no exposed internal ports

---

## 13. Dependencies

### New R Packages

| Package | Purpose | CRAN | Risk |
|---------|---------|:----:|------|
| **officer** | PowerPoint generation | Yes | Low — mature, widely used in enterprise R |

### Existing R Packages (already in renv)

| Package | Purpose |
|---------|---------|
| shiny | Application server |
| jsonlite | JSON sidecar I/O |
| htmltools | HTML utilities |
| base64enc | Image encoding |

### Frontend

**Zero external dependencies.** All vanilla HTML/CSS/JS. IndexedDB is built into all modern browsers.

**Note:** Plumber is NOT required. Removed from dependency list.

---

## 14. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| iframe CORS with `addResourcePath()` | Reports won't load | Verified: same-origin serving via Shiny works. Tested pattern. |
| Large reports (>10MB) slow iframe load | Poor UX | Loading indicator + lazy-load + LRU eviction |
| OneDrive file locking on sidecar writes | Saves fail | Retry with backoff; warn user; IndexedDB as fallback |
| Browser IndexedDB quota | Pins lost | JSON sidecar is source of truth; IndexedDB is cache |
| officer can't render complex tables | Broken PPTX slides | Three-tier fallback: native table → HTML → PNG |
| New module doesn't follow pin pattern | Pins don't forward | Module onboarding checklist; auto-discovery fallback |
| Shiny session timeout during long work | State lost | IndexedDB + sidecar persistence survives session restart |

---

## 15. Testing Strategy

### 15.1 R-Side (testthat)

- Project scanner: finds reports, handles missing dirs, Unicode paths
- Sidecar I/O: read/write JSON, handle corruption, version migration
- PPTX export: correct slide count, images render, template applied
- Integration with `combine_reports()`: pins transfer correctly

### 15.2 Frontend (manual + structured)

- Project browser: scan, filter, navigate, remember last project
- Report viewer: load tabs, tracker, confidence reports; verify rendering matches standalone
- Pin board: pin from each module type, reorder, edit insight, save/reload
- Export: PNG fidelity, PPTX opens correctly
- Cross-browser: Chrome, Safari, Edge, Firefox
- Performance: 10 reports, 50 pins, interactions under 100ms

### 15.3 Module Rollout Testing

For each module type:
- [ ] Report loads in iframe
- [ ] Bridge injection works (header hidden, nav sticky)
- [ ] Pin a view → appears on pin board with correct source badge
- [ ] Pin includes chart SVG and/or table HTML
- [ ] Insight text editable and persisted
- [ ] PNG export of pin matches visual

---

## 16. Out of Scope (v1.0)

- Multi-user collaboration (real-time co-editing)
- Cloud deployment (stays local + Docker)
- Dark mode
- Mobile responsive design
- Version history for annotations
- AI-assisted insight generation
- Cross-project search (deferred to v1.1)
- Local telemetry / usage tracking

---

## 17. Success Criteria

The Hub App is production-ready when:

1. Analyst can launch it from the Turas Shiny GUI — one click
2. Project browser finds and displays all report-containing project folders
3. Reports from tabs, tracker, and confidence load with full fidelity
4. Pins from every loaded report type forward correctly to the pin board
5. Pinned tables render with visual fidelity matching standalone reports
6. Insights are editable, persist across sessions, sync to sidecar files
7. PowerPoint export produces a client-ready deck with charts, tables, and insights
8. "Generate Hub File" produces a valid single-file hub with all pins included
9. Works reliably on Chrome, Safari, Edge, and Firefox
10. Jess can use it without developer assistance
11. New module reports plug in with verification only (no Hub App code changes)

---

## 18. Glossary

| Term | Definition |
|------|-----------|
| **Hub App** | The Shiny-native working environment (this spec) |
| **Single-file hub** | Self-contained HTML deliverable produced by `combine_reports()` |
| **Individual report** | Standalone HTML report from one module (e.g., tabs, tracker) |
| **Pin** | A captured view (chart + table + insight) from a report |
| **Sidecar file** | `.turas_pins.json` / `.turas_annotations.json` stored alongside reports |
| **Bridge** | JS injected into report iframes for header hiding, nav fixing, pin forwarding |
| **LRU eviction** | Unloading least-recently-used iframes to manage memory |

---

*This specification supersedes TURAS_HUB_APP_SPEC.md (v1). It will be updated as development progresses.*

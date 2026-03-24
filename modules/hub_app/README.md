# Hub App

## Overview

The Hub App is the **analyst working environment** for the Turas platform. It provides a browser-based interface for browsing Turas projects, viewing reports with full CSS fidelity, curating findings via a pin board, and exporting to PowerPoint or PNG.

**Key distinction from Report Hub:**
- **Report Hub** (`modules/report_hub/`) = single-file HTML deliverable sent to clients
- **Hub App** (`modules/hub_app/`) = working environment for analysts to browse, pin, annotate, compare, and export

Clients never see the Hub App. They receive standalone HTML files or combined hub files.

## Purpose

- **Project Discovery**: Scans configurable directories for Turas projects (by `<meta name="turas-report-type">` tag or Hub config files)
- **Report Viewer**: Load and view Turas HTML reports in iframes with full CSS/JS fidelity
- **Pin Board**: Pin charts, tables, and insights from across reports into a curated collection
- **Export Manager**: Generate PowerPoint decks, PNG ZIPs, or individual PNGs from pinned items
- **Annotations**: Add markdown insights to pinned views (bold, italic, headings, bullets, blockquotes)

## Usage

### From the Turas Launcher

The Hub App is available as a tile in the main `launch_turas.R` launcher grid.

### Standalone

```r
setwd("/path/to/Turas")
source("modules/hub_app/00_main.R")
launch_hub_app()

# With custom project directories
launch_hub_app(project_dirs = c("~/Projects", "~/OneDrive/Reports"))
```

### API

```r
launch_hub_app(
  project_dirs = c("~/Documents"),  # Directories to scan
  port = NULL,                       # Auto-select available port
  open_browser = TRUE                # Open browser on launch
)
```

## Architecture

```
hub_app/
├── 00_guard.R                  # TRS v1.0 guard layer — validates directories
├── 00_main.R                   # Main entry point (launch_hub_app)
├── run_hub_app_gui.R           # Shiny application (UI + server)
├── app/
│   ├── index.html              # Frontend SPA template
│   ├── css/
│   │   └── hub_app.css         # Responsive styling with print & modal CSS
│   └── js/
│       ├── app.js              # Core app init, Shiny bridge, view routing
│       ├── state.js            # IndexedDB + sidecar persistence, last-project memory
│       ├── project_browser.js  # Project grid, module badges, search filter
│       ├── report_viewer.js    # Tabbed iframes, lazy loading, LRU eviction
│       ├── pin_board.js        # Pin curation, drag-drop, insights, table PNG capture
│       ├── export_manager.js   # PPTX, PDF, PNG ZIP, individual PNG, hub generation
│       ├── annotations.js      # Project-level executive summary, background, notes
│       ├── preferences.js      # Settings modal UI
│       └── search.js           # Cross-project search overlay
├── assets/
│   └── turas_template.pptx     # Branded PowerPoint template
├── lib/
│   ├── project_scanner.R       # Scan directories for Turas projects
│   ├── export_pptx.R           # PowerPoint generation via officer package
│   ├── hub_generator.R         # Auto-generate single-file combined hub
│   ├── search_index.R          # Cross-project search indexing and query
│   ├── preferences.R           # Read/write ~/.turas/hub_app_config.json
│   └── create_branded_template.R # One-time PPTX template generator
├── docs/
│   ├── TECHNICAL_DOCS.md       # Architecture, data flows, component reference
│   └── USER_MANUAL.md          # End-user guide for all features
└── tests/
    ├── testthat/
    │   ├── test_guard.R             # Guard layer tests (12 tests)
    │   ├── test_project_scanner.R   # Scanner + utility tests (16 tests)
    │   ├── test_export_pptx.R       # PPTX export tests (34 tests)
    │   ├── test_integration.R       # End-to-end flow tests (44 tests)
    │   ├── test_search_index.R      # Search index + query tests (39 tests)
    │   ├── test_preferences.R       # Preferences save/load tests (28 tests)
    │   └── test_hub_generator.R     # Hub generation guard tests (11 tests)
    └── fixtures/
        └── synthetic_data/
            └── generate_test_data.R # Mock project/pin data generator
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                 Shiny App (single process)                   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            Hub App (iframe inside Shiny)               │   │
│  │                                                       │   │
│  │  ┌───────────┐ ┌──────────┐ ┌──────────────┐        │   │
│  │  │ Project   │ │ Report   │ │ Pin Board /  │        │   │
│  │  │ Browser   │ │ Viewer   │ │ Export Mgr   │        │   │
│  │  └───────────┘ └──────────┘ └──────────────┘        │   │
│  │                                                       │   │
│  │  ┌─────────────────────────────────────────────────┐  │   │
│  │  │         Shared State (IndexedDB + sidecar)       │  │   │
│  │  └─────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  R-side services:                                           │
│  ├── addResourcePath() — serve report HTML files            │
│  ├── officer — PowerPoint generation from pins              │
│  └── JSON sidecar I/O — read/write .turas_pins.json        │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### Project Scanner (`lib/project_scanner.R`)
- Scans configurable root directories (up to 3 levels deep)
- Detects Turas projects via `<meta name="turas-report-type">` meta tag
- Also detects projects with `*_Report_Hub_Config.xlsx` files
- Groups reports by module type with coloured badges
- Skips hidden directories, `node_modules`, `renv`, `.git`, `tests`

### Report Viewer (`app/js/report_viewer.js`)
- Reports loaded in iframes via `addResourcePath()` (same-origin, no CORS)
- Full CSS/JS fidelity — reports render identically to standalone
- Tab bar for switching between reports
- Lazy-load: iframes loaded on first tab activation
- LRU eviction: max 5 iframes loaded simultaneously
- Bridge injection: hides report headers, makes nav strips sticky
- Pin forwarding: MutationObserver intercepts pins from reports

### Pin Board (`app/js/pin_board.js`)
- Collects pins from report iframes via bridge (MutationObserver)
- Source badges colour-coded by module type
- Drag-and-drop reordering
- Section dividers for narrative structure
- Editable markdown insights (double-click to edit, blur to save)
- SVG compression for efficient storage
- Persists to IndexedDB (fast) and `.turas_pins.json` sidecar (source of truth)

### Export Manager (`app/js/export_manager.js` + `lib/export_pptx.R`)
- **PowerPoint (.pptx)**: Title slide, section headers, pin slides with chart PNGs and text. Uses branded Turas template.
- **PDF**: Print-optimised layout opened in new window via `window.print()`. Clean, professional styling.
- **PNG ZIP**: All pin charts rendered at 3x resolution, packaged as ZIP
- **Individual PNG**: Per-pin SVG→Canvas→PNG export at 3x resolution (download button on each pin card)
- **Hub Generation**: Auto-generate a single-file combined hub from the current project's reports (calls `combine_reports()`)
- Progress indicator with 30-second timeout safety

### State Management (`app/js/state.js`)
- **IndexedDB**: Fast browser-side cache (immediate reads)
- **JSON sidecar**: `.turas_pins.json` in project directory (source of truth, syncs to OneDrive)
- Flow: On project open → R reads sidecar → sends to browser → browser updates IndexedDB + UI
- Debounced saves (500ms) to both IndexedDB and sidecar

### Table PNG Capture (`app/js/pin_board.js`)
- When a pin with table HTML is captured, a hidden iframe renders the table with the source report's CSS
- Canvas captures at 3x resolution via SVG foreignObject technique
- The resulting PNG is stored on the pin for display fidelity
- Raw `tableHtml` preserved for PPTX export (officer can render HTML tables)

### Cross-Project Search (`lib/search_index.R` + `app/js/search.js`)
- Builds in-memory index from all scanned projects
- Indexes: report metadata, pin titles/insights, annotation text
- Case-insensitive substring matching across title, snippet, source, project name
- Results show project name, type badge, title, and snippet
- Click a result to open the project

### Project Annotations (`app/js/annotations.js`)
- Executive Summary (markdown with live preview)
- Background & Methodology
- Project Notes
- Auto-saves to `.turas_annotations.json` sidecar file

### Preferences (`lib/preferences.R` + `app/js/preferences.js`)
- Settings modal with scan directories, brand/accent colours, logo path
- Persists to `~/.turas/hub_app_config.json`
- Adding scan directories triggers automatic rescan

## Communication Pattern

The Hub App frontend runs inside an iframe hosted by Shiny. Communication uses:

- **Frontend → R**: `Shiny.setInputValue(name, value)` via parent window
- **R → Frontend**: `session$sendCustomMessage(type, data)` with JSON payloads
- **Custom messages**: `hub_projects`, `hub_report_list`, `hub_error`, `hub_save_confirm`, `hub_export_complete`, `hub_pins_loaded`

## Supported Report Types

Tabs, Tracker, Segment, MaxDiff, Conjoint, Pricing, Confidence, Key Driver, Cat Driver, Weighting

## Dependencies

### R Packages
- `shiny` — Web application framework
- `shinyjs` — JavaScript integration
- `shinyFiles` — Native file/directory browser
- `jsonlite` — JSON serialization
- `officer` — PowerPoint generation
- `base64enc` — Image decoding for PNG export

### Frontend
- Vanilla HTML5, CSS3, JavaScript (no frameworks, no build step)
- IndexedDB API (browser native)

## Testing

```r
# Run all Hub App tests
Sys.setenv(TURAS_ROOT = getwd())
testthat::test_dir("modules/hub_app/tests/testthat")

# Run specific test file
testthat::test_file("modules/hub_app/tests/testthat/test_export_pptx.R")
```

**Current coverage**: 223+ tests across 7 test files (guard, scanner, export, integration, search, preferences, hub generator)

## Configuration

The Hub App uses the shared Turas GUI theme (`modules/shared/lib/gui_theme.R`) for consistent visual styling.

## For Operators

If running Turas via Docker, the Hub App provides the main entry point. See the [Operator Guide](../../OPERATOR_GUIDE.md).

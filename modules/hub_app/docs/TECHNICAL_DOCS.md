# Hub App — Technical Documentation

## Architecture Overview

The Hub App is a Shiny-native web application that runs as a panel within the Turas launcher. It uses a **dual-layer architecture**:

- **R Backend** (Shiny server): File I/O, project scanning, PPTX export, search indexing, preferences management
- **JS Frontend** (vanilla HTML/CSS/JS): UI rendering, state management, pin curation, PDF export

Communication flows through Shiny's custom message system:
- **Frontend → R**: `Shiny.setInputValue(name, value)` via the parent window
- **R → Frontend**: `session$sendCustomMessage(type, jsonData)`

### Why Shiny-Native (Not Plumber)

| Factor | Shiny | Plumber |
|--------|-------|---------|
| Entry point | Single app, single port | Two servers, two ports |
| Docker deployment | One process | Orchestration needed |
| CORS / iframe | Same origin via `addResourcePath()` | Same origin (both work) |
| Reactivity | Native | Must poll or use WebSocket |

---

## Component Reference

### R Backend Files

| File | Purpose |
|------|---------|
| `00_main.R` | Entry point: `launch_hub_app()` — validates dirs, launches GUI |
| `00_guard.R` | TRS v1.0 guard: validates directories and project paths |
| `run_hub_app_gui.R` | Shiny app definition (UI + server + all message handlers) |
| `lib/project_scanner.R` | Scans directories for Turas projects via meta tag detection |
| `lib/export_pptx.R` | PowerPoint generation using officer package |
| `lib/hub_generator.R` | Auto-generates Report Hub config and calls `combine_reports()` |
| `lib/search_index.R` | Builds and queries cross-project search index |
| `lib/preferences.R` | Read/write `~/.turas/hub_app_config.json` |
| `lib/create_branded_template.R` | One-time PPTX template generator |

### JS Frontend Files

| File | Purpose |
|------|---------|
| `app/js/app.js` | Core init, Shiny bridge, view routing, event binding |
| `app/js/state.js` | IndexedDB + sidecar persistence, last-project memory |
| `app/js/project_browser.js` | Project grid rendering, module badges, search filter |
| `app/js/report_viewer.js` | Tabbed iframes, lazy loading, LRU eviction, bridge injection |
| `app/js/pin_board.js` | Pin curation, drag-drop, markdown insights, table PNG capture |
| `app/js/export_manager.js` | PPTX, PDF, PNG ZIP, individual PNG, hub generation |
| `app/js/annotations.js` | Project-level executive summary, background, notes |
| `app/js/preferences.js` | Settings modal UI |
| `app/js/search.js` | Cross-project search overlay UI |

---

## Data Flow

### Project Scanning

```
launch_hub_app(dirs)
  → guard_hub_app(dirs)        # Validate directories exist
  → scan_for_projects(dirs)    # Walk subdirs up to depth 3
    → find_project_dirs()      # List dirs with .html files
    → evaluate_project_dir()   # Check for turas-report-type meta tag
      → sniff_report_type()    # Read first 100 lines, extract meta
  → JSON → sendCustomMessage("hub_projects")
  → ProjectBrowser.render()    # JS renders project grid
```

### Report Loading

```
User clicks project tile
  → JS: sendToShiny("hub_open_project", path)
  → R: addResourcePath("hub-project", path)
  → R: get_project_reports(path)
  → R: sendCustomMessage("hub_report_list", json)
  → JS: ReportViewer.render(data)
    → Creates tab bar
    → Creates iframe elements (not loaded)
    → activateReport(firstKey)
      → Sets iframe.src (lazy load)
      → injectBridge() on load:
        - Hides report headers
        - Makes nav strips sticky
        - Sets up MutationObserver for pin stores
```

### Pin Capture

```
User clicks "Pin" in report (inside iframe)
  → Report's savePinnedData() updates pinned-views-data store
  → MutationObserver detects change
  → PinBoard.addPin(source, pinObj)
    → Compresses SVG
    → Adds to items array
    → Triggers table PNG capture (async, hidden iframe)
    → Renders board
    → HubState.save(items)
      → Writes to IndexedDB (fast)
      → Sends JSON to R via Shiny
      → R writes .turas_pins.json sidecar
```

### Table PNG Capture (F18)

```
PinBoard.addPin() detects tableHtml
  → captureTablePng(pinId, tableHtml, sourceKey)
    → Extracts CSS from source report iframe
    → Creates hidden iframe
    → Writes table HTML + CSS into it
    → Waits for render (200ms)
    → SVG foreignObject → Image → Canvas (3x scale) → PNG data URL
    → Updates pin.tablePng
    → Re-renders board
    → Persists
```

### Export Flows

**PPTX:**
```
ExportManager.exportPptx()
  → Renders SVGs to PNG data URLs (canvas, 3x)
  → Sends pin data + PNGs to R
  → R: export_pins_to_pptx()
    → Loads branded template (or default)
    → Creates title slide
    → For each section: section header slide
    → For each pin: title + body text + chart image
    → Saves .pptx
  → Response → toast notification
```

**PDF:**
```
ExportManager.exportPdf()
  → Builds self-contained HTML document with print CSS
  → Opens in new window
  → Triggers window.print()
  → User saves as PDF via browser dialog
```

**Hub Generation:**
```
ExportManager.generateHub()
  → Sends project path + name to R
  → R: generate_hub_from_project()
    → Discovers reports via get_project_reports()
    → Generates temporary Excel config
    → Sources report_hub/00_main.R
    → Calls combine_reports(config)
    → Cleans up temp config
    → Returns output path
```

---

## State Management

### Persistence Layers

1. **IndexedDB** (browser): Fast local cache. Database: `TurasHubApp`, Store: `pins`
2. **JSON sidecar** (filesystem): Source of truth. Files:
   - `.turas_pins.json` — pins and sections
   - `.turas_annotations.json` — executive summary, background, notes
3. **Preferences**: `~/.turas/hub_app_config.json` — scan dirs, colours, logo

### Sync Flow

- On project open: R reads sidecar → sends to browser → browser updates IndexedDB + UI
- On pin change: browser updates IndexedDB → debounced (500ms) → sends JSON to R → R writes sidecar
- On next open: R reads sidecar (truth), browser compares timestamps

### Last-Project Memory

Stored in IndexedDB under key `__hub_last_project__`. On app launch, after projects are scanned, the app checks if the last-opened project is still in the scan results and auto-opens it.

---

## Search System

### Index Structure

Each indexed item has:
- `type`: "report" | "pin" | "section" | "annotation"
- `project_name`, `project_path`
- `source`: report filename or annotation type
- `title`: searchable title
- `snippet`: truncated text (120 chars, markdown stripped)

### Query Matching

Case-insensitive substring matching across: title, snippet, source, project_name. Results include `match_field` indicating which field matched. Max 50 results.

---

## Report Bridge

When a report loads in its iframe, `injectBridge()` performs:

1. **CSS injection**: Hides headers (`.header`, `.tk-header`, etc.), makes nav strips sticky
2. **Pin callback**: Sets `win.pinToHub(data)` on the iframe window
3. **MutationObserver**: Watches `pinned-views-data` stores (known IDs + wildcard fallback)
4. **Late store detection**: If pin store not found after 5s of polling, watches for dynamically created elements (auto-disconnects after 30s)

### Known Pin Store IDs

`pinned-views-data`, `seg-pinned-views-data`, `cd-pinned-views-data`, `kd-pinned-views-data`, `md-pinned-views-data`, `cj-pinned-views-data`, `pr-pinned-views-data`

---

## Testing

### Test Files

| File | Tests | Coverage |
|------|-------|----------|
| `test_guard.R` | 12 | guard_hub_app, guard_project |
| `test_project_scanner.R` | 16 | scan_for_projects, sniff_report_type, utilities |
| `test_export_pptx.R` | 34 | export_pins_to_pptx, strip_markdown, decode_data_url |
| `test_integration.R` | 44 | Full guard→scan→export flow, edge cases |
| `test_search_index.R` | 39 | build_search_index, search_index, truncate_text |
| `test_preferences.R` | 28 | save/load/merge/defaults |
| `test_hub_generator.R` | 11 | Guards + discovery |

**Total: 223+ tests**

### Running Tests

```r
Sys.setenv(TURAS_ROOT = getwd())
testthat::test_dir("modules/hub_app/tests/testthat")
```

### Test Data

`tests/fixtures/synthetic_data/generate_test_data.R` provides:
- `create_mock_project()` — creates project dirs with Turas HTML reports
- `create_mock_export_items()` — creates pin/section data for export testing
- `create_non_turas_html()` — creates non-Turas HTML files for skip-testing

---

## Dependencies

### R Packages (Required)

| Package | Purpose |
|---------|---------|
| shiny | Web application framework |
| shinyjs | JavaScript integration |
| shinyFiles | Native file browser dialogs |
| jsonlite | JSON serialisation |

### R Packages (Feature-specific)

| Package | Feature | Required? |
|---------|---------|-----------|
| officer | PPTX export | Yes, for export |
| base64enc | PNG decoding | Yes, for export |
| openxlsx | Hub generation (config file) | Yes, for hub generation |

### Frontend

Vanilla HTML5/CSS3/JS. No frameworks, no build step, no npm. Uses:
- IndexedDB API (browser native)
- Canvas API (PNG rendering)
- SVG foreignObject (table capture)
- Blob/URL.createObjectURL (image processing)

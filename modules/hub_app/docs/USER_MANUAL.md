# Hub App — User Manual

## Getting Started

### Launching the Hub App

**From the Turas launcher:**
Click the "Hub App" tile in the main launcher grid.

**From R console:**
```r
setwd("/path/to/Turas")
source("modules/hub_app/00_main.R")
launch_hub_app()
```

**With specific directories:**
```r
launch_hub_app(project_dirs = c("~/Documents/Projects", "~/OneDrive/Research"))
```

The Hub App opens in your default browser at a local URL (e.g., `http://127.0.0.1:XXXX`).

---

## Project Browser

When the Hub App launches, it scans your configured directories for Turas projects. A project is any folder containing HTML files with the `turas-report-type` meta tag.

### Project Cards

Each project shows:
- **Project name** (folder name)
- **Module badges** — colour-coded tags showing which report types are present (Tabs, Tracker, MaxDiff, etc.)
- **Report count** — number of Turas HTML reports
- **Last modified** — relative timestamp (e.g., "2 days ago")

### Filtering

Use the search bar to filter projects by name or module type.

### Adding Directories

Click **Add Folder** to choose additional directories to scan. Or use **Settings** (gear icon) to configure scan directories permanently.

### Rescanning

Click **Rescan** to re-scan all configured directories for new or changed projects.

---

## Report Viewer

Click a project card to open it. The report viewer shows:

- **Tab bar** at the top for switching between reports
- **Full-fidelity rendering** — reports look identical to their standalone versions
- **Lazy loading** — only the active report is loaded; others load on first click
- **Memory management** — max 5 reports loaded simultaneously (least-recently-used eviction)

### Navigation

- Report headers are automatically hidden (the Hub App provides its own header)
- Report navigation strips (tabs within reports) are made sticky at the top
- Click the **back arrow** to return to the project browser

---

## Pin Board

The Pin Board lets you collect findings from across reports into a curated collection.

### Pinning from Reports

1. Open a report in the viewer
2. Use the report's built-in **Pin** button on any chart or table
3. The pin appears in the Pin Board side panel

### Opening the Pin Board

Click the **Pins** button in the toolbar. The pin board opens as a side panel alongside the report.

### Pin Cards

Each pin shows:
- **Source badge** — colour-coded by module type (e.g., blue for Tracker)
- **Title** — the chart/table title from the report
- **Subtitle** — additional context (e.g., question code)
- **Insight** — editable markdown text area
- **Chart** — SVG chart (if pinned)
- **Table** — rendered with full CSS fidelity as a PNG capture

### Editing Insights

Double-click the insight area to edit. Supports markdown:
- `**bold**` → **bold**
- `*italic*` → *italic*
- `## Heading` → heading
- `- bullet` → bullet list
- `> quote` → blockquote

Click away (blur) to save.

### Reordering

- Use the **up/down arrows** on each pin card
- Or **drag and drop** cards to reorder

### Section Dividers

Click **Section** in the toolbar to add a section divider for organising your pins into narrative sections. Section titles are editable — click to rename.

### Removing Pins

Click the **X** button on any pin or section to remove it.

### Per-Pin Export

Click the **download arrow** on a pin card to export just that chart as a high-resolution PNG.

---

## Project Annotations

Click the **Notes** button in the toolbar to open the annotations panel. Three editable fields:

- **Executive Summary** — markdown-formatted summary of key findings (rendered preview shown below)
- **Background & Methodology** — project context, sample details, fieldwork dates
- **Project Notes** — working notes, reminders, follow-up items

All text auto-saves to a `.turas_annotations.json` file in your project directory.

---

## Export Options

### PowerPoint (.pptx)

Click **PPTX** to generate a PowerPoint presentation:
- **Title slide** with project name and date
- **Section header slides** for each section divider
- **Content slides** for each pin: title, source badge, insight text, chart image
- Uses the Turas branded template (customisable in `assets/turas_template.pptx`)

The file is saved to your project directory.

### PDF

Click **PDF** to open a print-optimised view of all your pins in a new browser window. Use your browser's print dialog to save as PDF. The layout is clean and professional with:
- Project title and date header
- Section dividers
- Pin cards with charts, insights, and tables

### PNG Export

- **All PNGs**: Click **PNGs** to export all pinned charts as high-resolution PNG files, packaged in a ZIP
- **Individual PNG**: Click the download icon on a specific pin card

### Generate Combined Hub

Click **Hub** to auto-generate a single-file combined HTML report from all the reports in the current project. This calls the Report Hub module's `combine_reports()` function and produces a self-contained HTML file suitable for sending to clients.

---

## Cross-Project Search

Click **Search** in the project browser toolbar to open the search overlay. Search across:
- Report titles and types
- Pin titles and insight text
- Annotation content (executive summaries, backgrounds)
- Project names

Click a search result to open that project directly.

---

## Settings

Click the **gear icon** in the project browser toolbar to open Settings:

- **Scan Directories** — one directory per line; these are scanned for Turas projects
- **Brand Colour** — primary colour used in exports
- **Accent Colour** — secondary colour used in exports
- **Logo Path** — path to a logo file for PPTX exports

Settings are saved to `~/.turas/hub_app_config.json` and persist across sessions.

---

## Persistence

### Where Data is Stored

| Data | Location | Format |
|------|----------|--------|
| Pins & sections | `{project}/.turas_pins.json` | JSON sidecar |
| Annotations | `{project}/.turas_annotations.json` | JSON sidecar |
| Preferences | `~/.turas/hub_app_config.json` | JSON |
| Browser cache | IndexedDB (`TurasHubApp`) | Browser storage |
| Last-opened project | IndexedDB | Browser storage |

### Auto-Save

Pin and annotation changes auto-save after 500ms of inactivity. No manual save needed.

### OneDrive / Cloud Sync

Sidecar files (`.turas_pins.json`, `.turas_annotations.json`) are stored alongside your project files. If your project folders are on OneDrive, Dropbox, or another cloud service, the sidecar files sync automatically.

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Escape` | Close search overlay |

---

## Troubleshooting

### "No Turas projects found"

- Check that your scan directories contain folders with Turas HTML reports
- HTML reports must have a `<meta name="turas-report-type">` tag in the `<head>`
- Click **Add Folder** to add the correct directory
- Check Settings to verify scan directories are configured

### Reports not loading

- Check the R console for error messages
- Ensure the report HTML files are valid and not corrupted
- Try clicking another report tab, then back

### Pins not saving

- Check the R console for "ERROR saving pins" messages
- Ensure the project directory is writable
- Check that the `.turas_pins.json` file is not locked by another process

### PPTX export fails

- Check the R console for officer package errors
- Ensure the `officer` package is installed: `install.packages("officer")`
- Check that the output directory is writable

### Pop-up blocked (PDF export)

- Allow pop-ups for the Hub App URL in your browser settings
- The PDF export opens a new window for printing

### Hub generation fails

- Check the R console for detailed error output
- Ensure the `report_hub` module is present and functional
- Ensure `openxlsx` is installed: `install.packages("openxlsx")`

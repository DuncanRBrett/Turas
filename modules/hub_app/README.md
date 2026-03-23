# Hub App

## Overview

The Hub App is the **project launcher and dashboard** for the Turas platform. It provides a visual interface for browsing, launching, and managing analysis projects across all Turas modules.

## Purpose

- **Project Discovery**: Scans for Turas projects across configured directories
- **Quick Launch**: One-click access to any module's GUI for a selected project
- **Pin Board**: Pin frequently-used projects and reports for fast access
- **Export**: Generate PowerPoint summaries from completed analyses

## Usage

### From the Turas Launcher

The Hub App is available as a tile in the main `launch_turas.R` launcher grid.

### Standalone

```r
setwd("/path/to/Turas")
source("modules/hub_app/run_hub_app_gui.R")
```

## Architecture

```
hub_app/
├── 00_guard.R              # Input validation (TRS compliant)
├── 00_main.R               # Main orchestration
├── run_hub_app_gui.R        # Shiny GUI launcher
├── app/
│   ├── index.html           # HTML template
│   ├── css/                 # Frontend stylesheets
│   └── js/
│       └── pin_board.js     # Pin board interactivity
├── lib/
│   ├── project_scanner.R    # Scan directories for Turas projects
│   └── export_pptx.R       # Export project summaries to PowerPoint
└── tests/
    └── testthat/
        ├── test_guard.R
        └── test_project_scanner.R
```

## Key Features

### Project Scanner
Discovers Turas projects by looking for configuration files (Excel configs, output directories, etc.) across specified paths. Groups projects by module type.

### Pin Board
Users can pin projects and reports to a persistent board for quick access. Pin state persists across sessions.

### PPTX Export
Generates a PowerPoint deck summarising completed analyses, pulling key charts and tables from output directories.

## Configuration

The Hub App uses the shared Turas GUI theme (`modules/shared/lib/gui_theme.R`) for consistent visual styling across the platform.

## For Operators

If you're running Turas via Docker, the Hub App provides the main entry point for project management. See the [Operator Guide](../../OPERATOR_GUIDE.md) for detailed instructions.

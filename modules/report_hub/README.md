# Report Hub Module

Combines multiple standalone Turas HTML reports (Tracker, Crosstabs, Confidence, etc.) into a single unified interactive report with shared navigation, unified pinned views, and a front page overview.

## Architecture

The module uses a **7-step DOM merge pipeline**:

```
Excel Config → Guard Validation → HTML Parsing → Namespace Rewriting
→ Navigation Building → Front Page Assembly → Page Assembly → HTML Output
```

### Pipeline Steps

| Step | File | Purpose |
|------|------|---------|
| 1 | `00_guard.R` | Validates Excel config (Settings + Reports sheets) |
| 2 | `01_html_parser.R` | Extracts CSS, JS, content panels, header, footer, help overlay, metadata from each source HTML |
| 3 | `02_namespace_rewriter.R` | Prefixes all DOM IDs, CSS selectors, and JS functions/variables to prevent conflicts between reports |
| 4 | `04_navigation_builder.R` | Builds two-tier navigation (L1: report tabs, L2: sub-tabs within each report) |
| 5 | `03_front_page_builder.R` | Generates Overview tab with report index cards, executive summary, and qualitative slides |
| 6 | `07_page_assembler.R` | Assembles the final HTML document from all components |
| 7 | `08_html_writer.R` | Writes the self-contained HTML file to disk |

### Key Design Decisions

- **Self-contained output**: All CSS, JS, images, and data are embedded in a single HTML file — no external dependencies.
- **Namespace isolation**: Each report's DOM IDs, CSS selectors, and JS functions are prefixed with the report key (e.g., `tracker--tab-summary`) to prevent conflicts.
- **Help overlay preservation**: Help overlays (? guide) from source reports are extracted separately (they sit outside tab-panel divs) and included in the combined report with their own namespaced ? buttons.
- **Balanced div extraction**: Uses `extract_balanced_div()` — a div-counting approach rather than fragile regex — to reliably extract nested HTML blocks.
- **TRS compliance**: All error paths use structured TRS refusals; no `stop()` calls. Diagnostic messages via `message()` for non-fatal warnings.

## Usage

```r
source("modules/report_hub/00_main.R")

result <- combine_reports(
  config_file = "path/to/Combined_Config.xlsx",
  output_file = "Combined_Report.html"
)

if (result$status == "PASS") {
  browseURL(result$result$output_path)
}
```

### Config Excel Format

The config file requires two sheets:

**Settings sheet** (key-value pairs):
| Field | Value |
|-------|-------|
| project_title | My Combined Report |
| brand_colour | #323367 |
| accent_colour | #CC9900 |
| company_name | Research Co |
| client_name | Brand Inc |
| output_dir | output/ |
| logo_path | assets/logo.png |

**Reports sheet** (one row per report):
| report_key | label | path | type |
|------------|-------|------|------|
| tracker | Brand Tracker | path/to/tracker.html | tracker |
| tabs | Crosstabs | path/to/tabs.html | tabs |

## File Structure

```
modules/report_hub/
├── 00_guard.R              # Input validation (TRS guard layer)
├── 00_main.R               # Main orchestration (combine_reports)
├── 01_html_parser.R        # HTML parsing and component extraction
├── 02_namespace_rewriter.R # DOM/CSS/JS namespace isolation
├── 03_front_page_builder.R # Overview page generation
├── 04_navigation_builder.R # Two-tier navigation
├── 07_page_assembler.R     # Final HTML assembly
├── 08_html_writer.R        # File output
├── assets/
│   └── hub_styles.css      # Hub UI styles (with colour tokens)
├── js/
│   ├── hub_id_resolver.js  # ReportHub namespace and ID resolution
│   ├── hub_navigation.js   # Tab switching and keyboard navigation
│   └── hub_pinned.js       # Unified pinned views management
├── tests/
│   └── testthat/
│       └── test_report_hub.R  # 557 tests
├── docs/
│   └── templates/
│       └── Report_Hub_Config_Template.xlsx  # Config template
└── README.md
```

## Supported Report Types

- **Tracker** — Longitudinal tracking reports
- **Tabs** — Cross-tabulation / crosstabs reports
- **Confidence** — Confidence interval reports
- **Catdriver** — Categorical driver analysis
- **Keydriver** — Key driver correlation analysis
- **Weighting** — Sample weighting reports

## Testing

```r
# Run all tests
testthat::test_dir("modules/report_hub/tests/testthat")

# Current: 557 tests, 0 failures
```

## Dependencies

- `openxlsx` — Excel config reading
- `htmltools` — HTML escaping
- `jsonlite` — JSON serialization for pinned data
- `base64enc` — Logo image encoding

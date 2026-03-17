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

**Slides sheet** (optional — one row per qualitative slide):
| slide_title | content | display_order | image_path |
|-------------|---------|---------------|------------|
| Intro | Title slide content | 1 | path/to/intro.jpg |
| Methodology | Method description... | 2 | |
| Grid | | 3 | path/to/grid.png |

- `slide_title` (required): Displayed as the slide heading
- `content` (optional if `image_path` provided): Markdown-formatted text rendered on the slide. If both content and image_path are empty, the slide is skipped.
- `display_order` (required): Numeric sort order
- `image_path` (optional): Path to an image file (PNG, JPG/JPEG, or SVG). Can be absolute or relative to the config file directory.

### Slide Image Handling

Images specified via `image_path` are automatically **compressed and base64-embedded** into the self-contained HTML — no external links or dependencies.

**Compression pipeline:**
1. Images wider than **800px** are downscaled (bilinear interpolation) to 800px width, preserving aspect ratio
2. PNG and JPEG images are re-encoded as **JPEG at 0.85 quality**
3. SVG images pass through as-is (already lightweight vector format)
4. The compressed image is base64-encoded and embedded directly in the HTML

**Rough compression guide:**

| Original | Dimensions | After resize + JPEG 0.85 |
|----------|-----------|--------------------------|
| 5MB PNG, 3000x2000 | 800x533 | ~40-80KB |
| 5MB PNG, 1200x800 | 800x533 | ~50-100KB |
| 5MB JPEG, 4000x3000 | 800x600 | ~30-60KB |
| 5MB JPEG, 800x600 (already <=800) | No resize | ~80-150KB |

Base64 encoding adds ~33% to the byte size in the HTML file. A typical slide image adds **65-200KB** to the output file.

**Manual image uploads** (via the image button in the report UI) are also compressed client-side: resized to max 800px wide, JPEG 0.7 quality, with a 5MB file size guard.

**Requirements:** The `png`, `jpeg`, and `base64enc` R packages must be available for image compression. If unavailable, images are embedded at their original size as a fallback (larger file size but still functional).

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
- `base64enc` — Logo and slide image encoding
- `png` — PNG image reading (for slide image compression)
- `jpeg` — JPEG image reading/writing (for slide image compression)

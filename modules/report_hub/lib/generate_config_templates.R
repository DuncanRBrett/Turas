# ==============================================================================
# REPORT HUB - Professional Config Template Generator
# ==============================================================================
# Generates polished Excel config template with dropdown validation,
# colour-coded sections, help text, and example data.
#
# Uses shared template infrastructure from modules/shared/template_styles.R
#
# USAGE:
#   source("modules/shared/template_styles.R")
#   source("modules/report_hub/lib/generate_config_templates.R")
#   generate_report_hub_config_template("output/Report_Hub_Config.xlsx")
#
# VERSION: 1.0
# DATE: 2026-03-08
# ==============================================================================


# ==============================================================================
# TEMPLATE GENERATOR
# ==============================================================================

#' Generate Professional Report Hub Config Template
#'
#' Creates a polished Excel config workbook with:
#' - Settings sheet with key-value pairs, dropdowns, and help text
#' - Reports sheet for listing HTML reports to combine
#' - CrossRef sheet for tracker-to-tabs question mapping
#'
#' @param output_path Path for the output Excel file
#' @return Invisible TRUE on success
#' @export
generate_report_hub_config_template <- function(output_path) {

  # --- Load shared infrastructure if not already loaded ---
  if (!exists("write_settings_sheet", mode = "function")) {
    shared_path <- file.path("modules", "shared", "template_styles.R")
    if (!file.exists(shared_path)) {
      # Try relative to this file
      shared_path <- file.path(dirname(sys.frame(1)$ofile %||% "."),
                               "..", "..", "shared", "template_styles.R")
    }
    if (file.exists(shared_path)) {
      source(shared_path)
    } else {
      stop("Cannot find shared template_styles.R. Source it before calling this function.")
    }
  }

  cat("Generating Report Hub config template...\n")

  wb <- openxlsx::createWorkbook()

  # ============================================================================
  # SHEET 1: Settings (key-value format)
  # ============================================================================

  settings_def <- list(
    list(
      section_name = "PROJECT",
      fields = list(
        list(
          name = "project_title",
          required = TRUE,
          default = "Combined Brand Study",
          description = "Main title displayed in the combined report header",
          valid_values_text = "Any descriptive text"
        ),
        list(
          name = "subtitle",
          required = FALSE,
          default = "",
          description = "Optional subtitle displayed below the main title",
          valid_values_text = "Any text or leave blank"
        ),
        list(
          name = "company_name",
          required = TRUE,
          default = "The Research LampPost",
          description = "Company name shown in the 'Prepared by' line",
          valid_values_text = "Your company or research firm name"
        ),
        list(
          name = "client_name",
          required = FALSE,
          default = "",
          description = "Client name shown as 'Prepared for' (optional)",
          valid_values_text = "Client name or leave blank"
        )
      )
    ),
    list(
      section_name = "BRANDING",
      fields = list(
        list(
          name = "brand_colour",
          required = FALSE,
          default = "#323367",
          description = "Primary brand colour for report header and accents",
          valid_values_text = "Hex colour code (e.g., #323367)"
        ),
        list(
          name = "accent_colour",
          required = FALSE,
          default = "#CC9900",
          description = "Secondary accent colour for highlights and tabs",
          valid_values_text = "Hex colour code (e.g., #CC9900)"
        ),
        list(
          name = "logo_path",
          required = FALSE,
          default = "",
          description = "Path to logo image (PNG, JPG, or SVG). Embedded as Base64 in report.",
          valid_values_text = "File path (relative to config or absolute)"
        )
      )
    ),
    list(
      section_name = "OUTPUT",
      fields = list(
        list(
          name = "output_dir",
          required = FALSE,
          default = "",
          description = "Output directory for the combined report. Created if needed.",
          valid_values_text = "Directory path (relative to config or absolute)"
        ),
        list(
          name = "output_file",
          required = FALSE,
          default = "",
          description = "Output filename. Auto-generated from title + date if blank.",
          valid_values_text = "Filename ending in .html (e.g., Brand_Report_2026.html)"
        )
      )
    )
  )

  write_settings_sheet(
    wb = wb,
    sheet_name = "Settings",
    settings_def = settings_def,
    title = "Report Hub Configuration",
    subtitle = "Settings for combining multiple Turas HTML reports"
  )

  cat("  Settings sheet created\n")

  # ============================================================================
  # SHEET 2: Reports (table format)
  # ============================================================================

  reports_columns <- list(
    list(
      name = "report_path",
      width = 45,
      required = TRUE,
      description = "Path to the HTML report file (absolute or relative to this config file)",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = NULL
    ),
    list(
      name = "report_label",
      width = 25,
      required = TRUE,
      description = "Display name shown in navigation tabs (e.g., 'Brand Tracker', 'Crosstabs')",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = NULL
    ),
    list(
      name = "report_key",
      width = 20,
      required = TRUE,
      description = "Unique ID for DOM namespacing. Letters/numbers/hyphens/underscores only.",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = NULL
    ),
    list(
      name = "order",
      width = 10,
      required = TRUE,
      description = "Sort order for navigation tabs (1, 2, 3...)",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = c(1, 99)
    ),
    list(
      name = "report_type",
      width = 18,
      required = FALSE,
      description = "Report type override (auto-detected if blank)",
      dropdown = c("tracker", "tabs", "confidence", "catdriver", "keydriver", "weighting"),
      numeric_range = NULL,
      integer_range = NULL
    )
  )

  reports_examples <- list(
    list(report_path = "output/Brand_Tracker_Report.html",
         report_label = "Brand Tracker",
         report_key = "tracker",
         order = 1,
         report_type = "tracker"),
    list(report_path = "output/Crosstabs_Report.html",
         report_label = "Cross-Tabulations",
         report_key = "tabs",
         order = 2,
         report_type = "tabs"),
    list(report_path = "output/Confidence_Report.html",
         report_label = "Confidence Intervals",
         report_key = "confidence",
         order = 3,
         report_type = "")
  )

  write_table_sheet(
    wb = wb,
    sheet_name = "Reports",
    columns_def = reports_columns,
    title = "Report Files",
    subtitle = "List all HTML reports to combine (one per row, in display order)",
    example_rows = reports_examples,
    num_blank_rows = 15
  )

  cat("  Reports sheet created\n")

  # ============================================================================
  # SHEET 3: CrossRef (table format, optional)
  # ============================================================================

  crossref_columns <- list(
    list(
      name = "tracker_code",
      width = 30,
      required = TRUE,
      description = "Question code in the tracker report (must match tracker's QuestionCode)",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = NULL
    ),
    list(
      name = "tabs_code",
      width = 30,
      required = TRUE,
      description = "Corresponding question code in the tabs/crosstabs report",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = NULL
    ),
    list(
      name = "notes",
      width = 45,
      required = FALSE,
      description = "Optional notes about the mapping (for documentation only)",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = NULL
    )
  )

  crossref_examples <- list(
    list(tracker_code = "Q1_Brand_Awareness",
         tabs_code = "Q1",
         notes = "Brand awareness - same question both waves"),
    list(tracker_code = "Q3_Satisfaction",
         tabs_code = "Q3",
         notes = "Overall satisfaction rating"),
    list(tracker_code = "NPS",
         tabs_code = "Q_NPS",
         notes = "Net Promoter Score")
  )

  write_table_sheet(
    wb = wb,
    sheet_name = "CrossRef",
    columns_def = crossref_columns,
    title = "Cross-Reference Mapping (Optional)",
    subtitle = "Map question codes between tracker and tabs reports for cross-linking",
    example_rows = crossref_examples,
    num_blank_rows = 30
  )

  cat("  CrossRef sheet created\n")

  # ============================================================================
  # SHEET 4: Slides (table format, optional)
  # ============================================================================

  slides_columns <- list(
    list(
      name = "slide_title",
      width = 30,
      required = TRUE,
      description = "Slide title/heading",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = NULL
    ),
    list(
      name = "content",
      width = 60,
      required = TRUE,
      description = "Slide content (supports markdown: **bold**, *italic*, - bullets)",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = NULL
    ),
    list(
      name = "display_order",
      width = 12,
      required = TRUE,
      description = "Display order (1, 2, 3...)",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = c(1, 999)
    ),
    list(
      name = "image_path",
      width = 45,
      required = FALSE,
      description = "Path to slide image (PNG, JPG, SVG). Auto-compressed and embedded as Base64. Relative to config file or absolute.",
      dropdown = NULL,
      numeric_range = NULL,
      integer_range = NULL
    )
  )

  slides_examples <- list(
    list(slide_title = "Key Findings",
         content = "**Main insight:** Customer satisfaction increased significantly in Q1.",
         display_order = 1,
         image_path = ""),
    list(slide_title = "Methodology",
         content = "Online survey conducted Jan-Feb 2025. n=1,000 nationally representative.",
         display_order = 2,
         image_path = "images/methodology_chart.png")
  )

  write_table_sheet(
    wb = wb,
    sheet_name = "Slides",
    columns_def = slides_columns,
    title = "Insight Slides (Optional)",
    subtitle = "Add insight cards with optional images to the Overview tab. Images are auto-compressed to keep file size small.",
    example_rows = slides_examples,
    num_blank_rows = 10
  )

  cat("  Slides sheet created\n")

  # ============================================================================
  # Save workbook
  # ============================================================================

  # Ensure output directory exists
  out_dir <- dirname(output_path)
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  }

  openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)

  cat(sprintf("  Template saved: %s (%s bytes)\n",
              output_path, file.size(output_path)))
  cat("Done!\n")

  invisible(TRUE)
}


#' Generate All Report Hub Templates
#'
#' Convenience function to generate all config templates
#' into a given directory.
#'
#' @param output_dir Directory for template files
#' @return Invisible TRUE on success
#' @export
generate_all_report_hub_templates <- function(output_dir = "modules/report_hub/docs/templates") {

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  generate_report_hub_config_template(
    file.path(output_dir, "Report_Hub_Config_Template.xlsx")
  )

  invisible(TRUE)
}

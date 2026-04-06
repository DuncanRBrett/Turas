# ==============================================================================
# GENERATE_CONFIG_TEMPLATES.R - TURAS Weighting Module
# ==============================================================================
# Creates professional, hardened Excel config templates with:
#   - Data validation (dropdown lists) for all option fields
#   - Visual formatting (branded colours, section grouping)
#   - Help text descriptors for every field
#   - Required/Optional markers
#   - Protected non-editable areas (headers, descriptors)
#   - Every permutation and option documented
#
# USAGE:
#   source("modules/weighting/lib/generate_config_templates.R")
#   generate_weight_config_template("path/to/output/Weight_Config.xlsx")
#   # Or use convenience wrapper:
#   generate_all_weighting_templates("path/to/output/")
#
# DEPENDS ON:
#   modules/shared/template_styles.R (colour palette, style factories,
#   write_settings_sheet, write_table_sheet)
#
# ==============================================================================

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  if (exists("weighting_refuse", mode = "function")) {
    weighting_refuse(
      code = "PKG_OPENXLSX_MISSING",
      title = "Required Package Not Installed",
      problem = "Package 'openxlsx' is required for config template generation but is not installed.",
      why_it_matters = "Cannot generate Excel config templates without the openxlsx package.",
      how_to_fix = "Install with: install.packages('openxlsx')"
    )
  } else {
    cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
    cat("│ Code: PKG_OPENXLSX_MISSING\n")
    cat("│ Package 'openxlsx' is required for config templates.\n")
    cat("│ Fix: install.packages('openxlsx')\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    stop("Package 'openxlsx' is required for config template generation.", call. = FALSE)
  }
}

# Source the shared template infrastructure
# Provides: .TPL_* colour constants, make_*_style() factories,
#           write_settings_sheet(), write_table_sheet()
.weighting_tpl_shared_path <- file.path(
  dirname(dirname(dirname(normalizePath(
    ifelse(exists("owd"), owd, "."), mustWork = FALSE
  )))),
  "modules", "shared", "template_styles.R"
)

# Try multiple resolution strategies for shared template path
if (!file.exists(.weighting_tpl_shared_path)) {
  # Try relative to this script's location
  .weighting_tpl_shared_path <- file.path(
    dirname(dirname(sys.frame(1)$ofile %||% ".")),
    "..", "shared", "template_styles.R"
  )
}
if (!file.exists(.weighting_tpl_shared_path)) {
  # Try from working directory
  .weighting_tpl_shared_path <- file.path("modules", "shared", "template_styles.R")
}
if (file.exists(.weighting_tpl_shared_path)) {
  source(.weighting_tpl_shared_path)
}


# ==============================================================================
# MAIN TEMPLATE GENERATOR
# ==============================================================================

#' Generate Professional Weight Config Template
#'
#' Creates a comprehensive, validated Excel configuration template for the
#' TURAS Weighting Module. The template includes all sheets required for
#' design, rim, rake, and cell weighting with full data validation,
#' dropdown menus, example data, and help text.
#'
#' @param output_path Character, file path for the output .xlsx file
#'
#' @return Invisibly returns TRUE on success, or a TRS refusal list on failure
#'
#' @examples
#' \dontrun{
#'   generate_weight_config_template("output/Weight_Config.xlsx")
#' }
#'
#' @export
generate_weight_config_template <- function(output_path) {

  # --- Input validation ---
  if (missing(output_path) || is.null(output_path) || !is.character(output_path)) {
    return(list(
      status = "REFUSED",
      code = "IO_INVALID_PATH",
      message = "output_path must be a non-empty character string",
      how_to_fix = "Provide a valid file path, e.g. 'output/Weight_Config.xlsx'"
    ))
  }

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(output_dir)) {
      return(list(
        status = "REFUSED",
        code = "IO_DIR_CREATE_FAILED",
        message = sprintf("Cannot create output directory: %s", output_dir),
        how_to_fix = "Check write permissions or specify a different output path"
      ))
    }
  }

  cat("\n=== TURAS Weighting Module: Generating Config Template ===\n")
  cat(sprintf("  Output: %s\n", output_path))

  wb <- createWorkbook()

  # ============================================================================
  # SHEET 1: Settings
  # ============================================================================
  cat("  [1/7] Settings sheet...\n")

  settings_def <- list(
    # --- FILE PATHS section ---
    list(
      section_name = "FILE PATHS",
      fields = list(
        list(
          name = "project_name",
          required = TRUE,
          default = "",
          description = "Name for this weighting project (used in output headers and filenames)",
          valid_values_text = "Any descriptive text, e.g. 'Brand Tracker Q1 2026'"
        ),
        list(
          name = "data_file",
          required = TRUE,
          default = "",
          description = "Path to the input data file (CSV or Excel)",
          valid_values_text = "Relative or absolute file path, e.g. 'data/survey.csv'"
        ),
        list(
          name = "id_column",
          required = FALSE,
          default = "ResponseID",
          description = "Name of the respondent ID column in the data file. Used to produce the weight lookup file (ID + Weight columns only)",
          valid_values_text = "Column name from your data, e.g. 'ResponseID', 'resp_id', 'ID'"
        ),
        list(
          name = "output_file",
          required = FALSE,
          default = "",
          description = "Path for the weight lookup file (ID + weight columns). If blank, auto-generated from data_file",
          valid_values_text = "File path with .csv or .xlsx extension"
        ),
        list(
          name = "save_diagnostics",
          required = FALSE,
          default = "N",
          description = "Save weighting diagnostics report (convergence, efficiency, distribution stats)",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "diagnostics_file",
          required = FALSE,
          default = "",
          description = "Path for the diagnostics output file. Required if save_diagnostics=Y",
          valid_values_text = "File path with .xlsx or .txt extension"
        ),
        list(
          name = "html_report",
          required = FALSE,
          default = "N",
          description = "Generate an interactive HTML diagnostics report",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        ),
        list(
          name = "html_report_file",
          required = FALSE,
          default = "",
          description = "Path for the HTML report file. Required if html_report=Y",
          valid_values_text = "File path with .html extension"
        ),
        list(
          name = "generate_stats_pack",
          required = FALSE,
          default = "Y",
          description = "Generate a diagnostic stats pack workbook alongside main output. The stats pack provides a full audit trail of data received, methods used, assumptions, and reproducibility — designed for advanced partners and research statisticians. Output file is named {output}_stats_pack.xlsx.",
          valid_values_text = "Y or N",
          dropdown = c("Y", "N")
        )
      )
    ),

    # --- BRANDING section ---
    list(
      section_name = "BRANDING",
      fields = list(
        list(
          name = "brand_colour",
          required = FALSE,
          default = "#1e3a5f",
          description = "Primary brand colour for reports and charts (hex format)",
          valid_values_text = "Hex colour code, e.g. #1e3a5f"
        ),
        list(
          name = "accent_colour",
          required = FALSE,
          default = "#2aa198",
          description = "Accent colour for highlights and secondary elements (hex format)",
          valid_values_text = "Hex colour code, e.g. #2aa198"
        ),
        list(
          name = "researcher_name",
          required = FALSE,
          default = "",
          description = "Name of the researcher or research company (shown in report footer)",
          valid_values_text = "Any text"
        ),
        list(
          name = "client_name",
          required = FALSE,
          default = "",
          description = "Name of the client (shown in report header)",
          valid_values_text = "Any text"
        ),
        list(
          name = "logo_file",
          required = FALSE,
          default = "",
          description = "Path to a logo image file (PNG or JPG) for reports",
          valid_values_text = "File path to .png or .jpg image"
        )
      )
    ),

    # --- STUDY IDENTIFICATION section ---
    list(
      section_name = "STUDY IDENTIFICATION",
      fields = list(
        list(
          name = "Project_Name",
          required = FALSE,
          default = "",
          description = "Project name — appears in the stats pack Declaration sheet for identification and sign-off purposes. Leave blank if not using stats pack.",
          valid_values_text = "Free text"
        ),
        list(
          name = "Analyst_Name",
          required = FALSE,
          default = "",
          description = "Analyst name — appears in the stats pack Declaration sheet.",
          valid_values_text = "Free text"
        ),
        list(
          name = "Research_House",
          required = FALSE,
          default = "",
          description = "Research organisation name — appears in the stats pack Declaration sheet. Use your company or white-label partner name.",
          valid_values_text = "Free text"
        )
      )
    )
  )

  write_settings_sheet(
    wb, "General", settings_def,
    title = "TURAS Weighting Module - Configuration",
    subtitle = "Configure file paths and branding options. Required fields are highlighted in orange."
  )

  # ============================================================================
  # SHEET 2: Weight_Specifications
  # ============================================================================
  cat("  [2/7] Weight_Specifications sheet...\n")

  weight_specs_columns <- list(
    list(
      name = "weight_name",
      width = 25,
      required = TRUE,
      description = "Unique identifier for this weight. Used to link targets and advanced settings."
    ),
    list(
      name = "method",
      width = 18,
      required = TRUE,
      description = "Weighting method to apply: design (stratified), rim (iterative proportional fitting), rake (alias for rim), or cell (interlocked).",
      dropdown = c("design", "rim", "rake", "cell")
    ),
    list(
      name = "description",
      width = 40,
      required = FALSE,
      description = "Human-readable description of what this weight corrects for."
    ),
    list(
      name = "apply_trimming",
      width = 16,
      required = FALSE,
      description = "Whether to cap extreme weights after calculation. Y or N.",
      dropdown = c("Y", "N")
    ),
    list(
      name = "trim_method",
      width = 18,
      required = FALSE,
      description = "How to trim weights: cap (fixed multiplier of mean) or percentile (cap at Nth percentile).",
      dropdown = c("cap", "percentile")
    ),
    list(
      name = "trim_value",
      width = 15,
      required = FALSE,
      description = "Trimming threshold. For cap: max ratio (e.g. 5 = 5x mean). For percentile: percentile value (e.g. 95)."
    )
  )

  weight_specs_examples <- list(
    list(
      weight_name = "wgt_demo",
      method = "rim",
      description = "Demographic rim weighting",
      apply_trimming = "Y",
      trim_method = "cap",
      trim_value = 5
    ),
    list(
      weight_name = "wgt_design",
      method = "design",
      description = "Design weight by region",
      apply_trimming = "N",
      trim_method = "",
      trim_value = ""
    ),
    list(
      weight_name = "wgt_cell",
      method = "cell",
      description = "Cell weight gender x age",
      apply_trimming = "Y",
      trim_method = "percentile",
      trim_value = 95
    )
  )

  write_table_sheet(
    wb, "Weight_Specifications", weight_specs_columns,
    title = "Weight Specifications",
    subtitle = "Define each weight to calculate. Each weight_name must be unique and links to its targets in other sheets.",
    example_rows = weight_specs_examples,
    num_blank_rows = 20
  )

  # ============================================================================
  # SHEET 3: Design_Targets
  # ============================================================================
  cat("  [3/7] Design_Targets sheet...\n")

  design_targets_columns <- list(
    list(
      name = "weight_name",
      width = 25,
      required = TRUE,
      description = "Must match a weight_name from Weight_Specifications with method=design."
    ),
    list(
      name = "stratum_variable",
      width = 25,
      required = TRUE,
      description = "Column name in your data that defines the stratification variable (e.g. Region, Cluster)."
    ),
    list(
      name = "stratum_category",
      width = 25,
      required = TRUE,
      description = "Specific value/category within the stratum variable (must match data values exactly)."
    ),
    list(
      name = "population_size",
      width = 18,
      required = TRUE,
      description = "Known population count for this stratum category. Must be a positive number."
    )
  )

  design_targets_examples <- list(
    list(
      weight_name = "wgt_design",
      stratum_variable = "Region",
      stratum_category = "North",
      population_size = 45000
    ),
    list(
      weight_name = "wgt_design",
      stratum_variable = "Region",
      stratum_category = "South",
      population_size = 55000
    )
  )

  write_table_sheet(
    wb, "Design_Targets", design_targets_columns,
    title = "Design Weight Targets",
    subtitle = "Define population sizes for each stratum. Used by method=design weights.",
    example_rows = design_targets_examples,
    num_blank_rows = 50
  )

  # ============================================================================
  # SHEET 4: Rim_Targets
  # ============================================================================
  cat("  [4/7] Rim_Targets sheet...\n")

  rim_targets_columns <- list(
    list(
      name = "weight_name",
      width = 25,
      required = TRUE,
      description = "Must match a weight_name from Weight_Specifications with method=rim or rake."
    ),
    list(
      name = "variable",
      width = 25,
      required = TRUE,
      description = "Column name in your data for this rim dimension (e.g. Gender, AgeGroup)."
    ),
    list(
      name = "category",
      width = 25,
      required = TRUE,
      description = "Specific value within the variable (must match data values exactly)."
    ),
    list(
      name = "target_percent",
      width = 18,
      required = TRUE,
      description = "Target population percentage for this category. All categories within a variable must sum to 100.",
      numeric_range = c(0, 100)
    )
  )

  rim_targets_examples <- list(
    list(
      weight_name = "wgt_demo",
      variable = "Gender",
      category = "Male",
      target_percent = 48.5
    ),
    list(
      weight_name = "wgt_demo",
      variable = "Gender",
      category = "Female",
      target_percent = 51.5
    ),
    list(
      weight_name = "wgt_demo",
      variable = "AgeGroup",
      category = "18-34",
      target_percent = 30
    ),
    list(
      weight_name = "wgt_demo",
      variable = "AgeGroup",
      category = "35-54",
      target_percent = 35
    ),
    list(
      weight_name = "wgt_demo",
      variable = "AgeGroup",
      category = "55+",
      target_percent = 35
    )
  )

  write_table_sheet(
    wb, "Rim_Targets", rim_targets_columns,
    title = "Rim / Rake Weight Targets",
    subtitle = "Define marginal target percentages for each variable. Categories within each variable must sum to 100%.",
    example_rows = rim_targets_examples,
    num_blank_rows = 100
  )

  # ============================================================================
  # SHEET 5: Cell_Targets
  # ============================================================================
  cat("  [5/7] Cell_Targets sheet...\n")

  cell_targets_columns <- list(
    list(
      name = "weight_name",
      width = 25,
      required = TRUE,
      description = "Must match a weight_name from Weight_Specifications with method=cell."
    ),
    list(
      name = "Gender",
      width = 20,
      required = TRUE,
      description = "EXAMPLE column — rename to your first interlocking variable. Values must match data exactly."
    ),
    list(
      name = "AgeGroup",
      width = 20,
      required = TRUE,
      description = "EXAMPLE column — rename to your second interlocking variable. Values must match data exactly."
    ),
    list(
      name = "target_percent",
      width = 18,
      required = TRUE,
      description = "Target population percentage for this cell combination. All cells for a weight must sum to 100.",
      numeric_range = c(0, 100)
    )
  )

  cell_targets_examples <- list(
    list(
      weight_name = "wgt_cell",
      Gender = "Male",
      AgeGroup = "18-34",
      target_percent = 15
    ),
    list(
      weight_name = "wgt_cell",
      Gender = "Male",
      AgeGroup = "35-54",
      target_percent = 17
    ),
    list(
      weight_name = "wgt_cell",
      Gender = "Male",
      AgeGroup = "55+",
      target_percent = 16
    )
  )

  write_table_sheet(
    wb, "Cell_Targets", cell_targets_columns,
    title = "Cell / Interlocked Weight Targets",
    subtitle = "Define joint target percentages for cross-classified cells. All cells for each weight must sum to 100%.",
    example_rows = cell_targets_examples,
    num_blank_rows = 50
  )

  # ============================================================================
  # SHEET 6: Advanced_Settings
  # ============================================================================
  cat("  [6/7] Advanced_Settings sheet...\n")

  advanced_columns <- list(
    list(
      name = "weight_name",
      width = 25,
      required = TRUE,
      description = "Must match a weight_name from Weight_Specifications."
    ),
    list(
      name = "max_iterations",
      width = 18,
      required = FALSE,
      description = "Maximum iterations for convergence (rim/rake methods). Default: 50.",
      integer_range = c(1, 500)
    ),
    list(
      name = "convergence_tolerance",
      width = 22,
      required = FALSE,
      description = "Convergence threshold for rim/rake. Smaller = more precise but slower. Default: 0.001."
    ),
    list(
      name = "force_convergence",
      width = 20,
      required = FALSE,
      description = "If Y, use the last iteration result even if convergence was not achieved.",
      dropdown = c("Y", "N")
    )
  )

  advanced_examples <- list(
    list(
      weight_name = "wgt_demo",
      max_iterations = 50,
      convergence_tolerance = 0.001,
      force_convergence = "N"
    )
  )

  write_table_sheet(
    wb, "Advanced_Settings", advanced_columns,
    title = "Advanced Weighting Settings",
    subtitle = "Optional per-weight overrides for iteration limits and convergence. Leave blank to use defaults.",
    example_rows = advanced_examples,
    num_blank_rows = 10
  )

  # ============================================================================
  # SHEET 7: Notes
  # ============================================================================
  cat("  [7/7] Notes sheet...\n")

  notes_columns <- list(
    list(
      name = "Section",
      width = 25,
      required = TRUE,
      description = "Category for this note. Helps organise methodology documentation.",
      dropdown = c("Assumptions", "Methodology", "Data Quality", "Caveats")
    ),
    list(
      name = "Note",
      width = 80,
      required = TRUE,
      description = "Free-text note documenting assumptions, methodology decisions, or data quality issues."
    )
  )

  notes_examples <- list(
    list(
      Section = "Methodology",
      Note = "Rim weighting applied using iterative proportional fitting"
    ),
    list(
      Section = "Data Quality",
      Note = "3 cases excluded due to missing demographic information"
    )
  )

  write_table_sheet(
    wb, "Notes", notes_columns,
    title = "Weighting Notes & Documentation",
    subtitle = "Record methodology decisions, assumptions, data quality notes, and caveats for audit trail.",
    example_rows = notes_examples,
    num_blank_rows = 20
  )

  # ============================================================================
  # SAVE WORKBOOK
  # ============================================================================

  tryCatch({
    saveWorkbook(wb, output_path, overwrite = TRUE)
    cat(sprintf("  Template saved: %s\n", output_path))
    cat("=== Template generation complete ===\n\n")
    invisible(TRUE)
  }, error = function(e) {
    cat(sprintf("\n=== TURAS ERROR ===\n"))
    cat(sprintf("Code: IO_WRITE_FAILED\n"))
    cat(sprintf("Message: Failed to save template: %s\n", e$message))
    cat(sprintf("Fix: Check file is not open in Excel and path is writable\n"))
    cat(sprintf("==================\n\n"))
    return(list(
      status = "REFUSED",
      code = "IO_WRITE_FAILED",
      message = sprintf("Failed to save template workbook: %s", e$message),
      how_to_fix = "Ensure the file is not open in another application and the directory is writable"
    ))
  })
}


# ==============================================================================
# CONVENIENCE WRAPPER
# ==============================================================================

#' Generate All Weighting Templates
#'
#' Creates the weight configuration template in the specified directory.
#' Convenience wrapper that handles file naming automatically.
#'
#' @param output_dir Character, directory to write the template file into
#'
#' @return Invisibly returns TRUE on success
#'
#' @examples
#' \dontrun{
#'   generate_all_weighting_templates("output/templates/")
#' }
#'
#' @export
generate_all_weighting_templates <- function(output_dir) {

  if (missing(output_dir) || is.null(output_dir) || !is.character(output_dir)) {
    return(list(
      status = "REFUSED",
      code = "IO_INVALID_PATH",
      message = "output_dir must be a non-empty character string",
      how_to_fix = "Provide a valid directory path, e.g. 'output/templates/'"
    ))
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  config_path <- file.path(output_dir, "Weight_Config.xlsx")
  result <- generate_weight_config_template(config_path)

  invisible(result)
}

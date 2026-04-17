# ==============================================================================
# 1BRAND SYNTHETIC EXAMPLE - TOP-LEVEL BUILDER
# ==============================================================================
# Runs all three generators to produce the complete synthetic study:
#   1. Brand_Config.xlsx            (polished, filled)
#   2. Survey_Structure.xlsx        (polished, filled)
#   3. ipk_dryspices_wave1.csv      (300 respondents, full CBM)
#
# USAGE (from the Turas project root):
#   source("modules/brand/examples/1brand/00_build_all.R")
#   build_1brand_synthetic_example()
#
# By default, writes to the OneDrive example folder:
#   ~/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/Examples/1Brand
# ==============================================================================


# ==============================================================================
# DEFAULT OUTPUT DIRECTORY
# ==============================================================================

.default_1brand_output_dir <- function() {
  path.expand(file.path(
    "~", "Library", "CloudStorage", "OneDrive-Personal",
    "DB Files", "TurasProjects", "Examples", "1Brand"
  ))
}


# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

.source_1brand_sources <- function() {

  # Find this script's directory
  this_dir <- tryCatch(dirname(sys.frame(1)$ofile),
                       error = function(e) NULL)
  if (is.null(this_dir) || !dir.exists(this_dir)) {
    this_dir <- file.path("modules", "brand", "examples", "1brand")
  }

  # Shared template infrastructure (write_settings_sheet / write_table_sheet)
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()

  styles_path <- file.path(turas_root, "modules", "shared", "template_styles.R")
  if (!file.exists(styles_path)) {
    styles_path <- file.path("modules", "shared", "template_styles.R")
  }
  if (!file.exists(styles_path)) {
    rlang::abort(
      sprintf("Cannot find template_styles.R (tried %s)", styles_path),
      class = "dep_missing"
    )
  }
  source(styles_path, local = FALSE)

  # Column definitions from the generic brand template generator (we reuse
  # .build_categories_columns, .build_questions_columns, etc.)
  gen_path <- file.path(turas_root, "modules", "brand", "R",
                        "generate_config_templates.R")
  if (!file.exists(gen_path)) {
    gen_path <- file.path("modules", "brand", "R",
                          "generate_config_templates.R")
  }
  if (!file.exists(gen_path)) {
    rlang::abort(
      sprintf("Cannot find generate_config_templates.R (tried %s)", gen_path),
      class = "dep_missing"
    )
  }
  source(gen_path, local = FALSE)

  # Example-specific generators
  for (f in c("01_constants.R", "02_config.R", "03_structure.R",
              "04a_data_helpers.R", "04b_data_respondent.R",
              "04c_data_matrices.R", "04d_data_brand_level.R",
              "04_data.R")) {
    fp <- file.path(this_dir, f)
    if (!file.exists(fp)) {
      rlang::abort(sprintf("Cannot find %s at %s", f, fp),
                   class = "dep_missing")
    }
    source(fp, local = FALSE)
  }

  invisible(TRUE)
}


# ==============================================================================
# MAIN BUILD
# ==============================================================================

#' Build the complete 1Brand synthetic study
#'
#' Generates Brand_Config.xlsx, Survey_Structure.xlsx, and a 300-row CSV
#' in the specified directory. Overwrites existing files.
#'
#' @param output_dir Character. Destination directory. Defaults to the
#'   OneDrive Examples/1Brand folder.
#' @param seed Integer. RNG seed (default 42).
#' @return List with paths to the three generated files.
#' @export
build_1brand_synthetic_example <- function(output_dir = NULL, seed = 42) {

  if (is.null(output_dir)) output_dir <- .default_1brand_output_dir()

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  .source_1brand_sources()

  cat(sprintf("\n=== Building 1Brand synthetic study ===\n"))
  cat(sprintf("Output: %s\n\n", output_dir))

  meta <- ipk_study_meta()

  config_path    <- file.path(output_dir, "Brand_Config.xlsx")
  structure_path <- file.path(output_dir, "Survey_Structure.xlsx")
  data_path      <- file.path(output_dir, meta$data_file_name)

  generate_1brand_config(config_path)
  generate_1brand_structure(structure_path)
  generate_1brand_data(data_path, n = meta$sample_size, seed = seed)

  cat(sprintf("\n=== Build complete ===\n"))
  cat(sprintf("  Files written: 3\n"))
  cat(sprintf("  Sample size:   %d respondents\n", meta$sample_size))
  cat(sprintf("  Brands:        %d\n", length(ipk_brands())))
  cat(sprintf("  CEPs:          %d\n", length(ipk_ceps())))
  cat(sprintf("  Attributes:    %d\n", length(ipk_attributes())))
  cat(sprintf("  DBA assets:    %d\n", length(ipk_dba_assets())))
  cat("\n")

  invisible(list(
    config    = config_path,
    structure = structure_path,
    data      = data_path
  ))
}

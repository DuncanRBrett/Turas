# ==============================================================================
# 3CAT SYNTHETIC EXAMPLE - TOP-LEVEL BUILDER
# ==============================================================================
# Generates all three artefacts for the IPK 3-category brand health study:
#   1. Brand_Config.xlsx         (polished, fully filled)
#   2. Survey_Structure.xlsx     (polished, fully filled)
#   3. ipk_3cat_wave1.xlsx       (300 synthetic respondents)
#
# USAGE (from the Turas project root):
#   source("modules/brand/examples/3cat/00_build_all.R")
#   build_3cat_synthetic_example()
#
# Output directory (default):
#   ~/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/Examples/IPK_3Category
# ==============================================================================


# ==============================================================================
# DEFAULT OUTPUT DIRECTORY
# ==============================================================================

.default_3cat_output_dir <- function() {
  onedrive <- path.expand(file.path(
    "~", "Library", "CloudStorage", "OneDrive-Personal",
    "DB Files", "TurasProjects", "Examples", "IPK_3Category"
  ))
  if (dir.exists(dirname(dirname(onedrive)))) return(onedrive)
  path.expand(file.path("~", "TurasProjects", "Examples", "IPK_3Category"))
}


# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

.source_3cat_deps <- function() {

  # Resolve this script's directory
  this_dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NULL)
  if (is.null(this_dir) || !dir.exists(this_dir)) {
    this_dir <- file.path("modules", "brand", "examples", "3cat")
  }

  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()

  # Shared template infrastructure
  styles_path <- file.path(turas_root, "modules", "shared", "template_styles.R")
  if (!file.exists(styles_path)) {
    styles_path <- file.path("modules", "shared", "template_styles.R")
  }
  if (!file.exists(styles_path)) {
    stop(sprintf("Cannot find template_styles.R. Tried: %s", styles_path))
  }
  source(styles_path, local = FALSE)

  # Generic brand config column definitions (reused from 1brand infrastructure)
  gen_path <- file.path(turas_root, "modules", "brand", "R", "generate_config_templates.R")
  if (!file.exists(gen_path)) {
    gen_path <- file.path("modules", "brand", "R", "generate_config_templates.R")
  }
  if (!file.exists(gen_path)) {
    stop(sprintf("Cannot find generate_config_templates.R. Tried: %s", gen_path))
  }
  source(gen_path, local = FALSE)

  # 3cat example files
  for (f in c("01_constants.R", "02_config.R", "03_structure.R", "04_data.R")) {
    fp <- file.path(this_dir, f)
    if (!file.exists(fp)) stop(sprintf("Cannot find %s at %s", f, fp))
    source(fp, local = FALSE)
  }

  invisible(TRUE)
}


# ==============================================================================
# MAIN BUILD
# ==============================================================================

#' Build the complete IPK 3-category synthetic study
#'
#' Generates Brand_Config.xlsx, Survey_Structure.xlsx, and a 300-row Excel
#' data file in the specified directory. Overwrites existing files.
#'
#' @param output_dir Character. Destination directory. Defaults to the
#'   OneDrive Examples/IPK_3Category folder.
#' @param n    Integer. Total respondents; divided equally across 3 categories
#'   (default: 300).
#' @param seed Integer. RNG seed for reproducible data (default: 42).
#' @return Named list with paths to the three generated files.
#' @export
build_3cat_synthetic_example <- function(output_dir = NULL, n = 300, seed = 42) {

  if (is.null(output_dir)) output_dir <- .default_3cat_output_dir()
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  .source_3cat_deps()

  meta <- cat3_study_meta()

  cat(sprintf("\n=== Building IPK 3-Category synthetic study ===\n"))
  cat(sprintf("Output directory: %s\n\n", output_dir))

  config_path    <- file.path(output_dir, "Brand_Config.xlsx")
  structure_path <- file.path(output_dir, "Survey_Structure.xlsx")
  data_path      <- file.path(output_dir, meta$data_file_name)

  generate_3cat_config(config_path)
  generate_3cat_structure(structure_path)
  generate_3cat_data(data_path, n = n, seed = seed)

  n_brands_total <- sum(sapply(c("DSS", "PAS", "SLD"), function(cc) length(cat3_brands(cc))))
  n_ceps_total   <- sum(sapply(c("DSS", "PAS", "SLD"), function(cc) length(cat3_ceps(cc))))

  cat(sprintf("\n=== Build complete ===\n"))
  cat(sprintf("  Files written:    3\n"))
  cat(sprintf("  Respondents:      %d (%d per category)\n", n, floor(n / 3)))
  cat(sprintf("  Categories:       3 (DSS, PAS, SLD)\n"))
  cat(sprintf("  Brands:           %d total (%d per category, some shared)\n",
              n_brands_total, 10))
  cat(sprintf("  CEPs:             %d total (15 per category, globally unique)\n", n_ceps_total))
  cat(sprintf("  Attributes:       5 (same text per category, category-prefixed codes)\n"))
  cat(sprintf("  DBA assets:       %d (Ina Paarman's Kitchen only)\n",
              length(cat3_dba_assets())))
  cat("\n")

  invisible(list(
    config    = config_path,
    structure = structure_path,
    data      = data_path
  ))
}

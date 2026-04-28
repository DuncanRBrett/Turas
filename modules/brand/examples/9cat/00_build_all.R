# ==============================================================================
# 9CAT SYNTHETIC EXAMPLE - TOP-LEVEL BUILDER
# ==============================================================================
# Generates all three artefacts for the IPK 9-category brand health study:
#   1. Brand_Config.xlsx         (polished, fully filled)
#   2. Survey_Structure.xlsx     (polished, fully filled)
#   3. ipk_9cat_wave1.xlsx       (1200 synthetic respondents — 300 per full category)
#
# Study design:
#   4 FULL CBM categories (DSS, POS, PAS, BAK): complete battery
#   5 AWARENESS-ONLY categories (SLD, STO, PES, COO, ANT): brand awareness only
#
# USAGE (from the Turas project root):
#   source("modules/brand/examples/9cat/00_build_all.R")
#   build_9cat_synthetic_example()
#
# Output directory (default):
#   ~/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/Examples/IPK_9Category
# ==============================================================================


# ==============================================================================
# DEFAULT OUTPUT DIRECTORY
# ==============================================================================

.default_9cat_output_dir <- function() {
  onedrive <- path.expand(file.path(
    "~", "Library", "CloudStorage", "OneDrive-Personal",
    "DB Files", "TurasProjects", "Examples", "IPK_9Category"
  ))
  if (dir.exists(dirname(dirname(onedrive)))) return(onedrive)
  path.expand(file.path("~", "TurasProjects", "Examples", "IPK_9Category"))
}


# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

.source_9cat_deps <- function() {

  this_dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NULL)
  if (is.null(this_dir) || !dir.exists(this_dir)) {
    this_dir <- file.path("modules", "brand", "examples", "9cat")
  }

  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root)) turas_root <- getwd()

  styles_path <- file.path(turas_root, "modules", "shared", "template_styles.R")
  if (!file.exists(styles_path))
    styles_path <- file.path("modules", "shared", "template_styles.R")
  if (!file.exists(styles_path))
    stop(sprintf("Cannot find template_styles.R. Tried: %s", styles_path))
  source(styles_path, local = FALSE)

  gen_path <- file.path(turas_root, "modules", "brand", "R", "generate_config_templates.R")
  if (!file.exists(gen_path))
    gen_path <- file.path("modules", "brand", "R", "generate_config_templates.R")
  if (!file.exists(gen_path))
    stop(sprintf("Cannot find generate_config_templates.R. Tried: %s", gen_path))
  source(gen_path, local = FALSE)

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

#' Build the complete IPK 9-category synthetic study
#'
#' Generates Brand_Config.xlsx, Survey_Structure.xlsx, and a 1200-row
#' Excel data file in the specified directory. Overwrites existing files.
#'
#' @param output_dir Character. Destination directory. Defaults to the
#'   OneDrive Examples/IPK_9Category folder.
#' @param n    Integer. Total respondents; divided equally across 4 full
#'   categories (default: 1200 — matches the portfolio test fixture).
#' @param seed Integer. RNG seed for reproducible data (default: 42).
#' @return Named list with paths to the three generated files.
#' @export
build_9cat_synthetic_example <- function(output_dir = NULL, n = 1200, seed = 42) {

  if (is.null(output_dir)) output_dir <- .default_9cat_output_dir()
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  .source_9cat_deps()

  meta <- cat9_study_meta()

  cat(sprintf("\n=== Building IPK 9-Category synthetic study ===\n"))
  cat(sprintf("Output directory: %s\n\n", output_dir))

  config_path    <- file.path(output_dir, "Brand_Config.xlsx")
  structure_path <- file.path(output_dir, "Survey_Structure.xlsx")
  data_path      <- file.path(output_dir, meta$data_file_name)

  generate_9cat_config(config_path)
  generate_9cat_structure(structure_path)
  generate_9cat_data(data_path, n = n, seed = seed)

  n_full_cats  <- length(Filter(function(c) c$analysis_depth == "full",           cat9_categories()))
  n_aware_cats <- length(Filter(function(c) c$analysis_depth == "awareness_only", cat9_categories()))
  n_brands_full <- sum(sapply(c("DSS","POS","PAS","BAK"), function(cc) length(cat9_brands(cc))))
  n_ceps_total  <- sum(sapply(c("DSS","POS","PAS","BAK"), function(cc) length(cat9_ceps(cc))))

  cat(sprintf("\n=== Build complete ===\n"))
  cat(sprintf("  Files written:         3\n"))
  cat(sprintf("  Respondents:           %d (%d per full category)\n", n, floor(n / 4)))
  cat(sprintf("  Full categories:       %d (DSS, POS, PAS, BAK) — complete CBM battery\n", n_full_cats))
  cat(sprintf("  Awareness-only cats:   %d (SLD, STO, PES, COO, ANT) — brand awareness only\n", n_aware_cats))
  cat(sprintf("  Brands (full cats):    %d total (%d per category, some shared)\n",
              n_brands_full, 10))
  cat(sprintf("  CEPs:                  %d total (15 per full category, globally unique)\n", n_ceps_total))
  cat(sprintf("  Attributes:            5 (same text per category, category-prefixed codes)\n"))
  cat(sprintf("  DBA assets:            %d (Ina Paarman's Kitchen only)\n",
              length(cat9_dba_assets())))
  cat("\n")

  invisible(list(
    config    = config_path,
    structure = structure_path,
    data      = data_path
  ))
}

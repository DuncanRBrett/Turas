# ==============================================================================
# IPK WAVE 1 FIXTURE — ORCHESTRATOR
# ==============================================================================
# Run this file to (re)generate the IPK Wave 1 fixture bundle:
#   * ipk_wave1_data.xlsx       — synthetic respondent-level data
#   * Survey_Structure.xlsx     — tabs-format + brand-extension sheets
#   * Brand_Config.xlsx         — settings / categories / adhoc / audience lens
#
# All three files together form a complete project the brand module can run.
# Determinism: set.seed(IPK_FIXTURE_SEED) — same seed → same fixture.
#
# Usage:
#   source("modules/brand/tests/fixtures/ipk_wave1/00_generate.R")
#   ipk_generate_fixture()
# ==============================================================================

#' Generate the full IPK Wave 1 fixture bundle
#'
#' @param out_dir Destination directory (created if missing).
#' @return Named list of file paths written.
ipk_generate_fixture <- function(out_dir = NULL) {
  here <- ipk_fixture_dir()
  if (is.null(out_dir)) out_dir <- here
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  ipk_source_fixture_helpers()
  set.seed(IPK_FIXTURE_SEED)

  message("[IPK fixture] Building admin + screener (n=", IPK_N_RESPONDENTS, ")")
  admin <- ipk_build_admin_screener()

  message("[IPK fixture] Building cross-cat awareness")
  aware <- ipk_build_cross_cat_awareness(admin$sq1_categories)
  awareness_dss <- attr(aware, "awareness_matrix")[["DSS"]]

  message("[IPK fixture] Building DSS deep dive")
  dss <- ipk_build_dss_deep_dive(admin$focal, awareness_dss,
                                 admin$sq2_categories)

  message("[IPK fixture] Building demographics")
  demo <- ipk_build_demographics()

  # Combine into one wide data frame
  full_data <- cbind(admin$data, aware, dss$data, demo)

  # Coerce numeric-coded columns from character to numeric so the fixture
  # matches AlchemerParser output exactly (parser produces numeric for radio
  # responses with numeric reporting values)
  full_data <- ipk_coerce_numeric_columns(full_data)

  data_path <- file.path(out_dir, "ipk_wave1_data.xlsx")
  ss_path   <- file.path(out_dir, "Survey_Structure.xlsx")
  bc_path   <- file.path(out_dir, "Brand_Config.xlsx")

  message("[IPK fixture] Writing data file: ", data_path)
  openxlsx::write.xlsx(full_data, data_path, overwrite = TRUE)

  message("[IPK fixture] Writing Survey_Structure: ", ss_path)
  ipk_write_survey_structure(ss_path, basename(data_path))

  message("[IPK fixture] Writing Brand_Config: ", bc_path)
  ipk_write_brand_config(bc_path)

  message(sprintf("[IPK fixture] Done. %d rows × %d cols.",
                  nrow(full_data), ncol(full_data)))

  invisible(list(data = data_path,
                 survey_structure = ss_path,
                 brand_config = bc_path,
                 n_rows = nrow(full_data),
                 n_cols = ncol(full_data)))
}

# Source all helper files relative to this script's directory
ipk_source_fixture_helpers <- function() {
  here <- ipk_fixture_dir()
  for (f in c("01_constants.R",
              "02_helpers.R",
              "03_admin_screener.R",
              "04_cross_cat_aware.R",
              "05_dss_deep_dive.R",
              "06_demographics.R",
              "07_structure_writers.R")) {
    source(file.path(here, f), local = FALSE)
  }
}

# Resolve this file's directory regardless of how it was sourced
ipk_fixture_dir <- function() {
  # When sourced via source(), sys.frames()[[1]]$ofile points to this file
  for (frame in rev(sys.frames())) {
    f <- frame$ofile
    if (!is.null(f) && nzchar(f)) return(dirname(normalizePath(f)))
  }
  # Fallback: assume working directory is repo root
  file.path("modules", "brand", "tests", "fixtures", "ipk_wave1")
}

# ==============================================================================
# CROSS-ENGINE PARITY FIXTURE. Island regenerator
# ==============================================================================
#
# Runs the parity project through the real tabs pipeline and writes the v2 data
# layer ("the island") to JSON. That JSON is COMMITTED and is what the JS half
# of the parity harness renders, so the JS suite is testing R's actual output,
# not a hand-authored stub that agrees with R by coincidence.
#
# REGENERATE WITH (from the Turas root):
#   Rscript modules/tabs/tests/fixtures/parity_project/regenerate_parity_island.R
#
# Regenerate only when the fixture project or the writer deliberately changes.
# The R harness (test_cross_engine_stats.R, section R-2) rebuilds the layer in
# memory on every run and compares it to the committed JSON, so a writer change
# that has not been regenerated fails the suite rather than passing silently.
#
# Writes, next to this script:
#   parity_island.json           unweighted, dual alpha, with populations
#   parity_island_weighted.json  the same data on the weighted config
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  path <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "tabs"))) return(normalizePath(path))
    path <- dirname(path)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME or run from the Turas root.")
}

turas_root <- detect_turas_root()
FIXTURE_DIR <- file.path(turas_root, "modules/tabs/tests/fixtures/parity_project")

# The workbooks are gitignored (*.xlsx): the deterministic generator is what
# lives in git, so write them if this is a fresh checkout. Sourced in a local
# environment: the generator defines its own FIXTURE_DIR, which would otherwise
# clobber the absolute one resolved above.
local({
  gen_env <- new.env(parent = globalenv())
  sys.source(file.path(FIXTURE_DIR, "generate_parity_project.R"), envir = gen_env)
  gen_env$ensure_parity_project(FIXTURE_DIR)
})

source(file.path(FIXTURE_DIR, "load_tabs_pipeline.R"))

#' Run one config through the pipeline and return its data layer
build_parity_island <- function(config_file) {
  config_result <- load_crosstabs_config(config_file)
  data_result   <- load_crosstabs_data(config_result)
  analysis      <- run_crosstabs_analysis(
    config_result, data_result,
    checkpoint_frequency = 10, total_column = "Total"
  )
  results <- setNames(
    analysis$all_results,
    vapply(analysis$all_results, function(r) r$question_code, character(1))
  )
  build_data_layer(results, analysis$banner_info, config_result$config_obj,
                   survey_structure = data_result$survey_structure)
}

write_island <- function(config_name, out_name) {
  island <- build_parity_island(file.path(FIXTURE_DIR, config_name))
  out <- file.path(FIXTURE_DIR, out_name)
  jsonlite::write_json(island, out, pretty = TRUE, auto_unbox = TRUE,
                       digits = 8, null = "null", na = "null")
  cat("Wrote", out_name, "-", length(island$questions), "questions\n")
  invisible(island)
}

write_island("Parity_Crosstab_Config.xlsx", "parity_island.json")
write_island("Parity_Crosstab_Config_Weighted.xlsx", "parity_island_weighted.json")

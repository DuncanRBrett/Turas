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
#   parity_micro.json            the SAME run's respondent island (TR.MICRO)
#   parity_micro_weighted.json   the same, weighted
#   parity_cube.json             the SAME run's aggregate cube (TR.CUBE)
#   parity_cube_weighted.json    the same, weighted
#
# The micro / cube outputs are ADDITIVE: the two island files above are written
# by the same call as before and stay byte-identical. They exist so
# computed_parity_tests.mjs can run the engine's computed path against an
# R-built respondent island, and then the cube branch against the micro branch,
# rather than against a hand-authored stub.
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

#' Run one config through the pipeline and return the pieces the gates need
#'
#' Returns the data layer plus everything build_microdata() / build_cube() take,
#' so the caller can write the published layer, the respondent island and the
#' cube from ONE pipeline run. Mirrors the call run_crosstabs.R makes.
build_parity_pieces <- function(config_file) {
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
  dl <- build_data_layer(results, analysis$banner_info, config_result$config_obj,
                         survey_structure = data_result$survey_structure)
  list(data_layer = dl, config_result = config_result,
       data_result = data_result, analysis = analysis)
}

#' The parity cube's shape. Every banner group is declared, plus the questions
#' named here, at k = 5 and order 2, which is the configuration the cube gate
#' enumerates. Q1 and Q3 are the fixture's single-response questions with
#' category rows, which is what a declared filter variable has to be.
PARITY_CUBE_K <- 5L
PARITY_CUBE_ORDER <- 2L
PARITY_CUBE_FILTER_VARS <- c("Q1", "Q3")

write_island <- function(config_name, out_name, micro_name, cube_name) {
  pieces <- build_parity_pieces(file.path(FIXTURE_DIR, config_name))
  island <- pieces$data_layer
  out <- file.path(FIXTURE_DIR, out_name)
  jsonlite::write_json(island, out, pretty = TRUE, auto_unbox = TRUE,
                       digits = 8, null = "null", na = "null")
  cat("Wrote", out_name, "-", length(island$questions), "questions\n")

  # The respondent island from the SAME run. Written with serialize_microdata()
  # so the JS gate parses exactly what a real report embeds.
  micro <- build_microdata(island, pieces$data_result$survey_data,
                           pieces$data_result$survey_structure,
                           pieces$analysis$banner_info,
                           pieces$config_result$config_obj,
                           composite_defs = pieces$data_result$composite_defs)
  writeLines(serialize_microdata(micro), file.path(FIXTURE_DIR, micro_name))
  cat("Wrote", micro_name, "-", if (is.null(micro)) 0 else micro$n, "respondents\n")

  # The cube from the same microdata list. Skipped until cube_writer.R exists,
  # so this script stays runnable while stage 2 is in flight.
  if (exists("build_cube", mode = "function") && !is.null(micro)) {
    cfg <- pieces$config_result$config_obj
    cfg$min_reporting_base <- PARITY_CUBE_K
    cfg$html_report_v2_cube_order <- PARITY_CUBE_ORDER
    cfg$html_report_v2_filter_vars <- PARITY_CUBE_FILTER_VARS
    cube <- build_cube(micro, island, cfg)
    writeLines(serialize_cube(cube), file.path(FIXTURE_DIR, cube_name))
    cat("Wrote", cube_name, "-", length(cube$slices), "slices,",
        cube$blocks_shipped, "blocks shipped,", cube$blocks_refused, "refused\n")
  } else {
    cat("Skipped", cube_name, "- cube_writer.R not present yet\n")
  }
  invisible(island)
}

write_island("Parity_Crosstab_Config.xlsx", "parity_island.json",
             "parity_micro.json", "parity_cube.json")
write_island("Parity_Crosstab_Config_Weighted.xlsx", "parity_island_weighted.json",
             "parity_micro_weighted.json", "parity_cube_weighted.json")

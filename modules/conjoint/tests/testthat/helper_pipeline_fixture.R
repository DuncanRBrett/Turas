# ==============================================================================
# CONJOINT - PIPELINE FIXTURE (robustness gate 2)
# ==============================================================================
#
# Writes a config workbook in the shipped example's shape (Settings and
# Attributes sheets, modules/conjoint/examples/create_example_config.R) and a
# data CSV into a temporary folder, then runs run_conjoint_analysis() on it in
# a child Rscript, the way launch_turas() does. The tests read every number
# back from the files the run wrote.
#
# Sourced explicitly by the pipeline tests (the runner only runs test*.R).
# ==============================================================================

cj_pipe_root <- function() {
  d <- normalizePath(getwd())
  for (i in 1:10) {
    if (file.exists(file.path(d, "launch_turas.R"))) return(d)
    d <- dirname(d)
  }
  stop("Turas root not found above ", getwd())
}

#' Run one conjoint study from a config workbook in a child Rscript
#'
#' @param data Long choice data (one row per alternative).
#' @param attributes Named list of level vectors, first level = baseline.
#' @param settings Named list of Settings rows (added to the defaults below).
#' @param pre Extra R code run in the child before the analysis.
#' @return list(dir, log, status, sheet paths, result_status)
cj_pipe_run <- function(data, attributes, settings = list(), pre = "",
                        out_dir = tempfile("cj_pipe_")) {
  root <- cj_pipe_root()
  dir.create(file.path(out_dir, "output"), recursive = TRUE, showWarnings = FALSE)
  out_dir <- normalizePath(out_dir)
  utils::write.csv(data, file.path(out_dir, "data.csv"), row.names = FALSE)
  base <- list(project_name = "Pipe conjoint", analysis_type = "choice",
               estimation_method = "mlogit", choice_type = "single",
               data_file = "data.csv", output_file = file.path(out_dir, "output", "pipe.xlsx"),
               respondent_id_column = "resp_id", choice_set_column = "task_id",
               alternative_id_column = "alt_id", chosen_column = "chosen",
               confidence_level = "0.95", generate_market_simulator = "TRUE",
               generate_html_simulator = "TRUE", generate_tabs_export = "Y",
               tabs_question_code = "CJIMP", generate_stats_pack = "Y")
  for (k in names(settings)) base[[k]] <- settings[[k]]
  set_df <- data.frame(Setting = names(base), Value = vapply(base, as.character, ""),
                       stringsAsFactors = FALSE)
  attr_df <- data.frame(AttributeName = names(attributes), AttributeLabel = names(attributes),
                        NumLevels = lengths(attributes),
                        LevelNames = vapply(attributes, paste, "", collapse = ", "),
                        stringsAsFactors = FALSE)
  cfg <- file.path(out_dir, "config.xlsx")
  openxlsx::write.xlsx(list(Settings = set_df, Attributes = attr_df), cfg)

  script <- file.path(out_dir, "run.R")
  writeLines(c(
    sprintf("setwd(%s)", deparse(root)),
    "suppressMessages(source('modules/conjoint/R/00_main.R'))",
    pre,
    sprintf("res <- run_conjoint_analysis(%s)", deparse(cfg)),
    sprintf("saveRDS(list(status = res$status, code = res$code, run_status = res$run_result$status,
                          wtp = !is.null(res$wtp_result) || !is.null(res$wtp)), %s)", deparse(file.path(out_dir, "result.rds")))
  ), script)
  log <- system2(file.path(R.home("bin"), "Rscript"), script, stdout = TRUE, stderr = TRUE,
                 env = c(paste0("R_LIBS=", paste(.libPaths(), collapse = .Platform$path.sep)),
                         "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE"))
  res_file <- file.path(out_dir, "result.rds")
  stem <- file.path(out_dir, "output", "pipe")
  list(dir = out_dir, log = log,
       result = if (file.exists(res_file)) readRDS(res_file) else list(status = "CRASHED"),
       workbook = paste0(stem, ".xlsx"),
       island = paste0(stem, "_cj_island.json"),
       simulator = paste0(stem, "_simulator.html"),
       stats_pack = paste0(stem, "_stats_pack.xlsx"),
       tabs_export = paste0(stem, "_tabs_importance.xlsx"))
}

cj_pipe_sheet <- function(path, sheet) {
  openxlsx::read.xlsx(path, sheet = sheet, skipEmptyRows = FALSE)
}

cj_run_status <- function(path) {
  x <- openxlsx::read.xlsx(path, sheet = "Run_Status", colNames = FALSE, skipEmptyRows = FALSE)
  cells <- as.character(unlist(x))
  status_row <- which(x[[1]] == "Status")
  list(status = if (length(status_row)) x[[2]][status_row[1]] else NA_character_,
       text = paste(cells[!is.na(cells)], collapse = "\n"))
}

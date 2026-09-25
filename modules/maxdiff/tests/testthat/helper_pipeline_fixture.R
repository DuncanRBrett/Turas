# ==============================================================================
# MAXDIFF - PIPELINE FIXTURE (robustness gate 2)
# ==============================================================================
#
# Builds a small study with the shipped example's own generator
# (examples/maxdiff/create_maxdiff_example.R: the module's DESIGN mode, then
# responses simulated from known utilities), then runs run_maxdiff() on the
# ANALYSIS config in a child Rscript, the way launch_turas() does. Nothing the
# test session has loaded can stand in for what the module loads itself.
#
# Sourced explicitly by the pipeline tests (the runner only runs test*.R).
# Every file is written under a tempdir(); nothing goes near examples/.
# ==============================================================================

md_pipe_root <- function() {
  d <- normalizePath(getwd())
  for (i in 1:10) {
    if (file.exists(file.path(d, "launch_turas.R"))) return(d)
    d <- dirname(d)
  }
  stop("Turas root not found above ", getwd())
}

md_pipe_stan_ready <- function() {
  requireNamespace("cmdstanr", quietly = TRUE) &&
    !inherits(try(cmdstanr::cmdstan_path(), silent = TRUE), "try-error")
}

#' Build and run one pipeline study in a child Rscript
#'
#' @param n Respondents.
#' @param weighted Add a weight column Wt (values 0.5 / 1 / 2.5 by respondent).
#' @param project_settings,output_settings Named character vectors of rows to
#'   set or add on those config sheets (for example HB_Iterations).
#' @param lib_prepend Library directories placed before the normal ones in the
#'   child (used to hide cmdstanr and force the empirical-Bayes fallback).
#' @return list(dir, log, status, files)
md_pipe_run <- function(n = 90, weighted = TRUE,
                        project_settings = c(), output_settings = c(),
                        lib_prepend = character(0),
                        weight_scale = 1, weight_values = c(0.5, 1, 2.5),
                        item_labels = NULL, data_edits = "",
                        out_dir = tempfile("md_pipe_")) {
  root <- md_pipe_root()
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_dir <- normalizePath(out_dir)
  script <- file.path(out_dir, "run.R")
  status_file <- file.path(out_dir, "final_status.txt")
  dput_chr <- function(x) paste(deparse(x), collapse = "")
  writeLines(c(
    sprintf("setwd(%s)", deparse(root)),
    "options(turas.example.no_run = TRUE)",
    "suppressMessages(source('modules/maxdiff/R/00_main.R'))",
    "source('examples/maxdiff/create_maxdiff_example.R')",
    sprintf("resp <- karoo_default_respondents(n = %d, seed = 2026)", n),
    sprintf("resp$Wt <- %s[(seq_len(nrow(resp)) %%%% 3) + 1] * %s",
            paste(deparse(weight_values), collapse = ""), deparse(weight_scale)),
    sprintf("b <- build_maxdiff_example(%s, %s, respondents = resp, project_name = 'Pipe',",
            deparse(root), deparse(out_dir)),
    sprintf("  file_stem = 'Pipe_MaxDiff', weight_variable = %s, verbose = FALSE)",
            deparse(if (weighted) "Wt" else "")),
    # Rewrite the config from a fresh workbook (never loadWorkbook + save),
    # setting or adding the requested rows.
    "sheets <- openxlsx::getSheetNames(b$config)",
    "all <- lapply(sheets, function(s) openxlsx::read.xlsx(b$config, sheet = s, skipEmptyRows = FALSE))",
    "names(all) <- sheets",
    "set_rows <- function(df, kv) { for (k in names(kv)) { i <- match(k, df[[1]]);",
    "  if (is.na(i)) { df[nrow(df) + 1, 1] <- k; i <- nrow(df) }; df[i, 2] <- kv[[k]] }; df }",
    sprintf("all$PROJECT_SETTINGS <- set_rows(all$PROJECT_SETTINGS, %s)", dput_chr(as.list(project_settings))),
    sprintf("all$OUTPUT_SETTINGS <- set_rows(all$OUTPUT_SETTINGS, %s)", dput_chr(as.list(output_settings))),
    sprintf("relabel <- %s", dput_chr(item_labels)),
    "if (length(relabel)) all$ITEMS$Item_Label[match(names(relabel), all$ITEMS$Item_ID)] <- unname(relabel)",
    # Edits to the respondent data, applied to the data FILE the run reads.
    "dat <- openxlsx::read.xlsx(b$data_file, sheet = 1)",
    data_edits,
    "dwb <- openxlsx::createWorkbook(); openxlsx::addWorksheet(dwb, 'Data'); openxlsx::writeData(dwb, 'Data', dat)",
    "turas_saveWorkbook(dwb, b$data_file, overwrite = TRUE)",
    "wb <- openxlsx::createWorkbook()",
    "for (s in sheets) { openxlsx::addWorksheet(wb, s); openxlsx::writeData(wb, s, all[[s]]) }",
    "turas_saveWorkbook(wb, b$config, overwrite = TRUE)",
    "saveRDS(list(config = b$config, data_file = b$data_file, design_file = b$design_file,",
    "             true_utils = b$true_utils), file.path(dirname(b$config), 'build.rds'))",
    "res <- tryCatch(run_maxdiff(b$config, verbose = FALSE),",
    "  turas_refusal = function(e) { cat('\\nREFUSED:', e$code, '\\n'); NULL })",
    sprintf("writeLines(if (is.null(res)) 'REFUSED' else res$run_result$status %%||%% 'NO_RUN_RESULT', %s)",
            deparse(status_file)),
    "if (!is.null(res)) saveRDS(res$run_result, file.path(dirname(b$config), 'run_result.rds'))"
  ), script)
  libs <- c(lib_prepend, .libPaths())
  log <- system2(file.path(R.home("bin"), "Rscript"), script, stdout = TRUE, stderr = TRUE,
                 env = c(paste0("R_LIBS=", paste(libs, collapse = .Platform$path.sep)),
                         "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE"))
  out <- file.path(out_dir, "Output")
  stem <- file.path(out, "Pipe_MaxDiff_Results")
  list(
    dir = out_dir,
    log = log,
    status = if (file.exists(status_file)) readLines(status_file)[1] else "CRASHED",
    build = if (file.exists(file.path(out_dir, "build.rds"))) readRDS(file.path(out_dir, "build.rds")),
    run_result = if (file.exists(file.path(out_dir, "run_result.rds"))) readRDS(file.path(out_dir, "run_result.rds")),
    workbook = paste0(stem, ".xlsx"),
    island = paste0(stem, "_md_island.json"),
    simulator = paste0(stem, "_simulator.html"),
    stats_pack = paste0(stem, "_stats_pack.xlsx"),
    tabs_export = paste0(stem, "_tabs_shares.xlsx")
  )
}

#' Read a sheet back with blank rows kept (never compact the row index).
md_pipe_sheet <- function(path, sheet) {
  openxlsx::read.xlsx(path, sheet = sheet, skipEmptyRows = FALSE)
}

#' Rebuild the long data from the data and design FILES, independently of
#' the module's reshape: one row per respondent x task x item shown.
md_pipe_long <- function(build, weighted = TRUE) {
  data <- openxlsx::read.xlsx(build$data_file, sheet = 1)
  design <- openxlsx::read.xlsx(build$design_file, sheet = "DESIGN")
  item_cols <- grep("^Item[0-9]+_ID$", names(design), value = TRUE)
  rows <- list()
  for (r in seq_len(nrow(data))) {
    v <- data$Version[r]
    for (t in sort(unique(design$Task_Number))) {
      drow <- design[design$Version == v & design$Task_Number == t, item_cols]
      shown <- as.character(unlist(drow[1, ]))
      shown <- shown[!is.na(shown) & nzchar(shown)]
      best <- data[[sprintf("T%d_Best", t)]][r]
      worst <- data[[sprintf("T%d_Worst", t)]][r]
      rows[[length(rows) + 1]] <- data.frame(
        resp_id = data$RespID[r], version = v, task = t, item_id = shown,
        position = seq_along(shown),
        is_best = as.integer(!is.na(best) & shown == best),
        is_worst = as.integer(!is.na(worst) & shown == worst),
        weight = if (weighted) data$Wt[r] else 1, stringsAsFactors = FALSE)
    }
  }
  list(long = do.call(rbind, rows), data = data)
}

#' Read one Field -> Value row from the stats pack's Assumptions sheet.
md_pipe_stats_value <- function(path, field) {
  x <- openxlsx::read.xlsx(path, sheet = "Assumptions", colNames = FALSE,
                           skipEmptyRows = FALSE)
  hit <- which(x[[1]] == field)
  if (length(hit) == 0) return(NA_character_)
  as.character(x[[2]][hit[1]])
}

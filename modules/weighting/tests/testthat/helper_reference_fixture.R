# ==============================================================================
# WEIGHTING - REFERENCE FIXTURE (robustness gates, 25 Sep 2026)
# ==============================================================================
# A 200-respondent survey whose counts are chosen so every weight the module
# produces can be written down as a fraction by hand, plus a config-workbook
# builder and an independent raking loop. Sourced explicitly by the reference,
# pipeline and adversarial test files (the runner only runs test*.R).
#
# Counts (Region x Gender):
#
#                Male  Female  Total
#   North          70      30    100
#   South          30      30     60
#   East           20      20     40
#   Total         120      80    200
#
# Nothing here calls the weighting engines. The references below are
# arithmetic, or come from code that shares nothing with lib/.
# ==============================================================================

#' The 200-respondent reference survey, rows in a fixed order.
ref_survey <- function() {
  cells <- data.frame(
    Region = c("North", "North", "South", "South", "East", "East"),
    Gender = c("Male", "Female", "Male", "Female", "Male", "Female"),
    n      = c(70, 30, 30, 30, 20, 20),
    stringsAsFactors = FALSE
  )
  rows <- cells[rep(seq_len(nrow(cells)), cells$n), c("Region", "Gender")]
  rownames(rows) <- NULL
  data.frame(id = seq_len(nrow(rows)), rows, stringsAsFactors = FALSE)
}

#' Hand design weights for the fixture, normalised to sum to n = 200.
#'
#' Populations North 30,000, South 40,000, East 30,000 (total 100,000).
#' Raw N/n: North 300, South 2000/3, East 750. Normalising multiplies by
#' 200 / 100,000 = 0.002, giving North 0.6, South 4/3, East 1.5.
#' Check: 100 x 0.6 + 60 x 4/3 + 40 x 1.5 = 60 + 80 + 60 = 200.
ref_design_weight <- function(region) {
  unname(c(North = 0.6, South = 4 / 3, East = 1.5)[region])
}

#' The same design weights at population scale (grossing = Y).
ref_design_weight_grossed <- function(region) {
  unname(c(North = 300, South = 2000 / 3, East = 750)[region])
}

#' Hand cell weights: target% x 200 / cell count.
#'
#'   North Male   14% -> 28 / 70 = 0.4       North Female 16% -> 32 / 30 = 16/15
#'   South Male   19% -> 38 / 30 = 19/15     South Female 21% -> 42 / 30 = 1.4
#'   East  Male   14% -> 28 / 20 = 1.4       East  Female 16% -> 32 / 20 = 1.6
ref_cell_targets <- function() {
  data.frame(
    Region = c("North", "North", "South", "South", "East", "East"),
    Gender = c("Male", "Female", "Male", "Female", "Male", "Female"),
    target_percent = c(14, 16, 19, 21, 14, 16),
    stringsAsFactors = FALSE
  )
}

ref_cell_weight <- function(region, gender) {
  key <- paste(region, gender)
  unname(c(`North Male` = 0.4, `North Female` = 16 / 15,
           `South Male` = 19 / 15, `South Female` = 1.4,
           `East Male` = 1.4, `East Female` = 1.6)[key])
}

#' Rim targets for the fixture, as proportions.
ref_rim_targets <- function() {
  list(
    Region = c(North = 0.30, South = 0.40, East = 0.30),
    Gender = c(Male = 0.48, Female = 0.52)
  )
}

#' Independent raking: iterative proportional fitting written out by hand.
#'
#' Shares no code with survey::calibrate() or lib/rim_weights.R. Starts every
#' weight at 1, then repeatedly scales each category so its weighted share hits
#' its target, holding the total at n. The unique raking solution, so it equals
#' calibrate(calfun = "raking") whenever the weight bounds do not bind.
ref_hand_rake <- function(data, targets, iterations = 2000, tol = 1e-13) {
  w <- rep(1, nrow(data))
  for (it in seq_len(iterations)) {
    w_before <- w
    for (v in names(targets)) {
      total <- sum(w)
      for (k in names(targets[[v]])) {
        in_k <- data[[v]] == k
        w[in_k] <- w[in_k] * targets[[v]][[k]] * total / sum(w[in_k])
      }
    }
    if (max(abs(w - w_before)) < tol) break
  }
  w
}

#' Kish effective n written out, for the reference comments to lean on.
ref_kish <- function(w) {
  w <- w[!is.na(w) & w > 0]
  sum(w)^2 / sum(w^2)
}

#' Build a weighting config workbook for the fixture.
#'
#' @param dir Directory to write into (the config, data and outputs live there)
#' @param specs Weight_Specifications data frame
#' @param design_targets,rim_targets,cell_targets,advanced Optional sheets
#' @param data Survey data frame (default the reference survey)
#' @param html,stats_pack Whether the run writes the HTML report / stats pack
#' @return Named list of paths: config, data, lookup, diagnostics, html,
#'   stats_pack
ref_build_config <- function(dir, specs, design_targets = NULL,
                             rim_targets = NULL, cell_targets = NULL,
                             advanced = NULL, data = ref_survey(),
                             html = TRUE, stats_pack = TRUE,
                             lookup_ext = "xlsx") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  paths <- list(
    config      = file.path(dir, "Weight_Config.xlsx"),
    data        = file.path(dir, "survey.csv"),
    lookup      = file.path(dir, paste0("weights.", lookup_ext)),
    diagnostics = file.path(dir, "weight_diagnostics.xlsx"),
    html        = file.path(dir, "weight_report.html")
  )
  paths$stats_pack <- file.path(dir, "weights_stats_pack.xlsx")

  utils::write.csv(data, paths$data, row.names = FALSE, fileEncoding = "UTF-8")

  general <- data.frame(
    Setting = c("project_name", "data_file", "id_column", "output_file",
                "save_diagnostics", "diagnostics_file", "html_report",
                "html_report_file", "generate_stats_pack"),
    Value = c("Reference fixture", paths$data, "id", paths$lookup,
              "Y", paths$diagnostics, if (html) "Y" else "N",
              paths$html, if (stats_pack) "Y" else "N"),
    stringsAsFactors = FALSE
  )

  wb <- openxlsx::createWorkbook()
  add <- function(name, df) {
    if (!is.null(df)) {
      openxlsx::addWorksheet(wb, name)
      openxlsx::writeData(wb, name, df)
    }
  }
  add("General", general)
  add("Weight_Specifications", specs)
  add("Design_Targets", design_targets)
  add("Rim_Targets", rim_targets)
  add("Cell_Targets", cell_targets)
  add("Advanced_Settings", advanced)
  turas_saveWorkbook(wb, paths$config, overwrite = TRUE)
  paths
}

#' One Weight_Specifications row.
ref_spec <- function(name, method, trim_method = NA, trim_value = NA) {
  data.frame(
    weight_name = name, method = method, description = name,
    apply_trimming = if (is.na(trim_method)) "N" else "Y",
    trim_method = trim_method, trim_value = trim_value,
    stringsAsFactors = FALSE
  )
}

#' Design_Targets rows for the fixture populations.
ref_design_targets <- function(name, populations = c(North = 30000, South = 40000, East = 30000)) {
  data.frame(
    weight_name = name, stratum_variable = "Region",
    stratum_category = names(populations),
    population_size = unname(populations),
    stringsAsFactors = FALSE
  )
}

#' Rim_Targets rows (percentages) from a proportions list.
ref_rim_target_rows <- function(name, targets = ref_rim_targets()) {
  do.call(rbind, lapply(names(targets), function(v) {
    data.frame(weight_name = name, variable = v, category = names(targets[[v]]),
               target_percent = 100 * unname(targets[[v]]),
               stringsAsFactors = FALSE)
  }))
}

#' Run run_weighting.R on a config in a fresh Rscript, the way the CLI does.
#'
#' A child process keeps anything the pipeline sets globally out of the test
#' runner, and it is the level Duncan consumes: a config goes in, files come
#' out. Returns the exit status and the console text.
ref_run_child <- function(config_path, turas_root) {
  script <- file.path(turas_root, "modules", "weighting", "run_weighting.R")
  # The CLI locates its module from the working directory, as it does when
  # run from the Turas root.
  old_wd <- setwd(turas_root)
  on.exit(setwd(old_wd), add = TRUE)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    args = c(shQuote(script), shQuote(config_path)),
    stdout = TRUE, stderr = TRUE,
    env = c(paste0("R_LIBS=", paste(.libPaths(), collapse = .Platform$path.sep)),
            "RENV_CONFIG_AUTOLOADER_ENABLED=FALSE")
  ))
  status <- attr(out, "status") %||% 0L
  list(status = status, console = out)
}

#' Read a whole sheet as text cells, blank rows kept in place.
ref_read_sheet <- function(path, sheet) {
  openxlsx::read.xlsx(path, sheet = sheet, colNames = FALSE,
                      skipEmptyRows = FALSE, skipEmptyCols = FALSE)
}

#' The first filled cell to the right of the cell that equals `label`.
#'
#' Sheets place their labels in different columns (the stats pack Declaration
#' uses B and D), so the label is found wherever it sits.
ref_kv <- function(sheet_df, label) {
  m <- as.matrix(sheet_df)
  hit <- which(trimws(m) == label, arr.ind = TRUE)
  if (nrow(hit) == 0) return(NA_character_)
  r <- hit[1, "row"]
  right <- m[r, seq_len(ncol(m)) > hit[1, "col"]]
  right <- right[!is.na(right) & nzchar(trimws(right))]
  if (length(right) == 0) NA_character_ else trimws(as.character(right[1]))
}

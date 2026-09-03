# ==============================================================================
# TURAS PRICING - EXAMPLE STUDY GENERATOR
# ==============================================================================
# Builds a complete, runnable pricing study for a fictional company, "Karoo
# Coffee Roasters": what should a 250 g bag of their coffee cost? Everything is
# synthetic. No client data is involved at any point.
#
# What it writes into the output folder:
#   Karoo_Pricing_Data.xlsx              one row per respondent
#   Karoo_Pricing_Config.xlsx            Van Westendorp + Gabor-Granger, weighted
#   Karoo_Pricing_Config_Monadic.xlsx    the monadic cell test on the same people
#   Karoo_Pricing_Config_StopEarly.xlsx  Gabor-Granger on a stop-early ladder,
#                                        which the module must refuse by default
#   Karoo_Pricing_Config_StopEarly_Imputed.xlsx  the same ladder with
#                                        GG_Stop_Early_Imputation = NO_AFTER_STOP
#
# The responses are simulated from KNOWN quantities (karoo_pricing_truth), so a
# run can be checked against the truth: the price points the module reports
# should sit inside the bands that function states.
#
# Usage, from the Turas root:
#   Rscript examples/pricing/create_pricing_example.R [turas_root] [out_dir]
# then
#   Rscript -e 'source("modules/pricing/R/00_main.R"); run_pricing_analysis("examples/pricing/Karoo_Pricing_Config.xlsx")'
#
# The integrated demo (examples/integrated_demo) sources this file for its
# functions and passes its own respondent frame, so the same people answer the
# survey, the conjoint, the MaxDiff and the pricing questions.
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

# --- The product and its true price landscape ---------------------------------

#' What the population really thinks a 250 g bag is worth.
#'
#' `anchor` is the median value anchor in rands. The four Van Westendorp
#' answers are multiples of each respondent's own anchor; the multipliers are
#' the population medians. `gg_rungs` is the Gabor-Granger ladder. `mon_cells`
#' are the monadic prices. The bands are what a correct run must land in; they
#' are deliberately wide because the sample is finite.
karoo_pricing_truth <- function() {
  list(
    product = "Karoo Coffee 250 g bag",
    currency = "R",
    anchor = 95,
    multipliers = c(too_cheap = 0.55, cheap = 0.78, expensive = 1.25, too_expensive = 1.60),
    gg_rungs = c(60, 80, 100, 120, 140),
    mon_cells = c(70, 90, 110, 130),
    unit_cost = 38,
    # Where the headline points must land on the full weighted sample.
    bands = list(
      OPP = c(80, 115),
      IDP = c(85, 125),
      PMC = c(60, 95),
      PME = c(110, 165),
      gg_demand_first_rung_min = 0.70,
      gg_demand_last_rung_max = 0.40,
      monadic_slope_sign = -1
    )
  )
}

#' Segment shifts on the value anchor. Premium customers value the bag more,
#' Budget customers less. A crosstab of the exported acceptance grid by
#' Customer Segment should show exactly this.
karoo_pricing_segment_effects <- function() {
  c(Premium = 1.25, Standard = 1.00, Budget = 0.80, "New Customer" = 0.95)
}

#' Region shifts, used for the weight. Western Cape values the bag more; the
#' weight over-represents it in the sample so the weighted and unweighted Van
#' Westendorp points differ visibly.
karoo_pricing_region_effects <- function() {
  c("Gauteng" = 1.00, "Western Cape" = 1.15, "KwaZulu-Natal" = 0.95,
    "Eastern Cape" = 0.90)
}

# --- A default respondent frame ----------------------------------------------
# The maxdiff example owns karoo_default_respondents(); reuse it so the four
# demographics are the same across every Karoo example.

.pricing_example_source_maxdiff <- function(turas_root) {
  if (exists("karoo_default_respondents", mode = "function")) return(invisible(TRUE))
  f <- file.path(turas_root, "examples", "maxdiff", "create_maxdiff_example.R")
  if (!file.exists(f)) stop("[IO_EXAMPLE_NOT_FOUND] ", f)
  old <- getOption("turas.example.no_run")
  options(turas.example.no_run = TRUE)
  on.exit(options(turas.example.no_run = old), add = TRUE)
  source(f, local = FALSE)
  invisible(TRUE)
}

# --- The weight -------------------------------------------------------------------

#' A population weight by Region. The sample over-represents Gauteng and
#' under-represents the Eastern Cape relative to the target shares below, so
#' the weights are not all 1. Scaled to mean 1.
karoo_pricing_weights <- function(respondents) {
  target <- c("Gauteng" = 0.30, "Western Cape" = 0.34, "KwaZulu-Natal" = 0.18,
              "Eastern Cape" = 0.18)
  sample_share <- prop.table(table(factor(respondents$Region, levels = names(target))))
  w <- target[respondents$Region] / as.numeric(sample_share[respondents$Region])
  w <- w / mean(w)
  round(as.numeric(w), 4)
}

# --- Response simulation ----------------------------------------------------------

#' Simulate every pricing question for a respondent frame.
#'
#' Returns one row per respondent: RespID, the demographics, Weight, the four
#' Van Westendorp columns, the full-presentation Gabor-Granger grid (GG_R60 ..
#' GG_R140, 0/1), the stop-early copy of the same grid (GGS_R60 .. GGS_R140,
#' NA after the first No), and the monadic cell (MON_Price, MON_Intent on a
#' 1 to 5 scale).
simulate_pricing_responses <- function(respondents, seed = 2026,
                                       intransitive_rate = 0.08,
                                       gg_noise = 0.05) {
  set.seed(seed)
  truth <- karoo_pricing_truth()
  n <- nrow(respondents)
  seg_eff <- karoo_pricing_segment_effects()
  reg_eff <- karoo_pricing_region_effects()

  # Each respondent's own value anchor: the population anchor, moved by
  # segment and region, with log-normal spread.
  anchor <- truth$anchor *
    unname(seg_eff[respondents$Segment]) *
    unname(reg_eff[respondents$Region]) *
    exp(rnorm(n, 0, 0.22))

  # Van Westendorp: multiples of the anchor with per-answer noise, rounded to
  # R5 the way people answer. Sorted per respondent so the four are logical,
  # then a share of respondents have cheap and expensive swapped.
  m <- truth$multipliers
  vw <- cbind(
    anchor * m[["too_cheap"]] * exp(rnorm(n, 0, 0.12)),
    anchor * m[["cheap"]] * exp(rnorm(n, 0, 0.10)),
    anchor * m[["expensive"]] * exp(rnorm(n, 0, 0.10)),
    anchor * m[["too_expensive"]] * exp(rnorm(n, 0, 0.12))
  )
  vw <- t(apply(vw, 1, sort))
  vw <- round(vw / 5) * 5
  vw[vw < 5] <- 5
  swap <- sample(n, floor(n * intransitive_rate))
  tmp <- vw[swap, 2]; vw[swap, 2] <- vw[swap, 3]; vw[swap, 3] <- tmp

  # Gabor-Granger: a respondent accepts a rung when it is at or below their
  # own ceiling, which sits between "expensive" and "too expensive". A little
  # noise makes a few answers non-monotone, as real ladders are.
  ceiling_price <- anchor * runif(n, 1.05, m[["too_expensive"]] - 0.15)
  rungs <- truth$gg_rungs
  gg <- sapply(rungs, function(p) {
    accept <- as.integer(p <= ceiling_price)
    flip <- runif(n) < gg_noise
    accept[flip] <- 1L - accept[flip]
    accept
  })
  colnames(gg) <- sprintf("GG_R%d", rungs)

  # The stop-early copy: ascending presentation, stop after the first No.
  ggs <- gg
  for (r in seq_len(n)) {
    first_no <- which(gg[r, ] == 0L)
    if (length(first_no) > 0 && first_no[1] < ncol(gg)) {
      ggs[r, (first_no[1] + 1):ncol(gg)] <- NA_integer_
    }
  }
  colnames(ggs) <- sprintf("GGS_R%d", rungs)

  # Monadic: one random price cell each; intent on a 1 to 5 scale from a
  # latent that falls with the price shown relative to the anchor.
  cells <- truth$mon_cells
  mon_price <- sample(cells, n, replace = TRUE)
  latent <- 3.4 - 2.2 * (mon_price / anchor - 1) + rnorm(n, 0, 0.9)
  mon_intent <- pmin(5L, pmax(1L, as.integer(round(latent))))

  out <- respondents
  out$Weight <- karoo_pricing_weights(respondents)
  out$VW_TooCheap <- vw[, 1]
  out$VW_Cheap <- vw[, 2]
  out$VW_Expensive <- vw[, 3]
  out$VW_TooExpensive <- vw[, 4]
  out <- cbind(out, as.data.frame(gg), as.data.frame(ggs))
  out$MON_Price <- mon_price
  out$MON_Intent <- mon_intent
  out
}

# --- Config writers -------------------------------------------------------------
# Built from scratch with openxlsx, not by patching the shipped template: a
# loadWorkbook() round trip collapses sheet dimensions (see
# docs/HANDOVER_openxlsx_broken_workbooks.md). Setting names are the
# template's Title_Case names, so the configs exercise the same loader path a
# hand-edited template takes.

.pricing_example_saver <- function() {
  if (exists("turas_saveWorkbook", mode = "function")) return(turas_saveWorkbook)
  function(wb, file, overwrite = TRUE) openxlsx::saveWorkbook(wb, file, overwrite = overwrite)
}

.pricing_settings_sheet <- function(wb, sheet, keys, values) {
  df <- data.frame(Setting = keys, Value = as.character(values), stringsAsFactors = FALSE)
  openxlsx::addWorksheet(wb, sheet)
  openxlsx::writeData(wb, sheet, df)
  openxlsx::setColWidths(wb, sheet, cols = 1:2, widths = c(32, 48))
}

.pricing_rung_cols <- function(prefix, rungs) sprintf("%s_R%d", prefix, rungs)

#' Write one pricing config workbook.
#'
#' @param path Where to write.
#' @param method "both", "van_westendorp", "gabor_granger" or "monadic".
#' @param data_file Data file name, relative to the config.
#' @param output_file Output workbook, relative to the config.
#' @param gg_prefix "GG" for the full ladder, "GGS" for the stop-early copy.
#' @param stop_early_imputation NULL, or "NO_AFTER_STOP" to opt in.
#' @param weighted Use the Weight column.
#' @param html_report,simulator,stats_pack Output switches.
write_pricing_config <- function(path, method = "both",
                                 data_file = "Karoo_Pricing_Data.xlsx",
                                 output_file = "Output/Karoo_Pricing_Results.xlsx",
                                 project_name = "Karoo Coffee 250 g bag",
                                 gg_prefix = "GG",
                                 stop_early_imputation = NULL,
                                 weighted = TRUE,
                                 segment_column = "Segment",
                                 html_report = FALSE, simulator = FALSE,
                                 stats_pack = TRUE,
                                 tabs_export = FALSE, question_code = "GGACC",
                                 vw_monotonicity = "drop",
                                 bootstrap_iterations = 300) {
  truth <- karoo_pricing_truth()
  yn <- function(x) if (isTRUE(x)) "TRUE" else "FALSE"
  wb <- openxlsx::createWorkbook()

  settings <- c(
    Project_Name = project_name,
    Analysis_Method = method,
    Data_File = data_file,
    Output_File = output_file,
    ID_Variable = "RespID",
    Weight_Variable = if (isTRUE(weighted)) "Weight" else "",
    Currency_Symbol = truth$currency,
    Unit_Cost = as.character(truth$unit_cost),
    DK_Codes = "",
    Generate_HTML_Report = yn(html_report),
    Generate_Simulator = yn(simulator),
    Generate_Stats_Pack = if (isTRUE(stats_pack)) "Y" else "N",
    Generate_Tabs_Export = yn(tabs_export),
    Tabs_Question_Code = question_code,
    VW_Monotonicity_Behavior = vw_monotonicity,
    GG_Monotonicity_Behavior = "smooth",
    Segment_Column = segment_column %||% "",
    Min_Segment_N = "30",
    Include_Total = "TRUE",
    N_Tiers = "3",
    Tier_Names = "Value;Standard;Premium",
    Min_Gap_Pct = "15",
    Max_Gap_Pct = "50",
    Round_To = "0.99",
    Analyst_Name = "Turas example",
    Research_House = "The Research LampPost"
  )
  if (!is.null(stop_early_imputation)) {
    settings <- c(settings, GG_Stop_Early_Imputation = stop_early_imputation)
  }
  .pricing_settings_sheet(wb, "Settings", names(settings), unname(settings))

  if (method %in% c("both", "van_westendorp")) {
    vw <- c(
      Col_Too_Cheap = "VW_TooCheap",
      Col_Cheap = "VW_Cheap",
      Col_Expensive = "VW_Expensive",
      Col_Too_Expensive = "VW_TooExpensive",
      Calculate_Confidence = "TRUE",
      Confidence_Level = "0.95",
      Bootstrap_Iterations = as.character(bootstrap_iterations)
    )
    .pricing_settings_sheet(wb, "VanWestendorp", names(vw), unname(vw))
  }

  if (method %in% c("both", "gabor_granger")) {
    rungs <- truth$gg_rungs
    gg <- c(
      Data_Format = "wide",
      # Semicolons, as the template instructs.
      Price_Sequence = paste(rungs, collapse = ";"),
      Response_Columns = paste(.pricing_rung_cols(gg_prefix, rungs), collapse = ";"),
      Response_Type = "binary",
      Smoothing_Method = "isotonic",
      Calculate_Elasticity = "TRUE",
      Revenue_Optimization = "TRUE",
      Confidence_Intervals = "TRUE",
      Bootstrap_Iterations = as.character(bootstrap_iterations),
      Confidence_Level = "0.95"
    )
    .pricing_settings_sheet(wb, "GaborGranger", names(gg), unname(gg))
  }

  if (method == "monadic") {
    mon <- c(
      Price_Column = "MON_Price",
      Intent_Column = "MON_Intent",
      Intent_Type = "scale",
      Scale_Threshold = "4",
      Model_Type = "logistic",
      Min_Cell_Size = "30",
      Prediction_Points = "100",
      Confidence_Intervals = "TRUE",
      Bootstrap_Iterations = as.character(bootstrap_iterations),
      Confidence_Level = "0.95"
    )
    .pricing_settings_sheet(wb, "Monadic", names(mon), unname(mon))
  }

  val <- c(Min_Completeness = "0.80", Min_Sample = "30",
           Price_Min = "5", Price_Max = "500")
  .pricing_settings_sheet(wb, "Validation", names(val), unname(val))

  .pricing_example_saver()(wb, path, overwrite = TRUE)
  invisible(path)
}

# --- Orchestration ----------------------------------------------------------------

#' Build the example: simulate, write the data and the three configs. Returns
#' the paths and the truth. Does NOT run the analysis.
build_pricing_example <- function(turas_root, out_dir, respondents = NULL,
                                  file_stem = "Karoo_Pricing", seed = 2026,
                                  verbose = TRUE, ...) {
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  out_dir <- normalizePath(out_dir)
  saver_src <- file.path(turas_root, "modules", "shared", "lib", "turas_save_workbook_atomic.R")
  if (file.exists(saver_src) && !exists("turas_saveWorkbook", mode = "function")) source(saver_src)

  if (is.null(respondents)) {
    .pricing_example_source_maxdiff(turas_root)
    respondents <- karoo_default_respondents(seed = seed)
  }

  data <- simulate_pricing_responses(respondents, seed = seed)
  data_file <- file.path(out_dir, paste0(file_stem, "_Data.xlsx"))
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, "Data", data)
  .pricing_example_saver()(wb, data_file, overwrite = TRUE)
  if (verbose) cat(sprintf("Data: %d respondents -> %s\n", nrow(data), data_file))

  cfg <- file.path(out_dir, paste0(file_stem, "_Config.xlsx"))
  write_pricing_config(cfg, method = "both", data_file = basename(data_file),
                       output_file = file.path("Output", paste0(file_stem, "_Results.xlsx")), ...)
  cfg_mon <- file.path(out_dir, paste0(file_stem, "_Config_Monadic.xlsx"))
  write_pricing_config(cfg_mon, method = "monadic", data_file = basename(data_file),
                       output_file = file.path("Output", paste0(file_stem, "_Monadic_Results.xlsx")),
                       segment_column = NULL, ...)
  cfg_stop <- file.path(out_dir, paste0(file_stem, "_Config_StopEarly.xlsx"))
  write_pricing_config(cfg_stop, method = "gabor_granger", data_file = basename(data_file),
                       output_file = file.path("Output", paste0(file_stem, "_StopEarly_Results.xlsx")),
                       gg_prefix = "GGS", segment_column = NULL, ...)
  # The same ladder with the opt-in, so both behaviours can be run without
  # editing a config.
  cfg_stop_imp <- file.path(out_dir, paste0(file_stem, "_Config_StopEarly_Imputed.xlsx"))
  write_pricing_config(cfg_stop_imp, method = "gabor_granger", data_file = basename(data_file),
                       output_file = file.path("Output", paste0(file_stem, "_StopEarly_Imputed_Results.xlsx")),
                       gg_prefix = "GGS", segment_column = NULL,
                       stop_early_imputation = "NO_AFTER_STOP", ...)
  if (verbose) cat("Configs:", basename(cfg), basename(cfg_mon), basename(cfg_stop),
                   basename(cfg_stop_imp), "\n")

  invisible(list(data_file = data_file, config = cfg, config_monadic = cfg_mon,
                 config_stop_early = cfg_stop, config_stop_early_imputed = cfg_stop_imp,
                 data = data, truth = karoo_pricing_truth()))
}

# --- Run when executed as a script -------------------------------------------------

if (sys.nframe() == 0L && !isTRUE(getOption("turas.example.no_run"))) {
  args <- commandArgs(trailingOnly = TRUE)
  turas_root <- if (length(args) >= 1) args[1] else getwd()
  out_dir <- if (length(args) >= 2) args[2] else file.path(turas_root, "examples", "pricing")
  res <- build_pricing_example(turas_root, out_dir)
  cat("\nBuilt. Next:\n")
  cat(sprintf("  Rscript -e 'source(\"modules/pricing/R/00_main.R\"); run_pricing_analysis(\"%s\")'\n",
              file.path("examples", "pricing", basename(res$config))))
}

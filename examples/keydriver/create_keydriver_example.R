# ==============================================================================
# TURAS KEYDRIVER - WORKED EXAMPLE: SUIDERLAND BANK
# ==============================================================================
#
# Builds a small, self-contained key driver study whose right answer is known
# by construction, so the module can be run end to end and checked against
# something rather than eyeballed.
#
# Why it exists: keydriver had no example of any kind. Three separate features
# in it had never produced a number, and nothing caught that because there was
# nothing to run. Pricing gained its Karoo example for the same reason.
#
#   Suiderland_KeyDriver_Data.xlsx    900 respondents
#   Suiderland_KeyDriver_Config.xlsx  the config the module reads
#
# THE TRUE ANSWER, by construction, is in README.md and asserted in
# modules/keydriver/tests/testthat/test_keydriver_example.R.
#
# Usage:
#   source("examples/keydriver/create_keydriver_example.R")
#   ex <- build_keydriver_example()      # writes both files, returns their paths
#
# Set options(turas.example.no_run = TRUE) to source this file without building
# anything, which is what the test suite does.
# ==============================================================================

# The true standardised effects. Well separated, so a correct engine must
# recover this order and no sampling wobble can reorder them.
KD_EXAMPLE_TRUTH <- c(
  digital_banking = 0.80,   # strongest by a distance
  fees_clarity    = 0.52,
  branch_service  = 0.34,
  staff_knowledge = 0.16,
  product_range   = 0.05    # close to noise
)

# The categorical driver's effect, for the mixed-model path.
KD_EXAMPLE_CHANNEL_EFFECT <- c(App = 0.45, Branch = 0.00, `Call centre` = -0.55)


#' Generate the Suiderland respondent file
#' @keywords internal
build_keydriver_data <- function(n = 900, seed = 2026) {
  set.seed(seed)

  drivers <- names(KD_EXAMPLE_TRUTH)
  # Correlated drivers, as in any real battery: a respondent who rates one
  # thing well tends to rate the rest well. An engine that ignores this is
  # exactly what Johnson's relative weights exist to correct.
  age_band <- sample(c("18-24", "25-34", "35-49", "50+"), n, TRUE,
                     prob = c(0.18, 0.30, 0.32, 0.20))
  is_young <- age_band %in% c("18-24", "25-34")

  latent <- rnorm(n)
  d <- as.data.frame(lapply(drivers, function(v) {
    # The age shift sits ONLY on the strongest driver and, below, on the
    # channel. Putting it on branch_service as well reordered branch_service
    # and staff_knowledge under weighting, because their true effects are
    # close: the weighting was then strong enough to overturn a real but small
    # difference. The contrast is still there, and the ordering is safe from it.
    shift <- switch(v, digital_banking = ifelse(is_young, 1.1, -0.5), 0)
    round(pmin(pmax(5.5 + 1.1 * latent + shift + rnorm(n, sd = 1.4), 1), 10), 0)
  }))
  names(d) <- drivers

  channel <- ifelse(is_young,
                    sample(c("App", "Branch", "Call centre"), n, TRUE, prob = c(0.70, 0.15, 0.15)),
                    sample(c("App", "Branch", "Call centre"), n, TRUE, prob = c(0.25, 0.45, 0.30)))
  customer_tier <- sample(c("Standard", "Premium"), n, TRUE, prob = c(0.72, 0.28))

  # Standardise the drivers before applying the true effects, so the
  # coefficients ARE the standardised ones and the truth is unambiguous.
  z <- scale(as.matrix(d[, drivers]))
  linear <- as.numeric(z %*% KD_EXAMPLE_TRUTH) +
    unname(KD_EXAMPLE_CHANNEL_EFFECT[channel])

  d$overall_satisfaction <- round(pmin(pmax(
    7.0 + 1.25 * linear + rnorm(n, sd = 0.9), 0), 10), 0)

  # One model for everybody, so the true driver order holds for the whole
  # sample and an engine that recovers it is demonstrably right. The weighting
  # contrast comes from WHO is in the sample, not from a different model: the
  # younger half rate digital banking higher and the branch lower, and they
  # carry three times the weight, so a weighted run shifts the numbers while
  # the ordering stays the truth.
  #
  # An earlier version of this file gave the younger half their own equation.
  # That produced a file whose "known" answer was not knowable, and the module
  # duly returned a different order. The fixture was wrong, not the engine.
  younger <- age_band %in% c("18-24", "25-34")

  d$contact_channel <- channel
  d$age_band <- age_band
  d$customer_tier <- customer_tier
  d$weight <- ifelse(younger, 1.9, 0.6)
  d$respondent_id <- sprintf("S%04d", seq_len(n))

  d[, c("respondent_id", "overall_satisfaction", drivers,
        "contact_channel", "age_band", "customer_tier", "weight")]
}


#' Write the config workbook the module reads
#' @keywords internal
write_keydriver_config <- function(path, data_file, output_file,
                                   include_categorical = TRUE) {
  drivers <- names(KD_EXAMPLE_TRUTH)

  settings <- data.frame(
    Setting = c(
      "data_file", "output_file", "analysis_name",
      "outcome_variable", "weight_variable",
      "enable_shap", "enable_quadrant", "enable_bootstrap",
      "enable_dominance", "enable_nca", "enable_elastic_net", "enable_gam",
      "enable_html_report", "Generate_Stats_Pack",
      "bootstrap_iterations", "random_seed",
      "importance_source", "threshold_method", "min_segment_n"
    ),
    Value = c(
      basename(data_file), output_file, "Suiderland Bank customer satisfaction",
      "overall_satisfaction", "weight",
      # SHAP and the optional engines are off by default so the example runs in
      # seconds. Switch them on to exercise those paths.
      "No", "Yes", "Yes",
      "Yes", "No", "No", "No",
      "Yes", "Yes",
      "200", "2026",
      "relative_weights", "mean", "60"
    ),
    stringsAsFactors = FALSE
  )

  variables <- data.frame(
    VariableName = c("overall_satisfaction", drivers,
                     if (include_categorical) "contact_channel", "weight"),
    Type = c("Outcome", rep("Driver", length(drivers)),
             if (include_categorical) "Driver", "Weight"),
    Label = c("Overall satisfaction",
              "Digital banking", "Clarity of fees", "Branch service",
              "Staff knowledge", "Product range",
              if (include_categorical) "Main contact channel",
              "Survey weight"),
    DriverType = c("", rep("continuous", length(drivers)),
                   if (include_categorical) "categorical", ""),
    stringsAsFactors = FALSE
  )

  # Two segment variables, and one of them groups four levels into two named
  # segments. Reading more than the first row, and reading segment_values at
  # all, is what review C2 fixed.
  segments <- data.frame(
    segment_name = c("Younger", "Older", "Standard", "Premium"),
    segment_variable = c("age_band", "age_band", "customer_tier", "customer_tier"),
    segment_values = c("18-24, 25-34", "35-49, 50+", "Standard", "Premium"),
    stringsAsFactors = FALSE
  )

  stated <- data.frame(
    driver = drivers,
    stated_importance = c(8.4, 7.9, 6.1, 7.2, 5.4),
    stringsAsFactors = FALSE
  )

  wb <- openxlsx::createWorkbook()
  header <- openxlsx::createStyle(textDecoration = "bold")
  for (nm in c("Settings", "Variables", "Segments", "StatedImportance")) {
    openxlsx::addWorksheet(wb, nm)
  }
  openxlsx::writeData(wb, "Settings", settings, headerStyle = header)
  openxlsx::writeData(wb, "Variables", variables, headerStyle = header)
  openxlsx::writeData(wb, "Segments", segments, headerStyle = header)
  openxlsx::writeData(wb, "StatedImportance", stated, headerStyle = header)
  for (nm in c("Settings", "Variables", "Segments", "StatedImportance")) {
    openxlsx::setColWidths(wb, nm, cols = 1:6, widths = "auto")
  }

  .keydriver_example_saver()(wb, path, overwrite = TRUE)
  path
}


#' The workbook saver, found rather than assumed
#'
#' Never openxlsx::saveWorkbook() directly: it writes relationships to drawing
#' parts it never creates, and Excel repairs the file by stripping every
#' dropdown. See docs/HANDOVER_openxlsx_broken_workbooks.md. This example used
#' a bare fallback when the helper was not loaded, which main's own guard test
#' now forbids, so it locates the helper instead.
#'
#' @return A function with turas_saveWorkbook()'s signature.
#' @keywords internal
.keydriver_example_saver <- function() {
  if (exists("turas_saveWorkbook", mode = "function")) return(turas_saveWorkbook)
  rel <- file.path("modules", "shared", "lib", "turas_save_workbook_atomic.R")
  dir <- getwd()
  while (!file.exists(file.path(dir, rel)) && dir != dirname(dir)) dir <- dirname(dir)
  if (file.exists(file.path(dir, rel))) {
    source(file.path(dir, rel))
    if (exists("turas_saveWorkbook", mode = "function")) return(turas_saveWorkbook)
  }
  cat("\n\u250c\u2500\u2500\u2500 TURAS WARNING \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n")
  cat("\u2502 Code: IO_SAVER_NOT_FOUND\n")
  cat("\u2502 Message: turas_save_workbook_atomic.R was not found, so this example is\n")
  cat("\u2502          written without part reconciliation and Excel may offer to\n")
  cat("\u2502          repair it, losing its dropdowns.\n")
  cat("\u2502 How to fix: run from the Turas project root\n")
  cat("\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n\n")
  function(wb, file, overwrite = TRUE) openxlsx::saveWorkbook(wb, file, overwrite = overwrite)  # turas-saver-fallback
}


#' Build the whole example
#'
#' @param root Turas project root.
#' @param out_dir Where to write. Defaults to this folder.
#' @param verbose Print what was written.
#' @return A list of paths, plus the data frame and the known truth.
#' @export
build_keydriver_example <- function(root = NULL, out_dir = NULL, verbose = TRUE,
                                    n = 900, seed = 2026) {
  if (is.null(root)) root <- getwd()
  if (is.null(out_dir)) out_dir <- file.path(root, "examples", "keydriver")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(out_dir, "Output"), showWarnings = FALSE, recursive = TRUE)

  d <- build_keydriver_data(n = n, seed = seed)

  data_file <- file.path(out_dir, "Suiderland_KeyDriver_Data.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, "Data", d,
                      headerStyle = openxlsx::createStyle(textDecoration = "bold"))
  .keydriver_example_saver()(wb, data_file, overwrite = TRUE)

  # Two configs, the way the pricing example ships four.
  #
  # The first is five continuous drivers and runs clean to PASS: it is the one
  # to look at when you want to see the module working and check the answer.
  #
  # The second adds the categorical driver. It runs to PARTIAL, correctly and
  # on purpose: a bootstrap cannot resample a factor and a zero-order
  # correlation is not defined for one, so both refuse by name and the run
  # degrades instead of quietly producing numbers for them. That is worth
  # having in front of you, because it is what honest degradation looks like.
  config_file <- file.path(out_dir, "Suiderland_KeyDriver_Config.xlsx")
  write_keydriver_config(config_file, data_file,
                         output_file = "Output/Suiderland_KeyDriver_Results.xlsx",
                         include_categorical = FALSE)

  config_mixed <- file.path(out_dir, "Suiderland_KeyDriver_Config_Mixed.xlsx")
  write_keydriver_config(config_mixed, data_file,
                         output_file = "Output/Suiderland_KeyDriver_Mixed_Results.xlsx",
                         include_categorical = TRUE)

  if (verbose) {
    cat("Suiderland key driver example written:\n")
    cat("  data:    ", basename(data_file), sprintf("(%d respondents)\n", nrow(d)))
    cat("  config:  ", basename(config_file), "(five continuous drivers, runs to PASS)\n")
    cat("  config:  ", basename(config_mixed), "(adds the categorical driver, runs to PARTIAL)\n")
    cat("  true driver order:", paste(names(KD_EXAMPLE_TRUTH), collapse = " > "), "\n")
  }

  list(data_file = data_file, config = config_file, config_mixed = config_mixed,
       data = d, truth = KD_EXAMPLE_TRUTH, out_dir = out_dir)
}


if (!isTRUE(getOption("turas.example.no_run", FALSE)) && sys.nframe() == 0) {
  build_keydriver_example()
}

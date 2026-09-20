# ==============================================================================
# TURAS SEGMENT - WORKED EXAMPLE: THORNHILL GROCERS
# ==============================================================================
#
# A small, self-contained shopper segmentation whose right answer is known
# before the module sees it, so segment can be run end to end and checked
# against something rather than eyeballed.
#
# Why it exists: segment had no example of any kind. That is the same gap that
# let keydriver ship three features which had never produced a number, and it
# is why mini-batch k-means was dead for every study over 10,000 rows without
# anyone noticing (V2 lift review 2026-07-11, C1).
#
#   Thornhill_Segment_Data.xlsx             1,200 shoppers
#   Thornhill_Segment_Config.xlsx           final mode, k = 3
#   Thornhill_Segment_Config_Explore.xlsx   exploration mode, k = 2 to 6
#
# THE TRUE ANSWER, by construction, is in README.md and asserted in
# modules/segment/tests/testthat/test_segment_example.R.
#
# Usage:
#   source("examples/segment/create_segment_example.R")
#   ex <- build_segment_example()      # writes all three files, returns paths
#
# Set options(turas.example.no_run = TRUE) to source this file without building
# anything, which is what the test suite does.
# ==============================================================================

# Three shopper segments, separated on six attitude statements scored 1 to 10.
# The gaps are wide enough that a correct engine must recover them and no
# sampling wobble can merge two, but not so wide that the problem is trivial:
# Convenience and Quality overlap on brand trust, which is what makes the
# silhouette interesting rather than perfect.
SEGMENT_EXAMPLE_TRUTH <- list(
  `Price-led` = c(
    price_first = 8.6, promo_hunting = 8.2, convenience = 3.4,
    time_poor = 3.0, fresh_quality = 4.2, brand_trust = 3.6
  ),
  `Convenience-led` = c(
    price_first = 4.0, promo_hunting = 3.4, convenience = 8.8,
    time_poor = 8.4, fresh_quality = 5.6, brand_trust = 6.4
  ),
  `Quality-led` = c(
    price_first = 3.2, promo_hunting = 2.8, convenience = 5.4,
    time_poor = 4.6, fresh_quality = 8.9, brand_trust = 7.8
  )
)

# Unequal, as real segments are. A solution that splits 33/33/33 has found the
# k-means grid, not these shoppers.
SEGMENT_EXAMPLE_SHARES <- c(`Price-led` = 0.45, `Convenience-led` = 0.32,
                            `Quality-led` = 0.23)

SEGMENT_EXAMPLE_VARS <- names(SEGMENT_EXAMPLE_TRUTH[[1]])


#' Generate the Thornhill shopper file
#'
#' @param n Number of shoppers
#' @param seed Random seed
#' @return Data frame, one row per shopper, carrying its true segment
#' @keywords internal
build_segment_data <- function(n = 1200, seed = 2026) {
  set.seed(seed)

  segments <- names(SEGMENT_EXAMPLE_TRUTH)
  true_segment <- sample(segments, n, replace = TRUE, prob = SEGMENT_EXAMPLE_SHARES)

  # Each attitude is its segment's centre plus noise, clipped to the 1-10 scale
  # the questionnaire used. sd = 1.25 puts real overlap between neighbouring
  # segments without dissolving them.
  attitudes <- lapply(SEGMENT_EXAMPLE_VARS, function(v) {
    centres <- vapply(true_segment, function(s) SEGMENT_EXAMPLE_TRUTH[[s]][[v]], numeric(1))
    round(pmin(10, pmax(1, centres + rnorm(n, 0, 1.25))))
  })
  names(attitudes) <- paste0("att_", SEGMENT_EXAMPLE_VARS)

  # Demographics are NOT clustering variables. They exist so the profiling and
  # demographics sections of the report have something to say, and so the
  # nominal path through test_segment_differences is exercised on a real run:
  # region is a character variable, and chi-square is the test it deserves.
  is_conv <- true_segment == "Convenience-led"
  is_qual <- true_segment == "Quality-led"

  age_band <- vapply(seq_len(n), function(i) {
    p <- if (is_conv[i]) c(0.30, 0.34, 0.24, 0.12)
         else if (is_qual[i]) c(0.10, 0.24, 0.36, 0.30)
         else c(0.16, 0.26, 0.32, 0.26)
    sample(c("18-24", "25-34", "35-49", "50+"), 1, prob = p)
  }, character(1))

  region <- vapply(seq_len(n), function(i) {
    p <- if (is_conv[i]) c(0.44, 0.22, 0.20, 0.14)
         else if (is_qual[i]) c(0.34, 0.20, 0.28, 0.18)
         else c(0.22, 0.30, 0.22, 0.26)
    sample(c("Gauteng", "KwaZulu-Natal", "Western Cape", "Eastern Cape"), 1, prob = p)
  }, character(1))

  shops_online <- ifelse(
    runif(n) < ifelse(is_conv, 0.62, ifelse(is_qual, 0.34, 0.18)), "Yes", "No")

  # Monthly grocery spend. Quality-led spend most, Price-led least, and the
  # spread is wide enough that the segment difference is not the only story.
  basket_base <- ifelse(is_qual, 4200, ifelse(is_conv, 3400, 2600))
  monthly_spend <- round(pmax(400, basket_base + rnorm(n, 0, 900)), -1)

  household_size <- pmax(1, pmin(7, round(rnorm(n, ifelse(is_qual, 3.4, 3.0), 1.2))))

  d <- data.frame(
    respondent_id = sprintf("R%04d", seq_len(n)),
    stringsAsFactors = FALSE
  )
  for (nm in names(attitudes)) d[[nm]] <- attitudes[[nm]]
  d$age_band <- age_band
  d$region <- region
  d$shops_online <- shops_online
  d$household_size <- household_size
  d$monthly_spend <- monthly_spend
  d$true_segment <- true_segment
  d
}


#' The workbook saver, found rather than assumed
#'
#' Never openxlsx::saveWorkbook() directly: it writes relationships to drawing
#' parts it never creates, and Excel repairs the file by stripping every
#' dropdown. See docs/HANDOVER_openxlsx_broken_workbooks.md.
#'
#' @return A function with turas_saveWorkbook()'s signature
#' @keywords internal
.segment_example_saver <- function() {
  if (exists("turas_saveWorkbook", mode = "function")) return(turas_saveWorkbook)
  rel <- file.path("modules", "shared", "lib", "turas_save_workbook_atomic.R")
  dir <- getwd()
  while (!file.exists(file.path(dir, rel)) && dir != dirname(dir)) dir <- dirname(dir)
  if (file.exists(file.path(dir, rel))) {
    source(file.path(dir, rel))
    if (exists("turas_saveWorkbook", mode = "function")) return(turas_saveWorkbook)
  }
  cat("\n[TURAS WARNING] IO_SAVER_NOT_FOUND\n")
  cat("  turas_save_workbook_atomic.R was not found, so this example is written\n")
  cat("  without part reconciliation and Excel may offer to repair it.\n")
  cat("  How to fix: run from the Turas project root.\n\n")
  function(wb, file, overwrite = TRUE) openxlsx::saveWorkbook(wb, file, overwrite = overwrite)
}


#' Write the shopper file
#' @keywords internal
write_segment_data <- function(d, path) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, "Data", d,
                      headerStyle = openxlsx::createStyle(textDecoration = "bold"))
  openxlsx::setColWidths(wb, "Data", cols = seq_len(ncol(d)), widths = "auto")
  .segment_example_saver()(wb, path, overwrite = TRUE)
  path
}


#' Write one config workbook
#'
#' Every setting here is one the shipped template offers. That is deliberate:
#' validation now names any setting it does not recognise, and this example
#' should produce a clean run, not a warning (V2 lift review H3).
#'
#' @param path Where to write
#' @param mode "final" (k fixed at 3) or "exploration" (k = 2 to 6)
#' @keywords internal
write_segment_config <- function(path, mode = c("final", "exploration")) {
  mode <- match.arg(mode)

  settings <- c(
    data_file              = "Thornhill_Segment_Data.xlsx",
    data_sheet             = "Data",
    id_variable            = "respondent_id",
    clustering_vars        = paste(paste0("att_", SEGMENT_EXAMPLE_VARS), collapse = ","),
    profile_vars           = "household_size,monthly_spend",
    demographic_vars       = "age_band,region,shops_online",

    method                 = "kmeans",
    k_fixed                = if (mode == "final") "3" else "",
    k_min                  = "2",
    k_max                  = "6",
    k_selection_metrics    = "silhouette,elbow",
    nstart                 = "50",
    seed                   = "2026",

    missing_data           = "listwise_deletion",
    missing_threshold      = "15",
    standardize            = "TRUE",
    min_segment_size_pct   = "10",

    # Relative to the working directory, NOT to this config: the module hands
    # output_folder straight to create_output_folder(). launch_turas() runs
    # from the Turas root, so this puts the outputs beside the example.
    output_folder          = "examples/segment/Output/",
    output_prefix          = if (mode == "final") "thornhill_" else "thornhill_explore_",
    create_dated_folder    = "FALSE",
    save_model             = "TRUE",
    generate_stats_pack    = "Y",
    segment_names          = "auto",
    auto_name_style        = "descriptive",
    scale_max              = "10",

    html_report            = "TRUE",
    brand_colour           = "#323367",
    accent_colour          = "#CC9900",
    report_title           = if (mode == "final") "Thornhill Grocers: shopper segments"
                             else "Thornhill Grocers: how many segments?",
    html_show_exec_summary = "TRUE",
    html_show_overview     = "TRUE",
    html_show_validation   = "TRUE",
    html_show_importance   = "TRUE",
    html_show_profiles     = "TRUE",
    html_show_demographics = "TRUE",
    html_show_rules        = "TRUE",
    html_show_cards        = "TRUE",
    html_show_stability    = "TRUE",
    html_show_membership   = "TRUE",
    html_show_guide        = "TRUE",

    generate_rules         = "TRUE",
    rules_max_depth        = "3",
    generate_action_cards  = "TRUE",
    run_stability_check    = "TRUE",
    stability_n_runs       = "5",
    golden_questions_n     = "3",

    project_name           = "Thornhill Grocers shopper segmentation",
    analyst_name           = "Turas worked example",
    description            = "1,200 shoppers, six attitude statements, three segments by construction.",
    research_house         = "The Research LampPost"
  )

  # An empty k_fixed is how the module is told to explore. Writing the row with
  # a blank value is the same as leaving it out: the shared loader drops empty
  # cells before the parser sees them.
  settings <- settings[nzchar(settings)]

  config <- data.frame(
    Setting = names(settings),
    Value = unname(settings),
    stringsAsFactors = FALSE
  )

  labels <- data.frame(
    Variable = paste0("att_", SEGMENT_EXAMPLE_VARS),
    Label = c(
      "Price comes first",
      "I hunt for promotions",
      "Convenience matters more than price",
      "I am short of time",
      "Fresh quality is worth paying for",
      "I stick to brands I trust"
    ),
    stringsAsFactors = FALSE
  )

  wb <- openxlsx::createWorkbook()
  header <- openxlsx::createStyle(textDecoration = "bold")
  openxlsx::addWorksheet(wb, "Config")
  openxlsx::writeData(wb, "Config", config, headerStyle = header)
  openxlsx::setColWidths(wb, "Config", cols = 1:2, widths = c(26, 62))
  openxlsx::addWorksheet(wb, "Labels")
  openxlsx::writeData(wb, "Labels", labels, headerStyle = header)
  openxlsx::setColWidths(wb, "Labels", cols = 1:2, widths = c(22, 42))

  .segment_example_saver()(wb, path, overwrite = TRUE)
  path
}


#' Build the whole example
#'
#' @param out_dir Where to write. Defaults to this file's own folder.
#' @return Named list of the paths written
#' @export
build_segment_example <- function(out_dir = NULL) {
  if (is.null(out_dir)) {
    out_dir <- if (dir.exists(file.path("examples", "segment"))) {
      file.path("examples", "segment")
    } else {
      "."
    }
  }
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  d <- build_segment_data()
  data_file <- write_segment_data(d, file.path(out_dir, "Thornhill_Segment_Data.xlsx"))
  final_cfg <- write_segment_config(
    file.path(out_dir, "Thornhill_Segment_Config.xlsx"), "final")
  explore_cfg <- write_segment_config(
    file.path(out_dir, "Thornhill_Segment_Config_Explore.xlsx"), "exploration")

  cat("\nThornhill Grocers example written:\n")
  cat("  ", data_file, sprintf(" (%d shoppers)\n", nrow(d)), sep = "")
  cat("  ", final_cfg, " (final mode, k = 3)\n", sep = "")
  cat("  ", explore_cfg, " (exploration, k = 2 to 6)\n", sep = "")
  cat("\nRun it: launch_turas() -> Segment -> pick a config above.\n\n")

  invisible(list(data = data_file, config = final_cfg, config_explore = explore_cfg))
}

if (!isTRUE(getOption("turas.example.no_run", FALSE)) && identical(environment(), globalenv())) {
  invisible(NULL)  # sourcing defines the functions; call build_segment_example() to write
}

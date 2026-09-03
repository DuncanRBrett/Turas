# ==============================================================================
# TURAS MAXDIFF - EXAMPLE STUDY GENERATOR
# ==============================================================================
# Builds a complete, runnable MaxDiff study for a fictional company, "Karoo
# Coffee Roasters": what matters most to customers when they choose a coffee
# roaster. Everything is synthetic. No client data is involved at any point.
#
# What it writes into the output folder:
#   Karoo_MaxDiff_Design_Config.xlsx  DESIGN-mode config (ITEMS + DESIGN_SETTINGS)
#   Karoo_MaxDiff_Design.xlsx         the design the module itself generated
#   Karoo_MaxDiff_Data.xlsx           simulated responses, one row per respondent
#   Karoo_MaxDiff_Config.xlsx         ANALYSIS-mode config pointing at the two above
#
# The responses are simulated from KNOWN utilities (karoo_maxdiff_true_utils),
# so a run can be checked against the truth: the item ranking the module
# reports should match the ranking of those utilities.
#
# Usage, from the Turas root:
#   Rscript examples/maxdiff/create_maxdiff_example.R [turas_root] [out_dir]
# then
#   Rscript -e 'source("modules/maxdiff/R/00_main.R"); run_maxdiff("examples/maxdiff/Karoo_MaxDiff_Config.xlsx")'
#
# The integrated demo (examples/integrated_demo) sources this file for its
# functions and passes its own respondent frame, so the same people answer the
# survey, the conjoint and the MaxDiff.
# ==============================================================================

# --- Items ---------------------------------------------------------------------

karoo_maxdiff_items <- function() {
  data.frame(
    Item_ID = c("FRESH", "ORIGIN", "PRICE", "DELIVERY", "SUBSCRIBE", "GRIND",
                "ETHICAL", "DECAF", "STORE", "REWARDS"),
    Item_Label = c(
      "Roasted within the last two weeks",
      "Single-origin beans with the farm named",
      "A lower price per kilogram",
      "Free delivery on every order",
      "A subscription I can pause or change online",
      "Ground to my brewing method at no extra cost",
      "Fair pay for growers, independently verified",
      "A decaf that tastes like the real thing",
      "A shop I can visit and taste before buying",
      "Loyalty rewards on repeat orders"
    ),
    Item_Group = c("Product", "Product", "Price", "Service", "Service", "Product",
                   "Values", "Product", "Service", "Price"),
    Include = 1L,
    Anchor_Item = 0L,
    Display_Order = 1:10,
    Notes = "",
    stringsAsFactors = FALSE
  )
}

# The population's true utilities (logit scale). Freshness and origin lead,
# rewards and decaf trail. Segments pull on these below.
karoo_maxdiff_true_utils <- function() {
  c(FRESH = 1.6, ORIGIN = 1.1, PRICE = 0.6, DELIVERY = 0.5, SUBSCRIBE = 0.2,
    GRIND = 0.0, ETHICAL = 0.4, DECAF = -1.2, STORE = -0.3, REWARDS = -0.9)
}

# Segment shifts on the true utilities: the Budget segment cares about price
# and rewards, Premium about origin and ethics. This is what a crosstab of the
# exported shares by Customer Segment should show.
karoo_maxdiff_segment_effects <- function() {
  list(
    Budget  = c(PRICE = 1.1, REWARDS = 0.9, ORIGIN = -0.7, ETHICAL = -0.3),
    Premium = c(ORIGIN = 0.8, ETHICAL = 0.6, PRICE = -0.8, FRESH = 0.3),
    "New Customer" = c(STORE = 0.6, DELIVERY = 0.3)
  )
}

# --- A default respondent frame ----------------------------------------------

karoo_default_respondents <- function(n = 400, seed = 2026) {
  set.seed(seed)
  data.frame(
    RespID = sprintf("R%04d", seq_len(n)),
    Region = sample(c("Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape"),
                    n, replace = TRUE, prob = c(.38, .30, .20, .12)),
    Gender = sample(c("Male", "Female"), n, replace = TRUE),
    Age_Group = sample(c("18 - 24", "25 - 34", "35 - 44", "45 - 54", "55+"),
                       n, replace = TRUE, prob = c(.12, .30, .28, .18, .12)),
    Segment = sample(c("Premium", "Standard", "Budget", "New Customer"),
                     n, replace = TRUE, prob = c(.25, .40, .20, .15)),
    stringsAsFactors = FALSE
  )
}

# --- Config writers -------------------------------------------------------------
# Built from scratch with openxlsx, not by patching the shipped template: a
# loadWorkbook() round trip collapses sheet dimensions (see
# docs/HANDOVER_openxlsx_broken_workbooks.md).

.md_example_saver <- function() {
  if (exists("turas_saveWorkbook", mode = "function")) return(turas_saveWorkbook)
  function(wb, file, overwrite = TRUE) openxlsx::saveWorkbook(wb, file, overwrite = overwrite)
}

.md_settings_sheet <- function(wb, sheet, keys, values, name_col = "Setting_Name") {
  df <- data.frame(keys, values, stringsAsFactors = FALSE)
  names(df) <- c(name_col, "Value")
  openxlsx::addWorksheet(wb, sheet)
  openxlsx::writeData(wb, sheet, df)
  openxlsx::setColWidths(wb, sheet, cols = 1:2, widths = c(32, 40))
}

write_maxdiff_design_config <- function(path, project_name, items,
                                        items_per_task = 4, tasks = 8,
                                        versions = 3, seed = 2026) {
  wb <- openxlsx::createWorkbook()
  .md_settings_sheet(wb, "PROJECT_SETTINGS",
    c("Project_Name", "Mode", "Output_Folder", "Seed", "Brand_Colour", "Accent_Colour"),
    c(project_name, "DESIGN", ".", as.character(seed), "#0d8a8a", "#c0392b"))
  openxlsx::addWorksheet(wb, "ITEMS")
  openxlsx::writeData(wb, "ITEMS", items)
  .md_settings_sheet(wb, "DESIGN_SETTINGS",
    c("Items_Per_Task", "Tasks_Per_Respondent", "Num_Versions", "Design_Type",
      "Randomise_Task_Order", "Randomise_Item_Order_Within_Task"),
    c(items_per_task, tasks, versions, "BALANCED", "NO", "YES"),
    name_col = "Parameter_Name")
  .md_settings_sheet(wb, "OUTPUT_SETTINGS",
    c("Generate_Design_File", "Generate_Stats_Pack", "Generate_HTML_Report"),
    c("YES", "NO", "NO"))
  .md_example_saver()(wb, path, overwrite = TRUE)
  invisible(path)
}

write_maxdiff_analysis_config <- function(path, project_name, data_file, design_file,
                                          output_folder = "Output",
                                          id_var = "RespID", n_tasks = 8,
                                          segments = c(Region = "Region", Gender = "Gender",
                                                       Age_Group = "Age group",
                                                       Segment = "Customer segment"),
                                          weight_variable = "",
                                          question_code = "MDSHARE",
                                          tabs_export = TRUE, allow_approx = TRUE,
                                          simulator = TRUE, html_report = FALSE,
                                          anchor_variable = "MustHave",
                                          seed = 2026) {
  wb <- openxlsx::createWorkbook()
  .md_settings_sheet(wb, "PROJECT_SETTINGS",
    c("Project_Name", "Mode", "Raw_Data_File", "Design_File", "Output_Folder",
      "Data_File_Sheet", "Respondent_ID_Variable", "Weight_Variable",
      "Choice_Value_Type", "Seed", "Brand_Colour", "Accent_Colour",
      "Analyst_Name", "Research_House"),
    c(project_name, "ANALYSIS", data_file, design_file, output_folder,
      "1", id_var, weight_variable, "ITEM_ID", as.character(seed),
      "#0d8a8a", "#c0392b", "Turas example", "The Research LampPost"))
  openxlsx::addWorksheet(wb, "ITEMS")
  openxlsx::writeData(wb, "ITEMS", karoo_maxdiff_items())
  mapping <- data.frame(
    Field_Type = c("VERSION", rep(c("BEST_CHOICE", "WORST_CHOICE"), n_tasks)),
    Field_Name = c("Version", as.vector(rbind(sprintf("T%d_Best", seq_len(n_tasks)),
                                              sprintf("T%d_Worst", seq_len(n_tasks))))),
    Task_Number = c(NA, rep(seq_len(n_tasks), each = 2)),
    stringsAsFactors = FALSE
  )
  openxlsx::addWorksheet(wb, "SURVEY_MAPPING")
  openxlsx::writeData(wb, "SURVEY_MAPPING", mapping)
  seg <- data.frame(
    Segment_ID = names(segments), Segment_Label = unname(segments),
    Variable_Name = names(segments), Segment_Def = "", Include_in_Output = 1L,
    stringsAsFactors = FALSE
  )
  openxlsx::addWorksheet(wb, "SEGMENT_SETTINGS")
  openxlsx::writeData(wb, "SEGMENT_SETTINGS", seg)
  yn <- function(x) if (isTRUE(x)) "YES" else "NO"
  .md_settings_sheet(wb, "OUTPUT_SETTINGS",
    c("Generate_Count_Scores", "Generate_Aggregate_Logit", "Generate_HB_Model",
      "Generate_Segment_Tables", "Generate_Charts", "Generate_HTML_Report",
      "Generate_Simulator", "Generate_Stats_Pack",
      "Generate_Tabs_Export", "Tabs_Question_Code", "Allow_Approx_Utilities_Export",
      "Generate_TURF", "TURF_Max_Items", "TURF_Threshold",
      "Has_Anchor_Question", "Anchor_Variable", "Anchor_Threshold", "Anchor_Format",
      "Score_Rescale_Method", "Export_Individual_Utils", "Min_Respondents_Per_Segment"),
    c("YES", "YES", "YES", "YES", "NO", yn(html_report), yn(simulator), "YES",
      yn(tabs_export), question_code, yn(allow_approx),
      "YES", "5", "ABOVE_MEAN",
      yn(nzchar(anchor_variable)), anchor_variable, "0.5", "COMMA_SEPARATED",
      "0_100", "YES", "30"))
  .md_example_saver()(wb, path, overwrite = TRUE)
  invisible(path)
}

# --- Response simulation ---------------------------------------------------------

#' Simulate best/worst choices for every respondent from a design and known
#' utilities. Returns one row per respondent: RespID, the segment columns,
#' Version, T{n}_Best / T{n}_Worst holding Item_IDs, and MustHave (a
#' comma-separated list of the items the respondent rates as essential).
simulate_maxdiff_responses <- function(design, items, respondents, true_utils,
                                       segment_effects = list(), seed = 2026,
                                       resp_sd = 0.6, must_have_cut = 0.9) {
  set.seed(seed)
  n <- nrow(respondents)
  item_cols <- grep("^Item[0-9]+_ID$", names(design), value = TRUE)
  versions <- sort(unique(design$Version))
  tasks <- sort(unique(design$Task_Number))
  ids <- items$Item_ID[items$Include == 1]

  out <- respondents
  out$Version <- rep_len(versions, n)[sample(n)]
  for (t in tasks) {
    out[[sprintf("T%d_Best", t)]] <- NA_character_
    out[[sprintf("T%d_Worst", t)]] <- NA_character_
  }
  out$MustHave <- ""

  for (r in seq_len(n)) {
    u <- true_utils[ids] + rnorm(length(ids), 0, resp_sd)
    seg <- respondents$Segment[r]
    if (!is.null(seg) && !is.na(seg) && !is.null(segment_effects[[seg]])) {
      eff <- segment_effects[[seg]]
      u[names(eff)] <- u[names(eff)] + eff
    }
    names(u) <- ids
    v <- out$Version[r]
    vd <- design[design$Version == v, , drop = FALSE]
    for (t in tasks) {
      row <- vd[vd$Task_Number == t, , drop = FALSE]
      shown <- as.character(unlist(row[1, item_cols]))
      shown <- shown[!is.na(shown) & nzchar(shown)]
      us <- u[shown]
      p_best <- exp(us - max(us)); p_best <- p_best / sum(p_best)
      best <- sample(shown, 1, prob = p_best)
      rest <- setdiff(shown, best)
      p_worst <- exp(-u[rest] + max(u[rest])); p_worst <- p_worst / sum(p_worst)
      worst <- sample(rest, 1, prob = p_worst)
      out[[sprintf("T%d_Best", t)]][r] <- best
      out[[sprintf("T%d_Worst", t)]][r] <- worst
    }
    essential <- ids[u > must_have_cut]
    out$MustHave[r] <- paste(essential, collapse = ",")
  }
  out
}

# --- Orchestration ----------------------------------------------------------------

#' Build the example: design through the module, then simulate, then write the
#' analysis config. Returns the paths. Does NOT run the analysis.
build_maxdiff_example <- function(turas_root, out_dir, respondents = NULL,
                                  project_name = "Karoo", file_stem = "Karoo_MaxDiff",
                                  seed = 2026, weight_variable = "", verbose = TRUE) {
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  out_dir <- normalizePath(out_dir)
  if (!exists("run_maxdiff", mode = "function")) {
    source(file.path(turas_root, "modules", "maxdiff", "R", "00_main.R"))
  }
  saver_src <- file.path(turas_root, "modules", "shared", "lib", "turas_save_workbook_atomic.R")
  if (file.exists(saver_src) && !exists("turas_saveWorkbook", mode = "function")) source(saver_src)

  items <- karoo_maxdiff_items()
  if (is.null(respondents)) respondents <- karoo_default_respondents(seed = seed)

  design_cfg <- file.path(out_dir, paste0(file_stem, "_Design_Config.xlsx"))
  write_maxdiff_design_config(design_cfg, project_name, items, seed = seed)
  if (verbose) cat("Design config:", design_cfg, "\n")

  design_res <- run_maxdiff(design_cfg, verbose = FALSE)
  design_file <- file.path(out_dir, paste0(project_name, "_MaxDiff_Design.xlsx"))
  if (!file.exists(design_file)) {
    stop("[IO_DESIGN_NOT_WRITTEN] the module's design mode did not write ", design_file)
  }
  design <- openxlsx::read.xlsx(design_file, sheet = "DESIGN")
  if (verbose) cat(sprintf("Design: %d versions x %d tasks\n",
                           length(unique(design$Version)), length(unique(design$Task_Number))))

  data <- simulate_maxdiff_responses(design, items, respondents,
                                     karoo_maxdiff_true_utils(),
                                     karoo_maxdiff_segment_effects(), seed = seed)
  data_file <- file.path(out_dir, paste0(file_stem, "_Data.xlsx"))
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, "Data", data)
  .md_example_saver()(wb, data_file, overwrite = TRUE)
  if (verbose) cat(sprintf("Data: %d respondents -> %s\n", nrow(data), data_file))

  cfg <- file.path(out_dir, paste0(file_stem, "_Config.xlsx"))
  write_maxdiff_analysis_config(
    cfg, project_name,
    data_file = basename(data_file), design_file = basename(design_file),
    output_folder = "Output", n_tasks = length(unique(design$Task_Number)),
    weight_variable = weight_variable, seed = seed
  )
  if (verbose) cat("Analysis config:", cfg, "\n")

  invisible(list(design_config = design_cfg, design_file = design_file,
                 data_file = data_file, config = cfg, data = data,
                 true_utils = karoo_maxdiff_true_utils()))
}

# --- Run when executed as a script -------------------------------------------------

if (sys.nframe() == 0L && !isTRUE(getOption("turas.example.no_run"))) {
  args <- commandArgs(trailingOnly = TRUE)
  turas_root <- if (length(args) >= 1) args[1] else getwd()
  out_dir <- if (length(args) >= 2) args[2] else file.path(turas_root, "examples", "maxdiff")
  build_maxdiff_example(turas_root, out_dir)
}

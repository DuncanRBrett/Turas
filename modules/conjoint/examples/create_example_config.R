# ==============================================================================
# CREATE THE EXAMPLE CONJOINT CONFIGURATION FILE
# ==============================================================================
#
# Writes example_config.xlsx beside this script: a smartphone choice-based
# conjoint (5 attributes, 3 to 4 levels each) over sample_cbc_data.csv.
#
# The config asks for hierarchical Bayes (bayesm), so a run produces every
# deliverable the module has: the Excel workbook, the stats pack, the
# interactive-report contribution (example_results_cj_island.json), the
# crosstabbable importance export (example_results_tabs_importance.xlsx) and
# the standalone market simulator (example_results_simulator.html).
#
# Usage, from the Turas root:
#   Rscript modules/conjoint/examples/create_example_config.R
#
# Built from scratch with openxlsx. Never patch the shipped workbook with
# loadWorkbook() + save: the round trip collapses sheet dimensions.
# ==============================================================================

.example_dir <- local({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg))))
  for (i in seq_len(sys.nframe())) {
    ofile <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (is.character(ofile) && grepl("create_example_config[.]R$", ofile)) {
      return(dirname(normalizePath(ofile)))
    }
  }
  file.path(getwd(), "modules", "conjoint", "examples")
})

output_file <- file.path(.example_dir, "example_config.xlsx")

saver <- local({
  p <- file.path(.example_dir, "..", "..", "shared", "lib", "turas_save_workbook_atomic.R")
  if (file.exists(p) && !exists("turas_saveWorkbook", mode = "function")) source(p)
  if (exists("turas_saveWorkbook", mode = "function")) turas_saveWorkbook
  else function(wb, file, overwrite = TRUE) openxlsx::saveWorkbook(wb, file, overwrite = overwrite)
})

wb <- openxlsx::createWorkbook()

# --- Settings ------------------------------------------------------------------

settings_data <- data.frame(
  Setting = c(
    "project_name",
    "analysis_type",
    "estimation_method",
    "choice_type",
    "data_file",
    "output_file",
    "respondent_id_column",
    "choice_set_column",
    "alternative_id_column",
    "chosen_column",
    "confidence_level",
    "generate_market_simulator",
    "generate_html_simulator",
    "generate_tabs_export",
    "tabs_question_code",
    "generate_stats_pack"
  ),
  Value = c(
    "Smartphone example",
    "choice",
    "hb",
    "single",
    "sample_cbc_data.csv",
    "output/example_results.xlsx",
    "resp_id",
    "choice_set_id",
    "alternative_id",
    "chosen",
    "0.95",
    "TRUE",
    "TRUE",
    "Y",
    "CJIMP",
    "Y"
  ),
  Description = c(
    "Name shown in the outputs",
    "Analysis type: 'choice' or 'rating'",
    "Estimation method: 'auto', 'mlogit', 'clogit', 'hb' or 'latent_class'. HB gives each respondent their own part-worths, which is what the tabs export needs.",
    "Choice type: 'single', 'single_with_none', 'best_worst', 'continuous_sum'",
    "Path to the data file (relative to this config, or absolute)",
    "Path to the output Excel file; every other output takes its name from this",
    "Column name for the respondent id",
    "Column name for the choice-set id",
    "Column name for the alternative id (optional)",
    "Column name for the chosen indicator (1 = chosen, 0 = not chosen)",
    "Confidence level for intervals (0 to 1)",
    "Add the interactive market simulator sheet to the Excel workbook (TRUE/FALSE)",
    "Write the standalone HTML market simulator, {output}_simulator.html (TRUE/FALSE)",
    "Write per-respondent attribute importance as a tabs Allocation question, {output}_tabs_importance.xlsx (Y/N). Needs hb or latent_class.",
    "QuestionCode for that export; the columns are {code}_1 .. {code}_k",
    "Write the stats pack workbook, {output}_stats_pack.xlsx (Y/N)"
  ),
  stringsAsFactors = FALSE
)

openxlsx::addWorksheet(wb, "Settings")
openxlsx::writeData(wb, "Settings", settings_data, startRow = 1, startCol = 1)

header_style <- openxlsx::createStyle(
  fontColour = "#FFFFFF", fgFill = "#4F81BD", halign = "center", valign = "center",
  textDecoration = "bold", border = "TopBottomLeftRight"
)
openxlsx::addStyle(wb, "Settings", header_style, rows = 1, cols = 1:3, gridExpand = TRUE)
openxlsx::setColWidths(wb, "Settings", cols = 1:3, widths = c(30, 34, 90))
openxlsx::freezePane(wb, "Settings", firstRow = TRUE)

# --- Attributes ----------------------------------------------------------------

attributes_data <- data.frame(
  AttributeName = c("Brand", "Price", "Screen_Size", "Battery_Life", "Camera_Quality"),
  AttributeLabel = c("Brand", "Price", "Screen Size", "Battery Life", "Camera Quality"),
  NumLevels = c(4, 4, 3, 3, 3),
  LevelNames = c(
    "Apple, Samsung, Google, OnePlus",
    "$299, $399, $499, $599",
    "5.5 inches, 6.1 inches, 6.7 inches",
    "12 hours, 18 hours, 24 hours",
    "Basic, Good, Excellent"
  ),
  stringsAsFactors = FALSE
)

openxlsx::addWorksheet(wb, "Attributes")
openxlsx::writeData(wb, "Attributes", attributes_data, startRow = 1, startCol = 1)
openxlsx::addStyle(wb, "Attributes", header_style, rows = 1, cols = 1:4, gridExpand = TRUE)
openxlsx::setColWidths(wb, "Attributes", cols = 1:4, widths = c(20, 20, 12, 44))
openxlsx::freezePane(wb, "Attributes", firstRow = TRUE)

# --- Instructions ----------------------------------------------------------------

instructions <- c(
  "TURAS CONJOINT ANALYSIS: EXAMPLE CONFIGURATION",
  "",
  "A smartphone choice-based conjoint over sample_cbc_data.csv (50 respondents, 8 choice sets each, 3 alternatives per set).",
  "",
  "ATTRIBUTES",
  "1. Brand: Apple, Samsung, Google, OnePlus",
  "2. Price: $299, $399, $499, $599",
  "3. Screen Size: 5.5, 6.1, 6.7 inches",
  "4. Battery Life: 12, 18, 24 hours",
  "5. Camera Quality: Basic, Good, Excellent",
  "",
  "TO RUN IT, from the Turas root:",
  "  Rscript -e 'source(\"modules/conjoint/R/00_main.R\"); run_conjoint_analysis(\"modules/conjoint/examples/example_config.xlsx\")'",
  "",
  "WHAT IT WRITES, into modules/conjoint/examples/output/:",
  "  example_results.xlsx                 the workbook",
  "  example_results_stats_pack.xlsx      the stats pack",
  "  example_results_cj_island.json       the Conjoint tab for a tabs v2 report (conjoint_island setting)",
  "  example_results_tabs_importance.xlsx per-respondent importance as a tabs Allocation question",
  "  example_results_simulator.html       the standalone market simulator",
  "",
  "The data was simulated from known utilities (see README.md); the HB run should recover their order.",
  "50 respondents is small for HB, so expect a convergence warning and a PARTIAL status. That is honest, not a fault."
)
openxlsx::addWorksheet(wb, "Instructions")
openxlsx::writeData(wb, "Instructions", data.frame(Instructions = instructions),
                    startRow = 1, startCol = 1, colNames = FALSE)
openxlsx::setColWidths(wb, "Instructions", cols = 1, widths = 120)

saver(wb, output_file, overwrite = TRUE)
cat("Example configuration written:", output_file, "\n")

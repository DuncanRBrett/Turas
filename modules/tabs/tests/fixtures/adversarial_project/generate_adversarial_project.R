# ==============================================================================
# ADVERSARIAL FIXTURE. Generator (robustness programme, 24 Sep 2026)
# ==============================================================================
#
# A small deterministic tabs project built from the hard cases the parity
# fixture does not carry. No RNG. Written into a directory the caller owns
# (never this folder): generate_adversarial_project(dir).
#
#   Region banner   North 50, South 40, East 20, West 10 (East and West sit
#                   under the low-base threshold of 30).
#   W2 weights      in every region one respondent in five weighs 3.0, the
#                   rest 0.5: sum w = n, sum w^2 = 2n, so the design effect is
#                   exactly 2 and n_eff = n / 2 (North 25, South 20, East 10,
#                   West 5, Total 60).
#   WG weights      W2 x 1000, grossed to a population. Every percentage, mean,
#                   SD and letter must equal the W2 run's.
#   QR  Rating 1-5 plus 99 = "Don't know", flagged ExcludeFromIndex, with Top
#       and Bottom 2 Boxes (NET POSITIVE) and a Standard Deviation row.
#   QN  NPS 0-10 plus 99 = "Don't know", flagged ExcludeFromIndex.
#   QM  Multi_Mention over QM_1..QM_3; some respondents mention nothing.
#   QL  Single_Response whose options start with - + = @, and non-ASCII.
#   QF  Single_Response with BaseFilter Region != 'East': an empty column.
# ==============================================================================

suppressWarnings(suppressMessages(library(openxlsx)))

ADV_REGIONS <- c(North = 50L, South = 40L, East = 20L, West = 10L)
ADV_LABELS <- c("-2", "+1", "=A", "@home", "Café ñ", "Zürich")

build_adversarial_data <- function() {
  rows <- list()
  for (reg in names(ADV_REGIONS)) {
    n <- ADV_REGIONS[[reg]]
    i <- seq_len(n)
    w2 <- ifelse(i %% 5 == 0, 3.0, 0.5)
    rows[[reg]] <- data.frame(
      Region = reg,
      QR = rep_len(c(5, 4, 4, 3, 99, 2, 1, 5, 4, 3), n),
      QN = rep_len(c(10, 9, 8, 7, 99, 6, 0, 10, 5, 9), n),
      QM_1 = ifelse(i %% 2 == 0, "Bank", NA_character_),
      QM_2 = ifelse(i %% 3 == 0, "Retailer", NA_character_),
      QM_3 = ifelse(i %% 7 == 0, "Other", NA_character_),
      QL = rep_len(ADV_LABELS, n),
      QF = rep_len(c("Yes", "No", "No"), n),
      W2 = w2, WG = w2 * 1000,
      stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, c(rows, list(make.row.names = FALSE)))
  out$RespondentID <- seq_len(nrow(out))
  out
}

.adv_save <- function(wb, path) {
  if (exists("turas_saveWorkbook", mode = "function")) turas_saveWorkbook(wb, path)
  else openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
}

build_adversarial_structure <- function(path) {
  project <- data.frame(
    Setting = c("project_name", "project_code", "client_name", "study_type",
                "study_date", "data_file", "total_sample", "weight_column_exists",
                "weight_columns", "default_weight", "weight_description"),
    Value = c("Turas Adversarial Fixture", "ADV_2026", "Turas Analytics (Fixture)",
              "Ad-hoc", "20260924", "Adversarial_Data.xlsx", "120", "Y", "W2,WG",
              "W2", "Design effect 2; WG is W2 grossed x1000."),
    stringsAsFactors = FALSE)
  questions <- data.frame(
    QuestionCode = c("Region", "QR", "QN", "QM", "QL", "QF"),
    QuestionText = c("Region", "How would you rate it?", "How likely to recommend?",
                     "Which do you use?", "Which label?", "Filtered yes/no"),
    Variable_Type = c("Single_Response", "Rating", "NPS", "Multi_Mention",
                      "Single_Response", "Single_Response"),
    Columns = c(1L, 1L, 1L, 3L, 1L, 1L),
    Category = "Adversarial", ShortLabel = "", LinkedOpenQuestion = "",
    stringsAsFactors = FALSE)
  opt <- function(code, texts, display = texts, box = NA_character_, excl = NA_character_) {
    data.frame(QuestionCode = code, OptionText = texts, DisplayText = display,
               ShowInOutput = "Y", DisplayOrder = seq_along(texts), Index_Weight = NA_real_,
               BoxCategory = box, ExcludeFromIndex = excl, stringsAsFactors = FALSE)
  }
  options_df <- rbind(
    opt("Region", names(ADV_REGIONS)),
    opt("QR", c(as.character(1:5), "99"), c(as.character(1:5), "Don't know"),
        box = c("Bottom 2 Box", "Bottom 2 Box", NA, "Top 2 Box", "Top 2 Box", NA),
        excl = c(rep(NA, 5), "Y")),
    opt("QN", c(as.character(0:10), "99"), c(as.character(0:10), "Don't know"),
        excl = c(rep(NA, 11), "Y")),
    # Multi_Mention options are keyed per slot column (QM_1..QM_3), the
    # convention the processor and the microdata writer read.
    opt(c("QM_1", "QM_2", "QM_3"), c("Bank", "Retailer", "Other")),
    opt("QL", ADV_LABELS),
    opt("QF", c("Yes", "No")))
  wb <- createWorkbook()
  addWorksheet(wb, "Project");   writeData(wb, "Project", project)
  addWorksheet(wb, "Questions"); writeData(wb, "Questions", questions)
  addWorksheet(wb, "Options");   writeData(wb, "Options", options_df)
  .adv_save(wb, path)
}

build_adversarial_config <- function(path, output_filename, weight = NULL) {
  settings <- list(
    structure_file = "Adversarial_Structure.xlsx", output_subfolder = "Output",
    output_filename = output_filename, output_format = "xlsx",
    apply_weighting = if (is.null(weight)) "FALSE" else "TRUE",
    weight_variable = if (is.null(weight)) "W2" else weight,
    show_unweighted_n = "TRUE", show_effective_n = if (is.null(weight)) "FALSE" else "TRUE",
    show_frequency = "TRUE", show_percent_column = "TRUE", show_percent_row = "FALSE",
    decimal_places_percent = "2", decimal_places_ratings = "3",
    decimal_places_index = "3", decimal_places_numeric = "3",
    boxcategory_frequency = "TRUE", boxcategory_percent_column = "TRUE",
    enable_significance_testing = "TRUE", alpha = "0.05", alpha_secondary = "0.20",
    significance_min_base = "30", bonferroni_correction = "TRUE",
    show_standard_deviation = "TRUE", show_net_positive = "TRUE",
    html_report_v2 = "TRUE", project_title = "Adversarial Fixture",
    brand_colour = "#323367")
  selection <- data.frame(
    QuestionCode = c("Region", "QR", "QN", "QM", "QL", "QF"),
    Include = "Y", UseBanner = c("Y", "N", "N", "N", "N", "N"),
    BannerLabel = c("Region", "", "", "", "", ""),
    DisplayOrder = c(1L, NA, NA, NA, NA, NA),
    CreateIndex = c("N", "Y", "N", "N", "N", "N"),   # QR: the Mean row
    BaseFilter = c("", "", "", "", "", "Region != 'East'"),
    FilterLabel = c("", "", "", "", "", "Not East"),
    Category = "Adversarial", stringsAsFactors = FALSE)
  wb <- createWorkbook()
  addWorksheet(wb, "Settings")
  writeData(wb, "Settings", data.frame(Setting = names(settings),
                                       Value = unlist(settings, use.names = FALSE)))
  addWorksheet(wb, "Selection"); writeData(wb, "Selection", selection)
  .adv_save(wb, path)
}

generate_adversarial_project <- function(dir) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  wb <- createWorkbook(); addWorksheet(wb, "Data")
  writeData(wb, "Data", build_adversarial_data())
  .adv_save(wb, file.path(dir, "Adversarial_Data.xlsx"))
  build_adversarial_structure(file.path(dir, "Adversarial_Structure.xlsx"))
  build_adversarial_config(file.path(dir, "Adv_Config_Unweighted.xlsx"), "Adv_Unweighted.xlsx")
  build_adversarial_config(file.path(dir, "Adv_Config_W2.xlsx"), "Adv_W2.xlsx", "W2")
  build_adversarial_config(file.path(dir, "Adv_Config_WG.xlsx"), "Adv_WG.xlsx", "WG")
  invisible(dir)
}

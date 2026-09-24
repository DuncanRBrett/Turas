# ==============================================================================
# Synthetic two-wave tracker project for the pipeline and consistency tests
# ==============================================================================
# Writes a complete project to a directory: two wave CSVs, a Survey_Structure
# per wave, the tracking config and the question mapping. Deterministic (fixed
# seed) so every figure can be recomputed independently from the CSVs.
#
# What it exercises (robustness brief, tracker adversarial cases):
#   - weights with a design effect well above 1 (W1) and the same shape
#     grossed to a population of 2.4 million (W2)
#   - a numeric don't-know code (99, ExcludeFromIndex = Y) in a rating
#   - a multi-mention question routed to part of the sample
#   - a composite of two ratings
#   - a single-choice code present in W2 only, a label starting with "-",
#     and a non-ASCII label
#   - a question asked in W2 only
#   - a rating (EASE, Q12) tracked "mean,top_box" with no scale in the
#     structure: the box is refused, the mean ships, the run is PARTIAL
#   - a Region banner whose South segment (every third respondent, n = 40)
#     has an effective base under 30, so its pairs must not be tested
# ==============================================================================

pipeline_fixture_write <- function(dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  set.seed(20260924)
  n <- 120

  make_wave <- function(wave, sat_shift, yes_p, gross = 1) {
    w <- rep(c(0.4, 0.8, 1.6, 2.4), length.out = n)
    if (gross != 1) w <- w * gross / sum(w)
    sat <- sample(1:5, n, replace = TRUE, prob = c(1, 2, 3, 4 + sat_shift, 3 + sat_shift))
    sat[c(7, 19, 44, 90)] <- 99                      # don't know
    val <- sample(1:5, n, replace = TRUE, prob = c(1, 1, 3, 3, 2))
    nps <- sample(0:10, n, replace = TRUE,
                  prob = c(1, 1, 1, 1, 1, 2, 2, 4, 5, 5 + sat_shift, 4 + sat_shift))
    aware_codes <- if (wave == "W1") c("Yes", "No", "Café") else
      c("Yes", "No", "Café", "- None of these")
    aware <- sample(aware_codes, n, replace = TRUE,
                    prob = if (wave == "W1") c(yes_p, 1 - yes_p - 0.1, 0.1) else
                      c(yes_p, 1 - yes_p - 0.15, 0.1, 0.05))
    routed <- seq_len(n) > 90                        # 30 not asked the multi
    mm <- function(p) ifelse(routed, NA, rbinom(n, 1, p))
    df <- data.frame(
      RespID = seq_len(n), wt = w,
      Region = ifelse(seq_len(n) %% 3 == 0, "South", "North"),
      Q10 = sat, Q11 = val, Q12 = sample(1:5, n, replace = TRUE), Q15 = nps, Q20 = aware,
      Q30_1 = mm(0.45), Q30_2 = mm(0.35 + sat_shift / 20), Q30_3 = mm(0.2),
      stringsAsFactors = FALSE
    )
    if (wave == "W2") df$Q40 <- sample(1:5, n, replace = TRUE)
    df
  }

  # W2 moves satisfaction and NPS far enough that their wave-on-wave tests are
  # significant, while channel 1 stays flat, so the arrow checks see both kinds
  waves <- list(W1 = make_wave("W1", 0, 0.40), W2 = make_wave("W2", 6, 0.55, gross = 2.4e6))
  for (wid in names(waves)) {
    utils::write.csv(waves[[wid]], file.path(dir, paste0(wid, ".csv")),
                     row.names = FALSE, fileEncoding = "UTF-8")
  }

  scale_rows <- function(code, points) {
    data.frame(QuestionCode = code, OptionText = as.character(points),
               Index_Weight = points, ExcludeFromIndex = NA_character_,
               stringsAsFactors = FALSE)
  }
  options_df <- rbind(
    scale_rows("Q10", 1:5),
    data.frame(QuestionCode = "Q10", OptionText = "99", Index_Weight = NA,
               ExcludeFromIndex = "Y", stringsAsFactors = FALSE),
    scale_rows("Q11", 1:5),
    scale_rows("Q15", 0:10),
    scale_rows("Q40", 1:5)
  )
  for (wid in names(waves)) {
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "Options")
    openxlsx::writeData(wb, "Options", options_df)
    turas_saveWorkbook(wb, file.path(dir, paste0("structure_", wid, ".xlsx")), overwrite = TRUE)
  }

  config_path <- file.path(dir, "tracking_config.xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Waves")
  openxlsx::writeData(wb, "Waves", data.frame(
    WaveID = c("W1", "W2"), WaveName = c("Wave 1", "Wave 2"),
    DataFile = c("W1.csv", "W2.csv"),
    FieldworkStart = c("2025-03-01", "2026-03-01"),
    FieldworkEnd = c("2025-03-31", "2026-03-31"),
    WeightVar = c("wt", "wt"),
    StructureFile = c("structure_W1.xlsx", "structure_W2.xlsx"),
    stringsAsFactors = FALSE))
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("project_name", "question_mapping_file", "alpha", "minimum_base",
                "report_types", "show_significance", "decimal_places_ratings",
                "html_report", "generate_stats_pack"),
    Value = c("Pipeline Fixture", "question_mapping.xlsx", "0.05", "30",
              "detailed,wave_history,dashboard,sig_matrix,tracking_crosstab",
              "Y", "2", "N", "N"),
    stringsAsFactors = FALSE))
  openxlsx::addWorksheet(wb, "Banner")
  openxlsx::writeData(wb, "Banner", data.frame(
    BreakVariable = c("Total", "Region"), BreakLabel = c("Total", "Region"),
    stringsAsFactors = FALSE))
  openxlsx::addWorksheet(wb, "TrackedQuestions")
  openxlsx::writeData(wb, "TrackedQuestions", data.frame(
    QuestionCode = c("SAT", "REC", "AWARE", "CHAN", "CX", "NEWQ", "EASE"),
    MetricLabel = c("Satisfaction", "Recommend", "Awareness", "Channels", "CX index",
                    "New question", "Ease"),
    TrackingSpecs = c("mean,top2_box", "", "all", "auto,any", "mean,range:4-5", "mean",
                      "mean,top_box"),
    Section = "Fixture", SortOrder = 1:7, stringsAsFactors = FALSE))
  turas_saveWorkbook(wb, config_path, overwrite = TRUE)

  wb2 <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb2, "QuestionMap")
  openxlsx::writeData(wb2, "QuestionMap", data.frame(
    QuestionCode = c("SAT", "VAL", "REC", "AWARE", "CHAN", "CX", "NEWQ", "EASE"),
    QuestionText = c("Satisfaction", "Value", "Recommend", "Aware of us", "Channels used",
                     "CX index", "New question", "Ease"),
    QuestionType = c("Rating", "Rating", "NPS", "Single_Response", "Multi_Mention",
                     "Composite", "Rating", "Rating"),
    SourceQuestions = c(NA, NA, NA, NA, NA, "SAT,VAL", NA, NA),
    W1 = c("Q10", "Q11", "Q15", "Q20", "Q30", NA, NA, "Q12"),
    W2 = c("Q10", "Q11", "Q15", "Q20", "Q30", NA, "Q40", "Q12"),
    stringsAsFactors = FALSE))
  turas_saveWorkbook(wb2, file.path(dir, "question_mapping.xlsx"), overwrite = TRUE)

  list(dir = dir, config_path = config_path, waves = waves)
}

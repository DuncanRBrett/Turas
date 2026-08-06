# ==============================================================================
# CROSS-ENGINE PARITY FIXTURE — generator
# ==============================================================================
#
# Writes the small synthetic tabs project that the cross-engine parity harness
# runs against (spec: docs/tabs_production_review_2026-08/CROSS_ENGINE_STATS_SPEC.md
# section 3). Everything here is DETERMINISTIC — no RNG, no dates, no locale
# dependence — so the generated workbooks and the island built from them are
# reproducible byte for byte.
#
# REGENERATE WITH:
#   Rscript modules/tabs/tests/fixtures/parity_project/generate_parity_project.R
#
# WHAT THE FIXTURE IS ENGINEERED TO CONTAIN
#
# One banner question, Cohort, with four columns that between them cover every
# branch of the finite population correction (apply_fpc, modules/shared/lib/fpc.R):
#
#   Column   n    Universe N   coverage   apply_fpc(1, n, N)      exercises
#   ------   --   ----------   --------   ---------------------   ----------------
#   Alpha    40   40           1.00       Inf                     full census
#   Beta     60   150          0.40       149/90 = 1.6556         real correction
#   Gamma    50   5000         0.01       1 (below 5% floor)      the floor
#   Delta    50   (no row)     -          1 (unresolved)          no population
#
# Total base 200; population_size 5000 (coverage 4%, below the floor — the Total
# column is never lettered anyway).
#
# Q1 is a Yes/No proportion question whose Beta-vs-Gamma pair is engineered to
# sit BETWEEN the two Bonferroni-adjusted thresholds without FPC, and to cross
# the primary one with FPC. Hand-derivation (divisor choose(4,2) = 6, so
# alpha_adj = 0.05/6 = 0.0083333 and alpha2_adj = 0.20/6 = 0.0333333):
#
#   Beta  39/60 = 0.650      Gamma 20/50 = 0.400
#   pooled p = 59/110 = 0.5363636
#   no FPC:  SE = sqrt(0.5363636*0.4636364*(1/60 + 1/50))  = 0.0954892
#            z  = 0.25 / 0.0954892 = 2.61810   ->  p = 0.008842
#            0.008842 > 0.0083333  -> NOT significant at 95%
#            0.008842 < 0.0333333  -> significant at 80%    (lowercase c on Beta)
#   with FPC: Beta's n_eff becomes 60 * 149/90 = 99.3333, Gamma's is unchanged
#            (coverage 50/5000 = 1%, below the floor)
#            SE = sqrt(0.5363636*0.4636364*(1/99.3333 + 1/50)) = 0.0864698
#            z  = 0.25 / 0.0864698 = 2.89118   ->  p = 0.003838
#            0.003838 < 0.0083333  -> significant at 95%    (uppercase C on Beta)
#
# That single pair is the executable form of three separate claims: the dual
# alpha rows disagree in a way the reader can see, the FPC changes a published
# letter, and the change is one a human can check by hand.
#
# Q2 is a 1-5 rating with a Top 2 Box net, an Index row AND a Standard Deviation
# row — the summary block whose Sig. row is appended AFTER the Std Dev row, so
# it pins the writer's mean-sig attachment (data_layer_writer.R mean_sig_for).
#
# Q3 is routed (BaseFilter Q1 == "Yes"), so its per-column bases are the Q1 Yes
# counts: 24 / 39 / 20 / 30. Two of those sit below the min_base of 30, which is
# what makes the min_base gate visible on a real table rather than only in a
# unit test.
#
# The weighted config uses the same data with a Weight column that varies by
# cohort, so every carried statistic rides a real Kish effective base.
# ==============================================================================

suppressWarnings(suppressMessages(library(openxlsx)))

# Only trust a --file= that actually names THIS script (i.e. we were run with
# Rscript). When sourced, callers pass the directory explicitly.
FIXTURE_DIR <- (function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    p <- sub("^--file=", "", file_arg[1])
    if (identical(basename(p), "generate_parity_project.R")) {
      return(dirname(normalizePath(p)))
    }
  }
  getwd()
})()

# ==============================================================================
# 1. SURVEY DATA
# ==============================================================================

# Cohort sizes. Alpha is a full census of its 40-person universe.
COHORTS <- c(Alpha = 40L, Beta = 60L, Gamma = 50L, Delta = 50L)

# Q1 "Yes" counts per cohort (see the hand-derivation in the header).
Q1_YES <- c(Alpha = 24L, Beta = 39L, Gamma = 20L, Delta = 30L)

# Q2 rating distribution per cohort, counts for scores 1..5. Each row sums to
# the cohort size. Top 2 Box = scores 4 + 5.
Q2_DIST <- rbind(
  Alpha = c(2L,  4L,  10L, 14L, 10L),   # T2B 24/40 = 60.0%
  Beta  = c(2L,  6L,  13L, 24L, 15L),   # T2B 39/60 = 65.0%
  Gamma = c(8L, 12L,  10L, 12L,  8L),   # T2B 20/50 = 40.0%
  Delta = c(4L,  6L,  10L, 18L, 12L)    # T2B 30/50 = 60.0%
)

# Q3 "Agree" counts, among that cohort's Q1 == "Yes" respondents only.
Q3_AGREE <- c(Alpha = 14L, Beta = 27L, Gamma = 8L, Delta = 18L)

# Weights, one constant per cohort plus a deliberate within-cohort split so the
# Kish effective base is genuinely below the raw n (a constant weight would make
# n_eff == n and quietly test nothing).
COHORT_WEIGHT <- c(Alpha = 1.6, Beta = 0.8, Gamma = 1.2, Delta = 1.0)
# Every third respondent in a cohort carries 1.75x its base weight.
WEIGHT_BUMP <- 1.75

build_survey_data <- function() {
  rows <- list()
  rid <- 0L
  for (coh in names(COHORTS)) {
    n <- COHORTS[[coh]]
    # Q1: the first Q1_YES[coh] respondents answer Yes.
    q1 <- c(rep("Yes", Q1_YES[[coh]]), rep("No", n - Q1_YES[[coh]]))
    # Q2: scores laid out in order, counts from Q2_DIST.
    q2 <- rep(1:5, times = Q2_DIST[coh, ])
    # Q3 is asked only of Q1 == "Yes"; everyone else gets NA.
    n_yes <- Q1_YES[[coh]]
    q3_yes <- c(rep("Agree", Q3_AGREE[[coh]]), rep("Disagree", n_yes - Q3_AGREE[[coh]]))
    q3 <- c(q3_yes, rep(NA_character_, n - n_yes))
    w <- rep(COHORT_WEIGHT[[coh]], n)
    w[seq(3, n, by = 3)] <- w[seq(3, n, by = 3)] * WEIGHT_BUMP

    rows[[coh]] <- data.frame(
      RespondentID = rid + seq_len(n),
      Cohort = coh,
      Q1 = q1,
      Q2 = q2,
      Q3 = q3,
      Weight = w,
      stringsAsFactors = FALSE
    )
    rid <- rid + n
  }
  do.call(rbind, c(rows, list(make.row.names = FALSE)))
}

# ==============================================================================
# 2. SURVEY STRUCTURE WORKBOOK
# ==============================================================================

build_structure_workbook <- function(path) {
  project <- data.frame(
    Setting = c("project_name", "project_code", "client_name",
                "study_type", "study_date", "data_file", "total_sample",
                # Declared so the weighted config passes validation — the
                # unweighted configs simply never read the Weight column.
                "weight_column_exists", "weight_columns", "default_weight",
                "weight_description"),
    Value = c("Turas Cross-Engine Parity Fixture", "PARITY_2026",
              "Turas Analytics (Fixture)", "Ad-hoc", "20260101",
              "Parity_Survey_Data.xlsx", "200",
              "Y", "Weight", "Weight",
              "Synthetic cohort weights; every third respondent carries 1.75x."),
    stringsAsFactors = FALSE
  )

  questions <- data.frame(
    QuestionCode = c("Cohort", "Q1", "Q2", "Q3"),
    QuestionText = c("Cohort",
                     "Have you used the service in the last month?",
                     "How would you rate the service?",
                     "The service is good value for money"),
    Variable_Type = c("Single_Response", "Single_Response", "Rating", "Single_Response"),
    Columns = c(1L, 1L, 1L, 1L),
    Category = c("Demographics", "Usage", "Satisfaction", "Value"),
    # Optional columns the data-layer writer reads. Present-but-blank rather
    # than absent, so the fixture does not warn its way through every run.
    ShortLabel = c("", "", "", ""),
    LinkedOpenQuestion = c("", "", "", ""),
    stringsAsFactors = FALSE
  )

  opt <- function(code, texts, order, box = NA_character_, weights = NA) {
    data.frame(
      QuestionCode = code,
      OptionText = texts,
      DisplayText = texts,
      ShowInOutput = "Y",
      DisplayOrder = order,
      Index_Weight = weights,
      BoxCategory = box,
      ExcludeFromIndex = NA,
      stringsAsFactors = FALSE
    )
  }

  options_df <- rbind(
    opt("Cohort", c("Alpha", "Beta", "Gamma", "Delta"), 1:4),
    opt("Q1", c("Yes", "No"), 1:2),
    # Q2's box column groups 4+5 into a Top 2 Box NET; Index_Weight makes the
    # Index row a 0-100 rescale of the 1-5 mean.
    opt("Q2", as.character(1:5), 1:5,
        box = c(NA, NA, NA, "Top 2 Box", "Top 2 Box"),
        weights = c(0, 25, 50, 75, 100)),
    opt("Q3", c("Agree", "Disagree"), 1:2)
  )

  wb <- createWorkbook()
  addWorksheet(wb, "Project");   writeData(wb, "Project", project)
  addWorksheet(wb, "Questions"); writeData(wb, "Questions", questions)
  addWorksheet(wb, "Options");   writeData(wb, "Options", options_df)
  saveWorkbook(wb, path, overwrite = TRUE)
}

# ==============================================================================
# 3. CROSSTAB CONFIG WORKBOOK
# ==============================================================================

# The four-column universe table. Delta is deliberately absent: an unresolved
# column must fall back to no correction.
POPULATION_SHEET <- data.frame(
  Banner = c("Cohort", "Cohort", "Cohort"),
  Group = c("Alpha", "Beta", "Gamma"),
  Population = c(40, 150, 5000),
  stringsAsFactors = FALSE
)

build_config_workbook <- function(path, output_filename, weighted,
                                  with_population = TRUE, dual_alpha = TRUE) {
  settings <- list(
    structure_file = "Parity_Survey_Structure.xlsx",
    output_subfolder = "Output",
    output_filename = output_filename,
    output_format = "xlsx",
    apply_weighting = if (weighted) "TRUE" else "FALSE",
    weight_variable = "Weight",
    show_unweighted_n = "TRUE",
    show_effective_n = if (weighted) "TRUE" else "FALSE",
    show_frequency = "TRUE",
    show_percent_column = "TRUE",
    show_percent_row = "FALSE",
    decimal_places_percent = "0",
    decimal_places_ratings = "1",
    decimal_places_index = "1",
    boxcategory_frequency = "TRUE",
    boxcategory_percent_column = "TRUE",
    enable_significance_testing = "TRUE",
    alpha = "0.05",
    significance_min_base = "30",
    bonferroni_correction = "TRUE",
    create_index_summary = "Y",
    show_standard_deviation = "TRUE",
    show_net_positive = "FALSE",
    # No html_report row: the classic report is retired and the setting now
    # raises a pre-flight issue.
    project_title = "Cross-Engine Parity Fixture",
    brand_colour = "#323367",
    include_summary = "TRUE",
    show_charts = "FALSE"
  )
  if (dual_alpha) settings$alpha_secondary <- "0.20"
  if (with_population) settings$population_size <- "5000"

  settings_df <- data.frame(
    Setting = names(settings),
    Value = unlist(settings, use.names = FALSE),
    stringsAsFactors = FALSE
  )

  selection <- data.frame(
    QuestionCode = c("Cohort", "Q1", "Q2", "Q3"),
    Include = c("N", "Y", "Y", "Y"),
    UseBanner = c("Y", "N", "N", "N"),
    BannerLabel = c("Cohort", "", "", ""),
    DisplayOrder = c(1L, NA, NA, NA),
    CreateIndex = c("N", "N", "Y", "N"),
    # Q3 is routed: only respondents who answered Yes to Q1 were asked it.
    BaseFilter = c("", "", "", "Q1 == 'Yes'"),
    FilterLabel = c("", "", "", "Used the service in the last month"),
    Category = c("Demographics", "Usage", "Satisfaction", "Value"),
    stringsAsFactors = FALSE
  )

  wb <- createWorkbook()
  addWorksheet(wb, "Settings");  writeData(wb, "Settings", settings_df)
  addWorksheet(wb, "Selection"); writeData(wb, "Selection", selection)
  if (with_population) {
    addWorksheet(wb, "Population"); writeData(wb, "Population", POPULATION_SHEET)
  }
  saveWorkbook(wb, path, overwrite = TRUE)
}

# ==============================================================================
# 4. WRITE EVERYTHING
# ==============================================================================

generate_parity_project <- function(dir = FIXTURE_DIR) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)

  survey <- build_survey_data()
  wb <- createWorkbook()
  addWorksheet(wb, "Data"); writeData(wb, "Data", survey)
  saveWorkbook(wb, file.path(dir, "Parity_Survey_Data.xlsx"), overwrite = TRUE)

  build_structure_workbook(file.path(dir, "Parity_Survey_Structure.xlsx"))

  # Unweighted, dual alpha, with population — the main fixture.
  build_config_workbook(file.path(dir, "Parity_Crosstab_Config.xlsx"),
                        "Parity_Crosstabs.xlsx", weighted = FALSE)
  # Weighted variant: same data, real Kish effective bases.
  build_config_workbook(file.path(dir, "Parity_Crosstab_Config_Weighted.xlsx"),
                        "Parity_Crosstabs_Weighted.xlsx", weighted = TRUE)
  # No-population control: proves the fpc_mul defaults are inert (harness R-3).
  build_config_workbook(file.path(dir, "Parity_Crosstab_Config_NoPop.xlsx"),
                        "Parity_Crosstabs_NoPop.xlsx", weighted = FALSE,
                        with_population = FALSE)
  # The plainest report Turas can produce — unweighted, single alpha, no
  # population. This is the batch's guardrail case: its output must be identical
  # to what pre-batch main produced, because none of the new code paths engage.
  build_config_workbook(file.path(dir, "Parity_Crosstab_Config_Plain.xlsx"),
                        "Parity_Crosstabs_Plain.xlsx", weighted = FALSE,
                        with_population = FALSE, dual_alpha = FALSE)

  invisible(dir)
}

PARITY_WORKBOOKS <- c(
  "Parity_Survey_Data.xlsx", "Parity_Survey_Structure.xlsx",
  "Parity_Crosstab_Config.xlsx", "Parity_Crosstab_Config_Weighted.xlsx",
  "Parity_Crosstab_Config_NoPop.xlsx", "Parity_Crosstab_Config_Plain.xlsx"
)

#' Write the fixture workbooks if any of them is missing
#'
#' The repo gitignores *.xlsx, so the workbooks are NOT committed — this
#' generator is. Callers (the harness, the island regenerator) call this first;
#' generation is deterministic, so a rebuilt workbook is the same workbook.
ensure_parity_project <- function(dir = FIXTURE_DIR) {
  present <- file.exists(file.path(dir, PARITY_WORKBOOKS))
  if (!all(present)) generate_parity_project(dir)
  invisible(dir)
}

# Run only when invoked as a script (Rscript ...), not when sourced.
if (length(grep("^--file=", commandArgs(trailingOnly = FALSE))) > 0) {
  d <- generate_parity_project()
  cat("Parity fixture written to:", d, "\n")
  cat("Files:", paste(basename(list.files(d, pattern = "[.]xlsx$")), collapse = ", "), "\n")
}

# ==============================================================================
# MAXDIFF TESTS - REVIEW FOLLOW-UPS (REVIEW_FINDINGS_MAXDIFF_SESSION_A_2026-09-03)
# ==============================================================================
# F2  a refused HTML report is an event, not a footnote (integration test)
# F3  the numeric respondent ID is not an item in the report or simulator layer
# F4  ITEM_SCORES keeps the logit and HB utility columns
# F6  a position on an empty design slot refuses
# F7  a fractional position refuses
# F8  a non-numeric weight column refuses instead of crashing
# F10 an included item no design row shows fails validation
# F11 dropped-task disclosure reaches the study summary and SUMMARY sheet
# F12 sourcing 11_turf.R twice keeps the shared engine

.rf_numeric_id_utils <- function(n = 20, seed = 7) {
  set.seed(seed)
  data.frame(resp_id = 10000 + seq_len(n),
             A = rnorm(n, 1.0, 0.4), B = rnorm(n, 0.2, 0.4), C = rnorm(n, -1.2, 0.4),
             stringsAsFactors = FALSE)
}

.rf_items <- function(ids = c("A", "B", "C")) {
  data.frame(Item_ID = ids, Item_Label = tolower(ids), Item_Group = "G",
             Display_Order = seq_along(ids), Include = 1L, Anchor_Item = 0L,
             stringsAsFactors = FALSE)
}

.rf_hb <- function(iu) {
  list(individual_utilities = iu,
       population_utilities = data.frame(
         Item_ID = c("A", "B", "C"), Item_Label = c("a", "b", "c"), Item_Group = "G",
         Display_Order = 1:3, HB_Utility_Mean = c(1, 0.2, -1.2), HB_Utility_SD = 0.4,
         HB_Utility_Q5 = 0, HB_Utility_Q95 = 0, HB_Rhat = NA_real_, HB_ESS = NA_real_,
         Rank = 1:3, Estimation_Method = "Empirical Bayes (count-based; SD/Q5/Q95 are population spread, not posterior uncertainty)",
         stringsAsFactors = FALSE),
       model_fit = list(method = "empirical_bayes_shrinkage"), diagnostics = list())
}

# ------------------------------------------------------------------------------
# F3
# ------------------------------------------------------------------------------

test_that("F3: the simulator island never carries the respondent ID as a utility", {
  skip_if(!exists("build_simulator_data", mode = "function"))
  hb <- .rf_hb(.rf_numeric_id_utils())
  cfg <- list(items = .rf_items(), project_settings = list(Respondent_ID_Variable = "resp_id"),
              segment_settings = NULL)
  sim <- build_simulator_data(hb, NULL, cfg)
  expect_equal(length(sim$items), 3)
  expect_equal(length(sim$individual_utils[[1]]$utilities), 3)
  expect_true(all(abs(sim$individual_utils[[1]]$utilities) < 100))
})

test_that("F3: the report transformers ignore a numeric resp_id column", {
  skip_if(!exists("transform_diagnostics_section", mode = "function"))
  res <- list(hb_results = .rf_hb(.rf_numeric_id_utils()))
  cfg <- list(items = .rf_items(), project_settings = list(Project_Name = "P"), output_settings = list())

  # The diagnostics transformer used to crash here ("row names contain
  # missing values"), which refused the whole report.
  expect_error(diag <- transform_diagnostics_section(res, cfg), NA)

  h2h <- transform_h2h_section(res, cfg)
  expect_false("resp_id" %in% rownames(h2h$h2h_data))
  expect_setequal(rownames(h2h$h2h_data), c("A", "B", "C"))

  ud <- transform_utility_distributions(res)
  ud_ids <- if (is.data.frame(ud)) ud$Item_ID else ud$stats$Item_ID %||% ud$dist_df$Item_ID
  expect_false("resp_id" %in% ud_ids)
})

# ------------------------------------------------------------------------------
# F4
# ------------------------------------------------------------------------------

test_that("F4: ITEM_SCORES keeps the utility columns the orchestrator already merged", {
  cs <- data.frame(Item_ID = c("A", "B"), Item_Label = c("a", "b"), Item_Group = "G",
                   Times_Shown = 10, Times_Best = c(6, 2), Times_Worst = c(1, 5),
                   Best_Pct = c(60, 20), Worst_Pct = c(10, 50), Net_Score = c(50, -30),
                   BW_Score = c(0.5, -0.3), Rank = 1:2, Display_Order = 1:2,
                   Logit_Utility = c(1.2, 0), Logit_SE = c(0.1, NA),
                   HB_Utility_Mean = c(0.9, -0.4), HB_Utility_SD = 0.3, stringsAsFactors = FALSE)
  results <- list(
    count_scores = cs,
    logit_results = list(utilities = cs[, c("Item_ID", "Logit_Utility", "Logit_SE")]),
    hb_results = list(population_utilities = cs[, c("Item_ID", "HB_Utility_Mean", "HB_Utility_SD")]))
  config <- list(output_settings = get_default_output_settings())
  wb <- openxlsx::createWorkbook()
  write_item_scores_sheet(wb, results, config, create_output_styles())
  tmp <- tempfile(fileext = ".xlsx"); on.exit(unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp)
  sheet <- openxlsx::read.xlsx(tmp, "ITEM_SCORES")
  expect_true(all(c("Logit_Utility", "Logit_SE", "HB_Utility_Mean", "HB_Utility_SD") %in% names(sheet)))
  # Rescaled_Score derives from the HB mean, not Net_Score: the top item is A.
  expect_equal(sheet$Item_ID[sheet$Rank == 1], "A")
  expect_equal(sheet$Logit_Utility[sheet$Item_ID == "A"], 1.2)
})

# ------------------------------------------------------------------------------
# F6, F7
# ------------------------------------------------------------------------------

.rf_design <- function() data.frame(Version = c(1L, 1L), Task_Number = c(1L, 2L),
  Item1_ID = c("APPLE", "CHERRY"), Item2_ID = c("BANANA", "DATE"), Item3_ID = c("CHERRY", "APPLE"),
  stringsAsFactors = FALSE)
.rf_mapping <- function() data.frame(
  Field_Type = c("VERSION", "BEST_CHOICE", "WORST_CHOICE", "BEST_CHOICE", "WORST_CHOICE"),
  Field_Name = c("Version", "T1_Best", "T1_Worst", "T2_Best", "T2_Worst"),
  Task_Number = c(NA, 1L, 1L, 2L, 2L), stringsAsFactors = FALSE)
.rf_cfg <- function(v = "ITEM_POSITION") list(project_settings = list(
  Respondent_ID_Variable = "RespID", Weight_Variable = NULL, Choice_Value_Type = v))

test_that("F6: a position that lands on an empty design slot refuses", {
  d <- .rf_design(); d$Item3_ID[2] <- NA      # task 2 shows only two items
  data <- data.frame(RespID = "R1", Version = 1L, T1_Best = 1L, T1_Worst = 3L,
                     T2_Best = 3L, T2_Worst = 2L, stringsAsFactors = FALSE)
  expect_error(build_maxdiff_long(data, .rf_mapping(), d, .rf_cfg(), verbose = FALSE),
               "DATA_CHOICE_POSITION_INVALID|position")
})

test_that("F7: a fractional position refuses instead of truncating", {
  for (bad in list("2.7", 2.7)) {
    data <- data.frame(RespID = "R1", Version = 1L, T1_Best = bad, T1_Worst = 3,
                       T2_Best = 1, T2_Worst = 2, stringsAsFactors = FALSE)
    expect_error(build_maxdiff_long(data, .rf_mapping(), .rf_design(), .rf_cfg(), verbose = FALSE),
                 "DATA_CHOICE_POSITION_INVALID|whole-number")
  }
  # Whole numbers stored as doubles still decode.
  data <- data.frame(RespID = "R1", Version = 1L, T1_Best = 1, T1_Worst = 3, T2_Best = 3, T2_Worst = 2)
  long <- build_maxdiff_long(data, .rf_mapping(), .rf_design(), .rf_cfg(), verbose = FALSE)
  expect_equal(long$item_id[long$task == 1 & long$is_best == 1], "APPLE")
})

# ------------------------------------------------------------------------------
# F8, F10
# ------------------------------------------------------------------------------

test_that("F8: a non-numeric weight column refuses with the column named", {
  v <- validate_maxdiff_weights(c("1,2", "0,8"), verbose = FALSE)
  expect_false(v$valid)
  expect_true(any(grepl("not numeric", v$issues)))
})

test_that("F10: an included item that no design row shows fails validation", {
  items <- .rf_items(c("APPLE", "BANANA", "CHERRY", "DATE", "ELDER"))
  data <- data.frame(RespID = "R1", Version = 1L, T1_Best = "APPLE", T1_Worst = "CHERRY",
                     T2_Best = "DATE", T2_Worst = "APPLE", stringsAsFactors = FALSE)
  v <- validate_survey_data(data, .rf_mapping(), .rf_design(), items, verbose = FALSE)
  expect_false(v$valid)
  expect_true(any(grepl("ELDER", v$issues) & grepl("no design row", v$issues)))
})

.rf_long_for_eb <- function() {
  set.seed(4); items <- c("A", "B", "C"); rows <- list()
  for (r in 1:12) for (t in 1:3) {
    best <- sample(items, 1); worst <- sample(setdiff(items, best), 1)
    for (pos in seq_along(items)) rows[[length(rows) + 1]] <- data.frame(
      resp_id = paste0("R", r), version = 1L, task = t, item_id = items[pos], position = pos,
      is_best = as.integer(items[pos] == best), is_worst = as.integer(items[pos] == worst),
      weight = 1, stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows); out$obs_id <- seq_len(nrow(out)); out
}

# ------------------------------------------------------------------------------
# F11
# ------------------------------------------------------------------------------

test_that("F11: the study summary counts tasks the models drop", {
  # 6 respondents x 2 tasks x 3 items; respondent R1's task 2 has a best but no worst.
  items <- c("A", "B", "C"); rows <- list()
  for (r in 1:6) for (t in 1:2) {
    best <- items[(r + t) %% 3 + 1]; worst <- items[(r + t + 1) %% 3 + 1]
    for (pos in seq_along(items)) rows[[length(rows) + 1]] <- data.frame(
      resp_id = paste0("R", r), version = 1L, task = t, item_id = items[pos], position = pos,
      is_best = as.integer(items[pos] == best),
      is_worst = as.integer(items[pos] == worst && !(r == 1 && t == 2)),
      weight = 1, stringsAsFactors = FALSE)
  }
  long <- do.call(rbind, rows)
  ss <- compute_study_summary(long, list(project_settings = list(Weight_Variable = NULL)), verbose = FALSE)
  expect_equal(ss$n_tasks_total, 12)
  expect_equal(ss$n_tasks_dropped_from_models, 1)
})

# ------------------------------------------------------------------------------
# F12
# ------------------------------------------------------------------------------

test_that("F12: sourcing 11_turf.R a second time keeps the shared engine", {
  turf_file <- file.path(TURAS_ROOT, "modules", "maxdiff", "R", "11_turf.R")
  skip_if(!file.exists(turf_file))
  source(turf_file, local = FALSE)
  df <- .rf_numeric_id_utils()
  res <- run_turf_analysis(df, .rf_items(), max_items = 2, verbose = FALSE)
  expect_equal(res$status, "PASS")
  expect_equal(as.character(res$incremental_table$Item_ID[1]), "A")
})

# ------------------------------------------------------------------------------
# F2 + F3 + F4 + F11 end to end: a synthetic ANALYSIS run with numeric IDs
# ------------------------------------------------------------------------------

test_that("integration: a numeric-ID, weighted, position-coded run ships every deliverable", {
  skip_if(!requireNamespace("survival", quietly = TRUE))
  main <- file.path(TURAS_ROOT, "modules", "maxdiff", "R", "00_main.R")
  skip_if(!file.exists(main))
  source(main, local = FALSE)   # sources the module files again; 11_turf.R is guarded (F12)

  W <- tempfile("md_e2e_"); dir.create(W); on.exit(unlink(W, recursive = TRUE), add = TRUE)
  ids <- sprintf("ITEM_%02d", 1:6); set.seed(3); K <- 4; nT <- 6
  des <- do.call(rbind, lapply(seq_len(nT), function(t) {
    sh <- c(ids[((t - 1) %% 6) + 1], sample(setdiff(ids, ids[((t - 1) %% 6) + 1]), K - 1))
    data.frame(Version = 1L, Task_Number = t, Item1_ID = sh[1], Item2_ID = sh[2],
               Item3_ID = sh[3], Item4_ID = sh[4], stringsAsFactors = FALSE) }))
  expect_true(all(ids %in% unlist(des[, 3:6])))
  openxlsx::write.xlsx(list(DESIGN = des), file.path(W, "design.xlsx"))
  tu <- setNames(seq(1.5, -1.5, length.out = 6), ids); nR <- 40
  dat <- data.frame(Region = rep(c("N", "S"), 20), RespID = 10000 + seq_len(nR), Version = 1L,
                    Weight = round(runif(nR, 0.5, 2), 3))
  for (t in seq_len(nT)) { sh <- unlist(des[t, 3:6]); b <- w <- integer(nR)
    for (r in seq_len(nR)) { u <- tu[sh]; bi <- sample(K, 1, prob = exp(u) / sum(exp(u)))
      rem <- setdiff(seq_len(K), bi); wi <- sample(rem, 1, prob = exp(-u[rem]) / sum(exp(-u[rem])))
      b[r] <- bi; w[r] <- wi }
    dat[[sprintf("MaxDiff_T%d_Best", t)]] <- b; dat[[sprintf("MaxDiff_T%d_Worst", t)]] <- w }
  write.csv(dat, file.path(W, "data.csv"), row.names = FALSE)

  ps <- data.frame(Setting_Name = c("Project_Name", "Mode", "Raw_Data_File", "Design_File", "Output_Folder",
                                    "Respondent_ID_Variable", "Weight_Variable", "Choice_Value_Type", "Seed"),
                   Value = c("E2E", "ANALYSIS", file.path(W, "data.csv"), file.path(W, "design.xlsx"),
                             file.path(W, "output"), "RespID", "Weight", "ITEM_POSITION", "1"),
                   stringsAsFactors = FALSE)
  items <- data.frame(Item_ID = ids, Item_Label = paste("Item", 1:6), Include = 1L, Anchor_Item = 0L,
                      Display_Order = 1:6, stringsAsFactors = FALSE)
  mapping <- data.frame(Field_Type = c("VERSION", rep(c("BEST_CHOICE", "WORST_CHOICE"), nT)),
                        Field_Name = c("Version", as.vector(rbind(sprintf("MaxDiff_T%d_Best", 1:nT),
                                                                 sprintf("MaxDiff_T%d_Worst", 1:nT)))),
                        Task_Number = c(NA, rep(1:nT, each = 2)), stringsAsFactors = FALSE)
  os <- data.frame(Setting_Name = c("Generate_Aggregate_Logit", "Generate_HB_Model", "Generate_HTML_Report",
                                    "Generate_Simulator", "Generate_TURF", "Export_Individual_Utils",
                                    "Generate_Stats_Pack", "Generate_Charts"),
                   Value = c("YES", "YES", "YES", "YES", "YES", "YES", "NO", "NO"), stringsAsFactors = FALSE)
  cfgp <- file.path(W, "config.xlsx")
  openxlsx::write.xlsx(list(PROJECT_SETTINGS = ps, ITEMS = items, SURVEY_MAPPING = mapping,
                            OUTPUT_SETTINGS = os), cfgp)

  out <- capture.output(res <- suppressMessages(run_maxdiff(cfgp, verbose = FALSE)), type = "output")
  expect_false(inherits(res, "turas_refusal_result"))
  expect_false(any(grepl("MAXD_HTML_TRANSFORM_FAILED|MAXD_HTML_REFUSED", out)))

  html <- list.files(file.path(W, "output"), pattern = "\\.html$", full.names = TRUE)
  expect_equal(length(html), 1)
  txt <- paste(readLines(html, warn = FALSE), collapse = "\n")
  expect_false(grepl("resp_id", txt, fixed = TRUE))
  # The simulator island (HTML-escaped JSON): 6 items, 6 utilities per respondent (F3).
  island <- regmatches(txt, regexpr('individual_utils&quot;:\\[\\{&quot;utilities&quot;:\\[[^]]*\\]', txt))
  expect_equal(length(island), 1)
  expect_equal(length(strsplit(sub('.*\\[', "", island), ",")[[1]]), 6)

  xl <- list.files(file.path(W, "output"), pattern = "Results\\.xlsx$", full.names = TRUE)
  expect_equal(length(xl), 1)
  scores <- openxlsx::read.xlsx(xl, "ITEM_SCORES")
  expect_true(all(c("Logit_Utility", "Logit_SE", "HB_Utility_Mean", "HB_Utility_SD") %in% names(scores)))   # F4
  expect_true(all(is.finite(scores$Best_Pct)))
  summ <- openxlsx::read.xlsx(xl, "SUMMARY", skipEmptyRows = FALSE)
  expect_true(any(grepl("Tasks excluded from logit/HB", summ[[1]])))   # F11
})

# ------------------------------------------------------------------------------
# F5 ruling: HB_Utility_SD is the spread across respondents on both paths
# ------------------------------------------------------------------------------

test_that("F5: hb_spread_across_respondents returns the SD and percentiles of the respondents' utilities", {
  skip_if(!exists("hb_spread_across_respondents", mode = "function"))
  iu <- data.frame(resp_id = c("r1", "r2", "r3", "r4"),
                   A = c(1, 2, 3, 4), B = c(0, 0, 0, 0), stringsAsFactors = FALSE)
  sp <- hb_spread_across_respondents(iu, c("A", "B", "ZZ"))
  expect_equal(sp$sd, c(sd(1:4), 0, NA_real_))
  expect_equal(sp$q5, c(unname(quantile(1:4, 0.05)), 0, NA_real_))
  expect_equal(sp$q95, c(unname(quantile(1:4, 0.95)), 0, NA_real_))
})

test_that("F5: the EB path carries an NA HB_Mean_SE, so both paths share one schema", {
  long <- .rf_long_for_eb()
  res <- fit_approximate_hb(long, .rf_items(), list(), verbose = FALSE)
  pop <- res$population_utilities
  expect_true(all(c("HB_Mean_SE", "HB_Mean_Q5", "HB_Mean_Q95") %in% names(pop)))
  expect_true(all(is.na(pop$HB_Mean_SE)))
  # And the SD really is the spread of the shrunken individual scores.
  iu <- res$individual_utilities
  expect_equal(pop$HB_Utility_SD[pop$Item_ID == "A"], sd(iu$A), tolerance = 1e-8)
})

test_that("F5: the report labels the column as spread, and shows SE only when a posterior exists", {
  skip_if(!exists("transform_preferences_section", mode = "function"))
  hb <- .rf_hb(.rf_numeric_id_utils())
  hb$population_utilities$HB_Mean_SE <- NA_real_
  cfg <- list(items = .rf_items(), project_settings = list(Project_Name = "P"), output_settings = list())
  pref <- transform_preferences_section(list(hb_results = hb), cfg)
  expect_true("Spread_SD" %in% names(pref$scores))
  expect_true(!"SE" %in% names(pref$scores) || all(is.na(pref$scores$SE)))
  html <- build_preference_scores_table(pref$scores)
  expect_true(grepl("Spread (SD)", html, fixed = TRUE))
  expect_false(grepl(">SE<", html, fixed = TRUE))

  hb$population_utilities$HB_Mean_SE <- 0.05
  hb$population_utilities$Estimation_Method <- "Stan HB (cmdstanr posterior)"
  pref2 <- transform_preferences_section(list(hb_results = hb), cfg)
  html2 <- build_preference_scores_table(pref2$scores)
  expect_true(grepl("Spread (SD)", html2, fixed = TRUE))
  expect_true(grepl(">SE<", html2, fixed = TRUE))
})

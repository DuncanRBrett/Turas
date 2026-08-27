# ==============================================================================
# MAXDIFF TESTS - A5: GUI HONESTY AND HONEST LABELS (H4, H5, M2, M5, M6, M11, M12)
# ==============================================================================

.a5_long <- function(drop_worst_for_task = NULL) {
  # 6 respondents x 2 tasks x 3 items, ITEM-coded, complete unless asked not to.
  items <- c("A", "B", "C")
  rows <- list()
  for (r in 1:6) {
    for (t in 1:2) {
      best <- items[(r + t) %% 3 + 1]
      worst <- items[(r + t + 1) %% 3 + 1]
      for (pos in seq_along(items)) {
        is_worst <- as.integer(items[pos] == worst)
        if (!is.null(drop_worst_for_task) && t == drop_worst_for_task && r == 1) {
          is_worst <- 0L   # task with a best but NO worst -> must be disclosed
        }
        rows[[length(rows) + 1]] <- data.frame(
          resp_id = paste0("R", r), version = 1L, task = t,
          item_id = items[pos], position = pos,
          is_best = as.integer(items[pos] == best),
          is_worst = is_worst,
          weight = 1, stringsAsFactors = FALSE
        )
      }
    }
  }
  out <- do.call(rbind, rows)
  out$obs_id <- seq_len(nrow(out))
  out
}

.a5_items <- function() {
  data.frame(Item_ID = c("A", "B", "C"),
             Item_Label = c("Alpha", "Beta", "Gamma"),
             Item_Group = "G", Display_Order = 1:3,
             Include = 1L, Anchor_Item = 0L, stringsAsFactors = FALSE)
}

# ------------------------------------------------------------------------------
# M5: the EB fallback stamps what its numbers are
# ------------------------------------------------------------------------------

test_that("M5: EB population utilities carry an honest Estimation_Method stamp", {
  res <- fit_approximate_hb(.a5_long(), .a5_items(), list(), verbose = FALSE)
  pop <- res$population_utilities

  expect_true("Estimation_Method" %in% names(pop))
  expect_true(all(grepl("Empirical Bayes", pop$Estimation_Method)))
  expect_true(all(grepl("population spread", pop$Estimation_Method)))
  expect_equal(res$model_fit$method, "empirical_bayes_shrinkage")
})

# ------------------------------------------------------------------------------
# M2: dropped tasks are disclosed, not swallowed
# ------------------------------------------------------------------------------

test_that("M2: a task without a worst choice is counted out loud (HB path)", {
  long <- .a5_long(drop_worst_for_task = 2)
  out <- capture.output(stan_data <- prepare_stan_data(long, .a5_items()))
  expect_true(any(grepl("MAXD_TASKS_DROPPED", out)))
  expect_true(any(grepl("1 of 12 tasks", out)))
})

test_that("M2: a task without a worst choice is counted out loud (logit path)", {
  long <- .a5_long(drop_worst_for_task = 1)
  out <- capture.output(
    ld <- prepare_logit_data(long, c("A", "B", "C"), anchor_item = NULL)
  )
  expect_true(any(grepl("MAXD_TASKS_DROPPED", out)))
})

# ------------------------------------------------------------------------------
# M11 / M12: output-settings defaults and parsing
# ------------------------------------------------------------------------------

test_that("M12: the HTML report defaults ON, as the manual always claimed", {
  defaults <- get_default_output_settings()
  expect_true(isTRUE(defaults$Generate_HTML_Report))
})

test_that("M11: Generate_Stats_Pack is read from OUTPUT_SETTINGS", {
  df <- data.frame(Option_Name = "Generate_Stats_Pack", Value = "NO",
                   stringsAsFactors = FALSE)
  parsed <- parse_output_settings(df)
  expect_false(isTRUE(parsed$Generate_Stats_Pack))

  df$Value <- "YES"
  expect_true(isTRUE(parse_output_settings(df)$Generate_Stats_Pack))
})

# ------------------------------------------------------------------------------
# H4 / H5 / M6: source-level guarantees
# ------------------------------------------------------------------------------

test_that("H4/H5: the GUI checks the result status and captures messages", {
  gui <- file.path(TURAS_ROOT, "modules", "maxdiff", "run_maxdiff_gui.R")
  skip_if(!file.exists(gui), "GUI file not present")
  src <- paste(readLines(gui, warn = FALSE), collapse = "\n")

  # H5: messages are sunk alongside stdout (the Stan-fallback notice is a
  # message; a stdout-only sink hid it).
  expect_true(grepl('sink(capture_con, type = "message")', src, fixed = TRUE))
  expect_true(grepl('sink(type = "message")', src, fixed = TRUE))

  # H4: a refusal never gets the green success toast.
  expect_true(grepl("turas_refusal_result", src, fixed = TRUE))
  expect_true(grepl("MAXDIFF %s REFUSED", src, fixed = TRUE))
})

test_that("M6: the stats pack no longer claims ChoiceModelR", {
  main <- file.path(TURAS_ROOT, "modules", "maxdiff", "R", "00_main.R")
  src <- paste(readLines(main, warn = FALSE), collapse = "\n")

  expect_false(grepl("ChoiceModelR", src, fixed = TRUE))
  expect_true(grepl("Stan HB (cmdstanr)", src, fixed = TRUE))
  expect_true(grepl("Empirical Bayes shrinkage", src, fixed = TRUE))
})

# ------------------------------------------------------------------------------
# A7: M4, M7, M8, M9
# ------------------------------------------------------------------------------

test_that("M4: an Include=0 item that is in the fielded design fails validation", {
  design <- data.frame(Version = 1L, Task_Number = 1L,
                       Item1_ID = "A", Item2_ID = "B", Item3_ID = "C",
                       stringsAsFactors = FALSE)
  mapping <- data.frame(Field_Type = c("VERSION", "BEST_CHOICE", "WORST_CHOICE"),
                        Field_Name = c("Version", "T1_Best", "T1_Worst"),
                        Task_Number = c(NA, 1L, 1L), stringsAsFactors = FALSE)
  items <- data.frame(Item_ID = c("A", "B", "C"),
                      Item_Label = c("a", "b", "c"),
                      Include = c(1L, 1L, 0L),      # C excluded but fielded
                      Anchor_Item = 0L, stringsAsFactors = FALSE)
  data <- data.frame(RespID = "R1", Version = 1L,
                     T1_Best = "A", T1_Worst = "B", stringsAsFactors = FALSE)

  v <- validate_survey_data(data, mapping, design, items, verbose = FALSE)
  expect_false(v$valid)
  expect_true(any(grepl("Include = 0", v$issues)))
})

test_that("M7: the study summary discloses weighting engine by engine", {
  long <- .a5_long()
  cfg <- list(project_settings = list(Weight_Variable = "W"))
  ss <- compute_study_summary(long, cfg, verbose = FALSE)

  expect_true(!is.null(ss$weighting_by_engine))
  expect_match(ss$weighting_by_engine$hb, "UNWEIGHTED")
  expect_match(ss$weighting_by_engine$counts, "weighted")

  ss_uw <- compute_study_summary(long,
                                 list(project_settings = list(Weight_Variable = NULL)),
                                 verbose = FALSE)
  expect_equal(ss_uw$weighting_by_engine$hb, "unweighted")
})

test_that("M8: the anti-conservative count CI machinery is gone", {
  expect_false(exists("add_count_confidence_intervals", mode = "function"))
})

test_that("M9: respondents with an NA design version are counted out loud", {
  fxd <- data.frame(Version = c(1L, 1L), Task_Number = c(1L, 2L),
                    Item1_ID = c("APPLE", "CHERRY"), Item2_ID = c("BANANA", "DATE"),
                    Item3_ID = c("CHERRY", "APPLE"), stringsAsFactors = FALSE)
  fxm <- data.frame(Field_Type = c("VERSION", "BEST_CHOICE", "WORST_CHOICE",
                                   "BEST_CHOICE", "WORST_CHOICE"),
                    Field_Name = c("Version", "T1_Best", "T1_Worst", "T2_Best", "T2_Worst"),
                    Task_Number = c(NA, 1L, 1L, 2L, 2L), stringsAsFactors = FALSE)
  data <- data.frame(RespID = c("R1", "R2"), Version = c(1L, NA),
                     T1_Best = c("APPLE", "BANANA"), T1_Worst = c("CHERRY", "APPLE"),
                     T2_Best = c("DATE", "CHERRY"), T2_Worst = c("APPLE", "DATE"),
                     stringsAsFactors = FALSE)
  cfg <- list(project_settings = list(Respondent_ID_Variable = "RespID",
                                      Weight_Variable = NULL,
                                      Choice_Value_Type = "ITEM_ID"))

  out <- capture.output(long <- build_maxdiff_long(data, fxm, fxd, cfg, verbose = FALSE))
  expect_true(any(grepl("MAXD_NA_VERSION", out)))
  expect_true(any(grepl("1 respondent", out)))
  expect_equal(sort(unique(long$resp_id)), "R1")
})

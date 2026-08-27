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

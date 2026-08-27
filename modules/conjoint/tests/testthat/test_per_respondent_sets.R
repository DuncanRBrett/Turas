# ==============================================================================
# TESTS: CHOICE SETS ARE (RESPONDENT, SET), NOT SET (review finding H1)
# ==============================================================================
#
# The estimator explicitly supports set ids numbered within respondent — it
# builds chid as respondent x set. Several validators grouped by the set id
# alone, so with that layout every "set" pooled the whole sample:
#
#   - validate_none_choices() saw n_chosen = number of respondents, and
#     refused every explicit-None dataset.
#   - detect_none_option()'s method 2 never found an all-unchosen set, so
#     implicit-None detection silently never fired.
#   - handle_implicit_none() attributed every none row to whichever respondent
#     sorted first.
#   - Best-worst validation failed every dataset for the same reason.
#
# Each test below builds data with set ids 1..n_tasks repeated per respondent.
# ==============================================================================

make_per_respondent_data <- function(n_respondents = 6, n_tasks = 4, n_alts = 3,
                                     none_mode = c("none", "explicit", "implicit"),
                                     seed = 1) {
  none_mode <- match.arg(none_mode)
  set.seed(seed)

  rows <- list()
  for (r in seq_len(n_respondents)) {
    for (t in seq_len(n_tasks)) {
      # NOTE: set id restarts at 1 for every respondent.
      alts <- seq_len(n_alts)
      chosen_alt <- sample(alts, 1)

      for (a in alts) {
        rows[[length(rows) + 1]] <- data.frame(
          resp_id = r,
          choice_set_id = t,
          alternative_id = a,
          Brand = sample(c("Alpha", "Beta", "Gamma"), 1),
          Price = sample(c("$10", "$20"), 1),
          chosen = as.integer(a == chosen_alt),
          stringsAsFactors = FALSE
        )
      }

      if (none_mode == "explicit") {
        # A real None alternative, chosen in every fourth task.
        none_chosen <- (t %% 4 == 0)
        if (none_chosen) {
          for (i in seq(length(rows) - n_alts + 1, length(rows))) {
            rows[[i]]$chosen <- 0L
          }
        }
        rows[[length(rows) + 1]] <- data.frame(
          resp_id = r,
          choice_set_id = t,
          alternative_id = n_alts + 1,
          Brand = "None",
          Price = "None",
          chosen = as.integer(none_chosen),
          stringsAsFactors = FALSE
        )
      } else if (none_mode == "implicit" && t %% 4 == 0) {
        # Nothing chosen at all in this task.
        for (i in seq(length(rows) - n_alts + 1, length(rows))) {
          rows[[i]]$chosen <- 0L
        }
      }
    }
  }

  do.call(rbind, rows)
}

make_config <- function() {
  attributes <- list(Brand = c("Alpha", "Beta", "Gamma"), Price = c("$10", "$20"))
  attr_df <- data.frame(
    AttributeName = names(attributes),
    NumLevels = sapply(attributes, length),
    stringsAsFactors = FALSE
  )
  attr_df$levels_list <- unname(attributes)
  list(
    respondent_id_column = "resp_id",
    choice_set_column = "choice_set_id",
    alternative_id_column = "alternative_id",
    chosen_column = "chosen",
    attributes = attr_df,
    none_label = "None",
    confidence_level = 0.95
  )
}

test_that("H1: a valid explicit-None dataset with per-respondent set ids validates", {
  data <- make_per_respondent_data(none_mode = "explicit")
  config <- make_config()
  data$is_none_alternative <- data$Brand == "None"

  # Sanity: set ids really do repeat across respondents.
  expect_equal(sort(unique(data$choice_set_id)), 1:4)
  expect_gt(length(unique(data$resp_id)), 1)

  # Must not refuse.
  expect_silent(validate_none_choices(data, config))
})

test_that("H1: validate_none_choices still catches a genuinely bad set", {
  data <- make_per_respondent_data(none_mode = "explicit")
  config <- make_config()
  data$is_none_alternative <- data$Brand == "None"

  # Respondent 2, set 1: choose two alternatives.
  bad <- which(data$resp_id == 2 & data$choice_set_id == 1)
  data$chosen[bad[1]] <- 1L
  data$chosen[bad[2]] <- 1L

  cond <- tryCatch({ validate_none_choices(data, config); NULL },
                   turas_refusal = function(e) e)

  expect_false(is.null(cond))
  expect_equal(cond$code, "DATA_INVALID_NONE_CHOICES")
})

test_that("H1: implicit None is detected when set ids repeat per respondent", {
  data <- make_per_respondent_data(none_mode = "implicit")
  config <- make_config()

  info <- detect_none_option(data, config)

  expect_true(isTRUE(info$has_none) || isTRUE(info$has_all_zeros) ||
                isTRUE(info$none_type == "implicit"),
              info = paste("detect_none_option returned:",
                           paste(names(info), collapse = ", ")))
})

test_that("H1: implicit-None rows are attributed to the right respondent", {
  data <- make_per_respondent_data(none_mode = "implicit")
  config <- make_config()

  result <- handle_implicit_none(data, config, none_info = list(), verbose = FALSE)

  expect_true(result$has_none)

  none_rows <- result$data[isTRUE(result$data$is_none_alternative) |
                             result$data$is_none_alternative %in% TRUE, , drop = FALSE]

  # One none row per (respondent, empty task): 6 respondents x 1 empty task.
  expect_equal(nrow(none_rows), 6)
  expect_equal(sort(unique(none_rows$resp_id)), 1:6)
})

test_that("H1: best-worst validation accepts per-respondent set ids", {
  set.seed(9)
  rows <- list()
  for (r in 1:5) {
    for (t in 1:4) {
      picks <- sample(1:3, 2)
      for (a in 1:3) {
        rows[[length(rows) + 1]] <- data.frame(
          resp_id = r, choice_set_id = t, alt_id = a,
          Brand = sample(c("Alpha", "Beta", "Gamma"), 1),
          best = as.integer(a == picks[1]),
          worst = as.integer(a == picks[2]),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  data <- do.call(rbind, rows)

  config <- make_config()
  config$alternative_id_column <- "alt_id"

  v <- validate_best_worst_data(data, config)

  expect_length(v$critical, 0)
})

test_that("H1: best-worst validation still catches a set with two bests", {
  set.seed(9)
  rows <- list()
  for (r in 1:5) {
    for (t in 1:4) {
      picks <- sample(1:3, 2)
      for (a in 1:3) {
        rows[[length(rows) + 1]] <- data.frame(
          resp_id = r, choice_set_id = t, alt_id = a,
          Brand = sample(c("Alpha", "Beta", "Gamma"), 1),
          best = as.integer(a == picks[1]),
          worst = as.integer(a == picks[2]),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  data <- do.call(rbind, rows)
  # Respondent 3, set 2: two bests.
  idx <- which(data$resp_id == 3 & data$choice_set_id == 2)
  data$best[idx] <- c(1L, 1L, 0L)
  data$worst[idx] <- c(0L, 0L, 1L)

  config <- make_config()
  config$alternative_id_column <- "alt_id"

  v <- validate_best_worst_data(data, config)

  expect_gt(length(v$critical), 0)
  expect_true(any(grepl("'best'", v$critical, fixed = TRUE)))
})

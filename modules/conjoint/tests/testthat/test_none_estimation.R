# ==============================================================================
# TESTS: NONE ALTERNATIVES DO NOT REACH THE ESTIMATORS (review finding H8)
# ==============================================================================
#
# None rows carry the none label in every attribute column, and the estimators
# factor attributes on the configured levels only, so those rows become NA on
# every attribute. There is no alternative-specific constant for them to land
# on. Before this fix, mlogit failed and the module reported
# CFG_EST_MLOGIT_FAILED with the message "missing value where TRUE/FALSE
# needed" — a refusal that tells the user nothing about the cause or the fix.
#
# Estimating a None alternative properly is a planned feature: it needs the
# design constant, the reference-level handling and the simulator's none
# utility together. Until then the module says so.
# ==============================================================================

make_none_data <- function(n_respondents = 20, n_tasks = 4, n_alts = 3,
                           with_none = TRUE, seed = 3) {
  set.seed(seed)
  rows <- list()
  for (r in seq_len(n_respondents)) {
    for (t in seq_len(n_tasks)) {
      chosen_alt <- sample(seq_len(n_alts + as.integer(with_none)), 1)
      for (a in seq_len(n_alts)) {
        rows[[length(rows) + 1]] <- data.frame(
          resp_id = r, choice_set_id = t, alternative_id = a,
          Brand = sample(c("Alpha", "Beta", "Gamma"), 1),
          Price = sample(c("$10", "$20"), 1),
          chosen = as.integer(a == chosen_alt),
          stringsAsFactors = FALSE
        )
      }
      if (with_none) {
        rows[[length(rows) + 1]] <- data.frame(
          resp_id = r, choice_set_id = t, alternative_id = n_alts + 1,
          Brand = "None", Price = "None",
          chosen = as.integer(chosen_alt == n_alts + 1),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

none_config <- function() {
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
    estimation_method = "mlogit",
    analysis_type = "choice",
    confidence_level = 0.95,
    none_label = "None",
    zero_center_utilities = TRUE
  )
}

test_that("H8: an explicit None alternative refuses with a message that names the cause", {
  data <- make_none_data(with_none = TRUE)
  config <- none_config()

  cond <- tryCatch(
    {
      suppressWarnings(capture.output(
        estimate_choice_model(list(data = data), config, verbose = FALSE),
        type = "output"
      ))
      NULL
    },
    turas_refusal = function(e) e
  )

  expect_false(is.null(cond))
  expect_equal(cond$code, "FEATURE_NONE_ALTERNATIVE_NOT_ESTIMABLE")

  # It must say how many None rows there are and what to do, not just fail.
  expect_match(cond$problem, "None")
  expect_match(cond$problem, "80")  # 20 respondents x 4 tasks, one None row each
  expect_gt(length(cond$how_to_fix), 1)
  expect_true(any(grepl("Remove the None rows", cond$how_to_fix, fixed = TRUE)))
})

test_that("H8: the refusal also fires on the is_none_alternative flag", {
  data <- make_none_data(with_none = TRUE)
  config <- none_config()

  # Same data, but the None marker is the flag column rather than the label.
  data$is_none_alternative <- data$Brand == "None"
  data$Brand[data$is_none_alternative] <- "Alpha"
  data$Price[data$is_none_alternative] <- "$10"

  cond <- tryCatch(
    {
      suppressWarnings(capture.output(
        estimate_choice_model(list(data = data), config, verbose = FALSE),
        type = "output"
      ))
      NULL
    },
    turas_refusal = function(e) e
  )

  expect_false(is.null(cond))
  expect_equal(cond$code, "FEATURE_NONE_ALTERNATIVE_NOT_ESTIMABLE")
})

test_that("H8: ordinary data without a None alternative still estimates", {
  skip_if_not_installed("mlogit")

  data <- make_none_data(with_none = FALSE)
  config <- none_config()

  suppressWarnings(capture.output(
    model <- estimate_choice_model(list(data = data), config, verbose = FALSE),
    type = "output"
  ))

  expect_true(!is.null(model$coefficients))
  expect_gt(length(model$coefficients), 0)
})

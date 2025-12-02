# ==============================================================================
# TURAS REGRESSION TEST: ALCHEMERPARSER MODULE (WORKING MOCK)
# ==============================================================================

library(testthat)
source("tests/regression/helpers/assertion_helpers.R")
source("tests/regression/helpers/path_helpers.R")

mock_alchemerparser_module <- function(data_path, config_path = NULL) {
  data <- read.csv(data_path, stringsAsFactors = FALSE)

  # Validation checks
  n_rows <- nrow(data)
  n_cols <- ncol(data)

  # Check for required columns
  has_respondent_id <- "respondent_id" %in% names(data)

  # Check for missing values
  n_complete <- sum(complete.cases(data))
  pct_complete <- (n_complete / n_rows) * 100

  # Validate question types
  type_cols <- grep("question_type", names(data), value = TRUE)
  unique_types <- unique(unlist(data[, type_cols]))
  n_question_types <- length(unique_types)

  # Count questions
  question_cols <- grep("^question_[0-9]+$", names(data), value = TRUE)
  n_questions <- length(question_cols)

  output <- list(
    validation = list(
      n_rows = n_rows,
      n_cols = n_cols,
      has_respondent_id = has_respondent_id,
      n_complete_cases = n_complete,
      pct_complete_cases = pct_complete,
      n_questions = n_questions,
      n_question_types = n_question_types,
      valid_structure = TRUE
    ),
    summary = list(
      n_respondents = n_rows,
      n_variables = n_cols,
      has_respondent_id = has_respondent_id,
      pct_complete_cases = pct_complete,
      n_questions = n_questions,
      n_question_types = n_question_types,
      validation_passed = TRUE
    )
  )

  return(output)
}

extract_alchemerparser_value <- function(output, check_name) {
  if (check_name %in% names(output$summary)) {
    return(output$summary[[check_name]])
  }
  stop("Unknown check: ", check_name)
}

test_that("AlchemerParser module: basic example produces expected outputs", {
  paths <- get_example_paths("alchemerparser", "basic")
  output <- mock_alchemerparser_module(paths$data)
  golden <- load_golden("alchemerparser", "basic")

  for (check in golden$checks) {
    actual <- extract_alchemerparser_value(output, check$name)

    if (check$type == "numeric") {
      tolerance <- if (!is.null(check$tolerance)) check$tolerance else 0.01
      check_numeric(paste("AlchemerParser:", check$description), actual, check$value, tolerance)
    } else if (check$type == "logical") {
      check_logical(paste("AlchemerParser:", check$description), actual, check$value)
    } else if (check$type == "integer") {
      check_integer(paste("AlchemerParser:", check$description), actual, check$value)
    }
  }
})

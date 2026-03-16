# ==============================================================================
# TEST SUITE: Wave Data Loader
# ==============================================================================
# Tests for wave data loading, file resolution, weighting, and cleaning.
#
# Functions tested from wave_loader.R:
#   - load_wave_data()
#   - load_all_waves()
#   - resolve_data_file_path()
#   - get_wave_weight_var()
#   - apply_wave_weights()
#   - clean_wave_data()
#   - validate_wave_data()
#   - extract_categorical_question_codes()
#   - get_wave_summary()
#
# ==============================================================================

library(testthat)

context("Wave Data Loader")

# ==============================================================================
# SETUP: Source required modules
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Source shared TRS infrastructure
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

# Source tracker modules in dependency order
guard_path <- file.path(tracker_root, "lib", "00_guard.R")
if (file.exists(guard_path)) source(guard_path)

constants_path <- file.path(tracker_root, "lib", "constants.R")
if (file.exists(constants_path)) source(constants_path)

metric_types_path <- file.path(tracker_root, "lib", "metric_types.R")
if (file.exists(metric_types_path)) source(metric_types_path)

config_loader_path <- file.path(tracker_root, "lib", "tracker_config_loader.R")
if (file.exists(config_loader_path)) source(config_loader_path)

wave_loader_path <- file.path(tracker_root, "lib", "wave_loader.R")
if (file.exists(wave_loader_path)) source(wave_loader_path)


# ==============================================================================
# HELPER: Create test config and data
# ==============================================================================

create_wave_test_config <- function(data_dir = tempdir(), weight_var = NULL) {
  waves <- data.frame(
    WaveID = c("W1", "W2"),
    WaveName = c("Wave 1", "Wave 2"),
    DataFile = c("wave1.csv", "wave2.csv"),
    FieldworkStart = as.Date(c("2024-01-01", "2024-04-01")),
    FieldworkEnd = as.Date(c("2024-01-31", "2024-04-30")),
    stringsAsFactors = FALSE
  )

  if (!is.null(weight_var)) {
    waves$WeightVar <- rep(weight_var, 2)
  }

  list(
    waves = waves,
    settings = list(project_name = "Test"),
    banner = data.frame(
      BreakVariable = "Total",
      BreakLabel = "Overall",
      stringsAsFactors = FALSE
    ),
    tracked_questions = data.frame(
      QuestionCode = c("Q_SAT", "Q_NPS"),
      stringsAsFactors = FALSE
    ),
    config_path = file.path(data_dir, "config.xlsx")
  )
}

create_test_csv <- function(file_path, n = 50, include_weight = FALSE,
                            include_questions = TRUE) {
  set.seed(42)
  df <- data.frame(
    ResponseID = 1:n,
    stringsAsFactors = FALSE
  )

  if (include_questions) {
    df$Q10 <- sample(1:5, n, replace = TRUE)
    df$Q15 <- sample(0:10, n, replace = TRUE)
    df$Q20 <- sample(c("Yes", "No"), n, replace = TRUE)
  }

  if (include_weight) {
    df$weight <- runif(n, 0.5, 2.0)
  }

  write.csv(df, file_path, row.names = FALSE)
  return(df)
}


# ==============================================================================
# TESTS: CSV file loading
# ==============================================================================

test_that("load_wave_data loads CSV file correctly", {
  tmp_dir <- tempdir()
  csv_path <- file.path(tmp_dir, "test_wave.csv")

  create_test_csv(csv_path, n = 30)

  result <- load_wave_data(csv_path, "W1")

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 30)
  expect_true("ResponseID" %in% names(result))

  file.remove(csv_path)
})

test_that("load_wave_data preserves column names from CSV", {
  tmp_dir <- tempdir()
  csv_path <- file.path(tmp_dir, "test_colnames.csv")

  df <- data.frame(
    `Q 10` = c(1, 2, 3),
    `Response ID` = c(101, 102, 103),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  write.csv(df, csv_path, row.names = FALSE)

  result <- load_wave_data(csv_path, "W1")

  expect_true("Q 10" %in% names(result))
  expect_true("Response ID" %in% names(result))

  file.remove(csv_path)
})

test_that("load_wave_data loads CSV with many rows", {
  tmp_dir <- tempdir()
  csv_path <- file.path(tmp_dir, "test_large.csv")

  create_test_csv(csv_path, n = 1000)

  result <- load_wave_data(csv_path, "W1")

  expect_equal(nrow(result), 1000)

  file.remove(csv_path)
})


# ==============================================================================
# TESTS: XLSX file loading
# ==============================================================================

test_that("load_wave_data loads XLSX file correctly", {
  skip_if_not(requireNamespace("openxlsx", quietly = TRUE), "openxlsx not available")

  tmp_dir <- tempdir()
  xlsx_path <- file.path(tmp_dir, "test_wave.xlsx")

  set.seed(42)
  df <- data.frame(
    ResponseID = 1:20,
    Q10 = sample(1:5, 20, replace = TRUE),
    Q15 = sample(0:10, 20, replace = TRUE),
    stringsAsFactors = FALSE
  )

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Data")
  openxlsx::writeData(wb, "Data", df)
  openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)

  result <- load_wave_data(xlsx_path, "W1")

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 20)

  file.remove(xlsx_path)
})


# ==============================================================================
# TESTS: Missing file handling (TRS refusal)
# ==============================================================================

test_that("load_wave_data refuses when file does not exist", {
  expect_error(
    load_wave_data("/nonexistent/path/data.csv", "W1"),
    class = "turas_refusal"
  )
})

test_that("load_wave_data refuses unsupported file format", {
  tmp_dir <- tempdir()
  txt_path <- file.path(tmp_dir, "data.txt")
  writeLines("a,b,c", txt_path)

  expect_error(
    load_wave_data(txt_path, "W1"),
    class = "turas_refusal"
  )

  file.remove(txt_path)
})


# ==============================================================================
# TESTS: Empty data file handling
# ==============================================================================

test_that("load_wave_data refuses empty CSV file", {
  tmp_dir <- tempdir()
  csv_path <- file.path(tmp_dir, "empty_wave.csv")

  # Write header only (no data rows)
  writeLines("ResponseID,Q10,Q15", csv_path)

  expect_error(
    load_wave_data(csv_path, "W1"),
    class = "turas_refusal"
  )

  file.remove(csv_path)
})


# ==============================================================================
# TESTS: Weight variable validation
# ==============================================================================

test_that("apply_wave_weights applies existing weight column", {
  df <- data.frame(
    ResponseID = 1:5,
    Q10 = c(1, 2, 3, 4, 5),
    weight = c(1.0, 1.5, 0.8, 1.2, 1.0),
    stringsAsFactors = FALSE
  )

  result <- apply_wave_weights(df, "weight", "W1")

  expect_true("weight_var" %in% names(result))
  expect_equal(result$weight_var, c(1.0, 1.5, 0.8, 1.2, 1.0))
})

test_that("apply_wave_weights falls back to 1 when weight column missing", {
  df <- data.frame(
    ResponseID = 1:5,
    Q10 = c(1, 2, 3, 4, 5),
    stringsAsFactors = FALSE
  )

  output <- capture.output(
    result <- apply_wave_weights(df, "missing_weight", "W1"),
    type = "output"
  )

  expect_true("weight_var" %in% names(result))
  expect_equal(result$weight_var, rep(1, 5))
  expect_true(any(grepl("not found", output)))
})

test_that("apply_wave_weights warns on missing weight values (NA)", {
  df <- data.frame(
    ResponseID = 1:5,
    weight = c(1.0, NA, 0.8, NA, 1.0),
    stringsAsFactors = FALSE
  )

  output <- capture.output(
    result <- apply_wave_weights(df, "weight", "W1"),
    type = "output"
  )

  expect_true(any(grepl("missing weights", output)))
})

test_that("apply_wave_weights warns on zero or negative weights", {
  df <- data.frame(
    ResponseID = 1:5,
    weight = c(1.0, 0, -0.5, 1.2, 1.0),
    stringsAsFactors = FALSE
  )

  output <- capture.output(
    result <- apply_wave_weights(df, "weight", "W1"),
    type = "output"
  )

  expect_true(any(grepl("zero or negative", output)))
  # Invalid weights should be set to NA
  expect_true(is.na(result$weight_var[2]))
  expect_true(is.na(result$weight_var[3]))
})


# ==============================================================================
# TESTS: get_wave_weight_var
# ==============================================================================

test_that("get_wave_weight_var returns WeightVar from waves definition", {
  config <- create_wave_test_config(weight_var = "wgt")
  result <- get_wave_weight_var(config, "W1")
  expect_equal(result, "wgt")
})

test_that("get_wave_weight_var falls back to global setting", {
  config <- create_wave_test_config()
  config$settings$weight_variable <- "global_weight"

  result <- get_wave_weight_var(config, "W1")
  expect_equal(result, "global_weight")
})

test_that("get_wave_weight_var returns NULL when no weight specified", {
  config <- create_wave_test_config()
  result <- get_wave_weight_var(config, "W1")
  expect_null(result)
})

test_that("get_wave_weight_var handles NA in WeightVar", {
  config <- create_wave_test_config()
  config$waves$WeightVar <- c(NA, "wgt_w2")

  result_w1 <- get_wave_weight_var(config, "W1")
  result_w2 <- get_wave_weight_var(config, "W2")

  # W1 has NA, should fall back to global (which is NULL)
  expect_null(result_w1)
  expect_equal(result_w2, "wgt_w2")
})


# ==============================================================================
# TESTS: Data type coercion (clean_wave_data)
# ==============================================================================

test_that("clean_wave_data converts comma decimals to period decimals", {
  df <- data.frame(
    Q10 = c("3,5", "4,2", "2,8"),
    stringsAsFactors = FALSE
  )

  result <- clean_wave_data(df, "W1")

  expect_true(is.numeric(result$Q10))
  expect_equal(result$Q10, c(3.5, 4.2, 2.8))
})

test_that("clean_wave_data converts DK/Don't Know to NA", {
  df <- data.frame(
    Q10 = c("4", "DK", "3", "Don't Know", "5"),
    stringsAsFactors = FALSE
  )

  result <- clean_wave_data(df, "W1")

  expect_true(is.numeric(result$Q10))
  expect_equal(result$Q10[1], 4)
  expect_true(is.na(result$Q10[2]))
  expect_equal(result$Q10[3], 3)
  expect_true(is.na(result$Q10[4]))
  expect_equal(result$Q10[5], 5)
})

test_that("clean_wave_data preserves categorical columns", {
  df <- data.frame(
    Q10 = c("Yes", "No", "Yes"),
    Q20 = c("1", "2", "3"),
    stringsAsFactors = FALSE
  )

  result <- clean_wave_data(df, "W1", categorical_cols = c("Q10"))

  # Q10 should remain as text
  expect_true(is.character(result$Q10))
  expect_equal(result$Q10, c("Yes", "No", "Yes"))

  # Q20 should be converted to numeric
  expect_true(is.numeric(result$Q20))
})

test_that("clean_wave_data skips already-numeric columns", {
  df <- data.frame(
    Q10 = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  result <- clean_wave_data(df, "W1")

  expect_true(is.numeric(result$Q10))
  expect_equal(result$Q10, c(1, 2, 3))
})

test_that("clean_wave_data skips all-NA columns", {
  df <- data.frame(
    Q10 = c(NA_character_, NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )

  result <- clean_wave_data(df, "W1")

  expect_true(all(is.na(result$Q10)))
})

test_that("clean_wave_data only processes mapped columns when specified", {
  df <- data.frame(
    Q10 = c("1", "2", "3"),
    Q99 = c("a", "b", "c"),
    stringsAsFactors = FALSE
  )

  result <- clean_wave_data(df, "W1", mapped_cols = c("Q10"))

  # Q10 is mapped and should be processed
  expect_true(is.numeric(result$Q10))
  # Q99 is unmapped and should be left as-is
  expect_true(is.character(result$Q99))
})

test_that("clean_wave_data handles N/A and Refused non-response codes", {
  df <- data.frame(
    Q10 = c("4", "N/A", "3", "Refused", "5"),
    stringsAsFactors = FALSE
  )

  result <- clean_wave_data(df, "W1")

  expect_true(is.numeric(result$Q10))
  expect_true(is.na(result$Q10[2]))
  expect_true(is.na(result$Q10[4]))
})

test_that("clean_wave_data preserves non-question columns", {
  df <- data.frame(
    ResponseID = c("ABC", "DEF", "GHI"),
    Age = c("25", "30", "45"),
    Q10 = c("1", "2", "3"),
    stringsAsFactors = FALSE
  )

  result <- clean_wave_data(df, "W1")

  # ResponseID and Age are not Q## pattern, should be untouched
  expect_true(is.character(result$ResponseID))
  expect_true(is.character(result$Age))
  # Q10 is a question column and should be converted
  expect_true(is.numeric(result$Q10))
})


# ==============================================================================
# TESTS: extract_categorical_question_codes
# ==============================================================================

test_that("extract_categorical_question_codes identifies Single_Response types", {
  question_mapping <- data.frame(
    QuestionCode = c("Q_SAT", "Q_GENDER"),
    QuestionType = c("Rating", "Single_Response"),
    stringsAsFactors = FALSE
  )

  result <- extract_categorical_question_codes(question_mapping = question_mapping)

  expect_true("Q_GENDER" %in% result)
  expect_false("Q_SAT" %in% result)
})

test_that("extract_categorical_question_codes identifies Multi_Mention types", {
  question_mapping <- data.frame(
    QuestionCode = c("Q_SAT", "Q_BRANDS"),
    QuestionType = c("Rating", "Multi_Mention"),
    stringsAsFactors = FALSE
  )

  result <- extract_categorical_question_codes(question_mapping = question_mapping)

  expect_true("Q_BRANDS" %in% result)
  expect_false("Q_SAT" %in% result)
})

test_that("extract_categorical_question_codes handles banner variables", {
  config <- list(
    banner = data.frame(
      BreakVariable = c("Total", "Gender"),
      BreakLabel = c("Overall", "Male"),
      W1 = c("", "Q05"),
      W2 = c("", "Q06"),
      stringsAsFactors = FALSE
    ),
    waves = data.frame(WaveID = c("W1", "W2"), stringsAsFactors = FALSE)
  )

  result <- extract_categorical_question_codes(config = config)

  expect_true("Q05" %in% result)
  expect_true("Q06" %in% result)
})

test_that("extract_categorical_question_codes returns empty for NULL inputs", {
  result <- extract_categorical_question_codes()
  expect_equal(length(result), 0)
})

test_that("extract_categorical_question_codes returns unique codes", {
  question_mapping <- data.frame(
    QuestionCode = c("Q_A", "Q_A"),
    QuestionType = c("Single_Response", "Single_Response"),
    stringsAsFactors = FALSE
  )

  result <- extract_categorical_question_codes(question_mapping = question_mapping)
  expect_equal(length(result), 1)
})


# ==============================================================================
# TESTS: resolve_data_file_path
# ==============================================================================

test_that("resolve_data_file_path returns existing absolute path", {
  tmp_dir <- tempdir()
  csv_path <- file.path(tmp_dir, "resolve_test.csv")
  writeLines("a,b\n1,2", csv_path)

  result <- resolve_data_file_path(csv_path)
  expect_true(file.exists(result))

  file.remove(csv_path)
})

test_that("resolve_data_file_path resolves relative path with data_dir", {
  tmp_dir <- tempdir()
  csv_path <- file.path(tmp_dir, "resolve_rel.csv")
  writeLines("a,b\n1,2", csv_path)

  result <- resolve_data_file_path("resolve_rel.csv", tmp_dir)
  expect_true(file.exists(result))

  file.remove(csv_path)
})

test_that("resolve_data_file_path returns original for nonexistent file", {
  result <- resolve_data_file_path("nonexistent.csv", "/tmp/nodir")
  expect_equal(result, "nonexistent.csv")
})


# ==============================================================================
# TESTS: load_all_waves
# ==============================================================================

test_that("load_all_waves loads multiple wave CSV files", {
  tmp_dir <- tempdir()

  # Create two test CSV files
  csv1 <- file.path(tmp_dir, "wave1.csv")
  csv2 <- file.path(tmp_dir, "wave2.csv")
  create_test_csv(csv1, n = 30)
  create_test_csv(csv2, n = 40)

  config <- create_wave_test_config(data_dir = tmp_dir)

  result <- load_all_waves(config, data_dir = tmp_dir)

  expect_true(is.list(result))
  expect_true("wave_data" %in% names(result))
  expect_true("wave_structures" %in% names(result))
  expect_equal(length(result$wave_data), 2)
  expect_equal(nrow(result$wave_data[["W1"]]), 30)
  expect_equal(nrow(result$wave_data[["W2"]]), 40)
  # Default weight should be 1
  expect_true(all(result$wave_data[["W1"]]$weight_var == 1))

  file.remove(csv1, csv2)
})

test_that("load_all_waves applies weighting from WeightVar column", {
  tmp_dir <- tempdir()

  csv1 <- file.path(tmp_dir, "wave1.csv")
  csv2 <- file.path(tmp_dir, "wave2.csv")
  create_test_csv(csv1, n = 20, include_weight = TRUE)
  create_test_csv(csv2, n = 25, include_weight = TRUE)

  config <- create_wave_test_config(data_dir = tmp_dir, weight_var = "weight")

  result <- load_all_waves(config, data_dir = tmp_dir)

  # Weight variable should be applied (not all 1s)
  w1_weights <- result$wave_data[["W1"]]$weight_var
  expect_false(all(w1_weights == 1))
  expect_true(all(!is.na(w1_weights)))

  file.remove(csv1, csv2)
})


# ==============================================================================
# TESTS: validate_wave_data
# ==============================================================================

test_that("validate_wave_data passes with valid wave data", {
  config <- create_wave_test_config()

  wave_data <- list(
    W1 = data.frame(Q10 = c(1, 2, 3), weight_var = c(1, 1, 1), stringsAsFactors = FALSE),
    W2 = data.frame(Q10 = c(4, 5, 6), weight_var = c(1, 1, 1), stringsAsFactors = FALSE)
  )

  question_mapping <- data.frame(
    QuestionCode = c("Q_SAT"),
    QuestionType = c("Rating"),
    W1 = c("Q10"),
    W2 = c("Q10"),
    stringsAsFactors = FALSE
  )

  output <- capture.output(
    result <- validate_wave_data(wave_data, config, question_mapping),
    type = "output"
  )

  expect_true(result)
})

test_that("validate_wave_data refuses when waves are missing from data", {
  config <- create_wave_test_config()

  # Only W1 loaded, W2 is missing
  wave_data <- list(
    W1 = data.frame(Q10 = c(1, 2, 3), weight_var = c(1, 1, 1), stringsAsFactors = FALSE)
  )

  question_mapping <- data.frame(
    QuestionCode = c("Q_SAT"),
    QuestionType = c("Rating"),
    W1 = c("Q10"),
    W2 = c("Q10"),
    stringsAsFactors = FALSE
  )

  expect_error(
    validate_wave_data(wave_data, config, question_mapping),
    class = "turas_refusal"
  )
})

test_that("validate_wave_data refuses when weight_var column missing from wave", {
  config <- create_wave_test_config()

  wave_data <- list(
    W1 = data.frame(Q10 = c(1, 2, 3), weight_var = c(1, 1, 1), stringsAsFactors = FALSE),
    W2 = data.frame(Q10 = c(4, 5, 6), stringsAsFactors = FALSE)  # Missing weight_var!
  )

  question_mapping <- data.frame(
    QuestionCode = c("Q_SAT"),
    QuestionType = c("Rating"),
    stringsAsFactors = FALSE
  )

  expect_error(
    validate_wave_data(wave_data, config, question_mapping),
    class = "turas_refusal"
  )
})

test_that("validate_wave_data warns on missing mapped questions", {
  config <- create_wave_test_config()

  wave_data <- list(
    W1 = data.frame(Q10 = c(1, 2, 3), weight_var = c(1, 1, 1), stringsAsFactors = FALSE),
    W2 = data.frame(Q10 = c(4, 5, 6), weight_var = c(1, 1, 1), stringsAsFactors = FALSE)
  )

  # Mapping references Q10 and Q99, but Q99 doesn't exist in data
  question_mapping <- data.frame(
    QuestionCode = c("Q_SAT", "Q_MISS"),
    QuestionType = c("Rating", "Rating"),
    W1 = c("Q10", "Q99"),
    W2 = c("Q10", "Q99"),
    stringsAsFactors = FALSE
  )

  output <- capture.output(
    result <- validate_wave_data(wave_data, config, question_mapping),
    type = "output"
  )

  expect_true(any(grepl("not found in data", output)))
})


# ==============================================================================
# TESTS: NA handling in data columns
# ==============================================================================

test_that("load_wave_data preserves NAs in data", {
  tmp_dir <- tempdir()
  csv_path <- file.path(tmp_dir, "na_test.csv")

  df <- data.frame(
    ResponseID = 1:5,
    Q10 = c(1, NA, 3, NA, 5),
    stringsAsFactors = FALSE
  )
  write.csv(df, csv_path, row.names = FALSE)

  result <- load_wave_data(csv_path, "W1")

  expect_equal(sum(is.na(result$Q10)), 2)

  file.remove(csv_path)
})


# ==============================================================================
# TESTS: get_wave_summary
# ==============================================================================

test_that("get_wave_summary returns summary for loaded waves", {
  wave_data <- list(
    W1 = data.frame(
      Q10 = c(1, 2, 3), weight_var = c(1, 1, 1), stringsAsFactors = FALSE
    ),
    W2 = data.frame(
      Q10 = c(4, 5, 6, 7), weight_var = c(1, 1, 1, 1), stringsAsFactors = FALSE
    )
  )

  result <- get_wave_summary(wave_data)

  expect_true(is.data.frame(result))
  expect_true(nrow(result) >= 2)
})


# ==============================================================================
# TESTS: Multi_Mention sub-column detection in validate_wave_data
# ==============================================================================

test_that("validate_wave_data recognizes Multi_Mention sub-columns", {
  config <- create_wave_test_config()

  wave_data <- list(
    W1 = data.frame(
      Q10_1 = c(1, 0, 1), Q10_2 = c(0, 1, 1),
      weight_var = c(1, 1, 1), stringsAsFactors = FALSE
    ),
    W2 = data.frame(
      Q10_1 = c(1, 1, 0), Q10_2 = c(0, 0, 1),
      weight_var = c(1, 1, 1), stringsAsFactors = FALSE
    )
  )

  question_mapping <- data.frame(
    QuestionCode = c("Q_BRANDS"),
    QuestionType = c("Multi_Mention"),
    W1 = c("Q10"),
    W2 = c("Q10"),
    stringsAsFactors = FALSE
  )

  # Should NOT warn about Q10 being missing since Q10_1, Q10_2 exist
  output <- capture.output(
    result <- validate_wave_data(wave_data, config, question_mapping),
    type = "output"
  )

  # If Q10 sub-columns exist, it should pass without warnings about Q10
  expect_false(any(grepl("Q10.*not found", output)))
})


# ==============================================================================
# TESTS: Edge cases
# ==============================================================================

test_that("load_wave_data handles single-row CSV", {
  tmp_dir <- tempdir()
  csv_path <- file.path(tmp_dir, "single_row.csv")

  df <- data.frame(ResponseID = 1, Q10 = 5, stringsAsFactors = FALSE)
  write.csv(df, csv_path, row.names = FALSE)

  result <- load_wave_data(csv_path, "W1")
  expect_equal(nrow(result), 1)

  file.remove(csv_path)
})

test_that("load_wave_data handles CSV with only header and no data rows refuses", {
  tmp_dir <- tempdir()
  csv_path <- file.path(tmp_dir, "header_only.csv")

  writeLines("ResponseID,Q10,Q15", csv_path)

  expect_error(
    load_wave_data(csv_path, "W1"),
    class = "turas_refusal"
  )

  file.remove(csv_path)
})

test_that("clean_wave_data handles mixed numeric and text in same column", {
  df <- data.frame(
    Q10 = c("1", "2", "three", "4", "five"),
    stringsAsFactors = FALSE
  )

  output <- capture.output(
    result <- clean_wave_data(df, "W1"),
    type = "output"
  )

  expect_true(is.numeric(result$Q10))
  expect_equal(result$Q10[1], 1)
  expect_true(is.na(result$Q10[3]))
  expect_equal(result$Q10[4], 4)
  expect_true(is.na(result$Q10[5]))
})


# ==============================================================================
# END OF TEST SUITE
# ==============================================================================

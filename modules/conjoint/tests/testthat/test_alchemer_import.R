# ==============================================================================
# TEST SUITE: Conjoint Alchemer Import (05_alchemer_import.R)
# ==============================================================================

library(testthat)

context("Conjoint Alchemer Import")

# ==============================================================================
# HELPERS: Mock Data and File Builders
# ==============================================================================

create_mock_alchemer_csv <- function(n_resp = 5, n_sets = 3, n_cards = 3,
                                      score_scale = "binary", file_path = NULL) {
  if (is.null(file_path)) {
    file_path <- tempfile(fileext = ".csv")
  }

  rows <- list()
  for (r in seq_len(n_resp)) {
    for (s in seq_len(n_sets)) {
      chosen_card <- sample(seq_len(n_cards), 1)
      for (c in seq_len(n_cards)) {
        score <- if (score_scale == "binary") {
          ifelse(c == chosen_card, 1, 0)
        } else if (score_scale == "hundred") {
          ifelse(c == chosen_card, 100, 0)
        } else {
          ifelse(c == chosen_card, 1, 0)
        }

        rows[[length(rows) + 1]] <- data.frame(
          ResponseID = r,
          SetNumber = s,
          CardNumber = c,
          Brand = sample(c("Alpha_01", "Beta_02", "Gamma_03"), 1),
          Price = sample(c("Low_071", "Mid_089", "High_107"), 1),
          Score = score,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  df <- do.call(rbind, rows)
  utils::write.csv(df, file_path, row.names = FALSE)
  file_path
}

create_mock_alchemer_xlsx <- function(n_resp = 5, n_sets = 3, n_cards = 3) {
  file_path <- tempfile(fileext = ".xlsx")

  rows <- list()
  for (r in seq_len(n_resp)) {
    for (s in seq_len(n_sets)) {
      chosen_card <- sample(seq_len(n_cards), 1)
      for (c in seq_len(n_cards)) {
        rows[[length(rows) + 1]] <- data.frame(
          ResponseID = r,
          SetNumber = s,
          CardNumber = c,
          Brand = sample(c("Alpha_01", "Beta_02", "Gamma_03"), 1),
          Price = sample(c("Low_071", "Mid_089", "High_107"), 1),
          Score = ifelse(c == chosen_card, 1, 0),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  df <- do.call(rbind, rows)
  openxlsx::write.xlsx(df, file_path)
  file_path
}


# ==============================================================================
# TESTS: validate_alchemer_columns()
# ==============================================================================

test_that("validate_alchemer_columns passes with correct columns", {
  df <- data.frame(
    ResponseID = 1:3,
    SetNumber = 1:3,
    CardNumber = 1:3,
    Score = c(1, 0, 0),
    Brand = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )

  result <- validate_alchemer_columns(df)
  expect_true(all(c("ResponseID", "SetNumber", "CardNumber", "Score") %in% names(result)))
})

test_that("validate_alchemer_columns corrects case-insensitive column names", {
  df <- data.frame(
    responseid = 1:3,
    setnumber = 1:3,
    cardnumber = 1:3,
    score = c(1, 0, 0),
    stringsAsFactors = FALSE
  )

  result <- validate_alchemer_columns(df)
  expect_true("ResponseID" %in% names(result))
  expect_true("SetNumber" %in% names(result))
  expect_true("CardNumber" %in% names(result))
  expect_true("Score" %in% names(result))
})

test_that("validate_alchemer_columns refuses when columns are truly missing", {
  df <- data.frame(
    ID = 1:3,
    Brand = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )

  expect_error(
    validate_alchemer_columns(df),
    regexp = "REFUSED|Missing|columns",
    ignore.case = TRUE
  )
})


# ==============================================================================
# TESTS: normalize_score_column()
# ==============================================================================

test_that("normalize_score_column handles binary 0/1 scores", {
  scores <- c(0, 1, 0, 0, 1)
  result <- normalize_score_column(scores)

  expect_equal(result, c(0L, 1L, 0L, 0L, 1L))
})

test_that("normalize_score_column normalizes 0/100 scale", {
  scores <- c(0, 100, 0, 0, 100)
  result <- normalize_score_column(scores)

  expect_equal(result, c(0L, 1L, 0L, 0L, 1L))
})

test_that("normalize_score_column handles NA values", {
  scores <- c(0, 1, NA, 0, 1)
  result <- normalize_score_column(scores)

  expect_equal(length(result), 5)
  expect_equal(result[3], 0L)  # NA treated as not chosen
})

test_that("normalize_score_column handles unknown positive scale", {
  scores <- c(0, 5, 0, 3, 0)
  result <- normalize_score_column(scores)

  expect_equal(result, c(0L, 1L, 0L, 1L, 0L))
})


# ==============================================================================
# TESTS: clean_alchemer_level()
# ==============================================================================

test_that("clean_alchemer_level removes price format suffix", {
  values <- c("Low_071", "Mid_089", "High_107")
  result <- clean_alchemer_level(values, "Price")

  expect_equal(result, c("Low", "Mid", "High"))
})

test_that("clean_alchemer_level removes attribute prefix format", {
  values <- c("MSG_Present", "MSG_Absent")
  result <- clean_alchemer_level(values, "MSG")

  expect_equal(result, c("Present", "Absent"))
})

test_that("clean_alchemer_level leaves simple values unchanged", {
  values <- c("A", "B", "C", "D", "E")
  result <- clean_alchemer_level(values, "NutriScore")

  expect_equal(result, c("A", "B", "C", "D", "E"))
})

test_that("clean_alchemer_level handles NULL and empty input", {
  expect_null(clean_alchemer_level(NULL, "Test"))
  expect_equal(clean_alchemer_level(character(0), "Test"), character(0))
})

test_that("clean_alchemer_level handles consistent generic prefix", {
  values <- c("PotassiumChloride_Present", "PotassiumChloride_Absent")
  result <- clean_alchemer_level(values, "SaltAlternative")

  expect_equal(result, c("Present", "Absent"))
})


# ==============================================================================
# TESTS: import_alchemer_conjoint() - CSV
# ==============================================================================

test_that("import_alchemer_conjoint loads CSV file correctly", {
  csv_path <- create_mock_alchemer_csv(n_resp = 10, n_sets = 4, n_cards = 3)
  on.exit(unlink(csv_path), add = TRUE)

  df <- import_alchemer_conjoint(csv_path, verbose = FALSE)

  expect_true(is.data.frame(df))
  expect_true("resp_id" %in% names(df))
  expect_true("choice_set_id" %in% names(df))
  expect_true("alternative_id" %in% names(df))
  expect_true("chosen" %in% names(df))

  # Check all chosen values are 0 or 1
  expect_true(all(df$chosen %in% c(0L, 1L)))
})

test_that("import_alchemer_conjoint loads XLSX file correctly", {
  xlsx_path <- create_mock_alchemer_xlsx(n_resp = 5, n_sets = 3, n_cards = 3)
  on.exit(unlink(xlsx_path), add = TRUE)

  df <- import_alchemer_conjoint(xlsx_path, verbose = FALSE)

  expect_true(is.data.frame(df))
  expect_equal(length(unique(df$resp_id)), 5)
})

test_that("import_alchemer_conjoint cleans level names by default", {
  csv_path <- create_mock_alchemer_csv(n_resp = 5, n_sets = 3, n_cards = 3)
  on.exit(unlink(csv_path), add = TRUE)

  df <- import_alchemer_conjoint(csv_path, verbose = FALSE, clean_levels = TRUE)

  # Price levels should be cleaned (Low_071 -> Low)
  price_levels <- unique(df$Price)
  expect_false(any(grepl("_\\d+$", price_levels)),
               info = "Price levels should have numeric suffix removed")
})

test_that("import_alchemer_conjoint preserves raw levels when clean_levels=FALSE", {
  csv_path <- create_mock_alchemer_csv(n_resp = 5, n_sets = 3, n_cards = 3)
  on.exit(unlink(csv_path), add = TRUE)

  df <- import_alchemer_conjoint(csv_path, verbose = FALSE, clean_levels = FALSE)

  # Price levels should retain suffix
  price_levels <- unique(df$Price)
  expect_true(any(grepl("_\\d+$", price_levels)),
              info = "Price levels should retain numeric suffix when clean_levels=FALSE")
})

test_that("import_alchemer_conjoint refuses missing file", {
  expect_error(
    import_alchemer_conjoint("/nonexistent/path/data.csv", verbose = FALSE),
    regexp = "REFUSED|not found|not exist",
    ignore.case = TRUE
  )
})

test_that("import_alchemer_conjoint handles 0/100 score scale", {
  csv_path <- create_mock_alchemer_csv(n_resp = 5, n_sets = 3, n_cards = 3,
                                        score_scale = "hundred")
  on.exit(unlink(csv_path), add = TRUE)

  df <- import_alchemer_conjoint(csv_path, verbose = FALSE)

  # All chosen values should be normalized to 0/1
  expect_true(all(df$chosen %in% c(0L, 1L)))
})


# ==============================================================================
# TESTS: validate_alchemer_data()
# ==============================================================================

test_that("validate_alchemer_data passes for valid data", {
  csv_path <- create_mock_alchemer_csv(n_resp = 40, n_sets = 6, n_cards = 3)
  on.exit(unlink(csv_path), add = TRUE)

  df <- import_alchemer_conjoint(csv_path, verbose = FALSE)
  result <- validate_alchemer_data(df, verbose = FALSE)

  expect_true(result$is_valid)
  expect_equal(length(result$errors), 0)
})

test_that("validate_alchemer_data detects multiple selections per set", {
  df <- data.frame(
    resp_id = c(1, 1, 1),
    choice_set_id = c("1_1", "1_1", "1_1"),
    alternative_id = c(1, 2, 3),
    Brand = c("A", "B", "C"),
    chosen = c(1, 1, 0),  # Two chosen in same set
    stringsAsFactors = FALSE
  )

  result <- validate_alchemer_data(df, verbose = FALSE)
  expect_true(length(result$errors) > 0)
})

test_that("validate_alchemer_data warns about low respondent count", {
  df <- data.frame(
    resp_id = rep(1:5, each = 3),
    choice_set_id = rep(paste0("1_", 1:5), each = 3),
    alternative_id = rep(1:3, 5),
    Brand = sample(c("A", "B", "C"), 15, replace = TRUE),
    chosen = rep(c(1, 0, 0), 5),
    stringsAsFactors = FALSE
  )

  result <- validate_alchemer_data(df, verbose = FALSE)
  # Low respondent count should generate a warning
  expect_true(length(result$warnings) > 0)
  expect_true(any(grepl("respondent", result$warnings, ignore.case = TRUE)))
})


# ==============================================================================
# TESTS: get_alchemer_attributes()
# ==============================================================================

test_that("get_alchemer_attributes extracts attribute summary", {
  csv_path <- create_mock_alchemer_csv(n_resp = 5, n_sets = 3, n_cards = 3)
  on.exit(unlink(csv_path), add = TRUE)

  df <- import_alchemer_conjoint(csv_path, verbose = FALSE)
  attrs <- get_alchemer_attributes(df)

  expect_true(is.data.frame(attrs))
  expect_true("AttributeName" %in% names(attrs))
  expect_true("NumLevels" %in% names(attrs))
  expect_true("Brand" %in% attrs$AttributeName)
  expect_true("Price" %in% attrs$AttributeName)
})

# ==============================================================================
# UNIT TESTS - OUTPUT GENERATION (06_output.R)
# ==============================================================================
# Tests for: generate_crosstab_config, generate_survey_structure,
#   generate_data_headers, create_crosstab_row, create_question_row,
#   create_option_rows, calculate_display_columns, check_exclude_from_index,
#   generate_output_files
# ==============================================================================

library(testthat)

# --- Helpers: build mock question structures ---

make_single_response <- function(q_code = "Q01", q_text = "Favourite colour?",
                                  options = list(
                                    list(code = "1", text = "Red"),
                                    list(code = "2", text = "Blue"),
                                    list(code = "3", text = "Green")
                                  )) {
  list(
    q_code = q_code,
    q_codes = q_code,
    question_text = q_text,
    variable_type = "Single_Response",
    is_grid = FALSE,
    n_columns = 1,
    options = options,
    columns = list(list(col_index = 1, row_label = q_text))
  )
}

make_multi_mention <- function(q_code = "Q04", q_text = "Select all that apply",
                                labels = c("Email", "Phone", "SMS"),
                                include_other = FALSE) {
  codes <- paste0(q_code, "_", seq_along(labels))
  if (include_other) {
    labels <- c(labels, "Other")
    codes <- c(codes, paste0(q_code, "_othermention"))
  }
  cols <- lapply(seq_along(labels), function(i) {
    list(col_index = i, row_label = labels[i])
  })
  list(
    q_code = q_code,
    q_codes = codes,
    question_text = q_text,
    variable_type = "Multi_Mention",
    is_grid = FALSE,
    n_columns = length(labels),
    col_labels = labels,
    columns = cols,
    options = list()
  )
}

make_rating <- function(q_code = "Q05", q_text = "How satisfied?",
                         options = list(
                           list(code = "1", text = "Very Dissatisfied"),
                           list(code = "2", text = "Dissatisfied"),
                           list(code = "3", text = "Neutral"),
                           list(code = "4", text = "Satisfied"),
                           list(code = "5", text = "Very Satisfied")
                         )) {
  list(
    q_code = q_code,
    q_codes = q_code,
    question_text = q_text,
    variable_type = "Rating",
    is_grid = FALSE,
    n_columns = 1,
    options = options,
    columns = list(list(col_index = 1, row_label = q_text))
  )
}

make_nps <- function(q_code = "Q06", q_text = "How likely to recommend?") {
  opts <- lapply(0:10, function(i) list(code = as.character(i), text = as.character(i)))
  list(
    q_code = q_code,
    q_codes = q_code,
    question_text = q_text,
    variable_type = "NPS",
    is_grid = FALSE,
    n_columns = 1,
    options = opts,
    columns = list(list(col_index = 1, row_label = q_text))
  )
}

make_likert <- function(q_code = "Q07", q_text = "To what extent do you agree?",
                         options = list(
                           list(code = "1", text = "Strongly Disagree"),
                           list(code = "2", text = "Disagree"),
                           list(code = "3", text = "Neutral"),
                           list(code = "4", text = "Agree"),
                           list(code = "5", text = "Strongly Agree"),
                           list(code = "6", text = "Don't know")
                         )) {
  list(
    q_code = q_code,
    q_codes = q_code,
    question_text = q_text,
    variable_type = "Likert",
    is_grid = FALSE,
    n_columns = 1,
    options = options,
    columns = list(list(col_index = 1, row_label = q_text))
  )
}

make_ranking <- function(q_code = "Q12", q_text = "Rank the following",
                          items = c("Price", "Quality", "Service")) {
  codes <- paste0(q_code, "_", seq_along(items))
  cols <- lapply(seq_along(items), function(i) {
    list(col_index = i, row_label = items[i])
  })
  list(
    q_code = q_code,
    q_codes = codes,
    question_text = q_text,
    variable_type = "Ranking",
    is_grid = FALSE,
    n_columns = length(items),
    columns = cols,
    options = list()
  )
}

make_grid_question <- function(q_code_prefix = "Q10",
                                sub_texts = c("Brand A", "Brand B"),
                                var_type = "Single_Response",
                                options = list(
                                  list(code = "1", text = "Yes"),
                                  list(code = "2", text = "No")
                                )) {
  subs <- list()
  for (i in seq_along(sub_texts)) {
    suffix <- LETTERS[i]
    sub_code <- paste0(q_code_prefix, suffix)
    subs[[suffix]] <- list(
      q_code = sub_code,
      q_codes = sub_code,
      question_text = sub_texts[i],
      variable_type = var_type,
      n_columns = 1,
      options = options,
      columns = list(list(col_index = 1, row_label = sub_texts[i]))
    )
  }
  list(
    q_code = q_code_prefix,
    question_text = "Grid question",
    is_grid = TRUE,
    sub_questions = subs
  )
}


# ==============================================================================
# TEST: check_exclude_from_index
# ==============================================================================

test_that("check_exclude_from_index flags DK/NA patterns for index types", {
  expect_true(check_exclude_from_index("Don't know", "Likert"))
  expect_true(check_exclude_from_index("dont know", "Rating"))
  expect_true(check_exclude_from_index("DK", "NPS"))
  expect_true(check_exclude_from_index("Not applicable", "Likert"))
  expect_true(check_exclude_from_index("NA", "Rating"))
  expect_true(check_exclude_from_index("N/A", "Likert"))
  expect_true(check_exclude_from_index("Prefer not to say", "NPS"))
})

test_that("check_exclude_from_index is case-insensitive", {
  expect_true(check_exclude_from_index("DON'T KNOW", "Likert"))
  expect_true(check_exclude_from_index("not Applicable", "Rating"))
  expect_true(check_exclude_from_index("PREFER NOT to answer", "NPS"))
})

test_that("check_exclude_from_index returns FALSE for valid options", {
  expect_false(check_exclude_from_index("Strongly Agree", "Likert"))
  expect_false(check_exclude_from_index("5", "Rating"))
  expect_false(check_exclude_from_index("Very Satisfied", "NPS"))
})

test_that("check_exclude_from_index returns FALSE for non-index types", {
  expect_false(check_exclude_from_index("Don't know", "Single_Response"))
  expect_false(check_exclude_from_index("NA", "Multi_Mention"))
  expect_false(check_exclude_from_index("Not applicable", "Ranking"))
})

test_that("check_exclude_from_index handles whitespace", {
  expect_true(check_exclude_from_index("  Don't know  ", "Likert"))
  expect_true(check_exclude_from_index("  NA  ", "Rating"))
})


# ==============================================================================
# TEST: create_crosstab_row
# ==============================================================================

test_that("create_crosstab_row returns correct structure", {
  row <- create_crosstab_row("Q01", "Test question", "Single_Response")
  expect_equal(names(row), c("QuestionCode", "Include", "UseBanner",
                              "BannerBoxCategory", "BannerLabel",
                              "DisplayOrder", "CreateIndex",
                              "BaseFilter", "FilterLabel", "QuestionText"))
  expect_equal(nrow(row), 1)
})

test_that("create_crosstab_row sets CreateIndex=Y for index types", {
  expect_equal(create_crosstab_row("Q01", "q", "NPS")$CreateIndex, "Y")
  expect_equal(create_crosstab_row("Q01", "q", "Rating")$CreateIndex, "Y")
  expect_equal(create_crosstab_row("Q01", "q", "Likert")$CreateIndex, "Y")
})

test_that("create_crosstab_row sets CreateIndex=N for non-index types", {
  expect_equal(create_crosstab_row("Q01", "q", "Single_Response")$CreateIndex, "N")
  expect_equal(create_crosstab_row("Q01", "q", "Multi_Mention")$CreateIndex, "N")
  expect_equal(create_crosstab_row("Q01", "q", "Ranking")$CreateIndex, "N")
})

test_that("create_crosstab_row sets Include=N for othermention", {
  row <- create_crosstab_row("Q04_othermention", "Other", "Single_Response")
  expect_equal(row$Include, "N")
})

test_that("create_crosstab_row leaves Include=NA for normal questions", {
  row <- create_crosstab_row("Q01", "Colour?", "Single_Response")
  expect_true(is.na(row$Include))
})


# ==============================================================================
# TEST: calculate_display_columns
# ==============================================================================

test_that("calculate_display_columns returns 1 for Single_Response", {
  q <- make_single_response()
  expect_equal(calculate_display_columns(q), 1)
})

test_that("calculate_display_columns counts non-other codes for Multi_Mention", {
  q <- make_multi_mention(labels = c("A", "B", "C"))
  expect_equal(calculate_display_columns(q), 3)
})

test_that("calculate_display_columns excludes othermention from count", {
  q <- make_multi_mention(labels = c("A", "B"), include_other = TRUE)
  # q_codes: Q04_1, Q04_2, Q04_othermention → display_columns = 2
  expect_equal(calculate_display_columns(q), 2)
})

test_that("calculate_display_columns falls back to n_columns", {
  q <- list(variable_type = "Open_Text", q_codes = NULL, n_columns = 1)
  expect_equal(calculate_display_columns(q), 1)
})


# ==============================================================================
# TEST: create_question_row
# ==============================================================================

test_that("create_question_row returns correct structure", {
  row <- create_question_row("Q01", "Question?", "Single_Response", 1)
  expect_equal(names(row), c("QuestionCode", "QuestionText", "Variable_Type",
                              "Columns", "Ranking_Format", "Ranking_Positions",
                              "Ranking_Direction", "Category", "Notes"))
  expect_equal(nrow(row), 1)
})

test_that("create_question_row sets Ranking_Format for multi-column rankings", {
  row <- create_question_row("Q12", "Rank", "Ranking", 3)
  expect_equal(row$Ranking_Format, "position")
})

test_that("create_question_row sets NA Ranking_Format for non-ranking", {
  row <- create_question_row("Q01", "Question?", "Single_Response", 1)
  expect_true(is.na(row$Ranking_Format))
})

test_that("create_question_row sets NA Ranking_Format for single-column ranking", {
  row <- create_question_row("Q12", "Rank", "Ranking", 1)
  expect_true(is.na(row$Ranking_Format))
})


# ==============================================================================
# TEST: create_option_rows
# ==============================================================================

test_that("create_option_rows generates rows for Single_Response", {
  q <- make_single_response()
  rows <- create_option_rows(q)
  expect_equal(length(rows), 3)
  expect_equal(rows[[1]]$QuestionCode, "Q01")
  expect_equal(rows[[1]]$OptionText, "Red")
  expect_equal(rows[[1]]$ShowInOutput, "Y")
})

test_that("create_option_rows generates rows for Multi_Mention", {
  q <- make_multi_mention(labels = c("Email", "Phone"))
  rows <- create_option_rows(q)
  expect_equal(length(rows), 2)
  expect_equal(rows[[1]]$QuestionCode, "Q04_1")
  expect_equal(rows[[1]]$OptionText, "Email")
})

test_that("create_option_rows hides othermention in Multi_Mention", {
  q <- make_multi_mention(labels = c("Email", "Phone"), include_other = TRUE)
  rows <- create_option_rows(q)
  # Last row should have othermention code with ShowInOutput = N
  other_row <- rows[[length(rows)]]
  expect_true(grepl("othermention", other_row$QuestionCode))
  expect_equal(other_row$ShowInOutput, "N")
})

test_that("create_option_rows flags DK for exclusion in Rating", {
  q <- make_rating(options = list(
    list(code = "1", text = "Bad"),
    list(code = "2", text = "Good"),
    list(code = "3", text = "Don't know")
  ))
  rows <- create_option_rows(q)
  expect_equal(length(rows), 3)
  # DK should have ExcludeFromIndex = "Y"
  expect_equal(rows[[3]]$ExcludeFromIndex, "Y")
  # Normal options should have NA
  expect_true(is.na(rows[[1]]$ExcludeFromIndex))
})

test_that("create_option_rows generates rows for Ranking", {
  q <- make_ranking(items = c("Price", "Quality", "Service"))
  rows <- create_option_rows(q)
  expect_equal(length(rows), 3)
  expect_equal(rows[[1]]$QuestionCode, "Q12_1")
  expect_equal(rows[[1]]$OptionText, "Price")
})

test_that("create_option_rows handles NPS 0-10 scale", {
  q <- make_nps()
  rows <- create_option_rows(q)
  expect_equal(length(rows), 11)
  expect_equal(rows[[1]]$OptionText, "0")
  expect_equal(rows[[11]]$OptionText, "10")
})

test_that("create_option_rows handles Likert with DK exclusion", {
  q <- make_likert()
  rows <- create_option_rows(q)
  expect_equal(length(rows), 6)
  # "Don't know" is the 6th option
  expect_equal(rows[[6]]$ExcludeFromIndex, "Y")
  # "Strongly Agree" should not be excluded
  expect_true(is.na(rows[[5]]$ExcludeFromIndex))
})

test_that("create_option_rows returns empty structure for unknown type", {
  q <- list(variable_type = "Open_Text", options = list(), columns = list())
  rows <- create_option_rows(q)
  expect_equal(length(rows), 1)
  expect_equal(nrow(rows[[1]]), 0)
})


# ==============================================================================
# TEST: generate_crosstab_config
# ==============================================================================

test_that("generate_crosstab_config includes ResponseID row", {
  questions <- list("1" = make_single_response())
  result <- generate_crosstab_config(questions)
  expect_true("ResponseID" %in% result$QuestionCode)
  # ResponseID should be first
  expect_equal(result$QuestionCode[1], "ResponseID")
})

test_that("generate_crosstab_config handles single response question", {
  questions <- list("1" = make_single_response("Q01", "Colour?"))
  result <- generate_crosstab_config(questions)
  expect_equal(nrow(result), 2)  # ResponseID + Q01
  expect_true("Q01" %in% result$QuestionCode)
})

test_that("generate_crosstab_config handles multi-mention with individual codes", {
  q <- make_multi_mention("Q04", "Select all", c("A", "B", "C"))
  q$variable_type <- "Multi_Mention"
  # For multi-mention, crosstab uses base code only (non-grid)
  questions <- list("4" = q)
  result <- generate_crosstab_config(questions)
  # Non-grid multi-mention: uses base q_code
  expect_true("Q04" %in% result$QuestionCode)
})

test_that("generate_crosstab_config handles grid questions with sub-questions", {
  q <- make_grid_question("Q10", c("Brand A", "Brand B"), "Single_Response")
  questions <- list("10" = q)
  result <- generate_crosstab_config(questions)
  expect_true("Q10A" %in% result$QuestionCode)
  expect_true("Q10B" %in% result$QuestionCode)
})

test_that("generate_crosstab_config returns only ResponseID for empty input", {
  result <- generate_crosstab_config(list())
  expect_equal(nrow(result), 1)
  expect_equal(result$QuestionCode[1], "ResponseID")
})

test_that("generate_crosstab_config has correct columns", {
  questions <- list("1" = make_single_response())
  result <- generate_crosstab_config(questions)
  expected_cols <- c("QuestionCode", "Include", "UseBanner", "BannerBoxCategory",
                     "BannerLabel", "DisplayOrder", "CreateIndex", "BaseFilter",
                     "FilterLabel", "QuestionText")
  expect_equal(names(result), expected_cols)
})


# ==============================================================================
# TEST: generate_survey_structure
# ==============================================================================

test_that("generate_survey_structure returns questions and options", {
  questions <- list("1" = make_single_response())
  result <- generate_survey_structure(questions)
  expect_true("questions" %in% names(result))
  expect_true("options" %in% names(result))
})

test_that("generate_survey_structure questions sheet has correct structure", {
  questions <- list("1" = make_single_response())
  result <- generate_survey_structure(questions)
  expected_cols <- c("QuestionCode", "QuestionText", "Variable_Type",
                     "Columns", "Ranking_Format", "Ranking_Positions",
                     "Ranking_Direction", "Category", "Notes")
  expect_equal(names(result$questions), expected_cols)
})

test_that("generate_survey_structure options sheet has correct structure", {
  questions <- list("1" = make_single_response())
  result <- generate_survey_structure(questions)
  expected_cols <- c("QuestionCode", "OptionText", "DisplayText",
                     "DisplayOrder", "ShowInOutput", "ExcludeFromIndex",
                     "Index_Weight", "BoxCategory")
  expect_equal(names(result$options), expected_cols)
})

test_that("generate_survey_structure handles mixed question types", {
  questions <- list(
    "1" = make_single_response("Q01", "Colour?"),
    "2" = make_rating("Q02", "Satisfaction?"),
    "3" = make_multi_mention("Q03", "Channels?", c("Email", "Phone"))
  )
  result <- generate_survey_structure(questions)
  expect_equal(nrow(result$questions), 3)
  # Q01: 3 opts, Q02: 5 opts, Q03: 2 multi-mention opts
  expect_equal(nrow(result$options), 10)
})

test_that("generate_survey_structure handles ranking questions", {
  questions <- list("12" = make_ranking("Q12", "Rank", c("A", "B", "C")))
  result <- generate_survey_structure(questions)
  expect_equal(result$questions$Variable_Type, "Ranking")
  expect_equal(result$questions$Columns, 3)
  expect_equal(result$questions$Ranking_Format, "position")
  expect_equal(nrow(result$options), 3)
})

test_that("generate_survey_structure handles grid questions", {
  q <- make_grid_question("Q10", c("Brand A", "Brand B"), "Single_Response",
                           options = list(
                             list(code = "1", text = "Yes"),
                             list(code = "2", text = "No")
                           ))
  questions <- list("10" = q)
  result <- generate_survey_structure(questions)
  # 2 sub-questions
  expect_equal(nrow(result$questions), 2)
  # 2 options x 2 sub-questions
  expect_equal(nrow(result$options), 4)
})

test_that("generate_survey_structure returns empty frames for empty input", {
  result <- generate_survey_structure(list())
  expect_equal(nrow(result$questions), 0)
  expect_equal(nrow(result$options), 0)
})


# ==============================================================================
# TEST: generate_data_headers
# ==============================================================================

test_that("generate_data_headers starts with ResponseID", {
  questions <- list("1" = make_single_response("Q01"))
  result <- generate_data_headers(questions)
  expect_equal(result[1, 1], "ResponseID")
})

test_that("generate_data_headers includes single response code", {
  questions <- list("1" = make_single_response("Q01"))
  result <- generate_data_headers(questions)
  headers <- as.character(result[1, ])
  expect_true("Q01" %in% headers)
})

test_that("generate_data_headers includes multi-mention column codes", {
  q <- make_multi_mention("Q04", "Select all", c("A", "B", "C"))
  questions <- list("4" = q)
  result <- generate_data_headers(questions)
  headers <- as.character(result[1, ])
  expect_true("Q04_1" %in% headers)
  expect_true("Q04_2" %in% headers)
  expect_true("Q04_3" %in% headers)
})

test_that("generate_data_headers converts othermention to othertext", {
  q <- make_multi_mention("Q04", "Select all", c("A", "B"), include_other = TRUE)
  questions <- list("4" = q)
  result <- generate_data_headers(questions)
  headers <- as.character(result[1, ])
  # _othermention should be renamed to _othertext in headers
  expect_true("Q04_othertext" %in% headers)
  expect_false("Q04_othermention" %in% headers)
})

test_that("generate_data_headers handles grid sub-questions", {
  q <- make_grid_question("Q10", c("Brand A", "Brand B"), "Single_Response")
  questions <- list("10" = q)
  result <- generate_data_headers(questions)
  headers <- as.character(result[1, ])
  expect_true("Q10A" %in% headers)
  expect_true("Q10B" %in% headers)
})

test_that("generate_data_headers sorts by question number", {
  questions <- list(
    "3" = make_single_response("Q03"),
    "1" = make_single_response("Q01"),
    "2" = make_single_response("Q02")
  )
  result <- generate_data_headers(questions)
  headers <- as.character(result[1, ])
  # Should be ResponseID, Q01, Q02, Q03
  expect_equal(headers, c("ResponseID", "Q01", "Q02", "Q03"))
})

test_that("generate_data_headers returns single-row data frame", {
  questions <- list("1" = make_single_response())
  result <- generate_data_headers(questions)
  expect_equal(nrow(result), 1)
  expect_true(is.data.frame(result))
})


# ==============================================================================
# TEST: generate_output_files (integration — writes to disk)
# ==============================================================================

test_that("generate_output_files creates all three Excel files", {
  skip_if_not_installed("openxlsx")

  tmp_dir <- tempdir()
  on.exit(unlink(list.files(tmp_dir, pattern = "TestProject_.*_parsed\\.xlsx$",
                            full.names = TRUE)))

  questions <- list(
    "1" = make_single_response("Q01", "Colour?"),
    "2" = make_rating("Q02", "Satisfaction?")
  )

  result <- generate_output_files(questions, "TestProject", tmp_dir, verbose = FALSE)

  expect_true(file.exists(result$crosstab_config))
  expect_true(file.exists(result$survey_structure))
  expect_true(file.exists(result$data_headers))

  # Verify file names contain _parsed suffix

  expect_true(grepl("_parsed\\.xlsx$", result$crosstab_config))
  expect_true(grepl("_parsed\\.xlsx$", result$survey_structure))
  expect_true(grepl("_parsed\\.xlsx$", result$data_headers))
})

test_that("generate_output_files produces readable Excel content", {
  skip_if_not_installed("openxlsx")

  tmp_dir <- tempdir()
  on.exit(unlink(list.files(tmp_dir, pattern = "ReadTest_.*_parsed\\.xlsx$",
                            full.names = TRUE)))

  questions <- list("1" = make_single_response("Q01", "Colour?"))

  result <- generate_output_files(questions, "ReadTest", tmp_dir, verbose = FALSE)

  # Read back crosstab config
  ct <- openxlsx::read.xlsx(result$crosstab_config)
  expect_true("QuestionCode" %in% names(ct))
  expect_true("ResponseID" %in% ct$QuestionCode)
  expect_true("Q01" %in% ct$QuestionCode)

  # Read back survey structure - Questions sheet
  ss_q <- openxlsx::read.xlsx(result$survey_structure, sheet = "Questions")
  expect_true("Q01" %in% ss_q$QuestionCode)
  expect_equal(ss_q$Variable_Type[ss_q$QuestionCode == "Q01"], "Single_Response")

  # Read back survey structure - Options sheet
  ss_o <- openxlsx::read.xlsx(result$survey_structure, sheet = "Options")
  expect_true("Red" %in% ss_o$OptionText)

  # Read back data headers
  dh <- openxlsx::read.xlsx(result$data_headers, colNames = FALSE)
  headers <- as.character(dh[1, ])
  expect_true("ResponseID" %in% headers)
  expect_true("Q01" %in% headers)
})

test_that("generate_output_files handles verbose output", {
  skip_if_not_installed("openxlsx")

  tmp_dir <- tempdir()
  on.exit(unlink(list.files(tmp_dir, pattern = "VerboseTest_.*_parsed\\.xlsx$",
                            full.names = TRUE)))

  questions <- list("1" = make_single_response())

  output <- capture.output(
    generate_output_files(questions, "VerboseTest", tmp_dir, verbose = TRUE)
  )
  expect_true(any(grepl("Generating Crosstab_Config", output)))
  expect_true(any(grepl("Generating Survey_Structure", output)))
  expect_true(any(grepl("Generating Data_Headers", output)))
})


cat("\n=== AlchemerParser Output Tests Complete ===\n")

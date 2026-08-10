# ==============================================================================
# VAS - reporting label overrides
# ==============================================================================
# The text a reader sees comes from two places, neither written for them: an
# asked question carries its Alchemer title, a derived column carries its
# dictionary description. vas_report_labels.csv is where a reporting label goes
# instead, and it has to survive a rebuild — which hand-editing the generated
# structure workbook does not.
# ==============================================================================

questions_fixture <- function() {
  data.frame(
    QuestionCode = c("PPU", "PrepaidElectricity_Purchased", "Age"),
    QuestionText = c("Have you bought prepaid electricity in the last 12 months?",
                     "Buy Prepaid electricity at all in last 12 months?",
                     "What is your age?"),
    Variable_Type = c("Multi_Mention", "Single_Response", "Single_Response"),
    Columns = 1L, stringsAsFactors = FALSE)
}

write_labels <- function(dir, df) {
  utils::write.csv(df, file.path(dir, "vas_report_labels.csv"), row.names = FALSE)
  dir
}

test_that("a matching code is relabelled and nothing else moves", {
  d <- tempfile(); dir.create(d)
  write_labels(d, data.frame(question_code = "PPU",
                             question_text = "Who have you bought electricity for?",
                             stringsAsFactors = FALSE))

  out <- apply_report_labels(questions_fixture(), d)

  expect_equal(out$QuestionText[out$QuestionCode == "PPU"],
               "Who have you bought electricity for?")
  expect_equal(out$QuestionText[out$QuestionCode == "Age"], "What is your age?")
  expect_equal(nrow(out), 3)
  expect_equal(out$QuestionCode, questions_fixture()$QuestionCode)
})

test_that("a code that does not exist is refused, not ignored", {
  # A typo that silently does nothing is the worst outcome: the run succeeds,
  # the label does not change, and nothing on screen points at the file.
  d <- tempfile(); dir.create(d)
  write_labels(d, data.frame(question_code = c("PPU", "PPUU"),
                             question_text = c("a", "b"), stringsAsFactors = FALSE))

  err <- tryCatch(apply_report_labels(questions_fixture(), d), error = function(e) e)

  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "PPUU")
  expect_match(conditionMessage(err), "Nothing was relabelled")
})

test_that("one question cannot carry two labels", {
  d <- tempfile(); dir.create(d)
  write_labels(d, data.frame(question_code = c("PPU", "PPU"),
                             question_text = c("a", "b"), stringsAsFactors = FALSE))

  err <- tryCatch(apply_report_labels(questions_fixture(), d), error = function(e) e)

  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "more than once")
})

test_that("no file, an empty file, and blank rows all mean no overrides", {
  d_none <- tempfile(); dir.create(d_none)
  expect_equal(apply_report_labels(questions_fixture(), d_none)$QuestionText,
               questions_fixture()$QuestionText)

  d_empty <- tempfile(); dir.create(d_empty)
  write_labels(d_empty, data.frame(question_code = character(0),
                                   question_text = character(0),
                                   stringsAsFactors = FALSE))
  expect_equal(apply_report_labels(questions_fixture(), d_empty)$QuestionText,
               questions_fixture()$QuestionText)

  d_blank <- tempfile(); dir.create(d_blank)
  write_labels(d_blank, data.frame(question_code = c("PPU", ""),
                                   question_text = c("", "x"),
                                   stringsAsFactors = FALSE))
  expect_equal(apply_report_labels(questions_fixture(), d_blank)$QuestionText,
               questions_fixture()$QuestionText)
})

test_that("a file missing its columns says which ones", {
  d <- tempfile(); dir.create(d)
  write_labels(d, data.frame(code = "PPU", text = "x", stringsAsFactors = FALSE))

  err <- tryCatch(apply_report_labels(questions_fixture(), d), error = function(e) e)

  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "question_code")
})

test_that("surrounding whitespace in the file does not stop a match", {
  d <- tempfile(); dir.create(d)
  write_labels(d, data.frame(question_code = "  PPU  ",
                             question_text = "  Who have you bought electricity for?  ",
                             stringsAsFactors = FALSE))

  out <- apply_report_labels(questions_fixture(), d)
  expect_equal(out$QuestionText[out$QuestionCode == "PPU"],
               "Who have you bought electricity for?")
})

test_that("the shipped label file matches its own contract", {
  f <- file.path(dirname(dirname(getwd())), "vas_report_labels.csv")
  skip_if_not(file.exists(f), "shipped label file not found from test wd")

  labels <- utils::read.csv(f, stringsAsFactors = FALSE, colClasses = "character")
  expect_true(all(c("question_code", "question_text") %in% names(labels)))
  expect_gt(nrow(labels), 0)
  expect_false(any(duplicated(trimws(labels$question_code))))
  expect_true(all(nzchar(trimws(labels$question_text))))
})

# test-vas_bill_who_for.R
# One who-for table per bill type, built from the derived Own and Oth sides.
# The invariants that matter: every respondent carries exactly the mentions
# their sides justify, the three options never leave anyone out, and the table
# agrees with the base filters the config already uses on the same sides.

who_for_fixture_map <- function() {
  data.frame(
    category = c("BillMunicipal", "BillMunicipal", "BillTraffic", "BillTraffic",
                 "BillOneSided", "PPU", "PPU"),
    label = c("Municipal account", "Municipal account", "Traffic fines",
              "Traffic fines", "One sided", "Prepaid electricity",
              "Prepaid electricity"),
    base = c("Own", "Oth", "Own", "Oth", "Own", "Own", "Oth"),
    stringsAsFactors = FALSE
  )
}

# Six respondents, one per case worth getting wrong:
#   1  pays the municipal account for themselves only
#   2  pays it for someone else only
#   3  pays it for both
#   4  pays it for neither
#   5  a zero on one side and a real count on the other
#   6  routed past the category - a zero, not a missing answer
who_for_fixture_data <- function() {
  data.frame(
    ResponseID = as.character(1:6),
    BillMunicipal_Own_TxnPerMonth = c(1, 0, 2, 0, 0, 0),
    BillMunicipal_Oth_TxnPerMonth = c(0, 1, 1, 0, 3, 0),
    BillMunicipal_Purchased = c("Yes", "Yes", "Yes", "No", "Yes", "No"),
    BillTraffic_Own_TxnPerMonth = c(0, 0, 0, 0, 0, 0),
    BillTraffic_Oth_TxnPerMonth = c(0, 0, 0, 0, 0, 0),
    BillTraffic_Purchased = rep("No", 6),
    stringsAsFactors = FALSE
  )
}

who_for_fixture_structure <- function() {
  list(
    questions = data.frame(
      QuestionCode = c("BillMunicipal_Purchased", "BillTraffic_Purchased"),
      QuestionText = c("Did you pay a municipal account in the past 12 months?",
                       "Did you pay traffic fines in the past 12 months?"),
      Variable_Type = "Single_Response", Columns = 1L,
      stringsAsFactors = FALSE),
    options = data.frame(
      QuestionCode = rep(c("BillMunicipal_Purchased", "BillTraffic_Purchased"),
                         each = 2),
      OptionText = c("Yes", "No", "Yes", "No"),
      DisplayText = c("Yes", "No", "Yes", "No"),
      DisplayOrder = c(1L, 2L, 1L, 2L),
      stringsAsFactors = FALSE)
  )
}

test_that("only bill categories collected on both sides qualify", {
  found <- find_bill_who_for_categories(who_for_fixture_data(),
                                        who_for_fixture_map())

  # BillOneSided has no Oth row in the map; PPU is not a bill and asks its own
  # who-for question already
  expect_equal(found$category, c("BillMunicipal", "BillTraffic"))
  expect_equal(found$label, c("Municipal account", "Traffic fines"))
})

test_that("a category the dataset does not carry is left out", {
  data <- who_for_fixture_data()
  data$BillTraffic_Oth_TxnPerMonth <- NULL

  found <- find_bill_who_for_categories(data, who_for_fixture_map())
  expect_equal(found$category, "BillMunicipal")
})

test_that("each respondent carries exactly the mentions their sides justify", {
  data <- who_for_fixture_data()
  categories <- find_bill_who_for_categories(data, who_for_fixture_map())
  columns <- bill_who_for_columns(data, categories)

  expect_equal(columns$BillMunicipal_For_1,
               c("Myself", NA, "Myself", NA, NA, NA))
  expect_equal(columns$BillMunicipal_For_2,
               c(NA, "Someone else", "Someone else", NA, "Someone else", NA))
  expect_equal(columns$BillMunicipal_For_3,
               c(NA, NA, NA, "Have not paid any", NA, "Have not paid any"))
})

test_that("nobody is left without a mention", {
  data <- who_for_fixture_data()
  categories <- find_bill_who_for_categories(data, who_for_fixture_map())
  columns <- bill_who_for_columns(data, categories)

  members <- do.call(cbind, columns[sprintf("BillMunicipal_For_%d", 1:3)])
  expect_true(all(rowSums(!is.na(members)) >= 1))
})

test_that("the who-for table and the config's base filters agree on who is in", {
  # the config filters the for-self tables with `<Category>_Own_TxnPerMonth != 0`;
  # a respondent mentioned under "Myself" must be exactly one of those
  data <- who_for_fixture_data()
  categories <- find_bill_who_for_categories(data, who_for_fixture_map())
  columns <- bill_who_for_columns(data, categories)

  expect_equal(!is.na(columns$BillMunicipal_For_1),
               data$BillMunicipal_Own_TxnPerMonth != 0)
  expect_equal(!is.na(columns$BillMunicipal_For_2),
               data$BillMunicipal_Oth_TxnPerMonth != 0)
})

test_that("a side that disagrees with the Yes/No flag is reported, not hidden", {
  data <- who_for_fixture_data()
  data$BillMunicipal_Purchased[1] <- "No"        # transacts, but flagged No
  categories <- find_bill_who_for_categories(data, who_for_fixture_map())

  expect_output(disagreements <- report_bill_who_for_disagreement(data, categories),
                "DATA_WHO_FOR_DISAGREES_WITH_PURCHASED")
  expect_equal(disagreements, 1L)
})

test_that("a dataset whose sides all agree reports nothing", {
  data <- who_for_fixture_data()
  categories <- find_bill_who_for_categories(data, who_for_fixture_map())

  expect_silent(disagreements <- report_bill_who_for_disagreement(data, categories))
  expect_equal(disagreements, 0L)
})

test_that("the structure rows declare exactly the columns the data gains", {
  # the alignment guard in vas_turas_build.R expands a Multi_Mention into
  # "<code>_1..<Columns>" and refuses any drift either way, so the declaration
  # and the new columns have to be the same set
  data <- who_for_fixture_data()
  structure <- who_for_fixture_structure()

  added <- add_bill_who_for(data, structure, who_for_fixture_map())

  new_questions <- setdiff(added$questions$QuestionCode,
                           structure$questions$QuestionCode)
  declared <- unlist(lapply(match(new_questions, added$questions$QuestionCode),
                            function(i) {
    expect_equal(added$questions$Variable_Type[i], "Multi_Mention")
    sprintf("%s_%d", added$questions$QuestionCode[i],
            seq_len(as.integer(added$questions$Columns[i])))
  }))
  gained <- setdiff(names(added$data), names(data))

  expect_equal(sort(declared), sort(gained))
  # and the option rows cover every declared member exactly once
  new_options <- setdiff(added$options$QuestionCode, structure$options$QuestionCode)
  expect_equal(sort(new_options), sort(declared))
})

test_that("each new question is spliced in behind its own Yes/No question", {
  added <- add_bill_who_for(who_for_fixture_data(), who_for_fixture_structure(),
                            who_for_fixture_map())

  expect_equal(added$questions$QuestionCode,
               c("BillMunicipal_Purchased", "BillMunicipal_For",
                 "BillTraffic_Purchased", "BillTraffic_For"))
  # and its options behind that question's own options
  expect_equal(added$options$QuestionCode[1:5],
               c("BillMunicipal_Purchased", "BillMunicipal_Purchased",
                 "BillMunicipal_For_1", "BillMunicipal_For_2",
                 "BillMunicipal_For_3"))
})

test_that("running twice refuses rather than overwriting the columns", {
  once <- add_bill_who_for(who_for_fixture_data(), who_for_fixture_structure(),
                           who_for_fixture_map())

  expect_error(
    add_bill_who_for(once$data,
                     list(questions = once$questions, options = once$options),
                     who_for_fixture_map()),
    class = "vas_bill_who_for_already_added")
})

test_that("a study with no bill categories is left untouched", {
  map <- who_for_fixture_map()
  map <- map[!grepl("^Bill", map$category), , drop = FALSE]

  added <- add_bill_who_for(who_for_fixture_data(), who_for_fixture_structure(), map)
  expect_equal(names(added$data), names(who_for_fixture_data()))
  expect_equal(nrow(added$categories), 0L)
})

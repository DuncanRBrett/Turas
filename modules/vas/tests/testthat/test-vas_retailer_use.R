# test-vas_retailer_use.R
# Total used / most often / also used, for the till point and money market
# retailer pair. Two invariants matter: Ever = Main + Also for every retailer,
# and the people who use no retailer at all are OUT of the also-used base
# rather than counted as using exactly one.

retailer_fixture_questions <- function() {
  data.frame(
    QuestionCode = c("RetailerMain", "RetailerOther", "Gender"),
    QuestionText = c("Which retailer do you use most often for till point or money market counter transactions?",
                     "What other retailers have you used in the last 12 months for till point or money market counter transactions?",
                     "Gender"),
    Variable_Type = c("Single_Response", "Multi_Mention", "Single_Response"),
    Columns = c(1L, 4L, 1L),
    stringsAsFactors = FALSE
  )
}

retailer_fixture_options <- function() {
  shops <- c("Shoprite", "Checkers", "Other")
  rbind(
    # the non-user answer leads, exactly as the live survey lists it
    data.frame(QuestionCode = "RetailerMain",
               OptionText = c(VAS_RETAILER_NONUSER, shops),
               DisplayText = c(VAS_RETAILER_NONUSER, "Shoprite", "Checkers",
                               "Other (Please Specify)"),
               DisplayOrder = 1:4, stringsAsFactors = FALSE),
    # ... and the partner lists no non-user answer, but does list "No other
    # retailers", in a different position again
    data.frame(QuestionCode = sprintf("RetailerOther_%d", 1:4),
               OptionText = c("Shoprite", "Checkers", VAS_RETAILER_NONE_OTHER,
                              "Other"),
               DisplayText = c("Shoprite", "Checkers", VAS_RETAILER_NONE_OTHER,
                               "Other (Please Specify)"),
               DisplayOrder = 1:4, stringsAsFactors = FALSE),
    data.frame(QuestionCode = "Gender", OptionText = c("Male", "Female"),
               DisplayText = c("Male", "Female"), DisplayOrder = 1:2,
               stringsAsFactors = FALSE)
  )
}

# Six respondents, one per case worth getting wrong:
#   1  Shoprite most often, and names it AGAIN under "other" (the defect)
#   2  Shoprite most often, plus a genuinely additional retailer
#   3  Shoprite most often, "No other retailers"
#   4  uses no retailer at all - not asked the other question
#   5  answered "other" only, no most-often retailer
#   6  not asked either question
retailer_fixture_data <- function() {
  data.frame(
    ResponseID = as.character(1:6),
    RetailerMain = c("Shoprite", "Shoprite", "Shoprite", VAS_RETAILER_NONUSER,
                     NA, NA),
    RetailerOther_1 = c("Shoprite", "Shoprite", NA, NA, "Shoprite", NA),
    RetailerOther_2 = c(NA, "Checkers", NA, NA, NA, NA),
    RetailerOther_3 = c(NA, NA, VAS_RETAILER_NONE_OTHER, NA, NA, NA),
    RetailerOther_4 = c(NA, NA, NA, NA, "", NA),
    Gender = c("Male", "Female", "Male", "Female", "Male", "Female"),
    stringsAsFactors = FALSE
  )
}

retailer_fixture_structure <- function() {
  list(questions = retailer_fixture_questions(),
       options = retailer_fixture_options())
}

test_that("the pair is recognised only when both questions are there in the right types", {
  expect_true(has_retailer_pair(retailer_fixture_questions()))

  no_main <- retailer_fixture_questions()
  no_main$QuestionCode[1] <- "SomethingElse"
  expect_false(has_retailer_pair(no_main))

  wrong_type <- retailer_fixture_questions()
  wrong_type$Variable_Type[2] <- "Single_Response"
  expect_false(has_retailer_pair(wrong_type))
})

test_that("the total table leads with the non-user row and the also table ends with No other retailers", {
  lists <- retailer_option_lists(retailer_fixture_options(),
                                 retailer_fixture_questions())

  # the most-often question's own order, non-user answer included
  expect_equal(lists$ever$value,
               c(VAS_RETAILER_NONUSER, "Shoprite", "Checkers", "Other"))
  # the same retailers, non-user answer dropped, "No other retailers" appended
  expect_equal(lists$also$value,
               c("Shoprite", "Checkers", "Other", VAS_RETAILER_NONE_OTHER))
  # the partner's own order is kept separately, because its member columns sit
  # in it and "No other retailers" is NOT last there
  expect_equal(lists$other$value,
               c("Shoprite", "Checkers", VAS_RETAILER_NONE_OTHER, "Other"))
})

test_that("a retailer offered by only one of the two questions is refused, not used", {
  options <- retailer_fixture_options()
  options$OptionText[options$QuestionCode == "RetailerOther_2"] <- "Boxer"
  expect_error(retailer_option_lists(options, retailer_fixture_questions()),
               class = "vas_retailer_options_differ")

  no_sentinel <- retailer_fixture_options()
  no_sentinel$OptionText[no_sentinel$QuestionCode == "RetailerOther_3"] <- "Boxer"
  expect_error(retailer_option_lists(no_sentinel, retailer_fixture_questions()),
               class = "vas_retailer_options_differ")
})

test_that("total used counts a retailer once, however many times it was named", {
  lists <- retailer_option_lists(retailer_fixture_options(),
                                 retailer_fixture_questions())
  cols <- retailer_use_columns(retailer_fixture_data(), lists)

  # Shoprite is column 2 of the total table (the non-user answer is column 1)
  expect_equal(cols$RetailerEver_2,
               c("Shoprite", "Shoprite", "Shoprite", NA, "Shoprite", NA))
  expect_equal(cols$RetailerEver_3, c(NA, "Checkers", NA, NA, NA, NA))
  # the non-user row comes from the most-often question alone
  expect_equal(cols$RetailerEver_1,
               c(NA, NA, NA, VAS_RETAILER_NONUSER, NA, NA))
})

test_that("also used strips the retailer used most often", {
  lists <- retailer_option_lists(retailer_fixture_options(),
                                 retailer_fixture_questions())
  cols <- retailer_use_columns(retailer_fixture_data(), lists)

  # respondent 1 named Shoprite twice: it is not an ADDITIONAL retailer
  # respondent 5 named Shoprite with no most-often answer: it is
  expect_equal(cols$RetailerAlso_1, c(NA, NA, NA, NA, "Shoprite", NA))
  expect_equal(cols$RetailerAlso_2, c(NA, "Checkers", NA, NA, NA, NA))
})

test_that("Ever = Main + Also for every retailer", {
  lists <- retailer_option_lists(retailer_fixture_options(),
                                 retailer_fixture_questions())
  data <- retailer_fixture_data()
  cols <- retailer_use_columns(data, lists)

  for (i in seq_along(lists$ever$value)) {
    retailer <- lists$ever$value[i]
    if (identical(retailer, VAS_RETAILER_NONUSER)) next
    also_at <- match(retailer, lists$also$value)
    ever <- sum(!is.na(cols[[sprintf("RetailerEver_%d", i)]]))
    main <- sum(!is.na(data$RetailerMain) & data$RetailerMain == retailer)
    also <- sum(!is.na(cols[[sprintf("RetailerAlso_%d", also_at)]]))
    expect_equal(ever, main + also, info = retailer)
  }
})

test_that("No other retailers is recomputed, and people who use none are out of that base", {
  lists <- retailer_option_lists(retailer_fixture_options(),
                                 retailer_fixture_questions())
  cols <- retailer_use_columns(retailer_fixture_data(), lists)
  none <- cols[[sprintf("RetailerAlso_%d", nrow(lists$also))]]

  # 1 ticked only their own main retailer, so they use ONE retailer and the
  # recomputed row says so - the raw question does not
  # 3 ticked it themselves
  # 4 uses no retailer at all: NA, not "No other retailers"
  # 5 named an additional retailer; 6 answered nothing
  expect_equal(none, c(VAS_RETAILER_NONE_OTHER, NA, VAS_RETAILER_NONE_OTHER,
                       NA, NA, NA))
})

test_that("saying you use no retailer and then naming one is refused", {
  lists <- retailer_option_lists(retailer_fixture_options(),
                                 retailer_fixture_questions())
  data <- retailer_fixture_data()
  data$RetailerOther_1[4] <- "Shoprite"          # the non-user names a retailer

  expect_error(retailer_use_columns(data, lists),
               class = "vas_retailer_nonuser_contradicted")
})

test_that("the structure rows declare exactly the columns that were built", {
  lists <- retailer_option_lists(retailer_fixture_options(),
                                 retailer_fixture_questions())
  rows <- retailer_use_structure_rows(lists)
  cols <- retailer_use_columns(retailer_fixture_data(), lists)

  expect_equal(rows$questions$QuestionCode, c("RetailerEver", "RetailerAlso"))
  expect_true(all(rows$questions$Variable_Type == "Multi_Mention"))
  expect_equal(rows$questions$Columns, c(4L, 4L))
  declared <- unlist(lapply(seq_len(nrow(rows$questions)), function(i) {
    sprintf("%s_%d", rows$questions$QuestionCode[i],
            seq_len(rows$questions$Columns[i]))
  }))
  expect_setequal(declared, names(cols))
  expect_setequal(rows$options$QuestionCode, declared)
})

test_that("add_retailer_use widens the data and the structure together, once", {
  built <- add_retailer_use(retailer_fixture_data(), retailer_fixture_structure())

  expect_true(all(c("RetailerEver", "RetailerAlso") %in%
                    built$questions$QuestionCode))
  # spliced in behind the asked pair, not stranded at the end
  expect_true(match("RetailerEver", built$questions$QuestionCode) >
                match("RetailerOther", built$questions$QuestionCode))
  expect_true(match("Gender", built$questions$QuestionCode) >
                match("RetailerAlso", built$questions$QuestionCode))
  expect_true(all(sprintf("RetailerEver_%d", 1:4) %in% names(built$data)))

  expect_error(add_retailer_use(built$data,
                                list(questions = built$questions,
                                     options = built$options)),
               class = "vas_retailer_already_added")
})

test_that("a study without the pair is left exactly as it was", {
  structure <- retailer_fixture_structure()
  structure$questions <- structure$questions[
    structure$questions$QuestionCode == "Gender", , drop = FALSE]
  data <- retailer_fixture_data()

  built <- add_retailer_use(data, structure)
  expect_equal(built$data, data)
  expect_equal(built$questions, structure$questions)
})

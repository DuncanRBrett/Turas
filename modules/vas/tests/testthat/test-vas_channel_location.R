# test-vas_channel_location.R
# Two location tables per section, folded from the channel tables. The
# invariants that matter: a location is counted ONCE however many of its
# channels a respondent named, and the most-often location is always in that
# respondent's own all-used table.

cl_fixture_questions <- function() {
  data.frame(
    QuestionCode = c("PPUChannelMain", "PPUOthChannel", "PPUChannelEver",
                     "PPUChannelAlso", "Gender"),
    QuestionText = c("Where do you buy prepaid electricity most often?",
                     "Where else have you bought prepaid electricity?",
                     "All prepaid electricity channels used",
                     "Where else do you buy prepaid electricity?", "Gender"),
    Variable_Type = c("Single_Response", "Multi_Mention", "Multi_Mention",
                      "Multi_Mention", "Single_Response"),
    Columns = c(1L, 5L, 4L, 5L, 1L),
    stringsAsFactors = FALSE
  )
}

# Four channels, two of which are the same location - that is the fold this
# file exists for.
CL_CHANNELS <- c("Bank App", "Bank ATM", "Spaza Shop / Kiosk", "Bus station kiosks")

cl_fixture_options <- function() {
  rbind(
    data.frame(QuestionCode = "PPUChannelMain", OptionText = CL_CHANNELS,
               DisplayText = CL_CHANNELS, DisplayOrder = 1:4,
               stringsAsFactors = FALSE),
    data.frame(QuestionCode = sprintf("PPUOthChannel_%d", 1:5),
               OptionText = c(CL_CHANNELS, "Nowhere else"),
               DisplayText = c(CL_CHANNELS, "Nowhere else"), DisplayOrder = 1:5,
               stringsAsFactors = FALSE),
    data.frame(QuestionCode = sprintf("PPUChannelEver_%d", 1:4),
               OptionText = CL_CHANNELS, DisplayText = CL_CHANNELS,
               DisplayOrder = 1:4, stringsAsFactors = FALSE),
    data.frame(QuestionCode = sprintf("PPUChannelAlso_%d", 1:5),
               OptionText = c(CL_CHANNELS, "Nowhere else"),
               DisplayText = c(CL_CHANNELS, "Nowhere else"), DisplayOrder = 1:5,
               stringsAsFactors = FALSE),
    data.frame(QuestionCode = "Gender", OptionText = c("Male", "Female"),
               DisplayText = c("Male", "Female"), DisplayOrder = 1:2,
               stringsAsFactors = FALSE)
  )
}

# Four respondents:
#   1  bank app AND bank ATM - two channels, ONE location
#   2  bank app plus a spaza - two locations
#   3  a bus-station kiosk only - an unlisted channel, so Other
#   4  never answered
cl_fixture_data <- function() {
  data.frame(
    ResponseID = as.character(1:4),
    PPUChannelMain = c("Bank App", "Bank App", "Bus station kiosks", NA),
    PPUChannelEver_1 = c("Bank App", "Bank App", NA, NA),
    PPUChannelEver_2 = c("Bank ATM", NA, NA, NA),
    PPUChannelEver_3 = c(NA, "Spaza Shop / Kiosk", NA, NA),
    PPUChannelEver_4 = c(NA, NA, "Bus station kiosks", NA),
    Gender = c("Male", "Female", "Male", "Female"),
    stringsAsFactors = FALSE
  )
}

cl_fixture_structure <- function() {
  list(questions = cl_fixture_questions(), options = cl_fixture_options())
}

cl_pairs <- function() {
  channel_location_pairs(find_channel_pairs(cl_fixture_questions(),
                                            cl_fixture_options()))
}

test_that("each occasion gets an all-used and a most-often location question", {
  pairs <- cl_pairs()

  expect_equal(nrow(pairs), 1L)
  expect_equal(pairs$stem, "PPU")
  expect_equal(pairs$location_ever, "PPULocationEver")
  expect_equal(pairs$location_main, "PPULocationMain")
})

test_that("a location is counted once however many of its channels were named", {
  cols <- channel_location_columns(cl_fixture_data(), cl_pairs(),
                                   cl_fixture_options())

  # respondent 1 named the bank app AND the bank ATM: one location
  expect_equal(cols$PPULocationEver_1, c("Bank", "Bank", NA, NA))
  expect_equal(cols$PPULocationEver_4, c(NA, "Spaza Shop", NA, NA))
})

test_that("every section carries all six locations, used or not", {
  cols <- channel_location_columns(cl_fixture_data(), cl_pairs(),
                                   cl_fixture_options())

  members <- sprintf("PPULocationEver_%d", seq_len(nrow(VAS_LOCATIONS)))
  expect_true(all(members %in% names(cols)))
  # this occasion offers no retailer and no MNO channel at all
  expect_true(all(is.na(cols$PPULocationEver_2)))
  expect_true(all(is.na(cols$PPULocationEver_3)))
})

test_that("an unlisted channel is Other, and someone who never answered is nobody", {
  cols <- channel_location_columns(cl_fixture_data(), cl_pairs(),
                                   cl_fixture_options())

  expect_equal(cols$PPULocationEver_6, c(NA, NA, "Other", NA))
  expect_equal(cols$PPULocationMain, c("Bank", "Bank", "Other", NA))
})

test_that("a most-often location missing from the all-used table is refused", {
  data <- cl_fixture_data()
  data$PPUChannelEver_1 <- NA_character_        # take the bank out of Ever
  expect_error(channel_location_columns(data, cl_pairs(), cl_fixture_options()),
               class = "vas_channel_location_main_not_in_ever")
})

test_that("the structure rows declare exactly the columns that were built", {
  pairs <- cl_pairs()
  rows <- channel_location_structure_rows(pairs, cl_fixture_questions())
  cols <- channel_location_columns(cl_fixture_data(), pairs, cl_fixture_options())

  expect_equal(rows$questions$QuestionCode, c("PPULocationEver", "PPULocationMain"))
  expect_equal(rows$questions$Variable_Type, c("Multi_Mention", "Single_Response"))
  expect_equal(rows$questions$Columns, c(nrow(VAS_LOCATIONS), 1L))
  declared <- c(sprintf("PPULocationEver_%d", seq_len(nrow(VAS_LOCATIONS))),
                "PPULocationMain")
  expect_setequal(declared, names(cols))
  # the single-response question keeps its options under its own code
  expect_equal(sum(rows$options$QuestionCode == "PPULocationMain"),
               nrow(VAS_LOCATIONS))
})

test_that("add_channel_location widens the data and the structure together, once", {
  built <- add_channel_location(cl_fixture_data(), cl_fixture_structure())

  expect_true(all(c("PPULocationEver", "PPULocationMain") %in%
                    built$questions$QuestionCode))
  # spliced in behind the channel block, not stranded at the end
  expect_true(match("PPULocationEver", built$questions$QuestionCode) >
                match("PPUChannelAlso", built$questions$QuestionCode))
  expect_true("PPULocationMain" %in% names(built$data))

  expect_error(add_channel_location(built$data,
                                    list(questions = built$questions,
                                         options = built$options)),
               class = "vas_channel_location_already_added")
})

test_that("a structure whose channel tables have not been built yet is left alone", {
  structure <- cl_fixture_structure()
  drop <- structure$questions$QuestionCode %in% c("PPUChannelEver", "PPUChannelAlso")
  structure$questions <- structure$questions[!drop, , drop = FALSE]
  data <- cl_fixture_data()

  built <- add_channel_location(data, structure)
  expect_equal(built$data, data)
  expect_equal(built$questions, structure$questions)
})

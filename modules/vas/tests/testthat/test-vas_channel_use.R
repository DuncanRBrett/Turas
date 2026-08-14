# test-vas_channel_use.R
# Total used / most often / also used. The invariant that matters is
# Ever = Main + Also for every channel: the derived tables must partition the
# people the raw pair double-counts.

channel_fixture_questions <- function() {
  data.frame(
    QuestionCode = c("PPUChannelMain", "PPUOthChannel", "Gender"),
    QuestionText = c("Where do you buy prepaid electricity most often?",
                     "Where else have you bought prepaid electricity in the past 12 months?",
                     "Gender"),
    Variable_Type = c("Single_Response", "Multi_Mention", "Single_Response"),
    Columns = c(1L, 4L, 1L),
    stringsAsFactors = FALSE
  )
}

channel_fixture_options <- function() {
  channels <- c("Bank App", "Spaza", "Till")
  rbind(
    data.frame(QuestionCode = "PPUChannelMain", OptionText = channels,
               DisplayText = c("Bank: App", "Spaza Shop", "Retailer: Till"),
               DisplayOrder = 1:3, stringsAsFactors = FALSE),
    data.frame(QuestionCode = sprintf("PPUOthChannel_%d", 1:4),
               OptionText = c(channels, "Nowhere else"),
               DisplayText = c("Bank: App", "Spaza Shop", "Retailer: Till",
                               "Nowhere else"),
               DisplayOrder = 1:4, stringsAsFactors = FALSE),
    data.frame(QuestionCode = "Gender", OptionText = c("Male", "Female"),
               DisplayText = c("Male", "Female"), DisplayOrder = 1:2,
               stringsAsFactors = FALSE)
  )
}

# Five respondents, one per case worth getting wrong:
#   1  bank app most often, and names it AGAIN under "where else" (the defect)
#   2  bank app most often, plus a genuinely additional channel
#   3  bank app most often, "Nowhere else"
#   4  answered "where else" only - no most-often channel
#   5  not asked at all
channel_fixture_data <- function() {
  data.frame(
    ResponseID = as.character(1:5),
    PPUChannelMain = c("Bank App", "Bank App", "Bank App", NA, NA),
    PPUOthChannel_1 = c("Bank App", "Bank App", NA, "Bank App", NA),
    PPUOthChannel_2 = c(NA, "Spaza", NA, NA, NA),
    PPUOthChannel_3 = c(NA, NA, NA, "", NA),
    PPUOthChannel_4 = c(NA, NA, "Nowhere else", NA, NA),
    Gender = c("Male", "Female", "Male", "Female", "Male"),
    stringsAsFactors = FALSE
  )
}

channel_fixture_structure <- function() {
  list(questions = channel_fixture_questions(), options = channel_fixture_options())
}

test_that("a most-often question pairs with the partner offering its options plus Nowhere else", {
  pairs <- find_channel_pairs(channel_fixture_questions(), channel_fixture_options())

  expect_equal(nrow(pairs), 1L)
  expect_equal(pairs$main, "PPUChannelMain")
  # paired on the option list, not the name - PPUOthChannel follows no pattern
  expect_equal(pairs$other, "PPUOthChannel")
  expect_equal(pairs$ever, "PPUChannelEver")
  expect_equal(pairs$also, "PPUChannelAlso")
  expect_equal(pairs$channels, 3L)
  expect_equal(pairs$members, 4L)
})

test_that("a partner offering different channels refuses, naming the difference", {
  options <- channel_fixture_options()
  # the survey grew an option on one question and not the other
  options$OptionText[options$QuestionCode == "PPUOthChannel_2"] <- "Kiosk"

  expect_error(find_channel_pairs(channel_fixture_questions(), options),
               class = "vas_channel_unpaired")
  expect_error(find_channel_pairs(channel_fixture_questions(), options),
               "only here: Spaza; only there: Kiosk")
})

test_that("a most-often question with no partner at all refuses, naming what it looked for", {
  questions <- channel_fixture_questions()
  questions$QuestionCode[questions$QuestionCode == "PPUOthChannel"] <- "PPUElsewhere"
  options <- channel_fixture_options()
  options$QuestionCode <- sub("^PPUOthChannel_", "PPUElsewhere_", options$QuestionCode)

  expect_error(find_channel_pairs(questions, options),
               class = "vas_channel_unpaired")
  expect_error(find_channel_pairs(questions, options),
               "no multi-mention question named PPUChannelOther / PPUOthChannel")
})

test_that("the two questions may list the channels in different orders", {
  # Lotto really does: LOTTO Website before LOTTO App in one question and after
  # it in the other. Member columns are found by option value, so the tables
  # are still built - in the most-often question's order.
  options <- channel_fixture_options()
  swap <- options$QuestionCode %in% c("PPUOthChannel_2", "PPUOthChannel_3")
  options$OptionText[swap] <- rev(options$OptionText[swap])
  options$DisplayText[swap] <- rev(options$DisplayText[swap])

  pairs <- find_channel_pairs(channel_fixture_questions(), options)
  expect_equal(nrow(pairs), 1L)

  columns <- channel_use_columns(channel_fixture_data(), pairs, options)
  # respondent 2 ticked member column 2, which now carries "Till"
  expect_equal(columns$PPUChannelEver_2, rep(NA_character_, 5))
  expect_equal(columns$PPUChannelEver_3, c(NA, "Till", NA, NA, NA))
  # and the rows still come out in the most-often question's order
  rows <- channel_use_structure_rows(pairs, channel_fixture_questions(), options)
  expect_equal(rows$options$OptionText[rows$options$QuestionCode == "PPUChannelEver_2"],
               "Spaza")
})

test_that("a derived code taken by a different question refuses rather than overwriting it", {
  questions <- rbind(channel_fixture_questions(), data.frame(
    QuestionCode = "PPUChannelEver", QuestionText = "an asked question",
    Variable_Type = "Single_Response", Columns = 1L, stringsAsFactors = FALSE))

  expect_error(find_channel_pairs(questions, channel_fixture_options()),
               class = "vas_channel_code_clash")
})

test_that("one taken code does not drag its migrated neighbour into the clash", {
  # Ever is already there and correct; Also is taken by something else. Only
  # Also is a clash - a length-recycled test flagged both.
  questions <- rbind(channel_fixture_questions(), data.frame(
    QuestionCode = c("PPUChannelEver", "PPUChannelAlso"),
    QuestionText = c("total used", "an asked question"),
    Variable_Type = c("Multi_Mention", "Single_Response"), Columns = c(3L, 1L),
    stringsAsFactors = FALSE))

  err <- tryCatch(find_channel_pairs(questions, channel_fixture_options()),
                  vas_channel_code_clash = function(e) conditionMessage(e))
  expect_match(err, "PPUChannelAlso")
  expect_false(grepl("PPUChannelEver", err))
})

test_that("a structure already carrying the derived questions reads quietly", {
  # the migration script reads the KEPT structure and pairs off it, so the
  # second run of a one-time migration must not refuse
  questions <- rbind(channel_fixture_questions(), data.frame(
    QuestionCode = c("PPUChannelEver", "PPUChannelAlso"),
    QuestionText = c("total used", "also used"),
    Variable_Type = "Multi_Mention", Columns = c(3L, 4L), stringsAsFactors = FALSE))

  pairs <- find_channel_pairs(questions, channel_fixture_options())
  expect_equal(nrow(pairs), 1L)
  # ... but building them a second time onto that structure is a mistake
  expect_error(add_channel_use(channel_fixture_data(),
                               list(questions = questions,
                                    options = channel_fixture_options())),
               class = "vas_channel_already_added")
})

test_that("total used counts each channel once, however it was named", {
  pairs <- find_channel_pairs(channel_fixture_questions(), channel_fixture_options())
  columns <- channel_use_columns(channel_fixture_data(), pairs,
                                 channel_fixture_options())

  # respondent 1 named the bank app twice and counts once; 4 named it only
  # under "where else" and still counts
  expect_equal(columns$PPUChannelEver_1,
               c("Bank App", "Bank App", "Bank App", "Bank App", NA))
  expect_equal(columns$PPUChannelEver_2, c(NA, "Spaza", NA, NA, NA))
  expect_equal(columns$PPUChannelEver_3, rep(NA_character_, 5))
  # Ever has no Nowhere else member at all
  expect_null(columns$PPUChannelEver_4)
})

test_that("also used drops the channel the respondent uses most often", {
  pairs <- find_channel_pairs(channel_fixture_questions(), channel_fixture_options())
  columns <- channel_use_columns(channel_fixture_data(), pairs,
                                 channel_fixture_options())

  # 1 and 2 both ticked the bank app under "where else"; for both it IS their
  # main channel, so neither is an additional channel
  expect_equal(columns$PPUChannelAlso_1, c(NA, NA, NA, "Bank App", NA))
  expect_equal(columns$PPUChannelAlso_2, c(NA, "Spaza", NA, NA, NA))
})

test_that("Nowhere else is recomputed, so it means what it says", {
  pairs <- find_channel_pairs(channel_fixture_questions(), channel_fixture_options())
  columns <- channel_use_columns(channel_fixture_data(), pairs,
                                 channel_fixture_options())

  # 1 uses one channel - they only re-named their main one - so they join 3,
  # who ticked the row themselves. 5 was never asked and stays out.
  expect_equal(columns$PPUChannelAlso_4,
               c("Nowhere else", NA, "Nowhere else", NA, NA))
})

test_that("every answered respondent lands in exactly one Also row", {
  pairs <- find_channel_pairs(channel_fixture_questions(), channel_fixture_options())
  data <- channel_fixture_data()
  columns <- channel_use_columns(data, pairs, channel_fixture_options())

  also <- vapply(seq_len(nrow(data)), function(i) {
    sum(!is.na(vapply(sprintf("PPUChannelAlso_%d", 1:4),
                      function(cc) columns[[cc]][i], character(1))))
  }, numeric(1))
  answered <- c(TRUE, TRUE, TRUE, TRUE, FALSE)

  expect_true(all(also[answered] >= 1))       # so the Also base equals the Main base
  expect_equal(also[!answered], 0)
})

test_that("Ever equals Main plus Also, channel by channel", {
  pairs <- find_channel_pairs(channel_fixture_questions(), channel_fixture_options())
  data <- channel_fixture_data()
  columns <- channel_use_columns(data, pairs, channel_fixture_options())

  for (i in 1:3) {
    option <- channel_fixture_options()$OptionText[
      channel_fixture_options()$QuestionCode == sprintf("PPUOthChannel_%d", i)]
    ever <- sum(columns[[sprintf("PPUChannelEver_%d", i)]] == option, na.rm = TRUE)
    also <- sum(columns[[sprintf("PPUChannelAlso_%d", i)]] == option, na.rm = TRUE)
    main <- sum(!is.na(data$PPUChannelMain) & data$PPUChannelMain == option)
    expect_equal(ever, main + also)
  }
})

test_that("an empty cell counts as not ticked, not as a channel used", {
  pairs <- find_channel_pairs(channel_fixture_questions(), channel_fixture_options())
  columns <- channel_use_columns(channel_fixture_data(), pairs,
                                 channel_fixture_options())

  # respondent 4's third member column holds "" - an export writes an unticked
  # box either way, and reading it as a tick would put a channel in every table
  expect_true(is.na(columns$PPUChannelEver_3[4]))
  expect_true(is.na(columns$PPUChannelAlso_3[4]))
})

test_that("the derived tables carry the asked question's own option labels", {
  pairs <- find_channel_pairs(channel_fixture_questions(), channel_fixture_options())
  rows <- channel_use_structure_rows(pairs, channel_fixture_questions(),
                                     channel_fixture_options())

  ever <- rows$options[rows$options$QuestionCode == "PPUChannelEver_1", ]
  also <- rows$options[rows$options$QuestionCode == "PPUChannelAlso_1", ]
  expect_equal(ever$OptionText, "Bank App")
  expect_equal(ever$DisplayText, "Bank: App")
  expect_equal(also$DisplayText, "Bank: App")   # the three tables read as one set

  question_rows <- rows$questions
  expect_equal(question_rows$Variable_Type, c("Multi_Mention", "Multi_Mention"))
  expect_equal(question_rows$Columns[question_rows$QuestionCode == "PPUChannelEver"], 3L)
  expect_equal(question_rows$Columns[question_rows$QuestionCode == "PPUChannelAlso"], 4L)
})

test_that("the derived questions are spliced in behind the asked pair", {
  added <- add_channel_use(channel_fixture_data(), channel_fixture_structure())

  expect_equal(added$questions$QuestionCode,
               c("PPUChannelMain", "PPUOthChannel", "PPUChannelEver",
                 "PPUChannelAlso", "Gender"))
  # and the option rows land behind the partner's last member, not at the end
  expect_equal(tail(added$options$QuestionCode, 1), "Gender")
  expect_equal(which(added$options$QuestionCode == "PPUChannelEver_1"),
               which(added$options$QuestionCode == "PPUOthChannel_4") + 1L)
})

test_that("a study with no channel questions is unchanged", {
  questions <- channel_fixture_questions()[3, , drop = FALSE]
  options <- channel_fixture_options()[
    channel_fixture_options()$QuestionCode == "Gender", , drop = FALSE]
  data <- channel_fixture_data()[, c("ResponseID", "Gender")]

  added <- add_channel_use(data, list(questions = questions, options = options))
  expect_equal(added$data, data)
  expect_equal(nrow(added$pairs), 0L)
})

test_that("the raw where-else question starts unselected in a generated config", {
  added <- add_channel_use(channel_fixture_data(), channel_fixture_structure())
  path <- tempfile(fileext = ".xlsx")
  write_turas_config(added$questions, "VAS_Survey_Structure.xlsx", path,
                     hide_codes = added$pairs$other)
  selection <- openxlsx::read.xlsx(path, sheet = "Selection")

  include <- function(code) selection$Include[match(code, selection$QuestionCode)]
  expect_equal(include("PPUOthChannel"), "N")
  expect_equal(include("PPUChannelEver"), "Y")
  expect_equal(include("PPUChannelMain"), "Y")
  expect_equal(include("PPUChannelAlso"), "Y")
})

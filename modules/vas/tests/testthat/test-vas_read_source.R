

# ---- repeated records in the export ------------------------------------------
# The 19 Aug 2026 export repeated its first nine records, so 1,114 rows carried
# 1,105 people and every figure counted nine of them twice.

repeat_fixture <- function() {
  data.frame(
    `Response ID` = c("1", "2", "3"),
    Gender = c("Male", "Female", "Male"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

test_that("an export with no repeats is returned untouched", {
  frame <- repeat_fixture()
  expect_equal(drop_repeated_responses(frame, 1L, "x.xlsx"), frame)
})

test_that("an identical repeat is dropped, keeping the first copy", {
  frame <- rbind(repeat_fixture(), repeat_fixture()[1:2, ])
  out <- drop_repeated_responses(frame, 1L, "x.xlsx")

  expect_equal(nrow(out), 3L)
  expect_equal(out[["Response ID"]], c("1", "2", "3"))
  expect_equal(rownames(out), as.character(1:3))
})

test_that("a repeat whose answers differ is refused rather than guessed at", {
  frame <- rbind(repeat_fixture(), repeat_fixture()[1, ])
  frame$Gender[4] <- "Female"

  expect_error(drop_repeated_responses(frame, 1L, "x.xlsx"),
               class = "vas_export_duplicate_responses")
})

test_that("a missing response id is not treated as a repeat of another", {
  frame <- rbind(repeat_fixture(),
                 data.frame(`Response ID` = c(NA_character_, NA_character_),
                            Gender = c("Male", "Female"),
                            check.names = FALSE, stringsAsFactors = FALSE))
  out <- drop_repeated_responses(frame, 1L, "x.xlsx")
  expect_equal(nrow(out), 5L)
})

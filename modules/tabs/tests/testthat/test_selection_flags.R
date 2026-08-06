# ==============================================================================
# TABS MODULE - Y/N GATE COLUMN NORMALISATION (C3)
# ==============================================================================
#
# The Selection sheet's Include / UseBanner / BannerBoxCategory / CreateIndex and
# the Options sheet's ShowInOutput / ExcludeFromIndex used to be read with an
# exact `== "Y"` test by the engine and with `toupper(...) == "Y"` by several
# preflight validators. A lowercase "y" passed validation and was then dropped by
# the engine — a question, a banner, an index row or a response option vanished
# from the deliverable with nothing printed anywhere.
#
# These tests pin the contract: both sheets are canonicalised to "Y"/"N" at their
# single load site, so every reader agrees; an unreadable token refuses instead
# of quietly meaning "no".
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_selection_flags.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))
source(file.path(turas_root, "modules/tabs/lib/crosstabs/data_setup.R"))
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

# Write a Selection sheet to a temp workbook and load it through the real loader.
write_selection <- function(df) {
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Selection")
  openxlsx::writeData(wb, "Selection", df)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

load_selection <- function(df) {
  suppressMessages(load_question_selection(write_selection(df)))
}

flag_survey_structure <- function(show_in_output = c("Y", "Y")) {
  list(
    questions = data.frame(
      QuestionCode = c("Q1", "Gender"),
      QuestionText = c("Satisfaction", "Gender"),
      Variable_Type = c("Likert", "Single_Response"),
      Columns = c("Q1", "Gender"),
      stringsAsFactors = FALSE
    ),
    options = data.frame(
      QuestionCode = c("Gender", "Gender", "Q1", "Q1"),
      OptionText   = c("Male", "Female", "Agree", "Disagree"),
      DisplayText  = c("Male", "Female", "Agree", "Disagree"),
      ShowInOutput = c(show_in_output, "Y", "Y"),
      stringsAsFactors = FALSE
    )
  )
}


# ==============================================================================
# 1. Selection sheet — Include
# ==============================================================================

context("Y-flag normalisation — Include")

test_that("a lowercase Include 'y' keeps the question in the analysis", {
  res <- load_selection(data.frame(
    QuestionCode = c("Q1", "Q2", "Q3"),
    Include = c("y", "Y", "n"),
    stringsAsFactors = FALSE
  ))

  expect_equal(sort(res$crosstab_questions$QuestionCode), c("Q1", "Q2"))
  expect_equal(res$selection_df$Include, c("Y", "Y", "N"))
})

test_that("Include accepts the everyday spellings of yes and no", {
  res <- load_selection(data.frame(
    QuestionCode = c("Q1", "Q2", "Q3", "Q4", "Q5", "Q6"),
    Include = c("Yes", "TRUE", "1", "no", "FALSE", "0"),
    stringsAsFactors = FALSE
  ))

  expect_equal(res$selection_df$Include, c("Y", "Y", "Y", "N", "N", "N"))
  expect_equal(sort(res$crosstab_questions$QuestionCode), c("Q1", "Q2", "Q3"))
})

test_that("a blank Include still means N", {
  res <- load_selection(data.frame(
    QuestionCode = c("Q1", "Q2"),
    Include = c("Y", NA_character_),
    stringsAsFactors = FALSE
  ))

  expect_equal(res$selection_df$Include, c("Y", "N"))
  expect_equal(res$crosstab_questions$QuestionCode, "Q1")
})

test_that("engine and preflight now select the same questions", {
  # The engine tests `Include == "Y"`; preflight tests `toupper(Include) == "Y"`.
  # Before normalisation those two disagreed on any lowercase cell.
  res <- load_selection(data.frame(
    QuestionCode = c("Q1", "Q2", "Q3"),
    Include = c("y", "Y", "N"),
    stringsAsFactors = FALSE
  ))
  sel <- res$selection_df

  engine_view <- sel$QuestionCode[sel$Include == "Y"]
  preflight_view <- sel$QuestionCode[toupper(sel$Include) == "Y"]

  expect_equal(engine_view, preflight_view)
  expect_equal(engine_view, c("Q1", "Q2"))
})


# ==============================================================================
# 2. Selection sheet — UseBanner and BannerBoxCategory
# ==============================================================================

context("Y-flag normalisation — UseBanner / BannerBoxCategory")

test_that("a lowercase UseBanner 'y' still builds the banner", {
  res <- load_selection(data.frame(
    QuestionCode = c("Q1", "Gender"),
    Include = c("Y", "N"),
    UseBanner = c("N", "y"),
    stringsAsFactors = FALSE
  ))

  ss <- flag_survey_structure()
  ss$options <- prepare_options_columns(ss$options)
  banner <- create_banner_structure(res$selection_df, ss)

  expect_true(all(c("Male", "Female") %in% banner$columns))
})

test_that("a lowercase BannerBoxCategory 'y' is read as a box/category banner", {
  res <- load_selection(data.frame(
    QuestionCode = c("Q1", "Gender"),
    Include = c("Y", "N"),
    UseBanner = c("N", "Y"),
    BannerBoxCategory = c("N", "y"),
    stringsAsFactors = FALSE
  ))

  expect_equal(res$selection_df$BannerBoxCategory, c("N", "Y"))
})

test_that("blank UseBanner leaves a Total-only banner", {
  res <- load_selection(data.frame(
    QuestionCode = c("Q1", "Gender"),
    Include = c("Y", "N"),
    UseBanner = c(NA_character_, NA_character_),
    stringsAsFactors = FALSE
  ))

  ss <- flag_survey_structure()
  ss$options <- prepare_options_columns(ss$options)
  banner <- create_banner_structure(res$selection_df, ss)

  expect_equal(banner$columns, "Total")
})


# ==============================================================================
# 3. Selection sheet — CreateIndex
# ==============================================================================

context("Y-flag normalisation — CreateIndex")

test_that("a lowercase CreateIndex 'y' opens the engine's index gate", {
  res <- load_selection(data.frame(
    QuestionCode = c("Q1", "Q2"),
    Include = c("Y", "Y"),
    CreateIndex = c("y", "N"),
    stringsAsFactors = FALSE
  ))
  sel_row <- res$selection_df[res$selection_df$QuestionCode == "Q1", ]

  # add_summary_statistic()'s gate is `create_index != "Y"` -> return(NULL);
  # check_create_index_config()'s is `toupper(CreateIndex) == "Y"`.
  expect_false(sel_row$CreateIndex != "Y")
  expect_true(toupper(sel_row$CreateIndex) == "Y")
})


# ==============================================================================
# 4. Options sheet — ShowInOutput and ExcludeFromIndex
# ==============================================================================

context("Y-flag normalisation — Options sheet")

test_that("a lowercase ShowInOutput 'y' still shows the option", {
  opts <- prepare_options_columns(flag_survey_structure(c("y", "Y"))$options)
  gender <- opts[opts$QuestionCode == "Gender", ]

  # This is the filter used by standard_processor.R and banner.R.
  shown <- gender[gender$ShowInOutput == "Y" | is.na(gender$ShowInOutput), ]

  expect_equal(sort(shown$OptionText), c("Female", "Male"))
})

test_that("a lowercase ShowInOutput 'n' still hides the option", {
  opts <- prepare_options_columns(flag_survey_structure(c("n", "Y"))$options)
  gender <- opts[opts$QuestionCode == "Gender", ]
  shown <- gender[gender$ShowInOutput == "Y" | is.na(gender$ShowInOutput), ]

  expect_equal(shown$OptionText, "Female")
})

test_that("a blank ShowInOutput still defaults to showing the option", {
  opts <- flag_survey_structure()$options
  opts$ShowInOutput <- c(NA_character_, NA_character_, "Y", "Y")
  opts <- prepare_options_columns(opts)

  expect_equal(opts$ShowInOutput, c("Y", "Y", "Y", "Y"))
})

test_that("a lowercase ExcludeFromIndex 'y' excludes on every engine path", {
  opts <- flag_survey_structure()$options
  opts$ExcludeFromIndex <- c("N", "N", "y", "N")
  opts <- prepare_options_columns(opts)

  # cell_calculator.R / score_utils.R / composite_processor.R read
  # `!= "Y"`; summary_builder.R / tracking_wave_values.R read
  # `toupper(trimws(...)) == "Y"`. Before normalisation these disagreed.
  keeps_exact <- opts$ExcludeFromIndex != "Y"
  drops_toupper <- toupper(trimws(opts$ExcludeFromIndex)) == "Y"

  expect_equal(keeps_exact, !drops_toupper)
  expect_equal(opts$ExcludeFromIndex, c("N", "N", "Y", "N"))
})

test_that("a blank ExcludeFromIndex still means N", {
  opts <- flag_survey_structure()$options
  opts$ExcludeFromIndex <- rep(NA_character_, 4)
  opts <- prepare_options_columns(opts)

  expect_equal(opts$ExcludeFromIndex, rep("N", 4))
})


# ==============================================================================
# 5. Unreadable tokens refuse rather than defaulting to "no"
# ==============================================================================

context("Y-flag normalisation — unreadable tokens refuse")

test_that("an unreadable Include token refuses instead of dropping the question", {
  expect_error(
    load_selection(data.frame(
      QuestionCode = c("Q1", "Q2"),
      Include = c("Y", "maybe"),
      stringsAsFactors = FALSE
    )),
    class = "turas_refusal"
  )
})

test_that("the refusal names the sheet, the column, the row and the value", {
  msg <- tryCatch(
    normalise_flag_column(c("Y", "maybe"), "Include", "Selection",
                          default = "N", row_codes = c("Q1", "Q2")),
    turas_refusal = function(e) conditionMessage(e)
  )

  expect_true(grepl("Include", msg, fixed = TRUE))
  expect_true(grepl("Selection", msg, fixed = TRUE))
  expect_true(grepl("Q2", msg, fixed = TRUE))
  expect_true(grepl("maybe", msg, fixed = TRUE))
})

test_that("an unreadable ShowInOutput token refuses instead of hiding the option", {
  opts <- flag_survey_structure(c("x", "Y"))$options

  expect_error(prepare_options_columns(opts), class = "turas_refusal")
})


# ==============================================================================
# 6. normalise_flag_column — unit behaviour
# ==============================================================================

context("normalise_flag_column")

test_that("case and surrounding whitespace are ignored", {
  expect_equal(
    normalise_flag_column(c(" y ", "Y", "  Yes", "yEs "), "Include", "Selection"),
    c("Y", "Y", "Y", "Y")
  )
})

test_that("whitespace-only cells count as blank and take the default", {
  expect_equal(
    normalise_flag_column(c("   ", NA, ""), "Include", "Selection", default = "N"),
    c("N", "N", "N")
  )
  expect_equal(
    normalise_flag_column(c("   ", NA, ""), "ShowInOutput", "Options", default = "Y"),
    c("Y", "Y", "Y")
  )
})

test_that("a zero-length column returns a zero-length result", {
  expect_equal(
    normalise_flag_column(character(0), "Include", "Selection"),
    character(0)
  )
})

test_that("logical and numeric columns normalise without a detour through text", {
  # readxl returns text, but a hand-built data frame (tests, the qual quant
  # layer) can carry real logicals or numbers.
  expect_equal(
    normalise_flag_column(c(TRUE, FALSE, NA), "Include", "Selection"),
    c("Y", "N", "N")
  )
  expect_equal(
    normalise_flag_column(c(1, 0), "Include", "Selection"),
    c("Y", "N")
  )
})

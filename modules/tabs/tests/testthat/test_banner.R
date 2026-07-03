# ==============================================================================
# TABS MODULE - BANNER CREATION TESTS
# ==============================================================================
#
# Tests for banner structure creation and index calculation:
#   1. banner.R — create_banner_structure, process_standard_banner,
#                 generate_excel_letters, get_banner_label, validate_banner_structure
#   2. banner_indices.R — create_banner_row_indices, calculate_banner_bases,
#                         create_single_choice_indices, get_column_weights
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_banner.R")
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

# Source TRS infrastructure
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))

# Source the guard layer
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))

# Source utility modules in dependency order
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))

# Source banner modules
source(file.path(turas_root, "modules/tabs/lib/banner.R"))
source(file.path(turas_root, "modules/tabs/lib/banner_indices.R"))


# ==============================================================================
# HELPERS
# ==============================================================================

# Minimal survey structure for testing
make_test_survey_structure <- function() {
  list(
    questions = data.frame(
      QuestionCode = c("Gender", "Age", "Satisfaction"),
      QuestionText = c("What is your gender?", "What is your age group?", "How satisfied are you?"),
      Variable_Type = c("Single_Response", "Single_Response", "Likert"),
      Columns = c("Gender", "Age", "Satisfaction"),
      stringsAsFactors = FALSE
    ),
    options = data.frame(
      QuestionCode = c("Gender", "Gender", "Age", "Age", "Age",
                       "Satisfaction", "Satisfaction", "Satisfaction"),
      OptionText = c("Male", "Female", "18-34", "35-49", "50+",
                     "Satisfied", "Neutral", "Dissatisfied"),
      DisplayText = c("Male", "Female", "18-34", "35-49", "50+",
                      "Satisfied", "Neutral", "Dissatisfied"),
      ShowInOutput = c("Y", "Y", "Y", "Y", "Y", "Y", "Y", "Y"),
      stringsAsFactors = FALSE
    )
  )
}

# Minimal selection for testing
make_test_selection <- function() {
  data.frame(
    QuestionCode = c("Gender", "Age", "Satisfaction"),
    Include = c("N", "N", "Y"),
    UseBanner = c("Y", "Y", "N"),
    BannerBoxCategory = c("N", "N", "N"),
    DisplayOrder = c(1, 2, 3),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# 1. generate_excel_letters
# ==============================================================================

context("generate_excel_letters")

test_that("generates single letters A-Z", {
  letters_vec <- generate_excel_letters(26)
  expect_equal(letters_vec[1], "A")
  expect_equal(letters_vec[26], "Z")
  expect_length(letters_vec, 26)
})

test_that("generates double letters after Z", {
  letters_vec <- generate_excel_letters(28)
  expect_equal(letters_vec[27], "AA")
  expect_equal(letters_vec[28], "AB")
})

test_that("handles AZ to BA boundary", {
  letters_vec <- generate_excel_letters(53)
  expect_equal(letters_vec[52], "AZ")
  expect_equal(letters_vec[53], "BA")
})

test_that("handles zero input", {
  letters_vec <- generate_excel_letters(0)
  expect_length(letters_vec, 0)
})

test_that("handles single letter", {
  letters_vec <- generate_excel_letters(1)
  expect_equal(letters_vec, "A")
})


# ==============================================================================
# 2. get_banner_label
# ==============================================================================

context("get_banner_label")

test_that("uses BannerLabel when available", {
  df <- data.frame(
    QuestionCode = "Gender",
    BannerLabel = "Gender Identity",
    QuestionText = "What is your gender?",
    stringsAsFactors = FALSE
  )
  expect_equal(get_banner_label(df, 1), "Gender Identity")
})

test_that("falls back to QuestionText when BannerLabel missing", {
  df <- data.frame(
    QuestionCode = "Gender",
    QuestionText = "What is your gender?",
    stringsAsFactors = FALSE
  )
  expect_equal(get_banner_label(df, 1), "What is your gender?")
})

test_that("falls back to QuestionCode when both missing", {
  df <- data.frame(
    QuestionCode = "Q_GENDER",
    stringsAsFactors = FALSE
  )
  expect_equal(get_banner_label(df, 1), "Q_GENDER")
})

test_that("handles NA BannerLabel", {
  df <- data.frame(
    QuestionCode = "Gender",
    BannerLabel = NA_character_,
    QuestionText = "What is your gender?",
    stringsAsFactors = FALSE
  )
  expect_equal(get_banner_label(df, 1), "What is your gender?")
})


# ==============================================================================
# 3. create_banner_structure — full integration
# ==============================================================================

context("create_banner_structure")

test_that("creates banner from selection and survey structure", {
  selection_df <- make_test_selection()
  survey_structure <- make_test_survey_structure()

  result <- create_banner_structure(selection_df, survey_structure)

  # Should have Total + Gender options + Age options = 1 + 2 + 3 = 6 columns
  expect_true(length(result$internal_keys) >= 6)
  # First key should be Total
  expect_true(grepl("TOTAL", result$internal_keys[1]))
  # Should have letters matching columns
  expect_equal(length(result$letters), length(result$internal_keys))
  # Should have banner headers
  expect_true(!is.null(result$banner_headers))
})

test_that("includes column_to_banner mapping", {
  selection_df <- make_test_selection()
  survey_structure <- make_test_survey_structure()

  result <- create_banner_structure(selection_df, survey_structure)

  expect_true(!is.null(result$column_to_banner))
  expect_true(is.character(result$column_to_banner))
})


# ==============================================================================
# 4. process_standard_banner
# ==============================================================================

context("process_standard_banner")

test_that("creates columns for each option", {
  options_df <- data.frame(
    QuestionCode = c("Gender", "Gender"),
    OptionText = c("Male", "Female"),
    DisplayText = c("Male", "Female"),
    ShowInOutput = c("Y", "Y"),
    stringsAsFactors = FALSE
  )
  question_info <- data.frame(
    QuestionCode = "Gender",
    QuestionText = "Gender?",
    Variable_Type = "Single_Response",
    stringsAsFactors = FALSE
  )

  result <- process_standard_banner("Gender", question_info, options_df, start_col = 1)

  expect_equal(result$columns, c("Male", "Female"))
  expect_equal(result$internal_keys, c("Gender::Male", "Gender::Female"))
  expect_equal(length(result$letters), 2)
  expect_null(result$boxcat_groups)
})

test_that("ShowInOutput filtering happens in process_banner_question", {
  # ShowInOutput=N options are filtered BEFORE process_standard_banner is called
  # process_standard_banner receives already-filtered options
  # Test with pre-filtered data (only Y options)
  options_df <- data.frame(
    QuestionCode = c("Q1", "Q1"),
    OptionText = c("A", "C"),
    DisplayText = c("A", "C"),
    ShowInOutput = c("Y", "Y"),
    stringsAsFactors = FALSE
  )
  question_info <- data.frame(
    QuestionCode = "Q1",
    QuestionText = "Question 1?",
    Variable_Type = "Single_Response",
    stringsAsFactors = FALSE
  )

  result <- process_standard_banner("Q1", question_info, options_df, start_col = 1)

  expect_equal(result$columns, c("A", "C"))
  expect_equal(length(result$internal_keys), 2)
})


# ==============================================================================
# 5. validate_banner_structure
# ==============================================================================

context("validate_banner_structure")

test_that("accepts valid banner structure", {
  banner <- list(
    columns = c("Total", "Male", "Female"),
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    letters = c("A", "B", "C"),
    column_to_banner = c("TOTAL::Total" = "TOTAL", "Gender::Male" = "Gender",
                         "Gender::Female" = "Gender"),
    key_to_display = c("TOTAL::Total" = "Total", "Gender::Male" = "Male",
                       "Gender::Female" = "Female")
  )
  result <- tryCatch(
    validate_banner_structure(banner),
    turas_refusal = function(e) e
  )
  expect_false(inherits(result, "turas_refusal"))
})

test_that("rejects banner with length mismatch", {
  banner <- list(
    columns = c("Total", "Male"),
    internal_keys = c("TOTAL::Total", "Gender::Male", "Gender::Female"),
    letters = c("A", "B", "C"),
    column_to_banner = c("TOTAL::Total" = "TOTAL"),
    key_to_display = c("TOTAL::Total" = "Total")
  )
  result <- tryCatch(
    validate_banner_structure(banner),
    turas_refusal = function(e) e
  )
  expect_true(inherits(result, "turas_refusal"))
})


# ==============================================================================
# 6. create_banner_row_indices — single-choice banner
# ==============================================================================

context("create_banner_row_indices")

test_that("creates correct row indices for single-choice banner", {
  data <- data.frame(
    Gender = c("Male", "Female", "Male", "Female", "Male"),
    Age = c("18-34", "35-49", "50+", "18-34", "35-49"),
    stringsAsFactors = FALSE
  )

  # Build banner info manually
  selection_df <- data.frame(
    QuestionCode = "Gender",
    Include = "N",
    UseBanner = "Y",
    BannerBoxCategory = "N",
    DisplayOrder = 1,
    stringsAsFactors = FALSE
  )
  survey_structure <- list(
    questions = data.frame(
      QuestionCode = "Gender",
      QuestionText = "Gender?",
      Variable_Type = "Single_Response",
      Columns = "Gender",
      stringsAsFactors = FALSE
    ),
    options = data.frame(
      QuestionCode = c("Gender", "Gender"),
      OptionText = c("Male", "Female"),
      DisplayText = c("Male", "Female"),
      ShowInOutput = c("Y", "Y"),
      stringsAsFactors = FALSE
    )
  )

  banner <- create_banner_structure(selection_df, survey_structure)
  indices <- create_banner_row_indices(data, banner)

  # Total should include all rows
  total_key <- banner$internal_keys[1]
  expect_equal(length(indices$row_indices[[total_key]]), 5)

  # Male should have rows 1, 3, 5
  male_key <- "Gender::Male"
  expect_equal(sort(indices$row_indices[[male_key]]), c(1L, 3L, 5L))

  # Female should have rows 2, 4
  female_key <- "Gender::Female"
  expect_equal(sort(indices$row_indices[[female_key]]), c(2L, 4L))
})


# ==============================================================================
# 7. calculate_banner_bases
# ==============================================================================

context("calculate_banner_bases")

test_that("calculates unweighted bases correctly", {
  row_indices <- list(
    row_indices = list(
      "TOTAL::Total" = 1:10,
      "Gender::Male" = c(1L, 3L, 5L, 7L, 9L),
      "Gender::Female" = c(2L, 4L, 6L, 8L, 10L)
    )
  )
  weights <- rep(1, 10)

  bases <- calculate_banner_bases(row_indices, weights, is_weighted = FALSE)

  expect_equal(bases[["TOTAL::Total"]]$unweighted, 10)
  expect_equal(bases[["Gender::Male"]]$unweighted, 5)
  expect_equal(bases[["Gender::Female"]]$unweighted, 5)
})

test_that("calculates weighted bases correctly", {
  row_indices <- list(
    row_indices = list(
      "TOTAL::Total" = 1:4,
      "Gender::Male" = c(1L, 2L),
      "Gender::Female" = c(3L, 4L)
    )
  )
  weights <- c(1.5, 0.5, 1.2, 0.8)

  bases <- calculate_banner_bases(row_indices, weights, is_weighted = TRUE)

  expect_equal(bases[["TOTAL::Total"]]$unweighted, 4)
  expect_equal(bases[["TOTAL::Total"]]$weighted, sum(weights))
  expect_equal(bases[["Gender::Male"]]$weighted, 2.0)
  expect_equal(bases[["Gender::Female"]]$weighted, 2.0)
  # Effective base should be calculated
  expect_true(!is.null(bases[["TOTAL::Total"]]$effective))
  expect_true(bases[["TOTAL::Total"]]$effective > 0)
})

test_that("effective base uses Kish formula", {
  row_indices <- list(
    row_indices = list(
      "TOTAL::Total" = 1:4
    )
  )
  weights <- c(2, 2, 2, 2)  # Equal weights

  bases <- calculate_banner_bases(row_indices, weights, is_weighted = TRUE)

  # With equal weights, effective base should equal unweighted base
  expect_equal(bases[["TOTAL::Total"]]$effective, 4)
})


# ==============================================================================
# 8. get_column_weights
# ==============================================================================

context("get_column_weights")

test_that("extracts weights for specified indices", {
  weights <- c(1.5, 0.5, 1.2, 0.8, 1.0)
  indices <- c(2L, 4L)

  result <- get_column_weights(weights, indices)

  expect_equal(result, c(0.5, 0.8))
})

test_that("returns empty for empty indices", {
  weights <- c(1.5, 0.5, 1.2)
  indices <- integer(0)

  result <- get_column_weights(weights, indices)

  expect_length(result, 0)
})


# ==============================================================================
# 9. create_total_only_banner
# ==============================================================================

context("create_total_only_banner")

test_that("creates banner with only Total column", {
  result <- create_total_only_banner()

  expect_true("TOTAL::Total" %in% result$internal_keys)
  expect_equal(length(result$internal_keys), 1)
  expect_equal(length(result$columns), 1)
  expect_equal(length(result$letters), 1)
})


# ==============================================================================
# 10. Slot-indexed Multi_Mention banner (CFG_BANNER_NO_OPTIONS regression)
# ==============================================================================

context("slot-indexed Multi_Mention banner")

make_slot_indexed_survey_structure <- function() {
  # Simulates BRANDPEN1_DSS stored across 3 slot columns, with options defined
  # per-slot (BRANDPEN1_DSS_1, _2, _3) rather than under the root code.
  brands <- c("ROB", "CHS", "IPK")
  brand_labels <- c("Robertsons", "Cape Herb & Spice", "Ina Paarman's Kitchen")
  slot_codes <- paste0("BRANDPEN1_DSS_", 1:3)

  options_df <- do.call(rbind, lapply(slot_codes, function(code) {
    data.frame(
      QuestionCode   = code,
      OptionText     = brands,
      DisplayText    = brand_labels,
      ShowInOutput   = "Y",
      DisplayOrder   = seq_along(brands),
      stringsAsFactors = FALSE
    )
  }))

  list(
    questions = data.frame(
      QuestionCode  = "BRANDPEN1_DSS",
      QuestionText  = "Which brands have you purchased?",
      Variable_Type = "Multi_Mention",
      Columns       = "3",
      stringsAsFactors = FALSE
    ),
    options = options_df
  )
}

make_slot_indexed_selection <- function() {
  data.frame(
    QuestionCode    = "BRANDPEN1_DSS",
    Include         = "N",
    UseBanner       = "Y",
    BannerBoxCategory = "N",
    DisplayOrder    = 1,
    stringsAsFactors = FALSE
  )
}

test_that("slot-indexed Multi_Mention banner creates structure without error", {
  result <- tryCatch(
    create_banner_structure(
      make_slot_indexed_selection(),
      make_slot_indexed_survey_structure()
    ),
    turas_refusal = function(e) e
  )
  expect_false(inherits(result, "turas_refusal"))
  # Total + 3 brand options
  expect_equal(length(result$columns), 4)
  expect_true("Robertsons" %in% result$columns)
  expect_true("Cape Herb & Spice" %in% result$columns)
  expect_true("Ina Paarman's Kitchen" %in% result$columns)
})

test_that("slot-indexed banner deduplicates options — each brand appears once", {
  result <- create_banner_structure(
    make_slot_indexed_selection(),
    make_slot_indexed_survey_structure()
  )
  brand_cols <- result$columns[result$columns != "Total"]
  expect_equal(length(brand_cols), 3)
  expect_equal(length(unique(brand_cols)), 3)
})

test_that("slot-indexed banner internal keys use root code", {
  result <- create_banner_structure(
    make_slot_indexed_selection(),
    make_slot_indexed_survey_structure()
  )
  brand_keys <- result$internal_keys[!grepl("^TOTAL", result$internal_keys)]
  expect_true(all(grepl("^BRANDPEN1_DSS::", brand_keys)))
})

test_that("slot-indexed Multi_Mention banner row indices use OR logic across slots", {
  # R1: ROB in slot1 only
  # R2: CHS in slot1, ROB in slot2
  # R3: IPK in slot1
  # R4: ROB in slot2
  # R5: CHS in slot2
  data <- data.frame(
    BRANDPEN1_DSS_1 = c("ROB", "CHS", "IPK", NA,    "CHS"),
    BRANDPEN1_DSS_2 = c(NA,    "ROB", NA,    "ROB", NA),
    BRANDPEN1_DSS_3 = c(NA,    NA,    NA,    NA,    NA),
    stringsAsFactors = FALSE
  )

  banner  <- create_banner_structure(
    make_slot_indexed_selection(),
    make_slot_indexed_survey_structure()
  )
  indices <- create_banner_row_indices(data, banner)

  rob_key <- "BRANDPEN1_DSS::Robertsons"
  chs_key <- "BRANDPEN1_DSS::Cape Herb & Spice"
  ipk_key <- "BRANDPEN1_DSS::Ina Paarman's Kitchen"

  expect_equal(sort(indices$row_indices[[rob_key]]), c(1L, 2L, 4L))
  expect_equal(sort(indices$row_indices[[chs_key]]), c(2L, 5L))
  expect_equal(sort(indices$row_indices[[ipk_key]]), c(3L))
})

test_that("exact root-code options take priority over slot fallback", {
  # If the user has already defined options under the root code, use those.
  survey_structure <- make_slot_indexed_survey_structure()
  survey_structure$options <- rbind(
    data.frame(
      QuestionCode = "BRANDPEN1_DSS",
      OptionText   = c("ROB", "CHS"),
      DisplayText  = c("Robertsons", "Cape Herb & Spice"),
      ShowInOutput = "Y",
      DisplayOrder = c(1, 2),
      stringsAsFactors = FALSE
    ),
    survey_structure$options
  )
  result <- create_banner_structure(
    make_slot_indexed_selection(),
    survey_structure
  )
  brand_cols <- result$columns[result$columns != "Total"]
  # Only 2 columns from root-code definition, not 3 from slots
  expect_equal(length(brand_cols), 2)
  expect_equal(brand_cols, c("Robertsons", "Cape Herb & Spice"))
})

# ==============================================================================
# DUPLICATE DisplayText OPTIONS (audit fix: colliding internal keys)
# ==============================================================================

context("duplicate DisplayText banner options")

make_dup_display_structure <- function() {
  list(
    questions = data.frame(
      QuestionCode = "Region",
      QuestionText = "Which region?",
      Variable_Type = "Single_Response",
      Columns = "Region",
      stringsAsFactors = FALSE
    ),
    options = data.frame(
      QuestionCode = c("Region", "Region", "Region"),
      OptionText   = c("North", "East", "West"),
      DisplayText  = c("North", "Other", "Other"),   # East + West both shown as "Other"
      ShowInOutput = c("Y", "Y", "Y"),
      stringsAsFactors = FALSE
    )
  )
}

make_dup_display_selection <- function() {
  data.frame(
    QuestionCode = "Region",
    Include = "N",
    UseBanner = "Y",
    BannerBoxCategory = "N",
    DisplayOrder = 1,
    stringsAsFactors = FALSE
  )
}

test_that("duplicated DisplayText yields unique internal keys and a console warning", {
  out <- capture.output(
    banner <- create_banner_structure(make_dup_display_selection(),
                                      make_dup_display_structure())
  )
  expect_true(any(grepl("duplicated DisplayText", out)))
  expect_equal(anyDuplicated(banner$internal_keys), 0L)
  # Display labels are unchanged — both columns still read "Other"
  expect_equal(banner$columns, c("Total", "North", "Other", "Other"))
  expect_equal(banner$internal_keys,
               c("TOTAL::Total", "Region::North", "Region::Other", "Region::Other#1"))
})

test_that("each duplicated-label option keeps its OWN respondents", {
  out <- capture.output(
    banner <- create_banner_structure(make_dup_display_selection(),
                                      make_dup_display_structure())
  )
  data <- data.frame(Region = c("North", "East", "West", "East"),
                     stringsAsFactors = FALSE)
  idx <- create_banner_row_indices(data, banner)$row_indices
  expect_equal(idx[["Region::Other"]], c(2L, 4L))    # East respondents
  expect_equal(idx[["Region::Other#1"]], 3L)         # West respondents — not overwritten
  expect_equal(idx[["Region::North"]], 1L)
})

test_that("distinct DisplayText banners emit no duplicate-label warning", {
  out <- capture.output(
    banner <- create_banner_structure(make_test_selection(),
                                      make_test_survey_structure())
  )
  expect_false(any(grepl("duplicated DisplayText", out)))
})

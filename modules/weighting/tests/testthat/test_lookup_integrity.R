# ==============================================================================
# WEIGHTING MODULE - LOOKUP FILE INTEGRITY (W4, W5, W6)
# ==============================================================================
# The module's deliverable is a lookup file of respondent IDs and weight
# columns, which tabs merges back onto the survey data. These tests cover the
# three ways that file could mislead the run that consumes it:
#
#   W6  a key that cannot be joined on          (duplicate / missing IDs)
#   W6  a weight that overwrites something else (name collisions)
#   W4  a column of blanks that looks like a weight
#   W5  two weights on incompatible scales
# ==============================================================================


# ==============================================================================
# W6: the merge key
# ==============================================================================

test_that("duplicate respondent IDs are refused", {
  data <- data.frame(id = c(1, 2, 3, 2, 5), Region = "North",
                     stringsAsFactors = FALSE)

  refusal <- tryCatch(validate_id_column(data, "id"),
                      turas_refusal = function(e) e)

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "DATA_DUPLICATE_IDS")
  expect_match(conditionMessage(refusal), "1 repeated value")
  expect_match(conditionMessage(refusal), "2 of 5 rows")
})

test_that("an auto-detected ID column that repeats says so in the fix", {
  # Defaulting to column 1 and finding repeats almost always means column 1 is
  # not an identifier — the advice should point at that, not at de-duplicating.
  data <- data.frame(Region = c("North", "North", "South"), id = 1:3,
                     stringsAsFactors = FALSE)

  refusal <- tryCatch(validate_id_column(data, "Region", auto_detected = TRUE),
                      turas_refusal = function(e) e)

  expect_s3_class(refusal, "turas_refusal")
  expect_match(conditionMessage(refusal), "defaulted to the first column")
  expect_match(conditionMessage(refusal), "Set id_column explicitly")
})

test_that("missing or blank respondent IDs are refused", {
  for (ids in list(c(1, 2, NA, 4), c("a", "b", "", "d"))) {
    data <- data.frame(id = ids, stringsAsFactors = FALSE)
    refusal <- tryCatch(validate_id_column(data, "id"),
                        turas_refusal = function(e) e)
    expect_s3_class(refusal, "turas_refusal")
    expect_equal(refusal$code, "DATA_MISSING_ID")
  }
})

test_that("an ID column that is not in the data is refused", {
  data <- data.frame(id = 1:3, stringsAsFactors = FALSE)
  refusal <- tryCatch(validate_id_column(data, "respondent_id"),
                      turas_refusal = function(e) e)
  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "CFG_INVALID_ID_COLUMN")
})

test_that("a unique ID column passes", {
  data <- data.frame(id = 1:100, stringsAsFactors = FALSE)
  expect_true(validate_id_column(data, "id"))
})


# ==============================================================================
# W6: weight names
# ==============================================================================

test_that("a weight named after the ID column is refused", {
  data <- data.frame(id = 1:10, Region = "North", stringsAsFactors = FALSE)

  refusal <- tryCatch(validate_weight_names(data, "id", "id"),
                      turas_refusal = function(e) e)

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "CFG_WEIGHT_NAME_IS_ID")
})

test_that("a weight that would overwrite an existing column is refused", {
  # Re-running a config against data that already carries last month's weight is
  # the realistic case: data[[weight_name]] <- weights replaced it silently.
  data <- data.frame(id = 1:10, Region = "North", design_weight = 1,
                     stringsAsFactors = FALSE)

  refusal <- tryCatch(
    validate_weight_names(data, c("design_weight", "rim_weight"), "id"),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "CFG_WEIGHT_NAME_COLLISION")
  expect_match(conditionMessage(refusal), "'design_weight'")
  expect_false(grepl("rim_weight", conditionMessage(refusal), fixed = TRUE))
})

test_that("weight names that collide with nothing pass", {
  data <- data.frame(id = 1:10, Region = "North", stringsAsFactors = FALSE)
  expect_true(validate_weight_names(data, c("w1", "w2"), "id"))
})


# ==============================================================================
# W5: design weights arrive on the same scale as rim weights
# ==============================================================================

build_design_config <- function(data, tag, grossing = NULL) {
  skip_if_not_installed("openxlsx")

  data_path <- file.path(tempdir(), paste0("scale_", tag, ".csv"))
  write.csv(data, data_path, row.names = FALSE)

  config_path <- file.path(tempdir(), paste0("scale_", tag, ".xlsx"))
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "General")
  openxlsx::writeData(wb, "General", data.frame(
    Setting = c("project_name", "data_file", "id_column", "save_diagnostics"),
    Value = c("Design scale", data_path, "id", "N"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Weight_Specifications")
  openxlsx::writeData(wb, "Weight_Specifications", data.frame(
    weight_name = "design_weight", method = "design",
    description = "Region", apply_trimming = "N",
    trim_method = NA, trim_value = NA, stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Design_Targets")
  openxlsx::writeData(wb, "Design_Targets", data.frame(
    weight_name = rep("design_weight", 2),
    stratum_variable = rep("Region", 2),
    stratum_category = c("North", "South"),
    population_size = c(300000, 100000),
    stringsAsFactors = FALSE
  ))

  if (!is.null(grossing)) {
    openxlsx::addWorksheet(wb, "Advanced_Settings")
    openxlsx::writeData(wb, "Advanced_Settings", data.frame(
      weight_name = "design_weight", grossing = grossing,
      stringsAsFactors = FALSE
    ))
  }

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  load_weighting_config(config_path, verbose = FALSE)
}

design_scale_data <- function() {
  data.frame(
    id = 1:100,
    Region = rep(c("North", "South"), each = 50),
    stringsAsFactors = FALSE
  )
}

test_that("config-path design weights are normalised to sum = n", {
  # Raw design weights here are 300000/50 = 6000 and 100000/50 = 2000, so the
  # un-normalised column would arrive in tabs with a mean of 4000 while a rim
  # weight on the same study has a mean of 1.
  data <- design_scale_data()
  cfg <- build_design_config(data, "default")

  res <- calculate_design_weights_from_config(data, cfg, "design_weight",
                                              verbose = FALSE)

  expect_equal(sum(res$weights), 100)
  expect_equal(res$weight_scale, "sample")
  expect_false(res$grossing)
  # The population total is still reported, so nothing is lost by normalising.
  expect_equal(res$population_total, 400000)
  # Relative weighting is untouched: North is still 3x South.
  expect_equal(res$weights[1] / res$weights[51], 3)
  expect_equal(unname(res$weights[1]), 1.5)   # 6000 / 4000
  expect_equal(unname(res$weights[51]), 0.5)  # 2000 / 4000
})

test_that("grossing = Y keeps population scale and says so", {
  data <- design_scale_data()
  cfg <- build_design_config(data, "grossing", grossing = "Y")

  res <- calculate_design_weights_from_config(data, cfg, "design_weight",
                                              verbose = FALSE)

  expect_equal(sum(res$weights), 400000)
  expect_equal(res$weight_scale, "population")
  expect_true(res$grossing)
  expect_equal(unname(res$weights[1]), 6000)
  expect_equal(unname(res$weights[51]), 2000)
})

test_that("an unreadable grossing setting is refused, not guessed", {
  data <- design_scale_data()
  cfg <- build_design_config(data, "badgrossing", grossing = "sometimes")

  refusal <- tryCatch(
    calculate_design_weights_from_config(data, cfg, "design_weight",
                                         verbose = FALSE),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "CFG_INVALID_GROSSING")
})

test_that("Kish n_eff is unchanged by the scale, so significance is unaffected", {
  # This is why normalising is safe to default: DEFF and n_eff are
  # scale-invariant, so only the weighted Ns on the face of the report move.
  data <- design_scale_data()

  normalised <- calculate_design_weights_from_config(
    data, build_design_config(data, "kish_norm"), "design_weight", verbose = FALSE
  )$weights
  grossed <- calculate_design_weights_from_config(
    data, build_design_config(data, "kish_gross", grossing = "Y"),
    "design_weight", verbose = FALSE
  )$weights

  kish <- function(w) sum(w)^2 / sum(w^2)
  expect_equal(kish(normalised), kish(grossed))
})


# ==============================================================================
# W4: a failed weight is left out, not written as a column of blanks
# ==============================================================================

test_that("a failed weight is omitted from the lookup file, not written all-NA", {
  skip_if_not_installed("openxlsx")

  data <- data.frame(
    id = 1:100,
    Region = rep(c("North", "South"), each = 50),
    Gender = rep(c("Male", "Female"), 50),
    stringsAsFactors = FALSE
  )

  data_path <- file.path(tempdir(), "partial_data.csv")
  write.csv(data, data_path, row.names = FALSE)
  output_path <- file.path(tempdir(), "partial_weights.csv")
  unlink(output_path)

  config_path <- file.path(tempdir(), "partial_config.xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "General")
  openxlsx::writeData(wb, "General", data.frame(
    Setting = c("project_name", "data_file", "id_column", "output_file",
                "save_diagnostics", "html_report"),
    Value = c("Partial run", data_path, "id", output_path, "N", "N"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Weight_Specifications")
  openxlsx::writeData(wb, "Weight_Specifications", data.frame(
    weight_name = c("good_weight", "bad_weight"),
    method = c("design", "design"),
    description = c("Region", "Gender"),
    apply_trimming = c("N", "N"),
    trim_method = c(NA, NA), trim_value = c(NA, NA),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Design_Targets")
  openxlsx::writeData(wb, "Design_Targets", data.frame(
    weight_name = c(rep("good_weight", 2), rep("bad_weight", 2)),
    stratum_variable = c(rep("Region", 2), rep("Gender", 2)),
    stratum_category = c("North", "South", "Male", "Female"),
    population_size = c(300000, 100000, 200000, 200000),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)

  # Force the second weight to fail with a plain error — not a TRS refusal,
  # which aborts the whole run by design. This is the PARTIAL path: one weight
  # calculable, one not.
  original <- calculate_design_weights_from_config
  on.exit(assign("calculate_design_weights_from_config", original,
                 envir = globalenv()), add = TRUE)

  assign("calculate_design_weights_from_config",
         function(data, config, weight_name, verbose = FALSE) {
           if (weight_name == "bad_weight") {
             stop("simulated engine failure for bad_weight")
           }
           original(data, config, weight_name, verbose = verbose)
         },
         envir = globalenv())

  result <- suppressWarnings(run_weighting(config_path, verbose = FALSE))

  expect_true(file.exists(output_path))
  written <- read.csv(output_path, stringsAsFactors = FALSE)

  # The surviving weight is there and is a real weight.
  expect_true("good_weight" %in% names(written))
  expect_false(any(is.na(written$good_weight)))
  expect_equal(nrow(written), 100)

  # The failed one is absent. An all-NA column would merge back into tabs and
  # give every respondent a blank weight under a name the config asked for —
  # a missing column is a question, a blank column is a wrong answer.
  expect_false("bad_weight" %in% names(written))

  # And the run does not call itself a success.
  expect_true(result$status %in% c("PARTIAL", "REFUSED"))
})

# ==============================================================================
# TESTS: follow-ups from the independent review of W1-W8
# ==============================================================================
# Every test here fails on the code as it stood at 82642f2b. They are grouped by
# the finding they close, and the findings are in
# docs/v2_lift/REVIEW_FINDINGS_WEIGHTING_W1-W8_2026-08-09.md.
# ==============================================================================

# ------------------------------------------------------------------------------
# Config builders
# ------------------------------------------------------------------------------

fu_write_data <- function(data, tag) {
  path <- file.path(tempdir(), paste0("fu_", tag, ".csv"))
  write.csv(data, path, row.names = FALSE)
  path
}

#' Build a weighting config workbook from the pieces each test needs.
#' Sheets are only added when supplied, so a config can be design-only,
#' rim-only, or both.
fu_build_config <- function(tag, data_path, specs, design_targets = NULL,
                            rim_targets = NULL, cell_targets = NULL,
                            advanced = NULL, output_file = NULL,
                            id_column = "id") {
  skip_if_not_installed("openxlsx")

  config_path <- file.path(tempdir(), paste0("fu_", tag, ".xlsx"))
  wb <- openxlsx::createWorkbook()

  general <- data.frame(
    Setting = c("project_name", "data_file", "id_column", "save_diagnostics",
                "html_report"),
    Value = c(paste("Follow-up", tag), data_path, id_column, "N", "N"),
    stringsAsFactors = FALSE
  )
  if (!is.null(output_file)) {
    general <- rbind(general, data.frame(Setting = "output_file",
                                         Value = output_file,
                                         stringsAsFactors = FALSE))
  }

  openxlsx::addWorksheet(wb, "General")
  openxlsx::writeData(wb, "General", general)

  openxlsx::addWorksheet(wb, "Weight_Specifications")
  openxlsx::writeData(wb, "Weight_Specifications", specs)

  add <- function(name, df) {
    if (!is.null(df)) {
      openxlsx::addWorksheet(wb, name)
      openxlsx::writeData(wb, name, df)
    }
  }
  add("Design_Targets", design_targets)
  add("Rim_Targets", rim_targets)
  add("Cell_Targets", cell_targets)
  add("Advanced_Settings", advanced)

  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  config_path
}

fu_spec <- function(name, method, description) {
  data.frame(weight_name = name, method = method, description = description,
             apply_trimming = "N", trim_method = NA, trim_value = NA,
             stringsAsFactors = FALSE)
}


# ==============================================================================
# F1 - the design summary reports the weights that were actually written
# ==============================================================================

fu_design_data <- function() {
  data.frame(id = 1:100, Region = rep(c("North", "South"), each = 50),
             stringsAsFactors = FALSE)
}

fu_design_config <- function(tag, grossing = NULL) {
  data <- fu_design_data()
  advanced <- if (is.null(grossing)) NULL else data.frame(
    weight_name = "design_weight", grossing = grossing, stringsAsFactors = FALSE
  )
  path <- fu_build_config(
    tag, fu_write_data(data, tag),
    specs = fu_spec("design_weight", "design", "Region"),
    design_targets = data.frame(
      weight_name = rep("design_weight", 2),
      stratum_variable = rep("Region", 2),
      stratum_category = c("North", "South"),
      population_size = c(300000, 100000),
      stringsAsFactors = FALSE
    ),
    advanced = advanced
  )
  list(data = data, config = load_weighting_config(path, verbose = FALSE))
}

test_that("the stratum summary reports the weights the lookup file carries", {
  # The summary was built from population/sample AFTER the vector had been
  # normalised, so the module's own report said 6000 and 2000 while the lookup
  # file carried 1.5 and 0.5. Three orders of magnitude apart, with nothing
  # saying which was which.
  f <- fu_design_config("f1")
  res <- calculate_design_weights_from_config(f$data, f$config, "design_weight",
                                              verbose = FALSE)

  applied <- sort(unique(round(res$weights, 10)))
  summarised <- sort(round(res$stratum_summary$weight, 10))

  expect_equal(summarised, applied)

  # North 300000/50 = 6000, South 100000/50 = 2000; raw sum 400000 over 100
  # respondents normalises by 1/4000 to 1.5 and 0.5, summing to 100.
  expect_equal(summarised, c(0.5, 1.5))
  expect_equal(sum(res$weights), 100, tolerance = 1e-9)

  # The arithmetic the weight came from is still on the table, in its own column.
  expect_equal(sort(res$stratum_summary$weight_population_scale), c(2000, 6000))
})

test_that("under grossing the two columns agree, because nothing was rescaled", {
  f <- fu_design_config("f1g", grossing = "Y")
  res <- calculate_design_weights_from_config(f$data, f$config, "design_weight",
                                              verbose = FALSE)

  expect_equal(res$weight_scale, "population")
  expect_equal(res$stratum_summary$weight, res$stratum_summary$weight_population_scale)
  expect_equal(sum(res$weights), 400000, tolerance = 1e-6)
})


# ==============================================================================
# F2 - the two opt-ins are separate, and the population side is redistributed
# ==============================================================================

test_that("design: allow_unmatched does not silence an empty stratum", {
  data <- data.frame(id = 1:100, Region = rep("North", 100),
                     stringsAsFactors = FALSE)
  pops <- c(North = 300000, South = 100000)

  refusal <- tryCatch(
    calculate_design_weights(data, "Region", pops, allow_unmatched = TRUE,
                             verbose = FALSE),
    turas_refusal = function(e) e
  )

  expect_s3_class(refusal, "turas_refusal")
  expect_equal(refusal$code, "DATA_UNWEIGHTED_ROWS")
  expect_match(refusal$how_to_fix, "allow_empty_targets = YES")
  # And it says how many people have nobody to represent them.
  expect_match(conditionMessage(refusal), "100,000 of 400,000")
})

test_that("design: allow_empty_targets proceeds on the strata that have sample", {
  data <- data.frame(id = 1:100, Region = rep("North", 100),
                     stringsAsFactors = FALSE)
  pops <- c(North = 300000, South = 100000)

  weights <- calculate_design_weights(data, "Region", pops,
                                      allow_empty_targets = TRUE, verbose = FALSE)

  expect_equal(sum(is.na(weights)), 0)
  expect_equal(attr(weights, "zero_sample_strata"), "South")
  expect_equal(attr(weights, "population_covered"), 300000)
  expect_equal(attr(weights, "population_total"), 400000)
})

test_that("the weighted base is checked against what it should be", {
  # Nothing checked the sum. A weight that quietly lost a quarter of its base
  # still reported GOOD quality, because every check was on the shape of the
  # weights rather than on their total.
  short <- validate_calculated_weights(rep(0.75, 100), "short", expected_sum = 100)
  expect_false(short$valid)
  expect_match(paste(short$errors, collapse = " "), "should sum to")

  ok <- validate_calculated_weights(rep(1, 100), "ok", expected_sum = 100)
  expect_true(ok$valid)
  expect_equal(ok$sum_weights, 100)

  # No expectation supplied, no assertion made — a grossed weight has nothing
  # independent to be checked against.
  quiet <- validate_calculated_weights(rep(4000, 100), "grossed")
  expect_true(quiet$valid)
  expect_null(quiet$expected_sum)
})

test_that("rim checks its total against what it calibrated to, not against itself", {
  skip_if_not(requireNamespace("survey", quietly = TRUE), "survey not available")

  data <- data.frame(Gender = rep(c("Male", "Female"), c(120, 80)),
                     stringsAsFactors = FALSE)
  res <- calculate_rim_weights(data, list(Gender = c(Male = 0.48, Female = 0.52)),
                               verbose = FALSE)

  # target_sum is the sum of the starting weights — the independent expectation.
  # Asserting sum_weights against sum_weights would always pass and check nothing.
  expect_equal(res$diagnostics$target_sum, 200)
  expect_equal(res$diagnostics$sum_weights, 200, tolerance = 1e-9)

  check <- validate_calculated_weights(res$weights, "rim",
                                       expected_sum = res$diagnostics$target_sum)
  expect_true(check$valid)
})

test_that("a grossed weight does not trip the extreme-weight warning", {
  # mean weight = population/sample by design, so the >10 check fired on every
  # grossed run and meant nothing.
  grossed <- validate_calculated_weights(rep(4000, 100), "grossed",
                                         population_scale = TRUE)
  expect_false(any(grepl("very high", grossed$warnings)))

  normalised <- validate_calculated_weights(c(rep(1, 99), 50), "normalised")
  expect_true(any(grepl("very high", normalised$warnings)))
})


# ==============================================================================
# F3 - one weight failing no longer takes the others with it
# ==============================================================================

test_that("a refusal in one weight leaves the other weights calculated", {
  skip_if_not_installed("openxlsx")

  data <- data.frame(
    id = 1:100,
    Region = rep(c("North", "South"), each = 50),
    Gender = rep(c("Male", "Female"), 50),
    stringsAsFactors = FALSE
  )

  output_file <- file.path(tempdir(), "fu_partial_out.csv")
  unlink(output_file)

  # good_weight is calculable. bad_weight names a stratum category nobody is
  # in, which is a TRS refusal — and a TRS refusal used to abort the whole run,
  # so the surviving weight was never written and W4 never fired.
  config_path <- fu_build_config(
    "f3", fu_write_data(data, "f3"),
    specs = rbind(fu_spec("good_weight", "design", "Region"),
                  fu_spec("bad_weight", "design", "Gender")),
    design_targets = data.frame(
      weight_name = c(rep("good_weight", 2), rep("bad_weight", 3)),
      stratum_variable = c(rep("Region", 2), rep("Gender", 3)),
      stratum_category = c("North", "South", "Male", "Female", "Nonbinary"),
      population_size = c(300000, 100000, 200000, 200000, 50000),
      stringsAsFactors = FALSE
    ),
    output_file = output_file
  )

  result <- suppressWarnings(run_weighting(config_path, verbose = FALSE))

  expect_true(file.exists(output_file))
  written <- read.csv(output_file, stringsAsFactors = FALSE)

  expect_true("good_weight" %in% names(written))
  expect_false(any(is.na(written$good_weight)))
  expect_false("bad_weight" %in% names(written))
  expect_equal(nrow(written), 100)
  expect_true(result$status %in% c("PARTIAL", "REFUSED"))
})

test_that("a single-weight config still refuses outright", {
  skip_if_not_installed("openxlsx")

  data <- data.frame(id = 1:100, Gender = rep(c("Male", "Female"), 50),
                     stringsAsFactors = FALSE)
  output_file <- file.path(tempdir(), "fu_single_out.csv")
  unlink(output_file)

  config_path <- fu_build_config(
    "f3single", fu_write_data(data, "f3single"),
    specs = fu_spec("only_weight", "design", "Gender"),
    design_targets = data.frame(
      weight_name = rep("only_weight", 3),
      stratum_variable = rep("Gender", 3),
      stratum_category = c("Male", "Female", "Nonbinary"),
      population_size = c(200000, 200000, 50000),
      stringsAsFactors = FALSE
    ),
    output_file = output_file
  )

  refusal <- tryCatch(
    suppressWarnings(run_weighting(config_path, verbose = FALSE)),
    turas_refusal = function(e) e
  )

  # Nothing to carry on with, so the refusal is the result — and no file is
  # written that could be mistaken for a successful run.
  expect_true(inherits(refusal, "turas_refusal") ||
                identical(refusal$status, "REFUSED"))
  expect_false(file.exists(output_file))
})


# ==============================================================================
# F5 - the smaller items
# ==============================================================================

test_that("an empty cell combination is a preflight Error, not a Warning", {
  cell_df <- data.frame(
    weight_name = rep("cell_weight", 4),
    Gender = c("Male", "Male", "Female", "Female"),
    Age = c("Young", "Old", "Young", "Old"),
    target_percent = c(25, 25, 25, 25),
    stringsAsFactors = FALSE
  )
  data <- data.frame(
    Gender = c(rep("Male", 50), rep("Female", 50)),
    Age = c(rep("Young", 50), rep("Old", 50)),
    stringsAsFactors = FALSE
  )

  log <- check_cell_combinations_vs_data(cell_df, data, NULL)
  empty_rows <- log[log$Issue == "Cell Combination Not in Data", ]

  expect_gt(nrow(empty_rows), 0)
  expect_true(all(empty_rows$Severity == "Error"))
})

test_that("preflight and the engine agree at the edge of the target-sum tolerance", {
  skip_if_not(requireNamespace("survey", quietly = TRUE), "survey not available")

  # 100.5 sits exactly on the allowed tolerance. Preflight passed it and the
  # engine, working in proportions, refused it on floating point.
  rim_df <- data.frame(
    weight_name = rep("w", 3), variable = rep("Region", 3),
    category = c("A", "B", "C"), target_percent = c(33.5, 33.5, 33.5),
    stringsAsFactors = FALSE
  )
  log <- check_rim_targets_sum(rim_df, NULL)
  preflight_blocks <- !is.null(log) && nrow(log) > 0 && any(log$Severity == "Error")

  data <- data.frame(Region = rep(c("A", "B", "C"), c(40, 30, 30)),
                     stringsAsFactors = FALSE)
  engine <- tryCatch(
    calculate_rim_weights(data, list(Region = c(A = 0.335, B = 0.335, C = 0.335)),
                          verbose = FALSE),
    turas_refusal = function(e) e
  )
  engine_blocks <- inherits(engine, "turas_refusal")

  expect_equal(preflight_blocks, engine_blocks)
})


# ==============================================================================
# Golden regression - the gap the review named as the largest
# ==============================================================================

test_that("a full run reproduces a lookup file computed by hand", {
  skip_if_not_installed("openxlsx")
  skip_if_not(requireNamespace("survey", quietly = TRUE), "survey not available")

  # The expected file was derived from arithmetic, not from running the module,
  # so this is a genuine gate rather than a record of what the code happens to
  # do. Every value is hand-checkable:
  #
  #   design  North 300000/120 = 2500, South 100000/80 = 1250. Raw sum 400000
  #           across 200 respondents, normalised by 200/400000 = 0.0005, giving
  #           1.25 and 0.625 — which sum to 120*1.25 + 80*0.625 = 200.
  #   rim     Gender is exactly 100/100 against targets of 48/52, so Male gets
  #           0.96 and Female 1.04 — 100*0.96 + 100*1.04 = 200.
  #
  # If a future change moves any weight, this fails and names the file.
  fixture_dir <- file.path(MODULE_DIR, "tests", "fixtures", "golden")
  data_path <- file.path(fixture_dir, "golden_survey.csv")
  expected <- read.csv(file.path(fixture_dir, "golden_expected_weights.csv"),
                       stringsAsFactors = FALSE)

  output_file <- file.path(tempdir(), "fu_golden_out.csv")
  unlink(output_file)

  config_path <- fu_build_config(
    "golden", data_path,
    specs = rbind(fu_spec("design_weight", "design", "Region"),
                  fu_spec("rim_weight", "rim", "Gender")),
    design_targets = data.frame(
      weight_name = rep("design_weight", 2),
      stratum_variable = rep("Region", 2),
      stratum_category = c("North", "South"),
      population_size = c(300000, 100000),
      stringsAsFactors = FALSE
    ),
    rim_targets = data.frame(
      weight_name = rep("rim_weight", 2),
      variable = rep("Gender", 2),
      category = c("Male", "Female"),
      target_percent = c(48, 52),
      stringsAsFactors = FALSE
    ),
    output_file = output_file
  )

  result <- run_weighting(config_path, verbose = FALSE)
  expect_equal(result$status, "PASS")

  written <- read.csv(output_file, stringsAsFactors = FALSE)

  expect_equal(names(written), names(expected))
  expect_equal(written$id, expected$id)
  expect_equal(written$design_weight, expected$design_weight, tolerance = 1e-9)
  expect_equal(written$rim_weight, expected$rim_weight, tolerance = 1e-9)

  # Both columns are on the same scale, which is the point of W5.
  expect_equal(sum(written$design_weight), 200, tolerance = 1e-9)
  expect_equal(sum(written$rim_weight), 200, tolerance = 1e-9)
})

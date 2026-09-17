# ==============================================================================
# KEYDRIVER - MEDIUMS FROM THE SESSION A REVIEW (F8, F10 to F15, F17)
# ==============================================================================

kd_ensure_module_loaded("all")

test_that("Generate_Stats_Pack reads Yes as yes (F13)", {
  # The gate was toupper(x) == "Y", so "Yes", which is what the example ships
  # and what an analyst writes, produced no stats pack and said nothing. This
  # is the M14 defect class on the one gate spelled with capitals, which is
  # why the M14 sweep missed it.
  main <- readLines(file.path(module_dir, "R", "00_main.R"), warn = FALSE)
  code <- main[!grepl("^\\s*#", main)]
  block <- paste(code, collapse = "\n")
  expect_false(grepl('toupper(config$settings$Generate_Stats_Pack', block, fixed = TRUE))
  expect_true(grepl("as_logical_setting(\n    config$settings$Generate_Stats_Pack, TRUE\n  )",
                    block, fixed = TRUE))

  # The helper itself agrees on every spelling a config might carry.
  for (v in c("Y", "y", "Yes", "YES", "TRUE", "true", "1", "on")) {
    expect_true(as_logical_setting(v), info = v)
  }
  for (v in c("N", "No", "FALSE", "0", "off")) {
    expect_false(as_logical_setting(v), info = v)
  }
  # Unset still means on, which is the documented default.
  expect_true(as_logical_setting(NULL, TRUE))
})

test_that("one parser reads a Segments sheet cell (F15)", {
  # Pre-flight split on "," alone, the quadrant comparison on ",\\s*" and the
  # pipeline on "[;,|]". A cell written "18-24; 25-34" built one segment in
  # the pipeline, warned as a missing value in pre-flight, and produced a
  # segment with no observations in the quadrant. Same run, three answers.
  expect_true(exists("kd_split_segment_values", mode = "function"))

  expect_equal(kd_split_segment_values("18-24, 25-34"), c("18-24", "25-34"))
  expect_equal(kd_split_segment_values("18-24; 25-34"), c("18-24", "25-34"))
  expect_equal(kd_split_segment_values("18-24|25-34"), c("18-24", "25-34"))
  expect_equal(kd_split_segment_values(" 18-24 ;  25-34 "), c("18-24", "25-34"))
  expect_equal(kd_split_segment_values("Solo"), "Solo")
  expect_equal(kd_split_segment_values(NA), character(0))
  expect_equal(kd_split_segment_values(""), character(0))
  expect_equal(kd_split_segment_values(NULL), character(0))
  # A trailing separator does not produce an empty level.
  expect_equal(kd_split_segment_values("a, b,"), c("a", "b"))

  # And all three consumers go through it.
  for (f in c(file.path(module_dir, "R", "00_main.R"),
              file.path(module_dir, "R", "kda_quadrant", "quadrant_comparison.R"),
              file.path(module_dir, "lib", "validation", "preflight_validators.R"))) {
    src <- paste(readLines(f, warn = FALSE), collapse = "\n")
    expect_true(grepl("kd_split_segment_values", src, fixed = TRUE), info = basename(f))
  }
  # The old private splits are gone from the two that had them.
  quad <- paste(readLines(file.path(module_dir, "R", "kda_quadrant",
                                    "quadrant_comparison.R"), warn = FALSE),
                collapse = "\n")
  expect_false(grepl('strsplit(as.character(segments$segment_values[i]), ",\\\\s*")',
                     quad, fixed = TRUE))
})

test_that("a weighted segment comparison uses weighted spreads (F8)", {
  expect_true(exists(".kd_weighted_sd", mode = "function"))
  # A standardised beta is b * (sd_x / sd_y). The coefficients came from a
  # weighted fit and sd_y was weighted, and sd_x was not, so the ratio mixed
  # the model's weighted population with the file's unweighted one.
  seg <- readLines(file.path(module_dir, "R", "07_segment_comparison.R"), warn = FALSE)
  code <- seg[!grepl("^\\s*#", seg)]
  block <- paste(code, collapse = "\n")
  expect_true(grepl(".kd_weighted_sd(col, seg_w)", block, fixed = TRUE))
  # The unweighted branch survives, for an unweighted study.
  expect_true(grepl("apply(mm, 2, stats::sd, na.rm = TRUE)", block, fixed = TRUE))

  # The two disagree whenever weights vary, which is the whole point.
  x <- c(1, 2, 3, 4, 100)
  w <- c(1, 1, 1, 1, 20)
  expect_false(isTRUE(all.equal(stats::sd(x), .kd_weighted_sd(x, w))))

  # .kd_weighted_sd divides by sum(w) and stats::sd by n - 1, so they differ
  # even on flat weights. That is not a defect here: a standardised beta is a
  # RATIO of two spreads, and each branch uses one convention for both the
  # numerator and sd_y, so the denominator cancels. This pins that, because
  # using one helper for sd_x and the other for sd_y would not cancel and is
  # exactly the shape of the bug being fixed.
  expect_equal(.kd_weighted_sd(x, rep(1, 5)),
               sqrt(sum((x - mean(x))^2) / length(x)), tolerance = 1e-10)
  flat_ratio_weighted <- .kd_weighted_sd(x, rep(1, 5)) / .kd_weighted_sd(x * 2, rep(1, 5))
  flat_ratio_plain <- stats::sd(x) / stats::sd(x * 2)
  expect_equal(flat_ratio_weighted, flat_ratio_plain, tolerance = 1e-10)
})

test_that("the NCA bottleneck columns hold the level they name (F12)", {
  nca <- readLines(file.path(module_dir, "R", "10_nca.R"), warn = FALSE)
  block <- paste(nca, collapse = "\n")
  # steps is the number of intervals the 0 to 100 grid is cut into. Three
  # intervals give 0, 33.3, 66.7, 100, and the nearest-level lookup then put
  # the value from 33.3 or 66.7 under the heading Y_50pct.
  expect_true(grepl("KD_NCA_BOTTLENECK_STEPS <- 20L", block, fixed = TRUE))
  expect_true(grepl("steps = KD_NCA_BOTTLENECK_STEPS", block, fixed = TRUE))
  expect_false(grepl("steps = length(bottleneck_levels)", block, fixed = TRUE))
  # Exact, not nearest.
  expect_true(grepl("which(abs(y_levels - lv) < 1e-6)", block, fixed = TRUE))
  expect_false(grepl("which.min(abs(y_levels - lv))", block, fixed = TRUE))

  # And 20 intervals really does contain every level asked for.
  grid <- seq(0, 100, length.out = 20L + 1L)
  for (lv in c(50, 75, 90)) {
    expect_equal(sum(abs(grid - lv) < 1e-6), 1L, info = as.character(lv))
  }
  # Three intervals, the old value, contains none of them.
  old_grid <- seq(0, 100, length.out = 3L + 1L)
  for (lv in c(50, 75, 90)) {
    expect_equal(sum(abs(old_grid - lv) < 1e-6), 0L, info = as.character(lv))
  }
})

test_that("the bootstrap and quadrant disclosures reach Run_Status (F10, F11)", {
  # Not skipped when the helper is absent: its absence is the regression.
  expect_true(exists(".kd_disclosure_rows", mode = "function"))

  # They were attributes on the features' own return values and nothing read
  # them, so a reader of the workbook could not tell that Point_Estimate is
  # the mean of the bootstrap distribution, that iterations had been dropped,
  # or that a requested quadrant source had been substituted.
  boot <- data.frame(driver = "a", stringsAsFactors = FALSE)
  attr(boot, "iterations_requested") <- 1000L
  attr(boot, "iterations_used") <- 998L
  attr(boot, "iterations_dropped") <- 2L
  attr(boot, "bootstrap_policy") <- "Point_Estimate is the MEAN OF THE BOOTSTRAP DISTRIBUTION."
  quad <- structure(list(data = data.frame(driver = "a")),
                    class = "quadrant_results",
                    importance_source_requested = "shap",
                    importance_source_used = "auto (shap was requested and is absent)")

  rows <- .kd_disclosure_rows(list(bootstrap_ci = boot, quadrant = quad))
  expect_true(is.data.frame(rows))
  expect_setequal(rows$Field,
                  c("bootstrap_iterations_requested", "bootstrap_iterations_used",
                    "bootstrap_iterations_dropped", "bootstrap_policy",
                    "quadrant_importance_source_requested",
                    "quadrant_importance_source_used"))
  expect_equal(rows$Value[rows$Field == "bootstrap_iterations_dropped"], "2")
  expect_true(grepl("MEAN OF THE BOOTSTRAP",
                    rows$Value[rows$Field == "bootstrap_policy"], fixed = TRUE))
  expect_true(grepl("shap was requested",
                    rows$Value[rows$Field == "quadrant_importance_source_used"],
                    fixed = TRUE))

  # A run without either feature adds nothing.
  expect_equal(nrow(.kd_disclosure_rows(list())), 0L)
  expect_equal(nrow(.kd_disclosure_rows(NULL)), 0L)

  # The quadrant carries the attributes out rather than losing them on the way.
  qm <- paste(readLines(file.path(module_dir, "R", "kda_quadrant",
                                  "quadrant_main.R"), warn = FALSE), collapse = "\n")
  expect_true(grepl('importance_source_requested = attr(importance,', qm, fixed = TRUE))

  # And the writer is actually given the results object.
  main <- paste(readLines(file.path(module_dir, "R", "00_main.R"), warn = FALSE),
                collapse = "\n")
  expect_true(grepl("results = results)", main, fixed = TRUE))
})

test_that("the bootstrap does not tell an analyst to number their categories (F14)", {
  src <- paste(readLines(file.path(module_dir, "R", "05_bootstrap.R"), warn = FALSE),
               collapse = "\n")
  # "Convert 'contact_channel' to numeric" is advice that invents an order and
  # a spacing the data does not have, and every number downstream inherits it.
  expect_false(grepl("' to numeric before calling bootstrap_importance_ci()",
                     src, fixed = TRUE))
  expect_true(grepl("do NOT score its categories", src, fixed = TRUE))
  # And it states the limitation honestly: the estimators, not the resampling.
  expect_true(grepl("The\n          \"resampling itself is not the obstacle.", src, fixed = TRUE) ||
                grepl("resampling itself is not the obstacle", src, fixed = TRUE))
})

test_that("the example README no longer overstates what it guarantees (F9, F14)", {
  readme <- file.path(project_root, "examples", "keydriver", "README.md")
  skip_if(!file.exists(readme), "README not present")
  src <- paste(readLines(readme, warn = FALSE), collapse = "\n")

  # F9: the order is guaranteed at the committed seed, not by the design. An
  # independent check swapped the two smallest drivers in 3 of 40 runs.
  expect_false(grepl("sampling noise cannot reorder them", src, fixed = TRUE))
  expect_true(grepl("guaranteed at the committed seed", src, fixed = TRUE))

  # F14: resampling rows is indifferent to column types.
  expect_false(grepl("A bootstrap cannot resample a factor", src, fixed = TRUE))
  expect_true(grepl("nothing about resampling that a factor breaks", src, fixed = TRUE))
})

test_that("no test file reports zero tests in isolation (F17)", {
  # A file-level skip_if made three files report 0 tests, 0 skipped, 0 failed
  # under test_file, which reads as success. That is how a file full of
  # assertions can quietly test nothing.
  expect_true(exists("kd_ensure_module_loaded", mode = "function"))
  test_dir_path <- file.path(module_dir, "tests", "testthat")
  files <- list.files(test_dir_path, pattern = "^test_.*[.]R$", full.names = TRUE)
  expect_gt(length(files), 20)

  for (f in files) {
    src <- readLines(f, warn = FALSE)
    # A skip_if outside any test_that() block skips the whole file.
    in_block <- cumsum(grepl("^test_that\\(", src)) > 0
    top_level <- src[!in_block]
    offenders <- grep("^skip_if\\(!exists\\(", top_level, value = TRUE)
    expect_equal(length(offenders), 0L,
                 info = paste(basename(f), paste(offenders, collapse = " | ")))
  }
})

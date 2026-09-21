# Demographic profiling: the config setting that computed nothing.
#
# `demographic_vars` was parsed, carried through validation, offered by the
# template as "categorical variables for demographic profiling", gated by a
# second setting `html_show_demographics`, and read by no caller anywhere in
# the module (independent review 2026-09-21, F2). The worked example named
# three variables and its README said they were along for profiling. The only
# reader of the result returned NULL "gracefully" for a key nothing ever set.
#
# These tests are the wiring's gate: the function has to be called, its numbers
# have to be right, and both the report and the workbook have to show them.

.demographics_fixture <- function(n = 400, seed = 42) {
  # 400 rows: the sample-size guard refuses a study too small for the default
  # k_max, and a fixture that cannot complete a run proves nothing.
  set.seed(seed)
  seg <- rep(1:3, length.out = n)
  data.frame(
    respondent_id = sprintf("R%04d", seq_len(n)),
    q1 = rnorm(n, mean = seg),
    q2 = rnorm(n, mean = -seg),
    q3 = rnorm(n, mean = seg * 2),
    region = c("North", "South", "East")[seg],
    gender = sample(c("Female", "Male"), n, TRUE),
    stringsAsFactors = FALSE
  )
}

.demographics_config <- function(data = NULL, ...) {
  if (is.null(data)) data <- .demographics_fixture()
  dpath <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(data, dpath, sheetName = "Data")
  utils::modifyList(
    list(data_file = dpath, data_sheet = "Data", id_variable = "respondent_id",
         clustering_vars = "q1,q2,q3", k_fixed = "3", method = "kmeans",
         demographic_vars = "region,gender",
         create_dated_folder = "FALSE", generate_stats_pack = "N",
         output_prefix = "seg_"),
    list(...)
  )
}

.demographics_write_config <- function(cfg) {
  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Config")
  openxlsx::writeData(wb, "Config", data.frame(
    Setting = names(cfg), Value = unlist(lapply(cfg, as.character)),
    stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

.demographics_run <- function(...) {
  out_dir <- file.path(tempdir(), paste0("demo_", as.integer(runif(1) * 1e6)))
  cfg <- .demographics_config(output_folder = out_dir, ...)
  path <- .demographics_write_config(cfg)
  capture.output(suppressMessages(
    res <- turas_segment_from_config(path, verbose = FALSE)))
  list(res = res, out_dir = out_dir, config = cfg)
}


# ------------------------------------------------------------------------------
# 1. The function itself, on a known answer.
# ------------------------------------------------------------------------------

test_that("a demographic that is a recoding of the segment shows 100 on the diagonal", {
  clusters <- rep(1:3, each = 40)
  d <- data.frame(
    region = c("North", "South", "East")[clusters],
    stringsAsFactors = FALSE
  )

  capture.output(prof <- profile_demographics(
    data = d, clusters = clusters, demo_vars = "region",
    segment_names = c("Alpha", "Beta", "Gamma")))

  reg <- prof$categorical_profiles$region
  expect_equal(reg$Alpha[reg$Category == "North"], 100)
  expect_equal(reg$Beta[reg$Category == "South"], 100)
  expect_equal(reg$Gamma[reg$Category == "East"], 100)
  expect_equal(sum(reg$Alpha), 100)

  p <- as.numeric(prof$chi_sq_tests$P_Value[prof$chi_sq_tests$Variable == "region"])
  expect_lt(p, 1e-10)
  expect_true(prof$chi_sq_tests$Significant[1])
})

test_that("a demographic unrelated to the segment is not significant", {
  set.seed(11)
  clusters <- rep(1:3, each = 40)
  d <- data.frame(region = sample(c("North", "South", "East"), 120, TRUE),
                  stringsAsFactors = FALSE)

  capture.output(prof <- profile_demographics(
    data = d, clusters = clusters, demo_vars = "region"))

  p <- as.numeric(prof$chi_sq_tests$P_Value[1])
  expect_gt(p, 0.05)
  expect_false(prof$chi_sq_tests$Significant[1])
})


# ------------------------------------------------------------------------------
# 2. The pipeline. This is the test that fails without the wiring.
# ------------------------------------------------------------------------------

test_that("a run with demographic_vars profiles them, shows them and exports them", {
  run <- .demographics_run(html_report = "TRUE")
  res <- run$res

  expect_false(inherits(res, "turas_refusal_result"))
  prof <- res$enhanced$demographic_profiles
  expect_false(is.null(prof))
  expect_setequal(names(prof$categorical_profiles), c("region", "gender"))

  html_path <- file.path(run$out_dir, "seg_segmentation_report.html")
  expect_true(file.exists(html_path))
  html <- paste(readLines(html_path, warn = FALSE), collapse = "\n")
  expect_true(grepl(">Demographics<", html, fixed = TRUE))
  expect_true(grepl("seg-demographics-section", html, fixed = TRUE))
  expect_true(grepl("region", html, fixed = TRUE))
  expect_true(grepl("gender", html, fixed = TRUE))

  xlsx_path <- file.path(run$out_dir, "seg_segmentation_report.xlsx")
  sheets <- openxlsx::getSheetNames(xlsx_path)
  expect_true("Demographics_Tests" %in% sheets)
  expect_true("Demo_region" %in% sheets)
  expect_true("Demo_gender" %in% sheets)
})

test_that("html_show_demographics = FALSE hides the section and keeps the sheets", {
  run <- .demographics_run(html_report = "TRUE", html_show_demographics = "FALSE")

  html <- paste(readLines(file.path(run$out_dir, "seg_segmentation_report.html"),
                          warn = FALSE), collapse = "\n")
  expect_false(grepl("seg-demographics-section", html, fixed = TRUE))
  expect_false(grepl("id=\"seg-demographics\"", html, fixed = TRUE))

  sheets <- openxlsx::getSheetNames(file.path(run$out_dir, "seg_segmentation_report.xlsx"))
  expect_true("Demographics_Tests" %in% sheets)
  expect_true("Demo_region" %in% sheets)
})

test_that("a run without demographic_vars has no section and no sheets", {
  out_dir <- file.path(tempdir(), paste0("demo_none_", as.integer(runif(1) * 1e6)))
  cfg <- .demographics_config(output_folder = out_dir, html_report = "TRUE")
  cfg$demographic_vars <- NULL
  capture.output(suppressMessages(
    res <- turas_segment_from_config(.demographics_write_config(cfg), verbose = FALSE)))

  expect_null(res$enhanced$demographic_profiles)
  html <- paste(readLines(file.path(out_dir, "seg_segmentation_report.html"),
                          warn = FALSE), collapse = "\n")
  expect_false(grepl("seg-demographics-section", html, fixed = TRUE))
  sheets <- openxlsx::getSheetNames(file.path(out_dir, "seg_segmentation_report.xlsx"))
  expect_false("Demographics_Tests" %in% sheets)
})


# ------------------------------------------------------------------------------
# 3. A name the data does not carry is refused at load, before clustering.
# ------------------------------------------------------------------------------

test_that("a missing demographic variable is refused by name before the run starts", {
  out_dir <- file.path(tempdir(), paste0("demo_miss_", as.integer(runif(1) * 1e6)))
  cfg <- .demographics_config(output_folder = out_dir,
                              demographic_vars = "region,provinceX")
  capture.output(suppressMessages(
    res <- turas_segment_from_config(.demographics_write_config(cfg), verbose = FALSE)))

  expect_s3_class(res, "turas_refusal_result")
  expect_equal(res$code, "CFG_DEMOGRAPHIC_VARS_MISSING")
  expect_true(grepl("provinceX", res$problem, fixed = TRUE))
  # Refused at load: nothing was clustered and no output was written.
  expect_false(dir.exists(out_dir) && length(list.files(out_dir)) > 0)
})


# ------------------------------------------------------------------------------
# 4. The section builder on its own.
# ------------------------------------------------------------------------------

.demographics_html_data <- function() {
  list(
    k = 2,
    segment_names = c("Savers", "Spenders"),
    segment_sizes = data.frame(
      segment_id = 1:2, segment_name = c("Savers", "Spenders"),
      n = c(60L, 40L), pct = c(60, 40), stringsAsFactors = FALSE),
    enhanced = list(demographic_profiles = list(
      categorical_profiles = list(region = data.frame(
        Category = c("North", "South"),
        Overall = c(55, 45),
        Savers = c(70, 30),
        Spenders = c(32.5, 67.5),
        stringsAsFactors = FALSE)),
      numeric_profiles = list(),
      chi_sq_tests = data.frame(
        Variable = "region", Chi_Sq = 13.9, DF = 1, P_Value = "1.92e-04",
        Significant = TRUE, Low_Expected = FALSE, stringsAsFactors = FALSE),
      segment_names = c("Savers", "Spenders")))
  )
}

test_that("the section renders percentages and the segment names", {
  hd <- .demographics_html_data()
  tables <- list(demographics = build_seg_demographics_table(hd),
                 demographics_numeric = build_seg_demographics_numeric_table(hd))
  expect_false(is.null(tables$demographics))

  html <- as.character(build_seg_demographics_section(tables, hd))
  expect_true(grepl("Demographics", html, fixed = TRUE))
  expect_true(grepl("Savers", html, fixed = TRUE))
  expect_true(grepl("Spenders", html, fixed = TRUE))
  expect_true(grepl("70%", html, fixed = TRUE))
  expect_true(grepl("column percentages", html, fixed = TRUE))
  # The base note names the clustered n, not the data file's row count.
  expect_true(grepl("100 respondents who were clustered", html, fixed = TRUE))
})

test_that("the section is NULL when nothing profiled", {
  hd <- .demographics_html_data()
  hd$enhanced$demographic_profiles <- NULL
  expect_null(build_seg_demographics_section(list(), hd))
  expect_null(build_seg_demographics_table(hd))
})

test_that("a numeric demographic renders its own table", {
  hd <- .demographics_html_data()
  hd$enhanced$demographic_profiles$numeric_profiles <- list(age_years = data.frame(
    Segment = c("Savers", "Spenders", "Overall"),
    N = c(60L, 40L, 100L), Mean = c(51.2, 33.4, 44.1),
    Median = c(50, 32, 43), SD = c(9.1, 8.2, 11.9),
    Min = c(30, 19, 19), Max = c(72, 55, 72), stringsAsFactors = FALSE))

  tables <- list(demographics = build_seg_demographics_table(hd),
                 demographics_numeric = build_seg_demographics_numeric_table(hd))
  expect_false(is.null(tables$demographics_numeric))

  html <- as.character(build_seg_demographics_section(tables, hd))
  expect_true(grepl("age_years", html, fixed = TRUE))
  expect_true(grepl("51.2", html, fixed = TRUE))
  expect_true(grepl("carry no test", html, fixed = TRUE))
})


# ------------------------------------------------------------------------------
# 5. The numbers, recomputed from the assignments file rather than trusted.
# ------------------------------------------------------------------------------

test_that("the profile percentages match a recomputation from the assignments file", {
  run <- .demographics_run(html_report = "FALSE")
  res <- run$res
  expect_false(inherits(res, "turas_refusal_result"))

  assignments <- openxlsx::read.xlsx(
    file.path(run$out_dir, "seg_segment_assignments.xlsx"), sheet = 1,
    skipEmptyRows = FALSE)
  source_data <- openxlsx::read.xlsx(run$config$data_file, sheet = "Data",
                                     skipEmptyRows = FALSE)

  joined <- merge(assignments[, c("respondent_id", "segment_name")],
                  source_data[, c("respondent_id", "region")],
                  by = "respondent_id")
  joined <- joined[!is.na(joined$segment_name) &
                     joined$segment_name != "Unassigned", ]

  expected <- round(prop.table(
    table(joined$region, joined$segment_name), margin = 2) * 100, 1)

  got <- res$enhanced$demographic_profiles$categorical_profiles$region
  seg_cols <- setdiff(names(got), c("Category", "Overall"))
  expect_setequal(seg_cols, colnames(expected))

  for (sn in seg_cols) {
    for (i in seq_len(nrow(got))) {
      expect_equal(got[[sn]][i],
                   unname(expected[got$Category[i], sn]),
                   tolerance = 0.1,
                   info = sprintf("%s / %s", sn, got$Category[i]))
    }
  }
})


# ------------------------------------------------------------------------------
# 6. The base. Rows the module removed before clustering are not in it.
# ------------------------------------------------------------------------------

test_that("the profile base is the clustered respondents, not the data file", {
  # Five respondents lose a clustering answer, so listwise deletion removes
  # them. Their region must not count towards any segment's percentages.
  d <- .demographics_fixture()
  dropped <- c(3, 50, 120, 200, 299)
  d$q1[dropped] <- NA
  run <- .demographics_run(data = d, html_report = "FALSE")
  res <- run$res

  expect_false(inherits(res, "turas_refusal_result"))
  prof <- res$enhanced$demographic_profiles
  expect_false(is.null(prof))

  assignments <- openxlsx::read.xlsx(
    file.path(run$out_dir, "seg_segment_assignments.xlsx"), sheet = 1,
    skipEmptyRows = FALSE)
  expect_equal(nrow(assignments), nrow(d) - length(dropped))

  # Every segment column still adds to 100 across its categories.
  reg <- prof$categorical_profiles$region
  seg_cols <- setdiff(names(reg), c("Category", "Overall"))
  for (sn in seg_cols) expect_equal(sum(reg[[sn]]), 100, tolerance = 0.2)
})


# ------------------------------------------------------------------------------
# 7. Combined mode says the section is not written there.
# ------------------------------------------------------------------------------

test_that("combined mode names demographic profiling as skipped", {
  out_dir <- file.path(tempdir(), paste0("demo_multi_", as.integer(runif(1) * 1e6)))
  cfg <- .demographics_config(output_folder = out_dir, html_report = "FALSE",
                              method = "kmeans,hclust")
  out <- capture.output(suppressMessages(
    res <- turas_segment_from_config(.demographics_write_config(cfg), verbose = FALSE)))

  expect_false(inherits(res, "turas_refusal_result"))
  joined <- paste(out, collapse = " ")
  expect_true(grepl("Report section skipped: demographic profiles", joined, fixed = TRUE))
  expect_true(grepl("single-method final run", joined, fixed = TRUE))
})


# ------------------------------------------------------------------------------
# 8. A demographic nobody answered is named, not dropped in silence.
# ------------------------------------------------------------------------------

test_that("an empty demographic is named in the section and in the tests sheet", {
  d <- .demographics_fixture()
  d$empty_var <- NA_character_
  run <- .demographics_run(data = d, html_report = "TRUE",
                           demographic_vars = "region,empty_var")
  res <- run$res

  expect_false(inherits(res, "turas_refusal_result"))
  # The chi-square row survives the failed test rather than vanishing.
  tests <- res$enhanced$demographic_profiles$chi_sq_tests
  expect_true("empty_var" %in% tests$Variable)
  expect_true(is.na(tests$Chi_Sq[tests$Variable == "empty_var"]))
  expect_equal(ncol(tests), 6L)

  html <- paste(readLines(file.path(run$out_dir, "seg_segmentation_report.html"),
                          warn = FALSE), collapse = "\n")
  expect_true(grepl("no clustered respondent answered: empty_var",
                    html, fixed = TRUE))
  # region is still shown normally.
  expect_true(grepl("seg-demo-var-title\">region<", html, fixed = TRUE))
})

test_that("a numeric demographic reaches its own sheet and block", {
  set.seed(3)
  d <- .demographics_fixture()
  d$age_years <- sample(18:75, nrow(d), TRUE)
  run <- .demographics_run(data = d, html_report = "TRUE",
                           demographic_vars = "region,age_years")
  dp <- run$res$enhanced$demographic_profiles

  expect_equal(names(dp$categorical_profiles), "region")
  expect_equal(names(dp$numeric_profiles), "age_years")

  sheets <- openxlsx::getSheetNames(
    file.path(run$out_dir, "seg_segmentation_report.xlsx"))
  expect_true("Demo_age_years" %in% sheets)

  html <- paste(readLines(file.path(run$out_dir, "seg_segmentation_report.html"),
                          warn = FALSE), collapse = "\n")
  expect_true(grepl("seg-demographics-numeric-section", html, fixed = TRUE))
  expect_true(grepl("Numeric demographics", html, fixed = TRUE))
})

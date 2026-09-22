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

  # An ABSOLUTE comparison. testthat's tolerance is relative, so
  # tolerance = 0.1 on a cell of 30 would accept anything from 27 to 33 and
  # this test would pass on percentages that are plainly wrong.
  for (sn in seg_cols) {
    for (i in seq_len(nrow(got))) {
      expect_lt(abs(got[[sn]][i] - unname(expected[got$Category[i], sn])), 0.051)
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
  # Absolute again: a relative 0.2 here would accept a column summing to 80.
  for (sn in seg_cols) expect_lt(abs(sum(reg[[sn]]) - 100), 0.25)
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
  # Seven since the reviewer's D9 fix: the frame carries a Note saying why a
  # variable was not tested, rather than an all-NA row with no reason.
  expect_equal(ncol(tests), 7L)
  expect_true(grepl("nobody answered|no clustered respondent answered",
                    tests$Note[tests$Variable == "empty_var"]))

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


# ------------------------------------------------------------------------------
# 9. Exploration mode chooses no k, so it says the section is not written there.
# ------------------------------------------------------------------------------

test_that("exploration mode names demographic profiling as skipped", {
  out_dir <- file.path(tempdir(), paste0("demo_expl_", as.integer(runif(1) * 1e6)))
  cfg <- .demographics_config(output_folder = out_dir, html_report = "FALSE")
  cfg$k_fixed <- NULL
  cfg$k_min <- "3"
  cfg$k_max <- "4"
  out <- capture.output(suppressMessages(
    res <- turas_segment_from_config(.demographics_write_config(cfg), verbose = FALSE)))

  expect_false(inherits(res, "turas_refusal_result"))
  joined <- paste(out, collapse = " ")
  expect_true(grepl("Report section skipped: demographic profiles", joined, fixed = TRUE))
  expect_true(grepl("after you fix k", joined, fixed = TRUE))
})

test_that("an all-numeric set of demographics does not name a sheet that is absent", {
  hd <- .demographics_html_data()
  hd$enhanced$demographic_profiles$categorical_profiles <- list()
  hd$enhanced$demographic_profiles$chi_sq_tests <- NULL
  hd$enhanced$demographic_profiles$numeric_profiles <- list(age_years = data.frame(
    Segment = c("Savers", "Spenders", "Overall"),
    N = c(60L, 40L, 100L), Mean = c(51.2, 33.4, 44.1),
    Median = c(50, 32, 43), SD = c(9.1, 8.2, 11.9),
    Min = c(30, 19, 19), Max = c(72, 55, 72), stringsAsFactors = FALSE))

  tables <- list(demographics = build_seg_demographics_table(hd),
                 demographics_numeric = build_seg_demographics_numeric_table(hd))
  html <- as.character(build_seg_demographics_section(tables, hd))

  expect_true(grepl("age_years", html, fixed = TRUE))
  expect_false(grepl("Demographics_Tests", html, fixed = TRUE))
  expect_true(grepl("respondents who were clustered", html, fixed = TRUE))
})


# ------------------------------------------------------------------------------
# 10. Reviewer's tests (independent review 2026-09-22).
# ------------------------------------------------------------------------------

test_that("the section does not call the clustered sample the base of its percentages", {
  # D1. Percentages are computed among the respondents who answered the
  # demographic, which is smaller than the clustered n whenever a demographic
  # has blanks. The section used to say the Overall column was "the same
  # calculation on the whole clustered sample", which is false in that case.
  hd <- .demographics_html_data()
  tables <- list(demographics = build_seg_demographics_table(hd),
                 demographics_numeric = build_seg_demographics_numeric_table(hd))
  html <- as.character(build_seg_demographics_section(tables, hd))

  expect_false(grepl("the whole clustered sample", html, fixed = TRUE))
  # Since the D1 base fix, the intro points at the per-table base rather than
  # describing the shrinkage in the abstract.
  expect_true(grepl("Each table states its own base", html, fixed = TRUE))
  expect_true(grepl("fewer respondents than the clustered n", html, fixed = TRUE))
  # The two claims the rest of the suite relies on are still made.
  expect_true(grepl("column percentages", html, fixed = TRUE))
  expect_true(grepl("respondents who were clustered", html, fixed = TRUE))
})


test_that("two demographics whose sheet names collide get a sheet each", {
  # D5. substr(paste0("Demo_", var), 1, 31) truncates, so two names sharing
  # their first 26 characters map to one sheet and the second would overwrite
  # the first without a word. The guard in export_final_report() renames it;
  # nothing noticed when the guard was reverted.
  v1 <- "household_income_bracket_detailed_a"
  v2 <- "household_income_bracket_detailed_b"
  expect_equal(substr(paste0("Demo_", v1), 1, 31),
               substr(paste0("Demo_", v2), 1, 31))

  d <- .demographics_fixture()
  d[[v1]] <- d$region
  d[[v2]] <- d$gender
  run <- .demographics_run(data = d, html_report = "FALSE",
                           demographic_vars = paste(v1, v2, sep = ","))
  expect_false(inherits(run$res, "turas_refusal_result"))

  sheets <- openxlsx::getSheetNames(
    file.path(run$out_dir, "seg_segmentation_report.xlsx"))
  demo_sheets <- grep("^Demo_household", sheets, value = TRUE)
  expect_length(demo_sheets, 2L)
  expect_equal(length(unique(demo_sheets)), 2L)

  # Both frames survive: one carries the region categories, one the gender ones.
  cats <- lapply(demo_sheets, function(s) {
    sort(openxlsx::read.xlsx(
      file.path(run$out_dir, "seg_segmentation_report.xlsx"),
      sheet = s, skipEmptyRows = FALSE)$Category)
  })
  expect_true(any(vapply(cats, function(c) identical(c, sort(unique(d$region))), logical(1))))
  expect_true(any(vapply(cats, function(c) identical(c, sort(unique(d$gender))), logical(1))))
})


# ------------------------------------------------------------------------------
# 11. D9: a demographic that cannot vary must not be reported as significant.
#
# chisq.test() on a one-row table is a goodness-of-fit test against equal
# expected counts, so it tests whether the segments are the same size rather
# than whether the demographic differs. With equal segments it returns p = 1
# and looks harmless; with real segment sizes it returns a tiny p and the
# module wrote Significant = TRUE for a variable every respondent answered
# the same way (independent review 2026-09-22).
# ------------------------------------------------------------------------------

test_that("a constant demographic is not tested, whatever the segment sizes are", {
  for (sizes in list(c(40, 40, 40), c(532, 263, 405))) {
    clusters <- rep(seq_along(sizes), times = sizes)
    d <- data.frame(only = rep("Yes", sum(sizes)), stringsAsFactors = FALSE)

    capture.output(prof <- profile_demographics(d, clusters, "only"))
    row <- prof$chi_sq_tests[prof$chi_sq_tests$Variable == "only", ]

    expect_equal(nrow(row), 1L)
    # The point of the test: never TRUE, and never a p-value at all.
    expect_false(isTRUE(row$Significant))
    expect_true(is.na(row$Significant))
    expect_true(is.na(row$Chi_Sq))
    expect_true(is.na(row$P_Value))
    expect_true(grepl("one category", row$Note, fixed = TRUE))
  }
})

test_that("the 532/263/405 case does not produce the old tiny p-value", {
  # The exact shape that made this a finding: Thornhill's own segment sizes.
  clusters <- rep(1:3, times = c(532, 263, 405))
  d <- data.frame(only = rep("Yes", 1200), stringsAsFactors = FALSE)
  capture.output(prof <- profile_demographics(d, clusters, "only"))

  p <- suppressWarnings(as.numeric(prof$chi_sq_tests$P_Value[1]))
  expect_true(is.na(p))
  # The profile frame still shows the variable, reading 100 in every column.
  frame <- prof$categorical_profiles$only
  expect_equal(nrow(frame), 1L)
  expect_true(all(as.numeric(frame[1, -1]) == 100))
})

test_that("a demographic that can vary is still tested normally", {
  clusters <- rep(1:3, times = c(532, 263, 405))
  d <- data.frame(region = c("North", "South", "East")[clusters],
                  stringsAsFactors = FALSE)
  capture.output(prof <- profile_demographics(d, clusters, "region"))
  row <- prof$chi_sq_tests[1, ]

  expect_false(is.na(row$Chi_Sq))
  expect_true(isTRUE(row$Significant))
  expect_equal(row$Note, "")
})

test_that("the tests frame carries a Note column on every branch", {
  d <- .demographics_fixture()
  d$empty_var <- NA_character_
  d$constant_var <- "Yes"
  run <- .demographics_run(data = d, html_report = "TRUE",
                           demographic_vars = "region,empty_var,constant_var")
  tests <- run$res$enhanced$demographic_profiles$chi_sq_tests

  expect_true("Note" %in% names(tests))
  expect_equal(ncol(tests), 7L)
  expect_setequal(tests$Variable, c("region", "empty_var", "constant_var"))
  expect_equal(tests$Note[tests$Variable == "region"], "")
  expect_true(nzchar(tests$Note[tests$Variable == "empty_var"]))
  expect_true(grepl("one category", tests$Note[tests$Variable == "constant_var"],
                    fixed = TRUE))
  expect_false(isTRUE(tests$Significant[tests$Variable == "constant_var"]))

  # The sheet the user opens carries the reason too.
  sheet <- openxlsx::read.xlsx(
    file.path(run$out_dir, "seg_segmentation_report.xlsx"),
    sheet = "Demographics_Tests", skipEmptyRows = FALSE)
  expect_true("Note" %in% names(sheet))
})


# ------------------------------------------------------------------------------
# 12. D1, D2, D3: the base, the unhandled class and the blank in the threshold.
# ------------------------------------------------------------------------------

test_that("D3: a blank does not push a ten-value demographic into the means table", {
  # length(unique(x)) counted NA as one of the ten, so a ten-point coded
  # demographic changed form the moment one respondent left it blank.
  clusters <- rep(1:3, length.out = 300)

  ten_clean <- data.frame(x = rep(1:10, length.out = 300))
  capture.output(a <- profile_demographics(ten_clean, clusters, "x"))
  expect_equal(names(a$categorical_profiles), "x")
  expect_length(a$numeric_profiles, 0L)

  ten_blanks <- ten_clean
  ten_blanks$x[1:5] <- NA
  capture.output(b <- profile_demographics(ten_blanks, clusters, "x"))
  expect_equal(names(b$categorical_profiles), "x")
  expect_length(b$numeric_profiles, 0L)

  # Eleven real values is still numeric, blanks or not.
  eleven <- data.frame(x = rep(1:11, length.out = 300))
  eleven$x[1:5] <- NA
  capture.output(cc <- profile_demographics(eleven, clusters, "x"))
  expect_equal(names(cc$numeric_profiles), "x")
  expect_length(cc$categorical_profiles, 0L)
})

test_that("D2: a demographic of an unhandled class is named, not dropped", {
  clusters <- rep(1:3, length.out = 300)
  d <- data.frame(region = c("N", "S", "E")[clusters], stringsAsFactors = FALSE)
  d$interview_date <- as.POSIXct("2026-01-01", tz = "UTC") +
    rep(1:50, length.out = 300) * 86400

  capture.output(prof <- profile_demographics(d, clusters, c("region", "interview_date")))

  # It reaches neither profile list, which is the old behaviour and is fine.
  expect_equal(names(prof$categorical_profiles), "region")
  expect_length(prof$numeric_profiles, 0L)
  # What is new: it is named, with a reason, instead of vanishing.
  row <- prof$chi_sq_tests[prof$chi_sq_tests$Variable == "interview_date", ]
  expect_equal(nrow(row), 1L)
  expect_true(is.na(row$Significant))
  expect_true(grepl("POSIXct", row$Note, fixed = TRUE))
})

test_that("D2: a date with few values is still cross-tabulated", {
  clusters <- rep(1:3, length.out = 300)
  d <- data.frame(wave = as.Date("2026-01-01") + rep(1:4, length.out = 300))
  capture.output(prof <- profile_demographics(d, clusters, "wave"))
  expect_equal(names(prof$categorical_profiles), "wave")
})

test_that("D1: the answered base is returned per variable and differs from the clustered n", {
  set.seed(5)
  clusters <- rep(1:3, length.out = 400)
  reg <- c("N", "S", "E")[clusters]
  reg[sample(400, 80)] <- NA
  d <- data.frame(region = reg, stringsAsFactors = FALSE)

  capture.output(prof <- profile_demographics(d, clusters, "region"))

  expect_true("bases" %in% names(prof))
  b <- prof$bases[prof$bases$Variable == "region", ]
  expect_equal(b$N_Clustered, 400L)
  expect_equal(b$N_Answered, 320L)
  expect_equal(b$N_Blank, 80L)
})

test_that("D1: each table in the report carries its own answered base", {
  d <- .demographics_fixture()
  d$region[1:60] <- NA
  run <- .demographics_run(data = d, html_report = "TRUE")
  html <- paste(readLines(file.path(run$out_dir, "seg_segmentation_report.html"),
                          warn = FALSE), collapse = "\n")

  prof <- run$res$enhanced$demographic_profiles
  n_reg <- prof$bases$N_Answered[prof$bases$Variable == "region"]
  n_gen <- prof$bases$N_Answered[prof$bases$Variable == "gender"]
  expect_lt(n_reg, n_gen)

  # The smaller base is stated on the face of the table it belongs to.
  expect_true(grepl(sprintf("Base: %d answered", n_reg), html, fixed = TRUE))
  expect_true(grepl(sprintf("Base: %d answered", n_gen), html, fixed = TRUE))

  # And the workbook carries the bases too.
  sheets <- openxlsx::getSheetNames(
    file.path(run$out_dir, "seg_segmentation_report.xlsx"))
  expect_true("Demographics_Bases" %in% sheets)
  bs <- openxlsx::read.xlsx(
    file.path(run$out_dir, "seg_segmentation_report.xlsx"),
    sheet = "Demographics_Bases", skipEmptyRows = FALSE)
  expect_setequal(bs$Variable, c("region", "gender"))
  expect_equal(bs$N_Answered[bs$Variable == "region"], n_reg)
})

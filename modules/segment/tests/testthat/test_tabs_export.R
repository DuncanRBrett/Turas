# Session C: the segment to tabs banner bridge.
#
# export_segment_assignments()'s own docstring has called its output "the join
# table that feeds the segment-as-banner workflow in tabs" since it was
# written, and nothing implemented that workflow. Duncan merged the column
# into his survey file by hand and declared the banner by hand. Review section
# 7(a): zero consumers outside the module.
#
# The join is the whole risk. A silent partial match produces a banner whose
# "Unassigned" column is really "people the join lost", and nothing downstream
# can tell the difference.

.tabs_export_fixture <- function(n = 60, ids = NULL, segments = NULL) {
  set.seed(9)
  if (is.null(ids)) ids <- sprintf("R%03d", seq_len(n))
  survey <- data.frame(
    respondent_id = ids,
    q1 = sample(1:5, n, TRUE),
    q2 = sample(c("Yes", "No"), n, TRUE),
    stringsAsFactors = FALSE
  )
  if (is.null(segments)) {
    segments <- data.frame(
      respondent_id = ids,
      segment_id = rep_len(1:3, n),
      segment_name = rep_len(c("Price-led", "Convenience-led", "Quality-led"), n),
      stringsAsFactors = FALSE
    )
  }
  survey_path <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(survey, survey_path, sheetName = "Data")
  list(survey = survey, assignments = segments, survey_path = survey_path)
}

test_that("the joined file carries every survey row and the segment column", {
  fx <- .tabs_export_fixture()
  out <- tempfile(fileext = ".xlsx")

  capture.output(res <- segment_export_for_tabs(
    assignments = fx$assignments, survey_file = fx$survey_path,
    survey_sheet = "Data", id_variable = "respondent_id", output_file = out))

  expect_equal(res$status, "PASS")
  joined <- openxlsx::read.xlsx(out, sheet = 1, skipEmptyRows = FALSE)
  expect_equal(nrow(joined), nrow(fx$survey))
  expect_true("segment_name" %in% names(joined))
  expect_equal(sort(unique(joined$segment_name)),
               sort(unique(fx$assignments$segment_name)))
})

test_that("the join keeps the survey's own row order", {
  # tabs matches rows by position in several places, so a reordered file is a
  # silently different study.
  fx <- .tabs_export_fixture()
  out <- tempfile(fileext = ".xlsx")

  capture.output(segment_export_for_tabs(
    fx$assignments, fx$survey_path, "Data", "respondent_id", out))

  joined <- openxlsx::read.xlsx(out, sheet = 1, skipEmptyRows = FALSE)
  expect_equal(joined$respondent_id, fx$survey$respondent_id)
})

test_that("a partial join is refused unless it was allowed explicitly", {
  fx <- .tabs_export_fixture()
  short <- fx$assignments[1:40, ]
  out <- tempfile(fileext = ".xlsx")

  err <- tryCatch(
    capture.output(segment_export_for_tabs(short, fx$survey_path, "Data",
                                           "respondent_id", out)),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_true(grepl("20", conditionMessage(err)))          # the unmatched count
  expect_true(grepl("allow_partial_join", conditionMessage(err), fixed = TRUE))
})

test_that("an allowed partial join marks the gap Unassigned and says how many", {
  fx <- .tabs_export_fixture()
  short <- fx$assignments[1:40, ]
  out <- tempfile(fileext = ".xlsx")

  txt <- capture.output(res <- segment_export_for_tabs(
    short, fx$survey_path, "Data", "respondent_id", out,
    allow_partial_join = TRUE))

  expect_equal(res$status, "PARTIAL")
  expect_equal(res$n_unmatched, 20)
  joined <- openxlsx::read.xlsx(out, sheet = 1, skipEmptyRows = FALSE)
  expect_equal(sum(joined$segment_name == "Unassigned"), 20)
  expect_true(any(grepl("20", txt)))
})

test_that("duplicate IDs are refused on either side", {
  fx <- .tabs_export_fixture()
  out <- tempfile(fileext = ".xlsx")

  dup_assign <- rbind(fx$assignments, fx$assignments[1, ])
  err1 <- tryCatch(
    capture.output(segment_export_for_tabs(dup_assign, fx$survey_path, "Data",
                                           "respondent_id", out)),
    turas_refusal = function(e) e)
  expect_s3_class(err1, "turas_refusal")
  expect_true(grepl("duplicate", conditionMessage(err1), ignore.case = TRUE))

  dup_survey <- rbind(fx$survey, fx$survey[1, ])
  sp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(dup_survey, sp, sheetName = "Data")
  err2 <- tryCatch(
    capture.output(segment_export_for_tabs(fx$assignments, sp, "Data",
                                           "respondent_id", out)),
    turas_refusal = function(e) e)
  expect_s3_class(err2, "turas_refusal")
  expect_true(grepl("duplicate", conditionMessage(err2), ignore.case = TRUE))
})

test_that("a missing ID column is refused, naming which file lacks it", {
  fx <- .tabs_export_fixture()
  out <- tempfile(fileext = ".xlsx")

  err <- tryCatch(
    capture.output(segment_export_for_tabs(fx$assignments, fx$survey_path,
                                           "Data", "no_such_id", out)),
    turas_refusal = function(e) e)

  expect_s3_class(err, "turas_refusal")
  expect_true(grepl("no_such_id", conditionMessage(err), fixed = TRUE))
})

test_that("GMM membership probabilities never reach the survey file (C-3)", {
  # D5: they are model estimates. In the survey file they would be one join
  # away from being used as weights.
  fx <- .tabs_export_fixture()
  a <- fx$assignments
  a$prob_1 <- runif(nrow(a)); a$max_probability <- a$prob_1
  a$uncertainty <- 1 - a$prob_1
  a$outlier_flag <- FALSE
  out <- tempfile(fileext = ".xlsx")

  capture.output(segment_export_for_tabs(a, fx$survey_path, "Data",
                                         "respondent_id", out))

  joined <- openxlsx::read.xlsx(out, sheet = 1, skipEmptyRows = FALSE)
  expect_false(any(grepl("^prob_|max_probability|uncertainty", names(joined))))
  expect_true("segment_name" %in% names(joined))
})

test_that("an outlier with no segment becomes Unassigned, not NA", {
  fx <- .tabs_export_fixture()
  a <- fx$assignments
  a$segment_name[1:5] <- NA_character_
  out <- tempfile(fileext = ".xlsx")

  capture.output(segment_export_for_tabs(a, fx$survey_path, "Data",
                                         "respondent_id", out))

  joined <- openxlsx::read.xlsx(out, sheet = 1, skipEmptyRows = FALSE)
  expect_equal(sum(joined$segment_name == "Unassigned"), 5)
  expect_false(any(is.na(joined$segment_name)))
})


# ------------------------------------------------------------------------------
# C-2: the banner stub. Its job is that the reader does not have to know what
# tabs expects. Shapes checked against examples/tabs/basic/Survey_Structure.xlsx
# and its tabs_config.xlsx Selection sheet.
# ------------------------------------------------------------------------------

test_that("the stub declares the column as a single-response question", {
  out <- tempfile(fileext = ".xlsx")
  capture.output(res <- segment_write_banner_stub(
    segments = c("Price-led", "Convenience-led", "Quality-led"),
    column_name = "segment_name", output_file = out))

  q <- openxlsx::read.xlsx(out, sheet = "Questions", skipEmptyRows = FALSE)
  expect_equal(nrow(q), 1)
  expect_equal(q$QuestionCode[1], "segment_name")
  expect_equal(q$Variable_Type[1], "Single_Response")
  expect_equal(as.integer(q$Columns[1]), 1L)
})

test_that("every segment gets an option row whose text matches the data exactly", {
  segs <- c("Price-led", "Convenience-led", "Quality-led", "Unassigned")
  out <- tempfile(fileext = ".xlsx")
  capture.output(segment_write_banner_stub(segs, "segment_name", out))

  o <- openxlsx::read.xlsx(out, sheet = "Options", skipEmptyRows = FALSE)
  expect_equal(nrow(o), length(segs))
  # OptionText must be the EXACT value in the data, case and all: tabs matches
  # on it literally.
  expect_equal(sort(o$OptionText), sort(segs))
  expect_true(all(o$ShowInOutput == "Y"))
  expect_true(all(o$QuestionCode == "segment_name"))
})

test_that("the Selection row turns the column into a banner", {
  out <- tempfile(fileext = ".xlsx")
  capture.output(segment_write_banner_stub(c("A", "B"), "segment_name", out))

  s <- openxlsx::read.xlsx(out, sheet = "Selection", skipEmptyRows = FALSE)
  expect_equal(nrow(s), 1)
  expect_equal(s$UseBanner[1], "Y")
  expect_equal(s$QuestionCode[1], "segment_name")
  expect_true(nzchar(s$BannerLabel[1]))
})

test_that("the banner DisplayOrder stays a single digit", {
  # It sorts as TEXT in modules/tabs/lib/banner.R, so a two-digit value would
  # order 10 before 2.
  out <- tempfile(fileext = ".xlsx")
  capture.output(segment_write_banner_stub(c("A", "B"), "segment_name", out,
                                           display_order = 3))

  s <- openxlsx::read.xlsx(out, sheet = "Selection", skipEmptyRows = FALSE)
  expect_true(nchar(as.character(s$DisplayOrder[1])) == 1)

  err <- tryCatch(
    capture.output(segment_write_banner_stub(c("A", "B"), "segment_name", out,
                                             display_order = 12)),
    turas_refusal = function(e) e)
  expect_s3_class(err, "turas_refusal")
})

test_that("the stub carries the provenance a reader needs (D5)", {
  out <- tempfile(fileext = ".xlsx")
  capture.output(segment_write_banner_stub(c("A", "B"), "segment_name", out))

  q <- openxlsx::read.xlsx(out, sheet = "Questions", skipEmptyRows = FALSE)
  note <- paste(q$Notes, collapse = " ")

  expect_true(grepl("model-derived", note, ignore.case = TRUE))
  expect_true(grepl("unweighted", note, ignore.case = TRUE))
  expect_true(grepl("in-sample", note, ignore.case = TRUE))
})

test_that("no string in the stub carries an em dash", {
  # House rule: no em dashes in anything that reaches Duncan or a client.
  out <- tempfile(fileext = ".xlsx")
  capture.output(segment_write_banner_stub(c("A", "B"), "segment_name", out))

  for (sh in openxlsx::getSheetNames(out)) {
    d <- openxlsx::read.xlsx(out, sheet = sh, skipEmptyRows = FALSE)
    txt <- paste(unlist(lapply(d, as.character)), collapse = " ")
    expect_false(grepl("—", txt), info = sh)
  }
})

test_that("the stub explains where each sheet's rows go", {
  out <- tempfile(fileext = ".xlsx")
  capture.output(segment_write_banner_stub(c("A", "B"), "segment_name", out))

  expect_true("How_to_use" %in% openxlsx::getSheetNames(out))
  r <- openxlsx::read.xlsx(out, sheet = "How_to_use", skipEmptyRows = FALSE)
  txt <- paste(unlist(lapply(r, as.character)), collapse = " ")
  expect_true(grepl("Survey_Structure", txt, fixed = TRUE))
  expect_true(grepl("Selection", txt, fixed = TRUE))
})


# ------------------------------------------------------------------------------
# The wiring: the export is a config setting, off by default, and it has to be
# a REAL setting rather than another knob validation drops (H3).
# ------------------------------------------------------------------------------

.tabs_export_config <- function(n = 300, ...) {
  # 300, not 60: the sample-size guard refuses a study too small for k_max,
  # and a fixture that cannot complete a run proves nothing about the export.
  d <- data.frame(respondent_id = sprintf("R%03d", seq_len(n)),
                  q1 = rnorm(n), q2 = rnorm(n), q3 = rnorm(n),
                  stringsAsFactors = FALSE)
  path <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(d, path, sheetName = "Data")
  utils::modifyList(
    list(data_file = path, data_sheet = "Data", id_variable = "respondent_id",
         clustering_vars = "q1,q2,q3", k_fixed = "3", method = "kmeans"),
    list(...)
  )
}

test_that("tabs_export and allow_partial_join survive validation", {
  capture.output(cfg <- validate_segment_config(
    .tabs_export_config(tabs_export = "Y", allow_partial_join = "Y")))

  expect_equal(toupper(as.character(cfg$tabs_export)), "Y")
  expect_true(isTRUE(cfg$allow_partial_join))
})

test_that("the export is off unless asked for", {
  capture.output(cfg <- validate_segment_config(.tabs_export_config()))

  expect_equal(toupper(as.character(cfg$tabs_export %||% "N")), "N")
  expect_false(isTRUE(cfg$allow_partial_join))
})

test_that("neither new setting trips the unused-settings warning", {
  out <- capture.output(validate_segment_config(
    .tabs_export_config(tabs_export = "Y", allow_partial_join = "N")))

  joined <- paste(out, collapse = " ")
  expect_false(grepl("did not survive validation", joined))
  expect_false(grepl("unused config settings", joined))
})

test_that("the template offers both settings", {
  tpl <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tpl), add = TRUE)
  capture.output(generate_segment_config_template(output_path = tpl))

  settings <- tolower(as.character(
    openxlsx::read.xlsx(tpl, sheet = "Config", skipEmptyRows = FALSE)[[1]]))
  expect_true("tabs_export" %in% settings)
  expect_true("allow_partial_join" %in% settings)
})

test_that("a full run with tabs_export writes both files and nothing else new", {
  cfg <- .tabs_export_config(tabs_export = "Y")
  out_dir <- file.path(tempdir(), paste0("tabsexp_", as.integer(runif(1) * 1e6)))
  cfg$output_folder <- out_dir
  cfg$create_dated_folder <- "FALSE"
  cfg$html_report <- "FALSE"
  cfg$generate_stats_pack <- "N"
  cfg$output_prefix <- "seg_"

  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Config")
  openxlsx::writeData(wb, "Config", data.frame(
    Setting = names(cfg), Value = unlist(lapply(cfg, as.character)),
    stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  capture.output(res <- turas_segment_from_config(path, verbose = FALSE))

  files <- list.files(out_dir)
  expect_true("seg_tabs_data.xlsx" %in% files)
  expect_true("seg_tabs_banner_stub.xlsx" %in% files)

  joined <- openxlsx::read.xlsx(file.path(out_dir, "seg_tabs_data.xlsx"),
                               sheet = 1, skipEmptyRows = FALSE)
  expect_equal(nrow(joined), 300)
  expect_true("segment_name" %in% names(joined))
  expect_false(any(is.na(joined$segment_name)))
})

test_that("a run without the setting writes no export", {
  cfg <- .tabs_export_config()
  out_dir <- file.path(tempdir(), paste0("tabsexp_off_", as.integer(runif(1) * 1e6)))
  cfg$output_folder <- out_dir
  cfg$create_dated_folder <- "FALSE"
  cfg$html_report <- "FALSE"
  cfg$generate_stats_pack <- "N"

  path <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Config")
  openxlsx::writeData(wb, "Config", data.frame(
    Setting = names(cfg), Value = unlist(lapply(cfg, as.character)),
    stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  capture.output(turas_segment_from_config(path, verbose = FALSE))

  files <- list.files(out_dir)
  expect_false(any(grepl("tabs_data|banner_stub", files)))
})


# ------------------------------------------------------------------------------
# Against tabs itself. The stub's whole claim is that tabs will accept these
# rows, so this feeds them to tabs' REAL banner builder rather than asserting
# their shape and hoping.
# ------------------------------------------------------------------------------

test_that("tabs' own banner builder accepts the stub's rows", {
  banner_file <- file.path(Sys.getenv("TURAS_ROOT"), "modules", "tabs", "lib", "banner.R")
  skip_if_not(file.exists(banner_file), "tabs not present")

  segs <- c("Price-led", "Convenience-led", "Quality-led")
  stub <- tempfile(fileext = ".xlsx")
  capture.output(segment_write_banner_stub(segs, "segment_name", stub))

  questions <- openxlsx::read.xlsx(stub, sheet = "Questions", skipEmptyRows = FALSE)
  options_df <- openxlsx::read.xlsx(stub, sheet = "Options", skipEmptyRows = FALSE)
  selection <- openxlsx::read.xlsx(stub, sheet = "Selection", skipEmptyRows = FALSE)

  # Load tabs' banner module into its own environment so nothing here leaks
  # into the segment namespace.
  tabs_env <- new.env(parent = globalenv())
  tabs_env$tabs_refuse <- function(code, title, problem, ...) {
    stop(structure(class = c("turas_refusal", "error", "condition"),
                   list(message = paste(code, problem), call = NULL)))
  }
  sys.source(banner_file, envir = tabs_env)

  banner <- tabs_env$create_banner_structure(
    selection_df = selection,
    survey_structure = list(questions = questions, options = options_df)
  )

  # Total plus one column per segment, in the order the stub declared.
  expect_true("Total" %in% banner$columns)
  for (s in segs) expect_true(s %in% banner$columns, info = s)
  expect_equal(length(banner$columns), length(segs) + 1)
})

test_that("tabs gives a Total-only banner when the stub is not switched on", {
  banner_file <- file.path(Sys.getenv("TURAS_ROOT"), "modules", "tabs", "lib", "banner.R")
  skip_if_not(file.exists(banner_file), "tabs not present")

  stub <- tempfile(fileext = ".xlsx")
  capture.output(segment_write_banner_stub(c("A", "B"), "segment_name", stub))
  selection <- openxlsx::read.xlsx(stub, sheet = "Selection", skipEmptyRows = FALSE)
  selection$UseBanner <- "N"

  tabs_env <- new.env(parent = globalenv())
  tabs_env$tabs_refuse <- function(code, title, problem, ...) stop(problem)
  sys.source(banner_file, envir = tabs_env)

  banner <- tabs_env$create_banner_structure(
    selection_df = selection,
    survey_structure = list(
      questions = openxlsx::read.xlsx(stub, sheet = "Questions", skipEmptyRows = FALSE),
      options = openxlsx::read.xlsx(stub, sheet = "Options", skipEmptyRows = FALSE))
  )

  expect_equal(banner$columns, "Total")
})

# ==============================================================================
# TABS. THE ADVERSARY TEST
# ==============================================================================
# Given ONLY the delivered HTML, can a respondent-by-question dataset be
# rebuilt from it?
#
# On a records build the answer is yes, and has always been: `data-micro`
# carries one array position per respondent, and those indices join to the
# `data-agg` labels. That is what the delivery manifest says out loud and what
# the aggregate cube exists to replace.
#
# This file builds the SAME report twice from the parity fixture, once carrying
# records and once carrying a cube, and runs the same four checks over both.
# The cube build must pass all four. The records build must FAIL the ones that
# are about respondent records, because a test that passes on both is a test
# that is green by construction and proves nothing.
#
# Everything happens in memory: no file is written, nothing under examples/ or
# OneDrive is touched, and the gate runs anywhere the suite runs.
# ==============================================================================

turas_root <- local({
  path <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "tabs"))) return(normalizePath(path))
    path <- dirname(path)
  }
  stop("Cannot detect the Turas project root")
})

FIXTURE_DIR <- file.path(turas_root, "modules/tabs/tests/fixtures/parity_project")
ASSETS_DIR <- file.path(turas_root, "modules/tabs/lib/html_report_v2/assets")

source(file.path(turas_root, "modules/shared/lib/turas_release_audit.R"))
source(file.path(turas_root, "modules/tabs/lib/cube_writer.R"))
if (!exists("build_report_v2_html", mode = "function")) {
  source(file.path(turas_root, "modules/tabs/lib/html_report_v2/report_text.R"))
  source(file.path(turas_root, "modules/tabs/lib/html_report_v2/build_report_v2.R"))
}

ADVERSARY_K <- 5


#' The committed parity islands, and a report built from them
#'
#' The fixture's published layer, respondent island and cube are all written by
#' one pipeline run (regenerate_parity_island.R), so the two reports below differ
#' in exactly one thing: which computed source they carry.
adversary_reports <- function() {
  read_json_file <- function(name) {
    paste(readLines(file.path(FIXTURE_DIR, name), warn = FALSE), collapse = "\n")
  }
  agg_json <- read_json_file("parity_island.json")
  micro_json <- read_json_file("parity_micro.json")
  cube_json <- read_json_file("parity_cube.json")
  cfg <- list(project_title = "Adversary fixture", client_name = "Test",
              wave = "W1", brand_colour = "#323367", accent_colour = "#CC9900",
              alpha = 0.05, significance_min_base = 30,
              min_reporting_base = ADVERSARY_K,
              sampling_method = "Not_Specified", apply_weighting = FALSE)
  list(
    n = jsonlite::fromJSON(micro_json, simplifyVector = FALSE)$n,
    k = jsonlite::fromJSON(cube_json, simplifyVector = FALSE)$k,
    records = build_report_v2_html(agg_json, cfg, ASSETS_DIR,
                                   generated = "2026-09-04 00:00 SAST",
                                   micro_json = micro_json),
    cube = build_report_v2_html(agg_json, cfg, ASSETS_DIR,
                                generated = "2026-09-04 00:00 SAST",
                                micro_json = "null", cube_json = cube_json)
  )
}

#' Every JSON array length that appears anywhere inside one island
adversary_array_lengths <- function(body) {
  if (is.na(body) || !nzchar(body) || identical(body, "null")) return(integer(0))
  parsed <- jsonlite::fromJSON(body, simplifyVector = FALSE)
  out <- integer(0)
  walk <- function(node) {
    if (!is.list(node)) return(invisible(NULL))
    if (is.null(names(node))) out <<- c(out, length(node))
    for (child in node) walk(child)
    invisible(NULL)
  }
  walk(parsed)
  out
}

#' Every cell base the cube ships: the audience count and each question's
#' answered base, in one vector.
adversary_cell_bases <- function(body) {
  cube <- jsonlite::fromJSON(body, simplifyVector = FALSE)
  out <- numeric(0)
  for (slice in cube$slices) {
    if (is.null(slice)) next
    for (rec in (slice$cells %||% list())) {
      if (!is.null(rec$a)) out <- c(out, as.numeric(rec$a[[1]]))
    }
    for (block in (slice$q %||% list())) {
      if (is.null(block)) next
      for (rec in block) {
        if (!is.null(rec$b)) out <- c(out, as.numeric(rec$b[[1]]))
      }
    }
  }
  out
}

reports <- adversary_reports()


# --- 1. no respondent island --------------------------------------------------

test_that("the cube build carries no respondent island, and the records build does", {
  expect_equal(release_island_body(reports$cube, "data-micro"), "null")

  # The same check on the records build must FAIL, or check 1 proves nothing.
  records_body <- release_island_body(reports$records, "data-micro")
  expect_false(identical(records_body, "null"))
  expect_equal(jsonlite::fromJSON(records_body, simplifyVector = FALSE)$n, reports$n)
})


# --- 2. nothing in the file is one value per respondent ----------------------

test_that("no array anywhere in the cube is as long as the study", {
  cube_body <- release_island_body(reports$cube, "data-cube")
  lengths_in_cube <- adversary_array_lengths(cube_body)
  expect_gt(length(lengths_in_cube), 0)          # there ARE arrays to check
  expect_false(any(lengths_in_cube >= reports$n))

  # Inside `slices`, where every number is a cell statistic, the widest record
  # is the five-number score accumulator. The wider arrays in the island are the
  # per-question histogram (one weighted count per SCALE POINT, over the whole
  # sample) and the list of distinct score values, both bounded by the scale
  # rather than by the number of people.
  slices_only <- jsonlite::fromJSON(cube_body, simplifyVector = FALSE)$slices
  slice_lengths <- integer(0)
  walk <- function(node) {
    if (!is.list(node)) return(invisible(NULL))
    if (is.null(names(node))) slice_lengths <<- c(slice_lengths, length(node))
    for (child in node) walk(child)
    invisible(NULL)
  }
  walk(slices_only)
  expect_lte(max(slice_lengths), 5)

  # The records build carries several arrays of exactly n, which is the whole
  # difference between the two files.
  lengths_in_micro <- adversary_array_lengths(release_island_body(reports$records, "data-micro"))
  expect_true(any(lengths_in_micro == reports$n))
})

test_that("the respondent channels are absent from the cube build's ISLANDS", {
  # Scanned in the islands, not the whole page: the renderer's own source
  # legitimately contains the string "answers" wherever it reads TR.MICRO, and
  # matching that would make this test cry wolf on a correct file.
  cube_islands <- paste(
    vapply(c("data-micro", "data-cube", "data-agg"),
           function(id) { b <- release_island_body(reports$cube, id); if (is.na(b)) "" else b },
           character(1)), collapse = "\n")
  records_islands <- paste(
    vapply(c("data-micro", "data-cube", "data-agg"),
           function(id) { b <- release_island_body(reports$records, id); if (is.na(b)) "" else b },
           character(1)), collapse = "\n")
  # The KEY form, with its colon: the cube legitimately carries the token
  # "answers" inside a question's `has` list, which says the question carries
  # raw category answers, not that any are in the file.
  for (marker in c("\"banner_vars\":", "\"weights\":", "\"answers\":")) {
    expect_false(grepl(marker, cube_islands, fixed = TRUE), info = marker)
    expect_true(grepl(marker, records_islands, fixed = TRUE), info = marker)
  }
})


# --- 3. every cell base is 0 or at least k ------------------------------------

test_that("no cell base sits between 1 and k minus 1", {
  bases <- adversary_cell_bases(release_island_body(reports$cube, "data-cube"))
  expect_gt(length(bases), 0)
  expect_equal(sum(bases > 0 & bases < reports$k), 0)
  expect_equal(reports$k, ADVERSARY_K)
})


# --- 4. the label join has nothing to join ------------------------------------

test_that("the first-look reconstruction has no index array to join to a label", {
  # The demonstrated attack: take each respondent's position in
  # data-micro.answers[q], look the index up in data-agg's row labels for q, and
  # a respondent-by-question dataset falls out. It needs a per-respondent index
  # array. Here there is not one to take.
  cube <- jsonlite::fromJSON(release_island_body(reports$cube, "data-cube"),
                             simplifyVector = FALSE)
  agg <- jsonlite::fromJSON(release_island_body(reports$cube, "data-agg"),
                            simplifyVector = FALSE)
  codes <- vapply(agg$questions, function(q) as.character(q$code), character(1))
  expect_gt(length(codes), 0)
  for (code in codes) {
    # Whatever the cube says about a question is filter-independent FACTS
    # (which channels it carries, its score range, its histogram), never a
    # position per respondent.
    facts <- cube$questions[[code]]
    if (is.null(facts)) next
    for (key in names(facts)) {
      v <- facts[[key]]
      if (is.list(v) && is.null(names(v))) {
        expect_true(length(v) < reports$n, info = paste(code, key))
      }
    }
  }

  # And the same join on the records build DOES produce a row per respondent.
  micro <- jsonlite::fromJSON(release_island_body(reports$records, "data-micro"),
                              simplifyVector = FALSE)
  first_code <- codes[[1]]
  expect_equal(length(micro$answers[[first_code]]), reports$n)
})


# --- the release audit reaches the same verdict -------------------------------

test_that("the release audit reads a REAL report and reaches the same verdict", {
  # These fixtures are unminified, so the audit legitimately reports engineering
  # detail still readable and the overall status is FLAGGED on both. What this
  # asserts is the disclosure verdict, which is what client-safe turns on.
  cube_audit <- turas_release_audit(reports$cube, client_safe = FALSE, refuse = FALSE)
  expect_false(cube_audit$microdata$present)
  expect_true(cube_audit$cube$present)
  expect_equal(cube_audit$cube$violations, character(0))
  expect_equal(cube_audit$cube$k, ADVERSARY_K)

  records_audit <- turas_release_audit(reports$records, client_safe = FALSE, refuse = FALSE)
  expect_equal(records_audit$status, "FLAGGED")
  expect_true(records_audit$microdata$present)
  expect_false(records_audit$cube$present)
})

test_that("a client-safe declaration refuses the records build and accepts the cube", {
  expect_false(turas_release_audit(reports$cube, client_safe = TRUE,
                                   refuse = FALSE)$client_safe_violation)
  expect_true(turas_release_audit(reports$records, client_safe = TRUE,
                                  refuse = FALSE)$client_safe_violation)
  expect_error(
    turas_release_audit(reports$records, client_safe = TRUE, refuse = TRUE),
    regexp = "respondent|CLIENT_SAFE")
})

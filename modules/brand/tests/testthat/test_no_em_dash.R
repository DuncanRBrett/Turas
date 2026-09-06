# ==============================================================================
# House rule gate: no em dash in the brand engine or its report layer
# ==============================================================================
# An em dash is the punctuation mark readers most associate with AI-written
# prose, so it must not reach Duncan or a client. It reached both through the
# brand report's own titles, table cells and console messages, which is why the
# gate lives here rather than in a pass over each published file.
#
# The scan covers every form the dash can take in this codebase: the character
# itself, the named HTML entity, both numeric entities, and the six-character
# source escape that R and JavaScript expand into the character at runtime.
# The escape matters most, because a grep for the character alone walks straight
# past a string literal that renders as a dash in the finished report.
#
# En dashes, hyphens and minus signs are deliberately not scanned. This gate is
# about U+2014 only.
#
# Every form below is BUILT rather than typed, so that this file can name the
# thing it bans without carrying a single instance of it.
# ------------------------------------------------------------------------------
library(testthat)

# The character itself, and the literal backslash-u escape as it appears in R
# and JavaScript source. Both are assembled so they never appear in this file.
.em_dash_char <- function() intToUtf8(8212L)
.em_dash_source_escape <- function() paste0("\\", "u", "2014")

#' The perl regex the gate scans with
.em_dash_pattern <- function() {
  paste(
    c(
      .em_dash_char(),
      "&mdash;",
      "&#8212;",
      "&#x2014;",
      paste0("\\", .em_dash_source_escape())  # a literal backslash, then u2014
    ),
    collapse = "|"
  )
}

#' Every file the gate scans, as paths relative to the testthat directory
.em_dash_scanned_files <- function() {
  roots <- c(
    file.path("..", "..", "lib", "html_report"),
    file.path("..", "..", "R")
  )
  files <- character(0)
  for (root in roots) {
    if (!dir.exists(root)) next
    files <- c(files, list.files(
      root,
      pattern = "\\.(R|r|js)$",
      recursive = TRUE,
      full.names = TRUE
    ))
  }
  sort(unique(files))
}

#' Offending lines, as a character vector of "path:line: text" strings
.em_dash_offenders <- function(files = .em_dash_scanned_files()) {
  pattern <- .em_dash_pattern()
  hits <- character(0)
  for (f in files) {
    lines <- tryCatch(
      readLines(f, warn = FALSE, encoding = "UTF-8"),
      error = function(e) character(0)
    )
    if (length(lines) == 0) next
    idx <- grep(pattern, lines, perl = TRUE)
    if (length(idx) == 0) next
    hits <- c(hits, sprintf(
      "%s:%d: %s", f, idx, substr(trimws(lines[idx]), 1, 160)
    ))
  }
  hits
}


test_that("the gate can see the files it is meant to scan", {
  files <- .em_dash_scanned_files()
  expect_gt(length(files), 50)
  expect_true(any(grepl("html_report", files, fixed = TRUE)))
  expect_true(any(grepl("00_main.R", files, fixed = TRUE)))
})


test_that("the gate detects every form of the dash and spares the en dash", {
  tmp <- tempfile(fileext = ".R")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(c(
    "ok <- 'no dash here'",
    paste0("a <- '", .em_dash_char(), "'"),
    "b <- '&mdash;'",
    "c <- '&#8212;'",
    "d <- '&#x2014;'",
    paste0("e <- '", .em_dash_source_escape(), "'"),
    paste0("f <- 'en dash ", intToUtf8(8211L), " stays'"),
    "g <- 'hyphen - stays'"
  ), tmp)
  found <- .em_dash_offenders(tmp)
  expect_equal(length(found), 5L)
  expect_false(any(grepl("en dash", found, fixed = TRUE)))
  expect_false(any(grepl("hyphen", found, fixed = TRUE)))
})


test_that("no em dash reaches the reader from the brand engine or report layer", {
  offenders <- .em_dash_offenders()
  if (length(offenders) > 0) {
    cat("\n=== EM DASH GATE ===\n")
    cat(sprintf("%d line(s) carry an em dash:\n", length(offenders)))
    cat(paste0("  ", offenders, collapse = "\n"), "\n")
    cat("Replace it with a full stop, comma or colon, or with an en dash ")
    cat("where it stands in for a blank cell.\n")
    cat("====================\n\n")
  }
  expect_equal(
    offenders, character(0),
    info = "See the console listing above for the offending file and line."
  )
})

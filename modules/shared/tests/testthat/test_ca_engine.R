# ==============================================================================
# SHARED CORRESPONDENCE ANALYSIS ENGINE TESTS
# ==============================================================================
# Covers: run_correspondence_analysis (known answers, invariants, refusals),
#         build_association_matrix, apply_base_gate, render_ca_report_html.

# --- Find project root ---
.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) {
      return(dir)
    }
    dir <- dirname(dir)
  }
  getwd()
}

TURAS_ROOT <- .find_turas_root_for_test()
source(file.path(TURAS_ROOT, "modules", "shared", "lib", "ca_engine.R"))
source(file.path(TURAS_ROOT, "modules", "shared", "lib", "ca_html.R"))

fixture_matrix <- function() {
  m <- matrix(c(30, 5, 10,
                8, 25, 12,
                4, 6, 28,
                15, 15, 15), nrow = 4, byrow = TRUE)
  dimnames(m) <- list(c("ATM", "App", "Till", "Spaza"),
                      c("Safe", "Fast", "Cash"))
  return(m)
}

# --- The decomposition itself -------------------------------------------------

test_that("total inertia equals the chi-square statistic over n", {
  m <- fixture_matrix()
  result <- run_correspondence_analysis(m)
  expect_equal(result$status, "PASS")
  chi_square <- suppressWarnings(stats::chisq.test(m, correct = FALSE))$statistic
  expect_equal(result$total_inertia, unname(chi_square) / sum(m), tolerance = 1e-10)
})

test_that("the first singular value matches MASS::corresp", {
  skip_if_not_installed("MASS")
  m <- fixture_matrix()
  result <- run_correspondence_analysis(m)
  expect_equal(result$singular_values[1],
               unname(MASS::corresp(m, nf = 1)$cor), tolerance = 1e-8)
})

test_that("principal coordinates are centred at their masses", {
  result <- run_correspondence_analysis(fixture_matrix())
  for (d in seq_len(ncol(result$row_coords))) {
    expect_equal(sum(result$row_mass * result$row_coords[, d]), 0, tolerance = 1e-10)
    expect_equal(sum(result$col_mass * result$col_coords[, d]), 0, tolerance = 1e-10)
  }
})

test_that("explained proportions are descending and bounded", {
  result <- run_correspondence_analysis(fixture_matrix())
  expect_true(all(diff(result$explained) <= 1e-12))
  expect_true(sum(result$explained) <= 1 + 1e-12)
})

test_that("a 2x2 matrix yields the single available dimension", {
  m <- matrix(c(20, 5, 8, 30), nrow = 2,
              dimnames = list(c("A", "B"), c("X", "Y")))
  result <- run_correspondence_analysis(m, n_dimensions = 2)
  expect_equal(result$status, "PASS")
  expect_equal(ncol(result$row_coords), 1L)
})

test_that("all-zero rows are dropped with a PARTIAL, not an error", {
  m <- rbind(fixture_matrix(), Nothing = c(0, 0, 0))
  result <- run_correspondence_analysis(m)
  expect_equal(result$status, "PARTIAL")
  expect_true("Nothing" %in% result$dropped)
  expect_false("Nothing" %in% rownames(result$row_coords))
})

test_that("the engine refuses what it cannot decompose", {
  expect_equal(run_correspondence_analysis("not a matrix")$code, "DATA_CA_NOT_MATRIX")
  m <- fixture_matrix()
  bad <- m; bad[1, 1] <- -1
  expect_equal(run_correspondence_analysis(bad)$code, "DATA_CA_INVALID_VALUES")
  unnamed <- matrix(1:4, nrow = 2)
  expect_equal(run_correspondence_analysis(unnamed)$code, "DATA_CA_NO_DIMNAMES")
  tiny <- matrix(c(1, 2), nrow = 1, dimnames = list("A", c("X", "Y")))
  expect_equal(run_correspondence_analysis(tiny)$code, "DATA_CA_TOO_SMALL")
})

test_that("a base gate that drops every entity refuses as too-small, not unlabelled", {
  m <- fixture_matrix()
  gated <- apply_base_gate(list(matrix = m,
                                base_n = stats::setNames(rep(5, 4), rownames(m))),
                           min_base = 30)
  result <- run_correspondence_analysis(gated$matrix)
  expect_equal(result$code, "DATA_CA_TOO_SMALL")
  expect_match(result$message, "base gate")
})

# --- The matrix builder -------------------------------------------------------

builder_fixture <- function() {
  data <- data.frame(
    check.names = FALSE, stringsAsFactors = FALSE,
    AttrSafe_1 = c("Bank ATM", "Bank ATM", NA, "Bank ATM"),
    AttrSafe_2 = c("Spaza", NA, NA, NA),
    AttrFast_1 = c(NA, "Bank ATM", "Bank ATM", NA),
    # AttrFast deliberately does NOT offer Spaza - alignment is by value
    Awareness_1 = c("Bank ATM", "Bank ATM", "Bank ATM", NA),
    Awareness_2 = c("Spaza", "Spaza", NA, NA)
  )
  options <- data.frame(
    QuestionCode = c("AttrSafe_1", "AttrSafe_2", "AttrFast_1",
                     "Awareness_1", "Awareness_2"),
    OptionText = c("Bank ATM", "Spaza", "Bank ATM", "Bank ATM", "Spaza"),
    stringsAsFactors = FALSE
  )
  return(list(data = data, options = options))
}

test_that("the builder aligns member columns by option value, not position", {
  fixture <- builder_fixture()
  result <- build_association_matrix(
    fixture$data, fixture$options,
    attribute_questions = c(Safe = "AttrSafe", Fast = "AttrFast"),
    entity_values = c("Bank ATM", "Spaza")
  )
  expect_equal(result$status, "PASS")
  expect_equal(result$matrix["Bank ATM", "Safe"], 3)
  expect_equal(result$matrix["Bank ATM", "Fast"], 2)
  expect_equal(result$matrix["Spaza", "Safe"], 1)
  expect_equal(result$matrix["Spaza", "Fast"], 0)   # never offered: honest zero
  expect_equal(unname(result$base_n), c(4, 4))
})

test_that("an entity base restricts both the count and the base size", {
  fixture <- builder_fixture()
  aware <- list(
    "Bank ATM" = !is.na(fixture$data$Awareness_1),
    "Spaza" = !is.na(fixture$data$Awareness_2)
  )
  result <- build_association_matrix(
    fixture$data, fixture$options,
    attribute_questions = c(Safe = "AttrSafe"),
    entity_values = c("Bank ATM", "Spaza"),
    base_by_entity = aware, as_percent_of_base = TRUE
  )
  # respondent 4 ticked Safe for Bank ATM but is NOT aware -> excluded
  expect_equal(result$matrix["Bank ATM", "Safe"], 100 * 2 / 3)
  expect_equal(unname(result$base_n), c(3, 2))
})

test_that("the base gate drops small entities and says so", {
  fixture <- builder_fixture()
  result <- build_association_matrix(
    fixture$data, fixture$options,
    attribute_questions = c(Safe = "AttrSafe"),
    entity_values = c("Bank ATM", "Spaza"),
    base_by_entity = list("Bank ATM" = rep(TRUE, 4), "Spaza" = c(TRUE, FALSE, FALSE, FALSE))
  )
  gated <- apply_base_gate(result, min_base = 2)
  expect_equal(rownames(gated$matrix), "Bank ATM")
  expect_match(gated$excluded, "Spaza \\(base 1 < 2\\)")
})

test_that("unnamed attribute questions are refused", {
  fixture <- builder_fixture()
  expect_equal(build_association_matrix(fixture$data, fixture$options,
                                        c("AttrSafe"), "Bank ATM")$code,
               "CFG_CA_UNNAMED_ATTRIBUTES")
})

# --- Segments -----------------------------------------------------------------

test_that("categorical and numeric segment definitions select the right rows", {
  data <- data.frame(
    IncomeBand = c("Less than R3,500", "R8,000 to R21,999", NA, "R3,500 to R7,999"),
    CategoriesPurchased = c("2", "9", "12", NA),
    stringsAsFactors = FALSE
  )
  lower <- segment_rows(data, list(question = "IncomeBand",
                                   values = c("Less than R3,500", "R3,500 to R7,999")))
  expect_equal(lower$rows, c(TRUE, FALSE, FALSE, TRUE))   # NA is in no segment

  heavy <- segment_rows(data, list(question = "CategoriesPurchased", min = 8))
  expect_equal(heavy$rows, c(FALSE, TRUE, TRUE, FALSE))

  banded <- segment_rows(data, list(question = "CategoriesPurchased", min = 3, max = 10))
  expect_equal(banded$rows, c(FALSE, TRUE, FALSE, FALSE))
})

test_that("bad segment definitions are refused with the reason", {
  data <- data.frame(IncomeBand = "x", stringsAsFactors = FALSE)
  expect_equal(segment_rows(data, list(values = "x"))$code, "CFG_CA_SEGMENT_NO_QUESTION")
  expect_equal(segment_rows(data, list(question = "Nope", values = "x"))$code,
               "DATA_CA_SEGMENT_COLUMN_ABSENT")
  expect_equal(segment_rows(data, list(question = "IncomeBand"))$code,
               "CFG_CA_SEGMENT_EMPTY")
})

test_that("stacked segment matrices share one space with labelled rows", {
  m <- fixture_matrix()
  per_segment <- list(
    "Low" = list(matrix = m, base_n = stats::setNames(rep(40, 4), rownames(m)),
                 excluded = character(0)),
    "High" = list(matrix = 2 * m, base_n = stats::setNames(rep(50, 4), rownames(m)),
                  excluded = "Spaza (base 10 < 30)")
  )
  stacked <- stack_segment_matrices(per_segment)
  expect_equal(nrow(stacked$matrix), 8)
  expect_true("ATM | Low" %in% rownames(stacked$matrix))
  expect_true("ATM | High" %in% rownames(stacked$matrix))
  expect_equal(unname(stacked$base_n["App | High"]), 50)
  expect_equal(stacked$excluded, "Spaza (base 10 < 30)")

  result <- run_correspondence_analysis(stacked$matrix)
  expect_equal(result$status, "PASS")
  expect_equal(nrow(result$row_coords), 8)
  # the two copies of a row profile land in the same place: 2*m has the same
  # profiles as m, so "ATM | Low" and "ATM | High" must coincide
  expect_equal(unname(result$row_coords["ATM | Low", ]),
               unname(result$row_coords["ATM | High", ]), tolerance = 1e-10)
})

# --- The renderer -------------------------------------------------------------

test_that("the report is a self-contained file carrying maps and numbers", {
  path <- file.path(tempdir(), "ca_report.html")
  on.exit(unlink(path), add = TRUE)
  m <- fixture_matrix()
  matrix_result <- list(matrix = m, base_n = stats::setNames(rep(50, 4), rownames(m)),
                        excluded = character(0))
  ca <- run_correspondence_analysis(m)
  rendered <- render_ca_report_html(
    maps = list(list(ca = ca, matrix_result = matrix_result,
                     title = "Test map", notes = "A note.",
                     importance = c(Safe = 1, Fast = 0.5, Cash = 0.2))),
    main_title = "CA test", subtitle = "fixture", path = path)
  expect_equal(rendered$status, "PASS")
  html <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(html, "<svg", fixed = TRUE)
  expect_match(html, "Spaza")
  expect_match(html, "The numbers behind this map")
  # self-contained: no external scripts, stylesheets or fetched assets
  # (the SVG xmlns namespace identifier is not a network reference)
  expect_false(grepl("<script src=|<link |url\\(http|@import", html))
})

test_that("a page with only refused maps is itself refused", {
  refused <- list(status = "REFUSED", message = "no data")
  result <- render_ca_report_html(
    maps = list(list(ca = refused, title = "x", matrix_result = NULL)),
    main_title = "t", subtitle = "s", path = tempfile())
  expect_equal(result$code, "DATA_CA_NOTHING_TO_RENDER")
})

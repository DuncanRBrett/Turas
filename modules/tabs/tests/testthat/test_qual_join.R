# ==============================================================================
# TABS MODULE — QUALITATIVE PHASE-2 JOIN TESTS (comments -> host survey by ResponseID)
# ==============================================================================
#
# Drives the Phase-2 join seam: a coded-comment workbook is resolved against a host
# survey by ResponseID so the DATA_QUAL island shares the host's anonymous MICRO row
# index (which is what lets the closed<->open jump filter comments by the cut's mask).
# Asserts the index re-keying is correct, unmatched commenters are dropped, the id
# column auto-detects (and the override wins), and an id-less survey degrades cleanly.
#
# The integrated path skips the crosstab engine, so this uses a LEAN bootstrap (the
# qual files + TRS + jsonlite + openxlsx), not the full pipeline chain.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_join.R")
# ==============================================================================

library(testthat)

local({
  detect_root <- function() {
    for (c in c(getwd(), "../..", "../../..", "../../../..")) {
      r <- tryCatch(normalizePath(c, mustWork = FALSE), error = function(e) "")
      if (nzchar(r) && dir.exists(file.path(r, "modules/tabs/lib"))) return(r)
    }
    stop("Cannot locate Turas root for qual_join test")
  }
  repo <- detect_root()
  lib <- file.path(repo, "modules/tabs/lib")
  suppressWarnings(suppressMessages({ library(jsonlite); library(openxlsx) }))
  source(file.path(repo, "modules/shared/lib/trs_refusal.R"), local = FALSE)
  for (f in c("qual_workbook_reader.R", "qual_workbook_io.R", "qual_assemble.R",
              "qual_island_builder.R", "qual_report.R")) {
    source(file.path(lib, f), local = FALSE)
  }
})

# ---- Synthetic fixtures -------------------------------------------------------

# A coded-comment workbook: 4 commenters (ids 101..104), one themed column "Price".
# Commenter 555 is present in the workbook but absent from the host survey (dropped).
write_join_workbook <- function(ids = c("101", "102", "103", "104", "555"),
                                path = tempfile(fileext = ".xlsx")) {
  rows <- list(c("Why did you say that?", NA, NA, NA),
               c("ID", "Comment", "Noteworthy", "Price"))
  for (i in seq_along(ids)) {
    price <- if (i %% 2 == 1) "1" else NA                 # odd-indexed mention Price
    rows[[length(rows) + 1L]] <- c(ids[[i]],
                                   sprintf("Comment from respondent %s", ids[[i]]),
                                   NA, price)
  }
  grid <- do.call(rbind, lapply(rows, function(r) { length(r) <- 4; r }))
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Overall")
  openxlsx::writeData(wb, "Overall", as.data.frame(grid), colNames = FALSE)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

# A host survey whose response-id column places the commenter ids at known rows.
# Row order (0-based): 104->0, 999->1, 102->2, 101->3, 103->4  (999 has no comment).
host_survey <- function(id_name = "Response ID") {
  df <- data.frame(x = c("a", "b", "c", "d", "e"), stringsAsFactors = FALSE)
  df[[id_name]] <- c("104", "999", "102", "101", "103")
  df
}

# ==============================================================================
# ID-COLUMN DETECTION
# ==============================================================================

test_that("the host response-id column auto-detects via the anchor and the override wins", {
  sd <- host_survey("Response ID")
  expect_equal(qual_find_host_id_column(sd), "Response ID")

  sd2 <- host_survey("respondent_uid")             # no anchor match
  expect_true(is.na(qual_find_host_id_column(sd2)))
  expect_equal(qual_find_host_id_column(sd2, "respondent_uid"), "respondent_uid")
  expect_equal(qual_find_host_id_column(sd2, "RESPONDENT_UID"), "respondent_uid")  # case-insensitive
  expect_true(is.na(qual_find_host_id_column(sd2, "NA")))   # config "NA" => unset
})

test_that("ResponseID maps to the correct 0-based host row, first occurrence wins", {
  sd <- host_survey()
  m <- qual_host_id_to_idx(sd, "Response ID")
  expect_equal(unname(m[["104"]]), 0L)
  expect_equal(unname(m[["101"]]), 3L)
  expect_equal(unname(m[["103"]]), 4L)
  expect_false("" %in% names(m))                   # blanks dropped
})

# ==============================================================================
# THE JOIN: re-keys the anonymous index to the host rows; drops unmatched commenters
# ==============================================================================

test_that("qual_resolve_against_survey re-keys to host rows and counts matches", {
  wb <- write_join_workbook(); on.exit(unlink(wb), add = TRUE)
  res <- qual_read_workbook(wb)
  joined <- qual_resolve_against_survey(res$questions, host_survey())
  expect_equal(joined$status, "PASS")
  expect_equal(joined$master$n, 5L)                # the host (idx) space, not the workbook's
  expect_equal(joined$matched, 4L)                 # 101..104 matched; 555 not in host
  expect_equal(joined$total, 5L)
  expect_equal(joined$id_column, "Response ID")
  # workbook id -> host row index
  expect_equal(unname(joined$master$id_to_idx[["101"]]), 3L)
  expect_equal(unname(joined$master$id_to_idx[["104"]]), 0L)
})

test_that("a survey with no resolvable id column reports NO_ID_COLUMN (standalone fallback)", {
  wb <- write_join_workbook(); on.exit(unlink(wb), add = TRUE)
  res <- qual_read_workbook(wb)
  sd <- host_survey("respondent_uid")              # no anchor, no override
  joined <- qual_resolve_against_survey(res$questions, sd)
  expect_equal(joined$status, "NO_ID_COLUMN")
  expect_null(joined$master)
})

# ==============================================================================
# INTEGRATED ISLAND: records carry the HOST idx; unmatched commenters absent
# ==============================================================================

test_that("build_integrated_qual_island keys records to host rows and drops unmatched", {
  wb <- write_join_workbook(); on.exit(unlink(wb), add = TRUE)
  cfg <- list(qual_confidentiality_mode = "full", qual_demographic_cuts = "allow",
              qual_noteworthy_default = "all", qual_join_id_column = "")
  out <- build_integrated_qual_island(wb, cfg, host_survey())
  expect_equal(out$status, "PASS")
  expect_equal(out$matched, 4L)
  isl <- out$island
  expect_equal(isl$n, 5L)                          # host idx space
  q <- isl$questions[[1]]
  idxs <- vapply(q$records, function(r) r$idx, integer(1))
  expect_setequal(idxs, c(0L, 2L, 3L, 4L))         # 104,102,101,103 -> their host rows
  expect_false(1L %in% idxs)                        # host row 1 (999) never commented
  expect_equal(length(q$records), 4L)              # commenter 555 dropped (not in host)
})

test_that("an id column that matches nobody reports NO_MATCHES (not a silent empty island)", {
  wb <- write_join_workbook(ids = c("A1", "A2")); on.exit(unlink(wb), add = TRUE)
  cfg <- list(qual_confidentiality_mode = "hidden", qual_join_id_column = "")
  out <- build_integrated_qual_island(wb, cfg, host_survey())   # host ids are 101.. etc.
  expect_equal(out$status, "NO_MATCHES")
  expect_null(out$json)
})

test_that("the confidentiality dial still governs the integrated island text", {
  wb <- write_join_workbook(); on.exit(unlink(wb), add = TRUE)
  hidden <- build_integrated_qual_island(
    wb, list(qual_confidentiality_mode = "hidden"), host_survey())
  expect_false(grepl("Comment from respondent 101", hidden$json, fixed = TRUE))
  full <- build_integrated_qual_island(
    wb, list(qual_confidentiality_mode = "full"), host_survey())
  expect_match(full$json, "Comment from respondent 101", fixed = TRUE)
})

# ==============================================================================
# JUMP LINKS: CommentSheet/CommentLink -> a target-keyed map for the JS affordance
# ==============================================================================

# The fixture workbook's single sheet is "Overall" -> qual_sheet_code = QUAL_OVERALL.
make_island <- function() {
  wb <- write_join_workbook(); on.exit(unlink(wb), add = TRUE)
  build_integrated_qual_island(wb, list(qual_confidentiality_mode = "full"),
                               host_survey())$island
}

selection_with <- function(sheet, link) {
  data.frame(QuestionCode = "Q17", Include = "N",
             CommentSheet = sheet, CommentLink = link, stringsAsFactors = FALSE)
}

test_that("qual_build_links keys a resolved link by its target code", {
  isl <- make_island()
  res <- qual_build_links(selection_with("Overall", "Q_Engage"), isl)
  expect_true("Q_Engage" %in% names(res$links))
  expect_equal(res$links[["Q_Engage"]]$qcode, "QUAL_OVERALL")
  expect_equal(res$links[["Q_Engage"]]$openEnd, "Q17")
  expect_equal(res$links[["Q_Engage"]]$sheet, "Overall")
  expect_length(res$unresolved, 0)
})

test_that("a CommentSheet with no CommentLink is generic, not a jump target", {
  isl <- make_island()
  res <- qual_build_links(selection_with("Overall", NA), isl)
  expect_length(res$links, 0)
  expect_true("QUAL_OVERALL" %in% res$generic)
})

test_that("a CommentSheet that matches no island question is reported unresolved", {
  isl <- make_island()
  res <- qual_build_links(selection_with("Nonexistent Sheet", "Q5"), isl)
  expect_length(res$links, 0)
  expect_true("Nonexistent Sheet" %in% res$unresolved)
})

test_that("a Selection sheet without the CommentSheet column yields no links", {
  isl <- make_island()
  sel <- data.frame(QuestionCode = "Q1", Include = "Y", stringsAsFactors = FALSE)
  res <- qual_build_links(sel, isl)
  expect_length(res$links, 0)
})

test_that("a CommentLink target that matches no rendered card is flagged (catches typos)", {
  isl <- make_island()
  sel <- selection_with("Overall", "Q_Values")              # typo: real composite is Q_Value
  # Without valid_targets the link is still built (back-compat), nothing flagged.
  expect_length(qual_build_links(sel, isl)$unlinked_targets, 0)
  # With the rendered-code universe, the mistyped target is reported.
  res <- qual_build_links(sel, isl, valid_targets = c("Q_Value", "Q25", "Q28"))
  expect_length(res$unlinked_targets, 1)
  expect_equal(res$unlinked_targets[[1]]$target, "Q_Values")
  expect_equal(res$unlinked_targets[[1]]$openEnd, "Q17")
  # A correct target passes clean.
  ok <- qual_build_links(selection_with("Overall", "Q_Value"), isl, valid_targets = c("Q_Value"))
  expect_length(ok$unlinked_targets, 0)
})

test_that("the island question carries its source sheet name", {
  isl <- make_island()
  expect_equal(isl$questions[[1]]$sheet, "Overall")
})

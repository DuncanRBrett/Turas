# ==============================================================================
# TABS MODULE. QUALITATIVE READER: openpyxl INLINE-STRING ARTEFACTS
# ==============================================================================
#
# openpyxl 3.1+ (scripts/build_comment_appendix.py) writes every string as an
# inline string. openxlsx 4.2.x reads those without unescaping XML entities and
# without handling the xml:space attribute, so "a & b" arrived as "a &amp; b" and
# " padded " as 'xml:space="preserve"> padded '. A padded " Overall Sentiment "
# header then failed the name match and the sheet lost its sentiment column.
# Verified 3 Sep 2026 on the SACS 2026 Comment Appendix.
#
# The fixture is a committed openpyxl-written workbook (see the fixture README);
# it must not be re-saved by Excel. It was produced with:
#
#   import openpyxl
#   wb = openpyxl.Workbook(); ws = wb.active; ws.title = "Probe"
#   ws.append(["ID","Noteworthy","Comment","Overall Sentiment","Systems & Resources"])
#   for row in ([1,None,"a & b",1,1],[2,None," padded ",2,None],[3,None,"line1\nline2",3,None],
#               [4,None,"plain",1,None],[5,None,"ends with space ",2,None],
#               [6,None,'<b> "quoted" it\'s',3,None]): ws.append(row)
#   ws2 = wb.create_sheet("Padded")
#   ws2.append(["ID","Noteworthy","Comment"," Overall Sentiment ","Support & Wellbeing "])
#   for row in ([1,None,"Good support",1,1],[2,"hide","n/a",2,None],
#               [3,None,"Poor wellbeing & pay",3,3],[4,None,"Fine",1,None]): ws2.append(row)
#   wb.save("modules/tabs/tests/fixtures/qual_inline_strings/inline_strings_openpyxl.xlsx")
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_inline_strings.R")
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Could not locate Turas root for sourcing the qual reader")
}

turas_root <- detect_turas_root()
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/qual_workbook_reader.R"))
source(file.path(turas_root, "modules/tabs/lib/qual_workbook_io.R"))

fixture <- file.path(turas_root, "modules/tabs/tests/fixtures/qual_inline_strings/inline_strings_openpyxl.xlsx")

get_question <- function(res, code) {
  for (q in res$questions) if (identical(q$code, code)) return(q)
  NULL
}

# ------------------------------------------------------------------------------
# Pure helper
# ------------------------------------------------------------------------------

test_that("qual_clean_inline_artefacts strips the xml:space artefact and unescapes entities", {
  expect_equal(qual_clean_inline_artefacts("a &amp; b"), "a & b")
  expect_equal(qual_clean_inline_artefacts('xml:space="preserve"> padded '), " padded ")
  expect_equal(qual_clean_inline_artefacts('xml:space="preserve">ends with space '), "ends with space ")
  expect_equal(qual_clean_inline_artefacts("&lt;b&gt; &quot;quoted&quot; it&apos;s"), "<b> \"quoted\" it's")
  expect_equal(qual_clean_inline_artefacts("&amp;lt;"), "&lt;")      # &amp; unescaped last
  expect_equal(qual_clean_inline_artefacts(c("plain", NA, "line1\nline2")), c("plain", NA, "line1\nline2"))
})

test_that("qual_norm_cells cleans before trimming, so a padded header normalises to its name", {
  expect_equal(qual_norm_cells('xml:space="preserve"> Overall Sentiment '), "Overall Sentiment")
  expect_equal(qual_norm_cells("Systems &amp; Resources "), "Systems & Resources")
})

# ------------------------------------------------------------------------------
# Through openxlsx, on the committed openpyxl-written fixture
# ------------------------------------------------------------------------------

test_that("fixture is still openpyxl-written (inline strings, no sharedStrings part)", {
  skip_if_not(file.exists(fixture), "fixture missing")
  parts <- utils::unzip(fixture, list = TRUE)$Name
  expect_false("xl/sharedStrings.xml" %in% parts)
})

test_that("qual_read_sheet_rows returns the five probe strings clean", {
  skip_if_not(file.exists(fixture), "fixture missing")
  rows <- qual_read_sheet_rows(fixture, "Probe")
  comments <- vapply(rows[2:7], function(r) r[[3]], character(1))
  expect_equal(comments, c("a & b", "padded", "line1\nline2", "plain", "ends with space", "<b> \"quoted\" it's"))
  expect_equal(rows[[1]][[5]], "Systems & Resources")
  expect_false(any(grepl("xml:space|&amp;", unlist(rows), fixed = FALSE)))
})

test_that("a padded ' Overall Sentiment ' header is still detected as the sentiment column", {
  skip_if_not(file.exists(fixture), "fixture missing")
  res <- qual_read_workbook(fixture)
  expect_equal(res$status, "PASS")

  padded <- get_question(res, "QUAL_PADDED")
  expect_false(is.null(padded))
  expect_equal(padded$type, "themed")
  expect_false(is.na(padded$roles$sentiment))
  expect_equal(vapply(padded$roles$themes, function(t) t$label, character(1)), "Support & Wellbeing")
  sentiments <- vapply(padded$records, function(r) as.integer(r$sentiment), integer(1))
  expect_equal(sentiments, c(1L, 2L, 3L, 1L))
  expect_equal(padded$records[[3]]$text, "Poor wellbeing & pay")

  probe <- get_question(res, "QUAL_PROBE")
  expect_false(is.na(probe$roles$sentiment))
  expect_equal(vapply(probe$roles$themes, function(t) t$label, character(1)), "Systems & Resources")
})

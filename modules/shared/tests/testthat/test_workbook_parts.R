# ==============================================================================
# TESTS: turas_reconcile_workbook_parts / turas_check_workbook_parts
# ==============================================================================
# Guards the defect where openxlsx writes a relationship to a drawing,
# vmlDrawing or sharedStrings part that it never puts in the archive. Excel
# treats that as a corrupt file, offers to repair it, and its repair strips
# every data-validation dropdown.
#
# The assertions here are deliberately at the ZIP level rather than against
# openxlsx internals, so they keep their meaning if openxlsx changes how it
# seeds relationships.
# ==============================================================================

local({
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  candidates <- if (nzchar(turas_root)) {
    turas_root
  } else {
    c(file.path(getwd(), "..", "..", "..", ".."), file.path(getwd(), "..", ".."), getwd())
  }
  for (root in candidates) {
    p <- file.path(root, "modules", "shared", "lib", "turas_save_workbook_atomic.R")
    if (file.exists(p)) {
      source(p)
      break
    }
  }
})


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

# A workbook exercising all three cases at once: a plain sheet (must lose its
# seeded drawing and vml relationships), a sheet with an image (must keep its
# drawing relationship) and a sheet with a comment (must keep its vml one).
make_mixed_workbook <- function(with_image = TRUE, with_comment = TRUE) {
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "plain")
  openxlsx::writeData(wb, "plain", data.frame(a = 1:3, b = c("x", "y", "z")))
  openxlsx::dataValidation(wb, "plain", col = 2, rows = 2:4, type = "list", value = '"x,y,z"')

  if (with_image) {
    openxlsx::addWorksheet(wb, "img")
    openxlsx::writeData(wb, "img", data.frame(a = 1:3))
    png_path <- tempfile(fileext = ".png")
    grDevices::png(png_path, width = 200, height = 200)
    graphics::plot(1:10)
    grDevices::dev.off()
    openxlsx::insertImage(wb, "img", png_path, width = 2, height = 2)
  }

  if (with_comment) {
    openxlsx::addWorksheet(wb, "cmt")
    openxlsx::writeData(wb, "cmt", data.frame(a = 1:3))
    openxlsx::writeComment(wb, "cmt", col = 1, row = 2,
                           comment = openxlsx::createComment("hello"))
  }

  wb
}

count_data_validations <- function(path) {
  parts <- utils::unzip(path, list = TRUE)$Name
  n <- 0L
  for (part in grep("^xl/worksheets/sheet.*\\.xml$", parts, value = TRUE)) {
    con <- unz(path, part)
    xml <- paste(readLines(con, warn = FALSE), collapse = "")
    close(con)
    n <- n + lengths(regmatches(xml, gregexpr("<dataValidation[ >]", xml)))
    n <- n + lengths(regmatches(xml, gregexpr("<x14:dataValidation[ >]", xml)))
  }
  as.integer(n)
}

sheet_xml <- function(path, part) {
  con <- unz(path, part)
  on.exit(close(con), add = TRUE)
  paste(readLines(con, warn = FALSE), collapse = "")
}


# ------------------------------------------------------------------------------
# The checker itself must be able to fail, or every test below is vacuous
# ------------------------------------------------------------------------------

test_that("turas_check_workbook_parts detects the defect in an unreconciled save", {
  wb <- make_mixed_workbook()
  path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  chk <- turas_check_workbook_parts(path)

  expect_equal(chk$status, "PARTIAL")
  expect_true(length(chk$dangling) > 0)
  expect_true(length(chk$phantom_overrides) > 0)
})

test_that("turas_check_workbook_parts refuses a missing file without stopping", {
  chk <- turas_check_workbook_parts(tempfile(fileext = ".xlsx"))

  expect_equal(chk$status, "REFUSED")
  expect_equal(chk$code, "IO_FILE_MISSING")
  expect_true(nzchar(chk$how_to_fix))
})


# ------------------------------------------------------------------------------
# The fix
# ------------------------------------------------------------------------------

test_that("a reconciled workbook has no reference to an absent part", {
  wb <- make_mixed_workbook()
  path <- tempfile(fileext = ".xlsx")

  turas_reconcile_workbook_parts(wb)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  chk <- turas_check_workbook_parts(path)

  expect_equal(chk$status, "PASS")
  expect_equal(chk$dangling, character(0))
  expect_equal(chk$phantom_overrides, character(0))
})

test_that("turas_save_workbook_atomic writes a sound workbook", {
  wb <- make_mixed_workbook()
  path <- tempfile(fileext = ".xlsx")

  result <- turas_save_workbook_atomic(wb, path, verbose = FALSE)

  expect_true(result$success)
  expect_equal(turas_check_workbook_parts(path)$status, "PASS")
})

test_that("turas_saveWorkbook writes a sound workbook", {
  wb <- make_mixed_workbook()
  path <- tempfile(fileext = ".xlsx")

  turas_saveWorkbook(wb, path, overwrite = TRUE)

  expect_equal(turas_check_workbook_parts(path)$status, "PASS")
})


# ------------------------------------------------------------------------------
# The fix must not cost anything -- this is the part Excel's own repair destroys
# ------------------------------------------------------------------------------

test_that("data validations and cell values survive reconciliation", {
  before_path <- tempfile(fileext = ".xlsx")
  after_path <- tempfile(fileext = ".xlsx")

  wb_before <- make_mixed_workbook()
  openxlsx::saveWorkbook(wb_before, before_path, overwrite = TRUE)

  wb_after <- make_mixed_workbook()
  turas_reconcile_workbook_parts(wb_after)
  openxlsx::saveWorkbook(wb_after, after_path, overwrite = TRUE)

  expect_true(count_data_validations(before_path) > 0)
  expect_equal(count_data_validations(after_path), count_data_validations(before_path))

  for (sheet in c("plain", "img", "cmt")) {
    expect_equal(
      openxlsx::read.xlsx(after_path, sheet = sheet),
      openxlsx::read.xlsx(before_path, sheet = sheet)
    )
  }
})

test_that("sheets with real drawings and comments keep their parts", {
  wb <- make_mixed_workbook()
  path <- tempfile(fileext = ".xlsx")

  turas_reconcile_workbook_parts(wb)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  parts <- utils::unzip(path, list = TRUE)$Name

  expect_true("xl/drawings/drawing2.xml" %in% parts)
  expect_true("xl/media/image1.png" %in% parts)
  expect_true("xl/drawings/vmlDrawing3.vml" %in% parts)
  expect_true("xl/comments3.xml" %in% parts)

  # The kept relationship must still carry the Id the sheet XML refers to.
  expect_true(grepl('<drawing r:id="rId1"/>',
                    sheet_xml(path, "xl/worksheets/sheet2.xml"), fixed = TRUE))
})


# ------------------------------------------------------------------------------
# Idempotence and the save -> mutate -> save path
# ------------------------------------------------------------------------------

test_that("reconciliation is idempotent", {
  wb <- make_mixed_workbook()

  turas_reconcile_workbook_parts(wb)
  rels_once <- lapply(wb$worksheets_rels, identity)
  ct_once <- wb$Content_Types

  turas_reconcile_workbook_parts(wb)

  expect_equal(lapply(wb$worksheets_rels, identity), rels_once)
  expect_equal(wb$Content_Types, ct_once)
})

test_that("a relationship is re-added when a sheet gains a drawing after a save", {
  wb <- make_mixed_workbook()
  first_path <- tempfile(fileext = ".xlsx")
  second_path <- tempfile(fileext = ".xlsx")

  turas_reconcile_workbook_parts(wb)
  openxlsx::saveWorkbook(wb, first_path, overwrite = TRUE)

  # "plain" had its seeded drawing relationship dropped by the first pass.
  png_path <- tempfile(fileext = ".png")
  grDevices::png(png_path, width = 150, height = 150)
  graphics::plot(1:5)
  grDevices::dev.off()
  openxlsx::insertImage(wb, "plain", png_path, width = 1.5, height = 1.5)

  turas_reconcile_workbook_parts(wb)
  openxlsx::saveWorkbook(wb, second_path, overwrite = TRUE)

  expect_equal(turas_check_workbook_parts(second_path)$status, "PASS")
  expect_true("xl/drawings/drawing1.xml" %in% utils::unzip(second_path, list = TRUE)$Name)

  rels <- sheet_xml(second_path, "xl/worksheets/_rels/sheet1.xml.rels")
  expect_true(grepl('Id="rId1"', rels, fixed = TRUE))
  expect_true(grepl("drawing1.xml", rels, fixed = TRUE))
})


# ------------------------------------------------------------------------------
# loadWorkbook re-seeds the relationships, so it is a reinfection path
# ------------------------------------------------------------------------------

test_that("loading a clean workbook and saving it again reintroduces the defect", {
  clean_path <- tempfile(fileext = ".xlsx")
  resaved_path <- tempfile(fileext = ".xlsx")

  wb <- make_mixed_workbook()
  turas_reconcile_workbook_parts(wb)
  openxlsx::saveWorkbook(wb, clean_path, overwrite = TRUE)
  expect_equal(turas_check_workbook_parts(clean_path)$status, "PASS")

  loaded <- openxlsx::loadWorkbook(clean_path)
  openxlsx::saveWorkbook(loaded, resaved_path, overwrite = TRUE)

  # Documents WHY every save must reconcile, not just the first one.
  expect_equal(turas_check_workbook_parts(resaved_path)$status, "PARTIAL")
})

test_that("a reconciled load-modify-save round trip stays sound", {
  clean_path <- tempfile(fileext = ".xlsx")
  resaved_path <- tempfile(fileext = ".xlsx")

  wb <- make_mixed_workbook()
  turas_reconcile_workbook_parts(wb)
  openxlsx::saveWorkbook(wb, clean_path, overwrite = TRUE)

  loaded <- openxlsx::loadWorkbook(clean_path)
  result <- turas_save_workbook_atomic(loaded, resaved_path, verbose = FALSE)

  expect_true(result$success)
  expect_equal(turas_check_workbook_parts(resaved_path)$status, "PASS")
  expect_true("xl/media/image1.png" %in% utils::unzip(resaved_path, list = TRUE)$Name)
})


# ------------------------------------------------------------------------------
# Edge cases
# ------------------------------------------------------------------------------

test_that("a workbook with no shared strings is sound", {
  # xl/sharedStrings.xml is only written when the workbook holds strings, but the
  # relationship to it is seeded unconditionally.
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "nums")
  openxlsx::writeData(wb, "nums", data.frame(a = 1:3), colNames = FALSE)
  path <- tempfile(fileext = ".xlsx")

  turas_reconcile_workbook_parts(wb)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  expect_equal(turas_check_workbook_parts(path)$status, "PASS")
  expect_equal(openxlsx::read.xlsx(path, colNames = FALSE)[[1]], c(1, 2, 3))
})

test_that("the sharedStrings relationship is re-added when strings appear later", {
  # The re-add path: an all-numeric save drops the relationship, then writeData
  # introduces strings and the next save must put it back -- with an Id that
  # cannot collide with the sheet or styles relationships already present.
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "nums")
  openxlsx::writeData(wb, "nums", data.frame(a = 1:3), colNames = FALSE)

  numeric_path <- tempfile(fileext = ".xlsx")
  turas_reconcile_workbook_parts(wb)
  openxlsx::saveWorkbook(wb, numeric_path, overwrite = TRUE)
  expect_equal(turas_check_workbook_parts(numeric_path)$status, "PASS")

  openxlsx::writeData(wb, "nums", data.frame(b = c("now", "strings")), startCol = 3)

  strings_path <- tempfile(fileext = ".xlsx")
  turas_reconcile_workbook_parts(wb)
  openxlsx::saveWorkbook(wb, strings_path, overwrite = TRUE)

  expect_equal(turas_check_workbook_parts(strings_path)$status, "PASS")
  expect_true("xl/sharedStrings.xml" %in% utils::unzip(strings_path, list = TRUE)$Name)

  # No duplicate relationship Ids in workbook.xml.rels.
  rels <- sheet_xml(strings_path, "xl/_rels/workbook.xml.rels")
  ids <- regmatches(rels, gregexpr('Id="[^"]*"', rels))[[1]]
  expect_equal(anyDuplicated(ids), 0L)

  # The strings actually survive the round trip.
  back <- openxlsx::read.xlsx(strings_path, colNames = FALSE)
  expect_true(all(c("now", "strings") %in% unlist(back, use.names = FALSE)))
})

test_that("a workbook with a single empty sheet is sound", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "empty")
  path <- tempfile(fileext = ".xlsx")

  turas_reconcile_workbook_parts(wb)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)

  expect_equal(turas_check_workbook_parts(path)$status, "PASS")
})

test_that("reconciliation refuses bad input without stopping", {
  # TRS: no stop(), and the refusal is visible on the console for Shiny.
  expect_output(turas_reconcile_workbook_parts(data.frame(a = 1)), "DATA_NOT_WORKBOOK")
  expect_silent(turas_reconcile_workbook_parts(openxlsx::createWorkbook()))
})

# ==============================================================================
# EVERY COMMITTED WORKBOOK IS READABLE BY A STRICT OPC READER
# ==============================================================================
#
# openxlsx seeds every worksheet with a relationship to a drawing part and a
# vmlDrawing part, and a [Content_Types].xml override for the drawing, whether
# or not the sheet ever gains one. saveWorkbook() writes those parts only when
# the sheet really holds a drawing or a comment, so the archive ends up with a
# relationship pointing at a part that is not there. That is a hard OPC error:
# Excel reports unreadable content and offers a repair that strips every
# data-validation dropdown, and Python readers refuse the file outright.
# openxlsx itself reads such a file happily, which is why twenty committed
# workbooks carried the fault unnoticed until 2026-09-17.
#
# turas_saveWorkbook() prevents it for anything Turas writes from now on. This
# suite stops a broken workbook being committed again, and stops a writer of a
# committed workbook going back to the bare openxlsx save.
#
# See docs/HANDOVER_openxlsx_broken_workbooks.md.
# ==============================================================================

find_repo_root <- function() {
  d <- normalizePath(getwd(), mustWork = FALSE)
  for (i in 1:10) {
    if (dir.exists(file.path(d, "modules")) && dir.exists(file.path(d, ".git")) ||
        dir.exists(file.path(d, "modules")) && file.exists(file.path(d, ".git"))) {
      return(d)
    }
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  NULL
}

repo_root <- find_repo_root()

# The shared saver is not loaded by a testthat run of this directory, so this
# file locates and sources it the way every other shared test locates its
# library.
if (!is.null(repo_root) && !exists("turas_check_workbook_parts", mode = "function")) {
  .saver <- file.path(repo_root, "modules", "shared", "lib",
                      "turas_save_workbook_atomic.R")
  if (file.exists(.saver)) source(.saver)
}

committed_workbooks <- function(root) {
  out <- suppressWarnings(system2(
    "git", c("-C", shQuote(root), "ls-files", "*.xlsx", "*.xlsm", "*.xltx"),
    stdout = TRUE, stderr = FALSE
  ))
  if (!length(out)) return(character(0))
  out[nzchar(out)]
}

test_that("no committed workbook references a part that is not in the archive", {
  skip_if(is.null(repo_root), "not inside the repository")
  skip_if(!nzchar(Sys.which("git")), "git not available")
  skip_if(!exists("turas_check_workbook_parts", mode = "function"),
          "turas_check_workbook_parts() not loaded")

  files <- committed_workbooks(repo_root)
  skip_if(length(files) == 0, "no committed workbooks found")

  broken <- list()
  for (f in files) {
    res <- turas_check_workbook_parts(file.path(repo_root, f))
    if (!identical(res$status, "PASS")) {
      broken[[f]] <- c(res$dangling, res$phantom_overrides)
    }
  }

  # Name every offender, and what it points at, so the failure is actionable
  # rather than a count. tools/repair_workbook_parts.py --write fixes them
  # without touching a single cell.
  info <- if (length(broken)) {
    paste0(
      length(broken), " of ", length(files), " committed workbooks are broken.\n",
      "Repair with: python3 tools/repair_workbook_parts.py --write <files>\n",
      paste(sprintf("  %s\n    %s", names(broken),
                    vapply(broken, function(x) paste(utils::head(x, 4), collapse = "\n    "),
                           character(1))),
            collapse = "\n")
    )
  } else ""
  expect_equal(length(broken), 0L, info = info)
})

test_that("a workbook saved through turas_saveWorkbook keeps its dropdowns and has no dangling parts", {
  skip_if(!exists("turas_saveWorkbook", mode = "function"),
          "turas_saveWorkbook() not loaded")
  skip_if(!exists("turas_check_workbook_parts", mode = "function"),
          "turas_check_workbook_parts() not loaded")

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::addWorksheet(wb, "Options")
  openxlsx::writeData(wb, "Settings",
                      data.frame(Setting = c("Mode", "Weighting"),
                                 Value = c("ANALYSIS", "YES"),
                                 stringsAsFactors = FALSE))
  openxlsx::writeData(wb, "Options",
                      data.frame(Choice = c("YES", "NO"), stringsAsFactors = FALSE))
  openxlsx::dataValidation(wb, "Settings", col = 2, rows = 2:3,
                           type = "list", value = "'Options'!$A$2:$A$3")

  path <- tempfile(fileext = ".xlsx")
  turas_saveWorkbook(wb, path, overwrite = TRUE)
  on.exit(unlink(path), add = TRUE)

  res <- turas_check_workbook_parts(path)
  expect_equal(res$status, "PASS", info = paste(c(res$dangling, res$message), collapse = " | "))

  # The dropdown is the thing an Excel repair would take away, so prove it is
  # still in the file rather than only that the file is well formed.
  sheet_xml <- paste(readLines(unz(path, "xl/worksheets/sheet1.xml"), warn = FALSE),
                     collapse = "")
  expect_match(sheet_xml, "dataValidation")
})

test_that("a bare openxlsx save still produces the fault, so this suite is testing something", {
  skip_if(!exists("turas_check_workbook_parts", mode = "function"),
          "turas_check_workbook_parts() not loaded")

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "S1")
  openxlsx::writeData(wb, "S1", data.frame(a = "x", stringsAsFactors = FALSE))
  path <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  on.exit(unlink(path), add = TRUE)

  res <- turas_check_workbook_parts(path)
  expect_false(identical(res$status, "PASS"),
               info = "openxlsx no longer seeds phantom drawing parts; if this fails on a
new openxlsx version, the reconciler may no longer be needed.")
})

test_that("the writers of committed workbooks do not call openxlsx::saveWorkbook directly", {
  skip_if(is.null(repo_root), "not inside the repository")
  skip_if(!nzchar(Sys.which("git")), "git not available")

  dirs <- c("tools", "scripts", "examples")
  dirs <- dirs[dir.exists(file.path(repo_root, dirs))]
  skip_if(length(dirs) == 0, "no generator directories")

  files <- unlist(lapply(dirs, function(d)
    list.files(file.path(repo_root, d), pattern = "[.]R$", full.names = TRUE,
               recursive = TRUE)))
  skip_if(length(files) == 0, "no R files in the generator directories")

  offenders <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    # The fallback inside the shared-saver bootstrap is the one legitimate
    # direct call: it is what runs when the helper cannot be found at all.
    keep <- grepl("(?<![\\w.])(openxlsx::)?saveWorkbook\\(", lines, perl = TRUE) &
      !grepl("turas_saveWorkbook\\(", lines) &
      !grepl("^\\s*#", lines) &
      # The one legitimate direct call is the bootstrap's own last-resort
      # fallback, which runs only when the shared helper cannot be found at
      # all. It carries an explicit marker rather than being recognised by
      # its position.
      !grepl("turas-saver-fallback", lines, fixed = TRUE)
    hits <- which(keep)
    if (length(hits)) {
      offenders <- c(offenders, sprintf("%s:%d",
                                        sub(paste0("^", repo_root, "/"), "", f), hits))
    }
  }

  expect_equal(length(offenders), 0L,
               info = paste0(
                 "These write workbooks with the bare openxlsx save, which seeds a\n",
                 "relationship to a drawing part it never writes. Route them through\n",
                 "turas_saveWorkbook() with the shared-saver bootstrap:\n  ",
                 paste(offenders, collapse = "\n  ")))
})

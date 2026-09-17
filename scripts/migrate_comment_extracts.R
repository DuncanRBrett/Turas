#!/usr/bin/env Rscript
# ==============================================================================
# MIGRATE A COMMENT APPENDIX TO PER-THEME EXTRACTS
# ==============================================================================
#
# An appendix whose verbatim cells were shortened by hand has a problem the
# extracts sheet exists to solve: the theme codes on a row were coded on the WHOLE
# comment, so a fragment kept in the verbatim cell is quoted beside every theme the
# comment carries. See modules/tabs/docs/QUALITATIVE_EXTRACTS_PLAN.md.
#
# This script proposes the migration. For every comment that ships text and is
# coded on MORE THAN ONE theme, it writes one extracts row carrying that comment's
# CURRENT text and ALL of its coded theme labels. The analyst then deletes the
# labels each fragment does not actually speak to. That is the only judgement in
# the job and it cannot be automated.
#
# The property that makes this safe: a row left untouched behaves exactly as the
# report does today, and a row deleted behaves exactly as today, so the shipped set
# of quotes is a subset of what ships now, by construction. A half-pruned workbook
# is safe to ship.
#
# It NEVER touches the workbook it reads. A new file is written, and the original
# is left alone, so undoing the migration is pointing the config back at it.
#
# WHY TWO LANGUAGES. The sheet classification (which column is the verbatim, which
# are themes) lives in the R reader and is not re-implemented here, because a
# divergence would key extracts to the wrong theme labels. The WRITE is openpyxl,
# because an openxlsx load-and-save round trip collapses each sheet's declared
# dimension (docs/HANDOVER_openxlsx_broken_workbooks.md). So R proposes, Python
# writes, and this script runs both.
#
# USAGE (from the Turas root)
#   Rscript scripts/migrate_comment_extracts.R "<appendix.xlsx>"
#   Rscript scripts/migrate_comment_extracts.R "<appendix.xlsx>" --out "<new.xlsx>"
#   Rscript scripts/migrate_comment_extracts.R "<appendix.xlsx>" --plan-only
# The Project Steps tile passes the workbook as --appendix "<path>"; both forms work.
# ==============================================================================

turas_migrate_root <- function() {
  home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(home) && dir.exists(file.path(home, "modules"))) return(normalizePath(home))
  path <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "tabs"))) return(normalizePath(path))
    path <- dirname(path)
  }
  stop("Cannot find the Turas root. Run from the Turas root or set TURAS_HOME.")
}

#' Propose the extracts rows for one classified question.
#'
#' A comment earns a row only when quoting it could go wrong: it ships text, and it
#' is coded on more than one theme. A single-theme comment cannot be quoted beside
#' a theme it does not address, and a hide-marked comment ships no text at all.
#'
#' @param question A question from `qual_read_workbook()`.
#' @return list(sheet, base, rows): each row list(id, themes, text).
migrate_propose_rows <- function(question) {
  labels <- vapply(question$roles$themes, function(t) t$label, character(1))
  rows <- list()
  for (rec in question$records) {
    if (isTRUE(rec$hidden)) next                       # hide: no text ships
    text <- trimws(as.character(rec$text))
    if (!nzchar(text) || identical(text, "-")) next    # nothing to quote
    coded <- labels[labels %in% names(rec$themeVals)]
    if (length(coded) < 2L) next                       # one theme cannot be mis-placed
    rows[[length(rows) + 1L]] <- list(
      id = rec$id, themes = paste(coded, collapse = "; "), text = text)
  }
  list(sheet = paste0(question$sheet, " Extracts"),
       base = question$sheet, rows = rows)
}

# ---- CLI ---------------------------------------------------------------------

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args)) {
    cat("Usage: Rscript scripts/migrate_comment_extracts.R <appendix.xlsx> [--out <new.xlsx>] [--plan-only]\n")
    quit(status = 2L)
  }
  # The path may be positional (a shell) or behind --appendix (the Project Steps
  # tile, whose registry emits a switch for every argument).
  in_path <- if ("--appendix" %in% args) {
    at <- which(args == "--appendix")[[1]]
    if (at + 1L > length(args)) "" else args[[at + 1L]]
  } else if (startsWith(args[[1]], "--")) "" else args[[1]]
  if (!nzchar(in_path)) {
    cat("\nNo appendix given. Pass the workbook path, or --appendix <path>.\n")
    quit(status = 2L)
  }
  out_path <- if ("--out" %in% args) args[[which(args == "--out") + 1L]] else {
    sub("\\.xlsx$", sprintf(" (with extracts %s).xlsx", format(Sys.Date(), "%Y%m%d")), in_path)
  }
  plan_only <- "--plan-only" %in% args

  root <- turas_migrate_root()
  source(file.path(root, "modules/shared/lib/trs_refusal.R"))
  source(file.path(root, "modules/tabs/lib/qual_workbook_reader.R"))
  source(file.path(root, "modules/tabs/lib/qual_workbook_io.R"))

  if (!file.exists(in_path)) {
    cat(sprintf("\nThe appendix '%s' does not exist.\n", in_path)); quit(status = 1L)
  }
  if (!plan_only && file.exists(out_path)) {
    cat(sprintf(paste0("\nRefusing: '%s' already exists. Delete it, or pass --out with ",
                       "another name. This script never overwrites.\n"), out_path))
    quit(status = 1L)
  }

  read <- qual_read_workbook(in_path, module = "TABS/migrate")
  themed <- Filter(function(q) identical(q$type, "themed"), read$questions)
  if (!length(themed)) {
    cat("\nNo themed question sheets in this workbook, so there is nothing to migrate.\n")
    quit(status = 0L)
  }
  already <- Filter(function(q) any(vapply(q$records, function(r) isTRUE(r$has_extracts),
                                           logical(1))), themed)
  if (length(already)) {
    cat(sprintf(paste0("\nRefusing: this workbook already carries extracts (%s). Migrating ",
                       "again would overwrite pruning work that has been done by hand.\n"),
                paste(vapply(already, function(q) q$sheet, character(1)), collapse = ", ")))
    quit(status = 1L)
  }

  plan <- lapply(themed, migrate_propose_rows)
  too_long <- Filter(function(p) nchar(p$sheet) > QUAL_SHEET_NAME_MAX, plan)
  if (length(too_long)) {
    cat(sprintf(paste0("\nRefusing: the sheet name '%s' would be %d characters and Excel ",
                       "caps a sheet name at %d. Shorten the question sheet's name first.\n"),
                too_long[[1]]$sheet, nchar(too_long[[1]]$sheet), QUAL_SHEET_NAME_MAX))
    quit(status = 1L)
  }

  cat("\nProposed extracts, one row per comment that ships text and carries more than one theme:\n")
  total <- 0L
  for (p in plan) {
    cat(sprintf("  %-28s %4d row(s)\n", p$sheet, length(p$rows)))
    total <- total + length(p$rows)
  }
  cat(sprintf("  %-28s %4d row(s) to prune\n", "TOTAL", total))

  if (plan_only) {
    cat("\n--plan-only: nothing written.\n")
    quit(status = 0L)
  }

  plan_json <- tempfile(fileext = ".json")
  jsonlite::write_json(plan, plan_json, auto_unbox = TRUE, pretty = FALSE)
  py <- file.path(root, "scripts/migrate_comment_extracts.py")
  status <- system2("python3", c(shQuote(py), "--workbook", shQuote(in_path),
                                 "--plan", shQuote(plan_json), "--out", shQuote(out_path)))
  unlink(plan_json)
  if (status != 0L) {
    cat("\nThe writer failed. The original workbook is untouched.\n"); quit(status = 1L)
  }
  cat(sprintf(paste0("\nWritten: %s\n",
    "Your original appendix is untouched.\n\n",
    "NEXT: open the new workbook, and on each Extracts sheet delete the theme labels\n",
    "each fragment does not actually speak to. A row you leave alone behaves exactly as\n",
    "the report does today, so you can stop half way and still ship. Then point\n",
    "qual_workbook in the Crosstab_Config at the new file and regenerate.\n"), out_path))
}

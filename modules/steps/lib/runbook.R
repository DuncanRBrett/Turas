# ==============================================================================
# TURAS > PROJECT STEPS - RUNBOOK (per-project step checklist)
# ==============================================================================
# Purpose: Read, validate and create the workbook that records how one project's
#          deliverable is produced - the ordered list of steps, what type each
#          one is, and (for tool steps) the arguments to run it with.
# Location: modules/steps/lib/runbook.R
#
# The runbook is a checklist, NOT a pipeline engine. Nothing sequences itself,
# nothing runs on its own, and there is no "run all". Human work between steps
# is the normal case, not an edge case.
#
# Workbook shape
# --------------
# Sheet `Steps` - one row per step, in the order they happen:
#
#   Order   1, 2, 3 ... the sequence. Sorted numerically when every value is a
#           number; otherwise left in sheet order.
#   Step    What happens, in plain words. This is the documentation.
#   Type    module | tool | ai-assisted | manual
#   Tool    For `tool` rows: the Steps registry id (must resolve, or the runbook
#           refuses naming the row). For `module` rows: the Turas module, for
#           the record. Blank otherwise.
#   Notes   Anything the next person needs to know.
#   arg:*   Any column headed `arg:<id>` supplies that argument to the tool.
#           e.g. `arg:data`, `arg:appendix`. Blank cells are simply not passed.
#
# Sheet `Provenance` (optional) - parameter | value, the Turas config convention.
#   Records which AI features were on for this project and where the client's
#   approval or restriction lives. Nothing enforces off it; it is the record
#   that makes the policy auditable. See docs/REPORT_GENERATION_METHOD.md.
#
# Sheet `Guide` (optional) - written by the template generator, ignored on read.
# ==============================================================================


STEPS_RUNBOOK_TYPES <- c("module", "tool", "ai-assisted", "manual")

STEPS_RUNBOOK_REQUIRED_COLUMNS <- c("Order", "Step", "Type")

STEPS_RUNBOOK_ARG_PREFIX <- "arg:"

# The Provenance keys the template ships with. A runbook may carry others; these
# are the ones the policy asks for.
STEPS_RUNBOOK_PROVENANCE_KEYS <- c(
  "ai_insights_narrative",
  "reader_ai_prose",
  "verbatim_theming",
  "client_approval_reference",
  "notes"
)


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

#' Normalise a step type as typed by a human
#'
#' Accepts "AI-assisted", "ai assisted", "ai_assisted" and so on.
#'
#' @param x Character. The Type cell.
#' @return Character. A value from STEPS_RUNBOOK_TYPES, or the input lowercased
#'   when it matches none (the caller refuses on that).
#' @keywords internal
.steps_normalise_type <- function(x) {
  v <- tolower(trimws(as.character(x)))
  v <- gsub("[ _]+", "-", v)
  v
}


#' Trim a cell to a single string, treating NA as blank
#' @keywords internal
.steps_cell <- function(x) {
  if (is.null(x) || length(x) == 0) return("")
  x <- x[1]
  if (is.na(x)) return("")
  trimws(as.character(x))
}


#' Which columns of a Steps sheet are argument columns?
#'
#' @param headers Character vector of column headers.
#' @return Named character vector: names are the argument ids, values the header.
#' @keywords internal
.steps_arg_columns <- function(headers) {
  is_arg <- startsWith(tolower(headers), STEPS_RUNBOOK_ARG_PREFIX)
  if (!any(is_arg)) return(character(0))
  cols <- headers[is_arg]
  ids <- trimws(substring(cols, nchar(STEPS_RUNBOOK_ARG_PREFIX) + 1))
  stats::setNames(cols, ids)
}


#' Match a required column header case-insensitively
#' @keywords internal
.steps_find_column <- function(headers, wanted) {
  hit <- which(tolower(trimws(headers)) == tolower(wanted))
  if (length(hit) == 0) return(NA_integer_)
  hit[1]
}


# ------------------------------------------------------------------------------
# Reading
# ------------------------------------------------------------------------------

#' Read and validate a project runbook
#'
#' @param path Character. Path to the runbook .xlsx.
#' @param manifests List of tool manifests, used to check that every `tool` row
#'   names a tool that exists. Defaults to the built-in registry.
#' @return A list with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{result}{list(path, steps, provenance) when PASS. `steps` is a list of
#'     step records, each with order/step/type/tool/notes/args/row.}
#' @export
steps_runbook_read <- function(path, manifests = steps_builtin_manifests()) {

  if (!.steps_is_string(path)) {
    return(steps_refuse(
      "CFG_RUNBOOK_INVALID",
      "No runbook path was given.",
      "Choose a runbook workbook before loading it."
    ))
  }

  if (!file.exists(path)) {
    return(steps_refuse(
      "IO_RUNBOOK_NOT_FOUND",
      sprintf("There is no runbook at %s.", path),
      c("Check the path - a moved or renamed file is the usual cause.",
        "Or create one: the Steps GUI can write a blank runbook template."),
      context = list(path = path)
    ))
  }

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    return(steps_refuse(
      "PKG_MISSING_DEPENDENCY",
      "The openxlsx package is not installed, so the runbook cannot be read.",
      "Run renv::restore() - openxlsx is already in renv.lock.",
      context = list(path = path)
    ))
  }

  sheets <- tryCatch(openxlsx::getSheetNames(path), error = function(e) e)
  if (inherits(sheets, "error")) {
    return(steps_refuse(
      "IO_RUNBOOK_UNREADABLE",
      sprintf("%s could not be opened as a workbook: %s",
              basename(path), conditionMessage(sheets)),
      c("Check the file is a real .xlsx and is not open in Excel with unsaved changes.",
        "If it was written by another tool, re-save it from Excel."),
      context = list(path = path)
    ))
  }

  if (!"Steps" %in% sheets) {
    return(steps_refuse(
      "CFG_RUNBOOK_INVALID",
      sprintf("%s has no 'Steps' sheet.", basename(path)),
      c("Add a sheet named exactly 'Steps'.",
        "Or start from a blank template written by the Steps GUI."),
      context = list(path = path, sheets_found = sheets)
    ))
  }

  raw <- tryCatch(
    openxlsx::read.xlsx(path, sheet = "Steps", colNames = TRUE,
                        skipEmptyRows = FALSE, sep.names = " "),
    error = function(e) e
  )
  if (inherits(raw, "error")) {
    return(steps_refuse(
      "IO_RUNBOOK_UNREADABLE",
      sprintf("The 'Steps' sheet of %s could not be read: %s",
              basename(path), conditionMessage(raw)),
      "Check the sheet has a header row and at least one step below it.",
      context = list(path = path)
    ))
  }

  headers <- names(raw)
  missing_cols <- Filter(
    function(w) is.na(.steps_find_column(headers, w)),
    STEPS_RUNBOOK_REQUIRED_COLUMNS
  )
  if (length(missing_cols) > 0) {
    return(steps_refuse(
      "CFG_RUNBOOK_INVALID",
      sprintf("The 'Steps' sheet of %s is missing column(s): %s.",
              basename(path), paste(missing_cols, collapse = ", ")),
      c(sprintf("The required columns are: %s.",
                paste(STEPS_RUNBOOK_REQUIRED_COLUMNS, collapse = ", ")),
        "Optional: Tool, Notes, and any number of 'arg:<id>' columns."),
      context = list(path = path, columns_found = headers)
    ))
  }

  col_order <- headers[.steps_find_column(headers, "Order")]
  col_step  <- headers[.steps_find_column(headers, "Step")]
  col_type  <- headers[.steps_find_column(headers, "Type")]
  i_tool  <- .steps_find_column(headers, "Tool")
  i_notes <- .steps_find_column(headers, "Notes")
  arg_cols <- .steps_arg_columns(headers)

  steps <- list()
  for (i in seq_len(nrow(raw))) {
    sheet_row <- i + 1L   # +1 for the header row, so the message matches Excel

    order_val <- .steps_cell(raw[[col_order]][i])
    step_val  <- .steps_cell(raw[[col_step]][i])
    type_val  <- .steps_cell(raw[[col_type]][i])

    # A wholly blank row is spacing, not a step.
    if (!nzchar(order_val) && !nzchar(step_val) && !nzchar(type_val)) next

    if (!nzchar(step_val)) {
      return(steps_refuse(
        "CFG_RUNBOOK_INVALID",
        sprintf("Row %d of the 'Steps' sheet has no Step description.", sheet_row),
        "Every step needs a plain-words description - that is what the runbook is for.",
        context = list(path = path, row = sheet_row)
      ))
    }

    type_norm <- .steps_normalise_type(type_val)
    if (!type_norm %in% STEPS_RUNBOOK_TYPES) {
      return(steps_refuse(
        "CFG_RUNBOOK_INVALID",
        sprintf("Row %d ('%s') has Type '%s', which is not a step type.",
                sheet_row, step_val, type_val),
        sprintf("Use one of: %s.", paste(STEPS_RUNBOOK_TYPES, collapse = ", ")),
        context = list(path = path, row = sheet_row, step = step_val)
      ))
    }

    tool_val <- if (is.na(i_tool)) "" else .steps_cell(raw[[headers[i_tool]]][i])

    if (identical(type_norm, "tool")) {
      if (!nzchar(tool_val)) {
        return(steps_refuse(
          "CFG_RUNBOOK_INVALID",
          sprintf("Row %d ('%s') is a tool step but names no Tool.", sheet_row, step_val),
          c("Put the Steps registry id in the Tool column.",
            sprintf("Registered ids: %s",
                    paste(vapply(manifests, function(m) m$id, character(1)),
                          collapse = ", "))),
          context = list(path = path, row = sheet_row, step = step_val)
        ))
      }
      if (is.null(steps_find_tool(tool_val, manifests))) {
        return(steps_refuse(
          "CFG_RUNBOOK_INVALID",
          sprintf("Row %d ('%s') names tool '%s', which is not in the registry.",
                  sheet_row, step_val, tool_val),
          c(sprintf("Registered ids: %s",
                    paste(vapply(manifests, function(m) m$id, character(1)),
                          collapse = ", ")),
            "If the tool is new, add its manifest to modules/steps/lib/registry.R.",
            "If the step is not runnable from Turas, type it as 'manual' instead."),
          context = list(path = path, row = sheet_row, tool = tool_val)
        ))
      }
    }

    args <- list()
    for (arg_id in names(arg_cols)) {
      v <- .steps_cell(raw[[arg_cols[[arg_id]]]][i])
      if (nzchar(v)) args[[arg_id]] <- v
    }

    steps[[length(steps) + 1L]] <- list(
      order = order_val,
      step  = step_val,
      type  = type_norm,
      tool  = tool_val,
      notes = if (is.na(i_notes)) "" else .steps_cell(raw[[headers[i_notes]]][i]),
      args  = args,
      row   = sheet_row
    )
  }

  if (length(steps) == 0) {
    return(steps_refuse(
      "CFG_RUNBOOK_INVALID",
      sprintf("The 'Steps' sheet of %s has no steps in it.", basename(path)),
      "Add at least one step row below the header.",
      context = list(path = path)
    ))
  }

  # Sort by Order when every value is a number; otherwise keep sheet order, which
  # is at least what the author saw.
  orders <- vapply(steps, function(s) s$order, character(1))
  nums <- suppressWarnings(as.numeric(orders))
  if (!any(is.na(nums))) steps <- steps[order(nums)]

  provenance <- .steps_runbook_read_provenance(path, sheets)

  list(
    status = "PASS",
    result = list(
      path       = normalizePath(path, winslash = "/", mustWork = FALSE),
      steps      = steps,
      provenance = provenance
    )
  )
}


#' Read the optional Provenance sheet
#'
#' Malformed provenance is not worth refusing a whole runbook over - the steps
#' are the operational part. An unreadable sheet yields an empty record.
#'
#' @return Named list of parameter -> value.
#' @keywords internal
.steps_runbook_read_provenance <- function(path, sheets) {
  if (!"Provenance" %in% sheets) return(list())
  raw <- tryCatch(
    openxlsx::read.xlsx(path, sheet = "Provenance", colNames = TRUE,
                        skipEmptyRows = TRUE, sep.names = " "),
    error = function(e) NULL
  )
  if (is.null(raw) || ncol(raw) < 2 || nrow(raw) == 0) return(list())

  out <- list()
  for (i in seq_len(nrow(raw))) {
    key <- .steps_cell(raw[[1]][i])
    if (!nzchar(key)) next
    out[[key]] <- .steps_cell(raw[[2]][i])
  }
  out
}


# ------------------------------------------------------------------------------
# Last-run state (sidecar - never written into the analyst's workbook)
# ------------------------------------------------------------------------------

#' Path of the sidecar state file for a runbook
#'
#' Named after the workbook so two runbooks in one folder cannot collide.
#'
#' @param workbook_path Character. Path to the runbook .xlsx.
#' @return Character. Path to the sidecar .rds (which need not exist).
#' @export
steps_runbook_state_path <- function(workbook_path) {
  stem <- sub("\\.[Xx][Ll][Ss][Xx]$", "", basename(workbook_path))
  file.path(dirname(workbook_path), sprintf(".%s_runbook_state.rds", stem))
}


#' Read the last-run state for a runbook
#'
#' @param workbook_path Character. Path to the runbook .xlsx.
#' @return Named list keyed by step key. Empty list when there is no state yet
#'   or the file is unreadable - state is a convenience, never a dependency.
#' @export
steps_runbook_state_read <- function(workbook_path) {
  p <- steps_runbook_state_path(workbook_path)
  if (!file.exists(p)) return(list())
  val <- tryCatch(readRDS(p), error = function(e) NULL)
  if (is.null(val) || !is.list(val)) list() else val
}


#' Record the outcome of running one step
#'
#' @param workbook_path Character. Path to the runbook .xlsx.
#' @param step_key Character. Stable key for the step (see steps_runbook_key()).
#' @param status Character. "PASS" or "REFUSED".
#' @param args Named list of the arguments used.
#' @param when POSIXct. Defaults to now.
#' @return The updated state list, invisibly. Failure to write is silent by
#'   design: losing a timestamp must never cost the run that produced it.
#' @export
steps_runbook_state_write <- function(workbook_path, step_key, status,
                                      args = list(), when = Sys.time()) {
  state <- steps_runbook_state_read(workbook_path)
  state[[step_key]] <- list(
    last_run    = when,
    last_status = status,
    last_args   = args
  )
  tryCatch(saveRDS(state, steps_runbook_state_path(workbook_path)),
           error = function(e) NULL)
  invisible(state)
}


#' Stable key for a step, used by the sidecar state
#'
#' Built from the order and the step text so that inserting a row elsewhere does
#' not silently move another step's history onto it.
#'
#' @param step A step record from steps_runbook_read().
#' @return Character key.
#' @export
steps_runbook_key <- function(step) {
  paste0(step$order, "|", substr(step$step, 1, 80))
}


# ------------------------------------------------------------------------------
# Template
# ------------------------------------------------------------------------------

#' Write a blank runbook template
#'
#' @param path Character. Where to write the .xlsx.
#' @param project_name Character. Used in the Guide sheet's heading.
#' @param steps Optional data frame of starter rows with columns
#'   Order/Step/Type/Tool/Notes and any `arg:` columns. NULL writes a header-only
#'   Steps sheet.
#' @param provenance Optional named list of Provenance values. Missing keys are
#'   written blank.
#' @param overwrite Logical. Refuses rather than overwriting when FALSE.
#' @return list(status = "PASS", path = ...) or a TRS refusal.
#' @export
steps_runbook_write_template <- function(path,
                                         project_name = "Project",
                                         steps = NULL,
                                         provenance = list(),
                                         overwrite = FALSE) {

  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    return(steps_refuse(
      "PKG_MISSING_DEPENDENCY",
      "The openxlsx package is not installed, so a runbook cannot be written.",
      "Run renv::restore() - openxlsx is already in renv.lock."
    ))
  }

  if (file.exists(path) && !isTRUE(overwrite)) {
    return(steps_refuse(
      "IO_RUNBOOK_EXISTS",
      sprintf("There is already a runbook at %s.", path),
      c("Choose a different name, or open the existing one.",
        "A runbook holds the analyst's own notes - it is never overwritten silently."),
      context = list(path = path)
    ))
  }

  if (is.null(steps)) {
    steps <- data.frame(
      Order = integer(0), Step = character(0), Type = character(0),
      Tool = character(0), Notes = character(0),
      stringsAsFactors = FALSE
    )
  }

  prov_keys <- unique(c(STEPS_RUNBOOK_PROVENANCE_KEYS, names(provenance)))
  prov_df <- data.frame(
    Parameter = prov_keys,
    Value = vapply(prov_keys, function(k) {
      v <- provenance[[k]]
      if (is.null(v)) "" else as.character(v)[1]
    }, character(1)),
    stringsAsFactors = FALSE
  )

  guide <- data.frame(
    Column = c(
      sprintf("%s runbook", project_name),
      "Order", "Step", "Type", "Tool", "Notes", "arg:<id>",
      "", "Type: module", "Type: tool", "Type: ai-assisted", "Type: manual",
      "", "Provenance sheet", "What this is not"
    ),
    Meaning = c(
      "The ordered record of how this project's deliverable is produced. Open it from launch_turas -> Project Steps.",
      "The sequence. Numbers; the checklist sorts on them.",
      "What happens, in plain words. This is the documentation - write it for someone who has never run this project.",
      "One of: module, tool, ai-assisted, manual.",
      "For a tool step, the Steps registry id (e.g. comment_appendix_build). For a module step, the Turas module, for the record.",
      "Anything the next person needs to know: gotchas, who does it, what to check.",
      "Any column headed 'arg:' plus an argument id supplies that argument to the tool, e.g. arg:data. Blank cells are not passed.",
      "",
      "A Turas module run from its own tile (Tabs, Weighting, Tracker...).",
      "Runs from the Project Steps tile. Needs a registered Tool id.",
      "An analyst-supervised AI step - AI proposes, you check every output before it is used. Never recorded as 'manual'.",
      "A genuinely human step. Listed so the sequence is complete, even though nothing can run it.",
      "",
      "Which AI features were on for this project, and where the client's approval or restriction lives. See docs/REPORT_GENERATION_METHOD.md.",
      "This is a checklist, not a pipeline. Nothing sequences itself and there is no 'run all' - human work between steps is the normal case."
    ),
    stringsAsFactors = FALSE
  )

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Steps")
  openxlsx::addWorksheet(wb, "Provenance")
  openxlsx::addWorksheet(wb, "Guide")

  openxlsx::writeData(wb, "Steps", steps)
  openxlsx::writeData(wb, "Provenance", prov_df)
  openxlsx::writeData(wb, "Guide", guide)

  header <- openxlsx::createStyle(textDecoration = "bold", fgFill = "#1a2744",
                                  fontColour = "#ffffff", halign = "left")
  wrap <- openxlsx::createStyle(wrapText = TRUE, valign = "top")

  for (sh in c("Steps", "Provenance", "Guide")) {
    n_col <- max(1L, ncol(if (sh == "Steps") steps else if (sh == "Provenance") prov_df else guide))
    openxlsx::addStyle(wb, sh, header, rows = 1, cols = seq_len(n_col), gridExpand = TRUE)
    openxlsx::freezePane(wb, sh, firstRow = TRUE)
  }

  openxlsx::setColWidths(wb, "Steps", cols = seq_len(max(1L, ncol(steps))),
                         widths = c(7, 60, 14, 32, 60,
                                    rep(30, max(0L, ncol(steps) - 5L)))[seq_len(max(1L, ncol(steps)))])
  openxlsx::setColWidths(wb, "Provenance", cols = 1:2, widths = c(30, 70))
  openxlsx::setColWidths(wb, "Guide", cols = 1:2, widths = c(22, 100))

  n_steps <- max(nrow(steps), 200L)   # room to keep typing
  openxlsx::addStyle(wb, "Steps", wrap, rows = 2:(n_steps + 1),
                     cols = c(2, 5), gridExpand = TRUE, stack = TRUE)
  openxlsx::addStyle(wb, "Guide", wrap, rows = 2:(nrow(guide) + 1), cols = 2,
                     gridExpand = TRUE, stack = TRUE)

  # A dropdown on Type, so the four values stay the four values.
  type_col <- .steps_find_column(names(steps), "Type")
  if (!is.na(type_col)) {
    tryCatch(
      openxlsx::dataValidation(
        wb, "Steps", cols = type_col, rows = 2:(n_steps + 1),
        type = "list",
        value = sprintf('"%s"', paste(STEPS_RUNBOOK_TYPES, collapse = ","))
      ),
      error = function(e) NULL
    )
  }

  # openxlsx::saveWorkbook only WARNS when the destination folder is missing - it
  # returns normally having written nothing. Trusting its return value would
  # report a runbook that does not exist, so the write is confirmed on disk.
  warnings_seen <- character(0)
  written <- tryCatch(
    withCallingHandlers({
      openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
      TRUE
    }, warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }),
    error = function(e) e
  )

  if (inherits(written, "error") || !file.exists(path)) {
    why <- if (inherits(written, "error")) {
      conditionMessage(written)
    } else if (length(warnings_seen) > 0) {
      paste(warnings_seen, collapse = "; ")
    } else {
      "the file was not created and nothing said why"
    }
    return(steps_refuse(
      "IO_RUNBOOK_WRITE_FAILED",
      sprintf("Could not write the runbook to %s: %s", path, why),
      c("Check the folder exists - it is not created for you.",
        "Check the file is not open in Excel, and that you can write there."),
      context = list(path = path)
    ))
  }

  list(status = "PASS",
       path = normalizePath(path, winslash = "/", mustWork = FALSE),
       message = sprintf("Runbook written: %s", basename(path)))
}

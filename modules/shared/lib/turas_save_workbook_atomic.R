# ==============================================================================
# TURAS ATOMIC WORKBOOK SAVE (TRS v1.0)
# ==============================================================================
#
# Provides atomic file saving with refusal hardening for Excel workbooks.
# Prevents partial/corrupt files from being written on failure.
#
# USAGE:
#   result <- turas_save_workbook_atomic(wb, "output.xlsx", run_result)
#   if (!result$success) { handle error }
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================


# ==============================================================================
# WORKBOOK PART RECONCILIATION
# ==============================================================================
#
# WHY THIS EXISTS
#
# openxlsx seeds every worksheet, at addWorksheet() time, with a relationship to
# a drawing part and a vmlDrawing part, plus a [Content_Types].xml override for
# the drawing. It does this unconditionally, so that insertImage()/writeComment()
# never have to manage relationships themselves. But saveWorkbook() only writes
# those parts when the sheet actually holds a drawing or a comment.
#
# The result is a relationship pointing at a part that is not in the archive,
# which is a hard OPC error. Excel reports "we found a problem with some content"
# and offers to repair the file -- and its repair strips every data-validation
# dropdown. openxlsx::loadWorkbook() re-seeds the same relationships, so a
# load-modify-save round trip reintroduces the fault even on a clean file.
#
# The same defect exists once more at workbook level: the sharedStrings
# relationship is seeded unconditionally but xl/sharedStrings.xml is only written
# when the workbook holds shared strings, so an all-numeric or empty workbook is
# broken even when every sheet is sound.
#
# The reconciler makes the relationship set agree with what will actually be
# written: a drawing relationship exists if and only if the sheet has drawing
# content, a vmlDrawing relationship exists if and only if the sheet has vml or
# comment content, and a sharedStrings relationship exists if and only if the
# workbook has shared strings. It both drops and re-adds, so it is idempotent and
# safe to call before every save -- including a save that follows an earlier save
# on the same workbook object (sanitise -> save -> insertImage -> save).
#
# IMPLEMENTATION NOTE: this reaches into openxlsx internals (worksheets_rels,
# Content_Types, drawings, vml, comments) as of openxlsx 4.2.8, pinned by renv.
# The regression tests in modules/shared/tests/testthat/test_workbook_parts.R and
# modules/tabs/tests/testthat/test_workbook_builder.R are the guard if that ever
# changes: they assert the zip-level invariant, not the mechanism.
# ==============================================================================

.TURAS_REL_TYPE_DRAWING <- "http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing"
.TURAS_REL_TYPE_VML <- "http://schemas.openxmlformats.org/officeDocument/2006/relationships/vmlDrawing"
.TURAS_REL_TYPE_SHARED_STRINGS <- "http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings"
.TURAS_CT_DRAWING <- "application/vnd.openxmlformats-officedocument.drawing+xml"
.TURAS_CT_SHARED_STRINGS <- "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"


#' Does an openxlsx part slot hold any content?
#'
#' openxlsx represents "no content" for a sheet part as an empty list, and
#' sometimes as a list of empty strings. Both mean the part will not be written.
#'
#' @param slot An element of wb$drawings, wb$vml or wb$comments
#' @return TRUE if the part will be written, FALSE otherwise
#' @keywords internal
.turas_part_has_content <- function(slot) {
  if (is.null(slot)) {
    return(FALSE)
  }
  flat <- unlist(slot, use.names = FALSE)
  if (length(flat) == 0) {
    return(FALSE)
  }
  flat <- flat[!is.na(flat)]
  any(nzchar(trimws(as.character(flat))))
}


#' Reconcile Worksheet Relationships With Parts That Will Be Written
#'
#' Brings an openxlsx workbook's worksheet relationships and content-type
#' overrides into agreement with the parts saveWorkbook() will actually write,
#' so that the saved .xlsx contains no relationship pointing at an absent part.
#'
#' Call this immediately before openxlsx::saveWorkbook(). It mutates the
#' workbook in place (openxlsx Workbook objects are reference objects) and also
#' returns it invisibly, so either calling style works.
#'
#' Nothing is added or removed that changes what the user sees: sheets with real
#' images, charts or comments keep their relationships, and cell values, styles
#' and data validations are never touched.
#'
#' @param wb The openxlsx workbook object
#' @param module Module name for logging (default: "TURAS")
#' @param verbose Logical. Print a summary of what was reconciled? (default FALSE)
#'
#' @return The workbook, invisibly. On invalid input the workbook is returned
#'   unchanged and a refusal is written to the console.
#'
#' @examples
#' \dontrun{
#'   turas_reconcile_workbook_parts(wb)
#'   openxlsx::saveWorkbook(wb, "output.xlsx", overwrite = TRUE)
#' }
#'
#' @export
turas_reconcile_workbook_parts <- function(wb, module = "TURAS", verbose = FALSE) {

  if (is.null(wb) || !inherits(wb, "Workbook")) {
    cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
    cat("│ Context:", module, "- reconcile workbook parts\n")
    cat("│ Code: DATA_NOT_WORKBOOK\n")
    cat("│ Message: Object passed to turas_reconcile_workbook_parts() is not an openxlsx Workbook\n")
    cat("│ How to fix: Pass the workbook created by openxlsx::createWorkbook() or loadWorkbook()\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    return(invisible(wb))
  }

  # A zero-sheet workbook falls straight through the per-sheet loop and is still
  # handled by the workbook-level reconciliation below.
  n_sheets <- length(wb$worksheets)

  drawing_type_tag <- paste0("Type=\"", .TURAS_REL_TYPE_DRAWING, "\"")
  vml_type_tag <- paste0("Type=\"", .TURAS_REL_TYPE_VML, "\"")

  n_dropped <- 0L
  n_added <- 0L
  drop_part_names <- character(0)
  keep_part_names <- character(0)

  for (i in seq_len(n_sheets)) {

    has_drawing <- .turas_part_has_content(wb$drawings[[i]])
    has_vml <- .turas_part_has_content(wb$vml[[i]]) ||
      .turas_part_has_content(wb$comments[[i]])

    rels <- as.character(unlist(wb$worksheets_rels[[i]], use.names = FALSE))
    rels <- rels[!is.na(rels) & nzchar(rels)]

    is_drawing_rel <- grepl(drawing_type_tag, rels, fixed = TRUE)
    is_vml_rel <- grepl(vml_type_tag, rels, fixed = TRUE)

    # The drawing part name is derived from the relationship Target rather than
    # assumed to be drawing<i>.xml, so that a loaded workbook whose numbering
    # does not follow sheet order is handled correctly.
    for (target in .turas_rel_targets(rels[is_drawing_rel])) {
      part_name <- sub("^\\.\\./", "/xl/", target)
      if (has_drawing) {
        keep_part_names <- c(keep_part_names, part_name)
      } else {
        drop_part_names <- c(drop_part_names, part_name)
      }
    }

    keep <- rep(TRUE, length(rels))
    if (!has_drawing) keep[is_drawing_rel] <- FALSE
    if (!has_vml) keep[is_vml_rel] <- FALSE
    n_dropped <- n_dropped + sum(!keep)
    rels <- rels[keep]

    # Re-add anything the sheet now needs but does not carry. This is what makes
    # the function idempotent across save -> mutate -> save: dropping alone would
    # leave a later insertImage() with a drawing part and no relationship to it.
    if (has_drawing && !any(grepl(drawing_type_tag, rels, fixed = TRUE))) {
      # rId1 is not arbitrary: openxlsx emits <drawing r:id="rId1"/> in the
      # sheet XML, so the drawing relationship must carry that exact Id.
      rels <- c(
        sprintf("<Relationship Id=\"rId1\" Type=\"%s\" Target=\"../drawings/drawing%d.xml\"/>",
                .TURAS_REL_TYPE_DRAWING, i),
        rels
      )
      keep_part_names <- c(keep_part_names, sprintf("/xl/drawings/drawing%d.xml", i))
      n_added <- n_added + 1L
    }

    if (has_vml && !any(grepl(vml_type_tag, rels, fixed = TRUE))) {
      rels <- c(
        rels,
        sprintf("<Relationship Id=\"rIdvml\" Type=\"%s\" Target=\"../drawings/vmlDrawing%d.vml\"/>",
                .TURAS_REL_TYPE_VML, i)
      )
      n_added <- n_added + 1L
    }

    wb$worksheets_rels[[i]] <- rels
  }

  # The same defect exists once at workbook level: the sharedStrings
  # relationship and its content-type override are seeded unconditionally, but
  # xl/sharedStrings.xml is only written when the workbook actually holds shared
  # strings. A workbook whose cells are entirely numeric, or which has an empty
  # sheet only, therefore ships a dangling reference even with every sheet
  # reconciled.
  ct <- as.character(unlist(wb$Content_Types, use.names = FALSE))
  ct <- ct[!is.na(ct) & nzchar(ct)]

  has_shared_strings <- length(unlist(wb$sharedStrings, use.names = FALSE)) > 0
  ss_type_tag <- paste0("Type=\"", .TURAS_REL_TYPE_SHARED_STRINGS, "\"")
  ss_part_tag <- "PartName=\"/xl/sharedStrings.xml\""

  wb_rels <- as.character(unlist(wb$workbook.xml.rels, use.names = FALSE))
  wb_rels <- wb_rels[!is.na(wb_rels) & nzchar(wb_rels)]
  is_ss_rel <- grepl(ss_type_tag, wb_rels, fixed = TRUE)

  if (!has_shared_strings) {
    if (any(is_ss_rel)) {
      n_dropped <- n_dropped + sum(is_ss_rel)
      wb$workbook.xml.rels <- wb_rels[!is_ss_rel]
    }
    ct <- ct[!grepl(ss_part_tag, ct, fixed = TRUE)]
  } else {
    if (!any(is_ss_rel)) {
      # A fixed, unmistakable Id rather than a computed rIdN: nothing refers to
      # the sharedStrings relationship by Id (readers find it by Type), and a
      # computed one could collide with a sheet or styles relationship on the
      # re-add path (all-numeric save -> writeData adds strings -> save again).
      # openxlsx uses the same trick with "rIdvml".
      wb$workbook.xml.rels <- c(
        wb_rels,
        sprintf("<Relationship Id=\"rIdTurasSharedStrings\" Type=\"%s\" Target=\"sharedStrings.xml\"/>",
                .TURAS_REL_TYPE_SHARED_STRINGS)
      )
      n_added <- n_added + 1L
    }
    if (!any(grepl(ss_part_tag, ct, fixed = TRUE))) {
      ct <- c(ct, sprintf("<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"%s\"/>",
                          .TURAS_CT_SHARED_STRINGS))
    }
  }

  drop_part_names <- setdiff(unique(drop_part_names), unique(keep_part_names))
  if (length(drop_part_names) > 0) {
    drop_tags <- sprintf("PartName=\"%s\"", drop_part_names)
    is_phantom <- Reduce(`|`, lapply(drop_tags, function(tag) grepl(tag, ct, fixed = TRUE)))
    ct <- ct[!is_phantom]
  }

  for (part_name in unique(keep_part_names)) {
    tag <- sprintf("PartName=\"%s\"", part_name)
    if (!any(grepl(tag, ct, fixed = TRUE))) {
      ct <- c(ct, sprintf("<Override PartName=\"%s\" ContentType=\"%s\"/>",
                          part_name, .TURAS_CT_DRAWING))
    }
  }

  wb$Content_Types <- ct

  if (verbose) {
    cat(sprintf("   Reconciled workbook parts: %d relationship(s) dropped, %d re-added\n",
                n_dropped, n_added))
  }

  invisible(wb)
}


#' Check a Saved .xlsx for References to Parts That Are Not in the Archive
#'
#' Opens a saved workbook as a zip and checks the OPC invariant that Excel
#' enforces: every relationship Target must resolve to a part present in the
#' archive, and every [Content_Types].xml override must name a present part.
#' A file that fails this is the one Excel offers to repair.
#'
#' This is the verification used by the regression tests. It is deliberately
#' independent of how the file was written, so it keeps working if openxlsx
#' internals change.
#'
#' @param path Path to an .xlsx file
#'
#' @return A list with structure:
#'   \item{status}{"PASS" if sound, "PARTIAL" if references are dangling,
#'     "REFUSED" if the file cannot be read}
#'   \item{dangling}{Character vector of "source.rels -> missing part" strings}
#'   \item{phantom_overrides}{Character vector of absent parts named in
#'     [Content_Types].xml}
#'   \item{message}{Human-readable summary}
#'
#' @examples
#' \dontrun{
#'   chk <- turas_check_workbook_parts("output.xlsx")
#'   if (chk$status != "PASS") print(chk$dangling)
#' }
#'
#' @export
turas_check_workbook_parts <- function(path) {

  if (!is.character(path) || length(path) != 1 || !file.exists(path)) {
    return(list(
      status = "REFUSED",
      code = "IO_FILE_MISSING",
      dangling = character(0),
      phantom_overrides = character(0),
      message = paste("Workbook not found:", paste(path, collapse = ", ")),
      how_to_fix = "Pass the path to an existing .xlsx file"
    ))
  }

  parts <- tryCatch(utils::unzip(path, list = TRUE)$Name, error = function(e) NULL)
  if (is.null(parts)) {
    return(list(
      status = "REFUSED",
      code = "IO_NOT_A_ZIP",
      dangling = character(0),
      phantom_overrides = character(0),
      message = paste("File is not a readable zip archive:", basename(path)),
      how_to_fix = "Check the file was written completely and is a valid .xlsx"
    ))
  }

  read_part <- function(part) {
    con <- unz(path, part)
    on.exit(close(con), add = TRUE)
    paste(readLines(con, warn = FALSE), collapse = "")
  }

  dangling <- character(0)

  for (rels_part in grep("\\.rels$", parts, value = TRUE)) {
    xml <- tryCatch(read_part(rels_part), error = function(e) "")
    rel_nodes <- regmatches(xml, gregexpr("<Relationship\\b[^>]*/>", xml))[[1]]
    if (length(rel_nodes) == 0) next

    # A relationship whose base directory is xl/worksheets/_rels resolves its
    # Target against xl/worksheets.
    base_dir <- dirname(dirname(rels_part))
    if (base_dir == ".") base_dir <- ""

    for (node in rel_nodes) {
      if (grepl("TargetMode=\"External\"", node, fixed = TRUE)) next
      target <- .turas_rel_targets(node)
      if (length(target) != 1 || !nzchar(target)) next
      if (grepl("^(https?|file|mailto):", target)) next

      resolved <- if (startsWith(target, "/")) {
        sub("^/", "", target)
      } else {
        .turas_normalise_rel_path(file.path(base_dir, target))
      }

      if (!(resolved %in% parts)) {
        dangling <- c(dangling, paste(rels_part, "->", resolved))
      }
    }
  }

  phantom <- character(0)
  if ("[Content_Types].xml" %in% parts) {
    ct_xml <- tryCatch(read_part("[Content_Types].xml"), error = function(e) "")
    overrides <- regmatches(ct_xml, gregexpr("PartName=\"[^\"]*\"", ct_xml))[[1]]
    for (o in overrides) {
      part_name <- sub("^PartName=\"(.*)\"$", "\\1", o)
      resolved <- sub("^/", "", part_name)
      if (!(resolved %in% parts)) {
        phantom <- c(phantom, resolved)
      }
    }
  }

  sound <- length(dangling) == 0 && length(phantom) == 0

  list(
    status = if (sound) "PASS" else "PARTIAL",
    dangling = dangling,
    phantom_overrides = phantom,
    message = if (sound) {
      sprintf("%s: all relationships and content-type overrides resolve", basename(path))
    } else {
      sprintf("%s: %d dangling relationship(s), %d phantom override(s)",
              basename(path), length(dangling), length(phantom))
    }
  )
}


#' Collapse "." and ".." segments in a zip-relative path
#'
#' @param p A path built with file.path(), possibly containing ".." segments
#' @return The normalised path, using forward slashes
#' @keywords internal
.turas_normalise_rel_path <- function(p) {
  p <- gsub("\\\\", "/", p)
  p <- sub("^\\./", "", p)
  segments <- strsplit(p, "/", fixed = TRUE)[[1]]
  out <- character(0)
  for (s in segments) {
    if (s == "" || s == ".") next
    if (s == "..") {
      if (length(out) > 0) out <- out[-length(out)]
    } else {
      out <- c(out, s)
    }
  }
  paste(out, collapse = "/")
}


#' Drop-in Replacement for openxlsx::saveWorkbook
#'
#' Identical signature and return value to openxlsx::saveWorkbook(), but
#' reconciles worksheet relationships first so the saved file has no dangling
#' part references. Use this at call sites that write a workbook directly and do
#' not need the atomic temp-file-and-rename behaviour of
#' turas_save_workbook_atomic().
#'
#' @param wb The openxlsx workbook object
#' @param file Path to write to
#' @param overwrite Logical. Overwrite an existing file? (default TRUE)
#' @param ... Further arguments passed to openxlsx::saveWorkbook()
#'
#' @return Whatever openxlsx::saveWorkbook() returns
#'
#' @examples
#' \dontrun{
#'   turas_saveWorkbook(wb, "output.xlsx", overwrite = TRUE)
#' }
#'
#' @export
turas_saveWorkbook <- function(wb, file, overwrite = TRUE, ...) {
  turas_reconcile_workbook_parts(wb, verbose = FALSE)
  openxlsx::saveWorkbook(wb, file, overwrite = overwrite, ...)
}


#' Extract Target attributes from relationship XML strings
#'
#' @param rels Character vector of <Relationship .../> strings
#' @return Character vector of Target values (possibly empty)
#' @keywords internal
.turas_rel_targets <- function(rels) {
  if (length(rels) == 0) {
    return(character(0))
  }
  m <- regmatches(rels, regexpr("Target=\"[^\"]*\"", rels))
  if (length(m) == 0) {
    return(character(0))
  }
  sub("^Target=\"(.*)\"$", "\\1", m)
}


#' Atomic Workbook Save with TRS Integration
#'
#' Saves an openxlsx workbook atomically by writing to a temp file first,
#' then renaming. This prevents corrupt/partial files on failure.
#'
#' Worksheet relationships are reconciled before the save (see
#' turas_reconcile_workbook_parts) so that the saved file contains no
#' relationship pointing at a part that is absent from the archive -- the defect
#' that makes Excel offer to repair the file and strip its dropdowns.
#'
#' @param wb The openxlsx workbook object
#' @param file_path The target file path
#' @param run_result Optional TRS run_result object for event logging
#' @param module Module name for logging (default: "TURAS")
#' @param overwrite Logical. Overwrite existing file? (default TRUE)
#' @param verbose Logical. Print progress messages? (default TRUE)
#'
#' @return List with success (logical), file_path, error (if any)
#' @export
turas_save_workbook_atomic <- function(wb,
                                        file_path,
                                        run_result = NULL,
                                        module = "TURAS",
                                        overwrite = TRUE,
                                        verbose = TRUE) {

  # Validate inputs

if (is.null(wb)) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Cannot save NULL workbook", code = paste0(module, "_NULL_WB"))
    }
    return(list(success = FALSE, file_path = file_path, error = "Workbook is NULL"))
  }

  if (!inherits(wb, "Workbook")) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Invalid workbook object", code = paste0(module, "_INVALID_WB"))
    }
    return(list(success = FALSE, file_path = file_path, error = "Object is not an openxlsx Workbook"))
  }

  # Normalize the file path
  file_path <- normalizePath(file_path, mustWork = FALSE)
  dir_path <- dirname(file_path)

  # Ensure directory exists
  if (!dir.exists(dir_path)) {
    dir_ok <- tryCatch({
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
      dir.exists(dir_path)
    }, error = function(e) {
      FALSE
    })
    if (!dir_ok) {
      if (exists("turas_log_refuse", mode = "function")) {
        turas_log_refuse(module, paste("Cannot create directory:", dir_path),
                         code = paste0(module, "_DIR_FAIL"))
      }
      return(list(success = FALSE, file_path = file_path,
                  error = paste("Cannot create directory:", dir_path)))
    }
  }

  # Check if file exists and we can't overwrite
  if (file.exists(file_path) && !overwrite) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, paste("File exists and overwrite=FALSE:", basename(file_path)),
                       code = paste0(module, "_FILE_EXISTS"))
    }
    return(list(success = FALSE, file_path = file_path,
                error = "File exists and overwrite is FALSE"))
  }

  # Create temp file path in same directory (for atomic rename)
  temp_file <- paste0(file_path, ".tmp.", format(Sys.time(), "%Y%m%d%H%M%S"), ".", Sys.getpid())

  # Attempt to save to temp file
  save_error <- NULL
  save_success <- tryCatch({
    if (verbose) {
      cat(sprintf("   Writing: %s\n", basename(file_path)))
    }

    # Make the relationship set agree with the parts that will be written, so
    # Excel does not find a dangling reference and offer to repair the file.
    # Done before the save, not after the rename, so atomicity is preserved.
    turas_reconcile_workbook_parts(wb, module = module, verbose = FALSE)

    # Use openxlsx saveWorkbook
    openxlsx::saveWorkbook(wb, temp_file, overwrite = TRUE)
    TRUE
  }, error = function(e) {
    save_error <<- e$message
    FALSE
  })

  if (!save_success) {
    # Clean up temp file if it exists
    if (file.exists(temp_file)) {
      try(unlink(temp_file), silent = TRUE)
    }

    # Log the failure
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, paste("Failed to write workbook:", save_error),
                       code = paste0(module, "_WRITE_FAIL"))
    }

    # Record in run_result if available
    if (!is.null(run_result) && exists("turas_run_state_event", mode = "function")) {
      turas_run_state_event(run_result, "REFUSE",
                            paste("Workbook write failed:", save_error),
                            code = paste0(module, "_WRITE_FAIL"))
    }

    return(list(success = FALSE, file_path = file_path,
                error = paste("Write failed:", save_error)))
  }

  # Verify temp file was created and has content
  if (!file.exists(temp_file)) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Temp file not created after save",
                       code = paste0(module, "_TEMP_MISSING"))
    }
    return(list(success = FALSE, file_path = file_path,
                error = "Temp file was not created"))
  }

  temp_size <- file.info(temp_file)$size
  if (is.na(temp_size) || temp_size == 0) {
    try(unlink(temp_file), silent = TRUE)
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Temp file is empty",
                       code = paste0(module, "_EMPTY_FILE"))
    }
    return(list(success = FALSE, file_path = file_path,
                error = "Saved file is empty"))
  }

  # Atomic rename: remove old file, rename temp to final
  rename_error <- NULL
  rename_success <- tryCatch({
    # Remove existing file if present
    if (file.exists(file_path)) {
      unlink(file_path)
    }

    # Rename temp to final (atomic on most filesystems)
    file.rename(temp_file, file_path)
  }, error = function(e) {
    rename_error <<- e$message
    FALSE
  })

  if (!rename_success) {
    # Try to clean up
    if (file.exists(temp_file)) {
      try(unlink(temp_file), silent = TRUE)
    }

    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, paste("Failed to rename temp file:", rename_error),
                       code = paste0(module, "_RENAME_FAIL"))
    }

    return(list(success = FALSE, file_path = file_path,
                error = paste("Rename failed:", rename_error)))
  }

  # Final verification
  if (!file.exists(file_path)) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Final file not found after rename",
                       code = paste0(module, "_VERIFY_FAIL"))
    }
    return(list(success = FALSE, file_path = file_path,
                error = "Final file missing after rename"))
  }

  final_size <- file.info(file_path)$size

  # Log success
  if (verbose && exists("turas_log_info", mode = "function")) {
    turas_log_info(module, sprintf("Saved: %s (%s bytes)", basename(file_path), format(final_size, big.mark = ",")))
  }

  # Record success in run_result if available
  if (!is.null(run_result) && exists("turas_run_state_event", mode = "function")) {
    turas_run_state_event(run_result, "INFO",
                          sprintf("Output saved: %s", basename(file_path)),
                          code = paste0(module, "_SAVED"))
  }

  return(list(success = TRUE, file_path = file_path, size = final_size, error = NULL))
}


#' Atomic Save for writexl (Non-openxlsx Workbooks)
#'
#' For modules using writexl instead of openxlsx, provides similar atomic
#' save functionality for data frame lists.
#'
#' @param sheets Named list of data frames (sheet_name = data.frame)
#' @param file_path The target file path
#' @param run_result Optional TRS run_result object
#' @param module Module name for logging (default: "TURAS")
#' @param verbose Logical. Print progress messages? (default TRUE)
#'
#' @return List with success (logical), file_path, error (if any)
#' @export
turas_save_writexl_atomic <- function(sheets,
                                       file_path,
                                       run_result = NULL,
                                       module = "TURAS",
                                       verbose = TRUE) {

  # Validate inputs
  if (!is.list(sheets) || length(sheets) == 0) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "Sheets must be a non-empty named list",
                       code = paste0(module, "_INVALID_SHEETS"))
    }
    return(list(success = FALSE, file_path = file_path, error = "Invalid sheets input"))
  }

  # Check writexl is available
  if (!requireNamespace("writexl", quietly = TRUE)) {
    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, "writexl package not available",
                       code = paste0(module, "_NO_WRITEXL"))
    }
    return(list(success = FALSE, file_path = file_path, error = "writexl not installed"))
  }

  # Normalize the file path
  file_path <- normalizePath(file_path, mustWork = FALSE)
  dir_path <- dirname(file_path)

  # Ensure directory exists
  if (!dir.exists(dir_path)) {
    dir_ok <- tryCatch({
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
      dir.exists(dir_path)
    }, error = function(e) {
      FALSE
    })
    if (!dir_ok) {
      return(list(success = FALSE, file_path = file_path,
                  error = paste("Cannot create directory:", dir_path)))
    }
  }

  # Create temp file path
  temp_file <- paste0(file_path, ".tmp.", format(Sys.time(), "%Y%m%d%H%M%S"), ".", Sys.getpid())

  # Attempt to save
  save_error <- NULL
  save_success <- tryCatch({
    if (verbose) {
      cat(sprintf("   Writing: %s\n", basename(file_path)))
    }
    writexl::write_xlsx(sheets, temp_file)
    TRUE
  }, error = function(e) {
    save_error <<- e$message
    FALSE
  })

  if (!save_success) {
    if (file.exists(temp_file)) {
      try(unlink(temp_file), silent = TRUE)
    }

    if (exists("turas_log_refuse", mode = "function")) {
      turas_log_refuse(module, paste("writexl save failed:", save_error),
                       code = paste0(module, "_WRITEXL_FAIL"))
    }

    return(list(success = FALSE, file_path = file_path,
                error = paste("Write failed:", save_error)))
  }

  # Verify and rename
  if (!file.exists(temp_file) || file.info(temp_file)$size == 0) {
    try(unlink(temp_file), silent = TRUE)
    return(list(success = FALSE, file_path = file_path, error = "Temp file empty or missing"))
  }

  # Atomic rename
  rename_success <- tryCatch({
    if (file.exists(file_path)) unlink(file_path)
    file.rename(temp_file, file_path)
  }, error = function(e) {
    FALSE
  })

  if (!rename_success) {
    try(unlink(temp_file), silent = TRUE)
    return(list(success = FALSE, file_path = file_path, error = "Rename failed"))
  }

  final_size <- file.info(file_path)$size

  if (verbose && exists("turas_log_info", mode = "function")) {
    turas_log_info(module, sprintf("Saved: %s (%s bytes)", basename(file_path), format(final_size, big.mark = ",")))
  }

  return(list(success = TRUE, file_path = file_path, size = final_size, error = NULL))
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

if (interactive()) {
  message("[TRS INFO] Atomic workbook save helper loaded (turas_save_workbook_atomic v1.0)")
}

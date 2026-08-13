# ==============================================================================
# TURAS > PROJECT STEPS - TOOL REGISTRY
# ==============================================================================
# Purpose: Describe every external tool the Steps GUI can run, and validate
#          those descriptions before anything is executed.
# Location: modules/steps/lib/registry.R
#
# A "manifest" is a plain R list describing one runnable tool. Tools themselves
# stay where they live (scripts/, custom/); the registry only points at them.
#
# Manifest fields
#   id           Character. Unique, lowercase/underscore. Used in runbooks.
#   name         Character. Display name in the GUI.
#   description  Character. One line, shown under the name.
#   runtime      Character. Binary to invoke ("python3", "Rscript", ...).
#   entry        Character. Script path RELATIVE TO TURAS_ROOT.
#   requires     Character vector. Importable modules the runtime must have.
#   docs         Character. Optional path to the tool's documentation.
#   group        Character. Optional grouping label (default "Built-in tools").
#   args         List of argument descriptors (see below).
#
# Argument descriptor fields
#   id           Character. Unique within the manifest; the form input name.
#   label        Character. Field label in the GUI.
#   type         "file" | "dir" | "text" | "choice" | "flag" | "flag_value"
#   cli          Character. The command-line switch, e.g. "--data".
#   required     Logical. Default FALSE. A required field left blank refuses.
#   must_exist   Logical. For "file"/"dir" only; default TRUE. Set FALSE when
#                the path is an output the tool creates.
#   choices      Character vector. Required for type "choice".
#   exclusive    Character. Group name; at most one arg per group may be set.
#   help         Character. Optional hint text shown under the field.
#
# Type semantics when the command is built
#   file/dir/text/choice  Blank -> omitted. Set -> `cli value`.
#   flag                  TRUE  -> `cli`.  FALSE/blank -> omitted.
#   flag_value            ALWAYS emits `cli`; appends the value when supplied.
#                         Used for switches like --report-changes whose value
#                         is optional and whose presence selects the mode.
# ==============================================================================


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

STEPS_ARG_TYPES <- c("file", "dir", "text", "choice", "flag", "flag_value")

STEPS_DEFAULT_GROUP <- "Built-in tools"


# ------------------------------------------------------------------------------
# Built-in manifests
# ------------------------------------------------------------------------------

#' The comment-appendix argument block shared by all three modes
#'
#' All three modes resolve the comment columns the same way (the Python script
#' resolves columns BEFORE it dispatches on mode), so every mode needs the same
#' data / appendix / column-selection arguments. Omitting them from the review
#' modes would silently fall back to the default column pattern and miss sheets.
#'
#' @param appendix_must_exist Logical. TRUE for the review modes (which read an
#'   existing appendix); FALSE for the build mode (which creates it).
#' @return A list of argument descriptors.
#' @keywords internal
.steps_comment_appendix_common_args <- function(appendix_must_exist) {
  list(
    list(id = "data", label = "Survey data file (.xlsx)",
         type = "file", required = TRUE, must_exist = TRUE, cli = "--data",
         help = "The survey data workbook the verbatims are read from."),

    list(id = "appendix", label = "Comment appendix workbook (.xlsx)",
         type = "file", required = TRUE, must_exist = appendix_must_exist,
         cli = "--appendix",
         help = if (appendix_must_exist) {
           "The coded-comment workbook to read."
         } else {
           "The coded-comment workbook to create or update."
         }),

    list(id = "config", label = "Crosstab config (.xlsx) - names the open-ends AND their sheets",
         type = "file", required = FALSE, must_exist = TRUE,
         cli = "--config", exclusive = "columns",
         help = paste("Best option on an existing project: every Selection row with a CommentSheet",
                      "is an open-end, and that cell is the appendix sheet its comments belong in.",
                      "It is the same declaration the report reads, so the two cannot drift apart.")),

    list(id = "columns_file", label = "Comment-columns file (one column per line)",
         type = "file", required = FALSE, must_exist = TRUE,
         cli = "--columns-file", exclusive = "columns",
         help = "Names the comment columns when there is no config to read. Leave blank to use a pattern instead."),

    list(id = "pattern", label = "Column pattern (regex)",
         type = "text", required = FALSE, cli = "--pattern", exclusive = "columns",
         help = "Alternative to the columns file, e.g. comment|verbatim|feedback."),

    # Without this, a topic-named appendix (sheets called Engagement / Values rather
    # than Q17 / Q24) gets a SECOND set of column-named sheets and the coded ones are
    # left empty — a run that reports success and produces an appendix the report
    # cannot read. The config supplies it; this is the manual override.
    list(id = "sheet_map", label = "Sheet map (COLUMN=SHEET, comma-separated)",
         type = "text", required = FALSE, cli = "--sheet-map",
         help = paste("Only needed when the appendix names its sheets for the topic and there is no",
                      "config to read, e.g. 'Q17=Engagement, Q24=Values'. Overrides the config for",
                      "the columns it names. Leave blank when the sheets are named after the columns."))
  )
}


#' Built-in tool manifests
#'
#' @return A list of manifests. Phase 3 will append discovered custom-view
#'   manifests to this list.
#' @keywords internal
steps_builtin_manifests <- function() {
  list(

    list(
      id          = "comment_appendix_build",
      name        = "Comment Appendix - build/update",
      description = "Append new respondents' verbatims to the coded-comment workbook. Never edits existing rows.",
      runtime     = "python3",
      entry       = "scripts/build_comment_appendix.py",
      requires    = c("openpyxl", "pandas"),
      docs        = "scripts/README_comment_appendix.md",
      args = c(
        .steps_comment_appendix_common_args(appendix_must_exist = FALSE),
        list(
          list(id = "dry_run", label = "Dry run (report only, write nothing)",
               type = "flag", required = FALSE, cli = "--dry-run",
               help = "Prints what would change and stops before saving.")
        )
      )
    ),

    list(
      id          = "comment_appendix_report_changes",
      name        = "Comment Appendix - report changed comments",
      description = "Write a review list of verbatims whose text differs between the data and the appendix. Changes nothing.",
      runtime     = "python3",
      entry       = "scripts/build_comment_appendix.py",
      requires    = c("openpyxl", "pandas"),
      docs        = "scripts/README_comment_appendix.md",
      args = c(
        .steps_comment_appendix_common_args(appendix_must_exist = TRUE),
        list(
          # Emitted last: --report-changes takes an OPTIONAL value, so nothing
          # else may follow it on the command line.
          list(id = "report_changes", label = "Review-list output file (blank = auto-name beside the appendix)",
               type = "flag_value", required = FALSE, cli = "--report-changes",
               help = "Leave blank to write '<appendix> changes <timestamp>.xlsx'.")
        )
      )
    ),

    list(
      id          = "comment_appendix_apply_changes",
      name        = "Comment Appendix - apply approved changes",
      description = "Rewrite the verbatim text on rows marked 'y' in a review list. Coding columns are untouched.",
      runtime     = "python3",
      entry       = "scripts/build_comment_appendix.py",
      requires    = c("openpyxl", "pandas"),
      docs        = "scripts/README_comment_appendix.md",
      args = c(
        .steps_comment_appendix_common_args(appendix_must_exist = TRUE),
        list(
          list(id = "changes_file", label = "Reviewed change list (.xlsx)",
               type = "file", required = TRUE, must_exist = TRUE,
               cli = "--apply-changes",
               help = "The review workbook you marked with 'y' in the 'Apply? (y)' column.")
        )
      )
    )
  )
}


#' Get the validated tool registry
#'
#' @return A list with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{result}{The list of manifests, when status is PASS}
#' @export
steps_registry <- function() {
  manifests <- steps_builtin_manifests()
  check <- steps_validate_registry(manifests)
  if (check$status == "REFUSED") return(check)
  list(status = "PASS", result = manifests)
}


#' Find one manifest by id
#'
#' @param tool_id Character. The manifest id.
#' @param manifests List of manifests. Defaults to the built-in registry.
#' @return The manifest list, or NULL when no manifest carries that id.
#' @export
steps_find_tool <- function(tool_id, manifests = steps_builtin_manifests()) {
  if (!is.character(tool_id) || length(tool_id) != 1) return(NULL)
  Find(function(m) identical(m$id, tool_id), manifests)
}


# ------------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------------

#' Is x a single, non-empty character string?
#' @keywords internal
.steps_is_string <- function(x) {
  is.character(x) && length(x) == 1 && !is.na(x) && nzchar(x)
}


#' Build a TRS refusal list (returned, never thrown)
#'
#' Modules in Turas return structured refusals rather than calling stop(), so a
#' Shiny session can print them to the console and show them in the UI.
#'
#' @param code TRS refusal code (IO_*, CFG_*, PKG_*, ...).
#' @param message One-sentence description of what went wrong.
#' @param how_to_fix Character vector of explicit fixes.
#' @param context Optional named list of diagnostic details.
#' @return A list with status/code/message/how_to_fix/context.
#' @export
steps_refuse <- function(code, message, how_to_fix, context = list()) {
  list(
    status     = "REFUSED",
    code       = code,
    message    = message,
    how_to_fix = how_to_fix,
    context    = context
  )
}


#' Validate a single argument descriptor
#'
#' @param arg The argument descriptor list.
#' @param tool_id Character. Owning manifest id, for the message.
#' @param position Integer. 1-based position in the args list.
#' @return list(status = "PASS") or a TRS refusal.
#' @keywords internal
steps_validate_arg <- function(arg, tool_id, position) {
  where <- sprintf("tool '%s', argument %d", tool_id, position)

  if (!is.list(arg)) {
    return(steps_refuse(
      "CFG_STEP_ARG_INVALID",
      sprintf("%s is not a list.", where),
      "Each entry of a manifest's 'args' must be a list of argument fields."
    ))
  }

  for (field in c("id", "label", "type", "cli")) {
    if (!.steps_is_string(arg[[field]])) {
      return(steps_refuse(
        "CFG_STEP_ARG_INVALID",
        sprintf("%s has no valid '%s'.", where, field),
        sprintf("Give every argument a single non-empty '%s' string.", field),
        context = list(tool = tool_id, position = position)
      ))
    }
  }

  if (!arg$type %in% STEPS_ARG_TYPES) {
    return(steps_refuse(
      "CFG_STEP_ARG_INVALID",
      sprintf("%s ('%s') has unknown type '%s'.", where, arg$id, arg$type),
      sprintf("Use one of: %s", paste(STEPS_ARG_TYPES, collapse = ", ")),
      context = list(tool = tool_id, arg = arg$id)
    ))
  }

  if (!grepl("^-", arg$cli)) {
    return(steps_refuse(
      "CFG_STEP_ARG_INVALID",
      sprintf("%s ('%s') has cli '%s', which is not a command-line switch.",
              where, arg$id, arg$cli),
      "Command-line switches must start with '-' or '--'.",
      context = list(tool = tool_id, arg = arg$id)
    ))
  }

  if (identical(arg$type, "choice") &&
      !(is.character(arg$choices) && length(arg$choices) > 0)) {
    return(steps_refuse(
      "CFG_STEP_ARG_INVALID",
      sprintf("%s ('%s') is type 'choice' but lists no choices.", where, arg$id),
      "Give a 'choices' character vector with at least one option.",
      context = list(tool = tool_id, arg = arg$id)
    ))
  }

  if (!is.null(arg$required) && !(is.logical(arg$required) && length(arg$required) == 1)) {
    return(steps_refuse(
      "CFG_STEP_ARG_INVALID",
      sprintf("%s ('%s') has a non-logical 'required'.", where, arg$id),
      "'required' must be TRUE or FALSE.",
      context = list(tool = tool_id, arg = arg$id)
    ))
  }

  if (!is.null(arg$must_exist) && !(is.logical(arg$must_exist) && length(arg$must_exist) == 1)) {
    return(steps_refuse(
      "CFG_STEP_ARG_INVALID",
      sprintf("%s ('%s') has a non-logical 'must_exist'.", where, arg$id),
      "'must_exist' must be TRUE or FALSE.",
      context = list(tool = tool_id, arg = arg$id)
    ))
  }

  if (!is.null(arg$exclusive) && !.steps_is_string(arg$exclusive)) {
    return(steps_refuse(
      "CFG_STEP_ARG_INVALID",
      sprintf("%s ('%s') has a non-string 'exclusive' group.", where, arg$id),
      "'exclusive' must be a single group name, or absent.",
      context = list(tool = tool_id, arg = arg$id)
    ))
  }

  list(status = "PASS")
}


#' Validate one tool manifest
#'
#' @param manifest The manifest list.
#' @return list(status = "PASS") or a TRS refusal naming the offending field.
#' @export
steps_validate_manifest <- function(manifest) {
  if (!is.list(manifest)) {
    return(steps_refuse(
      "CFG_STEP_MANIFEST_INVALID",
      "A tool manifest is not a list.",
      "Each manifest must be an R list of manifest fields."
    ))
  }

  tool_id <- if (.steps_is_string(manifest$id)) manifest$id else "<unnamed>"

  for (field in c("id", "name", "description", "runtime", "entry")) {
    if (!.steps_is_string(manifest[[field]])) {
      return(steps_refuse(
        "CFG_STEP_MANIFEST_INVALID",
        sprintf("Tool '%s' has no valid '%s'.", tool_id, field),
        sprintf("Give every manifest a single non-empty '%s' string.", field),
        context = list(tool = tool_id)
      ))
    }
  }

  if (!grepl("^[a-z][a-z0-9_]*$", manifest$id)) {
    return(steps_refuse(
      "CFG_STEP_MANIFEST_INVALID",
      sprintf("Tool id '%s' is not a valid identifier.", manifest$id),
      "Tool ids must be lowercase letters, digits and underscores, starting with a letter.",
      context = list(tool = tool_id)
    ))
  }

  if (!is.null(manifest$requires) && !is.character(manifest$requires)) {
    return(steps_refuse(
      "CFG_STEP_MANIFEST_INVALID",
      sprintf("Tool '%s' has a non-character 'requires'.", tool_id),
      "'requires' must be a character vector of module names, or absent.",
      context = list(tool = tool_id)
    ))
  }

  args <- manifest$args
  if (is.null(args)) args <- list()
  if (!is.list(args)) {
    return(steps_refuse(
      "CFG_STEP_MANIFEST_INVALID",
      sprintf("Tool '%s' has a non-list 'args'.", tool_id),
      "'args' must be a list of argument descriptors, or absent.",
      context = list(tool = tool_id)
    ))
  }

  for (i in seq_along(args)) {
    check <- steps_validate_arg(args[[i]], tool_id, i)
    if (check$status == "REFUSED") return(check)
  }

  arg_ids <- vapply(args, function(a) as.character(a$id), character(1))
  dupes <- unique(arg_ids[duplicated(arg_ids)])
  if (length(dupes) > 0) {
    return(steps_refuse(
      "CFG_STEP_MANIFEST_INVALID",
      sprintf("Tool '%s' repeats argument id(s): %s.", tool_id, paste(dupes, collapse = ", ")),
      "Every argument id must be unique within its manifest.",
      context = list(tool = tool_id, duplicates = dupes)
    ))
  }

  list(status = "PASS")
}


#' Validate a whole registry
#'
#' @param manifests List of manifests.
#' @return list(status = "PASS") or a TRS refusal.
#' @export
steps_validate_registry <- function(manifests) {
  if (!is.list(manifests)) {
    return(steps_refuse(
      "CFG_STEP_REGISTRY_INVALID",
      "The tool registry is not a list.",
      "steps_builtin_manifests() must return a list of manifests."
    ))
  }

  for (m in manifests) {
    check <- steps_validate_manifest(m)
    if (check$status == "REFUSED") return(check)
  }

  ids <- vapply(manifests, function(m) as.character(m$id), character(1))
  dupes <- unique(ids[duplicated(ids)])
  if (length(dupes) > 0) {
    return(steps_refuse(
      "CFG_STEP_REGISTRY_INVALID",
      sprintf("The tool registry repeats tool id(s): %s.", paste(dupes, collapse = ", ")),
      "Every tool id must be unique across the registry.",
      context = list(duplicates = dupes)
    ))
  }

  list(status = "PASS")
}

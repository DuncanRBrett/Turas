# vas_turas_plan.R
# ------------------------------------------------------------------------------
# The column plan for the Turas dataset: one row per export column, saying what
# happens to it. Generated from the export, the survey snapshot and the
# category map - then hand-editable, because the plan is the contract.
#
# Actions:
#   id          the Response ID column
#   keep        rides into the Turas dataset (scalar question)
#   multi       rides in as one member column of a Multi_Mention question
#   merge_town        coalesced into the single Town column
#   merge_town_other  the "Other (Please Specify)" twin of a town question,
#                     folded into Town in place of the literal "Other"
#   engine      consumed by the derived-variable engine; replaced by the
#               derived columns, so it does not ride in itself
#   drop        left out (GPS machinery, QC fields, PII, write-in duplicates)
#
# The builder REFUSES to run when the export and the plan disagree on which
# columns exist, so a mid-field survey change can never silently shift the
# dataset. Regenerate (or hand-edit) the plan to accept a change.
# ------------------------------------------------------------------------------

VAS_TURAS_PLAN_FILE <- "vas_turas_columns.csv"

# Admin columns Alchemer always exports. Response ID is the join key; Status
# rides in (Complete / Partial is a useful reporting filter); the rest carry
# no analysis value.
VAS_PLAN_ADMIN_KEEP <- c("Status")
VAS_PLAN_ADMIN_ID <- "Response ID"
VAS_PLAN_ADMIN_DROP <- c("Time Started", "Date Submitted", "IP Address",
                         "Longitude", "Latitude", "Country", "City", "State/Region",
                         "Edit Links")

# Dropped by name or pattern: GPS capture machinery, QC-only fields and PII.
# The register and the QC world keep these; the analysis dataset must not.
VAS_PLAN_DROP_ALIASES <- c("Supervisor", "Interviewer", "Respondent", "RespCell",
                           "Consent", "IntNotes", "IntManualLocation")
VAS_PLAN_DROP_PATTERNS <- c("^gps", "Residence")

# The nine per-province town questions coalesce into one Town column,
# because Province already exists as its own question.
VAS_PLAN_TOWN_PATTERN <- "^(WC|EC|FS|KZN|Gauteng|Limpopo|Mpuma|NC|NW)_Town$"

#' Split an export header into its option title and alias
#'
#' Checkbox columns arrive as "<option title>:<alias>"; scalar columns are the
#' alias alone. Option titles themselves contain colons ("Bank: ATM"), so the
#' alias is everything after the LAST colon.
#'
#' @param header A character vector of export headers.
#'
#' @return A data frame of \code{option_title} (NA for scalars) and \code{alias}.
split_export_header <- function(header) {
  has_option <- grepl(":", header, fixed = TRUE)
  alias <- ifelse(has_option, sub("^.*:", "", header), header)
  option_title <- ifelse(has_option, sub(":[^:]*$", "", header), NA_character_)
  return(data.frame(option_title = option_title, alias = alias,
                    stringsAsFactors = FALSE))
}

#' Every alias the derived-variable engine consumes
#'
#' @param category_map The category map data frame.
#'
#' @return A character vector of aliases.
engine_aliases <- function(category_map) {
  alias_columns <- c("freq1", "freq2", "freq3", "freq4", "amount_alias",
                     "count_alias", "legs_alias", "presence_alias")
  return(unique(stats::na.omit(unlist(category_map[, alias_columns]))))
}

#' The engine aliases that ride into the dataset as questions anyway
#'
#' Most engine inputs are replaced by the derived columns they feed, so
#' publishing them too would be the same number twice. The one-way/return
#' question is different: it is a finding in its own right - how people travel,
#' not just what the trip is priced at - and no derived column carries it, so it
#' rides in as an ordinary Single_Response question.
#'
#' @param category_map The category map data frame.
#'
#' @return A character vector of aliases.
reported_engine_aliases <- function(category_map) {
  return(unique(stats::na.omit(category_map$legs_alias)))
}

#' Decide the action for one export column
#'
#' @param header The export header.
#' @param parts One row from \code{split_export_header()}.
#' @param consumed Aliases the engine consumes.
#' @param index The survey index data frame (for the question type).
#' @param duplicate Is this header's second or later occurrence?
#' @param scalar_aliases Headers that are bare aliases (no colon). An
#'   "Option:Alias" column whose alias is also a scalar column is a
#'   single-choice question's "Other (Specify)" write-in, not a checkbox
#'   member - a real checkbox question never exports a bare scalar column.
#'
#' @return A single action string.
classify_export_column <- function(header, parts, consumed, index, duplicate,
                                   scalar_aliases = character(0)) {
  if (duplicate) {
    return("drop")            # the write-in twin of an "Other (Specify)" option
  }
  if (identical(header, VAS_PLAN_ADMIN_ID)) {
    return("id")
  }
  if (header %in% VAS_PLAN_ADMIN_KEEP) {
    return("keep")
  }
  if (header %in% VAS_PLAN_ADMIN_DROP || parts$alias %in% VAS_PLAN_DROP_ALIASES) {
    return("drop")
  }
  if (any(vapply(VAS_PLAN_DROP_PATTERNS, grepl, logical(1), x = parts$alias))) {
    return("drop")
  }
  if (parts$alias %in% consumed) {
    return("engine")
  }
  if (grepl(VAS_PLAN_TOWN_PATTERN, parts$alias)) {
    # The write-in twin is KEPT, not dropped: a respondent who picked "Other"
    # typed their town into it, and publishing them as "Other" throws that away
    # for the 11% of the sample who did. It is folded into Town rather than
    # published as a column of its own - see assemble_town_column().
    return(if (is.na(parts$option_title)) "merge_town" else "merge_town_other")
  }
  if (!is.na(parts$option_title) && parts$alias %in% scalar_aliases) {
    return("drop")            # a single-choice question's write-in column
  }
  if (!is.na(parts$option_title)) {
    return("multi")           # a checkbox option column; a write-in twin is a dup
  }
  question_type <- index$type[match(parts$alias, index$alias)]
  if (!is.na(question_type) && question_type %in% c("HIDDEN", "JAVASCRIPT", "URLREDIRECT")) {
    return("drop")
  }
  return("keep")
}

#' Build the column plan from an export's headers
#'
#' @param headers The export's header row, in order.
#' @param category_map The category map data frame.
#' @param index The survey index data frame (page/q_id/alias/type/q_title).
#'
#' @return The plan data frame, one row per export column.
build_turas_column_plan <- function(headers, category_map, index) {
  parts <- split_export_header(headers)
  consumed <- setdiff(engine_aliases(category_map),
                      reported_engine_aliases(category_map))
  duplicate <- duplicated(headers)
  scalar_aliases <- headers[!grepl(":", headers, fixed = TRUE)]
  action <- vapply(seq_along(headers), function(i) {
    classify_export_column(headers[i], parts[i, ], consumed, index, duplicate[i],
                           scalar_aliases)
  }, character(1))

  question_code <- ifelse(action %in% c("keep", "multi"), parts$alias,
                          ifelse(action %in% c("merge_town", "merge_town_other"), "Town",
                                 ifelse(action == "id", "ResponseID", NA_character_)))
  question_code[headers == "Status"] <- "ResponseStatus"

  return(data.frame(
    export_header = headers,
    alias = parts$alias,
    option_title = parts$option_title,
    action = action,
    question_code = question_code,
    question_type = index$type[match(parts$alias, index$alias)],
    stringsAsFactors = FALSE
  ))
}

#' Read the column plan, or generate and save it when absent
#'
#' @param plan_path Where the plan CSV lives.
#' @param headers The export headers.
#' @param category_map The category map data frame.
#' @param index The survey index data frame.
#'
#' @return The plan data frame.
read_or_create_column_plan <- function(plan_path, headers, category_map, index) {
  if (file.exists(plan_path)) {
    return(utils::read.csv(plan_path, stringsAsFactors = FALSE, na.strings = ""))
  }
  plan <- build_turas_column_plan(headers, category_map, index)
  utils::write.csv(plan, plan_path, row.names = FALSE, na = "")
  cat(sprintf("Column plan generated: %s (%d rows). Review it; it is now the contract.\n",
              plan_path, nrow(plan)))
  return(plan)
}

#' Refuse to build when the export and the plan disagree
#'
#' @param headers The export headers.
#' @param plan The plan data frame.
#'
#' @return Invisibly TRUE when they agree.
#'
#' @throws Stops with class "vas_plan_mismatch" listing both directions.
verify_plan_covers_export <- function(headers, plan) {
  unplanned <- setdiff(headers, plan$export_header)
  vanished <- setdiff(plan$export_header, headers)
  if (length(unplanned) || length(vanished)) {
    stop(structure(class = c("vas_plan_mismatch", "error", "condition"), list(
      message = sprintf(paste0(
        "The export and the column plan disagree - the survey has changed ",
        "since the plan was made.\n  In the export but not the plan (%d):\n    %s\n",
        "  In the plan but not the export (%d):\n    %s\n\n",
        "Review the change, then delete %s and run again to regenerate it."),
        length(unplanned), paste(utils::head(unplanned, 10), collapse = "\n    "),
        length(vanished), paste(utils::head(vanished, 10), collapse = "\n    "),
        VAS_TURAS_PLAN_FILE), call = NULL)))
  }
  return(invisible(TRUE))
}

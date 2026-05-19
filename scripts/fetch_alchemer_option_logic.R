# scripts/fetch_alchemer_option_logic.R
#
# Fetch per-option show/hide logic for any Alchemer survey via the v5 REST API.
# One row per option, with the resolved source question + target option codes
# so the rules are readable without cross-referencing IDs.
#
# Complements scripts/fetch_alchemer_reporting_values.R (which captures
# reporting values + aliases, not logic).
#
# ------------------------------------------------------------------------------
# Auth
# ------------------------------------------------------------------------------
# Set credentials as environment variables (recommended):
#   ALCHEMER_API_TOKEN
#   ALCHEMER_API_SECRET
# Add them to ~/.Renviron and restart R, or pass them explicitly to the function.
#
# ------------------------------------------------------------------------------
# Usage from R
# ------------------------------------------------------------------------------
#   source("scripts/fetch_alchemer_option_logic.R")
#
#   # Per-option logic (one row per option, show rules resolved)
#   opts <- fetch_alchemer_option_logic(survey_id = 8822527)
#
#   # Page-level LOGIC actions (skip / disqualify / jump)
#   acts <- fetch_alchemer_logic_actions(survey_id = 8822527)
#
#   # Save both to a single xlsx workbook
#   save_alchemer_logic_audit(8822527, "ipk_8822527_logic.xlsx")
#
# ------------------------------------------------------------------------------
# Usage from the command line
# ------------------------------------------------------------------------------
#   Rscript scripts/fetch_alchemer_option_logic.R 8822527
#   Rscript scripts/fetch_alchemer_option_logic.R 8822527 ipk_logic.xlsx
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(httr)
  library(data.table)
})

# Reuse credentials helper, HTTP helper, paginator, and .flatten_text from the
# reporting-values fetcher. Both scripts live in scripts/ side by side.
source(file.path(dirname(sys.frame(1L)$ofile %||% "scripts/fetch_alchemer_option_logic.R"),
                 "fetch_alchemer_reporting_values.R"))

# ---- operator + atom-type labels ---------------------------------------------
#
# Codes observed in Alchemer payloads. atom.type / atom2.type and operator are
# integer-coded; we map the common ones for readability and leave anything
# unknown as "code:<n>" so the raw value is preserved.

.alchemer_atom_type_label <- function(code) {
  switch(as.character(code),
    "3"  = "question_id",
    "17" = "option_ids",
    "21" = "variable",
    sprintf("type:%s", code)
  )
}

#
# Operator codes vary by Alchemer atom type. Only codes directly demonstrated
# by surveys we've inspected are labelled here; everything else is returned as
# "op:<n>" so the raw value is preserved in `operator_code` for spot-checking
# against the Alchemer Build UI. Add new mappings as you confirm them.
.alchemer_operator_label <- function(code) {
  switch(as.character(code),
    "5"  = "is any of",           # verified: page LOGIC actions w/ type-17 atom2
    "12" = "is any of",           # verified: option-level show_rules w/ type-17 atom2
    sprintf("op:%s", code)
  )
}

# ---- question / option lookups -----------------------------------------------

.build_question_index <- function(questions) {
  # Map question_id (chr) -> shortname (or "" if blank)
  idx <- list()
  for (q in questions) {
    qid <- as.character(q$id %||% "")
    if (!nzchar(qid)) next
    sh <- q$shortname
    if (is.list(sh) || is.null(sh) || length(sh) == 0) sh <- ""
    idx[[qid]] <- as.character(sh)
  }
  idx
}

.build_option_index <- function(questions) {
  # Map "qid-oid" -> list(value = ..., title = ...)
  idx <- list()
  for (q in questions) {
    qid <- as.character(q$id %||% "")
    opts <- q$options %||% list()
    for (op in opts) {
      oid <- as.character(op$id %||% "")
      if (!nzchar(qid) || !nzchar(oid)) next
      idx[[paste0(qid, "-", oid)]] <- list(
        value = as.character(op$value %||% NA_character_),
        title = .flatten_text(op$title)
      )
    }
  }
  idx
}

# ---- atom rendering ----------------------------------------------------------

.render_atom <- function(atom, question_index, option_index) {
  if (is.null(atom)) return(list(type = NA_character_, raw = NA_character_, resolved = NA_character_))
  atype <- as.character(atom$type %||% "")
  raw_val <- atom$value
  type_label <- .alchemer_atom_type_label(atype)

  if (atype == "3") {
    # Single question id reference
    qid <- as.character(raw_val %||% "")
    resolved <- if (nzchar(qid) && !is.null(question_index[[qid]])) {
      sn <- question_index[[qid]]
      if (nzchar(sn)) sprintf("%s (qid %s)", sn, qid) else sprintf("qid %s", qid)
    } else {
      sprintf("qid %s", qid)
    }
    return(list(type = type_label, raw = qid, resolved = resolved))
  }

  if (atype == "17") {
    # Array of "qid-oid" strings
    refs <- if (is.list(raw_val)) unlist(raw_val, use.names = FALSE) else as.character(raw_val)
    refs <- refs[!is.na(refs) & nzchar(refs)]
    resolved_parts <- vapply(refs, function(ref) {
      opt <- option_index[[ref]]
      if (is.null(opt)) return(ref)
      val <- opt$value
      if (is.na(val) || !nzchar(val)) val <- "(no value)"
      sprintf("%s [%s]", val, ref)
    }, character(1))
    return(list(
      type = type_label,
      raw  = paste(refs, collapse = ", "),
      resolved = paste(resolved_parts, collapse = ", ")
    ))
  }

  # Fallback: flatten anything else to a single string
  flat <- if (is.list(raw_val)) paste(unlist(raw_val, use.names = FALSE), collapse = ", ")
          else as.character(raw_val %||% NA_character_)
  list(type = type_label, raw = flat, resolved = flat)
}

# ---- option logic extraction -------------------------------------------------

.option_logic_row <- function(option, question_meta, question_index, option_index) {
  rule <- option$properties$show_rules
  if (is.null(rule) || length(rule) == 0) {
    return(data.table::data.table(
      survey_id          = question_meta$survey_id,
      question_id        = question_meta$question_id,
      question_shortname = question_meta$question_shortname,
      question_title     = question_meta$question_title,
      question_type      = question_meta$question_type,
      option_id          = as.character(option$id    %||% NA_character_),
      option_value       = as.character(option$value %||% NA_character_),
      option_title       = .flatten_text(option$title),
      has_show_rule      = FALSE,
      operator_code      = NA_character_,
      operator_label     = NA_character_,
      source_atom_type   = NA_character_,
      source_raw         = NA_character_,
      source_resolved    = NA_character_,
      target_atom_type   = NA_character_,
      target_raw         = NA_character_,
      target_resolved    = NA_character_,
      rule_id            = NA_character_
    ))
  }

  src <- .render_atom(rule$atom,  question_index, option_index)
  tgt <- .render_atom(rule$atom2, question_index, option_index)

  data.table::data.table(
    survey_id          = question_meta$survey_id,
    question_id        = question_meta$question_id,
    question_shortname = question_meta$question_shortname,
    question_title     = question_meta$question_title,
    question_type      = question_meta$question_type,
    option_id          = as.character(option$id    %||% NA_character_),
    option_value       = as.character(option$value %||% NA_character_),
    option_title       = .flatten_text(option$title),
    has_show_rule      = TRUE,
    operator_code      = as.character(rule$operator %||% NA_character_),
    operator_label     = .alchemer_operator_label(rule$operator %||% ""),
    source_atom_type   = src$type,
    source_raw         = src$raw,
    source_resolved    = src$resolved,
    target_atom_type   = tgt$type,
    target_raw         = tgt$raw,
    target_resolved    = tgt$resolved,
    rule_id            = as.character(rule$id %||% NA_character_)
  )
}

#' Fetch per-option show logic for an Alchemer survey
#'
#' One row per option. Rows with `has_show_rule = FALSE` show no rule columns;
#' rows with `has_show_rule = TRUE` include the resolved source question and
#' the resolved target option codes for easy auditing.
#'
#' @param survey_id  Integer or character Alchemer survey ID.
#' @param api_token  Optional API token. Defaults to env ALCHEMER_API_TOKEN.
#' @param api_secret Optional API secret. Defaults to env ALCHEMER_API_SECRET.
#' @return A data.table.
#' @export
fetch_alchemer_option_logic <- function(survey_id,
                                        api_token  = NULL,
                                        api_secret = NULL) {
  if (missing(survey_id) || is.null(survey_id) || is.na(survey_id) ||
      !nzchar(as.character(survey_id))) {
    stop("survey_id is required (numeric or character).", call. = FALSE)
  }
  survey_id <- as.character(survey_id)
  creds     <- .alchemer_credentials(api_token, api_secret)

  questions <- .alchemer_get_paginated(
    sprintf("/survey/%s/surveyquestion", survey_id),
    creds = creds
  )
  if (length(questions) == 0) {
    stop(sprintf("Survey %s returned no questions.", survey_id), call. = FALSE)
  }

  qidx <- .build_question_index(questions)
  oidx <- .build_option_index(questions)

  rows <- vector("list", length(questions))
  for (i in seq_along(questions)) {
    qmeta <- .question_meta(questions[[i]], survey_id)
    opts  <- questions[[i]]$options %||% list()
    if (length(opts) == 0) {
      rows[[i]] <- NULL
      next
    }
    rows[[i]] <- data.table::rbindlist(
      lapply(opts, .option_logic_row,
             question_meta = qmeta,
             question_index = qidx,
             option_index   = oidx),
      use.names = TRUE,
      fill      = TRUE
    )
  }
  data.table::rbindlist(rows, use.names = TRUE, fill = TRUE)
}

# ---- LOGIC action extraction (page-level skip / disqualify / jump) ----------

.logic_action_row <- function(question, survey_id, question_index, option_index) {
  rules <- question$properties$rules
  if (is.null(rules)) return(NULL)

  logic <- rules$logic
  src <- .render_atom(logic$atom,  question_index, option_index)
  tgt <- .render_atom(logic$atom2, question_index, option_index)

  actions <- rules$actions %||% list()
  # Flatten action booleans + any messages
  action_summary <- character(0)
  if (isTRUE(actions$jump))       action_summary <- c(action_summary, "jump")
  if (isTRUE(actions$redirect))   action_summary <- c(action_summary, "redirect")
  if (isTRUE(actions$save_data))  action_summary <- c(action_summary, "save_data")
  if (isTRUE(actions$complete))   action_summary <- c(action_summary, "complete")
  dq <- .flatten_text(actions$disqualify)
  if (!is.na(dq) && nzchar(dq)) action_summary <- c(action_summary, "disqualify")

  data.table::data.table(
    survey_id          = survey_id,
    logic_id           = as.character(question$id %||% NA_character_),
    title              = .flatten_text(question$title),
    operator_code      = as.character(logic$operator %||% NA_character_),
    operator_label     = .alchemer_operator_label(logic$operator %||% ""),
    source_atom_type   = src$type,
    source_raw         = src$raw,
    source_resolved    = src$resolved,
    target_atom_type   = tgt$type,
    target_raw         = tgt$raw,
    target_resolved    = tgt$resolved,
    actions            = paste(action_summary, collapse = " + "),
    disqualify_message = dq,
    rule_id            = as.character(logic$id %||% NA_character_)
  )
}

#' Fetch page-level LOGIC actions (skip / disqualify / jump) for a survey
#'
#' One row per LOGIC action. Returns an empty data.table if none exist.
#'
#' @param survey_id  Integer or character Alchemer survey ID.
#' @param api_token  Optional. Defaults to env ALCHEMER_API_TOKEN.
#' @param api_secret Optional. Defaults to env ALCHEMER_API_SECRET.
#' @return A data.table.
#' @export
fetch_alchemer_logic_actions <- function(survey_id,
                                         api_token  = NULL,
                                         api_secret = NULL) {
  if (missing(survey_id) || is.null(survey_id) || is.na(survey_id) ||
      !nzchar(as.character(survey_id))) {
    stop("survey_id is required (numeric or character).", call. = FALSE)
  }
  survey_id <- as.character(survey_id)
  creds     <- .alchemer_credentials(api_token, api_secret)

  questions <- .alchemer_get_paginated(
    sprintf("/survey/%s/surveyquestion", survey_id),
    creds = creds
  )
  qidx <- .build_question_index(questions)
  oidx <- .build_option_index(questions)

  rows <- lapply(questions, function(q) {
    qtype <- as.character(q$`_type` %||% q$type %||% "")
    if (!identical(qtype, "LOGIC")) return(NULL)
    .logic_action_row(q, survey_id, qidx, oidx)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    return(data.table::data.table(
      survey_id = character(0), logic_id = character(0), title = character(0),
      operator_code = character(0), operator_label = character(0),
      source_atom_type = character(0), source_raw = character(0), source_resolved = character(0),
      target_atom_type = character(0), target_raw = character(0), target_resolved = character(0),
      actions = character(0), disqualify_message = character(0), rule_id = character(0)
    ))
  }
  data.table::rbindlist(rows, use.names = TRUE, fill = TRUE)
}

# ---- writers -----------------------------------------------------------------

#' Save option logic + page-level LOGIC actions to a workbook or pair of files
#'
#' For `.xlsx` output both tables are written as separate sheets (`option_logic`
#' and `logic_actions`). For `.csv` / `.tsv` output two files are written side
#' by side with `_options` and `_actions` suffixes.
#'
#' @param survey_id   Integer or character Alchemer survey ID.
#' @param output_path Path ending in .csv, .tsv or .xlsx.
#' @param api_token   Optional. Defaults to env ALCHEMER_API_TOKEN.
#' @param api_secret  Optional. Defaults to env ALCHEMER_API_SECRET.
#' @return Invisibly, a list with `options` and `actions` data.tables.
#' @export
save_alchemer_logic_audit <- function(survey_id,
                                      output_path,
                                      api_token  = NULL,
                                      api_secret = NULL) {
  if (missing(output_path) || !is.character(output_path) ||
      length(output_path) != 1L || !nzchar(output_path)) {
    stop("output_path is required (single non-empty character).", call. = FALSE)
  }
  output_path <- path.expand(output_path)
  parent_dir  <- dirname(output_path)
  if (!dir.exists(parent_dir)) {
    stop(sprintf(
      "Parent directory does not exist: %s\n  Create it first, e.g. dir.create(\"%s\", recursive = TRUE)",
      parent_dir, parent_dir
    ), call. = FALSE)
  }

  opts <- fetch_alchemer_option_logic(survey_id, api_token, api_secret)
  acts <- fetch_alchemer_logic_actions(survey_id, api_token, api_secret)

  ext <- tolower(tools::file_ext(output_path))
  switch(ext,
    "xlsx" = {
      if (!requireNamespace("openxlsx", quietly = TRUE)) {
        stop(
          "Writing .xlsx requires the openxlsx package. ",
          "Install it with install.packages(\"openxlsx\"), or use a .csv / .tsv path instead.",
          call. = FALSE
        )
      }
      wb <- openxlsx::createWorkbook()
      openxlsx::addWorksheet(wb, "option_logic")
      openxlsx::writeData(wb, "option_logic", opts)
      openxlsx::addWorksheet(wb, "logic_actions")
      openxlsx::writeData(wb, "logic_actions", acts)
      openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
    },
    "tsv" = {
      base <- tools::file_path_sans_ext(output_path)
      data.table::fwrite(opts, paste0(base, "_options.tsv"), sep = "\t", quote = FALSE)
      data.table::fwrite(acts, paste0(base, "_actions.tsv"), sep = "\t", quote = FALSE)
    },
    "csv" = {
      base <- tools::file_path_sans_ext(output_path)
      data.table::fwrite(opts, paste0(base, "_options.csv"), quote = TRUE)
      data.table::fwrite(acts, paste0(base, "_actions.csv"), quote = TRUE)
    },
    stop(sprintf(
      "Unsupported output extension '.%s'. Use .csv, .tsv or .xlsx.",
      ext
    ), call. = FALSE)
  )

  cat(sprintf(
    "Wrote %d option rows (%d with show rules) and %d LOGIC actions.\nFile(s) at: %s\n",
    nrow(opts),
    sum(opts$has_show_rule, na.rm = TRUE),
    nrow(acts),
    normalizePath(output_path, mustWork = FALSE)
  ))
  invisible(list(options = opts, actions = acts))
}

# ---- CLI entry point ---------------------------------------------------------

if (sys.nframe() == 0L && !interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1L) {
    stop(
      "Usage: Rscript fetch_alchemer_option_logic.R <survey_id> [output.xlsx]",
      call. = FALSE
    )
  }
  survey_id_arg <- args[[1L]]
  output_path   <- if (length(args) >= 2L) args[[2L]] else
    sprintf("alchemer_%s_logic.xlsx", survey_id_arg)

  save_alchemer_logic_audit(survey_id_arg, output_path)
}

# ==============================================================================
# TABS. DELIVERY MANIFEST (what is actually inside the file you are about to send)
# ==============================================================================
#
# Every v2 build prints one of these. Not only the builds that happen to trip a
# warning.
#
# Why it exists. Turas already had a disclosure warning box, but it fired only
# when `min_reporting_base` was set. A report built with the threshold unset,
# which is the ordinary case, shipped a per-respondent island and said nothing at
# all. A demo report was handed to a third party in exactly that state, and a
# respondent by question dataset was rebuilt out of it from the page source
# alone. The lesson is not that the island is wrong: it is what makes live
# filtering work, and for most studies it is fine. The lesson is that nobody
# should have to remember what a given build contains.
#
# So this prints the contents of the file, plainly, on every build. Duncan's
# policy is case by case, and a case by case policy only works when each case is
# visible at the moment the file is produced.
#
# Depends on nothing. Pure given its arguments, so it is testable without a run:
#   testthat::test_file("modules/tabs/tests/testthat/test_delivery_manifest.R")
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' Decide whether this build carries the microdata island
#'
#' Two switches, either of which turns the island off: the config's
#' `html_report_v2_microdata = FALSE`, and the GUI's "Client safe" delivery
#' mode (`TURAS_DELIVERY_CLIENT_SAFE`). The GUI choice used to be a declaration
#' only, enforced by an audit after the file was built; choosing it while the
#' config still said TRUE produced a full respondent-level file and then a
#' refusal. A client-safe choice now decides the build.
#'
#' @param config_obj The built config object.
#' @param client_safe Logical. The GUI delivery mode; defaults to the global
#'   the tabs GUI sets, FALSE when unset.
#'
#' @return A list with structure:
#'   \item{wanted}{TRUE when the island should be built}
#'   \item{reason}{Why it is off: "config", "gui", or NA when it is on}
#'
#' @keywords internal
tabs_microdata_wanted <- function(config_obj,
                                  client_safe = isTRUE(get0("TURAS_DELIVERY_CLIENT_SAFE",
                                                            envir = .GlobalEnv))) {
  cfg <- config_obj %||% list()
  if (isFALSE(cfg$html_report_v2_microdata)) {
    return(list(wanted = FALSE, reason = "config"))
  }
  if (isTRUE(client_safe)) {
    return(list(wanted = FALSE, reason = "gui"))
  }
  list(wanted = TRUE, reason = NA_character_)
}


#' Describe what a finished v2 build contains, as manifest lines
#'
#' @param micro The microdata island list from build_microdata(), or NULL.
#' @param qual_json The serialised qualitative island (character), or NULL.
#' @param config_obj The built config object.
#' @param output_file Path of the report the manifest describes, or NULL.
#'
#' @return A list with structure:
#'   \item{lines}{Character vector, the manifest as printable lines}
#'   \item{microdata}{TRUE when the file carries per-respondent records}
#'   \item{n}{Respondent count carried, or NA when none}
#'   \item{restricted}{TRUE when the file should not be forwarded unconsidered}
#'
#' @keywords internal
tabs_delivery_manifest <- function(micro, qual_json, config_obj,
                                   output_file = NULL) {
  cfg <- config_obj %||% list()
  has_micro <- !is.null(micro)
  n <- if (has_micro) suppressWarnings(as.integer(micro$n %||% NA_integer_)) else NA_integer_
  has_weights <- has_micro && !is.null(micro$weights) && length(micro$weights) > 0L

  k_raw <- suppressWarnings(as.numeric(cfg$min_reporting_base))
  k_set <- length(k_raw) == 1L && !is.na(k_raw) && k_raw > 1
  k_txt <- if (k_set) format(k_raw) else "not set"

  has_qual <- !is.null(qual_json) && nzchar(as.character(qual_json)) &&
    !identical(trimws(as.character(qual_json)), "null")

  text_mode <- tolower(trimws(as.character(cfg$qual_confidentiality_mode %||% "hidden")))
  cuts      <- tolower(trimws(as.character(cfg$qual_demographic_cuts %||% "allow")))

  verbatim_txt <- if (!has_qual) "no comment tab in this build" else switch(
    text_mode,
    full     = "FULL text in the file",
    redacted = "text in the file, direct identifiers scrubbed",
    hidden   = "no text in the file (counts and themes only)",
    text_mode)

  tags_txt <- if (!has_qual) "not applicable" else switch(
    cuts,
    block = "none (comments carry no demographics)",
    safe  = if (k_set) sprintf("k-anonymised against k=%s", k_txt) else
      "declared safe but k is unset, so tags ship raw",
    allow = "every tag ships",
    cuts)

  pad <- function(label) formatC(label, width = 30, flag = "-")
  lines <- c(
    "┌─── TURAS DELIVERY MANIFEST ──────────────────────────────────┐",
    if (!is.null(output_file)) paste0("│ File: ", basename(output_file)),
    paste0("│ ", pad("Respondent-level records"), ": ",
           if (has_micro) sprintf("YES (%s respondents)",
                                  if (is.na(n)) "count unknown" else format(n)) else "NO"),
    paste0("│ ", pad("Row-level weights"), ": ", if (has_weights) "YES" else "NO"),
    paste0("│ ", pad("Direct identifiers"), ": NO (indices only, never IDs or raw text)"),
    paste0("│ ", pad("Verbatim comments"), ": ", verbatim_txt),
    paste0("│ ", pad("Comment demographic tags"), ": ", tags_txt),
    paste0("│ ", pad("Minimum reporting base"), ": ", k_txt),
    paste0("│ ", pad("Live filters, custom banners"), ": ",
           if (has_micro) "ON" else "off (published figures only)")
  )

  if (has_micro) {
    lines <- c(lines,
      "│",
      "│ This file can be turned back into a respondent-level dataset by",
      "│ anyone who opens the page source. That is fine for your own working",
      "│ copy, and for a client who has been told. It is not fine for a file",
      "│ that may be forwarded on, pasted into an AI tool, or sent to a study",
      "│ population that was promised individual answers would not be shared.",
      "│",
      "│ The confidentiality ship is one Settings row:",
      "│   html_report_v2_microdata = FALSE",
      "│ Published figures only. Live filters and computed views switch off;",
      "│ tracking, column suppression and the comment tab all still work."
    )
    if (k_set) {
      # Duncan's C3 decision (production review 2026-08). Render-time suppression
      # is a viewing convenience; microdata = FALSE is the confidential ship. A
      # k-gated build that still carries the island must say so in terms the
      # operator can act on before the file leaves.
      lines <- c(lines,
        "│",
        sprintf("│ NOTE: min_reporting_base = %s hides sub-k cells ON SCREEN, but the", k_txt),
        "│ withheld numbers are in the page source of THIS build.")
    }
  }

  lines <- c(lines,
             "└──────────────────────────────────────────────────────────────┘")

  list(lines = lines, microdata = has_micro, n = n, restricted = has_micro)
}


#' Print the delivery manifest to the console
#'
#' Console, because Turas runs inside Shiny and the operator debugs and checks in
#' the terminal that launched it.
#'
#' @inheritParams tabs_delivery_manifest
#' @return The manifest list, invisibly.
#' @keywords internal
tabs_print_delivery_manifest <- function(micro, qual_json, config_obj,
                                         output_file = NULL) {
  m <- tabs_delivery_manifest(micro, qual_json, config_obj, output_file)
  cat("\n")
  cat(paste0(m$lines, collapse = "\n"))
  cat("\n\n")
  invisible(m)
}

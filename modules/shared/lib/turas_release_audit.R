# ==============================================================================
# TURAS RELEASE AUDIT (what is in the finished file, checked rather than assumed)
# ==============================================================================
#
# run_minify_verification() answers "did minification break anything?". This
# answers the other question, which nothing asked until now: "what is in the file
# I am about to send?".
#
# It reads the finished HTML and reports two kinds of thing.
#
#   Disclosure. Whether a per-respondent island is present, how many respondents
#   it covers, whether row-level weights ride with it, and whether any island
#   carries a field that looks like a direct identifier. When the caller declares
#   the build client-safe, a populated island is a refusal, not a note. That is
#   the only way a declaration means anything.
#
#   IP. Engineering commentary, internal review references, R and Python
#   filenames, source maps, test hooks. These are notes, never refusals: a dev
#   build is supposed to have them, and the audit runs on both.
#
# Pure given the HTML string, so it is testable without a build:
#   testthat::test_file("modules/shared/tests/testthat/test_release_audit.R")
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Strings that should not reach a client build. Each is a regex, matched against
# the whole file. Kept deliberately short: a list nobody reads is a list nobody
# maintains, and the minifier already removes comments wholesale.
.RELEASE_IP_PATTERNS <- c(
  "TODO / FIXME notes"          = "\\bTODO\\b|\\bFIXME\\b",
  "source map reference"        = "sourceMappingURL",
  "R or Python source filename" = "[A-Za-z0-9_]+\\.(?:R|py)\\b",
  "internal review reference"   = "review 20[0-9][0-9]|production review|\\breview_[a-z]+",
  "test-harness hook"           = "node-testable|node gate|unit-tested",
  "JSDoc block comment"         = "/\\*\\*"
)

# JSON keys that would be a direct identifier if they appeared in a RESPONDENT
# island. Matched as quoted keys with a non-empty value, so a verbatim mentioning
# the word "email" is not a hit and neither is an unfilled field.
.RELEASE_IDENTIFIER_KEYS <- c(
  "ResponseID", "response_id", "respondent_id", "contact_id",
  "email", "Email", "phone", "Phone", "msisdn", "id_number", "ip_address"
)

# Only these islands hold per-respondent records. data-agg deliberately carries
# report_meta.email and report_meta.phone, which are the ANALYST's contact
# details for the About page, and flagging those taught the audit to cry wolf on
# every single build. An audit that fires on a correct file gets skipped, and a
# skipped audit is the same as no audit.
.RELEASE_RESPONDENT_ISLANDS <- c("data-micro", "data-qual")


#' Extract one JSON island's body from a finished report
#'
#' @param html The whole HTML file as a single string.
#' @param island_id The island's id attribute, e.g. "data-micro".
#' @return The island body as a trimmed string, or NA_character_ when absent.
#' @keywords internal
release_island_body <- function(html, island_id) {
  pat <- paste0("<script[^>]*id=\"", island_id, "\"[^>]*>(.*?)</script>")
  m <- regmatches(html, regexpr(pat, html, perl = TRUE))
  if (length(m) == 0L) return(NA_character_)
  body <- sub(paste0("^<script[^>]*id=\"", island_id, "\"[^>]*>"), "", m[1], perl = TRUE)
  trimws(sub("</script>$", "", body))
}


#' Audit a finished Turas HTML report before it is delivered
#'
#' @param html Character. The finished report, read as a single string.
#' @param client_safe Logical. TRUE when the operator has declared this build
#'   carries no respondent-level data. A populated microdata island then refuses.
#' @param refuse Logical. Whether a client-safe violation raises a TRS refusal
#'   (TRUE, the delivery path) or is only reported (FALSE, for tests and dry runs).
#'
#' @return A list with structure:
#'   \item{status}{"PASS" when nothing was found, "FLAGGED" otherwise}
#'   \item{microdata}{list(present, n, weights)}
#'   \item{identifiers}{Character vector of identifier-looking keys found}
#'   \item{ip}{Named integer vector of IP-pattern hit counts (non-zero only)}
#'   \item{lines}{Character vector, the audit as printable lines}
#'   \item{client_safe_violation}{TRUE when client_safe was declared and broken}
#'
#' @keywords internal
turas_release_audit <- function(html, client_safe = FALSE, refuse = TRUE) {
  if (!is.character(html) || length(html) != 1L) {
    stop("turas_release_audit: html must be a single string", call. = FALSE)
  }

  micro_body <- release_island_body(html, "data-micro")
  micro_present <- !is.na(micro_body) && nzchar(micro_body) &&
    !identical(micro_body, "null")
  micro_n <- NA_integer_
  micro_weights <- FALSE
  if (micro_present) {
    nm <- regmatches(micro_body, regexpr('"n"\\s*:\\s*([0-9]+)', micro_body, perl = TRUE))
    if (length(nm)) micro_n <- as.integer(gsub("\\D", "", nm[1]))
    micro_weights <- grepl('"weights"\\s*:\\s*\\[', micro_body, perl = TRUE)
  }

  # Identifier keys are looked for in the RESPONDENT islands only, and only when
  # they carry a value. Scanning the whole page hits the renderer's own code (a
  # mailto label); scanning data-agg hits the analyst's own contact block.
  respondent_json <- paste(
    vapply(.RELEASE_RESPONDENT_ISLANDS,
           function(id) { b <- release_island_body(html, id); if (is.na(b)) "" else b },
           character(1)),
    collapse = "\n")
  identifiers <- .RELEASE_IDENTIFIER_KEYS[vapply(.RELEASE_IDENTIFIER_KEYS, function(k) {
    # key: "value" with something in it, or key: <non-string, non-null> literal.
    filled <- paste0("\"", k, "\"\\s*:\\s*(?:\"[^\"]+\"|(?!null|\"\")[^,}\\s])")
    grepl(filled, respondent_json, perl = TRUE)
  }, logical(1))]
  identifiers <- unname(identifiers)

  ip_hits <- vapply(.RELEASE_IP_PATTERNS, function(p) {
    length(unlist(gregexpr(p, html, perl = TRUE))[
      unlist(gregexpr(p, html, perl = TRUE)) > 0])
  }, integer(1))
  ip_hits <- ip_hits[ip_hits > 0L]

  violation <- isTRUE(client_safe) && micro_present

  pad <- function(x) formatC(x, width = 32, flag = "-")
  lines <- c(
    "┌─── TURAS RELEASE AUDIT ──────────────────────────────────────┐",
    paste0("│ ", pad("Declared delivery mode"), ": ",
           if (isTRUE(client_safe)) "CLIENT SAFE" else "full (respondent data permitted)"),
    paste0("│ ", pad("Respondent-level island"), ": ",
           if (micro_present) sprintf("PRESENT (%s respondents)",
                                      if (is.na(micro_n)) "count unreadable" else micro_n)
           else "absent"),
    paste0("│ ", pad("Row-level weights"), ": ", if (micro_weights) "present" else "absent"),
    paste0("│ ", pad("Direct-identifier fields"), ": ",
           if (length(identifiers)) paste(identifiers, collapse = ", ") else "none found")
  )

  if (length(ip_hits)) {
    lines <- c(lines, "│", "│ Engineering detail still readable in this file:")
    for (nm in names(ip_hits)) {
      lines <- c(lines, sprintf("│   %s %s", pad(nm), format(ip_hits[[nm]])))
    }
    lines <- c(lines,
      "│ Expected in a dev build. In a deliverable it means the minify step",
      "│ did not run, or ran without the obfuscator.")
  } else {
    lines <- c(lines, paste0("│ ", pad("Engineering detail readable"), ": none found"))
  }

  lines <- c(lines, "└──────────────────────────────────────────────────────────────┘")

  out <- list(
    status = if (!micro_present && !length(identifiers) && !length(ip_hits)) "PASS" else "FLAGGED",
    microdata = list(present = micro_present, n = micro_n, weights = micro_weights),
    identifiers = identifiers,
    ip = ip_hits,
    lines = lines,
    client_safe_violation = violation
  )

  if (violation && isTRUE(refuse)) {
    if (exists("turas_refuse", mode = "function")) {
      turas_refuse(
        code = "CFG_CLIENT_SAFE_VIOLATED",
        title = "Client-safe build still contains respondent-level data",
        problem = sprintf(
          "This build was declared client-safe, but the file carries a populated data-micro island (%s respondents).",
          if (is.na(micro_n)) "count unreadable" else micro_n),
        why_it_matters = paste(
          "A client-safe file is one that stays safe if it is forwarded on.",
          "This one can be turned back into a respondent-by-question dataset",
          "from the page source."),
        how_to_fix = c(
          "Choose 'Client safe' in the tabs GUI before running: the build then drops the island itself.",
          "Running outside the GUI: set html_report_v2_microdata = FALSE on the Settings sheet.",
          "The island is decided when the report is built, so it cannot be removed afterwards.",
          "Or build without declaring client-safe, if respondent data is acceptable for this recipient."),
        module = "RELEASE AUDIT"
      )
    } else {
      stop("Client-safe build still contains respondent-level data", call. = FALSE)
    }
  }

  out
}


#' Print a release audit to the console
#'
#' @inheritParams turas_release_audit
#' @return The audit list, invisibly.
#' @keywords internal
turas_print_release_audit <- function(html, client_safe = FALSE, refuse = TRUE) {
  a <- turas_release_audit(html, client_safe = client_safe, refuse = refuse)
  cat("\n"); cat(paste0(a$lines, collapse = "\n")); cat("\n\n")
  invisible(a)
}

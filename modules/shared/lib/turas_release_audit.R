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

# Islands that hold AGGREGATES, never records. data-cube is the interesting one:
# it exists to be the computed source of a file that carries no respondents, so
# it is audited on its OWN terms (every cell at or above k, no partial block, no
# array as long as the study) rather than treated as a respondent island.
.RELEASE_AGGREGATE_ISLANDS <- c("data-agg", "data-cube")


#' Audit an aggregate cube island against its own promises
#'
#' Three checks, each a thing the cube claims about itself:
#'   1. No array anywhere in it is as long as the study. An array of n values is
#'      respondent-level data whatever the island is called.
#'   2. No cell base is between 1 and k - 1. A cell nobody answered is 0 and
#'      discloses nothing; a cell of one to four people is the whole point of k.
#'   3. No slice ships a partial block. A block ships whole or not at all,
#'      because a cell withheld on its own is recovered by subtraction from the
#'      margin that remains.
#'
#' @param body The data-cube island body, already extracted.
#' @return list(present, k, n, order, blocks, violations) where violations is a
#'   character vector, empty when the cube keeps its promises.
#' @keywords internal
release_audit_cube <- function(body) {
  out <- list(present = FALSE, k = NA_real_, n = NA_integer_, order = NA_integer_,
              cells = 0L, violations = character(0))
  if (is.na(body) || !nzchar(body) || identical(body, "null")) return(out)
  out$present <- TRUE
  cube <- tryCatch(jsonlite::fromJSON(body, simplifyVector = FALSE),
                   error = function(e) NULL)
  if (is.null(cube)) {
    out$violations <- "the data-cube island did not parse"
    return(out)
  }
  out$k <- suppressWarnings(as.numeric(cube$k %||% NA_real_))
  out$n <- suppressWarnings(as.integer(cube$n %||% NA_integer_))
  out$order <- suppressWarnings(as.integer(cube$order %||% NA_integer_))
  k <- out$k
  if (is.na(k) || k <= 1) {
    out$violations <- c(out$violations,
      "the cube states no confidentiality threshold, so it protects nothing")
  }

  # 1. respondent-shaped arrays
  n <- out$n
  long <- FALSE
  scan_arrays <- function(node, depth) {
    if (long || depth > 8 || is.null(node)) return(invisible(NULL))
    if (is.list(node)) {
      if (is.null(names(node)) && length(node) == n && !is.na(n) && n > 5) {
        long <<- TRUE; return(invisible(NULL))
      }
      for (child in node) scan_arrays(child, depth + 1)
    }
    invisible(NULL)
  }
  scan_arrays(cube$slices, 0)
  if (long) {
    out$violations <- c(out$violations, sprintf(
      "the cube carries an array of %s values, which is one per respondent", format(n)))
  }

  # 2 and 3. cell bases, and whole blocks
  sub_k <- 0L
  cells <- 0L
  for (skey in names(cube$slices %||% list())) {
    slice <- cube$slices[[skey]]
    if (is.null(slice)) next
    for (rec in (slice$cells %||% list())) {
      a <- rec$a
      if (is.null(a)) next
      cells <- cells + 1L
      v <- suppressWarnings(as.numeric(a[[1]]))
      if (!is.na(v) && v > 0 && !is.na(k) && v < k) sub_k <- sub_k + 1L
    }
    for (qcode in names(slice$q %||% list())) {
      block <- slice$q[[qcode]]
      if (is.null(block)) next               # refused whole, which is the rule
      for (rec in block) {
        b <- rec$b
        if (is.null(b)) next
        cells <- cells + 1L
        v <- suppressWarnings(as.numeric(b[[1]]))
        if (!is.na(v) && v > 0 && !is.na(k) && v < k) sub_k <- sub_k + 1L
      }
    }
  }
  out$cells <- cells
  if (sub_k > 0L) {
    out$violations <- c(out$violations, sprintf(
      "%d cell base(s) sit between 1 and k - 1, which the block rule forbids", sub_k))
  }
  out
}


#' Extract one JSON island's body from a finished report
#'
#' @param html The whole HTML file as a single string.
#' @param island_id The island's id attribute, e.g. "data-micro".
#' @return The island body as a trimmed string, or NA_character_ when absent.
#' @keywords internal
release_island_body <- function(html, island_id) {
  # (?s) so "." matches a NEWLINE. Without it this matched only an island whose
  # whole body sat on one line, which is true of the hand-built strings in the
  # gate and false of every report the template writes: template.html puts a
  # newline after the opening tag and before the closing one. So the audit read
  # NO island at all from a real deliverable, reported "Respondent-level island:
  # absent" on a file carrying every respondent, and passed a client-safe
  # declaration it should have refused. Found 4 September 2026 while building
  # the adversary gate against a real report rather than a fixture.
  pat <- paste0("(?s)<script[^>]*id=\"", island_id, "\"[^>]*>(.*?)</script>")
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

  cube_audit <- release_audit_cube(release_island_body(html, "data-cube"))

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

  cube_violation <- isTRUE(client_safe) && length(cube_audit$violations) > 0
  violation <- isTRUE(client_safe) && (micro_present || cube_violation)

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
           if (length(identifiers)) paste(identifiers, collapse = ", ") else "none found"),
    paste0("│ ", pad("Aggregate cube"), ": ",
           if (!cube_audit$present) "absent"
           else sprintf("present (k = %s, up to %s variables, %s cells)",
                        format(cube_audit$k), cube_audit$order, format(cube_audit$cells)))
  )

  if (length(cube_audit$violations)) {
    lines <- c(lines, "│", "│ The cube does not keep its own promises:")
    for (v in cube_audit$violations) lines <- c(lines, paste0("│   ", v))
  }

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
    status = if (!micro_present && !length(identifiers) && !length(ip_hits) &&
                 !length(cube_audit$violations)) "PASS" else "FLAGGED",
    microdata = list(present = micro_present, n = micro_n, weights = micro_weights),
    cube = cube_audit,
    identifiers = identifiers,
    ip = ip_hits,
    lines = lines,
    client_safe_violation = violation
  )

  if (violation && isTRUE(refuse)) {
    if (exists("turas_refuse", mode = "function")) {
      turas_refuse(
        code = "CFG_CLIENT_SAFE_VIOLATED",
        title = if (micro_present) "Client-safe build still contains respondent-level data"
                else "Client-safe build carries an aggregate cube that breaks its own rule",
        problem = if (micro_present) sprintf(
          "This build was declared client-safe, but the file carries a populated data-micro island (%s de-identified records).",
          if (is.na(micro_n)) "count unreadable" else micro_n)
        else paste0(
          "This build was declared client-safe, and its aggregate cube does not keep ",
          "its own promises: ", paste(cube_audit$violations, collapse = "; "), "."),
        why_it_matters = paste(
          "A client-safe file carries no respondent-level records, and any",
          "aggregates in it keep their own k rule. This build does not match",
          "the mode it was declared under."),
        how_to_fix = if (micro_present) c(
          "Choose 'Client safe' in the tabs GUI before running: the build then drops the island itself.",
          "Running outside the GUI: set html_report_v2_interactivity = none on the Settings sheet.",
          "The island is decided when the report is built, so it cannot be removed afterwards.",
          "Or build without declaring client-safe, if respondent data is acceptable for this recipient.")
        else c(
          "Raise min_reporting_base and rebuild: the cube then withholds the cuts that are too small.",
          "Or set html_report_v2_interactivity = none for published tables with no live views.",
          "The cube is decided when the report is built, so it cannot be repaired afterwards."),
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

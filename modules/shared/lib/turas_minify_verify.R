# ==============================================================================
# TURAS MINIFICATION VERIFICATION HELPERS
# ==============================================================================
#
# Post-minification integrity checks that compare original and minified HTML
# to ensure the minification pipeline preserved all critical content.
#
# Called by turas_minify() after processing. Each check returns a named list
# with $pass (logical) and $message (character). Failures produce warnings,
# never errors — a report with a failed check may still be valid.
#
# Version: 1.0
# Date: April 2026
# ==============================================================================


# -- Constants ----------------------------------------------------------------

.VERIFY_HANDLER_ATTRS <- c("onclick", "onchange", "onload", "oninput",
                           "onsubmit", "onfocus", "onblur", "onkeydown",
                           "onkeyup", "onmousedown", "onmouseup")


# -- Individual checks --------------------------------------------------------

#' Verify Top-Level JS Function Count
#'
#' Counts named function declarations (function name(...)) in original and
#' minified JavaScript. With toplevel=false in terser, these names are
#' preserved, so counts must match.
#'
#' @param original_js Character string of original JS content.
#' @param minified_js Character string of minified JS content.
#' @return Named list with pass (logical) and message (character).
#' @keywords internal
.verify_js_function_count <- function(original_js, minified_js) {
  pattern <- "function\\s+([A-Za-z_$][A-Za-z0-9_$]*)\\s*\\("
  original_names <- regmatches(original_js,
                               gregexpr(pattern, original_js, perl = TRUE))[[1]]
  minified_names <- regmatches(minified_js,
                               gregexpr(pattern, minified_js, perl = TRUE))[[1]]

  n_orig <- length(original_names)
  n_mini <- length(minified_names)

  # terser with dead_code=true may legitimately remove unreachable functions,

  # so the minified count can be <= original. It should never be greater.
  if (n_mini <= n_orig) {
    removed <- n_orig - n_mini
    msg <- if (removed == 0L) {
      sprintf("JS function count: %d matched", n_orig)
    } else {
      sprintf("JS function count: %d -> %d (%d dead code removed)",
              n_orig, n_mini, removed)
    }
    list(pass = TRUE, message = msg)
  } else {
    list(pass = FALSE,
         message = sprintf(
           "JS function count increased unexpectedly: original %d, minified %d",
           n_orig, n_mini
         ))
  }
}


#' Verify Inline Handler Functions Exist in Minified JS
#'
#' Extracts function names from inline event handlers (onclick, onchange, etc.)
#' in the HTML body and checks each exists in the minified JavaScript.
#'
#' @param html_content Full HTML string of the minified report.
#' @param minified_js Character string of minified JS content.
#' @return Named list with pass (logical) and message (character).
#' @keywords internal
.verify_js_handler_functions <- function(html_content, minified_js) {
  handler_pattern <- paste0(
    "(?:",
    paste(.VERIFY_HANDLER_ATTRS, collapse = "|"),
    ")\\s*=\\s*[\"']([^\"']+)[\"']"
  )

  handler_values <- regmatches(
    html_content,
    gregexpr(handler_pattern, html_content, perl = TRUE, ignore.case = TRUE)
  )[[1]]

  if (length(handler_values) == 0L) {
    return(list(pass = TRUE, message = "No inline handlers found to check"))
  }

  # Extract the function name (first word before parenthesis)
  fn_pattern <- "([A-Za-z_$][A-Za-z0-9_$.]*?)\\s*\\("
  fn_names <- unique(unlist(regmatches(
    handler_values,
    gregexpr(fn_pattern, handler_values, perl = TRUE)
  )))
  fn_names <- unique(gsub("\\s*\\($", "", fn_names))
  fn_names <- fn_names[nzchar(fn_names)]

  # Filter out method chains and built-in DOM methods — these are not top-level
  # function definitions (e.g., this.closest, event.stopPropagation,
  # this.parentElement.classList.toggle)
  fn_names <- fn_names[!grepl("^(this|event|document|window)\\.", fn_names)]
  fn_names <- fn_names[!grepl("\\.", fn_names) |
                         grepl("^(TurasPins|ReportHub|window)\\.", fn_names)]

  if (length(fn_names) == 0L) {
    return(list(pass = TRUE, message = "No function names extracted from handlers"))
  }

  missing_fns <- fn_names[!vapply(fn_names, function(fn) {
    grepl(fn, minified_js, fixed = TRUE)
  }, logical(1))]

  if (length(missing_fns) == 0L) {
    list(pass = TRUE,
         message = sprintf("All %d handler function names found in JS",
                          length(fn_names)))
  } else {
    list(pass = FALSE,
         message = sprintf(
           "Missing %d handler function(s) in minified JS: %s",
           length(missing_fns),
           paste(missing_fns[seq_len(min(5L, length(missing_fns)))], collapse = ", ")
         ))
  }
}


#' Verify CSS Custom Property Count
#'
#' Counts all CSS custom property declarations (any -- prefixed property)
#' in original and minified CSS. Covers all namespaces: --ct-, --t-, --hub-.
#'
#' @param original_css Character string of original CSS content.
#' @param minified_css Character string of minified CSS content.
#' @return Named list with pass (logical) and message (character).
#' @keywords internal
.verify_css_custom_props <- function(original_css, minified_css) {
  pattern <- "--[a-zA-Z][a-zA-Z0-9-]*\\s*:"
  n_orig <- length(gregexpr(pattern, original_css, perl = TRUE)[[1]])
  n_mini <- length(gregexpr(pattern, minified_css, perl = TRUE)[[1]])

  # gregexpr returns -1 for no matches
  if (identical(n_orig, 1L) && gregexpr(pattern, original_css, perl = TRUE)[[1]][1] == -1L) n_orig <- 0L
  if (identical(n_mini, 1L) && gregexpr(pattern, minified_css, perl = TRUE)[[1]][1] == -1L) n_mini <- 0L

  if (n_orig == n_mini) {
    list(pass = TRUE,
         message = sprintf("CSS custom properties: %d matched", n_orig))
  } else {
    list(pass = FALSE,
         message = sprintf(
           "CSS custom property count mismatch: original %d, minified %d",
           n_orig, n_mini
         ))
  }
}


#' Verify CSS Rule Block Count
#'
#' Counts CSS rule blocks (selector followed by {) in original and minified.
#' Level 1 clean-css should preserve all rules.
#'
#' @param original_css Character string of original CSS content.
#' @param minified_css Character string of minified CSS content.
#' @return Named list with pass (logical) and message (character).
#' @keywords internal
.verify_css_rule_count <- function(original_css, minified_css) {
  count_rules <- function(css) {
    # Count opening braces as proxy for rule blocks
    nchar(gsub("[^{]", "", css))
  }

  n_orig <- count_rules(original_css)
  n_mini <- count_rules(minified_css)

  # Allow small tolerance — clean-css level 1 can merge duplicate empty selectors
  diff_pct <- if (n_orig > 0) abs(n_orig - n_mini) / n_orig * 100 else 0

  if (diff_pct <= 1) {
    list(pass = TRUE,
         message = sprintf("CSS rule blocks: %d -> %d (%.1f%% delta)",
                          n_orig, n_mini, diff_pct))
  } else {
    list(pass = FALSE,
         message = sprintf(
           "CSS rule block count mismatch: original %d, minified %d (%.1f%%)",
           n_orig, n_mini, diff_pct
         ))
  }
}


#' Verify HTML Element Counts
#'
#' Checks that table, tr, td, and th element counts match between original
#' and minified HTML. Only counts tags in the HTML body outside of script
#' blocks, since JS string literals can contain tag-like substrings that
#' terser may legitimately remove during dead code elimination.
#'
#' @param original_html Full original HTML string.
#' @param minified_html Full minified HTML string.
#' @return Named list with pass (logical) and message (character).
#' @keywords internal
.verify_html_elements <- function(original_html, minified_html) {
  # Strip all script blocks before counting HTML tags, so we don't count
  # tag-like strings inside JavaScript (e.g., "<table" in JSZip/PptxGen)
  strip_scripts <- function(html) {
    gsub("(<script(?=[\\s>])[^>]*>)([\\s\\S]*?)(</script>)", "", html, perl = TRUE)
  }

  count_tag <- function(html, tag) {
    pattern <- paste0("<", tag, "[\\s>]")
    matches <- gregexpr(pattern, html, perl = TRUE, ignore.case = TRUE)[[1]]
    if (matches[1] == -1L) 0L else length(matches)
  }

  orig_body <- strip_scripts(original_html)
  mini_body <- strip_scripts(minified_html)

  tags <- c("table", "tr", "td", "th")
  mismatches <- character(0)

  for (tag in tags) {
    n_orig <- count_tag(orig_body, tag)
    n_mini <- count_tag(mini_body, tag)
    if (n_orig != n_mini) {
      mismatches <- c(mismatches,
                      sprintf("<%s>: %d -> %d", tag, n_orig, n_mini))
    }
  }

  if (length(mismatches) == 0L) {
    list(pass = TRUE, message = "HTML element counts: all matched")
  } else {
    list(pass = FALSE,
         message = paste("HTML element count mismatch:",
                        paste(mismatches, collapse = "; ")))
  }
}


#' Verify Data Attribute Counts
#'
#' Checks that data-q-code and data-col-key attribute counts match.
#'
#' @param original_html Full original HTML string.
#' @param minified_html Full minified HTML string.
#' @return Named list with pass (logical) and message (character).
#' @keywords internal
.verify_data_attributes <- function(original_html, minified_html) {
  count_attr <- function(html, attr_name) {
    pattern <- paste0(attr_name, "\\s*=")
    matches <- gregexpr(pattern, html, perl = TRUE)[[1]]
    if (matches[1] == -1L) 0L else length(matches)
  }

  attrs <- c("data-q-code", "data-col-key")
  mismatches <- character(0)

  for (attr_name in attrs) {
    n_orig <- count_attr(original_html, attr_name)
    n_mini <- count_attr(minified_html, attr_name)
    if (n_orig != n_mini) {
      mismatches <- c(mismatches,
                      sprintf("%s: %d -> %d", attr_name, n_orig, n_mini))
    }
  }

  if (length(mismatches) == 0L) {
    list(pass = TRUE, message = "Data attribute counts: all matched")
  } else {
    list(pass = FALSE,
         message = paste("Data attribute count mismatch:",
                        paste(mismatches, collapse = "; ")))
  }
}


#' Verify File Size Reduction
#'
#' Checks that the minified file is smaller than the original.
#'
#' @param input_size_bytes Numeric, original file size in bytes.
#' @param output_size_bytes Numeric, minified file size in bytes.
#' @return Named list with pass (logical) and message (character).
#' @keywords internal
.verify_file_size <- function(input_size_bytes, output_size_bytes) {
  if (output_size_bytes < input_size_bytes) {
    reduction <- (1 - output_size_bytes / input_size_bytes) * 100
    list(pass = TRUE,
         message = sprintf("File size reduced by %.1f%%", reduction))
  } else {
    list(pass = FALSE,
         message = sprintf(
           "File size not reduced: %s -> %s bytes",
           format(input_size_bytes, big.mark = ","),
           format(output_size_bytes, big.mark = ",")
         ))
  }
}


# -- Orchestrator -------------------------------------------------------------

#' Run All Minification Verification Checks
#'
#' Orchestrates all verification checks after minification. Returns a
#' structured result with individual check outcomes.
#'
#' @param original_html Full original HTML string.
#' @param minified_html Full minified HTML string.
#' @param original_css Combined original CSS from all style blocks.
#' @param minified_css Combined minified CSS from all style blocks.
#' @param original_js Combined original JS from all script blocks.
#' @param minified_js Combined minified JS from all script blocks.
#' @param input_size_bytes Original file size in bytes.
#' @param output_size_bytes Minified file size in bytes.
#'
#' @return Named list:
#'   \item{all_passed}{Logical, TRUE if every check passed.}
#'   \item{checks}{Named list of individual check results.}
#'   \item{summary}{Character vector of all check messages.}
#'
#' @keywords internal
run_minify_verification <- function(original_html, minified_html,
                                    original_css, minified_css,
                                    original_js, minified_js,
                                    input_size_bytes, output_size_bytes) {
  checks <- list(
    file_size      = .verify_file_size(input_size_bytes, output_size_bytes),
    js_functions   = .verify_js_function_count(original_js, minified_js),
    js_handlers    = .verify_js_handler_functions(minified_html, minified_js),
    css_props      = .verify_css_custom_props(original_css, minified_css),
    css_rules      = .verify_css_rule_count(original_css, minified_css),
    html_elements  = .verify_html_elements(original_html, minified_html),
    data_attrs     = .verify_data_attributes(original_html, minified_html)
  )

  all_passed <- all(vapply(checks, function(ch) ch$pass, logical(1)))
  summary_msgs <- vapply(checks, function(ch) {
    prefix <- if (ch$pass) "PASS" else "FAIL"
    sprintf("[%s] %s", prefix, ch$message)
  }, character(1))

  list(
    all_passed = all_passed,
    checks = checks,
    summary = summary_msgs
  )
}

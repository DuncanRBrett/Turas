# ==============================================================================
# AI EASYSTATS — APA-Style Statistical Narration (Rule-Based, No LLM)
# ==============================================================================
#
# Optional complement to AI insights. Uses the easystats ecosystem to generate
# formal APA-style statistical narration for significance testing results.
# This is deterministic, reproducible, and requires no API calls.
#
# This is NOT AI-generated content — it is rule-based narration from the
# easystats report() function. No AI label is needed.
#
# Functions:
#   generate_apa_narration()      — APA narration for a question's sig results
#   generate_all_apa_narrations() — batch narration for all questions
#   build_apa_narration_panel()   — HTML rendering for narration
#
# Dependencies:
#   easystats/report (CRAN) — APA-style reporting
#   stats (base R)          — chi-squared test
#
# Config:
#   config$ai_insights$easystats_narration = TRUE/FALSE
#
# Usage:
#   source("modules/tabs/lib/ai/ai_easystats.R")
#   narration <- generate_apa_narration(q_result, banner_info)
#
# ==============================================================================


# --- Constants ----------------------------------------------------------------
APA_MIN_BASE_SIZE <- 30L
APA_ALPHA_DEFAULT <- 0.05


#' Generate APA-style narration for a single question
#'
#' Analyses the crosstab data for a question and produces a formal
#' statistical description. Uses chi-squared test of independence
#' for categorical data. Returns NULL if the question type is not
#' suitable or base sizes are too small.
#'
#' @param q_result List. A single question's result from all_results.
#' @param banner_info List. Banner structure.
#' @param alpha Numeric. Significance level (default: 0.05).
#'
#' @return List with:
#'   \item{narration}{Character. APA-style text.}
#'   \item{test_type}{Character. Type of test applied.}
#'   \item{significant}{Logical. Whether the test was significant.}
#'   Or NULL if narration cannot be generated.
generate_apa_narration <- function(q_result, banner_info,
                                   alpha = APA_ALPHA_DEFAULT) {

  if (!requireNamespace("report", quietly = TRUE)) {
    return(NULL)
  }

  if (is.null(q_result) || is.null(q_result$table)) return(NULL)

  table <- q_result$table
  if (nrow(table) == 0) return(NULL)

  # Only handle categorical data (Single_Response, Likert, etc.)
  q_type <- q_result$question_type %||% ""
  if (q_type %in% c("Numeric", "Open_End")) return(NULL)

  # Get frequency rows
  freq_rows <- table[!is.na(table$RowType) & table$RowType == "Frequency", , drop = FALSE]
  if (nrow(freq_rows) == 0) return(NULL)

  # Identify banner columns (exclude Total)
  all_keys <- banner_info$internal_keys
  banner_keys <- setdiff(all_keys, "TOTAL::Total")
  available_keys <- intersect(banner_keys, names(table))
  if (length(available_keys) < 2) return(NULL)

  key_to_display <- banner_info$key_to_display

  # Check base sizes
  if (!is.null(q_result$bases)) {
    for (key in available_keys) {
      base_entry <- q_result$bases[[key]]
      base_n <- if (is.list(base_entry)) {
        base_entry$unweighted %||% base_entry$weighted %||% 0
      } else if (is.numeric(base_entry)) {
        base_entry
      } else {
        0
      }
      if (base_n < APA_MIN_BASE_SIZE) return(NULL)
    }
  }

  # Build contingency table
  response_labels <- freq_rows$RowLabel
  col_labels <- sapply(available_keys, function(k) {
    key_to_display[[k]] %||% sub("^.*::", "", k)
  })

  freq_matrix <- matrix(NA, nrow = nrow(freq_rows), ncol = length(available_keys))
  for (j in seq_along(available_keys)) {
    vals <- as.numeric(freq_rows[[available_keys[j]]])
    freq_matrix[, j] <- vals
  }

  # Remove rows/cols with all zeros or NAs
  valid_rows <- apply(freq_matrix, 1, function(r) all(!is.na(r)) && sum(r) > 0)
  valid_cols <- apply(freq_matrix, 2, function(c) all(!is.na(c)) && sum(c) > 0)
  if (sum(valid_rows) < 2 || sum(valid_cols) < 2) return(NULL)

  freq_matrix <- freq_matrix[valid_rows, valid_cols, drop = FALSE]
  row_labs <- response_labels[valid_rows]
  col_labs <- col_labels[valid_cols]

  rownames(freq_matrix) <- row_labs
  colnames(freq_matrix) <- col_labs

  # Run chi-squared test
  chi_result <- tryCatch({
    suppressWarnings(stats::chisq.test(freq_matrix))
  }, error = function(e) NULL)

  if (is.null(chi_result)) return(NULL)

  # Generate APA narration using report package
  narration_text <- tryCatch({
    rpt <- report::report(chi_result)
    as.character(rpt)
  }, error = function(e) {
    # Fallback: manual APA formatting
    sprintf(
      "A chi-squared test of independence was performed to examine the relationship between response categories and %s. The test was %s, X2(%d, N = %d) = %.2f, p %s %.3f.",
      paste(col_labs, collapse = "/"),
      if (chi_result$p.value < alpha) "statistically significant" else "not statistically significant",
      chi_result$parameter,
      sum(freq_matrix),
      chi_result$statistic,
      if (chi_result$p.value < 0.001) "<" else "=",
      if (chi_result$p.value < 0.001) 0.001 else chi_result$p.value
    )
  })

  list(
    narration   = narration_text,
    test_type   = "chi-squared",
    significant = chi_result$p.value < alpha,
    p_value     = chi_result$p.value,
    statistic   = chi_result$statistic,
    df          = chi_result$parameter
  )
}


#' Generate APA narrations for all questions
#'
#' Batch processor: runs generate_apa_narration() for each question in
#' all_results and returns a named list of narrations.
#'
#' @param all_results Named list. Full analysis results.
#' @param banner_info List. Banner structure.
#' @param alpha Numeric. Significance level.
#'
#' @return Named list keyed by q_code. Each element is a narration list or NULL.
generate_all_apa_narrations <- function(all_results, banner_info,
                                        alpha = APA_ALPHA_DEFAULT) {
  narrations <- list()

  for (q_code in names(all_results)) {
    narr <- tryCatch(
      generate_apa_narration(all_results[[q_code]], banner_info, alpha),
      error = function(e) NULL
    )
    if (!is.null(narr)) {
      narrations[[q_code]] <- narr
    }
  }

  narrations
}


#' Build HTML panel for APA narration
#'
#' Renders a distinct panel for the statistical narration — not styled as
#' AI content because it is deterministic and rule-based.
#'
#' @param narration List. Output of generate_apa_narration().
#' @param q_code Character. Question code.
#'
#' @return Character. HTML string, or empty string if no narration.
build_apa_narration_panel <- function(narration, q_code) {

  if (is.null(narration) || !nzchar(narration$narration %||% "")) return("")

  # Escape HTML in narration text
  narr_text <- narration$narration
  narr_text <- gsub("&", "&amp;", narr_text, fixed = TRUE)
  narr_text <- gsub("<", "&lt;", narr_text, fixed = TRUE)
  narr_text <- gsub(">", "&gt;", narr_text, fixed = TRUE)

  sprintf(
    '<div class="turas-apa-narration" data-q-code="%s">
  <div class="apa-narration-label">Statistical test</div>
  <div class="apa-narration-body">%s</div>
</div>',
    q_code, narr_text
  )
}


#' Build CSS for APA narration panels
#'
#' @return Character. CSS string.
build_apa_narration_css <- function() {
  '
/* === APA Statistical Narration (deterministic, not AI) === */
.turas-apa-narration {
  background: var(--ct-bg-surface, #fafbfc);
  border-left: 3px solid var(--ct-text-tertiary, #8a8a9a);
  border-radius: var(--ct-radius-md, 6px);
  padding: 10px 16px;
  margin: 6px 0 12px 0;
  font-size: 12px;
  line-height: 1.6;
  color: var(--ct-text-secondary, #555566);
  font-style: italic;
}
.turas-apa-narration .apa-narration-label {
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 1px;
  text-transform: uppercase;
  color: var(--ct-text-tertiary, #8a8a9a);
  margin-bottom: 4px;
  font-style: normal;
}
@media print {
  .turas-apa-narration { break-inside: avoid; }
}
'
}

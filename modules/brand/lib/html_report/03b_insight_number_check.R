# ==============================================================================
# BRAND HTML REPORT - AUTHORED INSIGHT NUMBER CHECK
# ==============================================================================
# Analyst-authored insights come from the Section_Insights sheet in the brand
# config workbook (R/01b_section_insights.R). They are typed once and survive
# every re-run, which is the point of them and also the risk: a sentence that
# was true when it was written can be left standing above a table whose
# figures have since moved.
#
# That happened on a real IPK report. The funnel moved to the nested chain,
# so the Dry Seasonings table read aware 42, prefer 35, past 12m 22, past 3m
# 16, while the insight above it still read "Aware 42%, prefer 59%, past 12m
# 31%, past 3m 20% ... Prefer (59%) exceeds aware (42%) by 17pp". Every
# figure past the first was the old absolute view and the last sentence
# asserted something the table below it visibly contradicted.
#
# This file checks, for each authored insight, that every figure it cites
# appears in the data of the section it is anchored to. It never refuses a
# run: an analyst's wording is not a data error, and a brand run that dies
# because a sentence is stale is worse than the stale sentence. A flagged
# insight produces three things, in this order of visibility:
#
#   1. a console box, because Turas runs inside a Shiny app and the operator
#      debugs from the R console;
#   2. a run warning, spliced into generate_brand_html_report()'s $warnings,
#      which is what brand_gui_outcome() shows the operator;
#   3. a marker rendered inside the insight box in the HTML itself, so the
#      reader of the report knows the sentence was not checked out.
#
# ------------------------------------------------------------------------------
# DESIGN DECISIONS (see docs/v2_lift/NOTES_BRAND_INSIGHT_NUMBER_CHECK.md)
# ------------------------------------------------------------------------------
#
# THE COMPARISON is deterministic_number_check() + extract_all_numbers() from
# modules/shared/lib/ai/ai_verify.R, the same pair the tabs reader report uses
# for AI prose. Nothing here re-implements number extraction or matching. The
# shared pool argument must be a clean, finite numeric vector: the helper does
# any(abs(pool - n) < tol), and one NA in the pool makes that NA and the check
# throws. Same reason reader_ai_prose.R filters its pool.
#
# THE TOLERANCE is the shared helper's 0.6. The brand tables render a
# percentage with sprintf("%.0f%%", ...), so the largest honest gap between a
# stored figure and the figure a reader sees is 0.5. An insight saying 42%
# against a stored 41.7 is correct and passes. 0.6 leaves a tenth of slack for
# an analyst who read the figure off an export at one decimal.
#
# THE POOL IS SCOPED to the section the insight is anchored to, because that
# is the table the sentence sits above. Cross-cutting anchors (the executive
# summary, the summary cards, the project background) are NOT checked: they
# quote figures from anywhere in the report by design, so a section pool would
# fire on every sentence and a report-wide pool would pass every sentence.
# Skipping them is stated in the log rather than pretended away.
#
# THE FUNNEL POOL IS THE VIEW THE REPORT OPENS ON, not every view the toggle
# can reach. The funnel carries four views of the same counts, and matching
# any of them would have passed the 59 in the case above, because 59 is a real
# figure in the absolute view. It is a real figure the reader cannot see. The
# nested chain is what the page opens on, so that is what the sentence above
# it is read against. The values come from .fn_chain_pct() and
# .fn_chain_stats_by_stage() in panels/03_funnel_panel_table.R, the same two
# helpers the table itself is rendered with, so the check and the table can
# never drift apart.
#
# NOT EVERY NUMBER IN A SENTENCE IS A CLAIM ABOUT THAT SECTION. A check that
# fires constantly is ignored, so four kinds of number are left alone:
#   * 0 to 10 and exactly 100, which the shared helper already skips. Covers
#     "top 3", "wave 2", ranks, and a difference of a few points.
#   * a four-digit number in 1900..2100, read as a year. A percentage is never
#     four digits. A base that happens to be 2000 is skipped too, which errs
#     towards saying nothing rather than crying wolf.
#   * a number carrying a difference unit: 17pp, 17 ppt, 17 pts, 17 points,
#     17 percentage points. A difference is derived from two figures, it is
#     not itself a figure in the table, and pooling every pairwise difference
#     to accept it would make the pool cover almost every integer and gut the
#     check. The two levels the difference is drawn from are still checked,
#     which is what caught the real case.
#   * a base quoted inline: n=1,200 or "base of 1,200". Analysts quote a base
#     from elsewhere in the report often enough that it is not worth flagging.
#
# THOUSANDS SEPARATORS are stripped before the shared helper sees the text.
# Its regex would read "1,200" as 1 and 200. Percentages, decimals and signs
# it already handles.
#
# VERSION: 1.0
# ==============================================================================

BRAND_INSIGHT_NUMBER_CHECK_VERSION <- "1.0"

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


# ==============================================================================
# SHARED HELPER ACCESS
# ==============================================================================

#' Make sure the shared deterministic number check is loaded
#'
#' modules/shared/lib/ai/ai_verify.R is not on any brand source path: the
#' brand suite and acceptance_check.R source modules/shared/lib/*.R without
#' recursing into ai/. Source it on demand, and never let a failure to find
#' it stop a report.
#'
#' @return TRUE when both shared functions are callable, FALSE otherwise.
#' @keywords internal
.bin_ensure_shared_check <- function() {
  if (exists("deterministic_number_check", mode = "function") &&
      exists("extract_all_numbers", mode = "function")) return(TRUE)

  roots <- unique(Filter(nzchar, c(
    Sys.getenv("TURAS_ROOT", ""),
    tryCatch(if (exists("find_turas_root", mode = "function"))
      find_turas_root() else "", error = function(e) ""),
    getwd()
  )))
  for (r in roots) {
    fp <- file.path(r, "modules", "shared", "lib", "ai", "ai_verify.R")
    if (file.exists(fp)) {
      tryCatch(source(fp, local = FALSE), error = function(e) NULL)
      if (exists("deterministic_number_check", mode = "function") &&
          exists("extract_all_numbers", mode = "function")) return(TRUE)
    }
  }
  FALSE
}


# ==============================================================================
# TEXT PREPARATION
# ==============================================================================

#' Prepare authored insight text for the shared number check
#'
#' Strips thousands separators, then blanks the digits of every number that is
#' not a claim about this section's data (years, differences carrying a pp /
#' points unit, inline bases). The blanked numbers are replaced with a letter,
#' so the shared extractor cannot see them and no two neighbouring figures are
#' joined into one.
#'
#' @param txt Character scalar. The authored insight.
#' @return Character scalar, ready for deterministic_number_check().
#' @keywords internal
.bin_prepare_text <- function(txt) {
  if (is.null(txt) || is.na(txt) || !nzchar(txt)) return("")
  s <- as.character(txt)

  # 1,200 -> 1200. Repeated so 1,234,567 collapses fully.
  for (i in 1:3) s <- gsub("(\\d),(\\d{3})(?![\\d])", "\\1\\2", s, perl = TRUE)

  # An inline base: n=1200, n = 1200, base of 1200, base 1200.
  s <- gsub("(\\bn\\s*=\\s*)-?\\d+(?:\\.\\d+)?", "\\1nn", s,
            perl = TRUE, ignore.case = TRUE)
  s <- gsub("(\\bbase\\s+(?:of\\s+)?)-?\\d+(?:\\.\\d+)?", "\\1nn", s,
            perl = TRUE, ignore.case = TRUE)

  # A difference carrying its unit: 17pp, 17 ppt, -7 pts, 17 points,
  # 17 percentage points.
  s <- gsub(
    "(?<![\\d.])-?\\d+(?:\\.\\d+)?(?=\\s*(?:pp|ppt|pts|percentage\\s+points|points)\\b)",
    "dd", s, perl = TRUE, ignore.case = TRUE)

  # A four-digit year. A percentage is never four digits. The lookarounds keep
  # 21999 and the 1999 inside 1999.5 out of it, while still masking a year
  # that ends a sentence: the trailing guard rejects an optional dot only when
  # a digit follows it.
  s <- gsub("(?<![\\d.])(?:19|20)\\d{2}(?!\\.?\\d)", "yyyy", s, perl = TRUE)

  s
}


#' Pull the offending figures out of the shared helper's issues string
#'
#' deterministic_number_check() reports its unmatched figures as one formatted
#' sentence. This reads them back so the warning, the console box and the HTML
#' marker can name them. test_insight_number_check.R locks this parse, so a
#' change to the shared message breaks a test rather than silently emitting an
#' empty marker.
#'
#' @param issues Character scalar from deterministic_number_check()$issues.
#' @return Character vector of figures as written, or character(0).
#' @keywords internal
.bin_parse_issue_figures <- function(issues) {
  if (is.null(issues) || length(issues) == 0L) return(character(0))
  s <- as.character(issues)[1]
  if (is.na(s) || !nzchar(s)) return(character(0))
  tail_part <- sub("^.*not in source data:\\s*", "", s)
  if (identical(tail_part, s)) return(character(0))
  parts <- trimws(strsplit(tail_part, ",", fixed = TRUE)[[1]])
  parts <- parts[nzchar(parts)]
  ok <- !is.na(suppressWarnings(as.numeric(parts)))
  if (!all(ok)) return(character(0))
  parts
}


# ==============================================================================
# NUMBER POOLS
# ==============================================================================

#' Clean a numeric pool for the shared check
#'
#' Drops non-finite values (the shared comparison returns NA on any NA in the
#' pool and the check then throws) and adds the percentage form of every
#' proportion, because the engine stores 0.42 where the table prints 42%.
#'
#' @keywords internal
.bin_clean_pool <- function(v) {
  v <- suppressWarnings(as.numeric(v))
  v <- v[is.finite(v)]
  if (length(v) == 0L) return(numeric(0))
  prop <- v[v >= 0 & v <= 1]
  unique(c(v, prop * 100))
}


#' Every finite number reachable inside a results sub-object
#' @keywords internal
.bin_generic_pool <- function(x) {
  if (is.null(x)) return(numeric(0))
  vals <- tryCatch(extract_all_numbers(x), error = function(e) numeric(0))
  .bin_clean_pool(vals)
}


#' The funnel's pool: the view the report opens on
#'
#' Built from the same panel data the funnel panel is rendered from, and
#' through the same two helpers, so the pool holds exactly the figures on
#' screen when the page loads. Carries, for every brand and stage: the nested
#' chain percentage, its unweighted count (the n= under the cell), the stage's
#' own unweighted base, and the category-average row's mean and its two range
#' bar bounds. Plus the panel's weighted and unweighted respondent totals.
#'
#' @param funnel List. cat_results$funnel from run_brand().
#' @return Numeric vector, empty when the funnel cannot be read.
#' @keywords internal
.bin_funnel_pool <- function(funnel) {
  if (is.null(funnel) || identical(funnel$status, "REFUSED")) return(numeric(0))
  if (is.null(funnel$stages) || nrow(funnel$stages) == 0) return(numeric(0))
  if (!exists(".panel_table", mode = "function") ||
      !exists(".fn_chain_pct", mode = "function") ||
      !exists(".fn_chain_stats_by_stage", mode = "function")) {
    return(numeric(0))
  }

  # .panel_table() rather than the whole build_funnel_panel_data(): it is the
  # builder of the cells the funnel table renders from, and it needs nothing
  # from the attitude pipeline that the cards half of the panel data pulls in.
  # A minimal brand list is enough, because the cells the pool reads carry
  # counts and percentages, none of which depend on a brand's label.
  codes <- unique(as.character(funnel$stages$brand_code))
  brand_df <- data.frame(BrandCode = codes, BrandLabel = codes,
                         stringsAsFactors = FALSE)
  stage_keys <- funnel$meta$stage_keys %||%
                unique(as.character(funnel$stages$stage_key))
  tbl <- tryCatch(.panel_table(funnel, brand_df, stage_keys, config = list()),
                  error = function(e) NULL)
  if (is.null(tbl) || length(tbl$cells) == 0) return(numeric(0))
  pd <- list(table = tbl, meta = funnel$meta)

  n_weighted <- suppressWarnings(as.numeric(pd$meta$n_weighted %||% NA_real_))
  vals <- numeric(0)

  # base_chain_unweighted is the count the nested cell prints under its
  # figure. base_unweighted, the stage's own raw count, is deliberately left
  # out: it belongs to the absolute view and is not on screen here. The base
  # row above the table prints the panel's n_unweighted, added below.
  n_pct <- 0L
  for (cell in pd$table$cells) {
    chain <- .fn_chain_pct(cell, n_weighted)
    if (is.finite(chain)) {
      vals <- c(vals, 100 * chain)
      n_pct <- n_pct + 1L
    }
    vals <- c(vals,
              suppressWarnings(as.numeric(cell$base_chain_unweighted %||% NA_real_)))
  }
  # No nested percentage means the view the page opens on could not be
  # reconstructed. A pool of counts alone would flag every percentage in the
  # sentence, so the section is left unchecked instead.
  if (n_pct == 0L) return(numeric(0))

  stats_by_stage <- tryCatch(
    .fn_chain_stats_by_stage(pd$table$cells, pd$table$stage_keys,
                             pd$table$brand_codes, n_weighted),
    error = function(e) list())
  for (st in stats_by_stage) {
    vals <- c(vals, 100 * c(st$mean %||% NA_real_, st$ci_lo %||% NA_real_,
                            st$ci_hi %||% NA_real_, st$col_max %||% NA_real_))
  }

  vals <- c(vals, n_weighted,
            suppressWarnings(as.numeric(pd$meta$n_unweighted %||% NA_real_)))

  v <- vals[is.finite(vals)]
  if (length(v) == 0L) return(numeric(0))
  unique(v)
}


#' Split an anchor into its element and category parts
#'
#' Anchors are element-catid, e.g. funnel-dss, ceps-pas, advantage-pas. The
#' category id is the lower-cased CategoryCode with non-alphanumerics
#' hyphenated, so an element name that itself contains a hyphen would be
#' ambiguous; every element key here is hyphen-free, and the split takes the
#' first hyphen.
#'
#' @keywords internal
.bin_split_anchor <- function(anchor) {
  a <- as.character(anchor)
  pos <- regexpr("-", a, fixed = TRUE)
  if (pos < 1) return(list(element = a, cat_id = ""))
  list(element = substr(a, 1, pos - 1), cat_id = substr(a, pos + 1, nchar(a)))
}


# Anchors that quote figures from anywhere in the report by design. Not
# checked; named in the console line so nobody thinks they were.
.BIN_CROSS_CUTTING <- c("_EXECUTIVE_SUMMARY", "_BACKGROUND", "summary-cards",
                        "brsum-insight")

# Element anchor -> the category result field its section is drawn from.
# funnel and attitude are absent on purpose: funnel has its own view-scoped
# pool above, and attitude is the decomposition inside the funnel result
# rather than the funnel's own stage figures.
.BIN_ELEMENT_FIELD <- c(
  attributes    = "mental_availability",
  ceps          = "mental_availability",
  advantage     = "mental_availability",
  metrics       = "mental_availability",
  repertoire    = "repertoire",
  wom           = "wom",
  branded_reach = "branded_reach",
  demographics  = "demographics",
  adhoc         = "adhoc",
  audience_lens = "audience_lens"
)


#' Find a category result by its anchor's category id
#' @keywords internal
.bin_category_for <- function(results, cat_id) {
  cats <- results$results$categories
  if (is.null(cats) || length(cats) == 0L) return(NULL)
  for (key in names(cats)) {
    cr <- cats[[key]]
    id <- gsub("[^a-z0-9]", "-", tolower(cr$cat_code %||% key))
    if (identical(id, cat_id)) return(cr)
  }
  NULL
}


#' The number pool for one section anchor
#'
#' @param anchor Character. Section anchor id, e.g. "funnel-dss".
#' @param results List. The run_brand() result.
#' @return List with `pool` (numeric), `view` (character, the view the pool
#'   was built at, or "") and `checked` (logical). checked = FALSE means the
#'   anchor has no data mapping and the insight is left alone.
#' @keywords internal
brand_insight_pool_for <- function(anchor, results) {
  none <- list(pool = numeric(0), view = "", checked = FALSE)
  if (is.null(anchor) || is.na(anchor) || !nzchar(anchor)) return(none)
  if (anchor %in% .BIN_CROSS_CUTTING) return(none)

  if (startsWith(anchor, "pf-")) {
    pool <- .bin_clean_pool(c(
      .bin_generic_pool(results$results$portfolio),
      .bin_generic_pool(results$results$portfolio_overview)))
    if (length(pool) == 0L) return(none)
    return(list(pool = pool, view = "", checked = TRUE))
  }

  parts <- .bin_split_anchor(anchor)
  el <- parts$element
  cr <- .bin_category_for(results, parts$cat_id)
  if (is.null(cr)) return(none)

  if (identical(el, "funnel")) {
    pool <- .bin_funnel_pool(cr$funnel)
    if (length(pool) == 0L) return(none)
    return(list(pool = pool, view = "the nested funnel, the view this page opens on",
                checked = TRUE))
  }

  # The Brand Attitude sub-tab renders the attitude decomposition, not the
  # funnel's stage figures, so its pool is that block plus the panel's bases.
  # Pooling the whole funnel result here would quietly let an absolute-view
  # stage figure pass on a sub-tab that never shows one.
  if (identical(el, "attitude")) {
    pool <- .bin_generic_pool(list(cr$funnel$attitude_decomposition,
                                   cr$funnel$meta))
    if (length(pool) == 0L) return(none)
    return(list(pool = pool, view = "", checked = TRUE))
  }

  field <- .BIN_ELEMENT_FIELD[[el]]
  if (is.null(field)) return(none)

  src <- cr[[field]]
  if (is.null(src)) return(none)
  # Category Buying draws on the Dirichlet blocks alongside the repertoire.
  if (identical(el, "repertoire")) {
    src <- list(src, cr$cat_buying_frequency, cr$brand_volume,
                cr$dirichlet_norms, cr$buyer_heaviness, cr$buying_location)
  }
  pool <- .bin_generic_pool(src)
  if (length(pool) == 0L) return(none)
  list(pool = pool, view = "", checked = TRUE)
}


# ==============================================================================
# THE CHECK
# ==============================================================================

#' Check every authored insight's figures against its own section's data
#'
#' Never throws and never refuses. An anchor with no data mapping, an
#' unreadable section, or a missing shared helper all mean the insight is left
#' alone rather than reported wrongly.
#'
#' @param section_insights Named character vector (anchor to text), or NULL.
#' @param results List. The run_brand() result.
#'
#' @return List with:
#'   \item{findings}{Named list, one entry per flagged anchor, each with
#'     `anchor`, `figures` (character vector) and `view` (character).}
#'   \item{checked}{Character vector of anchors that were checked.}
#'   \item{skipped}{Character vector of anchors with no data mapping.}
#'
#' @export
check_brand_section_insights <- function(section_insights, results) {
  empty <- list(findings = list(), checked = character(0),
                skipped = character(0))
  if (is.null(section_insights) || length(section_insights) == 0L) return(empty)
  if (is.null(results)) return(empty)
  if (!.bin_ensure_shared_check()) {
    cat("  [INFO] Insight number check skipped: the shared deterministic",
        "check could not be loaded\n")
    return(empty)
  }

  findings <- list()
  checked <- character(0)
  skipped <- character(0)

  for (anchor in names(section_insights)) {
    text <- section_insights[[anchor]]
    if (is.null(text) || is.na(text) || !nzchar(trimws(text))) next

    got <- tryCatch(brand_insight_pool_for(anchor, results),
                    error = function(e) list(pool = numeric(0), view = "",
                                             checked = FALSE))
    if (!isTRUE(got$checked)) { skipped <- c(skipped, anchor); next }

    chk <- tryCatch(
      deterministic_number_check(.bin_prepare_text(text), got$pool),
      error = function(e) list(pass = TRUE, issues = NULL))
    checked <- c(checked, anchor)
    if (isTRUE(chk$pass)) next

    figs <- .bin_parse_issue_figures(chk$issues)
    findings[[anchor]] <- list(anchor = anchor, figures = figs,
                               view = got$view %||% "")
  }

  list(findings = findings, checked = checked, skipped = skipped)
}


# ==============================================================================
# REPORTING: CONSOLE, RUN WARNINGS, HTML MARKER
# ==============================================================================

#' One sentence naming an anchor's offending figures
#' @keywords internal
.bin_finding_sentence <- function(finding) {
  figs <- finding$figures
  fig_txt <- if (length(figs) == 0L) "one or more figures" else
    paste(figs, collapse = ", ")
  view_txt <- if (nzchar(finding$view %||% ""))
    sprintf(" on %s", finding$view) else ""
  sprintf("%s does not appear in this section's data%s", fig_txt, view_txt)
}


#' Run warnings, one per flagged anchor
#'
#' Spliced into generate_brand_html_report()'s $warnings, which is the list
#' brand_gui_outcome() puts in front of the operator.
#'
#' @param check Result of check_brand_section_insights().
#' @return Character vector, empty when nothing was flagged.
#' @export
brand_insight_check_warnings <- function(check) {
  if (is.null(check) || length(check$findings) == 0L) return(character(0))
  vapply(check$findings, function(f) sprintf(
    "authored insight on section %s cites a figure the section does not carry: %s",
    f$anchor, .bin_finding_sentence(f)), character(1), USE.NAMES = FALSE)
}


#' Print the console box for a flagged run
#'
#' Turas runs inside a Shiny app and the operator reads the R console, so the
#' box has to stand out in a scrolling log. Matches the shape in CLAUDE.md.
#'
#' @param check Result of check_brand_section_insights().
#' @return Invisible NULL. Prints nothing when nothing was flagged.
#' @export
brand_insight_check_console <- function(check) {
  if (is.null(check) || length(check$findings) == 0L) return(invisible(NULL))
  cat("\n+--- TURAS BRAND: AUTHORED INSIGHT NUMBER CHECK ---------+\n")
  cat("| An insight typed into the Section_Insights sheet cites a\n")
  cat("| figure that is not in the data of the section it sits on.\n")
  cat("| The report was still written. Edit the sheet and re-run.\n")
  cat("|\n")
  for (f in check$findings) {
    cat(sprintf("| Section: %s\n", f$anchor))
    cat(sprintf("|   Figures not found: %s\n",
                if (length(f$figures) == 0L) "one or more, see the report marker"
                else paste(f$figures, collapse = ", ")))
    if (nzchar(f$view %||% ""))
      cat(sprintf("|   Read against: %s\n", f$view))
  }
  cat("|\n")
  cat("| How to fix: open the Section_Insights sheet in the brand\n")
  cat("| config workbook, correct the sentence for that section,\n")
  cat("| and generate the report again.\n")
  cat("+--------------------------------------------------------+\n\n")
  invisible(NULL)
}


#' The HTML marker for one section's insight box
#'
#' Rendered inside the insight container so the reader of the report sees it
#' next to the sentence, not only the operator in a terminal. Neutral wording:
#' the check reports what it could not find, it does not call the analyst
#' wrong.
#'
#' @param check Result of check_brand_section_insights(), or NULL.
#' @param anchor Character. Section anchor id.
#' @return Character scalar. "" when the section was not flagged.
#' @export
brand_insight_check_note <- function(check, anchor) {
  if (is.null(check) || length(check$findings %||% list()) == 0L) return("")
  if (is.null(anchor) || is.na(anchor) || !nzchar(anchor)) return("")
  f <- check$findings[[anchor]]
  if (is.null(f)) return("")

  figs <- f$figures
  fig_txt <- if (length(figs) == 0L) "A figure in this note" else
    sprintf("%s in this note", paste(figs, collapse = ", "))
  view_txt <- if (nzchar(f$view %||% ""))
    sprintf(" on %s", f$view) else ""
  esc <- if (exists(".br_esc", mode = "function")) .br_esc else function(x) x

  sprintf(paste0(
    '<div class="br-insight-check" data-section="%s" ',
    'style="margin-top:8px;padding:8px 10px;border-left:3px solid #d97706;',
    'background:#fffbeb;border-radius:0 4px 4px 0;font-size:12px;',
    'line-height:1.5;color:#78350f;">',
    '<strong>Number check.</strong> %s could not be found in this ',
    'section&#39;s data%s. Read the note against the table below before ',
    'this report goes out.',
    '</div>'),
    esc(as.character(anchor)), esc(fig_txt), esc(view_txt))
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand insight number check loaded (v%s)",
                  BRAND_INSIGHT_NUMBER_CHECK_VERSION))
}

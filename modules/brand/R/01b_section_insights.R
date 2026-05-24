# ==============================================================================
# BRAND MODULE - SECTION INSIGHTS LOADER
# ==============================================================================
# Optional persistence layer for the per-panel "+ Add Insight" editors that
# the brand HTML report renders. Loads a `Section_Insights` sheet from the
# brand config workbook, maps friendly Category + Section labels to the raw
# data-section anchor IDs used in the HTML, and exposes the result as
# config$section_insights — a named character vector keyed by anchor ID,
# values are the insight text (markdown supported).
#
# Mirror of tabs/lib/crosstabs/crosstabs_config.R::load_comments_sheet()
# pattern so the platform stays consistent: edit insights once in the config,
# rerun the report any number of times without losing them.
#
# Sheet shape (all optional except Section + Insight):
#
#   Category | Section             | Insight                 | Order | Author | Date
#   ---------|---------------------|-------------------------|-------|--------|------
#   _REPORT  | Executive Summary   | One-line topline...     | 0     | DB     | 2026-05-24
#   _REPORT  | Portfolio Overview  | IPK reaches every cat...| 1     | DB     | 2026-05-24
#   POS      | Brand Funnel        | Best funnel in the...   | 5     | DB     | 2026-05-24
#   POS      | Mental Advantage    | Closest gaps of any...  | 6     | DB     | 2026-05-24
#
# Reserved Category code:
#   _REPORT — cross-cutting sections that aren't per-category
#             (Executive Summary, Background, Portfolio sub-tabs).
#
# Reserved Section codes (case-insensitive on lookup):
#   Executive Summary           → _EXECUTIVE_SUMMARY (renders in brsum-insight)
#   Background                  → _BACKGROUND        (renders in About tab)
#   Portfolio Overview          → pf-overview
#   Portfolio Category Context  → pf-clutter
#   Portfolio Competitive Set   → pf-constellation
#   Portfolio Footprint         → pf-footprint
#
# Per-category Section labels (Category column = CategoryCode, e.g. POS):
#   Brand Funnel        → funnel-{cat}
#   Mental Advantage    → ma-{cat}
#   Category Buying     → repertoire-{cat}
#   Word of Mouth       → wom-{cat}
#   Branded Reach       → branded_reach-{cat}
#   Demographics        → demographics-{cat}
#   Ad Hoc              → adhoc-{cat}
#   Audience Lens       → audience_lens-{cat}
#
# Analysts may also enter the raw anchor ID in the Section column directly;
# the resolver passes through anything it doesn't recognise as a friendly
# label, which means new sections work without a code change.
#
# VERSION: 1.0
#
# DEPENDENCIES:
# - openxlsx
# - modules/brand/R/01_config.R
# ==============================================================================

BRAND_SECTION_INSIGHTS_VERSION <- "1.0"


# Cross-cutting (Category = _REPORT) friendly-to-anchor map
.BRAND_REPORT_SECTION_MAP <- list(
  "executive summary"          = "_EXECUTIVE_SUMMARY",
  "background"                 = "_BACKGROUND",
  "portfolio overview"         = "pf-overview",
  "portfolio category context" = "pf-clutter",
  "portfolio competitive set"  = "pf-constellation",
  "portfolio footprint"        = "pf-footprint"
)

# Per-category friendly-to-element map. Anchor = element-{cat_id} where
# cat_id is the lower-cased CategoryCode with non-alphanumerics replaced
# by hyphens — same rule as build_br_category_panel() in 03_page_builder.R.
#
# v1.1: Funnel + Mental Availability now have per-sub-tab anchors so the
# analyst can write a distinct insight on each sub-tab. The element keys
# below match the data-internal-tab attribute used by switchCategorySubtab
# in brand_report.js. Names chosen to match the visible UI label where
# possible (Brand Attitude → attitude, not relationship).
.BRAND_CATEGORY_SECTION_MAP <- list(
  # Brand Funnel panel sub-tabs
  "brand funnel"           = "funnel",        # Brand Funnel sub-tab
  "brand attitude"         = "attitude",      # Brand Attitude sub-tab
  "attitude"               = "attitude",
  # Mental Availability panel sub-tabs
  "brand attributes"       = "attributes",    # Brand Attributes sub-tab
  "attributes"             = "attributes",
  "category entry points"  = "ceps",          # CEPs sub-tab
  "ceps"                   = "ceps",
  "mental advantage"       = "advantage",     # Mental Advantage sub-tab
  "advantage"              = "advantage",
  "ma metrics"             = "metrics",       # Headline Metrics sub-tab
  "headline metrics"       = "metrics",
  "metrics"                = "metrics",
  # Category Buying — single tab today
  "category buying"        = "repertoire",
  "cat buying"             = "repertoire",
  "repertoire"             = "repertoire",
  # Other element panels
  "word of mouth"          = "wom",
  "wom"                    = "wom",
  "branded reach"          = "branded_reach",
  "demographics"           = "demographics",
  "ad hoc"                 = "adhoc",
  "adhoc"                  = "adhoc",
  "audience lens"          = "audience_lens"
)

# Internal-tab aliases. The brand_report.js sub-tab switcher uses these
# names in data-internal-tab attributes. The page builder maps each
# friendly label above to one of these so the insight toolbar tags itself
# with the right internal tab and the JS shows/hides correctly.
#
# Note "attitude" → JS uses "relationship" historically; we expose
# "attitude" as the anchor name (matches the UI label) and translate to
# the JS internal-tab name at render time.
.BRAND_ELEMENT_TO_INTERNAL_TAB <- c(
  funnel       = "funnel",
  attitude     = "relationship",
  attributes   = "attributes",
  ceps         = "ceps",
  advantage    = "advantage",
  metrics      = "metrics"
)

# Which sub-panel (subpanel key in build_br_category_panel) each element
# anchor belongs to. Used by the page builder to emit toolbars in the
# right wrapper.
.BRAND_ELEMENT_TO_SUBPANEL <- c(
  funnel     = "fn",
  attitude   = "fn",
  attributes = "ma",
  ceps       = "ma",
  advantage  = "ma",
  metrics    = "ma"
)


#' Convert a CategoryCode to the cat_id used in HTML anchor IDs
#'
#' Matches the rule in build_br_category_panel() in
#' modules/brand/lib/html_report/03_page_builder.R — lower-case the code
#' and replace non-alphanumerics with hyphens.
#'
#' @keywords internal
.brand_cat_id <- function(cat_code) {
  gsub("[^a-z0-9]", "-", tolower(as.character(cat_code)))
}


#' Resolve a (Category, Section) pair to a raw anchor ID
#'
#' @param category Character. CategoryCode (e.g. "POS"), reserved "_REPORT",
#'   or blank/NA (treated as _REPORT).
#' @param section Character. Either a friendly section label
#'   (e.g. "Brand Funnel") or a raw anchor ID (e.g. "funnel-pos"). Anything
#'   not recognised as a friendly label is passed through unchanged so
#'   future sections work without a code change.
#'
#' @return Character. The resolved anchor ID, or NA when input is unusable.
#'
#' @keywords internal
.brand_section_anchor <- function(category, section) {
  if (is.null(section) || is.na(section) || !nzchar(trimws(as.character(section))))
    return(NA_character_)
  sec_raw <- trimws(as.character(section))
  sec_key <- tolower(sec_raw)

  cat_raw <- if (is.null(category) || is.na(category)) "" else trimws(as.character(category))
  is_report <- !nzchar(cat_raw) || identical(toupper(cat_raw), "_REPORT")

  # Pass through raw anchor IDs (start with reserved prefix or contain a hyphen
  # that looks like an element-cat pattern). Anything unrecognised goes through
  # unchanged so the loader is permissive — analysts can type the raw anchor
  # directly when they prefer it.
  if (startsWith(sec_raw, "_")) return(sec_raw)

  if (is_report) {
    mapped <- .BRAND_REPORT_SECTION_MAP[[sec_key]]
    if (!is.null(mapped)) return(mapped)
    # Pass through anything that already looks like an anchor (pf-*, brsum-*)
    return(sec_raw)
  }

  # Per-category lookup
  el <- .BRAND_CATEGORY_SECTION_MAP[[sec_key]]
  if (!is.null(el)) {
    return(paste0(el, "-", .brand_cat_id(cat_raw)))
  }

  # Pass-through: assume the analyst typed a raw anchor (e.g. "funnel-pos")
  # and we leave it as-is. This is the escape hatch for sections we haven't
  # added a friendly label for.
  sec_raw
}


#' Load Optional Section_Insights Sheet from Brand_Config.xlsx
#'
#' Reads a "Section_Insights" sheet from the brand config workbook if it
#' exists. Resolves Category + Section into anchor IDs and returns a named
#' character vector keyed by anchor, with insight text as values.
#'
#' @param config_path Character. Path to Brand_Config.xlsx.
#'
#' @return Named character vector (anchor → insight text), or NULL when
#'   the sheet is absent / empty / unusable. Sheet load failures emit a
#'   warning but never abort the report (insights are an optional layer).
#'
#' @keywords internal
load_section_insights_sheet <- function(config_path) {
  if (is.null(config_path) || !file.exists(config_path)) return(NULL)

  tryCatch({
    sheets <- openxlsx::getSheetNames(config_path)
    if (!"Section_Insights" %in% sheets) return(NULL)

    df <- suppressWarnings(
      openxlsx::read.xlsx(config_path, sheet = "Section_Insights", startRow = 1)
    )
    if (is.null(df) || nrow(df) == 0) return(NULL)

    # Auto-detect header row when the sheet uses the template format
    # (title row + description row + headers in row 3)
    .has_headers <- function(d) {
      all(c("Section", "Insight") %in% names(d))
    }
    if (!.has_headers(df)) {
      for (.sr in 2:4) {
        df2 <- tryCatch(
          suppressWarnings(
            openxlsx::read.xlsx(config_path, sheet = "Section_Insights", startRow = .sr)
          ),
          error = function(e) NULL
        )
        if (!is.null(df2) && .has_headers(df2)) { df <- df2; break }
      }
    }
    if (!.has_headers(df)) {
      cat("  [INFO] Section_Insights sheet found but missing Section/Insight columns - skipped\n")
      return(NULL)
    }

    # Filter junk rows (blanks, help text marked with [], comments rows)
    df <- df[
      !is.na(df$Section) &
        nzchar(trimws(as.character(df$Section))) &
        !grepl("^\\[", as.character(df$Section)) &
        !is.na(df$Insight) &
        nzchar(trimws(as.character(df$Insight))),
      , drop = FALSE
    ]
    if (nrow(df) == 0) return(NULL)

    # Optional Order column for downstream tooling (pin-reel builder etc.)
    if ("Order" %in% names(df)) {
      ord <- suppressWarnings(as.integer(df$Order))
      ord[is.na(ord)] <- .Machine$integer.max
      df <- df[order(ord), , drop = FALSE]
    }

    # Resolve every row to an anchor
    cats <- if ("Category" %in% names(df)) df$Category else rep(NA_character_, nrow(df))
    anchors <- mapply(.brand_section_anchor, cats, df$Section,
                      USE.NAMES = FALSE)
    insights <- trimws(as.character(df$Insight))

    keep <- !is.na(anchors) & nzchar(anchors)
    anchors  <- anchors[keep]
    insights <- insights[keep]
    if (length(anchors) == 0L) return(NULL)

    # When the same anchor appears more than once, keep the last entry
    # (deterministic on duplicates; emit an info line so analysts notice).
    if (anyDuplicated(anchors) != 0L) {
      dup <- unique(anchors[duplicated(anchors)])
      cat(sprintf(
        "  [INFO] Section_Insights: %d duplicate anchor(s) — last entry wins: %s\n",
        length(dup), paste(dup, collapse = ", ")))
    }
    result <- stats::setNames(insights, anchors)
    result <- result[!duplicated(names(result), fromLast = TRUE)]

    cat(sprintf("  [INFO] Loaded %d insights from Section_Insights sheet\n",
                length(result)))
    result
  }, error = function(e) {
    cat(sprintf("  [WARNING] Could not read Section_Insights sheet: %s\n",
                e$message))
    NULL
  })
}


#' Look up the prefilled insight text for a section anchor
#'
#' Safe accessor used by every panel builder. Returns "" when the config
#' has no insight for the anchor or when section_insights is NULL.
#'
#' @param section_insights Named character vector or NULL.
#' @param anchor Character. The section anchor ID (e.g. "funnel-pos").
#'
#' @return Character scalar. Insight text or "".
#'
#' @keywords internal
section_insight_for <- function(section_insights, anchor) {
  if (is.null(section_insights) || length(section_insights) == 0L) return("")
  if (is.null(anchor) || is.na(anchor) || !nzchar(anchor)) return("")
  # Use `[` not `[[` — the former tolerates a missing name (returns an NA-named
  # element), the latter throws "subscript out of bounds" on a plain named
  # character vector. Either calling convention works on a list, but the
  # loader returns a named character vector for compactness.
  if (!(anchor %in% names(section_insights))) return("")
  val <- section_insights[[anchor]]
  if (is.null(val) || is.na(val)) return("")
  as.character(val)
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand section-insights loader loaded (v%s)",
                  BRAND_SECTION_INSIGHTS_VERSION))
}

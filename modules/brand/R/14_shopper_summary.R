# ==============================================================================
# BRAND MODULE — SHOPPER CONTEXT + FOCAL ENGAGEMENT (sample-wide)
# ==============================================================================
# Two thin engines that surface IPK-2026's sample-wide shopper questions on the
# Summary tab. Neither is per-category — both compute one number set against
# the whole sample.
#
#   compute_shopper_context()  — grocery chains, media channels, recipe-use freq
#                                Roots discovered by convention: GroceryChains,
#                                MEDIA, RECIPE. Multi-mention slots carry the
#                                option label text; the single-mention RECIPE
#                                column carries the 5-pt scale value.
#
#   compute_focal_engagement() — focal-brand behavioural KPIs. Looks for
#                                <FOCAL>WEB, <FOCAL>BOOK, <FOCAL>_RECIPE
#                                Single_Response Yes/No columns. <FOCAL>_RECIPE
#                                is conditional on RECIPE != "Never" (the
#                                Never-recipe-users segment can't have tried
#                                the focal's recipes so they're excluded from
#                                the base — reported separately).
#
# Both engines return a list ready to hand to the panel renderer; no HTML here.
# Returns NULL when no relevant data columns exist.
# ==============================================================================

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a


# Find sort+label info for a multi-mention root from the Options sheet.
# Returns a list(label_by_value, order_by_value) keyed on the option value as
# stored in the data; falls back to bare value -> value mapping when no row.
.shopper_option_map <- function(structure, qcode) {
  opts <- structure$options
  if (is.null(opts) || !is.data.frame(opts) || nrow(opts) == 0) return(NULL)
  qc_col   <- intersect(c("QuestionCode", "Code"), names(opts))[1]
  val_col  <- intersect(c("OptionValue", "Value"), names(opts))[1]
  lbl_col  <- intersect(c("OptionText", "OptionLabel", "Label"), names(opts))[1]
  ord_col  <- intersect(c("SortOrder", "Sort", "DisplayOrder"), names(opts))[1]
  if (any(is.na(c(qc_col, val_col, lbl_col)))) return(NULL)
  rows <- opts[trimws(as.character(opts[[qc_col]])) == qcode, , drop = FALSE]
  if (nrow(rows) == 0) return(NULL)
  values <- as.character(rows[[val_col]])
  labels <- as.character(rows[[lbl_col]])
  order_v <- if (!is.na(ord_col)) suppressWarnings(as.integer(rows[[ord_col]]))
             else seq_len(nrow(rows))
  order_v[is.na(order_v)] <- 9999L
  list(values = values, labels = labels, order = order_v)
}


# Weighted % of TRUE rows in a logical vector (NAs treated as FALSE). Returns
# 0 when no rows.
.shopper_pct <- function(mask, weights) {
  if (length(mask) == 0) return(0)
  mask[is.na(mask)] <- FALSE
  if (is.null(weights)) return(mean(mask) * 100)
  w <- as.numeric(weights)
  total <- sum(w, na.rm = TRUE)
  if (!isTRUE(total > 0)) return(0)
  sum(w * mask, na.rm = TRUE) / total * 100
}


# Build the response distribution for a single Multi_Mention root (e.g.
# GroceryChains). Each slot column carries a label string when picked, NA
# when not. An option is selected when ANY slot equals its option value.
.shopper_multi_mention <- function(data, root, structure, weights) {
  cols <- grep(paste0("^", root, "_[0-9]+$"), names(data), value = TRUE)
  if (length(cols) == 0) return(NULL)
  om <- .shopper_option_map(structure, root)
  values <- if (!is.null(om)) om$values
            else unique(unlist(lapply(cols, function(c) data[[c]]), use.names = FALSE))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0) return(NULL)
  labels <- if (!is.null(om)) om$labels else values
  order_v <- if (!is.null(om)) om$order else seq_along(values)

  n_total <- nrow(data)
  rows <- lapply(seq_along(values), function(i) {
    v <- values[i]
    mask <- rep(FALSE, n_total)
    for (col in cols) {
      vals <- as.character(data[[col]])
      mask <- mask | (!is.na(vals) & vals == v)
    }
    list(
      value = v,
      label = labels[i],
      order = order_v[i],
      n     = sum(mask, na.rm = TRUE),
      pct_weighted = .shopper_pct(mask, weights)
    )
  })
  rows <- rows[order(vapply(rows, function(r) r$order, numeric(1)))]
  list(question_root = root,
       n_total       = n_total,
       rows          = rows)
}


# Single 5-pt frequency-style question. Returns the distribution in the order
# given by the Options sheet (or alphabetical fallback). 1 row per option;
# pct_weighted across the sample.
.shopper_single_scale <- function(data, col, structure, weights) {
  if (!(col %in% names(data))) return(NULL)
  raw <- as.character(data[[col]])
  om  <- .shopper_option_map(structure, col)
  values <- if (!is.null(om)) om$values
            else sort(unique(raw[!is.na(raw)]))
  if (length(values) == 0) return(NULL)
  labels <- if (!is.null(om)) om$labels else values
  order_v <- if (!is.null(om)) om$order else seq_along(values)

  rows <- lapply(seq_along(values), function(i) {
    v <- values[i]
    mask <- !is.na(raw) & raw == v
    list(
      value = v,
      label = labels[i],
      order = order_v[i],
      n     = sum(mask, na.rm = TRUE),
      pct_weighted = .shopper_pct(mask, weights)
    )
  })
  rows <- rows[order(vapply(rows, function(r) r$order, numeric(1)))]
  list(question_root = col,
       n_total       = sum(!is.na(raw)),
       rows          = rows)
}


#' Compute sample-wide shopper context
#'
#' @param data Data frame of respondent rows.
#' @param structure Survey structure (used for Options sheet lookup).
#' @param weights Optional numeric weights of length nrow(data).
#' @return List with `grocery`, `media`, `recipe_use` slots (any can be NULL
#'   when the underlying data columns aren't present). NULL if all three
#'   missing.
#' @export
compute_shopper_context <- function(data, structure, weights = NULL) {
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) return(NULL)
  grocery    <- .shopper_multi_mention(data, "GroceryChains", structure, weights)
  media      <- .shopper_multi_mention(data, "MEDIA",         structure, weights)
  recipe_use <- .shopper_single_scale(data, "RECIPE", structure, weights)
  if (is.null(grocery) && is.null(media) && is.null(recipe_use)) return(NULL)
  list(grocery = grocery, media = media, recipe_use = recipe_use,
       n_total = nrow(data))
}


# Resolve a focal-engagement column by convention. Returns the actual data
# column name when present; NULL otherwise. The IPK 2026 column names are
# IPKWEB / IPKBOOK / IPK_RECIPE — for any other focal code we look for
# {focal}WEB / {focal}BOOK / {focal}_RECIPE first, then fall back to the
# literal IPK column name (so a non-IPK config still surfaces the IPK questions
# verbatim when the survey reuses them).
.engagement_col <- function(data, focal, suffix, prefix_sep = "") {
  cand <- paste0(focal, prefix_sep, suffix)
  if (cand %in% names(data)) return(cand)
  legacy <- paste0("IPK", prefix_sep, suffix)
  if (legacy %in% names(data)) return(legacy)
  NULL
}


# Single-mention Yes/No KPI. Returns list with n_total / n_yes / pct_yes (and
# optional base note when a conditional base mask is supplied).
.engagement_yes_no <- function(data, col, weights, base_mask = NULL,
                                base_note = NULL) {
  if (is.null(col) || !(col %in% names(data))) return(NULL)
  raw <- as.character(data[[col]])
  base <- if (is.null(base_mask)) !is.na(raw) else base_mask & !is.na(raw)
  yes  <- base & raw == "Yes"
  n_total <- sum(base, na.rm = TRUE)
  list(
    column      = col,
    n_total     = n_total,
    n_yes       = sum(yes, na.rm = TRUE),
    pct_yes     = .shopper_pct(yes[base], if (is.null(weights)) NULL else weights[base]),
    base_note   = base_note
  )
}


#' Compute focal-brand engagement KPIs (website / books / recipes-tried)
#'
#' @param data Data frame of respondent rows.
#' @param focal_brand Focal brand code (e.g. "IPK").
#' @param weights Optional numeric weights of length nrow(data).
#' @return List with `website`, `books`, `recipes_tried` slots (each NULL when
#'   the underlying data column is absent). NULL if all three missing.
#' @export
compute_focal_engagement <- function(data, focal_brand, weights = NULL) {
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) return(NULL)
  if (is.null(focal_brand) || !nzchar(focal_brand)) focal_brand <- "IPK"

  web_col   <- .engagement_col(data, focal_brand, "WEB")
  book_col  <- .engagement_col(data, focal_brand, "BOOK")
  recipe_col <- .engagement_col(data, focal_brand, "_RECIPE")

  # IPK_RECIPE conditional base: respondents who DO use recipes at all
  # (RECIPE != "Never"). Reported here so the panel can show the conditional
  # base size explicitly.
  base_mask <- NULL; base_note <- NULL
  if (!is.null(recipe_col) && "RECIPE" %in% names(data)) {
    base_mask <- !is.na(data$RECIPE) & as.character(data$RECIPE) != "Never"
    base_note <- "Base: respondents who use recipes at all (RECIPE ≠ Never)."
  }

  website       <- .engagement_yes_no(data, web_col,    weights)
  books         <- .engagement_yes_no(data, book_col,   weights)
  recipes_tried <- .engagement_yes_no(data, recipe_col, weights,
                                       base_mask = base_mask,
                                       base_note = base_note)

  if (is.null(website) && is.null(books) && is.null(recipes_tried)) return(NULL)
  list(focal_brand   = focal_brand,
       website       = website,
       books         = books,
       recipes_tried = recipes_tried)
}

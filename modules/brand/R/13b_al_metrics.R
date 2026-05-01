# ==============================================================================
# BRAND MODULE - AUDIENCE LENS: METRIC COMPUTATION
# ==============================================================================
# For a given respondent subset (logical mask `keep_idx`), computes the 14
# focal-brand KPIs in four families. All metrics are computed directly from
# the survey data using the QuestionMap role registry — the audience lens
# does NOT call into upstream engines, which keeps it tolerant of partial
# upstream failures and makes the result self-contained.
#
# Metric families (order matches the panel render):
#   FUNNEL & EQUITY      awareness · consideration · p3m_usage · brand_love · branded_reach
#   MENTAL AVAILABILITY  mpen · network_size · mms · som
#   WORD OF MOUTH        net_heard · net_said
#   LOYALTY & BEHAVIOUR  loyalty_scr · purchase_distribution · purchase_frequency
#                        (last three are brand-buyer-base metrics — N/A on the
#                        non-buyer side of pair audiences by definition)
#
# Each metric returns a list with:
#   value      numeric, NA when not derivable for the subset
#   n_base     unweighted denominator used (for sig testing)
#   n_buyer_base TRUE when the metric is defined on focal brand buyers only
#   note       optional human-readable explanation when value is NA
#
# VERSION: 1.0
# ==============================================================================

BRAND_AL_METRICS_VERSION <- "1.0"


# Static metric definitions — order is the display order in the banner table.
.AL_METRIC_GROUPS <- list(
  list(group = "Funnel & Equity", metrics = list(
    list(id = "awareness",     label = "Aided awareness",      kind = "pct"),
    list(id = "consideration", label = "Consideration",        kind = "pct"),
    list(id = "p3m_usage",     label = "P3M usage",            kind = "pct"),
    list(id = "brand_love",    label = "Brand love",           kind = "pct"),
    list(id = "branded_reach", label = "Branded reach",        kind = "pct")
  )),
  list(group = "Mental Availability", metrics = list(
    list(id = "mpen",          label = "MPen",                 kind = "pct"),
    list(id = "network_size",  label = "Network size",         kind = "num"),
    list(id = "mms",           label = "MMS",                  kind = "ratio"),
    list(id = "som",           label = "SoM",                  kind = "ratio")
  )),
  list(group = "Word of Mouth", metrics = list(
    list(id = "net_heard",     label = "Net heard",            kind = "net"),
    list(id = "net_said",      label = "Net said",             kind = "net")
  )),
  list(group = "Loyalty & Behaviour", metrics = list(
    list(id = "loyalty_scr",          label = "Loyalty (SCR)",         kind = "pct",
         buyer_base = TRUE),
    list(id = "purchase_distribution", label = "Purchase distribution", kind = "dist",
         buyer_base = TRUE),
    list(id = "purchase_frequency",    label = "Purchase frequency",    kind = "num",
         buyer_base = TRUE)
  ))
)


#' Return the audience-lens metric catalogue (id, label, kind, buyer_base)
#'
#' Stable list used by the renderer + test suite to enumerate metrics and
#' keep group ordering consistent.
#' @export
audience_lens_metric_catalog <- function() .AL_METRIC_GROUPS


# ==============================================================================
# Internal metric helpers
# ==============================================================================

.al_metric_branded_reach <- function(data, weights, keep_idx, cat_code,
                                      focal_brand, structure) {
  # Branded reach is computed across all eligible respondents per the BR
  # engine's Romaniuk definition. We re-derive from raw data so we can
  # restrict to the audience subset.
  am <- structure$marketing_reach
  if (is.null(am) || !is.data.frame(am) || nrow(am) == 0) {
    return(.al_na_metric("No MarketingReach assets configured"))
  }
  am <- am[!is.na(am$AssetCode) & nzchar(trimws(as.character(am$AssetCode))) &
             !is.na(am$Brand), , drop = FALSE]
  if (nrow(am) == 0) return(.al_na_metric("No focal-brand reach assets"))

  cat_filter <- am$Category == "ALL" | am$Category == cat_code
  am <- am[cat_filter, , drop = FALSE]
  am <- am[trimws(as.character(am$Brand)) == focal_brand, , drop = FALSE]
  if (nrow(am) == 0) {
    return(.al_na_metric("No reach assets for focal brand in this category"))
  }

  # Per-respondent: did they correctly attribute ANY focal-brand asset?
  # Eligibility = saw at least one focal-brand ad's question (non-NA seen).
  reached <- rep(FALSE, nrow(data))
  eligible <- rep(FALSE, nrow(data))
  for (i in seq_len(nrow(am))) {
    seen_col  <- as.character(am$SeenQuestionCode[i])
    brand_col <- as.character(am$BrandQuestionCode[i])
    if (!seen_col %in% names(data) || !brand_col %in% names(data)) next
    sv <- data[[seen_col]]; bv <- data[[brand_col]]
    elig_i <- !is.na(sv)
    seen_i <- elig_i & sv == 1L  # 1 = recognised per reach_seen_scale
    correct_i <- seen_i & !is.na(bv) &
      trimws(as.character(bv)) == focal_brand
    eligible <- eligible | elig_i
    reached  <- reached  | correct_i
  }

  base_idx <- keep_idx & eligible
  n_unw <- sum(base_idx)
  if (n_unw == 0) return(.al_na_metric("No eligible respondents in subset"))
  list(value = sum(weights[reached & keep_idx]) / sum(weights[base_idx]),
       n_base = n_unw, n_buyer_base = FALSE, note = NULL)
}


.al_first_col <- function(data, candidates) {
  hit <- intersect(candidates, names(data))
  if (length(hit) == 0) NULL else hit[1]
}


.al_na_metric <- function(note) {
  list(value = NA_real_, n_base = 0L, n_buyer_base = FALSE, note = note)
}


# ==============================================================================
# SIZE-EXCEPTION: v1 + v2 coexist during IPK rebuild migration window.
# v1 deletion at cutover restores this file under the 300-line guideline.
# ==============================================================================

# ==============================================================================
# V2: ROLE-MAP-DRIVEN KPI COMPUTATION (slot-indexed data access)
# ==============================================================================
# v2 reads respondent data via 00_data_access.R helpers and resolves columns
# from a v2 role map (built by build_brand_role_map). Same metric catalogue
# and per-metric output shape as v1 — the only difference is the seam between
# the role registry and respondent data.
#
# Tracker-friendliness note: every per-respondent indicator built here is a
# pure function of (data, role_map, focal_brand) — no report-internal state.
# The Audience Lens v3 project (post-cutover) will materialise these as
# per-respondent KPI columns so the tracker module can lift them across
# waves without re-implementing the math.
# ==============================================================================


#' Compute the audience-lens KPI panel for one respondent subset (v2)
#'
#' v2 alternative to \code{compute_al_metrics_for_subset()}. Uses the v2
#' role map + slot-indexed data access. Returns the same shape (named list
#' keyed by metric id; each value is a list with value, n_base,
#' n_buyer_base, note).
#'
#' @export
compute_al_metrics_for_subset <- function(data, role_map, weights, keep_idx,
                                             cat_brands, cat_code,
                                             focal_brand, structure,
                                             category_results = NULL,
                                             config = NULL) {

  if (is.null(weights)) weights <- rep(1, nrow(data))
  if (is.null(keep_idx)) keep_idx <- rep(TRUE, nrow(data))
  keep_idx[is.na(keep_idx)] <- FALSE

  brand_codes <- as.character(cat_brands$BrandCode)

  aware_role <- paste0("funnel.awareness.", cat_code)
  att_role   <- paste0("funnel.attitude.", cat_code)
  pen2_role  <- paste0("funnel.penetration_target.", cat_code)
  pen3_role  <- paste0("funnel.frequency.", cat_code)

  aware_root <- role_map[[aware_role]]$column_root
  pen2_root  <- role_map[[pen2_role ]]$column_root
  pen3_root  <- role_map[[pen3_role ]]$column_root

  # Per-respondent focal indicators (logical/numeric; tracker-portable shape)
  awareness_ind <- if (!is.null(aware_root))
    respondent_picked(data, aware_root, focal_brand) else NULL
  p3m_ind <- if (!is.null(pen2_root))
    respondent_picked(data, pen2_root, focal_brand) else NULL

  # Buyer mask within the subset (for brand-buyer-base metrics)
  buyer_idx <- if (!is.null(p3m_ind)) p3m_ind else rep(FALSE, nrow(data))

  # Per-brand attitude column for the focal brand (single column lookup)
  att_entry <- role_map[[att_role]]
  att_col_name <- if (!is.null(att_entry) &&
                       is.character(att_entry$columns) &&
                       length(att_entry$columns) > 0L &&
                       !is.null(names(att_entry$columns)) &&
                       focal_brand %in% names(att_entry$columns))
                    att_entry$columns[[focal_brand]] else NULL
  att_vec <- if (!is.null(att_col_name) && att_col_name %in% names(data))
                suppressWarnings(as.integer(data[[att_col_name]])) else NULL

  out <- list()

  # ---- FUNNEL & EQUITY -----------------------------------------------------
  out$awareness <- .al_metric_pct_from_logical(
    awareness_ind, weights, keep_idx, na_means_no = TRUE,
    note_when_missing = "Awareness role not in role map")

  out$consideration <- .al_metric_pct_from_attitude(
    att_vec, weights, keep_idx, codes = c(1L, 2L),
    note_when_missing = "Attitude column not resolvable")

  out$p3m_usage <- .al_metric_pct_from_logical(
    p3m_ind, weights, keep_idx, na_means_no = TRUE,
    note_when_missing = "Bought-target role not in role map")

  out$brand_love <- .al_metric_pct_from_attitude(
    att_vec, weights, keep_idx, codes = 1L,
    note_when_missing = "Attitude column not resolvable")

  out$branded_reach <- .al_metric_branded_reach(
    data, weights, keep_idx, cat_code, focal_brand, structure)

  # ---- MENTAL AVAILABILITY -------------------------------------------------
  ma <- .al_metric_ma_block(data, role_map, weights, keep_idx,
                                brand_codes, cat_code, focal_brand)
  out$mpen         <- ma$mpen
  out$network_size <- ma$network_size
  out$mms          <- ma$mms
  out$som          <- ma$som

  # ---- WORD OF MOUTH -------------------------------------------------------
  wom <- .al_metric_wom_block(data, role_map, weights, keep_idx,
                                  cat_code, focal_brand)
  out$net_heard <- wom$net_heard
  out$net_said  <- wom$net_said

  # ---- LOYALTY & BEHAVIOUR (brand-buyer base) ------------------------------
  buyer_keep <- keep_idx & buyer_idx

  # Per-respondent per-brand frequency tensor (n × B numeric, 0 = didn't buy)
  freq_mat <- if (!is.null(pen2_root) && !is.null(pen3_root))
                slot_paired_numeric_matrix(data, pen2_root, pen3_root,
                                           brand_codes) else NULL
  focal_freq <- if (!is.null(freq_mat) && focal_brand %in% colnames(freq_mat))
                  as.numeric(freq_mat[, focal_brand]) else NULL

  out$loyalty_scr <- .al_metric_scr(
    freq_mat = freq_mat, weights = weights, buyer_keep = buyer_keep,
    focal_brand = focal_brand)

  out$purchase_distribution <- .al_metric_purchase_dist(
    focal_freq = focal_freq, weights = weights, buyer_keep = buyer_keep)

  out$purchase_frequency <- .al_metric_purchase_freq(
    focal_freq = focal_freq, weights = weights, buyer_keep = buyer_keep)

  out
}


# ==============================================================================
# Internal v2 metric helpers
# ==============================================================================

#' Generic % from a per-respondent logical indicator
#'
#' \code{na_means_no = TRUE}: NA in the indicator counts as FALSE; denom
#' is the full subset (Multi_Mention "not selected" semantics).
#' \code{na_means_no = FALSE}: NA excluded from base (Single_Response
#' "didn't answer" semantics).
#' @keywords internal
.al_metric_pct_from_logical <- function(indicator, weights, keep_idx,
                                         na_means_no = TRUE,
                                         note_when_missing = "Indicator missing") {
  if (is.null(indicator)) return(.al_na_metric(note_when_missing))
  ind <- as.logical(indicator)
  if (na_means_no) {
    ind[is.na(ind)] <- FALSE
    base_idx <- keep_idx
  } else {
    base_idx <- keep_idx & !is.na(ind)
    ind[is.na(ind)] <- FALSE
  }
  hit <- ind & keep_idx
  n_unw <- sum(base_idx)
  if (n_unw == 0) return(.al_na_metric("Empty subset for this metric"))
  list(value = sum(weights[hit]) / sum(weights[base_idx]),
       n_base = n_unw, n_buyer_base = FALSE, note = NULL)
}


#' % of subset whose attitude code is in `codes`
#'
#' Single_Response semantics — NA in the attitude column means "didn't
#' answer" so it's excluded from the base.
#' @keywords internal
.al_metric_pct_from_attitude <- function(att_vec, weights, keep_idx, codes,
                                          note_when_missing) {
  if (is.null(att_vec)) return(.al_na_metric(note_when_missing))
  base_idx <- keep_idx & !is.na(att_vec)
  n_unw <- sum(base_idx)
  if (n_unw == 0) return(.al_na_metric("Empty subset for this metric"))
  hit <- base_idx & att_vec %in% codes
  list(value = sum(weights[hit]) / sum(weights[base_idx]),
       n_base = n_unw, n_buyer_base = FALSE, note = NULL)
}


#' Mental Availability block — v2 (role-map driven CEPs)
#' @keywords internal
.al_metric_ma_block <- function(data, role_map, weights, keep_idx,
                                    brand_codes, cat_code, focal_brand) {

  na_block <- function(msg) list(
    mpen = .al_na_metric(msg), network_size = .al_na_metric(msg),
    mms = .al_na_metric(msg), som = .al_na_metric(msg))

  if (length(brand_codes) == 0L) return(na_block("No brands configured"))

  # Walk role_map for mental_avail.cep.<cat>.* entries
  prefix <- paste0("mental_avail.cep.", cat_code, ".")
  cep_roles <- names(role_map)[startsWith(names(role_map), prefix)]
  if (length(cep_roles) == 0L) return(na_block(
    sprintf("No CEP roles for category %s in role map", cat_code)))

  # Per-respondent integer link matrices (n × B), one per CEP
  link_mats <- list()
  for (rk in cep_roles) {
    e <- role_map[[rk]]
    if (is.null(e$column_root)) next
    m <- multi_mention_brand_matrix(data, e$column_root, brand_codes)
    if (is.null(m) || ncol(m) == 0L) next
    link_mats[[length(link_mats) + 1L]] <- matrix(as.integer(m),
                                                   nrow = nrow(m),
                                                   ncol = ncol(m),
                                                   dimnames = dimnames(m))
  }
  if (length(link_mats) == 0L) return(na_block("No CEP-brand link data"))

  focal_pos <- which(brand_codes == focal_brand)
  if (length(focal_pos) == 0L) return(na_block(
    "Focal brand not in category brand list"))

  # Aggregate across CEPs (vectorised; same algebra as v1)
  links_focal_per_resp <- Reduce(`+`, lapply(link_mats,
                                              function(m) m[, focal_pos]))
  links_per_brand_per_resp <- Reduce(`+`, link_mats)

  base_idx <- keep_idx
  n_unw <- sum(base_idx)
  if (n_unw == 0) return(na_block("Empty subset"))
  w_total <- sum(weights[base_idx])

  mpen_indicator <- links_focal_per_resp > 0
  mpen_val <- if (w_total > 0)
    sum(weights[base_idx & mpen_indicator]) / w_total else NA_real_

  ns_val <- if (w_total > 0)
    sum(weights[base_idx] * links_focal_per_resp[base_idx]) / w_total else NA_real_

  total_links_all <- sum(weights[base_idx] *
                          rowSums(links_per_brand_per_resp)[base_idx])
  total_links_focal <- sum(weights[base_idx] *
                            links_focal_per_resp[base_idx])
  mms_val <- if (total_links_all > 0)
    total_links_focal / total_links_all else NA_real_

  n_cep <- length(link_mats)
  som_val <- if (w_total > 0 && n_cep > 0)
    total_links_focal / (w_total * n_cep) else NA_real_

  metric_ok <- function(v) list(value = v, n_base = n_unw,
                                 n_buyer_base = FALSE, note = NULL)
  list(mpen = metric_ok(mpen_val), network_size = metric_ok(ns_val),
       mms = metric_ok(mms_val),  som = metric_ok(som_val))
}


#' Word of Mouth block — v2 (role-map driven mention sets)
#' @keywords internal
.al_metric_wom_block <- function(data, role_map, weights, keep_idx,
                                     cat_code, focal_brand) {

  net <- function(pos_role, neg_role, label) {
    pos_root <- role_map[[pos_role]]$column_root
    neg_root <- role_map[[neg_role]]$column_root
    if (is.null(pos_root) || is.null(neg_root)) {
      return(.al_na_metric(sprintf("%s WOM role missing", label)))
    }
    pos_ind <- respondent_picked(data, pos_root, focal_brand)
    neg_ind <- respondent_picked(data, neg_root, focal_brand)
    base_idx <- keep_idx
    n_unw <- sum(base_idx)
    if (n_unw == 0) return(.al_na_metric("No WOM responses in subset"))
    w_total <- sum(weights[base_idx])
    if (w_total <= 0) return(.al_na_metric("Zero weight in subset"))
    pos_w <- sum(weights[base_idx & pos_ind])
    neg_w <- sum(weights[base_idx & neg_ind])
    list(value = (pos_w - neg_w) / w_total,
         n_base = n_unw, n_buyer_base = FALSE, note = NULL)
  }

  list(
    net_heard = net(paste0("wom.pos_rec.",   cat_code),
                     paste0("wom.neg_rec.",   cat_code), "Heard"),
    net_said  = net(paste0("wom.pos_share.", cat_code),
                     paste0("wom.neg_share.", cat_code), "Said")
  )
}


#' Share of Category Requirements (SCR) — v2
#' @keywords internal
.al_metric_scr <- function(freq_mat, weights, buyer_keep, focal_brand) {
  if (is.null(freq_mat) || !is.matrix(freq_mat) ||
      !(focal_brand %in% colnames(freq_mat))) {
    return(list(value = NA_real_, n_base = 0L, n_buyer_base = TRUE,
                note = "Frequency tensor not derivable"))
  }
  base_idx <- buyer_keep
  n_unw <- sum(base_idx)
  if (n_unw == 0) {
    return(list(value = NA_real_, n_base = 0L, n_buyer_base = TRUE,
                note = "No focal brand buyers in subset"))
  }
  focal_freq <- as.numeric(freq_mat[, focal_brand])
  total_freq <- as.numeric(rowSums(freq_mat))
  num <- sum(weights[base_idx] * focal_freq[base_idx])
  den <- sum(weights[base_idx] * total_freq[base_idx])
  list(value = if (den > 0) num / den else NA_real_,
       n_base = n_unw, n_buyer_base = TRUE, note = NULL)
}


#' Purchase frequency (mean focal-brand count among focal buyers) — v2
#' @keywords internal
.al_metric_purchase_freq <- function(focal_freq, weights, buyer_keep) {
  if (is.null(focal_freq)) {
    return(list(value = NA_real_, n_base = 0L, n_buyer_base = TRUE,
                note = "Frequency column not derivable"))
  }
  base_idx <- buyer_keep & !is.na(focal_freq) & focal_freq > 0
  n_unw <- sum(base_idx)
  if (n_unw == 0) {
    return(list(value = NA_real_, n_base = 0L, n_buyer_base = TRUE,
                note = "No focal-brand buyers in subset"))
  }
  list(value = sum(weights[base_idx] * focal_freq[base_idx]) /
                sum(weights[base_idx]),
       n_base = n_unw, n_buyer_base = TRUE, note = NULL)
}


#' Purchase distribution (% heavy buyers, top tercile of frequency) — v2
#' @keywords internal
.al_metric_purchase_dist <- function(focal_freq, weights, buyer_keep) {
  if (is.null(focal_freq)) {
    return(list(value = NA_real_, n_base = 0L, n_buyer_base = TRUE,
                note = "Frequency column not derivable",
                distribution = NULL))
  }
  base_idx <- buyer_keep & !is.na(focal_freq) & focal_freq > 0
  n_unw <- sum(base_idx)
  if (n_unw == 0) {
    return(list(value = NA_real_, n_base = 0L, n_buyer_base = TRUE,
                note = "No focal-brand buyers in subset",
                distribution = NULL))
  }
  w  <- weights[base_idx]; vv <- focal_freq[base_idx]
  total_w <- sum(w)
  buckets <- sort(unique(vv))
  dist <- vapply(buckets, function(b) sum(w[vv == b]) / total_w, numeric(1))
  names(dist) <- as.character(buckets)
  if (length(buckets) >= 3L) {
    top_n <- ceiling(length(buckets) / 3L)
    top_codes <- tail(buckets, top_n)
    headline <- sum(dist[as.character(top_codes)])
  } else {
    headline <- max(dist)
  }
  list(value = headline,
       n_base = n_unw, n_buyer_base = TRUE,
       note = NULL,
       distribution = dist)
}


if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}


if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Audience lens metrics loaded (v%s)",
                  BRAND_AL_METRICS_VERSION))
}

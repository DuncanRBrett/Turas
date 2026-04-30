# ==============================================================================
# IPK WAVE 1 FIXTURE — DSS DEEP DIVE
# ==============================================================================
# Generates the full DSS deep-dive battery for respondents whose Focal_Category
# = "DSS". All other respondents get NA across these columns.
#
# Battery covers:
#   * BRANDATTR_DSS_CEP01..15 + ATT01..15 — slot-indexed Multi_Mention
#   * BRANDATT1_DSS_{brand}                — per-brand Single_Response (1-5)
#   * BRANDATT2_DSS_{brand}                — per-brand Open_End (mostly NA)
#   * WOM_POS_REC_DSS / WOM_POS_SHARE_DSS
#     WOM_NEG_REC_DSS / WOM_NEG_SHARE_DSS  — slot-indexed Multi_Mention
#   * WOM_POS_COUNT_DSS_{brand} / WOM_NEG_COUNT_DSS_{brand}
#                                         — per-brand Single_Response (1-5)
#   * CATBUY_DSS                          — Single_Response (1-5)
#   * CATCOUNT_DSS                        — Numeric (0-99)
#   * CHANNEL_DSS_1..6                    — slot-indexed Multi_Mention
#   * PACK_DSS_1..4                       — slot-indexed Multi_Mention
#   * BRANDPEN1_DSS_1..16                 — slot-indexed (12-month buyers)
#   * BRANDPEN2_DSS_1..16                 — slot-indexed (3-month buyers)
#   * BRANDPEN3_DSS_1..15                 — Continuous Sum, numeric per slot
# ==============================================================================

CAT_DSS <- "DSS"

#' Build the full DSS deep dive for all respondents
#'
#' @param focal Character vector length N — Focal_Category per respondent.
#' @param awareness_dss Logical matrix [n x n_brands] from cross-cat awareness.
#' @param sq2_per_resp List length N — SQ2 category selections per respondent.
#' @return Data frame with all DSS deep-dive columns.
ipk_build_dss_deep_dive <- function(focal, awareness_dss, sq2_per_resp) {
  n <- IPK_N_RESPONDENTS
  out <- data.frame(.row_idx = seq_len(n))

  is_dss <- !is.na(focal) & focal == CAT_DSS
  brands <- IPK_BRANDS[[CAT_DSS]]
  n_slots <- ipk_brand_slot_count(CAT_DSS)

  # CEP × brand matrix (15 CEPs)
  out <- .ipk_dss_attrs(out, n, n_slots, is_dss,
                        IPK_CEPS_DSS, awareness_dss, "CEP")

  # Attribute × brand matrix (15 attributes)
  out <- .ipk_dss_attrs(out, n, n_slots, is_dss,
                        IPK_ATTS_DSS, awareness_dss, "ATT")

  # BRANDATT1 + BRANDATT2 (per-brand Single_Response + Open_End)
  attitude_mat <- .ipk_dss_attitudes(out, n, is_dss, brands, awareness_dss)
  for (b in brands) {
    out[[paste0("BRANDATT1_", CAT_DSS, "_", b)]] <- attitude_mat[, b]
    out[[paste0("BRANDATT2_", CAT_DSS, "_", b)]] <- ifelse(
      !is.na(attitude_mat[, b]) & attitude_mat[, b] == "4",
      "Refused — fictional reason for fixture",
      NA_character_
    )
  }

  # WOM (4 multi-mention sets + 30 per-brand counts)
  out <- .ipk_dss_wom(out, n, n_slots, is_dss, brands, awareness_dss)

  # Cat buying + count + channel + pack
  out <- .ipk_dss_cat_behaviour(out, n, is_dss, sq2_per_resp)

  # Penetration 1, 2, 3
  out <- .ipk_dss_penetration(out, n, n_slots, is_dss, brands, awareness_dss)

  out$.row_idx <- NULL
  list(
    data = out,
    attitude = attitude_mat
  )
}

# ------------------------------------------------------------------------------
# CEP / ATT × brand matrix — slot-indexed Multi_Mention per CEP/ATT row
# ------------------------------------------------------------------------------

.ipk_dss_attrs <- function(out, n, n_slots, is_dss, items, aware_mat, kind) {
  brands <- colnames(aware_mat)
  store <- list()
  for (item in items) {
    code <- item$code
    root <- paste0("BRANDATTR_", CAT_DSS, "_", code)
    for (i in seq_len(n)) {
      if (!is_dss[i]) next
      # Sample 0-4 brands the respondent associates with this CEP/ATT
      n_pick <- sample(0:4, 1, prob = c(0.25, 0.30, 0.25, 0.15, 0.05))
      eligible <- brands[aware_mat[i, ]]
      if (n_pick == 0 || length(eligible) == 0) {
        selected <- "NONE"
      } else {
        selected <- sample(eligible, size = min(n_pick, length(eligible)))
      }
      store <- ipk_record_slots(store, root, selected, n_slots, i)
    }
    for (j in seq_len(n_slots)) {
      col <- paste0(root, "_", j)
      out[[col]] <- store[[col]] %||% rep(NA_character_, n)
    }
    store <- list()  # reset for next item
  }
  out
}

# ------------------------------------------------------------------------------
# Brand attitudes (per-brand Single_Response, code 1-5)
# ------------------------------------------------------------------------------

.ipk_dss_attitudes <- function(out, n, is_dss, brands, aware_mat) {
  mat <- matrix(NA_character_, nrow = n, ncol = length(brands),
                dimnames = list(NULL, brands))
  for (i in seq_len(n)) {
    if (!is_dss[i]) next
    for (b in brands) {
      mat[i, b] <- if (aware_mat[i, b]) {
        ipk_sample_attitude(b, CAT_DSS)
      } else {
        "5"  # No opinion / don't know this brand
      }
    }
  }
  mat
}

# ------------------------------------------------------------------------------
# WOM — 4 multi-mention sets + per-brand counts (conditional)
# ------------------------------------------------------------------------------

.ipk_dss_wom <- function(out, n, n_slots, is_dss, brands, aware_mat) {
  wom_probs <- list(POS_REC = 0.25, POS_SHARE = 0.18,
                    NEG_REC = 0.10, NEG_SHARE = 0.06)
  wom_picks <- list()  # store who picked which brand for each WOM type

  for (typ in names(wom_probs)) {
    root <- paste0("WOM_", typ, "_", CAT_DSS)
    store <- list()
    picks_mat <- matrix(FALSE, n, length(brands), dimnames = list(NULL, brands))
    for (i in seq_len(n)) {
      if (!is_dss[i]) next
      eligible <- brands[aware_mat[i, ]]
      picked <- character(0)
      for (b in eligible) {
        if (runif(1) < wom_probs[[typ]]) picked <- c(picked, b)
      }
      picks_mat[i, picked] <- TRUE
      selected <- if (length(picked) > 0) picked else "NONE"
      store <- ipk_record_slots(store, root, selected, n_slots, i)
    }
    for (j in seq_len(n_slots)) {
      col <- paste0(root, "_", j)
      out[[col]] <- store[[col]] %||% rep(NA_character_, n)
    }
    wom_picks[[typ]] <- picks_mat
  }

  # WOM counts: per-brand single-response, shown if respondent picked that brand
  # in the corresponding SHARE question
  for (b in brands) {
    pos_share_picked <- wom_picks$POS_SHARE[, b]
    out[[paste0("WOM_POS_COUNT_", CAT_DSS, "_", b)]] <- ifelse(
      pos_share_picked,
      sample(IPK_WOM_COUNT_CODES, n, replace = TRUE,
             prob = c(0.40, 0.25, 0.15, 0.10, 0.10)),
      NA_character_
    )
    neg_share_picked <- wom_picks$NEG_SHARE[, b]
    out[[paste0("WOM_NEG_COUNT_", CAT_DSS, "_", b)]] <- ifelse(
      neg_share_picked,
      sample(IPK_WOM_COUNT_CODES, n, replace = TRUE,
             prob = c(0.55, 0.25, 0.10, 0.05, 0.05)),
      NA_character_
    )
  }
  out
}

# ------------------------------------------------------------------------------
# Cat buying / cat count / channels / pack sizes
# ------------------------------------------------------------------------------

.ipk_dss_cat_behaviour <- function(out, n, is_dss, sq2_per_resp) {
  out[["CATBUY_DSS"]] <- ifelse(is_dss,
    sample(IPK_CATBUY_CODES, n, replace = TRUE,
           prob = c(0.20, 0.35, 0.30, 0.10, 0.05)),
    NA_character_)
  out[["CATCOUNT_DSS"]] <- ifelse(is_dss,
    pmin(99, pmax(0, round(rgamma(n, shape = 2.5, rate = 0.6)))),
    NA_real_)

  # Channels — slot-indexed; only respondents who bought DSS in last 3m
  channel_codes <- vapply(IPK_CHANNELS, function(c) c$code, character(1))
  pack_codes    <- vapply(IPK_PACK_SIZES, function(c) c$code, character(1))
  recent_buyer  <- vapply(seq_len(n),
                          function(i) is_dss[i] && CAT_DSS %in% sq2_per_resp[[i]],
                          logical(1))

  store_ch <- list()
  store_pk <- list()
  for (i in seq_len(n)) {
    if (!recent_buyer[i]) next
    n_ch <- sample(1:3, 1, prob = c(0.55, 0.30, 0.15))
    ch <- sample(channel_codes, n_ch)
    store_ch <- ipk_record_slots(store_ch, "CHANNEL_DSS", ch,
                                 length(channel_codes), i)
    n_pk <- sample(1:2, 1, prob = c(0.70, 0.30))
    pk <- sample(pack_codes, n_pk)
    store_pk <- ipk_record_slots(store_pk, "PACK_DSS", pk,
                                 length(pack_codes), i)
  }
  for (j in seq_len(length(channel_codes))) {
    col <- paste0("CHANNEL_DSS_", j)
    out[[col]] <- store_ch[[col]] %||% rep(NA_character_, n)
  }
  for (j in seq_len(length(pack_codes))) {
    col <- paste0("PACK_DSS_", j)
    out[[col]] <- store_pk[[col]] %||% rep(NA_character_, n)
  }
  out
}

# ------------------------------------------------------------------------------
# Penetration 1, 2, 3 — slot-indexed P1 + P2; per-slot continuous-sum P3
# ------------------------------------------------------------------------------

.ipk_dss_penetration <- function(out, n, n_slots, is_dss, brands, aware_mat) {
  store_p1 <- list()
  store_p2 <- list()
  pen2_per_resp <- vector("list", n)  # remember P2 for P3 piping

  for (i in seq_len(n)) {
    if (!is_dss[i]) next
    aware <- brands[aware_mat[i, ]]
    p1 <- character(0)
    for (b in aware) {
      if (runif(1) < ipk_penetration_long_prob(b, CAT_DSS)) p1 <- c(p1, b)
    }
    p2 <- character(0)
    for (b in p1) {
      if (runif(1) < ipk_penetration_target_prob(b, CAT_DSS)) p2 <- c(p2, b)
    }
    p1_sel <- if (length(p1) > 0) p1 else "NONE"
    p2_sel <- if (length(p2) > 0) p2 else "NONE"
    store_p1 <- ipk_record_slots(store_p1, "BRANDPEN1_DSS", p1_sel, n_slots, i)
    store_p2 <- ipk_record_slots(store_p2, "BRANDPEN2_DSS", p2_sel, n_slots, i)
    pen2_per_resp[[i]] <- p2  # excluding NONE
  }
  for (j in seq_len(n_slots)) {
    out[[paste0("BRANDPEN1_DSS_", j)]] <- store_p1[[paste0("BRANDPEN1_DSS_", j)]] %||% rep(NA_character_, n)
    out[[paste0("BRANDPEN2_DSS_", j)]] <- store_p2[[paste0("BRANDPEN2_DSS_", j)]] %||% rep(NA_character_, n)
  }

  # BRANDPEN3 — Continuous Sum, 15 slots (= length(brands)). Slot j holds the
  # numeric purchase frequency for whichever brand was at position j in P2.
  for (j in seq_len(length(brands))) {
    out[[paste0("BRANDPEN3_DSS_", j)]] <- NA_real_
  }
  for (i in seq_len(n)) {
    if (!is_dss[i]) next
    p2 <- pen2_per_resp[[i]]
    if (length(p2) == 0) next
    # Distribute 10 occasions across the brands, biased toward focal
    weights <- ifelse(p2 == IPK_FOCAL_BRAND[[CAT_DSS]], 3, 1)
    counts <- as.numeric(table(factor(
      sample(p2, size = 10, replace = TRUE, prob = weights / sum(weights)),
      levels = p2
    )))
    for (j in seq_along(p2)) {
      out[[paste0("BRANDPEN3_DSS_", j)]][i] <- counts[j]
    }
  }
  out
}

# ==============================================================================
# IPK WAVE 1 FIXTURE — CROSS-CATEGORY BRAND AWARENESS
# ==============================================================================
# Generates BRANDAWARE_{CAT}_1...N columns for every category. Each
# respondent answers BRANDAWARE_{CAT} only for categories they selected in
# SQ1 (Alchemer show-logic).
#
# Awareness probabilities follow IPK_BRANDS list order (focal first; decay
# linear toward 0.30 for the least-known brand). NONE option is added when
# the respondent recognises zero brands in the category — keeps the data
# realistic.
# ==============================================================================

#' Build BRANDAWARE_* columns across all categories for all respondents
#'
#' @param sq1_per_resp List of length N_RESPONDENTS — each element is a
#'   character vector of category codes that respondent selected in SQ1.
#' @return Data frame, N_RESPONDENTS rows, one column per slot per category.
#' @return Plus an attribute "awareness_matrix" — list keyed by category,
#'   each a logical matrix [n_resp x n_brands] of who recognised which brand.
#'   Used downstream so DSS deep dive (Section 5) is gated by awareness
#'   correctly (consideration ⊆ awareness).
ipk_build_cross_cat_awareness <- function(sq1_per_resp) {

  n <- IPK_N_RESPONDENTS
  out <- data.frame(.row_idx = seq_len(n))
  awareness_matrix <- list()

  for (cat_meta in IPK_CATEGORIES) {
    cat <- cat_meta$code
    brands  <- IPK_BRANDS[[cat]]
    n_slots <- ipk_brand_slot_count(cat)
    aw_probs <- ipk_awareness_probs(cat)

    aw_logical <- matrix(FALSE, nrow = n, ncol = length(brands),
                         dimnames = list(NULL, brands))
    store <- list()

    for (i in seq_len(n)) {
      if (!(cat %in% sq1_per_resp[[i]])) next  # not asked

      # Sample which brands this respondent recognises
      picks <- vapply(brands, function(b) runif(1) < aw_probs[[b]],
                      logical(1))
      aw_logical[i, ] <- picks
      selected <- brands[picks]
      if (length(selected) == 0) selected <- "NONE"

      store <- ipk_record_slots(store, paste0("BRANDAWARE_", cat),
                                selected, n_slots, i)
    }

    # Bind columns
    for (j in seq_len(n_slots)) {
      col <- paste0("BRANDAWARE_", cat, "_", j)
      out[[col]] <- store[[col]] %||% rep(NA_character_, n)
    }
    awareness_matrix[[cat]] <- aw_logical
  }

  out$.row_idx <- NULL
  attr(out, "awareness_matrix") <- awareness_matrix
  out
}

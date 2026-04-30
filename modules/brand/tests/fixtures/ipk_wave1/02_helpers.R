# ==============================================================================
# IPK WAVE 1 FIXTURE — HELPERS
# ==============================================================================
# Shared utilities for the fixture generator: slot-indexed encoding (the
# Alchemer-parser shape), brand awareness-decay model (so generated data has
# realistic funnel shapes), and per-respondent randomness with a deterministic
# seed.
# ==============================================================================

# ------------------------------------------------------------------------------
# Slot-indexed encoding — the canonical shape AlchemerParser produces for
# Multi_Mention questions. For a question with N options, the data has columns
# Q_1 ... Q_N. Selected option codes appear left-packed in the slots; unused
# slots are NA. Order within slots reflects the order of selection.
# ------------------------------------------------------------------------------

#' Encode a vector of selected option codes into N slot columns
#'
#' @param selected Character vector of selected option codes (any length).
#' @param n_slots Total number of slots available (= total options).
#' @return Character vector of length n_slots: selected codes left-packed,
#'   remaining slots NA.
#'
#' @examples
#' ipk_encode_slots(c("IPK", "ROB"), 5)
#' # c("IPK", "ROB", NA, NA, NA)
ipk_encode_slots <- function(selected, n_slots) {
  out <- rep(NA_character_, n_slots)
  if (length(selected) == 0) return(out)
  selected <- as.character(selected)
  k <- min(length(selected), n_slots)
  out[seq_len(k)] <- selected[seq_len(k)]
  out
}

#' Build slot column names for a Multi_Mention root
#'
#' @param root Question root (e.g. "BRANDAWARE_DSS").
#' @param n_slots Number of slot columns.
#' @return Character vector of column names.
ipk_slot_colnames <- function(root, n_slots) {
  paste0(root, "_", seq_len(n_slots))
}

#' Append a respondent's slot-encoded answers to a list-of-vectors store
#'
#' Internal helper — builds the per-column character vectors as we walk
#' respondents, keeping memory bounded.
#'
#' @keywords internal
ipk_record_slots <- function(store, root, selected, n_slots, resp_idx) {
  encoded <- ipk_encode_slots(selected, n_slots)
  for (j in seq_len(n_slots)) {
    col <- paste0(root, "_", j)
    if (is.null(store[[col]])) {
      store[[col]] <- rep(NA_character_, IPK_N_RESPONDENTS)
    }
    store[[col]][resp_idx] <- encoded[j]
  }
  store
}

# ------------------------------------------------------------------------------
# Brand awareness/funnel realism. The fixture must have funnel shapes that
# pass sanity checks: awareness decays from focal brand outward, consideration
# is a subset of awareness, penetration is a subset of consideration. Without
# this, sanity tests in the funnel module would fire on the fixture.
# ------------------------------------------------------------------------------

#' Per-brand awareness probability for a category
#'
#' Focal brand has high baseline (0.92), decays toward 0.30 across the brand
#' list. Returns a named numeric vector.
#'
#' @param cat_code Category code (e.g. "DSS").
#' @return Named numeric vector — names = brand codes, values = awareness probs.
ipk_awareness_probs <- function(cat_code) {
  brands <- IPK_BRANDS[[cat_code]]
  focal  <- IPK_FOCAL_BRAND[[cat_code]]
  n <- length(brands)
  # Linear decay from 0.92 (focal) to 0.30 (least-known)
  ranks <- seq_len(n)
  # Place focal at rank 1; others ranked by position in IPK_BRANDS list
  focal_idx <- which(brands == focal)
  ord <- c(focal_idx, setdiff(seq_len(n), focal_idx))
  probs <- numeric(n)
  probs[ord] <- seq(from = 0.92, to = 0.30, length.out = n)
  setNames(probs, brands)
}

#' Per-brand attitude code for a respondent given they are aware
#'
#' Focal brand skews toward "Love/Prefer", others spread across the scale.
#' Returns a single attitude code from IPK_ATTITUDE_CODES.
#'
#' @param brand Brand code.
#' @param cat_code Category code.
#' @return Single character: one of "1","2","3","4","5".
ipk_sample_attitude <- function(brand, cat_code) {
  focal <- IPK_FOCAL_BRAND[[cat_code]]
  if (brand == focal) {
    sample(c("1", "2", "3", "4"),
           size = 1, prob = c(0.35, 0.40, 0.20, 0.05))
  } else {
    sample(c("1", "2", "3", "4", "5"),
           size = 1, prob = c(0.10, 0.25, 0.30, 0.10, 0.25))
  }
}

#' Penetration probability given awareness + consideration
#'
#' Penetration (long window) is a subset of considerers. Used to bias the
#' BRANDPEN1 selection. Returns probability of "yes I bought it long-window"
#' given the respondent considers the brand (attitude in 1-3).
#'
#' @param brand Brand code.
#' @param cat_code Category code.
#' @return Numeric probability [0, 1].
ipk_penetration_long_prob <- function(brand, cat_code) {
  if (brand == IPK_FOCAL_BRAND[[cat_code]]) 0.65 else 0.35
}

#' Penetration target window probability given long-window penetration
#' @return Numeric [0, 1].
ipk_penetration_target_prob <- function(brand, cat_code) {
  if (brand == IPK_FOCAL_BRAND[[cat_code]]) 0.70 else 0.50
}

# ------------------------------------------------------------------------------
# Sampling utilities
# ------------------------------------------------------------------------------

#' Sample a category list from per-cat selection probabilities (SQ1)
#'
#' @return Character vector of category codes the respondent selected (always
#'   includes at least one Core category — qualification rule).
ipk_sample_sq1_categories <- function() {
  # Probability of selecting each category
  core_probs <- c(DSS = 0.85, POS = 0.55, PAS = 0.65, BAK = 0.50)
  adj_probs  <- c(SLD = 0.40, STO = 0.55, PES = 0.30,
                  COO = 0.45, ANT = 0.20)
  selected <- character(0)
  for (cat in names(core_probs)) {
    if (runif(1) < core_probs[[cat]]) selected <- c(selected, cat)
  }
  for (cat in names(adj_probs)) {
    if (runif(1) < adj_probs[[cat]]) selected <- c(selected, cat)
  }
  # Qualification: at least one Core. If none, force DSS (the most common).
  if (!any(selected %in% IPK_CORE_CATS)) selected <- c("DSS", selected)
  selected
}

#' Sample SQ2 (target-window buyers) from SQ1 selections — a subset
#'
#' @param sq1 Character vector of SQ1 selections.
#' @return Character vector — subset of sq1 (lapsed buyers excluded).
ipk_sample_sq2_categories <- function(sq1) {
  # ~75% of SQ1 selections also bought in target window
  keep <- runif(length(sq1)) < 0.75
  sq1[keep]
}

#' Assign focal category — random pick from Core categories the respondent
#' selected in SQ1.
#'
#' @param sq1 Character vector of SQ1 selections.
#' @return Single category code or NA if respondent qualifies for no Core.
ipk_assign_focal <- function(sq1) {
  eligible <- intersect(sq1, IPK_CORE_CATS)
  if (length(eligible) == 0) return(NA_character_)
  sample(eligible, size = 1)
}

#' Sample from a discrete distribution
#'
#' Wrapper for sample() with named probs vector — used for demographics.
#'
#' @param dist List with $codes and $probs.
#' @return Single character code.
ipk_sample_discrete <- function(dist) {
  sample(dist$codes, size = 1, prob = dist$probs)
}

#' Coerce known-numeric columns from character to numeric
#'
#' AlchemerParser produces numeric columns for radio responses with numeric
#' reporting values (attitude codes 1-5, count codes, demographic codes). The
#' fixture generator stores these as character (sampling from c("1","2",...));
#' this helper coerces them so the fixture round-trips through openxlsx with
#' the right column types.
#'
#' Patterns coerced:
#'   * BRANDATT1_*, BRANDATT2_* — only BRANDATT1 (rejection OE stays character)
#'   * WOM_POS_COUNT_*, WOM_NEG_COUNT_*
#'   * CATBUY_*
#'   * DEMO_* (all)
#'
#' @param df Data frame.
#' @return Data frame with relevant columns coerced.
ipk_coerce_numeric_columns <- function(df) {
  patterns <- c(
    "^BRANDATT1_",
    "^WOM_POS_COUNT_",
    "^WOM_NEG_COUNT_",
    "^CATBUY_",
    "^DEMO_"
  )
  for (pat in patterns) {
    cols <- grep(pat, names(df), value = TRUE)
    for (col in cols) {
      df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
    }
  }
  df
}

#' Sample timestamps for Time.Started / Date.Submitted
#'
#' Uniformly distributed across a fictional Wave 1 fieldwork window.
#'
#' @param n Number of timestamps.
#' @return List of two character vectors: started + submitted.
ipk_sample_timestamps <- function(n) {
  start_pool <- as.POSIXct("2026-04-15 08:00:00", tz = "Africa/Johannesburg")
  end_pool   <- as.POSIXct("2026-04-28 18:00:00", tz = "Africa/Johannesburg")
  starts <- start_pool +
    runif(n, 0, as.numeric(difftime(end_pool, start_pool, units = "secs")))
  durations <- runif(n, 600, 1800)  # 10-30 minute completion
  submits <- starts + durations
  list(
    started   = format(starts,  "%d %B %Y %H:%M:%S"),
    submitted = format(submits, "%d %B %Y %H:%M:%S")
  )
}

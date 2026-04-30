# ==============================================================================
# IPK WAVE 1 FIXTURE — ADMIN + QUALIFYING + SCREENER
# ==============================================================================
# Generates the system / qualifying / SQ1 / SQ2 / focal-category portion of
# the dataset. All respondents in the fixture pass qualifying (target gender,
# target age range, no industry exclusion, metro region). Adds the Wave column
# at the end (wave-derived-in-prep_data convention from tracker module).
# ==============================================================================

#' Build the admin + qualifying + screener panel for all respondents
#'
#' @return Data frame with N_RESPONDENTS rows and the admin/screener columns.
ipk_build_admin_screener <- function() {

  n <- IPK_N_RESPONDENTS
  ts <- ipk_sample_timestamps(n)

  # System columns — leading "Response.ID" matches the Alchemer parser output
  # (uses BOM on first column; we use a clean name here, no BOM)
  out <- data.frame(
    Response.ID    = seq_len(n) + 3L,  # Alchemer numbers from ~4 in IPK
    Time.Started   = ts$started,
    Date.Submitted = ts$submitted,
    Status         = "Complete",
    Contact.ID     = NA_integer_,
    Tags           = NA_character_,
    IP.Address     = "156.155.20.130",
    Is_Dummy       = NA_character_,
    Focal_Category = NA_character_,
    stringsAsFactors = FALSE
  )

  # Consent + qualifying — all-pass values for fixture respondents
  out$I.agree.to.participate.in.this.survey <- "I agree"
  out$Gender          <- sample(IPK_QUAL_GENDER_VALUES, n, replace = TRUE)
  out$Age             <- sample(IPK_QUAL_AGE_VALUES, n, replace = TRUE)
  out$Industry_Screen <- sample(IPK_QUAL_INDUSTRY_VALUES, n, replace = TRUE)
  out$Region <- sample(IPK_QUAL_REGION_VALUES, n,
                       replace = TRUE, prob = IPK_QUAL_REGION_PROBS)

  # SQ1 + SQ2 + Focal_Category — generated per respondent
  sq1_n_slots <- length(IPK_CATEGORIES) + 1L  # 9 cats + 1 spare
  sq2_n_slots <- length(IPK_CATEGORIES)
  sq1_store <- list()
  sq2_store <- list()
  focal_vec <- character(n)

  for (i in seq_len(n)) {
    sq1 <- ipk_sample_sq1_categories()
    sq2 <- ipk_sample_sq2_categories(sq1)
    focal <- ipk_assign_focal(sq1)
    focal_vec[i] <- if (is.na(focal)) NA_character_ else focal

    sq1_store <- ipk_record_slots(sq1_store, "SQ1", sq1, sq1_n_slots, i)
    sq2_store <- ipk_record_slots(sq2_store, "SQ2", sq2, sq2_n_slots, i)
  }

  # Bind SQ1 / SQ2 columns in slot order
  for (j in seq_len(sq1_n_slots)) {
    col <- paste0("SQ1_", j)
    out[[col]] <- sq1_store[[col]] %||% rep(NA_character_, n)
  }
  out$Assign.Focal.Category    <- focal_vec
  out$Assign.Focal.Category.JS <- NA_character_
  for (j in seq_len(sq2_n_slots)) {
    col <- paste0("SQ2_", j)
    out[[col]] <- sq2_store[[col]] %||% rep(NA_character_, n)
  }

  out$Focal_Category <- focal_vec

  # Wave column — derived per tracker convention
  out$Wave <- IPK_WAVE

  list(
    data = out,
    sq1_categories = lapply(seq_len(n), function(i) {
      slots <- vapply(seq_len(sq1_n_slots),
                      function(j) sq1_store[[paste0("SQ1_", j)]][i],
                      character(1))
      slots[!is.na(slots)]
    }),
    sq2_categories = lapply(seq_len(n), function(i) {
      slots <- vapply(seq_len(sq2_n_slots),
                      function(j) sq2_store[[paste0("SQ2_", j)]][i],
                      character(1))
      slots[!is.na(slots)]
    }),
    focal = focal_vec
  )
}

# Null-coalescing operator (handy for store lookups when key is absent)
`%||%` <- function(a, b) if (is.null(a)) b else a

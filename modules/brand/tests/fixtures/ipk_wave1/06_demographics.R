# ==============================================================================
# IPK WAVE 1 FIXTURE — DEMOGRAPHICS
# ==============================================================================
# DEMO_* questions for all respondents. Coding: numeric codes (matching
# IPK_DEMO_* distributions in 01_constants.R).
# ==============================================================================

#' Build demographics columns for all respondents
#'
#' @return Data frame with N_RESPONDENTS rows.
ipk_build_demographics <- function() {
  n <- IPK_N_RESPONDENTS

  draw <- function(dist) sample(dist$codes, n, replace = TRUE,
                                 prob = dist$probs)

  data.frame(
    DEMO_AGE           = draw(IPK_DEMO_AGE),
    DEMO_GENDER        = draw(IPK_DEMO_GENDER),
    DEMO_PROVINCE      = draw(IPK_DEMO_PROVINCE),
    DEMO_GROCERY_ROLE  = draw(IPK_DEMO_GROCERY_ROLE),
    DEMO_HH_SIZE       = draw(IPK_DEMO_HH_SIZE),
    DEMO_EMPLOYMENT    = draw(IPK_DEMO_EMPLOYMENT),
    DEMO_SEM           = draw(IPK_DEMO_SEM),
    stringsAsFactors   = FALSE
  )
}

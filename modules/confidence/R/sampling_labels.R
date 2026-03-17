# ==============================================================================
# SAMPLING_LABELS.R - TURAS Confidence Module
# ==============================================================================
# Central terminology helper for sampling-method-aware labelling.
#
# Maps the Sampling_Method config value to a set of presentation labels.
# Probability designs (Random, Stratified, Cluster, Census) get standard
# statistical language ("Confidence Interval", "CI", "MOE").
# Non-probability designs (Quota, Online_Panel, Self_Selected, Not_Specified)
# get softened language ("Stability Interval", "SI", "Precision Estimate").
#
# Called by both the HTML report pipeline and the Excel output pipeline
# so that terminology is consistent across all outputs.
#
# USAGE:
#   source("modules/confidence/R/sampling_labels.R")
#   labels <- get_sampling_labels("Online_Panel")
#   labels$interval_name   # "Stability Interval"
#   labels$moe_abbrev      # "PE"
#   labels$is_probability  # FALSE
# ==============================================================================


#' Get Sampling-Method-Aware Terminology Labels
#'
#' Returns a named list of presentation labels appropriate for the given
#' sampling method. Probability designs get standard statistical language;
#' non-probability designs get softened language that honestly reflects
#' what the intervals actually measure.
#'
#' @param sampling_method Character. One of: Random, Stratified, Cluster,
#'   Quota, Online_Panel, Self_Selected, Census, Not_Specified.
#'   NULL, NA, or empty string treated as "Not_Specified".
#'
#' @return A named list with fields:
#'   \item{sampling_method_normalised}{Lowercase spec key (e.g. "panel", "random")}
#'   \item{is_probability}{Logical. TRUE for probability-based designs.}
#'   \item{interval_name}{Full name: "Confidence Interval" or "Stability Interval"}
#'   \item{interval_abbrev}{"CI" or "SI"}
#'   \item{moe_name}{"Margin of Error" or "Precision Estimate"}
#'   \item{moe_abbrev}{"MOE" or "PE"}
#'   \item{halfwidth_name}{"Half-Width" or "Precision Estimate"}
#'   \item{precision_term}{"margin of error" or "precision range" (lowercase, for prose)}
#'   \item{interval_term}{"confidence interval" or "stability interval" (lowercase, for prose)}
#'   \item{report_title}{HTML/Excel report title}
#'   \item{report_subtitle}{HTML report subtitle}
#'   \item{badge_text_fmt}{sprintf format for badge, e.g. "\%d\%\% Confidence"}
#'   \item{overview_title}{Summary panel card title}
#'
#' @examples
#' \dontrun{
#'   labels <- get_sampling_labels("Random")
#'   labels$interval_abbrev   # "CI"
#'   labels$is_probability    # TRUE
#'
#'   labels <- get_sampling_labels("Online_Panel")
#'   labels$interval_abbrev   # "SI"
#'   labels$is_probability    # FALSE
#'
#'   labels <- get_sampling_labels("Not_Specified")
#'   labels$interval_abbrev   # "SI"  (cautious default)
#' }
#'
#' @export
get_sampling_labels <- function(sampling_method = "Not_Specified") {

  # Normalise NULL / NA / empty to Not_Specified

  if (is.null(sampling_method) || length(sampling_method) == 0) {
    sampling_method <- "Not_Specified"
  }
  if (is.na(sampling_method) || !nzchar(trimws(sampling_method))) {
    sampling_method <- "Not_Specified"
  }
  sampling_method <- trimws(sampling_method)

  # Map config values to spec keys
  normalised <- switch(sampling_method,
    "Random"        = "random",
    "Stratified"    = "stratified",
    "Cluster"       = "cluster",
    "Census"        = "census",
    "Quota"         = "quota",
    "Online_Panel"  = "panel",
    "Self_Selected" = "convenience",
    "Not_Specified" = "not_specified",
    "not_specified"  # fallback: unrecognised values default to cautious framing
  )
  if (is.null(normalised)) normalised <- "not_specified"

  # Probability-based designs use standard CI/MOE language
  # Non-probability (including not_specified) uses softened SI/PE language
  use_standard <- normalised %in% c("random", "stratified", "cluster", "census")

  if (use_standard) {
    list(
      sampling_method_normalised = normalised,
      is_probability    = TRUE,
      interval_name     = "Confidence Interval",
      interval_abbrev   = "CI",
      moe_name          = "Margin of Error",
      moe_abbrev        = "MOE",
      halfwidth_name    = "Half-Width",
      precision_term    = "margin of error",
      interval_term     = "confidence interval",
      report_title      = "Turas Confidence Analysis",
      report_subtitle   = "Statistical confidence interval report",
      badge_text_fmt    = "%d%% Confidence",
      overview_title    = "Confidence Interval Overview"
    )
  } else {
    list(
      sampling_method_normalised = normalised,
      is_probability    = FALSE,
      interval_name     = "Stability Interval",
      interval_abbrev   = "SI",
      moe_name          = "Precision Estimate",
      moe_abbrev        = "PE",
      halfwidth_name    = "Precision Estimate",
      precision_term    = "precision range",
      interval_term     = "stability interval",
      report_title      = "Turas Precision Analysis",
      report_subtitle   = "Statistical precision and stability report",
      badge_text_fmt    = "%d%% Stability",
      overview_title    = "Stability Interval Overview"
    )
  }
}


# ==============================================================================
# CLUSTER WARNING HTML CONSTANT
# ==============================================================================
# Displayed in each question's detail panel when Sampling_Method is Cluster.
# Uses ci-callout-warning styling for prominence.

CLUSTER_WARNING_HTML <- paste0(
  '<div class="ci-callout ci-callout-warning">',
  '<strong>Clustering not adjusted.</strong> ',
  'These intervals assume independent observations. In a cluster sample, ',
  'respondents within the same cluster (e.g. branch, store, or team) tend to ',
  'respond similarly, which means the true uncertainty is larger than shown. ',
  'Differences near the margin of error should be interpreted with particular caution.',
  '</div>'
)

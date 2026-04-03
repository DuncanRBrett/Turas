# ==============================================================================
# AI SCHEMAS — Shared Structured Output Type Definitions
# ==============================================================================
#
# Defines ellmer type_object schemas used across all modules for:
#   - Verification (factual accuracy checking)
#   - Selectivity (editorial quality filtering)
#
# Module-specific schemas (e.g., ai_callout_schema, exec_patterns_schema)
# live in their respective module directories.
#
# Dependencies:
#   ellmer (CRAN) — type_object, type_boolean, type_string, type_array, type_enum
#
# Usage:
#   source("modules/shared/lib/ai/ai_schemas.R")
#   result <- call_insight_model(prompt, verification_schema, config)
#
# ==============================================================================


#' Verification schema — checks AI callout accuracy against source data
#'
#' Used by the verification pass to confirm that every number and significance
#' claim in an AI callout matches the source data exactly. Returns structured
#' boolean flags plus a description of any mismatches found.
verification_schema <- ellmer::type_object(
  "Verification of an AI callout against source data",

  numbers_accurate = ellmer::type_boolean(
    "TRUE if every number cited in the narrative matches the source data.
     FALSE if any number is wrong, rounded incorrectly, or fabricated."
  ),

  significance_accurate = ellmer::type_boolean(
    "TRUE if every significance claim matches the significance flags.
     FALSE if any claim of statistical significance is made for a
     non-significant difference, or vice versa."
  ),

  mismatches = ellmer::type_string(
    "Describe any specific mismatches found. Empty string if none."
  )
)


#' Selectivity schema — identifies low-value callouts for removal
#'
#' Used by the selectivity pass to review the full set of AI callouts and
#' flag any that merely restate what the chart shows without adding
#' interpretive value. Returns question codes to remove plus reasoning.
selectivity_schema <- ellmer::type_object(
  "Selectivity review of a set of AI callouts",

  remove_q_codes = ellmer::type_array(
    "Question codes of callouts that should be removed because they
     merely restate what the chart shows, state the obvious, or
     add no interpretive value beyond the raw numbers.",
    items = ellmer::type_string()
  ),

  reasoning = ellmer::type_string(
    "Brief explanation of why each flagged callout was deemed low-value."
  )
)

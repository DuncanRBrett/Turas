# ==============================================================================
# AI SCHEMAS TABS — Tabs-Specific Structured Output Type Definitions
# ==============================================================================
#
# Defines ellmer type_object schemas specific to the tabs module:
#   - ai_callout_schema      — per-question AI insight callout
#   - exec_patterns_schema   — executive summary Stage 1 (pattern identification)
#   - exec_narrative_schema  — executive summary Stage 2 (narrative generation)
#
# Shared schemas (verification, selectivity) live in modules/shared/lib/ai/.
#
# Dependencies:
#   ellmer (CRAN) — type_object, type_boolean, type_string, type_array, type_enum
#
# Usage:
#   source("modules/tabs/lib/ai/ai_schemas_tabs.R")
#   result <- call_insight_model(prompt, ai_callout_schema, config)
#
# ==============================================================================


#' Per-question AI callout schema
#'
#' Structured output for a single survey question's AI-assisted observation.
#' The LLM decides whether the data is noteworthy (has_insight) and, if so,
#' provides a 2-4 sentence observational narrative.
ai_callout_schema <- ellmer::type_object(
  "AI-assisted observational callout for a single survey question",

  has_insight = ellmer::type_boolean(
    "TRUE if the data shows a noteworthy pattern worth flagging.
     FALSE if results are flat and unremarkable across all subgroups."
  ),

  narrative = ellmer::type_string(
    "2-4 sentence observational commentary highlighting notable
     patterns, significant differences, or surprising results.
     Focus on what the data shows, not what the client should do.
     Empty string if has_insight is FALSE."
  ),

  confidence = ellmer::type_enum(
    "Confidence level based on base sizes and statistical robustness",
    values = c("high", "medium", "low")
  ),

  data_limitations = ellmer::type_string(
    "Any data quality caveats: small base sizes, marginal significance,
     high variance. Empty string if none."
  )
)


#' Executive summary pattern identification schema (Stage 1)
#'
#' Structured extraction of key patterns across all questions.
#' This feeds into Stage 2 (narrative generation).
exec_patterns_schema <- ellmer::type_object(
  "Structured identification of key patterns across all questions",

  strongest_measures = ellmer::type_array(
    "The 3-4 measures with the highest positive scores. Each entry must
     be a self-contained string in the format:
     '{q_code}: {measure} — {score} ({why notable})'
     Example: 'Q3: Brand Trust — 72% (highest score across all measures,
     significantly above Q7 Satisfaction at 54%)'",
    items = ellmer::type_string(
      "One strong measure: '{q_code}: {measure} — {score} ({why notable})'"
    )
  ),

  weakest_measures = ellmer::type_array(
    "The 3-4 measures with the lowest or most concerning scores. Each
     entry must be a self-contained string in the format:
     '{q_code}: {measure} — {score} ({why concerning})'
     Example: 'Q9: Delivery Speed — 31% good/excellent (lowest score,
     significantly below category average)'",
    items = ellmer::type_string(
      "One weak measure: '{q_code}: {measure} — {score} ({why concerning})'"
    )
  ),

  dominant_subgroup_pattern = ellmer::type_string(
    "Which banner dimension shows the most consistent and meaningful
     variation across multiple questions? Describe the pattern."
  ),

  cross_question_patterns = ellmer::type_array(
    "Patterns that emerge across multiple questions -- e.g., the same
     subgroup consistently under- or over-performing, or measures that
     move together.",
    items = ellmer::type_string()
  ),

  overall_assessment = ellmer::type_string(
    "One sentence: is this a healthy, mixed, or concerning result set?"
  )
)


#' Executive summary narrative schema (Stage 2)
#'
#' Synthesised executive summary narrative generated from
#' the patterns identified in Stage 1.
exec_narrative_schema <- ellmer::type_object(
  "Synthesised executive summary narrative",

  narrative = ellmer::type_string(
    "3-5 paragraph executive summary in continuous prose. No bullet
     points. No headers. Lead with the most commercially important
     finding."
  ),

  confidence = ellmer::type_enum(
    "Overall confidence level",
    values = c("high", "medium", "low")
  ),

  data_limitations = ellmer::type_string(
    "Any study-level data quality caveats. Empty string if none."
  )
)

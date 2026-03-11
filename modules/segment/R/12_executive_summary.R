# ==============================================================================
# SEGMENT MODULE - EXECUTIVE SUMMARY GENERATOR
# ==============================================================================
# Generates plain-English executive summary of segmentation results.
# Adapted from keydriver pattern for segmentation-specific insights.
#
# Generates: headline, key findings, quality assessment, per-segment
# descriptions, warnings, and recommendations.
#
# All functions use TRS refusal patterns (no stop()/warning()/message()).
# Console output uses cat("[INFO] ...") only.
#
# Version: 11.0
# ==============================================================================


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Generate Executive Summary of Segmentation Results
#'
#' Produces a structured, plain-English summary suitable for HTML reports,
#' Excel output, or console display.
#'
#' @param cluster_result Standard clustering result list
#' @param validation_metrics Validation metrics list
#' @param profile_result Profile result from create_full_segment_profile()
#' @param segment_names Character vector of segment names
#' @param config Configuration list
#' @param enhanced List of enhanced features (rules, cards, stability)
#' @return List with headline, key_findings, quality_assessment,
#'   segment_descriptions, warnings, recommendations
#' @export
generate_segment_executive_summary <- function(cluster_result,
                                                validation_metrics,
                                                profile_result,
                                                segment_names,
                                                config,
                                                enhanced = list()) {

  if (is.null(cluster_result) || !is.list(cluster_result)) {
    segment_refuse(
      code = "DATA_INVALID_RESULTS",
      title = "Invalid Clustering Results",
      problem = "The 'cluster_result' argument is NULL or not a list.",
      why_it_matters = "Executive summary requires valid clustering results.",
      how_to_fix = "Ensure clustering completed successfully before calling this function."
    )
  }

  k <- cluster_result$k
  method <- cluster_result$method %||% config$method %||% "kmeans"
  n_obs <- length(cluster_result$clusters)
  silhouette <- validation_metrics$avg_silhouette %||% NA_real_

  # Segment sizes
  seg_table <- table(cluster_result$clusters)
  seg_sizes <- as.integer(seg_table)
  seg_pcts <- round(seg_sizes / n_obs * 100, 1)

  warnings_out <- character(0)

  # --- 1. Headline ---
  headline <- .build_segment_headline(k, method, n_obs, silhouette, seg_pcts)

  # --- 2. Key findings ---
  key_findings <- character(0)

  # Segment distribution finding
  key_findings <- c(key_findings, .describe_segment_distribution(k, seg_sizes, seg_pcts, segment_names))

  # Dominant segment check
  dominant_msg <- .detect_dominant_segment(seg_pcts, segment_names, threshold = 40)
  if (!is.null(dominant_msg)) {
    key_findings <- c(key_findings, dominant_msg)
    warnings_out <- c(warnings_out, dominant_msg)
  }

  # Top differentiating variables
  if (!is.null(profile_result$clustering_profile)) {
    diff_msg <- .summarize_differentiating_variables(profile_result$clustering_profile, top_n = 3)
    if (!is.null(diff_msg)) {
      key_findings <- c(key_findings, diff_msg)
    }
  }

  # Method-specific insights
  method_msg <- .generate_method_insight(cluster_result, method)
  if (!is.null(method_msg)) {
    key_findings <- c(key_findings, method_msg)
  }

  # Stability insight
  if (!is.null(enhanced$stability)) {
    stability_msg <- .summarize_stability(enhanced$stability)
    if (!is.null(stability_msg)) {
      key_findings <- c(key_findings, stability_msg)
    }
  }

  # --- 3. Quality assessment ---
  quality_assessment <- .assess_segmentation_quality(silhouette, validation_metrics, k, n_obs)

  # Low quality warning
  if (!is.na(silhouette) && silhouette < 0.25) {
    low_q_msg <- sprintf(
      "Low cluster separation (silhouette=%.3f). Segments may not be clearly distinct - interpret with caution.",
      silhouette
    )
    warnings_out <- c(warnings_out, low_q_msg)
  }

  # --- 4. Per-segment descriptions ---
  segment_descriptions <- .generate_segment_descriptions(
    cluster_result, profile_result, segment_names, config
  )

  # --- 5. Recommendations ---
  recommendations <- .generate_segment_recommendations(
    k, silhouette, seg_pcts, method, enhanced, config
  )

  list(
    headline = headline,
    key_findings = key_findings,
    quality_assessment = quality_assessment,
    segment_descriptions = segment_descriptions,
    warnings = warnings_out,
    recommendations = recommendations
  )
}


# ==============================================================================
# FINDING GENERATORS
# ==============================================================================

#' Build Headline for Segmentation Summary
#' @keywords internal
.build_segment_headline <- function(k, method, n_obs, silhouette, seg_pcts) {

  method_label <- switch(method,
    kmeans = "K-means",
    hclust = "hierarchical",
    gmm = "Gaussian mixture model",
    method
  )

  quality <- if (is.na(silhouette)) {
    ""
  } else if (silhouette >= 0.50) {
    " with strong separation"
  } else if (silhouette >= 0.25) {
    " with reasonable separation"
  } else {
    " with weak separation"
  }

  # Check for balanced vs unbalanced
  balance <- if (max(seg_pcts) > 50) {
    " (one dominant segment)"
  } else if (max(seg_pcts) - min(seg_pcts) < 15) {
    " (well-balanced)"
  } else {
    ""
  }

  sprintf(
    "%s clustering identified %d distinct segments from %s respondents%s%s.",
    method_label, k, format(n_obs, big.mark = ","), quality, balance
  )
}


#' Describe Segment Size Distribution
#' @keywords internal
.describe_segment_distribution <- function(k, seg_sizes, seg_pcts, segment_names) {

  # Find largest and smallest
  largest_idx <- which.max(seg_sizes)
  smallest_idx <- which.min(seg_sizes)

  largest_name <- if (!is.null(segment_names) && length(segment_names) >= largest_idx) {
    segment_names[largest_idx]
  } else {
    paste("Segment", largest_idx)
  }

  smallest_name <- if (!is.null(segment_names) && length(segment_names) >= smallest_idx) {
    segment_names[smallest_idx]
  } else {
    paste("Segment", smallest_idx)
  }

  sprintf(
    "The largest segment is %s (%s%%, n=%s) and the smallest is %s (%s%%, n=%s).",
    largest_name, seg_pcts[largest_idx], format(seg_sizes[largest_idx], big.mark = ","),
    smallest_name, seg_pcts[smallest_idx], format(seg_sizes[smallest_idx], big.mark = ",")
  )
}


#' Detect Dominant Segment
#' @keywords internal
.detect_dominant_segment <- function(seg_pcts, segment_names, threshold = 40) {

  max_idx <- which.max(seg_pcts)
  max_pct <- seg_pcts[max_idx]

  if (max_pct > threshold) {
    seg_name <- if (!is.null(segment_names) && length(segment_names) >= max_idx) {
      segment_names[max_idx]
    } else {
      paste("Segment", max_idx)
    }

    sprintf(
      "Warning: %s contains %.0f%% of respondents - consider whether this segment can be meaningfully subdivided.",
      seg_name, max_pct
    )
  } else {
    NULL
  }
}


#' Summarize Top Differentiating Variables
#' @keywords internal
.summarize_differentiating_variables <- function(profile_df, top_n = 3) {

  if (is.null(profile_df) || nrow(profile_df) == 0) return(NULL)

  # Look for eta-squared or F-statistic columns
  eta_col <- NULL
  f_col <- NULL

  for (col in c("eta_sq", "eta_squared", "Eta_Sq", "Eta_Squared")) {
    if (col %in% names(profile_df)) { eta_col <- col; break }
  }

  for (col in c("F_statistic", "F_stat", "f_stat", "F")) {
    if (col %in% names(profile_df)) { f_col <- col; break }
  }

  # Use eta-squared if available, otherwise F-statistic
  sort_col <- eta_col %||% f_col
  if (is.null(sort_col)) return(NULL)

  # Sort by discriminating power
  valid_rows <- !is.na(profile_df[[sort_col]])
  if (sum(valid_rows) == 0) return(NULL)

  sorted <- profile_df[valid_rows, , drop = FALSE]
  sorted <- sorted[order(-sorted[[sort_col]]), , drop = FALSE]

  top_n_actual <- min(top_n, nrow(sorted))
  top_vars <- sorted$Variable[seq_len(top_n_actual)]

  if (!is.null(eta_col)) {
    top_etas <- round(sorted[[eta_col]][seq_len(top_n_actual)], 3)
    var_parts <- paste0(top_vars, " (\u03b7\u00b2=", top_etas, ")")
  } else {
    var_parts <- top_vars
  }

  sprintf(
    "The top %d differentiating variables are: %s.",
    top_n_actual, paste(var_parts, collapse = ", ")
  )
}


#' Generate Method-Specific Insight
#' @keywords internal
.generate_method_insight <- function(cluster_result, method) {

  info <- cluster_result$method_info
  if (is.null(info)) return(NULL)

  switch(method,
    kmeans = {
      if (!is.null(info$algorithm)) {
        if (info$algorithm == "mini-batch") {
          "Mini-batch K-means was used for computational efficiency on this larger dataset."
        } else {
          NULL
        }
      } else {
        NULL
      }
    },

    hclust = {
      msgs <- character(0)
      if (!is.null(info$linkage)) {
        msgs <- c(msgs, sprintf("Hierarchical clustering used %s linkage.", info$linkage))
      }
      if (!is.null(info$cophenetic_correlation) && !is.na(info$cophenetic_correlation)) {
        coph <- info$cophenetic_correlation
        quality <- if (coph >= 0.85) "excellent" else if (coph >= 0.70) "good" else "moderate"
        msgs <- c(msgs, sprintf("Cophenetic correlation is %.3f (%s dendrogram fidelity).", coph, quality))
      }
      if (length(msgs) > 0) paste(msgs, collapse = " ") else NULL
    },

    gmm = {
      msgs <- character(0)
      if (!is.null(info$model_name)) {
        msgs <- c(msgs, sprintf("Best GMM model type: %s.", info$model_name))
      }
      if (!is.null(info$bic)) {
        msgs <- c(msgs, sprintf("BIC = %.1f.", info$bic))
      }
      if (!is.null(info$n_borderline) && info$n_borderline > 0) {
        msgs <- c(msgs, sprintf(
          "%d respondents (%.1f%%) have borderline membership (uncertainty > 0.3).",
          info$n_borderline,
          info$n_borderline / length(cluster_result$clusters) * 100
        ))
      }
      if (length(msgs) > 0) paste(msgs, collapse = " ") else NULL
    },

    NULL
  )
}


#' Summarize Stability Assessment
#' @keywords internal
.summarize_stability <- function(stability_result) {

  if (is.null(stability_result)) return(NULL)

  jaccard <- stability_result$mean_jaccard %||% stability_result$avg_jaccard
  if (is.null(jaccard) || is.na(jaccard)) return(NULL)

  quality <- if (jaccard >= 0.85) {
    "highly stable"
  } else if (jaccard >= 0.75) {
    "reasonably stable"
  } else if (jaccard >= 0.60) {
    "moderately stable"
  } else {
    "unstable"
  }

  sprintf(
    "Bootstrap stability assessment: segments are %s (mean Jaccard = %.3f).",
    quality, jaccard
  )
}


# ==============================================================================
# QUALITY ASSESSMENT
# ==============================================================================

#' Assess Segmentation Quality
#' @keywords internal
.assess_segmentation_quality <- function(silhouette, validation_metrics, k, n_obs) {

  if (is.null(silhouette) || is.na(silhouette)) {
    return("Cluster quality metrics not available.")
  }

  # Silhouette interpretation
  sil_quality <- if (silhouette >= 0.70) {
    "strong"
  } else if (silhouette >= 0.50) {
    "good"
  } else if (silhouette >= 0.25) {
    "fair"
  } else {
    "weak"
  }

  bss_tss <- validation_metrics$betweenss_totss
  bss_msg <- if (!is.null(bss_tss) && !is.na(bss_tss)) {
    sprintf(", explaining %.0f%% of total variance", bss_tss * 100)
  } else {
    ""
  }

  obs_per_segment <- round(n_obs / k)
  ratio_msg <- sprintf("Average segment size is %s respondents", format(obs_per_segment, big.mark = ","))

  sprintf(
    "Overall segmentation quality is %s (silhouette = %.3f%s). %s.",
    sil_quality, silhouette, bss_msg, ratio_msg
  )
}


# ==============================================================================
# SEGMENT DESCRIPTIONS
# ==============================================================================

#' Generate Per-Segment Descriptions
#'
#' Creates a one-line description per segment based on its distinguishing
#' characteristics relative to the overall sample.
#'
#' @keywords internal
.generate_segment_descriptions <- function(cluster_result, profile_result,
                                            segment_names, config) {

  k <- cluster_result$k
  descriptions <- character(k)

  # Compute segment sizes and percentages from cluster assignments
  seg_table <- table(cluster_result$clusters)
  seg_sizes <- as.integer(seg_table)
  n_total <- length(cluster_result$clusters)
  seg_pcts <- round(seg_sizes / n_total * 100, 1)

  # Extract question labels from config (optional human-readable names)
  q_labels <- config$question_labels

  profile_df <- profile_result$clustering_profile
  if (is.null(profile_df)) {
    for (i in seq_len(k)) {
      name <- if (!is.null(segment_names) && length(segment_names) >= i) {
        segment_names[i]
      } else {
        paste("Segment", i)
      }
      descriptions[i] <- sprintf(
        "**%s** (n=%s, %s%%): Profile data not available.",
        name, format(seg_sizes[i], big.mark = ","), seg_pcts[i]
      )
    }
    return(descriptions)
  }

  # Find segment columns and overall column
  seg_cols <- paste0("Segment_", seq_len(k))
  overall_col <- "Overall"

  # Check columns exist
  available_seg_cols <- seg_cols[seg_cols %in% names(profile_df)]
  has_overall <- overall_col %in% names(profile_df)

  if (length(available_seg_cols) == 0) {
    for (i in seq_len(k)) {
      name <- if (!is.null(segment_names) && length(segment_names) >= i) {
        segment_names[i]
      } else {
        paste("Segment", i)
      }
      descriptions[i] <- sprintf(
        "**%s** (n=%s, %s%%): Segment column data not available.",
        name, format(seg_sizes[i], big.mark = ","), seg_pcts[i]
      )
    }
    return(descriptions)
  }

  # Helper: resolve a variable name to a human-readable label
  .resolve_label <- function(var_name, labels) {
    if (!is.null(labels) && var_name %in% names(labels)) {
      return(labels[[var_name]])
    }
    var_name
  }

  # Helper: map deviation magnitude to a strength descriptor
  .strength_descriptor <- function(deviation) {
    abs_dev <- abs(deviation)
    direction <- if (deviation > 0) "positive" else "negative"
    if (abs_dev > 30) {
      return(if (direction == "positive") "very high" else "very low")
    } else if (abs_dev > 15) {
      return(if (direction == "positive") "high" else "low")
    } else {
      return(if (direction == "positive") "slightly above average" else "slightly below average")
    }
  }

  for (i in seq_len(k)) {
    seg_col <- paste0("Segment_", i)
    name <- if (!is.null(segment_names) && length(segment_names) >= i) {
      segment_names[i]
    } else {
      paste("Segment", i)
    }

    size_label <- sprintf(
      "(n=%s, %s%%)",
      format(seg_sizes[i], big.mark = ","), seg_pcts[i]
    )

    if (!(seg_col %in% names(profile_df)) || !has_overall) {
      descriptions[i] <- sprintf(
        "**%s** %s: Detailed profile not available.", name, size_label
      )
      next
    }

    # Calculate deviations from overall
    seg_vals <- as.numeric(profile_df[[seg_col]])
    overall_vals <- as.numeric(profile_df[[overall_col]])
    vars <- profile_df$Variable

    valid <- !is.na(seg_vals) & !is.na(overall_vals) & overall_vals != 0
    if (sum(valid) == 0) {
      descriptions[i] <- sprintf(
        "**%s** %s: No valid comparison data.", name, size_label
      )
      next
    }

    # Index scores (segment / overall * 100)
    index_scores <- seg_vals[valid] / overall_vals[valid] * 100
    deviations <- index_scores - 100
    var_names <- vars[valid]

    # Sort by deviation magnitude
    pos_order <- order(-deviations)
    neg_order <- order(deviations)

    # Collect top 3 positive deviations (threshold > 5pt)
    pos_traits <- character(0)
    pos_labels_for_sketch <- character(0)
    n_pos <- min(3, sum(deviations > 5))
    if (n_pos > 0) {
      for (j in seq_len(n_pos)) {
        idx <- pos_order[j]
        if (deviations[idx] > 5) {
          label <- .resolve_label(var_names[idx], q_labels)
          strength <- .strength_descriptor(deviations[idx])
          pos_traits <- c(pos_traits, sprintf("%s %s", strength, label))
          pos_labels_for_sketch <- c(pos_labels_for_sketch, label)
        }
      }
    }

    # Collect top 2 negative deviations (threshold < -5pt)
    neg_traits <- character(0)
    neg_labels_for_sketch <- character(0)
    n_neg <- min(2, sum(deviations < -5))
    if (n_neg > 0) {
      for (j in seq_len(n_neg)) {
        idx <- neg_order[j]
        if (deviations[idx] < -5) {
          label <- .resolve_label(var_names[idx], q_labels)
          strength <- .strength_descriptor(deviations[idx])
          neg_traits <- c(neg_traits, sprintf("%s %s", strength, label))
          neg_labels_for_sketch <- c(neg_labels_for_sketch, label)
        }
      }
    }

    all_traits <- c(pos_traits, neg_traits)

    if (length(all_traits) > 0) {
      # Build a one-sentence pen sketch summary from top distinguishing traits
      sketch <- .build_pen_sketch(
        pos_labels_for_sketch, neg_labels_for_sketch, name
      )
      trait_list <- paste(all_traits, collapse = ", ")
      descriptions[i] <- sprintf(
        "**%s** %s: %s Key traits: %s.",
        name, size_label, sketch, trait_list
      )
    } else {
      descriptions[i] <- sprintf(
        "**%s** %s: This segment closely mirrors the overall sample with no strongly distinguishing characteristics.",
        name, size_label
      )
    }
  }

  descriptions
}


#' Build a One-Sentence Pen Sketch from Top Traits
#'
#' Constructs a natural-language summary sentence highlighting the most
#' distinguishing positive and negative characteristics.
#'
#' @param pos_labels Character vector of top positive trait labels.
#' @param neg_labels Character vector of top negative trait labels.
#' @param seg_name Name of the segment (for fallback phrasing).
#' @return A single sentence ending with a period.
#' @keywords internal
.build_pen_sketch <- function(pos_labels, neg_labels, seg_name) {
  has_pos <- length(pos_labels) > 0
  has_neg <- length(neg_labels) > 0

  if (has_pos && has_neg) {
    pos_phrase <- paste(pos_labels, collapse = " and ")
    neg_phrase <- paste(neg_labels, collapse = " and ")
    sprintf(
      "A group that stands out for elevated %s, combined with lower %s.",
      pos_phrase, neg_phrase
    )
  } else if (has_pos) {
    pos_phrase <- paste(pos_labels, collapse = ", ")
    sprintf(
      "A group distinguished by notably higher %s relative to the overall sample.",
      pos_phrase
    )
  } else if (has_neg) {
    neg_phrase <- paste(neg_labels, collapse = " and ")
    sprintf(
      "A group characterised by markedly lower %s compared to the overall sample.",
      neg_phrase
    )
  } else {
    sprintf("A segment with a profile close to the overall average.")
  }
}


# ==============================================================================
# RECOMMENDATIONS
# ==============================================================================

#' Generate Segmentation Recommendations
#' @keywords internal
.generate_segment_recommendations <- function(k, silhouette, seg_pcts, method,
                                               enhanced, config) {

  recs <- character(0)

  # Recommendation 1: Use segment assignments
  recs <- c(recs,
    "Use the segment assignment file to append segment membership to your data for cross-tabulation and driver analysis by segment."
  )

  # Recommendation 2: Quality-based
  if (!is.na(silhouette)) {
    if (silhouette < 0.25) {
      recs <- c(recs,
        sprintf(
          "Cluster separation is weak (silhouette = %.3f). Consider trying a different number of segments, alternative clustering method, or reviewing variable selection.",
          silhouette
        )
      )
    } else if (silhouette >= 0.50) {
      recs <- c(recs,
        "Segments show good separation - results are suitable for strategic decision-making and targeting."
      )
    }
  }

  # Recommendation 3: Balance-based
  if (max(seg_pcts) > 50) {
    recs <- c(recs,
      sprintf(
        "The largest segment contains %.0f%% of respondents. Consider whether this group can be further subdivided for more actionable targeting.",
        max(seg_pcts)
      )
    )
  }

  if (min(seg_pcts) < 5) {
    recs <- c(recs,
      sprintf(
        "The smallest segment is only %.0f%% of the sample. This may be too small for reliable analysis - consider merging with the most similar segment.",
        min(seg_pcts)
      )
    )
  }

  # Recommendation 4: Method-specific
  if (method == "kmeans" && is.null(enhanced$stability)) {
    recs <- c(recs,
      "Consider running a stability assessment (bootstrap) to verify segment robustness."
    )
  }

  # Recommendation 5: Cross-module
  recs <- c(recs,
    "Run key driver analysis and categorical driver analysis by segment to identify segment-specific improvement priorities."
  )

  # Cap at 4
  if (length(recs) > 4) recs <- recs[1:4]

  recs
}


# ==============================================================================
# FORMATTER
# ==============================================================================

#' Format Segment Executive Summary for Output
#'
#' Formats the summary list into plain text or HTML.
#'
#' @param summary_list List from generate_segment_executive_summary()
#' @param format "text" (default) or "html"
#' @return Character vector (text) or single HTML string
#' @export
format_segment_executive_summary <- function(summary_list, format = "text") {

  if (is.null(summary_list) || !is.list(summary_list)) {
    return("Executive summary not available.")
  }

  format <- tryCatch(
    match.arg(format, choices = c("text", "html")),
    error = function(e) {
      segment_refuse(
        code = "CFG_INVALID_FORMAT",
        title = "Invalid Summary Format",
        problem = sprintf("Format '%s' is not valid. Must be 'text' or 'html'.", format),
        why_it_matters = "Executive summary requires a supported output format.",
        how_to_fix = "Set format to 'text' or 'html'."
      )
    }
  )

  if (format == "text") {
    .format_segment_text(summary_list)
  } else {
    .format_segment_html(summary_list)
  }
}


#' Format Summary as Plain Text
#' @keywords internal
.format_segment_text <- function(s) {

  lines <- character(0)

  lines <- c(lines, "EXECUTIVE SUMMARY")
  lines <- c(lines, paste(rep("=", 60), collapse = ""))
  lines <- c(lines, "")
  lines <- c(lines, s$headline %||% "")
  lines <- c(lines, "")

  # Key Findings
  lines <- c(lines, "KEY FINDINGS:")
  lines <- c(lines, paste(rep("-", 40), collapse = ""))
  for (f in s$key_findings) {
    lines <- c(lines, paste0("  * ", f))
  }
  lines <- c(lines, "")

  # Quality Assessment
  lines <- c(lines, "QUALITY ASSESSMENT:")
  lines <- c(lines, paste(rep("-", 40), collapse = ""))
  lines <- c(lines, paste0("  ", s$quality_assessment %||% "Not assessed."))
  lines <- c(lines, "")

  # Segment Descriptions
  if (length(s$segment_descriptions) > 0) {
    lines <- c(lines, "SEGMENT DESCRIPTIONS:")
    lines <- c(lines, paste(rep("-", 40), collapse = ""))
    for (desc in s$segment_descriptions) {
      lines <- c(lines, paste0("  ", desc))
    }
    lines <- c(lines, "")
  }

  # Warnings
  if (length(s$warnings) > 0) {
    lines <- c(lines, "WARNINGS:")
    lines <- c(lines, paste(rep("-", 40), collapse = ""))
    for (w in s$warnings) {
      lines <- c(lines, paste0("  ! ", w))
    }
    lines <- c(lines, "")
  }

  # Recommendations
  lines <- c(lines, "RECOMMENDATIONS:")
  lines <- c(lines, paste(rep("-", 40), collapse = ""))
  for (i in seq_along(s$recommendations)) {
    lines <- c(lines, sprintf("  %d. %s", i, s$recommendations[i]))
  }
  lines <- c(lines, "")
  lines <- c(lines, paste(rep("=", 60), collapse = ""))

  lines
}


#' Format Summary as HTML
#' @keywords internal
.format_segment_html <- function(s) {

  # Turas design tokens
  heading_color <- "#1e293b"
  text_color <- "#334155"
  muted_color <- "#64748b"
  warning_color <- "#d97706"
  bg_color <- "#f8fafc"
  border_color <- "#e2e8f0"

  html <- paste0(
    '<div class="seg-exec-summary" style="font-family: \'Segoe UI\', Arial, sans-serif; ',
    'color: ', text_color, '; max-width: 720px; padding: 24px; ',
    'background: ', bg_color, '; border: 1px solid ', border_color, '; border-radius: 4px;">\n'
  )

  # Headline
  html <- paste0(html,
    '<h2 style="color: ', heading_color, '; font-size: 18px; font-weight: 600; ',
    'margin: 0 0 8px 0; padding-bottom: 8px; border-bottom: 2px solid var(--seg-brand, #323367);">',
    'Executive Summary</h2>\n',
    '<p style="font-size: 15px; font-weight: 500; margin: 0 0 20px 0; line-height: 1.5;">',
    .seg_html_escape(s$headline %||% ""), '</p>\n'
  )

  # Key Findings
  html <- paste0(html,
    '<h3 style="color: ', heading_color, '; font-size: 14px; font-weight: 600; ',
    'margin: 0 0 8px 0; text-transform: uppercase; letter-spacing: 0.5px;">Key Findings</h3>\n',
    '<ul style="margin: 0 0 20px 0; padding-left: 20px; line-height: 1.7;">\n'
  )
  for (f in s$key_findings) {
    html <- paste0(html, '<li style="font-size: 13px; margin-bottom: 4px;">',
                   .seg_html_escape(f), '</li>\n')
  }
  html <- paste0(html, '</ul>\n')

  # Quality Assessment
  html <- paste0(html,
    '<h3 style="color: ', heading_color, '; font-size: 14px; font-weight: 600; ',
    'margin: 0 0 8px 0; text-transform: uppercase; letter-spacing: 0.5px;">Quality Assessment</h3>\n',
    '<p style="font-size: 13px; margin: 0 0 20px 0; color: ', muted_color, '; line-height: 1.5;">',
    .seg_html_escape(s$quality_assessment %||% "Not assessed."), '</p>\n'
  )

  # Segment Descriptions
  if (length(s$segment_descriptions) > 0) {
    html <- paste0(html,
      '<h3 style="color: ', heading_color, '; font-size: 14px; font-weight: 600; ',
      'margin: 0 0 8px 0; text-transform: uppercase; letter-spacing: 0.5px;">Segment Profiles</h3>\n',
      '<ul style="margin: 0 0 20px 0; padding-left: 20px; line-height: 1.7;">\n'
    )
    for (desc in s$segment_descriptions) {
      html <- paste0(html, '<li style="font-size: 13px; margin-bottom: 4px;">',
                     .seg_html_escape(desc), '</li>\n')
    }
    html <- paste0(html, '</ul>\n')
  }

  # Warnings
  if (length(s$warnings) > 0) {
    html <- paste0(html,
      '<div style="background: #fffbeb; border: 1px solid ', warning_color, '; ',
      'border-radius: 4px; padding: 12px 16px; margin-bottom: 20px;">\n',
      '<h3 style="color: ', warning_color, '; font-size: 14px; font-weight: 600; ',
      'margin: 0 0 8px 0;">Warnings</h3>\n',
      '<ul style="margin: 0; padding-left: 20px;">\n'
    )
    for (w in s$warnings) {
      html <- paste0(html, '<li style="font-size: 13px; color: ', text_color,
                     '; margin-bottom: 4px;">', .seg_html_escape(w), '</li>\n')
    }
    html <- paste0(html, '</ul>\n</div>\n')
  }

  # Recommendations
  html <- paste0(html,
    '<h3 style="color: ', heading_color, '; font-size: 14px; font-weight: 600; ',
    'margin: 0 0 8px 0; text-transform: uppercase; letter-spacing: 0.5px;">Recommendations</h3>\n',
    '<ol style="margin: 0 0 12px 0; padding-left: 20px; line-height: 1.7;">\n'
  )
  for (rec in s$recommendations) {
    html <- paste0(html, '<li style="font-size: 13px; margin-bottom: 4px;">',
                   .seg_html_escape(rec), '</li>\n')
  }
  html <- paste0(html, '</ol>\n')

  html <- paste0(html, '</div>\n')
  html
}


#' HTML-Escape a String (segment module)
#' @keywords internal
.seg_html_escape <- function(x) {
  if (is.null(x) || length(x) == 0) return("")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

# ==============================================================================
# TURAS SEGMENTATION MODULE - SEGMENT ACTION CARDS
# ==============================================================================
# Feature 6: Auto-generate executive-ready segment summaries
# Part of Turas Segmentation Module
# ==============================================================================

#' Generate Segment Action Cards
#'
#' Creates concise, executive-ready summaries for each segment including
#' what defines them, strengths, pain points, and recommended actions.
#'
#' @param data Data frame with all variables
#' @param clusters Integer vector of segment assignments
#' @param clustering_vars Character vector of clustering variable names
#' @param segment_names Character vector of segment names
#' @param question_labels Named vector of question labels (optional)
#' @param scale_max Numeric, maximum value on rating scale (default: 10)
#'
#' @return List with cards (list of card data), cards_df (data frame), cards_text (character)
#' @export
#' @examples
#' cards <- generate_segment_cards(
#'   data = survey_data,
#'   clusters = result$clusters,
#'   clustering_vars = config$clustering_vars,
#'   segment_names = c("Advocates", "Satisfied", "At-Risk", "Detractors")
#' )
generate_segment_cards <- function(data, clusters, clustering_vars,
                                    segment_names = NULL, question_labels = NULL,
                                    scale_max = 10) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("GENERATING SEGMENT ACTION CARDS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  k <- length(unique(clusters))

  # Generate default segment names if not provided
  if (is.null(segment_names)) {
    segment_names <- paste0("Segment ", 1:k)
  }

  # ===========================================================================
  # CALCULATE SEGMENT STATISTICS
  # ===========================================================================

  segment_stats <- list()

  for (seg in 1:k) {
    seg_data <- data[clusters == seg, clustering_vars, drop = FALSE]
    all_data <- data[, clustering_vars, drop = FALSE]

    # Calculate means for segment and overall
    seg_means <- sapply(seg_data, mean, na.rm = TRUE)
    overall_means <- sapply(all_data, mean, na.rm = TRUE)

    # Calculate difference from overall
    diffs <- seg_means - overall_means

    # Identify strengths (high relative to overall) and weaknesses (low)
    high_threshold <- scale_max * 0.7  # e.g., > 7 on 10-point scale
    low_threshold <- scale_max * 0.4   # e.g., < 4 on 10-point scale
    diff_threshold <- 0.5  # At least 0.5 point difference

    # Strengths: high absolute AND high relative
    strengths_idx <- which(seg_means >= high_threshold & diffs > diff_threshold)
    # Weaknesses: low absolute AND low relative
    weaknesses_idx <- which(seg_means <= low_threshold & diffs < -diff_threshold)
    # Defining traits: biggest differences from overall
    defining_idx <- order(abs(diffs), decreasing = TRUE)[1:min(3, length(diffs))]

    segment_stats[[seg]] <- list(
      segment = seg,
      segment_name = segment_names[seg],
      n = sum(clusters == seg),
      pct = round(100 * sum(clusters == seg) / length(clusters), 1),
      means = seg_means,
      overall_means = overall_means,
      diffs = diffs,
      strengths = clustering_vars[strengths_idx],
      weaknesses = clustering_vars[weaknesses_idx],
      defining_vars = clustering_vars[defining_idx]
    )
  }

  # ===========================================================================
  # GENERATE CARDS
  # ===========================================================================

  cards <- list()
  cards_text <- character(0)

  for (seg in 1:k) {
    stats <- segment_stats[[seg]]

    # Build card components
    card <- list(
      segment_name = stats$segment_name,
      size = sprintf("%d respondents (%.0f%%)", stats$n, stats$pct),
      headline = generate_headline(stats, question_labels),
      defining_traits = generate_defining_traits(stats, question_labels, scale_max),
      strengths = generate_strengths_list(stats, question_labels, scale_max),
      pain_points = generate_pain_points_list(stats, question_labels, scale_max),
      recommended_actions = generate_recommended_actions(stats, question_labels)
    )

    cards[[seg]] <- card

    # Generate text version
    card_text <- format_card_text(card)
    cards_text <- c(cards_text, card_text)
  }

  # ===========================================================================
  # CREATE DATA FRAME VERSION
  # ===========================================================================

  cards_df <- data.frame(
    Segment = 1:k,
    Segment_Name = segment_names,
    Size_N = sapply(segment_stats, function(s) s$n),
    Size_Pct = sapply(segment_stats, function(s) s$pct),
    Headline = sapply(cards, function(c) c$headline),
    Key_Traits = sapply(cards, function(c) paste(c$defining_traits, collapse = "; ")),
    Strengths = sapply(cards, function(c) paste(c$strengths, collapse = "; ")),
    Pain_Points = sapply(cards, function(c) paste(c$pain_points, collapse = "; ")),
    Actions = sapply(cards, function(c) paste(c$recommended_actions, collapse = "; ")),
    stringsAsFactors = FALSE
  )

  # ===========================================================================
  # OUTPUT
  # ===========================================================================

  cat(sprintf("✓ Generated %d segment action cards\n\n", k))

  return(list(
    cards = cards,
    cards_df = cards_df,
    cards_text = cards_text,
    segment_stats = segment_stats
  ))
}


#' Generate Headline for Segment Card
#'
#' @param stats Segment statistics
#' @param question_labels Question labels
#' @return Character headline
#' @keywords internal
generate_headline <- function(stats, question_labels) {

  # Get top 2 defining characteristics
  top_vars <- stats$defining_vars[1:min(2, length(stats$defining_vars))]
  diffs <- stats$diffs[top_vars]

  # Determine sentiment
  avg_mean <- mean(stats$means)
  overall_avg <- mean(stats$overall_means)

  if (avg_mean > overall_avg + 1) {
    sentiment <- "High-satisfaction"
  } else if (avg_mean < overall_avg - 1) {
    sentiment <- "Low-satisfaction"
  } else {
    sentiment <- "Mixed-satisfaction"
  }

  # Build headline
  if (length(top_vars) > 0) {
    primary_trait <- top_vars[1]
    trait_direction <- if (diffs[primary_trait] > 0) "high" else "low"

    # Get label for trait
    trait_name <- if (!is.null(question_labels) && primary_trait %in% names(question_labels)) {
      question_labels[primary_trait]
    } else {
      primary_trait
    }

    headline <- sprintf("%s group with %s %s",
                        sentiment, trait_direction,
                        substr(trait_name, 1, 40))
  } else {
    headline <- sprintf("%s segment", sentiment)
  }

  return(headline)
}


#' Generate Defining Traits Description
#'
#' @param stats Segment statistics
#' @param question_labels Question labels
#' @param scale_max Maximum scale value
#' @return Character vector of traits
#' @keywords internal
generate_defining_traits <- function(stats, question_labels, scale_max) {

  traits <- character(0)

  for (var in stats$defining_vars) {
    mean_val <- stats$means[var]
    overall_val <- stats$overall_means[var]
    diff <- stats$diffs[var]

    # Get label
    var_name <- if (!is.null(question_labels) && var %in% names(question_labels)) {
      question_labels[var]
    } else {
      var
    }

    # Format trait
    direction <- if (diff > 0) "higher" else "lower"
    trait <- sprintf("%s: %.1f vs %.1f overall (%s)",
                     substr(var_name, 1, 35), mean_val, overall_val, direction)
    traits <- c(traits, trait)
  }

  return(traits)
}


#' Generate Strengths List
#'
#' @param stats Segment statistics
#' @param question_labels Question labels
#' @param scale_max Maximum scale value
#' @return Character vector of strengths
#' @keywords internal
generate_strengths_list <- function(stats, question_labels, scale_max) {

  if (length(stats$strengths) == 0) {
    return("No standout strengths identified")
  }

  strengths <- character(0)

  for (var in stats$strengths) {
    mean_val <- stats$means[var]

    var_name <- if (!is.null(question_labels) && var %in% names(question_labels)) {
      question_labels[var]
    } else {
      var
    }

    strength <- sprintf("%s (%.1f/%.0f)", substr(var_name, 1, 40), mean_val, scale_max)
    strengths <- c(strengths, strength)
  }

  return(strengths)
}


#' Generate Pain Points List
#'
#' @param stats Segment statistics
#' @param question_labels Question labels
#' @param scale_max Maximum scale value
#' @return Character vector of pain points
#' @keywords internal
generate_pain_points_list <- function(stats, question_labels, scale_max) {

  if (length(stats$weaknesses) == 0) {
    return("No major pain points identified")
  }

  pain_points <- character(0)

  for (var in stats$weaknesses) {
    mean_val <- stats$means[var]

    var_name <- if (!is.null(question_labels) && var %in% names(question_labels)) {
      question_labels[var]
    } else {
      var
    }

    point <- sprintf("%s (%.1f/%.0f)", substr(var_name, 1, 40), mean_val, scale_max)
    pain_points <- c(pain_points, point)
  }

  return(pain_points)
}


#' Generate Recommended Actions
#'
#' @param stats Segment statistics
#' @param question_labels Question labels
#' @return Character vector of recommendations
#' @keywords internal
generate_recommended_actions <- function(stats, question_labels) {

  actions <- character(0)
  avg_mean <- mean(stats$means)
  overall_avg <- mean(stats$overall_means)

  # High satisfaction segment
  if (avg_mean > overall_avg + 1) {
    actions <- c(actions,
                 "Leverage as brand advocates",
                 "Gather testimonials/case studies",
                 "Offer referral programs",
                 "Monitor for any declining satisfaction")
  }

  # Low satisfaction segment
  if (avg_mean < overall_avg - 1) {
    actions <- c(actions,
                 "Priority intervention needed",
                 "Conduct root cause analysis")

    # Add specific actions for pain points
    if (length(stats$weaknesses) > 0) {
      top_pain <- stats$weaknesses[1]
      pain_name <- if (!is.null(question_labels) && top_pain %in% names(question_labels)) {
        question_labels[top_pain]
      } else {
        top_pain
      }
      actions <- c(actions, sprintf("Focus improvement on: %s", substr(pain_name, 1, 30)))
    }
  }

  # Middle segment
  if (avg_mean >= overall_avg - 1 && avg_mean <= overall_avg + 1) {
    actions <- c(actions,
                 "Identify quick wins to move toward advocacy",
                 "Address any specific pain points")
    if (length(stats$strengths) > 0) {
      actions <- c(actions, "Build on existing strengths")
    }
  }

  # Default if no specific actions
  if (length(actions) == 0) {
    actions <- c("Monitor segment metrics over time",
                 "Compare with other segments regularly")
  }

  return(actions)
}


#' Format Card Text for Display
#'
#' @param card Card list from generate_segment_cards
#' @return Formatted text string
#' @keywords internal
format_card_text <- function(card) {

  lines <- c(
    "",
    paste(rep("=", 60), collapse = ""),
    sprintf("SEGMENT: %s", card$segment_name),
    paste(rep("=", 60), collapse = ""),
    "",
    sprintf("Size: %s", card$size),
    "",
    sprintf("HEADLINE: %s", card$headline),
    "",
    "DEFINING TRAITS:"
  )

  for (trait in card$defining_traits) {
    lines <- c(lines, sprintf("  - %s", trait))
  }

  lines <- c(lines, "", "STRENGTHS:")
  for (s in card$strengths) {
    lines <- c(lines, sprintf("  + %s", s))
  }

  lines <- c(lines, "", "PAIN POINTS:")
  for (p in card$pain_points) {
    lines <- c(lines, sprintf("  - %s", p))
  }

  lines <- c(lines, "", "RECOMMENDED ACTIONS:")
  for (a in card$recommended_actions) {
    lines <- c(lines, sprintf("  > %s", a))
  }

  lines <- c(lines, "")

  paste(lines, collapse = "\n")
}


#' Print Segment Cards to Console
#'
#' @param cards_result Result from generate_segment_cards()
#' @export
print_segment_cards <- function(cards_result) {
  for (card_text in cards_result$cards_text) {
    cat(card_text)
  }
}


#' Export Segment Cards to Text File
#'
#' @param cards_result Result from generate_segment_cards()
#' @param output_path File path
#' @export
export_cards_text <- function(cards_result, output_path) {

  all_text <- paste(
    "SEGMENT ACTION CARDS",
    paste(rep("=", 60), collapse = ""),
    sprintf("Generated: %s", Sys.time()),
    "",
    cards_result$cards_text,
    collapse = "\n"
  )

  writeLines(all_text, output_path)
  cat(sprintf("✓ Segment cards exported to: %s\n", output_path))
}


#' Export Segment Cards to Excel
#'
#' @param cards_result Result from generate_segment_cards()
#' @param output_path File path (.xlsx)
#' @export
export_cards_excel <- function(cards_result, output_path) {

  if (!requireNamespace("writexl", quietly = TRUE)) {
    segment_refuse(
      code = "PKG_WRITEXL_MISSING",
      title = "Package writexl Required",
      problem = "Package 'writexl' is not installed.",
      why_it_matters = "Excel export requires the writexl package.",
      how_to_fix = "Install the package with: install.packages('writexl')"
    )
  }

  # Create multiple sheets
  sheets <- list(
    "Summary" = cards_result$cards_df
  )

  # Add detailed card for each segment
  for (i in seq_along(cards_result$cards)) {
    card <- cards_result$cards[[i]]
    seg_name <- card$segment_name

    card_df <- data.frame(
      Category = c("Size", "Headline",
                   rep("Defining Trait", length(card$defining_traits)),
                   rep("Strength", length(card$strengths)),
                   rep("Pain Point", length(card$pain_points)),
                   rep("Action", length(card$recommended_actions))),
      Detail = c(card$size, card$headline,
                 card$defining_traits,
                 card$strengths,
                 card$pain_points,
                 card$recommended_actions),
      stringsAsFactors = FALSE
    )

    sheet_name <- substr(gsub("[^A-Za-z0-9]", "_", seg_name), 1, 31)
    sheets[[sheet_name]] <- card_df
  }

  writexl::write_xlsx(sheets, output_path)
  cat(sprintf("✓ Segment cards exported to: %s\n", output_path))
}

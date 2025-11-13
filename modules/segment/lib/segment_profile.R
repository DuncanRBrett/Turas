# ==============================================================================
# SEGMENT PROFILING
# ==============================================================================
# Calculate segment characteristics, means, ANOVA, demographics
# Part of Turas Segmentation Module
# ==============================================================================

#' Create segment profiles (mean values by segment)
#'
#' DESIGN: Calculates means for all variables by segment
#' RETURNS: Data frame with variables as rows, segments as columns
#'
#' @param data Data frame with variables to profile
#' @param clusters Integer vector, cluster assignments
#' @param var_names Character vector, variable names to profile
#' @return Data frame with profile statistics
#' @export
create_segment_profiles <- function(data, clusters, var_names = NULL) {
  if (is.null(var_names)) {
    var_names <- names(data)
  }

  # Filter to existing variables
  var_names <- intersect(var_names, names(data))

  if (length(var_names) == 0) {
    stop("No valid variables to profile", call. = FALSE)
  }

  # Get unique segments
  segments <- sort(unique(clusters))
  k <- length(segments)

  # Initialize results
  profile_df <- data.frame(
    Variable = var_names,
    Overall = numeric(length(var_names)),
    stringsAsFactors = FALSE
  )

  # Add columns for each segment
  for (seg in segments) {
    profile_df[[paste0("Segment_", seg)]] <- numeric(length(var_names))
  }

  # Calculate means
  for (i in seq_along(var_names)) {
    var <- var_names[i]

    # Check if variable is numeric
    if (!is.numeric(data[[var]])) {
      # For non-numeric, store NA
      profile_df$Overall[i] <- NA
      for (seg in segments) {
        profile_df[[paste0("Segment_", seg)]][i] <- NA
      }
      next
    }

    # Overall mean
    profile_df$Overall[i] <- mean(data[[var]], na.rm = TRUE)

    # Segment means
    for (seg in segments) {
      seg_data <- data[[var]][clusters == seg]
      profile_df[[paste0("Segment_", seg)]][i] <- mean(seg_data, na.rm = TRUE)
    }
  }

  return(profile_df)
}

#' Calculate statistical differences between segments (ANOVA)
#'
#' DESIGN: Tests if segment means differ significantly
#' RETURNS: F-statistics and p-values for each variable
#'
#' @param data Data frame with variables
#' @param clusters Integer vector, cluster assignments
#' @param var_names Character vector, variables to test
#' @return Data frame with F-statistics and p-values
#' @export
calculate_segment_differences <- function(data, clusters, var_names = NULL) {
  if (is.null(var_names)) {
    var_names <- names(data)
  }

  # Filter to existing numeric variables
  var_names <- intersect(var_names, names(data))
  numeric_vars <- c()
  for (var in var_names) {
    if (is.numeric(data[[var]])) {
      numeric_vars <- c(numeric_vars, var)
    }
  }

  if (length(numeric_vars) == 0) {
    return(data.frame(
      Variable = character(),
      F_statistic = numeric(),
      p_value = numeric(),
      stringsAsFactors = FALSE
    ))
  }

  # Initialize results
  anova_results <- data.frame(
    Variable = numeric_vars,
    F_statistic = numeric(length(numeric_vars)),
    p_value = numeric(length(numeric_vars)),
    stringsAsFactors = FALSE
  )

  # Run ANOVA for each variable
  for (i in seq_along(numeric_vars)) {
    var <- numeric_vars[i]

    tryCatch({
      # Run ANOVA
      aov_result <- aov(data[[var]] ~ factor(clusters))
      aov_summary <- summary(aov_result)

      # Extract F and p
      f_stat <- aov_summary[[1]]["F value"][1, 1]
      p_value <- aov_summary[[1]]["Pr(>F)"][1, 1]

      anova_results$F_statistic[i] <- f_stat
      anova_results$p_value[i] <- p_value

    }, error = function(e) {
      # If ANOVA fails, store NA
      anova_results$F_statistic[i] <- NA
      anova_results$p_value[i] <- NA
    })
  }

  return(anova_results)
}

#' Generate automatic segment names based on characteristics
#'
#' DESIGN: Simple descriptive names based on segment number
#' NOTE: Auto-naming based on profiles is Phase 2 enhancement
#'
#' @param k Integer, number of segments
#' @param method Character, naming method ("simple" or "auto")
#' @return Character vector of segment names
#' @export
generate_segment_names <- function(k, method = "simple") {
  if (method == "simple" || method == "auto") {
    # Simple numeric names for Phase 1
    return(paste0("Segment ", 1:k))
  }

  # Future: sophisticated auto-naming based on distinguishing characteristics
  return(paste0("Segment ", 1:k))
}

#' Create complete segment profile with statistics
#'
#' DESIGN: Combines profiles and ANOVA results
#' RETURNS: Comprehensive profile data frame
#'
#' @param data Data frame with variables
#' @param clusters Integer vector, cluster assignments
#' @param clustering_vars Character vector, clustering variable names
#' @param profile_vars Character vector, profile variable names
#' @return List with profiles, anova_results, segment_sizes
#' @export
create_full_segment_profile <- function(data, clusters, clustering_vars, profile_vars = NULL) {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("SEGMENT PROFILING\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")

  k <- length(unique(clusters))
  n <- length(clusters)

  # Segment sizes
  seg_sizes <- table(clusters)
  seg_pcts <- prop.table(seg_sizes) * 100

  cat("Segment sizes:\n")
  for (i in 1:k) {
    cat(sprintf("  Segment %d: %4d (%5.1f%%)\n", i, seg_sizes[i], seg_pcts[i]))
  }

  # Profile clustering variables
  cat("\nProfiling clustering variables...\n")
  clustering_profile <- create_segment_profiles(data, clusters, clustering_vars)
  clustering_anova <- calculate_segment_differences(data, clusters, clustering_vars)

  # Merge profiles and ANOVA
  clustering_full <- merge(clustering_profile, clustering_anova, by = "Variable", all.x = TRUE)

  # Profile additional variables if specified
  if (!is.null(profile_vars) && length(profile_vars) > 0) {
    cat(sprintf("Profiling %d additional variables...\n", length(profile_vars)))
    profile_profile <- create_segment_profiles(data, clusters, profile_vars)
    profile_anova <- calculate_segment_differences(data, clusters, profile_vars)
    profile_full <- merge(profile_profile, profile_anova, by = "Variable", all.x = TRUE)
  } else {
    profile_full <- NULL
  }

  cat("\n✓ Profiling complete\n")

  # Check significance
  sig_vars <- sum(clustering_anova$p_value < 0.05, na.rm = TRUE)
  cat(sprintf("  Clustering variables significantly different: %d/%d\n",
              sig_vars, nrow(clustering_anova)))

  return(list(
    clustering_profile = clustering_full,
    profile_profile = profile_full,
    segment_sizes = data.frame(
      Segment = 1:k,
      Count = as.vector(seg_sizes),
      Percentage = as.vector(seg_pcts)
    ),
    k = k,
    n = n
  ))
}

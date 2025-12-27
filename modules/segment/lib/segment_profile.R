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
  # Validate clusters length matches data rows
  if (length(clusters) != nrow(data)) {
    stop(sprintf(
      "Clusters length (%d) does not match data rows (%d). Ensure clusters were generated from the same data.",
      length(clusters), nrow(data)
    ), call. = FALSE)
  }

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


# ==============================================================================
# FEATURE 5: AUTO SEGMENT NAMING
# ==============================================================================

#' Auto-generate Descriptive Segment Names
#'
#' Generates meaningful segment names based on their distinguishing characteristics.
#' Analyzes the clustering variables to find what makes each segment unique.
#'
#' @param data Data frame with all variables
#' @param clusters Integer vector of segment assignments
#' @param clustering_vars Character vector of clustering variable names
#' @param question_labels Named vector of question labels (optional)
#' @param scale_max Numeric, maximum value on rating scale (default: 10)
#' @param name_style Character, naming style: "descriptive", "persona", or "emoji" (default: "descriptive")
#'
#' @return Character vector of segment names
#' @export
#' @examples
#' names <- auto_name_segments(
#'   data = survey_data,
#'   clusters = result$clusters,
#'   clustering_vars = config$clustering_vars,
#'   name_style = "descriptive"
#' )
auto_name_segments <- function(data, clusters, clustering_vars,
                                question_labels = NULL, scale_max = 10,
                                name_style = "descriptive") {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("AUTO-GENERATING SEGMENT NAMES\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  k <- length(unique(clusters))
  segment_names <- character(k)

  # Calculate overall means
  overall_means <- sapply(clustering_vars, function(v) mean(data[[v]], na.rm = TRUE))

  # High/mid/low thresholds
  high_threshold <- scale_max * 0.75   # e.g., 7.5 on 10-point scale
  low_threshold <- scale_max * 0.35    # e.g., 3.5 on 10-point scale
  mid_high <- scale_max * 0.6
  mid_low <- scale_max * 0.45

  for (seg in 1:k) {
    seg_data <- data[clusters == seg, clustering_vars, drop = FALSE]
    seg_means <- sapply(seg_data, mean, na.rm = TRUE)

    # Calculate how each segment differs from overall
    diffs <- seg_means - overall_means

    # Classify segment based on overall level
    avg_mean <- mean(seg_means)

    # Determine primary characteristic
    primary_trait <- NULL
    trait_direction <- NULL

    # Find the variable with biggest difference
    max_diff_idx <- which.max(abs(diffs))
    max_diff_var <- clustering_vars[max_diff_idx]
    max_diff <- diffs[max_diff_idx]

    if (name_style == "descriptive") {
      # Generate descriptive name based on overall satisfaction level
      if (avg_mean >= high_threshold) {
        # High satisfaction segment
        base_name <- "High Performers"
        if (max_diff > 1) {
          # Even higher on something specific
          trait_label <- get_short_trait_name(max_diff_var, question_labels)
          base_name <- paste0("Top ", trait_label)
        }
      } else if (avg_mean <= low_threshold) {
        # Low satisfaction segment
        base_name <- "At-Risk"
        if (max_diff < -1) {
          trait_label <- get_short_trait_name(max_diff_var, question_labels)
          base_name <- paste0("Low ", trait_label)
        }
      } else if (avg_mean > mid_high) {
        base_name <- "Satisfied"
      } else if (avg_mean < mid_low) {
        base_name <- "Dissatisfied"
      } else {
        base_name <- "Moderate"
      }

      # Add distinguishing detail if similar names
      segment_names[seg] <- base_name

    } else if (name_style == "persona") {
      # Generate persona-style names
      if (avg_mean >= high_threshold) {
        personas <- c("Champions", "Advocates", "Enthusiasts", "Promoters", "Loyalists")
        segment_names[seg] <- personas[((seg - 1) %% length(personas)) + 1]
      } else if (avg_mean <= low_threshold) {
        personas <- c("Detractors", "Critics", "Frustrated", "Disengaged", "At-Risk")
        segment_names[seg] <- personas[((seg - 1) %% length(personas)) + 1]
      } else {
        personas <- c("Moderates", "Neutrals", "Fence-Sitters", "Passives", "Middle-Ground")
        segment_names[seg] <- personas[((seg - 1) %% length(personas)) + 1]
      }

    } else if (name_style == "emoji") {
      # Generate emoji-style names
      if (avg_mean >= high_threshold) {
        segment_names[seg] <- paste0("Segment ", seg, " (High)")
      } else if (avg_mean <= low_threshold) {
        segment_names[seg] <- paste0("Segment ", seg, " (Low)")
      } else {
        segment_names[seg] <- paste0("Segment ", seg, " (Mid)")
      }
    }
  }

  # Ensure unique names by adding numbers if duplicates
  segment_names <- make_names_unique(segment_names)

  cat("Generated segment names:\n")
  for (seg in 1:k) {
    seg_size <- sum(clusters == seg)
    seg_pct <- 100 * seg_size / length(clusters)
    cat(sprintf("  Segment %d: %s (%.0f%%)\n", seg, segment_names[seg], seg_pct))
  }
  cat("\n")

  return(segment_names)
}


#' Get Short Trait Name from Variable
#'
#' @param var Variable name
#' @param question_labels Named vector of labels
#' @return Short descriptive name
#' @keywords internal
get_short_trait_name <- function(var, question_labels) {
  if (!is.null(question_labels) && var %in% names(question_labels)) {
    label <- question_labels[var]
    # Extract first meaningful word(s)
    words <- unlist(strsplit(label, " "))
    # Remove common prefixes
    skip_words <- c("Overall", "Satisfaction", "with", "the", "a", "an")
    meaningful <- words[!tolower(words) %in% tolower(skip_words)]
    if (length(meaningful) > 0) {
      return(paste(meaningful[1:min(2, length(meaningful))], collapse = " "))
    }
  }
  # Return cleaned variable name
  return(gsub("_", " ", gsub("^q[0-9]+_?", "", var)))
}


#' Make Names Unique
#'
#' @param names Character vector
#' @return Character vector with unique names
#' @keywords internal
make_names_unique <- function(names) {
  dup_counts <- table(names)
  duplicated_names <- names(dup_counts[dup_counts > 1])

  for (dup in duplicated_names) {
    indices <- which(names == dup)
    for (i in seq_along(indices)) {
      if (i > 1) {
        names[indices[i]] <- paste0(dup, " ", i)
      }
    }
  }

  return(names)
}


# ==============================================================================
# FEATURE 8: DEMOGRAPHIC PROFILING
# ==============================================================================

#' Profile Segments by Demographics
#'
#' Analyzes demographic composition of each segment including categorical
#' variables (gender, region, etc.) and numeric demographics (age, income).
#'
#' @param data Data frame with all variables
#' @param clusters Integer vector of segment assignments
#' @param demo_vars Character vector of demographic variable names
#' @param segment_names Character vector of segment names (optional)
#'
#' @return List with categorical_profiles, numeric_profiles, chi_sq_tests
#' @export
#' @examples
#' demo_profile <- profile_demographics(
#'   data = survey_data,
#'   clusters = result$clusters,
#'   demo_vars = c("gender", "age_group", "region", "income_bracket")
#' )
profile_demographics <- function(data, clusters, demo_vars,
                                  segment_names = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("DEMOGRAPHIC PROFILING\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  k <- length(unique(clusters))

  if (is.null(segment_names)) {
    segment_names <- paste0("Segment_", 1:k)
  }

  # Check which demo vars exist
  available_vars <- intersect(demo_vars, names(data))
  missing_vars <- setdiff(demo_vars, names(data))

  if (length(missing_vars) > 0) {
    cat(sprintf("Warning: Variables not found: %s\n",
                paste(missing_vars, collapse = ", ")))
  }

  if (length(available_vars) == 0) {
    stop("No demographic variables found in data", call. = FALSE)
  }

  # Separate categorical and numeric variables
  categorical_vars <- character(0)
  numeric_vars <- character(0)

  for (var in available_vars) {
    if (is.factor(data[[var]]) || is.character(data[[var]]) ||
        length(unique(data[[var]])) <= 10) {
      categorical_vars <- c(categorical_vars, var)
    } else if (is.numeric(data[[var]])) {
      numeric_vars <- c(numeric_vars, var)
    }
  }

  cat(sprintf("Profiling %d categorical and %d numeric demographics...\n\n",
              length(categorical_vars), length(numeric_vars)))

  # ===========================================================================
  # PROFILE CATEGORICAL DEMOGRAPHICS
  # ===========================================================================

  categorical_profiles <- list()
  chi_sq_tests <- list()

  for (var in categorical_vars) {
    cat(sprintf("Analyzing: %s\n", var))

    # Cross-tabulation
    cross_tab <- table(data[[var]], clusters)

    # Convert to percentages within each segment
    pct_tab <- prop.table(cross_tab, margin = 2) * 100

    # Add overall column
    overall_pct <- prop.table(table(data[[var]])) * 100

    # Create profile data frame
    profile_df <- as.data.frame.matrix(pct_tab)
    names(profile_df) <- segment_names[1:ncol(profile_df)]
    profile_df$Category <- rownames(profile_df)
    profile_df$Overall <- as.vector(overall_pct)

    # Reorder columns
    profile_df <- profile_df[, c("Category", "Overall", segment_names[1:k])]

    # Round percentages
    for (col in names(profile_df)[-1]) {
      profile_df[[col]] <- round(profile_df[[col]], 1)
    }

    categorical_profiles[[var]] <- profile_df

    # Chi-squared test
    tryCatch({
      chi_result <- chisq.test(cross_tab)
      chi_sq_tests[[var]] <- data.frame(
        Variable = var,
        Chi_Sq = round(chi_result$statistic, 2),
        DF = chi_result$parameter,
        P_Value = format(chi_result$p.value, scientific = TRUE, digits = 3),
        Significant = chi_result$p.value < 0.05,
        stringsAsFactors = FALSE
      )

      if (chi_result$p.value < 0.05) {
        cat(sprintf("  ✓ Significant difference (p < 0.05)\n"))
      } else {
        cat(sprintf("    Not significant (p = %.3f)\n", chi_result$p.value))
      }

    }, error = function(e) {
      cat(sprintf("  Warning: Chi-squared test failed: %s\n", e$message))
      chi_sq_tests[[var]] <- data.frame(
        Variable = var,
        Chi_Sq = NA,
        DF = NA,
        P_Value = NA,
        Significant = NA,
        stringsAsFactors = FALSE
      )
    })
  }

  # ===========================================================================
  # PROFILE NUMERIC DEMOGRAPHICS
  # ===========================================================================

  numeric_profiles <- list()

  if (length(numeric_vars) > 0) {
    for (var in numeric_vars) {
      cat(sprintf("Analyzing: %s\n", var))

      # Calculate stats by segment
      stats_df <- data.frame(
        Segment = segment_names[1:k],
        N = numeric(k),
        Mean = numeric(k),
        Median = numeric(k),
        SD = numeric(k),
        Min = numeric(k),
        Max = numeric(k),
        stringsAsFactors = FALSE
      )

      for (seg in 1:k) {
        seg_data <- data[[var]][clusters == seg]
        seg_data <- seg_data[!is.na(seg_data)]

        stats_df$N[seg] <- length(seg_data)
        stats_df$Mean[seg] <- round(mean(seg_data), 1)
        stats_df$Median[seg] <- round(median(seg_data), 1)
        stats_df$SD[seg] <- round(sd(seg_data), 1)
        stats_df$Min[seg] <- min(seg_data)
        stats_df$Max[seg] <- max(seg_data)
      }

      # Add overall row
      all_data <- data[[var]][!is.na(data[[var]])]
      overall_row <- data.frame(
        Segment = "Overall",
        N = length(all_data),
        Mean = round(mean(all_data), 1),
        Median = round(median(all_data), 1),
        SD = round(sd(all_data), 1),
        Min = min(all_data),
        Max = max(all_data),
        stringsAsFactors = FALSE
      )
      stats_df <- rbind(stats_df, overall_row)

      numeric_profiles[[var]] <- stats_df

      # ANOVA test
      tryCatch({
        anova_result <- aov(data[[var]] ~ as.factor(clusters))
        anova_summary <- summary(anova_result)
        p_value <- anova_summary[[1]]$`Pr(>F)`[1]

        if (p_value < 0.05) {
          cat(sprintf("  ✓ Significant difference (p < 0.05)\n"))
        } else {
          cat(sprintf("    Not significant (p = %.3f)\n", p_value))
        }
      }, error = function(e) {
        cat(sprintf("  Warning: ANOVA test failed\n"))
      })
    }
  }

  # ===========================================================================
  # COMBINE CHI-SQUARED TESTS
  # ===========================================================================

  chi_sq_combined <- do.call(rbind, chi_sq_tests)

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("DEMOGRAPHIC PROFILE SUMMARY\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  n_sig <- sum(chi_sq_combined$Significant, na.rm = TRUE)
  cat(sprintf("Categorical variables with significant segment differences: %d/%d\n",
              n_sig, length(categorical_vars)))

  if (n_sig > 0) {
    sig_vars <- chi_sq_combined$Variable[chi_sq_combined$Significant == TRUE]
    cat(sprintf("  Significant: %s\n", paste(sig_vars, collapse = ", ")))
  }

  cat("\n")

  return(list(
    categorical_profiles = categorical_profiles,
    numeric_profiles = numeric_profiles,
    chi_sq_tests = chi_sq_combined,
    segment_names = segment_names
  ))
}


#' Export Demographic Profiles to Excel
#'
#' @param demo_result Result from profile_demographics()
#' @param output_path Path to Excel file
#' @export
export_demographic_profiles <- function(demo_result, output_path) {

  if (!requireNamespace("writexl", quietly = TRUE)) {
    stop("Package 'writexl' required for Excel export", call. = FALSE)
  }

  sheets <- list()

  # Summary sheet with chi-squared tests
  sheets[["Summary"]] <- demo_result$chi_sq_tests

  # Categorical profiles
  for (var in names(demo_result$categorical_profiles)) {
    sheet_name <- substr(paste0("Cat_", var), 1, 31)
    sheets[[sheet_name]] <- demo_result$categorical_profiles[[var]]
  }

  # Numeric profiles
  for (var in names(demo_result$numeric_profiles)) {
    sheet_name <- substr(paste0("Num_", var), 1, 31)
    sheets[[sheet_name]] <- demo_result$numeric_profiles[[var]]
  }

  writexl::write_xlsx(sheets, output_path)
  cat(sprintf("✓ Demographic profiles exported to: %s\n", basename(output_path)))
}

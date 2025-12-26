# ==============================================================================
# TURAS SEGMENTATION MODULE - LATENT CLASS ANALYSIS (LCA)
# ==============================================================================
# Feature 12: Alternative to k-means for categorical/ordinal data
# Part of Turas Segmentation Module
#
# LCA is preferred over k-means when:
#   - Variables are categorical or ordinal (Likert scales)
#   - You want probabilistic class membership (soft clustering)
#   - You need fit statistics (AIC, BIC) for model comparison
#
# Key functions:
#   - run_lca(): Main LCA function (exploration or final mode)
#   - calculate_entropy_rsquared(): Classification quality metric
#   - create_lca_profiles(): Generate class response profiles
#   - type_respondent_lca(): Classify new respondents using saved model
#   - compare_kmeans_lca(): Compare both methods on same data
#
# Package dependency: poLCA (required for LCA)
# ==============================================================================


# ==============================================================================
# ENTROPY R-SQUARED (CLASSIFICATION QUALITY)
# ==============================================================================

#' Calculate Entropy R-Squared for LCA Model
#'
#' Entropy R-squared measures classification certainty. Values closer to 1
#' indicate respondents are clearly assigned to one class. Values near 0
#' indicate fuzzy boundaries between classes.
#'
#' Interpretation:
#'   > 0.80: Excellent classification quality
#'   0.60 - 0.80: Good classification quality
#'   0.40 - 0.60: Moderate classification quality
#'   < 0.40: Poor classification quality (consider different k)
#'
#' @param posterior Matrix of posterior probabilities (n x k)
#' @param class_probs Vector of class proportions (length k)
#' @return Numeric, entropy R-squared value between 0 and 1
#' @export
#' @examples
#' # After running LCA:
#' entropy_rsq <- calculate_entropy_rsquared(lca_result$posterior, lca_result$P)
calculate_entropy_rsquared <- function(posterior, class_probs) {

  if (is.null(posterior) || !is.matrix(posterior)) {
    warning("Posterior probabilities required for entropy calculation")
    return(NA_real_)
  }

  n <- nrow(posterior)
  k <- ncol(posterior)

  if (k < 2) {
    return(1.0)  # Perfect classification with single class
  }

  # Calculate entropy of posterior probabilities
  # E_k = -sum(p * log(p)) for each respondent, then average
  posterior_entropy <- 0
  for (i in 1:n) {
    p <- posterior[i, ]
    # Avoid log(0) by filtering zeros
    p <- p[p > 0]
    posterior_entropy <- posterior_entropy + sum(-p * log(p))
  }
  posterior_entropy <- posterior_entropy / n

  # Calculate maximum possible entropy (uniform distribution)
  max_entropy <- -sum(class_probs * log(class_probs))

  # If max entropy is 0, return NA (shouldn't happen with k >= 2)
  if (max_entropy == 0) {
    return(NA_real_)
  }

  # Entropy R-squared = 1 - (observed entropy / max entropy)
  entropy_rsq <- 1 - (posterior_entropy / max_entropy)

  # Bound to [0, 1]
  entropy_rsq <- max(0, min(1, entropy_rsq))

  return(entropy_rsq)
}


#' Interpret Entropy R-Squared Value
#'
#' @param entropy_rsq Numeric entropy R-squared value
#' @return Character interpretation
#' @keywords internal
interpret_entropy_rsquared <- function(entropy_rsq) {
  if (is.na(entropy_rsq)) {
    return("Unknown (calculation failed)")
  } else if (entropy_rsq >= 0.80) {
    return("Excellent - clear class separation")
  } else if (entropy_rsq >= 0.60) {
    return("Good - adequate class separation")
  } else if (entropy_rsq >= 0.40) {
    return("Moderate - some overlap between classes")
  } else {
    return("Poor - consider different number of classes")
  }
}


#' Run Latent Class Analysis (LCA)
#'
#' Alternative to k-means clustering, particularly suited for categorical
#' or ordinal data. Uses poLCA package for estimation.
#'
#' @param data Data frame with all variables
#' @param id_var Character, name of ID variable
#' @param clustering_vars Character vector of clustering variable names
#' @param n_classes Integer or NULL. If NULL, tests range from n_min to n_max.
#' @param n_min Integer, minimum number of classes to test (default: 2)
#' @param n_max Integer, maximum number of classes to test (default: 6)
#' @param nrep Integer, number of random starts (default: 10)
#' @param output_folder Character, path for outputs
#' @param question_labels Named vector of question labels (optional)
#'
#' @return List with model, classes, class_probabilities, fit_statistics
#' @export
#' @examples
#' lca_result <- run_lca(
#'   data = survey_data,
#'   id_var = "respondent_id",
#'   clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
#'   n_classes = NULL,  # exploration mode
#'   n_max = 5
#' )
run_lca <- function(data, id_var, clustering_vars, n_classes = NULL,
                    n_min = 2, n_max = 6, nrep = 10,
                    output_folder = "output/", question_labels = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("LATENT CLASS ANALYSIS (LCA)\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # ===========================================================================
  # CHECK POLCA PACKAGE (TRS-compliant refusal)
  # ===========================================================================

  if (!requireNamespace("poLCA", quietly = TRUE)) {
    # Source guard layer if not already loaded
    if (!exists("segment_refuse", mode = "function")) {
      guard_path <- file.path(dirname(sys.frame(1)$ofile), "00_guard.R")
      if (file.exists(guard_path)) source(guard_path)
    }

    if (exists("segment_refuse", mode = "function")) {
      segment_refuse(
        code = "PKG_POLCA_MISSING",
        title = "poLCA Package Not Installed",
        problem = "The 'poLCA' package is required for Latent Class Analysis but is not installed.",
        why_it_matters = "LCA cannot be performed without the poLCA package. This package provides the statistical algorithms for fitting latent class models.",
        how_to_fix = c(
          "Install poLCA: install.packages('poLCA')",
          "Or use k-means clustering: Set method='kmeans' in your config"
        )
      )
    } else {
      stop("Package 'poLCA' required for Latent Class Analysis.\n",
           "Install with: install.packages('poLCA')\n\n",
           "Alternative: Use standard k-means with method='kmeans' in config.",
           call. = FALSE)
    }
  }

  # ===========================================================================
  # PREPARE DATA
  # ===========================================================================

  cat("Preparing data for LCA...\n")

  # Check variables exist
  missing_vars <- setdiff(clustering_vars, names(data))
  if (length(missing_vars) > 0) {
    stop(sprintf("Variables not found in data: %s",
                 paste(missing_vars, collapse = ", ")),
         call. = FALSE)
  }

  # LCA requires positive integers (categories starting at 1)
  lca_data <- data[, clustering_vars, drop = FALSE]

  # Convert to categorical - poLCA needs factors or positive integers
  for (var in clustering_vars) {
    vals <- lca_data[[var]]

    # Handle missing values
    if (any(is.na(vals))) {
      cat(sprintf("  Warning: %s has %d missing values\n",
                  var, sum(is.na(vals))))
    }

    # Convert to positive integers (1-based)
    if (is.numeric(vals)) {
      # Shift to start at 1 if necessary
      min_val <- min(vals, na.rm = TRUE)
      if (min_val < 1) {
        lca_data[[var]] <- vals - min_val + 1
      }
      # Also round if not integers
      lca_data[[var]] <- round(lca_data[[var]])
    } else if (is.factor(vals)) {
      lca_data[[var]] <- as.integer(vals)
    }
  }

  # Remove rows with missing values
  complete_rows <- complete.cases(lca_data)
  n_removed <- sum(!complete_rows)
  if (n_removed > 0) {
    cat(sprintf("  Removed %d rows with missing values\n", n_removed))
    lca_data <- lca_data[complete_rows, ]
    data <- data[complete_rows, ]
  }

  cat(sprintf("✓ Data prepared: %d respondents, %d variables\n\n",
              nrow(lca_data), length(clustering_vars)))

  # ===========================================================================
  # BUILD FORMULA
  # ===========================================================================

  formula_str <- paste("cbind(", paste(clustering_vars, collapse = ", "), ") ~ 1")
  lca_formula <- as.formula(formula_str)

  # ===========================================================================
  # RUN LCA
  # ===========================================================================

  if (is.null(n_classes)) {
    # =========================================================================
    # EXPLORATION MODE: Test multiple class solutions
    # =========================================================================

    cat("EXPLORATION MODE: Testing ", n_min, " to ", n_max, " classes\n")
    cat(paste(rep("-", 60), collapse = ""), "\n\n")

    results <- list()
    fit_stats <- data.frame(
      n_classes = integer(0),
      llik = numeric(0),
      AIC = numeric(0),
      BIC = numeric(0),
      Gsq = numeric(0),
      df = integer(0),
      stringsAsFactors = FALSE
    )

    for (nclass in n_min:n_max) {
      cat(sprintf("Testing %d classes...\n", nclass))

      tryCatch({
        # Suppress output during fitting
        capture.output({
          model <- poLCA::poLCA(
            lca_formula,
            data = lca_data,
            nclass = nclass,
            nrep = nrep,
            verbose = FALSE,
            na.rm = TRUE
          )
        })

        results[[as.character(nclass)]] <- model

        fit_stats <- rbind(fit_stats, data.frame(
          n_classes = nclass,
          llik = model$llik,
          AIC = model$aic,
          BIC = model$bic,
          Gsq = model$Gsq,
          df = model$resid.df,
          stringsAsFactors = FALSE
        ))

        cat(sprintf("  AIC: %.1f, BIC: %.1f\n", model$aic, model$bic))

      }, error = function(e) {
        cat(sprintf("  Error fitting %d classes: %s\n", nclass, e$message))
      })
    }

    # =========================================================================
    # DETERMINE OPTIMAL NUMBER OF CLASSES
    # =========================================================================

    if (nrow(fit_stats) == 0) {
      stop("No LCA models could be fitted", call. = FALSE)
    }

    # Select based on BIC (lower is better)
    best_idx <- which.min(fit_stats$BIC)
    optimal_classes <- fit_stats$n_classes[best_idx]
    best_model <- results[[as.character(optimal_classes)]]

    cat("\n")
    cat(paste(rep("=", 60), collapse = ""), "\n")
    cat("MODEL SELECTION\n")
    cat(paste(rep("=", 60), collapse = ""), "\n")
    cat("\n")
    cat("Fit Statistics:\n")
    print(fit_stats)
    cat("\n")
    cat(sprintf("✓ Optimal number of classes (lowest BIC): %d\n", optimal_classes))
    cat(sprintf("  BIC: %.1f\n", fit_stats$BIC[best_idx]))

    # Export exploration report
    output_folder <- create_output_folder(output_folder, TRUE)
    report_path <- file.path(output_folder, "lca_exploration_report.xlsx")

    export_lca_exploration(fit_stats, results, report_path)

    return(list(
      mode = "exploration",
      optimal_classes = optimal_classes,
      fit_statistics = fit_stats,
      all_models = results,
      best_model = best_model,
      recommended_k = optimal_classes,
      output_files = list(report = report_path)
    ))

  } else {
    # =========================================================================
    # FINAL MODE: Fit specified number of classes
    # =========================================================================

    cat(sprintf("FINAL MODE: Fitting %d-class model\n", n_classes))
    cat(paste(rep("-", 60), collapse = ""), "\n\n")

    model <- poLCA::poLCA(
      lca_formula,
      data = lca_data,
      nclass = n_classes,
      nrep = nrep,
      verbose = FALSE,
      na.rm = TRUE
    )

    # Get class assignments
    classes <- model$predclass

    # Get class probabilities (posterior probabilities)
    class_probs <- model$posterior

    # =========================================================================
    # CALCULATE CLASSIFICATION QUALITY
    # =========================================================================

    entropy_rsq <- calculate_entropy_rsquared(class_probs, model$P)

    # =========================================================================
    # OUTPUT RESULTS
    # =========================================================================

    cat(sprintf("✓ %d-class LCA model fitted\n\n", n_classes))

    cat("Model Fit:\n")
    cat(sprintf("  Log-likelihood: %.1f\n", model$llik))
    cat(sprintf("  AIC: %.1f\n", model$aic))
    cat(sprintf("  BIC: %.1f\n", model$bic))
    cat(sprintf("  G-squared: %.1f (df = %d)\n", model$Gsq, model$resid.df))
    cat(sprintf("  Entropy R-sq: %.3f (%s)\n", entropy_rsq,
                interpret_entropy_rsquared(entropy_rsq)))

    cat("\nClass Distribution:\n")
    class_table <- table(classes)
    for (cls in 1:n_classes) {
      n_cls <- sum(classes == cls)
      pct <- 100 * n_cls / length(classes)
      cat(sprintf("  Class %d: %d (%.1f%%)\n", cls, n_cls, pct))
    }

    # Create output folder and export
    output_folder <- create_output_folder(output_folder, TRUE)

    # Export assignments
    assignments <- data.frame(
      ID = data[[id_var]],
      Class = classes,
      stringsAsFactors = FALSE
    )

    # Add probability columns
    for (cls in 1:n_classes) {
      assignments[[paste0("Prob_Class_", cls)]] <- round(class_probs[, cls], 3)
    }

    assignments$Max_Probability <- apply(class_probs, 1, max)
    assignments$Assignment_Certainty <- ifelse(
      assignments$Max_Probability > 0.7, "High",
      ifelse(assignments$Max_Probability > 0.5, "Medium", "Low")
    )

    assignments_path <- file.path(output_folder, "lca_class_assignments.xlsx")
    writexl::write_xlsx(assignments, assignments_path)
    cat(sprintf("\n✓ Class assignments saved to: %s\n", basename(assignments_path)))

    # Export profiles
    profiles <- create_lca_profiles(model, clustering_vars, question_labels)
    profiles_path <- file.path(output_folder, "lca_class_profiles.xlsx")
    writexl::write_xlsx(profiles, profiles_path)
    cat(sprintf("✓ Class profiles saved to: %s\n", basename(profiles_path)))

    # Save model
    model_path <- file.path(output_folder, "lca_model.rds")

    model_object <- list(
      model = model,
      method = "lca",
      k = n_classes,
      classes = classes,
      class_probabilities = class_probs,
      clustering_vars = clustering_vars,
      id_variable = id_var,
      timestamp = Sys.time(),
      turas_version = "1.0"
    )

    saveRDS(model_object, model_path)
    cat(sprintf("✓ Model saved to: %s\n", basename(model_path)))

    cat("\n")

    return(list(
      mode = "final",
      model = model,
      k = n_classes,
      classes = classes,
      class_probabilities = class_probs,
      entropy_rsquared = entropy_rsq,
      fit_statistics = data.frame(
        llik = model$llik,
        AIC = model$aic,
        BIC = model$bic,
        Gsq = model$Gsq,
        df = model$resid.df,
        entropy_rsq = entropy_rsq
      ),
      profiles = profiles,
      output_files = list(
        assignments = assignments_path,
        profiles = profiles_path,
        model = model_path
      )
    ))
  }
}


#' Create LCA Class Profiles
#'
#' @param model poLCA model object
#' @param clustering_vars Character vector of variable names
#' @param question_labels Named vector of question labels
#' @return List of data frames for Excel export
#' @keywords internal
create_lca_profiles <- function(model, clustering_vars, question_labels = NULL) {

  n_classes <- length(model$P)

  # Get conditional probabilities (item response probabilities)
  probs <- model$probs

  # Create profile summary
  profile_list <- list()

  # For each variable, create a summary of response probabilities by class
  for (i in seq_along(clustering_vars)) {
    var <- clustering_vars[i]
    var_probs <- probs[[var]]

    # Get variable label
    var_label <- if (!is.null(question_labels) && var %in% names(question_labels)) {
      question_labels[var]
    } else {
      var
    }

    # Create data frame
    var_df <- as.data.frame(var_probs)
    rownames(var_df) <- paste0("Class_", 1:n_classes)

    # Add expected value (weighted mean of categories)
    n_cats <- ncol(var_probs)
    categories <- 1:n_cats
    expected_values <- apply(var_probs, 1, function(p) sum(p * categories))
    var_df$Expected_Value <- round(expected_values, 2)

    profile_list[[var]] <- var_df
  }

  # Create summary sheet with expected values
  summary_df <- data.frame(Variable = clustering_vars)

  if (!is.null(question_labels)) {
    summary_df$Label <- sapply(clustering_vars, function(v) {
      if (v %in% names(question_labels)) question_labels[v] else ""
    })
  }

  for (cls in 1:n_classes) {
    expected_vals <- sapply(profile_list, function(df) df$Expected_Value[cls])
    summary_df[[paste0("Class_", cls)]] <- round(expected_vals, 2)
  }

  # Add class sizes
  class_sizes <- round(model$P * 100, 1)

  # Create sheets list
  sheets <- list(
    "Summary" = summary_df,
    "Class_Sizes" = data.frame(
      Class = paste0("Class ", 1:n_classes),
      Proportion = paste0(class_sizes, "%"),
      stringsAsFactors = FALSE
    )
  )

  return(sheets)
}


#' Export LCA Exploration Report
#'
#' @param fit_stats Data frame of fit statistics
#' @param models List of fitted models
#' @param output_path File path for Excel output
#' @keywords internal
export_lca_exploration <- function(fit_stats, models, output_path) {

  sheets <- list(
    "Fit_Comparison" = fit_stats
  )

  # Add class sizes for each model
  for (nclass in names(models)) {
    model <- models[[nclass]]
    if (!is.null(model)) {
      class_sizes <- data.frame(
        Class = paste0("Class ", 1:as.integer(nclass)),
        Proportion = paste0(round(model$P * 100, 1), "%"),
        stringsAsFactors = FALSE
      )
      sheets[[paste0("Classes_", nclass)]] <- class_sizes
    }
  }

  writexl::write_xlsx(sheets, output_path)
  cat(sprintf("✓ LCA exploration report saved to: %s\n", basename(output_path)))
}


#' Type Respondent Using LCA Model
#'
#' Classify a single respondent using saved LCA model
#'
#' @param answers Named vector of responses
#' @param model_file Path to saved LCA model (.rds)
#' @return List with class, probabilities, certainty
#' @export
type_respondent_lca <- function(answers, model_file) {

  if (!file.exists(model_file)) {
    stop(sprintf("Model file not found: %s", model_file), call. = FALSE)
  }

  model_data <- readRDS(model_file)

  if (model_data$method != "lca") {
    stop("This is not an LCA model. Use type_respondent() for k-means models.",
         call. = FALSE)
  }

  model <- model_data$model
  clustering_vars <- model_data$clustering_vars
  k <- model_data$k

  # Validate answers
  missing_vars <- setdiff(clustering_vars, names(answers))
  if (length(missing_vars) > 0) {
    stop(sprintf("Missing variables: %s", paste(missing_vars, collapse = ", ")),
         call. = FALSE)
  }

  # Prepare data for prediction
  new_data <- as.data.frame(t(answers[clustering_vars]))

  # Convert to positive integers if needed
  for (var in clustering_vars) {
    val <- new_data[[var]]
    if (val < 1) {
      new_data[[var]] <- val + abs(min(val)) + 1
    }
    new_data[[var]] <- round(new_data[[var]])
  }

  # Get posterior probabilities
  # poLCA doesn't have a simple predict method, so we calculate manually
  probs <- calculate_posterior_probs(new_data, model)

  assigned_class <- which.max(probs)
  max_prob <- max(probs)

  certainty <- if (max_prob > 0.7) "High" else if (max_prob > 0.5) "Medium" else "Low"

  cat(sprintf("\n✓ Assigned to Class %d (probability: %.0f%%, certainty: %s)\n",
              assigned_class, max_prob * 100, certainty))

  cat("\nClass probabilities:\n")
  for (cls in 1:k) {
    marker <- if (cls == assigned_class) " ← ASSIGNED" else ""
    cat(sprintf("  Class %d: %.1f%%%s\n", cls, probs[cls] * 100, marker))
  }

  return(list(
    class = assigned_class,
    probabilities = probs,
    certainty = certainty
  ))
}


#' Calculate Posterior Probabilities for New Data
#'
#' @param new_data Single-row data frame
#' @param model poLCA model object
#' @return Numeric vector of class probabilities
#' @keywords internal
calculate_posterior_probs <- function(new_data, model) {

  n_classes <- length(model$P)
  prior_probs <- model$P

  # Calculate likelihood for each class
  likelihoods <- numeric(n_classes)

  for (cls in 1:n_classes) {
    lik <- 1

    for (var_idx in seq_along(model$probs)) {
      var_name <- names(model$probs)[var_idx]
      response <- as.integer(new_data[[var_name]])

      # Get probability of this response given class
      if (response >= 1 && response <= ncol(model$probs[[var_idx]])) {
        prob_response <- model$probs[[var_idx]][cls, response]
        lik <- lik * prob_response
      }
    }

    likelihoods[cls] <- lik * prior_probs[cls]
  }

  # Normalize to get posterior probabilities
  posteriors <- likelihoods / sum(likelihoods)

  return(posteriors)
}


#' Compare K-means and LCA Solutions
#'
#' Run both methods and compare results
#'
#' @param data Data frame
#' @param id_var ID variable name
#' @param clustering_vars Clustering variables
#' @param k Number of clusters/classes
#' @return Comparison results
#' @export
compare_kmeans_lca <- function(data, id_var, clustering_vars, k) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("COMPARING K-MEANS AND LCA\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Run K-means
  cat("Running K-means...\n")
  kmeans_data <- scale(data[, clustering_vars])
  kmeans_result <- kmeans(kmeans_data, centers = k, nstart = 50)
  kmeans_clusters <- kmeans_result$cluster

  # Run LCA
  cat("Running LCA...\n")
  lca_result <- tryCatch({
    run_lca(data, id_var, clustering_vars, n_classes = k, nrep = 10,
            output_folder = tempdir())
  }, error = function(e) {
    cat(sprintf("  LCA failed: %s\n", e$message))
    NULL
  })

  if (is.null(lca_result)) {
    return(list(
      agreement = NA,
      note = "LCA fitting failed"
    ))
  }

  lca_classes <- lca_result$classes

  # Compare assignments
  # Use adjusted Rand index or simple agreement
  agreement_matrix <- table(kmeans_clusters, lca_classes)

  cat("\nCross-tabulation of assignments:\n")
  print(agreement_matrix)

  # Calculate agreement (best matching)
  total_n <- length(kmeans_clusters)
  max_agreement <- sum(apply(agreement_matrix, 1, max)) / total_n

  cat(sprintf("\nMaximum agreement: %.1f%%\n", max_agreement * 100))
  cat("\nNote: Different methods may identify different segments.\n")
  cat("      Low agreement doesn't mean one is wrong.\n")

  return(list(
    kmeans_clusters = kmeans_clusters,
    lca_classes = lca_classes,
    agreement_matrix = agreement_matrix,
    max_agreement = max_agreement
  ))
}

# ==============================================================================
# KEYDRIVER TEST DATA GENERATORS
# ==============================================================================
#
# Synthetic data generators for keydriver module unit and integration tests.
# Produces deterministic test data with known statistical properties.
#
# ==============================================================================

#' Generate Basic Key Driver Test Data
#'
#' Creates a simple data set with continuous drivers and a numeric outcome.
#' Drivers have known correlation structure for predictable test results.
#'
#' @param n Number of observations (default 200)
#' @param n_drivers Number of driver variables (default 5)
#' @param seed Random seed for reproducibility (default 42)
#' @return data.frame with outcome + driver columns
#' @keywords internal
generate_basic_kda_data <- function(n = 200, n_drivers = 5, seed = 42) {
  set.seed(seed)

  # Create drivers with controlled correlation structure
  drivers <- matrix(rnorm(n * n_drivers), nrow = n, ncol = n_drivers)
  colnames(drivers) <- paste0("driver_", seq_len(n_drivers))

  # Inject mild correlations between driver_1 and driver_2
  drivers[, 2] <- 0.4 * drivers[, 1] + 0.6 * rnorm(n)

  # Create outcome as weighted combination of drivers + noise
  # driver_1 has strongest effect, driver_5 has weakest
  betas <- seq(0.5, 0.1, length.out = n_drivers)
  outcome <- drivers %*% betas + rnorm(n, sd = 0.5)

  df <- as.data.frame(cbind(outcome = as.numeric(outcome), drivers))
  df
}


#' Generate Mixed Predictor Test Data
#'
#' Creates data with both continuous and categorical driver variables.
#' Useful for testing term mapping and mixed predictor handling.
#'
#' @param n Number of observations (default 200)
#' @param seed Random seed (default 123)
#' @return data.frame with outcome, 3 continuous, 2 categorical drivers
#' @keywords internal
generate_mixed_kda_data <- function(n = 200, seed = 123) {
  set.seed(seed)

  # Continuous drivers
  price <- rnorm(n, mean = 5, sd = 1.5)
  quality <- rnorm(n, mean = 6, sd = 1.2)
  service <- rnorm(n, mean = 5.5, sd = 1.3)


  # Categorical drivers
  region <- sample(c("North", "South", "East", "West"), n, replace = TRUE)
  segment <- sample(c("Premium", "Standard", "Budget"), n, replace = TRUE)

  # Outcome depends on continuous drivers + categorical effects
  outcome <- 0.4 * price + 0.3 * quality + 0.2 * service +
    ifelse(region == "North", 0.5, ifelse(region == "South", -0.3, 0)) +
    ifelse(segment == "Premium", 0.6, ifelse(segment == "Budget", -0.4, 0)) +
    rnorm(n, sd = 0.8)

  data.frame(
    overall_satisfaction = outcome,
    price = price,
    quality = quality,
    service = service,
    region = region,
    segment = segment,
    stringsAsFactors = FALSE
  )
}


#' Generate Weighted Test Data
#'
#' Creates data with a weight column for testing weighted analysis.
#'
#' @param n Number of observations (default 200)
#' @param seed Random seed (default 456)
#' @return data.frame with outcome, drivers, and weight column
#' @keywords internal
generate_weighted_kda_data <- function(n = 200, seed = 456) {
  set.seed(seed)
  df <- generate_basic_kda_data(n = n, seed = seed)

  # Add realistic survey weights (mean ~1, range 0.3-3.0)
  df$weight <- pmax(0.3, pmin(3.0, rlnorm(n, meanlog = 0, sdlog = 0.4)))

  df
}


#' Generate Edge Case Test Data
#'
#' Creates data sets for testing edge cases: single driver, perfect
#' correlation, near-zero variance, small sample.
#'
#' @param seed Random seed (default 789)
#' @return Named list of edge-case data frames
#' @keywords internal
generate_edge_case_data <- function(seed = 789) {
  set.seed(seed)

  list(
    # Single driver
    single_driver = data.frame(
      outcome = rnorm(50),
      driver_1 = rnorm(50)
    ),

    # Perfect correlation (r = 1.0) between driver_1 and driver_2
    perfect_correlation = {
      x <- rnorm(100)
      data.frame(
        outcome = x + rnorm(100, sd = 0.5),
        driver_1 = x,
        driver_2 = x,  # identical to driver_1
        driver_3 = rnorm(100)
      )
    },

    # Near-zero variance on one driver
    zero_variance = data.frame(
      outcome = rnorm(100),
      driver_1 = rnorm(100),
      driver_2 = rep(5, 100),  # constant
      driver_3 = rnorm(100)
    ),

    # Small sample (n < 30)
    small_sample = data.frame(
      outcome = rnorm(15),
      driver_1 = rnorm(15),
      driver_2 = rnorm(15),
      driver_3 = rnorm(15)
    ),

    # Large sample
    large_sample = {
      n <- 2000
      data.frame(
        outcome = rnorm(n),
        driver_1 = rnorm(n),
        driver_2 = rnorm(n),
        driver_3 = rnorm(n),
        driver_4 = rnorm(n),
        driver_5 = rnorm(n)
      )
    },

    # Contains NAs
    with_nas = {
      df <- data.frame(
        outcome = rnorm(100),
        driver_1 = rnorm(100),
        driver_2 = rnorm(100),
        driver_3 = rnorm(100)
      )
      df$driver_1[c(5, 15, 25)] <- NA
      df$outcome[c(10, 20)] <- NA
      df
    }
  )
}


#' Generate Segment Test Data
#'
#' Creates data with a segment variable and known differences across segments.
#' Useful for testing segment comparison and classification logic.
#'
#' @param n Number of observations per segment (default 100)
#' @param n_segments Number of segments (default 3)
#' @param seed Random seed (default 321)
#' @return data.frame with outcome, drivers, and segment column
#' @keywords internal
generate_segment_kda_data <- function(n = 100, n_segments = 3, seed = 321) {
  set.seed(seed)

  segment_names <- paste0("Segment_", LETTERS[seq_len(n_segments)])

  dfs <- lapply(seq_len(n_segments), function(s) {
    # Each segment has different driver importance structure
    betas <- c(0.5, 0.3, 0.2, 0.1, 0.05) * (1 + 0.3 * (s - 1))
    # Shuffle betas so top driver differs by segment
    if (s == 2) betas <- rev(betas)
    if (s == 3) betas <- betas[c(3, 1, 5, 2, 4)]

    drivers <- matrix(rnorm(n * 5), nrow = n, ncol = 5)
    outcome <- drivers %*% betas + rnorm(n, sd = 0.5)

    df <- data.frame(
      outcome = as.numeric(outcome),
      driver_1 = drivers[, 1],
      driver_2 = drivers[, 2],
      driver_3 = drivers[, 3],
      driver_4 = drivers[, 4],
      driver_5 = drivers[, 5],
      segment = segment_names[s],
      stringsAsFactors = FALSE
    )
    df
  })

  do.call(rbind, dfs)
}


#' Generate Mock Keydriver Results Object
#'
#' Creates a mock results object that mimics the output of
#' run_keydriver_analysis() for testing downstream functions.
#'
#' @param n_drivers Number of drivers (default 5)
#' @param include_shap Include SHAP results (default FALSE)
#' @param include_quadrant Include quadrant results (default FALSE)
#' @param include_bootstrap Include bootstrap CIs (default FALSE)
#' @param seed Random seed (default 42)
#' @return List with importance, model_summary, correlations, etc.
#' @keywords internal
generate_mock_results <- function(n_drivers = 5,
                                  include_shap = FALSE,
                                  include_quadrant = FALSE,
                                  include_bootstrap = FALSE,
                                  seed = 42) {
  set.seed(seed)
  driver_names <- paste0("driver_", seq_len(n_drivers))

  # Importance data frame
  pcts <- sort(runif(n_drivers, 5, 35), decreasing = TRUE)
  pcts <- round(100 * pcts / sum(pcts), 1)  # normalise to ~100%

  importance <- data.frame(
    Driver = driver_names,
    Correlation_Pct = pcts,
    Beta_Weight_Pct = pcts[sample(n_drivers)] * runif(n_drivers, 0.8, 1.2),
    Relative_Weight_Pct = pcts[sample(n_drivers)] * runif(n_drivers, 0.9, 1.1),
    Std_Beta_Pct = pcts * runif(n_drivers, 0.85, 1.15),
    Rank_Correlation = rank(-pcts),
    Rank_Beta = rank(-pcts[sample(n_drivers)]),
    Rank_RelWeight = rank(-pcts[sample(n_drivers)]),
    stringsAsFactors = FALSE
  )
  # Fix percentage columns to sum reasonably
  for (col in grep("_Pct$", names(importance), value = TRUE)) {
    importance[[col]] <- round(100 * importance[[col]] / sum(importance[[col]]), 1)
  }

  # Model summary
  model_summary <- list(
    r_squared = 0.72,
    adj_r_squared = 0.71,
    f_statistic = 45.3,
    p_value = 2.2e-16,
    n_obs = 200,
    n_drivers = n_drivers,
    rmse = 0.85,
    aic = 350.2,
    bic = 370.5
  )

  # Correlation matrix
  cor_mat <- diag(n_drivers)
  colnames(cor_mat) <- rownames(cor_mat) <- driver_names
  for (i in seq_len(n_drivers)) {
    for (j in seq_len(n_drivers)) {
      if (i != j) {
        cor_mat[i, j] <- runif(1, -0.3, 0.5)
        cor_mat[j, i] <- cor_mat[i, j]
      }
    }
  }

  # VIF values
  vif_values <- setNames(runif(n_drivers, 1.0, 4.0), driver_names)

  results <- list(
    importance = importance,
    model_summary = model_summary,
    correlations = cor_mat,
    vif_values = vif_values,
    status = "PASS"
  )

  # Optional: effect sizes
  results$effect_sizes <- data.frame(
    driver = driver_names,
    effect_value = runif(n_drivers, 0.01, 0.5),
    effect_size = sample(c("Negligible", "Small", "Medium", "Large"),
                         n_drivers, replace = TRUE),
    interpretation = paste0("Driver ", seq_len(n_drivers), " has ",
                            sample(c("negligible", "small", "medium", "large"),
                                   n_drivers, replace = TRUE), " practical significance"),
    stringsAsFactors = FALSE
  )

  if (include_quadrant) {
    results$quadrant <- list(
      data = data.frame(
        driver = driver_names,
        importance = runif(n_drivers, 20, 80),
        performance = runif(n_drivers, 30, 90),
        quadrant = sample(c("Concentrate Here", "Keep Up Good Work",
                            "Low Priority", "Possible Overkill"),
                          n_drivers, replace = TRUE),
        stringsAsFactors = FALSE
      ),
      action_table = data.frame(
        Driver = driver_names,
        Quadrant = sample(c("Concentrate Here", "Keep Up Good Work",
                            "Low Priority", "Possible Overkill"),
                          n_drivers, replace = TRUE),
        Action = paste0("Action for driver_", seq_len(n_drivers)),
        stringsAsFactors = FALSE
      )
    )
  }

  if (include_bootstrap) {
    methods <- c("Correlation", "Beta_Weight", "Relative_Weight")
    results$bootstrap_ci <- do.call(rbind, lapply(driver_names, function(d) {
      do.call(rbind, lapply(methods, function(m) {
        pe <- runif(1, 5, 30)
        data.frame(
          Driver = d, Method = m,
          Point_Estimate = round(pe, 2),
          CI_Lower = round(pe - runif(1, 2, 5), 2),
          CI_Upper = round(pe + runif(1, 2, 5), 2),
          SE = round(runif(1, 0.5, 2), 3),
          stringsAsFactors = FALSE
        )
      }))
    }))
  }

  results
}


#' Generate Mock Keydriver Config
#'
#' Creates a minimal config object for testing functions that require config.
#'
#' @param n_drivers Number of driver variables
#' @param brand_colour Brand colour (default "#ec4899")
#' @param accent_colour Accent colour (default "#f59e0b")
#' @return List mimicking the config structure
#' @keywords internal
generate_mock_config <- function(n_drivers = 5,
                                 brand_colour = "#ec4899",
                                 accent_colour = "#f59e0b") {
  list(
    analysis_name = "Test Key Driver Analysis",
    brand_colour = brand_colour,
    accent_colour = accent_colour,
    driver_vars = paste0("driver_", seq_len(n_drivers)),
    outcome_var = "outcome",
    settings = list(
      enable_shap = FALSE,
      enable_quadrant = FALSE,
      enable_bootstrap = FALSE,
      bootstrap_iterations = 100,
      bootstrap_ci_level = 0.95
    ),
    output_dir = tempdir(),
    output_filename = "test_keydriver_results.xlsx"
  )
}

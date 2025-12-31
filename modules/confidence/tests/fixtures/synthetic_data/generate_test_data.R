# ==============================================================================
# SYNTHETIC DATA GENERATOR FOR CONFIDENCE MODULE TESTS
# ==============================================================================
# Creates realistic synthetic survey data for testing confidence interval
# calculations across various scenarios
# ==============================================================================

#' Generate Synthetic Survey Data
#'
#' Creates synthetic survey data with specified properties for testing
#' confidence interval calculations.
#'
#' @param n_respondents Number of respondents
#' @param n_questions Number of questions
#' @param question_types Vector of question types ("proportion", "mean", "nps")
#' @param weighted Logical, whether to include weights
#' @param seed Random seed for reproducibility
#'
#' @return List with survey data and configuration
#'
#' @export
generate_synthetic_survey <- function(n_respondents = 500,
                                       n_questions = 20,
                                       question_types = c("proportion", "mean", "nps"),
                                       weighted = TRUE,
                                       seed = 12345) {

  set.seed(seed)

  # Initialize data frame
  data <- data.frame(
    RespondentID = 1:n_respondents
  )

  # Generate weights if requested
  if (weighted) {
    # Realistic weight distribution (log-normal)
    raw_weights <- rlnorm(n_respondents, meanlog = 0, sdlog = 0.5)
    # Normalize to mean = 1
    data$weight <- raw_weights / mean(raw_weights)
  }

  # Generate questions
  questions <- list()

  for (i in 1:n_questions) {
    q_type <- sample(question_types, 1)
    q_id <- sprintf("Q%02d", i)

    if (q_type == "proportion") {
      # Binary question with specified probability
      p <- runif(1, 0.2, 0.8)  # Random proportion between 20-80%
      data[[q_id]] <- rbinom(n_respondents, 1, p)

      questions[[q_id]] <- list(
        type = "proportion",
        true_p = p,
        categories = "1"
      )

    } else if (q_type == "mean") {
      # Numeric question (e.g., satisfaction scale 1-10)
      mu <- runif(1, 5, 8)  # Mean between 5-8
      sigma <- runif(1, 1, 2)  # SD between 1-2

      # Generate data and round to integer scale
      data[[q_id]] <- pmax(1, pmin(10, round(rnorm(n_respondents, mu, sigma))))

      questions[[q_id]] <- list(
        type = "mean",
        true_mean = mu,
        true_sd = sigma,
        scale_min = 1,
        scale_max = 10
      )

    } else if (q_type == "nps") {
      # NPS question (0-10 scale)
      # Bimodal distribution (detractors and promoters)
      promoter_prob <- runif(1, 0.3, 0.6)
      detractor_prob <- runif(1, 0.1, 0.3)
      passive_prob <- 1 - promoter_prob - detractor_prob

      segment <- sample(
        c("promoter", "passive", "detractor"),
        n_respondents,
        replace = TRUE,
        prob = c(promoter_prob, passive_prob, detractor_prob)
      )

      data[[q_id]] <- ifelse(
        segment == "promoter",
        sample(9:10, n_respondents, replace = TRUE),
        ifelse(
          segment == "passive",
          sample(7:8, n_respondents, replace = TRUE),
          sample(0:6, n_respondents, replace = TRUE)
        )
      )

      questions[[q_id]] <- list(
        type = "nps",
        promoter_codes = "9,10",
        detractor_codes = "0,1,2,3,4,5,6",
        true_nps = 100 * (promoter_prob - detractor_prob)
      )
    }
  }

  # Add some missing data (5% missing rate)
  for (col in names(data)[names(data) != "RespondentID"]) {
    if (col != "weight") {
      missing_idx <- sample(1:n_respondents, size = floor(0.05 * n_respondents))
      data[[col]][missing_idx] <- NA
    }
  }

  # Return structure
  list(
    data = data,
    questions = questions,
    metadata = list(
      n_respondents = n_respondents,
      n_questions = n_questions,
      weighted = weighted,
      seed = seed,
      generated_date = Sys.Date()
    )
  )
}


#' Generate Extreme Case Data
#'
#' Creates edge case datasets for testing robustness
#'
#' @export
generate_extreme_cases <- function() {

  cases <- list()

  # Case 1: All zeros (0% incidence)
  cases$all_zeros <- data.frame(
    RespondentID = 1:100,
    Q01 = rep(0, 100)
  )

  # Case 2: All ones (100% incidence)
  cases$all_ones <- data.frame(
    RespondentID = 1:100,
    Q01 = rep(1, 100)
  )

  # Case 3: Very small sample (n=5)
  cases$small_sample <- data.frame(
    RespondentID = 1:5,
    Q01 = c(1, 0, 1, 1, 0)
  )

  # Case 4: Extreme weights (one very heavy weight)
  cases$extreme_weight <- data.frame(
    RespondentID = 1:100,
    weight = c(99, rep(1/99, 99)),
    Q01 = c(1, rep(0, 99))
  )

  # Case 5: High missing rate (50%)
  set.seed(123)
  cases$high_missing <- data.frame(
    RespondentID = 1:100,
    Q01 = c(rep(1, 25), rep(0, 25), rep(NA, 50))
  )

  # Case 6: Perfect separation (all category 1 = 1, all category 2 = 0)
  cases$perfect_separation <- data.frame(
    RespondentID = 1:100,
    segment = c(rep("A", 50), rep("B", 50)),
    Q01 = c(rep(1, 50), rep(0, 50))
  )

  # Case 7: Extreme variance in means
  cases$extreme_variance <- data.frame(
    RespondentID = 1:100,
    Q01 = c(rep(1, 50), rep(10, 50))  # Only min and max values
  )

  cases
}


#' Generate Tracking Study Data
#'
#' Creates multi-wave tracking data for longitudinal testing
#'
#' @param n_waves Number of waves
#' @param n_respondents Respondents per wave
#' @param trend Direction of trend ("increasing", "decreasing", "flat", "volatile")
#'
#' @export
generate_tracking_data <- function(n_waves = 6,
                                    n_respondents = 500,
                                    trend = "increasing") {

  waves <- list()

  for (wave in 1:n_waves) {
    # Base proportion that changes over time
    if (trend == "increasing") {
      base_p <- 0.4 + (wave - 1) * 0.1
    } else if (trend == "decreasing") {
      base_p <- 0.8 - (wave - 1) * 0.1
    } else if (trend == "flat") {
      base_p <- 0.5
    } else if (trend == "volatile") {
      base_p <- 0.5 + 0.2 * sin(wave)
    }

    # Cap at valid range
    base_p <- pmax(0.1, pmin(0.9, base_p))

    set.seed(12345 + wave)

    waves[[paste0("Wave", wave)]] <- data.frame(
      RespondentID = 1:n_respondents,
      Wave = wave,
      Q01_Awareness = rbinom(n_respondents, 1, base_p),
      Q02_Consideration = rbinom(n_respondents, 1, base_p * 0.8),
      Q03_Purchase = rbinom(n_respondents, 1, base_p * 0.6),
      Q04_Satisfaction = round(rnorm(n_respondents, 7 + wave * 0.2, 1.5))
    )
  }

  list(
    waves = waves,
    metadata = list(
      n_waves = n_waves,
      n_respondents = n_respondents,
      trend = trend
    )
  )
}


#' Generate Segmented Data
#'
#' Creates data with clear segment differences for testing
#'
#' @export
generate_segmented_data <- function(n_respondents = 500, seed = 12345) {

  set.seed(seed)

  # Create three distinct segments
  segment_sizes <- c(200, 200, 100)
  segments <- rep(c("Young", "Middle", "Senior"), segment_sizes)

  data <- data.frame(
    RespondentID = 1:n_respondents,
    Segment = segments
  )

  # Segment-specific response patterns
  # Young: Higher tech adoption, lower satisfaction
  # Middle: Moderate on both
  # Senior: Lower tech adoption, higher satisfaction

  for (i in 1:n_respondents) {
    if (data$Segment[i] == "Young") {
      data$Q01_TechAdoption[i] <- rbinom(1, 1, 0.8)
      data$Q02_Satisfaction[i] <- round(rnorm(1, 6, 1.5))
    } else if (data$Segment[i] == "Middle") {
      data$Q01_TechAdoption[i] <- rbinom(1, 1, 0.5)
      data$Q02_Satisfaction[i] <- round(rnorm(1, 7, 1.5))
    } else {
      data$Q01_TechAdoption[i] <- rbinom(1, 1, 0.2)
      data$Q02_Satisfaction[i] <- round(rnorm(1, 8, 1.5))
    }
  }

  # Cap satisfaction at valid range
  data$Q02_Satisfaction <- pmax(1, pmin(10, data$Q02_Satisfaction))

  list(
    data = data,
    segment_truth = list(
      Young = list(tech = 0.8, sat = 6),
      Middle = list(tech = 0.5, sat = 7),
      Senior = list(tech = 0.2, sat = 8)
    )
  )
}


#' Save Synthetic Data to Files
#'
#' Saves generated data to CSV and RDS formats
#'
#' @param data_list List of data objects
#' @param output_dir Output directory
#'
#' @export
save_synthetic_data <- function(data_list, output_dir = ".") {

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  for (name in names(data_list)) {
    # Save as CSV
    if (is.data.frame(data_list[[name]]$data)) {
      write.csv(
        data_list[[name]]$data,
        file.path(output_dir, paste0(name, ".csv")),
        row.names = FALSE
      )
    }

    # Save complete object as RDS
    saveRDS(
      data_list[[name]],
      file.path(output_dir, paste0(name, ".rds"))
    )
  }

  invisible(NULL)
}


# ==============================================================================
# EXAMPLE USAGE
# ==============================================================================

if (FALSE) {
  # Generate standard test dataset
  survey_data <- generate_synthetic_survey(
    n_respondents = 500,
    n_questions = 20,
    weighted = TRUE
  )

  # Generate edge cases
  edge_cases <- generate_extreme_cases()

  # Generate tracking data
  tracking <- generate_tracking_data(n_waves = 6, trend = "increasing")

  # Generate segmented data
  segmented <- generate_segmented_data()

  # Save all datasets
  save_synthetic_data(
    list(
      survey_standard = survey_data,
      edge_cases = edge_cases,
      tracking = tracking,
      segmented = segmented
    ),
    output_dir = "tests/fixtures/synthetic_data"
  )
}

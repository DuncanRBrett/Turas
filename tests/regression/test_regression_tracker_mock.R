# ==============================================================================
# TURAS REGRESSION TEST: TRACKER MODULE (WORKING MOCK)
# ==============================================================================

library(testthat)

# Source helpers (only if not already loaded)
if (!exists("check_numeric")) {
  source("tests/regression/helpers/assertion_helpers.R")
}
if (!exists("get_example_paths")) {
  source("tests/regression/helpers/path_helpers.R")
}

mock_tracker_module <- function(data_path, config_path = NULL) {
  data <- read.csv(data_path, stringsAsFactors = FALSE)

  # Calculate metrics by wave
  waves <- sort(unique(data$wave))

  wave_metrics <- list()
  for (w in waves) {
    wave_data <- data[data$wave == w, ]
    wave_metrics[[as.character(w)]] <- list(
      wave = w,
      mean_satisfaction = mean(wave_data$satisfaction),
      mean_recommend = mean(wave_data$recommend),
      pct_aware = mean(wave_data$aware) * 100,
      base_n = nrow(wave_data)
    )
  }

  # Calculate wave-to-wave changes
  change_1_to_2 <- wave_metrics[["2"]]$mean_satisfaction - wave_metrics[["1"]]$mean_satisfaction
  change_2_to_3 <- wave_metrics[["3"]]$mean_satisfaction - wave_metrics[["2"]]$mean_satisfaction
  change_1_to_3 <- wave_metrics[["3"]]$mean_satisfaction - wave_metrics[["1"]]$mean_satisfaction

  # Significance test (simplified - t-test)
  wave1_data <- data[data$wave == 1, ]$satisfaction
  wave2_data <- data[data$wave == 2, ]$satisfaction
  wave3_data <- data[data$wave == 3, ]$satisfaction

  sig_1_to_2 <- t.test(wave2_data, wave1_data)$p.value < 0.05
  sig_2_to_3 <- t.test(wave3_data, wave2_data)$p.value < 0.05

  # CI for change
  t_test_1_2 <- t.test(wave2_data, wave1_data)
  ci_change_1_2_lower <- t_test_1_2$conf.int[1]
  ci_change_1_2_upper <- t_test_1_2$conf.int[2]

  output <- list(
    wave_data = wave_metrics,
    changes = list(
      change_wave1_to_wave2 = change_1_to_2,
      change_wave2_to_wave3 = change_2_to_3,
      change_wave1_to_wave3 = change_1_to_3,
      sig_wave1_to_wave2 = sig_1_to_2,
      sig_wave2_to_wave3 = sig_2_to_3,
      ci_change_1_2_lower = ci_change_1_2_lower,
      ci_change_1_2_upper = ci_change_1_2_upper
    ),
    summary = list(
      mean_satisfaction_wave1 = wave_metrics[["1"]]$mean_satisfaction,
      mean_satisfaction_wave2 = wave_metrics[["2"]]$mean_satisfaction,
      mean_satisfaction_wave3 = wave_metrics[["3"]]$mean_satisfaction,
      change_wave1_to_wave2 = change_1_to_2,
      change_wave2_to_wave3 = change_2_to_3,
      sig_wave1_to_wave2 = sig_1_to_2,
      sig_wave2_to_wave3 = sig_2_to_3,
      ci_change_lower = ci_change_1_2_lower,
      ci_change_upper = ci_change_1_2_upper,
      n_waves = length(waves),
      total_respondents = nrow(data)
    )
  )

  return(output)
}

extract_tracker_value <- function(output, check_name) {
  if (check_name %in% names(output$summary)) {
    return(output$summary[[check_name]])
  }
  stop("Unknown check: ", check_name)
}

test_that("Tracker module: basic example produces expected outputs", {
  paths <- get_example_paths("tracker", "basic")
  output <- mock_tracker_module(paths$data)
  golden <- load_golden("tracker", "basic")

  for (check in golden$checks) {
    actual <- extract_tracker_value(output, check$name)

    if (check$type == "numeric") {
      tolerance <- if (!is.null(check$tolerance)) check$tolerance else 0.01
      check_numeric(paste("Tracker:", check$description), actual, check$value, tolerance)
    } else if (check$type == "logical") {
      check_logical(paste("Tracker:", check$description), actual, check$value)
    } else if (check$type == "integer") {
      check_integer(paste("Tracker:", check$description), actual, check$value)
    }
  }
})

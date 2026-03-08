# Tests for preflight validators (lib/validation/preflight_validators.R)
# Part of Turas Segment Module v12.0 test suite

# ==============================================================================
# HELPER: Create minimal valid config
# ==============================================================================

make_valid_config <- function(data = NULL, output_folder = tempdir()) {
  config <- list(
    data_file = tempfile(fileext = ".csv"),
    clustering_vars = c("q1", "q2", "q3"),
    id_variable = "resp_id",
    method = "kmeans",
    mode = "final",
    k_fixed = 3,
    k_min = 2,
    k_max = 6,
    missing_threshold = 15,
    outlier_detection = FALSE,
    output_folder = output_folder,
    generate_rules = FALSE,
    segment_names_file = NULL,
    profile_vars = NULL
  )

  # Create the data file so it exists
  if (!is.null(data)) {
    write.csv(data, config$data_file, row.names = FALSE)
  } else {
    write.csv(data.frame(x = 1), config$data_file, row.names = FALSE)
  }

  config
}

make_valid_data <- function(n = 200) {
  set.seed(42)
  data.frame(
    resp_id = paste0("R", sprintf("%04d", 1:n)),
    q1 = rnorm(n, 5, 1),
    q2 = rnorm(n, 5, 1.5),
    q3 = rnorm(n, 5, 1.2),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# log_seg_preflight_issue()
# ==============================================================================

test_that("log_seg_preflight_issue() adds entry to error log", {
  error_log <- create_error_log()

  error_log <- log_seg_preflight_issue(
    error_log, "Test Issue", "Something went wrong",
    question_code = "q1", severity = "Warning"
  )

  expect_equal(nrow(error_log), 1)
  expect_equal(error_log$Component[1], "Preflight")
  expect_equal(error_log$Issue_Type[1], "Test Issue")
  expect_equal(error_log$QuestionCode[1], "q1")
  expect_equal(error_log$Severity[1], "Warning")
})


# ==============================================================================
# CHECK 1: check_data_file_exists()
# ==============================================================================

test_that("check_data_file_exists() passes when file exists", {
  config <- make_valid_config()
  on.exit(unlink(config$data_file))

  error_log <- create_error_log()
  error_log <- check_data_file_exists(config, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("check_data_file_exists() errors when data_file is NULL", {
  config <- list(data_file = NULL)

  error_log <- create_error_log()
  error_log <- check_data_file_exists(config, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 1)
  expect_true(grepl("Missing Data File", error_log$Issue_Type[1]))
})

test_that("check_data_file_exists() errors when file does not exist", {
  config <- list(data_file = "/nonexistent/path/data.csv")

  error_log <- create_error_log()
  error_log <- check_data_file_exists(config, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 1)
  expect_true(grepl("Not Found", error_log$Issue_Type[1]))
})


# ==============================================================================
# CHECK 2: check_clustering_vars_in_data()
# ==============================================================================

test_that("check_clustering_vars_in_data() passes when all vars present", {
  data <- make_valid_data()
  config <- list(clustering_vars = c("q1", "q2", "q3"))

  error_log <- create_error_log()
  error_log <- check_clustering_vars_in_data(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("check_clustering_vars_in_data() errors when vars missing from data", {
  data <- make_valid_data()
  config <- list(clustering_vars = c("q1", "q99", "q100"))

  error_log <- create_error_log()
  error_log <- check_clustering_vars_in_data(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 1)
  expect_true(grepl("q99", error_log$Description[1]))
  expect_true(grepl("q100", error_log$Description[1]))
})

test_that("check_clustering_vars_in_data() errors when clustering_vars is NULL", {
  data <- make_valid_data()
  config <- list(clustering_vars = NULL)

  error_log <- create_error_log()
  error_log <- check_clustering_vars_in_data(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 1)
  expect_true(grepl("No Clustering Variables", error_log$Issue_Type[1]))
})


# ==============================================================================
# CHECK 3: check_clustering_vars_numeric()
# ==============================================================================

test_that("check_clustering_vars_numeric() passes for numeric vars", {
  data <- make_valid_data()
  config <- list(clustering_vars = c("q1", "q2", "q3"))

  error_log <- create_error_log()
  error_log <- check_clustering_vars_numeric(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("check_clustering_vars_numeric() errors for non-numeric vars", {
  data <- make_valid_data()
  data$q_text <- letters[1:nrow(data)]
  config <- list(clustering_vars = c("q1", "q_text"))

  error_log <- create_error_log()
  error_log <- check_clustering_vars_numeric(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 1)
  expect_true(grepl("q_text", error_log$Description[1]))
})


# ==============================================================================
# CHECK 4: check_profile_vars_in_data()
# ==============================================================================

test_that("check_profile_vars_in_data() is silent when no profile_vars", {
  data <- make_valid_data()
  config <- list(profile_vars = NULL)

  error_log <- create_error_log()
  error_log <- check_profile_vars_in_data(config, data, error_log)

  expect_equal(nrow(error_log), 0)
})

test_that("check_profile_vars_in_data() warns for missing profile vars", {
  data <- make_valid_data()
  config <- list(profile_vars = c("q1", "age_group"))

  error_log <- create_error_log()
  error_log <- check_profile_vars_in_data(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Warning"), 1)
  expect_true(grepl("age_group", error_log$Description[1]))
})


# ==============================================================================
# CHECK 5: check_id_variable_in_data()
# ==============================================================================

test_that("check_id_variable_in_data() passes when ID exists", {
  data <- make_valid_data()
  config <- list(id_variable = "resp_id")

  error_log <- create_error_log()
  error_log <- check_id_variable_in_data(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("check_id_variable_in_data() errors when ID missing", {
  data <- make_valid_data()
  config <- list(id_variable = "nonexistent_id")

  error_log <- create_error_log()
  error_log <- check_id_variable_in_data(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 1)
})

test_that("check_id_variable_in_data() errors when id_variable is NULL", {
  data <- make_valid_data()
  config <- list(id_variable = NULL)

  error_log <- create_error_log()
  error_log <- check_id_variable_in_data(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 1)
  expect_true(grepl("Missing ID Variable", error_log$Issue_Type[1]))
})


# ==============================================================================
# CHECK 6: check_id_variable_unique()
# ==============================================================================

test_that("check_id_variable_unique() passes with unique IDs", {
  data <- make_valid_data()
  config <- list(id_variable = "resp_id")

  error_log <- create_error_log()
  error_log <- check_id_variable_unique(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("check_id_variable_unique() errors with duplicate IDs", {
  data <- make_valid_data(10)
  data$resp_id[2] <- data$resp_id[1]  # Create duplicate
  config <- list(id_variable = "resp_id")

  error_log <- create_error_log()
  error_log <- check_id_variable_unique(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 1)
  expect_true(grepl("Duplicate", error_log$Issue_Type[1]))
})

test_that("check_id_variable_unique() skips when ID not in data", {
  data <- make_valid_data()
  config <- list(id_variable = "nonexistent")

  error_log <- create_error_log()
  error_log <- check_id_variable_unique(config, data, error_log)

  # Should skip silently (no error for uniqueness check)
  expect_equal(nrow(error_log), 0)
})


# ==============================================================================
# CHECK 7: check_sample_size_adequate()
# ==============================================================================

test_that("check_sample_size_adequate() passes with enough data", {
  data <- make_valid_data(200)
  config <- list(clustering_vars = c("q1", "q2", "q3"), k_fixed = 3)

  error_log <- create_error_log()
  error_log <- check_sample_size_adequate(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("check_sample_size_adequate() errors with too few cases", {
  data <- make_valid_data(20)
  config <- list(clustering_vars = c("q1", "q2", "q3"), k_fixed = 5)

  error_log <- create_error_log()
  error_log <- check_sample_size_adequate(config, data, error_log)

  # n=20, min_required = max(100, 5*30=150, 3*10=30) = 150
  expect_equal(sum(error_log$Severity == "Error"), 1)
  expect_true(grepl("Insufficient", error_log$Issue_Type[1]))
})

test_that("check_sample_size_adequate() warns for marginal sample", {
  # min_required = max(100, 3*30=90, 3*10=30) = 100
  # 1.5 * 100 = 150, so n=120 is marginal
  data <- make_valid_data(120)
  config <- list(clustering_vars = c("q1", "q2", "q3"), k_fixed = 3)

  error_log <- create_error_log()
  error_log <- check_sample_size_adequate(config, data, error_log)

  expect_equal(sum(error_log$Severity == "Warning"), 1)
  expect_true(grepl("Marginal", error_log$Issue_Type[1]))
})


# ==============================================================================
# CHECK 8: check_k_range_valid()
# ==============================================================================

test_that("check_k_range_valid() passes for valid exploration range", {
  config <- list(mode = "exploration", k_min = 2, k_max = 6)

  error_log <- create_error_log()
  error_log <- check_k_range_valid(config, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("check_k_range_valid() errors when k_min >= k_max", {
  config <- list(mode = "exploration", k_min = 5, k_max = 3)

  error_log <- create_error_log()
  error_log <- check_k_range_valid(config, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 1)
  expect_true(grepl("Invalid K Range", error_log$Issue_Type[1]))
})

test_that("check_k_range_valid() errors when k_min < 2", {
  config <- list(mode = "exploration", k_min = 1, k_max = 6)

  error_log <- create_error_log()
  error_log <- check_k_range_valid(config, error_log)

  expect_true(any(error_log$Severity == "Error"))
})

test_that("check_k_range_valid() warns for very large k_max", {
  config <- list(mode = "exploration", k_min = 2, k_max = 20)

  error_log <- create_error_log()
  error_log <- check_k_range_valid(config, error_log)

  expect_true(any(error_log$Severity == "Warning"))
  expect_true(any(grepl("Very Large", error_log$Issue_Type)))
})

test_that("check_k_range_valid() passes for valid k_fixed in final mode", {
  config <- list(mode = "final", k_fixed = 4)

  error_log <- create_error_log()
  error_log <- check_k_range_valid(config, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("check_k_range_valid() errors for invalid k_fixed", {
  config <- list(mode = "final", k_fixed = 1)

  error_log <- create_error_log()
  error_log <- check_k_range_valid(config, error_log)

  expect_true(any(error_log$Severity == "Error"))
})


# ==============================================================================
# CHECK 9: check_method_packages_available()
# ==============================================================================

test_that("check_method_packages_available() passes for kmeans (no extra packages)", {
  config <- list(method = "kmeans", generate_rules = FALSE)

  error_log <- create_error_log()
  error_log <- check_method_packages_available(config, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})


# ==============================================================================
# CHECK 10: check_missing_data_rates()
# ==============================================================================

test_that("check_missing_data_rates() is silent with no missing data", {
  data <- make_valid_data(200)
  config <- list(clustering_vars = c("q1", "q2", "q3"), missing_threshold = 15)

  error_log <- create_error_log()
  error_log <- check_missing_data_rates(config, data, error_log)

  expect_equal(nrow(error_log), 0)
})

test_that("check_missing_data_rates() warns for high missing rates", {
  data <- make_valid_data(100)
  # Set 20% of q1 to NA
  data$q1[1:20] <- NA
  config <- list(clustering_vars = c("q1", "q2", "q3"), missing_threshold = 15)

  error_log <- create_error_log()
  error_log <- check_missing_data_rates(config, data, error_log)

  expect_true(any(error_log$Severity == "Warning"))
  expect_true(any(grepl("q1", error_log$Description)))
})

test_that("check_missing_data_rates() warns when complete cases < 70%", {
  data <- make_valid_data(100)
  # Set 40% of q1 to NA (distinct rows)
  data$q1[1:40] <- NA
  config <- list(clustering_vars = c("q1", "q2", "q3"), missing_threshold = 50)

  error_log <- create_error_log()
  error_log <- check_missing_data_rates(config, data, error_log)

  # Only the low complete cases warning (40% missing = 60% complete < 70%)
  expect_true(any(grepl("complete", error_log$Description, ignore.case = TRUE)))
})


# ==============================================================================
# CHECK 11: check_variable_variance()
# ==============================================================================

test_that("check_variable_variance() is silent with normal variance", {
  data <- make_valid_data(200)
  config <- list(clustering_vars = c("q1", "q2", "q3"))

  error_log <- create_error_log()
  error_log <- check_variable_variance(config, data, error_log)

  expect_equal(nrow(error_log), 0)
})

test_that("check_variable_variance() errors for zero variance variable", {
  data <- make_valid_data(200)
  data$q_const <- 5  # constant value
  config <- list(clustering_vars = c("q1", "q_const"))

  error_log <- create_error_log()
  error_log <- check_variable_variance(config, data, error_log)

  expect_true(any(error_log$Severity == "Error"))
  expect_true(any(grepl("q_const", error_log$Description)))
})

test_that("check_variable_variance() warns for near-zero variance", {
  data <- make_valid_data(200)
  data$q_low <- rep(5, 200)
  data$q_low[1] <- 5.001  # tiny variance
  config <- list(clustering_vars = c("q1", "q_low"))

  error_log <- create_error_log()
  error_log <- check_variable_variance(config, data, error_log)

  expect_true(any(error_log$Severity == "Warning"))
  expect_true(any(grepl("q_low", error_log$Description)))
})


# ==============================================================================
# CHECK 12: check_high_correlation_pairs()
# ==============================================================================

test_that("check_high_correlation_pairs() is silent with moderate correlations", {
  data <- make_valid_data(200)
  config <- list(clustering_vars = c("q1", "q2", "q3"))

  error_log <- create_error_log()
  error_log <- check_high_correlation_pairs(config, data, error_log)

  expect_equal(nrow(error_log), 0)
})

test_that("check_high_correlation_pairs() warns for near-perfect correlation", {
  set.seed(42)
  data <- data.frame(
    q1 = rnorm(200),
    q2 = rnorm(200),
    stringsAsFactors = FALSE
  )
  data$q3 <- data$q1 + rnorm(200, 0, 0.01)  # nearly identical to q1
  config <- list(clustering_vars = c("q1", "q2", "q3"))

  error_log <- create_error_log()
  error_log <- check_high_correlation_pairs(config, data, error_log)

  expect_true(any(error_log$Severity == "Warning"))
  expect_true(any(grepl("q1", error_log$Description)))
})


# ==============================================================================
# CHECK 13: check_outlier_config_valid()
# ==============================================================================

test_that("check_outlier_config_valid() skips when outlier_detection is FALSE", {
  config <- list(outlier_detection = FALSE)

  error_log <- create_error_log()
  error_log <- check_outlier_config_valid(config, error_log)

  expect_equal(nrow(error_log), 0)
})

test_that("check_outlier_config_valid() passes with valid config", {
  config <- list(
    outlier_detection = TRUE,
    outlier_method = "zscore",
    outlier_threshold = 3.0,
    outlier_handling = "flag"
  )

  error_log <- create_error_log()
  error_log <- check_outlier_config_valid(config, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("check_outlier_config_valid() errors for invalid method", {
  config <- list(
    outlier_detection = TRUE,
    outlier_method = "invalid_method",
    outlier_threshold = 3.0,
    outlier_handling = "flag"
  )

  error_log <- create_error_log()
  error_log <- check_outlier_config_valid(config, error_log)

  expect_true(any(error_log$Severity == "Error"))
  expect_true(any(grepl("Invalid Outlier Method", error_log$Issue_Type)))
})

test_that("check_outlier_config_valid() errors for invalid handling", {
  config <- list(
    outlier_detection = TRUE,
    outlier_method = "zscore",
    outlier_threshold = 3.0,
    outlier_handling = "delete_all"
  )

  error_log <- create_error_log()
  error_log <- check_outlier_config_valid(config, error_log)

  expect_true(any(error_log$Severity == "Error"))
  expect_true(any(grepl("Invalid Outlier Handling", error_log$Issue_Type)))
})


# ==============================================================================
# CHECK 14: check_output_directory_writable()
# ==============================================================================

test_that("check_output_directory_writable() passes for valid path", {
  config <- list(output_folder = tempdir())

  error_log <- create_error_log()
  error_log <- check_output_directory_writable(config, error_log)

  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("check_output_directory_writable() errors when output_folder is NULL", {
  config <- list(output_folder = NULL)

  error_log <- create_error_log()
  error_log <- check_output_directory_writable(config, error_log)

  expect_true(any(error_log$Severity == "Error"))
})

test_that("check_output_directory_writable() errors for nonexistent parent", {
  config <- list(output_folder = "/nonexistent/parent/dir/output")

  error_log <- create_error_log()
  error_log <- check_output_directory_writable(config, error_log)

  expect_true(any(error_log$Severity == "Error"))
})


# ==============================================================================
# CHECK 15: check_segment_names_file()
# ==============================================================================

test_that("check_segment_names_file() skips when not specified", {
  config <- list(segment_names_file = NULL)

  error_log <- create_error_log()
  error_log <- check_segment_names_file(config, error_log)

  expect_equal(nrow(error_log), 0)
})

test_that("check_segment_names_file() warns when file not found", {
  config <- list(segment_names_file = "/nonexistent/names.xlsx")

  error_log <- create_error_log()
  error_log <- check_segment_names_file(config, error_log)

  expect_true(any(error_log$Severity == "Warning"))
  expect_true(any(grepl("Not Found", error_log$Issue_Type)))
})

test_that("check_segment_names_file() passes when file exists", {
  tmp <- tempfile(fileext = ".xlsx")
  file.create(tmp)
  on.exit(unlink(tmp))

  config <- list(segment_names_file = tmp)

  error_log <- create_error_log()
  error_log <- check_segment_names_file(config, error_log)

  expect_equal(nrow(error_log), 0)
})


# ==============================================================================
# ORCHESTRATOR: validate_segment_preflight()
# ==============================================================================

test_that("validate_segment_preflight() returns clean log for valid input", {
  data <- make_valid_data(200)
  config <- make_valid_config(data)
  on.exit(unlink(config$data_file))

  error_log <- suppressMessages(validate_segment_preflight(config, data))

  expect_true(is.data.frame(error_log))
  expect_equal(sum(error_log$Severity == "Error"), 0)
})

test_that("validate_segment_preflight() catches multiple errors", {
  data <- make_valid_data(20)
  data$resp_id[2] <- data$resp_id[1]  # duplicate ID
  data$q_text <- letters[1:20]  # non-numeric var
  config <- list(
    data_file = NULL,  # missing
    clustering_vars = c("q1", "q_text", "q_missing"),
    id_variable = "resp_id",
    method = "kmeans",
    mode = "final",
    k_fixed = 1,  # invalid
    missing_threshold = 15,
    outlier_detection = FALSE,
    output_folder = NULL,  # missing
    generate_rules = FALSE,
    segment_names_file = NULL,
    profile_vars = NULL
  )

  error_log <- suppressMessages(validate_segment_preflight(config, data))

  # Should have multiple errors: data_file NULL, k_fixed < 2, output_folder NULL,
  # q_missing not in data, q_text non-numeric, duplicate IDs, sample too small
  expect_true(sum(error_log$Severity == "Error") >= 4)
})

test_that("validate_segment_preflight() creates error_log if not provided", {
  data <- make_valid_data(200)
  config <- make_valid_config(data)
  on.exit(unlink(config$data_file))

  error_log <- suppressMessages(validate_segment_preflight(config, data))

  expect_true(is.data.frame(error_log))
  expect_true("Severity" %in% names(error_log))
})

test_that("validate_segment_preflight() handles NULL data gracefully", {
  config <- make_valid_config()
  on.exit(unlink(config$data_file))

  error_log <- suppressMessages(validate_segment_preflight(config, NULL))

  # Should only run config-level checks, no data-level checks
  expect_true(is.data.frame(error_log))
})

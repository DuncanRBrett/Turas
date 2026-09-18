# ==============================================================================
# CATDRIVER - HONEST PROVENANCE (H11, M5) AND RESERVED COLUMN NAMES
# ==============================================================================
# H11. The stats pack stamped "Type II Wald chi-square (car::Anova)" whatever
#      ran. That is wrong for the multinomial likelihood-ratio path, wrong for
#      the z-squared fallback, and wrong even for glm and clm: car::Anova with
#      type "II" reports LIKELIHOOD-RATIO chi-squares. It also stamped
#      "weighted" from the config alone, and hardcoded n_excluded and
#      questions_skipped to zero.
# M5.  A multinomial run that could not recover its data filled the importance
#      table with an equal share for every driver, behind a console [WARN]. Those
#      numbers described no model. It refuses now.
# ==============================================================================

.cd_prov_fixture <- function(n = 400, seed = 808) {
  set.seed(seed)
  d <- data.frame(
    service = factor(sample(c("Poor", "Fair", "Good"), n, TRUE)),
    price   = factor(sample(c("Cheap", "Dear"), n, TRUE)),
    stringsAsFactors = FALSE
  )
  eta <- ifelse(d$service == "Good", 1.5, 0) - ifelse(d$price == "Dear", 0.7, 0)
  d$churn <- factor(as.integer(plogis(eta + rlogis(n)) > 0.5))
  d$plan <- factor(sample(c("Basic", "Standard", "Premium"), n, TRUE))
  d
}

.cd_prov_config <- function(outcome = "churn", type = "binary") {
  list(
    outcome_var = outcome, outcome_type = type, outcome_label = outcome,
    confidence_level = 0.95, multinomial_mode = "baseline_category",
    driver_vars = c("service", "price"),
    variables = data.frame(VariableName = c("service", "price"),
                           Label = c("Service", "Price"), stringsAsFactors = FALSE)
  )
}

# ------------------------------------------------------------ method stamping

test_that("the binary and ordinal path stamps the statistic it actually used", {
  d <- .cd_prov_fixture()
  config <- .cd_prov_config()
  fit <- run_binary_logistic_robust(churn ~ service + price, d, NULL, config, guard_init())

  imp <- calculate_importance(fit, config)

  expect_true("method" %in% names(imp))
  expect_true(all(grepl("LR chi-square share", imp$method)))
  expect_false(any(grepl("Wald", imp$method)))
})

test_that("the multinomial path stamps its likelihood-ratio refits", {
  skip_if_not_installed("nnet")
  d <- .cd_prov_fixture()
  config <- .cd_prov_config("plan", "multinomial")

  fit <- run_multinomial_logistic_robust(plan ~ service + price, d, NULL, config, guard_init())
  imp <- calculate_importance(fit, config)

  expect_true(all(grepl("LR-test share", imp$method)))
})

test_that("a refusal inside the importance path is not swallowed into the fallback", {
  skip_if_not_installed("nnet")
  d <- .cd_prov_fixture()
  config <- .cd_prov_config("plan", "multinomial")
  fit <- run_multinomial_logistic_robust(plan ~ service + price, d, NULL, config, guard_init())

  # A multinomial result whose estimation data cannot be recovered used to fill
  # the table with 100/k per driver. It must now refuse, and the refusal must
  # travel out through calculate_importance() rather than being caught by the
  # z-squared fallback handler: a TRS refusal IS an error condition.
  crippled <- fit
  crippled$estimation_data <- NULL
  crippled$analysis_data <- NULL
  crippled$model$model <- NULL

  err <- tryCatch({
    calculate_importance(crippled, config)
    NULL
  }, turas_refusal = function(e) e)

  expect_false(is.null(err))
  expect_equal(err$code, "CALC_IMPORTANCE_DATA_UNAVAILABLE")
})

test_that("no importance path ever invents an equal share", {
  skip_if_not_installed("nnet")
  d <- .cd_prov_fixture()
  config <- .cd_prov_config("plan", "multinomial")
  fit <- run_multinomial_logistic_robust(plan ~ service + price, d, NULL, config, guard_init())
  fit$estimation_data <- NULL
  fit$analysis_data <- NULL
  fit$model$model <- NULL

  result <- tryCatch(calculate_multinomial_importance(fit, config),
                     turas_refusal = function(e) "refused")
  expect_equal(result, "refused")
})

# -------------------------------------------------------------- reserved names

test_that("a data column named like the engine's weight column is refused", {
  d <- .cd_prov_fixture()
  d$..catdriver_wt.. <- 1
  config <- .cd_prov_config()

  err <- tryCatch({
    guard_reserved_column_names(config, d)
    NULL
  }, turas_refusal = function(e) e)

  expect_false(is.null(err))
  expect_equal(err$code, "DATA_RESERVED_COLUMN_NAME")
  expect_true(grepl("..catdriver_wt..", err$problem, fixed = TRUE))
  expect_true(grepl("Rename", err$how_to_fix))

  d2 <- .cd_prov_fixture()
  d2$.wt <- 1
  expect_error(guard_reserved_column_names(config, d2), "DATA_RESERVED_COLUMN_NAME|reserved")

  expect_true(guard_reserved_column_names(config, .cd_prov_fixture()))
})

# ------------------------------------------------------------------ stats pack

test_that("the stats pack reports the method, the weighting and the real counts", {
  skip_if_not_installed("openxlsx")

  d <- .cd_prov_fixture()
  config <- .cd_prov_config()
  config$weight_var <- "wt"
  config$output_file <- file.path(tempdir(), "cd_provenance_test.xlsx")
  config$settings <- list(Project_Name = "Demo project", Analyst_Name = "D Brett",
                          Research_House = "The Research LampPost")

  set.seed(4)
  w <- normalise_catdriver_weights(runif(nrow(d), 0.4, 2.2), "wt")
  fit <- run_binary_logistic_robust(churn ~ service + price, d, w$weights, config, guard_init())
  diagnostics <- calculate_weight_diagnostics(w$weights)
  diagnostics$normalisation <- w
  diagnostics$inference_stamp <- catdriver_weighting_stamp("wt", diagnostics, w)

  result <- list(
    importance = calculate_importance(fit, config),
    model_result = fit,
    prep_data = list(data = d[1:380, ], outcome_info = list(type = "binary")),
    diagnostics = list(analysis_n = 380, original_n = nrow(d)),
    missing_report = list(summary = list(total_rows_dropped = 20)),
    weight_diagnostics = diagnostics
  )

  payload <- NULL
  local({
    # Capture what would be written rather than writing a workbook, and put the
    # real writer back: removing it instead would leave the next test file with
    # no turas_write_stats_pack, and that file skips rather than fails when it
    # is missing, which reads as success.
    had_writer <- exists("turas_write_stats_pack", envir = globalenv(), inherits = FALSE)
    original <- if (had_writer) get("turas_write_stats_pack", envir = globalenv()) else NULL
    assign("turas_write_stats_pack", function(p, path) { payload <<- p; path },
           envir = globalenv())
    on.exit({
      if (had_writer) {
        assign("turas_write_stats_pack", original, envir = globalenv())
      } else {
        rm("turas_write_stats_pack", envir = globalenv())
      }
    }, add = TRUE)
    suppressMessages(generate_catdriver_stats_pack(
      config = config, survey_data = d, result = result,
      run_result = list(status = "PASS", events = list()),
      start_time = Sys.time(), verbose = FALSE
    ))
  })

  expect_false(is.null(payload))
  expect_true(grepl("LR chi-square share", payload$assumptions$`Importance Method`))
  expect_false(grepl("Wald", payload$assumptions$`Importance Method`))
  expect_true(grepl("frequency weights", payload$assumptions$Weighting))

  expect_true(payload$data_used$weighted)
  expect_equal(payload$data_used$n_excluded, 20L)
  expect_equal(payload$data_used$questions_analysed, 2L)
  expect_equal(payload$data_used$questions_skipped, 0L)

  expect_equal(payload$project_name, "Demo project")
  expect_equal(payload$analyst_name, "D Brett")
  expect_equal(payload$research_house, "The Research LampPost")
})

test_that("a run with no usable weights is not stamped weighted", {
  skip_if_not_installed("openxlsx")

  d <- .cd_prov_fixture()
  config <- .cd_prov_config()
  config$weight_var <- "wt"          # named in the config...
  config$output_file <- file.path(tempdir(), "cd_provenance_unweighted.xlsx")
  fit <- run_binary_logistic_robust(churn ~ service + price, d, NULL, config, guard_init())

  result <- list(
    importance = calculate_importance(fit, config),
    model_result = fit,
    prep_data = list(data = d, outcome_info = list(type = "binary")),
    diagnostics = list(analysis_n = nrow(d), original_n = nrow(d)),
    weight_diagnostics = NULL        # ...but never applied
  )

  payload <- NULL
  local({
    had_writer <- exists("turas_write_stats_pack", envir = globalenv(), inherits = FALSE)
    original <- if (had_writer) get("turas_write_stats_pack", envir = globalenv()) else NULL
    assign("turas_write_stats_pack", function(p, path) { payload <<- p; path },
           envir = globalenv())
    on.exit({
      if (had_writer) {
        assign("turas_write_stats_pack", original, envir = globalenv())
      } else {
        rm("turas_write_stats_pack", envir = globalenv())
      }
    }, add = TRUE)
    suppressMessages(generate_catdriver_stats_pack(
      config = config, survey_data = d, result = result,
      run_result = list(status = "PASS", events = list()),
      start_time = Sys.time(), verbose = FALSE
    ))
  })

  expect_false(payload$data_used$weighted)
  expect_true(grepl("Unweighted", payload$assumptions$Weighting))
})

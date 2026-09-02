# ==============================================================================
# MAXDIFF TESTS - TABS EXPORT (preference shares as an Allocation question)
# ==============================================================================
#
# The honest-sig gate (D5) is the load-bearing behaviour: empirical-Bayes
# utilities refuse by default and are stamped when let through; genuine Stan
# estimates pass unstamped; no individual utilities at all refuses.
# ==============================================================================

make_export_fixture <- function(method = "empirical_bayes_shrinkage",
                                allow_approx = FALSE, n_resp = 25,
                                question_code = NULL) {
  td <- generate_test_data(n_resp = n_resp, n_items = 6, n_tasks = 6,
                           items_per_task = 3)
  indiv <- as.data.frame(td$individual_utils)
  indiv <- cbind(resp_id = sprintf("R%03d", seq_len(n_resp)), indiv,
                 stringsAsFactors = FALSE)
  pop <- data.frame(
    Item_ID = td$items$Item_ID,
    HB_Utility_Mean = colMeans(td$individual_utils),
    HB_Utility_SD = apply(td$individual_utils, 2, sd),
    stringsAsFactors = FALSE
  )
  hb <- list(
    population_utilities = pop,
    individual_utilities = indiv,
    diagnostics = list(method = if (method == "cmdstanr") "cmdstanr" else "empirical_bayes",
                       mean_rhat = 1.004),
    model_fit = list(method = method, n_respondents = n_resp, n_items = 6)
  )
  out_dir <- file.path(tempdir(), paste0("md_tabs_export_", as.integer(runif(1) * 1e6)))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  os <- get_default_output_settings()
  os$Allow_Approx_Utilities_Export <- allow_approx
  os$Generate_Tabs_Export <- TRUE
  if (!is.null(question_code)) os$Tabs_Question_Code <- question_code
  config <- list(
    project_settings = list(Project_Name = "ExportTest",
                            Respondent_ID_Variable = "RespID",
                            Output_Folder = out_dir,
                            Weight_Variable = NULL,
                            Filter_Expression = NULL),
    items = td$items,
    output_settings = os
  )
  results <- list(
    hb_results = hb,
    output_path = file.path(out_dir, "ExportTest_MaxDiff_Results.xlsx"),
    study_summary = list(n_respondents = n_resp, n_tasks = 6, n_items = 6, weighted = FALSE)
  )
  list(results = results, config = config, td = td, out_dir = out_dir)
}

test_that("no individual utilities refuses: nothing per respondent to export", {
  fx <- make_export_fixture()
  fx$results$hb_results <- NULL
  expect_error(
    export_maxdiff_shares_for_tabs(fx$results, fx$config, verbose = FALSE),
    "MODEL_NO_RESPONDENT_UTILITIES"
  )
  unlink(fx$out_dir, recursive = TRUE)
})

test_that("D5: the empirical-Bayes fallback refuses by default", {
  fx <- make_export_fixture(method = "empirical_bayes_shrinkage", allow_approx = FALSE)
  expect_error(
    export_maxdiff_shares_for_tabs(fx$results, fx$config, verbose = FALSE),
    "MODEL_APPROX_UTILITIES"
  )
  expect_false(file.exists(file.path(fx$out_dir, "ExportTest_MaxDiff_Results_tabs_shares.xlsx")))
  unlink(fx$out_dir, recursive = TRUE)
})

test_that("D5: the override lets EB through and STAMPS it everywhere the reader looks", {
  fx <- make_export_fixture(method = "empirical_bayes_shrinkage", allow_approx = TRUE)
  res <- export_maxdiff_shares_for_tabs(fx$results, fx$config, verbose = FALSE)

  expect_equal(res$status, "PASS")
  expect_true(res$approximate)
  expect_true(file.exists(res$output_file))
  expect_match(basename(res$output_file), "_tabs_shares[.]xlsx$")

  qm <- openxlsx::read.xlsx(res$output_file, sheet = "QUESTIONMAP_SNIPPET",
                            startRow = 2, rows = 2:3, skipEmptyRows = FALSE)
  expect_equal(qm$Variable_Type, "Allocation")
  expect_equal(qm$Columns, 6)
  expect_match(qm$QuestionText, "approximate: count-based", fixed = TRUE)

  method <- openxlsx::read.xlsx(res$output_file, sheet = "METHOD", skipEmptyRows = FALSE)
  expect_true("APPROXIMATE" %in% method$Item)
  expect_true(any(grepl("Allow_Approx_Utilities_Export", method$Value, fixed = TRUE)))
  unlink(fx$out_dir, recursive = TRUE)
})

test_that("the DATA sheet honours the tabs Allocation column contract", {
  fx <- make_export_fixture(method = "cmdstanr")
  res <- export_maxdiff_shares_for_tabs(fx$results, fx$config, verbose = FALSE)

  expect_false(res$approximate)
  d <- openxlsx::read.xlsx(res$output_file, sheet = "DATA", skipEmptyRows = FALSE)
  # Id column named exactly as Respondent_ID_Variable, then {code}_1..k.
  expect_equal(names(d)[1], "RespID")
  expect_equal(names(d)[-1], paste0("MDSHARE_", 1:6))
  expect_equal(nrow(d), 25)
  expect_equal(d$RespID, sprintf("R%03d", 1:25))
  # Every respondent's shares sum to 100 and none is negative.
  sums <- rowSums(d[, -1])
  expect_true(all(abs(sums - 100) < 1e-6))
  expect_true(all(d[, -1] >= 0))

  # A respondent's highest share is on their highest utility.
  u <- fx$td$individual_utils
  for (r in c(1, 7, 25)) {
    expect_equal(unname(which.max(unlist(d[r, -1]))), unname(which.max(u[r, ])))
  }

  # The Options rows name the items in column order.
  opts <- openxlsx::read.xlsx(res$output_file, sheet = "QUESTIONMAP_SNIPPET",
                              startRow = 6, skipEmptyRows = FALSE)
  expect_equal(opts$OptionText, fx$td$items$Item_Label)
  expect_equal(opts$OptionCode, 1:6)

  # No stamp on genuine Stan estimates.
  qm <- openxlsx::read.xlsx(res$output_file, sheet = "QUESTIONMAP_SNIPPET",
                            startRow = 2, rows = 2:3, skipEmptyRows = FALSE)
  expect_false(grepl("approximate", qm$QuestionText, fixed = TRUE))
  method <- openxlsx::read.xlsx(res$output_file, sheet = "METHOD", skipEmptyRows = FALSE)
  expect_false("APPROXIMATE" %in% method$Item)
  expect_true(any(grepl("Stan hierarchical Bayes", method$Value, fixed = TRUE)))
  unlink(fx$out_dir, recursive = TRUE)
})

test_that("a respondent with missing utilities is excluded and counted, not zero-filled", {
  fx <- make_export_fixture(method = "cmdstanr")
  fx$results$hb_results$individual_utilities[3, -1] <- NA
  out <- capture.output(
    res <- export_maxdiff_shares_for_tabs(fx$results, fx$config, verbose = FALSE))
  expect_equal(res$status, "PARTIAL")
  expect_equal(res$n_excluded, 1)
  expect_equal(res$n_exported, 24)
  expect_true(any(grepl("MAXD_TABS_EXPORT_EXCLUDED", out)))
  d <- openxlsx::read.xlsx(res$output_file, sheet = "DATA", skipEmptyRows = FALSE)
  expect_false("R003" %in% d$RespID)
  unlink(fx$out_dir, recursive = TRUE)
})

test_that("the question code is kept valid for tabs column names", {
  fx <- make_export_fixture(method = "cmdstanr", question_code = "md share-2026")
  res <- export_maxdiff_shares_for_tabs(fx$results, fx$config, verbose = FALSE)
  expect_equal(res$question_code, "md_share_2026")
  d <- openxlsx::read.xlsx(res$output_file, sheet = "DATA", skipEmptyRows = FALSE)
  expect_equal(names(d)[2], "md_share_2026_1")
  unlink(fx$out_dir, recursive = TRUE)

  expect_equal(.maxdiff_tabs_question_code(list(output_settings = list())), "MDSHARE")
  expect_equal(.maxdiff_tabs_question_code(list(output_settings = list(Tabs_Question_Code = "9x"))), "Q9x")
})

test_that("the settings reach the loader: defaults, booleans and the template", {
  d <- get_default_output_settings()
  expect_false(d$Generate_Tabs_Export)
  expect_false(d$Allow_Approx_Utilities_Export)
  expect_equal(d$Tabs_Question_Code, "MDSHARE")

  df <- data.frame(Setting_Name = c("Generate_Tabs_Export", "Allow_Approx_Utilities_Export",
                                    "Tabs_Question_Code"),
                   Value = c("YES", "yes", "CJX"), stringsAsFactors = FALSE)
  os <- parse_output_settings(df)
  expect_true(os$Generate_Tabs_Export)
  expect_true(os$Allow_Approx_Utilities_Export)
  expect_equal(os$Tabs_Question_Code, "CJX")

  tpl_script <- file.path(TURAS_ROOT, "modules", "maxdiff", "templates",
                          "create_maxdiff_template.R")
  skip_if(!file.exists(tpl_script), "template generator not present")
  out <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out), add = TRUE)
  env <- new.env()
  assign("TURAS_LAUNCHER_ACTIVE", TRUE, envir = env)
  sys.source(tpl_script, envir = env)
  capture.output(env$create_maxdiff_template(out))
  sheet <- openxlsx::read.xlsx(out, sheet = "OUTPUT_SETTINGS", skipEmptyRows = FALSE)
  expect_true(all(c("Generate_Tabs_Export", "Tabs_Question_Code",
                    "Allow_Approx_Utilities_Export") %in% sheet$Setting_Name))
  cfg <- load_maxdiff_config(out)
  expect_false(cfg$output_settings$Generate_Tabs_Export)
  expect_false(cfg$output_settings$Allow_Approx_Utilities_Export)
  expect_equal(cfg$output_settings$Tabs_Question_Code, "MDSHARE")
})

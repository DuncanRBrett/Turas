# ==============================================================================
# CHECKPOINT FINGERPRINTING (review 2026-08-21, finding C-1)
# ==============================================================================
# A checkpoint may only be resumed into the run that created it. Before this
# guard existed, checkpoints carried only results + a timestamp against a
# constant filename per output folder, so a resume could silently graft one
# run's numbers into another run's workbook — either after the operator edited
# the config/data between runs, or across two configs sharing an output folder.
#
# These are BEHAVIOURAL tests: they save and load real checkpoint files in a
# temp directory. The pre-existing checkpoint tests assert on formals() and
# deparse(body()), which pin signatures rather than behaviour.

.ckpt_lib <- file.path(rprojroot::find_root(rprojroot::has_dir(".git")),
                       "modules", "tabs", "lib")
source(file.path(.ckpt_lib, "logging_utils.R"), local = FALSE)
source(file.path(.ckpt_lib, "crosstabs", "checkpoint.R"), local = FALSE)

# A fingerprint needs real files on disk (it stamps mtime + size), so each
# scenario builds a throwaway project in tempdir().
make_run <- function(root, config_text = "cfg", data_text = "data",
                     questions = c("Q1", "Q2"), banner = c("TOTAL::Total", "GEN::Male"),
                     settings = list(apply_weighting = FALSE, alpha = 0.05)) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  cfg <- file.path(root, "config.xlsx")
  str <- file.path(root, "structure.xlsx")
  dat <- file.path(root, "data.xlsx")
  writeLines(config_text, cfg)
  writeLines("structure", str)
  writeLines(data_text, dat)
  list(
    fingerprint = build_checkpoint_fingerprint(
      config_file = cfg, structure_file = str, data_file = dat,
      question_codes = questions, banner_labels = banner, config_obj = settings
    ),
    checkpoint = file.path(root, ".crosstabs_checkpoint.rds")
  )
}

test_that("a checkpoint resumes into the run that created it", {
  root <- file.path(tempdir(), paste0("ckpt_same_", as.integer(runif(1, 1, 1e6))))
  run <- make_run(root)

  save_checkpoint(run$checkpoint, list(Q1 = "results"), "Q1", run$fingerprint)
  loaded <- load_checkpoint(run$checkpoint, run$fingerprint)

  expect_false(is.null(loaded))
  expect_equal(loaded$processed, "Q1")
  expect_equal(loaded$results$Q1, "results")
})

test_that("an edited config discards the checkpoint instead of resuming it", {
  root <- file.path(tempdir(), paste0("ckpt_cfg_", as.integer(runif(1, 1, 1e6))))
  run <- make_run(root)
  save_checkpoint(run$checkpoint, list(Q1 = "OLD CONFIG RESULTS"), "Q1", run$fingerprint)

  # The operator edits the config and re-runs. Size differs, so this does not
  # depend on filesystem mtime granularity.
  writeLines("cfg edited by the operator", file.path(root, "config.xlsx"))
  after <- build_checkpoint_fingerprint(
    config_file = file.path(root, "config.xlsx"),
    structure_file = file.path(root, "structure.xlsx"),
    data_file = file.path(root, "data.xlsx"),
    question_codes = c("Q1", "Q2"), banner_labels = c("TOTAL::Total", "GEN::Male"),
    config_obj = list(apply_weighting = FALSE, alpha = 0.05)
  )

  expect_equal(checkpoint_fingerprint_diff(run$fingerprint, after), "the config file")
  expect_output(
    expect_null(load_checkpoint(run$checkpoint, after)),
    "TURAS CHECKPOINT DISCARDED"
  )
})

test_that("a re-exported data file discards the checkpoint", {
  root <- file.path(tempdir(), paste0("ckpt_data_", as.integer(runif(1, 1, 1e6))))
  run <- make_run(root)
  save_checkpoint(run$checkpoint, list(Q1 = "stale"), "Q1", run$fingerprint)

  writeLines("data re-exported with more responses", file.path(root, "data.xlsx"))
  after <- build_checkpoint_fingerprint(
    config_file = file.path(root, "config.xlsx"),
    structure_file = file.path(root, "structure.xlsx"),
    data_file = file.path(root, "data.xlsx"),
    question_codes = c("Q1", "Q2"), banner_labels = c("TOTAL::Total", "GEN::Male"),
    config_obj = list(apply_weighting = FALSE, alpha = 0.05)
  )

  expect_equal(checkpoint_fingerprint_diff(run$fingerprint, after), "the survey data file")
  expect_output(expect_null(load_checkpoint(run$checkpoint, after)), "survey data file")
})

test_that("a second config in the same output folder cannot resume the first's results", {
  # Scenario (b) from C-1: the GUI batches every config in a folder, and the
  # checkpoint filename is a constant, so both configs address the same file.
  root <- file.path(tempdir(), paste0("ckpt_two_", as.integer(runif(1, 1, 1e6))))
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  writeLines("weighted config", file.path(root, "config_weighted.xlsx"))
  writeLines("plain config", file.path(root, "config_plain.xlsx"))
  writeLines("structure", file.path(root, "structure.xlsx"))
  writeLines("data", file.path(root, "data.xlsx"))
  shared_checkpoint <- file.path(root, ".crosstabs_checkpoint.rds")

  fp <- function(cfg, weighted) build_checkpoint_fingerprint(
    config_file = file.path(root, cfg),
    structure_file = file.path(root, "structure.xlsx"),
    data_file = file.path(root, "data.xlsx"),
    question_codes = c("Q1", "Q2"), banner_labels = c("TOTAL::Total"),
    config_obj = list(apply_weighting = weighted, alpha = 0.05)
  )

  # Config A (weighted) crashes mid-run, leaving its checkpoint behind.
  save_checkpoint(shared_checkpoint, list(Q1 = "WEIGHTED NUMBERS"), "Q1", fp("config_weighted.xlsx", TRUE))

  # Config B (unweighted) now runs against the same folder.
  expect_output(
    expect_null(load_checkpoint(shared_checkpoint, fp("config_plain.xlsx", FALSE))),
    "TURAS CHECKPOINT DISCARDED"
  )
})

test_that("changing the selected questions or the banner discards the checkpoint", {
  root <- file.path(tempdir(), paste0("ckpt_sel_", as.integer(runif(1, 1, 1e6))))
  run <- make_run(root)

  added_question <- build_checkpoint_fingerprint(
    config_file = file.path(root, "config.xlsx"),
    structure_file = file.path(root, "structure.xlsx"),
    data_file = file.path(root, "data.xlsx"),
    question_codes = c("Q1", "Q2", "Q3"), banner_labels = c("TOTAL::Total", "GEN::Male"),
    config_obj = list(apply_weighting = FALSE, alpha = 0.05)
  )
  expect_equal(checkpoint_fingerprint_diff(run$fingerprint, added_question),
               "the selected questions")

  new_banner <- build_checkpoint_fingerprint(
    config_file = file.path(root, "config.xlsx"),
    structure_file = file.path(root, "structure.xlsx"),
    data_file = file.path(root, "data.xlsx"),
    question_codes = c("Q1", "Q2"), banner_labels = c("TOTAL::Total", "AGE::18-34"),
    config_obj = list(apply_weighting = FALSE, alpha = 0.05)
  )
  expect_equal(checkpoint_fingerprint_diff(run$fingerprint, new_banner),
               "the banner definition")
})

test_that("reordering the Selection sheet does NOT discard a usable checkpoint", {
  # Already-computed tables stay valid when the same questions arrive in a
  # different order, so the guard must not force a needless full recompute.
  root <- file.path(tempdir(), paste0("ckpt_order_", as.integer(runif(1, 1, 1e6))))
  run <- make_run(root, questions = c("Q1", "Q2"))
  reordered <- build_checkpoint_fingerprint(
    config_file = file.path(root, "config.xlsx"),
    structure_file = file.path(root, "structure.xlsx"),
    data_file = file.path(root, "data.xlsx"),
    question_codes = c("Q2", "Q1"), banner_labels = c("TOTAL::Total", "GEN::Male"),
    config_obj = list(apply_weighting = FALSE, alpha = 0.05)
  )
  expect_length(checkpoint_fingerprint_diff(run$fingerprint, reordered), 0)
})

test_that("a checkpoint written before fingerprinting existed is never trusted", {
  root <- file.path(tempdir(), paste0("ckpt_legacy_", as.integer(runif(1, 1, 1e6))))
  run <- make_run(root)
  # The old shape: results + processed + timestamp, no fingerprint.
  saveRDS(list(results = list(Q1 = "pre-fingerprint"), processed = "Q1",
               timestamp = Sys.time()), run$checkpoint)

  expect_output(
    expect_null(load_checkpoint(run$checkpoint, run$fingerprint)),
    "TURAS CHECKPOINT DISCARDED"
  )
})

test_that("setup_checkpointing starts fresh when the fingerprint does not match", {
  root <- file.path(tempdir(), paste0("ckpt_setup_", as.integer(runif(1, 1, 1e6))))
  run <- make_run(root)
  save_checkpoint(run$checkpoint, list(Q1 = "stale"), "Q1", run$fingerprint)
  questions <- data.frame(QuestionCode = c("Q1", "Q2"), stringsAsFactors = FALSE)

  # Same run: resumes, Q1 excluded from the remaining work.
  resumed <- setup_checkpointing(TRUE, run$checkpoint, questions, run$fingerprint)
  expect_true(resumed$resumed)
  expect_equal(resumed$remaining_questions$QuestionCode, "Q2")

  # Different run: every question is recomputed.
  writeLines("cfg changed", file.path(root, "config.xlsx"))
  changed <- build_checkpoint_fingerprint(
    config_file = file.path(root, "config.xlsx"),
    structure_file = file.path(root, "structure.xlsx"),
    data_file = file.path(root, "data.xlsx"),
    question_codes = c("Q1", "Q2"), banner_labels = c("TOTAL::Total", "GEN::Male"),
    config_obj = list(apply_weighting = FALSE, alpha = 0.05)
  )
  fresh <- suppressWarnings(capture.output(
    result <- setup_checkpointing(TRUE, run$checkpoint, questions, changed)
  ))
  expect_false(result$resumed)
  expect_equal(result$remaining_questions$QuestionCode, c("Q1", "Q2"))
  expect_length(result$all_results, 0)
})

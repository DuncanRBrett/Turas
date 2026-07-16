# ==============================================================================
# TABS — SHARED AI PROSE VOICE (TURAS_PROSE_VOICE injection contract)
# ==============================================================================
# The single shared writing-voice fragment must be injected into every AI call
# that writes reader-facing PROSE (callout, exec patterns, exec narrative, and
# the reader narrative) and kept OFF the QA calls (verification, selectivity),
# where a writing voice is irrelevant. It must also degrade gracefully: a run in
# which ai_voice.R was not sourced produces a plain prompt, never an error.
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  for (candidate in c(getwd(), file.path(getwd(), "../.."),
                      file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME.")
}
turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/shared/lib/ai/ai_voice.R"))
source(file.path(turas_root, "modules/tabs/lib/ai/ai_prompts.R"))
source(file.path(turas_root, "modules/tabs/lib/reader_report/reader_ai_prose.R"))

ctx    <- list(study_name = "Test Study")
marker <- "Never announce"   # a phrase unique to the shared fragment

test_that("the shared voice fragment exists and carries the core rules", {
  expect_true(exists("TURAS_PROSE_VOICE"))
  expect_true(nzchar(TURAS_PROSE_VOICE))
  expect_true(grepl("a tension", TURAS_PROSE_VOICE, fixed = TRUE))          # abstraction ban
  expect_true(grepl("worth noting", TURAS_PROSE_VOICE, fixed = TRUE))       # signposting ban
  expect_true(grepl("CLAIMED or ACTUAL", TURAS_PROSE_VOICE, fixed = TRUE))  # claimed vs actual
  expect_true(grepl("leverage", TURAS_PROSE_VOICE, fixed = TRUE))           # unified banned list
  expect_true(grepl("South African English", TURAS_PROSE_VOICE, fixed = TRUE))
})

test_that("prose prompts carry the voice; QA prompts do not", {
  callout <- build_insight_prompt(list(q_code = "Q1"), ctx, "ai_callout")
  patts   <- build_insight_prompt(list(q = "x"), ctx, "exec_patterns")
  narr    <- build_insight_prompt(list(patterns = list(), all_q_data = list()), ctx, "exec_narrative")
  verify  <- build_insight_prompt(list(narrative = "t", question_data = list()), ctx, "verification")
  select  <- build_insight_prompt(list(a = 1), ctx, "selectivity")

  expect_true(grepl(marker, callout$system, fixed = TRUE))
  expect_true(grepl(marker, patts$system,   fixed = TRUE))
  expect_true(grepl(marker, narr$system,    fixed = TRUE))
  expect_false(grepl(marker, verify$system, fixed = TRUE))
  expect_false(grepl(marker, select$system, fixed = TRUE))
})

test_that("the executive summary no longer ends on a forward-looking question", {
  narr <- build_insight_prompt(list(patterns = list(), all_q_data = list()), ctx, "exec_narrative")
  expect_false(grepl("forward-looking", narr$user, fixed = TRUE))
})

test_that("the callout prompt's bespoke banned list is retired (one source of truth)", {
  callout <- build_insight_prompt(list(q_code = "Q1"), ctx, "ai_callout")
  expect_false(grepl("Do not use:", callout$system, fixed = TRUE))
})

test_that("the reader narrative prompt carries the shared voice", {
  sys <- reader_ai_prompt(list())$system
  expect_true(grepl(marker, sys, fixed = TRUE))
})

test_that("a missing fragment degrades to no-voice without erroring", {
  saved <- TURAS_PROSE_VOICE
  rm("TURAS_PROSE_VOICE", envir = .GlobalEnv)
  on.exit(assign("TURAS_PROSE_VOICE", saved, envir = .GlobalEnv))
  p <- build_insight_prompt(list(q_code = "Q1"), ctx, "ai_callout")
  expect_type(p$system, "character")
  expect_false(grepl(marker, p$system, fixed = TRUE))
})

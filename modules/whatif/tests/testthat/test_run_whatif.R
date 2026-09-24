# Session 2 and 4: a whole run from a config, the preflight, the outputs and
# the client-safe block of the contribution file.

proj <- test_project()
res <- quietly(run_whatif(proj$config, verbose = FALSE))

test_that("a run from a config writes the workbook and the contribution file", {
  expect_false(is_refusal(res))
  expect_false(is_error(res))
  expect_true(res$status %in% c("PASS", "PARTIAL"))
  expect_true(file.exists(res$files$excel))
  expect_true(file.exists(res$files$island))
  sheets <- readxl::excel_sheets(res$files$excel)
  expect_equal(sheets[1], "Run_Status")
  expect_true(all(c("Effort", "Groups", "Calibration", "Preflight", "Proposed_Structure", "Model",
                    "Profile", "Symptoms") %in% sheets))
})

test_that("the run matches the engine run on the same spec", {
  m <- quietly(whatif_run_engine(res$prep$spec, verbose = FALSE))
  expect_equal(unname(m$main$b), unname(res$model$main$b))
})

test_that("preflight finds the planted problems", {
  log <- res$preflight
  expect_true(any(log$Check == "Don't know" & log$Field == "admin"))
  expect_true(any(log$Check == "Possible symptom or outcome" & grepl("complain", log$Message)) ||
                !any(res$prep$spec$levers[[1]]$key == "called"))
  expect_true(any(log$Check == "Sign check" & log$Field == "noise"))
  expect_true(all(c("Component", "Check", "Field", "Message", "Severity") %in% names(log)))
})

test_that("proposed Structure rules list structural combinations nobody has, never personal traits", {
  ps <- res$proposed_structure
  expect_true(nrow(ps) > 0)
  expect_false(any(c(ps$Key1, ps$Key2) == "gender"))
  msc <- ps[ps$Key1 == "course" & ps$Level1 == "MSc" & ps$Key2 == "year" & ps$Level2 == "1st", ]
  expect_equal(nrow(msc), 1)
  ba <- ps[ps$Key1 == "course" & ps$Level1 == "BA" & ps$Key2 == "year" & ps$Level2 == "Masters", ]
  expect_true(ba$AlreadyRule)
})

test_that("the contribution file has every block, and meta says what it is", {
  j <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)
  expect_equal(j$meta$kind, "whatif")
  expect_equal(j$meta$n, 500)
  expect_equal(j$meta$id_variable, "ID")
  expect_true(all(c("meta", "model", "profile", "open", "safe") %in% names(j)))
  expect_length(j$model$fits, 21)
  expect_length(j$open$ids, 500)
  expect_length(j$open$val$teach, 500)
  expect_equal(unlist(j$open$ids)[1:3], sprintf("R%04d", 1:3))
})

longest_list <- function(o) {
  if (is.list(o) && is.null(names(o))) return(max(c(length(o), vapply(o, longest_list, numeric(1)))))
  if (is.list(o)) return(max(c(0, vapply(o, longest_list, numeric(1)))))
  length(o)
}

test_that("the client-safe block holds no respondent-length list and no group under the minimum", {
  j <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)
  safe <- list(meta = j$meta, model = j$model, safe = j$safe)
  expect_lt(longest_list(safe), 500)
  ns <- vapply(j$safe$groups, `[[`, 0, "n")
  expect_true(all(ns >= 5))
  needs <- unlist(lapply(j$safe$groups, function(g) unlist(g$need)))
  expect_true(all(is.na(needs) | needs >= 5))
  expect_equal(j$safe$audit$differencing_failures, 0)
  expect_equal(j$safe$audit$line_failures, 0)
})

test_that("published group results equal the engine's for the same group", {
  j <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)
  g <- j$safe$groups[[which(vapply(j$safe$groups, `[[`, "", "id") == "campus=North")]]
  mask <- res$model$spec$context$campus$values == "North"
  r <- whatif_group_results(res$model, list(north = mask))$north
  expect_equal(g$n, sum(mask))
  keys <- vapply(res$model$spec$levers, `[[`, "", "key")
  j_teach <- unlist(g$est[[match("teach", keys)]])
  expect_equal(j_teach[match("floor", WHATIF_MOVES)], round(r$levers$est[r$levers$key == "teach" & r$levers$move == "floor"], 2))
})

test_that("the client-safe profile offers only combinations shared by the minimum", {
  j <- jsonlite::fromJSON(res$files$island, simplifyVector = FALSE)
  sp <- j$safe$profile
  keys <- vapply(sp$keys, `[[`, "", "key")
  ctx <- res$model$spec$context
  combo <- do.call(paste, c(lapply(keys, function(k) ctx[[k]]$values), sep = "|"))
  for (cb in sp$combos) {
    lv <- vapply(seq_along(keys), function(i) sp$keys[[i]]$levels[[unlist(cb)[i] + 1]], "")
    expect_gte(sum(combo == paste(lv, collapse = "|")), 5)
  }
  counts <- unlist(lapply(sp$keys, function(k) unlist(k$n)))
  expect_true(all(counts >= 5))
})

test_that("the profile builder switch removes Build a ... from every block", {
  p2 <- test_project(config = list(profile_builder = "N"), n = 300)
  r2 <- quietly(run_whatif(p2$config, verbose = FALSE))
  j <- jsonlite::fromJSON(r2$files$island, simplifyVector = FALSE)
  expect_null(j$profile)
  expect_null(j$safe$profile)
})

test_that("symptom effects are reported and never enter the model", {
  expect_length(res$payload$model$symptoms, 1)
  expect_false("called" %in% vapply(res$model$spec$levers, `[[`, "", "key"))
})

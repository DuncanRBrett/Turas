# ==============================================================================
# BRAND MODULE TESTS - ROLE-REGISTRY GUARD LAYER
# ==============================================================================
# Covers guard_validate_role_map() per ROLE_REGISTRY §12.
# Every refusal code is exercised with a known-bad fixture.
# ==============================================================================

.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) {
      return(dir)
    }
    dir <- dirname(dir)
  }
  getwd()
}

TURAS_ROOT <- .find_turas_root_for_test()

shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "00_guard_role_map.R"))


# --- Fixture builders --------------------------------------------------------

.brand_list <- function(codes = c("IPK", "ROB", "CART")) {
  data.frame(BrandCode = codes,
             BrandLabel = codes,
             stringsAsFactors = FALSE)
}

.cep_list <- function(codes = c("CEP01", "CEP02")) {
  data.frame(CEPCode = codes,
             CEPText = paste("cep", codes),
             stringsAsFactors = FALSE)
}

.option_map_attitude <- function() {
  data.frame(
    Scale       = rep("attitude_scale", 5),
    ClientCode  = as.character(1:5),
    Role        = c("attitude.love", "attitude.prefer",
                    "attitude.ambivalent", "attitude.reject",
                    "attitude.no_opinion"),
    ClientLabel = c("Favourite", "Prefer", "Ambivalent",
                    "Reject", "No opinion"),
    OrderIndex  = 1:5,
    stringsAsFactors = FALSE
  )
}

.qm <- function() {
  data.frame(
    Role = c(
      "funnel.awareness", "funnel.attitude",
      "system.respondent.id", "system.respondent.weight"
    ),
    ClientCode = c("BRANDAWARE", "QBRANDATT1", "Respondent_ID", "Weight"),
    QuestionText = c("Heard of?", "Attitude?", NA, NA),
    QuestionTextShort = NA_character_,
    Variable_Type = c("Multi_Mention", "Single_Response",
                      "Single_Response", "Numeric"),
    ColumnPattern = c("{code}_{brand_code}", "{code}_{brand_code}",
                      "{code}", "{code}"),
    OptionMapScale = c("", "attitude_scale", "", ""),
    Notes = NA_character_,
    stringsAsFactors = FALSE
  )
}

.structure <- function(questionmap = .qm(),
                       optionmap = .option_map_attitude(),
                       brands = .brand_list(),
                       ceps = .cep_list()) {
  list(questionmap = questionmap,
       optionmap   = optionmap,
       brands      = brands,
       ceps        = ceps,
       dba_assets  = NULL)
}

.good_data <- function(brands = c("IPK", "ROB", "CART"), n = 20L, seed = 1L) {
  set.seed(seed)
  d <- data.frame(Respondent_ID = seq_len(n),
                  Weight = runif(n, 0.5, 1.5),
                  stringsAsFactors = FALSE)
  for (b in brands) {
    d[[paste0("BRANDAWARE_", b)]] <- sample(0:1, n, replace = TRUE)
    d[[paste0("QBRANDATT1_", b)]] <- sample(1:5, n, replace = TRUE)
  }
  d
}


# --- Happy path --------------------------------------------------------------

test_that("guard passes on a well-formed fixture", {
  rm <- load_role_map(.structure())
  res <- guard_validate_role_map(
    role_map       = rm,
    required_roles = c("funnel.awareness", "funnel.attitude"),
    data           = .good_data(),
    brand_list     = .brand_list()
  )
  expect_equal(res$status, "PASS")
})


# --- CFG_ROLE_MISSING --------------------------------------------------------

test_that("missing required role refuses with CFG_ROLE_MISSING", {
  rm <- load_role_map(.structure())
  res <- brand_with_refusal_handler(
    guard_validate_role_map(
      rm, required_roles = c("funnel.awareness", "ma.cep_matrix"),
      data = .good_data(), brand_list = .brand_list())
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_ROLE_MISSING")
  expect_true("ma.cep_matrix" %in% res$missing)
})


# --- CFG_COLUMN_NOT_FOUND ----------------------------------------------------

test_that("role pointing at a non-existent column refuses with CFG_COLUMN_NOT_FOUND", {
  rm <- load_role_map(.structure())
  data <- .good_data()
  data$BRANDAWARE_CART <- NULL  # Drop one brand's column
  res <- brand_with_refusal_handler(
    guard_validate_role_map(
      rm, required_roles = "funnel.awareness",
      data = data, brand_list = .brand_list())
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_COLUMN_NOT_FOUND")
  expect_true("BRANDAWARE_CART" %in% res$missing)
})


# --- CFG_PATTERN_MISMATCH ----------------------------------------------------

test_that("resolver producing zero columns refuses with CFG_PATTERN_MISMATCH", {
  qm <- .qm()
  qm$ColumnPattern[qm$Role == "funnel.awareness"] <- "{code}_{cep_code}"
  rm <- load_role_map(.structure(qm, ceps = .cep_list()))
  rm[["funnel.awareness"]]$columns <- character(0)

  res <- brand_with_refusal_handler(
    guard_validate_role_map(
      rm, required_roles = "funnel.awareness",
      data = .good_data(), brand_list = .brand_list())
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_PATTERN_MISMATCH")
})


# --- CFG_OPTIONMAP_INCOMPLETE ------------------------------------------------

test_that("Single_Response with missing OptionMap scale refuses", {
  rm <- load_role_map(.structure(optionmap = NULL))
  res <- brand_with_refusal_handler(
    guard_validate_role_map(
      rm, required_roles = "funnel.attitude",
      data = .good_data(), brand_list = .brand_list())
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_OPTIONMAP_INCOMPLETE")
})

test_that("Single_Response with blank OptionMapScale does NOT fail guard", {
  qm <- .qm()
  qm$OptionMapScale[qm$Role == "funnel.attitude"] <- ""
  rm <- load_role_map(.structure(qm, optionmap = NULL))
  res <- guard_validate_role_map(
    rm, required_roles = "funnel.attitude",
    data = .good_data(), brand_list = .brand_list())
  expect_equal(res$status, "PASS")
})


# --- DATA_RESPONDENT_ID_DUPLICATE --------------------------------------------

test_that("duplicate respondent IDs refuse loud", {
  rm <- load_role_map(.structure())
  data <- .good_data()
  data$Respondent_ID[5] <- data$Respondent_ID[4]
  res <- brand_with_refusal_handler(
    guard_validate_role_map(
      rm, required_roles = c("funnel.awareness", "funnel.attitude"),
      data = data, brand_list = .brand_list())
  )
  expect_true(res$refused)
  expect_equal(res$code, "DATA_RESPONDENT_ID_DUPLICATE")
})


# --- Weight invariants -------------------------------------------------------

test_that("non-numeric weight refuses with DATA_WEIGHT_NON_NUMERIC", {
  rm <- load_role_map(.structure())
  data <- .good_data()
  data$Weight <- rep("abc", nrow(data))
  res <- brand_with_refusal_handler(
    guard_validate_role_map(
      rm, required_roles = c("funnel.awareness", "funnel.attitude"),
      data = data, brand_list = .brand_list())
  )
  expect_true(res$refused)
  expect_equal(res$code, "DATA_WEIGHT_NON_NUMERIC")
})

test_that("negative weight refuses with DATA_WEIGHT_NEGATIVE", {
  rm <- load_role_map(.structure())
  data <- .good_data()
  data$Weight[3] <- -1
  res <- brand_with_refusal_handler(
    guard_validate_role_map(
      rm, required_roles = c("funnel.awareness", "funnel.attitude"),
      data = data, brand_list = .brand_list())
  )
  expect_true(res$refused)
  expect_equal(res$code, "DATA_WEIGHT_NEGATIVE")
})

test_that("zero-sum weight refuses with DATA_WEIGHT_ZERO_SUM", {
  rm <- load_role_map(.structure())
  data <- .good_data()
  data$Weight <- 0
  res <- brand_with_refusal_handler(
    guard_validate_role_map(
      rm, required_roles = c("funnel.awareness", "funnel.attitude"),
      data = data, brand_list = .brand_list())
  )
  expect_true(res$refused)
  expect_equal(res$code, "DATA_WEIGHT_ZERO_SUM")
})


# --- Brand orphan warning ----------------------------------------------------

test_that("columns referencing brands not in the list produce a PARTIAL warning", {
  rm <- load_role_map(.structure())
  data <- .good_data()
  data$BRANDAWARE_GHOST <- sample(0:1, nrow(data), replace = TRUE)

  res <- guard_validate_role_map(
    rm, required_roles = c("funnel.awareness", "funnel.attitude"),
    data = data, brand_list = .brand_list())

  expect_equal(res$status, "PARTIAL")
  expect_true(any(grepl("GHOST", res$warnings)))
})

test_that("no orphan warning when data contains only declared brands", {
  rm <- load_role_map(.structure())
  data <- .good_data()
  res <- guard_validate_role_map(
    rm, required_roles = c("funnel.awareness", "funnel.attitude"),
    data = data, brand_list = .brand_list())
  expect_equal(res$status, "PASS")
})


# --- Top-level argument errors -----------------------------------------------

test_that("empty data refuses with DATA_EMPTY", {
  rm <- load_role_map(.structure())
  res <- brand_with_refusal_handler(
    guard_validate_role_map(
      rm, required_roles = character(0),
      data = data.frame(), brand_list = .brand_list())
  )
  expect_true(res$refused)
  expect_equal(res$code, "DATA_EMPTY")
})


# --- Optional roles do not refuse when absent -------------------------------

test_that("required_roles = character(0) still validates other invariants", {
  rm <- load_role_map(.structure())
  res <- guard_validate_role_map(
    rm, required_roles = character(0),
    data = .good_data(), brand_list = .brand_list())
  expect_equal(res$status, "PASS")
})

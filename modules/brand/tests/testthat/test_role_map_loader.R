# ==============================================================================
# BRAND MODULE TESTS - ROLE MAP LOADER
# ==============================================================================
# Covers load_role_map() + .resolve_column_pattern().
# Design: in-memory fixtures (no Excel round-trip). Excel round-trip is
# covered by the integration suite in Phase E.
# Reference: modules/brand/docs/ROLE_REGISTRY.md §11.
# ==============================================================================

# --- Locate project root and source module ---
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

.asset_list <- function(codes = c("A01", "A02", "A03")) {
  data.frame(AssetCode = codes,
             AssetLabel = codes,
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

.qm_row <- function(role, client_code = "", variable_type = "Multi_Mention",
                    pattern = "{code}", scale = "",
                    question_text = NA_character_,
                    question_text_short = NA_character_,
                    notes = NA_character_) {
  data.frame(
    Role              = role,
    ClientCode        = client_code,
    QuestionText      = question_text,
    QuestionTextShort = question_text_short,
    Variable_Type     = variable_type,
    ColumnPattern     = pattern,
    OptionMapScale    = scale,
    Notes             = notes,
    stringsAsFactors  = FALSE
  )
}

.structure <- function(questionmap, optionmap = NULL,
                       brands = .brand_list(),
                       ceps = .cep_list(),
                       assets = .asset_list()) {
  list(questionmap = questionmap,
       optionmap   = optionmap,
       brands      = brands,
       ceps        = ceps,
       dba_assets  = assets)
}


# --- Tests: pattern resolution happy paths -----------------------------------

test_that("literal {code} pattern returns one column named by ClientCode", {
  qm <- .qm_row("system.respondent.id",
                client_code = "Respondent_ID",
                variable_type = "Single_Response",
                pattern = "{code}")
  rm <- load_role_map(.structure(qm))

  expect_equal(rm[["system.respondent.id"]]$columns, "Respondent_ID")
  expect_equal(rm[["system.respondent.id"]]$client_code, "Respondent_ID")
  expect_equal(rm[["system.respondent.id"]]$column_pattern, "{code}")
})

test_that("{code}_{brand_code} expands to one column per brand", {
  qm <- .qm_row("funnel.awareness",
                client_code = "BRANDAWARE",
                variable_type = "Multi_Mention",
                pattern = "{code}_{brand_code}")
  rm <- load_role_map(.structure(qm))

  expect_equal(rm[["funnel.awareness"]]$columns,
               c("BRANDAWARE_IPK", "BRANDAWARE_ROB", "BRANDAWARE_CART"))
})

test_that("{code}_{brandcode} (no-underscore alias) is equivalent", {
  qm <- .qm_row("funnel.awareness",
                client_code = "Q1",
                pattern = "{code}_{brandcode}")
  rm <- load_role_map(.structure(qm, brands = .brand_list(c("A", "B"))))

  expect_equal(rm[["funnel.awareness"]]$columns, c("Q1_A", "Q1_B"))
})

test_that("compound {code}_{cep_code}_{brand_code} expands across cross-product", {
  qm <- .qm_row("ma.cep_matrix",
                client_code = "Q1BRAND",
                pattern = "{code}_{cep_code}_{brand_code}")
  rm <- load_role_map(.structure(
    qm,
    brands = .brand_list(c("A", "B")),
    ceps   = .cep_list(c("C1", "C2"))
  ))

  cols <- rm[["ma.cep_matrix"]]$columns
  expect_equal(length(cols), 4)
  expect_true("Q1BRAND_C1_A" %in% cols)
  expect_true("Q1BRAND_C2_B" %in% cols)
})

test_that("{asset_code} pattern expands over the DBA asset list", {
  qm <- .qm_row("dba.asset.closed",
                client_code = "DBAA",
                variable_type = "Single_Response",
                pattern = "{code}_{asset_code}")
  rm <- load_role_map(.structure(qm))

  expect_equal(rm[["dba.asset.closed"]]$columns,
               c("DBAA_A01", "DBAA_A02", "DBAA_A03"))
})

test_that("{index} expands to 1..N using the asset list length", {
  qm <- .qm_row("dba.asset",
                client_code = "DBA",
                pattern = "{code}.{index}")
  rm <- load_role_map(.structure(qm))

  expect_equal(rm[["dba.asset"]]$columns,
               c("DBA.1", "DBA.2", "DBA.3"))
})

test_that("blank ColumnPattern defaults to {code}", {
  qm <- .qm_row("system.respondent.weight",
                client_code = "Weight",
                variable_type = "Numeric",
                pattern = "")
  rm <- load_role_map(.structure(qm))

  expect_equal(rm[["system.respondent.weight"]]$columns, "Weight")
})

test_that("patterns with no tokens and no {code} stay literal", {
  qm <- .qm_row("system.literal",
                client_code = "",
                variable_type = "Numeric",
                pattern = "SomeExactColumnName")
  rm <- load_role_map(.structure(qm))

  expect_equal(rm[["system.literal"]]$columns, "SomeExactColumnName")
})


# --- Tests: OptionMap lookup -------------------------------------------------

test_that("OptionMap scale is attached to roles that declare one", {
  qm <- .qm_row("funnel.attitude",
                client_code = "QBRANDATT1",
                variable_type = "Single_Response",
                pattern = "{code}_{brand_code}",
                scale = "attitude_scale")
  rm <- load_role_map(.structure(qm, optionmap = .option_map_attitude()))

  opt <- rm[["funnel.attitude"]]$option_map
  expect_equal(nrow(opt), 5)
  expect_true("attitude.love" %in% opt$Role)
})

test_that("missing optionmap is attached as NULL, not an error", {
  qm <- .qm_row("funnel.attitude",
                client_code = "QBRANDATT1",
                variable_type = "Single_Response",
                pattern = "{code}_{brand_code}",
                scale = "")
  rm <- load_role_map(.structure(qm))
  expect_null(rm[["funnel.attitude"]]$option_map)
})

test_that("unused scale entries do not leak into other roles", {
  qm <- rbind(
    .qm_row("funnel.attitude", "QBRANDATT1", "Single_Response",
            "{code}_{brand_code}", "attitude_scale"),
    .qm_row("funnel.awareness", "BRANDAWARE", "Multi_Mention",
            "{code}_{brand_code}", "")
  )
  rm <- load_role_map(.structure(qm, optionmap = .option_map_attitude()))

  expect_equal(nrow(rm[["funnel.attitude"]]$option_map), 5)
  expect_null(rm[["funnel.awareness"]]$option_map)
})


# --- Tests: multiple rows ----------------------------------------------------

test_that("multiple QuestionMap rows produce one role-map entry each", {
  qm <- rbind(
    .qm_row("funnel.awareness", "BRANDAWARE", "Multi_Mention",
            "{code}_{brand_code}", ""),
    .qm_row("funnel.attitude",  "QBRANDATT1", "Single_Response",
            "{code}_{brand_code}", "attitude_scale"),
    .qm_row("system.respondent.id", "Respondent_ID", "Single_Response",
            "{code}", ""),
    .qm_row("system.respondent.weight", "Weight", "Numeric",
            "{code}", "")
  )
  rm <- load_role_map(.structure(qm, optionmap = .option_map_attitude()))

  expect_setequal(names(rm),
    c("funnel.awareness", "funnel.attitude",
      "system.respondent.id", "system.respondent.weight"))
})

test_that("question_text_short falls back to question_text when blank", {
  qm <- .qm_row("funnel.awareness", "BRANDAWARE", "Multi_Mention",
                "{code}_{brand_code}", "",
                question_text = "Which brands have you heard of?",
                question_text_short = "")
  rm <- load_role_map(.structure(qm))

  expect_equal(rm[["funnel.awareness"]]$question_text,
               "Which brands have you heard of?")
  expect_equal(rm[["funnel.awareness"]]$question_text_short,
               "Which brands have you heard of?")
})


# --- Tests: refusals on bad input -------------------------------------------

test_that("NULL structure refuses with CFG_NULL_STRUCTURE", {
  res <- brand_with_refusal_handler(load_role_map(NULL))
  expect_true(res$refused)
  expect_equal(res$code, "CFG_NULL_STRUCTURE")
})

test_that("missing QuestionMap refuses with CFG_QUESTIONMAP_MISSING", {
  res <- brand_with_refusal_handler(
    load_role_map(list(questionmap = NULL, brands = .brand_list(),
                       ceps = .cep_list(), dba_assets = .asset_list()))
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_QUESTIONMAP_MISSING")
})

test_that("blank Role cell refuses with CFG_ROLE_BLANK", {
  qm <- .qm_row("", client_code = "X", variable_type = "Numeric")
  res <- brand_with_refusal_handler(load_role_map(.structure(qm)))
  expect_true(res$refused)
  expect_equal(res$code, "CFG_ROLE_BLANK")
})

test_that("blank Variable_Type refuses with CFG_VARIABLE_TYPE_BLANK", {
  qm <- .qm_row("funnel.awareness",
                client_code = "BRANDAWARE",
                variable_type = "",
                pattern = "{code}_{brand_code}")
  res <- brand_with_refusal_handler(load_role_map(.structure(qm)))
  expect_true(res$refused)
  expect_equal(res$code, "CFG_VARIABLE_TYPE_BLANK")
})

test_that("unknown Variable_Type refuses with CFG_VARIABLE_TYPE_INVALID", {
  qm <- .qm_row("funnel.awareness",
                client_code = "BRANDAWARE",
                variable_type = "Bogus_Type",
                pattern = "{code}")
  res <- brand_with_refusal_handler(load_role_map(.structure(qm)))
  expect_true(res$refused)
  expect_equal(res$code, "CFG_VARIABLE_TYPE_INVALID")
})

test_that("unknown token refuses with CFG_PATTERN_INVALID", {
  qm <- .qm_row("funnel.awareness",
                client_code = "BRANDAWARE",
                variable_type = "Multi_Mention",
                pattern = "{code}_{wave_code}")
  res <- brand_with_refusal_handler(load_role_map(.structure(qm)))
  expect_true(res$refused)
  expect_equal(res$code, "CFG_PATTERN_INVALID")
})

test_that("per-brand pattern with empty brand list refuses with CFG_BRAND_LIST_MISSING", {
  qm <- .qm_row("funnel.awareness",
                client_code = "BRANDAWARE",
                variable_type = "Multi_Mention",
                pattern = "{code}_{brand_code}")
  res <- brand_with_refusal_handler(
    load_role_map(.structure(qm, brands = data.frame()))
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_BRAND_LIST_MISSING")
})

test_that("per-CEP pattern with empty CEP list refuses with CFG_CEP_LIST_MISSING", {
  qm <- .qm_row("ma.cep_matrix",
                client_code = "Q1BRAND",
                pattern = "{code}_{cep_code}_{brand_code}")
  res <- brand_with_refusal_handler(
    load_role_map(.structure(qm, ceps = data.frame()))
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_CEP_LIST_MISSING")
})

test_that("per-asset pattern with empty asset list refuses with CFG_ASSET_LIST_MISSING", {
  qm <- .qm_row("dba.asset",
                client_code = "DBA",
                variable_type = "Single_Response",
                pattern = "{code}_{asset_code}")
  res <- brand_with_refusal_handler(
    load_role_map(.structure(qm, assets = data.frame()))
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_ASSET_LIST_MISSING")
})

test_that("{index} with empty asset list refuses with CFG_INDEX_LIST_MISSING", {
  qm <- .qm_row("dba.index",
                client_code = "DBA",
                pattern = "{code}.{index}")
  res <- brand_with_refusal_handler(
    load_role_map(.structure(qm, assets = data.frame()))
  )
  expect_true(res$refused)
  expect_equal(res$code, "CFG_INDEX_LIST_MISSING")
})

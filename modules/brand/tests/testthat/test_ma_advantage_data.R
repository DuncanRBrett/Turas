# ==============================================================================
# BRAND MODULE TESTS - MA ADVANTAGE PANEL DATA BUILDER
# ==============================================================================

.find_turas_root_for_test <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "launch_turas.R")) ||
        file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
TURAS_ROOT <- .find_turas_root_for_test()

source(file.path(TURAS_ROOT, "modules", "brand", "R", "02b_mental_advantage.R"))
source(file.path(TURAS_ROOT, "modules", "brand", "R", "02b_ma_advantage_data.R"))


# Helper: build the inputs to build_ma_advantage_block() from a tiny tensor.
.build_ma_inputs <- function() {
  # 2x2 textbook case as in test_mental_advantage.R
  count_mat <- matrix(c(30, 20, 10, 40), nrow = 2, ncol = 2,
                      dimnames = list(c("S1","S2"), c("A","B")))
  tensor <- list(
    A = matrix(c(rep(1L, 30), rep(0L, 70),
                 rep(1L, 20), rep(0L, 80)), nrow = 100, ncol = 2,
               dimnames = list(NULL, c("S1","S2"))),
    B = matrix(c(rep(1L, 10), rep(0L, 90),
                 rep(1L, 40), rep(0L, 60)), nrow = 100, ncol = 2,
               dimnames = list(NULL, c("S1","S2")))
  )
  ma <- calculate_mental_advantage(tensor, codes = c("S1","S2"), n_respondents = 100)

  raw_mat <- data.frame(CEPCode = c("S1","S2"), A = c(30, 20), B = c(10, 40),
                         stringsAsFactors = FALSE)

  ma_result <- list(
    cep_advantage          = ma,
    cep_brand_matrix       = raw_mat,
    attribute_advantage    = NULL,
    attribute_brand_matrix = NULL
  )
  list(ma_result = ma_result, brand_codes = c("A","B"),
       cep_list = data.frame(CEPCode = c("S1","S2"),
                              CEPText = c("First stim","Second stim"),
                              stringsAsFactors = FALSE))
}


# ==============================================================================
test_that("advantage block exposes CEPs sub-block when CEP MA result present", {
  inp <- .build_ma_inputs()
  block <- build_ma_advantage_block(inp$ma_result, inp$brand_codes,
                                     cep_list = inp$cep_list, focal_code = "A")
  expect_false(is.null(block))
  expect_equal(block$available_stims, "ceps")
  expect_equal(block$default_stim, "ceps")
  expect_equal(block$threshold_pp, 5)
  expect_null(block$attributes)
  expect_equal(block$ceps$brand_codes, c("A","B"))
  expect_equal(block$ceps$labels, c("First stim","Second stim"))
  expect_equal(length(block$ceps$cells), 4)
})


test_that("each cell carries MA, expected, actual, decision and raw linkage %", {
  inp <- .build_ma_inputs()
  block <- build_ma_advantage_block(inp$ma_result, inp$brand_codes,
                                     cep_list = inp$cep_list, focal_code = "A")
  cells <- block$ceps$cells
  cell_S1A <- Filter(function(c) c$stim_code == "S1" && c$brand_code == "A", cells)[[1]]
  expect_equal(cell_S1A$ma, 10)
  expect_equal(cell_S1A$expected, 20)
  expect_equal(cell_S1A$actual, 30)
  expect_equal(cell_S1A$decision, "defend")
  expect_equal(cell_S1A$pct_total, 30)
  expect_true(cell_S1A$is_sig)
})


test_that("focal summary classifies CEPs into Defend/Build/Maintain for the focal brand", {
  inp <- .build_ma_inputs()
  block <- build_ma_advantage_block(inp$ma_result, inp$brand_codes,
                                     cep_list = inp$cep_list, focal_code = "A")
  fs <- block$ceps$focal_summary
  expect_equal(fs$focal_brand_code, "A")
  expect_equal(fs$counts$defend, 1)
  expect_equal(fs$counts$build, 1)
  expect_equal(fs$counts$maintain, 0)
  expect_equal(fs$defend[[1]]$stim_code, "S1")
  expect_equal(fs$build[[1]]$stim_code, "S2")
})


test_that("attribute sub-block populates when attribute_advantage is provided", {
  inp <- .build_ma_inputs()
  inp$ma_result$attribute_advantage    <- inp$ma_result$cep_advantage
  inp$ma_result$attribute_brand_matrix <- inp$ma_result$cep_brand_matrix
  names(inp$ma_result$attribute_brand_matrix)[1] <- "AttrCode"
  attr_list <- data.frame(AttrCode = c("S1","S2"),
                           AttrText = c("Stylish","Practical"),
                           stringsAsFactors = FALSE)
  block <- build_ma_advantage_block(inp$ma_result, inp$brand_codes,
                                     cep_list = inp$cep_list,
                                     attribute_list = attr_list,
                                     focal_code = "A")
  expect_equal(block$available_stims, c("ceps","attributes"))
  expect_equal(block$attributes$labels, c("Stylish","Practical"))
})


test_that("advantage block returns NULL when MA result has no usable sub-result", {
  empty_result <- list(cep_advantage = NULL, attribute_advantage = NULL,
                       cep_brand_matrix = NULL, attribute_brand_matrix = NULL)
  expect_null(build_ma_advantage_block(empty_result, brand_codes = c("A","B")))
  expect_null(build_ma_advantage_block(NULL, brand_codes = c("A","B")))
})


test_that("aware-base linkage % is computed when awareness_by_brand provided", {
  inp <- .build_ma_inputs()
  awareness <- c(A = 50, B = 80)  # % aware per brand
  block <- build_ma_advantage_block(inp$ma_result, inp$brand_codes,
                                     cep_list = inp$cep_list,
                                     awareness_by_brand = awareness,
                                     focal_code = "A")
  # A on S1: pct_total = 30, awareness = 50 -> pct_aware = 30/50*100 = 60
  cell <- Filter(function(c) c$stim_code == "S1" && c$brand_code == "A",
                  block$ceps$cells)[[1]]
  expect_equal(cell$pct_aware, 60)
})

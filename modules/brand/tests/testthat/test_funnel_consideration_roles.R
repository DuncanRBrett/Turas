# ==============================================================================
# BRAND MODULE TESTS: THE CONSIDER STAGE IS DEFINED BY ROLE
# ==============================================================================
# The Consider stage's membership is named by position on the attitude scale
# ("attitude.price"), never by the response code the survey happened to
# export for it ("4", or "Price only"). These tests hold that contract.
#
# The bug they were written for: until 2026-09-06 the config knob took raw
# codes, and the OptionMap resolution ran ONLY when the codes matched the
# built-in pair. Any other code list was matched literally against the data.
# On a category whose attitude columns export LABELS rather than numbers,
# overriding with codes therefore returned a Consider stage of zero, with no
# refusal and no warning. The category next door, whose columns exported
# numbers, returned a plausible figure from the same config.
#
# Covered here:
#   - a label-encoded category, overridden by role, returns the hand-counted
#     stage (the fix)
#   - the same category overridden by raw code returns the SAME figure, so a
#     config written before the change keeps working (back-compatibility)
#   - a role the scale does not carry refuses rather than returning an empty
#     stage
#   - an unrecognised role name refuses
#   - the built-in default set drops a level the scale lacks and carries on
# ==============================================================================
library(testthat)

.find_root <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root()

shared_lib <- file.path(ROOT, "modules", "shared", "lib")
for (f in sort(list.files(shared_lib, pattern = "\\.R$", full.names = TRUE))) {
  tryCatch(source(f, local = FALSE), error = function(e) NULL)
}
source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_inference.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_role_map.R"))
source(file.path(ROOT, "modules", "brand", "R", "03a_funnel_derive.R"))
source(file.path(ROOT, "modules", "brand", "R", "03b_funnel_metrics.R"))
source(file.path(ROOT, "modules", "brand", "R", "03_funnel.R"))


# ==============================================================================
# Fixtures
# ==============================================================================

.cr_brands <- function() {
  data.frame(BrandCode = c("IPK", "ROB", "CART"),
             BrandLabel = c("IPK", "Robertsons", "Cartwrights"),
             stringsAsFactors = FALSE)
}

.cr_pack_mm <- function(picks, root) {
  n_slots <- max(vapply(picks, length, integer(1)), 1L)
  as.data.frame(
    setNames(
      lapply(seq_len(n_slots), function(j)
        vapply(picks, function(p)
          if (j <= length(p)) p[j] else NA_character_, character(1))),
      paste0(root, "_", seq_len(n_slots))),
    stringsAsFactors = FALSE)
}

# The six-level scale Duncan programmed for IPK 2026. Code 4 says the
# respondent will buy the brand if the price is right; code 3 says they would
# only consider it if nothing else were available.
.cr_optionmap_6 <- function() {
  data.frame(
    Scale      = rep("attitude_scale", 6),
    ClientCode = as.character(1:6),
    Role       = c("attitude.love", "attitude.prefer", "attitude.ambivalent",
                   "attitude.price", "attitude.avoid", "attitude.no_opinion"),
    ClientLabel = c("Love", "Prefer", "Ambivalent", "Price only",
                    "Avoid", "No opinion"),
    OrderIndex = 1:6,
    stringsAsFactors = FALSE)
}

.cr_optionmap_5 <- function() {
  data.frame(
    Scale      = rep("attitude_scale", 5),
    ClientCode = as.character(1:5),
    Role       = c("attitude.love", "attitude.prefer", "attitude.ambivalent",
                   "attitude.avoid", "attitude.no_opinion"),
    ClientLabel = c("Love", "Prefer", "Ambivalent", "Avoid", "No opinion"),
    OrderIndex = 1:5,
    stringsAsFactors = FALSE)
}

.cr_mm_entry <- function(role, column_root, n_slots) {
  list(role = role, category = "DSS", client_code = sub("_DSS$", "", column_root),
       variable_type = "Multi_Mention", column_root = column_root,
       per_brand = FALSE,
       columns = paste0(column_root, "_", seq_len(n_slots)),
       applicable_brands = NULL, question_text = "", option_scale = NA,
       option_map = NULL, notes = "")
}

.cr_att_entry <- function(option_map) {
  brands <- c("IPK", "ROB", "CART")
  list(role = "funnel.attitude", category = "DSS",
       client_code = "BRANDATT1",
       variable_type = "Single_Response_Brand",
       column_root = "BRANDATT1_DSS", per_brand = TRUE,
       columns = setNames(paste0("BRANDATT1_DSS_", brands), brands),
       applicable_brands = brands,
       question_text = "How do you feel about this brand?",
       option_scale = "attitude_scale",
       option_map = option_map, notes = "")
}

.cr_role_map <- function(option_map) {
  list(
    "funnel.awareness"          = .cr_mm_entry("funnel.awareness",
                                               "BRANDAWARE_DSS", 3),
    "funnel.attitude"           = .cr_att_entry(option_map),
    "funnel.penetration_long"   = .cr_mm_entry("funnel.penetration_long",
                                               "BRANDPEN1_DSS", 3),
    "funnel.penetration_target" = .cr_mm_entry("funnel.penetration_target",
                                               "BRANDPEN2_DSS", 3)
  )
}

# Ten respondents. The attitude columns export LABELS, which is what an
# Alchemer question whose Reporting Value was left on the option text does.
# This is the encoding the old code path could not match.
#
# IPK attitudes, in order:
#   Love, Prefer, Ambivalent, Price only, Avoid, Love, Ambivalent, Prefer,
#   No opinion, Price only
# So:  Love 2, Prefer 2, Price only 2, Ambivalent 2, Avoid 1, No opinion 1
#   love + prefer            = 4
#   love + prefer + price    = 6
.CR_IPK_ATT <- c("Love", "Prefer", "Ambivalent", "Price only", "Avoid",
                 "Love", "Ambivalent", "Prefer", "No opinion", "Price only")
.CR_ROB_ATT <- c("Prefer", "Love", "No opinion", "Price only", "Ambivalent",
                 "Avoid", "No opinion", "Price only", "Prefer", "Love")
.CR_CART_ATT <- c("No opinion", "Price only", "Prefer", "Love", "Avoid",
                  "Ambivalent", "No opinion", "Prefer", "Love", "Avoid")

.cr_data <- function(attitudes_as = c("labels", "codes")) {
  attitudes_as <- match.arg(attitudes_as)
  all3 <- replicate(10, c("IPK", "ROB", "CART"), simplify = FALSE)
  data <- cbind(
    data.frame(Respondent_ID = 1:10, Weight = 1, stringsAsFactors = FALSE),
    .cr_pack_mm(all3, "BRANDAWARE_DSS"),
    .cr_pack_mm(all3, "BRANDPEN1_DSS"),
    .cr_pack_mm(all3, "BRANDPEN2_DSS"))
  lab_to_code <- c("Love" = "1", "Prefer" = "2", "Ambivalent" = "3",
                   "Price only" = "4", "Avoid" = "5", "No opinion" = "6")
  put <- function(b, v) {
    data[[paste0("BRANDATT1_DSS_", b)]] <<-
      if (attitudes_as == "labels") v else unname(lab_to_code[v])
  }
  put("IPK", .CR_IPK_ATT)
  put("ROB", .CR_ROB_ATT)
  put("CART", .CR_CART_ATT)
  data
}

.cr_cfg <- function(...) {
  modifyList(list(`category.type` = "transactional", focal_brand = "IPK",
                  cat_code = "DSS",
                  `funnel.conversion_metric` = "ratio",
                  `funnel.warn_base` = 0, `funnel.suppress_base` = 0),
             list(...))
}

.cr_pct <- function(df, key, b) {
  row <- df[df$stage_key == key & df$brand_code == b, , drop = FALSE]
  if (nrow(row) == 0L) NA_real_ else row$pct_weighted
}


# ==============================================================================
# The fix: an override on a label-encoded category finds the right people
# ==============================================================================

test_that("Role override on a label-encoded category returns the counted stage", {
  res <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                    .cr_brands(),
                    .cr_cfg(`funnel.consideration_roles` =
                              c("love", "prefer", "price")))

  # Hand count from .CR_IPK_ATT: 2 Love + 2 Prefer + 2 Price only = 6 of 10.
  expect_equal(.cr_pct(res$stages, "consideration", "IPK"), 0.6,
               tolerance = 1e-9)
  expect_gt(.cr_pct(res$stages, "consideration", "IPK"), 0)
  expect_equal(res$meta$consideration$roles_used,
               c("attitude.love", "attitude.prefer", "attitude.price"))
  expect_equal(res$meta$consideration$source, "roles")
})


test_that("The same override reads the same on a code-encoded category", {
  by_label <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                         .cr_brands(),
                         .cr_cfg(`funnel.consideration_roles` =
                                   c("love", "prefer", "price")))
  by_code  <- run_funnel(.cr_data("codes"), .cr_role_map(.cr_optionmap_6()),
                         .cr_brands(),
                         .cr_cfg(`funnel.consideration_roles` =
                                   c("love", "prefer", "price")))
  expect_equal(by_label$stages$pct_weighted, by_code$stages$pct_weighted)
})


test_that("A comma separated string of short names is accepted", {
  res <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                    .cr_brands(),
                    .cr_cfg(`funnel.consideration_roles` =
                              "Love, Prefer, Price only"))
  expect_equal(.cr_pct(res$stages, "consideration", "IPK"), 0.6,
               tolerance = 1e-9)
})


# ==============================================================================
# Back-compatibility: a config that still carries raw codes
# ==============================================================================

test_that("Raw codes are resolved through the same path, not matched literally", {
  # This is the exact call that used to return zero: codes 1, 2 and 4 against
  # a category whose attitude columns hold labels.
  res <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                    .cr_brands(),
                    .cr_cfg(`funnel.positive_attitude_codes` =
                              c("1", "2", "4")))
  expect_equal(.cr_pct(res$stages, "consideration", "IPK"), 0.6,
               tolerance = 1e-9)
  expect_equal(res$meta$consideration$source, "codes")
  expect_setequal(res$meta$consideration$roles_used,
                  c("attitude.love", "attitude.prefer", "attitude.price"))
  expect_true(any(grepl("deprecated", res$meta$consideration$notes)))
})


test_that("Raw codes and the equivalent roles give identical stages", {
  by_code <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                        .cr_brands(),
                        .cr_cfg(`funnel.positive_attitude_codes` =
                                  c("1", "2", "4")))
  by_role <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                        .cr_brands(),
                        .cr_cfg(`funnel.consideration_roles` =
                                  c("love", "prefer", "price")))
  expect_equal(by_code$stages$pct_weighted, by_role$stages$pct_weighted)
})


test_that("A code on no position of the scale is matched literally and reported", {
  res <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                    .cr_brands(),
                    .cr_cfg(`funnel.positive_attitude_codes` =
                              c("1", "2", "99")))
  expect_equal(.cr_pct(res$stages, "consideration", "IPK"), 0.4,
               tolerance = 1e-9)
  expect_true(any(grepl("match no position",
                        res$meta$consideration$notes)))
})


# ==============================================================================
# Refusals replace the silent empty stage
# ==============================================================================

test_that("A named role the scale does not carry refuses", {
  expect_error(
    run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_5()),
               .cr_brands(),
               .cr_cfg(`funnel.consideration_roles` =
                         c("love", "prefer", "price"))),
    "CONSIDERATION_ROLE_ABSENT")
})


test_that("An unrecognised role name refuses", {
  expect_error(
    run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
               .cr_brands(),
               .cr_cfg(`funnel.consideration_roles` = c("love", "enthusiasm"))),
    "CONSIDERATION_ROLE_UNKNOWN")
})


test_that("Neither refusal fires for the built-in default set", {
  res5 <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_5()),
                     .cr_brands(), .cr_cfg())
  expect_true(res5$status %in% c("PASS", "PARTIAL"))
  expect_false("attitude.price" %in% res5$meta$consideration$roles_used)
})


# ==============================================================================
# The Turas standard consideration set
# ==============================================================================

test_that("The default set is Love, Prefer and Price-conditional", {
  expect_equal(.FUNNEL_CONSIDERATION_ROLES,
               c("attitude.love", "attitude.prefer", "attitude.price"))
})


test_that("On a six-level scale the default admits the price-conditional", {
  res <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                    .cr_brands(), .cr_cfg())
  # Love 2 + Prefer 2 + Price only 2 of 10 for IPK.
  expect_equal(.cr_pct(res$stages, "consideration", "IPK"), 0.6,
               tolerance = 1e-9)
  expect_equal(res$meta$consideration$roles_used,
               c("attitude.love", "attitude.prefer", "attitude.price"))
  expect_length(res$meta$consideration$roles_dropped, 0L)
})


test_that("The price-conditional respondents are what the new default adds", {
  new_default <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                            .cr_brands(), .cr_cfg())
  old_top2 <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                         .cr_brands(),
                         .cr_cfg(`funnel.consideration_roles` =
                                   c("love", "prefer")))
  expect_equal(.cr_pct(old_top2$stages, "consideration", "IPK"), 0.4,
               tolerance = 1e-9)
  expect_equal(.cr_pct(new_default$stages, "consideration", "IPK"), 0.6,
               tolerance = 1e-9)
})


test_that("The ambivalent respondents stay out of the default set", {
  res <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                    .cr_brands(), .cr_cfg())
  with_ambiv <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_6()),
                           .cr_brands(),
                           .cr_cfg(`funnel.consideration_roles` =
                                     c("love", "prefer", "price",
                                       "ambivalent")))
  # IPK has two ambivalent respondents, and they are not in the default set.
  expect_equal(.cr_pct(with_ambiv$stages, "consideration", "IPK") -
                 .cr_pct(res$stages, "consideration", "IPK"),
               0.2, tolerance = 1e-9)
})


test_that("A five-level scale drops the price level and reports it", {
  res <- run_funnel(.cr_data("labels"), .cr_role_map(.cr_optionmap_5()),
                    .cr_brands(), .cr_cfg())
  expect_equal(res$meta$consideration$roles_used,
               c("attitude.love", "attitude.prefer"))
  expect_equal(res$meta$consideration$roles_dropped, "attitude.price")
  expect_true(any(grepl("carries no price level",
                        res$meta$consideration$notes)))
  # A dropped default role is an operator note, not a degraded run.
  expect_false(any(grepl("price", res$warnings %||% character(0))))
})


test_that("The Consider stage is labelled Consider, not Prefer", {
  expect_equal(.FUNNEL_DEFAULT_LABELS$consideration, "Consider")
})


test_that("The three stage-label tables still agree with one another", {
  # 03c_funnel_panel_data.R and 03d_funnel_output.R each carry their own copy
  # of the label table, both commented "must mirror .FUNNEL_DEFAULT_LABELS".
  # They did not, which is how the report kept saying Prefer after the
  # default changed. This holds them together.
  source(file.path(ROOT, "modules", "brand", "R", "03c_funnel_panel_data.R"),
         local = TRUE)
  source(file.path(ROOT, "modules", "brand", "R", "03d_funnel_output.R"),
         local = TRUE)
  for (k in names(.FUNNEL_DEFAULT_LABELS)) {
    expect_equal(.stage_label(k), .FUNNEL_DEFAULT_LABELS[[k]], info = k)
    expect_equal(.stage_label_export(k), .FUNNEL_DEFAULT_LABELS[[k]], info = k)
  }
})

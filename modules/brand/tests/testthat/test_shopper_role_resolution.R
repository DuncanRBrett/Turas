# ==============================================================================
# Tests for resolve_shopper_role_columns()
# ==============================================================================
# Confirms the role-resolution helper correctly walks from a QuestionMap row
# to a parallel cols / codes / labels triple, expanding {channelcode} or
# {packsizecode} against the matching code-list sheet.
# ==============================================================================

source("../../R/08e_shopper_behaviour.R", chdir = FALSE)


build_structure <- function() {
  list(
    questionmap = data.frame(
      Role           = c("channel.purchase.DSS", "cat_buying.packsize.DSS",
                          "channel.purchase.LEGACY"),
      ClientCode     = c("CHANNEL_DSS", "PACKSIZE_DSS", "CHANNEL_LEGACY"),
      Variable_Type  = rep("Multi_Mention", 3),
      ColumnPattern  = c("{code}_{channelcode}", "{code}_{packsizecode}",
                          "{code}"),
      OptionMapScale = c("", "packsize_scale", ""),
      stringsAsFactors = FALSE
    ),
    channels = data.frame(
      ChannelCode  = c("SUPMKT", "ONLINE", "OTHER"),
      ChannelLabel = c("Supermarket", "Online", "Somewhere else"),
      DisplayOrder = c(1, 3, 2),  # deliberately out of order to test sort
      stringsAsFactors = FALSE
    ),
    packsizes = data.frame(
      PackSizeCode  = c("SMALL", "MEDIUM", "LARGE"),
      PackSizeLabel = c("Small (<200g)", "Medium (200-500g)", "Large (>500g)"),
      DisplayOrder  = c(1, 2, 3),
      stringsAsFactors = FALSE
    )
  )
}


test_that("resolves channel.purchase.{CAT} to one column per channel", {
  s <- build_structure()
  spec <- resolve_shopper_role_columns(s, "channel.purchase.DSS", "location")
  # DisplayOrder sorts SUPMKT (1), OTHER (2), ONLINE (3).
  expect_equal(spec$codes,  c("SUPMKT", "OTHER", "ONLINE"))
  expect_equal(spec$labels, c("Supermarket", "Somewhere else", "Online"))
  expect_equal(spec$cols,
               c("CHANNEL_DSS_SUPMKT", "CHANNEL_DSS_OTHER", "CHANNEL_DSS_ONLINE"))
})

test_that("resolves cat_buying.packsize.{CAT} to one column per pack size", {
  s <- build_structure()
  spec <- resolve_shopper_role_columns(s, "cat_buying.packsize.DSS", "packsize")
  expect_equal(spec$codes,  c("SMALL", "MEDIUM", "LARGE"))
  expect_equal(spec$labels,
               c("Small (<200g)", "Medium (200-500g)", "Large (>500g)"))
  expect_equal(spec$cols,
               c("PACKSIZE_DSS_SMALL", "PACKSIZE_DSS_MEDIUM", "PACKSIZE_DSS_LARGE"))
})

test_that("legacy {code} pattern (no expansion token) returns single column", {
  s <- build_structure()
  spec <- resolve_shopper_role_columns(s, "channel.purchase.LEGACY", "location")
  expect_equal(spec$cols,   "CHANNEL_LEGACY")
  expect_equal(spec$codes,  "CHANNEL_LEGACY")
  expect_equal(spec$labels, "CHANNEL_LEGACY")
})

test_that("absent role returns NULL (silent skip)", {
  s <- build_structure()
  expect_null(resolve_shopper_role_columns(s, "channel.purchase.DOES_NOT_EXIST",
                                            "location"))
})

test_that("absent code-list sheet returns NULL even when role is present", {
  s <- build_structure()
  s$packsizes <- NULL
  expect_null(resolve_shopper_role_columns(s, "cat_buying.packsize.DSS",
                                            "packsize"))
})

test_that("unknown kind returns NULL rather than crashing", {
  s <- build_structure()
  expect_null(resolve_shopper_role_columns(s, "channel.purchase.DSS",
                                            "totally_unknown"))
})

test_that("underscore variant {channel_code} resolves identically", {
  s <- build_structure()
  s$questionmap$ColumnPattern[1] <- "{code}_{channel_code}"
  spec <- resolve_shopper_role_columns(s, "channel.purchase.DSS", "location")
  expect_equal(spec$cols[1], "CHANNEL_DSS_SUPMKT")
})

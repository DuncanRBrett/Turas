# test-vas_channel_recode.R
# The channel-recode tool's decision logic, network-free. The API driver is
# main(), guarded by sys.nframe(), so sourcing the tool runs nothing.

source(file.path(VAS_PROJECT_ROOT, "tools", "vas_channel_reporting_recode.R"))

test_that("strip_title cleans HTML, entities, non-breaking spaces and whitespace", {
  expect_equal(strip_title("<b>Bank:&nbsp;ATM</b>"), "Bank: ATM")
  expect_equal(strip_title("Bank: ATM"), "Bank: ATM")
  expect_equal(strip_title("  Spaza   shop / kiosk  "), "Spaza shop / kiosk")
  # the API hands options back as one-element lists
  expect_equal(strip_title(list("Bank: ATM")), "Bank: ATM")
  expect_equal(strip_title(NULL), "")
})

test_that("a mapped channel title gets its reporting code", {
  decision <- recode_target("Bank: ATM")
  expect_true(decision$mapped)
  expect_equal(decision$target, "Bank ATM")
  # matching is case-insensitive and survives markup
  expect_equal(recode_target("<i>BANK: atm</i>")$target, "Bank ATM")
})

test_that("the short-distance-bus abbreviated wording lands on the same codes", {
  expect_equal(recode_target("Retail : till points using a card")$target,
               "Retailer tillpoint card")
  expect_equal(recode_target("Spaza shop / kiosks")$target, "Spaza Shop / Kiosk")
})

test_that("an unmapped option keeps its own cleaned label", {
  decision <- recode_target("  CashSend&nbsp;wallet ")
  expect_false(decision$mapped)
  expect_equal(decision$target, "CashSend wallet")
})

# ==============================================================================
# TABS MODULE. QUALITATIVE HOST-SOURCED TAG TESTS (Feature 2)
# ==============================================================================
#
# Known-answer tests for host-survey demographic tagging: parsing qual_tag_dimensions,
# attaching a host column's value to each comment via the join, and. The disclosure
# crux. Band-aware k-anonymisation (a tag safe overall but unique within a small band
# is suppressed within that band).
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_host_tags.R")
# ==============================================================================

library(testthat)

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(getwd(), file.path(getwd(), "../.."),
                  file.path(getwd(), "../../.."), file.path(getwd(), "../../../.."))
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) return(resolved)
  }
  stop("Could not locate Turas root")
}

.root <- detect_turas_root()
source(file.path(.root, "modules/tabs/lib/qual_assemble.R"))        # parse_tag_dims, attach, sort
source(file.path(.root, "modules/tabs/lib/qual_island_builder.R"))  # kanon_by_group, build_data_qual
source(file.path(.root, "modules/tabs/lib/microdata_writer.R"))     # micro_display_map (tag labels)

# ---- qual_parse_tag_dims -----------------------------------------------------

test_that("tag-dimension config parses Column and Column:Label forms", {
  d <- qual_parse_tag_dims("S03:Centre, S11:Channel")
  expect_equal(length(d), 2L)
  expect_equal(d[[1]]$col, "S03"); expect_equal(d[[1]]$label, "Centre")
  expect_equal(d[[2]]$label, "Channel")

  bare <- qual_parse_tag_dims("S03")
  expect_equal(bare[[1]]$col, "S03"); expect_equal(bare[[1]]$label, "S03")

  expect_equal(length(qual_parse_tag_dims("")), 0L)
  expect_equal(length(qual_parse_tag_dims(NA)), 0L)
  expect_equal(length(qual_parse_tag_dims("NA")), 0L)
})

# ---- qual_attach_host_tags ---------------------------------------------------

mk_q <- function(...) list(records = list(...))
mk_r <- function(id) list(id = id, demos = list())

test_that("a host column is stamped onto each comment + registered as a banner dim", {
  qs <- list(mk_q(mk_r("54"), mk_r("11")))
  master <- list(id_to_idx = stats::setNames(c(0L, 1L), c("54", "11")), banner_dims = list())
  survey <- data.frame(S03 = c("Worcester DC", "Paarl DC"), stringsAsFactors = FALSE)  # row1=id54, row2=id11

  res <- qual_attach_host_tags(qs, master, list(list(col = "S03", label = "Centre")), survey)
  expect_equal(res$questions[[1]]$records[[1]]$demos$Centre, "Worcester DC")
  expect_equal(res$questions[[1]]$records[[2]]$demos$Centre, "Paarl DC")
  labs <- vapply(res$master$banner_dims, function(d) d$label, character(1))
  expect_true("Centre" %in% labs)
})

test_that("an unmatched respondent gets NA, and a missing/dup dimension is skipped", {
  qs <- list(mk_q(mk_r("54"), mk_r("999")))  # 999 not in the join map
  master <- list(id_to_idx = stats::setNames(0L, "54"),
                 banner_dims = list(list(label = "Centre", values = "x")))
  survey <- data.frame(S03 = "Worcester DC", stringsAsFactors = FALSE)

  # missing host column -> skipped, no tag added
  miss <- suppressWarnings(qual_attach_host_tags(qs, master, list(list(col = "NOPE", label = "Zone")), survey))
  expect_null(miss$questions[[1]]$records[[1]]$demos$Zone)

  # duplicate label (Centre already a banner dim) -> skipped
  dup <- suppressWarnings(qual_attach_host_tags(qs, master, list(list(col = "S03", label = "Centre")), survey))
  labs <- vapply(dup$master$banner_dims, function(d) d$label, character(1))
  expect_equal(sum(labs == "Centre"), 1L)  # not duplicated

  # unmatched respondent -> NA tag
  ok <- suppressWarnings(qual_attach_host_tags(qs, list(id_to_idx = stats::setNames(0L, "54"), banner_dims = list()),
                             list(list(col = "S03", label = "Centre")), survey))
  expect_true(is.na(ok$questions[[1]]$records[[2]]$demos$Centre))
})

# ---- host tag values resolve to their structure display labels ---------------

# A coded host column (the CCPB channel case: data holds "11"/"12", the structure
# carries the words) must tag readably, or the chip reads "Channel: 11".
mk_struct <- function(...) {
  list(options = do.call(rbind, list(...)))
}
mk_opt <- function(code, option_text, display_text) {
  data.frame(QuestionCode = code, OptionText = option_text, DisplayText = display_text,
             stringsAsFactors = FALSE)
}

test_that("a coded host column tags with its DisplayText, not the raw code", {
  qs <- list(mk_q(mk_r("54"), mk_r("11")))
  master <- list(id_to_idx = stats::setNames(c(0L, 1L), c("54", "11")), banner_dims = list())
  survey <- data.frame(S09 = c("11", "12"), stringsAsFactors = FALSE)
  struct <- mk_struct(mk_opt("S09", "11", "11 - Spaza"),
                      mk_opt("S09", "12", "12 - Supermarket"))

  res <- qual_attach_host_tags(qs, master, list(list(col = "S09", label = "Channel")),
                               survey, struct)
  expect_equal(res$questions[[1]]$records[[1]]$demos$Channel, "11 - Spaza")
  expect_equal(res$questions[[1]]$records[[2]]$demos$Channel, "12 - Supermarket")
  # the banner dimension carries the labels too, so the cut picker matches the chips
  dim <- Filter(function(d) identical(d$label, "Channel"), res$master$banner_dims)[[1]]
  expect_equal(sort(dim$values), c("11 - Spaza", "12 - Supermarket"))
})

test_that("structure OptionText matches the data value trimmed, as the processors do", {
  # CCPB's structure carries trailing spaces ("Presell ") the data does not.
  qs <- list(mk_q(mk_r("54")))
  master <- list(id_to_idx = stats::setNames(0L, "54"), banner_dims = list())
  survey <- data.frame(S11 = "Presell", stringsAsFactors = FALSE)
  struct <- mk_struct(mk_opt("S11", "Presell ", "Presell"))

  res <- qual_attach_host_tags(qs, master, list(list(col = "S11", label = "Sales Method")),
                               survey, struct)
  expect_equal(res$questions[[1]]$records[[1]]$demos[["Sales Method"]], "Presell")
})

test_that("a value with no option is tagged raw and reported, never dropped", {
  # CCPB's S09 holds '06A', which the structure does not declare.
  qs <- list(mk_q(mk_r("54"), mk_r("11")))
  master <- list(id_to_idx = stats::setNames(c(0L, 1L), c("54", "11")), banner_dims = list())
  survey <- data.frame(S09 = c("06A", "11"), stringsAsFactors = FALSE)
  struct <- mk_struct(mk_opt("S09", "11", "11 - Spaza"))

  expect_output(
    res <- qual_attach_host_tags(qs, master, list(list(col = "S09", label = "Channel")),
                                 survey, struct),
    "06A")
  expect_equal(res$questions[[1]]$records[[1]]$demos$Channel, "06A")   # kept, not dropped
  expect_equal(res$questions[[1]]$records[[2]]$demos$Channel, "11 - Spaza")
})

test_that("no structure, or a column absent from it, leaves the raw values alone", {
  qs <- list(mk_q(mk_r("54")))
  master <- list(id_to_idx = stats::setNames(0L, "54"), banner_dims = list())
  survey <- data.frame(S03 = "Worcester DC", stringsAsFactors = FALSE)
  dims <- list(list(col = "S03", label = "Plant"))

  bare <- qual_attach_host_tags(qs, master, dims, survey)                      # no structure
  expect_equal(bare$questions[[1]]$records[[1]]$demos$Plant, "Worcester DC")

  other <- qual_attach_host_tags(qs, master, dims, survey,
                                 mk_struct(mk_opt("S09", "11", "11 - Spaza")))  # S03 not in it
  expect_equal(other$questions[[1]]$records[[1]]$demos$Plant, "Worcester DC")
})

test_that("an NA host value stays NA and is not reported as unmapped", {
  qs <- list(mk_q(mk_r("54")))
  master <- list(id_to_idx = stats::setNames(0L, "54"), banner_dims = list())
  survey <- data.frame(S09 = NA_character_, stringsAsFactors = FALSE)
  struct <- mk_struct(mk_opt("S09", "11", "11 - Spaza"))

  expect_silent(res <- qual_attach_host_tags(qs, master,
                                             list(list(col = "S09", label = "Channel")),
                                             survey, struct))
  expect_true(is.na(res$questions[[1]]$records[[1]]$demos$Channel))
})

# ---- qual_kanon_tags_by_group (the disclosure crux) --------------------------

test_that("a tag is suppressed within a small band but survives within a large one", {
  # 3 detractors + 6 promoters, ALL 'Worcester'. With k=5, Worcester matches only 3 within
  # the detractor band (suppressed) but 6 within the promoter band (survives).
  ids <- c(paste0("d", 1:3), paste0("p", 1:6))
  bands <- c(rep("Detractor", 3), rep("Promoter", 6))
  rows <- lapply(seq_along(ids), function(i) list(Centre = "Worcester"))
  km <- qual_kanon_tags_by_group(rows, ids, bands, "Centre", 5)

  expect_true(is.na(km[["d1"]]$Centre))     # suppressed: only 3 detractors share it (<5)
  expect_equal(km[["p1"]]$Centre, "Worcester")  # survives: 6 promoters share it (>=5)
})

test_that("with a single band the grouped k-anon equals the ungrouped one", {
  ids <- paste0("r", 1:6); bands <- rep("", 6)
  rows <- lapply(seq_along(ids), function(i) list(Centre = "Worcester"))
  grouped <- qual_kanon_tags_by_group(rows, ids, bands, "Centre", 5)
  flat <- stats::setNames(qual_kanon_tags(rows, "Centre", 5), ids)
  expect_equal(grouped, flat)
})

# ---- End-to-end: safe mode honours the band-aware suppression ----------------

test_that("qual_build_data_qual (safe) suppresses a small-band tag end to end", {
  mk_hrec <- function(id, band, centre) {
    list(id = id, text = "x", noteworthy = FALSE, noteworthy_tier = 0L, noteworthy_marker = "",
         sentiment = NA_integer_, rating = NA_real_, themeVals = list(), band = band,
         demos = list(Centre = centre))
  }
  recs <- c(lapply(1:3, function(i) mk_hrec(paste0("d", i), "Detractor", "Worcester")),
            lapply(1:6, function(i) mk_hrec(paste0("p", i), "Promoter", "Worcester")))
  q <- list(code = "QUAL_Q79", title = "Why", type = "raw", sheet = "QUAL_Q79",
            roles = list(themes = list()), records = recs,
            split = list(dim = "NPS band", bands = list("Detractor", "Promoter")),
            meta = list(dropped_codes = 0L, n_records = length(recs)))
  master <- list(n = 9, id_to_idx = stats::setNames(0:8, c(paste0("d", 1:3), paste0("p", 1:6))),
                 banner_dims = list(list(label = "Centre", values = "Worcester")))

  island <- qual_build_data_qual(list(q), master,
    list(text_mode = "full", demographic_cuts = "safe", min_reporting_base = 5))
  recs_out <- island$questions[[1]]$records
  demo_of <- function(band) {
    for (r in recs_out) if (identical(r$band, band)) return(r$demos$Centre)
    NULL
  }
  expect_true(is.na(demo_of("Detractor")))       # small band -> tag withheld from the source
  expect_equal(demo_of("Promoter"), "Worcester") # large band -> tag shown
  expect_equal(island$questions[[1]]$split$dim, "NPS band")
})

# ---- The CUT: a live filter reaching the comments on an aggregate build ------
# Each comment carries which level of each DECLARED variable its author falls
# in, using the aggregate cube's own level indices, so nothing has to be matched
# by label. It is demographic information about a person, so it obeys the same
# dial and the same k-anonymiser the tags do.

mk_cut_case <- function(cuts, k = 5, n_big = 8, n_small = 2) {
  mk <- function(id) {
    list(id = id, text = "x", noteworthy = FALSE, noteworthy_tier = 0L,
         noteworthy_marker = "", sentiment = NA_integer_, rating = NA_real_,
         themeVals = list(), demos = list())
  }
  ids <- c(paste0("b", seq_len(n_big)), paste0("s", seq_len(n_small)))
  recs <- lapply(ids, mk)
  q <- list(code = "QUAL_Q1", title = "Why", type = "raw", sheet = "QUAL_Q1",
            roles = list(themes = list()), records = recs,
            meta = list(dropped_codes = 0L, n_records = length(recs)))
  master <- list(n = length(ids),
                 id_to_idx = stats::setNames(seq_along(ids) - 1L, ids),
                 banner_dims = list())
  # Region: everyone on level 1. Segment: the big group on 1, a group of two on 9.
  cut_levels <- list(
    Region = rep(1L, length(ids)),
    Segment = c(rep(1L, n_big), rep(9L, n_small))
  )
  island <- qual_build_data_qual(list(q), master,
    list(text_mode = "full", demographic_cuts = cuts, min_reporting_base = k),
    cut_levels = cut_levels)
  list(island = island, records = island$questions[[1]]$records, ids = ids)
}

test_that("every comment carries the cut its author falls in", {
  case <- mk_cut_case("allow")
  expect_equal(unlist(case$island$cutVars), c("Region", "Segment"))
  for (r in case$records) {
    expect_equal(r$cut$Region, 1L)
    expect_true(r$cut$Segment %in% c(1L, 9L))
  }
})

test_that("safe mode drops a cut that would name a group below k", {
  case <- mk_cut_case("safe", k = 5)
  segs <- vapply(case$records, function(r) {
    v <- r$cut$Segment
    if (is.null(v)) NA_integer_ else as.integer(v)
  }, integer(1))
  # The eight in Segment 1 keep it; the two in Segment 9 do not, because naming
  # that group would name two people. Region survives for everyone: ten share it.
  expect_equal(sum(segs == 1L, na.rm = TRUE), 8)
  expect_equal(sum(is.na(segs)), 2)
  for (r in case$records) expect_equal(r$cut$Region, 1L)
})

test_that("block ships no cut at all, so the comments follow no filter", {
  case <- mk_cut_case("block")
  expect_null(case$island$cutVars)
  for (r in case$records) expect_null(r$cut)
})

test_that("no cut levels supplied leaves the island exactly as it was", {
  mk <- function(id) list(id = id, text = "x", noteworthy = FALSE, noteworthy_tier = 0L,
                          noteworthy_marker = "", sentiment = NA_integer_, rating = NA_real_,
                          themeVals = list(), demos = list())
  recs <- lapply(c("a", "b"), mk)
  q <- list(code = "QUAL_Q1", title = "Why", type = "raw", sheet = "QUAL_Q1",
            roles = list(themes = list()), records = recs,
            meta = list(dropped_codes = 0L, n_records = 2L))
  master <- list(n = 2, id_to_idx = stats::setNames(0:1, c("a", "b")), banner_dims = list())
  island <- qual_build_data_qual(list(q), master,
    list(text_mode = "full", demographic_cuts = "allow", min_reporting_base = 5))
  expect_null(island$cutVars)
  for (r in island$questions[[1]]$records) expect_null(r$cut)
})

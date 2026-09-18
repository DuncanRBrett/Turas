# ==============================================================================
# MAXDIFF TESTS - THE SEAM BETWEEN THE ISLAND AND THE TAB
# ==============================================================================
#
# test_v2_island.R proves the R side writes the right shape. The node gates in
# modules/tabs/tests/js prove the JS side renders a hand-built island. Neither
# proves the two agree: every island those gates read was written in
# JavaScript, by hand, by whoever wrote the gate.
#
# So this test writes a real island with 13_v2_island.R, feeds that exact file
# to the SHIPPED tab JS through modules/tabs/tests/js/render_maxdiff_island.mjs,
# and asserts on the HTML that came back. A field the R renames, or a scalar
# that unboxes into a one-element array, fails here and nowhere else.
#
# Skipped when node is not on PATH, the same way the pricing view gate is.
# ==============================================================================

.seam_island_file <- function(out_dir) {
  set.seed(11)
  n <- 40
  td <- generate_test_data(n_resp = n, n_items = 6, n_tasks = 6, items_per_task = 3)
  items <- td$items
  ids <- items$Item_ID

  counts <- data.frame(
    Item_ID = ids, Item_Label = items$Item_Label, Item_Group = items$Item_Group,
    Times_Shown = 60, Times_Best = c(30, 20, 15, 10, 5, 3),
    Times_Worst = c(2, 4, 8, 12, 20, 30),
    Best_Pct = c(50, 33.3, 25, 16.7, 8.3, 5),
    Worst_Pct = c(3.3, 6.7, 13.3, 20, 33.3, 50),
    Net_Score = c(46.7, 26.7, 11.7, -3.3, -25, -45),
    BW_Score = c(.47, .27, .12, -.03, -.25, -.45),
    Rank = 1:6, stringsAsFactors = FALSE
  )
  indiv <- cbind(resp_id = sprintf("R%03d", seq_len(n)),
                 as.data.frame(td$individual_utils), stringsAsFactors = FALSE)
  hb <- list(
    population_utilities = data.frame(
      Item_ID = ids, HB_Utility_Mean = colMeans(td$individual_utils),
      HB_Utility_SD = apply(td$individual_utils, 2, sd), stringsAsFactors = FALSE),
    individual_utilities = indiv,
    diagnostics = list(method = "empirical_bayes"),
    model_fit = list(method = "empirical_bayes_shrinkage")
  )

  # One segment variable with two levels, the second deliberately under the
  # configured minimum so the tab has something to flag.
  seg_levels <- c("18-34", "35+")
  seg_scores <- do.call(rbind, lapply(seq_along(seg_levels), function(k) {
    d <- counts
    d$Segment_ID <- "S1"
    d$Segment_Label <- "Age"
    d$Segment_Value <- seg_levels[k]
    d$Segment_N <- c(180L, 22L)[k]
    d$Net_Score <- d$Net_Score + k * 3
    d
  }))

  os <- get_default_output_settings()
  os$Generate_HTML_Report <- FALSE
  os$Min_Respondents_Per_Segment <- 50
  config <- list(
    project_settings = list(Project_Name = "SeamCheck"),
    items = items, output_settings = os,
    segment_settings = data.frame(
      Segment_ID = "S1", Segment_Label = "Age", Variable_Name = "AgeBand",
      stringsAsFactors = FALSE)
  )
  results <- list(
    count_scores = counts,
    logit_results = list(
      utilities = data.frame(Item_ID = ids,
        Logit_Utility = c(1.5, 1.0, .5, .2, -.4, 0), stringsAsFactors = FALSE),
      model_fit = list(log_likelihood = -120.4, aic = 250.8, bic = 268.1,
                       mcfadden_r2 = 0.287)),
    hb_results = hb,
    segment_results = list(segment_scores = seg_scores, segment_summary = NULL),
    study_summary = list(n_respondents = n, n_tasks = 6, n_items = 6,
                         weighted = FALSE),
    output_path = file.path(out_dir, "Seam.xlsx")
  )
  write_maxdiff_island(results, config, verbose = FALSE)$output_file
}

.seam_render <- function(island_file) {
  node <- unname(Sys.which("node"))
  if (!nzchar(node)) return(NULL)
  root <- .md_test_repo_root()
  renderer <- file.path(root, "modules", "tabs", "tests", "js",
                        "render_maxdiff_island.mjs")
  if (!file.exists(renderer)) return(NA_character_)
  out <- suppressWarnings(system2(
    node, c(shQuote(renderer), shQuote(island_file)),
    stdout = TRUE, stderr = TRUE))
  paste(out, collapse = "\n")
}

# The tests live in modules/maxdiff/tests/testthat; the repo root is four up.
.md_test_repo_root <- function() {
  d <- normalizePath(".", mustWork = FALSE)
  for (i in 1:8) {
    if (file.exists(file.path(d, "modules", "tabs", "tests", "js"))) return(d)
    d <- dirname(d)
  }
  NULL
}

test_that("the shipped tab JS renders the island the R module writes", {
  skip_if(!nzchar(unname(Sys.which("node"))), "node not on PATH")
  skip_if(is.null(.md_test_repo_root()), "repo root not found from the test cwd")

  out_dir <- file.path(tempdir(), paste0("md_seam_", as.integer(runif(1) * 1e6)))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  island <- .seam_island_file(out_dir)
  expect_true(file.exists(island))
  html <- .seam_render(island)
  skip_if(is.null(html) || identical(html, NA_character_), "renderer unavailable")

  # Every panel the four new blocks feed.
  for (panel in c("Model diagnostics", "Head-to-head win rates",
                  "Scores by segment", "Utility distributions", "Item strategy")) {
    expect_true(grepl(panel, html, fixed = TRUE), info = panel)
  }

  # The numbers crossed the language boundary intact.
  expect_true(grepl("-120.4", html, fixed = TRUE))   # log-likelihood
  expect_true(grepl("250.8", html, fixed = TRUE))    # AIC
  expect_true(grepl("268.1", html, fixed = TRUE))    # BIC
  expect_true(grepl("0.287", html, fixed = TRUE))    # pseudo R-squared
  expect_true(grepl("18-34", html, fixed = TRUE))
  expect_true(grepl("n = 22", html, fixed = TRUE))   # the thin level's base
  expect_match(html, "small base", ignore.case = TRUE)

  # Six items in, six shapes and a six-row matrix out.
  expect_equal(lengths(regmatches(html, gregexpr('class="md-violin"', html)))[1], 6L)
  h2h <- regmatches(html, regexpr("Head-to-head[^￿]*?</section>", html))
  expect_equal(lengths(regmatches(h2h, gregexpr("<tr>", h2h)))[1], 7L)

  # The failure modes that only show up at the seam.
  expect_false(grepl("NaN", html, fixed = TRUE))
  expect_false(grepl("undefined", html, fixed = TRUE))
  expect_false(grepl("[object", html, fixed = TRUE))
})

test_that("a counts-only run renders without the four new panels", {
  skip_if(!nzchar(unname(Sys.which("node"))), "node not on PATH")
  skip_if(is.null(.md_test_repo_root()), "repo root not found from the test cwd")

  out_dir <- file.path(tempdir(), paste0("md_seam_", as.integer(runif(1) * 1e6)))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  # Built here rather than borrowed from test_v2_island.R: testthat gives each
  # file its own scope, so a helper defined there is not visible from here.
  td <- generate_test_data(n_resp = 20, n_items = 6, n_tasks = 6, items_per_task = 3)
  items <- td$items
  counts <- data.frame(
    Item_ID = items$Item_ID, Item_Label = items$Item_Label,
    Times_Shown = 60, Times_Best = c(30, 20, 15, 10, 5, 3),
    Times_Worst = c(2, 4, 8, 12, 20, 30),
    Best_Pct = c(50, 33.3, 25, 16.7, 8.3, 5),
    Worst_Pct = c(3.3, 6.7, 13.3, 20, 33.3, 50),
    Net_Score = c(46.7, 26.7, 11.7, -3.3, -25, -45),
    Rank = 1:6, stringsAsFactors = FALSE)
  os <- get_default_output_settings()
  os$Generate_HTML_Report <- FALSE
  bare <- list(
    results = list(count_scores = counts, logit_results = NULL, hb_results = NULL,
                   study_summary = list(n_respondents = 20, n_tasks = 6, n_items = 6,
                                        weighted = FALSE),
                   output_path = file.path(out_dir, "Bare.xlsx")),
    config = list(project_settings = list(Project_Name = "Bare"),
                  items = items, output_settings = os))
  island <- write_maxdiff_island(bare$results, bare$config, verbose = FALSE)$output_file
  html <- .seam_render(island)
  skip_if(is.null(html) || identical(html, NA_character_), "renderer unavailable")

  # Absent blocks must produce absent panels, not empty ones. An empty object
  # is truthy in JavaScript, which is how a panel of dashes gets shipped.
  for (panel in c("Model diagnostics", "Head-to-head win rates",
                  "Scores by segment", "Utility distributions", "Item strategy")) {
    expect_false(grepl(panel, html, fixed = TRUE), info = panel)
  }
  # The scores table is still there: a counts-only run is a real result.
  expect_true(grepl("md-table", html, fixed = TRUE))
})

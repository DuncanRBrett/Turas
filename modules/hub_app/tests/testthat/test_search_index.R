# ==============================================================================
# Tests: Hub App Search Index
# ==============================================================================

turas_root <- Sys.getenv("TURAS_ROOT", getwd())
source(file.path(turas_root, "modules", "hub_app", "lib", "search_index.R"))
source(file.path(turas_root, "modules", "hub_app", "lib", "project_scanner.R"))
source(file.path(turas_root, "modules", "hub_app", "tests", "fixtures",
                  "synthetic_data", "generate_test_data.R"))

# ==============================================================================
# build_search_index()
# ==============================================================================

test_that("build_search_index returns PASS with empty index for no projects", {
  result <- build_search_index(list())
  expect_equal(result$status, "PASS")
  expect_equal(result$result$item_count, 0)
  expect_equal(length(result$result$index), 0)
})

test_that("build_search_index returns PASS for NULL input", {
  result <- build_search_index(NULL)
  expect_equal(result$status, "PASS")
  expect_equal(result$result$item_count, 0)
})

test_that("build_search_index indexes report metadata from projects", {
  root <- file.path(tempdir(), "search_idx_reports")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  create_mock_project(root, "Alpha", c("tabs", "tracker"))

  scan_result <- scan_for_projects(root, max_depth = 2)
  projects <- scan_result$result$projects

  result <- build_search_index(projects)
  expect_equal(result$status, "PASS")
  expect_equal(result$result$project_count, 1)
  # Should have at least 2 report entries
  expect_gte(result$result$item_count, 2)

  # Check that report types are indexed
  types <- sapply(result$result$index, function(i) i$type)
  expect_true("report" %in% types)
})

test_that("build_search_index indexes pins from sidecar files", {
  root <- file.path(tempdir(), "search_idx_pins")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  create_mock_project(root, "PinnedProject", "tabs", add_pins = TRUE)

  scan_result <- scan_for_projects(root, max_depth = 2)
  projects <- scan_result$result$projects

  result <- build_search_index(projects)
  expect_equal(result$status, "PASS")

  # Should have report entries + pin entries + section entries
  types <- sapply(result$result$index, function(i) i$type)
  expect_true("pin" %in% types)
  expect_true("section" %in% types)

  # Find the pin entry and verify content
  pin_entries <- Filter(function(i) i$type == "pin", result$result$index)
  expect_gte(length(pin_entries), 1)
  expect_equal(pin_entries[[1]]$title, "Test Pin - Q01 Overall Satisfaction")
})

test_that("build_search_index indexes annotations from sidecar files", {
  root <- file.path(tempdir(), "search_idx_ann")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  proj_path <- create_mock_project(root, "AnnotatedProject", "tabs")

  # Create annotations sidecar
  ann_data <- list(
    version = 1L,
    executive_summary = "This study examines brand health trends across three segments.",
    background = "Fieldwork conducted Jan-Feb 2026, n=1500.",
    notes = ""
  )
  jsonlite::write_json(ann_data, file.path(proj_path, ".turas_annotations.json"),
                        auto_unbox = TRUE, pretty = TRUE)

  scan_result <- scan_for_projects(root, max_depth = 2)
  projects <- scan_result$result$projects

  result <- build_search_index(projects)
  expect_equal(result$status, "PASS")

  types <- sapply(result$result$index, function(i) i$type)
  expect_true("annotation" %in% types)

  ann_entries <- Filter(function(i) i$type == "annotation", result$result$index)
  expect_gte(length(ann_entries), 2)  # exec summary + background
})

test_that("build_search_index handles multiple projects", {
  root <- file.path(tempdir(), "search_idx_multi")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  create_mock_project(root, "ProjectA", c("tabs", "tracker"), add_pins = TRUE)
  create_mock_project(root, "ProjectB", c("conjoint", "maxdiff"))

  scan_result <- scan_for_projects(root, max_depth = 2)
  projects <- scan_result$result$projects

  result <- build_search_index(projects)
  expect_equal(result$status, "PASS")
  expect_equal(result$result$project_count, 2)
  expect_gte(result$result$item_count, 5)  # 4 reports + 1 pin minimum
})

# ==============================================================================
# search_index()
# ==============================================================================

test_that("search_index returns empty for null/empty query", {
  index <- list(list(type = "report", title = "Test", snippet = ""))
  expect_equal(length(search_index(index, NULL)), 0)
  expect_equal(length(search_index(index, "")), 0)
  expect_equal(length(search_index(index, "  ")), 0)
})

test_that("search_index finds matches by title", {
  index <- list(
    list(type = "report", title = "Brand Tracker", snippet = "",
         source = "tracker.html", project_name = "Study"),
    list(type = "report", title = "Crosstabs", snippet = "",
         source = "tabs.html", project_name = "Study")
  )

  results <- search_index(index, "tracker")
  expect_equal(length(results), 1)
  expect_equal(results[[1]]$title, "Brand Tracker")
  expect_equal(results[[1]]$match_field, "title")
})

test_that("search_index finds matches by snippet", {
  index <- list(
    list(type = "pin", title = "Q01", snippet = "Satisfaction dropped 5pp",
         source = "Tracker", project_name = "Study")
  )

  results <- search_index(index, "satisfaction")
  expect_equal(length(results), 1)
  expect_equal(results[[1]]$match_field, "snippet")
})

test_that("search_index finds matches by project name", {
  index <- list(
    list(type = "report", title = "Report", snippet = "",
         source = "", project_name = "Brand Health 2026")
  )

  results <- search_index(index, "brand health")
  expect_equal(length(results), 1)
  expect_equal(results[[1]]$match_field, "project")
})

test_that("search_index is case-insensitive", {
  index <- list(
    list(type = "pin", title = "MaxDiff Results", snippet = "",
         source = "", project_name = "")
  )

  results <- search_index(index, "maxdiff")
  expect_equal(length(results), 1)
})

test_that("search_index respects max_results", {
  index <- list()
  for (i in 1:20) {
    index[[i]] <- list(type = "pin", title = paste("Pin", i),
                        snippet = "matching text", source = "", project_name = "")
  }

  results <- search_index(index, "matching", max_results = 5)
  expect_equal(length(results), 5)
})

# ==============================================================================
# truncate_text()
# ==============================================================================

test_that("truncate_text handles NULL and empty", {
  expect_equal(truncate_text(NULL), "")
  expect_equal(truncate_text(""), "")
})

test_that("truncate_text preserves short text", {
  expect_equal(truncate_text("Hello world", 50), "Hello world")
})

test_that("truncate_text truncates long text with ellipsis", {
  long_text <- paste(rep("word", 50), collapse = " ")
  result <- truncate_text(long_text, 30)
  expect_equal(nchar(result), 30)
  expect_true(endsWith(result, "..."))
})

test_that("truncate_text strips markdown formatting", {
  md <- "## Heading\n**bold** and *italic*\n- bullet"
  result <- truncate_text(md, 200)
  expect_false(grepl("\\*\\*", result))
  expect_false(grepl("^##", result))
})

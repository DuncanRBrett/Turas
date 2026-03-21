# ==============================================================================
# Tests for launch_turas.R
# ==============================================================================
# Validates the module registry, icon completeness, script paths, and
# the read_module_recents() helper function.
#
# These tests verify the launcher's data-driven architecture without
# starting a Shiny app.
# ==============================================================================

library(testthat)

# Find Turas root
find_turas_root <- function() {
  current_dir <- getwd()
  while (current_dir != dirname(current_dir)) {
    if (file.exists(file.path(current_dir, "launch_turas.R"))) {
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
  }
  stop("Cannot locate Turas root")
}

turas_root <- find_turas_root()


# ==============================================================================
# Extract module registry from launch_turas.R (without starting Shiny)
# ==============================================================================

# Extract the data structures by counting all parens (not just list() calls)
launcher_env <- new.env(parent = baseenv())
launcher_lines <- readLines(file.path(turas_root, "launch_turas.R"), warn = FALSE)

# Helper: extract a block starting at a pattern by counting total parens
extract_block <- function(lines, pattern) {
  start <- grep(pattern, lines)
  if (length(start) == 0) return(NULL)
  start <- start[1]
  depth <- 0
  for (i in start:length(lines)) {
    # Count ALL open and close parens in the line
    opens <- nchar(gsub("[^(]", "", lines[i]))
    closes <- nchar(gsub("[^)]", "", lines[i]))
    depth <- depth + opens - closes
    if (depth <= 0) {
      return(trimws(lines[start:i]))
    }
  }
  NULL
}

cat_block <- extract_block(launcher_lines, "^  categories <- list\\(")
if (!is.null(cat_block)) eval(parse(text = cat_block), envir = launcher_env)

mod_block <- extract_block(launcher_lines, "^  modules <- list\\(")
if (!is.null(mod_block)) eval(parse(text = mod_block), envir = launcher_env)

icon_block <- extract_block(launcher_lines, "^  icons <- list\\(")
if (!is.null(icon_block)) eval(parse(text = icon_block), envir = launcher_env)


# ==============================================================================
# TEST: Module Registry Structure
# ==============================================================================

test_that("module registry contains all 12 modules", {
  expect_equal(length(launcher_env$modules), 12)
})

test_that("every module has required fields", {
  required_fields <- c("id", "name", "description", "category", "script", "recent_file")

  for (mod in launcher_env$modules) {
    for (field in required_fields) {
      expect_true(
        field %in% names(mod),
        info = sprintf("Module '%s' missing required field '%s'", mod$id, field)
      )
    }
  }
})

test_that("all module IDs are unique", {
  ids <- sapply(launcher_env$modules, `[[`, "id")
  expect_equal(length(ids), length(unique(ids)),
               info = "Duplicate module IDs found")
})

test_that("all module categories reference valid category IDs", {
  valid_cats <- sapply(launcher_env$categories, `[[`, "id")

  for (mod in launcher_env$modules) {
    expect_true(
      mod$category %in% valid_cats,
      info = sprintf("Module '%s' has invalid category '%s'", mod$id, mod$category)
    )
  }
})

test_that("every category has at least one module", {
  mod_cats <- sapply(launcher_env$modules, `[[`, "category")

  for (cat in launcher_env$categories) {
    expect_true(
      cat$id %in% mod_cats,
      info = sprintf("Category '%s' has no modules", cat$id)
    )
  }
})

test_that("all module names are non-empty strings", {
  for (mod in launcher_env$modules) {
    expect_true(nzchar(mod$name), info = sprintf("Module '%s' has empty name", mod$id))
    expect_true(nzchar(mod$description), info = sprintf("Module '%s' has empty description", mod$id))
  }
})


# ==============================================================================
# TEST: Script Paths Exist
# ==============================================================================

test_that("all module GUI scripts exist on disk", {
  for (mod in launcher_env$modules) {
    script_path <- file.path(turas_root, mod$script)
    expect_true(
      file.exists(script_path),
      info = sprintf("Module '%s' script not found: %s", mod$id, mod$script)
    )
  }
})

test_that("all module GUI scripts parse without error", {
  for (mod in launcher_env$modules) {
    script_path <- file.path(turas_root, mod$script)
    result <- tryCatch(parse(file = script_path), error = function(e) e)
    expect_false(
      inherits(result, "error"),
      info = sprintf("Module '%s' script has parse error: %s",
                     mod$id, if (inherits(result, "error")) result$message else "")
    )
  }
})


# ==============================================================================
# TEST: Icon Completeness
# ==============================================================================

test_that("every module has a corresponding icon", {
  for (mod in launcher_env$modules) {
    expect_true(
      mod$id %in% names(launcher_env$icons),
      info = sprintf("Module '%s' missing icon", mod$id)
    )
  }
})

test_that("all icons are valid SVG strings", {
  for (id in names(launcher_env$icons)) {
    svg <- launcher_env$icons[[id]]
    expect_true(is.character(svg) && nzchar(svg),
                info = sprintf("Icon '%s' is empty", id))
    expect_true(grepl("^<svg", svg),
                info = sprintf("Icon '%s' doesn't start with <svg", id))
    expect_true(grepl("</svg>$", svg),
                info = sprintf("Icon '%s' doesn't end with </svg>", id))
  }
})

test_that("no orphan icons (every icon maps to a module)", {
  mod_ids <- sapply(launcher_env$modules, `[[`, "id")
  for (icon_id in names(launcher_env$icons)) {
    expect_true(
      icon_id %in% mod_ids,
      info = sprintf("Orphan icon '%s' has no module", icon_id)
    )
  }
})


# ==============================================================================
# TEST: Categories Structure
# ==============================================================================

test_that("categories have required fields", {
  for (cat in launcher_env$categories) {
    expect_true("id" %in% names(cat), info = "Category missing 'id'")
    expect_true("label" %in% names(cat), info = "Category missing 'label'")
    expect_true(nzchar(cat$id), info = "Category has empty id")
    expect_true(nzchar(cat$label), info = "Category has empty label")
  }
})

test_that("category IDs are unique", {
  ids <- sapply(launcher_env$categories, `[[`, "id")
  expect_equal(length(ids), length(unique(ids)))
})


# ==============================================================================
# TEST: read_module_recents() Logic
# ==============================================================================

# Recreate the function outside Shiny context for testing
read_module_recents_testable <- function(mod, turas_root) {
  tryCatch({
    rds_path <- if (isTRUE(mod$recent_absolute)) {
      mod$recent_file
    } else {
      file.path(turas_root, mod$recent_file)
    }
    if (!file.exists(rds_path)) return(character(0))

    data <- readRDS(rds_path)
    if (length(data) == 0) return(character(0))

    paths <- if (is.character(data)) {
      data
    } else if (is.list(data) && !is.null(mod$recent_key)) {
      sapply(data, function(x) {
        val <- x[[mod$recent_key]]
        if (is.null(val)) NA_character_ else val
      })
    } else {
      character(0)
    }

    paths <- paths[!is.na(paths)]
    paths <- paths[file.exists(paths) | dir.exists(paths)]
    paths <- paths[sapply(paths, function(p) {
      if (dir.exists(p)) {
        length(list.files(p, pattern = "\\.xlsx$", ignore.case = TRUE)) > 0
      } else {
        TRUE
      }
    })]
    head(paths, 5)
  }, error = function(e) character(0))
}


test_that("read_module_recents returns empty for missing RDS file", {
  mod <- list(recent_file = "nonexistent.rds", recent_key = NULL)
  result <- read_module_recents_testable(mod, turas_root)
  expect_equal(result, character(0))
})

test_that("read_module_recents handles character vector format", {
  # Create temp RDS with character vector of paths
  tmp_dir <- tempdir()
  rds_path <- tempfile(fileext = ".rds")
  on.exit(unlink(rds_path))

  # Create a real directory with an xlsx file
  test_dir <- file.path(tmp_dir, "test_recent_proj")
  dir.create(test_dir, showWarnings = FALSE)
  file.create(file.path(test_dir, "config.xlsx"))
  on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

  saveRDS(c(test_dir, "/nonexistent/path"), rds_path)

  mod <- list(recent_file = rds_path, recent_key = NULL, recent_absolute = TRUE)
  result <- read_module_recents_testable(mod, turas_root)

  expect_true(length(result) >= 1)
  expect_true(test_dir %in% result)
  # Nonexistent path should be filtered out
  expect_false("/nonexistent/path" %in% result)
})

test_that("read_module_recents handles list format with recent_key", {
  rds_path <- tempfile(fileext = ".rds")
  on.exit(unlink(rds_path))

  # Create a real file to reference
  test_file <- tempfile(fileext = ".xlsx")
  file.create(test_file)
  on.exit(unlink(test_file), add = TRUE)

  data <- list(
    list(config_path = test_file, name = "Project 1"),
    list(config_path = "/nonexistent.xlsx", name = "Project 2")
  )
  saveRDS(data, rds_path)

  mod <- list(recent_file = rds_path, recent_key = "config_path", recent_absolute = TRUE)
  result <- read_module_recents_testable(mod, turas_root)

  expect_true(test_file %in% result)
  expect_false("/nonexistent.xlsx" %in% result)
})

test_that("read_module_recents returns max 5 items", {
  rds_path <- tempfile(fileext = ".rds")
  on.exit(unlink(rds_path))

  # Create 7 real files
  test_files <- sapply(1:7, function(i) {
    f <- tempfile(fileext = ".xlsx")
    file.create(f)
    f
  })
  on.exit(unlink(test_files), add = TRUE)

  saveRDS(test_files, rds_path)

  mod <- list(recent_file = rds_path, recent_key = NULL, recent_absolute = TRUE)
  result <- read_module_recents_testable(mod, turas_root)

  expect_equal(length(result), 5)
})

test_that("read_module_recents handles empty RDS", {
  rds_path <- tempfile(fileext = ".rds")
  on.exit(unlink(rds_path))

  saveRDS(character(0), rds_path)

  mod <- list(recent_file = rds_path, recent_key = NULL, recent_absolute = TRUE)
  result <- read_module_recents_testable(mod, turas_root)

  expect_equal(result, character(0))
})

test_that("read_module_recents filters stale directories without xlsx files", {
  rds_path <- tempfile(fileext = ".rds")
  on.exit(unlink(rds_path))

  # Create empty directory (no xlsx files)
  empty_dir <- file.path(tempdir(), "empty_stale_dir")
  dir.create(empty_dir, showWarnings = FALSE)
  on.exit(unlink(empty_dir, recursive = TRUE), add = TRUE)

  # Create directory with xlsx
  good_dir <- file.path(tempdir(), "good_project_dir")
  dir.create(good_dir, showWarnings = FALSE)
  file.create(file.path(good_dir, "config.xlsx"))
  on.exit(unlink(good_dir, recursive = TRUE), add = TRUE)

  saveRDS(c(empty_dir, good_dir), rds_path)

  mod <- list(recent_file = rds_path, recent_key = NULL, recent_absolute = TRUE)
  result <- read_module_recents_testable(mod, turas_root)

  expect_false(empty_dir %in% result)
  expect_true(good_dir %in% result)
})

test_that("read_module_recents handles corrupt RDS gracefully", {
  rds_path <- tempfile(fileext = ".rds")
  on.exit(unlink(rds_path))

  writeLines("not a valid RDS file", rds_path)

  mod <- list(recent_file = rds_path, recent_key = NULL, recent_absolute = TRUE)
  result <- read_module_recents_testable(mod, turas_root)

  expect_equal(result, character(0))
})


# ==============================================================================
# TEST: launch_turas.R file parses cleanly
# ==============================================================================

test_that("launch_turas.R parses without error", {
  result <- tryCatch(
    parse(file = file.path(turas_root, "launch_turas.R")),
    error = function(e) e
  )
  expect_false(inherits(result, "error"))
})


cat("\n=== Launcher Tests Complete ===\n")

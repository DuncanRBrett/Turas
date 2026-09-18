# ==============================================================================
# KEYDRIVER - THE DOCS DESCRIBE THIS MODULE, NOT AN EARLIER ONE (review M15, M10)
# ==============================================================================
# CODE_INVENTORY.md is a table of file names and line counts. It was written
# once and then drifted: wrong sizes, files that had been split, a demo folder
# that has never existed, and two JS files that no report embeds. Numbers in a
# document nobody can check are worse than no numbers, so they are checked
# here.
# ==============================================================================

inventory <- file.path(module_dir, "docs", "CODE_INVENTORY.md")
skip_if(!file.exists(inventory), "CODE_INVENTORY.md not present")
inv <- readLines(inventory, warn = FALSE)

test_that("every line count in the inventory matches the file (M15)", {
  # Rows look like: | `01_config.R` | 749 | ... |
  rows <- grep("^\\| `[0-9A-Za-z_.]+\\.(R|js)` \\| [0-9,]+ \\|", inv, value = TRUE)
  expect_gt(length(rows), 20)

  search_dirs <- c(
    module_dir,
    file.path(module_dir, "R"),
    file.path(module_dir, "R", "kda_shap"),
    file.path(module_dir, "R", "kda_quadrant"),
    file.path(module_dir, "R", "kda_methods"),
    file.path(module_dir, "lib"),
    file.path(module_dir, "lib", "html_report"),
    file.path(module_dir, "lib", "html_report", "js"),
    file.path(module_dir, "lib", "validation"),
    file.path(module_dir, "tests", "testthat"))

  on_disk <- list()
  for (d in search_dirs) {
    if (!dir.exists(d)) next
    for (f in list.files(d, pattern = "[.](R|js)$", full.names = TRUE)) {
      on_disk[[basename(f)]] <- length(readLines(f, warn = FALSE))
    }
  }

  checked <- 0L
  for (row in rows) {
    nm <- sub("^\\| `([^`]+)` \\|.*$", "\\1", row)
    claimed <- as.integer(gsub(",", "", sub("^\\| `[^`]+` \\| ([0-9,]+) \\|.*$", "\\1", row)))
    actual <- on_disk[[nm]]

    # A file the inventory lists and the module does not have is the
    # kd_pinned_views.js case: documented as a live component, deleted or
    # never there.
    expect_false(is.null(actual),
                 info = sprintf("%s is in CODE_INVENTORY.md and not in the module", nm))
    if (is.null(actual)) next

    # Ten per cent, so a comment added to a file does not fail the suite,
    # while a file that has been split or rewritten does.
    tol <- max(20L, as.integer(actual * 0.10))
    expect_lt(abs(claimed - actual), tol + 1L,
              label = sprintf("%s: inventory says %d, file has %d", nm, claimed, actual))
    checked <- checked + 1L
  }
  expect_gt(checked, 20)
})

test_that("the inventory does not name a path that is not there (M15)", {
  paths <- regmatches(inv, gregexpr("examples/keydriver/[A-Za-z0-9_./-]*", inv))
  paths <- unique(unlist(paths))
  paths <- paths[!grepl("[.]md$", paths)]
  for (p in paths) {
    full <- file.path(project_root, sub("/$", "", p))
    expect_true(file.exists(full) || dir.exists(full),
                info = sprintf("CODE_INVENTORY.md names %s, which does not exist", p))
  }
})

test_that("no doc describes a setting or column the code does not read (M10)", {
  docs <- list.files(file.path(module_dir, "docs"), pattern = "[.]md$", full.names = TRUE)
  docs <- c(docs, file.path(module_dir, "README.md"))
  docs <- docs[file.exists(docs)]

  # Each of these was documented and read by nothing, so an analyst who set
  # it got no feature and no message.
  withdrawn <- c("slide_order", "slide_image", "use_stated_importance")
  for (d in docs) {
    src <- paste(readLines(d, warn = FALSE), collapse = "\n")
    for (w in withdrawn) {
      expect_false(grepl(w, src, fixed = TRUE),
                   info = sprintf("%s still documents %s", basename(d), w))
    }
  }

  # effect_size_method may still appear, but only as withdrawn.
  ref <- file.path(module_dir, "docs", "06_TEMPLATE_REFERENCE.md")
  if (file.exists(ref)) {
    src <- paste(readLines(ref, warn = FALSE), collapse = "\n")
    if (grepl("effect_size_method", src, fixed = TRUE)) {
      expect_true(grepl("effect_size_method (withdrawn)", src, fixed = TRUE))
    }
  }

  # And the CustomSlides column the code actually reads is documented.
  for (d in docs) {
    src <- paste(readLines(d, warn = FALSE), collapse = "\n")
    if (grepl("CustomSlides", src, fixed = TRUE) && grepl("slide_title", src, fixed = TRUE)) {
      expect_true(grepl("image_path", src, fixed = TRUE),
                  info = sprintf("%s describes CustomSlides without image_path", basename(d)))
    }
  }
})

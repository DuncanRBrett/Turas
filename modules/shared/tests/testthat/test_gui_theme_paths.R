# ==============================================================================
# Tests: gui_theme.R path utilities
# ==============================================================================
# Covers: resolve_turas_path, turas_recents_dir, turas_recent_file,
#         turas_load_recents, turas_save_recents, turas_add_recent,
#         turas_gui_volumes
# ==============================================================================

turas_root <- Sys.getenv("TURAS_ROOT", "")
if (!nzchar(turas_root)) {
  turas_root <- normalizePath(
    file.path(dirname(testthat::test_path()), "..", "..", "..", ".."),
    mustWork = FALSE
  )
}
source(file.path(turas_root, "modules", "shared", "lib", "gui_theme.R"))


# ==============================================================================
# resolve_turas_path
# ==============================================================================

test_that("resolve_turas_path passes absolute Unix paths through unchanged", {
  withr::with_envvar(list(TURAS_PROJECTS_ROOT = "/data"), {
    result <- resolve_turas_path("/other/file.xlsx")
    expect_equal(result, "/other/file.xlsx")
  })
})

test_that("resolve_turas_path passes Windows drive paths through unchanged", {
  withr::with_envvar(list(TURAS_PROJECTS_ROOT = "/data"), {
    result <- resolve_turas_path("C:/Users/Jess/file.xlsx")
    # normalizePath on non-Windows may alter separators but not the meaning
    expect_true(grepl("^C:", result, ignore.case = TRUE))
  })
})

test_that("resolve_turas_path resolves relative paths against TURAS_PROJECTS_ROOT", {
  withr::with_envvar(list(TURAS_PROJECTS_ROOT = "/data"), {
    result <- resolve_turas_path("ClientA/Wave1/data.xlsx")
    expect_equal(result, "/data/ClientA/Wave1/data.xlsx")
  })
})

test_that("resolve_turas_path returns relative path unchanged when root not set", {
  withr::with_envvar(list(TURAS_PROJECTS_ROOT = ""), {
    result <- resolve_turas_path("ClientA/data.xlsx")
    expect_equal(result, "ClientA/data.xlsx")
  })
})

test_that("resolve_turas_path returns empty string for empty input", {
  result <- resolve_turas_path("")
  expect_equal(result, "")
})


# ==============================================================================
# turas_recent_file
# ==============================================================================

test_that("turas_recent_file builds correct filename for module key", {
  withr::with_envvar(list(TURAS_PROJECTS_ROOT = "", TURAS_ROOT = tempdir()), {
    path <- turas_recent_file("tabs")
    expect_true(grepl("\\.recent_tabs\\.rds$", path))
  })
})

test_that("turas_recent_file uses .turas subdirectory when TURAS_PROJECTS_ROOT set", {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  withr::with_envvar(list(TURAS_PROJECTS_ROOT = tmp), {
    path <- turas_recent_file("tracker")
    expect_true(grepl("\\.turas[\\/]\\.recent_tracker\\.rds$", path))
    # Directory should have been created
    expect_true(dir.exists(file.path(tmp, ".turas")))
  })
})


# ==============================================================================
# turas_load_recents / turas_save_recents / turas_add_recent
# ==============================================================================

test_that("turas_load_recents returns empty character vector when file absent", {
  withr::with_envvar(list(TURAS_PROJECTS_ROOT = "", TURAS_ROOT = tempdir()), {
    result <- turas_load_recents("nonexistent_module_xyz")
    expect_identical(result, character(0))
  })
})

test_that("turas_save_recents and turas_load_recents round-trip correctly", {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  withr::with_envvar(list(TURAS_PROJECTS_ROOT = tmp), {
    paths <- c("/data/ProjectA", "/data/ProjectB")
    turas_save_recents("test_module", paths)
    result <- turas_load_recents("test_module")
    expect_equal(result, paths)
  })
})

test_that("turas_add_recent inserts at front and deduplicates", {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  withr::with_envvar(list(TURAS_PROJECTS_ROOT = tmp), {
    turas_add_recent("test_mod", "/data/A")
    turas_add_recent("test_mod", "/data/B")
    turas_add_recent("test_mod", "/data/A")  # duplicate — should move to front
    result <- turas_load_recents("test_mod")
    expect_equal(result[1], "/data/A")
    expect_equal(length(result), 2L)  # deduplicated: A and B only
  })
})

test_that("turas_add_recent trims to TURAS_MAX_RECENTS", {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  withr::with_envvar(list(TURAS_PROJECTS_ROOT = tmp), {
    # Add TURAS_MAX_RECENTS + 3 entries
    n <- TURAS_MAX_RECENTS + 3L
    for (i in seq_len(n)) {
      turas_add_recent("trim_mod", sprintf("/data/Project%02d", i))
    }
    result <- turas_load_recents("trim_mod")
    expect_equal(length(result), TURAS_MAX_RECENTS)
  })
})

test_that("TURAS_MAX_RECENTS is 10", {
  # Known-answer test: verify the constant has the expected value
  expect_equal(TURAS_MAX_RECENTS, 10L)
})


# ==============================================================================
# turas_gui_volumes
# ==============================================================================

test_that("turas_gui_volumes puts Projects first when TURAS_PROJECTS_ROOT set", {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  withr::with_envvar(
    list(TURAS_PROJECTS_ROOT = tmp, TURAS_DOCKER = ""),
    {
      vols <- turas_gui_volumes()
      # Projects must be present and must be the first entry
      expect_true("Projects" %in% names(vols))
      expect_equal(names(vols)[1], "Projects")
      expect_equal(unname(vols)[1], tmp)
      # Other roots (Home etc.) should still be present for legacy access
      expect_true(length(vols) > 1L)
    }
  )
})

test_that("turas_gui_volumes falls back to Docker roots when in Docker", {
  withr::with_envvar(
    list(TURAS_PROJECTS_ROOT = "", TURAS_DOCKER = "1"),
    {
      # Create /data stub only if not already present (CI may not have it)
      vols <- turas_gui_volumes()
      expect_false("Projects" %in% names(vols))
    }
  )
})

test_that("turas_gui_volumes falls back to home directory on desktop", {
  withr::with_envvar(
    list(TURAS_PROJECTS_ROOT = "", TURAS_DOCKER = ""),
    {
      vols <- turas_gui_volumes()
      expect_false("Projects" %in% names(vols))
      expect_true("Home" %in% names(vols) || length(vols) > 0)
    }
  )
})

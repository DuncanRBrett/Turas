# ==============================================================================
# Tests: Hub App Preferences
# ==============================================================================

turas_root <- Sys.getenv("TURAS_ROOT", getwd())
source(file.path(turas_root, "modules", "hub_app", "lib", "preferences.R"))

# ==============================================================================
# default_preferences()
# ==============================================================================

test_that("default_preferences returns expected structure", {
  defaults <- default_preferences()

  expect_true(is.list(defaults))
  expect_true("scan_directories" %in% names(defaults))
  expect_true("brand_colour" %in% names(defaults))
  expect_true("accent_colour" %in% names(defaults))
  expect_true("logo_path" %in% names(defaults))
  expect_true("auto_save_interval" %in% names(defaults))
  expect_true("theme" %in% names(defaults))

  expect_equal(defaults$brand_colour, "#2563EB")
  expect_equal(defaults$accent_colour, "#10B981")
  expect_equal(defaults$theme, "light")
  expect_equal(defaults$auto_save_interval, 500)
  expect_true(is.list(defaults$scan_directories))
})

# ==============================================================================
# get_preferences_path()
# ==============================================================================

test_that("get_preferences_path returns a path under ~/.turas/", {
  path <- get_preferences_path()
  expect_true(grepl(".turas", path, fixed = TRUE))
  expect_true(grepl("hub_app_config.json", path, fixed = TRUE))
})

# ==============================================================================
# save_hub_preferences() + get_hub_preferences()
# ==============================================================================

test_that("save and load preferences round-trips correctly", {
  # Use a temporary config path
  tmp_dir <- file.path(tempdir(), "prefs_test_roundtrip", ".turas")
  dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
  tmp_path <- file.path(tmp_dir, "hub_app_config.json")
  on.exit(unlink(file.path(tempdir(), "prefs_test_roundtrip"), recursive = TRUE))

  # Override the path function for this test
  local({
    # Temporarily override HOME to redirect config file
    old_home <- Sys.getenv("HOME")
    Sys.setenv(HOME = file.path(tempdir(), "prefs_test_roundtrip"))
    on.exit(Sys.setenv(HOME = old_home))

    prefs <- list(
      scan_directories = list("/Users/test/Projects"),
      brand_colour = "#FF5733",
      accent_colour = "#28B463",
      logo_path = "/path/to/logo.png",
      auto_save_interval = 1000,
      theme = "light"
    )

    # Save
    result <- save_hub_preferences(prefs)
    expect_equal(result$status, "PASS")

    # Load
    loaded <- get_hub_preferences()
    expect_equal(loaded$brand_colour, "#FF5733")
    expect_equal(loaded$accent_colour, "#28B463")
    expect_equal(loaded$logo_path, "/path/to/logo.png")
    expect_equal(loaded$auto_save_interval, 1000)
  })
})

test_that("get_hub_preferences returns defaults when no file exists", {
  old_home <- Sys.getenv("HOME")
  Sys.setenv(HOME = file.path(tempdir(), "prefs_test_nofile_xxx"))
  on.exit(Sys.setenv(HOME = old_home))

  prefs <- get_hub_preferences()
  defaults <- default_preferences()

  expect_equal(prefs$brand_colour, defaults$brand_colour)
  expect_equal(prefs$theme, defaults$theme)
})

test_that("save_hub_preferences merges with defaults", {
  old_home <- Sys.getenv("HOME")
  tmp_home <- file.path(tempdir(), "prefs_test_merge")
  dir.create(file.path(tmp_home, ".turas"), recursive = TRUE, showWarnings = FALSE)
  Sys.setenv(HOME = tmp_home)
  on.exit({
    Sys.setenv(HOME = old_home)
    unlink(tmp_home, recursive = TRUE)
  })

  # Save only partial prefs
  result <- save_hub_preferences(list(brand_colour = "#123456"))
  expect_equal(result$status, "PASS")

  # Load should have the custom value + defaults for everything else
  loaded <- get_hub_preferences()
  expect_equal(loaded$brand_colour, "#123456")
  expect_equal(loaded$accent_colour, "#10B981")  # default
  expect_equal(loaded$theme, "light")  # default
})

test_that("save_hub_preferences ignores unknown keys", {
  old_home <- Sys.getenv("HOME")
  tmp_home <- file.path(tempdir(), "prefs_test_unknown")
  dir.create(file.path(tmp_home, ".turas"), recursive = TRUE, showWarnings = FALSE)
  Sys.setenv(HOME = tmp_home)
  on.exit({
    Sys.setenv(HOME = old_home)
    unlink(tmp_home, recursive = TRUE)
  })

  result <- save_hub_preferences(list(
    brand_colour = "#AABBCC",
    unknown_field = "should_be_ignored"
  ))
  expect_equal(result$status, "PASS")

  loaded <- get_hub_preferences()
  expect_equal(loaded$brand_colour, "#AABBCC")
  expect_null(loaded$unknown_field)
})

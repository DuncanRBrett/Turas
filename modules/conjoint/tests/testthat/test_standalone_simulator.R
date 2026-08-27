# ==============================================================================
# TESTS: THE STANDALONE MARKET SIMULATOR
# ==============================================================================
#
# The simulator was folded into the combined HTML report in March 2026. That
# report is retired, so the simulator is a standalone file again — a tool the
# client opens and shares, which the interactive report links to rather than
# embeds (programme decision D2).
#
# What these tests hold to: it builds, it is genuinely self-contained, it
# refuses an interaction model rather than simulating one it cannot represent,
# and its script island cannot be broken open by an attribute name.
# ==============================================================================

root <- Sys.getenv("TURAS_ROOT")
sim_main <- file.path(root, "modules", "conjoint", "lib", "html_simulator",
                      "99_simulator_main.R")

test_that("the standalone simulator module is present", {
  expect_true(file.exists(sim_main))
  expect_true(file.exists(file.path(dirname(sim_main), "01_simulator_parts.R")))
  for (js in c("simulator_engine.js", "simulator_ui.js", "simulator_charts.js")) {
    expect_true(file.exists(file.path(dirname(sim_main), "js", js)), info = js)
  }
})

test_that("the retired report layer is gone, and nothing still reaches for it", {
  expect_false(dir.exists(file.path(root, "modules", "conjoint", "lib", "html_report")))

  for (f in list.files(file.path(root, "modules", "conjoint", "R"),
                       pattern = "[.]R$", full.names = TRUE)) {
    src <- paste(readLines(f, warn = FALSE), collapse = "\n")
    expect_false(grepl('"html_report"', src, fixed = TRUE), info = basename(f))
    expect_false(grepl("generate_conjoint_html_report", src, fixed = TRUE),
                 info = basename(f))
  }
})

test_that("generate_html_report is retired, not silently ignored", {
  expect_true("generate_html_report" %in% names(CONJOINT_RETIRED_SETTINGS))

  msg <- CONJOINT_RETIRED_SETTINGS[["generate_html_report"]]
  # The notice has to say where the results went and how to get a simulator.
  expect_match(msg, "conjoint_island")
  expect_match(msg, "generate_html_simulator")
})

# ---------------------------------------------------------------------------
# Building one
# ---------------------------------------------------------------------------

make_sim_results <- function(with_interactions = FALSE) {
  attributes <- list(Brand = c("Alpha", "Beta"), Price = c("$10", "$20"))
  attr_df <- data.frame(
    AttributeName = names(attributes),
    NumLevels = sapply(attributes, length),
    stringsAsFactors = FALSE
  )
  attr_df$levels_list <- unname(attributes)

  utilities <- data.frame(
    Attribute = c("Brand", "Brand", "Price", "Price"),
    Level = c("Alpha", "Beta", "$10", "$20"),
    Utility = c(-0.25, 0.25, 0.3, -0.3),
    Std_Error = c(0, 0.1, 0, 0.1),
    is_baseline = c(TRUE, FALSE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  if (with_interactions) {
    attr(utilities, "has_interactions") <- TRUE
    attr(utilities, "dropped_interaction_coefs") <- "BrandBeta:Price$20"
  }

  importance <- data.frame(Attribute = c("Brand", "Price"),
                           Importance = c(45.5, 54.5),
                           stringsAsFactors = FALSE)

  list(
    utilities = utilities,
    importance = importance,
    model_result = list(method = "mlogit", n_respondents = 200L),
    config = list(attributes = attr_df, currency_symbol = "$",
                  project_name = "Sim test")
  )
}

test_that("a simulator builds, and is one self-contained file", {
  skip_if(!file.exists(sim_main), "simulator module not present")
  source(sim_main, local = TRUE)

  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)

  res <- generate_conjoint_simulator(make_sim_results(), out, verbose = FALSE)

  expect_equal(res$status, "PASS")
  expect_true(file.exists(out))

  html <- paste(readLines(out, warn = FALSE), collapse = "\n")

  # Self-contained: no request leaves the file.
  expect_false(grepl('src="http', html, fixed = TRUE))
  expect_false(grepl('href="http', html, fixed = TRUE))

  # The engine, the data and the panel are all in it.
  expect_true(grepl("SimEngine", html, fixed = TRUE))
  expect_true(grepl("SimUI", html, fixed = TRUE))
  expect_true(grepl('id="cj-simulator-data"', html, fixed = TRUE))
  expect_true(grepl("cj-sim-results", html, fixed = TRUE))

  # And none of the report's furniture came along. (The CSS still defines rules
  # for elements the simulator does not render — see the note in
  # 01_simulator_parts.R — so this checks for the ELEMENTS, not the classes.)
  expect_false(grepl('<button class="cj-pin-btn"', html, fixed = TRUE))
  expect_false(grepl("showPinPopover", html, fixed = TRUE))
  expect_false(grepl("cj-tab-btn", html, fixed = TRUE))
})

test_that("an interaction model refuses rather than simulating main effects", {
  skip_if(!file.exists(sim_main), "simulator module not present")
  source(sim_main, local = TRUE)

  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)

  res <- generate_conjoint_simulator(make_sim_results(with_interactions = TRUE),
                                     out, verbose = FALSE)

  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CALC_INTERACTIONS_NOT_IN_SIMULATOR")
  expect_false(file.exists(out))
})

test_that("no utilities means no simulator, and it says so", {
  skip_if(!file.exists(sim_main), "simulator module not present")
  source(sim_main, local = TRUE)

  r <- make_sim_results()
  r$utilities <- NULL

  res <- generate_conjoint_simulator(r, tempfile(fileext = ".html"), verbose = FALSE)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "DATA_SIMULATOR_NO_UTILITIES")
})

test_that("an attribute name cannot break the data island open", {
  skip_if(!file.exists(sim_main), "simulator module not present")
  source(sim_main, local = TRUE)

  r <- make_sim_results()
  nasty <- 'Brand </script><script>alert(1)</script>'
  r$utilities$Attribute[1:2] <- nasty
  r$config$attributes$AttributeName[1] <- nasty
  r$config$attributes$levels_list[[1]] <- c("Alpha", "Beta")
  r$importance$Attribute[1] <- nasty

  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)

  res <- generate_conjoint_simulator(r, out, verbose = FALSE)
  skip_if(!identical(res$status, "PASS"), "simulator did not build with the hostile name")

  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  island <- regmatches(html, regexpr('id="cj-simulator-data">.*?</script>', html))
  expect_length(island, 1)

  body <- sub('^id="cj-simulator-data">', "", island)
  body <- sub("</script>$", "", body)
  expect_false(grepl("<", body, fixed = TRUE))
})

test_that("the simulator's JavaScript parses", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node not on PATH")

  js_dir <- file.path(dirname(sim_main), "js")
  for (f in list.files(js_dir, pattern = "[.]js$", full.names = TRUE)) {
    expect_equal(system2(node, c("--check", shQuote(f)), stdout = FALSE, stderr = FALSE),
                 0L, info = basename(f))
  }
})

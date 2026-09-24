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

test_that("the simulator data carries no None utility, so No-Purchase is not offered", {
  # Review 2026-09-24: the module refuses a None alternative before estimation
  # (03_estimation.R), so no None utility exists to embed. The simulator used to
  # offer "Include No-Purchase" anyway and score None at 0; it now offers the
  # option only when the data carries a finite noneUtility, and this pins the R
  # side of that contract: the island has no such key.
  skip_if(!file.exists(sim_main), "simulator module not present")
  source(sim_main, local = TRUE)

  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)
  res <- generate_conjoint_simulator(make_sim_results(), out, verbose = FALSE)
  expect_equal(res$status, "PASS")

  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  island <- regmatches(html, regexpr('id="cj-simulator-data">.*?</script>', html))
  body <- sub("</script>$", "", sub('^id="cj-simulator-data">', "", island))
  sim_data <- jsonlite::fromJSON(body, simplifyVector = FALSE)
  expect_null(sim_data$noneUtility)
  expect_true(length(sim_data$attributes) > 0)
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

test_that("every inline handler in the page has a definition in the page", {
  # The C-delta review found the extraction had left switchSimMode,
  # exportSimulatorExcel and cjExportPNG behind in the deleted report JS:
  # every mode button except the default and both export buttons threw a
  # ReferenceError. This closes that class of defect: any onclick the panel
  # markup emits must be defined somewhere in the same file.
  skip_if(!file.exists(sim_main), "simulator module not present")
  source(sim_main, local = TRUE)

  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)
  res <- generate_conjoint_simulator(make_sim_results(), out, verbose = FALSE)
  expect_equal(res$status, "PASS")

  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Only an identifier that is actually CALLED counts as a handler. The old
  # pattern took the first identifier in the attribute whatever followed it, so
  # the shared callout's onclick="this.parentElement.classList.toggle(...)"
  # yielded "this" and the test demanded a function called this. That made the
  # result depend on whether the callout registry happened to be loaded, so the
  # suite passed alone and failed after the shared suite had run.
  handlers <- unique(gsub(
    '^onclick="([A-Za-z_$][A-Za-z0-9_$]*)[[:space:]]*\\($', "\\1",
    regmatches(html, gregexpr('onclick="[A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*\\(',
                              html))[[1]]
  ))
  expect_true(length(handlers) > 0)

  for (fn in handlers) {
    # Object-method handlers (SimUI.addProduct()) resolve through the
    # object; bare ones must be defined as a function or window assignment.
    if (grepl("^(SimUI|SimEngine|SimCharts)$", fn)) next
    defined <- grepl(paste0("function ", fn, "\\s*\\("), html) ||
      grepl(paste0("window\\.", fn, "\\s*="), html) ||
      grepl(paste0("\\b", fn, "\\s*=\\s*function"), html)
    expect_true(defined, info = paste0("onclick handler '", fn,
                                       "' has no definition in the page"))
  }
})

# ------------------------------------------------------------------------------
# The page does not depend on what else the session happened to load
#
# .build_callout() used to test exists("turas_callout_html") and never load it.
# Nothing on the conjoint production route loads it, so every shipped simulator
# got the plain fallback box while the seven other modules that build a report
# locate the registry themselves and got the designed collapsible callout. It
# also made this file's own handler test pass alone and fail after the shared
# suite had run, because the shared callout's inline onclick only appeared in
# the page when the registry happened to be in the global environment.
#
# Both shapes are pinned here, each in its own process so neither can inherit
# the other's global environment.
# ------------------------------------------------------------------------------

run_sim_probe <- function(extra = "") {
  rscript <- file.path(R.home("bin"), "Rscript")
  if (!file.exists(rscript)) return(NULL)
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(c(
    sprintf('setwd("%s")', root),
    sprintf('Sys.setenv(TURAS_ROOT = "%s")', root),
    'e <- new.env(parent = globalenv()); e$test_that <- function(...) invisible(NULL)',
    sprintf('sys.source("%s", envir = e)',
            file.path(root, "modules", "conjoint", "tests", "testthat",
                      "test_standalone_simulator.R")),
    sprintf('source("%s")', sim_main),
    extra,
    'out <- tempfile(fileext = ".html")',
    'r <- generate_conjoint_simulator(e$make_sim_results(), out, verbose = FALSE)',
    'cat("STATUS:", r$status, "\\n")',
    'h <- paste(readLines(out, warn = FALSE), collapse = "\\n")',
    'cat("DESIGNED:", grepl("t-callout-header", h, fixed = TRUE), "\\n")',
    'cat("CHEVRON:", grepl("t-callout-chevron", h, fixed = TRUE), "\\n")',
    'cat("PLAINBOX:", grepl("<div class=\\"t-callout\\"><div class=\\"t-callout-body\\">", h, fixed = TRUE), "\\n")',
    'unlink(out)'
  ), script)
  suppressWarnings(system2(rscript, shQuote(script), stdout = TRUE, stderr = TRUE))
}

flag <- function(out, key) {
  line <- grep(paste0("^", key, ":"), out, value = TRUE)
  if (!length(line)) return(NA)
  identical(trimws(sub(paste0("^", key, ":"), "", line[1])), "TRUE")
}

test_that("a fresh process builds the designed callout, without anything preloading the registry", {
  out <- run_sim_probe()
  skip_if(is.null(out), "Rscript not found")
  expect_true(any(grepl("STATUS: PASS", out, fixed = TRUE)),
              info = paste(out, collapse = "\n"))
  # This is the regression: before the fix a fresh process got the plain box,
  # because nothing on the production route loads the registry.
  expect_true(flag(out, "DESIGNED"), info = paste(out, collapse = "\n"))
  expect_true(flag(out, "CHEVRON"), info = paste(out, collapse = "\n"))
})

test_that("preloading the registry gives exactly the same shape, so the page is deterministic", {
  out <- run_sim_probe(extra = sprintf(
    'source("%s")', file.path(root, "modules", "shared", "lib", "callouts",
                              "callout_registry.R")))
  skip_if(is.null(out), "Rscript not found")
  expect_true(any(grepl("STATUS: PASS", out, fixed = TRUE)),
              info = paste(out, collapse = "\n"))
  expect_true(flag(out, "DESIGNED"), info = paste(out, collapse = "\n"))
  expect_true(flag(out, "CHEVRON"), info = paste(out, collapse = "\n"))
})

test_that("with the registry genuinely unreachable the page still builds, and says so", {
  # A standalone checkout with no shared library. The fallback is legitimate
  # there; what is not legitimate is degrading silently.
  out <- run_sim_probe(extra = '.cj_sim_callout_dir <- function() NULL')
  skip_if(is.null(out), "Rscript not found")
  expect_true(any(grepl("STATUS: PASS", out, fixed = TRUE)),
              info = paste(out, collapse = "\n"))
  expect_false(flag(out, "DESIGNED"), info = paste(out, collapse = "\n"))
  expect_true(flag(out, "PLAINBOX"), info = paste(out, collapse = "\n"))
  expect_true(any(grepl("IO_CALLOUT_REGISTRY_MISSING", out, fixed = TRUE)),
              info = "the fallback must announce itself on the console")
})

test_that("the handler check is not affected by whether the registry is loaded", {
  # The inline onclick the shared callout carries is not a handler, and must
  # not be read as one. Both shapes are checked, in separate processes.
  for (extra in list("", sprintf('source("%s")',
                                 file.path(root, "modules", "shared", "lib",
                                           "callouts", "callout_registry.R")))) {
    out <- run_sim_probe(extra = extra)
    skip_if(is.null(out), "Rscript not found")
    expect_false(any(grepl("handler 'this'", out, fixed = TRUE)),
                 info = paste(out, collapse = "\n"))
  }
})

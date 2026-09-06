# ==============================================================================
# TEST: no style element is nested inside another
# ==============================================================================
# build_ma_panel_styles() returns its CSS already wrapped in a
# <style class="ma-panel-styles"> tag, the way the funnel, advantage and brand
# selector styling functions do, and 99_html_report_main.R wrapped it a second
# time. A CSS parser recovering from a style element opening inside another one
# discards the malformed prelude plus the next declaration block, so the first
# rule inside died: .ma-panel { --ma-brand: <focal>; position: relative;
# background: #fff; border: ... }. var(--ma-brand) is read 15 times in a
# generated report and 14 of those carry no fallback, so those accents resolved
# to nothing and the panel lost its border and background. Proved in headless
# Chrome on 6 September 2026, both that the rule dies and that only the first
# one does.
#
# Two guards. The first reads the generator, so a styling function that starts
# self-wrapping without its call site being updated fails here. The second
# reads assembled CSS, so any future double wrap fails whatever its shape.
# ==============================================================================

library(testthat)

.nst_root <- function() {
  d <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(d, "launch_turas.R")) ||
        file.exists(file.path(d, "CLAUDE.md"))) return(d)
    d <- dirname(d)
  }
  getwd()
}


test_that("a styling function that self-wraps is not wrapped again by the assembler", {
  root  <- .nst_root()
  pdir  <- file.path(root, "modules", "brand", "lib", "html_report", "panels")
  main  <- readLines(file.path(root, "modules", "brand", "lib", "html_report",
                               "99_html_report_main.R"), warn = FALSE)

  # Every class the assembler wraps in a style tag of its own.
  wrapped <- unique(unlist(regmatches(
    main, gregexpr('(?<=paste0\\(\'<style class=")[a-z0-9-]+', main, perl = TRUE))))

  # Every class a panel styling function emits for itself.
  self_wrapped <- character(0)
  for (f in list.files(pdir, pattern = "_styling\\.R$", full.names = TRUE)) {
    src <- readLines(f, warn = FALSE)
    hits <- unlist(regmatches(
      src, gregexpr('(?<=paste0\\(\'<style class=")[a-z0-9-]+', src, perl = TRUE)))
    self_wrapped <- c(self_wrapped, hits)
  }
  self_wrapped <- unique(self_wrapped)

  both <- intersect(wrapped, self_wrapped)
  expect_identical(
    both, character(0),
    info = paste("These panel styles are wrapped twice, once by the styling",
                 "function and once by 99_html_report_main.R:",
                 paste(both, collapse = ", ")))
})


test_that("assembled panel CSS opens no style element inside another", {
  root <- .nst_root()
  rdir <- file.path(root, "modules", "brand", "lib", "html_report")
  for (f in c("panels/00_brand_selector_styling.R",
              "panels/02_ma_panel_styling.R",
              "panels/02_ma_panel_advantage_styling.R",
              "panels/03_funnel_panel_styling.R")) {
    source(file.path(rdir, f), local = FALSE)
  }

  css <- paste(
    if (exists("build_ma_panel_styles", mode = "function"))
      build_ma_panel_styles("#1A5276") else "",
    if (exists("build_ma_advantage_styles", mode = "function"))
      build_ma_advantage_styles("#1A5276") else "",
    if (exists("build_funnel_panel_styles", mode = "function"))
      build_funnel_panel_styles("#1A5276") else "",
    sep = "\n")

  expect_false(grepl("<style[^>]*>\\s*<style", css, perl = TRUE),
               info = "a style element opens inside another")
})

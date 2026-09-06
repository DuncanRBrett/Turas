# ==============================================================================
# TEST: config values reach an inline <script> as JS literals (review F14)
# ==============================================================================
# build_br_portfolio_panel() pasted a section id and colour_focal straight
# into an inline script. colour_focal is operator-supplied and the config
# loader does not check it, so a value carrying a quote broke the script, and
# one carrying "</script>" ended the element early and swallowed whatever
# followed. Low severity because it is config-controlled, but the fix is the
# same discipline the JSON islands already use.
#
# HTML escaping is the wrong tool inside a script element: the parser does
# not decode entities there. These tests pin the JS-literal helper and the
# colour sanitiser.
# ==============================================================================

library(testthat)

local({
  find_root <- function() {
    d <- getwd()
    for (i in 1:10) {
      if (file.exists(file.path(d, "CLAUDE.md"))) return(d)
      d <- dirname(d)
    }
    getwd()
  }
  root <- find_root()
  source(file.path(root, "modules", "brand", "R", "01b_section_insights.R"),
         local = FALSE)
  source(file.path(root, "modules", "brand", "lib", "html_report",
                   "03_page_builder.R"), local = FALSE)
})


test_that(".br_js_str returns a quoted literal that parses back to the input", {
  for (v in c("portfolio-overview", "#1A5276", 'a "quoted" value',
              "back\\slash", "line\nbreak", "tab\there")) {
    lit <- .br_js_str(v)
    expect_true(startsWith(lit, '"'))
    expect_true(endsWith(lit, '"'))
    expect_identical(jsonlite::fromJSON(lit), v)
  }
})


test_that(".br_js_str makes </script unformable", {
  hostile <- '#fff</script><script>alert(1)</script>'
  lit <- .br_js_str(hostile)
  expect_false(grepl("<", lit, fixed = TRUE))
  expect_false(grepl("</script", lit, fixed = TRUE))
  expect_identical(jsonlite::fromJSON(lit), hostile)
})


test_that(".br_js_str closes the string a hostile quote tried to break out of", {
  hostile <- '#fff";alert(1);var x="'
  lit <- .br_js_str(hostile)
  # One opening and one closing quote; every inner quote is backslash-escaped.
  inner <- substr(lit, 2L, nchar(lit) - 1L)
  expect_false(grepl('(^|[^\\\\])"', inner))
  expect_identical(jsonlite::fromJSON(lit), hostile)
})


test_that(".br_js_str handles NULL and NA", {
  expect_identical(.br_js_str(NULL), '""')
  expect_identical(.br_js_str(NA_character_), '""')
})


test_that(".br_colour keeps real colour tokens", {
  for (v in c("#fff", "#1A5276", "#1A527680", "rgb(26, 82, 118)",
              "rgba(26,82,118,0.5)", "hsl(206, 64%, 28%)", "rebeccapurple")) {
    expect_identical(.br_colour(v), v)
  }
})


test_that(".br_colour rejects anything that could carry a declaration", {
  for (v in c("red;background:url(javascript:alert(1))",
              '#fff" onload="alert(1)',
              "expression(alert(1))",
              "#fff}.x{color:red",
              "")) {
    expect_identical(.br_colour(v), "#1A5276")
  }
  expect_identical(.br_colour(NULL), "#1A5276")
  expect_identical(.br_colour(NA_character_), "#1A5276")
  expect_identical(.br_colour("nonsense!", default = "#000"), "#000")
})


test_that("the portfolio brand-picker script carries no raw config text", {
  # Build the panel with a hostile colour and read the emitted script.
  results <- list(results = list(
    portfolio_overview = list(categories = list(
      list(cat_code = "AAA", category = "Alpha", depth = "full",
           usage_pct = 60, brand_codes = c("X", "Y"),
           brand_names = list(X = "Xylo", Y = "Yarrow"),
           brand_awareness = list(X = 0.5, Y = 0.4)),
      list(cat_code = "BBB", category = "Bravo", depth = "awareness_only",
           usage_pct = 40, brand_codes = c("X", "Y"),
           brand_names = list(X = "Xylo", Y = "Yarrow"),
           brand_awareness = list(X = 0.3, Y = 0.2)))),
    portfolio = list(n_total = 300L),
    categories = list()))
  config <- list(focal_brand = "X",
                 colour_focal = '#fff";alert(1);</script><script>alert(2)</script>')

  html <- build_br_portfolio_panel(results, config)
  expect_type(html, "character")

  # The brand-picker script is actually emitted, so this is not vacuous.
  brand_colour_line <- regmatches(
    html, regexpr("var brandColour = [^\n]*", html))
  expect_length(brand_colour_line, 1L)
  section_line <- regmatches(html, regexpr("var section = [^\n]*", html))
  expect_length(section_line, 1L)

  # No raw hostile fragment anywhere in the panel.
  expect_false(grepl("alert(1)", html, fixed = TRUE))
  expect_false(grepl("alert(2)", html, fixed = TRUE))
  expect_false(grepl("</script><script>", html, fixed = TRUE))
  # The section id reaches the script as a quoted literal.
  expect_true(grepl('"portfolio-overview"', section_line, fixed = TRUE))
  # The colour that reaches the style attributes is the sanitised default.
  expect_true(grepl("#1A5276", html, fixed = TRUE))
})

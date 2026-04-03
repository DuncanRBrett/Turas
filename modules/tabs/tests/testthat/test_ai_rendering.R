# ==============================================================================
# TABS MODULE - AI RENDERING TESTS
# ==============================================================================
#
# Tests for HTML rendering of AI insights components:
#   - build_ai_callout_panel()               — per-question AI callout
#   - build_researcher_commentary_panel()     — per-question commentary
#   - build_ai_exec_summary()                — executive summary (both variants)
#   - build_ai_methodology_note()            — model attribution note
#   - build_ai_toggle_control()              — show/hide toggle
#   - build_ai_callout_css()                 — CSS output
#   - build_ai_insights_js()                 — JS output
#   - escape_html()                          — HTML escaping
#   - narrative_to_paragraphs()              — paragraph conversion
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_ai_rendering.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/tabs/lib/ai/ai_rendering.R"))

# ==============================================================================
# HELPERS
# ==============================================================================

make_test_callout <- function(has_insight = TRUE,
                              narrative = "NPS of +7 masks a segment divide.",
                              confidence = "high",
                              pinned = FALSE,
                              data_limitations = "") {
  list(
    has_insight      = has_insight,
    narrative        = narrative,
    confidence       = confidence,
    data_limitations = data_limitations,
    pinned           = pinned,
    verified         = TRUE
  )
}

make_test_exec_summary <- function(narrative = "The study reveals strong patterns.") {
  list(
    narrative        = narrative,
    confidence       = "high",
    data_limitations = ""
  )
}

# ==============================================================================
# TESTS: build_ai_callout_panel
# ==============================================================================

context("build_ai_callout_panel")

test_that("renders callout with correct structure", {
  callout <- make_test_callout()
  html <- build_ai_callout_panel(callout, "Q001")

  expect_true(nzchar(html))
  expect_true(grepl('class="turas-ai-callout"', html, fixed = TRUE))
  expect_true(grepl('data-q-code="Q001"', html, fixed = TRUE))
  expect_true(grepl('data-confidence="high"', html, fixed = TRUE))
  expect_true(grepl("AI-assisted insight", html, fixed = TRUE))
  expect_true(grepl("NPS of +7", html, fixed = TRUE))
})

test_that("renders without pin button (pinning via question-level popover)", {
  callout <- make_test_callout()
  html <- build_ai_callout_panel(callout, "Q001")

  expect_false(grepl('data-pinned', html, fixed = TRUE))
  expect_false(grepl('ai-callout-pin', html, fixed = TRUE))
})

test_that("renders medium confidence with caveat", {
  callout <- make_test_callout(
    confidence = "medium",
    data_limitations = "Base sizes below 50 for Premium segment."
  )
  html <- build_ai_callout_panel(callout, "Q001")

  expect_true(grepl('data-confidence="medium"', html, fixed = TRUE))
  expect_true(grepl('class="ai-callout-caveat"', html, fixed = TRUE))
  expect_true(grepl("Base sizes below 50", html, fixed = TRUE))
})

test_that("does not render caveat for high confidence", {
  callout <- make_test_callout(
    confidence = "high",
    data_limitations = "Some limitation"
  )
  html <- build_ai_callout_panel(callout, "Q001")

  expect_false(grepl('class="ai-callout-caveat"', html, fixed = TRUE))
})

test_that("returns empty string when has_insight is FALSE", {
  callout <- make_test_callout(has_insight = FALSE)
  html <- build_ai_callout_panel(callout, "Q001")
  expect_equal(html, "")
})

test_that("returns empty string for NULL callout", {
  expect_equal(build_ai_callout_panel(NULL, "Q001"), "")
})

test_that("returns empty string for empty narrative", {
  callout <- make_test_callout(narrative = "")
  html <- build_ai_callout_panel(callout, "Q001")
  expect_equal(html, "")
})

test_that("escapes HTML in narrative", {
  callout <- make_test_callout(narrative = "Score <50% & rising")
  html <- build_ai_callout_panel(callout, "Q001")

  expect_true(grepl("&lt;50%", html, fixed = TRUE))
  expect_true(grepl("&amp;", html, fixed = TRUE))
  expect_false(grepl("<50%", html, fixed = TRUE))
})

test_that("includes dismiss button with onclick handler", {
  callout <- make_test_callout()
  html <- build_ai_callout_panel(callout, "Q001")

  expect_true(grepl("dismissAiCallout", html, fixed = TRUE))
  expect_true(grepl('class="ai-callout-dismiss"', html, fixed = TRUE))
  # Pin button removed — pinning handled by question-level pin popover
  expect_false(grepl('class="ai-callout-pin"', html, fixed = TRUE))
})

# ==============================================================================
# TESTS: build_researcher_commentary_panel
# ==============================================================================

context("build_researcher_commentary_panel")

test_that("renders commentary with correct structure", {
  html <- build_researcher_commentary_panel("Strategic observation here.", "Q001")

  expect_true(nzchar(html))
  expect_true(grepl('class="turas-commentary"', html, fixed = TRUE))
  expect_true(grepl('data-q-code="Q001"', html, fixed = TRUE))
  expect_true(grepl("Strategic observation here.", html, fixed = TRUE))
})

test_that("returns empty string for NULL commentary", {
  expect_equal(build_researcher_commentary_panel(NULL, "Q001"), "")
})

test_that("returns empty string for empty commentary", {
  expect_equal(build_researcher_commentary_panel("", "Q001"), "")
})

test_that("does not contain AI labelling", {
  html <- build_researcher_commentary_panel("Test commentary.", "Q001")

  expect_false(grepl("AI-assisted", html, fixed = TRUE))
  expect_false(grepl("ai-callout", html, fixed = TRUE))
})

# ==============================================================================
# TESTS: build_ai_exec_summary
# ==============================================================================

context("build_ai_exec_summary")

test_that("renders reviewed variant with gold AI styling, no review note", {
  exec <- make_test_exec_summary()
  config <- list(exec_summary_reviewed = TRUE)

  html <- build_ai_exec_summary(exec, config)

  expect_true(grepl('class="turas-ai-callout turas-ai-exec"', html, fixed = TRUE))
  expect_true(grepl("AI-assisted key findings", html, fixed = TRUE))
  expect_false(grepl("Reviewed by research team", html, fixed = TRUE))
})

test_that("renders unreviewed variant with gold AI styling, no review note", {
  exec <- make_test_exec_summary()
  config <- list(exec_summary_reviewed = FALSE)

  html <- build_ai_exec_summary(exec, config)

  expect_true(grepl('class="turas-ai-callout turas-ai-exec"', html, fixed = TRUE))
  expect_true(grepl("AI-assisted key findings", html, fixed = TRUE))
  expect_false(grepl("Reviewed by research team", html, fixed = TRUE))
})

test_that("converts double newlines to paragraphs", {
  exec <- make_test_exec_summary(
    narrative = "First paragraph.\n\nSecond paragraph.\n\nThird."
  )
  config <- list(exec_summary_reviewed = TRUE)

  html <- build_ai_exec_summary(exec, config)

  expect_true(grepl("<p>First paragraph.</p>", html, fixed = TRUE))
  expect_true(grepl("<p>Second paragraph.</p>", html, fixed = TRUE))
  expect_true(grepl("<p>Third.</p>", html, fixed = TRUE))
})

test_that("returns empty string for NULL summary", {
  expect_equal(build_ai_exec_summary(NULL, list()), "")
})

test_that("returns empty string for empty narrative", {
  exec <- make_test_exec_summary(narrative = "")
  expect_equal(build_ai_exec_summary(exec, list()), "")
})

# ==============================================================================
# TESTS: build_ai_methodology_note
# ==============================================================================

context("build_ai_methodology_note")

test_that("includes model name in reviewed variant", {
  config <- list(exec_summary_reviewed = TRUE)
  html <- build_ai_methodology_note(config, "Claude Sonnet 4 (Anthropic)")

  expect_true(grepl("Claude Sonnet 4 (Anthropic)", html, fixed = TRUE))
  expect_true(grepl("reviewed by the research team", html, fixed = TRUE))
  expect_true(grepl('class="turas-ai-methodology-note"', html, fixed = TRUE))
})

test_that("includes model name in unreviewed variant", {
  config <- list(exec_summary_reviewed = FALSE)
  html <- build_ai_methodology_note(config, "GPT-4.1 (OpenAI)")

  expect_true(grepl("GPT-4.1 (OpenAI)", html, fixed = TRUE))
  expect_false(grepl("reviewed by the research team", html, fixed = TRUE))
})

test_that("handles NULL model name gracefully", {
  config <- list(exec_summary_reviewed = TRUE)
  html <- build_ai_methodology_note(config, NULL)

  expect_true(grepl("AI model", html, fixed = TRUE))
})

# ==============================================================================
# TESTS: build_ai_toggle_control
# ==============================================================================

context("build_ai_toggle_control")

test_that("renders toggle with checkbox", {
  html <- build_ai_toggle_control()

  expect_true(grepl('class="ai-toggle"', html, fixed = TRUE))
  expect_true(grepl('type="checkbox"', html, fixed = TRUE))
  expect_true(grepl("checked", html, fixed = TRUE))
  expect_true(grepl("toggleAllCallouts", html, fixed = TRUE))
})

# ==============================================================================
# TESTS: build_ai_callout_css
# ==============================================================================

context("build_ai_callout_css")

test_that("CSS contains all required class selectors", {
  css <- build_ai_callout_css()

  expect_true(grepl(".turas-commentary", css, fixed = TRUE))
  expect_true(grepl(".turas-insight-exec", css, fixed = TRUE))
  expect_true(grepl(".turas-ai-callout", css, fixed = TRUE))
  expect_true(grepl(".ai-callout-header", css, fixed = TRUE))
  expect_true(grepl(".ai-callout-pin", css, fixed = TRUE))
  expect_true(grepl(".ai-callout-caveat", css, fixed = TRUE))
  expect_true(grepl(".ai-toggle", css, fixed = TRUE))
  expect_true(grepl(".turas-ai-methodology-note", css, fixed = TRUE))
})

test_that("CSS contains print media query", {
  css <- build_ai_callout_css()

  expect_true(grepl("@media print", css, fixed = TRUE))
  expect_true(grepl('data-pinned="true"', css, fixed = TRUE))
})

test_that("CSS handles confidence levels", {
  css <- build_ai_callout_css()

  expect_true(grepl('data-confidence="medium"', css, fixed = TRUE))
  expect_true(grepl('data-confidence="low"', css, fixed = TRUE))
})

# ==============================================================================
# TESTS: build_ai_insights_js
# ==============================================================================

context("build_ai_insights_js")

test_that("JS contains toggle and pin functions", {
  js <- build_ai_insights_js()

  expect_true(grepl("toggleAllCallouts", js, fixed = TRUE))
  expect_true(grepl("toggleCalloutPin", js, fixed = TRUE))
})

# ==============================================================================
# TESTS: Internal helpers
# ==============================================================================

context("AI rendering helpers")

test_that("escape_html handles special characters", {
  expect_equal(escape_html("a & b"), "a &amp; b")
  expect_equal(escape_html("<script>"), "&lt;script&gt;")
  expect_equal(escape_html('say "hello"'), 'say &quot;hello&quot;')
})

test_that("escape_html handles NULL and empty", {
  expect_equal(escape_html(NULL), "")
  expect_equal(escape_html(""), "")
})

test_that("narrative_to_paragraphs splits on double newlines", {
  result <- narrative_to_paragraphs("First.\n\nSecond.\n\nThird.")
  expect_equal(result, "<p>First.</p>\n<p>Second.</p>\n<p>Third.</p>")
})

test_that("narrative_to_paragraphs handles single paragraph", {
  result <- narrative_to_paragraphs("Just one paragraph.")
  expect_equal(result, "<p>Just one paragraph.</p>")
})

test_that("narrative_to_paragraphs handles empty string", {
  expect_equal(narrative_to_paragraphs(""), "")
})

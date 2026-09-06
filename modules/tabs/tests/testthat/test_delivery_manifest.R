# ==============================================================================
# TESTS: delivery manifest (modules/tabs/lib/delivery_manifest.R)
# ==============================================================================
# The manifest is the thing that stops a build shipping quietly. These tests hold
# it to that: it must always say whether respondent records are in the file, and
# it must never claim a protection the build is not applying.
# ==============================================================================

if (!exists("tabs_delivery_manifest", mode = "function")) {
  source(file.path(rprojroot::find_root(rprojroot::has_dir("modules")),
                   "modules", "tabs", "lib", "delivery_manifest.R"))
}

micro_fixture <- function(n = 600) {
  list(n = n, answers = list(Q1 = rep(0L, n)), weights = rep(1, n))
}

joined <- function(m) paste(m$lines, collapse = "\n")


test_that("a build carrying microdata says so, with the count", {
  m <- tabs_delivery_manifest(micro_fixture(600), NULL, list())
  expect_true(m$microdata)
  expect_true(m$restricted)
  expect_equal(m$n, 600L)
  expect_match(joined(m), "Respondent-level records\\s*: YES \\(600 de-identified records\\)")
  expect_match(joined(m), "Row-level weights\\s*: YES")
  expect_match(joined(m), "coded answers and weights")
  expect_match(joined(m), "html_report_v2_microdata = FALSE")
})


test_that("the confidentiality ship says so, and makes no restricted claim", {
  m <- tabs_delivery_manifest(NULL, NULL, list())
  expect_false(m$microdata)
  expect_false(m$restricted)
  expect_true(is.na(m$n))
  expect_match(joined(m), "Respondent-level records\\s*: NO")
  expect_match(joined(m), "Row-level weights\\s*: NO")
  expect_match(joined(m), "published figures only")
  # The records paragraph belongs only to a build that earns it.
  expect_false(grepl("coded answers and weights", joined(m)))
})


test_that("min_reporting_base is reported, and its on-screen-only limit is named", {
  m_set <- tabs_delivery_manifest(micro_fixture(), NULL, list(min_reporting_base = 5))
  expect_match(joined(m_set), "Minimum reporting base\\s*: 5")
  expect_match(joined(m_set), "hides sub-k cells ON SCREEN")

  m_unset <- tabs_delivery_manifest(micro_fixture(), NULL, list())
  expect_match(joined(m_unset), "Minimum reporting base\\s*: not set")
  expect_false(grepl("ON SCREEN", joined(m_unset)))

  # k = 1 is off, not a threshold of one.
  m_one <- tabs_delivery_manifest(NULL, NULL, list(min_reporting_base = 1))
  expect_match(joined(m_one), "Minimum reporting base\\s*: not set")
})


test_that("a build with no comment tab makes no claim about verbatims", {
  for (empty in list(NULL, "", "null")) {
    m <- tabs_delivery_manifest(NULL, empty, list(qual_confidentiality_mode = "full"))
    expect_match(joined(m), "no comment tab in this build")
    expect_match(joined(m), "Comment demographic tags\\s*: not applicable")
  }
})


test_that("each verbatim confidentiality mode is described as what it does", {
  q <- '{"questions":[]}'
  expect_match(joined(tabs_delivery_manifest(NULL, q, list(qual_confidentiality_mode = "full"))),
               "FULL text in the file")
  expect_match(joined(tabs_delivery_manifest(NULL, q, list(qual_confidentiality_mode = "redacted"))),
               "direct identifiers scrubbed")
  expect_match(joined(tabs_delivery_manifest(NULL, q, list(qual_confidentiality_mode = "hidden"))),
               "no text in the file")
  # Unset defaults to hidden, matching qual_island_builder.R.
  expect_match(joined(tabs_delivery_manifest(NULL, q, list())), "no text in the file")
})


test_that("demographic tags: 'safe' without a k is reported as raw, not as safe", {
  q <- '{"questions":[]}'
  # This mirrors the engine: qual_island_builder downgrades 'safe' to 'allow'
  # when min_reporting_base is unset, because there is nothing to anonymise
  # against. The manifest must not print a protection the build is not applying.
  m_bad <- tabs_delivery_manifest(NULL, q, list(qual_demographic_cuts = "safe"))
  expect_match(joined(m_bad), "declared safe but k is unset")

  m_good <- tabs_delivery_manifest(NULL, q, list(qual_demographic_cuts = "safe",
                                                 min_reporting_base = 10))
  expect_match(joined(m_good), "k-anonymised against k=10")

  m_block <- tabs_delivery_manifest(NULL, q, list(qual_demographic_cuts = "block"))
  expect_match(joined(m_block), "comments carry no demographics")

  m_allow <- tabs_delivery_manifest(NULL, q, list(qual_demographic_cuts = "allow"))
  expect_match(joined(m_allow), "every tag ships")
})


test_that("the manifest never claims direct identifiers are absent by accident", {
  # It is a fixed statement of what the island format is, and it must hold for
  # both ships, because it is the one reassuring line a client may be shown.
  expect_match(joined(tabs_delivery_manifest(micro_fixture(), NULL, list())),
               "indices only, never IDs or raw text")
})


test_that("the file name is carried when known, and omitted when not", {
  m <- tabs_delivery_manifest(NULL, NULL, list(), "/a/b/SACS_Crosstabs_report.html")
  expect_match(joined(m), "File: SACS_Crosstabs_report.html", fixed = TRUE)
  expect_false(grepl("File:", joined(tabs_delivery_manifest(NULL, NULL, list()))))
})


test_that("a NULL config and a missing n do not break the manifest", {
  expect_silent(m <- tabs_delivery_manifest(NULL, NULL, NULL))
  expect_match(joined(m), "Respondent-level records\\s*: NO")
  m2 <- tabs_delivery_manifest(list(answers = list()), NULL, NULL)
  expect_true(m2$microdata)
  expect_match(joined(m2), "count unknown")
  expect_match(joined(m2), "Row-level weights\\s*: NO")
})


test_that("the printer emits the lines and returns the manifest invisibly", {
  out <- capture.output(res <- tabs_print_delivery_manifest(micro_fixture(12), NULL, list()))
  expect_true(any(grepl("TURAS DELIVERY MANIFEST", out)))
  expect_true(any(grepl("YES \\(12 de-identified records\\)", out)))
  expect_true(res$microdata)
})


# -- tabs_microdata_wanted(): the GUI's client-safe choice decides the build ---

test_that("microdata is wanted by default, with no reason recorded", {
  d <- tabs_microdata_wanted(list(html_report_v2_microdata = TRUE), client_safe = FALSE)
  expect_true(d$wanted)
  expect_true(is.na(d$reason))
  d <- tabs_microdata_wanted(list(), client_safe = FALSE)
  expect_true(d$wanted)
})

test_that("the config switch turns the island off and says so", {
  d <- tabs_microdata_wanted(list(html_report_v2_microdata = FALSE), client_safe = FALSE)
  expect_false(d$wanted)
  expect_identical(d$reason, "config")
})

test_that("the GUI client-safe choice turns the island off even when the config says TRUE", {
  d <- tabs_microdata_wanted(list(html_report_v2_microdata = TRUE), client_safe = TRUE)
  expect_false(d$wanted)
  expect_identical(d$reason, "gui")
})

test_that("both switches off reports the config, the earlier decision", {
  d <- tabs_microdata_wanted(list(html_report_v2_microdata = FALSE), client_safe = TRUE)
  expect_false(d$wanted)
  expect_identical(d$reason, "config")
})

test_that("the default client_safe argument reads the GUI global and is FALSE when unset", {
  if (exists("TURAS_DELIVERY_CLIENT_SAFE", envir = .GlobalEnv)) {
    rm("TURAS_DELIVERY_CLIENT_SAFE", envir = .GlobalEnv)
  }
  expect_true(tabs_microdata_wanted(list(html_report_v2_microdata = TRUE))$wanted)
  assign("TURAS_DELIVERY_CLIENT_SAFE", TRUE, envir = .GlobalEnv)
  on.exit(rm("TURAS_DELIVERY_CLIENT_SAFE", envir = .GlobalEnv), add = TRUE)
  expect_false(tabs_microdata_wanted(list(html_report_v2_microdata = TRUE))$wanted)
})

# ---- The GUI's delivery mode against the config's own -------------------------
# Two places have an opinion about what a run builds. The rule is that the GUI
# sets a FLOOR of protection and can never lower one, so "Full report" cannot
# turn an aggregates project back into a respondent-level file, and a
# client-safe choice can no longer throw an aggregate build away.

test_that("no GUI choice leaves the config's mode exactly as it is", {
  for (m in c("records", "cube", "none")) {
    r <- tabs_delivery_interactivity(
      list(html_report_v2_interactivity = m, min_reporting_base = 5), NA_character_)
    expect_equal(r$mode, m, info = m)
    expect_equal(r$reason, "config", info = m)
  }
})

test_that("Full report is a permission, not an instruction", {
  # The failure this prevents: a project deliberately configured to ship
  # aggregates starts shipping respondent records because someone picked the
  # top radio button.
  r <- tabs_delivery_interactivity(
    list(html_report_v2_interactivity = "cube", min_reporting_base = 5), "full")
  expect_equal(r$mode, "cube")
  expect_true(r$client_safe)
  r2 <- tabs_delivery_interactivity(
    list(html_report_v2_interactivity = "records", min_reporting_base = 5), "full")
  expect_equal(r2$mode, "records")
  expect_false(r2$client_safe)
})

test_that("client safe interactive raises records to cube and keeps a cube", {
  r <- tabs_delivery_interactivity(
    list(html_report_v2_interactivity = "records", min_reporting_base = 5),
    "client_safe_interactive")
  expect_equal(r$mode, "cube")
  expect_equal(r$reason, "gui")
  expect_true(r$client_safe)
  # The bug this replaces: a cube config collapsed all the way to `none`.
  r2 <- tabs_delivery_interactivity(
    list(html_report_v2_interactivity = "cube", min_reporting_base = 5),
    "client_safe_interactive")
  expect_equal(r2$mode, "cube")
  expect_true(r2$client_safe)
})

test_that("client safe frozen is always published tables", {
  for (m in c("records", "cube", "none")) {
    r <- tabs_delivery_interactivity(
      list(html_report_v2_interactivity = m, min_reporting_base = 5),
      "client_safe_frozen")
    expect_equal(r$mode, "none", info = m)
    expect_true(r$client_safe, info = m)
  }
})

test_that("a stricter config is never loosened by a GUI choice", {
  r <- tabs_delivery_interactivity(
    list(html_report_v2_interactivity = "none", min_reporting_base = 5),
    "client_safe_interactive")
  expect_equal(r$mode, "none")
  expect_equal(r$reason, "config")
})

test_that("an interactive client-safe build with no threshold drops to frozen", {
  # A cube with no k protects nothing, so it must not be built under a name
  # that reads as protected. `none` is strictly safer and still honours the
  # choice; the caller says so on the console.
  r <- tabs_delivery_interactivity(
    list(html_report_v2_interactivity = "records"), "client_safe_interactive")
  expect_equal(r$mode, "none")
  expect_equal(r$reason, "needs_k")
  expect_true(r$client_safe)
  r2 <- tabs_delivery_interactivity(
    list(html_report_v2_interactivity = "records", min_reporting_base = 1),
    "client_safe_interactive")
  expect_equal(r2$mode, "none")
  expect_equal(r2$reason, "needs_k")
})

test_that("the retired microdata switch still wins where it is explicitly off", {
  r <- tabs_delivery_interactivity(
    list(html_report_v2_microdata = FALSE,
         html_report_v2_interactivity = "records", min_reporting_base = 5), "full")
  expect_equal(r$mode, "none")
  expect_true(r$client_safe)
})

test_that("the two-option GUI's old value still means frozen", {
  # An older caller passing "client_safe" must not silently start shipping
  # something different from what it shipped before.
  r <- tabs_delivery_interactivity(
    list(html_report_v2_interactivity = "cube", min_reporting_base = 5), "client_safe")
  expect_equal(r$mode, "none")
})

test_that("every mode the resolver returns is one the build knows how to make", {
  modes <- character(0)
  for (cm in c("records", "cube", "none")) {
    for (g in c(NA_character_, "full", "client_safe_interactive",
                "client_safe_frozen", "client_safe")) {
      modes <- c(modes, tabs_delivery_interactivity(
        list(html_report_v2_interactivity = cm, min_reporting_base = 5), g)$mode)
    }
  }
  expect_true(all(modes %in% c("records", "cube", "none")))
  # And client_safe is true for exactly the non-records modes.
  for (cm in c("records", "cube", "none")) {
    for (g in c(NA_character_, "full", "client_safe_interactive", "client_safe_frozen")) {
      r <- tabs_delivery_interactivity(
        list(html_report_v2_interactivity = cm, min_reporting_base = 5), g)
      expect_equal(r$client_safe, !identical(r$mode, "records"),
                   info = paste(cm, g))
    }
  }
})


# ==============================================================================
# THE QUALITATIVE FLOOR
# ==============================================================================
# The interactivity floor above decides whether respondent RECORDS ship. These
# decide what the COMMENT island carries, which was left entirely to the config
# until a review of the SACS 2025 client-safe build found 57 of its 144 tagged
# commenters were the only person in their Campus, Department and Tenure
# combination. A file whose crosstabs refuse any group under ten was naming
# individuals in its comment payload.

qd <- function(cuts = NULL, text = NULL, k = 10, gui = NA_character_) {
  cfg <- list(min_reporting_base = k)
  if (!is.null(cuts)) cfg$qual_demographic_cuts <- cuts
  if (!is.null(text)) cfg$qual_confidentiality_mode <- text
  tabs_delivery_qual_dials(cfg, gui)
}

test_that("no GUI choice leaves both qualitative dials exactly as they are", {
  for (c0 in c("allow", "safe", "block")) {
    for (t0 in c("full", "redacted", "hidden")) {
      r <- qd(c0, t0)
      expect_equal(r$cuts, c0, info = paste(c0, t0))
      expect_equal(r$text_mode, t0, info = paste(c0, t0))
      expect_equal(r$reason, "config", info = paste(c0, t0))
    }
  }
})

test_that("client safe interactive k-anonymises the tags rather than blocking them", {
  # `safe` and not `block`: this mode's promise is that the comments follow the
  # filter, and blocking the tags withdraws it.
  r <- qd("allow", "redacted", gui = "client_safe_interactive")
  expect_equal(r$cuts, "safe")
  expect_equal(r$reason, "gui")
  expect_equal(r$config_cuts, "allow")
})

test_that("a stricter config dial is never lowered by a client safe choice", {
  r <- qd("block", "hidden", gui = "client_safe_interactive")
  expect_equal(r$cuts, "block")
  expect_equal(r$text_mode, "hidden")
  expect_equal(r$reason, "config")
})

test_that("full report is a permission, so it floors neither dial", {
  r <- qd("allow", "full", gui = "full")
  expect_equal(r$cuts, "allow")
  expect_equal(r$text_mode, "full")
})

test_that("a client safe build never ships raw verbatim text", {
  # Direct identifiers only. A curated excerpt is the point of the tab; an email
  # address inside it is not.
  for (g in c("client_safe_interactive", "client_safe_frozen")) {
    r <- qd("safe", "full", gui = g)
    expect_equal(r$text_mode, "redacted", info = g)
  }
  # And a hidden config stays hidden.
  expect_equal(qd("safe", "hidden", gui = "client_safe_frozen")$text_mode, "hidden")
})

test_that("client safe frozen blocks the tags, which serve no reader there", {
  # Nothing in a frozen file can filter, so a demographic tag on a comment is
  # exposure with no function.
  r <- qd("allow", "redacted", gui = "client_safe_frozen")
  expect_equal(r$cuts, "block")
  expect_equal(r$reason, "gui")
  # The retired two-option value behaves as the frozen choice, as it does for
  # interactivity.
  expect_equal(qd("allow", "redacted", gui = "client_safe")$cuts, "block")
})

test_that("safe without a threshold blocks the tags instead of promising nothing", {
  # `safe` is a promise about k. Without one the island ships raw tags, so the
  # floor takes the strictly safer branch and says which it took.
  for (k in list(NULL, NA, 1, 0)) {
    r <- tabs_delivery_qual_dials(
      list(qual_demographic_cuts = "allow", min_reporting_base = k),
      "client_safe_interactive")
    expect_equal(r$cuts, "block", info = paste("k =", format(k)))
    expect_equal(r$reason, "needs_k", info = paste("k =", format(k)))
  }
})

test_that("an unset or unknown dial resolves to the island builder's own default", {
  r <- tabs_delivery_qual_dials(list(min_reporting_base = 10), NA_character_)
  expect_equal(r$cuts, "allow")        # qual_build_data_qual's default
  expect_equal(r$text_mode, "hidden")  # and its safe default for text
  r2 <- tabs_delivery_qual_dials(
    list(qual_demographic_cuts = "Nonsense", qual_confidentiality_mode = "",
         min_reporting_base = 10), NA_character_)
  expect_equal(r2$cuts, "allow")
  expect_equal(r2$text_mode, "hidden")
})

test_that("the floor is written back so every reader sees one set of values", {
  cfg <- list(qual_demographic_cuts = "allow", qual_confidentiality_mode = "full",
              min_reporting_base = 10)
  out <- tabs_apply_qual_floor(cfg, tabs_delivery_qual_dials(cfg, "client_safe_interactive"))
  expect_equal(out$qual_demographic_cuts, "safe")
  expect_equal(out$qual_confidentiality_mode, "redacted")
  # The manifest reads the config, so it now describes what the file carries.
  m <- tabs_delivery_manifest(NULL, "{\"questions\":[]}", out)
  expect_match(joined(m), "k-anonymised against k=10")
  expect_match(joined(m), "direct identifiers scrubbed")
})


test_that("the run applies the qualitative floor before it builds the comment island", {
  # A floor nobody calls is the failure this layer exists to prevent, and the
  # unit tests above would all still pass with the call deleted. Nothing in the
  # suite sets TURAS_DELIVERY_MODE and runs the pipeline, so this reads the
  # source and checks the call is there and in the right ORDER. It is a wiring
  # check, not a behaviour one: it cannot tell you the floor is correct, only
  # that the island is not built ahead of it.
  path <- file.path(rprojroot::find_root(rprojroot::has_dir("modules")),
                    "modules", "tabs", "lib", "run_crosstabs.R")
  src <- readLines(path, warn = FALSE)
  resolve <- grep("tabs_delivery_qual_dials\\(", src)
  apply_it <- grep("tabs_apply_qual_floor\\(", src)
  island <- grep("build_integrated_qual_island\\(", src)
  expect_true(length(resolve) >= 1)
  expect_true(length(apply_it) >= 1)
  expect_true(length(island) >= 1)
  expect_lt(max(resolve), min(apply_it))
  expect_lt(max(apply_it), min(island))
})

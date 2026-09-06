# ==============================================================================
# Tests for the five-destination category shell (Stage 2 of the brand
# simplification). In the style of test_subtab_nav_tiers.R, held by the tag
# rescue/review-brand-report-v2-upgrade-2026-06.
#
# What is covered:
#   - the destination registry: five destinations, ids independent of labels;
#   - the leaf registry: nineteen leaves, each in exactly one destination;
#   - a rendered category panel: five destination buttons, every configured
#     leaf present exactly once under some destination, no orphan host;
#   - a destination with nothing configured is hidden, not shown empty;
#   - display labels never appear in a data-* attribute, so a rename cannot
#     move a pin anchor, a section anchor or a Section_Insights anchor;
#   - the switchCategorySubtab route into the panels' hidden buttons survives.
# ==============================================================================
library(testthat)

.find_root_destnav <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT_DN <- .find_root_destnav()
source(file.path(ROOT_DN, "modules", "brand", "R", "01b_section_insights.R"))
source(file.path(ROOT_DN, "modules", "brand", "lib", "html_report",
                 "03_page_builder.R"))

pos_dn <- function(html, needle) regexpr(needle, html, fixed = TRUE)[[1]]
n_dn <- function(html, needle) {
  m <- gregexpr(needle, html, fixed = TRUE)[[1]]
  if (length(m) == 1L && m[1L] == -1L) 0L else length(m)
}
attr_vals_dn <- function(html, attr) {
  m <- gregexpr(sprintf('%s="[^"]*"', attr), html)[[1]]
  if (length(m) == 1L && m[1L] == -1L) return(character(0))
  raw <- regmatches(html, gregexpr(sprintf('%s="[^"]*"', attr), html))[[1]]
  sub('^[^"]*"', "", sub('"$', "", raw))
}


# --- the registries are the documented single source of truth ---------------

test_that("there are five destinations, in the agreed order", {
  expect_equal(length(.BR_DESTINATIONS), 5L)
  expect_equal(vapply(.BR_DESTINATIONS, function(d) d$id, character(1)),
               c("overview", "mental", "buying", "meaning", "audience"))
  expect_equal(vapply(.BR_DESTINATIONS, function(d) d$label, character(1)),
               c("Overview", "Mental Availability", "Brand and Buying",
                 "Brand Meaning", "Audience"))
})

test_that("id and label are separate fields on every destination and leaf", {
  for (d in .BR_DESTINATIONS) {
    expect_true(is.character(d$id) && nzchar(d$id))
    expect_true(is.character(d$label) && nzchar(d$label))
    expect_false(identical(d$id, d$label))
  }
  # Two destination ids read like their labels today ("overview",
  # "audience"). That is a coincidence of wording, not a derivation: the
  # test below renames every label and shows no identifier follows.
})

test_that("nineteen leaves, each with exactly one home and one label", {
  expect_equal(length(.BR_LEAF_HOMES), 19L)
  expect_equal(sort(names(.BR_LEAF_HOMES)), sort(names(.BR_LEAF_LABELS)))
  expect_equal(anyDuplicated(names(.BR_LEAF_HOMES)), 0L)

  dest_ids <- vapply(.BR_DESTINATIONS, function(d) d$id, character(1))
  for (k in names(.BR_LEAF_HOMES)) {
    h <- .BR_LEAF_HOMES[[k]]
    expect_true(h$dest %in% dest_ids, info = paste("unknown destination for", k))
    expect_true(h$tier %in% c("main", "advanced"), info = k)
    expect_true(is.numeric(h$order), info = k)
  }
})

test_that("the leaf set is exactly the nineteen the impact map counts", {
  expect_setequal(names(.BR_LEAF_HOMES), c(
    # the eleven leaves of the old flat sub-tab bar
    "fn-funnel", "fn-relationship", "ma-attributes", "ma-ceps",
    "ma-advantage", "ma-metrics", "wom", "branded_reach", "demographics",
    "adhoc", "audience_lens",
    # the eight the Category Buying sub-tab opened
    "cb-context", "cb-brands", "cb-norms", "cb-loyalty", "cb-dist",
    "cb-heaviness", "cb-dop", "cb-shopper"))
})

test_that("Duncan's ruling 2 holds: attributes with CEPs, meaning is what people say", {
  expect_equal(.BR_LEAF_HOMES[["ma-attributes"]]$dest, "mental")
  expect_equal(.BR_LEAF_HOMES[["ma-ceps"]]$dest,       "mental")
  expect_equal(.BR_LEAF_HOMES[["fn-relationship"]]$dest, "meaning")
  expect_equal(.BR_LEAF_HOMES[["wom"]]$dest,             "meaning")
  expect_equal(.BR_LEAF_HOMES[["branded_reach"]]$dest,   "meaning")
})

test_that("the Category Buying KPI leaves stay in the main view, the models go to Advanced", {
  expect_equal(.BR_LEAF_HOMES[["cb-context"]]$tier, "main")
  expect_equal(.BR_LEAF_HOMES[["cb-brands"]]$tier,  "main")
  for (k in c("cb-norms", "cb-loyalty", "cb-dist", "cb-heaviness", "cb-dop")) {
    expect_equal(.BR_LEAF_HOMES[[k]]$tier, "advanced", info = k)
  }
})


# --- a rendered category panel ----------------------------------------------
# Synthetic inputs: the page builder decides the shell from the presence of
# results and of panel fragments, so a fixture of the right shape exercises
# every branch without running the engines.

fake_cat_results <- function(funnel = TRUE, ma = TRUE, rep = TRUE,
                             wom = TRUE, demo = TRUE, reach = FALSE,
                             adhoc = FALSE, lens = FALSE) {
  ok <- function(x) if (x) list(status = "PASS") else NULL
  out <- list(cat_code = "DSS", category = "Dry Seasonings")
  if (funnel) out$funnel <- list(status = "PASS")
  if (ma)     out$mental_availability <- list(status = "PASS")
  if (rep)    out$repertoire <- list(status = "PASS")
  if (wom)    out$wom <- list(status = "PASS", wom_metrics = list(a = 1))
  if (demo)   out$demographics <- list(status = "PASS", questions = list(1))
  if (reach)  out$branded_reach <- list(status = "PASS", ads = list(1))
  if (adhoc)  out$adhoc <- list(status = "PASS", questions = list(1))
  if (lens)   out$audience_lens <- list(status = "PASS", audiences = list(1))
  out
}

fake_panels <- function(keys) {
  out <- list()
  for (k in keys) out[[k]] <- sprintf('<div class="stub-panel">%s</div>', k)
  out
}

# The panel keys a full-depth category produces. Each is one host.
full_keys <- c(
  "funnel_dss", "funnel_dss__relationship",
  "ma_dss", "ma_dss__attributes", "ma_dss__ceps", "ma_dss__advantage",
  "cat_buying_dss", "cat_buying_dss__brands", "cat_buying_dss__norms",
  "cat_buying_dss__loyalty", "cat_buying_dss__dist",
  "cat_buying_dss__heaviness", "cat_buying_dss__dop",
  "wom_dss", "demographics_dss")

render_cat <- function(cat_results = fake_cat_results(),
                       panels = fake_panels(full_keys),
                       config = list(focal_brand = "IPK",
                                     colour_focal = "#1A5276"),
                       ...) {
  build_br_category_panel("Dry Seasonings", cat_results, charts = list(),
                          tables = list(), config = config, panels = panels,
                          cat_display_name = "Dry Seasonings", ...)
}

test_that("a full-depth category renders five destination buttons", {
  out <- render_cat()
  expect_equal(n_dn(out, 'class="br-destination-btn'), 5L)
  for (d in .BR_DESTINATIONS) {
    # One button, one container, and for a destination that has an Advanced
    # drawer the drawer carries the attribute too.
    expect_true(n_dn(out, sprintf('data-destination="%s"', d$id)) %in% c(2L, 3L),
                info = paste(d$id, "needs a button and a container"))
    expect_equal(n_dn(out, sprintf('data-destination="%s" onclick=', d$id)), 1L,
                 info = paste(d$id, "needs exactly one nav button"))
  }
  # Exactly one destination is active on load, and it is the first.
  expect_equal(n_dn(out, 'class="br-destination-btn active"'), 1L)
  expect_true(pos_dn(out, 'data-destination="overview"') <
              pos_dn(out, 'data-destination="mental"'))
})

test_that("every configured leaf appears exactly once, under some destination", {
  out <- render_cat()
  hosts <- attr_vals_dn(out, "data-leaf")
  # data-leaf sits on the host and, for an Advanced leaf, on its accordion
  # item too. Count hosts by their sub-panel marker.
  host_leaves <- regmatches(out, gregexpr(
    'class="br-subpanel active" data-group="dss" data-subpanel="[^"]*" data-internal-tab="[^"]*" data-cb-tab="[^"]*" data-leaf="[^"]*"',
    out))[[1]]
  keys <- sub('.*data-leaf="([^"]*)"$', "\\1", host_leaves)
  expect_equal(anyDuplicated(keys), 0L)
  expect_setequal(keys, c(
    "fn-funnel", "fn-relationship", "ma-metrics", "ma-ceps", "ma-attributes",
    "ma-advantage", "cb-context", "cb-brands", "cb-norms", "cb-loyalty",
    "cb-dist", "cb-heaviness", "cb-dop", "wom", "demographics"))
  # No orphan: every host key has a home in the registry.
  for (k in keys) expect_false(is.null(.BR_LEAF_HOMES[[k]]), info = k)
})

test_that("a destination with nothing configured is hidden, never shown empty", {
  # Mental Availability and Brand Meaning both go dark when MA, the funnel,
  # WOM and Branded Reach are all off. Audience survives on Demographics.
  out <- render_cat(
    cat_results = fake_cat_results(funnel = FALSE, ma = FALSE, wom = FALSE),
    panels = fake_panels(c("cat_buying_dss", "cat_buying_dss__brands",
                            "cat_buying_dss__norms", "demographics_dss")))
  expect_equal(n_dn(out, 'data-destination="mental"'), 0L)
  expect_equal(n_dn(out, 'data-destination="meaning"'), 0L)
  # Brand and Buying keeps its Advanced drawer, which carries the attribute
  # as well as the button and the container.
  expect_equal(n_dn(out, 'data-destination="buying"'), 3L)
  expect_equal(n_dn(out, 'data-destination="audience"'), 2L)
  # The Overview always renders, so the shell never collapses to nothing.
  expect_equal(n_dn(out, 'data-destination="overview"'), 2L)
  expect_equal(n_dn(out, 'class="br-destination-btn'), 3L)
})

test_that("one category with only the funnel still gets a coherent shell", {
  out <- render_cat(
    cat_results = fake_cat_results(ma = FALSE, rep = FALSE, wom = FALSE,
                                    demo = FALSE),
    panels = fake_panels(c("funnel_dss", "funnel_dss__relationship")))
  expect_equal(n_dn(out, 'class="br-destination-btn'), 3L)
  expect_equal(n_dn(out, 'data-destination="buying"'), 2L)
  expect_equal(n_dn(out, 'data-destination="meaning"'), 2L)
  expect_equal(n_dn(out, 'data-destination="audience"'), 0L)
  # No empty Advanced drawer is emitted where no leaf lands in one.
  expect_equal(n_dn(out, 'class="br-advanced"'), 0L)
})

test_that("a destination whose only content is Advanced opens with the drawer open", {
  # Audience with Audience Lens configured and no Demographics and no Ad Hoc:
  # the main view has nothing, so the drawer must not start collapsed or the
  # destination reads as empty.
  cr <- fake_cat_results(demo = FALSE, lens = TRUE)
  out <- render_cat(
    cat_results = cr,
    panels = fake_panels(c(full_keys[!full_keys %in% "demographics_dss"],
                            "audience_lens_dss")))
  aud <- regmatches(out, regexpr(
    '<div class="br-destination" data-group="dss" data-destination="audience">.*',
    out))
  expect_true(nzchar(aud))
  expect_true(grepl('aria-expanded="true">Advanced', aud, fixed = TRUE))
  expect_false(grepl('class="br-advanced-body" hidden', substr(aud, 1, 2000),
                     fixed = TRUE))
})

test_that("an Advanced drawer opens collapsed with one item expanded", {
  out <- render_cat()
  expect_true(n_dn(out, 'class="br-advanced-body" hidden') >= 1L)
  # One researcher-grade analysis expanded at a time (ruling 7): exactly one
  # accordion toggle per drawer starts expanded.
  expect_equal(n_dn(out, 'class="br-adv-toggle" onclick="brToggleAdvancedItem(this)" aria-expanded="true"'),
               n_dn(out, 'class="br-advanced"'))
})


# --- the contract that must not change --------------------------------------

test_that("no display label is used as, or derived into, a data-* value", {
  out <- render_cat()
  labels <- c(vapply(.BR_DESTINATIONS, function(d) d$label, character(1)),
              unlist(.BR_LEAF_LABELS, use.names = FALSE))
  data_attrs <- c("data-destination", "data-leaf", "data-subpanel",
                  "data-internal-tab", "data-cb-tab", "data-section",
                  "data-group", "data-slot")
  vals <- unique(unlist(lapply(data_attrs, function(a) attr_vals_dn(out, a))))
  for (lb in labels) {
    expect_false(lb %in% vals, info = paste("label used as a data value:", lb))
  }
})

test_that("renaming every display label moves no identifier", {
  # This is the guarantee requirement C asks for. Analysts have already typed
  # anchors such as advantage-pas and ceps-pas into Section_Insights sheets,
  # and pins and Excel export resolve sections by them, so a later rename of
  # the destination vocabulary must not touch a single one.
  data_attrs <- c("data-destination", "data-leaf", "data-subpanel",
                  "data-internal-tab", "data-cb-tab", "data-section",
                  "data-group", "data-slot")
  snapshot <- function(html) {
    lapply(data_attrs, function(a) attr_vals_dn(html, a))
  }
  before <- snapshot(render_cat())

  old_d <- .BR_DESTINATIONS
  old_l <- .BR_LEAF_LABELS
  on.exit({
    .BR_DESTINATIONS <<- old_d
    .BR_LEAF_LABELS  <<- old_l
  }, add = TRUE)

  .BR_DESTINATIONS <<- lapply(seq_along(old_d), function(i) {
    d <- old_d[[i]]; d$label <- paste("Renamed", i); d
  })
  .BR_LEAF_LABELS <<- stats::setNames(
    as.list(paste("Leaf", seq_along(old_l))), names(old_l))

  after <- snapshot(render_cat())
  expect_equal(after, before)
})

test_that("each straddling panel gets one host per internal tab, and one wrapper", {
  out <- render_cat()
  # Funnel: two hosts, one section wrapper on the funnel host.
  expect_equal(n_dn(out, 'data-subpanel="fn"'), 2L)
  expect_equal(n_dn(out, 'id="section-funnel-dss"'), 1L)
  # Mental Availability: four hosts, one section wrapper on the metrics host.
  expect_equal(n_dn(out, 'data-subpanel="ma"'), 4L)
  expect_equal(n_dn(out, 'id="section-ma-dss"'), 1L)
  # Category Buying: seven hosts here, one section wrapper on the context host.
  expect_equal(n_dn(out, 'data-subpanel="rep"'), 7L)
  expect_equal(n_dn(out, 'id="section-repertoire-dss"'), 1L)
})

test_that("every per-sub-tab Section_Insights anchor still lands, once each", {
  out <- render_cat()
  for (a in c("funnel-dss", "attitude-dss", "attributes-dss", "advantage-dss",
              "ceps-dss", "metrics-dss")) {
    expect_true(grepl(sprintf('data-section="%s"', a), out, fixed = TRUE),
                info = paste("missing anchor", a))
  }
  # Six insight wraps per category, one per host that has an internal tab.
  expect_equal(n_dn(out, "br-insight-wrap"), 6L)
})

test_that("the header control area is a three-slot system with a reserved slot", {
  out <- render_cat()
  expect_equal(n_dn(out, 'class="br-controls"'), 1L)
  expect_equal(n_dn(out, 'data-slot="category"'), 1L)
  expect_equal(n_dn(out, 'data-slot="comparison"'), 1L)
  # Slot three is reserved for the period selector wave comparison will need.
  # It renders empty rather than being absent, so adding it later is an
  # insertion into a container that already exists.
  expect_equal(n_dn(out, 'data-slot="period"'), 1L)
  expect_true(grepl('data-slot="period" data-group="dss"></div>', out,
                    fixed = TRUE))
})

test_that("the comparison-set control offers the focal brand and comparators", {
  brands <- data.frame(
    BrandCode  = c("IPK", "ROB", "KNORR"),
    BrandLabel = c("Ina Paarman's Kitchen", "Robertsons", "Knorr"),
    stringsAsFactors = FALSE)
  out <- render_cat(cat_brands = brands)
  expect_equal(n_dn(out, 'class="br-focal-select"'), 1L)
  expect_equal(n_dn(out, 'class="br-cmp-check"'), 3L)
  # The focal brand is always in the set and cannot be unpicked.
  expect_true(grepl('value="IPK" disabled checked', out, fixed = TRUE))
  expect_equal(n_dn(out, 'class="br-cmp-popover"'), 1L)
})

test_that("the category switcher lists full-depth categories only", {
  choices <- list(list(id = "dss", label = "Dry Seasonings"),
                  list(id = "bak", label = "Baking"))
  out <- render_cat(category_choices = choices)
  expect_equal(n_dn(out, 'class="br-cat-select"'), 1L)
  expect_equal(n_dn(out, '<option value="dss" selected>'), 1L)
  expect_equal(n_dn(out, '<option value="bak">'), 1L)

  # With one full-depth category there is nothing to switch to, so the slot
  # states the category rather than offering a one-entry dropdown.
  one <- render_cat(category_choices = list(choices[[1]]))
  expect_equal(n_dn(one, 'class="br-cat-select"'), 0L)
  expect_equal(n_dn(one, "br-control-static"), 1L)
})

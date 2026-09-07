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
# The authored-insight number check: Stage 5 made the leaf commentary box
# conditional, and a flagged insight is one of the two things that still
# renders it, so the marker builder is sourced here rather than skipped.
source(file.path(ROOT_DN, "modules", "brand", "lib", "html_report",
                 "03b_insight_number_check.R"))

pos_dn <- function(html, needle) regexpr(needle, html, fixed = TRUE)[[1]]
n_dn <- function(html, needle) {
  m <- gregexpr(needle, html, fixed = TRUE)[[1]]
  if (length(m) == 1L && m[1L] == -1L) 0L else length(m)
}
# How many CONTAINERS a destination has: the destination div itself, plus its
# Advanced drawer where it has one. Stage 5 put a toolbar and a "How this
# works" drawer inside every view and both carry data-destination, so a raw
# count of the attribute no longer measures the shell. These two count the
# structure instead, and the toolbars are asserted on their own below.
n_dest_containers <- function(html, id) {
  n_dn(html, sprintf('data-destination="%s">', id))
}
n_dest_buttons <- function(html, id) {
  n_dn(html, sprintf('data-destination="%s" onclick=', id))
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
    expect_true(n_dest_containers(out, d$id) %in% c(1L, 2L),
                info = paste(d$id, "needs a container, and a drawer or not"))
    expect_equal(n_dest_buttons(out, d$id), 1L,
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
  # as well as the container.
  expect_equal(n_dest_containers(out, "buying"), 2L)
  expect_equal(n_dest_buttons(out, "buying"), 1L)
  expect_equal(n_dest_containers(out, "audience"), 1L)
  # The Overview always renders, so the shell never collapses to nothing.
  expect_equal(n_dest_containers(out, "overview"), 1L)
  expect_equal(n_dn(out, 'class="br-destination-btn'), 3L)
})

test_that("one category with only the funnel still gets a coherent shell", {
  out <- render_cat(
    cat_results = fake_cat_results(ma = FALSE, rep = FALSE, wom = FALSE,
                                    demo = FALSE),
    panels = fake_panels(c("funnel_dss", "funnel_dss__relationship")))
  expect_equal(n_dn(out, 'class="br-destination-btn'), 3L)
  expect_equal(n_dest_containers(out, "buying"), 1L)
  expect_equal(n_dest_containers(out, "meaning"), 1L)
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

test_that("a closed Advanced drawer opens on its list of titles", {
  out <- render_cat()
  expect_true(n_dn(out, 'class="br-advanced-body" hidden') >= 1L)
  # A drawer that starts closed has nothing expanded inside it, so opening
  # it shows the reader the titles and lets them choose. The drawer that
  # starts open, because its destination has no main view, is the exception
  # and is covered by its own test above.
  expect_equal(
    n_dn(out, 'class="br-adv-toggle" onclick="brToggleAdvancedItem(this)" aria-expanded="true"'),
    0L)
  expect_true(
    n_dn(out, 'class="br-adv-toggle" onclick="brToggleAdvancedItem(this)" aria-expanded="false"') >= 2L)
})

test_that("the Advanced drawer names how many analyses it holds", {
  out <- render_cat()
  # Five leaves land in Brand and Buying Advanced on a full-depth category.
  expect_match(out, '<span class="br-advanced-count">5</span>', fixed = TRUE)
})

test_that("a drawer holding one analysis has one level of disclosure", {
  # Brand Meaning with Branded Reach configured and nothing else in its
  # Advanced tier. The item's heading is a heading, not a second toggle,
  # and its body is not hidden behind a click of its own.
  out <- render_cat(cat_results = fake_cat_results(reach = TRUE),
                    panels = fake_panels(c(full_keys, "branded_reach_dss")))
  expect_match(out,
    '<div class="br-adv-item br-adv-item-single" data-group="dss" data-leaf="branded_reach"><div class="br-adv-toggle br-adv-static">Branded Reach</div><div class="br-adv-body">',
    fixed = TRUE)
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
  # Stage 5: the anchors are on the leaf wrappers now, so they stay on the
  # page whether or not a commentary box is rendered for them. With no
  # Section_Insights text in this config there is no insight wrap at all: the
  # commentary a reader writes goes in the destination's own box.
  expect_equal(n_dn(out, "br-insight-wrap"), 0L)
  expect_equal(n_dn(out, 'class="br-leaf-anchor"'), 5L)

  # With authored text the leaf's own box comes back, on its own anchor and
  # inside its own wrap, so the sentence sits beside the analysis it was
  # written against.
  with_text <- render_cat(config = list(
    focal_brand = "IPK", colour_focal = "#1A5276",
    section_insights = list("ceps-dss" = "CEP coverage is broad.")))
  expect_true(grepl('data-insight-internal-tab="ceps"', with_text, fixed = TRUE))
  expect_true(grepl("CEP coverage is broad.", with_text, fixed = TRUE))
  expect_equal(n_dn(with_text, "br-insight-wrap"), 1L)
})

test_that("every view has one export toolbar, and Advanced has its own", {
  out <- render_cat()
  # Four main views plus the one Advanced drawer a full-depth category has.
  # The Overview is the fifth destination and gets none: it holds a route to
  # the Summary tab, not an analysis, so there is nothing to export, no
  # marker for a significance toggle to govern, and a commentary box there
  # would compete with the one on the page it routes to.
  expect_equal(n_dn(out, 'class="br-dest-toolbar"'), 5L)
  expect_equal(n_dn(out, 'class="br-dest-btn br-dest-pin"'), 5L)
  expect_equal(n_dn(out, 'class="br-dest-btn br-dest-png"'), 5L)
  expect_equal(n_dn(out, 'class="br-dest-btn br-dest-excel"'), 5L)
  expect_false(grepl('data-destination="overview" data-tier="main">', out,
                     fixed = TRUE))
  # Significance and commentary are one per destination, not one per view,
  # so the Advanced drawer's toolbar carries neither.
  expect_equal(n_dn(out, "br-sig-toggle"), 4L)
  expect_equal(n_dn(out, "br-dest-note-text"), 4L)
  # The Advanced toolbar carries its three buttons and its own drawer, and
  # nothing else: five elements wearing the tier.
  expect_equal(n_dn(out, 'data-tier="advanced"'), 5L)

  # One shared per-leaf toolbar survives, on the Category Buying host. Its
  # buttons are not generic: brand_cat_buying_panel.js unbinds the inline
  # handler and rebinds a dialog that pins whichever of the eight sub-tabs is
  # on screen, which is finer than an anchor-level picker can be. Every other
  # per-leaf pin, PNG and Excel button in the category is gone.
  expect_equal(n_dn(out, 'class="br-pin-btn"'), 1L)
  expect_equal(n_dn(out, 'class="br-png-btn"'), 1L)
  expect_equal(n_dn(out, 'class="br-export-btn"'), 1L)
  expect_equal(n_dn(out, "cb-toolbar-top"), 1L)
})

test_that("significance is off until a reader asks for it", {
  out <- render_cat()
  # The markup never ships a destination in the on state, and the label says
  # which state it is in rather than what a click would do.
  expect_equal(n_dn(out, 'data-br-sig="on"'), 0L)
  expect_equal(n_dn(out, 'aria-pressed="false"'), 4L)
  expect_equal(n_dn(out, "Significance: off"), 4L)
})

test_that("every view carries a collapsed How this works drawer", {
  out <- render_cat()
  # One per main view plus one in the Advanced drawer. Each ships hidden and
  # is unhidden by brCollectHowTo() only when it found something to hold, so
  # a view with no methodology shows no drawer.
  expect_equal(n_dn(out, 'class="br-howto"'), 5L)
  expect_equal(n_dn(out, 'class="br-howto-body" hidden'), 5L)
  expect_equal(n_dn(out, 'aria-expanded="false" onclick="brToggleHowTo(this)"'), 5L)
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


# --- section 7 of the impact map: what must not change ----------------------

test_that("the switchCategorySubtab route into the panels' hidden buttons survives", {
  js <- paste(readLines(file.path(ROOT_DN, "modules", "brand", "lib",
                                   "html_report", "js", "brand_report.js"),
                        warn = FALSE), collapse = "\n")
  expect_true(grepl("window.switchCategorySubtab = function", js, fixed = TRUE))
  # The route is a click on the panel's own hidden sub-tab button. That is how
  # the Mental Availability and funnel panels run their state updates, and the
  # destination switcher shares the same helper.
  expect_true(grepl(".ma-subtab-btn[data-ma-subtab-target=", js, fixed = TRUE))
  expect_true(grepl(".fn-subtab-btn[data-fn-subtab-target=", js, fixed = TRUE))
  # Extended to the cat-buying panel, whose sub-nav is now hidden too.
  expect_true(grepl(".cb-subtab-btn[data-cb-tab=", js, fixed = TRUE))
  # The .br-insight-wrap show and hide logic still runs on activation.
  expect_true(grepl(".br-insight-wrap[data-insight-internal-tab]", js,
                    fixed = TRUE))
  expect_true(grepl("window.switchBrandDestination = function", js, fixed = TRUE))
})

test_that("the three panel sub-navs stay in the DOM and stay hidden by CSS", {
  css <- paste(readLines(file.path(ROOT_DN, "modules", "brand", "lib",
                                    "html_report", "03_page_builder.R"),
                         warn = FALSE), collapse = "\n")
  expect_true(grepl(".fn-subnav, .ma-subnav, .cb-subnav { display: none !important; }",
                    css, fixed = TRUE))
})


# --- Stage 5: the chrome ------------------------------------------------------
# These read the source files rather than a rendered page, because the rules
# they check are stylesheet and capture behaviour that a fragment cannot show.

.read_stage5 <- function(...) {
  paste(readLines(file.path(ROOT_DN, "modules", "brand", "lib", "html_report",
                            ...), warn = FALSE), collapse = "\n")
}

test_that("the significance rules hide, and hide only, the markers", {
  pb <- .read_stage5("03_page_builder.R")
  block <- sub(".*=== Significance, off until a reader asks for it", "", pb)
  block <- sub("=== \"How this works\".*", "", block)
  for (sel in c(".ma-sig", ".ma-fv-sig", ".ma-adv-sig", ".ct-sig",
                ".fn-sig-avg", ".fn-sig")) {
    expect_match(block, sprintf(':not([data-br-sig="on"]) %s', sel),
                 fixed = TRUE, info = sel)
  }
  # Off is the state with no attribute, so a report that has never been
  # touched, and a saved copy of one, both open with the markers hidden.
  expect_false(grepl('[data-br-sig="off"]', block, fixed = TRUE))
})

test_that("a capture taken with significance off has the markers stripped", {
  pins <- .read_stage5("js", "brand_pins.js")
  # One wrapper, at init, around the shared capture helper. Editing the
  # fourteen capture sites across five panel files instead would leave the
  # next one to be added uncovered.
  expect_match(pins, "TurasPins.capturePortableHtml = wrapped", fixed = TRUE)
  expect_match(pins, "wrapped.__brSigWrapped = true", fixed = TRUE)
  expect_match(pins, "window.brStripSigMarkers", fixed = TRUE)
  for (sel in c(".ma-sig", ".ma-fv-sig", ".ma-adv-sig", ".ct-sig",
                ".fn-sig-avg", ".fn-sig")) {
    expect_match(pins, sprintf('"%s"', sel), fixed = TRUE, info = sel)
  }
  # The page decides, and the page is the destination the root sits in.
  rpt <- .read_stage5("js", "brand_report.js")
  expect_match(rpt, "window.brSigOnFor = function(el)", fixed = TRUE)
  expect_match(rpt, 'dest.getAttribute("data-br-sig") === "on"', fixed = TRUE)
})

test_that("the print block keeps the drawers and drops the buttons", {
  pb <- .read_stage5("03_page_builder.R")
  pr <- sub(".*@media print \\{", "", pb)
  pr <- sub("\\n\\}.*", "", pr)
  # A printed page cannot be opened, so the methodology and the commentary
  # print. The buttons that open them do not.
  expect_match(pr, ".br-howto-body[hidden]", fixed = TRUE)
  expect_match(pr, ".br-dest-note[hidden] { display: block !important; }",
               fixed = TRUE)
  expect_match(pr, ".br-dest-tools { display: none !important; }", fixed = TRUE)
  # A drawer that found nothing stays hidden rather than printing a heading
  # over nothing.
  expect_false(grepl(".br-howto[hidden]", pr, fixed = TRUE))
})

test_that("the destination toolbar never reads or writes a section anchor", {
  rpt <- .read_stage5("js", "brand_report.js")
  block <- sub(".*Destination toolbars: one per main view", "", rpt)
  block <- sub("// --- Insight editor ---.*", "", block)
  # It resolves by destination. The data-section set is a contract with the
  # analysts who typed those names into Section_Insights sheets, and the
  # reachability gate holds it fixed, so nothing here may add to it.
  expect_match(block, 'data-destination="', fixed = TRUE)
  expect_match(block, 'data-tier"', fixed = TRUE)
  expect_false(grepl("setAttribute(\"data-section\"", block, fixed = TRUE))
  # And the markup carries no data-section on any destination control.
  out <- render_cat()
  bar <- regmatches(out, gregexpr('<div class="br-dest-toolbar"[^>]*>', out))[[1]]
  expect_gt(length(bar), 0L)
  for (b in bar) expect_false(grepl("data-section", b, fixed = TRUE), info = b)
})

test_that("a destination whose analyses are all Advanced still has its toggle", {
  # Audience with Audience Lens configured and neither Demographics nor Ad
  # Hoc is the real case, and Stage 2 already opens its drawer for it. The
  # main view has nothing to export, so it carries no pin, PNG or Excel; the
  # significance toggle and the commentary box are one per destination and
  # stay above the drawer, and the drawer's own toolbar carries the export.
  out <- render_cat(
    cat_results = fake_cat_results(demo = FALSE, lens = TRUE),
    panels = fake_panels(c(full_keys[!grepl("demographics", full_keys)],
                           "audience_lens_dss")))
  # Slice the audience container out by its opening tag. A greedy sub() would
  # match the Advanced drawer's copy of the attribute instead.
  open_tag <- '<div class="br-destination" data-group="dss" data-destination="audience">'
  i <- regexpr(open_tag, out, fixed = TRUE)[[1]]
  expect_gt(i, 0L)
  aud <- substring(out, i + nchar(open_tag))
  expect_match(aud, "br-sig-toggle", fixed = TRUE)
  expect_match(aud, "br-dest-note-text", fixed = TRUE)
  main <- sub('<div class="br-advanced".*', "", aud)
  expect_false(grepl("br-dest-pin", main, fixed = TRUE))
  expect_false(grepl("br-dest-excel", main, fixed = TRUE))
  # The drawer keeps its own three.
  adv <- sub('.*<div class="br-advanced"', "", aud)
  expect_match(adv, "br-dest-pin", fixed = TRUE)
  expect_match(adv, "br-dest-png", fixed = TRUE)
  expect_match(adv, "br-dest-excel", fixed = TRUE)
})

test_that("a flagged insight still renders its box and its number-check marker", {
  # The authored-insight number check writes a marker into the insight box.
  # Stage 5 made the leaf box conditional, so the marker has to be one of the
  # reasons a box renders: an insight the check flagged is exactly the one a
  # reader must not lose. The IPK fixture flags nothing, so this drives the
  # branch directly rather than waiting for a report that does.
  skip_if_not(exists("brand_insight_check_note", mode = "function"),
              "03b_insight_number_check.R is not sourced here")
  check <- list(findings = list(
    "ceps-dss" = list(figures = c("59%"), view = "the nested funnel")))
  note <- brand_insight_check_note(check, "ceps-dss")
  expect_true(nzchar(note))
  expect_match(note, "br-insight-check", fixed = TRUE)

  # With text and a finding, the box renders and carries the marker.
  html <- build_br_section_toolbar(
    "ceps-dss", prefill_text = "Prefer runs at 59%.",
    check_note = note, require_text = TRUE)
  expect_match(html, "br-insight-editor", fixed = TRUE)
  expect_match(html, "br-insight-check", fixed = TRUE)
  expect_match(html, "Prefer runs at 59%.", fixed = TRUE)

  # A finding with no authored text is not a case the check can produce, but
  # the marker alone is still enough to render the box rather than swallow it.
  only_note <- build_br_section_toolbar("ceps-dss", check_note = note,
                                        require_text = TRUE)
  expect_match(only_note, "br-insight-check", fixed = TRUE)

  # Nothing authored and nothing flagged: no box at all.
  expect_equal(build_br_section_toolbar("ceps-dss", require_text = TRUE), "")
})


# --- the category tab bar agrees with the category panel ---------------------
# Stage 6. The tab bar used to decide a category deserved a tab from Mental
# Availability or the funnel alone, while the panel built leaves from all
# eight elements. A study with Word of Mouth and Demographics and neither of
# those two therefore produced no category tab, and every analysis it had
# configured was absent from the report with no warning anywhere. Found by
# tests/qa/drive_element_flags.R, which drives one element flag at a time
# against the IPK fixture. Both now go through .br_cat_renderable().

test_that("every element that owns a leaf can carry a category on its own", {
  # One element at a time, nothing else configured.
  singles <- list(
    funnel        = fake_cat_results(TRUE,  FALSE, FALSE, FALSE, FALSE),
    ma            = fake_cat_results(FALSE, TRUE,  FALSE, FALSE, FALSE),
    repertoire    = fake_cat_results(FALSE, FALSE, TRUE,  FALSE, FALSE),
    wom           = fake_cat_results(FALSE, FALSE, FALSE, TRUE,  FALSE),
    demographics  = fake_cat_results(FALSE, FALSE, FALSE, FALSE, TRUE),
    branded_reach = fake_cat_results(FALSE, FALSE, FALSE, FALSE, FALSE,
                                     reach = TRUE),
    adhoc         = fake_cat_results(FALSE, FALSE, FALSE, FALSE, FALSE,
                                     adhoc = TRUE),
    audience_lens = fake_cat_results(FALSE, FALSE, FALSE, FALSE, FALSE,
                                     lens = TRUE))
  for (nm in names(singles)) {
    expect_true(.br_cat_has_content(singles[[nm]]),
                info = paste(nm, "alone should earn the category a tab"))
    expect_true(isTRUE(.br_cat_renderable(singles[[nm]])[[nm]]),
                info = paste(nm, "should read as renderable"))
  }
})

test_that("a category with nothing renderable earns no tab", {
  expect_false(.br_cat_has_content(fake_cat_results(
    FALSE, FALSE, FALSE, FALSE, FALSE)))
  expect_false(.br_cat_has_content(list(cat_code = "AWO")))
  expect_false(.br_cat_has_content(NULL))
})

test_that("a refused or empty element does not earn a tab on its own", {
  # The per-element conditions moved into the helper unchanged, so the
  # emptiness rules each one carries are asserted here rather than assumed.
  expect_false(.br_cat_has_content(list(funnel = list(status = "REFUSED"))))
  expect_false(.br_cat_has_content(list(mental_availability =
                                          list(status = "REFUSED"))))
  expect_false(.br_cat_has_content(list(repertoire = list(status = "REFUSED"))))
  # Word of Mouth needs its metrics, not just a PASS.
  expect_false(.br_cat_has_content(list(wom = list(status = "PASS"))))
  # These three need a non-empty list, which is how a placeholder result is
  # kept off the page.
  expect_false(.br_cat_has_content(list(branded_reach =
                                          list(status = "PASS", ads = list()))))
  expect_false(.br_cat_has_content(list(adhoc =
                                          list(status = "PASS", questions = list()))))
  expect_false(.br_cat_has_content(list(audience_lens =
                                          list(status = "PASS", audiences = list()))))
  # Demographics must be PASS, not PARTIAL.
  expect_false(.br_cat_has_content(list(demographics =
                                          list(status = "PARTIAL", questions = list(1)))))
  expect_true(.br_cat_has_content(list(demographics =
                                         list(status = "PASS", questions = list(1)))))
})

test_that("a category carried by Word of Mouth alone still renders its destination", {
  # The end of the bug: the panel had always been willing to build this.
  out <- render_cat(cat_results = fake_cat_results(FALSE, FALSE, FALSE,
                                                   TRUE, FALSE),
                    panels = fake_panels("wom_dss"))
  expect_equal(n_dest_buttons(out, "meaning"), 1L)
  expect_equal(n_dest_buttons(out, "mental"),  0L)
  expect_equal(n_dest_buttons(out, "buying"),  0L)
  expect_equal(n_dest_buttons(out, "audience"), 0L)
  expect_equal(n_dest_buttons(out, "overview"), 1L)
})

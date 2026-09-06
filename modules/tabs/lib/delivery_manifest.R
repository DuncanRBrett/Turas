# ==============================================================================
# TABS. DELIVERY MANIFEST (what is actually inside the file you are about to send)
# ==============================================================================
#
# Every v2 build prints one of these. Not only the builds that happen to trip a
# warning.
#
# Why it exists. Turas already had a disclosure warning box, but it fired only
# when `min_reporting_base` was set. A report built with the threshold unset,
# which is the ordinary case, shipped a per-respondent island and said nothing at
# all. A demo report was handed to a third party in exactly that state, and a
# respondent by question dataset was rebuilt out of it from the page source
# alone. The lesson is not that the island is wrong: it is what makes live
# filtering work, and for most studies it is fine. The lesson is that nobody
# should have to remember what a given build contains.
#
# So this prints the contents of the file, plainly, on every build. Duncan's
# policy is case by case, and a case by case policy only works when each case is
# visible at the moment the file is produced.
#
# Depends on nothing. Pure given its arguments, so it is testable without a run:
#   testthat::test_file("modules/tabs/tests/testthat/test_delivery_manifest.R")
# ==============================================================================

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' Decide whether this build carries the microdata island
#'
#' Two switches, either of which turns the island off: the config's
#' `html_report_v2_microdata = FALSE`, and the GUI's "Client safe" delivery
#' mode (`TURAS_DELIVERY_CLIENT_SAFE`). The GUI choice used to be a declaration
#' only, enforced by an audit after the file was built; choosing it while the
#' config still said TRUE produced a full respondent-level file and then a
#' refusal. A client-safe choice now decides the build.
#'
#' @param config_obj The built config object.
#' @param client_safe Logical. The GUI delivery mode; defaults to the global
#'   the tabs GUI sets, FALSE when unset.
#'
#' @return A list with structure:
#'   \item{wanted}{TRUE when the island should be built}
#'   \item{reason}{Why it is off: "config", "gui", or NA when it is on}
#'
#' @keywords internal
tabs_microdata_wanted <- function(config_obj,
                                  client_safe = isTRUE(get0("TURAS_DELIVERY_CLIENT_SAFE",
                                                            envir = .GlobalEnv))) {
  cfg <- config_obj %||% list()
  if (isFALSE(cfg$html_report_v2_microdata)) {
    return(list(wanted = FALSE, reason = "config"))
  }
  if (isTRUE(client_safe)) {
    return(list(wanted = FALSE, reason = "gui"))
  }
  list(wanted = TRUE, reason = NA_character_)
}


#' Resolve the interactivity mode one run actually builds
#'
#' Two places have an opinion. The CONFIG says what the project normally ships
#' (`html_report_v2_interactivity`: records, cube or none). The GUI says who
#' this particular file is for.
#'
#' The rule is that the GUI sets a FLOOR of protection and can never lower one.
#' Ordered least to most protected: records, cube, none. A GUI choice raises the
#' config's mode to its floor and otherwise leaves it alone.
#'
#'   full                     no floor. The config's mode stands.
#'   client_safe_interactive  floor `cube`. A records config becomes a cube; a
#'                            config already on `none` stays there, being
#'                            stricter.
#'   client_safe_frozen       floor `none`. Published tables, whatever the
#'                            config said.
#'
#' Why a floor and not an override. "Full report" is a permission, not an
#' instruction: a project deliberately configured to ship aggregates must not
#' start shipping respondent records because someone picked the top radio
#' button. And before this, "Client safe" collapsed a `cube` config all the way
#' to `none`, silently throwing away the interactivity the mode was built to
#' keep, while "Full report" was the only way to get a cube built. Both labels
#' were wrong, in opposite directions.
#'
#' `cube` needs a threshold to protect anything. When one is asked for and
#' `min_reporting_base` is not above 1 the mode drops to `none`, which is
#' strictly safer and still honours the client-safe choice. The caller says so
#' on the console; it is not a silent downgrade.
#'
#' @param config_obj The built config object.
#' @param gui_mode The GUI's delivery mode: "full", "client_safe_interactive",
#'   "client_safe_frozen", or NA when no deliverable was asked for. Defaults to
#'   the global the tabs GUI sets.
#'
#' @return A list with structure:
#'   \item{mode}{"records", "cube" or "none": what this run builds}
#'   \item{config_mode}{What the config alone asked for}
#'   \item{reason}{"config", "gui" or "needs_k": what decided it}
#'   \item{client_safe}{TRUE when the file must carry no respondent records}
#'
#' @keywords internal
TABS_INTERACTIVITY_RANK <- c(records = 1L, cube = 2L, none = 3L)

tabs_delivery_interactivity <- function(config_obj,
                                        gui_mode = get0("TURAS_DELIVERY_MODE",
                                                        envir = .GlobalEnv,
                                                        ifnotfound = NA_character_)) {
  cfg <- config_obj %||% list()
  config_mode <- tolower(trimws(as.character(
    cfg$html_report_v2_interactivity %||% "records")[1]))
  if (!config_mode %in% names(TABS_INTERACTIVITY_RANK)) config_mode <- "records"
  # The retired switch still wins where it is explicitly off, exactly as it did.
  if (isFALSE(cfg$html_report_v2_microdata)) config_mode <- "none"

  gui <- tolower(trimws(as.character(gui_mode %||% NA_character_)[1]))
  floor_mode <- switch(gui,
    client_safe_interactive = "cube",
    client_safe_frozen      = "none",
    # "client_safe" is the two-option GUI's old value. Treated as the FROZEN
    # choice, which is what it used to do, so an older caller cannot silently
    # start shipping something different.
    client_safe             = "none",
    NULL)

  mode <- config_mode
  reason <- "config"
  if (!is.null(floor_mode) &&
      TABS_INTERACTIVITY_RANK[[floor_mode]] > TABS_INTERACTIVITY_RANK[[mode]]) {
    mode <- floor_mode
    reason <- "gui"
  }

  if (identical(mode, "cube")) {
    k <- suppressWarnings(as.numeric(cfg$min_reporting_base))
    if (!(length(k) == 1L && !is.na(k) && k > 1)) {
      mode <- "none"
      reason <- "needs_k"
    }
  }

  list(mode = mode, config_mode = config_mode, reason = reason,
       client_safe = !identical(mode, "records"))
}


#' Resolve the QUALITATIVE confidentiality dials one run actually builds
#'
#' The same floor rule as tabs_delivery_interactivity, applied to the two dials
#' that decide what the comment island carries. It exists because the two were
#' unconnected: a build could be told to carry no respondent records and still
#' ship every comment tagged with the reader's full demographic triple, which
#' names one person as surely as a record does. On the SACS 2025 build 57 of the
#' 144 tagged commenters were the only person in their Campus, Department and
#' Tenure combination, on a file whose crosstabs refuse any group under ten.
#'
#' Ordered least to most protected:
#'   tags   allow    every tag ships
#'          safe     k-anonymised: a comment keeps a tag only while the
#'                   combination it belongs to still covers k people
#'          block    no tags, so the comments cannot follow a filter at all
#'   text   full     the raw verbatim
#'          redacted direct identifiers (email, URL, phone) scrubbed
#'          hidden   no text, counts and themes only
#'
#'   full                     no floor. The config's dials stand.
#'   client_safe_interactive  tags to `safe`, text to `redacted`. `safe` and not
#'                            `block` because this mode's promise is that the
#'                            comments follow the filter, and blocking the tags
#'                            withdraws that. Text is floored only off `full`:
#'                            a curated excerpt is the point of the tab, and an
#'                            email address in it is not.
#'   client_safe_frozen       tags to `block`, text to `redacted`. Nothing in a
#'                            frozen file can filter, so a tag serves no reader
#'                            and is exposure with no function.
#'
#' `safe` is a promise about k, so it needs one. Where min_reporting_base is not
#' above 1 a client-safe build floors the tags to `block` instead, which is the
#' same trade tabs_delivery_interactivity makes when a cube is asked for without
#' a threshold: strictly safer, and said out loud rather than assumed.
#'
#' @param config_obj The built config object.
#' @param gui_mode The GUI's delivery mode, as tabs_delivery_interactivity takes.
#'
#' @return A list with structure:
#'   \item{cuts}{"allow", "safe" or "block": the tag dial this run builds}
#'   \item{text_mode}{"full", "redacted" or "hidden": the text dial}
#'   \item{config_cuts}{What the config alone asked for}
#'   \item{config_text_mode}{The same, for text}
#'   \item{reason}{"config", "gui" or "needs_k": what decided the tag dial}
#'
#' @keywords internal
TABS_QUAL_CUTS_RANK <- c(allow = 1L, safe = 2L, block = 3L)
TABS_QUAL_TEXT_RANK <- c(full = 1L, redacted = 2L, hidden = 3L)
# How a comment is keyed. "respondent" gives one index and one token per person,
# the same in every question, so any two of that person's comments can be joined
# into a profile. "question" keys a comment by its position in its own question
# and ships no token. Client-safe raises it, whatever the config said.
TABS_QUAL_KEY_RANK <- c(respondent = 1L, question = 2L)

tabs_delivery_qual_dials <- function(config_obj,
                                     gui_mode = get0("TURAS_DELIVERY_MODE",
                                                     envir = .GlobalEnv,
                                                     ifnotfound = NA_character_)) {
  cfg <- config_obj %||% list()
  norm <- function(value, default, ranks) {
    v <- tolower(trimws(as.character(value %||% default)[1]))
    if (!length(v) || is.na(v) || !v %in% names(ranks)) default else v
  }
  # The same defaults the island builder applies, so this function and the
  # thing it is describing can never disagree about an unset dial.
  config_cuts <- norm(cfg$qual_demographic_cuts, "allow", TABS_QUAL_CUTS_RANK)
  config_text <- norm(cfg$qual_confidentiality_mode, "hidden", TABS_QUAL_TEXT_RANK)
  config_key <- norm(cfg$qual_comment_key, "respondent", TABS_QUAL_KEY_RANK)

  gui <- tolower(trimws(as.character(gui_mode %||% NA_character_)[1]))
  client_safe <- gui %in% c("client_safe_interactive", "client_safe_frozen",
                            "client_safe")
  k <- suppressWarnings(as.numeric(cfg$min_reporting_base))
  k_set <- length(k) == 1L && !is.na(k) && k > 1

  cuts_floor <- if (!client_safe) NULL
    else if (identical(gui, "client_safe_interactive")) {
      # A promise about k needs a k. Without one, `safe` ships raw tags.
      if (k_set) "safe" else "block"
    } else "block"
  text_floor <- if (client_safe) "redacted" else NULL
  # Every client-safe mode, frozen included: a frozen file still carries the
  # comment records, so the key that joins them across questions is exposure there
  # too, and nothing in a frozen file needs one.
  key_floor <- if (client_safe) "question" else NULL

  cuts <- config_cuts
  reason <- "config"
  if (!is.null(cuts_floor) &&
      TABS_QUAL_CUTS_RANK[[cuts_floor]] > TABS_QUAL_CUTS_RANK[[cuts]]) {
    cuts <- cuts_floor
    reason <- if (identical(gui, "client_safe_interactive") && !k_set) "needs_k" else "gui"
  }
  text_mode <- config_text
  if (!is.null(text_floor) &&
      TABS_QUAL_TEXT_RANK[[text_floor]] > TABS_QUAL_TEXT_RANK[[text_mode]]) {
    text_mode <- text_floor
  }

  comment_key <- config_key
  if (!is.null(key_floor) &&
      TABS_QUAL_KEY_RANK[[key_floor]] > TABS_QUAL_KEY_RANK[[comment_key]]) {
    comment_key <- key_floor
  }

  list(cuts = cuts, text_mode = text_mode, comment_key = comment_key,
       config_cuts = config_cuts, config_text_mode = config_text,
       config_comment_key = config_key,
       reason = reason)
}


#' Apply the qualitative floor to a config object
#'
#' Written back into the config so every reader downstream (the island builder,
#' the manifest, the source-exposure warning) sees ONE set of values. A floor
#' that only some readers honoured would put a manifest line and the file it
#' describes out of step, which is the failure this whole layer exists to stop.
#'
#' @param config_obj The built config object.
#' @param dials The result of tabs_delivery_qual_dials().
#' @return The config object with the two dials set to their effective values.
#' @keywords internal
tabs_apply_qual_floor <- function(config_obj, dials) {
  if (is.null(config_obj) || is.null(dials)) return(config_obj)
  config_obj$qual_demographic_cuts <- dials$cuts
  config_obj$qual_confidentiality_mode <- dials$text_mode
  config_obj$qual_comment_key <- dials$comment_key
  config_obj
}


#' Describe what a finished v2 build contains, as manifest lines
#'
#' @param micro The microdata island list from build_microdata(), or NULL.
#' @param qual_json The serialised qualitative island (character), or NULL.
#' @param config_obj The built config object.
#' @param output_file Path of the report the manifest describes, or NULL.
#' @param cube The aggregate cube from build_cube(), or NULL. Present only on an
#'   interactivity = cube build, where it is the computed source instead of the
#'   respondent island.
#'
#' @return A list with structure:
#'   \item{lines}{Character vector, the manifest as printable lines}
#'   \item{microdata}{TRUE when the file carries per-respondent records}
#'   \item{n}{Respondent count carried, or NA when none}
#'   \item{restricted}{TRUE when the file should not be forwarded unconsidered}
#'
#' @keywords internal
tabs_delivery_manifest <- function(micro, qual_json, config_obj,
                                   output_file = NULL, cube = NULL,
                                   excluded_renderers = character(0)) {
  cfg <- config_obj %||% list()
  has_micro <- !is.null(micro)
  n <- if (has_micro) suppressWarnings(as.integer(micro$n %||% NA_integer_)) else NA_integer_
  has_weights <- has_micro && !is.null(micro$weights) && length(micro$weights) > 0L

  k_raw <- suppressWarnings(as.numeric(cfg$min_reporting_base))
  k_set <- length(k_raw) == 1L && !is.na(k_raw) && k_raw > 1
  k_txt <- if (k_set) format(k_raw) else "not set"

  has_cube <- !is.null(cube)
  cube_k <- if (has_cube) suppressWarnings(as.numeric(cube$k %||% NA_real_)) else NA_real_
  cube_order <- if (has_cube) as.integer(cube$order %||% NA_integer_) else NA_integer_
  cube_vars <- if (has_cube) length(cube$vars) else 0L
  cube_var_list <- if (has_cube) paste(names(cube$vars), collapse = ", ") else ""
  cube_shipped <- if (has_cube) as.integer(cube$blocks$shipped %||% 0L) else 0L
  cube_refused <- if (has_cube) as.integer(cube$blocks$refused %||% 0L) else 0L

  has_qual <- !is.null(qual_json) && nzchar(as.character(qual_json)) &&
    !identical(trimws(as.character(qual_json)), "null")

  text_mode <- tolower(trimws(as.character(cfg$qual_confidentiality_mode %||% "hidden")))
  cuts      <- tolower(trimws(as.character(cfg$qual_demographic_cuts %||% "allow")))

  verbatim_txt <- if (!has_qual) "no comment tab in this build" else switch(
    text_mode,
    full     = "FULL text in the file",
    redacted = "text in the file, direct identifiers scrubbed",
    hidden   = "no text in the file (counts and themes only)",
    text_mode)

  key_txt <- if (!has_qual) "not applicable" else switch(
    tolower(trimws(as.character(cfg$qual_comment_key %||% "respondent"))),
    question = "question-local (no comment joins to another across questions)",
    "one per respondent (comments CAN be joined across questions)")

  tags_txt <- if (!has_qual) "not applicable" else switch(
    cuts,
    block = "none (comments carry no demographics)",
    safe  = if (k_set) sprintf("k-anonymised against k=%s", k_txt) else
      "declared safe but k is unset, so tags ship raw",
    allow = "every tag ships",
    cuts)

  pad <- function(label) formatC(label, width = 30, flag = "-")
  lines <- c(
    "┌─── TURAS DELIVERY MANIFEST ──────────────────────────────────┐",
    if (!is.null(output_file)) paste0("│ File: ", basename(output_file)),
    paste0("│ ", pad("Respondent-level records"), ": ",
           if (has_micro) sprintf("YES (%s de-identified records)",
                                  if (is.na(n)) "count unknown" else format(n)) else "NO"),
    paste0("│ ", pad("Row-level weights"), ": ", if (has_weights) "YES" else "NO"),
    paste0("│ ", pad("Direct identifiers"), ": NO (indices only, never IDs or raw text)"),
    paste0("│ ", pad("Verbatim comments"), ": ", verbatim_txt),
    paste0("│ ", pad("Comment demographic tags"), ": ", tags_txt),
    paste0("│ ", pad("Comment key"), ": ", key_txt),
    # An assertion, and labelled as one. No build can tell whether a human read
    # the comments, so the manifest must not let it read as a measured control.
    if (has_qual && isTRUE(cfg$qual_manual_review))
      paste0("│ ", pad("Manual review"), ": ASSERTED by the analyst (not verified by the build)"),
    paste0("│ ", pad("Minimum reporting base"), ": ", k_txt),
    paste0("│ ", pad("Live filters, custom banners"), ": ",
           if (has_micro) "ON"
           else if (has_cube) sprintf("ON, from aggregates (up to %s of %s declared variables)",
                                      cube_order, cube_vars)
           else "off (published figures only)")
  )

  if (has_cube) {
    lines <- c(lines,
      "│",
      sprintf("│ Interactivity: aggregate cube, k = %s, combinations up to %s,",
              format(cube_k), cube_order),
      sprintf("│ %s of %s blocks shipped. No respondent-level records.",
              format(cube_shipped), format(cube_shipped + cube_refused)),
      sprintf("│ Declared variables: %s", cube_var_list),
      "│",
      "│ A cut in which any group falls below k is withheld WHOLE, so it cannot",
      "│ be recovered by subtraction from the margins that remain. The residual",
      "│ is the one every published crosstab has: a group of exactly k in which",
      "│ everyone answered the same way discloses that answer for the group.",
      "│ This file is no more disclosive than a published table with base k."
    )
  }

  if (has_micro) {
    lines <- c(lines,
      "│",
      "│ The records are coded answers and weights, and they are what powers",
      "│ live filtering and the computed views.",
      "│",
      "│ The confidentiality ship is one Settings row:",
      "│   html_report_v2_microdata = FALSE",
      "│ Published figures only. Live filters and computed views switch off;",
      "│ tracking, column suppression and the comment tab all still work."
    )
    if (k_set) {
      # Duncan's C3 decision (production review 2026-08). Render-time suppression
      # is a viewing convenience; microdata = FALSE is the confidential ship. A
      # k-gated build that still carries the island must say so in terms the
      # operator can act on before the file leaves.
      lines <- c(lines,
        "│",
        sprintf("│ NOTE: min_reporting_base = %s hides sub-k cells ON SCREEN, but the", k_txt),
        "│ withheld numbers are in the page source of THIS build.")
    }
  }

  # What the client deliverable step will do to this file. The manifest is
  # printed at write time, before turas_minify() runs, so this says what is
  # about to happen rather than what happened.
  deliverable <- isTRUE(get0("TURAS_PREPARE_DELIVERABLE", envir = .GlobalEnv))
  lines <- c(lines,
    "│",
    paste0("│ ", pad("Client deliverable step"), ": ",
           if (deliverable) "YES, a minified copy will be written" else
             "NO, this is a development build"),
    paste0("│ ", pad("Data islands in the copy"), ": ",
           if (deliverable) "encoded" else "plain JSON"))
  if (deliverable) {
    lines <- c(lines,
      "│ Encoding stops reading and grepping. It does not stop a developer.",
      "│ Any downstream tool that reads the islands must use the _dev copy.")
  }
  lines <- c(lines,
    paste0("│ ", pad("Analysis renderers dropped"), ": ",
           if (length(excluded_renderers))
             paste(sub("^[0-9]+[a-z]?_", "", sub("\\.js$", "", excluded_renderers)),
                   collapse = ", ")
           else "none"))

  lines <- c(lines,
             "└──────────────────────────────────────────────────────────────┘")

  list(lines = lines, microdata = has_micro, n = n, restricted = has_micro,
       cube = has_cube, cube_k = cube_k, cube_order = cube_order,
       cube_blocks_shipped = cube_shipped, cube_blocks_refused = cube_refused,
       deliverable = deliverable, excluded_renderers = excluded_renderers)
}


#' Print the delivery manifest to the console
#'
#' Console, because Turas runs inside Shiny and the operator debugs and checks in
#' the terminal that launched it.
#'
#' @inheritParams tabs_delivery_manifest
#' @return The manifest list, invisibly.
#' @keywords internal
tabs_print_delivery_manifest <- function(micro, qual_json, config_obj,
                                         output_file = NULL, cube = NULL,
                                         excluded_renderers = character(0)) {
  m <- tabs_delivery_manifest(micro, qual_json, config_obj, output_file, cube,
                              excluded_renderers)
  cat("\n")
  cat(paste0(m$lines, collapse = "\n"))
  cat("\n\n")
  invisible(m)
}

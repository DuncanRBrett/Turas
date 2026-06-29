# ==============================================================================
# TABS MODULE — QUALITATIVE QUANT LAYER (themes -> DATA_AGG/DATA_MICRO via the
#               EXISTING crosstab engine; zero new stats)
# ==============================================================================
#
# Turns themed qual questions into ordinary Multi_Mention questions and runs them
# through the existing per-question engine + data-layer writer, so theme x banner
# crosstabs and significance are byte-identical to a closed question. Each theme is
# a multi-mention option; each respondent's mentioned theme labels are left-packed
# into slot columns; the embedded demographics become a real banner via
# create_banner_structure. The verbatim/sentiment layer is DATA_QUAL (separate).
#
# Recipe + the base-floor / DisplayText pitfalls are in QUALITATIVE_TAB_BUILD_NOTES.md.
# Significance flows through process_standard_question -> add_significance_row with no
# theme-aware code path: nothing here computes a statistic.
#
# Depends on (in scope in the running tabs pipeline): create_banner_structure,
# build_config_object, process_all_questions, build_data_layer, build_microdata.
#
# Run the tests with:
#   testthat::test_file("modules/tabs/tests/testthat/test_qual_quant_layer.R")
# ==============================================================================

QUAL_DEMO_CODE_PREFIX <- "QDEMO_"
# Seats answered-but-zero-theme commenters into the Multi_Mention base, so theme
# prevalence reads as "% of commenters" (not "% of theme-mentioners"). Non-blank but
# not a theme option, so it counts toward the base without becoming a theme row.
QUAL_NO_THEME_SENTINEL <- "(no theme mentioned)"

#' Slugify a demographic label into a synthetic banner question code.
qual_demo_code <- function(label) {
  slug <- gsub("^_+|_+$", "", toupper(gsub("[^A-Za-z0-9]+", "_", trimws(label))))
  paste0(QUAL_DEMO_CODE_PREFIX, if (nzchar(slug)) slug else "DIM")
}

#' "block" iff the demographic-cuts confidentiality dial is set to block, else "allow".
qual_demographic_cuts_mode <- function(config) {
  if (identical(config$demographic_cuts, "block")) "block" else "allow"
}

#' Per-respondent mentioned theme labels for one themed question (by 0-based index).
#' @return A list length n; each entry is the respondent's mentioned theme labels
#'   (or the no-theme sentinel if they answered but coded none), or NULL if unanswered.
qual_question_mentions <- function(question, id_to_idx, n) {
  mentions <- vector("list", n)
  for (rec in question$records) {
    slot <- unname(id_to_idx[rec$id])
    if (length(slot) != 1L || is.na(slot)) next
    labels <- names(rec$themeVals)
    mentions[[slot + 1L]] <- if (length(labels)) labels else QUAL_NO_THEME_SENTINEL
  }
  mentions
}

#' Build the Multi_Mention slot columns (data.frame) for one themed question.
#' @return list(columns = data.frame of code_1..code_k, k = slot count).
qual_slot_columns <- function(mentions, code) {
  k <- max(1L, max(vapply(mentions, length, integer(1))))
  cols <- lapply(seq_len(k), function(j) {
    vapply(mentions, function(m) if (length(m) >= j) m[[j]] else NA_character_, character(1))
  })
  names(cols) <- paste0(code, "_", seq_len(k))
  list(columns = as.data.frame(cols, stringsAsFactors = FALSE, check.names = FALSE), k = k)
}

#' Option rows (one per theme) for a themed question, keyed by the `code_n` prefix.
qual_theme_options <- function(question) {
  themes <- vapply(question$roles$themes, function(t) t$label, character(1))
  if (!length(themes)) return(NULL)
  data.frame(QuestionCode = paste0(question$code, "_", seq_along(themes)),
             OptionText = themes, DisplayText = themes, ShowInOutput = "Y",
             DisplayOrder = seq_along(themes), BoxCategory = NA_character_,
             stringsAsFactors = FALSE)
}

#' Synthetic survey artifacts (column, question row, options, selection row) for one cut.
qual_demo_artifacts <- function(dim, respondents) {
  code <- qual_demo_code(dim$label)
  column <- vapply(respondents, function(r) {
    v <- r$demos[[dim$label]]
    if (is.null(v) || is.na(v)) NA_character_ else as.character(v)
  }, character(1))
  list(code = code, column = column,
       options = data.frame(QuestionCode = code, OptionText = dim$values,
                            DisplayText = dim$values, ShowInOutput = "Y",
                            DisplayOrder = seq_along(dim$values), BoxCategory = NA_character_,
                            stringsAsFactors = FALSE),
       question = data.frame(QuestionCode = code, Variable_Type = "Single_Choice",
                             Columns = NA_integer_, QuestionText = dim$label,
                             stringsAsFactors = FALSE),
       selection = data.frame(QuestionCode = code, UseBanner = "Y", DisplayOrder = NA_integer_,
                              BannerLabel = dim$label, BannerBoxCategory = NA_character_,
                              stringsAsFactors = FALSE))
}

#' Themed question -> (slot columns, Multi_Mention question row, theme options).
qual_themed_artifacts <- function(question, id_to_idx, n) {
  slots <- qual_slot_columns(qual_question_mentions(question, id_to_idx, n), question$code)
  list(columns = slots$columns,
       question = data.frame(QuestionCode = question$code, Variable_Type = "Multi_Mention",
                             Columns = slots$k, QuestionText = question$title,
                             stringsAsFactors = FALSE),
       options = qual_theme_options(question))
}

#' Construct the synthetic survey_data + survey_structure + banner selection_df.
#'
#' @param questions Classified questions from the reader (themed ones are used).
#' @param master The respondent master from `qual_build_respondent_master()`.
#' @param demographic_cuts "allow" or "block" — block yields a Total-only banner.
#' @return list(survey_data, survey_structure, selection_df, themed_codes).
qual_build_synthetic_inputs <- function(questions, master, demographic_cuts = "allow") {
  themed <- Filter(function(q) identical(q$type, "themed"), questions)
  n <- master$n
  survey_cols <- list()
  q_rows <- list()
  opt_rows <- list()
  themed_codes <- character(0)
  for (question in themed) {
    art <- qual_themed_artifacts(question, master$id_to_idx, n)
    survey_cols <- c(survey_cols, as.list(art$columns))
    q_rows[[length(q_rows) + 1L]] <- art$question
    opt_rows[[length(opt_rows) + 1L]] <- art$options
    themed_codes <- c(themed_codes, question$code)
  }
  selection_rows <- list()
  if (!identical(demographic_cuts, "block")) {
    for (dim in master$banner_dims) {
      art <- qual_demo_artifacts(dim, master$respondents)
      survey_cols[[art$code]] <- art$column
      q_rows[[length(q_rows) + 1L]] <- art$question
      opt_rows[[length(opt_rows) + 1L]] <- art$options
      selection_rows[[length(selection_rows) + 1L]] <- art$selection
    }
  }
  list(survey_data = qual_assemble_survey_data(survey_cols, n),
       survey_structure = list(questions = do.call(rbind, q_rows),
                               options = do.call(rbind, Filter(Negate(is.null), opt_rows))),
       selection_df = qual_assemble_selection(selection_rows),
       themed_codes = themed_codes)
}

#' Assemble the synthetic survey_data, guaranteeing n rows even with no columns.
qual_assemble_survey_data <- function(survey_cols, n) {
  if (!length(survey_cols)) return(data.frame(.qual_dummy = rep(NA_character_, n)))
  as.data.frame(survey_cols, stringsAsFactors = FALSE, check.names = FALSE)
}

#' Assemble the banner selection_df, returning an empty (Total-only) frame when blocked.
qual_assemble_selection <- function(selection_rows) {
  if (length(selection_rows)) return(do.call(rbind, selection_rows))
  data.frame(QuestionCode = character(0), UseBanner = character(0),
             DisplayOrder = integer(0), BannerLabel = character(0),
             BannerBoxCategory = character(0), stringsAsFactors = FALSE)
}

#' Build the unweighted, dual-sig config object the qual quant run uses.
qual_quant_config <- function(config = list()) {
  min_base <- config$significance_min_base
  build_config_object(list(
    apply_weighting = FALSE, enable_significance_testing = TRUE,
    show_percent_column = TRUE, show_frequency = TRUE,
    alpha = 0.05, alpha_secondary = 0.20, bonferroni_correction = TRUE,
    significance_min_base = if (is.null(min_base)) 30 else min_base,
    project_name = if (is.null(config$project_name)) "Qualitative" else config$project_name,
    html_report_v2 = TRUE
  ))
}

#' Serialise themed qual questions into DATA_AGG + DATA_MICRO via the existing engine.
#'
#' @param questions Classified questions from the reader.
#' @param master The respondent master from `qual_build_respondent_master()`.
#' @param config List with optional `demographic_cuts`, `significance_min_base`, `project_name`.
#' @return list(agg, micro, banner); agg/micro are NULL when there are no themed questions.
#' @examples
#' \dontrun{
#'   ql <- qual_build_quant_layer(res$questions, master, list(demographic_cuts = "allow"))
#'   ql$agg$questions[[1]]$rows   # theme rows with pct/n/sig per banner column
#' }
qual_build_quant_layer <- function(questions, master, config = list()) {
  inputs <- qual_build_synthetic_inputs(questions, master, qual_demographic_cuts_mode(config))
  if (!length(inputs$themed_codes)) return(list(agg = NULL, micro = NULL, banner = NULL))
  banner_info <- create_banner_structure(inputs$selection_df, inputs$survey_structure)
  config_obj <- qual_quant_config(config)
  weights <- rep(1, nrow(inputs$survey_data))
  questions_to_process <- data.frame(QuestionCode = inputs$themed_codes,
                                      BaseFilter = NA, stringsAsFactors = FALSE)
  processed <- process_all_questions(
    questions_to_process, inputs$survey_data, inputs$survey_structure, banner_info, weights,
    config_obj, checkpoint_config = list(enabled = FALSE, file = NULL, frequency = Inf),
    is_weighted = FALSE, total_column = "Total")
  dl <- build_data_layer(processed$all_results, banner_info, config_obj, inputs$survey_structure)
  micro <- build_microdata(dl, inputs$survey_data, inputs$survey_structure, banner_info, config_obj)
  list(agg = dl, micro = micro, banner = banner_info)
}

# ==============================================================================
# BRAND MODULE - ROLE MAP LOADER (ROLE-REGISTRY ARCHITECTURE)
# ==============================================================================
# Reads QuestionMap + OptionMap from Survey_Structure.xlsx and resolves each
# declared role into a concrete column spec against the study's Brand / CEP
# lists. Output is consumed by every analytical element that has migrated to
# the role-registry architecture (funnel first; MA + others to follow).
#
# Reference:
# - modules/brand/docs/ROLE_REGISTRY.md  (role catalogue + schema)
# - modules/brand/docs/FUNNEL_SPEC_v2.md (first consumer)
#
# VERSION: 1.0
# ==============================================================================

BRAND_ROLE_MAP_VERSION <- "1.0"


# ==============================================================================
# CONSTANTS
# ==============================================================================

# Allowed Variable_Type values. Shared vocabulary with the tabs module; keep
# in sync with modules/tabs/lib/validation/structure_validators.R.
BRAND_VARIABLE_TYPES <- c(
  "Single_Response", "Multi_Mention", "Rating", "Likert", "NPS",
  "Ranking", "Numeric", "Open_End", "Grid_Single", "Grid_Multi"
)

# Pattern tokens the resolver understands. Aliases (no-underscore vs
# underscore) accept either spelling in the QuestionMap without relitigating
# every author's preference.
.BRAND_PATTERN_TOKENS <- list(
  brand  = c("{brandcode}", "{brand_code}"),
  cep    = c("{cepcode}",   "{cep_code}"),
  asset  = c("{assetcode}", "{asset_code}"),
  index  = c("{index}")
)


# ==============================================================================
# PUBLIC ENTRY
# ==============================================================================

#' Build a role map from a loaded Survey_Structure
#'
#' Walks the QuestionMap sheet (one row per role the project populates) and
#' returns a named list keyed by role. Each entry carries the resolved
#' column names, the raw pattern, the declared Variable_Type, the option map
#' scale (when relevant), and the client-facing question text drawn from the
#' same sheet. The resolver expands compound patterns like
#' \code{{code}_{cep_code}_{brand_code}} via Cartesian product of the brand
#' and CEP lists supplied in the Survey_Structure.
#'
#' The loader does \strong{not} validate that the resolved columns exist in
#' the data or that option maps are complete. That is the guard layer's job
#' (see \code{guard_validate_role_map}). Keeping resolution and validation
#' separate lets the loader fail on pattern / token problems only, and lets
#' consumers introspect the map before deciding whether to proceed.
#'
#' @param structure List. Output of \code{load_brand_survey_structure()}.
#'   Must contain \code{questionmap} (QuestionMap sheet) and optionally
#'   \code{optionmap} (OptionMap sheet), \code{brands}, \code{ceps},
#'   \code{dba_assets}.
#' @param brand_list Data frame or NULL. Falls back to \code{structure$brands}.
#'   Must contain a BrandCode column when per-brand patterns are used.
#' @param cep_list Data frame or NULL. Falls back to \code{structure$ceps}.
#'   Must contain a CEPCode column when per-CEP patterns are used.
#' @param asset_list Data frame or NULL. Falls back to \code{structure$dba_assets}.
#'   Must contain an AssetCode column when per-asset patterns are used.
#'
#' @return Named list. One entry per QuestionMap row, keyed by \code{Role}.
#'   Each entry is a list with fields role, client_code, question_text,
#'   question_text_short, variable_type, column_pattern, columns, option_map,
#'   option_scale, notes.
#'
#' @examples
#' \dontrun{
#'   structure <- load_brand_survey_structure("Survey_Structure.xlsx")
#'   role_map  <- load_role_map(structure)
#'   role_map[["funnel.awareness"]]$columns
#' }
#'
#' @export
load_role_map <- function(structure,
                          brand_list = NULL,
                          cep_list   = NULL,
                          asset_list = NULL) {

  .require_structure(structure)
  questionmap <- .require_questionmap(structure$questionmap)

  ctx <- list(
    brand_list = brand_list %||% structure$brands,
    cep_list   = cep_list   %||% structure$ceps,
    asset_list = asset_list %||% structure$dba_assets,
    optionmap  = structure$optionmap
  )

  role_map <- list()
  for (i in seq_len(nrow(questionmap))) {
    entry <- .build_role_entry(questionmap[i, , drop = FALSE], ctx, i)
    role_map[[entry$role]] <- entry
  }
  role_map
}


# ==============================================================================
# INTERNAL: TOP-LEVEL ARG VALIDATION
# ==============================================================================

.require_structure <- function(structure) {
  if (!is.null(structure)) return(invisible(TRUE))
  brand_refuse(
    code = "CFG_NULL_STRUCTURE",
    title = "No Survey Structure",
    problem = "Role map cannot be built: structure argument is NULL.",
    why_it_matters = paste(
      "Every analytical element reads data by role rather than by hardcoded",
      "column name. Without the Survey_Structure contents, no role can be",
      "resolved to data columns."
    ),
    how_to_fix = "Load the structure via load_brand_survey_structure() first."
  )
}


.require_questionmap <- function(questionmap) {
  if (!is.null(questionmap) && nrow(questionmap) > 0) return(questionmap)
  brand_refuse(
    code = "CFG_QUESTIONMAP_MISSING",
    title = "QuestionMap Sheet Missing or Empty",
    problem = paste(
      "Survey_Structure.xlsx does not contain a populated QuestionMap",
      "sheet. The role-registry architecture requires one row per role",
      "the project populates."
    ),
    why_it_matters = paste(
      "Elements that have migrated to the role registry (funnel in v1)",
      "cannot resolve a single column without QuestionMap. The legacy",
      "Questions sheet is kept for elements that have not migrated yet,",
      "but the funnel element requires QuestionMap."
    ),
    how_to_fix = c(
      "Open Survey_Structure.xlsx and add a QuestionMap sheet.",
      paste("Columns: Role, ClientCode, QuestionText, QuestionTextShort,",
            "Variable_Type, ColumnPattern, OptionMapScale, Notes."),
      "See modules/brand/docs/ROLE_REGISTRY.md for the full schema."
    )
  )
}


# ==============================================================================
# INTERNAL: ROW -> ROLE ENTRY
# ==============================================================================

#' Convert one QuestionMap row into a role-map entry
#' @keywords internal
.build_role_entry <- function(row, ctx, row_index) {

  role          <- .require_role_name(.trim_or_na(row$Role), row_index)
  client_code   <- .trim_or_na(row$ClientCode)
  variable_type <- .require_variable_type(.trim_or_na(row$Variable_Type), role)

  pattern <- .trim_or_na(row$ColumnPattern)
  if (is.na(pattern) || pattern == "") pattern <- "{code}"

  columns <- .resolve_column_pattern(pattern, client_code, ctx, role)
  opt_rows <- .lookup_option_scale(.trim_or_na(row$OptionMapScale), ctx$optionmap)

  list(
    role                = role,
    client_code         = client_code,
    question_text       = .trim_or_na(row$QuestionText),
    question_text_short = .nonblank(.trim_or_na(row$QuestionTextShort),
                                    fallback = .trim_or_na(row$QuestionText)),
    variable_type       = variable_type,
    column_pattern      = pattern,
    columns             = columns,
    option_map          = opt_rows,
    option_scale        = .trim_or_na(row$OptionMapScale),
    notes               = .nonblank(.trim_or_na(row$Notes), fallback = "")
  )
}


.require_role_name <- function(role, row_index) {
  if (!is.na(role) && role != "") return(role)
  brand_refuse(
    code = "CFG_ROLE_BLANK",
    title = "QuestionMap Row Has No Role",
    problem = sprintf("QuestionMap row %d has an empty Role cell.", row_index),
    why_it_matters = paste(
      "Every QuestionMap row declares a single role the module can read",
      "data by. A blank Role cell is always an operator error."
    ),
    how_to_fix = c(
      "Fill in the Role column for this row with a registry role name",
      "(e.g. funnel.awareness).",
      "See modules/brand/docs/ROLE_REGISTRY.md."
    )
  )
}


.require_variable_type <- function(variable_type, role) {
  if (is.na(variable_type) || variable_type == "") {
    brand_refuse(
      code = "CFG_VARIABLE_TYPE_BLANK",
      title = "Role Is Missing Variable_Type",
      problem = sprintf("Role '%s' has no Variable_Type declared.", role),
      why_it_matters = paste(
        "Variable_Type controls how data is interpreted (codes vs binary",
        "vs numeric). Without it the module cannot decide how to read the",
        "column."
      ),
      how_to_fix = c(
        sprintf("Set Variable_Type for role '%s' in QuestionMap.", role),
        sprintf("Allowed values: %s.",
                paste(BRAND_VARIABLE_TYPES, collapse = ", "))
      )
    )
  }
  if (!(variable_type %in% BRAND_VARIABLE_TYPES)) {
    brand_refuse(
      code = "CFG_VARIABLE_TYPE_INVALID",
      title = "Unrecognised Variable_Type",
      problem = sprintf("Role '%s' declares Variable_Type = '%s'.",
                        role, variable_type),
      why_it_matters = paste(
        "The brand module shares its Variable_Type vocabulary with the",
        "tabs module. An unrecognised value means either a typo or a type",
        "the platform does not yet support."
      ),
      how_to_fix = c(
        sprintf("Change Variable_Type for role '%s' to an allowed value.", role),
        sprintf("Allowed: %s.", paste(BRAND_VARIABLE_TYPES, collapse = ", "))
      ),
      expected = paste(BRAND_VARIABLE_TYPES, collapse = ", "),
      observed = variable_type
    )
  }
  variable_type
}


.lookup_option_scale <- function(scale_name, optionmap) {
  if (is.na(scale_name) || scale_name == "") return(NULL)
  if (is.null(optionmap) || nrow(optionmap) == 0) return(NULL)
  sub <- optionmap[
    !is.na(optionmap$Scale) &
      trimws(as.character(optionmap$Scale)) == scale_name,
    , drop = FALSE]
  if (nrow(sub) == 0) return(NULL)
  sub
}


# ==============================================================================
# INTERNAL: PATTERN RESOLUTION
# ==============================================================================

#' Resolve a ColumnPattern template to concrete column names
#'
#' Substitutes \code{{code}} with \code{client_code}, then expands any
#' remaining list-valued tokens (\code{{brandcode}}, \code{{cep_code}},
#' \code{{asset_code}}, \code{{index}}) via the Cartesian product of their
#' source lists. Unknown tokens refuse loud with \code{CFG_PATTERN_INVALID}.
#'
#' @keywords internal
.resolve_column_pattern <- function(pattern, client_code, ctx, role) {

  if (is.na(client_code) || client_code == "") client_code <- ""
  resolved <- gsub("{code}", client_code, pattern, fixed = TRUE)

  matches <- regmatches(resolved, gregexpr("\\{[a-z_]+\\}", resolved))[[1]]
  if (length(matches) == 0) return(resolved)

  unique_tokens <- unique(matches)
  value_lists <- lapply(unique_tokens, .values_for_token,
                        ctx = ctx, role = role)
  names(value_lists) <- unique_tokens

  combos <- do.call(expand.grid,
                    c(value_lists, list(stringsAsFactors = FALSE)))
  if (nrow(combos) == 0) return(character(0))

  vapply(seq_len(nrow(combos)), function(i) {
    out <- resolved
    for (tok in unique_tokens) {
      out <- gsub(tok, combos[[tok]][i], out, fixed = TRUE)
    }
    out
  }, character(1))
}


#' Dispatch a single token to its list of values
#' @keywords internal
.values_for_token <- function(token, ctx, role) {
  token_clean <- gsub("[{}]", "", token)
  bucket <- .classify_token(token_clean)
  if (is.na(bucket)) .refuse_unknown_token(token_clean, role)

  switch(bucket,
    brand = .values_brand(ctx$brand_list, token_clean, role),
    cep   = .values_cep(ctx$cep_list, token_clean, role),
    asset = .values_asset(ctx$asset_list, token_clean, role),
    index = .values_index(ctx$asset_list, role)
  )
}


.classify_token <- function(token_clean) {
  for (bucket in names(.BRAND_PATTERN_TOKENS)) {
    canon <- paste0("{", token_clean, "}")
    if (canon %in% .BRAND_PATTERN_TOKENS[[bucket]]) return(bucket)
  }
  NA_character_
}


.values_brand <- function(brand_list, token_clean, role) {
  if (is.null(brand_list) || nrow(brand_list) == 0 ||
      !("BrandCode" %in% names(brand_list))) {
    .refuse_missing_list(
      code      = "CFG_BRAND_LIST_MISSING",
      title     = "Brand List Unavailable for Pattern Expansion",
      list_name = "Brands",
      key_col   = "BrandCode",
      token     = token_clean,
      role      = role
    )
  }
  as.character(brand_list$BrandCode)
}


.values_cep <- function(cep_list, token_clean, role) {
  if (is.null(cep_list) || nrow(cep_list) == 0 ||
      !("CEPCode" %in% names(cep_list))) {
    .refuse_missing_list(
      code      = "CFG_CEP_LIST_MISSING",
      title     = "CEP List Unavailable for Pattern Expansion",
      list_name = "CEPs",
      key_col   = "CEPCode",
      token     = token_clean,
      role      = role
    )
  }
  as.character(cep_list$CEPCode)
}


.values_asset <- function(asset_list, token_clean, role) {
  if (is.null(asset_list) || nrow(asset_list) == 0 ||
      !("AssetCode" %in% names(asset_list))) {
    .refuse_missing_list(
      code      = "CFG_ASSET_LIST_MISSING",
      title     = "DBA Asset List Unavailable for Pattern Expansion",
      list_name = "DBA_Assets",
      key_col   = "AssetCode",
      token     = token_clean,
      role      = role
    )
  }
  as.character(asset_list$AssetCode)
}


.values_index <- function(asset_list, role) {
  n <- if (!is.null(asset_list)) nrow(asset_list) else 0L
  if (n == 0) {
    brand_refuse(
      code = "CFG_INDEX_LIST_MISSING",
      title = "No List to Index Over",
      problem = sprintf(
        "Role '%s' uses '{index}' but no asset list is available to index.",
        role),
      why_it_matters = paste(
        "{index} expands to 1..N. The current implementation uses the",
        "DBA asset list as its indexable source, so an empty list leaves",
        "nothing to expand."
      ),
      how_to_fix = c(
        "Populate DBA_Assets in Survey_Structure.xlsx.",
        "Or replace {index} with a more specific token like {asset_code}."
      )
    )
  }
  as.character(seq_len(n))
}


.refuse_missing_list <- function(code, title, list_name, key_col, token, role) {
  brand_refuse(
    code = code,
    title = title,
    problem = sprintf(
      "Role '%s' uses '{%s}' but no usable %s list is available.",
      role, token, list_name),
    why_it_matters = sprintf(paste(
      "Per-%s patterns produce one column per entry. Without a %s column",
      "on the %s sheet, the resolver has nothing to expand over."),
      tolower(list_name), key_col, list_name),
    how_to_fix = c(
      sprintf("Populate the %s sheet in Survey_Structure.xlsx.", list_name),
      sprintf("%s column is required.", key_col)
    )
  )
}


.refuse_unknown_token <- function(token_clean, role) {
  brand_refuse(
    code = "CFG_PATTERN_INVALID",
    title = "Unknown ColumnPattern Token",
    problem = sprintf(
      "Role '%s' uses token '{%s}' which the resolver does not recognise.",
      role, token_clean),
    why_it_matters = paste(
      "Pattern tokens are the only way role-map resolution walks from a",
      "template to a set of data columns. An unknown token means the",
      "column set cannot be determined."
    ),
    how_to_fix = c(
      "Use only the supported tokens:",
      "  {code}       - the row's ClientCode",
      "  {brandcode}  or {brand_code} - one value per brand",
      "  {cepcode}    or {cep_code}   - one value per CEP",
      "  {assetcode}  or {asset_code} - one value per DBA asset",
      "  {index}      - ordinal 1..N (asset list length)"
    ),
    observed = sprintf("{%s}", token_clean)
  )
}


# ==============================================================================
# SMALL UTILS (shared within file)
# ==============================================================================

.trim_or_na <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  x <- as.character(x)
  if (is.na(x)) return(NA_character_)
  trimws(x)
}


.nonblank <- function(x, fallback) {
  if (is.na(x) || !nzchar(x)) return(fallback)
  x
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
}

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Brand role-map loader loaded (v%s)",
                  BRAND_ROLE_MAP_VERSION))
}

# ==============================================================================
# AI PROVIDER — Provider Abstraction Layer
# ==============================================================================
#
# Shared infrastructure for LLM interactions via the ellmer package.
# Provider-agnostic: supports Anthropic, OpenAI, Google Gemini, and Ollama.
#
# Functions:
#   create_ai_chat()         — Create an ellmer Chat object for the configured provider
#   call_insight_model()     — Execute a single structured LLM call with error handling
#   get_model_display_name() — Human-readable model name for methodology notes
#
# Dependencies:
#   ellmer (CRAN) — unified R interface to LLM providers
#
# Usage:
#   source("modules/shared/lib/ai/ai_provider.R")
#   chat <- create_ai_chat(ai_config)
#   result <- call_insight_model(prompt, schema, ai_config)
#
# ==============================================================================


# --- Provider Registry --------------------------------------------------------
# Maps provider identifiers to their ellmer constructor functions.
# Extend this list to add new providers without modifying core logic.

AI_PROVIDER_REGISTRY <- list(
  anthropic = list(
    constructor = "ellmer::chat_anthropic",
    env_var     = "ANTHROPIC_API_KEY",
    label       = "Anthropic"
  ),
  openai = list(
    constructor = "ellmer::chat_openai",
    env_var     = "OPENAI_API_KEY",
    label       = "OpenAI"
  ),
  google = list(
    constructor = "ellmer::chat_google_gemini",
    env_var     = "GOOGLE_API_KEY",
    label       = "Google"
  ),
  ollama = list(
    constructor = "ellmer::chat_ollama",
    env_var     = NULL,
    label       = "Ollama (local)"
  )
)

# --- Rate Limiting ------------------------------------------------------------
AI_RATE_LIMIT_SECONDS <- 0.5


#' Create an ellmer Chat object for the configured provider
#'
#' Constructs a provider-specific Chat object using ellmer's unified interface.
#' The API key is read from the environment variable specified in the config.
#' For Ollama, no API key is required.
#'
#' @param ai_config List with provider, model, and optional ollama_model/ollama_url fields.
#'   Expected fields:
#'   \describe{
#'     \item{provider}{Character. One of "anthropic", "openai", "google", "ollama".}
#'     \item{model}{Character. Model identifier (e.g., "claude-sonnet-4-20250514").}
#'     \item{api_key_env}{Character. Environment variable name holding the API key.}
#'     \item{ollama_model}{Character. Ollama model name (used when provider = "ollama").}
#'     \item{ollama_url}{Character. Ollama endpoint URL (default: "http://localhost:11434").}
#'   }
#'
#' @return An ellmer Chat object, or a TRS refusal list on failure.
#'
#' @examples
#' \dontrun{
#'   config <- list(provider = "anthropic", model = "claude-sonnet-4-20250514",
#'                  api_key_env = "ANTHROPIC_API_KEY")
#'   chat <- create_ai_chat(config)
#' }
create_ai_chat <- function(ai_config) {

  if (!requireNamespace("ellmer", quietly = TRUE)) {
    return(list(
      status     = "REFUSED",
      code       = "PKG_MISSING_ELLMER",
      message    = "The 'ellmer' package is required for AI insights but is not installed",
      how_to_fix = "Install ellmer: install.packages('ellmer')"
    ))
  }

  provider <- ai_config$provider %||% "anthropic"

  if (!provider %in% names(AI_PROVIDER_REGISTRY)) {
    supported <- paste(names(AI_PROVIDER_REGISTRY), collapse = ", ")
    return(list(
      status     = "REFUSED",
      code       = "CFG_UNKNOWN_AI_PROVIDER",
      message    = sprintf("Unknown AI provider '%s'. Supported: %s", provider, supported),
      how_to_fix = sprintf("Set provider to one of: %s", supported)
    ))
  }

  reg <- AI_PROVIDER_REGISTRY[[provider]]

  # Validate API key (not required for Ollama)
  if (!is.null(reg$env_var)) {
    env_var_name <- ai_config$api_key_env %||% reg$env_var
    api_key <- Sys.getenv(env_var_name, "")

    if (!nzchar(api_key)) {
      return(list(
        status     = "REFUSED",
        code       = "CFG_MISSING_API_KEY",
        message    = sprintf("API key environment variable '%s' is not set", env_var_name),
        how_to_fix = sprintf("Set the environment variable: Sys.setenv(%s = 'your-key')",
                             env_var_name)
      ))
    }
  }

  # Build the chat object
  # max_tokens and temperature are set via params() at creation time
  chat <- tryCatch({
    model <- ai_config$model
    p <- ellmer::params(
      max_tokens  = as.integer(ai_config$max_tokens %||% 1500L),
      temperature = ai_config$temperature %||% NULL
    )
    switch(provider,
      "anthropic" = ellmer::chat_anthropic(model = model, params = p),
      "openai"    = ellmer::chat_openai(model = model, params = p),
      "google"    = ellmer::chat_google_gemini(model = model, params = p),
      "ollama"    = {
        ollama_model <- ai_config$ollama_model %||% model
        ollama_url   <- ai_config$ollama_url %||% "http://localhost:11434"
        ellmer::chat_ollama(model = ollama_model, base_url = ollama_url, params = p)
      }
    )
  }, error = function(e) {
    list(
      status     = "REFUSED",
      code       = "CFG_AI_PROVIDER_INIT_FAILED",
      message    = sprintf("Failed to initialise %s chat: %s", provider, e$message),
      how_to_fix = "Check API key, model name, and network connectivity"
    )
  })

  chat
}


#' Execute a single structured LLM call with error handling
#'
#' Sends a prompt to the configured LLM provider and returns a typed R list
#' matching the provided schema. Handles all error cases gracefully, returning
#' NULL on failure (never throws).
#'
#' @param prompt List with `system` and `user` character fields.
#' @param schema An ellmer type_object schema defining the expected response structure.
#' @param ai_config List with AI configuration (provider, model, temperature, max_tokens, etc.).
#'
#' @return A typed R list matching the schema, or NULL on any failure.
#'
#' @examples
#' \dontrun{
#'   prompt <- list(system = "You are a data analyst.", user = "Analyse this data.")
#'   result <- call_insight_model(prompt, my_schema, ai_config)
#' }
call_insight_model <- function(prompt, schema, ai_config) {

  tryCatch({
    chat <- create_ai_chat(ai_config)

    # If create_ai_chat returned a TRS refusal, log and return NULL
    if (is.list(chat) && identical(chat$status, "REFUSED")) {
      cat(sprintf("    [AI ERROR] Provider setup: [%s] %s\n", chat$code, chat$message))
      warning(sprintf("AI provider setup failed: [%s] %s", chat$code, chat$message))
      return(NULL)
    }

    # Set system prompt
    chat$set_system_prompt(prompt$system)

    # Execute structured chat
    result <- chat$chat_structured(
      prompt$user,
      type = schema
    )

    result

  }, error = function(e) {
    cat(sprintf("    [AI ERROR] %s\n", e$message))
    warning(sprintf("AI insight generation failed: %s", e$message))
    NULL
  })
}


#' Generate a human-readable model display name
#'
#' Produces a string like "Claude Sonnet 4 (Anthropic)" for use in
#' methodology notes and report attribution.
#'
#' @param ai_config List with provider and model fields.
#'
#' @return Character string with the display name.
#'
#' @examples
#' \dontrun{
#'   config <- list(provider = "anthropic", model = "claude-sonnet-4-20250514")
#'   get_model_display_name(config)
#'   # "claude-sonnet-4-20250514 (Anthropic)"
#' }
get_model_display_name <- function(ai_config) {
  provider <- ai_config$provider %||% "anthropic"
  model    <- ai_config$model %||% "unknown-model"

  label <- if (provider %in% names(AI_PROVIDER_REGISTRY)) {
    AI_PROVIDER_REGISTRY[[provider]]$label
  } else {
    provider
  }

  # For Ollama, use the ollama_model field if set

  if (provider == "ollama" && !is.null(ai_config$ollama_model)) {
    model <- ai_config$ollama_model
  }

  sprintf("%s (%s)", model, label)
}

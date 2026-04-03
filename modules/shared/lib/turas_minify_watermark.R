# ==============================================================================
# TURAS REPORT WATERMARKING
# ==============================================================================
#
# Invisible client watermarking for Turas HTML reports. Embeds a traceable
# identifier using two independent methods:
#
#   1. JS variable (reversed base64) — protected by obfuscation's string array
#   2. HTML span with zero-width character steganography — survives JS stripping
#
# Both encode the same payload: client name, date, and unique delivery ID.
# A decoder function (turas_decode_watermark) extracts and verifies watermarks
# from delivered reports. The decoder is NOT shipped with deliverables.
#
# Dependencies: base R only (no additional packages)
#
# Version: 1.0
# Date: April 2026
# ==============================================================================


# -- Constants ----------------------------------------------------------------

# Zero-width characters used for steganography encoding
# Each represents a 2-bit value (00, 01, 10, 11)
.WM_ZWC_CHARS <- c(
  "\u200B",  # ZERO WIDTH SPACE        = 00

"\u200C",  # ZERO WIDTH NON-JOINER   = 01
"\u200D",  # ZERO WIDTH JOINER       = 10
"\uFEFF"   # ZERO WIDTH NO-BREAK SP  = 11
)

# Markers for locating watermarks in HTML
.WM_JS_VAR_NAME <- "__turas_build__"
.WM_HTML_MARKER_CLASS <- "turas-wm"

# Base64 alphabet (RFC 4648)
.WM_B64_ALPHABET <- c(LETTERS, letters, 0:9, "+", "/")


# -- Base64 (pure R) ---------------------------------------------------------

#' Base64 Encode a Character String
#'
#' Pure R implementation of base64 encoding (RFC 4648). No external
#' packages required.
#'
#' @param text Character, string to encode.
#' @return Character, base64-encoded string.
#' @keywords internal
.watermark_base64_encode <- function(text) {
  raw_bytes <- charToRaw(text)
  n <- length(raw_bytes)
  if (n == 0L) return("")

  # Pad to multiple of 3
  pad_count <- (3L - n %% 3L) %% 3L
  padded <- c(as.integer(raw_bytes), rep(0L, pad_count))

  result <- character(0)
  for (i in seq(1L, length(padded), by = 3L)) {
    b1 <- padded[i]
    b2 <- padded[i + 1L]
    b3 <- padded[i + 2L]

    idx1 <- bitwShiftR(b1, 2L) + 1L
    idx2 <- bitwOr(bitwShiftL(bitwAnd(b1, 3L), 4L), bitwShiftR(b2, 4L)) + 1L
    idx3 <- bitwOr(bitwShiftL(bitwAnd(b2, 15L), 2L), bitwShiftR(b3, 6L)) + 1L
    idx4 <- bitwAnd(b3, 63L) + 1L

    result <- c(result, .WM_B64_ALPHABET[idx1], .WM_B64_ALPHABET[idx2],
                .WM_B64_ALPHABET[idx3], .WM_B64_ALPHABET[idx4])
  }

  # Replace padding positions with '='
  if (pad_count >= 1L) result[length(result)] <- "="
  if (pad_count >= 2L) result[length(result) - 1L] <- "="

  paste0(result, collapse = "")
}


#' Base64 Decode a Character String
#'
#' Pure R implementation of base64 decoding (RFC 4648).
#'
#' @param encoded Character, base64-encoded string.
#' @return Character, decoded string.
#' @keywords internal
.watermark_base64_decode <- function(encoded) {
  if (!nzchar(encoded)) return("")

  # Build lookup: character -> 0-63
  lookup <- setNames(0:63, .WM_B64_ALPHABET)

  # Strip padding, record count
  pad_count <- nchar(gsub("[^=]", "", encoded))
  clean <- gsub("=", "", encoded)
  chars <- strsplit(clean, "")[[1L]]

  # Pad chars to multiple of 4 for processing
  while (length(chars) %% 4L != 0L) chars <- c(chars, "A")

  raw_out <- integer(0)
  for (i in seq(1L, length(chars), by = 4L)) {
    v1 <- lookup[chars[i]]
    v2 <- lookup[chars[i + 1L]]
    v3 <- lookup[chars[i + 2L]]
    v4 <- lookup[chars[i + 3L]]

    raw_out <- c(raw_out,
                 bitwOr(bitwShiftL(v1, 2L), bitwShiftR(v2, 4L)),
                 bitwOr(bitwShiftL(bitwAnd(v2, 15L), 4L), bitwShiftR(v3, 2L)),
                 bitwOr(bitwShiftL(bitwAnd(v3, 3L), 6L), v4))
  }

  # Remove padding bytes
  if (pad_count > 0L) {
    raw_out <- raw_out[seq_len(length(raw_out) - pad_count)]
  }

  rawToChar(as.raw(raw_out))
}


# -- UUID generation (pure R) ------------------------------------------------

#' Generate a UUID v4-like Identifier
#'
#' Produces a 32-character hex string (no dashes) using R's random number
#' generator. Not cryptographically secure, but sufficient for delivery
#' traceability.
#'
#' @return Character, 32-character hex string.
#' @keywords internal
.watermark_generate_id <- function() {
  hex_chars <- c(0:9, "a", "b", "c", "d", "e", "f")
  paste0(sample(hex_chars, 32L, replace = TRUE), collapse = "")
}


# -- Zero-width character steganography -------------------------------------

#' Encode Text as Zero-Width Characters
#'
#' Converts each byte of the input to 4 zero-width characters (2 bits each),
#' producing an invisible string that renders as nothing in browsers.
#'
#' @param text Character, string to encode.
#' @return Character, zero-width character string.
#' @keywords internal
.watermark_encode_zwc <- function(text) {
  if (!nzchar(text)) return("")

  raw_bytes <- as.integer(charToRaw(text))
  zwc_parts <- character(length(raw_bytes) * 4L)
  pos <- 1L

  for (byte in raw_bytes) {
    zwc_parts[pos]      <- .WM_ZWC_CHARS[bitwShiftR(bitwAnd(byte, 192L), 6L) + 1L]
    zwc_parts[pos + 1L] <- .WM_ZWC_CHARS[bitwShiftR(bitwAnd(byte, 48L), 4L) + 1L]
    zwc_parts[pos + 2L] <- .WM_ZWC_CHARS[bitwShiftR(bitwAnd(byte, 12L), 2L) + 1L]
    zwc_parts[pos + 3L] <- .WM_ZWC_CHARS[bitwAnd(byte, 3L) + 1L]
    pos <- pos + 4L
  }

  paste0(zwc_parts, collapse = "")
}


#' Decode Zero-Width Characters Back to Text
#'
#' Inverse of .watermark_encode_zwc. Extracts the original text from a
#' zero-width character string.
#'
#' @param zwc_string Character, zero-width character string.
#' @return Character, decoded text, or empty string on failure.
#' @keywords internal
.watermark_decode_zwc <- function(zwc_string) {
  if (!nzchar(zwc_string)) return("")

  chars <- strsplit(zwc_string, "")[[1L]]

  # Filter to only ZWC characters
  zwc_lookup <- setNames(0:3, .WM_ZWC_CHARS)
  chars <- chars[chars %in% .WM_ZWC_CHARS]

  if (length(chars) == 0L || length(chars) %% 4L != 0L) return("")

  n_bytes <- length(chars) %/% 4L
  raw_out <- integer(n_bytes)

  for (i in seq_len(n_bytes)) {
    base <- (i - 1L) * 4L
    raw_out[i] <- bitwOr(
      bitwOr(
        bitwShiftL(zwc_lookup[chars[base + 1L]], 6L),
        bitwShiftL(zwc_lookup[chars[base + 2L]], 4L)
      ),
      bitwOr(
        bitwShiftL(zwc_lookup[chars[base + 3L]], 2L),
        zwc_lookup[chars[base + 4L]]
      )
    )
  }

  tryCatch(
    rawToChar(as.raw(raw_out)),
    error = function(e) ""
  )
}


# -- Watermark payload construction -----------------------------------------

#' Build Watermark Payload String
#'
#' Creates a pipe-delimited payload: client|date|id. Uses pipes instead of
#' JSON to avoid needing jsonlite.
#'
#' @param client_name Character, client identifier.
#' @return Named list with payload (character), client (character),
#'   date (character), and id (character).
#' @keywords internal
.watermark_build_payload <- function(client_name) {
  delivery_date <- format(Sys.Date(), "%Y-%m-%d")
  delivery_id <- .watermark_generate_id()
  payload <- paste(client_name, delivery_date, delivery_id, sep = "|")

  list(
    payload = payload,
    client = client_name,
    date = delivery_date,
    id = delivery_id
  )
}


#' Parse Watermark Payload String
#'
#' Extracts client, date, and id from a pipe-delimited payload.
#'
#' @param payload Character, pipe-delimited watermark payload.
#' @return Named list with client, date, id, or NULL on parse failure.
#' @keywords internal
.watermark_parse_payload <- function(payload) {
  parts <- strsplit(payload, "\\|", fixed = FALSE)[[1L]]
  if (length(parts) < 3L) return(NULL)

  list(
    client = parts[1L],
    date = parts[2L],
    id = parts[3L]
  )
}


# -- Watermark injection ----------------------------------------------------

#' Inject Watermark into HTML String
#'
#' Embeds two independent watermarks into an HTML report:
#'
#' 1. A JS variable with reversed base64 of the payload, injected into the
#'    last script block. If obfuscation follows, the string array encoding
#'    will further obscure this value.
#'
#' 2. An invisible HTML span with zero-width character encoding of the
#'    payload, injected before </body>. Survives even if all JS is stripped.
#'
#' @param html Character, full HTML string.
#' @param client_name Character, client identifier to embed.
#' @return Named list with:
#'   \item{html}{Modified HTML string}
#'   \item{client}{Client name embedded}
#'   \item{date}{Delivery date embedded}
#'   \item{id}{Delivery ID embedded}
#'   \item{success}{Logical, TRUE if at least one watermark was injected}
#'
#' @keywords internal
.minify_inject_watermark <- function(html, client_name) {
  if (!is.character(client_name) || !nzchar(client_name)) {
    return(list(html = html, client = "", date = "", id = "",
                success = FALSE))
  }

  wm <- .watermark_build_payload(client_name)
  js_injected <- FALSE
  html_injected <- FALSE

  # -- JS watermark: reversed base64 in a script variable -------------------
  encoded_b64 <- .watermark_base64_encode(wm$payload)
  reversed_b64 <- paste0(rev(strsplit(encoded_b64, "")[[1L]]), collapse = "")
  js_snippet <- sprintf("window.%s=\"%s\";", .WM_JS_VAR_NAME, reversed_b64)

  # Find the LAST </script> tag by locating all occurrences and using the last
  all_close_scripts <- gregexpr("</script>", html, fixed = TRUE)[[1L]]
  if (all_close_scripts[1L] > 0L) {
    last_pos <- all_close_scripts[length(all_close_scripts)]
    html <- paste0(
      substr(html, 1L, last_pos - 1L),
      js_snippet,
      substr(html, last_pos, nchar(html))
    )
    js_injected <- TRUE
  }

  # -- HTML watermark: ZWC span before </body> ------------------------------
  zwc_encoded <- .watermark_encode_zwc(wm$payload)
  # The span is positioned off-screen, font-size 0, invisible to users
  wm_span <- sprintf(
    "<span class=\"%s\" style=\"position:absolute;left:-9999px;font-size:0\">%s</span>",
    .WM_HTML_MARKER_CLASS, zwc_encoded
  )

  body_close <- regexpr("</body>", html, fixed = TRUE)
  if (body_close > 0L) {
    html <- paste0(
      substr(html, 1L, body_close - 1L),
      wm_span,
      substr(html, body_close, nchar(html))
    )
    html_injected <- TRUE
  }

  list(
    html = html,
    client = wm$client,
    date = wm$date,
    id = wm$id,
    success = js_injected || html_injected
  )
}


# -- Watermark extraction (decoder) -----------------------------------------

#' Decode Watermark from a Turas HTML Report
#'
#' Reads an HTML report file and extracts embedded watermarks. Checks both
#' the JS variable (reversed base64) and the HTML span (zero-width chars).
#' This function is a diagnostic tool — it is NOT shipped with deliverables.
#'
#' @param html_path Character, path to the HTML report file.
#' @return Named list with:
#'   \item{status}{"PASS" if watermark found, "REFUSED" if not}
#'   \item{js_watermark}{Decoded JS watermark (list with client/date/id) or NULL}
#'   \item{html_watermark}{Decoded HTML watermark (list with client/date/id) or NULL}
#'   \item{match}{Logical, TRUE if both watermarks decode to the same payload}
#'   \item{message}{Human-readable summary}
#'
#' @examples
#' \dontrun{
#'   result <- turas_decode_watermark("reports/Client_Report.html")
#'   if (result$status == "PASS") {
#'     cat("Client:", result$js_watermark$client, "\n")
#'     cat("Delivered:", result$js_watermark$date, "\n")
#'   }
#' }
#'
#' @export
turas_decode_watermark <- function(html_path) {
  if (!is.character(html_path) || length(html_path) != 1L || !nzchar(html_path)) {
    return(list(status = "REFUSED", js_watermark = NULL, html_watermark = NULL,
                match = FALSE,
                message = "html_path must be a single non-empty character string"))
  }
  if (!file.exists(html_path)) {
    return(list(status = "REFUSED", js_watermark = NULL, html_watermark = NULL,
                match = FALSE,
                message = sprintf("File not found: %s", html_path)))
  }

  html <- paste(readLines(html_path, warn = FALSE, encoding = "UTF-8"),
                collapse = "\n")

  js_result <- .watermark_extract_js(html)
  html_result <- .watermark_extract_html(html)

  found_any <- !is.null(js_result) || !is.null(html_result)
  both_match <- !is.null(js_result) && !is.null(html_result) &&
    js_result$client == html_result$client &&
    js_result$date == html_result$date

  if (!found_any) {
    return(list(status = "REFUSED", js_watermark = NULL, html_watermark = NULL,
                match = FALSE,
                message = "No watermark found in this file"))
  }

  # Build summary message
  source_wm <- if (!is.null(js_result)) js_result else html_result
  msg <- sprintf("Client: %s | Date: %s | ID: %s",
                 source_wm$client, source_wm$date, source_wm$id)
  if (!is.null(js_result) && !is.null(html_result)) {
    msg <- paste0(msg, if (both_match) " [JS+HTML match]" else " [JS/HTML MISMATCH]")
  } else {
    msg <- paste0(msg, if (!is.null(js_result)) " [JS only]" else " [HTML only]")
  }

  list(
    status = "PASS",
    js_watermark = js_result,
    html_watermark = html_result,
    match = both_match,
    message = msg
  )
}


#' Extract JS Watermark from HTML String
#'
#' Finds the window.__turas_build__ variable, reverses the base64, decodes.
#'
#' @param html Character, full HTML string.
#' @return Named list with client/date/id, or NULL if not found.
#' @keywords internal
.watermark_extract_js <- function(html) {
  pattern <- sprintf("window\\.%s=\"([^\"]+)\"", .WM_JS_VAR_NAME)
  match <- regmatches(html, regexpr(pattern, html, perl = TRUE))

  if (length(match) == 0L || !nzchar(match)) return(NULL)

  # Extract the encoded value between quotes
  value <- sub(sprintf("window\\.%s=\"", .WM_JS_VAR_NAME), "", match, fixed = FALSE)
  value <- sub("\"$", "", value)

  # Reverse and decode
  reversed <- paste0(rev(strsplit(value, "")[[1L]]), collapse = "")
  decoded <- tryCatch(
    .watermark_base64_decode(reversed),
    error = function(e) ""
  )

  if (!nzchar(decoded)) return(NULL)

  .watermark_parse_payload(decoded)
}


#' Extract HTML Watermark from HTML String
#'
#' Finds the turas-wm span and decodes its zero-width character content.
#'
#' @param html Character, full HTML string.
#' @return Named list with client/date/id, or NULL if not found.
#' @keywords internal
.watermark_extract_html <- function(html) {
  # Find the span with turas-wm class
  pattern <- sprintf("<span class=\"%s\"[^>]*>([^<]*)</span>", .WM_HTML_MARKER_CLASS)
  match <- regmatches(html, regexpr(pattern, html, perl = TRUE))

  if (length(match) == 0L || !nzchar(match)) return(NULL)

  # Extract content between tags
  content <- sub("^<span[^>]*>", "", match)
  content <- sub("</span>$", "", content)

  if (!nzchar(content)) return(NULL)

  decoded <- .watermark_decode_zwc(content)
  if (!nzchar(decoded)) return(NULL)

  .watermark_parse_payload(decoded)
}

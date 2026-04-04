# ==============================================================================
# TURAS REPORT MINIFICATION PIPELINE
# ==============================================================================
#
# Post-processing pipeline that takes a finished Turas HTML report and produces
# a minified deliverable. Reduces file size and casual readability for IP
# protection. Operates on the final HTML output — does not modify R generation
# code.
#
# Dependencies:
#   - Node.js tools: terser, clean-css-cli, html-minifier-terser (optional;
#     graceful degradation if missing)
#   - R: base R only (no additional packages)
#   - turas_minify_verify.R (verification helpers, loaded via import_all.R)
#   - trs_refusal.R (TRS error handling, loaded via import_all.R)
#
# Usage:
#   result <- turas_minify("reports/Project_dev.html", verbose = TRUE)
#
# Version: 1.0
# Date: April 2026
# ==============================================================================


# -- Constants ----------------------------------------------------------------

.MINIFY_VERSION <- "2.0"

.MINIFY_COPYRIGHT_TEMPLATE <- "/*! @preserve Turas (c) TRL %s. All rights reserved. */"

.MINIFY_TERSER_ARGS <- c(
  "--compress", "passes=2,dead_code=true,drop_console=false",
  "--mangle", "toplevel=false",
  "--no-mangle-props",
  "--comments", "some",
  "--output", "beautify=false"
)

.MINIFY_CLEANCSS_ARGS <- c("-O1")

.MINIFY_HTML_ARGS <- c(
  "--collapse-whitespace",
  "--conservative-collapse",
  "--remove-comments"
)

.MINIFY_TOOL_TIMEOUT_SECS <- 60L

# javascript-obfuscator config — written to a temp JSON file per invocation.
# renameGlobals=false: 676+ inline onclick handlers reference top-level functions.
# renameProperties=false: window.TurasPins.move() in dynamic onclick strings.
# stringArray + base64: primary IP protection — extracts all string literals
# into an encoded array, making casual reading impossible.
.MINIFY_OBFUSCATOR_CONFIG_JSON <- '{
  "compact": true,
  "stringArray": true,
  "stringArrayThreshold": 0.8,
  "stringArrayEncoding": ["base64"],
  "stringArrayShuffle": true,
  "controlFlowFlattening": false,
  "renameGlobals": false,
  "renameProperties": false,
  "selfDefending": false,
  "deadCodeInjection": false,
  "disableConsoleOutput": false,
  "log": false
}'

.MINIFY_NODE_SEARCH_PATHS <- c(
  "/opt/homebrew/bin",       # macOS Homebrew (Apple Silicon)
  "/usr/local/bin",          # macOS Homebrew (Intel) / manual installs
  "/usr/bin",                # Linux system packages / Docker
  "/usr/lib/node_modules/.bin"  # Linux global npm fallback
)


# -- Path helpers -------------------------------------------------------------

#' Derive Output Path from Input Path
#'
#' Applies the naming convention: if input has _dev suffix, output removes it.
#' Otherwise appends _min suffix.
#'
#' @param input_path Character, path to input HTML file.
#' @return Character, derived output path.
#' @keywords internal
.minify_derive_output_path <- function(input_path) {
  dir_name <- dirname(input_path)
  base_name <- tools::file_path_sans_ext(basename(input_path))
  ext <- tools::file_ext(basename(input_path))

  if (grepl("_dev$", base_name)) {
    clean_name <- sub("_dev$", "", base_name)
  } else {
    clean_name <- paste0(base_name, "_min")
  }

  file.path(dir_name, paste0(clean_name, ".", ext))
}


# -- Tool availability --------------------------------------------------------

#' Find a Node.js Tool on the System
#'
#' Searches standard paths and PATH for a named tool (terser, cleancss, etc.).
#' Returns the full path if found, empty string if not.
#'
#' @param tool_name Character, name of the tool binary.
#' @return Character, full path to tool or empty string.
#' @keywords internal
.minify_find_tool <- function(tool_name) {
  # Try Sys.which first (respects PATH)
  found <- Sys.which(tool_name)
  if (nzchar(found)) return(as.character(found))

  # Search common Node.js install locations

  for (search_path in .MINIFY_NODE_SEARCH_PATHS) {
    candidate <- file.path(search_path, tool_name)
    if (file.exists(candidate)) return(candidate)
  }

  ""
}


#' Check All Required Tools and Return Availability Map
#'
#' @return Named list with node, terser, cleancss, html_minifier paths (empty
#'   string if not found).
#' @keywords internal
.minify_check_tools <- function() {
  list(
    node          = .minify_find_tool("node"),
    terser        = .minify_find_tool("terser"),
    cleancss      = .minify_find_tool("cleancss"),
    html_minifier = .minify_find_tool("html-minifier-terser"),
    obfuscator    = .minify_find_tool("javascript-obfuscator")
  )
}


# -- Block extraction ---------------------------------------------------------

#' Extract Tagged Blocks from HTML
#'
#' Extracts content and positions of <style> or <script> blocks. For script
#' blocks, also captures the type attribute to allow skipping non-JS blocks.
#'
#' @param html Character, full HTML string.
#' @param tag Character, either "style" or "script".
#' @return List of lists, each with: content, start, end, type (for script),
#'   full_match (the complete tag including opening/closing tags).
#' @keywords internal
# SIZE-EXCEPTION: Block extraction requires inline filtering of style blocks
# inside script blocks, type attribute parsing, and position tracking. Splitting
# would fragment a coherent extraction pipeline that shares regex match state.
.minify_extract_blocks <- function(html, tag) {
  # Match only standalone HTML tags, not substrings (e.g., <styleSheet> in
  # Excel export XML). The tag must be followed by > or whitespace, not a letter.
  # Case-sensitive — Turas generates lowercase HTML tags; uppercase <Style> in
  # JS string literals (Excel export) must not match.
  pattern <- paste0("(<", tag, "(?=[\\s>])[^>]*>)([\\s\\S]*?)(</", tag, ">)")
  matches <- gregexpr(pattern, html, perl = TRUE)[[1]]
  if (matches[1] == -1L) return(list())

  # When extracting <style> blocks, filter out any that fall inside a <script>
  # block. JS string literals can contain "<style>...</style>" (e.g., the
  # dashboard styles wrapper function).
  script_ranges <- NULL
  if (tag == "style") {
    sp <- paste0("(<script(?=[\\s>])[^>]*>)([\\s\\S]*?)(</script>)")
    sm <- gregexpr(sp, html, perl = TRUE)[[1]]
    if (sm[1] != -1L) {
      script_ranges <- data.frame(
        start = as.integer(sm),
        end   = as.integer(sm) + attr(sm, "match.length") - 1L
      )
    }
  }

  match_lengths <- attr(matches, "match.length")
  blocks <- vector("list", length(matches))

  for (i in seq_along(matches)) {
    start_pos <- matches[i]
    end_pos <- start_pos + match_lengths[i] - 1L

    # Skip style blocks that fall inside a script block
    if (!is.null(script_ranges)) {
      inside_script <- any(
        start_pos >= script_ranges$start & start_pos <= script_ranges$end
      )
      if (inside_script) next
    }

    full_match <- substr(html, start_pos, end_pos)

    # Extract opening tag to get type attribute
    open_tag_match <- regexpr(sprintf("<%s[^>]*>", tag), full_match,
                              perl = TRUE, ignore.case = TRUE)
    open_tag <- regmatches(full_match, open_tag_match)

    block_type <- ""
    if (tag == "script") {
      type_match <- regexpr('type\\s*=\\s*["\']([^"\']*)["\']', open_tag,
                            perl = TRUE, ignore.case = TRUE)
      if (type_match > 0) {
        # Extract captured group
        cap_start <- attr(type_match, "capture.start")[1]
        cap_length <- attr(type_match, "capture.length")[1]
        block_type <- substr(open_tag, cap_start, cap_start + cap_length - 1L)
      }
    }

    # Extract inner content (between opening and closing tags)
    open_tag_len <- attr(open_tag_match, "match.length")
    close_tag_len <- nchar(sprintf("</%s>", tag))
    inner_start <- open_tag_len + 1L
    inner_end <- nchar(full_match) - close_tag_len
    content <- if (inner_start <= inner_end) {
      substr(full_match, inner_start, inner_end)
    } else {
      ""
    }

    blocks[[i]] <- list(
      content    = content,
      start      = start_pos,
      end        = end_pos,
      type       = block_type,
      tag_name   = tag,
      open_tag   = open_tag,
      full_match = full_match
    )
  }

  # Remove NULL entries from skipped blocks
  Filter(Negate(is.null), blocks)
}


# -- Meta tag stripping -------------------------------------------------------

#' Strip Turas Meta Tags
#'
#' Removes all <meta> tags where the name attribute starts with "turas-".
#' Preserves charset, viewport, and all other meta tags.
#'
#' @param html Character, full HTML string.
#' @return Named list with html (modified string) and count (tags removed).
#' @keywords internal
.minify_strip_meta_tags <- function(html) {
  pattern <- '<meta\\s+name\\s*=\\s*"turas-[^"]*"\\s+content\\s*=\\s*"[^"]*"\\s*/?>'
  count <- length(gregexpr(pattern, html, perl = TRUE, ignore.case = TRUE)[[1]])
  if (count == 1L && gregexpr(pattern, html, perl = TRUE, ignore.case = TRUE)[[1]][1] == -1L) {
    count <- 0L
  }
  html <- gsub(pattern, "", html, perl = TRUE, ignore.case = TRUE)
  # Also handle reversed attribute order (content before name)
  pattern_rev <- '<meta\\s+content\\s*=\\s*"[^"]*"\\s+name\\s*=\\s*"turas-[^"]*"\\s*/?>'
  count_rev <- length(gregexpr(pattern_rev, html, perl = TRUE, ignore.case = TRUE)[[1]])
  if (count_rev == 1L && gregexpr(pattern_rev, html, perl = TRUE, ignore.case = TRUE)[[1]][1] == -1L) {
    count_rev <- 0L
  }
  html <- gsub(pattern_rev, "", html, perl = TRUE, ignore.case = TRUE)

  list(html = html, count = count + count_rev)
}


# -- Comment removal ----------------------------------------------------------

#' Remove HTML Comments
#'
#' Removes <!-- ... --> comments from HTML. Protects JSON script blocks and
#' conditional comments (<!--[if ...]) from removal.
#'
#' @param html Character, full HTML string.
#' @return Named list with html (modified string) and count (comments removed).
#' @keywords internal
.minify_remove_html_comments <- function(html) {
  # Protect JSON and text/plain script blocks with placeholders
  json_blocks <- .minify_extract_blocks(html, "script")
  protected_blocks <- list()
  placeholder_idx <- 0L

  for (block in json_blocks) {
    if (block$type %in% c("application/json", "text/plain")) {
      placeholder_idx <- placeholder_idx + 1L
      placeholder <- sprintf("__TURAS_PROTECTED_BLOCK_%d__", placeholder_idx)
      protected_blocks[[placeholder]] <- block$full_match
      html <- sub(block$full_match, placeholder, html, fixed = TRUE)
    }
  }

  # Count and remove non-conditional HTML comments
  # Conditional comments start with <!--[if
  comment_pattern <- "<!--(?!\\[if\\s)[\\s\\S]*?-->"
  matches <- gregexpr(comment_pattern, html, perl = TRUE)[[1]]
  count <- if (matches[1] == -1L) 0L else length(matches)
  html <- gsub(comment_pattern, "", html, perl = TRUE)

  # Restore protected blocks
  for (placeholder in names(protected_blocks)) {
    html <- sub(placeholder, protected_blocks[[placeholder]], html, fixed = TRUE)
  }

  list(html = html, count = count)
}


# -- CSS minification ---------------------------------------------------------

#' Minify a Single CSS Block via clean-css
#'
#' Writes CSS to a temp file, runs clean-css, reads back the result.
#' Falls back to original content on failure.
#'
#' @param css_content Character, CSS content to minify.
#' @param cleancss_path Character, path to cleancss binary.
#' @return Named list with content (minified or original) and success (logical).
#' @keywords internal
.minify_css_block <- function(css_content, cleancss_path) {
  if (!nzchar(css_content) || !nzchar(cleancss_path)) {
    return(list(content = css_content, success = FALSE))
  }

  tmp_in <- tempfile(fileext = ".css")
  tmp_out <- tempfile(fileext = ".css")
  on.exit(unlink(c(tmp_in, tmp_out), force = TRUE), add = TRUE)

  writeLines(css_content, tmp_in, useBytes = TRUE)

  args <- c(.MINIFY_CLEANCSS_ARGS, "-o", tmp_out, tmp_in)
  result <- tryCatch(
    system2(cleancss_path, args = args,
            stdout = TRUE, stderr = TRUE,
            timeout = .MINIFY_TOOL_TIMEOUT_SECS),
    error = function(e) e
  )

  exit_status <- attr(result, "status")
  if (inherits(result, "error") ||
      (!is.null(exit_status) && exit_status != 0L) ||
      !file.exists(tmp_out)) {
    return(list(content = css_content, success = FALSE))
  }

  minified <- paste(readLines(tmp_out, warn = FALSE), collapse = "\n")
  if (!nzchar(minified)) {
    return(list(content = css_content, success = FALSE))
  }

  list(content = minified, success = TRUE)
}


# -- JS minification ----------------------------------------------------------

#' Minify a Single JS Block via terser
#'
#' Writes JS to a temp file, runs terser, reads back the result.
#' Injects a copyright comment at the top. Falls back to original on failure.
#'
#' @param js_content Character, JavaScript content to minify.
#' @param terser_path Character, path to terser binary.
#' @return Named list with content (minified or original) and success (logical).
#' @keywords internal
.minify_js_block <- function(js_content, terser_path) {
  if (!nzchar(js_content) || !nzchar(terser_path)) {
    return(list(content = js_content, success = FALSE))
  }

  # Extract vendor sections (already minified — skip them to avoid slow
  # re-parsing of 200KB+ compressed libraries like html2canvas, PptxGenJS).
  # Vendor sections are marked with /* TURAS_VENDOR_START */ ... /* TURAS_VENDOR_END */
  # Uses fixed string search (not regex) to avoid backtracking on large blocks.
  vendor_chunks <- list()
  js_to_minify <- js_content
  vendor_start_marker <- "/* TURAS_VENDOR_START */"
  vendor_end_marker <- "/* TURAS_VENDOR_END */"
  vendor_idx <- 0L

  repeat {
    v_start <- regexpr(vendor_start_marker, js_to_minify, fixed = TRUE)
    if (v_start == -1L) break

    v_end_pos <- regexpr(vendor_end_marker, js_to_minify, fixed = TRUE)
    if (v_end_pos == -1L) break

    v_end <- v_end_pos + nchar(vendor_end_marker) - 1L
    vendor_idx <- vendor_idx + 1L
    v_text <- substr(js_to_minify, v_start, v_end)
    placeholder <- sprintf("function __TURAS_VENDOR_%d__(){}", vendor_idx)
    vendor_chunks[[placeholder]] <- v_text
    js_to_minify <- paste0(
      substr(js_to_minify, 1L, v_start - 1L),
      placeholder,
      substr(js_to_minify, v_end + 1L, nchar(js_to_minify))
    )
  }

  # Prepend copyright notice so terser preserves it via --comments some
  copyright <- sprintf(.MINIFY_COPYRIGHT_TEMPLATE, format(Sys.Date(), "%Y"))
  js_with_copyright <- paste0(copyright, "\n", js_to_minify)

  tmp_in <- tempfile(fileext = ".js")
  tmp_out <- tempfile(fileext = ".js")
  on.exit(unlink(c(tmp_in, tmp_out), force = TRUE), add = TRUE)

  writeLines(js_with_copyright, tmp_in, useBytes = TRUE)

  args <- c(.MINIFY_TERSER_ARGS, tmp_in, "-o", tmp_out)
  result <- tryCatch(
    system2(terser_path, args = args,
            stdout = TRUE, stderr = TRUE,
            timeout = .MINIFY_TOOL_TIMEOUT_SECS),
    error = function(e) e
  )

  exit_status <- attr(result, "status")
  if (inherits(result, "error") || (!is.null(exit_status) && exit_status != 0L)) {
    return(list(content = js_content, success = FALSE))
  }

  if (!file.exists(tmp_out)) {
    return(list(content = js_content, success = FALSE))
  }

  minified <- paste(readLines(tmp_out, warn = FALSE), collapse = "\n")
  if (!nzchar(minified)) {
    return(list(content = js_content, success = FALSE))
  }

  # Re-insert vendor chunks
  for (placeholder in names(vendor_chunks)) {
    minified <- sub(placeholder, vendor_chunks[[placeholder]], minified, fixed = TRUE)
  }

  list(content = minified, success = TRUE)
}


# -- JS obfuscation ----------------------------------------------------------

#' Obfuscate a Single JS Block via javascript-obfuscator
#'
#' Writes JS to a temp file, runs javascript-obfuscator with a static config
#' file, reads back the result. Vendor blocks (TURAS_VENDOR_START/END) are
#' extracted and skipped, same as in minification.
#'
#' @param js_content Character, JavaScript content to obfuscate.
#' @param obfuscator_path Character, path to javascript-obfuscator binary.
#' @return Named list with content (obfuscated or original) and success (logical).
#' @keywords internal
.minify_obfuscate_js_block <- function(js_content, obfuscator_path) {
  if (!nzchar(js_content) || !nzchar(obfuscator_path)) {
    return(list(content = js_content, success = FALSE))
  }

  # Extract vendor sections — same pattern as .minify_js_block()
  vendor_chunks <- list()
  js_to_obfuscate <- js_content
  vendor_start_marker <- "/* TURAS_VENDOR_START */"
  vendor_end_marker <- "/* TURAS_VENDOR_END */"
  vendor_idx <- 0L

  repeat {
    v_start <- regexpr(vendor_start_marker, js_to_obfuscate, fixed = TRUE)
    if (v_start == -1L) break

    v_end_pos <- regexpr(vendor_end_marker, js_to_obfuscate, fixed = TRUE)
    if (v_end_pos == -1L) break

    v_end <- v_end_pos + nchar(vendor_end_marker) - 1L
    vendor_idx <- vendor_idx + 1L
    v_text <- substr(js_to_obfuscate, v_start, v_end)
    placeholder <- sprintf("function __TURAS_VENDOR_%d__(){}", vendor_idx)
    vendor_chunks[[placeholder]] <- v_text
    js_to_obfuscate <- paste0(
      substr(js_to_obfuscate, 1L, v_start - 1L),
      placeholder,
      substr(js_to_obfuscate, v_end + 1L, nchar(js_to_obfuscate))
    )
  }

  tmp_in <- tempfile(fileext = ".js")
  tmp_out <- tempfile(fileext = ".js")
  tmp_config <- tempfile(fileext = ".json")
  on.exit(unlink(c(tmp_in, tmp_out, tmp_config), force = TRUE), add = TRUE)

  writeLines(js_to_obfuscate, tmp_in, useBytes = TRUE)
  writeLines(.MINIFY_OBFUSCATOR_CONFIG_JSON, tmp_config)

  args <- c(tmp_in, "--output", tmp_out, "--config", tmp_config)
  result <- tryCatch(
    system2(obfuscator_path, args = args,
            stdout = TRUE, stderr = TRUE,
            timeout = .MINIFY_TOOL_TIMEOUT_SECS),
    error = function(e) e
  )

  exit_status <- attr(result, "status")
  if (inherits(result, "error") || (!is.null(exit_status) && exit_status != 0L)) {
    return(list(content = js_content, success = FALSE))
  }

  if (!file.exists(tmp_out)) {
    return(list(content = js_content, success = FALSE))
  }

  obfuscated <- paste(readLines(tmp_out, warn = FALSE), collapse = "\n")
  if (!nzchar(obfuscated)) {
    return(list(content = js_content, success = FALSE))
  }

  # Re-insert vendor chunks
  for (placeholder in names(vendor_chunks)) {
    obfuscated <- sub(placeholder, vendor_chunks[[placeholder]], obfuscated,
                      fixed = TRUE)
  }

  list(content = obfuscated, success = TRUE)
}


# -- Block replacement --------------------------------------------------------

#' Replace Extracted Blocks with Minified Content
#'
#' Replaces block content in the HTML string. Works backwards through the list
#' to preserve character positions of earlier blocks.
#'
#' @param html Character, full HTML string.
#' @param blocks List of block descriptors (from .minify_extract_blocks).
#' @param minified_contents Character vector of minified content, same length
#'   as blocks. NULL entries mean "keep original".
#' @return Character, modified HTML string.
#' @keywords internal
.minify_replace_blocks <- function(html, blocks, minified_contents) {
  # Work backwards to preserve positions
  indices <- rev(seq_along(blocks))

  for (i in indices) {
    block <- blocks[[i]]
    new_content <- minified_contents[[i]]
    if (is.null(new_content)) next

    # Reconstruct the full block with new content
    close_tag <- paste0("</", block$tag_name, ">")
    new_full <- paste0(block$open_tag, new_content, close_tag)

    html <- paste0(
      substr(html, 1L, block$start - 1L),
      new_full,
      substr(html, block$end + 1L, nchar(html))
    )
  }

  html
}


# -- HTML whitespace reduction ------------------------------------------------

#' Reduce HTML Whitespace via html-minifier-terser
#'
#' Applies conservative whitespace collapse to the full HTML string.
#' Falls back to original if the tool fails or result is larger.
#'
#' @param html Character, full HTML string.
#' @param html_minifier_path Character, path to html-minifier-terser binary.
#' @return Named list with html (processed or original) and success (logical).
#' @keywords internal
.minify_html_whitespace <- function(html, html_minifier_path) {
  if (!nzchar(html_minifier_path)) {
    return(list(html = html, success = FALSE))
  }

  tmp_in <- tempfile(fileext = ".html")
  tmp_out <- tempfile(fileext = ".html")
  on.exit(unlink(c(tmp_in, tmp_out), force = TRUE), add = TRUE)

  writeLines(html, tmp_in, useBytes = TRUE)

  args <- c(.MINIFY_HTML_ARGS, "-o", tmp_out, tmp_in)
  result <- tryCatch(
    system2(html_minifier_path, args = args,
            stdout = TRUE, stderr = TRUE,
            timeout = .MINIFY_TOOL_TIMEOUT_SECS),
    error = function(e) e
  )

  if (inherits(result, "error") || !file.exists(tmp_out)) {
    return(list(html = html, success = FALSE))
  }

  minified <- paste(readLines(tmp_out, warn = FALSE), collapse = "\n")
  if (!nzchar(minified)) {
    return(list(html = html, success = FALSE))
  }

  # Safety check: result should be smaller
  if (nchar(minified) >= nchar(html)) {
    return(list(html = html, success = FALSE))
  }

  list(html = minified, success = TRUE)
}


# -- Build tag ----------------------------------------------------------------

#' Inject Build Version Tag
#'
#' Adds a build version comment after the opening <html> tag for future
#' pipeline versioning and debugging.
#'
#' @param html Character, full HTML string.
#' @return Character, modified HTML string.
#' @keywords internal
.minify_inject_build_tag <- function(html) {
  tag <- sprintf("<!-- Turas Build v%s -->", .MINIFY_VERSION)
  sub("(<html[^>]*>)", paste0("\\1", tag), html, perl = TRUE, ignore.case = TRUE)
}


# -- Summary printer ----------------------------------------------------------

#' Print Minification Summary
#'
#' Formats and prints the minification result summary to the console.
#'
#' @param result Named list from turas_minify().
#' @keywords internal
.minify_print_summary <- function(result) {
  input_kb <- format(round(result$input_size_kb), big.mark = ",")
  output_kb <- format(round(result$output_size_kb), big.mark = ",")

  cat("\n")
  cat("Turas Minification Summary\n")
  cat(strrep("\u2500", 50), "\n")
  cat(sprintf("Input:     %s KB  (%s)\n", input_kb, basename(result$input_path)))
  cat(sprintf("Output:    %s KB  (%s)\n", output_kb, basename(result$output_path)))
  cat(sprintf("Reduction: %.1f%%\n", result$reduction_pct))
  cat(strrep("\u2500", 50), "\n")
  cat(sprintf("JS blocks:     %d minified\n", result$js_blocks_processed))
  cat(sprintf("JS blocks:     %d obfuscated\n", result$js_blocks_obfuscated))
  cat(sprintf("CSS blocks:    %d processed\n", result$css_blocks_processed))
  cat(sprintf("Meta tags:     %d stripped\n", result$meta_tags_stripped))
  cat(sprintf("HTML comments: %d removed\n", result$html_comments_removed))
  if (nzchar(result$watermark_client %||% "")) {
    cat(sprintf("Watermark:     %s\n", result$watermark_client))
  }
  cat(sprintf("Warnings:      %d\n", length(result$warnings)))
  cat(strrep("\u2500", 50), "\n")

  if (result$verification_passed) {
    cat("Verification:  ALL CHECKS PASSED\n")
  } else {
    cat("Verification:  SOME CHECKS FAILED\n")
    for (msg in result$verification_summary) {
      if (grepl("^\\[FAIL\\]", msg)) cat("  ", msg, "\n")
    }
  }
  cat("\n")
}


# -- Main function ------------------------------------------------------------
# SIZE-EXCEPTION: Orchestrator coordinates 10 pipeline steps with error
# accumulation. Decomposition would fragment the sequential flow and require
# passing a large mutable state object between functions.

#' Minify a Turas HTML Report
#'
#' Post-processes a finished Turas HTML report to produce a minified and
#' optionally obfuscated deliverable. Reduces file size via CSS/JS minification
#' and HTML whitespace collapse, obfuscates JS via string array encoding, and
#' strips internal metadata for IP protection. Optionally embeds invisible
#' client watermarks for delivery traceability.
#'
#' The pipeline is resilient: failure of any individual step produces a warning
#' and falls back to the original content. A minification failure never
#' prevents report delivery.
#'
#' @param input_path Character. Path to the finished Turas HTML report.
#' @param output_path Character or NULL. Path for the minified output. If NULL,
#'   derives from input_path: removes _dev suffix or appends _min.
#' @param keep_dev_copy Logical. If TRUE (default), the original file is
#'   preserved. If FALSE, the original is overwritten.
#' @param strip_meta Logical. Whether to remove turas-* meta tags.
#' @param minify_js Logical. Whether to minify JavaScript blocks.
#' @param minify_css Logical. Whether to minify CSS blocks.
#' @param minify_html Logical. Whether to reduce HTML whitespace.
#' @param obfuscate_js Logical. Whether to obfuscate JS with string array
#'   encoding after minification. Requires javascript-obfuscator.
#' @param watermark Character or NULL. Client name to embed as an invisible
#'   watermark. NULL or empty string skips watermarking.
#' @param verbose Logical. If TRUE, print progress and size comparison.
#'
#' @return A named list with:
#'   \item{status}{"PASS", "PARTIAL", or "REFUSED"}
#'   \item{input_path}{Path to the original file.}
#'   \item{output_path}{Path to the minified output.}
#'   \item{input_size_kb}{Original file size in KB.}
#'   \item{output_size_kb}{Minified file size in KB.}
#'   \item{reduction_pct}{Percentage size reduction (negative = size increase).}
#'   \item{js_blocks_processed}{Number of JS blocks minified.}
#'   \item{js_blocks_obfuscated}{Number of JS blocks obfuscated.}
#'   \item{css_blocks_processed}{Number of CSS blocks minified.}
#'   \item{meta_tags_stripped}{Number of meta tags removed.}
#'   \item{html_comments_removed}{Number of HTML comments removed.}
#'   \item{watermark_client}{Client name embedded, or empty string.}
#'   \item{verification_passed}{Logical, TRUE if all checks passed.}
#'   \item{verification_summary}{Character vector of check results.}
#'   \item{warnings}{Character vector of warning messages.}
#'
#' @examples
#' \dontrun{
#'   # Basic usage — derives output path from input
#'   result <- turas_minify("reports/Project_dev.html")
#'
#'   # With client watermark
#'   result <- turas_minify("reports/Project_dev.html",
#'                          watermark = "Acme Corp", verbose = TRUE)
#'
#'   # Skip obfuscation (minify only)
#'   result <- turas_minify("reports/Project_dev.html", obfuscate_js = FALSE)
#' }
#'
#' @export
turas_minify <- function(input_path,
                         output_path = NULL,
                         keep_dev_copy = TRUE,
                         strip_meta = TRUE,
                         minify_js = TRUE,
                         minify_css = TRUE,
                         minify_html = TRUE,
                         obfuscate_js = TRUE,
                         watermark = NULL,
                         verbose = FALSE) {

  warnings_acc <- character(0)
  add_warning <- function(msg) {
    warnings_acc <<- c(warnings_acc, msg)
    warning(msg, call. = FALSE)
  }

  # -- Step 0: Validate input -------------------------------------------------
  if (!is.character(input_path) || length(input_path) != 1L || !nzchar(input_path)) {
    turas_refuse(
      code = "IO_INVALID_PATH",
      title = "Invalid Input Path",
      problem = "input_path must be a single non-empty character string",
      why_it_matters = "Cannot locate the HTML report to minify",
      how_to_fix = c("Provide a valid file path as a character string",
                     "Example: turas_minify('reports/Project_dev.html')"),
      module = "MINIFY"
    )
  }

  if (!file.exists(input_path)) {
    turas_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "Input File Not Found",
      problem = sprintf("File does not exist: %s", input_path),
      why_it_matters = "Cannot minify a file that does not exist",
      how_to_fix = c("Check the file path is correct",
                     "Ensure the report has been generated before minifying",
                     sprintf("Looked for: %s", input_path)),
      module = "MINIFY"
    )
  }

  if (is.null(output_path)) {
    output_path <- .minify_derive_output_path(input_path)
  }

  input_size <- file.info(input_path)$size
  if (verbose) cat(sprintf("Minifying: %s (%.0f KB)\n", basename(input_path),
                           input_size / 1024))

  # -- Step 1: Check tools ----------------------------------------------------
  tools <- .minify_check_tools()

  if (!nzchar(tools$node)) {
    add_warning("Node.js not found. Copying file without minification.")
    file.copy(input_path, output_path, overwrite = TRUE)
    output_size <- file.info(output_path)$size
    return(list(
      status = "PARTIAL",
      input_path = input_path, output_path = output_path,
      input_size_kb = input_size / 1024, output_size_kb = output_size / 1024,
      reduction_pct = 0, js_blocks_processed = 0L, js_blocks_obfuscated = 0L,
      css_blocks_processed = 0L,
      meta_tags_stripped = 0L, html_comments_removed = 0L,
      watermark_client = "",
      verification_passed = TRUE, verification_summary = character(0),
      warnings = warnings_acc
    ))
  }

  if (minify_js && !nzchar(tools$terser)) {
    add_warning("terser not found. JS minification skipped. Install: npm install -g terser")
    minify_js <- FALSE
  }

  if (minify_css && !nzchar(tools$cleancss)) {
    add_warning("cleancss not found. CSS minification skipped. Install: npm install -g clean-css-cli")
    minify_css <- FALSE
  }

  if (minify_html && !nzchar(tools$html_minifier)) {
    add_warning("html-minifier-terser not found. HTML whitespace reduction skipped. Install: npm install -g html-minifier-terser")
    minify_html <- FALSE
  }

  if (obfuscate_js && !nzchar(tools$obfuscator)) {
    add_warning("javascript-obfuscator not found. JS obfuscation skipped. Install: npm install -g javascript-obfuscator")
    obfuscate_js <- FALSE
  }

  # -- Step 2: Read file ------------------------------------------------------
  html <- paste(readLines(input_path, warn = FALSE, encoding = "UTF-8"),
                collapse = "\n")
  original_html <- html

  # -- Step 3: Strip meta tags ------------------------------------------------
  meta_result <- list(count = 0L)
  if (strip_meta) {
    meta_result <- .minify_strip_meta_tags(html)
    html <- meta_result$html
    if (verbose && meta_result$count > 0L) {
      cat(sprintf("  Stripped %d turas-* meta tags\n", meta_result$count))
    }
  }

  # -- Step 4: Remove HTML comments -------------------------------------------
  comment_result <- .minify_remove_html_comments(html)
  html <- comment_result$html
  if (verbose && comment_result$count > 0L) {
    cat(sprintf("  Removed %d HTML comments\n", comment_result$count))
  }

  # -- Step 5: Extract and minify CSS blocks ----------------------------------
  css_blocks <- .minify_extract_blocks(html, "style")
  original_css_combined <- paste(vapply(css_blocks, function(b) b$content, character(1)),
                                  collapse = "\n")
  css_minified_contents <- vector("list", length(css_blocks))
  css_processed <- 0L

  if (minify_css && length(css_blocks) > 0L) {
    for (i in seq_along(css_blocks)) {
      if (!nzchar(css_blocks[[i]]$content)) {
        css_minified_contents[[i]] <- NULL
        next
      }
      result <- .minify_css_block(css_blocks[[i]]$content, tools$cleancss)
      if (result$success) {
        css_minified_contents[[i]] <- result$content
        css_processed <- css_processed + 1L
      } else {
        css_minified_contents[[i]] <- NULL
        add_warning(sprintf("CSS block %d failed to minify, kept original", i))
      }
    }

    html <- .minify_replace_blocks(html, css_blocks, css_minified_contents)
    if (verbose) cat(sprintf("  Minified %d/%d CSS blocks\n",
                             css_processed, length(css_blocks)))
  }

  # -- Step 6: Extract and minify JS blocks -----------------------------------
  # Re-extract after CSS replacement (positions changed)
  js_blocks <- .minify_extract_blocks(html, "script")
  original_js_combined <- ""
  js_minified_contents <- vector("list", length(js_blocks))
  js_processed <- 0L

  if (minify_js && length(js_blocks) > 0L) {
    js_original_parts <- character(0)
    for (i in seq_along(js_blocks)) {
      block <- js_blocks[[i]]

      # Skip non-JS blocks
      if (block$type %in% c("application/json", "text/plain")) {
        js_minified_contents[[i]] <- NULL
        next
      }

      if (!nzchar(block$content)) {
        js_minified_contents[[i]] <- NULL
        next
      }

      js_original_parts <- c(js_original_parts, block$content)
      result <- .minify_js_block(block$content, tools$terser)
      if (result$success) {
        js_minified_contents[[i]] <- result$content
        js_processed <- js_processed + 1L
      } else {
        js_minified_contents[[i]] <- NULL
        add_warning(sprintf("JS block %d failed to minify, kept original", i))
      }
    }

    original_js_combined <- paste(js_original_parts, collapse = "\n")
    html <- .minify_replace_blocks(html, js_blocks, js_minified_contents)
    if (verbose) cat(sprintf("  Minified %d/%d JS blocks\n",
                             js_processed, length(js_blocks)))
  } else {
    # Collect original JS for verification even if not minifying
    for (block in js_blocks) {
      if (!block$type %in% c("application/json", "text/plain")) {
        original_js_combined <- paste0(original_js_combined, block$content, "\n")
      }
    }
  }

  # -- Step 6b: JS obfuscation ------------------------------------------------
  js_obfuscated <- 0L
  obfuscation_applied <- FALSE

  if (obfuscate_js && nzchar(tools$obfuscator)) {
    # Re-extract JS blocks (positions shifted after step 6 replacement)
    obf_js_blocks <- .minify_extract_blocks(html, "script")
    obf_contents <- vector("list", length(obf_js_blocks))

    for (i in seq_along(obf_js_blocks)) {
      block <- obf_js_blocks[[i]]

      # Skip non-JS blocks
      if (block$type %in% c("application/json", "text/plain")) {
        obf_contents[[i]] <- NULL
        next
      }
      if (!nzchar(block$content)) {
        obf_contents[[i]] <- NULL
        next
      }

      result <- .minify_obfuscate_js_block(block$content, tools$obfuscator)
      if (result$success) {
        obf_contents[[i]] <- result$content
        js_obfuscated <- js_obfuscated + 1L
      } else {
        obf_contents[[i]] <- NULL
        add_warning(sprintf("JS block %d failed to obfuscate, kept minified version", i))
      }
    }

    if (js_obfuscated > 0L) {
      html <- .minify_replace_blocks(html, obf_js_blocks, obf_contents)
      obfuscation_applied <- TRUE
    }
    if (verbose) cat(sprintf("  Obfuscated %d/%d JS blocks\n",
                             js_obfuscated, length(obf_js_blocks)))
  }

  # -- Step 6c: Watermark injection --------------------------------------------
  watermark_client <- ""
  if (is.character(watermark) && length(watermark) == 1L && nzchar(watermark)) {
    if (exists(".minify_inject_watermark", mode = "function")) {
      wm_result <- .minify_inject_watermark(html, watermark)
      if (wm_result$success) {
        html <- wm_result$html
        watermark_client <- wm_result$client
        if (verbose) {
          cat(sprintf("  Watermark: %s (ID: %s)\n",
                      wm_result$client, substr(wm_result$id, 1L, 8L)))
        }
      } else {
        add_warning("Watermark injection failed")
      }
    } else {
      add_warning("Watermark functions not loaded. Source turas_minify_watermark.R first.")
    }
  }

  # -- Step 7: HTML whitespace reduction --------------------------------------
  html_reduced <- FALSE
  if (minify_html) {
    pre_html_size <- nchar(html)
    ws_result <- .minify_html_whitespace(html, tools$html_minifier)
    if (ws_result$success) {
      html <- ws_result$html
      html_reduced <- TRUE
      if (verbose) {
        saved <- pre_html_size - nchar(html)
        cat(sprintf("  HTML whitespace: saved %.0f KB\n", saved / 1024))
      }
    } else {
      add_warning("HTML whitespace reduction skipped (tool failed or result larger)")
    }
  }

  # -- Step 8: Inject build tag -----------------------------------------------
  html <- .minify_inject_build_tag(html)

  # -- Step 9: Write output ---------------------------------------------------
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  writeLines(html, output_path, useBytes = TRUE)
  output_size <- file.info(output_path)$size

  if (verbose) cat(sprintf("  Written: %s (%.0f KB)\n", basename(output_path),
                           output_size / 1024))

  # -- Step 10: Verification --------------------------------------------------
  minified_css_combined <- ""
  minified_js_combined <- ""

  # Re-extract minified blocks for verification
  minified_css_blocks <- .minify_extract_blocks(html, "style")
  minified_css_combined <- paste(vapply(minified_css_blocks,
                                         function(b) b$content, character(1)),
                                  collapse = "\n")

  minified_js_blocks <- .minify_extract_blocks(html, "script")
  for (block in minified_js_blocks) {
    if (!block$type %in% c("application/json", "text/plain")) {
      minified_js_combined <- paste0(minified_js_combined, block$content, "\n")
    }
  }

  verification <- run_minify_verification(
    original_html = original_html,
    minified_html = html,
    original_css = original_css_combined,
    minified_css = minified_css_combined,
    original_js = original_js_combined,
    minified_js = minified_js_combined,
    input_size_bytes = input_size,
    output_size_bytes = output_size,
    obfuscated = obfuscation_applied,
    watermark_client = if (nzchar(watermark_client)) watermark_client else NULL
  )

  if (!verification$all_passed) {
    failed_checks <- verification$summary[grepl("^\\[FAIL\\]", verification$summary)]
    for (msg in failed_checks) {
      add_warning(paste("Verification:", msg))
    }
  }

  # -- Step 11: Build result --------------------------------------------------
  reduction_pct <- if (input_size > 0) {
    (1 - output_size / input_size) * 100
  } else {
    0
  }

  status <- if (length(warnings_acc) == 0L) "PASS" else "PARTIAL"

  result <- list(
    status = status,
    input_path = input_path,
    output_path = output_path,
    input_size_kb = input_size / 1024,
    output_size_kb = output_size / 1024,
    reduction_pct = reduction_pct,
    js_blocks_processed = js_processed,
    js_blocks_obfuscated = js_obfuscated,
    css_blocks_processed = css_processed,
    meta_tags_stripped = meta_result$count,
    html_comments_removed = comment_result$count,
    watermark_client = watermark_client,
    verification_passed = verification$all_passed,
    verification_summary = verification$summary,
    warnings = warnings_acc
  )

  if (verbose) .minify_print_summary(result)

  result
}


#' Prepare Client Deliverable from HTML Report
#'
#' Convenience wrapper for Shiny GUI integration. Checks the
#' TURAS_PREPARE_DELIVERABLE global flag, renames the original to _dev,
#' minifies to the clean name, and falls back safely on failure.
#'
#' Call this after a successful HTML report write. Does nothing if the
#' flag is not set or turas_minify is not available.
#'
#' @param html_path Character. Path to the HTML report just written.
#' @return Invisible NULL (side effects: renames file, creates minified copy,
#'   prints progress to console).
#'
#' @examples
#' \dontrun{
#'   # In a module run script, after HTML write succeeds:
#'   turas_prepare_deliverable(html_output_path)
#' }
#'
#' @export
turas_prepare_deliverable <- function(html_path) {
  if (!isTRUE(get0("TURAS_PREPARE_DELIVERABLE", envir = .GlobalEnv))) {
    return(invisible(NULL))
  }

  if (!is.character(html_path) || length(html_path) != 1L || !nzchar(html_path)) {
    return(invisible(NULL))
  }

  if (!file.exists(html_path)) {
    return(invisible(NULL))
  }

  cat("\n  Preparing client deliverable...\n")
  dev_path <- sub("\\.html$", "_dev.html", html_path)

  if (!file.rename(html_path, dev_path)) {
    cat("  [WARNING] Could not rename file for minification. Report preserved.\n")
    return(invisible(NULL))
  }

  # Pick up client name from global env (set by GUI)
  client_name <- get0("TURAS_CLIENT_NAME", envir = .GlobalEnv)
  if (!is.character(client_name) || length(client_name) != 1L || !nzchar(client_name)) {
    client_name <- NULL
  }

  minify_result <- turas_minify(dev_path, verbose = TRUE, watermark = client_name)

  if (minify_result$status %in% c("PASS", "PARTIAL")) {
    cat(sprintf("  Client deliverable: %s (%.1f%% smaller)\n",
        basename(minify_result$output_path), minify_result$reduction_pct))
    cat(sprintf("  Dev copy kept: %s\n", basename(dev_path)))
  } else {
    file.rename(dev_path, html_path)
    cat("  [WARNING] Minification failed. Original report preserved.\n")
  }

  invisible(NULL)
}

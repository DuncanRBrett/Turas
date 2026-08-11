# ==============================================================================
# TURAS > PROJECT STEPS - COMMAND BUILD, ENVIRONMENT GUARD, EXECUTION
# ==============================================================================
# Purpose: Turn a validated manifest plus a set of form values into a command,
#          check the runtime can actually run it, execute it with live output,
#          and map the exit code to a TRS status.
# Location: modules/steps/lib/run_tool.R
#
# Nothing here is Shiny-aware: the GUI drives start / poll / finish, and tests
# drive the same three calls through the blocking wrapper steps_run_tool().
# ==============================================================================


# ------------------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------------------

#' Resolve the Turas root directory (Docker-aware, same rule as launch_turas.R)
#'
#' @return Character. Absolute path to the Turas root.
#' @export
steps_turas_root <- function() {
  root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(root) || !dir.exists(root)) root <- getwd()
  normalizePath(root, winslash = "/", mustWork = FALSE)
}


# ------------------------------------------------------------------------------
# Console output (Shiny rule: every refusal is visible in the console)
# ------------------------------------------------------------------------------

#' Print a TRS refusal in the boxed console format
#'
#' @param refusal A refusal list from steps_refuse().
#' @param context Character. Optional label for where the refusal came from.
#' @return The refusal, invisibly.
#' @export
steps_print_refusal <- function(refusal, context = "Project Steps") {
  if (is.null(refusal) || !identical(refusal$status, "REFUSED")) return(invisible(refusal))

  bar <- strrep("=", 78)
  cat("\n", bar, "\n", sep = "")
  cat("  [REFUSE] ", refusal$code, "\n", sep = "")
  cat(bar, "\n\n", sep = "")
  cat("Context:\n  ", context, "\n\n", sep = "")
  cat("Problem:\n  ", refusal$message, "\n\n", sep = "")
  cat("How to fix:\n")
  for (fix in refusal$how_to_fix) cat("  - ", fix, "\n", sep = "")
  if (length(refusal$context) > 0) {
    cat("\nDetails:\n")
    for (nm in names(refusal$context)) {
      cat("  ", nm, ": ", paste(as.character(refusal$context[[nm]]), collapse = ", "), "\n", sep = "")
    }
  }
  cat(bar, "\n\n", sep = "")
  invisible(refusal)
}


# ------------------------------------------------------------------------------
# Command construction
# ------------------------------------------------------------------------------

#' Normalise one form value to a single character string
#' @keywords internal
.steps_value_string <- function(value) {
  if (is.null(value) || length(value) == 0) return("")
  if (length(value) > 1) value <- value[1]
  if (is.na(value)) return("")
  trimws(as.character(value))
}


#' Make a path absolute, expanding "~"
#'
#' R expands "~" in file.exists(); the tool we hand the path to does not, so a
#' path that passed the existence check would fail inside python. Relative paths
#' are resolved here for the same reason: the child process runs with the Turas
#' root as its working directory, which need not be the caller's.
#'
#' @param p Character. A path as typed or picked.
#' @return Character. An absolute path (not required to exist).
#' @keywords internal
.steps_abs_path <- function(p) {
  p <- path.expand(p)
  if (!grepl("^(/|[A-Za-z]:)", p)) p <- file.path(getwd(), p)
  normalizePath(p, winslash = "/", mustWork = FALSE)
}


#' Is this form value "on" for a flag argument?
#' @keywords internal
.steps_value_flag <- function(value) {
  if (is.null(value) || length(value) == 0) return(FALSE)
  v <- value[1]
  if (is.logical(v)) return(isTRUE(v))
  if (is.na(v)) return(FALSE)
  tolower(trimws(as.character(v))) %in% c("true", "yes", "y", "1")
}


#' Build the command line for a tool
#'
#' Arguments are emitted in manifest order. Values are passed to the process
#' directly (no shell), so no quoting is applied to the argument vector; the
#' `display` string is shell-quoted for the console echo only.
#'
#' @param manifest A validated manifest.
#' @param values Named list of form values, keyed by argument id.
#' @param turas_root Character. Turas root, used to resolve `entry`.
#' @return list(status = "PASS", runtime, args, display) or a TRS refusal.
#' @export
steps_build_command <- function(manifest, values = list(), turas_root = steps_turas_root()) {

  check <- steps_validate_manifest(manifest)
  if (check$status == "REFUSED") return(check)

  entry_path <- file.path(turas_root, manifest$entry)
  if (!file.exists(entry_path)) {
    return(steps_refuse(
      "IO_STEP_ENTRY_NOT_FOUND",
      sprintf("The script for '%s' is not at %s.", manifest$name, entry_path),
      c(sprintf("Check that '%s' exists under the Turas root.", manifest$entry),
        "If the tool moved, update its manifest entry in modules/steps/lib/registry.R."),
      context = list(tool = manifest$id, entry = manifest$entry, turas_root = turas_root)
    ))
  }

  args <- manifest$args
  if (is.null(args)) args <- list()

  cli_args <- character(0)
  set_by_group <- list()

  for (arg in args) {
    required   <- isTRUE(arg$required)
    must_exist <- if (is.null(arg$must_exist)) TRUE else isTRUE(arg$must_exist)
    value      <- values[[arg$id]]

    if (identical(arg$type, "flag")) {
      if (.steps_value_flag(value)) cli_args <- c(cli_args, arg$cli)
      next
    }

    val <- .steps_value_string(value)

    # Paths are absolutised so the tool receives what the guard checked. A
    # leading "~/" is expanded whatever the type: no tool understands it, and no
    # pattern or free-text value legitimately starts that way.
    if (nzchar(val)) {
      if (arg$type %in% c("file", "dir")) {
        val <- .steps_abs_path(val)
      } else if (startsWith(val, "~/")) {
        val <- path.expand(val)
      }
    }

    if (identical(arg$type, "flag_value")) {
      # The switch itself selects the tool's mode, so it is always emitted.
      cli_args <- c(cli_args, arg$cli)
      if (nzchar(val)) cli_args <- c(cli_args, val)
      next
    }

    if (!nzchar(val)) {
      if (required) {
        return(steps_refuse(
          "CFG_STEP_ARG_MISSING",
          sprintf("'%s' is required by '%s' but was left blank.", arg$label, manifest$name),
          sprintf("Fill in '%s' and run the step again.", arg$label),
          context = list(tool = manifest$id, arg = arg$id)
        ))
      }
      next
    }

    if (identical(arg$type, "choice") && !val %in% arg$choices) {
      return(steps_refuse(
        "CFG_STEP_ARG_INVALID",
        sprintf("'%s' is set to '%s', which is not one of its choices.", arg$label, val),
        sprintf("Choose one of: %s", paste(arg$choices, collapse = ", ")),
        context = list(tool = manifest$id, arg = arg$id)
      ))
    }

    if (identical(arg$type, "file") && must_exist && !file.exists(val)) {
      return(steps_refuse(
        "IO_STEP_ARG_NOT_FOUND",
        sprintf("'%s' points at a file that does not exist: %s", arg$label, val),
        c("Check the path (a moved or renamed file is the usual cause).",
          "Use the Browse button so the path comes from the file picker."),
        context = list(tool = manifest$id, arg = arg$id, path = val)
      ))
    }

    if (identical(arg$type, "dir") && must_exist && !dir.exists(val)) {
      return(steps_refuse(
        "IO_STEP_ARG_NOT_FOUND",
        sprintf("'%s' points at a folder that does not exist: %s", arg$label, val),
        c("Check the path (a moved or renamed folder is the usual cause).",
          "Use the Browse button so the path comes from the folder picker."),
        context = list(tool = manifest$id, arg = arg$id, path = val)
      ))
    }

    if (!is.null(arg$exclusive)) {
      grp <- arg$exclusive
      if (!is.null(set_by_group[[grp]])) {
        return(steps_refuse(
          "CFG_STEP_ARGS_CONFLICT",
          sprintf("'%s' and '%s' cannot both be set.", set_by_group[[grp]], arg$label),
          sprintf("Clear one of them - '%s' accepts only one of these.", manifest$name),
          context = list(tool = manifest$id, group = grp)
        ))
      }
      set_by_group[[grp]] <- arg$label
    }

    cli_args <- c(cli_args, arg$cli, val)
  }

  full_args <- c(entry_path, cli_args)

  list(
    status  = "PASS",
    runtime = manifest$runtime,
    args    = full_args,
    display = paste(c(manifest$runtime, shQuote(full_args)), collapse = " ")
  )
}


# ------------------------------------------------------------------------------
# Environment guard
# ------------------------------------------------------------------------------

#' Build the runtime's "can you import this module?" command
#'
#' @param runtime Character. The runtime binary name.
#' @param module Character. The module to import.
#' @return Character vector of arguments, or NULL when the runtime has no known
#'   import check (in which case the module check is skipped).
#' @keywords internal
.steps_import_probe <- function(runtime, module) {
  base <- basename(runtime)
  if (grepl("^python", base)) return(c("-c", sprintf("import %s", module)))
  if (grepl("^Rscript", base)) return(c("-e", sprintf("library(%s)", module)))
  NULL
}


#' Check that a tool's runtime and its modules are available
#'
#' @param manifest A validated manifest.
#' @param which_fn Function used to locate the runtime binary. Injectable for
#'   tests; defaults to Sys.which.
#' @param probe_fn Function(runtime, args) returning an exit status. Injectable
#'   for tests; defaults to a silent system2 call.
#' @return list(status = "PASS", runtime_path = ...) or a TRS refusal.
#' @export
steps_check_env <- function(manifest,
                            which_fn = Sys.which,
                            probe_fn = NULL) {

  if (is.null(probe_fn)) {
    probe_fn <- function(runtime, args) {
      # system2() pastes arguments into one shell command without quoting, so an
      # argument containing a space ("import openpyxl") must be quoted here or
      # the runtime sees it as two arguments.
      suppressWarnings(
        system2(runtime, shQuote(args), stdout = FALSE, stderr = FALSE)
      )
    }
  }

  runtime <- manifest$runtime
  bin <- tryCatch(as.character(which_fn(runtime))[1], error = function(e) "")
  if (is.na(bin)) bin <- ""

  if (!nzchar(bin)) {
    return(steps_refuse(
      "PKG_RUNTIME_MISSING",
      sprintf("'%s' needs %s, which is not on this machine's PATH.", manifest$name, runtime),
      c(sprintf("Install %s, or add it to PATH, then relaunch Turas.", runtime),
        "On macOS, python3 ships with the Xcode command line tools: xcode-select --install",
        "In Docker, add the runtime to the image (see Docker/README notes)."),
      context = list(tool = manifest$id, runtime = runtime)
    ))
  }

  modules <- manifest$requires
  if (is.null(modules)) modules <- character(0)

  missing <- character(0)
  for (m in modules) {
    probe <- .steps_import_probe(runtime, m)
    if (is.null(probe)) next   # unknown runtime: nothing reliable to check
    status <- tryCatch(probe_fn(runtime, probe), error = function(e) 1L)
    if (!identical(as.integer(status), 0L)) missing <- c(missing, m)
  }

  if (length(missing) > 0) {
    return(steps_refuse(
      "PKG_RUNTIME_MISSING",
      sprintf("%s cannot import: %s.", runtime, paste(missing, collapse = ", ")),
      c("Install the missing packages: python3 -m pip install -r scripts/requirements.txt",
        sprintf("Then check it worked: %s -c \"import %s\"", runtime, missing[1])),
      context = list(tool = manifest$id, runtime = runtime, missing = missing)
    ))
  }

  list(status = "PASS", runtime_path = bin)
}


# ------------------------------------------------------------------------------
# Execution
# ------------------------------------------------------------------------------

#' Start a tool, returning a live process handle
#'
#' stdout and stderr are merged into one stream so the console shows them in the
#' order the tool produced them. Output is read incrementally by steps_drain().
#'
#' @param manifest A validated manifest.
#' @param values Named list of form values.
#' @param turas_root Character. Turas root.
#' @param check_env Logical. Run the environment guard first (default TRUE).
#' @return list(status = "PASS", process, command, display) or a TRS refusal.
#' @export
steps_start_tool <- function(manifest, values = list(),
                             turas_root = steps_turas_root(),
                             check_env = TRUE) {

  if (!requireNamespace("processx", quietly = TRUE)) {
    return(steps_refuse(
      "PKG_MISSING_DEPENDENCY",
      "The processx package is not installed, so Project Steps cannot run a tool.",
      c("Install it: renv::restore()  (processx is already in renv.lock)",
        "Or, outside renv: install.packages('processx')"),
      context = list(tool = manifest$id)
    ))
  }

  cmd <- steps_build_command(manifest, values, turas_root = turas_root)
  if (cmd$status == "REFUSED") return(cmd)

  if (isTRUE(check_env)) {
    env <- steps_check_env(manifest)
    if (env$status == "REFUSED") return(env)
  }

  proc <- tryCatch(
    processx::process$new(cmd$runtime, cmd$args,
                          stdout = "|", stderr = "2>&1",
                          wd = turas_root),
    error = function(e) e
  )

  if (inherits(proc, "error")) {
    return(steps_refuse(
      "IO_STEP_LAUNCH_FAILED",
      sprintf("Could not start '%s': %s", manifest$name, conditionMessage(proc)),
      c("Check that the runtime is executable and the script path is readable.",
        sprintf("Try the same command in a terminal: %s", cmd$display)),
      context = list(tool = manifest$id, command = cmd$display)
    ))
  }

  list(status = "PASS", process = proc, command = cmd$args, display = cmd$display)
}


#' Read whatever output a running tool has produced since the last call
#'
#' @param proc A processx process handle from steps_start_tool().
#' @param timeout_ms Integer. How long to wait for output before returning.
#' @return Character vector of new lines (possibly empty).
#' @export
steps_drain <- function(proc, timeout_ms = 200L) {
  tryCatch({
    proc$poll_io(timeout_ms)
    lines <- proc$read_output_lines()
    if (is.null(lines)) character(0) else lines
  }, error = function(e) character(0))
}


#' Map a finished process to a TRS status
#'
#' @param manifest The manifest that was run.
#' @param proc The finished processx handle.
#' @param output Character vector of everything the tool printed.
#' @param display Character. The command as echoed to the console.
#' @return list(status = "PASS", exit_status, output) on success, or a TRS
#'   refusal carrying the tail of the tool's output.
#' @export
steps_finish_tool <- function(manifest, proc, output = character(0), display = "") {

  exit_status <- tryCatch({
    proc$wait(timeout = 2000)
    proc$get_exit_status()
  }, error = function(e) NA_integer_)

  if (is.null(exit_status) || length(exit_status) != 1 || is.na(exit_status)) {
    return(steps_refuse(
      "IO_STEP_FAILED",
      sprintf("'%s' ended without reporting an exit status.", manifest$name),
      c("Re-run the step and watch the output for where it stopped.",
        sprintf("If it keeps happening, run it in a terminal: %s", display)),
      context = list(tool = manifest$id, command = display)
    ))
  }

  if (identical(as.integer(exit_status), 0L)) {
    return(list(
      status      = "PASS",
      exit_status = 0L,
      output      = output,
      message     = sprintf("%s finished successfully.", manifest$name)
    ))
  }

  tail_lines <- utils::tail(output[nzchar(trimws(output))], 8L)

  refusal <- steps_refuse(
    "IO_STEP_FAILED",
    sprintf("'%s' exited with status %d.", manifest$name, as.integer(exit_status)),
    c("Read the tool's output above - it names what it could not do.",
      sprintf("To reproduce outside Turas: %s", display)),
    context = list(
      tool        = manifest$id,
      exit_status = as.integer(exit_status),
      last_output = if (length(tail_lines) > 0) paste(tail_lines, collapse = " | ") else "(no output)"
    )
  )
  refusal$exit_status <- as.integer(exit_status)
  refusal$output <- output
  refusal
}


#' Run a tool to completion (blocking)
#'
#' Used by tests and by any non-Shiny caller. The GUI uses start/drain/finish
#' directly so the UI can flush output while the tool is still running.
#'
#' @param manifest A validated manifest.
#' @param values Named list of form values.
#' @param on_output Function(lines) called with each chunk of new output.
#'   Defaults to writing the lines to the console.
#' @param turas_root Character. Turas root.
#' @param check_env Logical. Run the environment guard first.
#' @param timeout_s Numeric. Give up after this many seconds (NULL = no limit).
#' @return list(status = "PASS", ...) or a TRS refusal. Never throws.
#' @export
steps_run_tool <- function(manifest, values = list(),
                           on_output = function(lines) cat(lines, sep = "\n"),
                           turas_root = steps_turas_root(),
                           check_env = TRUE,
                           timeout_s = NULL) {

  started <- steps_start_tool(manifest, values, turas_root = turas_root,
                              check_env = check_env)
  if (started$status == "REFUSED") return(started)

  proc <- started$process
  output <- character(0)
  begun <- Sys.time()

  repeat {
    lines <- steps_drain(proc, timeout_ms = 200L)
    if (length(lines) > 0) {
      output <- c(output, lines)
      if (is.function(on_output)) on_output(lines)
    }
    if (!proc$is_alive()) {
      # One last read: output written just before exit is still buffered.
      lines <- steps_drain(proc, timeout_ms = 0L)
      if (length(lines) > 0) {
        output <- c(output, lines)
        if (is.function(on_output)) on_output(lines)
      }
      break
    }
    if (!is.null(timeout_s) &&
        as.numeric(difftime(Sys.time(), begun, units = "secs")) > timeout_s) {
      tryCatch(proc$kill(), error = function(e) NULL)
      return(steps_refuse(
        "IO_STEP_FAILED",
        sprintf("'%s' was still running after %s seconds and was stopped.",
                manifest$name, timeout_s),
        c("Re-run with a smaller input, or run the command in a terminal to watch it.",
          sprintf("Command: %s", started$display)),
        context = list(tool = manifest$id, command = started$display)
      ))
    }
  }

  steps_finish_tool(manifest, proc, output = output, display = started$display)
}

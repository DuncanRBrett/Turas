# Tracker Console Output Issue - Handover to Sonnet

## Problem Statement
The tracker module GUI suppresses all console output while the tabs module displays it properly in the Shiny window. Users cannot see compilation errors, warnings, or progress messages.

## Current Status
- **Module state**: Working (runs successfully, completes analysis)
- **Console output**: Suppressed (nothing displays in GUI window)
- **User impact**: Cannot see config errors or debug information
- **Not committed**: All changes on branch `claude/fix-tracker-console-output-01A7Msp2jumwXoYhiXEemVsu`

## Root Cause Analysis

### Why Tabs Works, Tracker Doesn't
- **Tabs module** (`run_tabs.R`): Uses primarily `cat()` for output → goes to **stdout**
- **Tracker module** (`run_tracker.R`): Uses 40+ `message()` calls → goes to **stderr**

### Output Capture Mechanisms Attempted (All Failed)

| Approach | What Happened | Why It Failed |
|----------|---------------|---------------|
| `sink(file, type="output")` only | Output suppressed | Only captures stdout, not stderr (message streams) |
| `sink(file, type="message")` with connection object | Module broke silently | sink() needs file path string, not connection object |
| `capture.output(type="message")` | Output disappeared | Breaks in Shiny reactive context |
| `withCallingHandlers()` + message handler | Output disappeared, Shiny errors | Reactive context conflicts with message interception |
| Dual sink (output + message to same file) | App froze, greyed out screen | Lock/deadlock in Shiny reactive context |

### The Fundamental Issue
**Shiny's reactive context is fundamentally incompatible with R's output stream redirection (sink/capture.output) when trying to capture stderr (message streams).**

- stdout capture works fine (tabs proves this)
- stderr capture causes reactive context breakdown
- No amount of careful error handling fixes this

## What's in the Code Now

**File**: `/Users/duncan/Documents/Turas/modules/tracker/run_tracker_gui.R` (lines 594-607)

Current approach:
```r
# Run analysis
analysis_result <- tryCatch({
  output_file <- run_tracker(...)
  list(success = TRUE, output_file = output_file, error = NULL)
}, error = function(e) {
  list(success = FALSE, output_file = NULL, error = e)
})
```

This runs the tracker successfully but captures nothing.

## Known Working Patterns

### Tabs Module Pattern (Lines 366-379 of run_tabs_gui.R)
```r
output_file <- tempfile()
sink(output_file, type = "output")  # ONLY captures stdout
analysis_result <- tryCatch({
  source("run_crosstabs.R", local = FALSE)
}, error = ..., finally = {
  sink(type = "output")
})
captured_output <- readLines(output_file, warn = FALSE)
```

**Why it works**: tabs only uses `cat()` output, not `message()`

## Solution Approaches to Explore

### Option A: Modify run_tracker.R (Invasive but Likely to Work)
At the start of `run_tracker()` function, add:
```r
# Redirect stderr to stdout so all output goes to one stream
sink(stdout(), type = "message")
```

This would make all `message()` calls output to stdout, then a single `sink(type="output")` in the GUI would capture everything.

**Pros**: Simple, proven approach works
**Cons**: Modifies tracker module, changes how it outputs messages

### Option B: Custom Shiny Output Handler (May Work)
Instead of capturing at R level, use Shiny's built-in message handling:
- Create a custom handler for Shiny messages
- Intercept messages before Shiny processes them
- Append to console_output reactiveVal

**Pros**: Native Shiny approach
**Cons**: Complex, unclear if Shiny allows this level of interception

### Option C: Background Process with File Monitoring (Workaround)
Run tracker in background, write output to file, watch file for changes and display

**Pros**: Avoids reactive context issues entirely
**Cons**: Clunky, introduces file I/O complexity

### Option D: Modify run_tracker.R to Accept Output Function (Best Architecture)
Change `run_tracker()` signature to accept optional output function:
```r
run_tracker(..., output_handler = NULL)
```

Inside `run_tracker()`, instead of `message(msg)`, do:
```r
if (!is.null(output_handler)) {
  output_handler(msg)
} else {
  message(msg)
}
```

Then in GUI, pass `output_handler = function(msg) console_output(paste0(...))`

**Pros**: Clean, architectural solution, fully under control
**Cons**: Requires changes to run_tracker.R, but minimal and elegant

## Recent Commits (Attempted Solutions)
All on branch: `claude/fix-tracker-console-output-01A7Msp2jumwXoYhiXEemVsu`

- `4abb3d8`: Revert to working state (no output capture)
- `43bc366`: Dual sink attempt (froze app)
- `2341601`: capture.output attempt (suppressed output)
- `870d188`: withCallingHandlers attempt (disappeared)
- Earlier: Various sink attempts

All reverted/abandoned.

## Recommendation for Sonnet

**Try Option A first** (modify run_tracker.R):
1. At start of `run_tracker()` function, add: `sink(stdout(), type = "message")`
2. Use simple single-stream sink in GUI (proven to work)
3. Minimal, focused change with high confidence of success

**If Option A fails**, try **Option D** (output_handler function parameter):
- More elegant architectural solution
- Full control over message formatting
- Allows for future extensibility

## Files Involved
- `/Users/duncan/Documents/Turas/modules/tracker/run_tracker_gui.R` - GUI code
- `/Users/duncan/Documents/Turas/modules/tracker/run_tracker.R` - Tracker module
- `/Users/duncan/Documents/Turas/modules/tabs/run_tabs_gui.R` - Reference (working)

## Testing
Once implemented, test with:
- Run tracker analysis
- Verify all progress messages appear in GUI console
- Verify errors display properly
- Verify completion message shows

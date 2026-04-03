# Turas Report Minification Pipeline — Specification

**Version:** 1.0
**Date:** 3 April 2026
**Author:** Duncan Brett / TRL
**For:** Claude Code implementation

---

## 1. Purpose

Turas generates standalone HTML reports containing cross-tabulations, dashboards, heatmaps, and interactive charts. These reports are self-contained single files delivered to clients. Currently, the HTML, CSS, and JavaScript in these files are fully unminified — readable, well-commented, and completely exposed.

This spec defines a post-processing pipeline that takes any finished Turas HTML report and produces a minified deliverable version. The goal is twofold: reduce file size for faster loading, and reduce casual readability of the codebase for IP protection.

The pipeline operates on the **final HTML output** of any Turas module. It does not modify the R code that generates the reports. It is the last step before delivery.

---

## 2. Context

### What Turas reports look like

A typical Turas report is a single `.html` file, 1–3 MB, containing 10,000–15,000 lines. The file contains:

- **CSS** — approximately 2,000–2,500 lines of unminified CSS in one or more `<style>` blocks in the `<head>`. Uses a design system with `--ct-` prefixed CSS custom properties. Includes comments, legacy alias blocks, and readable class names.
- **HTML body** — structured content including dashboard gauge cards, heatmap tables, cross-tabulation tables, SVG charts, callout panels, and navigation. Data values are embedded directly in HTML attributes (`data-value-num`, `data-tier`, `data-col-key`, `data-sort-val`, `data-q-code`, `data-original-idx`) and in table cell content (`<span class="ct-val">57%</span>`, `<span class="ct-base-n">1,000</span>`).
- **JavaScript** — approximately 150 functions across multiple `<script>` blocks, all unminified. Functions handle: table sorting, column toggling, chart rendering, SVG slide export, Excel/CSV export, pin-to-slide functionality, gauge card interactions, heatmap colouring, print layout, and tab navigation.
- **Meta tags** — `<meta>` tags in `<head>` with `name` attributes prefixed `turas-` containing report metadata: `turas-source-filename`, `turas-report-type`, `turas-total-n`, `turas-questions`, `turas-banner-groups`, `turas-weighted`, `turas-fieldwork`.

### What the pipeline must NOT touch

- **Data values** in HTML table cells, gauge cards, heatmap cells, and chart elements. These are the client's research data and must be preserved exactly.
- **HTML structure and class names** used by CSS and JavaScript. The minified report must render and behave identically to the original.
- **`data-*` attributes** on HTML elements. These are consumed by JavaScript for interactivity. They must remain intact and unmodified.
- **Inline SVG content** within the report body.
- **Any content within `<div>` elements with `contenteditable` attributes** — these are user-editable commentary fields.

### Workflow

```
R pipeline generates report
        │
        ▼
  report_dev.html  ← kept in project folder for debugging
        │
        ▼
  turas_minify()   ← this pipeline
        │
        ▼
  report.html      ← delivered to client
```

Both files are saved. The dev copy is never sent to clients. The minified copy is the deliverable.

---

## 3. Requirements

### 3.1 JavaScript Minification

**What to do:**
- Extract all content between `<script>` and `</script>` tags (there may be multiple script blocks).
- Skip any `<script>` tags that have a `type` attribute other than `text/javascript` or no type. This includes `type="application/json"` (state data blocks like `<script type="application/json" id="sig-card-states">`) and `type="text/plain"` (hub reports embed entire base64-encoded sub-reports in `<script type="text/plain" data-encoding="base64">` blocks). All non-JavaScript script blocks must be left completely untouched.
- Minify each JavaScript block: remove whitespace, remove comments, shorten local variable and function names where safe.
- Replace the original script content with the minified version.

**Tool:** Use `terser` (Node.js) via system call. It is the industry standard for JavaScript minification and handles all ES6+ features safely.

**Terser options to use:**
```
--compress passes=2,dead_code=true,drop_console=false
--mangle toplevel=false
--mangle-props=false
--output beautify=false
--comments '/^!/'
```

Key decisions:
- `toplevel=false` — do NOT mangle top-level function names. Many functions are called from `onclick` attributes in the HTML (e.g., `onclick="toggleGaugeExclude(this)"`). Mangling top-level names would break these references. Only local variables inside functions should be shortened.
- `mangle-props=false` — do NOT rename object properties. Hub reports use namespace objects (`window.TurasPins`, `window.ReportHub`) whose methods are referenced in dynamically constructed onclick strings in JavaScript (e.g., `'onclick="TurasPins.move(\'' + pid + '\',-1)"'`). Property mangling would silently break these at runtime. This is critical.
- `drop_console=false` — preserve any console statements (there shouldn't be any in production, but don't silently remove them if they exist).
- `dead_code=true` — remove unreachable code.
- `comments '/^!/'` — preserve comments starting with `!` (copyright notices). The pipeline should inject a `/*! Turas © TRL [year]. All rights reserved. */` comment at the top of each minified JS block.

**Verification:** After minification, the total number of top-level function definitions (`function functionName`) must equal the number in the original. Write a check for this.

### 3.2 CSS Minification

**What to do:**
- Extract all content between `<style>` and `</style>` tags.
- Minify: remove comments, remove whitespace, collapse shorthand properties where safe.

**Tool:** Use `clean-css` (Node.js) via system call, or `csso`. Both are reliable.

**Options:**
```
--level 1
```

Level 1 is safe minification (whitespace and comment removal). Level 2 does structural optimisation which can occasionally break specificity — avoid it.

**Verification:** The number of CSS custom property declarations (any `--` prefixed property) in the output must equal the number in the input. Note: Turas reports use multiple custom property namespaces (`--t-`, `--ct-`, `--hub-`, and others) — the check must count all of them, not just one prefix.

### 3.3 HTML Whitespace Reduction

**What to do:**
- Remove unnecessary whitespace between HTML tags (not within text content or `<pre>` blocks).
- Collapse multiple spaces/newlines between tags to a single space or no space.
- Do NOT remove whitespace inside `<td>`, `<th>`, `<span>`, `<div>`, or any element that contains visible text content. Only strip whitespace that exists purely for source formatting between closing and opening tags.

**Tool:** Custom R logic using regex, or `html-minifier-terser` (Node.js) with conservative settings.

**If using html-minifier-terser:**
```
--collapse-whitespace
--conservative-collapse
--preserve-line-breaks=false
--remove-comments
--min-css=false          (we handle CSS separately)
--min-js=false           (we handle JS separately)
```

**Critical:** `--conservative-collapse` ensures whitespace is collapsed to a single space rather than removed entirely, which prevents inline elements from merging visually.

**Verification:** The rendered text content of the minified file must match the original exactly. Check by extracting all `textContent` from both files and comparing.

### 3.4 Meta Tag Stripping

**What to do:**
- Remove all `<meta>` tags where the `name` attribute starts with `turas-`.
- Preserve all other `<meta>` tags (`charset`, `viewport`, etc.).

**Implementation:** Simple regex or DOM manipulation in R.

**Pattern:** `<meta\s+name="turas-[^"]*"\s+content="[^"]*"\s*/?>` — remove the entire tag.

### 3.5 Comment Removal

**What to do:**
- Remove HTML comments (`<!-- ... -->`).
- CSS and JS comments are handled by their respective minifiers.

**Exception:** Do NOT remove conditional comments if any exist (e.g., `<!--[if IE]>`). These are unlikely in Turas reports but the code should check.

**Exception:** Do NOT remove comments inside `<script type="application/json">` blocks.

---

## 4. Implementation

### 4.1 Language and Location

The pipeline is an **R function** that lives in the Turas shared utilities. It is called at the end of any module's report generation process.

**File location:** Place in the Turas shared R utilities directory, wherever common functions used by all modules live. The implementing developer should examine the Turas project structure to determine the correct location.

**Function signature:**
```r
turas_minify <- function(
  input_path,
  output_path = NULL,
  keep_dev_copy = TRUE,
  strip_meta = TRUE,
  minify_js = TRUE,
  minify_css = TRUE,
  minify_html = TRUE,
  verbose = FALSE
)
```

**Parameters:**
- `input_path` — path to the finished Turas HTML report.
- `output_path` — path for the minified output. If `NULL`, derives from `input_path` by removing `_dev` suffix or appending `_min` — decide convention during implementation.
- `keep_dev_copy` — if `TRUE` (default), the original file is preserved as-is. If `FALSE`, the original is overwritten (not recommended for production use).
- `strip_meta` — whether to remove `turas-*` meta tags.
- `minify_js` — whether to minify JavaScript blocks.
- `minify_css` — whether to minify CSS blocks.
- `minify_html` — whether to reduce HTML whitespace.
- `verbose` — if `TRUE`, print progress and size comparison.

**Return value:** A named list:
```r
list(
  input_path = "path/to/original.html",
  output_path = "path/to/minified.html",
  input_size_kb = 2481,
  output_size_kb = 1650,
  reduction_pct = 33.5,
  js_blocks_processed = 3,
  css_blocks_processed = 1,
  meta_tags_stripped = 7,
  warnings = character(0)
)
```

### 4.2 Dependencies

**Node.js packages required:**
- `terser` — for JavaScript minification
- `clean-css-cli` or `csso-cli` — for CSS minification
- `html-minifier-terser` — for HTML whitespace reduction (optional — can be done in R with regex if preferred to avoid this dependency)

These should be installed globally or in a project-local node_modules. The R function should check for their availability and produce a clear error message if they are missing, including the install command.

**R packages required:**
- Only base R and standard string manipulation. No additional R package dependencies.

### 4.3 Processing Order

1. Read the entire HTML file as a single string.
2. Strip `turas-*` meta tags.
3. Remove HTML comments (except conditional comments).
4. Extract and minify each CSS `<style>` block (replace in-place in the string).
5. Extract and minify each JavaScript `<script>` block, skipping `type="application/json"` blocks (replace in-place in the string).
6. Apply HTML whitespace reduction to the full string.
7. Write the result to `output_path`.
8. Run verification checks (see section 5).
9. Return the summary list.

The order matters: CSS and JS must be extracted and processed before HTML whitespace reduction, because the whitespace reducer must not touch content inside `<style>` and `<script>` tags that has already been minified.

### 4.4 System Calls

For each Node.js tool, the pattern is:
1. Write the extracted content (JS or CSS) to a temporary file.
2. Call the tool via `system2()` with appropriate arguments.
3. Read the minified output.
4. Clean up the temporary file.
5. If the system call fails (non-zero exit code), warn and fall back to the original unminified content. The pipeline must never fail completely — a report with unminified JS is still a valid report.

**Temporary files** should be written to `tempdir()` with unique names to avoid conflicts if multiple reports are being processed.

---

## 5. Verification

After minification, run these automated checks. Any failure should produce a warning (not an error — the minified file may still be usable).

### 5.1 File Integrity

- The output file is valid HTML (opens without parse errors).
- The output file size is smaller than the input file size. If it is not, something went wrong — warn.

### 5.2 JavaScript Integrity

- Count the number of top-level named functions (matching pattern `function\s+\w+\s*\(`) in original and minified JavaScript. They must be equal, because `toplevel=false` means function names are preserved.
- Every function name referenced in an `onclick`, `onchange`, or other inline event handler in the HTML body must exist as a defined function in the minified JavaScript. Extract all function names from inline handlers and verify each appears in the JS.

### 5.3 CSS Integrity

- Count the number of CSS custom property declarations (`--ct-` prefix) in original and minified CSS. They must be equal.
- Count the number of CSS rule blocks (selectors followed by `{`) in original and minified. They must be equal.

### 5.4 Content Integrity

- The total number of `<table>` elements is the same in input and output.
- The total number of `<tr>` elements is the same.
- The total number of `<td>` and `<th>` elements is the same.
- The total number of `data-q-code` attributes is the same.
- The total number of `data-col-key` attributes is the same.

### 5.5 Size Report

Print (if `verbose = TRUE`) or return:
```
Turas Minification Summary
─────────────────────────────────
Input:     2,481 KB  (Demo_CX_Crosstabs_dev.html)
Output:    1,650 KB  (Demo_CX_Crosstabs.html)
Reduction: 33.5%
─────────────────────────────────
JS blocks:     3 processed
CSS blocks:    1 processed
Meta tags:     7 stripped
HTML comments: 12 removed
Warnings:      0
─────────────────────────────────
Verification:  ALL CHECKS PASSED
```

---

## 6. Error Handling

The pipeline must be resilient. A minification failure should never prevent a report from being delivered.

- If Node.js is not installed: warn, return the original file as the output (copy, not process), set a warning in the return list.
- If `terser` is not installed: warn, skip JS minification, process everything else.
- If CSS minifier is not installed: warn, skip CSS minification, process everything else.
- If a specific `<script>` block fails to minify: warn (including which block by index), keep the original unminified content for that block, continue with the rest.
- If HTML whitespace reduction produces a file larger than the original: warn, use the pre-whitespace-reduction version.
- If any verification check fails: warn with details, still output the file (it may be fine — the check may be overly strict).

**Never throw an error that stops report generation.** The worst case is that the client receives an unminified report, which is exactly what they receive today.

---

## 7. Testing

### 7.1 Test Files

Use the attached `Demo_CX_Crosstabs.html` as the primary test file. Additionally, test with at least one report from each Turas module type if available, to ensure the pipeline handles different report structures.

### 7.2 Test Cases

**Functional tests:**
1. Minified report opens in Chrome, Firefox, and Safari without console errors.
2. All interactive features work in the minified report: tab switching, table sorting, column toggling, gauge card exclusion, pin-to-slide, slide export (SVG and PNG), Excel export, CSV export, heatmap collapse/expand, print layout.
3. The visual appearance of the minified report is pixel-identical to the original (compare screenshots).
4. The minified file is measurably smaller than the original.

**Edge case tests:**
5. Report with no JavaScript (e.g., a static summary-only report) processes without error.
6. Report with `<script type="application/json">` blocks preserves them untouched.
7. Report with `contenteditable` divs preserves their content and whitespace.
8. Report with inline `onclick` handlers still triggers the correct functions after minification.
9. Running `turas_minify()` on an already-minified file does not corrupt it (idempotency — the second pass should produce a nearly identical file).
9a. Open a minified report, add client-side pins (chart pins, table pins, text insights), add slides with images, save the report. Re-open the saved version and confirm all pins, insights, slides, and images load back correctly. This tests that the save mechanism (which writes modified HTML to disk) produces valid output from a minified starting point.

**Graceful degradation tests:**
10. With `terser` not installed: function completes, warns, outputs file without JS minification.
11. With no Node.js at all: function completes, warns, copies file to output path unprocessed.

### 7.3 Known-Answer Tests

- Process the demo file. Assert that the output file size is between 50% and 95% of the input file size (if it is outside this range, something is wrong).
- Assert that the number of `<table>` tags is exactly preserved.
- Assert that the number of `function ` declarations in the JS is exactly preserved.
- Assert that the number of CSS custom property declarations (`--` prefixed) is exactly preserved.

---

## 8. File Naming Convention

**Convention:** The unminified (dev) file has a `_dev` suffix. The minified (deliverable) file has the clean project name.

```
Project folder:
  reports/
    CCPB_Brand_Tracker_2025_dev.html    ← your copy, for debugging
    CCPB_Brand_Tracker_2025.html        ← client deliverable, minified
```

The R pipeline should generate the file with the `_dev` suffix, then call `turas_minify()` which produces the clean-named version. This means the change to existing module code is minimal: append `_dev` to the filename in the existing `write` call, then add a single `turas_minify()` call afterwards.

---

## 9. Priority and Roadmap

### 9.1 Why This Matters

Minification is the industry baseline for commercial HTML report products. Shipping unminified, commented source code in a client deliverable exposes implementation logic and makes casual copying trivial. Minification raises the effort bar for reverse engineering, reduces file size, and signals professional delivery standards.

### 9.2 Priority Order by Impact

| Priority | Step | Size Impact | IP Impact | Scope |
|----------|------|------------|-----------|-------|
| 1 | Inline styles → CSS classes | Biggest reduction | Modest | R generation code change (separate project) |
| 2 | JS minification | Good reduction | Strong | Post-processing (this spec) |
| 3 | CSS minification | Modest reduction | Moderate | Post-processing (this spec) |
| 4 | Strip meta tags | None | Clean-up | Post-processing (this spec) |
| 5 | HTML whitespace | Modest reduction | Minimal | Post-processing (this spec) |

Items 2–5 are covered by this spec. Item 1 requires refactoring the R HTML generation code and is a separate project.

The first two items deliver the most value. Items 3–5 come along cheaply once a build step is in place.

### 9.3 Release Pipeline Context

This spec defines `turas_minify()` as a standalone function, but it is designed to slot into a broader `turas_release()` pipeline that runs all delivery preparation steps. The planned build order:

1. **AI insight generation** — build and stabilise first (separate spec)
2. **Minification** — this spec, built after AI insights are stable
3. **Future steps** — obfuscation, watermarking, etc. as needed

Each step is independent and pluggable. During development and internal use, reports never hit the release pipeline — only client deliverables pass through it.

### 9.4 Hub Report Workflow

Hub reports embed multiple individual sub-reports as base64-encoded blobs. The correct workflow is:

```
R generates individual report_dev.html
        │
        ▼
turas_minify() → report.html (minified individual)
        │
        ▼
Hub module base64-encodes report.html (not _dev)
        │
        ▼
hub_dev.html
        │
        ▼
turas_minify() → hub.html (minified hub shell)
```

Individual reports are minified first, then encoded into the hub, then the hub shell itself is minified. This ensures the base64 blobs are as small as possible.

---

## 10. Future Considerations (Not in Scope Now)

These are logged for awareness but are NOT part of this implementation:

- **Inline style consolidation** — moving repeated inline `style=""` attributes on heatmap cells to CSS class selectors driven by `data-tier` attributes. This is a larger refactoring of the R HTML generation code and should be a separate project. It would further reduce file size significantly. This is priority 1 by impact (see Section 9.2).
- **AI insight callouts** — adding AI-generated insight text alongside charts and tables, with distinct visual styling and pin-to-slide toggle. This is a separate feature that will need its own spec. The minification pipeline should handle any new HTML/CSS/JS that this feature introduces, without modification. This is built before minification in the release pipeline.
- **JS obfuscation** — tools like `javascript-obfuscator` go beyond minification: string encoding, control flow flattening, dead code injection. Makes reverse engineering actively hostile rather than merely inconvenient. Slots into the release pipeline as an optional step after minification.
- **Client watermarking** — embedding a unique invisible identifier (UUID, generation timestamp, client code) in each delivered report. Enables tracing if a report is shared or leaked. Cheap to implement as a release pipeline step.
- **Copyright notice** — injecting `/*! Turas © TRL [year]. All rights reserved. */` in preserved JS comments (supported via terser `--comments` flag, already included in this spec's options).
- **Source maps** — generating `.map` files alongside minified JS for browser dev tools debugging. Not needed because the dev copy serves this purpose.
- **Image optimisation** — if reports ever embed base64 images, these could be optimised. Not currently relevant.
- **Gzip pre-compression** — creating `.gz` versions for web serving. Not relevant for email/file-share delivery.

---

## 10a. Non-Technical Considerations

These are not code tasks but directly affect whether the technical IP protection in this spec has any teeth.

- **Contractual protection** — Client contracts should include clauses prohibiting reverse engineering, decompilation, and redistribution of Turas report code. Minification without legal protection is a locked door with the key under the mat. Review existing MSA/SOW templates and add IP protection language if not already present. This is a legal/commercial task, not a development task.
- **Client watermarking** — Embed a unique invisible identifier in each delivered report (e.g., a `<meta name="turas-delivery-id" content="uuid">` tag or a short encoded comment). This enables tracing if a report's code is found outside the intended client. Trivially cheap to implement as a release pipeline step. Consider adding client code, generation timestamp, and report version. Note: this tag would be injected *after* the `turas-*` meta stripping step, and should use a non-obvious name (not `turas-` prefixed) so it is not caught by the same strip rule.

---

## 11. Acceptance Criteria

The implementation is complete when:

1. `turas_minify()` processes the demo file without errors.
2. The minified demo file opens in a browser and all interactive features work identically to the original.
3. The minified file is at least 25% smaller than the original.
4. All verification checks pass.
5. All graceful degradation scenarios produce warnings (not errors) and output a usable file.
6. The function includes a plain-English delivery summary per Duncan's coding standards.
7. The function includes automated tests per Duncan's coding standards.
8. The function is documented with description, `@param`, `@return`, and `@examples`.

---

## 12. Reference Files

- `Demo_CX_Crosstabs.html` — primary test file (attached / available in project)
- Duncan's coding standards skill — read before implementation for coding conventions, testing requirements, and delivery protocol

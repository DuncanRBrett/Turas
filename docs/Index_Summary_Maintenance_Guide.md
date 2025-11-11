# TURAS Index Summary Module - Code Maintenance Guide

**Module Version:** V10.1
**Implementation Date:** November 2025
**Developer Documentation**

---

## Table of Contents

1. [Module Overview](#module-overview)
2. [Architecture](#architecture)
3. [Code Structure](#code-structure)
4. [Function Reference](#function-reference)
5. [Data Flow](#data-flow)
6. [Integration Points](#integration-points)
7. [Extending the Module](#extending-the-module)
8. [Testing Guidelines](#testing-guidelines)
9. [Common Maintenance Tasks](#common-maintenance-tasks)
10. [Troubleshooting Guide](#troubleshooting-guide)

---

## Module Overview

The Index Summary module creates a consolidated metrics summary sheet in TURAS crosstab output. It extracts key metrics from all processed questions and organizes them with composite scores for executive reporting.

**Core Responsibilities:**
- Extract Average, Index, Score, and Top/Bottom Box rows from question results
- Group composite scores with their source questions
- Apply section headers for logical organization
- Format for professional Excel output
- Match decimal formatting with standard crosstabs

**Module Location:**
- `/modules/tabs/lib/summary_builder.R` - Table construction logic
- `/modules/tabs/lib/excel_writer.R` - Excel output formatting (modified)
- `/modules/tabs/lib/run_crosstabs.R` - Integration orchestration (modified)

---

## Architecture

### Design Principles

**1. Modular Design**
- Separate concerns: table building vs Excel formatting
- Reusable functions with clear responsibilities
- No modification to existing question processing logic

**2. Non-Breaking Integration**
- Feature disabled by default
- All changes are additive
- Existing functionality untouched
- Graceful degradation if feature disabled

**3. Consistent Standards**
- Matches TURAS code style conventions
- Roxygen documentation for all functions
- Safe config value extraction throughout
- Error isolation prevents cascade failures

**4. Performance Optimized**
- Minimal overhead (< 1 second typical)
- Processes data already in memory
- No redundant calculations

---

## Code Structure

### Primary Module: summary_builder.R

**File:** `/modules/tabs/lib/summary_builder.R`
**Lines:** 605 total
**Purpose:** Constructs Index_Summary table from results

**Functions:**

```r
build_index_summary_table()
├── extract_metric_rows()           # Standard questions
├── extract_composite_rows()        # Composite scores
├── organize_by_composite_groups()  # Intelligent grouping
├── insert_section_headers()        # Section organization
└── format_summary_for_excel()      # Final formatting
```

**Dependencies:**
- `composite_processor.R` - For composite definitions and results
- `shared_functions.R` - For `get_config_value()`

---

### Modified Module: excel_writer.R

**File:** `/modules/tabs/lib/excel_writer.R`
**Additions:** ~200 lines (lines 1175-1430)
**Modifications:** Zero deletions from existing code

**New Function:**

```r
write_index_summary_sheet()
├── Create sheet and headers
├── Format section headers (gray background)
├── Format composite rows (cream background, → prefix)
├── Format metric rows (standard)
├── Write base sizes
└── Apply Excel styles
```

**Key Addition:**
- Lines 1330-1355: Numeric conversion for Excel style formatting
- This ensures decimal separator (comma/period) matches crosstabs

---

### Modified Module: run_crosstabs.R

**File:** `/modules/tabs/lib/run_crosstabs.R`
**Additions:** ~40 lines
**Modifications:** Zero deletions

**Integration Points:**

```r
# Line 140-141: Module loading
source(file.path(script_dir, "summary_builder.R"))

# Lines 950-980: Build and write Index_Summary
if (create_index_summary) {
  summary_table <- build_index_summary_table(...)
  write_index_summary_sheet(...)
}
```

---

## Function Reference

### build_index_summary_table()

**Purpose:** Main orchestrator - builds complete summary table

**Parameters:**
- `results_list` - List of standard question results
- `composite_results` - List of composite results
- `banner_info` - Banner structure information
- `config` - Configuration list
- `composite_defs` - Data frame of composite definitions (optional)

**Returns:** Data frame ready for Excel output

**Process Flow:**
```
1. Extract metric rows from standard questions
2. Extract composite rows (if any)
3. Combine into single data frame
4. Organize by composite groups
5. Insert section headers (if enabled)
6. Format for Excel
```

**Key Logic:**
- Replaces generic labels ("Mean", "Average") with question text
- Adds question codes to labels (e.g., "Q23 - Product Quality")
- Preserves all banner columns from source tables

---

### extract_metric_rows()

**Purpose:** Extract Average/Index/Score rows from question results

**Parameters:**
- `results_list` - List of question results
- `banner_info` - Banner structure
- `config` - Configuration (for decimal handling)

**Returns:** Data frame with metric rows

**Logic:**
```r
for each question in results_list:
  - Find rows where RowType = "Average" | "Index" | "Score"
  - Find rows matching "Top.*Box|Bottom.*Box" pattern
  - Replace generic labels with question text
  - Add metadata (QuestionCode, IsComposite=FALSE, Section=NA)
  - Ensure all banner columns exist
```

**Important:**
- Source question rows do NOT have decimal replacement here
- Values remain as-is from original processing
- Excel formatting handles decimal separator on output

---

### extract_composite_rows()

**Purpose:** Extract composite metric rows

**Parameters:**
- `composite_results` - List of composite results
- `banner_info` - Banner structure
- `composite_defs` - Composite definitions
- `config` - Configuration

**Returns:** Data frame with composite rows

**Logic:**
```r
for each composite in composite_results:
  - Check if excluded from summary
  - Get metric row (Average/Index/Score)
  - Add source questions to label: "Label (Q1, Q2, Q3)"
  - Mark as composite (IsComposite=TRUE)
  - Add section if defined
```

**Exclusion Logic:**
- If `ExcludeFromSummary = "Y"` in composite_defs, skip
- Allows composites to exist in crosstabs but not summary

---

### organize_by_composite_groups()

**Purpose:** Group composites with their source questions

**Parameters:**
- `metrics_df` - Combined metrics data frame
- `composite_defs` - Composite definitions
- `config` - Configuration

**Returns:** Reorganized data frame

**Algorithm:**
```
1. Separate composites from standard metrics
2. Build source question map (which questions belong to which composites)
3. For each section:
   a. Add composite row
   b. Add source questions (indented with "  " prefix)
4. Add composites without sections
5. Add remaining metrics not part of any composite
```

**Critical Feature:**
- Maintains visual hierarchy
- Source questions indented for clarity
- Order preserved for logical flow

---

### insert_section_headers()

**Purpose:** Insert section header rows

**Parameters:**
- `metrics_df` - Metrics data frame (already organized)
- `banner_info` - Banner structure

**Returns:** Data frame with headers inserted

**Key Design:**
- **Preserves existing order** (does not reorganize!)
- Inserts header row when Section value changes
- Header rows have RowType = "SectionHeader"

**Algorithm:**
```r
current_section = NULL
for each row in metrics_df:
  if row.Section changes and is not NA:
    - Insert section header row
    - Update current_section
  - Add data row
```

---

### write_index_summary_sheet()

**Purpose:** Write formatted Index_Summary sheet to Excel workbook

**Parameters:**
- `wb` - Workbook object
- `summary_table` - Summary data frame
- `banner_info` - Banner structure
- `config` - Configuration
- `styles` - Excel styles
- `all_results` - All question results (for base sizes)

**Returns:** Invisible NULL (modifies workbook by reference)

**Key Features:**

**1. Base Size Extraction**
```r
# If banner_info$base_sizes is NULL, extract from first question result
if (is.null(banner_info$base_sizes)) {
  for (result in all_results) {
    if (!is.null(result$bases)) {
      banner_info$base_sizes <- result$bases
      break
    }
  }
}
```

**2. Numeric Conversion (CRITICAL for decimal formatting)**
```r
# Lines 1334-1352
value <- as.character(value[1])  # Safe conversion
if (!is.na(value) && value != "NA" && value != "") {
  has_letters <- grepl("[a-zA-Z]", value)
  if (!is.na(has_letters) && !has_letters) {
    numeric_value <- suppressWarnings(as.numeric(gsub(",", ".", value)))
    if (!is.na(numeric_value)) {
      value <- numeric_value  # Write as numeric, not string!
    }
  }
}
```

**Why This Matters:**
- Writing numeric values allows Excel styles to apply number formatting
- The style contains the decimal separator (comma or period)
- Excel renders the number with the correct separator
- This matches exactly how standard crosstabs work

**3. Style Application**
```r
# Section headers: gray background
if (style_hint == "SectionHeader") {
  row_style <- section_style
}
# Composites: cream background
else if (style_hint == "Composite") {
  row_style <- composite_style
}
# Standard metrics: white background
else {
  row_style <- metric_style
}
```

---

## Data Flow

### High-Level Flow

```
run_crosstabs.R
  ├── [Process all standard questions]
  │   └── results_list created
  ├── process_all_composites()
  │   └── composite_results created
  ├── build_index_summary_table()
  │   ├── extract_metric_rows(results_list)
  │   ├── extract_composite_rows(composite_results)
  │   ├── organize_by_composite_groups()
  │   ├── insert_section_headers()
  │   └── format_summary_for_excel()
  └── write_index_summary_sheet()
      └── Excel workbook modified
```

### Data Structure Flow

**Input:** `results_list`
```r
list(
  Q23 = list(
    question_code = "Q23",
    question_text = "Product Quality",
    table = data.frame(
      RowLabel = c("Mean"),
      RowType = c("Average"),
      `TOTAL::Total` = c("8.1"),
      ...
    )
  )
)
```

**Intermediate:** `metric_rows`
```r
data.frame(
  RowLabel = "Q23 - Product Quality",
  RowType = "Average",
  QuestionCode = "Q23",
  IsComposite = FALSE,
  Section = NA,
  `TOTAL::Total` = "8.1",
  ...
)
```

**Output:** `summary_table`
```r
data.frame(
  RowLabel = c(
    "Company Metrics",           # Section header
    "→ Overall Satisfaction",    # Composite
    "  Q23 - Product Quality",   # Source (indented)
    "  Q25 - Customer Service"   # Source (indented)
  ),
  RowType = c("SectionHeader", "Average", "Average", "Average"),
  StyleHint = c("SectionHeader", "Composite", "Normal", "Normal"),
  `TOTAL::Total` = c("", "7.8", "8.1", "7.5"),
  ...
)
```

---

## Integration Points

### Configuration Settings

**Location:** `Crosstab_Config.xlsx` → Settings sheet

**Read By:** `run_crosstabs.R` via `config_obj`

**Settings Used:**
```r
config$create_index_summary              # Y/N - master switch
config$index_summary_show_sections       # Y/N - section headers
config$index_summary_show_base_sizes     # Y/N - base rows
config$index_summary_show_composites     # Y/N - include composites
config$index_summary_decimal_places      # 0-3 - override (optional)
config$decimal_separator                 # , or . - inherited
config$decimal_places_ratings            # default for ratings
```

**Access Pattern:**
```r
# Safe extraction with defaults
show_sections <- get_config_value(config, "index_summary_show_sections", TRUE)
```

---

### Banner Structure

**Source:** `banner_info` object from `create_banner_structure()`

**Used Fields:**
```r
banner_info$internal_keys    # Column keys (e.g., "TOTAL::Total", "Q67::Male")
banner_info$columns          # Banner column display names
banner_info$base_sizes       # May be NULL - extract from results if needed
```

**Special Handling:**
```r
# banner_info$base_sizes is often NULL
# Extract from first question result's bases
for (result in all_results) {
  if (!is.null(result$bases)) {
    banner_info$base_sizes <- result$bases
    break
  }
}
```

---

### Composite Integration

**Source:** `composite_processor.R`

**Composite Results Structure:**
```r
composite_results <- list(
  COMP_SAT = list(
    question_table = data.frame(...),
    metadata = list(
      composite_code = "COMP_SAT",
      source_questions = c("Q23", "Q25"),
      calculation_type = "Mean",
      has_significance = TRUE
    )
  )
)
```

**Composite Definitions Structure:**
```r
composite_defs <- data.frame(
  CompositeCode = "COMP_SAT",
  CompositeLabel = "Overall Satisfaction",
  CalculationType = "Mean",
  SourceQuestions = "Q23,Q25,Q27",
  ExcludeFromSummary = NA,
  SectionLabel = "SATISFACTION",
  ...
)
```

---

## Extending the Module

### Adding New Metric Types

**Current:** Extracts Average, Index, Score, Top/Bottom Box

**To Add New Type:**

1. Modify `extract_metric_rows()` in `summary_builder.R`:

```r
# Add to line ~128
new_rows <- table[table$RowType == "NewType", , drop = FALSE]

# Add to rbind at line ~138
all_rows <- rbind(avg_rows, idx_rows, score_rows, box_rows, new_rows)
```

2. Test with sample data containing new RowType

---

### Adding Custom Formatting

**Styles Defined:** `excel_writer.R` → `create_excel_styles()`

**To Add New Style:**

1. Add style hint in `format_summary_for_excel()`:

```r
# Line ~420 in summary_builder.R
if (meets_criteria) {
  metrics_df$StyleHint[idx] <- "CustomStyle"
}
```

2. Add style application in `write_index_summary_sheet()`:

```r
# Line ~1300 in excel_writer.R
else if (style_hint == "CustomStyle") {
  row_style <- custom_style
}
```

3. Define custom_style in `create_excel_styles()`

---

### Adding Configuration Options

**Steps:**

1. Add setting to `Crosstab_Config.xlsx` template
2. Read in `run_crosstabs.R`:

```r
new_setting <- get_config_value(config_obj, "new_setting_name", default_value)
```

3. Pass to functions as needed
4. Document in user manual

---

## Testing Guidelines

### Unit Testing

**Test Files Location:** `/tests/` (to be created)

**Key Test Cases:**

**1. extract_metric_rows()**
```r
test_that("extracts Average rows correctly", {
  # Setup mock results_list
  # Call extract_metric_rows()
  # Verify output structure and content
})

test_that("handles questions with no metrics", {
  # Test graceful handling of empty tables
})
```

**2. organize_by_composite_groups()**
```r
test_that("groups composites with sources", {
  # Verify composite appears before sources
  # Verify sources are indented
  # Verify order preserved
})

test_that("handles missing source questions", {
  # Composite exists but source not in data
  # Should not error
})
```

**3. insert_section_headers()**
```r
test_that("preserves existing order", {
  # Metrics already organized
  # Headers inserted without reordering
})

test_that("handles NA sections", {
  # Some rows with Section, some NA
  # NA rows grouped separately
})
```

---

### Integration Testing

**Test Scenarios:**

**Test 1: Feature Disabled (Regression Test)**
```r
# Config: create_index_summary = N
# Expected: No Index_Summary sheet
# Expected: All other output identical to previous version
```

**Test 2: Basic Summary**
```r
# Config: create_index_summary = Y, no composites
# Expected: Index_Summary with all Average/Index/Score rows
# Expected: Alphabetical order
# Expected: Base sizes populated
```

**Test 3: Summary with Composites**
```r
# Config: create_index_summary = Y, has composites
# Expected: Composites grouped with sources
# Expected: Section headers applied
# Expected: Correct indentation
```

**Test 4: Edge Cases**
```r
# No metrics (all categorical)
# Missing source questions
# Excluded composites
# NULL base_sizes in banner_info
```

---

### Manual Testing Checklist

- [ ] Index_Summary sheet appears in output
- [ ] All expected metrics present
- [ ] Question codes and text correct
- [ ] Composites grouped with source questions
- [ ] Source questions indented
- [ ] Section headers applied (if enabled)
- [ ] Decimal separator matches crosstabs (comma or period)
- [ ] Base sizes populated correctly
- [ ] Weighted n appears (if weighting enabled)
- [ ] Significance letters present (if applicable)
- [ ] Styling correct (section headers gray, composites cream)
- [ ] No duplicate rows
- [ ] No errors in Error Log sheet

---

## Common Maintenance Tasks

### Updating Decimal Places

**Location:** `excel_writer.R` → styles definition

**Current:** Inherited from `config$decimal_places_ratings`

**To Change Globally:**
Update config file setting

**To Change for Index_Summary Only:**
```r
# Add in write_index_summary_sheet()
decimal_override <- get_config_value(config, "index_summary_decimal_places", NULL)
if (!is.null(decimal_override)) {
  # Use override
}
```

---

### Changing Sort Order

**Current:** Organized by composite groups, then remaining alphabetically

**Location:** `summary_builder.R` → `organize_by_composite_groups()`

**To Change:**
- Modify lines 360-380 for non-composite sorting logic
- Current uses SortKey: Section_RowLabel

---

### Modifying Section Header Format

**Location:** `excel_writer.R` → `create_excel_styles()`

**Current Style:**
```r
section_header = createStyle(
  fontSize = 11,
  fontColour = "#FFFFFF",
  fgFill = "#808080",  # Gray
  textDecoration = "bold",
  halign = "left"
)
```

**To Modify:**
Change fgFill (background color), fontSize, etc.

---

### Adding Debug Output (for troubleshooting)

**Temporary Debug Pattern:**

```r
# In summary_builder.R
message(sprintf("DEBUG: Processing %d metrics", nrow(metrics_df)))

# In excel_writer.R
cat(sprintf("Writing row %d: %s\n", i, row_label))
```

**Remember:**
- Use `message()` for info (goes to stderr)
- Use `cat()` for detailed debug (goes to stdout)
- Remove before production release

---

## Troubleshooting Guide

### Issue: "argument is of length zero"

**Cause:** Accessing config/data without NULL/length checks

**Solution:**
```r
# WRONG
if (config$setting) { ... }

# RIGHT
if (!is.null(config$setting) && length(config$setting) > 0) {
  if (config$setting) { ... }
}
```

**Check:** Lines accessing config, RowType, Section columns

---

### Issue: Decimal separator not working

**Cause:** Values written as character strings instead of numeric

**Solution:**
Ensure numeric conversion in `excel_writer.R` lines 1334-1352

**Verify:**
```r
# Value must be numeric type when written
value <- as.numeric(gsub(",", ".", value))  # Convert "7,5" → 7.5
openxlsx::writeData(wb, sheet, value)  # Write as number, not string
```

---

### Issue: Composite grouping broken

**Cause:** `insert_section_headers()` reorganizing rows

**Solution:**
Ensure `insert_section_headers()` preserves order (lines 545-570)

**Key:** Iterate through existing order, insert headers without sorting

---

### Issue: Base sizes blank

**Cause:** `banner_info$base_sizes` is NULL

**Solution:**
Extract from question results (lines 1183-1191 in `excel_writer.R`)

**Verify:**
```r
if (is.null(banner_info$base_sizes)) {
  # Extract from all_results
}
```

---

### Issue: Missing questions in summary

**Cause:** Questions don't have Average/Index/Score rows

**Solution:**
- Only metric rows appear in summary
- Categorical questions don't produce metrics (by design)
- Check question RowType in crosstabs

---

## Code Quality Standards

### Roxygen Documentation

**Required for all functions:**
```r
#' Function Title
#'
#' Detailed description
#'
#' @param param_name Description
#' @return Description
#' @export or @keywords internal
function_name <- function(...) {
```

---

### Error Handling

**Pattern:**
```r
# Safe config access
value <- if (!is.null(config$setting) && length(config$setting) > 0) {
  config$setting
} else {
  default_value
}

# Safe data access
if ("Column" %in% names(df) && nrow(df) > 0) {
  # Process
}
```

---

### Naming Conventions

**Functions:** snake_case
- `build_index_summary_table()`
- `extract_metric_rows()`

**Variables:** snake_case
- `metric_rows`
- `composite_defs`

**Constants:** UPPER_SNAKE_CASE (if used)
- `DEFAULT_DECIMAL_PLACES`

---

## Performance Considerations

**Typical Performance:**
- Summary building: < 0.1 seconds
- Excel writing: < 0.2 seconds
- **Total overhead: < 0.5 seconds**

**Optimization Notes:**
- No redundant calculations
- Data already in memory
- Single pass through results
- rbind used efficiently

**To Monitor:**
```r
start_time <- Sys.time()
summary_table <- build_index_summary_table(...)
end_time <- Sys.time()
message(sprintf("Summary built in %.2f seconds", as.numeric(end_time - start_time)))
```

---

## Version History

**V10.1 (November 2025)**
- Initial implementation
- Composite grouping
- Section headers
- Decimal separator matching
- Base size extraction

**Future Enhancements (Planned):**
- Custom metric type filtering
- Row-level exclusion rules
- Alternative sort orders
- PDF export option

---

## Support & Contact

**Code Owner:** TURAS Development Team
**Module:** Index Summary (V10.1)
**Dependencies:** composite_processor.R, summary_builder.R

**For Questions:**
1. Review this guide
2. Check function Roxygen documentation
3. Examine test cases in `/tests/`
4. Contact development team with specific error details

---

**Document Version:** 1.0
**Last Updated:** November 2025
**Module Version:** V10.1

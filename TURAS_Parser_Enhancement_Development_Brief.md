# TURAS Parser Enhancement - Development Brief
## Multi-Source Questionnaire Parser v2.0

**Project:** TURAS Analytics Toolkit  
**Module:** Parser  
**Version:** 2.0.0  
**Date:** November 2025  
**Status:** Development Planning

---

## 1. Executive Summary

### Current State
The TURAS Parser currently extracts survey structure from Word documents (.docx) using pattern-matching and structure-based parsing strategies. While effective for well-formatted documents, it struggles with:
- Complex question types (radio grids, checkbox grids)
- Inconsistent formatting
- Piped question placeholders
- Multi-column matrix questions

### Proposed Enhancement
Extend the parser to support multiple input sources while maintaining backward compatibility:
- **Alchemer Translation Exports** (primary source - most reliable)
- **Data Export Headers** (validation source)
- **Word Documents** (legacy/fallback source)
- **Future platforms** (Qualtrics, SurveyMonkey, Google Forms, etc.)

### Benefits
1. **Higher accuracy** - Platform exports provide canonical question structure
2. **Grid question support** - Native handling of complex matrix questions
3. **Reduced manual cleanup** - Less post-processing needed
4. **Future-proof** - Extensible architecture for new platforms
5. **Smart fallback** - Automatically combines multiple sources when available

---

## 2. Architecture Overview

### 2.1 Design Principles

**SOLID Principles**
- **Single Responsibility**: Each parser handles one source type
- **Open/Closed**: Easily add new parsers without modifying existing code
- **Liskov Substitution**: All parsers implement common interface
- **Interface Segregation**: Clean parser contract
- **Dependency Inversion**: Orchestrator depends on abstractions, not concrete parsers

**Key Patterns**
- **Strategy Pattern**: Multiple parsing strategies (already in use)
- **Factory Pattern**: Create appropriate parser for input type
- **Chain of Responsibility**: Try multiple sources, combine results
- **Adapter Pattern**: Normalize different platform formats to common structure

### 2.2 New Directory Structure

```
modules/parser/
├── run_parser.R                    # Entry point (updated)
├── shiny_app.R                     # UI (enhanced for multi-source)
├── lib/
│   ├── core/
│   │   ├── parser_interface.R      # NEW: Base parser interface
│   │   ├── parser_factory.R        # NEW: Create parsers by type
│   │   ├── multi_source_orchestrator.R  # NEW: Combine sources
│   │   └── platform_detector.R     # NEW: Auto-detect file types
│   │
│   ├── parsers/
│   │   ├── docx/
│   │   │   ├── docx_parser.R       # REFACTOR: Wrap existing
│   │   │   ├── docx_reader.R       # MOVE: From lib/
│   │   │   ├── pattern_parser.R    # MOVE: From lib/
│   │   │   └── structure_parser.R  # MOVE: From lib/
│   │   │
│   │   ├── alchemer/
│   │   │   ├── alchemer_parser.R           # NEW: Main parser
│   │   │   ├── translation_reader.R        # NEW: Read translation CSV/Excel
│   │   │   ├── grid_expander.R             # NEW: Expand grids to rows
│   │   │   └── alchemer_type_mapper.R      # NEW: Map Alchemer types to TURAS
│   │   │
│   │   ├── data_headers/
│   │   │   ├── data_header_parser.R        # NEW: Parse column headers
│   │   │   └── column_analyzer.R           # NEW: Detect patterns in headers
│   │   │
│   │   └── qualtrics/                      # FUTURE
│   │       └── qualtrics_parser.R          # FUTURE: Placeholder
│   │
│   ├── shared/
│   │   ├── text_cleaner.R          # KEEP: Shared utility
│   │   ├── type_detector.R         # ENHANCE: Add platform hints
│   │   ├── bin_detector.R          # KEEP: Shared utility
│   │   └── question_merger.R       # NEW: Merge from multiple sources
│   │
│   └── output/
│       └── output_generator.R      # KEEP: Generate Excel files
│
└── Documentation/
    ├── Parser_v2_Architecture.md   # NEW: Architecture docs
    ├── Adding_New_Platform.md      # NEW: Guide for extensions
    └── Migration_Guide_v1_to_v2.md # NEW: Upgrade guide
```

---

## 3. Detailed Component Specifications

### 3.1 Core Components

#### `parser_interface.R` - Base Parser Interface
```r
#' Base Parser Interface
#' All parsers must implement these methods
#' 
BaseParser <- R6::R6Class("BaseParser",
  public = list(
    
    # Core methods (required)
    initialize = function(config) {},
    can_parse = function(file_path) {},
    parse = function(file_path) {},
    get_confidence = function() {},
    get_source_type = function() {},
    
    # Optional methods
    validate_input = function(file_path) {},
    get_metadata = function() {}
  )
)

#' Parsed Question Standard Structure
#' All parsers must return data in this format
#' 
#' @return list with:
#'   - questions: data.frame with columns:
#'       - code: Question code (Q1, Q2, etc.)
#'       - text: Question text (with placeholders preserved)
#'       - type: Variable_Type (Single_Response, Multi_Mention, etc.)
#'       - columns: Number of columns (for Multi_Mention, grids)
#'       - options: List column of option data frames
#'       - metadata: List column of additional info
#'       - confidence: Parsing confidence (high/medium/low)
#'       - needs_review: Logical flag
#'       - source: Which parser produced this (docx/alchemer/data)
#'   - metadata: list with:
#'       - platform: Source platform name
#'       - file_type: File extension
#'       - parsed_at: Timestamp
#'       - parser_version: Version string
```

#### `parser_factory.R` - Parser Factory
```r
#' Create Parser by File Type
#' 
#' @param file_path Path to input file
#' @param config Parsing configuration
#' @return Parser object
#' 
create_parser <- function(file_path, config) {
  
  # Detect file type
  file_type <- detect_file_type(file_path)
  platform <- detect_platform(file_path, file_type)
  
  # Create appropriate parser
  parser <- switch(platform,
    "alchemer_translation" = AlchemerTranslationParser$new(config),
    "alchemer_data" = AlchemerDataParser$new(config),
    "word" = DocxParser$new(config),
    "csv_generic" = GenericCsvParser$new(config),
    "excel_generic" = GenericExcelParser$new(config),
    stop("Unsupported file type: ", file_type)
  )
  
  return(parser)
}
```

#### `multi_source_orchestrator.R` - Multi-Source Orchestrator
```r
#' Parse from Multiple Sources and Merge
#' 
#' @param sources Named list of file paths
#'   e.g., list(translation = "file1.csv", data = "file2.xlsx", word = "file3.docx")
#' @param config Parsing configuration
#' @param strategy Merge strategy: "best", "priority", "consensus"
#' @return Merged question structure
#' 
parse_multi_source <- function(sources, config, strategy = "best") {
  
  results <- list()
  
  # Parse each source
  for (source_name in names(sources)) {
    file_path <- sources[[source_name]]
    
    parser <- create_parser(file_path, config)
    
    if (parser$can_parse(file_path)) {
      result <- parser$parse(file_path)
      result$source_name <- source_name
      results[[source_name]] <- result
    }
  }
  
  # Merge results based on strategy
  merged <- merge_sources(results, strategy, config)
  
  return(merged)
}

#' Merge Multiple Parsed Sources
#' 
#' Strategies:
#' - "best": Take highest confidence for each question
#' - "priority": Use first source, fill gaps with others
#' - "consensus": Only accept if multiple sources agree
#' 
merge_sources <- function(results, strategy, config) {
  
  if (length(results) == 0) {
    stop("No sources successfully parsed")
  }
  
  if (length(results) == 1) {
    return(results[[1]])
  }
  
  # Implementation based on strategy
  merged <- switch(strategy,
    "best" = merge_by_confidence(results),
    "priority" = merge_by_priority(results, config$priority_order),
    "consensus" = merge_by_consensus(results),
    merge_by_confidence(results)
  )
  
  return(merged)
}
```

### 3.2 Alchemer Parser Components

#### `alchemer_parser.R` - Main Alchemer Parser
```r
#' Alchemer Translation Parser
#' 
#' Parses Alchemer translation export files (CSV or Excel)
#' These contain the most reliable question structure
#' 
AlchemerTranslationParser <- R6::R6Class("AlchemerTranslationParser",
  inherit = BaseParser,
  
  public = list(
    
    parse = function(file_path) {
      
      # Read translation file
      raw_data <- read_alchemer_translation(file_path)
      
      # Extract questions
      questions <- extract_questions_from_translation(raw_data)
      
      # Handle grid questions (expand to individual rows)
      questions <- expand_grid_questions(questions)
      
      # Map Alchemer types to TURAS types
      questions <- map_alchemer_types(questions)
      
      # Extract options
      questions$options <- extract_options_from_translation(raw_data, questions)
      
      # Set confidence (translation exports are highly reliable)
      questions$confidence <- "high"
      questions$source <- "alchemer_translation"
      
      return(list(
        questions = questions,
        metadata = list(
          platform = "Alchemer",
          file_type = tools::file_ext(file_path),
          parsed_at = Sys.time(),
          parser_version = "2.0.0"
        )
      ))
    },
    
    can_parse = function(file_path) {
      # Check if file looks like Alchemer translation export
      is_alchemer_translation(file_path)
    }
  )
)
```

#### `translation_reader.R` - Translation File Reader
```r
#' Read Alchemer Translation Export
#' 
#' Handles both CSV and Excel formats
#' Auto-detects structure and columns
#' 
read_alchemer_translation <- function(file_path) {
  
  file_ext <- tools::file_ext(file_path)
  
  # Read file
  raw_data <- switch(file_ext,
    "csv" = readr::read_csv(file_path, col_types = readr::cols(.default = "c")),
    "xlsx" = readxl::read_excel(file_path),
    "xls" = readxl::read_excel(file_path),
    stop("Unsupported translation file format: ", file_ext)
  )
  
  # Validate expected columns exist
  required_cols <- c("question_id", "question_text", "question_type")
  validate_translation_structure(raw_data, required_cols)
  
  return(raw_data)
}

#' Detect Alchemer Translation File
#' 
#' Check if file matches Alchemer translation export structure
#' 
is_alchemer_translation <- function(file_path) {
  
  if (!file.exists(file_path)) return(FALSE)
  
  # Try to read first few rows
  tryCatch({
    sample <- readr::read_csv(file_path, n_max = 5, show_col_types = FALSE)
    
    # Check for Alchemer-specific column patterns
    col_names <- tolower(names(sample))
    has_question_cols <- any(grepl("question.*id", col_names)) &&
                        any(grepl("question.*text", col_names))
    
    return(has_question_cols)
    
  }, error = function(e) {
    return(FALSE)
  })
}
```

#### `grid_expander.R` - Grid Question Expander
```r
#' Expand Grid Questions to Individual Rows
#' 
#' Alchemer grids are stored as single questions with rows/columns
#' TURAS needs each grid row as a separate question
#' 
#' @param questions Data frame of questions
#' @return Expanded data frame with grid rows as questions
#' 
expand_grid_questions <- function(questions) {
  
  expanded_list <- list()
  
  for (i in seq_len(nrow(questions))) {
    
    if (is_grid_question(questions[i, ])) {
      
      # Extract grid structure
      grid_info <- parse_grid_structure(questions[i, ])
      
      # Create one question per grid row
      for (row_idx in seq_along(grid_info$rows)) {
        
        row_question <- create_grid_row_question(
          base_question = questions[i, ],
          row_info = grid_info$rows[[row_idx]],
          row_index = row_idx,
          columns = grid_info$columns
        )
        
        expanded_list[[length(expanded_list) + 1]] <- row_question
      }
      
    } else {
      # Not a grid - keep as-is
      expanded_list[[length(expanded_list) + 1]] <- questions[i, ]
    }
  }
  
  return(dplyr::bind_rows(expanded_list))
}

#' Create Question from Grid Row
#' 
#' Converts a grid row into a standard question format
#' 
create_grid_row_question <- function(base_question, row_info, row_index, columns) {
  
  # Determine question type based on grid type
  question_type <- if (base_question$grid_type == "radio") {
    "Single_Response"
  } else if (base_question$grid_type == "checkbox") {
    "Multi_Mention"
  } else {
    "Single_Response"  # Default
  }
  
  # Create question code: Q5_r1, Q5_r2, etc.
  question_code <- paste0(base_question$code, "_r", row_index)
  
  # Build question
  list(
    code = question_code,
    text = row_info$text,
    type = question_type,
    columns = if (question_type == "Multi_Mention") length(columns) else NA,
    grid_parent = base_question$code,
    grid_row_index = row_index,
    options = list(columns),  # Grid columns become options
    confidence = "high",
    needs_review = FALSE
  )
}
```

### 3.3 Data Header Parser

#### `data_header_parser.R` - Data Header Parser
```r
#' Data Header Parser
#' 
#' Extracts question structure from data export column headers
#' Used for validation and gap-filling
#' 
DataHeaderParser <- R6::R6Class("DataHeaderParser",
  inherit = BaseParser,
  
  public = list(
    
    parse = function(file_path) {
      
      # Read just the headers
      headers <- read_data_headers(file_path)
      
      # Analyze header patterns
      questions <- analyze_header_patterns(headers)
      
      # Set lower confidence (headers give structure but not text)
      questions$confidence <- "medium"
      questions$source <- "data_headers"
      questions$needs_review <- TRUE  # Needs text from other source
      
      return(list(
        questions = questions,
        metadata = list(
          platform = "Unknown",
          file_type = tools::file_ext(file_path),
          parsed_at = Sys.time(),
          parser_version = "2.0.0"
        )
      ))
    }
  )
)

#' Analyze Column Header Patterns
#' 
#' Detect question structure from header naming patterns
#' 
#' Examples:
#' - Q1, Q2, Q3 → Simple questions
#' - Q5_1, Q5_2, Q5_3 → Multi_Mention with 3 columns
#' - Q10_r1_c1, Q10_r1_c2, Q10_r2_c1 → Grid (2 rows, 2 cols)
#' - Q15_Rank1, Q15_Rank2, Q15_Rank3 → Ranking (3 positions)
#' 
analyze_header_patterns <- function(headers) {
  
  # Group headers by base question code
  header_groups <- group_headers_by_question(headers)
  
  questions_list <- list()
  
  for (base_code in names(header_groups)) {
    
    cols <- header_groups[[base_code]]
    
    # Detect question type from pattern
    type_info <- detect_type_from_headers(base_code, cols)
    
    questions_list[[length(questions_list) + 1]] <- list(
      code = base_code,
      text = NA_character_,  # Not available from headers
      type = type_info$type,
      columns = type_info$columns,
      data_columns = cols,  # Store actual column names
      confidence = "medium",
      needs_review = TRUE
    )
  }
  
  return(dplyr::bind_rows(questions_list))
}
```

### 3.4 Enhanced UI Components

#### Updated `shiny_app.R`
```r
# NEW UI Section: Multi-Source Upload

shiny::div(
  class = "card",
  shiny::h3("1. Select Input Files"),
  
  shiny::tabsetPanel(
    id = "input_mode",
    type = "pills",
    
    # Tab 1: Single Source (Simple mode)
    shiny::tabPanel(
      "Single File",
      value = "single",
      
      shiny::br(),
      shiny::radioButtons(
        "file_type",
        "File Type",
        choices = c(
          "Word Document (.docx)" = "docx",
          "Alchemer Translation" = "alchemer_trans",
          "Data Export Headers" = "data"
        ),
        selected = "alchemer_trans"
      ),
      
      shiny::fileInput(
        "single_file",
        "Choose file",
        accept = c(".docx", ".csv", ".xlsx", ".xls")
      )
    ),
    
    # Tab 2: Multiple Sources (Advanced mode)
    shiny::tabPanel(
      "Multiple Files (Recommended)",
      value = "multi",
      
      shiny::br(),
      shiny::p("Upload multiple files for best results. The parser will automatically merge them."),
      
      shiny::fileInput(
        "translation_file",
        "Alchemer Translation (Primary source)",
        accept = c(".csv", ".xlsx")
      ),
      
      shiny::fileInput(
        "data_file",
        "Data Export (Validation)",
        accept = c(".csv", ".xlsx", ".sav")
      ),
      
      shiny::fileInput(
        "word_file",
        "Word Document (Optional)",
        accept = c(".docx")
      ),
      
      shiny::selectInput(
        "merge_strategy",
        "Merge Strategy",
        choices = c(
          "Best Quality (Recommended)" = "best",
          "Priority Order" = "priority",
          "Consensus Only" = "consensus"
        ),
        selected = "best"
      )
    )
  )
)
```

---

## 4. Implementation Plan

### Phase 1: Foundation (Week 1-2)
**Goal:** Set up architecture without breaking existing functionality

1. **Refactor existing code** (2 days)
   - Move existing parsers to new directory structure
   - Wrap DOCX parser in new interface
   - Update imports in `run_parser.R`
   - Run tests to ensure nothing broke

2. **Create core interfaces** (2 days)
   - `parser_interface.R` - Base class definition
   - `parser_factory.R` - Factory pattern
   - `platform_detector.R` - File type detection
   - Write unit tests

3. **Update Shiny UI** (1 day)
   - Add file type selector
   - Keep existing functionality working
   - Add placeholder for multi-source

### Phase 2: Alchemer Parser (Week 3-4)
**Goal:** Implement high-quality Alchemer translation parser

1. **Translation reader** (2 days)
   - CSV/Excel reading
   - Structure validation
   - Auto-detection logic

2. **Grid expander** (3 days)
   - Parse grid structure from translation
   - Expand to individual questions
   - Handle radio vs checkbox grids
   - Edge case testing

3. **Type mapper** (1 day)
   - Map Alchemer types to TURAS types
   - Handle special cases (NPS, ranking, etc.)

4. **Integration** (2 days)
   - Connect to UI
   - End-to-end testing
   - Documentation

### Phase 3: Data Header Parser (Week 5)
**Goal:** Add validation/gap-filling from data exports

1. **Header analyzer** (2 days)
   - Pattern detection
   - Column grouping
   - Type inference from patterns

2. **Integration** (1 day)
   - Add to parser factory
   - UI updates

### Phase 4: Multi-Source Orchestrator (Week 6)
**Goal:** Intelligently merge multiple sources

1. **Merge strategies** (3 days)
   - Best quality algorithm
   - Priority-based merge
   - Consensus validation

2. **Question matcher** (2 days)
   - Match questions across sources
   - Handle code mismatches
   - Fuzzy text matching

3. **UI completion** (2 days)
   - Multi-file upload
   - Source priority settings
   - Merge strategy selector

### Phase 5: Testing & Documentation (Week 7)
**Goal:** Production-ready release

1. **Testing** (3 days)
   - Unit tests for all new components
   - Integration tests
   - Real-world survey testing
   - Performance benchmarking

2. **Documentation** (2 days)
   - Architecture guide
   - User guide update
   - "Adding New Platform" tutorial
   - Code comments

3. **Migration guide** (1 day)
   - V1 to V2 upgrade steps
   - Breaking changes list
   - Backward compatibility notes

### Phase 6: Future Extensibility (Week 8+)
**Goal:** Make it easy to add new platforms

1. **Platform template** (1 day)
   - Template parser class
   - Checklist for new platforms

2. **Qualtrics parser** (Future - as needed)
   - QSF file parser
   - Type mapping

3. **SurveyMonkey parser** (Future - as needed)
   - CSV export parser

---

## 5. Technical Specifications

### 5.1 File Format Support

#### Alchemer Translation Export
**Format:** CSV or Excel  
**Detection criteria:**
- Contains columns: `question_id`, `question_text`, `question_type`
- May contain: `answer_id`, `answer_text`, `grid_row`, `grid_column`

**Question type mapping:**
```r
alchemer_to_turas_types <- c(
  "radio" = "Single_Response",
  "checkbox" = "Multi_Mention",
  "textbox" = "Open_End",
  "essay" = "Open_End",
  "numeric" = "Numeric",
  "radio_grid" = "Single_Response",  # Expanded to rows
  "checkbox_grid" = "Multi_Mention", # Expanded to rows
  "nps" = "NPS",
  "rating" = "Rating",
  "rank" = "Ranking"
)
```

#### Data Export Headers
**Format:** CSV, Excel, or SPSS (.sav)  
**Detection patterns:**
```r
# Multi-mention: Q5_1, Q5_2, Q5_3
# Grid: Q10_r1_c1, Q10_r2_c2
# Ranking: Q15_Rank1, Q15_Rank2
```

### 5.2 Data Structures

#### Standard Question Structure
```r
question <- list(
  code = "Q5",
  text = "How satisfied were you with [COMPANY_NAME]?",
  type = "Single_Response",
  columns = NA,
  options = list(
    data.frame(
      OptionText = c("Very satisfied", "Satisfied", ...),
      DisplayText = c("Very satisfied", "Satisfied", ...),
      DisplayOrder = c(1, 2, ...)
    )
  ),
  metadata = list(
    grid_parent = NA,
    grid_row_index = NA,
    piped_from = c("COMPANY_NAME" = "Q1"),
    platform_type = "radio",
    platform_id = "12345"
  ),
  confidence = "high",
  needs_review = FALSE,
  source = "alchemer_translation"
)
```

### 5.3 Performance Requirements

- **Parse time:** <5 seconds for surveys with 50 questions
- **Memory:** <100MB for typical survey (500 questions)
- **File size support:** Up to 10MB input files
- **Grid expansion:** Handle grids up to 20 rows × 20 columns

### 5.4 Error Handling

```r
# Graceful degradation hierarchy:
1. Try primary source (e.g., Alchemer translation)
2. If fails, try secondary source (data headers)
3. If fails, try tertiary source (Word doc)
4. If all fail, provide clear error message

# Partial success handling:
- Some questions parsed successfully → Proceed with warnings
- Flag unparsed questions for review
- Generate partial output with clear indicators
```

---

## 6. Testing Strategy

### 6.1 Unit Tests
- Each parser component tested independently
- Mock file inputs
- Edge cases: empty files, malformed data, special characters
- Grid expansion edge cases

### 6.2 Integration Tests
- Multi-source merge scenarios
- Real Alchemer export files
- Real survey data files
- Word documents (existing test suite)

### 6.3 User Acceptance Tests
- Parse real client surveys
- Compare output to manual setup
- Performance benchmarks
- UI usability testing

### 6.4 Test Data Requirements
Collect sample files:
- 5 Alchemer translation exports (various question types)
- 5 data exports matching the translations
- 5 Word documents matching the translations
- Edge cases: very large surveys, grids, ranking, piping

---

## 7. Migration & Backward Compatibility

### 7.1 Backward Compatibility
- **Existing Word parsing:** Fully preserved, no breaking changes
- **API:** DocxParser maintains same interface as v1
- **Output format:** Survey_Structure.xlsx format unchanged
- **Configuration:** Existing config parameters still work

### 7.2 Migration Path
Users can:
1. Continue using v1 (Word only) - no changes needed
2. Opt into v2 features gradually
3. Use multi-source for new projects only

### 7.3 Deprecation Timeline
- V1 parser: Maintained indefinitely (low complexity)
- V2 becomes default in UI
- Word-only option always available

---

## 8. Future Extensibility

### 8.1 Adding New Platforms

**Template for new parser:**
```r
# 1. Create parser class
NewPlatformParser <- R6::R6Class("NewPlatformParser",
  inherit = BaseParser,
  public = list(
    parse = function(file_path) {
      # Implementation
    },
    can_parse = function(file_path) {
      # Detection logic
    }
  )
)

# 2. Add to factory
# 3. Add type mapping
# 4. Add detection logic
# 5. Write tests
# 6. Update documentation
```

### 8.2 Planned Platform Support

**Priority 1 (2025):**
- Alchemer ✓ (included in v2.0)
- Qualtrics (QSF export)

**Priority 2 (2026):**
- SurveyMonkey (CSV export)
- Google Forms (CSV export)

**Priority 3 (Future):**
- Typeform
- Forsta (Confirmit)
- Decipher

---

## 9. Success Criteria

### 9.1 Functional Requirements ✓
- [ ] Parse Alchemer translations with 95%+ accuracy
- [ ] Handle radio grids and checkbox grids correctly
- [ ] Preserve piped question placeholders
- [ ] Merge multiple sources intelligently
- [ ] Maintain backward compatibility with Word parsing

### 9.2 Quality Requirements ✓
- [ ] 80%+ code coverage with unit tests
- [ ] Zero breaking changes to existing Word parser
- [ ] Documentation complete and clear
- [ ] Performance: <5s for 50-question survey

### 9.3 User Experience ✓
- [ ] Single-file upload works (simple mode)
- [ ] Multi-file upload works (advanced mode)
- [ ] Clear error messages when parsing fails
- [ ] Helpful warnings for needs_review flags
- [ ] Easy to understand which source was used

---

## 10. Risks & Mitigation

### Risk 1: Platform Export Format Changes
**Impact:** High  
**Probability:** Medium  
**Mitigation:**
- Version detection in platform files
- Graceful degradation
- Clear error messages pointing to format issue
- Maintain parser for older formats

### Risk 2: Complex Grid Structures
**Impact:** Medium  
**Probability:** High  
**Mitigation:**
- Extensive testing with real surveys
- Manual review flags for complex grids
- Fallback to "needs review" rather than failing

### Risk 3: Merge Conflicts
**Impact:** Medium  
**Probability:** Medium  
**Mitigation:**
- Clear merge strategy selection
- Show source conflicts in UI
- Allow manual resolution

### Risk 4: Performance with Large Surveys
**Impact:** Low  
**Probability:** Low  
**Mitigation:**
- Streaming CSV reading for large files
- Progress indicators in UI
- Optimization if needed

---

## 11. Deliverables

### Code
1. ✓ All new parser modules
2. ✓ Enhanced Shiny UI
3. ✓ Updated orchestrator
4. ✓ Comprehensive test suite

### Documentation
1. ✓ Architecture documentation
2. ✓ User guide update
3. ✓ "Adding New Platform" tutorial
4. ✓ Code comments and roxygen docs

### Testing
1. ✓ Unit test suite
2. ✓ Integration test suite
3. ✓ Test data collection
4. ✓ Performance benchmarks

---

## 12. Timeline Summary

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Foundation | 2 weeks | Refactored architecture |
| Alchemer Parser | 2 weeks | Working Alchemer support |
| Data Parser | 1 week | Header validation |
| Multi-Source | 1 week | Intelligent merging |
| Testing & Docs | 1 week | Production-ready |
| **Total** | **7 weeks** | **V2.0 Release** |

---

## 13. Questions for Decision

1. **Priority:** Should we implement Qualtrics support in v2.0 or defer to v2.1?
2. **UI:** Separate app for multi-source or integrate into existing parser?
3. **Defaults:** Should multi-source be the default mode in UI?
4. **Grid naming:** Preference for grid row codes (Q5_r1 vs Q5_1)?
5. **Testing:** Which client surveys can we use for testing?

---

## Appendix A: Example Workflows

### Workflow 1: Alchemer Translation Only
```
User uploads: survey_translation.csv
↓
Platform detected: Alchemer
↓
Parse translation → Expand grids → Map types
↓
Output: Survey_Structure.xlsx (high confidence)
```

### Workflow 2: Multi-Source (Best Quality)
```
User uploads:
  - translation.csv (Alchemer)
  - data_export.xlsx (Column headers)
  - questionnaire.docx (Word)
↓
Parse all three sources
↓
Merge strategy: "best"
  - Use translation for structure (high confidence)
  - Validate columns with data headers
  - Fill text gaps with Word doc
↓
Output: Survey_Structure.xlsx (verified)
```

### Workflow 3: Data Headers Only (Validation Mode)
```
User uploads: survey_data.xlsx
↓
Parse column headers
↓
Infer question structure
↓
Output: Survey_Structure.xlsx
  - All questions marked "needs_review"
  - QuestionText fields empty
  - User must fill in text manually
```

---

## Appendix B: Code Samples

See implementation files for:
- `parser_interface.R` - Base class definition
- `alchemer_parser.R` - Full Alchemer implementation
- `grid_expander.R` - Grid expansion logic
- `multi_source_orchestrator.R` - Merge strategies

---

**Document Version:** 1.0  
**Last Updated:** November 17, 2025  
**Next Review:** Start of Phase 1 implementation

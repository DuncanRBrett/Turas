# TURAS 100/100 Product Specification

**Version:** 1.0
**Date:** 2025-12-31
**Author:** Claude Code (based on comprehensive interview with Duncan Brett)
**Current Status:** 85/100 → Target: 100/100
**Timeline:** 12-month roadmap to production excellence

---

## Executive Summary

This specification defines the path to transform TURAS from its current production-ready state (85/100) to a best-in-class market research analytics platform (100/100). The roadmap prioritizes statistical rigor, performance optimization, output quality, and service deployment readiness while maintaining the core philosophy of quality over speed.

**Strategic Context:**
- **Deployment Model:** Solo practitioner offering analytics as a service
- **Collaboration:** 2-3 person in-house team (Duncan + assistant) with lock-based editing
- **Client Access:** Send raw data → receive outputs and validation packs (no client platform access)
- **Infrastructure:** iMac 2017 (16GB RAM) - will upgrade if work flows, but optimize for current hardware
- **Revenue Model:** Flat fee per module (possibly per-analysis pricing) with cost estimators

**Key Differentiators:**
- Statistical validation at the core (transparent, rigorous, academically grounded)
- **Local AI-powered intelligence** (no client data leaves system - MUST HAVE)
- Clear PASS/PARTIAL/REFUSED status with degradation reporting
- AI-enhanced interpretation and executive summaries (local processing only)
- "What can I do with this data?" intelligent module recommendations
- Automated data quality detection as preprocessing module (prioritized as "fantastic feature")

**Design Philosophy (From Duncan):**
- **Not a service at present** - Duncan operates TURAS himself, may offer functionality as service later
- **First-time UX not priority** - Rely on manuals to explain module configuration
- **Statistical validation is the heart** - Not sure where to get benchmark data, but method disagreement flagging is validation pack priority
- **Local AI is MUST HAVE** - AI-level intelligence for interpretation/summaries, but absolutely no client data to external cloud platforms
- **Wizard modes deferred** - Configuration validation is important; wizard/expert toggle is future feature
- **Output interpretation is key** - AI-enhanced automated suggestions, clear indicators, plain-English reasons for PARTIAL, intelligent executive summaries
- **Expansion plans uncertain** - Needs to run for a while first; hybrid R/Python/web frontend likely long-term; no user script injection
- **Support via outputs only** - Self-healing will be great; support based on outputs, not live debugging
- **Quality over timing** - Avoid absolute deadlines; prefer concrete steps without time estimates

---

## 1. Critical Path to 100/100

### 1.1 Quality Pillars (Must-Have for 100/100)

#### **Pillar 1: Statistical Validation & Transparency (Score Impact: +5)**

**Current State:** Methods are sound but validation infrastructure incomplete
**Target State:** Bulletproof statistical validation with public benchmarks

**Implementation:**

1. **Validation Pack System**
   - Every module generates a validation pack alongside results
   - Contents:
     - Statistical assumptions checks (normality, homoscedasticity, etc.)
     - Diagnostic plots (residuals, Q-Q plots, influence diagnostics)
     - **Method comparison matrix (when multiple methods used) - PRIORITY**
     - Degradation report (why PARTIAL status if applicable)
     - Benchmark comparisons (vs published datasets where available)
   - Format: Separate Excel workbook + PDF report
   - **Duncan's Input:** Statistical validation is at the heart of TURAS. Not sure where to get benchmark data from evolving AI tools and platforms, but method disagreement warning should be flagged as part of validation pack.

2. **Benchmark Dataset Library** *(Aspirational - source TBD)*
   ```
   modules/shared/benchmarks/
   ├── conjoint_sawtooth_benchmark.rds     # Source: Academic papers, textbooks
   ├── maxdiff_academic_reference.rds      # Source: Published examples
   ├── catdriver_hosmer_lemeshow.rds       # Source: Statistical textbooks
   └── README.md (documents expected results and sources)
   ```
   - Automated tests run against these on every module execution
   - Regression tests ensure statistical accuracy maintained across versions
   - Test tolerance: ±0.001 for coefficients, ±0.01 for p-values
   - **Duncan's Input:** Benchmark data sources uncertain - research needed for where to obtain validation datasets

3. **Method Disagreement Detection** *(HIGH PRIORITY)*
   - For KeyDriver: Flag when correlation between importance methods < 0.7
   - Warning message: "Standardized coefficients and Shapley values moderately disagree (r=0.65). Check multicollinearity (VIF > 5 detected for X, Y). See validation pack Section 4."
   - Automatic VIF calculation and reporting
   - Condition number checks for matrix stability
   - **Duncan's Input:** This IS the validation - when methods disagree, flag it. This serves as cross-validation even without external benchmarks.

4. **Transparent Method Documentation**
   - Auto-generated methods section in outputs
   - Example: "Categorical driver analysis conducted using ordinal logistic regression (MASS::polr). Proportional odds assumption tested via Brant test (p=0.23, assumption holds). No separation detected. Model converged in 8 iterations."

#### **Pillar 2: Test Coverage & Quality Assurance (Score Impact: +3)**

**Current State:** 60% coverage, inconsistent across modules
**Target State:** 90%+ coverage with automated regression testing

**Implementation:**

1. **Synthetic Data Generator Framework** *(Duncan: "Great idea")*
   ```r
   # modules/shared/test_data/synthetic_generator.R
   generate_survey_data <- function(
     n_respondents = 1000,
     n_questions = 50,
     question_types = c("single", "multi", "numeric", "ranking"),
     correlations = NULL,  # Specify known relationships
     missing_rate = 0.02,
     seed = 123
   ) {
     # Returns list with:
     # - data: survey responses
     # - ground_truth: known parameters (for validation)
     # - config: TURAS-compatible config files
   }
   ```
   - Each module has dedicated generator preserving statistical properties
   - Ground truth parameters allow validation (e.g., "generated correlation = 0.6, TURAS should recover ~0.6")
   - **Duncan's Input:** Synthetic data generators are a great idea for testing without needing external benchmark sources

2. **Golden File Regression Tests**
   - Separate tests for **data content** vs **presentation**
   - Data content: Strict comparison (max tolerance ±0.001)
   - Presentation: Visual regression optional (not blocking)
   - Golden files stored in Git LFS (large Excel files)
   - **Duncan's Input:** Intentional statistical improvements should be adopted but package must be transparent - just flag if styling changes. Main concern is tests on data and statistical quality - style/formatting reporting quality is more pressing than presentation layer (but priority is improving reporting quality and presentation).

3. **Module Test Structure (Standardized)**
   ```
   modules/{module}/tests/
   ├── testthat/
   │   ├── test_01_core_functionality.R    # Happy path
   │   ├── test_02_edge_cases.R             # Boundaries, NAs, empty
   │   ├── test_03_trs_refusals.R           # Error handling
   │   ├── test_04_statistical_accuracy.R   # Benchmark validation
   │   ├── test_05_performance.R            # Speed/memory benchmarks
   │   └── test_06_golden_regression.R      # Output stability
   ├── fixtures/
   │   ├── synthetic_data/
   │   └── golden_outputs/
   └── README.md
   ```

4. **Automated Test Execution**
   - Pre-commit hook: Run tests for modified modules
   - Nightly: Full regression suite across all modules
   - Memory profiling: Flag if module exceeds 8GB RAM (half of available)

#### **Pillar 3: Performance & Scalability (Score Impact: +3)**

**Current State:** Works but no optimization, benchmarking, or memory management
**Target State:** Fast as possible on iMac 2017, graceful handling of memory constraints

**Implementation:**

1. **Automatic Memory Optimization**
   ```r
   # modules/shared/memory/memory_manager.R
   estimate_memory_needed <- function(data, operation) {
     # Estimates RAM required before starting
     # Returns list(estimated_mb, safe_to_proceed, recommendation)
   }

   optimize_processing_strategy <- function(data, available_ram) {
     # Returns: "in_memory" | "chunked" | "incremental_output"
   }
   ```
   - Check available RAM before operations: `mem_available <- (mem_max - mem_used) * 0.8`
   - Warn user if operation likely to exceed: "Analysis estimated to need 12GB, you have 9GB available. Recommend chunking."
   - Auto-select chunking for tabs module if >300 questions

2. **Incremental Output Generation**
   - For tabs module: Write Excel sheets progressively (not all in memory)
   - For bootstrap CI: Write iterations to disk, aggregate at end
   - For large HB estimation: Stream MCMC samples to disk

3. **Performance Monitoring UI**
   ```
   ┌─ Resource Monitor ─────────────┐
   │ Memory: ████████░░ 12.8/16 GB │
   │ CPU:    ██████████ 89%        │
   │ Time:   00:04:32 / ~00:08:00  │
   └────────────────────────────────┘
   ```
   - Real-time display during long operations
   - Memory usage graph over time
   - Automatic `gc()` when memory exceeds 80%

4. **Performance Benchmarks (Per Module)**
   ```
   # Performance targets (iMac 2017, 16GB RAM):
   # Duncan's Input: Currently running on iMac 2017 with 16GB RAM.
   # Would like to be as fast as possible. Not often past medium studies
   # but need to be as fast as possible.

   Small study (n=100, 20 questions):
   - tabs: <10 seconds (target: as fast as possible)
   - confidence: <30 seconds (with bootstrap)
   - keydriver: <20 seconds

   Medium study (n=1000, 100 questions):
   - tabs: <2 minutes (priority: optimize this)
   - confidence: <5 minutes
   - conjoint: <3 minutes (aggregate logit)

   Large study (n=5000, 500 questions):
   - tabs: <15 minutes (with chunking)
   - confidence: <20 minutes
   - tracker: <10 minutes (incremental)
   ```
   - Automated performance tests flag regressions (>20% slowdown)
   - **Duncan's Input:** If work starts to flow will upgrade machine, but in meantime implement automatic memory optimization. If needed would favor incremental output.

5. **Progress Bar Architecture**
   ```r
   # Stage-based progress with time estimates
   # Duncan's Input: Think batch processing is fine. Cancellable should
   # be an option. A job queue system would be ideal - allowing multiple
   # analysis and managing of queue - but that is down the line.

   progress <- TurasProgress$new(
     stages = c(
       "Validating inputs" = 5,
       "Processing data" = 30,
       "Running bootstrap (1000 iterations)" = 60,
       "Generating outputs" = 5
     )
   )

   progress$update("Processing data", percent = 45,
                   message = "Calculating crosstabs (23/100)")
   ```
   - Shows current stage, overall progress, time estimate (doesn't have to be super accurate - sufficient is fine)
   - **Cancellable option** (Duncan: should be an option)
   - **Job queue system** (Duncan: would be ideal for managing multiple analyses - down the line)
   - Background processing with notification on completion

#### **Pillar 4: Output Quality & Interpretation (Score Impact: +3)**

**Current State:** Excel outputs are functional but lack interpretation aids
**Target State:** Publication-ready outputs with AI-enhanced insights and executive summaries

**Note:** This pillar now focuses on output infrastructure; AI intelligence moved to Pillar 5 (MUST HAVE)

**Implementation:**

1. **PARTIAL Status Report Card** *(HIGH PRIORITY - Duncan: "Ideal addition")*
   ```
   ┌─ ANALYSIS STATUS: PARTIAL ─────────────────────────────────┐
   │                                                             │
   │ Overall Reliability: 78% (ACCEPTABLE WITH CAUTION)         │
   │                                                             │
   │ ✓ Core analysis completed successfully                     │
   │ ⚠ Bootstrap confidence intervals failed (n too small)      │
   │   → Used normal approximation instead (less accurate)      │
   │   → Impact: CI width may be 5-10% understated             │
   │   → Recommendation: Add 50+ responses for stability        │
   │                                                             │
   │ ⚠ SHAP analysis degraded (xgboost convergence warning)     │
   │   → Falling back to Shapley values only                    │
   │   → Impact: Non-linear effects not captured                │
   │   → Recommendation: Check for outliers in predictors       │
   │                                                             │
   │ Degradation Category: STATISTICAL_ASSUMPTION_VIOLATED      │
   │ User Action Required: REVIEW_BEFORE_INTERPRETATION         │
   │                                                             │
   │ See validation pack Section 3 for detailed diagnostics.    │
   └─────────────────────────────────────────────────────────────┘
   ```
   - Included as first sheet in Excel output
   - **Plain-English explanations** of each degradation (Duncan: needs clear descriptor of why partial and what the implication is)
   - **Form of degradation described** (Duncan: some form of degradation scale)
   - **Impact communicated** with appropriate warning of issue, risk and implications
   - Severity scoring concept: Duncan anticipates user-configured with appropriate warning
   - **Duncan's Input:** Don't think results need to be visually distinguished, but a partial report card is an ideal addition. Clear indicators, plain-English reasons, implications - these are key.

2. **PARTIAL Status Interpretation** *(Infrastructure for AI in Pillar 5)*
   - Structured data format for AI to interpret
   - Clear categorization of degradation types
   - Severity scoring data
   - **AI generates plain-English explanations** (see Pillar 5)

3. **Interactive Web Outputs** *(Duncan: "Would like to explore")*
   - HTML dashboards with embedded Plotly charts
   - Sortable/filterable tables
   - Export to PowerPoint with one click (Duncan: "Expanding outputs to interactive web outputs, powerpoint presentations")
   - Branded templates (client logo, colors) with options for clients to brand and customize color schemes
   - **Reproducibility features:**
     - Auto-generated methods section (text description of analysis) - Duncan: "would be a nice to have feature"
     - Embedded metadata (TURAS version, modules used, parameters)
     - "Rerun this analysis" button (restores exact configuration) - Duncan: "would be a nice to have feature"

#### **Pillar 5: Local AI Intelligence (Score Impact: +4) - MUST HAVE**

**Duncan's Mandate:** "I would like to move AI level intelligence up in importance to be a must have - but without uploading client data to any external cloud platform"

**Current State:** Template-based interpretation, no AI
**Target State:** AI-level intelligence running 100% locally on Duncan's machine

**Implementation Strategy:**

**1. Local LLM Selection & Deployment**

```r
# modules/shared/ai/local_llm_manager.R
# Architecture: Run open-source LLMs locally via Ollama or llama.cpp

# Options evaluated:
# 1. Ollama (easiest - RESTful API to local models)
# 2. llama.cpp (direct C++ integration via Rcpp)
# 3. R-specific packages (text, etc.)

initialize_local_ai <- function(model_name = "llama3.1:8b") {
  # Check if Ollama is running locally
  if (!check_ollama_available()) {
    return(list(
      status = "REFUSED",
      code = "AI_UNAVAILABLE",
      message = "Local AI not available. Install Ollama and download model.",
      how_to_fix = "1. Install Ollama from https://ollama.ai\n2. Run: ollama pull llama3.1:8b\n3. Ensure Ollama is running (ollama serve)"
    ))
  }

  # Test model availability
  test_result <- query_local_llm(
    prompt = "Test: respond with 'OK'",
    model = model_name,
    max_tokens = 5
  )

  if (test_result$status == "PASS") {
    return(list(
      status = "PASS",
      model = model_name,
      endpoint = "http://localhost:11434"
    ))
  }
}

query_local_llm <- function(prompt, model, max_tokens = 500, temperature = 0.3) {
  # Query local Ollama instance
  # CRITICAL: No data leaves localhost

  response <- httr::POST(
    url = "http://localhost:11434/api/generate",
    body = list(
      model = model,
      prompt = prompt,
      stream = FALSE,
      options = list(
        temperature = temperature,
        num_predict = max_tokens
      )
    ),
    encode = "json"
  )

  # Parse and return
  # ... error handling ...
}
```

**Recommended Models (all run locally):**
- **Llama 3.1 8B** (Primary choice - good quality, reasonable speed on iMac)
- **Mistral 7B** (Alternative - faster, slightly lower quality)
- **Phi-3 Mini** (Fallback - very fast, lower RAM)

**Hardware Requirements:**
- iMac 2017 with 16GB RAM can run 7B-8B models
- Inference speed: ~10-30 tokens/second (acceptable for batch processing)
- RAM usage: ~6-8GB during inference (monitor with resource manager)

**2. AI-Powered Interpretation System**

```r
# modules/shared/ai/ai_interpreter.R

generate_ai_interpretation <- function(statistical_results, analysis_type) {
  # Build structured prompt with statistical results
  # AI generates plain-English interpretation

  prompt <- build_interpretation_prompt(
    results = statistical_results,
    type = analysis_type,
    expertise_level = "market_research_professional"
  )

  interpretation <- query_local_llm(
    prompt = prompt,
    model = "llama3.1:8b",
    max_tokens = 500,
    temperature = 0.2  # Lower = more consistent, factual
  )

  # Validate interpretation (sanity checks)
  validated <- validate_ai_output(
    interpretation = interpretation$response,
    source_data = statistical_results
  )

  return(validated)
}

build_interpretation_prompt <- function(results, type, expertise_level) {
  # Structured prompt engineering for consistent outputs

  base_prompt <- sprintf("
You are a market research statistician interpreting results for a client.

Analysis Type: %s

Statistical Results:
%s

Task: Provide a clear, concise interpretation suitable for %s.

Requirements:
1. Explain what the findings mean in practical terms
2. Note statistical significance AND practical importance
3. Highlight key actionable insights
4. Flag any cautions or limitations
5. Use plain English, avoid jargon

Interpretation (max 200 words):
",
    type,
    format_results_for_prompt(results),
    expertise_level
  )

  return(base_prompt)
}
```

**3. AI-Generated Executive Summaries**

```r
# modules/shared/ai/executive_summary.R

generate_executive_summary <- function(all_module_results, study_context) {
  # Duncan: "An automatic executive summary would all be key features"
  # Now AI-powered for intelligent summarization

  # Step 1: Extract key findings across all modules
  key_findings <- extract_significant_findings(all_module_results)

  # Step 2: Build context-aware prompt
  prompt <- sprintf("
You are a senior market research consultant preparing an executive summary.

Study Context:
- Client: %s
- Study Type: %s
- Sample Size: %d
- Key Research Questions: %s

Analysis Results:
%s

Task: Generate a concise executive summary for the client.

Structure:
1. Key Findings (3-5 bullet points, most important first)
2. Recommendations (prioritized action items)
3. Statistical Quality Assessment

Requirements:
- Focus on business implications, not statistics
- Prioritize by impact and actionability
- Use confident, professional tone
- Max 300 words total

Executive Summary:
",
    study_context$client_name,
    study_context$study_type,
    study_context$sample_size,
    study_context$research_questions,
    format_findings_for_summary(key_findings)
  )

  summary <- query_local_llm(
    prompt = prompt,
    model = "llama3.1:8b",
    max_tokens = 600,
    temperature = 0.3
  )

  # Add statistical metadata
  summary$statistical_quality <- assess_overall_quality(all_module_results)
  summary$generated_by <- "TURAS AI (Local - Llama 3.1 8B)"
  summary$generated_at <- Sys.time()

  return(summary)
}
```

**4. AI-Enhanced Data Quality Detection**

```r
# modules/data_quality/ai_quality_detector.R

detect_quality_issues_ai <- function(data, timing_data, open_ends) {
  # Combines rule-based detection with AI pattern recognition

  # Step 1: Rule-based detection (fast, deterministic)
  rule_based <- detect_quality_rules(data, timing_data)

  # Step 2: AI analyzes open-ended responses for bot patterns
  if (!is.null(open_ends) && nrow(open_ends) > 0) {

    prompt <- sprintf("
You are analyzing survey open-ended responses for data quality issues.

Task: Identify responses that appear to be from bots or low-quality respondents.

Indicators to look for:
- Gibberish or nonsensical text
- Copy-paste patterns across multiple responses
- Overly generic or templated answers
- Contradictory statements
- Evidence of automated generation

Sample responses (first 20):
%s

Provide:
1. Suspected bot response IDs (if any)
2. Reasoning for each flag
3. Confidence level (low/medium/high)

Analysis:
",
      format_responses_for_review(head(open_ends, 20))
    )

    ai_analysis <- query_local_llm(
      prompt = prompt,
      model = "llama3.1:8b",
      max_tokens = 400
    )

    # Parse AI findings
    ai_flags <- parse_ai_quality_flags(ai_analysis$response)

    # Combine with rule-based
    combined_results <- merge_quality_detections(rule_based, ai_flags)
  } else {
    combined_results <- rule_based
  }

  return(combined_results)
}
```

**5. AI-Powered "What Can I Do?" Recommendations**

```r
# modules/shared/recommendations/ai_recommender.R

recommend_analyses_ai <- function(data, user_goal = NULL, data_source_description = NULL) {
  # Enhanced version of rule-based recommender with AI understanding

  # Step 1: Rule-based schema analysis (fast, deterministic)
  schema_analysis <- analyze_schema(data)

  # Step 2: AI understands user goal in natural language
  if (!is.null(user_goal)) {

    prompt <- sprintf("
You are a market research methodologist helping select appropriate analyses.

Dataset characteristics:
- %d respondents
- %d variables
- Variable types: %s
- Detected question types: %s
%s

User's goal: '%s'

Task: Recommend which TURAS modules would be most appropriate and why.

Available modules:
- tabs: Cross-tabulation and significance testing
- confidence: Confidence intervals for proportions/means
- keydriver: Key driver analysis (regression-based)
- catdriver: Categorical driver analysis (logistic regression)
- conjoint: Choice-based conjoint analysis
- maxdiff: MaxDiff preference analysis
- pricing: Price sensitivity (Van Westendorp, Gabor-Granger)
- tracker: Longitudinal trend analysis
- segment: Clustering and segmentation
- weighting: Sample weighting

Provide:
1. Top 3 recommended modules (priority order)
2. Brief rationale for each (why it fits the goal)
3. Any prerequisites or data requirements

Recommendations:
",
      nrow(data),
      ncol(data),
      paste(table(sapply(data, class)), collapse = ", "),
      paste(schema_analysis$question_types, collapse = ", "),
      ifelse(is.null(data_source_description), "",
             paste("\nData source:", data_source_description)),
      user_goal
    )

    ai_recommendations <- query_local_llm(
      prompt = prompt,
      model = "llama3.1:8b",
      max_tokens = 500
    )

    # Parse AI recommendations
    parsed <- parse_ai_recommendations(ai_recommendations$response)

    # Enrich with cost estimates, technical requirements
    enriched <- enrich_recommendations(parsed, schema_analysis)

    return(enriched)
  } else {
    # Fall back to rule-based if no user goal
    return(recommend_modules(data, user_goal = NULL))
  }
}
```

**6. Local AI Infrastructure Requirements**

**Installation & Setup (One-time):**
```bash
# Install Ollama (macOS)
curl -fsSL https://ollama.com/install.sh | sh

# Download recommended model (~4.7GB)
ollama pull llama3.1:8b

# Start Ollama server (runs on http://localhost:11434)
ollama serve
```

**R Package Dependencies:**
```r
# HTTP client for Ollama API
install.packages("httr")
install.packages("jsonlite")

# Optional: Direct llama.cpp integration (more complex but faster)
# devtools::install_github("rstudio/cpp11")
```

**Resource Management:**
```r
# modules/shared/ai/resource_manager.R

manage_ai_resources <- function() {
  # Monitor RAM usage during AI inference
  # Ensure AI doesn't starve statistical computations

  current_usage <- get_memory_usage()

  if (current_usage > 0.7) {  # 70% RAM used
    # Defer AI generation until more RAM available
    return(list(
      ai_enabled = FALSE,
      reason = "Insufficient RAM (saving for statistical computations)",
      fallback = "template_based_interpretation"
    ))
  }

  return(list(ai_enabled = TRUE))
}
```

**7. Graceful Degradation**

```r
# If local AI unavailable, fall back gracefully

generate_interpretation_with_fallback <- function(results, type) {

  # Try AI first
  ai_check <- check_ai_available()

  if (ai_check$status == "PASS") {
    interpretation <- generate_ai_interpretation(results, type)
    interpretation$method <- "AI (Local Llama 3.1)"
    return(interpretation)
  } else {
    # Fallback to template-based
    interpretation <- generate_template_interpretation(results, type)
    interpretation$method <- "Template-based (AI unavailable)"
    interpretation$ai_unavailable_reason <- ai_check$message
    return(interpretation)
  }
}
```

**Implementation Priority:**

**Phase 1 (Months 1-2): Infrastructure**
- [ ] Set up Ollama on Duncan's iMac
- [ ] Download and test Llama 3.1 8B model
- [ ] Build R interface to local LLM
- [ ] Implement resource management (RAM monitoring)
- [ ] Test inference speed and quality

**Phase 2 (Months 3-4): Core AI Features**
- [ ] AI-powered interpretation for keydriver module
- [ ] AI-powered interpretation for catdriver module
- [ ] AI-enhanced PARTIAL status explanations
- [ ] Validation against template-based outputs

**Phase 3 (Months 5-6): Executive Summaries**
- [ ] Multi-module result aggregation
- [ ] Executive summary prompt engineering
- [ ] Quality validation (ensure accuracy)
- [ ] A/B testing vs template-based summaries

**Phase 4 (Months 7-8): Advanced Features**
- [ ] AI-enhanced "What can I do?" recommendations
- [ ] Open-ended response analysis for data quality
- [ ] Custom prompt templates per client type

**Success Criteria:**
- ✅ Zero client data sent to external services (all localhost)
- ✅ Interpretations match or exceed human quality (validated by Duncan)
- ✅ Performance acceptable (<30 seconds per interpretation on iMac)
- ✅ Graceful fallback if AI unavailable
- ✅ Resource usage doesn't impact statistical computations

**Cost:** $0 (all open-source, runs locally)

**Risk Mitigation:**
- Start with one module (keydriver) to prove concept
- Extensive validation before deploying to clients
- Always provide template-based fallback
- Monitor resource usage to prevent crashes
- Version control prompts (treat as code)

---

### 1.2 Service Deployment Architecture

#### **Project Structure & File Management**

**Duncan's Input:** "I'm not clear on the implications but am envisaging a projects folder on my 1drive with client name as a subfolder then project then wave as subfolders within that."

```
/Volumes/1Drive/TURAS_Projects/
├── ClientA/
│   ├── Project_BrandTracker_2025/
│   │   ├── Wave_01_Jan2025/
│   │   │   ├── raw_data/
│   │   │   │   ├── survey_export.xlsx
│   │   │   │   └── alchemer_files/
│   │   │   ├── configs/
│   │   │   │   ├── tabs_config.xlsx
│   │   │   │   ├── confidence_config.xlsx
│   │   │   │   └── templates/ (client-specific validated templates)
│   │   │   ├── outputs/
│   │   │   │   ├── tabs_results_2025-01-15.xlsx
│   │   │   │   ├── confidence_results_2025-01-15.xlsx
│   │   │   │   └── executive_summary_2025-01-15.pdf
│   │   │   ├── validation_packs/
│   │   │   │   ├── tabs_validation_2025-01-15.xlsx
│   │   │   │   └── confidence_validation_2025-01-15.pdf
│   │   │   └── analysis_log.txt (TRS refusals, warnings, metadata)
│   │   ├── Wave_02_Feb2025/
│   │   └── Wave_03_Mar2025/
│   └── Project_NewProduct_Conjoint/
├── ClientB/
└── _Templates/
    ├── validated/ (Duncan-approved templates)
    │   ├── standard_brand_tracker.rds
    │   ├── fmcg_conjoint_template.rds
    │   └── b2b_satisfaction_template.rds
    └── experimental/ (development templates)
```

**File Management Principles:**
- **Lock-based editing:** Only one person (Duncan or assistant) edits at a time (Duncan: "assume lock based editing for now")
- **Version control:** Git repo for code, NOT for client data
- **Backup strategy:** We need a backup strategy (Duncan: "We need a backup strategy")
- **Access control:** No client access - Duncan sends outputs (Duncan: "envisage only myself and possibly an assistant to have authentication for now – no client access at all")

#### **Authentication & Collaboration**

**Current Implementation (Phase 1):**
- No client platform access (Duncan runs TURAS, sends outputs)
- Duncan + assistant share local file system access
- Lock files prevent simultaneous editing: `.turas_lock` file in project directory

**Lock File System:**
```r
# modules/shared/collaboration/lock_manager.R

acquire_lock <- function(project_path, user) {
  lock_file <- file.path(project_path, ".turas_lock")

  if (file.exists(lock_file)) {
    lock_info <- readLines(lock_file)
    return(list(
      status = "REFUSED",
      code = "PROJECT_LOCKED",
      message = sprintf("Project locked by %s since %s",
                        lock_info[1], lock_info[2]),
      how_to_fix = "Wait for lock to release or contact user to unlock"
    ))
  }

  writeLines(c(user, as.character(Sys.time())), lock_file)
  return(list(status = "PASS", lock_acquired = TRUE))
}

release_lock <- function(project_path) {
  lock_file <- file.path(project_path, ".turas_lock")
  if (file.exists(lock_file)) unlink(lock_file)
}
```

**Future Expansion (Phase 2 - 2-3 person team):**
- Shared TURAS instance on local network
- Real-time lock status visible in UI
- Async workflow: Assistant prepares configs → Duncan reviews → runs analysis

#### **Cost Estimator System**

**Duncan's Input:** "Pricing will be as a service – possibly a flat fee per module – there should be cost estimators. Cost estimators for output to output and validation pack."

```r
# modules/shared/pricing/cost_estimator.R
# Duncan: Pricing model is flat fee per module (possibly per-analysis)
# Need cost estimators showing cost before running
# Separate estimators for outputs and validation packs

estimate_analysis_cost <- function(module, data, config) {
  # Base module fees (Duncan: flat fee per module):
  base_fees <- list(
    tabs = 100,
    confidence = 75,
    keydriver = 150,
    conjoint = 300,
    maxdiff = 250,
    pricing = 200,
    catdriver = 175,
    tracker = 125,
    weighting = 50,
    segment = 200,
    data_quality = 50  # Preprocessing module
  )

  # Complexity multipliers:
  complexity <- calculate_complexity(data, config)
  # - Large sample (>2000): 1.2x
  # - Many questions (>200): 1.3x
  # - Bootstrap/HB: 1.5x
  # - Multiple segments: 1.2x per segment

  base_cost <- base_fees[[module]]
  total_cost <- base_cost * complexity$multiplier

  # Add-ons:
  validation_pack_cost <- 25  # Fixed per module

  return(list(
    base_cost = base_cost,
    complexity_multiplier = complexity$multiplier,
    complexity_factors = complexity$factors,
    total_analysis_cost = total_cost,
    validation_pack_cost = validation_pack_cost,
    total_cost = total_cost + validation_pack_cost,
    estimated_runtime = estimate_runtime(module, data, config)
  ))
}
```

**UI Display (Before Running Analysis):**
```
┌─ Cost Estimate ────────────────────────────────────────────┐
│                                                            │
│ Module: Tabs (Cross-tabulation)                           │
│                                                            │
│ Base Cost:                                      $100       │
│                                                            │
│ Complexity Adjustments:                                    │
│  • Large sample (n=3,247):                +20%  $20        │
│  • Many questions (287 questions):        +30%  $30        │
│  • Multiple banner points (8 banners):    +10%  $10        │
│                                                ───────     │
│ Analysis Subtotal:                              $160       │
│ Validation Pack:                                $25        │
│                                                ───────     │
│ Total Cost:                                     $185       │
│                                                            │
│ Estimated Runtime: 8-12 minutes                            │
│                                                            │
│ [Cancel]  [Proceed with Analysis]                         │
└────────────────────────────────────────────────────────────┘
```

---

### 1.3 Data Quality & Preprocessing

#### **Automated Data Quality Detection Module**

**Priority:** HIGH (Duncan: "would be a fantastic feature and operate as a pre-processing module - if feasible this can be prioritized")

**Duncan's Input on Data Quality:**
- Very open to AI-assisted features - essential but want to avoid having to upload client data to unknown evolving AI tools and platforms
- Automated quality detection would be fantastic
- Flagging speeders, straightliners, illogical responses, bot responses
- Operate as pre-processing module (run before analysis)

**Module Structure:**
```
modules/data_quality/
├── 00_main.R               # Orchestration
├── 00_guard.R              # TRS guard layer
├── 01_detect_speeders.R    # Response time analysis
├── 02_detect_straightlining.R  # Pattern detection
├── 03_detect_bots.R        # Bot response patterns
├── 04_detect_illogical.R   # Logic violations
├── 05_detect_outliers.R    # Statistical outliers
├── 06_detect_duplicates.R  # Duplicate responses
├── 07_recommendations.R    # Flagging & recommendations
└── 99_output.R             # Quality report generation
```

**Detection Methods:**

1. **Speeders Detection**
   ```r
   detect_speeders <- function(data, timing_col, threshold_method = "median_based") {
     # Methods:
     # - median_based: Flag responses < 50% of median time
     # - percentile: Flag bottom 5% of completion times
     # - question_based: Estimate minimum time per question

     # Returns: list of speeder IDs, severity score, recommendation
   }
   ```

2. **Straightlining Detection**
   ```r
   detect_straightlining <- function(data, question_cols) {
     # Detects:
     # - Same answer across all questions
     # - Same answer within question grids
     # - Alternating patterns (1,2,1,2,1,2...)

     # Returns: severity score (0-100), flagged respondents
   }
   ```

3. **Bot Detection**
   ```r
   detect_bots <- function(data) {
     # Heuristics:
     # - Impossible completion times (<30 seconds for 20-question survey)
     # - Perfect alternating patterns
     # - Copy-paste text responses (identical across open-ends)
     # - Suspicious metadata (same IP, user agent, timestamp clustering)

     # Returns: bot_probability (0-100), evidence list
   }
   ```

4. **Illogical Responses**
   ```r
   detect_illogical <- function(data, logic_rules) {
     # Examples:
     # - Age=25 but has 30 years work experience
     # - Never purchased brand X but rates it 10/10
     # - Mutually exclusive responses (own car=No, car brand=BMW)

     # logic_rules: User-defined validation rules
     # Returns: list of violations per respondent
   }
   ```

**Output: Data Quality Report**

```
┌─ DATA QUALITY REPORT ──────────────────────────────────────┐
│                                                            │
│ Total Responses: 1,523                                     │
│ Clean Responses: 1,387 (91%)                               │
│ Flagged Responses: 136 (9%)                                │
│                                                            │
│ Quality Issues Detected:                                   │
│                                                            │
│ ⚠ SPEEDERS: 47 respondents (3.1%)                          │
│   - Median time: 8m 32s                                    │
│   - Flagged threshold: <4m 16s (50% of median)             │
│   - Recommendation: EXCLUDE from analysis                  │
│                                                            │
│ ⚠ STRAIGHTLINING: 23 respondents (1.5%)                    │
│   - High severity: 8 (same answer 90%+ of questions)       │
│   - Moderate: 15 (same answer 60-90%)                      │
│   - Recommendation: EXCLUDE high severity, REVIEW moderate │
│                                                            │
│ ⚠ SUSPICIOUS BOTS: 12 respondents (0.8%)                   │
│   - Evidence: Impossible timing + pattern matching         │
│   - Recommendation: EXCLUDE from analysis                  │
│                                                            │
│ ⚠ ILLOGICAL RESPONSES: 54 respondents (3.5%)               │
│   - Logic rule violations detected                         │
│   - Most common: Age/experience mismatch (34 cases)        │
│   - Recommendation: REVIEW case-by-case                    │
│                                                            │
│ ✓ DUPLICATES: 0 detected                                   │
│ ✓ OUTLIERS: 3 statistical outliers (within acceptable)     │
│                                                            │
│ FINAL RECOMMENDATION:                                       │
│ - Exclude 82 responses (speeders + high straightliners +   │
│   bots)                                                     │
│ - Review 69 responses (moderate flags) manually            │
│ - Final clean sample: ~1,372 respondents                   │
│                                                            │
│ [Export Flagged List]  [Export Clean Dataset]              │
└────────────────────────────────────────────────────────────┘
```

**Integration:**
- Runs automatically when data loaded (optional, can disable)
- Generates flagging column: `turas_quality_flag` (CLEAN | REVIEW | EXCLUDE)
- Exports clean dataset for downstream modules
- Validation pack includes quality report

---

### 1.4 "What Can I Do With This Data?" Intelligence

**Feature:** Module Recommendation Engine

**Duncan's Input:** "Yes 'What can I do with this data' is a great feature - both after running and as marketing packs."

**User Flow:**
1. User uploads/specifies dataset
2. TURAS analyzes schema, data characteristics
3. Suggests applicable modules with use cases
4. Can also be used for marketing (showing potential clients what TURAS can do with their data)

**Implementation:**

```r
# modules/shared/recommendations/module_recommender.R

recommend_modules <- function(data, user_goal = NULL) {

  # Analyze data structure:
  schema <- analyze_schema(data)
  # - Has outcome variable? (DV for regression)
  # - Has choice data? (conjoint/maxdiff format)
  # - Has segments? (grouping variables)
  # - Has weights? (sampling weights)
  # - Has wave/time? (longitudinal)
  # - Question types detected (single, multi, numeric, ranking)

  recommendations <- list()

  # Rule-based recommendations:

  if (schema$has_outcome && schema$has_predictors) {
    if (schema$outcome_type == "numeric") {
      recommendations$keydriver <- list(
        priority = "HIGH",
        reason = "Detected numeric outcome with predictor variables",
        use_case = "Understand which factors drive your outcome metric (satisfaction, NPS, purchase intent)",
        requirements_met = TRUE,
        estimated_cost = "$150 + validation pack",
        estimated_time = "5-10 minutes"
      )
    }

    if (schema$outcome_type == "categorical") {
      recommendations$catdriver <- list(
        priority = "HIGH",
        reason = "Detected categorical outcome (purchase decision, satisfaction level)",
        use_case = "Determine drivers of categorical outcomes using logistic regression",
        requirements_met = TRUE,
        estimated_cost = "$175 + validation pack",
        estimated_time = "8-15 minutes"
      )
    }
  }

  if (schema$has_choice_data) {
    recommendations$conjoint <- list(
      priority = "HIGH",
      reason = "Detected choice-based data structure (CBC format)",
      use_case = "Estimate part-worth utilities and simulate market share",
      requirements_met = TRUE,
      estimated_cost = "$300 + validation pack",
      estimated_time = "10-20 minutes (aggregate), 30-60 min (HB)"
    )
  }

  if (schema$has_questions) {
    recommendations$tabs <- list(
      priority = "MEDIUM",
      reason = sprintf("Detected %d survey questions", schema$n_questions),
      use_case = "Generate crosstabulation reports with significance testing",
      requirements_met = TRUE,
      estimated_cost = "$100-200 (depends on complexity)",
      estimated_time = "5-15 minutes"
    )

    recommendations$confidence <- list(
      priority = "MEDIUM",
      reason = "Can calculate confidence intervals for survey metrics",
      use_case = "Add precision estimates to proportions, means, NPS",
      requirements_met = TRUE,
      estimated_cost = "$75 + validation pack",
      estimated_time = "3-10 minutes"
    )
  }

  if (schema$has_wave_data) {
    recommendations$tracker <- list(
      priority = "HIGH",
      reason = "Detected longitudinal/wave data",
      use_case = "Analyze trends over time, wave-over-wave comparisons",
      requirements_met = TRUE,
      estimated_cost = "$125 + validation pack",
      estimated_time = "8-12 minutes"
    )
  }

  # User goal-based recommendations:
  if (!is.null(user_goal)) {
    goal_keywords <- tolower(user_goal)

    if (grepl("price|pricing|willingness.*pay|wtp", goal_keywords)) {
      recommendations$pricing <- list(
        priority = "HIGH",
        reason = "User goal mentions pricing",
        use_case = "Van Westendorp PSM or Gabor-Granger price analysis",
        requirements_met = check_pricing_requirements(schema),
        estimated_cost = "$200 + validation pack",
        estimated_time = "10-15 minutes"
      )
    }

    if (grepl("segment|cluster|group", goal_keywords)) {
      recommendations$segment <- list(
        priority = "HIGH",
        reason = "User goal mentions segmentation",
        use_case = "Cluster analysis to identify customer segments",
        requirements_met = check_segment_requirements(schema),
        estimated_cost = "$200 + validation pack",
        estimated_time = "12-20 minutes"
      )
    }
  }

  # Sort by priority and requirements_met
  recommendations <- recommendations[order(
    sapply(recommendations, function(x) x$priority),
    sapply(recommendations, function(x) !x$requirements_met)
  )]

  return(recommendations)
}
```

**UI Display:**

```
┌─ RECOMMENDED ANALYSES ─────────────────────────────────────┐
│                                                            │
│ Based on your data, TURAS recommends:                     │
│                                                            │
│ ⭐ HIGH PRIORITY                                            │
│                                                            │
│ 1. KEY DRIVER ANALYSIS                                     │
│    Why: Detected numeric outcome (NPS) with 12 drivers    │
│    Use case: Understand which factors most impact NPS     │
│    Cost: ~$150 + $25 validation pack                       │
│    Time: 5-10 minutes                                      │
│    ✓ All requirements met                                  │
│    [Run KeyDriver]  [Learn More]                           │
│                                                            │
│ 2. TRACKING ANALYSIS                                       │
│    Why: Detected 4 waves of data (Jan-Apr 2025)           │
│    Use case: Analyze trends, wave-over-wave changes       │
│    Cost: ~$125 + $25 validation pack                       │
│    Time: 8-12 minutes                                      │
│    ✓ All requirements met                                  │
│    [Run Tracker]  [Learn More]                             │
│                                                            │
│ 🔵 MEDIUM PRIORITY                                          │
│                                                            │
│ 3. CROSS-TABULATION                                        │
│    Why: 47 survey questions detected                      │
│    Use case: Standard banner point tables with sig testing│
│    Cost: ~$120 + $25 validation pack                       │
│    Time: 6-10 minutes                                      │
│    [Run Tabs]  [Learn More]                                │
│                                                            │
│ 4. CONFIDENCE INTERVALS                                    │
│    Why: Can add precision to key metrics                  │
│    Use case: Calculate CIs for proportions, means         │
│    Cost: ~$75 + $25 validation pack                        │
│    Time: 3-8 minutes                                       │
│    [Run Confidence]  [Learn More]                          │
│                                                            │
│ Not sure which to choose?                                  │
│ [Tell me your goal] (e.g., "understand price sensitivity")│
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**User Goal Input:**
```
What are you trying to understand or accomplish?

[Text box: "I want to understand price sensitivity and optimal
          pricing for our new product"]

[Analyze Goals]

→ TURAS suggests: Pricing module (Van Westendorp PSM)
→ Alternative: Conjoint analysis (if choice data available)
→ Follow-up: KeyDriver to understand what drives WTP
```

---

### 1.5 Template & Configuration System

**Duncan's Input:** "Templates should be as full as possible, MVP configuration and data schema, validated and if possible automatic upgrading. Version compatibility – if template was created for TURAS v10.1 but user has v10.3 should be automatic migration."

**Template Structure:**

```r
# Template format (saved as .rds)
# Duncan: Templates should be as full as possible - configuration AND data schema
# MVP: Configuration + data schema
# Validated templates only (Duncan-approved)
# Automatic migration between versions where possible

validated_template <- list(
  metadata = list(
    name = "Standard Brand Tracker - FMCG",
    version = "1.2",
    created_by = "Duncan Brett",
    created_date = "2025-06-15",
    turas_version_min = "10.0",
    turas_version_max = "99.0",  # Compatible with future versions
    description = "Standard configuration for FMCG brand tracking studies",
    use_case = "Quarterly brand health tracking with NPS, awareness, consideration"
  ),

  modules = list(
    data_quality = list(
      enabled = TRUE,
      speeders_threshold = "median_50pct",
      straightlining_severity = "high",
      bot_detection = TRUE
    ),

    tabs = list(
      config_file = "tabs_config.xlsx",  # Included in template
      banner_points = c("Age", "Gender", "Region", "Brand_User"),
      significance_testing = TRUE,
      sig_level = 0.05
    ),

    confidence = list(
      methods = c("wilson", "bootstrap"),
      bootstrap_iterations = 1000,
      key_metrics = c("NPS", "Awareness", "Consideration")
    ),

    keydriver = list(
      outcome_var = "NPS",
      predictor_vars = c("Quality", "Price", "Service", "Brand"),
      methods = c("standardized", "relative_weights", "shapley")
    ),

    tracker = list(
      wave_var = "Wave",
      key_metrics_to_track = c("NPS", "Awareness", "Purchase_Intent"),
      trend_analysis = TRUE,
      alert_thresholds = list(NPS = 40)  # Alert if NPS < 40
    )
  ),

  data_schema = list(
    required_columns = c("RespondentID", "Wave", "NPS", "Age", "Gender"),
    expected_types = list(
      NPS = "numeric",
      Age = "numeric",
      Gender = "factor"
    ),
    validation_rules = list(
      "NPS must be 0-10" = "NPS >= 0 & NPS <= 10",
      "Age must be 18+" = "Age >= 18"
    )
  ),

  workflow = c(
    "data_quality",  # Always run first
    "tabs",
    "confidence",
    "keydriver",
    "tracker"
  )
)
```

**Template Application:**

```r
# modules/shared/templates/template_manager.R

apply_template <- function(template_path, data_path, output_dir) {

  # 1. Load template
  template <- readRDS(template_path)

  # 2. Validate TURAS version compatibility
  current_version <- get_turas_version()
  if (current_version < template$metadata$turas_version_min ||
      current_version > template$metadata$turas_version_max) {
    return(trs_refusal(
      code = "TEMPLATE_VERSION_INCOMPATIBLE",
      message = sprintf(
        "Template requires TURAS v%s-%s, you have v%s",
        template$metadata$turas_version_min,
        template$metadata$turas_version_max,
        current_version
      ),
      how_to_fix = "Update TURAS or use compatible template version"
    ))
  }

  # 3. Validate data schema
  data <- load_data(data_path)
  schema_check <- validate_schema(data, template$data_schema)
  if (schema_check$status == "REFUSED") {
    return(schema_check)
  }

  # 4. Execute workflow
  results <- list()
  for (module_name in template$workflow) {
    cat(sprintf("\n=== Running %s ===\n", module_name))

    module_config <- template$modules[[module_name]]
    result <- run_module(module_name, data, module_config, output_dir)

    results[[module_name]] <- result

    # Stop if REFUSED (unless continue_on_error = TRUE)
    if (result$status == "REFUSED") {
      cat(sprintf("Module %s REFUSED. Stopping workflow.\n", module_name))
      break
    }
  }

  # 5. Generate summary report
  summary <- generate_workflow_summary(results, template, output_dir)

  return(list(
    status = "PASS",
    results = results,
    summary = summary
  ))
}
```

**Template Library UI:**

```
┌─ TEMPLATE LIBRARY ─────────────────────────────────────────┐
│                                                            │
│ Validated Templates (Duncan-approved)                     │
│                                                            │
│ 📊 Standard Brand Tracker - FMCG                           │
│    Modules: Data Quality, Tabs, Confidence, KeyDriver,    │
│             Tracker                                        │
│    Use case: Quarterly brand health tracking              │
│    Version: 1.2 (updated 2025-06-15)                       │
│    [Apply Template]  [View Details]  [Customize]          │
│                                                            │
│ 📊 B2B Satisfaction Study                                  │
│    Modules: Data Quality, Tabs, KeyDriver, Confidence     │
│    Use case: Annual customer satisfaction measurement     │
│    Version: 1.0                                            │
│    [Apply Template]  [View Details]  [Customize]          │
│                                                            │
│ 📊 New Product Conjoint                                    │
│    Modules: Data Quality, Conjoint, Pricing               │
│    Use case: Feature optimization and pricing             │
│    Version: 2.1                                            │
│    [Apply Template]  [View Details]  [Customize]          │
│                                                            │
│ [Create New Template]  [Import Template]                  │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 2. Module-Specific Improvements

### 2.1 Priority Module Standardization

**Modules needing structure standardization:** segment, tracker, weighting

**Priority Order (based on current usage):**
1. **weighting** (used frequently as preprocessing)
2. **tracker** (recurring client need)
3. **segment** (less frequent but important)

**Standardization Checklist (per module):**
- [ ] Move to standard directory structure (R/, tests/, etc.)
- [ ] Implement TRS guard layer (00_guard.R)
- [ ] Add comprehensive tests (target 90% coverage)
- [ ] Generate validation pack output
- [ ] Add to module recommender system
- [ ] Create validated template examples
- [ ] Performance benchmark and optimize
- [ ] Documentation (README, roxygen2, examples)

### 2.2 Segment Module Deep Dive

**Must-Have Clustering Methods:**
1. **K-means** (fast, interpretable)
2. **Hierarchical** (dendrogram, no need to pre-specify k)
3. **Latent Class** (model-based, handles mixed data types)

**Integration with Other Modules:**
```r
# After segmentation, auto-suggest:
# "3 segments identified. Run analyses by segment?"
# → Tabs per segment
# → KeyDriver per segment
# → Confidence intervals per segment

# Workflow:
segment_result <- run_segmentation(data, config)
# Returns: data with segment assignments

# Auto-generate segment profiles:
# Segment 1: "Price Sensitive" (32% of sample)
#   - Lower income, younger, high price importance
# Segment 2: "Brand Loyal" (41% of sample)
#   - Higher income, older, low price sensitivity
# Segment 3: "Undifferentiated" (27% of sample)
#   - Mixed characteristics

# Offer to run KeyDriver per segment:
for (segment in 1:3) {
  keydriver_result <- run_keydriver(
    data[segment_assignments == segment, ],
    config
  )
}
```

### 2.3 Tracker Module Enhancements

**Duncan's Input on Tracker:**
- The tracking module is still limited
- Incremental updates should be catered for - only recompute affected analyses
- Alerting and monitoring can be added in future version
- Ability to choose rolling windows vs discrete waves needed
- No current need for scheduled reports

**Incremental Update Strategy:**

```r
# modules/tracker/incremental_processing.R

process_new_wave <- function(previous_results_path, new_wave_data, config) {

  # Load previous results
  prev <- readRDS(previous_results_path)

  # Only recompute:
  # 1. New wave metrics
  # 2. Updated trends (incorporating new wave)
  # 3. Wave-over-wave comparisons (latest vs previous)

  # DO NOT recompute:
  # - Historical wave metrics (already calculated)
  # - Cross-wave statistics that don't involve new wave

  # Returns: Updated results object with new wave integrated
}
```

**Rolling Window Support:**

```r
# Config option:
tracker_config <- list(
  window_type = "rolling",  # "rolling" | "discrete_waves"
  window_size = 12,         # months
  window_unit = "months",   # "months" | "weeks" | "waves"
  always_include_latest = TRUE
)

# Example: Monthly tracker, always show last 12 months
# Jan 2025 report: Feb 2024 - Jan 2025
# Feb 2025 report: Mar 2024 - Feb 2025 (drops Feb 2024, adds Feb 2025)
```

**Alert System (Future - noted for future version):**
```r
# Future feature: Threshold-based alerts
# "NPS dropped below 40" → notification
# For now: Manual review of outputs
```

---

## 3. Strategic Design Decisions (Duncan's Input)

### 3.1 Configuration & User Experience Philosophy

**Wizard vs Expert Modes:**
- **Duncan's Decision:** Wizard vs expert modes could be a future feature - but configuration validation is important
- **Current Approach:** Rely on manuals to explain how to configure and run modules
- **First-time UX:** Not a priority at present as Duncan intends to run it as a service, but once the manuals are written to remind how to configure and run
- **Implementation:** Focus on clear configuration validation rather than guided wizards

**Configuration Validation (HIGH PRIORITY):**
```r
# modules/shared/config/config_validator.R
# Priority: Configuration validation over wizard modes

validate_config <- function(module_name, config, data_schema = NULL) {
  # Validates configuration before running analysis
  # Returns detailed errors with how to fix

  validation_results <- list()

  # 1. Required fields present
  required_fields <- get_required_fields(module_name)
  missing <- setdiff(required_fields, names(config))
  if (length(missing) > 0) {
    validation_results$missing_fields <- list(
      status = "ERROR",
      message = sprintf("Missing required fields: %s", paste(missing, collapse = ", ")),
      how_to_fix = sprintf("Add these fields to your config file: %s",
                          paste(missing, collapse = ", "))
    )
  }

  # 2. Field types correct
  # 3. Value ranges valid
  # 4. Dependencies satisfied
  # 5. Data schema compatibility (if provided)

  if (length(validation_results) == 0) {
    return(list(status = "PASS", message = "Configuration valid"))
  } else {
    return(list(
      status = "REFUSED",
      code = "CFG_INVALID",
      validation_errors = validation_results
    ))
  }
}
```

### 3.2 Statistical Methods & Fallback Strategy

**Automatic Fallbacks (Duncan: "should not be blocking but must be reported"):**
- **Philosophy:** Automatic fallbacks are good, but user confirmation not required (ideally)
- **Reporting:** Fallbacks must be reported in PARTIAL status and validation pack
- **Duncan's Input:** "Automatic fallbacks should not be blocking but must be reported - ideally user confirmation required"

**Expert Mode for Statistical Methods (FUTURE):**
- Not current priority but down the line
- Duncan is very open to it as long as it's clear what is done and can choose classical stats if preferred
- Manual selection of specific methods for advanced users
- See diagnostic plots/statistics before proceeding

### 3.3 Platform Integration Strategy

**Survey Platform Integration:**
- **Duncan's Decision:** "I do not envisage direct alchemer integration at present but do envisage data file from other platforms including SurveyMonkey, SurveyToGo etc"
- **Priority:** Converting files to reduce manual effort (not direct API integration)
- **Approach:** Generic CSV/Excel mapper rather than platform-specific integrations
- **AlchemerParser:** Keep file-based approach, expand to other export formats

**File Conversion Priority:**
```
High Priority:
1. Alchemer exports (already supported via AlchemerParser)
2. SurveyMonkey exports (CSV/Excel format)
3. SurveyToGo exports
4. Generic Excel/CSV mapper for other platforms

Future:
- Qualtrics (if demand arises)
- Platform-specific parsers as needed
```

### 3.4 AI & Machine Learning Integration - **ELEVATED TO MUST HAVE (Pillar 5)**

**Duncan's Updated Mandate:** "I would like to move AI level intelligence up in importance to be a must have - but without uploading client data to any external cloud platform"

**Architecture: 100% Local AI via Ollama + Llama 3.1**

**Core Principles:**
- **MUST HAVE:** AI-level intelligence for interpretation, summaries, recommendations
- **ZERO CLOUD:** Absolutely no client data sent to external platforms
- **ALL LOCAL:** Open-source LLMs (Llama 3.1 8B) running on Duncan's iMac via Ollama
- **GRACEFUL FALLBACK:** Template-based interpretation if AI unavailable

**Implementation (See Pillar 5 for complete details):**

**Local AI Stack:**
```
Client Data (stays on iMac)
    ↓
TURAS R Code (statistical analysis)
    ↓
Statistical Results → Structured Prompts
    ↓
Ollama (localhost:11434)
    ↓
Llama 3.1 8B Model (runs locally, ~6-8GB RAM)
    ↓
AI-Generated Interpretations
    ↓
Validation & Quality Checks
    ↓
Final Outputs (Excel, PDF, Web)
```

**Key AI Features (ALL local):**
1. **Intelligent Interpretation** - Plain-English explanations of statistical results
2. **Executive Summaries** - Context-aware, prioritized findings and recommendations
3. **Data Quality Analysis** - AI analyzes open-ended responses for bot patterns
4. **Module Recommendations** - Natural language understanding of user goals
5. **PARTIAL Explanations** - Clear, actionable descriptions of degradations

**NOT Acceptable (data privacy):**
- ❌ Sending client data to GPT-4/Claude/other cloud APIs
- ❌ Cloud-based AI analysis of survey data
- ❌ Third-party AI platforms that store data
- ❌ Any external service that processes client information

**Acceptable (privacy-preserving):**
- ✅ Local LLMs via Ollama (data never leaves localhost)
- ✅ Open-source models (Llama 3.1, Mistral, Phi-3)
- ✅ On-premise inference (runs on Duncan's iMac)
- ✅ Rule-based systems (no external dependencies)

### 3.5 Platform Expansion & Technology Stack

**Long-term Technology Direction:**
- **Duncan's Input:** "I am not sure of the expansion plans as yet - this needs to run for a while first"
- **Likely long-term:** Hybrid R/Python/web frontend
- **Current decision:** Language functionality to be written/developed by me (Duncan) rather than users injecting own scripts
- **No user script injection:** Keep system controlled and validated

**Technology Roadmap (Aspirational):**
```
Phase 1 (Current): R-based, Shiny UI
Phase 2 (1-2 years): Hybrid R + Python for ML, improved web UI
Phase 3 (2+ years): Possible web frontend, R/Python backend services

Key Principle: Duncan controls all code - no user script injection for security/quality
```

### 3.6 Support & Maintenance Model

**Duncan's Support Philosophy:**
- **Support via outputs only** - not live debugging
- **Self-healing will be great**
- **I expect to always work with the output**
- **No real-time user support needed** (Duncan runs TURAS himself)

**Support Workflow:**
```
Client sends data
    ↓
Duncan runs TURAS
    ↓
TURAS generates:
- Analysis outputs (Excel/web)
- Validation pack (diagnostics)
- Executive summary
- Quality report (if data_quality module used)
    ↓
Duncan sends outputs to client
    ↓
If issues arise:
- Duncan reviews TRS refusals in console
- Checks validation pack
- Examines analysis log
- Self-healing features minimize need for intervention
```

**Self-Healing Features (HIGH PRIORITY for Duncan):**
- Automatic fallback strategies (with transparent reporting)
- Graceful degradation (PARTIAL status instead of crashes)
- Clear diagnostic information in validation packs
- Suggested fixes in TRS refusals

---

## 4. Technical Infrastructure

### 4.1 Backup & Disaster Recovery

**Duncan's Priority:** "We need a backup strategy"

**Backup Strategy:**

```bash
#!/bin/bash
# scripts/automated_backup.sh

# Daily backup of:
# 1. Client data (1Drive structure)
# 2. Templates
# 3. TURAS codebase (Git handles this)
# 4. renv.lock (package versions)

BACKUP_DATE=$(date +%Y%m%d)
BACKUP_DEST="/Volumes/BackupDrive/TURAS_Backups"

# Backup client data
rsync -av --exclude="*.turas_lock" \
  /Volumes/1Drive/clients/ \
  "$BACKUP_DEST/$BACKUP_DATE/clients/"

# Backup templates
rsync -av /Volumes/1Drive/templates/ \
  "$BACKUP_DEST/$BACKUP_DATE/templates/"

# Keep last 30 days of backups
find "$BACKUP_DEST" -type d -mtime +30 -exec rm -rf {} +

# Log backup completion
echo "$BACKUP_DATE: Backup completed successfully" >> "$BACKUP_DEST/backup_log.txt"
```

**Disaster Recovery:**
- Daily backups retained for 30 days
- Monthly backups retained for 1 year
- Backup verification: Monthly restore test
- RTO (Recovery Time Objective): 4 hours
- RPO (Recovery Point Objective): 24 hours (max 1 day of data loss)

### 3.2 Job Queue System

**Implementation (Future - Phase 2):**

```r
# modules/shared/queue/job_queue.R

# Job queue for batch processing
# Allows submitting multiple analyses, managing priority

job_queue <- R6::R6Class("JobQueue",
  public = list(
    jobs = list(),

    submit_job = function(module, data, config, priority = "normal") {
      job <- list(
        id = generate_job_id(),
        module = module,
        data = data,
        config = config,
        priority = priority,  # "high" | "normal" | "low"
        status = "queued",
        submitted_at = Sys.time(),
        started_at = NULL,
        completed_at = NULL,
        result = NULL
      )

      self$jobs[[job$id]] <- job
      return(job$id)
    },

    process_queue = function() {
      # Sort by priority, then submission time
      pending <- Filter(function(j) j$status == "queued", self$jobs)
      pending <- pending[order(
        sapply(pending, function(j) j$priority),
        sapply(pending, function(j) j$submitted_at)
      )]

      for (job in pending) {
        self$run_job(job$id)
      }
    },

    run_job = function(job_id) {
      job <- self$jobs[[job_id]]
      job$status <- "running"
      job$started_at <- Sys.time()

      result <- run_module(job$module, job$data, job$config)

      job$result <- result
      job$status <- if (result$status == "REFUSED") "failed" else "completed"
      job$completed_at <- Sys.time()

      self$jobs[[job_id]] <- job

      # Notification (future: email/desktop notification)
      notify_job_completion(job)
    },

    get_status = function(job_id = NULL) {
      if (is.null(job_id)) {
        # Return all jobs
        return(self$jobs)
      } else {
        return(self$jobs[[job_id]])
      }
    }
  )
)
```

**UI (Future):**
```
┌─ JOB QUEUE ────────────────────────────────────────────────┐
│                                                            │
│ Running (1):                                               │
│ ⏳ Job #1247: Tabs (ClientA/Wave3)       [Cancel]          │
│    Progress: ████████░░ 78% (6m 23s elapsed)               │
│                                                            │
│ Queued (2):                                                │
│ 🔵 Job #1248: KeyDriver (ClientA/Wave3)  [↑][↓][Cancel]    │
│ 🔵 Job #1249: Confidence (ClientB/Study) [↑][↓][Cancel]    │
│                                                            │
│ Completed Today (3):                                       │
│ ✅ Job #1244: Conjoint (ClientC) - 12:34 PM [View Results] │
│ ✅ Job #1245: Tabs (ClientA/Wave2) - 2:15 PM [View Results]│
│ ✅ Job #1246: Pricing (ClientD) - 3:47 PM [View Results]   │
│                                                            │
│ Failed (1):                                                │
│ ❌ Job #1243: MaxDiff (ClientE) - DATA_INVALID [View Error]│
│                                                            │
│ [Submit New Job]  [Clear Completed]  [Refresh]            │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### 3.3 Self-Healing & Graceful Degradation

**Automatic Fallback System:**

```r
# modules/shared/resilience/fallback_manager.R

execute_with_fallback <- function(primary_fn, fallback_fn, context) {

  # Try primary method
  primary_result <- tryCatch(
    primary_fn(),
    error = function(e) {
      list(status = "REFUSED", error = e$message)
    }
  )

  if (primary_result$status == "PASS") {
    return(primary_result)
  }

  # Primary failed, try fallback
  cat(sprintf("\n⚠ Primary method failed (%s), trying fallback...\n",
              primary_result$error))

  fallback_result <- tryCatch(
    fallback_fn(),
    error = function(e) {
      list(status = "REFUSED", error = e$message)
    }
  )

  if (fallback_result$status == "PASS") {
    # Fallback succeeded - return PARTIAL
    return(list(
      status = "PARTIAL",
      result = fallback_result$result,
      warnings = c(
        sprintf("Primary method failed: %s", primary_result$error),
        sprintf("Fallback method used: %s", context$fallback_description),
        sprintf("Impact: %s", context$fallback_impact)
      ),
      degradation_type = "METHOD_FALLBACK"
    ))
  }

  # Both failed - REFUSED
  return(list(
    status = "REFUSED",
    code = "ALL_METHODS_FAILED",
    message = sprintf("Primary and fallback both failed. Context: %s", context$operation),
    how_to_fix = context$how_to_fix,
    details = list(
      primary_error = primary_result$error,
      fallback_error = fallback_result$error
    )
  ))
}

# Example usage in CatDriver:
result <- execute_with_fallback(
  primary_fn = function() {
    # Try standard logistic regression
    MASS::polr(formula, data = data)
  },
  fallback_fn = function() {
    # Fallback to Firth correction
    brglm2::bracl(formula, data = data)
  },
  context = list(
    operation = "Ordinal logistic regression",
    fallback_description = "Firth bias-reduced logistic regression",
    fallback_impact = "Odds ratios more conservative (separation corrected)",
    how_to_fix = "Increase sample size or collapse rare categories"
  )
)
```

**Optional Dependency Handling:**

```r
# modules/shared/dependencies/optional_deps.R

check_optional_dependency <- function(package_name, feature_name) {

  if (!requireNamespace(package_name, quietly = TRUE)) {
    return(list(
      available = FALSE,
      message = sprintf(
        "Optional feature '%s' requires package '%s' (not installed)",
        feature_name, package_name
      ),
      how_to_install = sprintf("renv::install('%s')", package_name)
    ))
  }

  return(list(available = TRUE))
}

# Usage in KeyDriver for SHAP:
shap_available <- check_optional_dependency("xgboost", "SHAP analysis")

if (shap_available$available) {
  # Run SHAP analysis
  shap_result <- calculate_shap_importance(data, outcome)
} else {
  # Gracefully skip SHAP, continue with other methods
  cat("\n", shap_available$message, "\n")
  cat("Continuing with Shapley values only.\n")
  shap_result <- list(status = "SKIPPED", reason = "xgboost not available")
}
```

---

## 4. Documentation & User Experience

### 4.1 Comprehensive Documentation Structure

```
docs/
├── user_guides/
│   ├── getting_started.md
│   ├── module_guides/
│   │   ├── tabs_user_guide.md
│   │   ├── keydriver_user_guide.md
│   │   ├── conjoint_user_guide.md
│   │   └── ... (one per module)
│   ├── workflows/
│   │   ├── brand_tracking_workflow.md
│   │   ├── new_product_development_workflow.md
│   │   └── segmentation_workflow.md
│   └── faq.md
│
├── technical_docs/
│   ├── statistical_methods_reference.md (already exists)
│   ├── trs_error_codes_reference.md
│   ├── template_creation_guide.md
│   └── troubleshooting_guide.md
│
├── examples/
│   ├── tabs/
│   │   ├── basic_crosstab/
│   │   │   ├── README.md
│   │   │   ├── data.csv
│   │   │   ├── config.xlsx
│   │   │   └── expected_output.xlsx
│   │   └── advanced_significance_testing/
│   └── ... (examples per module)
│
└── video_tutorials/ (future)
    ├── 01_getting_started.mp4
    ├── 02_running_first_analysis.mp4
    └── ...
```

### 4.2 Error Code Reference

**Create comprehensive TRS error code documentation:**

```markdown
# TRS Error Code Reference

## IO_* Codes (Input/Output Errors)

### IO_FILE_NOT_FOUND
**Meaning:** Specified file path does not exist
**Common Causes:**
- Typo in file path
- File moved or deleted
- Incorrect working directory

**How to Fix:**
1. Verify file exists: `file.exists("path/to/file.xlsx")`
2. Check spelling and capitalization (case-sensitive)
3. Use absolute paths or `file.path()` for cross-platform compatibility

**Example:**
```r
# ❌ WRONG
data <- load_data("client_data.xlsx")  # Assumes current directory

# ✅ CORRECT
data <- load_data(file.path("data", "ClientA", "Wave1", "client_data.xlsx"))
```

### IO_FILE_LOCKED
**Meaning:** File is open in another application (Excel, etc.)
**How to Fix:**
1. Close file in Excel/other application
2. Check for hidden Excel processes (Task Manager/Activity Monitor)
3. Ensure no other TURAS instance is using the file

---

## DATA_* Codes (Data Validation Errors)

### DATA_MISSING_COLUMNS
**Meaning:** Required columns not found in dataset
**How to Fix:**
1. Check column names match config exactly (case-sensitive)
2. Review data schema in template
3. Export column names: `colnames(data)` and compare

### DATA_INVALID_TYPE
**Meaning:** Column has wrong data type (numeric expected, got character)
**How to Fix:**
1. Convert to correct type: `as.numeric()`, `as.factor()`
2. Check for non-numeric values in numeric columns ("N/A" strings, etc.)
3. Review data cleaning process

---

## CALC_* Codes (Statistical Calculation Errors)

### CALC_CONVERGENCE_FAILURE
**Meaning:** Iterative algorithm did not converge
**Common in:** Logistic regression, HB estimation
**How to Fix:**
1. Increase iteration limit (if available in config)
2. Check for perfect separation (see CALC_SEPARATION)
3. Simplify model (remove predictors, collapse categories)
4. Try fallback method (Firth correction, etc.)

### CALC_SEPARATION
**Meaning:** Perfect or quasi-perfect separation in logistic regression
**Why it happens:** Predictor perfectly predicts outcome (all 1s when X>5, all 0s when X<=5)
**How to Fix:**
1. Use Firth correction (automatic fallback in CatDriver)
2. Collect more data
3. Remove problematic predictor
4. Collapse categories to reduce separation

---

[Continue for all error codes...]
```

### 4.3 Troubleshooting Flowcharts

**Example: Memory Issues Troubleshooting**

```
START: "Error: Cannot allocate vector of size X GB"
  ↓
Is X > 80% of available RAM (16GB)?
  ↓ YES
  Reduce dataset size:
    - Remove unnecessary columns
    - Filter to subset of respondents
    - Use chunked processing
  ↓ NO
  Check for memory leaks:
    - Run gc() manually
    - Close other applications
    - Restart R session
  ↓
Still failing?
  ↓ YES
  Contact support with:
    - Memory usage graph
    - Data dimensions (nrow, ncol)
    - Module and config used
  ↓ NO
  Analysis proceeds successfully
  ↓
END
```

---

## 5. 12-Month Roadmap to 100/100

### Phase 1: Foundation (Months 1-3)

**Goal:** Critical infrastructure and testing

**Month 1:**
- [ ] Complete test infrastructure setup (synthetic data generators, testthat framework)
- [ ] Achieve 80% test coverage for high-priority modules (tabs, keydriver, confidence)
- [ ] Implement automatic memory optimization
- [ ] Create comprehensive TRS error code reference

**Month 2:**
- [ ] Build validation pack system (statistical diagnostics, method comparisons)
- [ ] Implement data quality detection module
- [ ] Create benchmark dataset library
- [ ] Standardize weighting module structure

**Month 3:**
- [ ] Build "What can I do with this data?" recommendation engine
- [ ] Create template library system (validated templates)
- [ ] Implement cost estimator
- [ ] Set up automated backup system

**Deliverables:**
- 80% test coverage (from 60%)
- Data quality module operational
- Validation packs for 5 core modules
- 3 validated templates created

---

### Phase 2: Enhancement (Months 4-6)

**Goal:** Output quality and interpretation

**Month 4:**
- [ ] Implement PARTIAL status report card system
- [ ] Build automated interpretation engine
- [ ] Create executive summary generator
- [ ] Standardize tracker module structure

**Month 5:**
- [ ] Implement performance benchmarking across all modules
- [ ] Optimize memory usage for tabs module (chunking)
- [ ] Add progress bars with time estimates to all long-running operations
- [ ] Complete documentation (user guides for all modules)

**Month 6:**
- [ ] Standardize segment module structure
- [ ] Implement segment integration with other modules
- [ ] Build self-healing/fallback infrastructure
- [ ] Create troubleshooting flowcharts

**Deliverables:**
- Executive summaries auto-generated
- All modules meet performance targets
- 90% test coverage achieved
- Complete user documentation

---

### Phase 3: Polish (Months 7-9)

**Goal:** Service deployment readiness

**Month 7:**
- [ ] Build project/client folder management system
- [ ] Implement lock-based collaboration for 2-3 person team
- [ ] Create workflow automation (template application)
- [ ] Add interactive web output generation (HTML dashboards)

**Month 8:**
- [ ] Implement method disagreement detection and warnings
- [ ] Add statistical assumption checking to all modules
- [ ] Create client-facing branded output templates
- [ ] Build "rerun this analysis" functionality

**Month 9:**
- [ ] Complete validation pack system for all 11 modules
- [ ] Implement incremental processing for tracker module
- [ ] Add rolling window support
- [ ] Final performance optimization pass

**Deliverables:**
- Service deployment infrastructure complete
- All modules have validation packs
- Branded output templates
- 95% test coverage

---

### Phase 4: Refinement (Months 10-12)

**Goal:** Excellence and future-proofing

**Month 10:**
- [ ] User acceptance testing with assistant
- [ ] Refinement based on real-world usage
- [ ] Create video tutorial library (getting started, common workflows)
- [ ] Build comprehensive example library

**Month 11:**
- [ ] Job queue system for batch processing (if needed based on usage)
- [ ] Additional statistical methods based on client demand
- [ ] AI-assisted features (automated insights, GPT-4 interpretation)
- [ ] Performance profiling and final optimization

**Month 12:**
- [ ] Final QA pass across all modules
- [ ] Achieve 100/100 quality score
- [ ] Complete marketing materials (module descriptions, use cases)
- [ ] Launch readiness checklist completion

**Deliverables:**
- 100/100 quality score achieved
- Complete documentation and examples
- Video tutorials available
- Production deployment ready

---

## 6. Success Metrics

### Quality Metrics

**Statistical Accuracy:**
- ✅ All modules pass benchmark validation tests (±0.001 tolerance)
- ✅ Zero statistical errors in production (all edge cases handled via TRS)
- ✅ Method disagreement detection catches 95%+ of problematic analyses

**Test Coverage:**
- ✅ 90%+ code coverage across all modules
- ✅ 100% of TRS refusals have corresponding tests
- ✅ All golden file regression tests passing

**Error Handling:**
- ✅ Zero silent failures (all errors produce TRS refusals)
- ✅ 100% of refusals have actionable "how_to_fix" guidance
- ✅ PARTIAL status includes degradation report in all cases

### Performance Metrics

**Speed (iMac 2017, 16GB RAM):**
- ✅ Small studies (n=100): < 30 seconds for any module
- ✅ Medium studies (n=1000): < 5 minutes for any module
- ✅ Large studies (n=5000): < 20 minutes for any module

**Memory:**
- ✅ No module exceeds 8GB RAM usage (50% of available)
- ✅ Automatic memory optimization prevents 95%+ of out-of-memory errors
- ✅ Chunking works correctly for 500+ question studies

### User Experience Metrics

**Output Quality:**
- ✅ Executive summaries correctly identify top 3 findings 90%+ of time
- ✅ Automated interpretation provides value-add insights (not just restating numbers)
- ✅ Validation packs answer 80%+ of "why this result?" questions

**Usability:**
- ✅ Assistant can run standard analyses independently (with Duncan review)
- ✅ "What can I do?" recommender suggests correct module 85%+ of time
- ✅ Templates reduce setup time by 70%+ vs manual configuration

**Reliability:**
- ✅ Zero data loss incidents
- ✅ Backup/restore tested monthly and working
- ✅ 99%+ uptime (minimal downtime due to bugs/crashes)

### Business Metrics

**Efficiency:**
- ✅ Time per analysis reduced by 60%+ vs manual methods
- ✅ Duncan's time spent on TURAS maintenance < 5 hours/week
- ✅ Client output turnaround time reduced by 50%+

**Adoption:**
- ✅ 80%+ of Duncan's analyses run through TURAS (vs manual)
- ✅ 3+ active client projects using TURAS simultaneously
- ✅ Templates reused 5+ times each (demonstrating value)

**Quality:**
- ✅ Zero client-reported statistical errors
- ✅ Client satisfaction with output quality 9/10+
- ✅ Validation packs preempt 90%+ of "how reliable is this?" questions

---

## 7. Risk Management

### Technical Risks

**Risk 1: Statistical Accuracy Issues**
- **Probability:** Low (rigorous validation)
- **Impact:** CRITICAL (client trust)
- **Mitigation:**
  - Benchmark testing against published datasets
  - Automated regression tests
  - Multiple method cross-validation
  - Validation packs surface assumptions
- **Contingency:** Immediate hotfix process, client notification protocol

**Risk 2: Memory/Performance Issues**
- **Probability:** Medium (hardware constrained)
- **Impact:** HIGH (unusable for large studies)
- **Mitigation:**
  - Automatic memory optimization
  - Chunking for large datasets
  - Performance benchmarks catch regressions
  - Machine upgrade path planned
- **Contingency:** Cloud processing offload (future), client communication re: limitations

**Risk 3: Data Loss/Corruption**
- **Probability:** Low (backups in place)
- **Impact:** CRITICAL (client data)
- **Mitigation:**
  - Daily automated backups
  - Monthly restore testing
  - Version control for code
  - Lock files prevent concurrent edits
- **Contingency:** 24-hour restore from backup, client notification

### Business Risks

**Risk 4: Maintenance Burden Too High**
- **Probability:** Medium (complex system)
- **Impact:** MEDIUM (time sink)
- **Mitigation:**
  - High test coverage reduces bugs
  - Self-healing/fallbacks reduce support
  - Comprehensive documentation reduces questions
  - Assistant handles routine operations
- **Contingency:** Prioritize automation, defer non-critical features

**Risk 5: Client Adoption Resistance**
- **Probability:** Low (Duncan controls usage)
- **Impact:** MEDIUM (ROI questioned)
- **Mitigation:**
  - Gradual rollout (prove value incrementally)
  - Templates make adoption easy
  - Output quality speaks for itself
  - Cost estimator demonstrates value
- **Contingency:** Continue hybrid approach (TURAS for appropriate analyses, manual for edge cases)

---

## 8. Open Questions & Decisions Needed

### Strategic Decisions

**Q1: AI Integration Depth**
- Should TURAS use GPT-4 for narrative insight generation?
- Tradeoff: Powerful interpretations vs. cost, API dependency, hallucination risk
- **Recommendation:** Phase 2 experimental feature (opt-in), validate outputs

**Q2: Platform Expansion**
- Stay R-only or consider hybrid (Python ML, web frontend)?
- Tradeoff: R ecosystem strength vs. performance/scalability
- **Recommendation:** Stay R for 12 months, reassess based on performance bottlenecks

**Q3: Extensibility**
- Allow custom R code injection or keep closed system?
- Tradeoff: Flexibility vs. security, supportability
- **Recommendation:** Closed system for now (maintain quality control)

### Technical Decisions

**Q4: Database vs File System**
- Current: File-based storage (1Drive folder structure)
- Alternative: SQLite/PostgreSQL for metadata, results
- Tradeoff: Simplicity vs. query performance, multi-user support
- **Recommendation:** File-based sufficient for solo practitioner, revisit for multi-client scaling

**Q5: CI/CD Investment**
- Automated testing infrastructure (GitHub Actions, etc.)
- Tradeoff: Setup time vs. long-term quality assurance
- **Recommendation:** Month 2-3 implementation (critical for 100/100)

**Q6: Cloud Processing**
- Offload heavy computations (HB, bootstrap) to cloud?
- Tradeoff: Speed vs. cost, data security, internet dependency
- **Recommendation:** Local processing for now (upgrade iMac if needed), cloud as future option

---

## 9. Appendices

### Appendix A: Module Complexity Matrix

| Module | Statistical Complexity | Performance Intensity | Test Priority | 100/100 Effort |
|--------|------------------------|----------------------|---------------|----------------|
| tabs | Medium | High (memory) | HIGH | Medium |
| confidence | Medium | Medium (bootstrap) | HIGH | Low |
| keydriver | High | Medium | HIGH | Medium |
| conjoint | Very High | High (HB) | HIGH | High |
| maxdiff | Very High | High (HB) | MEDIUM | High |
| catdriver | High | Medium | HIGH | Medium |
| pricing | Medium | Low | MEDIUM | Low |
| tracker | Medium | Medium | HIGH | Medium |
| weighting | Medium | Low | MEDIUM | Medium |
| segment | High | Medium | MEDIUM | High |
| data_quality | Medium | Low | HIGH | Medium |

### Appendix B: Dependency Audit

**Critical Dependencies (must maintain compatibility):**
- `openxlsx` (Excel I/O) - tested with 4.2.5
- `data.table` (performance) - tested with 1.14.8
- `ggplot2` (visualization) - tested with 3.4.2

**Statistical Dependencies:**
- `MASS` (ordinal regression) - base package, stable
- `nnet` (multinomial) - base package, stable
- `survival` (conditional logit) - base package, stable
- `boot` (bootstrap) - base package, stable

**Optional Dependencies (graceful degradation):**
- `xgboost` (SHAP) - may be difficult to install, fallback implemented
- `cmdstanr` (HB Bayes) - complex install, optional feature

**Risk Assessment:**
- Low risk: All critical dependencies are mature, stable packages
- Medium risk: Optional dependencies (handled via graceful degradation)
- High risk: None identified

### Appendix C: Statistical Method Validation References

**Benchmark Datasets for Testing:**

1. **Conjoint:** Sawtooth Software synthetic CBC data
2. **MaxDiff:** Academic published example (Louviere et al.)
3. **Logistic Regression:** Hosmer-Lemeshow textbook datasets
4. **Bootstrap CI:** Efron & Tibshirani examples
5. **Key Driver:** Published correlation/regression studies

**Validation Criteria:**
- Coefficients: ±0.001 tolerance
- P-values: ±0.01 tolerance
- Confidence intervals: ±0.02 tolerance
- Goodness-of-fit: ±0.05 tolerance

---

## 10. Conclusion

This specification defines a clear, achievable path to transform TURAS from 85/100 to 100/100 over 12 months. The roadmap prioritizes:

1. **Statistical rigor** (validation packs, benchmark testing)
2. **Output quality** (interpretation, executive summaries)
3. **Performance** (memory optimization, speed targets)
4. **Reliability** (test coverage, error handling)
5. **Usability** (templates, recommendations, documentation)

**Key Success Factors:**
- Quality over speed (Duncan's core philosophy maintained)
- Incremental progress (each month delivers tangible improvements)
- Real-world validation (assistant usage, client feedback)
- Pragmatic scope (no premature features, focus on excellence)

**12-Month Vision:**
By December 2026, TURAS will be a best-in-class market research analytics platform delivering publication-quality outputs with statistical transparency, automated insights, and bulletproof reliability - enabling Duncan to serve clients with confidence and efficiency.

**Next Steps:**
1. Review and refine this specification
2. Prioritize Month 1 tasks
3. Begin test infrastructure implementation
4. Iterate based on real-world usage

---

**Document Version:** 1.0
**Last Updated:** 2025-12-31
**Status:** Ready for Implementation
**Approval:** Pending Duncan Brett review

---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Final Polish Plan

**Owner:** Duncan Brett, The Research LampPost **Started:** 2026-04-06
**Status:** Phase 0 — Planning complete, execution begins Phase 1

------------------------------------------------------------------------

## What this is

Turas scores 93/100 with 11,808 passing tests. This is not a rebuild. It
is a systematic final polish to take a strong system to a flawless one —
the system Duncan stakes his reputation on for every project.

## What success looks like

1.  Every statistical calculation is verified correct, with no silent
    failure modes
2.  Jess can run any module from config to output without touching R
    code
3.  An external developer can navigate and maintain the codebase within
    a week
4.  Each advanced module has a technique guide good enough to hand to a
    client
5.  AI insights and callouts work across all modules with verified
    accuracy
6.  The directory is clean, the tooling is comprehensive, the
    documentation is sharp

------------------------------------------------------------------------

## Phase 0: Shared Infrastructure

**Goal:** Verify the foundation everything else depends on.

### 0.1 TRS compliance audit

-   144 stop() calls remain across the codebase (tabs: 41, weighting:
    24, conjoint: 14, confidence: 10, shared: 10)
-   Decide: which stop() calls should migrate to TRS refusals, which are
    legitimate (e.g., package load failures, developer-facing
    assertions)
-   Priority: any stop() in user-facing code paths must become TRS with
    console output
-   catdriver is missing 00_guard.R — add it

### 0.2 Shared utilities review

-   modules/shared/lib/ (42 files, 14,262 LOC)
-   Focus areas: trs_refusal.R, config_utils.R, validation_utils.R,
    stats_pack_writer.R
-   Verify: consistent behaviour across all callers
-   Test coverage: currently 0.23 ratio (8 tests for 34 code files) —
    identify gaps

### 0.3 Config system verification

-   config_utils.R handles all modules — verify edge cases
-   Auto-detection of header row, duplicate setting detection, sheet
    validation
-   Test with malformed configs (missing sheets, wrong column names,
    empty values)

### 0.4 Minification and delivery pipeline

-   turas_minify.R + verify + watermark chain
-   Confirm integrity across all HTML-generating modules
-   Verify Node.js tool detection works in Docker environment

**Deliverable:** Reviewed shared code, TRS compliance decisions
documented, test gaps identified.

------------------------------------------------------------------------

## Phase 1: Tabs + Tracker

**Goal:** Bulletproof the bread-and-butter modules Jess will run most.

### 1.1 Tabs

-   47,355 LOC across 87 files — the largest module
-   41 stop() calls to assess (highest in codebase)
-   AI insights are live here — verify statistical claims in callouts
-   Prompt tuning guide exists — review for completeness
-   Test ratio 0.45 — identify critical untested paths
-   HTML report generation: 39 references to review

### 1.2 Tracker

-   33,970 LOC across 56 files
-   Lib-based orchestration (no 00_main.R) — document as intentional
    pattern
-   6 stop() calls to assess, 0 TRS references
-   Future: trends option (flagged by Duncan)
-   Test ratio 0.55

### 1.3 Operational documentation

-   Review OPERATOR_GUIDE.md against actual Jess workflow
-   Docker setup instructions for Windows — verify completeness for
    2026-04-10 install
-   Module-specific quick-start for Tabs and Tracker

**Deliverable:** Reviewed Tabs + Tracker code, operational docs updated,
AI insights verified.

------------------------------------------------------------------------

## Phase 2: Weighting + Confidence

**Goal:** Verify the statistical rigour modules that feed into
everything.

### 2.1 Weighting

-   14,115 LOC, 39 files
-   24 stop() calls, 0 TRS references — significant migration needed
-   Lib-based orchestration pattern
-   RIM weighting, cell weighting, design weights — each calculation
    verified
-   Weight efficiency and design effect diagnostics

### 2.2 Confidence

-   21,909 LOC, 44 files
-   10 stop() calls, 1 TRS reference
-   4 CI methods — verify each against known results
-   Recently used as visual polish reference implementation
-   Test ratio 0.69

**Deliverable:** Reviewed statistical code, all calculations verified,
TRS migration complete.

------------------------------------------------------------------------

## Phase 3: KeyDriver + CatDriver

**Goal:** Review driver analysis modules. Produce technique guides.

### 3.1 KeyDriver code review

-   29,991 LOC, 63 files
-   Shapley, SHAP, Elastic Net, Dominance Analysis, NCA
-   Bootstrap confidence intervals — verify correctness
-   Test ratio 0.46

### 3.2 CatDriver code review

-   26,900 LOC, 46 files
-   Missing 00_guard.R — add
-   Test ratio 0.24 — weakest in codebase, needs significant test
    additions
-   7 stop() calls, 1 TRS reference
-   AI insights partially started — assess state

### 3.3 KeyDriver technique guide

-   Questionnaire design: what makes a good driver battery, scale
    choice, number of items
-   When to use: correlation-based importance vs regression
-   Method selection: Shapley vs SHAP vs Elastic Net — when each shines
-   Interpreting output: what "importance" means and doesn't mean
-   Watchouts: multicollinearity, small samples, dominant drivers
-   Where this module could go: relative importance visualisation,
    automated variable selection

### 3.4 CatDriver technique guide

-   When categorical drivers matter: binary outcomes, brand choice,
    churn
-   Questionnaire design for categorical outcomes
-   Logistic regression vs SHAP for categorical drivers
-   Interpreting odds ratios and marginal effects
-   Watchouts: rare events, separation, overfitting
-   Where this module could go: multinomial outcomes, interaction
    detection

**Deliverable:** Reviewed code, technique guides written, CatDriver
tests expanded.

------------------------------------------------------------------------

## Phase 4: Segment

**Goal:** Review clustering module. Produce technique guide.

### 4.1 Segment code review

-   34,566 LOC, 68 files
-   K-means, hierarchical, GMM — verify each algorithm
-   Silent failure mode risk: degenerate clusters, non-convergence
-   Test ratio 0.61
-   8 stop() calls

### 4.2 Segment technique guide

-   Questionnaire design: what variables make good segmentation inputs,
    scaling, battery design
-   Method selection: K-means vs hierarchical vs GMM — trade-offs
-   Choosing k: statistical criteria vs interpretability
-   Profiling and validation: discriminant analysis, stability testing
-   Watchouts: garbage-in-garbage-out, unstable solutions, segment size
    imbalances
-   Where this module could go: latent class analysis, ensemble
    approaches

**Deliverable:** Reviewed code, technique guide written.

------------------------------------------------------------------------

## Phase 5: Pricing

**Goal:** Review pricing module. Produce technique guide. Incorporate
Sawtooth material.

### 5.1 Pricing code review

-   23,121 LOC, 49 files
-   Van Westendorp, Gabor-Granger, monadic — verify each methodology
-   Revenue simulator accuracy
-   Test ratio 0.96 — best in codebase
-   Existing AUTHORITATIVE_GUIDE.md (26KB) +
    QUESTIONNAIRE_DESIGN_GUIDE.md — review and enhance

### 5.2 Pricing technique guide

-   Enhance existing questionnaire design guide with Sawtooth material
    (Duncan will provide)
-   Method selection: Van Westendorp vs Gabor-Granger vs monadic —
    decision framework
-   Question design watchouts: order effects, anchoring, realistic price
    ranges
-   Interpreting output: acceptable price range, optimal price, revenue
    curves
-   Where this module could go: competitive pricing analysis,
    conjoint-pricing integration

**Deliverable:** Reviewed code, enhanced technique guide incorporating
Sawtooth best practice.

------------------------------------------------------------------------

## Phase 6: Conjoint + MaxDiff

**Goal:** Review choice modelling modules. Produce technique guides.
Incorporate Sawtooth material.

### 6.1 Conjoint code review

-   24,587 LOC, 57 files
-   HB estimation — verify convergence diagnostics are catching failures
-   Market simulator — verify share calculations
-   14 stop() calls
-   Test ratio 0.72

### 6.2 MaxDiff code review

-   24,763 LOC, 43 files
-   HB and aggregate methods — verify both paths
-   TURF, IDA, portfolio analysis — verify each
-   6 stop() calls
-   Test ratio 0.72

### 6.3 Conjoint technique guide

-   Experimental design: attributes, levels, tasks, prohibitions —
    design efficiency
-   Questionnaire design: task format, number of concepts, none option,
    dual response
-   Sample size requirements for HB estimation
-   Interpreting utilities, importance scores, market simulation results
-   Watchouts: dominant attributes, unrealistic combinations,
    lexicographic respondents
-   Market simulator: share of preference vs first choice, sensitivity
    analysis
-   Incorporate Sawtooth material (Duncan will provide)
-   Where this module could go: ACBC, menu-based conjoint,
    willingness-to-pay

### 6.4 MaxDiff technique guide

-   When MaxDiff beats ranking and rating scales
-   Item selection: number of items, set size, design balance
-   Questionnaire design: best-worst format, anchored vs unanchored
-   Sample size for HB estimation
-   Interpreting probability scores and utility scores
-   TURF analysis and portfolio optimisation
-   Watchouts: item wording effects, context effects, acquiescence
-   Where this module could go: sparse MaxDiff, dual-response MaxDiff

**Deliverable:** Reviewed code, technique guides written, Sawtooth
material integrated.

------------------------------------------------------------------------

## Phase 7: AlchemerParser + Report Hub + hub_app

**Goal:** Review the input/output pipeline.

### 7.1 AlchemerParser

-   5,982 LOC, 20 files
-   Survey parsing accuracy — the foundation of everything downstream
-   5 stop() calls, 0 TRS references
-   Test ratio 0.81

### 7.2 Report Hub

-   6,420 LOC, 21 files
-   Multi-module report aggregation
-   Pin system, navigation, print overlay
-   Test ratio 1.10

### 7.3 hub_app

-   5,050 LOC, 17 files
-   Central launcher
-   0 stop() calls — cleanest module

**Deliverable:** Reviewed input/output pipeline, all modules verified.

------------------------------------------------------------------------

## Phase 8: Callout Editor

**Goal:** Flesh out the callout system into a comprehensive,
verified-correct feature.

### 8.1 Current state

-   Production-ready Shiny GUI at shared/lib/callouts/
-   \~400 lines, JSON registry, module filtering, search
-   Works but scope is limited

### 8.2 Enhancement

-   Expand callout coverage across all modules
-   Verification system: every callout must be statistically accurate
-   Integration with AI insights — AI-generated callouts vs manually
    curated
-   Callout preview in report context
-   Quality assurance workflow: draft → verify → approve

### 8.3 Correctness guarantee

-   Every callout makes a statistical claim — each must be testable
-   Build verification tests for callout accuracy
-   Duncan's standard: absolutely totally correct, no exceptions

**Deliverable:** Enhanced callout editor, verification system, expanded
coverage.

------------------------------------------------------------------------

## Phase 9: AI Insights Rollout

**Goal:** Extend AI insights from Tabs to all analysis modules.

### 9.1 Per-module rollout

For each module: - Custom data extraction (module output → structured
JSON for Claude) - Module-specific prompt design and tuning -
Verification pass: are the insights statistically correct? - Prompt
tuning documentation

### 9.2 Rollout order (tentative)

1.  CatDriver (partially started)
2.  KeyDriver (similar structure to CatDriver)
3.  Confidence (straightforward statistical summaries)
4.  Segment (profile descriptions, cluster interpretation)
5.  Pricing (price point interpretation, method comparison)
6.  Conjoint (utility interpretation, simulation narrative)
7.  MaxDiff (item ranking narrative, TURF interpretation)
8.  Tracker (wave comparison, trend detection)
9.  Weighting (diagnostic summary, efficiency narrative)

### 9.3 Prompt tuning guide

-   Extend existing guide from Tabs to cover module-specific tuning
-   Each module gets its own prompt tuning section
-   Document: what the AI should and should not say for each module

**Deliverable:** AI insights live in all modules, prompt tuning
documented per module.

------------------------------------------------------------------------

## Phase 10: Horizontal Pass + Cleanup

**Goal:** Cross-module consistency, directory hygiene, management
tooling.

### 10.1 Cross-module consistency

-   All 00_guard.R files follow same rigour
-   TRS codes consistent across modules
-   Config handling uniform
-   HTML report styling consistent (design tokens, no hardcoded colours)
-   Stats pack format consistent
-   Error messages actionable for Jess

### 10.2 Directory cleanup

-   Remove .DS_Store files (add to .gitignore)
-   Remove locked Excel temp files
-   Archive superseded planning docs
-   Verify no orphaned files

### 10.3 Management tools

-   Audit existing tools/ suite
-   Add: automated health check (run tests + platform stats in one
    command)
-   Add: module dependency map
-   Add: pre-release checklist script
-   Ensure all tools work in Docker

### 10.4 Documentation final pass

-   Every module README accurate and current
-   OPERATOR_GUIDE.md covers all modules Jess runs
-   CONTRIBUTING.md ready for external developer
-   claude.md updated with any new conventions from this initiative

**Deliverable:** Clean, consistent, fully-tooled platform.

------------------------------------------------------------------------

## Progress Tracker

| Phase | Scope                                 | Status                          |
|-------|---------------------------------------|---------------------------------|
| 0     | Shared infrastructure                 | Complete — passed re-review         |
| 1     | Tabs + Tracker                        | Fixes applied — awaiting re-review  |
| 2     | Weighting + Confidence                | Fixes applied — awaiting re-review  |
| 3     | KeyDriver + CatDriver                 | Fixes applied — awaiting re-review  |
| 4     | Segment                               | Not started |
| 5     | Pricing                               | Not started |
| 6     | Conjoint + MaxDiff                    | Not started |
| 7     | AlchemerParser + Report Hub + hub_app | Not started |
| 8     | Callout Editor                        | Not started |
| 9     | AI Insights Rollout                   | Not started |
| 10    | Horizontal Pass + Cleanup             | Not started |

------------------------------------------------------------------------

## Working principles

-   **Correctness over speed.** Every statistical claim verified. No
    rushing.
-   **Polish, not rebuild.** Respect what's already working. Fix what
    needs fixing.
-   **Write for Jess.** If she can't follow the docs, they're not done.
-   **Write for Duncan.** Clear, direct prose. No filler. No AI slop.
-   **One phase at a time.** Each phase complete before moving on.
-   **Document decisions.** When we choose to leave a stop() call or
    deviate from a pattern, record why.

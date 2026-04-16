---
editor_options: 
  markdown: 
    wrap: 72
---

# Brand Module — Project Plan

**Version:** 1.0 **Date:** 2026-04-16 **Author:** Duncan Brett / Claude
(The Research LampPost) **Status:** Planning complete. Ready for build.
**Detailed spec:** `docs/BRAND_MODULE_SPEC.md`

------------------------------------------------------------------------

## 1. Problem Statement

Market research clients need brand health measurement grounded in
evidence-based frameworks, not generic KPI dashboards. The
Ehrenberg-Bass Institute / Romaniuk approach (mental availability,
category entry points, distinctive brand assets) is the most rigorously
validated framework in marketing science, but no productised
implementation exists that combines it with high-quality visual output
and consultancy-grade delivery.

TRL has a commissioned brand health study (IPK, 1,200 respondents,
multi-category South African food brand) that requires this capability.
Building it as reusable Turas modules means the first project funds R&D
for a repeatable commercial offering: config-driven, click-of-a-button
analysis, production-quality HTML reports delivered within 5 business
days of fieldwork close.

------------------------------------------------------------------------

## 2. Landscape & Approach

**What exists:** - **Timelaps** (Romaniuk-affiliated SaaS) — productised
single-category tracker. Good framework implementation, self-service
model. Positioned for large brands with continuous tracking budgets. Not
consultancy-first; no multi-category portfolio view; not available as a
white-label tool. - **Kantar / Ipsos / Nielsen** — generic brand health
tools. Proprietary metrics (BrandZ, Brand Equity Index, etc.) with
limited transparency. Expensive, slow (4–6 week delivery), not based on
EBI evidence. - **In-house builds** — one-off R/Python scripts per
project. No reuse, no consistent quality, no visual standard.

**What we chose:** Extend Turas with two new modules (`brand` +
`portfolio`), following the established module pattern (config-driven,
TRS-compliant, HTML + Excel + CSV output, integrated with existing
pins/export/hub infrastructure). Romaniuk's CBM (Category Buyer Mindset)
questionnaire architecture from *Better Brand Health* (2022) as the
data-collection foundation.

**Why:** Turas already has the infrastructure (report hub, significance
testing, confidence intervals, tracking, weighting, driver analysis,
TURF, pins, export). Building on it avoids reinventing 80% of the
capability. The 20% that's new is the brand-specific analytics and the
CBM data model.

------------------------------------------------------------------------

## 3. Objectives

1.  **Deliver IPK wave 1:** Production-quality HTML brand health report
    within 5 business days of fieldwork close, covering all activated
    analytical elements.
2.  **Reusable capability:** A second client can onboard by filling in
    two Excel config files (Brand_Config.xlsx + Survey_Structure.xlsx)
    with zero code changes.
3.  **Methodological rigour:** MMS, MPen, NS, Fame, Uniqueness
    calculations validated against published Romaniuk examples. All
    metrics carry CIs and significance tests.
4.  **Visual quality:** Every chart follows the 9 locked design
    principles. Output quality matches FT / Economist / Pew Research
    visual standards. The visual output is the competitive moat.
5.  **Code quality:** 95+ quality score per `duncan-coding-standards`.
    Comprehensive test framework, zero technical debt, bug-free,
    modular, fully documented.
6.  **Tracker-ready:** Wave 1 output includes stable metric IDs consumed
    by the existing `tracker` module in wave 2+, with no retroactive
    changes needed.
7.  **Survey efficiency:** CBM questionnaire architecture keeps the
    survey under 15 minutes for core batteries + one optional battery,
    supporting multi-category studies via focal-category routing.

------------------------------------------------------------------------

## 4. Requirements

### Functional

-   Two new modules: `brand` (per-category) and `portfolio`
    (cross-category)
-   TURF engine refactored from `maxdiff` into `shared/` for reuse
-   Seven config-togglable analytical elements: Funnel, Mental
    Availability (+ CEP TURF), Repertoire, Drivers & Barriers, DBA,
    Portfolio, WOM
-   Two-file Excel config: Brand_Config.xlsx (analysis settings) +
    Survey_Structure.xlsx (data dictionary, shared with tabs/tracker)
-   Template generators for both config files
-   HTML report through existing `report_hub` + `hub_app` with
    TurasPins, insight boxes, pin-to-PPT export
-   Excel + CSV output per element
-   Structured metrics summary returned by every element (hook for AI
    annotations, exec summaries)
-   Panel-compatible from v1 (respondent ID support, no cross-sectional
    assumptions)

### Quality

-   95+ code quality score
-   Comprehensive test framework: unit, integration, edge case, golden
    file, performance
-   TRS-compliant throughout — no `stop()`, all errors console-visible
    for Shiny debugging
-   Guard layers validate every config parameter and data column before
    analysis
-   All functions documented with roxygen2
-   Zero technical debt — no known compromises without remediation plan
-   `styler` and `lintr` clean

### Constraints

-   \~4-week build window during IPK qual phase
-   Team: Duncan (methodology, design, review), Claude (implementation,
    tests, docs, Alchemer Lua), Jess (Alchemer programming)
-   15-minute survey hard limit; 1,200 completes; mobile-first
-   Must use existing Turas infrastructure (pins, exports, insight
    boxes, hub, shared utilities)

### Dependencies

-   `tabs` module (significance testing)
-   `confidence` module (CIs)
-   `catdriver` module (optional derived importance)
-   `tracker` module (wave 2 consumption)
-   `weighting` module (upstream)
-   `report_hub` + `hub_app` (rendering)
-   `shared/TurasPins` (pin system)
-   `shared/lib/config_utils.R` (config loading)
-   `AlchemerParser` (survey structure generation)

------------------------------------------------------------------------

## 5. Design & Experience

### Information architecture

```         
├── Executive Summary              ← Hero; progressive-disclosure
├── Portfolio                      ← Multi-category only
│   ├── Portfolio Map
│   ├── Priority Quadrants
│   └── Category TURF
├── Categories                     ← Tabbed, one per category
│   └── {Category}
│       ├── Funnel
│       ├── Mental Availability
│       ├── Repertoire
│       └── Drivers & Barriers
├── Brand Assets (DBA)             ← Brand-level, not per-category
├── Word-of-Mouth                  ← Brand-level
├── Audience Profile               ← Demographics, segments
└── About & Methodology            ← Romaniuk/HBG explainers
```

Dynamic navigation — sections appear only when their element is
activated and data is present.

### Questionnaire architecture

Romaniuk CBM shared-battery model. Five core batteries (always
collected) + two optional batteries (WOM, DBA):

1.  **Brand Awareness** — all qualified categories (lightweight)
2.  **Brand Attributes / CEP Matrix** — focal category only (the heavy
    lift: 15–20 screens)
3.  **Brand Attitude** — focal category only (5-level scale + rejection
    OE)
4.  **Category Buying** — focal category only
5.  **Brand Penetration** — full for focal category, light for non-focal
6.  *Optional: WOM* — brand-level, 6 questions
7.  *Optional: DBA* — brand-level, 2 questions per asset

### Multi-category routing

One focal category per respondent for the full CEP battery. Everything
else stretches across categories cheaply. Assignment method configurable
(balanced / quota / priority weighted).

### Design principles (9, locked)

1.  Clarity first (5-second rule)
2.  Headline states the finding
3.  Subject-vs-field colour discipline
4.  Progressive depth
5.  Chart grammar, not variety
6.  Direct labelling
7.  Distribution over central tendency
8.  Annotation is first-class
9.  Honest data, transparent footing

### Full element catalogue and config architecture

See `docs/BRAND_MODULE_SPEC.md` Sections 3–6 for complete detail.

------------------------------------------------------------------------

## 6. Growth Roadmap

### Immediate (v1 — the IPK build, \~4 weeks)

-   `brand` module: 6 elements, all config-togglable
-   `portfolio` module: 3 sub-views, multi-category only
-   TURF engine extraction into `shared/`
-   Config template generators
-   HTML + Excel + CSV output through existing Turas infrastructure
-   Structured metrics summary per element
-   Panel-compatible data handling
-   Alchemer programming brief + Lua routing logic

### Near-term (3–6 months)

1.  **IPK wave 2 tracker integration** — config change only, `tracker`
    module consumes v1 metric IDs
2.  **v1.1 elements** — Ad Reach first (uses existing image upload),
    then Physical Availability
3.  **AI-assisted annotations** — extend existing `ai-insights` from
    tabs to brand elements
4.  **Second client deployment** — validates config-driven reuse
5.  **Panel split-sample CEP rotation** — rotation matrix in config,
    expanded CEP coverage across waves

### Long-term (6–18 months)

6.  **Auto-coding rejection open-ends** — LLM-assisted theme coding with
    human review
7.  **Multi-market capability** — market dimension in config,
    cross-market comparison views
8.  **Standalone commercial offering** — per-project or annual license
    for other agencies/in-house teams

### Foundational decisions for v1

| Growth path | What v1 must do | Cost |
|------------------------|------------------------|------------------------|
| Tracker wave 2 | Stable metric IDs | Zero — in spec |
| v1.1 elements | Config toggle slots, battery codes in Survey_Structure | Zero — in spec |
| AI annotations | Structured metrics summary per element | Low — confirmed for v1 |
| Second client | Everything config-driven, no client-specific code | Zero — design principle |
| Panel support | Respondent ID column, no cross-sectional assumptions | Low — confirmed for v1 |
| Multi-market | Generic facet concept in rendering (don't hardcode "category" as only grouping) | Design note for v1 |

------------------------------------------------------------------------

## 7. Risks & Mitigations

### Execution risks

| \# | Risk | Likelihood | Severity | Mitigation |
|---------------|---------------|---------------|---------------|---------------|
| 1 | Survey length overrun | Medium | Medium | Pre-test with real respondents; CEP count is primary lever; soft launch with time monitoring; config disables optional batteries instantly |
| 2 | Build window compression | Medium | Low | Build in priority order (MA first); each element independently deployable; config absorbs partial delivery |
| 3 | CEP quality (bad wording) | Low-Med | **High** | Follow Romaniuk wording rules; cognitive pre-test; document CEP rationale in config |
| 4 | Sample size per category after routing | High (arithmetic) | Low | Low-base flagging at n\<75; suppression at n\<30; priority weighting available; honest methodology disclosure |
| 5 | Alchemer programming complexity | Medium | **High** | Claude assists with Lua routing logic; full routing-path test before fieldwork; Duncan reviews end-to-end |
| 6 | Data structure mismatch | Medium | Medium | Support both Alchemer export formats; use AlchemerParser; guard-layer column validation; test with synthetic data before fieldwork |

### Strategic risks

| \# | Risk | Likelihood | Severity | Mitigation |
|---------------|---------------|---------------|---------------|---------------|
| 7 | Single-client dependency | Low-Med | Low | Module is config-driven, not IPK-specific; wave 1 output becomes sales asset |
| 8 | Methodological pushback from clients | Medium | Low | About section with academic references; funnel element bridges familiar/rigorous; composite metrics for legacy KPIs if demanded |
| 9 | Competitive response (Timelaps/agencies) | Low | Low | Moat is visual quality + consultancy relationship + speed of delivery, not exclusive methodology access |

**Watch items:** #3 (CEP quality) and #5 (Alchemer routing) are the
highest-severity risks. Both are human-process, not code. CEP
development and Alchemer QA deserve dedicated time early in the build
window.

------------------------------------------------------------------------

## 8. Quality Standards

All code governed by `duncan-coding-standards` skill. Non-negotiable.

### Code

-   [ ] 95+ quality score
-   [ ] Comprehensive test framework (unit, integration, edge case,
    golden file, performance)
-   [ ] TRS-compliant — no `stop()`, structured refusals,
    console-visible errors
-   [ ] Guard layers validate all config and data inputs
-   [ ] Roxygen2 documentation on every exported function
-   [ ] `styler` and `lintr` clean
-   [ ] No hardcoded paths, no client-specific code, no credentials
-   [ ] Zero technical debt
-   [ ] Modular — single-responsibility functions, \<100 lines where
    feasible

### Statistical

-   [ ] MMS/MPen/NS validated against published Romaniuk examples
-   [ ] CIs on all headline metrics via `confidence` module
-   [ ] Significance tests on all comparisons via `tabs` module
-   [ ] Low-base warnings (n\<75) and suppression (n\<30)
-   [ ] TURF engine regression-tested against existing maxdiff output
-   [ ] CEP TURF reach verified by manual calculation

### Visual

-   [ ] All 9 design principles followed in every chart
-   [ ] No anti-pattern charts
-   [ ] Every chart: finding-led headline, base sizes, significance
    flags, dates
-   [ ] Colour discipline consistent across elements
-   [ ] Direct labelling throughout
-   [ ] Tablet-responsive verified (Chrome, Safari, Firefox)

### Config

-   [ ] Template generators produce valid, documented Excel files
-   [ ] Module runs with template defaults (no manual editing for basic
    run)
-   [ ] All element toggles work independently
-   [ ] Meaningful TRS error messages for incomplete/malformed config

### Delivery

-   [ ] HTML renders correctly in Chrome, Safari, Firefox, Edge
-   [ ] Existing TurasPins, insight boxes, pin-to-PPT export all
    functional
-   [ ] Excel output with proper formatting
-   [ ] CSV output clean, long-format
-   [ ] Tracker metric IDs stable (verified by double-run)
-   [ ] About & Methodology section with academic references

### Process

-   [ ] Alchemer programming brief + Lua routing logic written early in
    build
-   [ ] Full routing test (all category-assignment paths) before
    fieldwork
-   [ ] Pre-test with 5–10 respondents
-   [ ] Soft launch (50 completes) with completion time monitoring
-   [ ] Data validation on first 100 completes
-   [ ] Duncan reviews every element's output before delivery

------------------------------------------------------------------------

## 9. Build Order

Priority-sequenced for maximum value delivery and graceful partial
completion.

| Phase | What | Why first |
|------------------------|------------------------|------------------------|
| 1 | TURF engine extraction into `shared/` | Dependency for both modules; regression-test against existing maxdiff |
| 2 | Config template generators + data loader | Foundation everything else builds on; validates Survey_Structure.xlsx pattern |
| 3 | Mental Availability (+ CEP TURF) | Centrepiece element; most complex; validates CEP matrix data flow end-to-end |
| 4 | Funnel | Derived from MA + attitude + penetration; fast once MA data flow works |
| 5 | Drivers & Barriers | Derived; leverages catdriver; fast once CEP matrix is loaded |
| 6 | Repertoire | Derived from penetration data; standalone |
| 7 | Portfolio (Map + Quadrants + Category TURF) | Cross-category; consumes per-category outputs from phases 3–6 |
| 8 | WOM | Own battery; standalone; lower priority than core elements |
| 9 | DBA | Own battery; optional; can ship without if survey time is tight |
| 10 | Alchemer programming brief + Lua | Parallel track; needed before fieldwork, not before module code |

Phases 3–6 are independently deployable. If the build window compresses,
ship whatever is complete — config suppresses unfinished elements.

------------------------------------------------------------------------

## 10. Next Steps

1.  **Begin Phase 1 build:** TURF engine extraction from maxdiff into
    shared, with regression tests
2.  **Config template generators:** Brand_Config.xlsx +
    Survey_Structure.xlsx templates with documentation
3.  **Mental Availability element:** Full implementation following the
    spec
4.  **Alchemer brief for Jess:** Parallel track — routing logic, Lua
    scripts, brand-list piping
5.  **CEP development for IPK:** Duncan drafts category-specific CEPs
    following Romaniuk wording guidelines

------------------------------------------------------------------------

*This plan consolidates Phases 1–6 of the project planning process. The
detailed element catalogue, questionnaire architecture, config schema,
and visualisation specifications are in `docs/BRAND_MODULE_SPEC.md`.*

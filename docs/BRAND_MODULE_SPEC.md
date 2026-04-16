# Brand Module Specification

**Version:** 0.1 (Phase 4 Pass 2) **Date:** 2026-04-16 **Author:** Duncan Brett / Claude (The Research LampPost) **Status:** Planning — not yet implemented

------------------------------------------------------------------------

## Contents

1.  [Overview](#1-overview)
2.  [Architecture](#2-architecture)
3.  [Shared Questionnaire Architecture](#3-shared-questionnaire-architecture)
4.  [Multi-Category Routing](#4-multi-category-routing)
5.  [Element Catalogue](#5-element-catalogue)
    -   5.1 [Funnel](#51-funnel)
    -   5.2 [Mental Availability](#52-mental-availability)
    -   5.3 [Repertoire](#53-repertoire)
    -   5.4 [Drivers & Barriers](#54-drivers--barriers)
    -   5.5 [DBA (Distinctive Brand Assets)](#55-dba-distinctive-brand-assets)
    -   5.6 [Portfolio](#56-portfolio)
    -   5.7 [WOM (Word-of-Mouth)](#57-wom-word-of-mouth)
6.  [Config Architecture](#6-config-architecture)
7.  [Design Principles](#7-design-principles)
8.  [Visual Reference Pack](#8-visual-reference-pack)
9.  [Decisions Log](#9-decisions-log)

------------------------------------------------------------------------

## 1. Overview

### What we are building

A productised brand analytics capability inside Turas, applying Ehrenberg-Bass Institute (EBI) and Romaniuk frameworks to client brand studies. The data collection follows Romaniuk's Category Buyer Mindset (CBM) questionnaire architecture from *Better Brand Health* (2022). The analytical output is an interactive HTML report delivered through Turas's existing report and hub infrastructure.

### Why

IPK (South African multi-category food brand) commissioned a 1,200-respondent quantitative study for wave 1 baseline. The qual phase is running now, creating a build window of approximately 4 weeks. Wave 2 tracking is likely if wave 1 lands. This first deployment funds R&D for a reusable, config-driven capability.

### Commercial positioning

"We run the EBI/Romaniuk model, packaged in Turas reports." Specialist positioning differentiated from Kantar/Ipsos/Nielsen generic brand health tools and from SaaS trackers like Timelaps. Turas is reporting/analysis-first, not SaaS subscription. Duncan wants click-of-a-button analysis with full-stack ownership.

### Methodological foundation

The CBM approach collects data in shared batteries; analytical elements are independent views onto that shared data. The questionnaire is designed once per study; the config controls which analytical elements run. This is a structural departure from traditional brand trackers where each metric has its own bespoke question set.

### Quality mandate

All code must follow the `duncan-coding-standards` skill at all times: - **95+ code quality score** (Turas platform standard) - **Comprehensive test framework** — unit, integration, edge case, golden file, and performance tests - **Zero technical debt** — no known compromises without a documented remediation plan - **Bug-free** — all code paths tested, all edge cases handled, all errors TRS-compliant - **Modular** — single-responsibility functions, clean separation of concerns - **Well-documented** — roxygen2 on every exported function, module README, inline comments on non-obvious logic - **Structured metrics summary** — every element returns a named list of key metrics alongside rendered output (hook for AI annotations, executive summaries, cross-element integration) - **Panel-compatible** — respondent ID support from v1, no cross-sectional assumptions in data handling

Key references: - Romaniuk, J. (2022). *Better Brand Health*. Oxford University Press. (CBM framework, questionnaire template) - Sharp, B. (2010). *How Brands Grow*. Oxford University Press. (Double Jeopardy, mental/physical availability) - Romaniuk, J. & Sharp, B. (2016). *How Brands Grow Part 2*. Oxford University Press. (Mental availability measurement, CEPs) - Romaniuk, J. (2018). *Building Distinctive Brand Assets*. Oxford University Press. (Fame × Uniqueness DBA framework)

------------------------------------------------------------------------

## 2. Architecture

### Two new modules

| Module | Purpose | Scope |
|----|----|----|
| `brand` | Within-category brand strength analysis | Runs once per category. Produces per-category-per-element structured output. |
| `portfolio` | Cross-category brand mapping | Runs once per study. Requires multi-category setup (2+ categories). |

### Shared utility extraction

The TURF engine is refactored from the `maxdiff` module into `shared/` so that both `brand` (CEP TURF) and `portfolio` (Category TURF) can reuse it without duplication.

### Seven analytical elements

Elements are config-driven and opt-in. Each produces its own section in the HTML report. Elements only appear in navigation when activated and when their required data is present.

| \# | Element | Module | Group | Description |
|----|----|----|----|----|
| 1 | Funnel | brand | A — derived | Brand base shape: awareness → attitude → buying. Derived from core CBM data. |
| 2 | Mental Availability | brand | A — core | MMS, MPen, NS, CEP matrix, CEP TURF. The analytical centrepiece. |
| 3 | Repertoire | brand | A — derived | Multi-brand buying, share of requirements, switching patterns. |
| 4 | Drivers & Barriers | brand | A — derived | Which CEPs drive purchase; explicit rejection reasons. |
| 5 | DBA | brand | B — own battery | Fame × Uniqueness for distinctive brand assets. Adds \~2 min to survey. |
| 6 | Portfolio | portfolio | A — derived | Portfolio map, priority quadrants, category TURF. Multi-category only. |
| 7 | WOM | brand | B — own battery | Word-of-mouth: received/shared × positive/negative. Adds \~2 min to survey. |

**Group A** elements consume only core CBM data — toggling them on/off does not affect the questionnaire.

**Group B** elements have their own question batteries — toggling them on implies those batteries must be in the survey.

### Existing Turas modules and infrastructure leveraged

No duplication. The brand module consumes existing capabilities:

| Module / System | Role |
|----|----|
| `tabs` | Significance testing on all cross-brand comparisons |
| `tracker` | Wave-over-wave analysis (wave 2 onwards) |
| `weighting` | Sample weighting upstream |
| `confidence` | CIs on all headline metrics |
| `catdriver` | Optional CEP-to-purchase regression for derived importance (Drivers & Barriers) |
| `report_hub` | HTML report aggregation |
| `hub_app` | Dynamic navigation, conditional rendering per activated elements |
| `shared/TurasPins` | Pin system for image capture, drag-and-drop pin management, PNG export. Brand module charts use the standard TurasPins library — no new pin infrastructure. |
| Pin-to-PPT export | Existing image-pin-to-PPT pipeline. No new export mechanism. |
| Insight boxes | Existing editable insight/callout system per chart section. Brand module elements include standard insight boxes that analysts can edit in the HTML report. |
| `shared/lib/config_utils.R` | Config loading, typed getters, path resolution |
| `shared/template_styles.R` | Template generator infrastructure for Excel config files |
| `AlchemerParser` | Generate Survey_Structure.xlsx from Alchemer export structure |

### Alchemer programming

Claude assists with Alchemer survey programming alongside Jess, including Lua scripting for complex routing logic (focal-category assignment, cross-category piping, conditional battery display). This is not a Jess-only task — Claude provides Lua code, routing logic, and QA review.

### v1.1 architectural slots

Config schema includes placeholders for future elements. No implementation in v1.

-   Ad Reach / Branded Reach (uses existing Turas image upload infrastructure for creative stimuli)
-   Physical Availability
-   Price Perceptions
-   Brand Affinity / Emotional
-   Brand Image (may fold into Mental Availability's non-CEP attribute sub-view)

------------------------------------------------------------------------

## 3. Shared Questionnaire Architecture

The CBM approach collects data in shared batteries. The questionnaire is the same regardless of which analytical elements are activated. Group B elements (DBA, WOM) add optional batteries.

### Battery structure and flow

```         
SCREENER + DEMOGRAPHICS                              ← Routing gate
    ↓
CORE BATTERY 1: Brand Awareness                      ← All qualified categories
    ↓
CORE BATTERY 2: Brand Attributes / CEP Matrix        ← Focal category only
    ↓
CORE BATTERY 3: Brand Attitude                       ← Focal category only
    ↓
OPTIONAL BATTERY: WOM                                ← If elements.wom = true (brand-level)
    ↓
CORE BATTERY 4: Category Buying                      ← Focal category only
    ↓
CORE BATTERY 5: Brand Penetration (full)             ← Focal category only
    ↓
CORE BATTERY 5b: Brand Penetration (light)           ← Non-focal qualified categories
    ↓
OPTIONAL BATTERY: DBA                                ← If elements.dba = true (brand-level)
    ↓
DEMOGRAPHICS (remainder) + CLOSE
```

**Why this order:** The attribute/CEP matrix is placed early (before buying behaviour) because it measures mental associations. Respondents should be thinking about brand perceptions, not primed by their own purchase history. Buying questions come later to avoid contaminating the association data. DBA goes last because it is brand-level (not category-level) and benefits from the respondent being warmed up on brand thinking. WOM sits between attitude and buying as a natural bridge.

### Core Battery 1: Brand Awareness

**Scope:** All qualified categories per respondent (not just focal). **Questions:** One MR question per category.

> **BRANDAWARENESS:** "Which of the following brands have you heard of before today? Select all that apply."

-   MR, brand list in **alphabetical order** (Romaniuk specifies alphabetical for awareness — this is a recognition task where alphabetical ordering aids scanning, unlike association tasks which need randomisation)
-   "None of these" anchored at end
-   Show logos/pack images alongside names where available
-   Run once per category the respondent qualified for at screener

**Feeds:** Funnel (awareness stage), Mental Availability (aware base), Portfolio (cross-category awareness)

### Core Battery 2: Brand Attributes / CEP Matrix

**Scope:** Focal category only. **Questions:** One screen per attribute/CEP statement. 15–20 statements.

Intro screen (shown once):

> "Next, you will see some statements that people have linked to brands of [CATEGORY]. Please review each statement and indicate which, if any, of the listed brands you associate with that statement. You can select as many or as few brands as you like. It does not matter if you have actual experience with that particular brand or not; it is your opinion we are interested in."

Per statement:

> **Q1BRANDATTRIBUTE:** "Which of these [CATEGORY] brands do you link with the following statement? Remember that you can select as many or as few as you like, or none of these, if none are relevant to the statement." **[STATEMENT IN BOLD]**

-   MR per statement
-   **One statement per screen** (not a grid — forces individual consideration of each statement)
-   Brand list as buttons, **randomised per respondent**, carried consistently across all statement screens
-   Statement list **randomised across respondents** (controls fatigue effects on later items)
-   "None of these" anchored at end

**Statement composition:** 60–70% CEPs, 30–40% other brand image attributes. For 15 statements: \~10 CEPs + \~5 attributes. For 20 statements: \~13 CEPs + \~7 attributes.

**Wording guidance (Romaniuk):** Simple, concrete, situation-based for CEPs ("When I want something quick and easy" not "Convenience"). No comparatives ("better than"), no superlatives ("the best"), no double-barrelled statements.

**Brand list scope:** All bigger-share brands + medium-share + representative small brands including the focal brand. Maximum \~20 brands per category (beyond 20, the button grid becomes unwieldy on mobile).

**Programming notes:** - Brand button order randomised per respondent, carried consistently across all statement screens - Statement order randomised per respondent - If respondent qualified for multiple categories, the CEP matrix runs only for the assigned focal category - The intro screen shows once, not per statement

**Feeds:** Mental Availability (MMS/MPen/NS, CEP matrix, CEP TURF), Drivers & Barriers (derived importance), Portfolio (MMS input)

### Core Battery 3: Brand Attitude

**Scope:** Focal category only. **Questions:** One grid + conditional open-end.

> **QBRANDATT1:** "Which of the following statements best matches how you feel about this brand? Select one answer per brand."

| Code | Level | Label |
|----|----|----|
| 1 | Strong positive | "I love it / it's my favourite" |
| 2 | Mild positive | "It's among the ones I prefer" |
| 3 | Ambivalent buyer | "I wouldn't usually consider it, but I would if no other option was available" |
| 4 | Rejection | "I would refuse to buy this brand" |
| 5 | No attitude | "I have no opinion about this brand" |

-   SR per brand, grid format
-   Brand list = attribute brand list + any additional brands of interest (new launches)
-   Randomise brand order within the grid
-   Adapt level wording to category type: "buy" for TRANS, "own" or "use" for DUR, "be a customer of" for SERV

**Conditional open-end for rejection:**

> **QBRANDATT2:** "Thinking about [BRAND NAME], why would you refuse to buy this brand?"

-   Asked for each brand coded 4 at QBRANDATT1
-   Open-ended, 3 lines
-   Loops for each rejected brand (respondent may reject multiple)
-   If blank, error: "Please enter a response. If you cannot think of any answer, please type in 'Don't know'."

**Programming notes:** - Grid must be mobile-friendly — consider card-swipe format on mobile rather than matrix grid - QBRANDATT2 loops for each rejected brand

**Feeds:** Funnel (positive disposition = codes 1–3; preferred = code 1; rejection = code 4), Drivers & Barriers (rejection reasons from OE), Repertoire (preference layer)

### Core Battery 4: Category Buying

**Scope:** Focal category only. **Questions:** One question. Wording varies by category type.

**TRANS (transaction/FMCG):** \> **QCATEGORYBUYINGTRANS:** "How often have you bought [CATEGORY] in the last [TARGET TIMEFRAME]? Select one answer." \> (Frequency bands appropriate to category purchase cycle)

**DUR (durables):** \> **QCATEGORYBUYINGDUR:** "In the last X years, how many times have you bought [CATEGORY]? Select one answer."

**SERV (services):** \> **QCATEGORYBUYINGSERV:** "In the last X years, how many times have you bought [CATEGORY]? Select one answer."

-   SR, category-specific frequency bands
-   Purpose: classify lighter vs heavier category buyers (not a precision purchase measure)
-   Frequency bands should vary by category and consider common rounding errors

**Feeds:** Repertoire (category purchase weight), Portfolio (category engagement)

### Core Battery 5: Brand Penetration

**Scope:** Focal category (full version) + non-focal qualified categories (light version).

#### 5a. Full version (focal category only)

Varies significantly by category type.

**TRANS:**

**Q1 — Longer timeframe** (MR, alphabetical): \> "Which of the following brands have you bought in the last [LONGER TIMEFRAME]? Select all that apply."

**Q2 — Target timeframe** (MR, piped from Q1): \> "Which of the following brands have you bought in the last [TARGET TIMEFRAME]? Select all that apply."

**Q3 — Frequency** (scale 1–11+, piped from Q2, per brand): \> "How many times have you bought each of the following brands in the last [TARGET TIMEFRAME]? Select one response for each brand."

**DUR:**

**Q1 — Current ownership** (SR, alphabetical): \> "Which brand do you currently own for [CATEGORY]? Select one response."

**Q2 — Tenure** (SR, bands): \> "How long have you been a customer of [BRAND]? Select one response." \> (Bands: last 12 months / 1–3 years / 3–5 years / 5+ years)

**SERV:**

**Q1 — Current customer** (SR, alphabetical): \> "Which brand are you a customer of for [CATEGORY]? Select one response."

**Q2 — Tenure** (SR, bands — same as DUR)

**Q3 — Prior brand** (SR + open "Other" + "No other brand"): \> "Which brand did you use prior to [BRAND]?"

**Repeat Q1 for each relevant subcategory** (Romaniuk instruction).

**Programming notes:** - Brand list can be broader than the attribute list — include smaller brands and "Other (please specify)" - TRANS uses two timeframes: "longer" casts a wide net, "target" is the analytical period - DUR/SERV single-response ownership questions produce different data shapes — config `category.type` controls which variant

#### 5b. Light version (non-focal qualified categories)

One MR question per non-focal category:

> "Which of the following brands have you bought in the last [TIMEFRAME]? Select all that apply."

-   MR, alphabetical
-   No frequency, no timeframe layering, no tenure — just which brands bought
-   Purpose: provide basic penetration data for Portfolio element

**Feeds:** Funnel (trial/bought, preferred), Repertoire (multi-brand buying, share, switching), Drivers & Barriers (buyer/non-buyer classification), Portfolio (penetration per category)

### Optional Battery: WOM

**Scope:** Brand-level (all respondents, not category-specific). **Questions:** Six questions. \~2 minutes. **Condition:** Only collected if `elements.wom = true`.

**Q1 — Received positive** (MR by brand): \> "Has someone you know (e.g., friend, family member, work colleague) shared something positive about any of these brands in the last [TIMEFRAME]? Please tick as many responses as needed."

**Q2 — Received negative** (MR by brand): \> "Has someone you know (e.g., friend, family member, work colleague) shared something negative about any of these brands in the last [TIMEFRAME]? Please tick as many responses as needed."

**Q3 — Shared positive** (MR by brand): \> "Have you shared something positive about any of these brands in the last [TIMEFRAME] to people you know (e.g., friends, family members, work colleagues)? Please tick as many responses as needed."

**Q4 — Shared positive frequency** (per brand from Q3, pull-down 1–5+): \> "On how many occasions have you shared something positive about each brand in the last [TIMEFRAME]? Please put a response for each brand."

**Q5 — Shared negative** (MR by brand): \> "Have you shared something negative about any of these brands in the last [TIMEFRAME] to people you know? Please tick as many responses as needed."

**Q6 — Shared negative frequency** (per brand from Q5, pull-down 1–5+): \> "On how many separate occasions have you shared something negative about each brand in the last [TIMEFRAME]? Please put a response for each brand."

-   Brand list from the awareness/attribute list
-   "None of these" anchored at end for Q1–Q3, Q5
-   Timeframe consistent with category target timeframe

**Feeds:** WOM element exclusively.

### Optional Battery: DBA

**Scope:** Brand-level (all respondents, not category-specific). **Questions:** Two per asset (fame + attribution). \~2 minutes for 8–12 assets. **Condition:** Only collected if `elements.dba = true`.

See [Element 5.5](#55-dba-distinctive-brand-assets) for full question wording and programming notes.

### Survey time budget

| Battery | Questions | Est. time | Notes |
|----|----|----|----|
| Screener + demographics | 5–8 | 2.0 min |  |
| Core 1: Brand Awareness (all qualified cats) | 1/cat | 0.5–1.0 min | Depends on number of qualified categories |
| Core 2: Brand Attributes/CEPs (focal only) | 15–20 screens | 3.5–5.0 min | **The lever.** 15 = comfortable, 20 = tight. |
| Core 3: Brand Attitude (focal only) | 1 grid + OE | 1.0 min |  |
| Core 4: Category Buying (focal only) | 1 | 0.5 min |  |
| Core 5a: Brand Pen — full (focal only) | 2–3 | 1.0 min |  |
| Core 5b: Brand Pen — light (non-focal) | 1/cat | 0.5–1.0 min |  |
| **Core total** |  | **9.0–11.5 min** |  |
| Optional: WOM | 6 | 2.0 min |  |
| Optional: DBA | varies | 2.0–4.0 min | 8–12 assets |
| Buffer (page loads, intros, mobile overhead) |  | 1.0–1.5 min |  |

**Typical configurations:** - Core only (15 CEPs): \~11 min. Comfortable. - Core + WOM (15 CEPs): \~13 min. Feasible. - Core + WOM + DBA (15 CEPs, 8 assets): \~15.5 min. At the limit. - Core + WOM (20 CEPs): \~15 min. Tight.

------------------------------------------------------------------------

## 4. Multi-Category Routing

### The constraint

The CEP matrix (Core Battery 2) is 15–20 screens per category at \~15 seconds each. Running it for multiple categories per respondent is not feasible within a 15-minute survey. Everything else in the CBM battery is lightweight per category.

### Routing logic

```         
SCREENER (all respondents, n=full sample)
├── "Which of these categories have you bought in the last [timeframe]?"
├── MR across ALL study categories
├── Qualifies respondent for 1...n categories
└── Gives: CATEGORY PENETRATION for full sample
    ↓
CATEGORY ASSIGNMENT (invisible to respondent)
├── System assigns ONE focal category for the full CBM battery
├── Assignment methods (configurable):
│   ├── balanced   — random, ensures ~equal n per category
│   ├── quota      — guarantees minimum n per category
│   └── priority   — over-samples priority categories via weights
└── Transition text: "Now we'd like to focus on [CATEGORY] in more detail."
    ↓
BRAND AWARENESS (all qualified categories — lightweight)
├── One MR screen per qualified category (~15 sec each)
├── Asked BEFORE the focal category CEP matrix (clean awareness data, no priming)
└── Gives: AWARENESS across all categories for most respondents
    ↓
FULL CBM BATTERY (focal category only)
├── CEP Matrix (15–20 screens)
├── Brand Attitude (grid + rejection OE)
├── Category Buying (frequency)
└── Brand Penetration — full version (bought + timeframe + count)
    ↓
BRAND PENETRATION LIGHT (non-focal qualified categories)
├── One MR screen per non-focal category (~20 sec each)
├── "Which brands have you bought?" only — no frequency, no tenure
└── Gives: BASIC PENETRATION for Portfolio element
    ↓
OPTIONAL BATTERIES (WOM, DBA — brand-level, not category-specific)
```

### Sample distribution

For a study with n=1,200 and 4 categories with balanced assignment:

| Data layer | Scope | Approx. n per category | Adequate for |
|----|----|----|----|
| Category penetration | All categories, all respondents | 1,200 | Portfolio |
| Brand awareness | All qualified categories | \~600–900 (varies by cat penetration) | Portfolio, Funnel |
| Full CEP matrix | Focal category only | \~300 | MA, D&B, CEP TURF |
| Brand attitude | Focal category only | \~300 | Funnel, D&B |
| Full brand penetration | Focal category only | \~300 | Funnel, Repertoire |
| Light brand penetration | Non-focal qualified categories | \~600–900 | Portfolio |
| WOM, DBA | Brand-level, all respondents | 1,200 | WOM, DBA |

### Sample adequacy at n=300 per category

-   **MMS/MPen/NS headline metrics:** Stable estimates with reasonable CIs.
-   **CEP × brand matrix cells:** Interpretable. CIs on individual cells ±5–8pp at typical linkage rates.
-   **Per-brand funnel stages:** Adequate for brands with ≥20% awareness (\~60+ respondents at the brand level). Brands below 15% awareness will have shaky data — flag in output.
-   **Derived importance (D&B):** Adequate with catdriver regression approach. Too thin for simple cross-tab buyer-vs-nonbuyer on small brands.

### Priority weighting (optional)

If a study has a flagship category, assignment weights can over-sample it:

``` yaml
routing:
  focal_assignment: "priority"
  priority_weights:
    "Frozen Vegetables": 0.35    # ~420 respondents
    "Ready Meals": 0.25          # ~300 respondents
    "Sauces": 0.20               # ~240 respondents
    "Snacks": 0.20               # ~240 respondents
```

------------------------------------------------------------------------

## 5. Element Catalogue

Each element is documented with five sections: 1. **Why this element exists** — the business question it answers 2. **What you get** — outputs, metrics, derived measures 3. **Required batteries** — which data it consumes (and any element-specific questions) 4. **Visualisations** — chart types, annotation patterns, anti-patterns 5. **Real-world notes** — survey cost, sample requirements, pitfalls, pairings

### 5.1 Funnel

#### Why this element exists

The brand funnel answers the oldest diagnostic question in brand measurement: where does a brand lose people relative to competitors, and is the loss pattern where we think it is?

In the CBM architecture, the funnel is a **derived view** — no dedicated funnel questions. Stages are mapped from core CBM data. This is methodologically superior to a traditional sequential funnel because:

-   The 5-level attitude scale replaces binary consideration with a richer attitudinal picture
-   No pipe dependency between questions — a programming error at one stage doesn't destroy downstream stages
-   Saves \~2 minutes of survey time (no separate consideration or preferred-brand questions)
-   Rejection is captured explicitly (attitude code 4) rather than hidden inside "doesn't consider"

**Methodological position (surfaced in About section):** - Funnels are diagnostic snapshots, not behavioural models (Romaniuk) - Most variation in conversion rates is a function of brand size — Double Jeopardy (Sharp) - The funnel does NOT measure flow over time, identify causes of conversion weakness, or predict future behaviour

#### What you get

**Stage derivation from CBM data:**

| Funnel stage | CBM source | Derivation |
|----|----|----|
| Aware | BRANDAWARENESS | Direct: selected at awareness question |
| Positive disposition | BRANDATT1 codes 1–3 | Love + Prefer + Would-buy-if-no-choice |
| Bought in period | BRANDPEN target timeframe | Direct: bought in target period |
| Primary brand | BRANDATT1 code 1 OR BRANDPEN most-frequent | Configurable: attitudinal or behavioural definition |

**Metrics, per brand, per category:** - Aided Awareness (%) - Positive Disposition (%) — attitude codes 1–3 combined - Decomposed: Love (%), Prefer (%), Ambivalent-buyer (%) - Active Rejection (%) — attitude code 4 - No Opinion (%) — attitude code 5 - Bought in Period (%) - Primary Brand (%) - Stage-to-stage conversion ratios (Aware → Disposition, Disposition → Bought, Bought → Primary) - 95% CIs on every metric (via `confidence` module) - Significance tests on all cross-brand comparisons (via `tabs` module)

**Comparative views:** - Focal brand vs named competitors (top 5 by awareness) - Focal brand vs category average (excluding focal brand to avoid self-confounding) - Conversion leak index per stage-pair: focal brand's conversion minus category median - Per-segment overlay when audience segments are defined

**Outputs:** - HTML section: 3 charts per category (funnel bar with attitude decomposition, conversion leak dot plot, conditional segment small-multiples) - Excel: brand × stage matrix, attitude decomposition, conversion matrix, CIs - CSV: long-format stage data - Tracker-ready metric IDs for wave-over-wave integration

#### Required batteries

Core batteries only: Brand Awareness + Brand Attitude + Brand Penetration. No additional questions.

#### Visualisations

**Primary chart: Funnel bar with attitude decomposition**

Horizontal bars, one row per brand. The aware base decomposes into five attitude segments (stacked sub-bar within the row), with Bought and Primary as separate narrower bars.

```         
              Aware    Attitude decomposition            Bought  Primary
IPK        ┃█████████┃ ████ ██████ ████ ░░ ▒          ┃████████┃████   ┃
               85%      18%  32%   25%  8% 2%            48%     18%

           Love ████  Prefer ██████  Would-buy ████  Reject ░░  None ▒

Comp A     ┃████████ ┃ ██ ████████ ████████ ░░░ ▒    ┃██████  ┃██     ┃
               80%      8%  35%    28%     7%  2%       38%     10%
```

**Colour discipline:** - Focal brand: saturated brand primary colour - Competitors: desaturated grey scale - Attitude decomposition: sequential single-hue gradient (darkest = Love, lightest = Would-buy). Distinct muted colour for Reject. Lightest for No Opinion. - Category average: dashed mid-grey reference line

**Headline annotation (finding-led, auto-generated):** Example: *"IPK has the category's highest awareness (85%) but the shallowest love base — only 18% say 'favourite' vs 24% for Comp A. The opportunity is converting the 25% who would buy IPK 'if no other option' into active preference."*

**Secondary chart: Conversion leak dot plot (Cleveland)**

Per stage-pair, all brands on a single horizontal axis showing conversion %. Focal brand saturated dot, others grey. Category median reference line. Direct-labelled gap.

```         
Trial → Primary conversion, by brand

    20%         30%         40%         50%         60%
     │───────────│───────────│───────────│───────────│
                        ●─┐  │   ○        ○       ○
                        │ │  │Focal: 36%
                     Comp│B  │Category median: 42%
                        │29%│
                       leak gap: −6pp
```

Only surfaces gaps that are statistically significant via `tabs` module.

**Tertiary chart: Segment small multiples (conditional)**

If audience segments are defined, reproduce the primary funnel bar as a small-multiple grid (one panel per segment). Focal brand kept saturated in every panel. Only render if ≥3 segments and segment sample sizes pass n≥75 per stage.

**Anti-patterns (codified):** - Inverted triangle / "money funnel" (width implies volume; no comparison capability) - Five-plus brands on a single stacked bar - Pie charts of stage composition - Any chart without base sizes visible - Rainbow-coloured multi-brand bars

#### Real-world notes

-   **"Would buy if no choice" is diagnostic gold.** The ambivalent middle — people who haven't rejected the brand but don't actively want it. In EBI terms, these are the easiest growth targets: mentally available enough to consider the brand but not given a reason to prefer it. The funnel element should call this out explicitly.
-   **Rejection rate is a finding, not noise.** Traditional funnels hide rejection inside "doesn't consider". The attitude scale surfaces it. A brand with 15% active rejection has a different problem to one with 2% rejection and 40% "no opinion".
-   **Derivation transparency.** The About section must state that funnel stages are derived from attitude and buying data, not from sequential funnel questions. This is better (richer, no pipe dependency) but clients used to traditional funnels should understand the mapping.
-   **Base sizes:** n≥75 per brand per stage for stable conversion ratios. Brands below \~15% awareness in a category will have shaky data — flag visually (muted dot + "low base" badge), do not suppress.
-   **Pairings:** Mental Availability (MPen explains upper-funnel size differences), Drivers & Barriers (explains why people sit in each attitude bucket — cross-linked in HTML), Portfolio (conversion rates feed quadrant logic), Tracker (all funnel metrics are primary wave-over-wave diagnostics).

------------------------------------------------------------------------

### 5.2 Mental Availability

#### Why this element exists

Mental availability — whether a brand comes to mind in category buying situations — is the single strongest predictor of brand choice in the EBI evidence base. A brand that is mentally available to more buyers, in more buying situations, wins more often. This is not a theory preference; it is an empirical pattern observed across hundreds of categories and decades of data.

Mental availability is measured through Category Entry Points (CEPs): the situations, needs, occasions, and motivations that trigger category buying. A brand's mental availability is the sum of its linkages to CEPs across category buyers.

This element is the analytical centrepiece of the brand module. Everything else is secondary to it in the EBI framework.

#### What you get

**Headline metrics, per brand, per category:**

-   **Mental Penetration (MPen):** % of category buyers who link the brand to at least one CEP. The brand's mental reach. *"How many people think of us at all?"*
-   **Network Size (NS):** Average number of CEPs linked to the brand, among those who link at least one. The brand's mental depth. *"Among people who think of us, in how many situations do they think of us?"*
-   **Mental Market Share (MMS):** The brand's share of all brand–CEP links in the category. MMS = (brand's total CEP links) / (all brands' total CEP links). The headline metric. *"What share of category thinking do we own?"*

**CEP-level metrics:**

-   **CEP × brand matrix:** For each CEP, what % of category buyers link it to each brand. The raw association data — the richest analytical asset.
-   **CEP penetration ranking:** Which CEPs have the highest total linkage across all brands? The "biggest" entry points in the category.
-   **Brand-specific CEP profile:** For the focal brand, which CEPs are strongest and weakest? Sorted by focal brand's linkage rate.

**Brand image attributes** (from the 30–40% non-CEP statements in the matrix): - Same matrix structure, reported as a separate sub-view. These are perception items ("good value for money", "high quality") rather than entry points ("when I want a quick meal").

**CEP TURF** (optional sub-view, `cep_turf: true` in config): - Reach optimisation: what combination of CEPs maximises the focal brand's mental reach? - Answers: *"If we can only own 5 CEPs in our communications, which 5 reach the most unique buyers?"* - Uses the TURF engine (refactored from `maxdiff` into `shared/`) - Output: reach curve (cumulative % of category buyers reached as CEPs are added), optimal sequence identified

**Outputs:** - HTML section: MMS league chart, MPen × NS diagnostic scatter, CEP × brand heat strip, CEP TURF curve (conditional) - Excel: full brand × CEP matrix with %, MMS/MPen/NS table, TURF results - CSV: long-format CEP linkage data - Tracker-ready metric IDs for all headline metrics

#### Required batteries

Core Battery 2 (Brand Attributes / CEP Matrix). Also requires Core Battery 1 (Brand Awareness) for aware-base context.

#### Visualisations

**Primary chart: MMS League (Cleveland dot plot)**

One horizontal axis showing Mental Market Share (%). One dot per brand. Focal brand saturated, all others desaturated grey. Direct-labelled.

```         
Mental Market Share (% of all category brand–CEP links)

  0%          5%          10%         15%         20%
   │───────────│───────────│───────────│───────────│
                                       ●  Focal: 17.2%
                                  ○  Comp A: 14.8%
                            ○  Comp B: 11.3%
                        ○  Comp C: 9.7%
                     ○  Comp D: 8.1%
              ○○○○○  remaining brands: 2–5% each
```

This is the single most important chart in the entire report. It must be prominent, clean, and immediately readable.

**Annotation:** *"[Focal brand] leads the category in mental market share at 17.2%, 2.4pp ahead of Comp A. This gap is [significant / not significant] at 95% confidence."*

**Secondary chart: MPen × NS diagnostic scatter**

X-axis = Mental Penetration (%). Y-axis = Network Size (avg CEPs). Each brand is a dot. Focal brand saturated, rest grey. Reference lines at category medians.

Most brands cluster on a diagonal (Double Jeopardy: bigger brands have higher MPen AND NS). Brands **off** the diagonal are diagnostic: - High MPen / low NS = "broad but shallow" — many people think of us, but only in narrow situations - Low MPen / high NS = "narrow but deep" — fewer people, but those who do associate us with many situations (niche strength)

**Annotation:** Finding-led. Example: *"[Focal brand]'s mental reach (MPen 62%) is category-leading, but network size (3.2 CEPs) is below the fitted line — suggesting broad awareness but narrow situational associations. CEP TURF analysis identifies which entry points to target."*

**Tertiary chart: CEP × brand heat strip**

Sorted dot plot or heat strip. Rows = CEPs (sorted by focal brand's linkage rate, strongest at top). Columns = brands. Cell intensity shows linkage %.

-   **Single-hue sequential colour scale** (not a rainbow heatmap). Darkest = highest linkage.
-   Cell text shows % for readability
-   Non-significant cells masked (greyed or blanked)

**CEP TURF chart (conditional):**

Reach curve. X-axis = number of CEPs in combination. Y-axis = cumulative % of category buyers reached. Steep early rise, diminishing returns.

```         
100%│                              ●────●────●
    │                        ●──●
 80%│                  ●──●
    │            ●──●
 60%│      ●──●
    └──────────────────────────────────
     1    2    3    4    5    6    7
```

**Annotation:** *"[Focal brand] reaches 78% of category buyers through just 5 CEPs. Communication strategy should prioritise: [1] Quick weeknight meal, [2] Family enjoys, [3] Healthy option, [4] Budget-friendly, [5] Entertaining guests."*

#### Real-world notes

-   **MMS is the headline but MPen is the lever.** In EBI theory, growing mental penetration (getting more people to think of you at all) is almost always more productive than deepening network size. Report both, but frame MPen as the primary growth diagnostic.
-   **Double Jeopardy is expected, not news.** Bigger brands will have higher MMS, MPen, AND NS. The diagnostic value is in deviations from the pattern.
-   **CEP count is the survey-length lever.** 15 CEPs × \~15 sec = 3.75 min. 20 CEPs = 5 min. Recommendation: 15 CEPs + 5 brand image attributes = 20 screens.
-   **Attribute wording matters enormously.** Romaniuk's guidance: simple, concrete, situation-based for CEPs. No comparatives, no superlatives, no double-barrelled statements. Bad CEP wording produces useless data.
-   **Non-CEP attributes report separately.** Brand image attributes use the same matrix data but answer a different question: "What do people think about us?" vs "When do people think of us?"
-   **CEP TURF is a communication-planning tool, not a brand-health metric.** Position as strategic recommendation, not diagnostic. Some clients won't need it.
-   **Pairings:** Funnel (MPen explains upper-funnel size), Drivers & Barriers (which CEPs differentiate buyers), Portfolio (MMS feeds cross-category strength axis), Tracker (MMS/MPen/NS are primary wave-over-wave metrics).

------------------------------------------------------------------------

### 5.3 Repertoire

#### Why this element exists

Repertoire analysis answers: *"How many brands does a category buyer actually use, and how is their buying distributed?"*

In EBI theory, most category buyers are "polygamous loyals" — they buy from a repertoire of 2–5 brands with varying frequency. True single-brand loyalty is rare outside some durable/service categories. This is one of the most consistently replicated findings in marketing science.

For a portfolio brand, repertoire analysis reveals: - How many brands compete for the focal brand's buyers' wallets? - What is the focal brand's share of requirements among its own buyers? - Is the focal brand a repertoire brand (bought alongside others) or a primary brand (dominates its buyers' category spend)? - For DUR/SERV categories: what does the switching pattern look like?

#### What you get

**Per category:** - Average repertoire size (mean + distribution across buyers) - Share of requirements: among focal brand buyers, what % of their category purchases go to the focal brand? (TRANS only — frequency data from BRANDPEN Q3 enables this) - Sole loyalty rate: % of focal brand buyers who bought the focal brand exclusively in the target period - Shared loyalty profile: among focal brand buyers who also buy other brands, which brands co-occur most? - Category buyer classification: light / medium / heavy (from Category Buying) - For DUR/SERV: tenure distribution, prior brand switching matrix

**Cross-category** (feeds Portfolio): - Cross-category buying overlap: do focal-brand buyers in one category also buy in another?

**Outputs:** - HTML section: 3–4 charts per category - Excel: repertoire size distribution, share of requirements table, overlap matrix - CSV: buyer-level repertoire data

#### Required batteries

Core batteries: Brand Penetration (full — target timeframe + frequency for TRANS; ownership + tenure + prior brand for DUR/SERV) + Category Buying. No additional questions.

#### Visualisations

**Primary chart: Repertoire size distribution**

Horizontal bar chart showing % of category buyers buying 1, 2, 3, 4, 5+ brands in the target period.

```         
Brands bought (past 3 months)

  1 brand     ████████████████████████  34%
  2 brands    ████████████████████      30%
  3 brands    ████████████              18%
  4 brands    ██████                    10%
  5+ brands   ████                       8%

  Mean repertoire: 2.3 brands
```

Simple horizontal bar. No colour complexity needed — this is a distribution, not a comparison.

**Secondary chart: Share of requirements (TRANS) / Switching flow (DUR/SERV)**

For TRANS: horizontal bar chart showing mean share of requirements per brand, among that brand's buyers. Focal brand saturated, rest grey. Sorted by share.

For DUR/SERV: alluvial flow showing prior brand → current brand switching. Width proportional to switcher count. Focal brand flows saturated.

**Tertiary chart: Repertoire overlap dot plot**

Which brands share buyers with the focal brand? Sorted by overlap %.

```         
Brand overlap with [focal brand] buyers

Comp A    ████████████████████████████  45%
Comp D    ████████████████████          30%
Comp B    ██████████████                22%
Comp C    ████████                      12%
```

#### Real-world notes

-   **Repertoire size is a category metric, not a brand metric.** Average repertoire is driven by category dynamics (frequency, number of viable options, switching costs), not individual brand strategies.
-   **Share of requirements is the brand-level metric.** Low share + high buyer count = "many people buy us a little". High share + low buyer count = "few people, but committed".
-   **Sole loyalty is rarer than clients expect.** In FMCG, sole loyalty rates of 10–20% are normal. Set expectations in the About section.
-   **Small base warning for overlap analysis.** With \~300 per category, per-brand buyer bases may be 50–150. Overlap at the brand-pair level gets noisy. Flag low-base pairs.
-   **Pairings:** Funnel (repertoire size contextualises "preferred brand"), Mental Availability (MPen predicts repertoire inclusion), Portfolio (cross-category overlap is a portfolio strategic input).

------------------------------------------------------------------------

### 5.4 Drivers & Barriers

#### Why this element exists

Funnel shows *where* people drop off. Mental Availability shows *how much* mental presence a brand has. Drivers & Barriers answers *why* — what makes people choose or reject a brand?

In the CBM architecture, this element is almost entirely derived. Positive drivers come from the CEP × brand matrix crossed with buying behaviour: which attributes and CEPs differentiate buyers from non-buyers? Barriers come from explicit rejection data (Brand Attitude code 4 + the open-end follow-up).

The derived approach is methodologically stronger than asking "why do you buy Brand X?" directly. Self-reported reasons are unreliable (people post-rationalise). Statistical derivation reveals the attributes that actually predict buying, not the ones people claim matter.

#### What you get

**Derived importance analysis** (via `catdriver` module): - For each CEP and brand image attribute: the strength of association with buying the focal brand vs not - Importance ranking: which attributes most strongly predict focal brand purchase? - Performance gap: focal brand's linkage rate vs the derived importance of each attribute - Competitive advantage mapping: which attributes does the focal brand own that also drive purchase?

**Explicit barrier analysis:** - Rejection rate per brand (from Brand Attitude code 4) - Rejection reason themes (coded from BRANDATT2 open-end) - Rejection comparison: focal brand's rejection themes vs competitors

**Importance × Performance output:** - Per attribute: derived importance score + focal brand's performance (linkage %) - Gap analysis: high-importance attributes where the focal brand under-performs - Quadrant classification: Strengthen / Maintain / Deprioritise / Monitor

**Outputs:** - HTML section: I×P quadrant, competitive dumbbell, rejection theme bars - Excel: importance scores, performance gaps, rejection code counts - CSV: attribute-level detail

#### Required batteries

Core batteries: Brand Attributes/CEPs + Brand Penetration + Brand Attitude (including rejection OE). No additional questions.

**Optional enhancement:** If `catdriver` module is activated, derived importance uses SHAP values or regression coefficients (more rigorous, handles non-linear patterns). Without `catdriver`, importance is approximated by the buyer-vs-nonbuyer linkage differential (simpler but less robust to confounders). Recommend activating `catdriver` for any deployment with ≥12 CEPs.

#### Visualisations

**Primary chart: Importance × Performance quadrant**

2×2 scatter. X-axis = derived importance. Y-axis = focal brand's performance (linkage %). Each dot is a CEP or attribute, directly labelled.

```         
                     High importance
                          │
     STRENGTHEN           │         MAINTAIN
     (priority gaps)      │         (protect these)
  ● "Budget-friendly"     │      ● "Quick meal"
  ● "Healthy option"      │      ● "Family enjoys"
                          │
  ────────────────────────┼──────────────────────
                          │
     DEPRIORITISE         │         MONITOR
     (low stakes)         │         (latent strength)
  ● "Premium"             │      ● "Entertaining"
  ● "Innovative"          │
                          │
                     Low importance
```

Quadrant lines at category medians (not arbitrary 50/50). Annotate the Strengthen quadrant — that's where the action is.

**Secondary chart: Competitive dumbbell**

For the top 10 most important attributes: dumbbell showing focal brand's linkage vs category leader's linkage. Sorted by gap size.

```         
Attribute                    Focal      Leader     Gap
"Budget-friendly"            ○──────────●          −18pp (Comp B leads)
"Healthy option"             ○────────●            −14pp (Comp B leads)
"Quick weeknight meal"       ●────○                +8pp  (Focal leads)
"Family enjoys"              ●──○                  +5pp  (Focal leads)
```

Focal brand dot saturated, leader dot grey. Gap annotation direct-labelled.

**Tertiary chart: Rejection themes (horizontal bar)**

For brands with ≥30 rejection open-ends coded: horizontal bar chart of theme frequency.

#### Real-world notes

-   **Derived importance \> stated importance.** Do NOT ask "how important is each attribute?" as a survey question. It wastes time and produces flat, undifferentiated data. Importance is revealed by behaviour, not stated.
-   **The catdriver integration is the quality differentiator.** SHAP values identify non-linear importance patterns. Recommend activating for any deployment with ≥12 CEPs.
-   **Rejection open-end coding:** v1 requires human coding. Auto-coding (LLM-assisted) is a v1.1 enhancement. The module accepts pre-coded data.
-   **Small base risk on rejection.** At 5–15% rejection per brand and n=300 per category, the open-end base for a single brand may be 15–45. Enough for theme identification, not for precise frequencies. Report themes descriptively.
-   **Pairings:** Funnel (D&B answers the "why" for every funnel gap — cross-linked in HTML), Mental Availability (the CEP matrix IS the input), Repertoire (driver profile may differ for sole-loyal vs shared-loyal buyers — optional cut).

------------------------------------------------------------------------

### 5.5 DBA (Distinctive Brand Assets)

#### Why this element exists

Brand assets — logos, colours, characters, shapes, taglines, sonic cues, packaging elements — are the sensory triggers that connect marketing activity to the brand in buyer memory. Effective assets let a brand be recognised without needing to say its name. Ineffective assets burn marketing spend on executions that don't link back to the brand.

Romaniuk's DBA framework (*Building Distinctive Brand Assets*, 2018) measures two dimensions: - **Fame:** What proportion of category buyers recognise the asset? - **Uniqueness:** Among those who recognise it, what proportion correctly attribute it to the focal brand?

The 2×2 produces four quadrants with direct strategic implications. This is one of Romaniuk's most actionable frameworks.

DBA runs at **brand level**, not per-category. An asset belongs to the brand regardless of which category a consumer encounters it in.

#### What you get

**Per asset:** - Fame (%) — recognition rate among category buyers - Uniqueness (%) — correct focal-brand attribution among recognisers - Quadrant position:

|   | High Uniqueness (\>threshold) | Low Uniqueness (≤threshold) |
|----|----|----|
| **High Fame** | **Use or Lose** — widely known AND distinctly ours. Use consistently. | **Avoid Alone** — widely known but not distinctly ours. Needs brand-name context. |
| **Low Fame** | **Invest to Build** — distinctly ours but not widely known. Worth building. | **Ignore or Test** — neither known nor distinctive. Replace or redesign. |

-   Fame and Uniqueness thresholds default to 50% / 50% but are configurable (`dba.fame_threshold`, `dba.uniqueness_threshold`)
-   Competitive asset comparison (if competitor assets are tested alongside)
-   Wave-over-wave trajectory (wave 2+): has the asset moved quadrants?

**Outputs:** - HTML section: DBA Grid (2×2 scatter), asset ranking bars - Excel: asset × metric table, quadrant classification - Tracker-ready metric IDs

#### Required batteries

**DBA battery (own questions, not in core CBM). Only collected if `elements.dba = true`.**

Per asset, two questions:

**Q_FAME:** Show the asset (image, sound clip, phrase) WITHOUT the brand name. \> "Have you seen [or heard] this before?" \> Yes / No / Not sure

**Q_UNIQUE** (shown if Q_FAME = Yes or Not sure): \> "Which brand do you think this belongs to?" \> Open-ended text field

**Programming notes:** - Each asset is its own screen (asset stimulus + fame question; then attribution if recognised) - Asset presentation order randomised per respondent - Assets MUST be shown without any brand identification — strip brand names from logos, show colours without context, play audio without branding - "Not sure" at fame STILL gets the uniqueness question (uncertain familiarity is a finding) - Open-ended attribution recommended over forced-choice brand lists (Romaniuk: forced-choice inflates uniqueness scores through guessing). Coded post-fieldwork against brand list + "Don't know" + "Other".

**Survey time:** \~20–30 sec per asset. At 8 assets ≈ 3–4 min. At 12 assets ≈ 4–6 min.

**Typical asset list for a food brand:** logo, primary colour, packaging shape/design, tagline (if exists), character/mascot (if exists), distinctive visual advertising elements. 6–10 assets is typical for wave 1.

#### Visualisations

**Primary chart: DBA Grid (2×2 scatter)**

X-axis = Uniqueness (%). Y-axis = Fame (%). Each dot is an asset, directly labelled. Dot size by recognition base (n). Quadrant lines at configured thresholds. Action-verb quadrant labels.

```         
Fame (%)
100│
   │   USE OR LOSE          │    AVOID ALONE
   │                        │
   │   ● Logo (88%, 72%)    │    ● Green colour (75%, 34%)
   │                        │
   │   ● Tagline (62%, 68%) │
 50│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─
   │                        │
   │   INVEST TO BUILD      │    IGNORE OR TEST
   │                        │
   │   ● New mascot         │    ● Sonic logo (12%, 22%)
   │     (28%, 81%)         │
  0└────────────────────────┴───────────────────────── Uniqueness (%)
   0                       50                        100
```

**Annotation:** *"[Focal brand]'s logo is the strongest asset — high fame (88%) and high uniqueness (72%). The green colour is widely recognised (75%) but poorly attributed (34%) — avoid using it without the logo. The new mascot shows early promise: low fame but high uniqueness — worth investing in."*

**Secondary chart: Asset ranking bars**

Dual horizontal bar chart. Left side = Fame (%), right side = Uniqueness (%). Assets sorted by Fame descending.

#### Real-world notes

-   **Open-ended attribution is slower to process but more honest.** Forced-choice inflates uniqueness. Worth the coding effort.
-   **Asset quality varies enormously.** A DBA audit revealing "you have no distinctive assets beyond your logo" is a genuinely valuable finding.
-   **50% thresholds are guidelines, not science.** Low-involvement categories may need 40%; dominant-brand categories may need 60%. Make configurable.
-   **DBA is expensive in survey time.** At 8–12 assets × 25 sec = 3–5 min, this is 20–33% of a 15-minute budget. For tight surveys, DBA may be the first element to defer.
-   **Competitor assets are a bonus, not a requirement.** Testing focal-brand assets alone produces a complete audit. Competitor assets add the competitive dimension but double the asset count.
-   **Pairings:** Mental Availability (DBA assets are the executional bridge — how advertising links to the brand in memory), Tracker (DBA trajectory over waves is one of the most actionable tracking metrics).

------------------------------------------------------------------------

### 5.6 Portfolio

#### Why this element exists

For multi-category brands, the strategic question above any single category is: *"Where should we focus?"* Portfolio analysis maps the focal brand's position across its categories to identify strengths, opportunities, and deprioritisation candidates.

Three sub-views, all from the same data, each config-activatable. Only available when the study has 2+ categories.

#### What you get

**Portfolio-level metrics per category:** - Brand awareness (from Core Battery 1 — asked across all qualified categories) - Mental Market Share (from Core Battery 2 / MA element — focal category only, so available only for categories with full-battery respondents) - Brand penetration — target period (from Core Battery 5 full + light) - Category buyer base size (from screener)

**Sub-views:**

**6a. Portfolio Map:** Focal brand's position in each category plotted on two axes (configurable; default: X = category penetration, Y = brand penetration or MMS). Exploratory view.

**6b. Priority Quadrants:** Same data with quadrant logic: - High penetration / High MMS = **Defend** (stronghold) - High penetration / Low MMS = **Improve** (under-performing, losing mindshare) - Low penetration / High MMS = **Expand** (opportunity — mental strength not converting) - Low penetration / Low MMS = **Evaluate** (worth resourcing?)

**6c. Category TURF:** Optimal category combination for maximum unique consumer reach. Uses `shared/turf_engine`. Answers: *"If we can only invest in 3 of our 5 categories, which 3 reach the most unique consumers?"*

**Outputs:** - HTML section: map scatter, quadrant scatter, TURF curve - Excel: category-level metrics table, quadrant classification, TURF results - CSV: per-category long-format

#### Required batteries

Core batteries across multiple categories: Brand Awareness (all qualified) + Brand Penetration (full for focal, light for non-focal). MMS axis requires MA element to have run for each category. No additional questions.

Requires `multi_category: true` in study config (2+ categories).

#### Visualisations

**Portfolio Map: bubble scatter**

Each bubble is a category. Configurable axes (default: X = category penetration, Y = focal brand's MMS or brand penetration). Bubble size = category buyer base.

Direct-labelled bubbles. Reference lines at portfolio medians.

**Priority Quadrants:** Same scatter with light background colour bands per quadrant. Action labels in quadrant corners.

**Category TURF: reach curve**

X-axis = number of categories. Y-axis = cumulative % of consumers reached. Optimal combination highlighted.

#### Real-world notes

-   **Axis choice matters.** Default (penetration × MMS) is sensible but not universal. Some clients want penetration × share-of-wallet, or awareness × trial-rate. Make axes configurable.
-   **Quadrant labels are recommendations, not verdicts.** "Evaluate" means "investigate further", not "exit". Soften in About section.
-   **Category TURF is most useful with 5+ categories.** With 4 categories, the optimiser has limited combinatorial space. Still worth running (cheap computationally).
-   **MMS axis depends on focal-category assignment.** If a category had fewer assigned respondents (e.g., n=240 via priority weighting), MMS estimates for that category will have wider CIs. Flag this.
-   **Pairings:** Every per-category element feeds Portfolio. Funnel conversion rates, MMS, repertoire share can all serve as portfolio axes.

------------------------------------------------------------------------

### 5.7 WOM (Word-of-Mouth)

#### Why this element exists

Word-of-mouth is the most trusted form of marketing communication. Romaniuk includes WOM in the CBM template as a standard measurement because WOM levels correlate with brand growth — brands being talked about positively tend to be growing.

WOM answers: - Is the focal brand being talked about more or less than competitors? - Is the balance positive or negative? - Are the focal brand's buyers amplifiers (actively sharing) or passive (only receiving)? - Which brands have a WOM problem (disproportionately negative)?

#### What you get

**Per brand:** - Received positive WOM (% of category buyers) - Received negative WOM (%) - Shared positive WOM (%) - Shared negative WOM (%) - Shared positive frequency (mean occasions, among sharers) - Shared negative frequency (mean occasions, among sharers)

**Derived metrics:** - Net WOM balance: received positive minus received negative (and same for shared) - WOM amplification ratio: shared positive / received positive — brands where buyers actively advocate vs merely hear about - WOM intensity: frequency × incidence

**Outputs:** - HTML section: net WOM diverging bar, amplification dot plot - Excel: brand × WOM metric matrix - Tracker-ready metric IDs

#### Required batteries

WOM battery (6 questions). \~2 minutes. Only collected when `elements.wom = true`.

#### Visualisations

**Primary chart: Net WOM balance (diverging bar)**

Horizontal diverging bar. Positive extends right, negative extends left. One row per brand. Focal brand saturated, rest grey. Net balance labelled.

```         
           Negative ◄──────────┼──────────► Positive
                               │
Focal            ░░░  3%       │  ████████████  16%      Net: +13pp
Comp A            ░░  2%       │  ██████████    13%      Net: +11pp
Comp B        ░░░░░░  7%       │  ██████        8%       Net: +1pp
Comp C     ░░░░░░░░░  11%      │  █████         6%       Net: −5pp  ←
```

**Annotation:** *"[Focal brand] has the strongest positive WOM in the category (+13pp net). Comp C is the only brand with net-negative word-of-mouth."*

**Secondary chart: Amplification ratio (dot plot)**

Shared-positive / received-positive ratio per brand. Ratio \> 1 = buyers actively amplify; \< 1 = WOM is passively received.

#### Real-world notes

-   **WOM levels are typically LOW.** 5–15% of category buyers mention any brand in a given period. Per-brand bases will be small. CIs are critical.
-   **Negative WOM is rarer but louder.** Expect 2–8% negative vs 8–18% positive. Even slightly elevated negative WOM vs category norms signals a real problem.
-   **Frequency data is fragile.** The "how many occasions" question produces low-base, noisy estimates. Report as supporting, not headline.
-   **WOM is most diagnostic over time.** A single-wave snapshot establishes a baseline. Wave 2+ tracking is where WOM earns its keep — rising positive WOM signals brand momentum.
-   **Pairings:** Mental Availability (brands with rising WOM often show rising MMS in subsequent waves), Funnel (high positive WOM brands tend to have higher consideration rates).

------------------------------------------------------------------------

## 6. Config Architecture

### Two-file pattern

Follows the established Turas convention used by the tabs and tracker modules:

| File | Purpose | Pattern |
|----|----|----|
| **Brand_Config.xlsx** | Analysis settings — what to run, how to run it, output options | Setting/Value sheets + table sheets |
| **Survey_Structure.xlsx** | Data dictionary — what's in the data, what it means, what the labels are | Shared with tabs/tracker; extended for brand-specific content |

The Survey_Structure.xlsx is the single source of truth for data mapping. Multiple modules (brand, tabs, tracker) read from the same structure file. This avoids parallel definitions.

Both files use the standard Turas config utilities (`load_config_sheet()`, `get_config_value()`, typed getters from `shared/lib/config_utils.R`) and support auto-detect header row for branded Excel templates.

**Visual polish and inline documentation are mandatory.** The generated Excel templates must match the quality standard of existing Turas config templates (tabs, tracker): branded headers, colour-coded section dividers, help text rows with `[REQUIRED]` / `[Optional]` prefixes, inline explanations for every setting. An operator who has never used the module must be able to fill in the config from the Excel alone, without consulting external documentation. Comprehensive user manuals (operator guide) and technical documentation (architecture, function reference) are also required deliverables — see Project Plan Section 8.

### File 1: Brand_Config.xlsx

#### Settings sheet (Setting/Value format)

```         
─── STUDY ─────────────────────────────────────────────────
Setting                     Value
project_name                IPK Brand Health Wave 1
client_name                 IPK
study_type                  cross-sectional
wave                        1
data_file                   data/ipk_wave1.csv
sample_size                 1200

─── ROUTING ───────────────────────────────────────────────
focal_assignment            balanced
cross_category_awareness    Y
cross_category_pen_light    Y

─── ELEMENTS (Y = include, N = exclude) ───────────────────
element_funnel              Y
element_mental_avail        Y
element_cep_turf            Y
element_repertoire          Y
element_drivers_barriers    Y
element_dba                 N
element_portfolio           Y
element_wom                 Y

─── DBA (only if element_dba = Y) ─────────────────────────
dba_scope                   brand
dba_fame_threshold          0.50
dba_uniqueness_threshold    0.50
dba_attribution_type        open

─── WOM ───────────────────────────────────────────────────
wom_timeframe               3 months

─── COLOUR ────────────────────────────────────────────────
colour_focal                #1A5276
colour_focal_accent         #2E86C1
colour_competitor           #B0B0B0
colour_category_avg         #808080

─── OUTPUT ────────────────────────────────────────────────
output_dir                  output/ipk_wave1
output_html                 Y
output_excel                Y
output_csv                  Y
tracker_ids                 Y

─── REPORT ────────────────────────────────────────────────
report_title                IPK Brand Health
report_subtitle             Wave 1 Baseline
show_about_section          Y
```

All settings have sensible defaults. Element toggles default Y or N as shown but are overridable per project. Nothing is permanently locked — a project that wants funnel off and DBA on changes two lines.

`dba_attribution_type` defaults to `open` (open-ended text, coded post-fieldwork). Can be switched to `closed_list` (forced-choice from brand list) per project if the coding step is not feasible. Closed-list inflates uniqueness scores but eliminates post-fieldwork coding.

#### Categories sheet (table format)

| Category          | Type        | Timeframe_Long | Timeframe_Target | Focal_Weight |
|-------------------|-------------|----------------|------------------|--------------|
| Frozen Vegetables | transaction | 12 months      | 3 months         | 0.25         |
| Ready Meals       | transaction | 12 months      | 3 months         | 0.25         |
| Sauces            | transaction | 12 months      | 3 months         | 0.25         |
| Snacks            | transaction | 3 months       | 1 month          | 0.25         |

-   **Type:** `transaction` \| `durable` \| `service` — controls question wording variants and Brand Penetration structure
-   **Focal_Weight:** Only used when `focal_assignment = priority`. Must sum to 1.0 across categories. Ignored when `focal_assignment = balanced`.

#### DBA_Assets sheet (table format, only if element_dba = Y)

| AssetCode | AssetLabel   | AssetType | FilePath                      |
|-----------|--------------|-----------|-------------------------------|
| LOGO      | IPK Logo     | image     | assets/ipk_logo_unbranded.png |
| COLOUR    | Green colour | image     | assets/ipk_green_swatch.png   |
| TAGLINE   | Tagline      | text      | (text shown directly)         |
| MASCOT    | Character    | image     | assets/ipk_mascot.png         |

#### Insights sheet (table format, optional)

| Element | Section | Insight |
|----|----|----|
| funnel | Frozen Vegetables | IPK's consideration gap narrowed since the packaging refresh... |
| mental_avail | Ready Meals | The "quick meal" CEP dominates this category... |

#### Slides sheet (table format, optional)

| SlideTitle | Content | DisplayOrder |
|----|----|----|
| Strategic Implications | Key findings and recommended actions... | 1 |

### File 2: Survey_Structure.xlsx

Extends the existing tabs Survey_Structure pattern. Jess already knows this format.

#### Project sheet (Setting/Value)

| Setting      | Value                   |
|--------------|-------------------------|
| project_name | IPK Brand Health Wave 1 |
| data_file    | data/ipk_wave1.csv      |
| client_name  | IPK                     |
| focal_brand  | IPK                     |

#### Questions sheet (table format)

Maps every survey question to its CBM battery and category.

| QuestionCode | QuestionText | VariableType | Battery | Category |
|----|----|----|----|----|
| BRANDAWARE_FV | Which brands have you heard of? | Multi_Mention | awareness | Frozen Vegetables |
| BRANDATTR_FV_01 | Good for a quick weeknight meal | Multi_Mention | cep_matrix | Frozen Vegetables |
| BRANDATTR_FV_02 | Something the whole family enjoys | Multi_Mention | cep_matrix | Frozen Vegetables |
| BRANDATTR_FV_16 | Good value for money | Multi_Mention | attribute | Frozen Vegetables |
| BRANDATT1_FV | Brand attitude | Single_Mention | attitude | Frozen Vegetables |
| BRANDATT2_FV | Rejection reason | Open_End | attitude_oe | Frozen Vegetables |
| CATBUY_FV | Category purchase frequency | Single_Mention | cat_buying | Frozen Vegetables |
| BRANDPEN1_FV | Brands bought (long timeframe) | Multi_Mention | penetration | Frozen Vegetables |
| BRANDPEN2_FV | Brands bought (target timeframe) | Multi_Mention | penetration | Frozen Vegetables |
| BRANDPEN3_FV | Purchase frequency per brand | Rating | penetration | Frozen Vegetables |
| WOM_POS_REC | Received positive WOM | Multi_Mention | wom | ALL |
| WOM_NEG_REC | Received negative WOM | Multi_Mention | wom | ALL |
| WOM_POS_SHARE | Shared positive WOM | Multi_Mention | wom | ALL |
| WOM_POS_FREQ | Shared positive frequency | Rating | wom | ALL |
| WOM_NEG_SHARE | Shared negative WOM | Multi_Mention | wom | ALL |
| WOM_NEG_FREQ | Shared negative frequency | Rating | wom | ALL |
| DBA_FAME_LOGO | Have you seen this before? | Single_Mention | dba | ALL |
| DBA_UNIQUE_LOGO | Which brand does this belong to? | Open_End | dba | ALL |

**Battery codes:** `awareness`, `cep_matrix`, `attribute`, `attitude`, `attitude_oe`, `cat_buying`, `penetration`, `wom`, `dba`

**Category = ALL** for brand-level questions (WOM, DBA) that are not category-specific.

#### Options sheet (table format)

| QuestionCode | OptionText | DisplayText | DisplayOrder | ShowInOutput |
|----|----|----|----|----|
| BRANDATT1_FV | 1 | I love it / it's my favourite | 1 | Y |
| BRANDATT1_FV | 2 | It's among the ones I prefer | 2 | Y |
| BRANDATT1_FV | 3 | I wouldn't usually consider it, but I would if no other option | 3 | Y |
| BRANDATT1_FV | 4 | I would refuse to buy this brand | 4 | Y |
| BRANDATT1_FV | 5 | I have no opinion about this brand | 5 | Y |

#### Brands sheet (table format)

| Category          | BrandCode | BrandLabel   | DisplayOrder | IsFocal |
|-------------------|-----------|--------------|--------------|---------|
| Frozen Vegetables | IPK       | IPK          | 1            | Y       |
| Frozen Vegetables | MCCAIN    | McCain       | 2            | N       |
| Frozen Vegetables | FINDUS    | Findus       | 3            | N       |
| Ready Meals       | IPK       | IPK          | 1            | Y       |
| Ready Meals       | COMPA     | Competitor A | 2            | N       |

#### CEPs sheet (table format)

| Category          | CEPCode | CEPText                           | DisplayOrder |
|-------------------|---------|-----------------------------------|--------------|
| Frozen Vegetables | CEP01   | Good for a quick weeknight meal   | 1            |
| Frozen Vegetables | CEP02   | Something the whole family enjoys | 2            |
| Frozen Vegetables | CEP03   | When I want a healthy option      | 3            |

#### Attributes sheet (table format)

| Category          | AttrCode | AttrText                 | DisplayOrder |
|-------------------|----------|--------------------------|--------------|
| Frozen Vegetables | ATTR01   | Good value for money     | 1            |
| Frozen Vegetables | ATTR02   | High quality ingredients | 2            |

#### DBA_Assets sheet (table format, if DBA active)

| AssetCode | AssetLabel   | AssetType | FameQuestionCode | UniqueQuestionCode |
|-----------|--------------|-----------|------------------|--------------------|
| LOGO      | IPK Logo     | image     | DBA_FAME_LOGO    | DBA_UNIQUE_LOGO    |
| COLOUR    | Green colour | image     | DBA_FAME_COLOUR  | DBA_UNIQUE_COLOUR  |

### How modules share the Survey Structure

The Survey_Structure.xlsx is the shared data dictionary: - **Brand module** reads Brands, CEPs, Attributes, Questions (filtered by battery codes), Options - **Tabs module** reads Questions, Options (filtered to standard cross-tab variables) - **Tracker module** reads Questions (for metric mapping across waves) - A single project uses one Survey_Structure.xlsx; module-specific configs (Brand_Config.xlsx, Crosstab_Config.xlsx, Tracking_Config.xlsx) reference it

------------------------------------------------------------------------

## 7. Design Principles

Nine principles locked in Phase 4 Pass 1. All research-validated. These govern every visual output.

1.  **Clarity first** — 5-second rule. If the main finding isn't obvious in 5 seconds, redesign.
2.  **Headline states the finding** — not the chart label. "IPK's biggest opportunity is trial conversion" not "Funnel chart".
3.  **Subject-vs-field colour discipline** — focal brand saturated, competitors desaturated grey. Second accent reserved for deliberate comparator only. Sequential colour where no single subject exists.
4.  **Progressive depth** — one insight → one chart → layered detail. Not 12-chart dashboards.
5.  **Chart grammar, not chart variety** — 6–8 chart types mastered. No novelty charts.
6.  **Direct labelling beats legends** — label data points directly. Remove legends wherever possible.
7.  **Distribution over central tendency** — beeswarm/strip where respondent-level detail matters. Reveal variance, not just means.
8.  **Annotation is part of the chart** — first-class, not caption. Annotations are designed elements.
9.  **Honest data, transparent footing** — bases, significance flags, filters, and fieldwork dates visible on every chart.

### Anti-patterns (hard no)

-   Muddy heatmaps ("single most common failure mode in brand tracker output")
-   Radar/spider charts
-   Inverted-triangle funnels
-   Rainbow line charts
-   Pie charts with \>3 segments
-   Decimal-place false precision
-   Chart-junk brand styling
-   Any chart without base sizes

------------------------------------------------------------------------

## 8. Visual Reference Pack

### Craft reference (aspire to)

-   FT Visual Vocabulary / John Burn-Murdoch (FT)
-   The Pudding
-   Pew Research (+ their public ggplot2 package)
-   Bloomberg Billionaires index
-   Our World in Data
-   Economist Graphic Detail
-   FlowingData (Nathan Yau)

### Framework reference (adapt from)

-   Romaniuk DBA Grid (*Building Distinctive Brand Assets*)
-   Romaniuk CEP measurement (*How Brands Grow Part 2*, *Better Brand Health*)
-   Kantar BrandZ (interaction model only — not copying their visual language)
-   Binet & Field ESOV

### Typography

Must work identically across all modern browsers. Self-hosted Inter or Source Sans Pro with system-font fallback stack (pending verification of current Turas typography).

### Responsive targets

-   Tablet-responsive: baseline (must work)
-   Phone-responsive: aspirational (not blocking v1)

------------------------------------------------------------------------

## 9. Decisions Log

### Resolved decisions

| \# | Decision | Resolution | Date |
|----|----|----|----|
| 1 | Colour palette | Turas in-house palette by default. Configurable per project via `colour_focal` etc. in Brand_Config.xlsx. Can switch to client palette if needed. | 2026-04-16 |
| 2 | Typography | Run with current Turas typography for brand consistency. Any changes would be system-wide, not module-specific. | 2026-04-16 |
| 3 | WOM include/exclude | Configurable per project via `element_wom` in Brand_Config.xlsx. Default Y. Not an IPK-specific decision — every project decides. | 2026-04-16 |
| 4 | CEP count | Configurable per project via the CEPs sheet in Survey_Structure.xlsx. No hard limit in the module. Guidance: 10–15 CEPs + 5–7 attributes = 15–22 screens. | 2026-04-16 |
| 5 | DBA include/exclude | Configurable per project via `element_dba` in Brand_Config.xlsx. Default N (due to survey time cost). | 2026-04-16 |
| 6 | Focal category assignment | Configurable per project via `focal_assignment` and `Focal_Weight` column in Categories sheet. Default balanced. | 2026-04-16 |
| 7 | DBA attribution type | Default `open` (open-ended text, coded post-fieldwork). Switchable to `closed_list` per project via `dba_attribution_type` in Brand_Config.xlsx. | 2026-04-16 |
| 8 | Config architecture | Two-file Excel pattern (Brand_Config.xlsx + Survey_Structure.xlsx) following established Turas convention. Survey_Structure.xlsx shared across modules. | 2026-04-16 |

### Design principle

**Nothing is locked per-project.** The spec defines recommended defaults; every setting is overridable in the Excel config. A new project onboards by filling in two Excel files — no code changes.

### Module architecture decisions (locked in spec, not per-project)

-   Config-driven element activation via Excel: locked
-   Two modules (brand + portfolio) + shared TURF extraction: locked
-   CBM shared-battery questionnaire architecture: locked
-   Seven elements, Group A/B classification: locked
-   Single focal category per respondent with lightweight cross-category layer: locked
-   Academic labels (MMS, MPen, NS, Fame, Uniqueness): locked
-   DBA at brand level by default, config override for category: locked
-   Two-file config pattern (Brand_Config.xlsx + Survey_Structure.xlsx): locked
-   Survey_Structure.xlsx shared across brand/tabs/tracker modules: locked

------------------------------------------------------------------------

*End of Phase 4 Pass 2 specification. Next: Phase 5 (Growth Roadmap) and Phase 6 (Risks & Quality), followed by final Project Planning Document consolidation.*

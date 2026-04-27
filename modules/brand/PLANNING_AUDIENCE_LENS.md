# Audience Lens — Project Plan

**Status:** Planning complete, awaiting implementation
**Module:** `modules/brand/` (new sub-component)
**Target branch:** `feature/brand-audience-lens` (to be created from `main`)
**Estimated effort:** v1 — 1–2 weeks focused work

---

## 1. Problem Statement

The Turas brand health report presents comprehensive analysis at total and per-brand level across nine analytical panels. Clients consistently want to see how *their* (focal) brand performs among defined sub-populations — *"is our funnel different by region?"*, *"is mental availability different between buyers and non-buyers?"* — but running the entire report combinatorially across all brands × all subgroups × all metrics is computationally and visually unworkable. We need a focused, configurable, replicable feature that delivers focal-brand audience analysis without combinatorial blowup, with base-size honesty, and in a format that's directly deck-ready.

---

## 2. Landscape & Approach

### Market scan

| Platform | Audience model | Where applied | Comparison frame |
|---|---|---|---|
| **Kantar BrandZ** | Pre-defined lifestyle clusters at project level + geographic | Across MDS framework | Sub-segment vs project total |
| **YouGov BrandIndex** | Custom audience builder + YouGov Profiles integration | All 16 core metrics filterable | Vs syndicated benchmark + competitors |
| **Quantilope** | Dashboard filter chips ("Gen Z only") | Whole dashboard re-bases on filter | Filtered view, no built-in side-by-side |
| **Ipsos** | Pre-defined motivation/lifestyle segments + specialised audiences | KPI panels per audience | Audience profile vs total |
| **Latana** | Standard demos + custom characteristic builder | Brand funnel and sub-metrics | Explicit "audience vs general population" |
| **Tracksuit** | Pre-defined demographic cuts only | Brand funnel KPIs | Cut-by-cut view |

### Convergent practice (validated for Turas)

- Pre-defined audiences declared at project level, locked across waves
- Demographic + customer-status are universal families
- Comparison-vs-total is the universal display frame
- 80% of metrics constant across waves (industry guidance for trackers)

### Divergent practice — where we sit

- Quantilope/Latana use filter chips on whole dashboards → **we don't**
- Kantar/Ipsos use pre-baked banner tables on curated KPIs → **we align**
- Custom audiences are v1 in YouGov/Latana, deferred elsewhere → **v2 for us**

### Identified gaps in market practice (Turas opportunities to lead)

1. **No platform offers pair audiences** (buyer vs non-buyer side-by-side with explicit gap analysis) as a first-class concept
2. **No platform automates Romaniuk's GROW/FIX/DEFEND strategic classification**
3. **Base-size discipline is universally hidden** — n thresholds buried in fine print

These three are first-mover differentiators.

### Chosen approach

New **Audience Lens** tab per category. Focal-brand-only. Banner table primary view + per-audience pinnable cards. Pair audiences with side-by-side scorecards. Auto-classified GROW/FIX/DEFEND chips. Visible base-size thresholds. Pre-defined audiences declared in config; demographic + focal-brand-behavioural families in v1.

---

## 3. Objectives

| # | Objective | Measurable as | Priority |
|---|---|---|---|
| O1 | Show focal-brand performance across 3–6 pre-defined audiences on a curated KPI panel, all in one tab per category | Tab renders with banner table + per-audience cards for any valid config | Must |
| O2 | Make buyer-vs-non-buyer gap immediately visible (Romaniuk lens) | Pair audiences render as side-by-side scorecard with explicit Δ + sig flag column | Must |
| O3 | Auto-classify each pair-row gap as GROW / FIX / DEFEND | Every pair row in banner table shows a coloured chip with classification | Must |
| O4 | Enforce base-size honesty | n≥100 normal; n=50–99 "low base" badge; n<50 suppressed; brand-buyer-base metrics N/A on non-buyer side | Must |
| O5 | Replicable across waves of a tracker without re-configuration | Re-running same project on a new wave fixture produces an Audience Lens tab without config edits | Must |
| O6 | DRY config across categories | Demographic audiences declared once at project level, opted into per category | Must |
| O7 | Deck-ready exports | Each per-audience card has working pin button + PNG export, captured cleanly via TurasPins | Must |
| O8 | Fail visibly, not silently | Invalid filter / missing variable / exceeded audience ceiling → TRS refusal with code, message, fix | Must |
| O9 | Add no measurable bloat to base report size | Audience Lens adds <5% to total HTML size on a representative project | Must |
| O10 | Support custom audiences | Config accepts arbitrary filter expressions for analyst-defined audiences | **v2** |
| O11 | Support competitor comparator brand alongside focal | Config accepts `comparator_brand`; second block renders in banner table | **v2** |
| O12 | Tracker-aware: show wave-on-wave audience trend | Pair card shows current wave + previous wave with delta | **v3** |

---

## 4. Requirements

### Capabilities (v1)

- Read audience definitions from project + per-category config blocks
- Apply each audience filter to the survey fixture using existing tabs-module filter helpers (no new infra)
- Compute the curated KPI set for: total, each audience, each pair (a + b)
- Compute deltas (audience vs total; pair-a vs pair-b) with significance tests (two-proportion Z-test for proportions, t-test for means)
- Classify each pair row as GROW / FIX / DEFEND using deterministic rule set
- Render banner table (HTML) with sig flags, deltas, base sizes, low-base badges, suppression markers
- Render per-audience cards expandable from the banner table
- Emit JSON payload consumed client-side for re-render
- Pin/PNG via the shared TurasPins library

### Curated KPI set (v1)

14 metrics in 4 visual groups. Config-overrideable per category.

**Funnel & Equity (5):** Aided awareness · Consideration · P3M usage · Brand love · Branded reach

**Mental Availability (4):** MPen · NS · MMS · SoM
*(Romaniuk's canonical four — no fictional composite. MPen used as the single MA representative on the per-audience headline card per Romaniuk's "MPen is most interesting for non-buyers" guidance.)*

**Word of Mouth (2):** Net heard · Net said

**Loyalty & Behaviour (3):** Loyalty (SCR) · Purchase distribution · Purchase frequency
*(All three are brand-buyer-base metrics — non-buyer column is N/A by definition for pair comparisons.)*

### GROW / FIX / DEFEND rule set (v1)

Applied only to pair rows.

| Classification | Condition | Strategic readout |
|---|---|---|
| **GROW** | Buyers ≫ Non-buyers (gap ≥10pp, sig at 90%) | Recruitment opportunity — close the mental gap among non-buyers |
| **FIX** | Buyers ≤ Total (focal underperforms among own buyers vs category) | Retention/satisfaction risk — own buyers don't rate this metric |
| **DEFEND** | Buyers ≫ Non-buyers AND focal leads category total | Strong position; protect against competitive erosion |
| (no chip) | Gap not significant or <10pp | No clear strategic call |

Thresholds (10pp gap, 90% confidence) externalised in config.

### Base-size discipline

| Base | Treatment |
|---|---|
| n ≥ 100 | Show normally |
| n = 50–99 | Show with visible "low base" badge under column header |
| n < 50 | Suppress column, show single message: "n=42 — base too small for reliable estimate" |
| Brand-buyer-base metric on non-buyer pair side | N/A cell (greyed) with footnote: "Not applicable: metric defined on brand buyers" |

Thresholds config-overrideable.

### Quality standards

- TRS-compliant (no `stop()`, structured refusals)
- Console-visible errors (Shiny boxed pattern)
- ≥80% test coverage
- Roxygen2 on all exported functions
- Banner table accessible (keyboard nav, sufficient contrast, sig-flag legend)
- Renders <3s on 1200-respondent fixture for 5-audience config
- Total HTML size delta <5% of base report

### Constraints

- Follow brand module's whitelist loader pattern — every new file must be added to `.source_brand_module` list at `modules/brand/R/00_main.R:54-87` (silent failure otherwise)
- Use existing tabs module filter helpers; do NOT introduce parallel filter logic
- Use shared TurasPins library; do NOT roll a custom pin path
- Stay within current `renv` lockfile; no new package dependencies for v1
- All CSS portable (no panel-class ancestor selectors; `!important` on layout-critical CSS — TurasPins inliner defaults don't survive)
- Verification path: `launch_turas()` → pick config in GUI → browser-inspect generated HTML

### Dependencies

- Existing `focal_brand` declaration per category
- Existing fixture structure with respondent-level demographic + brand-buyer flags
- Existing tabs module (filter helpers, sig testing)
- Existing TurasPins library (pin + PNG export)
- Existing 9-cat module (provides funnel KPI metrics)
- Existing MA module (provides MPen, NS, MMS, SoM)
- Existing Branded Reach module (provides reach + WOM metrics)
- Existing Cat Buying / Shopper Behaviour modules (provides SCR, frequency, distribution)

---

## 5. Design & Experience

### Tab placement

```
[Shampoo] ▸ Portfolio · MA · Funnel · 9cat · Cat Buying · Shopper · Reach · Demographics · Ad Hoc · ▸ Audience Lens
```

Last position in category tab strip — deepest dive, ends the analytical journey. Same chip-and-tab styling as Demographics + Ad Hoc (consistency with existing per-category convention).

### Layout 1 — Banner table (default view)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│  Audience Lens — Pantene (Shampoo)                                                          │
│  Showing focal brand performance across 5 audiences. Sig at 90% vs Total unless noted.      │
└─────────────────────────────────────────────────────────────────────────────────────────────┘

                        │       │  ━━ PAIR ━━  ━━ PAIR ━━         │           │           │
                        │ Total │ Buyers   Non-buyers   Δ    Chip │ Gauteng   │ WC        │ KZN
                        │ 1200  │ 312      888          —    —    │ 384       │ 276       │ 240
─────────────────────────────────────────────────────────────────────────────────────────────────
FUNNEL & EQUITY
  Aided awareness        │ 75%   │ 95%a    60%b        +35  GROW  │ 78%       │ 72%       │ 70%
  Consideration          │ 45%   │ 85%a    25%b        +60  GROW  │ 50%c      │ 42%       │ 40%
  P3M usage              │ 28%   │ 78%a    5%b         +73  GROW  │ 32%c      │ 25%       │ 24%
  Brand love             │ 18%   │ 52%a    7%b         +45  GROW  │ 22%       │ 16%       │ 15%
  Branded reach          │ 18%   │ 45%a    7%b         +38  GROW  │ 21%c      │ 17%       │ 15%

MENTAL AVAILABILITY
  MPen                   │ 52%   │ 88%a    41%b        +47  GROW  │ 55%       │ 50%       │ 49%
  Network Size           │ 3.2   │ 5.1a    2.6b        +2.5 GROW  │ 3.4       │ 3.0       │ 2.9
  MMS                    │ 0.18  │ 0.42a   0.10b       +0.32 GROW │ 0.20      │ 0.16      │ 0.16
  SoM                    │ 0.21  │ 0.48a   0.12b       +0.36 GROW │ 0.23      │ 0.19      │ 0.18

WORD OF MOUTH
  Net heard              │ +12   │ +28a    +6b         +22  GROW  │ +15       │ +10       │ +8
  Net said               │ +8    │ +24a    +3b         +21  GROW  │ +11       │ +7        │ +5

LOYALTY & BEHAVIOUR
  Loyalty (SCR)          │ 42%   │ 42%     N/A †       —    —     │ 45%       │ 40%       │ 38%
  Purchase distribution  │ —     │ See †   N/A †       —    —     │ —         │ —         │ —
  Purchase frequency     │ 4.2   │ 4.2     N/A †       —    —     │ 4.5       │ 4.0       │ 3.8

  † Loyalty/distribution/frequency defined on brand buyers only — N/A for non-buyers by definition.
  a/b superscripts = significantly higher at 90% within the pair. c = sig vs Total.
```

**Visual treatment:**
- Group headers (FUNNEL & EQUITY etc.) — small caps, subtle navy background tint
- PAIR header span above buyer/non-buyer column pair, bracketed with thin borders
- Δ column in slightly bolder weight; positives standard colour, negatives in red
- Chip column (GROW/FIX/DEFEND) — coloured pill with the word
- N/A cells in light grey with † footnote marker (not "0", not blank)
- Low-base columns (n=50–99) get a "low base" badge under the n= header
- Suppressed columns (n<50) collapse to single "n=42 — base too small" message

### Layout 2 — Per-audience card (deck-ready, pinnable)

Triggered by clicking an audience column header. Renders inline below the banner table.

**Single audience card:**

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  Pantene among Non-buyers (Shampoo)                            [Pin] [PNG] [Close]  │
│  Base: n=888                                                                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┃ Among non-buyers, Pantene's mental availability collapses by 47pp vs buyers.    │
│  ┃ Closing this gap — particularly on memorable advertising and CEP recall —       │
│  ┃ is the dominant growth lever for the brand.                            [GROW]   │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  HEADLINE SCORECARD                       │  DELTA VS TOTAL                         │
│                                           │                                         │
│  Aided awareness    60%   ▼ -15pp ⚠       │  Aided awareness ─────●────|           │
│  Consideration      25%   ▼ -20pp ⚠       │  Consideration   ──●───────|           │
│  P3M usage          5%    ▼ -23pp ⚠       │  P3M usage       ●─────────|           │
│  Brand love         7%    ▼ -11pp ⚠       │  Brand love      ──●───────|           │
│  MPen               41%   ▼ -11pp ⚠       │  MPen            ──●───────|           │
│  Branded reach      7%    ▼ -11pp ⚠       │  Branded reach   ●─────────|           │
│  Net heard          +6    ▼ -6   ⚠        │  Net heard       ──●───────|           │
│  Loyalty (SCR)      N/A † (non-buyers)    │  ● = audience  | = total                │
│                                                                                     │
│  [▸ Show all 14 metrics]                                                            │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  Source: Pantene Brand Health Tracker, Wave 3 · Apr 2026 · n=1200 (888 non-buyers)  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**Pair audience card:**

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  Pantene Buyers vs Non-buyers (Shampoo)                       [Pin] [PNG] [Close]   │
│  Base: n=312 buyers / n=888 non-buyers                                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┃ Across all 8 headline metrics, the buyer–non-buyer gap is significant and        │
│  ┃ favours buyers. The largest opportunities sit in MPen (Δ +47pp) and             │
│  ┃ consideration (Δ +60pp). Non-buyer mental availability is the growth ceiling.   │
│  ┃                                                                       [GROW]    │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  SIDE-BY-SIDE SCORECARD                                                             │
│                          Total      Buyers      Non-buyers      Gap    Chip         │
│  Aided awareness         75%        95%         60%             +35    GROW         │
│  Consideration           45%        85%         25%             +60    GROW         │
│  P3M usage               28%        78%         5%              +73    GROW         │
│  Brand love              18%        52%         7%              +45    GROW         │
│  MPen                    52%        88%         41%             +47    GROW         │
│  Branded reach           18%        45%         7%              +38    GROW         │
│  Net heard               +12        +28         +6              +22    GROW         │
│  Loyalty (SCR)           42%        42%         N/A             —      —            │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

The pair card is the **strategic-priority card** — Romaniuk diagnostic the whole feature exists to surface.

### GROW / FIX / DEFEND chip styling

| Chip | Background | Text | When |
|---|---|---|---|
| **GROW** | `#2C7A3D` (deep green) | white | Buyer ≫ Non-buyer (gap ≥10pp, sig 90%) |
| **FIX** | `#A8351F` (deep red) | white | Buyers underperform Total |
| **DEFEND** | `#0E3A8A` (deep navy) | white | Buyers ≫ Non-buyers AND focal leads category |
| (none) | n/a | n/a | No significant pair gap |

Colour-blind safe (deep green / deep red / deep navy distinguishable in deuteranopia/protanopia). Portable through TurasPins inliner — use `!important` on chip CSS, no panel-class ancestor selectors.

### Pin / PNG behaviour

- **Pin** — captures per-audience card (insight + scorecard + chart + metadata) into project pin board via shared TurasPins
- **PNG** — same content rendered standalone via TurasPins inliner
- **Banner table itself is not pin/PNG-able in v1** — too dense for slide use; intended slide unit is one audience per slide
- All CSS uses portable selectors per inliner-defaults lesson

### Empty / error / edge states

| Condition | Treatment |
|---|---|
| Config has no `audience_lens` block | Tab not rendered |
| All audiences yield n<50 | Tab renders single message: "All declared audiences fall below the n=50 base threshold." TRS PARTIAL with `DATA_ALL_AUDIENCES_SUPPRESSED` |
| One audience suppressed | Column collapsed to "n=42 — base too small" |
| One metric not collected | Row omitted; footnote: "NPS not collected this wave" |
| Pair audience with one side empty | Empty side as N/A column, GROW/FIX/DEFEND suppressed for affected rows |
| Filter expression fails | TRS REFUSED at config load; tab does not render |

### Config example

```yaml
audience_lens:
  shared_audiences:                    # declared once, used everywhere
    - id: "gauteng",  type: single, filter: "region == 'Gauteng'"
    - id: "wc",       type: single, filter: "region == 'Western Cape'"
    - id: "kzn",      type: single, filter: "region == 'KZN'"
    - id: "under_35", type: single, filter: "age < 35"

categories:
  shampoo:
    focal_brand: "Pantene"
    audience_lens:
      use_shared: [gauteng, wc, kzn]
      audiences:
        - id: "buyer_pair"
          type: pair
          label_a: "Buyers"
          filter_a: "brand_buyer_pantene == TRUE"
          label_b: "Non-buyers"
          filter_b: "brand_buyer_pantene == FALSE"
      max_audiences: 6                 # validated at config load
      headline_metrics: [awareness, consideration, p3m_usage, brand_love,
                         mpen, branded_reach, net_heard, loyalty_scr]
```

---

## 6. Growth Roadmap

### v1 (this plan) — 1–2 weeks

Full feature as scoped above. Ships the Romaniuk-canonical case (focal brand × pre-defined audiences × pair comparison × strategic chip) and nothing else.

### v2.1 — ~1 week post-v1

- **Comparator brand** — `comparator_brand: "BrandY"` renders second focal-brand block in same banner table
- **Wave-on-wave trend** — pair cards show current + previous wave with delta (tracker renewal driver)

### v2.2 — ~1 week

- **Custom audience family** — analyst-defined filter expressions with TRS-validated parser
- **Category-behavioural audiences** — heavy/medium/light category buyers
- **Analyst-overrideable insight text**
- **Audience-level Excel export**
- **Audience description field**

### v3 — pull-driven only

- Cross-category Audience Lens (same focal brand across multiple categories)
- Audience portfolios (saved sets reusable across projects)
- Audience overlap / lift analysis
- AI-generated insight text (LLM, not rule-based)
- Predictive audience suggestion
- External panel refresh integration

### Foundational decisions in v1 (to keep v2/v3 doors open)

| Decision | v1 implementation | What it unlocks |
|---|---|---|
| Audience as structured config object | `id`, `label`, `type`, `filter`, `description`, `source` fields | Custom audiences (v2); audience portfolios (v3) |
| Filter expression as parsed AST | Even bounded vocabulary uses extensible parser | Custom filters (v2) without rewriting filter engine |
| Computation separated from rendering | Engine returns card payload (JSON); HTML is one renderer | Excel export (v2), cross-category aggregation (v3) |
| Card payload schema versioned | `schema_version: 1` | v2 can add fields; old pins still render |
| GROW/FIX/DEFEND rules externalised | Thresholds in config | Tracker-specific tuning |
| Audience metadata separated from results | Metadata block once, results array per audience | Cross-category lens (v3) reuses metadata |
| Pin payload self-contained | All metadata + base sizes + sig flags + insight inside pin | Pins remain valid even if config changes between waves |

---

## 7. Risks & Mitigations

### Execution risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Base-size collapse on focal-brand-buyer audiences in low-penetration brands | High | Medium | n=50/100 thresholds + visible badges + N/A treatment. Document expected n=300+ project sample. |
| TurasPins inliner gotcha — defaults don't survive PNG capture | Certain | High | Portable selectors, `!important` on layout-critical CSS, regression test in PNG pipeline |
| Brand module whitelist loader — silent failure if not registered | Certain | High | Implementation checklist: every new R file added to whitelist at `00_main.R:54-87` |
| Sig test wrong for pair audiences — paired vs independent confusion | Medium | High | Use existing tabs sig helpers; document pair Z-test as two-independent-proportions (every respondent independently classified) |
| Computation cost from 6 audiences × 14 metrics × CI | Low | Low | <100 cells per category — trivial vs MA matrix. Performance test in v1. |
| Merge conflict with concurrent brand-module branches | Medium | Low | Self-contained tab; minimal shared-file edits. Schedule after current brand work merges. |
| Auto-generated insight reads awkwardly for unusual data | High | Low | Templates fall back to "No significant differences vs total" for null cases. Override is v2. |
| Filter expression user error | High | Low | TRS refusal at config load with named valid values from data |

### Strategic risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Client misreads N/A column on non-buyer loyalty as "zero loyalty" | Medium | Medium | Footnote ALWAYS visible on N/A cells with explicit reason text |
| Methodological pushback on pair Z-test | Low | Medium | Document two-independent-proportions framing in module README; cite Romaniuk on the analytical question |
| v1 ships and clients demand v2 immediately (esp. comparator brand) | High | Low | v2 roadmap sequenced and credible — surface in client comms; comparator brand ~1 week post-v1 |
| Audience definitions baked into deck templates — changing breaks comparability | Medium | Medium | Audience IDs locked across waves; renaming requires explicit config flag |
| Confusion with Demographics tab | Medium | Low | Position differently: Demographics = profile of category audience; Audience Lens = focal brand among defined cuts. Tooltip clarification. |
| Feature creep during build | High | Medium | v1 scope locked in this document; deviations require explicit approval |

---

## 8. Quality Standards

### Code quality
- TRS-compliant: no `stop()`, all refusals structured with `code` + `message` + `how_to_fix` + `context`
- Console output for every TRS refusal using boxed Shiny error pattern
- Roxygen2 documentation on every exported function
- Functions <100 lines where feasible
- No hardcoded paths; use `file.path()` and config
- No new package dependencies
- `styler::style_file()` clean
- Brand module file layout: source files in `modules/brand/R/` with `00_main.R`, `00_guard.R` pattern
- Whitelist loader entry added (`modules/brand/R/00_main.R:54-87`)

### Test coverage
- ≥80% line coverage on new code
- Unit tests: filter parser, audience computation, sig test wrapper, GROW/FIX/DEFEND classifier, base-size masker
- Integration tests: full Audience Lens run on synthetic 1200-respondent fixture
- Edge cases: n=0, n<50, n=50–99, missing variable, invalid filter, focal brand with no buyers, all metrics suppressed
- Golden file tests: banner table HTML structure, card HTML structure, JSON payload
- Regression test: TurasPins PNG capture (verified-good baseline)

### UI / UX
- Banner table renders with group headers and sig-flag legend
- Per-audience card has insight callout, scorecard, delta chart, base size, pin button, PNG button
- N/A cells render with footnote marker (not blank, not zero)
- GROW/FIX/DEFEND chips colour-blind safe, deck-portable
- Tab placement at end of category tab strip
- Empty/error states handled per matrix above
- Accessibility: keyboard nav, sufficient contrast, sig-flag legend visible

### Performance
- Renders in <3s on 1200-respondent fixture for 5-audience config
- Total HTML size delta <5% vs base report
- No new memory hotspots (verify with `pryr::mem_used()`)

### Verification
- Browser-verified via `launch_turas()` → GUI → config selection (per standing rule, no preview server)
- PNG capture verified visually on at least one pair card and one single card
- Pin round-trip verified (pin → reload → unpin)

### Documentation
- `modules/brand/audience_lens/README.md` — config schema, audience families, GROW/FIX/DEFEND rules, base-size thresholds, methodological notes (pair Z-test framing)
- Operator Guide entry for Audience Lens config block
- Sample config in `examples/brand/audience_lens/`
- CHANGELOG.md entry

---

## 9. Next Steps

When ready to start v1:

1. Branch from `main`: `feature/brand-audience-lens`
2. Stub the module files: `modules/brand/R/audience_lens_*.R` per file layout convention; add to whitelist loader at `00_main.R:54-87`
3. Define config schema (YAML); add TRS validator; add 6-audience ceiling check (`CFG_AUDIENCE_CEILING_EXCEEDED`)
4. Build computation engine (audience filter → KPI compute → sig test → classifier → JSON payload)
5. Build banner table HTML renderer (with group headers, pair brackets, chips, N/A footnotes)
6. Build per-audience card renderer (single + pair variants)
7. Wire pin + PNG via TurasPins; verify with portable CSS + `!important`
8. Synthetic fixture + golden tests; coverage check ≥80%
9. Browser verification via `launch_turas()` with a real config
10. Write module README; Operator Guide entry; sample config in `examples/brand/audience_lens/`
11. CHANGELOG; PR review; merge to `main`

---

## Appendix A — Sources consulted in landscape research

- [Kantar BrandZ Methodology](https://www.kantar.com/campaigns/brandz/methodology)
- [Kantar Brand Tracking](https://www.kantar.com/uki/expertise/brand-growth/brand-tracking)
- [YouGov BrandIndex](https://business.yougov.com/product/brandindex)
- [Quantilope Brand Tracking Platform](https://www.quantilope.com/solutions/brand-tracking-platform)
- [Quantilope Mental Availability Method](https://www.quantilope.com/methods/mental-availability)
- [Ipsos Contextual Brand Tracking](https://www.ipsos.com/en/brand-success/contextual-brand-tracking)
- [Latana Audience Segmentation](https://resources.latana.com/audience-segmentation/)
- [Latana Create Audience Segments](https://knowledge.latana.com/create-audience-segments/)
- [Six Stages of Mental Availability Assessment](https://smilingcfo.co.uk/6-stages-of-mental-availability-assessment/)
- [Ehrenberg-Bass — How Brands Grow](https://marketingscience.info/news-and-insights/how-do-you-measure-how-brands-grow)
- [Romaniuk on Mental Availability and B2B](http://www.jenniromaniuk.com/blog/2022/3/28/mi3-mental-availability-brand-rejection-binet-amp-field-esov-and-ehrenberg-bass-new-b2b-data-shows-marketers-should-flip-the-funnel-sideways-for-business-growth-b2c-strategy-also-on-the-hook)

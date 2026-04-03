# Turas AI Insights — Project Plan

## Project Type: Software Feature (Turas Platform Extension)

---

## 1. Problem Statement

After Turas generates crosstabs, charts, and significance tests, the data sits waiting for a human researcher to spot patterns and write commentary. For a 27-question report, that observational pattern-spotting takes real time — and for white-label partners running Turas independently, it doesn't happen at all. The data speaks, but nobody translates.

AI-generated insight callouts can handle the observational layer ("here's what's notable in this data"), leaving the researcher to do the strategic layer ("here's what it means for your business"). Two complementary voices, honestly labelled. For TRL projects this saves researcher time. For white-label, it transforms a raw data output into something that actually communicates.

---

## 2. Landscape & Approach

### What exists

- **ellmer** (CRAN, Posit/Tidyverse official) — provides a unified R interface to Claude, OpenAI, Gemini, and Ollama with structured output extraction. This is the right tool — it abstracts provider differences and guarantees typed R list responses.
- **easystats** (CRAN) — rule-based, non-LLM complement for formal model descriptions. Its `report()` function generates APA-style narration ("A one-way ANOVA revealed a statistically significant difference between groups, F(2, 147) = 4.32, p = .015"). Deterministic, reproducible, no API calls. Complements the AI insights layer where formal statistical language is needed — does not replace it.
- **Turas's existing Comments sheet** — already supports per-question and banner-specific researcher commentary in Crosstab_Config.xlsx.

### Approach chosen

- Use ellmer for all LLM interactions (provider-agnostic)
- Structured output schemas guarantee typed, parseable responses
- Multi-pass quality assurance: verification (factual accuracy) + selectivity (editorial quality)
- Two-tier content model: AI callouts (observational, labelled) + researcher commentary (strategic, unlabelled)
- easystats as an optional complement for APA-style statistical narration
- Tabs module first, then roll out to other modules using shared infrastructure

### Why this approach

- ellmer is the R ecosystem's official LLM interface — maintained by Posit, not a hobby project
- Structured output avoids parsing fragility
- Multi-pass quality catches the two highest-risk failure modes (hallucinated numbers, low-value observations)
- The two-tier model protects Duncan's professional reputation while adding genuine value
- Tabs-first gives a concrete, testable implementation before touching other modules

---

## 3. Objectives

### Must-have (project fails without these)

1. **Zero regression** — All existing Turas tests pass with AI insights disabled AND enabled. No existing report changes output unless AI insights are explicitly turned on.
2. **Selectivity** — AI callouts generate for 35-60% of questions. Below 35% = too conservative. Above 60% = commenting on unremarkable data. Every question getting a callout is a failure.
3. **Factual accuracy** — Zero hallucinated numbers. Every number cited in every callout matches the source data exactly. Verified by automated verification pass.
4. **Significance discipline** — No callout uses assertive language ("significantly higher") for a difference not flagged as statistically significant in the source data.
5. **Graceful degradation** — Report generates successfully with zero AI-related errors when the API is unavailable, the key is missing, or the model returns malformed output.
6. **Idempotency** — Manually edited callouts, researcher commentary, and pin state are preserved across regeneration.
7. **Observational scope** — No AI callout contains strategic recommendations ("the company should..."). Callouts describe what the data shows, not what to do about it.
8. **Sub-5-minute pipeline** — Full run (all callouts + verification + selectivity + executive summary) completes in under 5 minutes for a 27-question report.
9. **Clean integration** — AI code is isolated in its own files in `modules/shared/lib/ai/`, sourced conditionally, never modifies existing function signatures.

### Nice-to-have (adds value but not essential for MVP)

10. **Executive summary quality** — Judged "usable with minor edits" by Duncan on 4 out of 5 test runs against real client datasets.
11. **Workflow efficiency** — A researcher can review, edit, and pin all AI callouts in under 10 minutes for a standard 25-question report.
12. **Client validation** — At least one trusted client confirms the two-tier labelling feels honest and the callouts add value.
13. **easystats narration** — Optional APA-style statistical narration available as a complement for formal reporting contexts.

---

## 4. Requirements

### Capabilities

- Per-question AI callout generation with structured output (has_insight, narrative, confidence, data_limitations)
- Automated verification pass checking every cited number and significance claim against source data
- Selectivity pass removing low-value callouts that merely restate what the chart shows
- Two-stage executive summary (pattern identification → narrative generation)
- HTML rendering with distinct visual treatment for AI callouts vs researcher commentary
- Pin-to-slide functionality for selective inclusion in findings decks
- Client-side toggle to show/hide all AI callouts
- Print CSS that only includes pinned callouts
- Provider switching (Claude, OpenAI, Gemini, Ollama) via config
- Per-question exclusion override (`ai_callout_exclude = TRUE`)
- Manual suppression (set `has_insight = FALSE` without triggering regeneration)
- JSON sidecar persistence for AI outputs (separate from Excel config)
- Content-hash caching — hash each question's data payload; skip API call if data unchanged and valid callout exists. Makes re-runs instant and free for unchanged questions.
- easystats APA narration as optional complement (non-LLM, rule-based)

### AI transparency (non-negotiable)

Per TRL guidelines, all AI-generated content must explicitly disclose:
- **That AI was used** — every AI callout panel and unreviewed executive summary must be clearly labelled as "AI-assisted"
- **Which model was used** — the methodology note in the report must state the specific model (e.g., "Claude Sonnet 4, Anthropic" or "GPT-4.1, OpenAI" or "Gemma 4 31B, local via Ollama"). This is populated automatically from `config$ai_insights$provider` and `config$ai_insights$model`.
- **What the AI did and didn't do** — the methodology note distinguishes between AI-generated observational callouts and researcher-written strategic commentary. The labelling must be honest about whether a human reviewed the content.

This is not optional transparency theatre — it is Duncan's professional standard. A SAMRA-accredited researcher with a 30-year reputation has more to lose from undisclosed AI text than from honest labelling. The label protects both the researcher and the client.

Implementation: The methodology note text (already specified in the spec) must include the model name. Add `model_display_name` to the config, auto-populated from provider + model fields, rendered in the methodology note HTML.

### Quality standards

- All existing Turas regression tests pass unchanged
- New test coverage for: extraction, verification, selectivity, rendering, graceful degradation, persistence
- JSON sidecar read/write is atomic (no corruption on interrupted writes)
- Every AI-touching code path behind `if (isTRUE(config$ai_insights$enabled))` guards
- Prompts stored as text constants in separate file (refinable without touching function code)
- ellmer version pinned in renv

### Constraints

- No changes to existing function signatures
- No new external dependencies beyond ellmer (jsonlite already in Turas)
- AI layer must be purely additive — existing reports byte-identical when AI disabled
- Rate limiting courtesy (0.5s between API calls)
- Context window management for large reports (compact extraction fallback)

### Dependencies

- ellmer package (CRAN) — LLM interface
- jsonlite package (already in Turas) — JSON serialisation
- easystats package (CRAN, optional) — APA-style statistical narration
- API key for chosen provider (env var)
- Existing Turas tabs analytical output (all_results from run_crosstabs_analysis)
- Existing HTML report generation pipeline

---

## 5. Design & Experience

### Two-tier content model

| Content type | Source | Visual treatment | Labelled as AI | Editable by |
|---|---|---|---|---|
| AI callout | LLM-generated | Grey background, ✦ icon, pin button | Yes — always. Model named in methodology note. | Researcher (via JSON sidecar) |
| Researcher commentary | Comments sheet (manual) | Standard styling, brand-colour border | No — never | Researcher (via Excel) |
| Executive summary (reviewed) | AI-drafted, researcher-edited | Standard styling, "Reviewed by research team" | No (but model named in methodology note) | Researcher |
| Executive summary (unreviewed) | AI-generated, no review | AI callout styling, "AI-assisted" | Yes. Model named in methodology note. | — |
| Methodology note | Auto-generated | Footer/appendix styling | N/A — this IS the disclosure | — |
| easystats narration | Rule-based (no LLM) | Distinct from AI callouts — no AI label needed | No — deterministic, not AI | — |

### Rendering order per question

```
┌─────────────────────────────────┐
│  Table / Chart (existing)       │
├─────────────────────────────────┤
│  Researcher Commentary          │  ← standard styling, brand-colour border
│  (from Comments sheet)          │     never AI-labelled
├─────────────────────────────────┤
│  ✦ AI-assisted insight    📌    │  ← grey background, distinct treatment
│  "The overall NPS of +7..."     │     always AI-labelled
│  ⚠ Base sizes below 50...      │  ← caveat if confidence < high
└─────────────────────────────────┘
```

### Researcher workflow

```
1. Configure project as normal (Excel config)
   └─ New: set ai_insights enabled = TRUE in Settings sheet

2. Run crosstabs as normal
   └─ AI callouts generated automatically after analysis
   └─ Progress: "Generating AI insights... Q001... Q005...
      Verification... Selectivity... Executive summary..."
   └─ If API fails: warning, report continues without callouts

3. Review HTML report
   └─ Executive summary at top of report
   └─ Each question: table/chart → commentary → AI callout
   └─ Pin button on each callout for slide export
   └─ Toggle to show/hide all AI callouts

4. Edit cycle
   └─ Suppress unwanted callouts in JSON sidecar
   └─ Edit callout text if needed
   └─ Add researcher commentary in Comments sheet
   └─ Re-run: preserves edits, only regenerates NULL callouts

5. Export
   └─ Print-to-PDF: only pinned callouts print
   └─ Pin-to-slide: integrates with export mechanism
```

### Pipeline position

```
[Existing] Survey data → R analysis → Tables/charts/significance
                                            ↓
[New]                              extract_insights_data()
                                            ↓
                                   build_insight_prompt()
                                            ↓
                              ┌─── Per-question callouts ───┐
                              │  call_insight_model()        │
                              │  verify_callout()            │
                              │  [regenerate if needed]      │
                              └──────────────────────────────┘
                                            ↓
                                   rank_callouts()
                                            ↓
                              ┌─── Executive summary ────────┐
                              │  Stage 1: identify patterns  │
                              │  Stage 2: write narrative    │
                              └──────────────────────────────┘
                                            ↓
                                   Save to JSON sidecar
                                            ↓
[Existing]                         Generate HTML report
```

---

## 6. Growth Roadmap

### Immediate scope (Tabs module MVP)

- Per-question AI callouts with verification + selectivity
- Executive summary (two-stage)
- HTML rendering with distinct styling
- Pin-to-slide, toggle, print support
- JSON sidecar persistence with content-hash caching
- Claude via ellmer (default provider)
- Shared AI infrastructure in `modules/shared/lib/ai/`

### Near-term extensions (3-6 months)

- **Tracker module** — AI insights on longitudinal data ("NPS has declined 8 points over 3 waves, driven primarily by the Budget segment"). Different prompt templates, same shared infrastructure.
- **Ollama local mode** — For clients who can't send data to external APIs. Provider abstraction already supports this.
- **easystats integration** — APA-style narration for significance testing, available as a complement to LLM insights.
- **Batch processing** — ellmer's `parallel_chat_structured()` for faster generation on large reports.

### Long-term potential (6-18 months)

- **Conjoint/MaxDiff modules** — AI insights on choice modelling outputs.
- **Cross-module synthesis** — AI that reads across tabs + tracker + segment outputs to find patterns no single module surfaces.
- **Report Hub integration** — AI insights that work across combined multi-module reports.
- **Client-facing insight editor** — Simple web UI where clients review and approve AI callouts before final delivery.

### Foundational decision

Shared infrastructure (provider abstraction, `call_insight_model()`, verification logic, schemas) lives in `modules/shared/lib/ai/` from the start. Module-specific code (extraction functions, prompt templates) stays in each module's directory. This costs nothing extra now and avoids a painful refactor when tracker is next.

### Commercial lens

- White-label AI insights move Turas from "tool" to "analyst" — different price point
- Feature pays for itself if it supports even one additional white-label deal
- API costs ~R30 per report (negligible vs value delivered)
- Strengthens recurring revenue positioning for semi-retirement

---

## 7. Risks & Mitigations

### Execution risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| ellmer API changes between versions | Medium | High | Pin version in renv. Wrapper function isolates dependency. Test before upgrading. |
| Hallucinated numbers in callouts | Medium | High | Verification pass catches this. Suppresses after 2 failed attempts. |
| Breaking existing reports | Low | Critical | All AI code behind feature flag. `enabled = FALSE` by default. Existing tests must pass unchanged. |
| Prompt quality insufficient | High initially | Medium | Budget full day of tuning against real data. Spec prompts are starting point. |
| Context window overflow on large reports | Low | Medium | Compact extraction fallback. Token estimation built in. |
| Rate limiting / API costs | Low | Low | 0.5s courtesy delay. ~30 calls per report ≈ R30. |
| Data extraction shape mismatch | High | Medium | First task: verify actual Turas output structure matches spec assumptions. |
| easystats version compatibility | Low | Low | Pin in renv alongside ellmer. |

### Strategic risks

| Risk | Mitigation |
|---|---|
| Client rejection of AI content | Toggle hides all callouts. Report works perfectly without them. Honest labelling protects trust. |
| Researcher overhead exceeds time saved | Jess workflow test is acceptance gate. If review > writing from scratch, feature isn't ready. |
| Quality floor too low for TRL reputation | Verification + selectivity + researcher review = three quality gates. |
| Competitor copies the approach | Duncan's 30 years of prompt domain knowledge is the moat. The tool is replicable; the analytical judgement encoded in the prompts is not. |

---

## 8. Quality Standards

### Pre-implementation

- [ ] Verify actual Turas `all_results` data structure matches spec assumptions
- [ ] Confirm ellmer structured output works with current Claude API
- [ ] Confirm Comments sheet → researcher_commentary mapping is clean

### During implementation

- [ ] All existing Turas regression tests pass at every phase gate
- [ ] New tests written for every new function before moving to next phase
- [ ] AI code isolated in `modules/shared/lib/ai/` and module-specific locations
- [ ] Every AI code path behind `if (isTRUE(config$ai_insights$enabled))` guard
- [ ] No existing function signatures modified

### Before first client use

- [ ] Full pipeline tested against Demo_CX dataset
- [ ] Full pipeline tested against 3+ real past client datasets
- [ ] Prompt refinement complete (budget 1 full day)
- [ ] Jess workflow test complete — callouts save time, not create overhead
- [ ] Zero hallucinated numbers across all test runs
- [ ] Selectivity pass removing 2-4 low-value callouts per report
- [ ] Report generates cleanly when API unavailable
- [ ] Manual edits and pin state preserved across re-runs
- [ ] Print-to-PDF includes only pinned callouts
- [ ] Toggle show/hide works correctly
- [ ] Executive summary renders correctly in both reviewed/unreviewed modes
- [ ] One trusted client shown prototype and confirms value

---

## 9. Build Sequence

### Phase A: Foundation (no changes to existing files)

| Step | What | Files | Risk |
|---|---|---|---|
| A1 | Install ellmer, pin in renv | renv.lock | Low — additive only |
| A2 | Create `modules/shared/lib/ai/` directory | New directory | Zero |
| A3 | Implement provider abstraction (ai_provider.R) | New file | Zero |
| A4 | Implement schemas (ai_schemas.R) | New file | Zero |
| A5 | Implement prompts (ai_prompts.R) | New file | Zero |
| A6 | Implement `call_insight_model()` with error handling | New file | Zero |
| A7 | Verify ellmer works — standalone test | Test script | Zero |

### Phase B: Data extraction (reads existing structures, doesn't modify them)

| Step | What | Risk |
|---|---|---|
| B1 | Study actual `all_results` structure from `run_crosstabs_analysis()` | Read-only |
| B2 | Implement `extract_question_data()` mapping from real Turas output | New file |
| B3 | Implement `extract_study_context()` | New file |
| B4 | Implement `extract_question_data_compact()` for large reports | New file |
| B5 | Implement `extract_sig_flags()` — translate column-letter notation | New file |
| B6 | Test extraction against Demo_CX | Test script |

### Phase C: Generation pipeline (new files only)

| Step | What | Risk |
|---|---|---|
| C1 | Implement `generate_all_insights()` — per-question callouts | New file |
| C2 | Test against Demo_CX — manual quality review | Manual |
| C3 | Implement `verify_callout()` with regeneration loop | New file |
| C4 | Implement `rank_callouts()` selectivity pass | New file |
| C5 | Implement JSON sidecar persistence (read/write, atomic) | New file |
| C6 | Implement content-hash caching in sidecar | New file |
| C7 | **Prompt refinement against 3+ real client datasets** | Iteration |

### Phase D: HTML rendering (first changes to existing files)

| Step | What | Risk |
|---|---|---|
| D1 | Add AI callout + commentary CSS | Additive |
| D2 | Add callout rendering in page_builder | **Medium** |
| D3 | Add researcher commentary rendering (Comments sheet mapping) | **Medium** |
| D4 | Add toggle JS and pin-to-slide JS | Additive |
| D5 | Add print CSS (pinned only) | Additive |
| D6 | **Full regression test** | Critical gate |

### Phase E: Integration (the careful bit)

| Step | What | Risk |
|---|---|---|
| E1 | Add `generate_all_insights()` call to `run_crosstabs.R` | **High** |
| E2 | Add AI config to Settings sheet template | Template change |
| E3 | Add config loading for ai_insights in crosstabs_config.R | **Medium** |
| E4 | **Full regression test suite** | Critical gate |
| E5 | Test with `enabled = FALSE` — output must be byte-identical | Critical gate |

### Phase F: Executive summary + polish

| Step | What | Risk |
|---|---|---|
| F1 | Implement two-stage executive summary | New file |
| F2 | Executive summary HTML rendering (both variants) | Additive |
| F3 | Methodology note rendering | Additive |
| F4 | Provider switching test (Ollama, OpenAI) | Validation |
| F5 | **Jess workflow test** | Acceptance gate |

### Phase G: easystats complement (parallel with Phase F)

| Step | What | Risk |
|---|---|---|
| G1 | Evaluate easystats `report()` for Turas question types | Research |
| G2 | Implement optional APA narration for significance | New file |
| G3 | Add config option and rendering | Additive |

**Steps A-C are the safe zone** — all new files, zero risk to existing Turas.
**Steps D-E are the careful zone** — surgical changes to existing files, behind feature flags.
**Step C6 is the quality gate** — do not ship to clients before prompt tuning against real data.

---

## 10. Architecture Decisions

### Decision 1: File location

**Decision:** Shared AI infrastructure in `modules/shared/lib/ai/`. Module-specific extraction and prompts in each module.

```
modules/shared/lib/ai/
├── ai_provider.R        # Provider abstraction (create_chat, call_insight_model)
├── ai_schemas.R         # Shared schemas (verification, selectivity)
├── ai_utils.R           # JSON sidecar persistence, token estimation, content-hash caching
└── ai_verify.R          # Verification and selectivity passes

modules/tabs/lib/
├── ai_insights.R        # Tabs-specific orchestration (generate_all_insights)
├── ai_prompts.R         # Tabs-specific prompt templates
├── ai_extraction.R      # Tabs-specific data extraction functions
└── ai_schemas_tabs.R    # Tabs-specific schemas (ai_callout_schema, exec_*)
```

**Rationale:** Supports multi-module rollout without refactoring. Provider switching, verification logic, and persistence are genuinely shared concerns. Extraction and prompts are module-specific because each module's data structure and analytical output differ.

### Decision 2: Persistence format

**Decision:** JSON sidecar file alongside the config Excel.

**File:** `{project_name}_ai_insights.json` in the same directory as the config workbook.

**Rationale:** See detailed analysis in project plan discussion.

### Decision 3: Comments sheet mapping

**Decision:** Existing Comments sheet maps directly to `researcher_commentary`.

**Rationale:** See detailed analysis in project plan discussion.

### Decision 4: Content-hash caching

**Decision:** Each AI callout in the JSON sidecar stores a content hash of the question data payload that produced it. On re-run, hash the current data — if it matches the stored hash and a valid callout exists, skip the API call entirely.

**How it works:**

```r
# In the JSON sidecar, each callout stores:
config$questions$Q001$ai_callout <- list(
  has_insight      = TRUE,
  narrative        = "The overall NPS of +7...",
  confidence       = "high",
  data_limitations = "",
  pinned           = TRUE,
  verified         = TRUE,
  data_hash        = "a1b2c3d4e5f6..."
)

# On re-run, before calling the API:
current_hash <- digest::digest(extract_question_data(q), algo = "md5")
existing     <- config$questions[[q_code]]$ai_callout

if (!is.null(existing) && identical(existing$data_hash, current_hash)) {
  # Data unchanged — keep existing callout, skip API call
  next
}
# Data changed or no callout exists — generate new one
```

**What triggers regeneration:**
- Underlying data changes (new respondents, re-weighted, corrected data) → hash changes → regenerate
- Researcher NULLs the callout (explicit request to regenerate) → no callout exists → regenerate
- Researcher edits the narrative text → hash still matches → edit preserved, no regeneration
- Researcher pins or suppresses → hash still matches → state preserved

**What does NOT trigger regeneration:**
- Re-running with identical data → hash matches → skip
- Editing pin state or suppression → callout still exists with matching hash → skip
- Changing a different question's data → only that question's hash changes

**Why this matters:**
- A 27-question report makes ~30 API calls (~2-4 minutes, ~R30). With caching, a re-run after editing one comment takes seconds and costs nothing.
- The edit cycle becomes: run once → review → edit/pin/suppress → re-run (instant) → export. No waiting for unchanged callouts to regenerate.
- Forces regeneration when it matters (data changed) and preserves work when it doesn't.

**Dependency:** `digest` package (CRAN, widely used, likely already in renv). If not, add it.

### Decision 5: easystats role

**Decision:** easystats is a rule-based, non-LLM complement — not a replacement for AI insights.

**Where it fits:** For questions involving statistical tests (group comparisons, correlations, regression), easystats `report()` generates formal APA-style narration. This is deterministic, reproducible, and satisfies methodological reviewers who want exact test statistics. It sits alongside AI callouts as a separate, optional content layer.

**Config:** `config$ai_insights$easystats_narration = TRUE/FALSE`

---

## 11. Prompt Tuning Guide

Prompt quality is the single biggest determinant of whether this feature adds value or creates noise. The spec's prompts are a starting point. Budget a full day of tuning against real client data. Here's how to do it well.

### Setup

1. Pick 3+ real past client datasets — not just Demo_CX. Choose diversity: one with clean significance patterns, one with messy/ambiguous data, one with small subgroups (n < 50). Real data has messy variable labels, inconsistent scales, and questions where the "right" interpretation is genuinely debatable.
2. Run the pipeline against each dataset with the spec's starting prompts.
3. Export every callout alongside the source data into a review spreadsheet: `q_code | q_title | source_data_summary | generated_callout | rating | notes`.

### Rating criteria

Score each callout 1-5:

| Score | Meaning | Action |
|---|---|---|
| 5 | Would include in client report as-is | Keep — this is the target |
| 4 | Useful observation, minor wording tweak needed | Keep — note what you'd change |
| 3 | Technically correct but adds little beyond what the chart shows | Fix — this is the selectivity problem |
| 2 | Misses the real story or focuses on the wrong thing | Fix — this is the prompt framing problem |
| 1 | Factually wrong, hallucinated, or contains recommendations | Fix — this is the guardrail problem |

**Target distribution after tuning:** 60%+ of callouts score 4-5. Zero score 1. The selectivity pass should be catching most score-3 callouts.

### What to tune and in what order

**Round 1: Guardrails (fix score 1 problems first)**
- Are numbers accurate? If not, check the extraction function — the LLM can only cite what it's given.
- Are significance claims correct? If not, check `extract_sig_flags()` — the boolean format may be ambiguous.
- Are there strategic recommendations? Tighten the system prompt's observational scope language.

**Round 2: Framing (fix score 2 problems)**
- Is the model focusing on the total column when the subgroup differences are the real story? Add to the user prompt: "Prioritise subgroup differences over topline results."
- Is it ignoring significance flags? Make the prompt more explicit: "If significance flags are present, they are the most important signal."
- Is it missing the priority metric (NPS, NET POSITIVE)? Add: "If a priority_metric is present, lead with it."
- Does it bury the interesting finding in sentence 3? Add: "Lead with the most notable observation."

**Round 3: Selectivity (fix score 3 problems)**
- Are callouts just restating "Brand X scored highest at 72%"? Tighten the selectivity prompt's removal criteria.
- Is the model commenting on every question? Raise the bar in the system prompt: "Only set has_insight to TRUE if the pattern would surprise a researcher looking at this data for the first time."
- Try adding negative examples to the system prompt: "Do NOT generate a callout that merely identifies the highest or lowest scorer without explaining why it matters."

**Round 4: Polish (get score 4 → 5)**
- Tone: Does it read like a research analyst's observation or like a ChatGPT summary? Add style examples from your own past commentary.
- Specificity: "scored 72%, significantly above the 58% average" is better than "scored well above average." The spec already covers this but real outputs may drift.
- Length: 2-4 sentences is the target. If outputs are consistently too long, reduce `max_tokens`. If too short, check that the data payload includes enough context.

### Prompt tuning mechanics

- **Change one thing at a time.** Edit the system prompt OR the user prompt, not both. Re-run against the same dataset. Compare.
- **Keep a changelog.** Version your prompts: V1 (spec original), V2 (added subgroup priority), V3 (tightened selectivity). You'll want to roll back if a change helps one dataset but hurts another.
- **Test across datasets.** A prompt that works perfectly for a CX study may fail on a brand tracker. Tune for generality, not for one dataset.
- **The system prompt sets the persona and guardrails.** It should rarely change after Round 1.
- **The user prompt sets the task framing.** This is where most tuning happens — what to focus on, what to prioritise, what to ignore.
- **The selectivity prompt is a separate editorial pass.** Tune it independently. It sees all callouts together, so it can catch repetition and redundancy that per-question tuning can't.

### Executive summary tuning

Tune this separately from per-question callouts. The two-stage approach (patterns → narrative) means you tune each stage independently:

- **Stage 1 (patterns):** Is it identifying the right 3-4 strongest/weakest measures? Is the "dominant subgroup pattern" genuinely the most important dimension? If not, add guidance: "The most commercially relevant dimension is usually the one with the largest significant differences across the most questions."
- **Stage 2 (narrative):** Does it read like an executive summary or a list of findings with connecting words? Push for the Insight-Implications-Evidence structure. Add examples of good executive summaries from your past reports (anonymised) if the model keeps producing flat recitals.

### When to stop tuning

You're done when:
- 60%+ of callouts across all test datasets score 4-5
- Zero score 1 (factual errors, recommendations)
- The selectivity pass is catching score-3 callouts reliably
- The executive summary is "usable with minor edits" on 4/5 runs
- Jess reviews a full report and says the callouts save time rather than create review overhead

### Common pitfalls

- **Over-tuning to one dataset.** If you add "always mention NPS" because one CX dataset benefits from it, you'll get irrelevant NPS references on a brand study that doesn't have NPS.
- **Prompt bloat.** Every instruction you add dilutes every other instruction. If the system prompt exceeds ~500 words, start removing less important guidance rather than adding more.
- **Ignoring the extraction layer.** Most "prompt problems" are actually data problems — the model is working with what it's given. If it can't see significance flags, it can't cite them. Check `extract_question_data()` output before blaming the prompt.
- **Tuning temperature instead of prompts.** Temperature 0.3 is right for this use case. Going lower makes output repetitive. Going higher makes it creative (which you don't want for factual observation). Fix the prompt, not the temperature.

---

## Spec Reference

Full technical specification: `TURAS_AI_INSIGHTS_SPEC_V4.md`
Covers: schemas, prompts, verification logic, selectivity logic, executive summary pipeline, HTML/CSS/JS rendering, error handling, and testing procedures.

---

## Assessment

| Dimension | Rating |
|---|---|
| Technical difficulty | Low-medium |
| Risk to existing Turas | Very low (feature-flagged, additive, behind guards) |
| Reputational risk | Low (verification + labelling + researcher review) |
| Time investment | 3-5 days to MVP + 1 day prompt tuning |
| Commercial value | High for white-label, moderate for TRL |
| Maintenance burden | Low |

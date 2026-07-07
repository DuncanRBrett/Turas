# Reader Report — AI prose quality & Discovery reports: design handover

**Status:** DESIGN — no implementation in this document.
**For:** an Opus 4.8 implementation session on branch `feature/tabs-reader-report`.
**Author:** Fable 5 design session, 2026-07-06.
**Prime rule for the implementer:** no invented numbers, paths, or results — verify
every claim about the codebase by reading it; the fable-method skill governs process.

---

## 1. Where things stand (verified 2026-07-06)

Read these before writing any code; all were confirmed by inspection this session.

1. The Reader pipeline is **built and committed** on `feature/tabs-reader-report`
   (5c9ef06c, merge f375dd90): `modules/tabs/lib/reader_report/`
   (`derive_reader_model.R`, `build_reader_report.R`, `reader_ai_prose.R`, `assets/`),
   wired into `lib/run_crosstabs.R` (~line 691 flag resolution, ~905 generation) and
   `run_tabs_gui.R` (~line 320 checkboxes). Tests: `test_reader_report.R` 44,
   `test_reader_ai_prose.R` 13 (mocked), v2 bundler 28 — green.
2. **Structure parity with the prototype is done.** The regenerated
   `SACS-2025_Crosstabs_Reader.html` (2026-07-06 12:24) carries real deltas
   (−0.50 progress, −0.48 recognition, −0.42 opinions …), the map, held/slipped,
   register, practitioner panels. The trend-linkage bug is fixed.
3. **The "pale shadow" contains no AI prose.** Its embedded model says
   `"mode":"deterministic"`, `"model":null`. It is the *templated fallback*, not an
   Opus draft. The live AI-prose path (`reader_ai_prose.R`, default model
   `claude-opus-4-8`) has **never been run against a real API key**. Therefore the
   question "can Opus write this?" is **untested**, and no conclusion about Opus
   quality may be drawn from that file.
4. Consequence of (3): the quality gap between
   `SACS-2025_Reader-report_PROTOTYPE.html` (the target) and the generated Reader is
   **prose only**. The deterministic template is factual but flat by design; the
   prototype is thesis-led editorial ("The quiet erosion", "Not most of them — all
   of them", "Staff are still doing their bit. It's the organisation…").
5. Failure handling today: if the AI call fails (no key, ellmer missing, number-check
   rejection), the pipeline prints one console line (`[Reader AI] … keeping the
   on-device narrative`) and ships the deterministic report **with no visible marker
   in the HTML that AI was requested and failed**. This invites exactly the
   misdiagnosis in (3).

## 2. The quality bar — what "prototype quality" is made of

Anatomy of the prototype's prose (the rubric everything is judged against):

- **A thesis, not a summary.** The title is an argument ("The quiet erosion"); the
  subtitle concedes the counter-case up front ("people like working here… but").
- **A five-claim spine** where each claim advances the argument and the order is
  rhetorical: good news first, then the erosion, then *where* it is concentrated,
  then who/what, then what to do. Claims answer "so what", not "what".
- **Numbers woven into sentences**, never listed: "All twelve engagement questions we
  tracked since 2023 are lower in 2025. Not most of them — all of them."
- **Honesty as a feature**: what the survey cannot say is part of the story, stated
  next to the claim, not in a footer.
- **Duncan's register**: plain words, short declaratives, concrete verbs, an
  occasional dry aside; no consultant boilerplate ("key insights", "stakeholders"),
  no hedging filler.
- **Selectivity**: ~15 figures carry the piece; everything else stays in the
  crosstab. Deciding what to leave out is most of the intelligence.

## 3. Track A — AI prose for the survey Reader (the main build)

### 3.1 Architecture: two calls, not one

Replace the current single prose call with a two-stage design. Rationale:
story-*finding* and story-*writing* are different skills; separating them makes the
weak point inspectable and editable, and gives a cheap place to escalate model
strength if needed.

**Call 1 — Story finding.** Input: the aggregates-only fact sheet (see 3.2).
Output (schema-forced): a `story_spec` —
`thesis` (one sentence), `story_shape` (from the menu in 3.5), 3–6 `claims` each
with `angle` (one sentence), `supporting_fact_ids` (references into the fact sheet,
not free numbers), `omissions` (facts deliberately left out + why), `caveats`.
This is the "explain what it has done" artefact Duncan asked for — it is persisted
(see 3.4) and rendered in the practitioner layer as a "How this narrative was built"
panel.

**Call 2 — Prose drafting.** Input: fact sheet + approved `story_spec` + voice pack
(3.3). Output: the existing prose schema (title/subtitle/claims/verdict/leverage/
limits). Keep `deterministic_number_check` as the hard gate, with the fix in 3.6.

Add a **self-edit instruction** inside call 2 (draft, then revise against the rubric
in §2 before answering) rather than a third API call — cheaper, and schema output
already forces one final form.

### 3.2 Fact sheet contract (extend, don't replace)

The current payload in `reader_ai_prose.R` is aggregates-only. Extend it to:

- Give every fact a stable `id` so call 1 can reference facts instead of restating
  them (grounding by construction).
- Include a `derived_numbers` pool: NETs, percentage-point gaps, "x of y items fell"
  counts — anything the deterministic layer can compute that prose will want to
  cite. The number-checker's allow-pool must include these (see 3.6).
- Include study-design facts (census vs sample, population, waves, banner groups,
  low-base register) so limits-prose is grounded.
- **Never** microdata or verbatims (unchanged privacy contract). Qual THEME
  aggregates (theme counts/sentiment) may go in once the qual-island parse lands.

### 3.3 Voice pack — encoding "Duncan's language"

The R pipeline cannot invoke Claude skills, so voice must live in the prompt:

- Distil `~/.claude/skills/anthropic-skills/duncan-writing-style` into a ~30-line
  style block inside `reader_ai_prompt` (rules, banned vocabulary, sentence rhythm).
  Do this once, by hand, at implementation time — read the skill, don't paraphrase
  from memory.
- Add **one few-shot exemplar** of the target register. **Do not embed SACS
  numbers/prototype text** — that is client data and would ride into every other
  client's prompt. Write a sanitised exemplar (fictional study, same rhetorical
  moves) once, store it in `assets/` beside the prompt.
- The prompt already says "find the story"; keep that, but feed it the story-shape
  menu (3.5) so it has vocabulary for non-SACS surveys.

### 3.4 Editability — sidecar prose file is the source of truth

Requirement: Duncan edits the narrative and the edit survives regeneration.

**Design: a sidecar file** `<stem>_Reader_prose.json` written beside the crosstab
outputs whenever prose is produced (AI or deterministic). It contains the
`story_spec` + the final prose fields + provenance (`mode`, `model`, timestamp).

Precedence at build time:
1. Sidecar exists and `edited: true` → use it verbatim (badge: "analyst-edited").
2. Sidecar exists, unedited, AI toggle on, `redraft` **not** requested → reuse it
   (no API call, no cost, stable output across regens).
3. AI toggle on + no sidecar (or GUI "re-draft narrative" ticked) → call the model,
   write a fresh sidecar.
4. Otherwise → deterministic template.

Editing surface: Duncan opens the JSON and edits text fields directly (it is prose
strings — friendly enough), sets `"edited": true`. A GUI checkbox "↳ re-draft the
Reader narrative" forces path 3. **Defer** any in-browser editing UI (contenteditable
+ saveCopy) to a later increment — the sidecar alone satisfies the requirement and
is testable; note it as future work, don't build it now.

### 3.5 Generalisation — every survey is different

The prototype is a *tracked, scale-battery census with a clean story*. The design
must not overfit to that. Two mechanisms:

- **Section applicability rules** (mostly already in `derive_reader_model.R`'s
  graceful degradation — verify, don't assume): no waves → no trend chart /
  held-slipped / erosion narratives; no scale battery → no priority map; single
  banner → no People section. The story spec's `story_shape` must be consistent
  with available sections.
- **Story-shape menu** given to call 1 (extend as needed):
  `erosion` (tracked decline), `recovery`, `divergence` (subgroups split),
  `strength-with-a-crack`, `flat-but-fragile`, `baseline` (wave 1 — the story is
  the starting picture and what to watch), `mixed-no-single-story` (honest fallback:
  the report leads with the three strongest independent findings instead of one
  thesis). The model must be explicitly permitted to choose the fallback —
  forcing a thesis onto storyless data is fabrication by another name.

### 3.6 Grounding, disclosure, and the number-checker

- Keep `deterministic_number_check` as the hard reject gate, but extend its allowed
  pool with the `derived_numbers` from 3.2, plus tolerant matching for rounding
  (4.08 vs 4.1) and formatted variants (+63, 76%). Today's checker risks
  false-rejecting good prose that cites a legitimate derived figure — each false
  reject silently ships the flat template.
- **Causal-claim rule** in the prompt: prose may *characterise* patterns ("the
  decline concentrates in items about being noticed") but may not *explain causes*
  not in the data ("because of the restructuring"). Anything speculative must be
  worded as a question for follow-up. The number-checker cannot catch this; the
  prompt rule + Duncan's edit pass are the gate — which is precisely what the
  "AI-drafted · analyst-reviewed" badge promises.
- Render the `story_spec` (including omissions) as a practitioner-layer panel:
  "How this narrative was built — what the model was given, what it chose, what it
  left out, what was checked." That is requirement 3 ("explains what it has done")
  made visible.

### 3.7 Failure visibility (do this first — it is the smallest WP)

When AI prose is requested but the pipeline degrades, the report must say so:
a visible topbar banner "AI narrative was requested but unavailable (<short
reason>) — showing the on-device narrative", plus the existing console line, plus
`disclosure.requested_mode` in the model JSON. This prevents the §1.3 misdiagnosis
from ever recurring.

### 3.8 Model ladder — the Opus vs Fable question

Honest answer to Duncan's question 3: **unknown — the live path has never run.**
Design so the answer becomes an experiment, not a guess:

- Model is already config-driven (`reader_ai_prose.R` line ~167, default
  `claude-opus-4-8`; the `feature/tabs-ai-model-config` branch adds a GUI picker —
  merge that first if convenient, but don't block on it).
- **Acceptance rubric** (score the generated Reader against §2, on real SACS with
  the prototype open beside it): thesis-not-summary; claim order is rhetorical;
  numbers woven not listed; limits inline; register passes Duncan's read; nothing
  invented. Pass = Duncan would forward it with edits of taste, not structure.
- **Ladder:** (1) Opus 4.8 + tuned two-call prompt + exemplar → if it fails the
  rubric after 2–3 prompt-tuning rounds, (2) escalate the *story-finding call only*
  to a stronger model (`claude-fable-5` via the same ellmer plumbing — verify id
  and pricing against the claude-api skill at implementation time, do not hardcode
  from memory), Opus still drafts; (3) both calls on the stronger model. Record
  which rung ships as the default. Expectation to test, not assume: heavy
  scaffolding (fact ids, story-shape menu, exemplar, self-edit) is designed
  precisely to let Opus reach the bar; every survey being different is why the
  story-finding call is the rung most likely to need Fable.
- Prompt-tuning loop (Duncan + implementer): regen SACS with AI on → compare to
  prototype → adjust `reader_ai_prompt` → repeat. The prototype is the golden
  target for SACS only; for other shapes use the synthetic fixtures in WP5.

## 4. Track B — standalone Discovery reports (AI + websearch, no survey)

The ASSA "Readiness Gap" and Electrum "VAS Explainer" discovery reports were
written in Claude chat sessions with web research. Productionise that as a
**Claude Code skill, not a Turas/R feature** — the R/Shiny app has no web tooling
and adding egress-by-default to Turas would break its privacy story.

**Skill spec (`~/.claude/skills/duncan-discovery-report/`):**
- **Input:** topic, purpose, audience, project folder to save into; optional
  seed sources (client docs, questionnaires).
- **Process:** invoke the existing `deep-research` harness for sourcing +
  adversarial claim verification; then synthesise in Duncan's voice
  (read `duncan-writing-style`); every claim carries a citation.
- **Output:** self-contained two-layer HTML using the same Reader design language
  (Plain/Practitioner toggle, argument spine, honest-limits section) but with the
  confidence axis swapped: **source-citation badges** (solid = primary/multiple
  sources, dotted = single/weak source) instead of base-size badges. Template
  vendored in the skill's `assets/` — port the CSS from
  `modules/tabs/lib/reader_report/assets/` so survey Readers and discovery reports
  are visibly one family.
- **Editability:** it is a generated HTML file in the project folder; iterate by
  re-prompting the session or hand-editing. A prose sidecar is unnecessary here —
  the skill session *is* the editor.
- **Model:** the skill runs on whatever model the session runs; recommend Fable for
  the synthesis pass (research synthesis without a deterministic fact-sheet floor
  is the highest-fabrication-risk step in this whole design). The skill file itself
  is trivially implementable by Opus.
- **Boundary with Track A:** a discovery report may be *linked from* a survey
  Reader ("background reading") but never mixed into it — survey Readers cite only
  the crosstab; discovery reports cite only external sources. One document, one
  evidence regime.

## 5. Work packages (each ends with a runnable check)

| WP | Scope | Verification |
|----|-------|--------------|
| **WP1** | Failure-visibility banner + `requested_mode` disclosure (§3.7); add `generate_reader_report` + `reader_ai_prose` rows to the Settings template in `generate_config_templates.R` (verified 2026-07-06: absent — existing configs default both to FALSE silently, and freshly generated configs would too) | Unit test: AI-on + stubbed failure → banner token present; deterministic-run → absent; template contains both rows |
| **WP2** | Fact-sheet v2: fact ids + derived-numbers pool + design facts (§3.2); checker tolerance (§3.6) | Extend `test_reader_ai_prose.R`: derived number cited → accepted; rounding variant → accepted; alien number → rejected |
| **WP3** | Two-call story-spec architecture + voice pack + sanitised exemplar + story-shape menu + causal rule (§3.1/3.3/3.5); story-spec practitioner panel | Mocked-provider tests for schema/merge; live SACS regen scored against §3.8 rubric by Duncan |
| **WP4** | Sidecar prose file + precedence + GUI "re-draft" checkbox (§3.4) | Tests: edited sidecar survives regen verbatim; unedited sidecar reused with no API call; redraft overwrites; badge states correct |
| **WP5** | Generalisation fixtures: synthetic wave-1 categorical study + synthetic no-banner study; confirm graceful sections + `baseline`/`mixed` story shapes | `test_reader_report.R` additions; visual check of both fixture Readers |
| **WP6** | Track B skill (§4) — separate session, outside this repo | Generate one discovery report on a fresh topic; Duncan reads against ASSA/VAS exemplars |

Order: WP1 → WP2 → WP3 (the quality loop starts here) → WP4 → WP5. WP6 is
independent. Existing suites (`test_reader_report.R` 44, `test_reader_ai_prose.R`
13, bundler 28) must stay green throughout. Live API calls are Duncan's to run;
the implementer verifies with mocked providers and hands Duncan the regen step.

## 6. Open decisions for Duncan

1. **Sidecar format** — JSON (recommended: round-trips losslessly into the build)
   vs Markdown (nicer to edit, needs a parser). Design above assumes JSON.
2. **Default rung on the model ladder** once tested — cost vs quality call that
   needs the WP3 live results first.
3. **Merge order** — fold `feature/tabs-ai-model-config` in before WP3 (gets the
   model picker for free) or after (less merge risk mid-build). Recommend before.

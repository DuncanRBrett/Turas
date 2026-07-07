# Open-End (Verbatim) Coding — Project Plan

**Status:** Planning (pre-build) · **Date:** 2026-06-18 · **Owner:** Duncan Brett
**Type:** Software capability (new TURAS analytics feature, spanning `tabs` + `tracker`)
**First instance:** SACS climate study (wave 4) · **Generic from day one**

> This is the consolidated output of a solution-finding session. It captures the
> agreed approach so the build can begin from a clear reference. Data-dependent
> specifics (the actual SACS frame, the back-coding effort estimate) are marked
> *TBC on receipt of data*.

---

## 1. Problem Statement

Open-ended survey responses are currently a dead end in TURAS. `Open_End` is a
recognised `Variable_Type`, but the crosstab engine deliberately skips it — it
warns on selection and produces empty tables. So the richest, most quotable part
of a survey never reaches the report as analysable data, and never trends across
waves. Researchers either pay a coding house, code by hand in Excel, or drop the
open-ends into an appendix nobody reads. For trackers this is worse: when
open-ends *are* coded, the frame drifts wave to wave, so the one thing a tracker
exists to show — change over time — is exactly what a messy frame destroys. We
need open-ends to become first-class TURAS data: coded to a stable, human-trusted
frame, cross-tabbable and trackable like any closed question, with real
respondent quotes available to bring the numbers to life — and we need it generic
enough to run any study from config.

---

## 2. Landscape & Approach

**What exists.** Standalone coding tools (Caplena, Codeit, Ascribe, Blix, CoLoop,
Qualtrics Text iQ) all do AI-assisted verbatim coding well enough, and the market
is shifting from manual/ML to generative coding. The settled best practice is
"human-led AI": the model does a fast first pass, the researcher refines, merges,
overrides, and every code traces back to source quotes for audit.

**The gap they leave.** Every one of them is a *coding* tool. You code there,
export, then cross-tab and report somewhere else. None of them own the whole
chain. The academic work is also blunt about the one failure mode that matters
for trackers: if the model re-invents themes each wave, the trend breaks. The fix
is deductive coding — build the frame once, then classify later waves against the
*fixed* frame, flagging genuinely new themes for review rather than absorbing
them silently.

**Recommended approach.** Build it native to TURAS rather than buy/bolt-on,
because TURAS already owns the three hardest pieces:

1. **AI infrastructure** — `ellmer`-based structured output, model-selectable
   (Sonnet 4.6 / Opus 4.8), with a sidecar-JSON pattern that already supports
   pin / dismiss / edit / override and hash-caching. That is the human-in-the-loop
   scaffolding the whole industry says you need.
2. **Multi-mention machinery** — a coded comment is just a multi-response
   variable; the microdata already stores multi-mention as an array of indices,
   so coded open-ends flow through crosstabs, significance testing and banners
   for free.
3. **Stable wave keys** — the tracker's canonical `QuestionCode` mapping is what
   holds a code frame still across waves.

The differentiator: TURAS becomes the only pipeline where **coding → crosstabs →
wave-tracking → branded report** happens in one place, with the frame stable *by
design* because it rides the existing wave keys.

---

## 3. Objectives (measurable)

1. **First-class data.** Any open-end question declared in config is coded to a
   human-approved frame and appears as a multi-mention variable in crosstabs and
   the tracker, identical in behaviour to a closed question. *Test:* selecting an
   `Open_End` question yields a non-empty, sig-tested crosstab and a wave trend.
2. **No fabricated quotes — by construction.** 100% of quotes displayed in any
   report are exact stored verbatims (after rule-based PII redaction); the model
   never authors quote text, only selects a comment ID, and a deterministic check
   confirms every cited ID exists before render. *Test:* every rendered quote
   string matches a stored source string byte-for-byte (modulo logged redactions).
3. **Old + new cross-check (where prior coding exists).** Comments whose AI code
   agrees with the mapped prior human code auto-accept; disagreements,
   low-confidence and uncoded comments route to a review queue. *Test:* agreement
   rate is computed and reported; nothing auto-accepts without two concurring
   signals or explicit human sign-off.
4. **Frame stability across waves.** Later waves classify against the locked
   frame; novel themes are surfaced for review, never silently added. *Test:*
   frame hash is constant across waves unless the frame is explicitly versioned.
5. **Reproducibility.** Identical inputs (comment + frame) yield identical codes
   (temperature 0 + hash cache). *Test:* re-running a coded study is byte-identical.
6. **Scale.** The engine codes ≥5,000 comments within an acceptable cost/time
   budget via batched classification. *Test:* a 5,000-comment run completes within
   the agreed token/time budget *(budget TBC)*.
7. **Quality gate with teeth.** When gold-set agreement falls below threshold,
   TURAS returns a TRS refusal (console-visible for Shiny) rather than publishing.
   *Test:* a deliberately degraded gold set produces `REFUSED`.
8. **Generic.** SACS and the 2,500- and 5,000-comment studies all run from config
   with no study-specific code. *Test:* the same engine binaries run all three.

---

## 4. Requirements

### Capabilities
- **Config schema** (Crosstab_Config): list of open-end questions; per-question
  frame source (`build` | `import` | `harmonise`); optional shared frame across
  questions; sentiment/stance axis on/off; quote display on/off + redaction rules;
  gold-set reference; agreement/confidence thresholds; coding model override.
- **Verbatim store.** Ingest each open-end response exactly as typed, keyed by the
  anonymised respondent index already used by the microdata island. Analyst-side;
  only scrubbed, selected quotes are promoted to the report.
- **Frame builder.** From a sample of comments, propose a clean canonical frame
  (nets → sub-codes, each with a definition and examples). Human-approved before
  any coding runs.
- **Frame harmoniser + crosswalk** (for studies with prior coding). Ingest all
  prior codes across waves; propose a rationalised canonical frame plus an
  old→new crosswalk; human approves/locks.
- **Classifier.** Deductive classification against the locked frame, temperature
  0, multi-mention output, per-decision confidence and an explicit "uncertain"
  abstain. Where a prior human code exists, supply it as a cross-check signal
  (agreement auto-accepts; disagreement queues). Batched for scale.
- **Exception queue.** Review surface for disagreements / low-confidence /
  uncoded, sortable by confidence, with one-click reassign and bulk actions; every
  action logged (audit trail). Reuses the pin/edit sidecar pattern.
- **Verification.** Deterministic ID-existence check for quotes; sample re-code
  agreement statistic; sanity check of back-coded wave totals against priors.
- **Optional embeddings cross-check** (phase 2): model-independent nearest-code
  flagging and near-duplicate detection. *New dependency — requires approval.*
- **Rendering.** Coded results appear inline in crosstabs and the tracker; a
  voice-of-customer quotes panel renders exact stored quotes by ID with PII
  scrubbed; report carries an honest methodology note when history was re-coded.

### Quality standards
- TRS throughout (no `stop()`); refusals echoed to console for Shiny visibility.
- Configuration over hardcoding; no study-specific branches.
- Tests + synthetic verbatim fixtures; reproducible (temp 0 + caching).
- Human sign-off required before publish; no quote without provenance.

### Constraints & dependencies
- `ellmer` already present (Anthropic). Embeddings would be an additional
  dependency — deferred and gated on approval.
- Cost scales with comment volume (5,000 is the current ceiling) — batching,
  caching and Sonnet-for-bulk are first-class concerns, not optimisations.
- Client data (SACS and others) stays local/gitignored.

### Scenarios
- *As the analyst,* I declare 6 open-end questions in config, review and lock the
  AI-proposed frame, run coding, clear a short exception queue, scrub/approve a
  handful of quotes, and publish — open-ends now trend across all 4 waves.
- *Unhappy path:* gold-set agreement is poor → TURAS refuses to publish, prints
  the code/threshold/fix to console, and points me at the exception queue.
- *Unhappy path:* a quote contains a name → rule-based redaction replaces it with
  `[name]`, shows me the diff, and only the redacted string can ship.

### Data confidentiality & coding modes (critical)

To AI-code a comment, its text must reach the model — so confidentiality hinges
on *where the model runs*. Coding mode is a per-study config choice:

- **Import / human coding** — no AI; TURAS tabulates existing codes. Nothing
  leaves the machine. (The SACS first slice; identical to today's crosstab data.)
- **Local model** — open-weights model via Ollama (`ellmer` already supports it);
  verbatims never leave the machine. Lower raw quality, offset by the trust cage;
  needs hardware.
- **Cloud API (Anthropic)** — most capable; the *only* mode where comment text
  leaves the machine. Must be governed.

Governing the cloud mode (terms verified June 2026):
- Anthropic does **not** train on API data (the consumer opt-out change does not
  apply to the API).
- Standard API retains logs for a short abuse-monitoring window (recently cited
  as ~7 days) then deletes; a **Zero Data Retention** agreement removes even that.
- Anthropic offers a **DPA / operator agreement** — the instrument POPIA's
  cross-border-transfer rules require.
- **Data minimisation:** PII is scrubbed locally *before* text is sent, so the
  third party only ever receives de-identified text. **Two scrub points** —
  pre-send (confidentiality) and pre-display (the deliverable) — both rule-based
  and logged.

Honest limits: rule-based scrubbing catches direct identifiers, not contextual
ones ("the only female plumber in Calvinia"), so cloud mode *reduces* exposure
but is not a hard guarantee — import and local modes are. And this is an
escalation over today's AI insights, which sends only aggregate stats and labels,
never raw respondent text. Default conservative; sensitive clients →
import/local only; greenfield scale studies → cloud with DPA + consent +
scrubbing, or a capable local setup.

---

## 5. Design & Experience

**Pipeline (the core idea).** Raw verbatims → AI coding engine (human in the
loop) → coded multi-mention variable + sentiment → feeds three outputs: crosstabs
(reused), tracker (reused), and a new voice-of-customer quotes panel → v2 +
tracker reports. Open-ends stop being an appendix and become ordinary,
cross-tabbable, trackable data.

**The trust cage** (directly answers the miscoding/hallucination concern):

- *Hallucinated quotes — solved by design.* The model returns a comment **ID**,
  never quote text; the report renders the exact stored string for that ID. The
  quote slot physically never carries model output. PII scrubbing is a separate,
  logged, rule-based redaction of the real string — a redaction, never a
  regeneration.
- *Miscoding — driven down and made visible.* (1) You approve the frame first, so
  the model can't invent rogue categories. (2) Confidence + abstain route the
  ambiguous tail to a review queue. (3) Click any number to see the exact comments
  behind it (traceability). (4) A sample is re-coded and an honest agreement %
  prints on the deliverable. (5) A gold-set guard refuses auto-publish below
  threshold (TRS). (6) Temperature 0 + hash caching make it reproducible.

**Frame harmonisation + agreement cross-check** (the SACS reality — coded but
messy/inconsistent across waves). Instead of trusting the drifted old coding *or*
re-coding blind, do both and let them check each other:

1. Harmonise the frame once (AI proposes clean frame + old→new crosswalk; human
   locks it).
2. Re-code every comment against the locked frame with the mapped old human code
   supplied as a cross-check: agreement → auto-accept; disagreement / low
   confidence / junk-or-blank old code → exception queue.
3. Validate the rewrite: per-code old→new flow, agreement % per wave, sanity vs
   prior totals, methodology note in the report.

This applies one frame uniformly across all four waves (kills coder drift), uses
the human history to shrink the review pile to genuine disagreements, and catches
errors in both directions. For the two greenfield studies there is no old code,
so they lean on confidence + gold-set instead — the engine supports both paths.

**Climate-content note.** Climate verbatims carry a *stance* as well as a theme
(concerned / sceptical / motivated / fatalistic) and are frequently multi-theme.
Build multi-mention plus a sentiment/stance axis in from the start.

**Per-study emphasis.** SACS (n≈150–200) tilts toward quotes and directional
read; the 2,500/5,000 studies make coded crosstabs statistically meaningful. The
report should lead with whichever the base supports, using existing base-flagging.

---

## 6. Growth Roadmap

- **Immediate (MVP, SACS proving ground).** Verbatim store + multi-mention output
  proven first with the existing coded history (zero AI); then the caged classifier
  with agreement cross-check to back-code waves 1–3 and code wave 4; then the
  quotes-by-ID panel. Build generic, run SACS.
- **Near-term (3–6 months).** Harden and scale-test against the 2,500/5,000-comment
  studies (batching, cost controls); add the sentiment/stance axis to reporting;
  optional embeddings cross-check and near-duplicate detection.
- **Longer-term (6–18 months).** A light "coding studio" review surface (editable
  frame, drag/merge/split, the exception queue as a first-class screen);
  cross-question theme rollups; reuse of the engine by any module with verbatims
  (brand, segment).
- **Commercial lens.** This removes a per-project dependency on external coding
  houses/tools and becomes a genuine differentiator for TURAS — "we code, tab,
  track and report your open-ends in one stable pipeline" is something the
  standalone tools structurally cannot say.

**Foundational decisions to get right now (so growth isn't blocked):** keep the
engine config-driven and study-agnostic; key the verbatim store on the anonymised
respondent index; version frames explicitly; keep the model's role to
classify/select (never author displayed text).

---

## 7. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| **Miscoding** (wrong/missed code) | Approved frame, confidence+abstain queue, old/new agreement cross-check, traceability, sample agreement %, gold-set TRS refusal |
| **Hallucinated quotes** | Solved by construction — model returns IDs, report renders stored strings; deterministic ID check |
| **Cost/latency at 5,000 comments** | Batched classification, hash caching, Sonnet for bulk, verify on sample not census |
| **Small base (SACS n≈150–200)** | Lead with quotes + directional read; honest base flags; coded crosstabs emphasised on the larger studies |
| **Frame drift across waves** | Locked, human-approved frame; novel themes flagged not absorbed; explicit frame versioning |
| **Credibility of re-coding history** | Per-code old→new flow, agreement stats, sanity vs prior totals, methodology note in report |
| **PII leakage in quotes** | Rule-based redaction with reviewable diff; anonymised store; quotes off unless enabled |
| **Sending verbatims to a third-party AI** (cloud mode) | Per-study coding mode (import / local / cloud); POPIA operator agreement (Anthropic DPA) + Zero Data Retention; local pre-send PII scrub (minimisation); import & local modes keep all text on-machine; default conservative |
| **Automation bias / over-trust** | Human sign-off before publish; agreement stat surfaced; exception queue mandatory for the ambiguous tail |
| **New dependency creep** | `ellmer` already present; embeddings deferred and approval-gated |

---

## 8. Quality Standards (project-specific checklist)

- [ ] No `stop()`; all failures are TRS refusals, echoed to console for Shiny.
- [ ] Fully config-driven; no SACS-specific code paths.
- [ ] Every displayed quote has provenance; no model-authored quote text can ship.
- [ ] Coding is reproducible (temp 0 + hash cache); re-runs byte-identical.
- [ ] Human approves the frame and signs off before publish.
- [ ] Synthetic verbatim fixtures + tests for: frame build, harmonise/crosswalk,
      classify, agreement cross-check, quote ID verification, gold-set refusal.
- [ ] Methodology note auto-included whenever history is re-coded.
- [ ] Coding mode is a per-study config choice; cloud mode gated behind DPA +
      consent + pre-send PII scrub; import & local modes keep all text on-machine.
- [ ] Scale test recorded against a 5,000-comment run (cost + time).

---

## 9. Next Steps

1. **Get the SACS artifacts** *(blocking for the harmonisation design)*: the
   existing messy frame, plus a sample of `comment + old code` for the 6 open-ends
   across the 3 waves. Treated as client-confidential, kept local/gitignored.
2. **Architecture decision (needs Duncan's steer):** does open-end coding live as
   a new engine module (e.g. `opencode`) that outputs a multi-mention variable
   consumed by `tabs` + `tracker`, or as a subsystem inside `tabs`? *Lean:* a
   separate engine module reusing the shared AI infra, to keep concerns clean and
   let other modules consume it later.
3. **Prototype the harmoniser** on the small SACS data → produce canonical frame +
   crosswalk → Duncan reviews and locks.
4. **Build the verbatim store + multi-mention output** (zero-AI plumbing) → SACS
   coded history flows into crosstabs + tracker. Prove the path with no accuracy
   risk.
5. **Add the caged classifier + agreement cross-check** → back-code waves 1–3,
   code wave 4.
6. **Add the quotes-by-ID panel** + PII scrub + review.
7. **Harden + scale-test** against the 2,500/5,000-comment studies.

> Build order is deliberately risk-descending: the riskiest part (AI accuracy)
> switches on only after the value is proven and auditable against coding you
> already trust.

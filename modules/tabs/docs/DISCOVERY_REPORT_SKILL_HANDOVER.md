# Handover — build the `duncan-discovery-report` skill (Fable session)

**For:** a fresh Claude **Fable 5** session, high effort. **Not** Opus.
**Why Fable:** this is skill-writing — a build-once artefact whose quality
compounds across every future discovery report. Fable's model-selection guide
reserves skill-writing for Fable ("spend once, reuse many times"); an Opus draft
already exists (see below) and your job is to lift it to Fable's bar, not start
cold.
**Written by:** the Opus session that produced the draft, 2026-07-06.
**Prime rule:** no invented numbers, paths, or facts — verify every claim about
the exemplars and the draft by reading the files. The fable-method skill governs
process; the `duncan-skill-design` skill governs the skill's quality bar — read
both before writing.

---

## 1. The task, in one line

Refine (or rewrite where it falls short) the `duncan-discovery-report` skill so
that a future Claude session, handed a topic and a client folder, produces a
standalone two-layer HTML "discovery report" in Duncan's voice, with every figure
wearing its source status — at the quality of the two exemplars.

## 2. What a discovery report is (and the boundary you must not cross)

Discovery reports are Duncan's argument-led, self-contained HTML documents built
from **web research, not survey data**. Two live examples exist and are the
quality bar. They are the **Track B** of `READER_REPORT_AI_DESIGN.md` (§4) — the
counterpart to the Turas *survey* Reader (Track A). The design language is shared
with the survey Reader (topbar, Plain/Practitioner depth toggle, hero + pledge,
verdict + ranked leverage, glossary); the one deliberate difference is that the
confidence axis is **source-citation**, not survey base-size.

**Boundary — do not cross it.** This is **WP6**, and it is *independent*. It is
**not WP3** (WP3 is the survey Reader's two-call story-spec, Track A, inside the
Turas R codebase — leave it alone). Do not touch `modules/tabs/lib/reader_report/`
or any R code. This skill lives entirely at `~/.claude/skills/duncan-discovery-report/`.
A discovery report may be *linked from* a survey Reader as background reading, but
the two are never merged: one document, one evidence regime.

## 3. Read these first (exact paths)

**The two exemplars — the quality bar. Read both in full:**
- ASSA "Readiness Gap" (a *precursor* report — precedes a study, hands it a
  register): `/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/ASSA/The Readiness Gap - SA retirement discovery report.html`
- Electrum "VAS Market Explainer" (a *standalone explainer* — no study to
  follow): `/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/Electrum/2026 planning/SA_VAS_Market_Explainer.html`

**The existing Opus draft — your starting scaffold (refine, don't restart):**
- `~/.claude/skills/duncan-discovery-report/SKILL.md` (237 lines)
- `~/.claude/skills/duncan-discovery-report/references/report_anatomy.md`
- `~/.claude/skills/duncan-discovery-report/references/evidence_discipline.md`
- `~/.claude/skills/duncan-discovery-report/assets/discovery_report_template.html`
  (a vendored, working, browser-safe engine distilled from the exemplars)

**The spec and the design family:**
- `/Users/duncan/Dev/Turas/modules/tabs/docs/READER_REPORT_AI_DESIGN.md` — §4 is
  the Track B spec; the WP table's WP6 row is this task.
- `/Users/duncan/Dev/Turas/modules/tabs/lib/reader_report/assets/` — the survey
  Reader's CSS/JS, the sibling design language.

**Skills to hold yourself to / that this skill invokes:**
- `duncan-skill-design` — the quality bar for the skill itself (read its
  `references/skill_anatomy.md` too).
- `duncan-writing-style` — the voice for the skill's own prose *and* what the
  skill tells future sessions to write in.
- `deep-research` — the sourcing/verification harness the skill depends on (a
  discovery report has no crosstab floor, so research *is* the evidence floor).
- `claude-api` — verify current model ids/pricing before the skill hardcodes any.

## 4. What the Opus draft already got right (validate, keep or improve)

Don't re-derive these — they came from reading both exemplars closely. Check them,
then keep or sharpen:

- **Two report *shapes*.** *Precursor* (ASSA): hands a study a register of
  figures it still owes; uses the `✓ cited / ≈ est / ◇ slot` badge idiom.
  *Explainer* (VAS): standalone, everything sourced to some tier, no register;
  uses `● ◐ ○` confidence dots. Pick one idiom per report; never mix.
- **The prime rule made into UI:** every figure appears with its evidence tier on
  its face, or it is not in the report. A bare number in the prose is a defect.
  No invented numbers, ever — an open slot is a success; a plausible fabrication
  is the one unforgivable failure.
- **Two genuine layers:** Plain reading stands alone; the dark `details.xp`
  practitioner panels hold mechanism, method, caveats, and honest hedging.
- **The fixed spine + a section menu** (argument-first; body blocks chosen per
  topic; verdict + ranked leverage; register; sources; glossary) — captured in
  `references/report_anatomy.md`.
- **The vendored template** is self-contained (JS node-validated, no external
  deps) and carries both badge idioms, the depth toggle, term popovers, and an
  auto-building register + glossary.

## 5. Where the draft is weakest — spend your tokens here

This is the taste/judgment layer, which is why it's a Fable job:

1. **A sanitised worked exemplar is missing.** The design (§3.3, by analogy)
   wants one *fictional* discovery report — same rhetorical moves, no real client
   data — vendored in `assets/` as a gold-standard sample a future session can
   pattern-match against. The draft describes the moves and gives snippets but
   never writes a full sanitised example. Consider writing one (short, fictional
   market/topic) — it may teach the format better than all the prose rules
   combined. Never embed real ASSA/VAS text in the skill (it would ride into
   every future client's report).
2. **The skill's own voice.** Read the draft SKILL.md against `duncan-writing-style`
   — cut any sentence that reads like a framework and doesn't sound like Duncan.
3. **Anti-pattern calibration.** The draft lists ~12. Are they the *right* ones —
   the specific ways a discovery report goes wrong that would make Duncan wince?
   Pressure-test against what actually makes the exemplars good.
4. **The pledge + tier definitions.** These are the trust core. Are the three
   tiers (validated / indicative-single-party / not-yet-sourced) drawn sharply
   enough that a future session assigns them correctly under pressure?
5. **Push beyond Duncan's current practice** (a `duncan-skill-design` mandate):
   the exemplars are two data points. Is there established practice in evidence
   grading, source triangulation, or research-synthesis honesty that would make
   the skill better than the exemplars? Add it, labelled by epistemic status.
6. **The template's optional components.** Confirm the funnel / map / dossier /
   comparison-table blocks are genuinely reusable and not ASSA-specific
   fossils; trim or generalise.

## 6. What "done" looks like

**Gate 1 — the skill passes `duncan-skill-design`'s quality checklist:**
goal-framed, source-grounded (it is — two real exemplars), extends beyond current
practice, epistemically honest, opinionated, ≥5 anti-patterns, verification built
in, progressive disclosure (SKILL.md < 500 lines), generous trigger, Duncan's
voice, no overlap with the survey Reader (acknowledged and bounded).

**Gate 2 — the real test (WP6 verification):** generate **one** discovery report
on a *fresh* topic using the skill — run `deep-research` for sourcing, synthesise
in Duncan's voice, save a self-contained HTML file — then read it against the
ASSA and VAS exemplars. It passes if Duncan would forward it to a client with
edits of taste, not structure, and if every figure defensibly wears its tier.
(This step makes live research/model calls; it can run in the same Fable session.
Duncan's ANTHROPIC key lives in his `~/.Renviron`/session, not in a plain shell.)

## 7. Effort

Per the model guide: **high** effort is the sweet spot; don't reflexively max it —
even low effort on Fable often beats xhigh on prior models. Raise it only if the
output looks shallow on the exemplar comparison.

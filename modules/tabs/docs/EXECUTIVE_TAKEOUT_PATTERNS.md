# Executive Takeout → Patterns view: framework + SACS worked example

Status: DESIGN (agreed direction) · 2026-06-28 · branch `feature/tabs-executive-takeout`

## Why we're changing it

The first Executive Takeout repeated the Dashboard and Differences tabs in a
tidier box — its cards (e.g. "recognition 3.44", "Cape Town behind") are the
same numbers already on those tabs. The only new things were the apex sentence
and the four posture labels. Not enough to justify a tab.

The reworked tab answers one question — **what's the big picture?** — and earns
its place by saying things the other tabs can't, because they only ever show one
question or one cell at a time:

1. **The group that stands out** across the whole survey (no tagging needed).
2. **The topic (area) that stands out** — a cluster of related questions (needs tagging).
3. **What moved** most since last wave.

These are cross-question by construction, so they don't duplicate anything.

## The tagging framework (how it stays generic across very different surveys)

Two optional labels per question:

- **Section** (Level 1) — the big bucket, from a short list seeded by a
  study-type template. Engagement → Basic Needs / Individual / Teamwork / Growth.
  Brand → Awareness / Consideration / Preference / Loyalty. CX → Product /
  Service / Price / Ease / Trust. Editable.
- **Theme** (Level 2) — an optional finer label inside the section, free text,
  the study-specific nuance (e.g. "Recognition & voice", "Fair pay").

The decisive principle: **the engine works on the *position* (which section,
which theme), never on what the labels say.** "Group the questions, find the
weakest group, find the group that's slipping" runs identically whether the
sections are Recognition/Growth or Awareness/Loyalty. So we never need one master
list of topics that fits every survey — that can't exist. Consistency comes from
the *structure* + per-domain starter templates; meaning lives in the labels.

Three rules make it practical (validated against Qualtrics topic models, Viva
Glint driver templates, and Q/Quantum reusable specs):

1. **Template-plus-override.** Pick a study type at setup; you get a starter
   Section list (and suggested Themes) to tag against. Override freely.
2. **Optional, with graceful fallback.** No tags → the view still does pattern 1
   (the standout group) from the breakouts, and lists topics in questionnaire
   order. Tagging only ever *adds* structure; it never blocks a result.
3. **Reusable for trackers.** Tag once; a tracker reuses the same tagging wave to
   wave, so trends stay comparable by construction.

### What Turas already has (so this is small)

The one-level version already exists: the **`Category`** column on the Selection
sheet → `q.category` on the data layer → drives the Dashboard's sections and the
sidebar. SACS just left it blank, which is *why* its questions read as
disconnected. The framework adds an optional second column (**`Theme`**) on the
same Selection sheet, carried the same way (`question_orchestrator.R` →
`data_layer_writer.R` → a `q.theme` field → a `byTheme` group-by in JS, mirroring
`d2.categories()` / the dashboard's `byCat`). Composites (Q_Engage/Q_Value) get a
section too (today they have none). No new statistics — pure grouping + the
patterns logic over numbers the report already computes.

## SACS worked example

### Tagging (about a 20-minute job — the 12 engagement items are the Gallup Q12)

| Section | Theme | Questions (index /5) |
|---|---|---|
| Satisfaction | — (headline) | Q28 overall satisfaction **3.90** |
| Engagement | Clarity & resources | Q05 know what's expected **4.51**, Q06 materials & equipment |
| Engagement | Recognition & voice | Q08 recognition **3.44**, Q11 opinions count **3.72**, Q15 progress conversations **3.75** |
| Engagement | Belonging & care | Q09 manager cares, Q10 encourages development, Q12 mission matters, Q13 co-workers committed **4.20**, Q14 someone to relate to |
| Engagement | Doing my best & growing | Q07 do what I'm best at, Q16 learn & grow **3.95** |
| Values | Values demonstrated | Q18 integrity, Q19 excellence (77%), Q20 team-ness (**63%**), Q21 results-oriented (79%), Q22 person-centred, Q23 purposeful (75%) |
| Values | Values alignment | Q25 alignment **4.18** (78%) |

(Composite indices Q_Engage 4.08 and Q_Value sit under Engagement / Values as the
section scores.)

### What the Patterns view then says (deterministic, no AI)

Headlines (apex): **Satisfaction 3.90 · 69% satisfied (▲)** · **Engagement 4.08
(▼, third year down)** · **Values 78% aligned (4.18)**.

1. **The group under strain — Cape Town.** Least satisfied campus (3.38), lowest
   engagement (3.75), least values-aligned. Behind the rest right across the
   survey. *(Also: new staff the most positive; Marketing's satisfaction fell
   sharply.)*
2. **Weakest area — Recognition & voice (≈3.6).** Recognition (3.44), opinions
   counting (3.72) and progress conversations (3.75) all sit low — and all three
   are falling year on year.
3. **Strongest area — Clarity & purpose.** Knowing what's expected (4.51) is the
   single highest item; belief in the mission and committed colleagues hold the
   place together.
4. **What moved — engagement's slow slide.** Down a third straight year
   (4.31 → 4.16 → 4.08), led by the recognition theme; satisfaction edged up
   (3.83 → 3.90).
5. **Values — aligned, with one soft value.** 78% aligned overall, but team-ness
   is the least-observed value (63%), and Cape Town is least aligned.

None of these is on the Dashboard or Differences as a single statement — each one
groups across questions (a theme) or across the whole survey (a segment). Drill
into the Dashboard for the individual scores.

### How each pattern is computed

- **Standout group (1):** add up, for each breakout column (campus, department,
  tenure), how often it is significantly above/below the rest across all
  questions; the most consistently-off column is the story. Needs no tagging.
- **Weakest/strongest area (2,3):** average the index of the questions in each
  theme; rank themes; name the worst item driving the weakest theme.
- **What moved (4):** the theme (or headline) with the biggest significant wave
  change.
- **Values (5):** same theme logic applied to the Values section.

## Other survey types (same engine, different labels)

- **Brand tracker:** Sections = Awareness / Consideration / Preference / Loyalty.
  Patterns view → "Weakest stage: Consideration; the segment under strain: under-35s;
  what moved: Preference up after the campaign."
- **Customer satisfaction:** Sections = Product / Service / Price / Ease / Trust.
  → "Weakest area: Price-value; branch X consistently lowest; Ease improved."

Same code, same four patterns — only the labels change.

## Build implications (next step, not yet built)

The engine already gathers what's needed (multi-banner standouts, touchpoint
levels, wave deltas). The rework:
- add the optional `Theme` column + carry `q.theme` to the data layer (mirrors
  `Category` plumbing);
- replace posture routing with: aggregate standouts per banner column (the
  standout-group pattern) + roll up levels by theme (weakest/strongest/moved);
- re-shape the Read/Present views around the 3–4 patterns instead of finding cards.
Tagging stays optional with fallback to the standout-group pattern + questionnaire
order.

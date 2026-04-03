# Turas AI Insights — Prompt Tuning Guide

## Overview

Prompt quality is the single biggest determinant of whether AI insights add value or create noise. The prompts shipped with the feature are a starting point. This guide walks you through systematic improvement against real data.

---

## Where prompts live

All prompts are text constants in one file:

```
modules/tabs/lib/ai/ai_prompts.R
```

Six prompt constants:
- `AI_SYSTEM_PROMPT` — persona and guardrails (shared across all callout calls)
- `AI_CALLOUT_USER_PROMPT_TEMPLATE` — per-question analysis task
- `AI_VERIFICATION_PROMPT_TEMPLATE` — factual accuracy check
- `AI_SELECTIVITY_PROMPT_TEMPLATE` — editorial quality filter
- `AI_EXEC_PATTERNS_PROMPT_TEMPLATE` — exec summary Stage 1 (patterns)
- `AI_EXEC_NARRATIVE_PROMPT_TEMPLATE` — exec summary Stage 2 (narrative)

The `build_insight_prompt()` function assembles system + user prompts with data interpolated. You edit the constants, not the function.

---

## Tuning process

### Setup

1. Pick 3+ real past client datasets — not just the demo data. Choose diversity:
   - One with clean significance patterns
   - One with messy/ambiguous data
   - One with small subgroups (n < 50)

2. Run the pipeline against each dataset.

3. Export every callout into a review spreadsheet:

| q_code | q_title | generated_callout | rating | notes |
|--------|---------|-------------------|--------|-------|
| Q001 | NPS | "The overall NPS of +7..." | 4 | Good but could lead with segment difference |

### Rating criteria

Score each callout 1-5:

| Score | Meaning | Action |
|-------|---------|--------|
| 5 | Would include in client report as-is | Keep — this is the target |
| 4 | Useful observation, minor wording tweak | Keep — note what you'd change |
| 3 | Technically correct but adds little | Fix — selectivity problem |
| 2 | Misses the real story | Fix — prompt framing problem |
| 1 | Factually wrong or contains recommendations | Fix — guardrail problem |

**Target:** 60%+ of callouts score 4-5. Zero score 1.

---

## What to tune and in what order

### Round 1: Fix guardrail problems (score 1)

These are the most dangerous. Fix first.

**Numbers wrong?** The LLM can only cite what it's given. Check `extract_question_data()` output — is the data payload correct? Most "hallucination" problems are actually extraction problems.

```r
# Debug: inspect what the LLM sees
source("modules/tabs/lib/ai/ai_extraction.R")
q_data <- extract_question_data(all_results[["Q001"]], banner_info)
str(q_data)
```

**Significance claims wrong?** Check `extract_sig_flags()` output. Are the boolean flags accurate?

**Contains recommendations?** ("the company should...") Tighten the system prompt:
```
# In AI_SYSTEM_PROMPT, make the boundary more explicit:
"Your role is strictly OBSERVATIONAL. You describe what the data shows.
 You NEVER recommend actions, strategies, or next steps."
```

### Round 2: Fix framing problems (score 2)

The model sees the right data but focuses on the wrong thing.

**Focuses on totals, ignores subgroup differences?** Add to the user prompt:
```
"Prioritise significant subgroup differences over topline results.
 If significance flags are present, they are the most important signal."
```

**Misses the priority metric (NPS, NET POSITIVE)?** Add:
```
"If a priority_metric is present, lead with it."
```

**Buries the interesting finding?** Add:
```
"Lead with the most notable observation in your first sentence."
```

### Round 3: Fix selectivity problems (score 3)

Callouts are accurate but don't add value beyond what the chart shows.

**Merely restates "Brand X scored highest"?** Tighten `AI_SELECTIVITY_PROMPT_TEMPLATE`:
```
"Remove any callout that merely identifies the highest or lowest scorer
 without explaining WHY it matters or what pattern it reveals."
```

**Commenting on every question?** Raise the bar in the system prompt:
```
"Only set has_insight to TRUE if the pattern would surprise a researcher
 looking at this data for the first time."
```

**Add negative examples:**
```
"Do NOT generate a callout that says 'Brand X has the highest score at 72%'
 without noting a significant difference or unexpected pattern."
```

### Round 4: Polish (score 4 → 5)

**Tone sounds like ChatGPT, not a research analyst?** Add style examples from your own past commentary to the system prompt. Show 2-3 examples of what good callouts look like.

**Too generic?** Emphasise specificity:
```
"Always cite specific numbers: '72%, significantly above the 58% average'
 not 'scored well above average'."
```

**Too long?** Reduce `max_tokens` in the sidecar JSON (default: 1500). Try 800 for more concise output.

**Too short?** Increase `max_tokens` to 2000 and add: "Write 3-4 sentences, not just one."

---

## Tuning mechanics

1. **Change one thing at a time.** Edit either the system prompt or the user prompt, not both. Re-run against the same dataset. Compare.

2. **Keep a changelog.** Version your prompts in comments at the top of `ai_prompts.R`:
```r
# PROMPT VERSION LOG
# V1 (2026-04-03) — Spec original
# V2 (2026-04-05) — Added subgroup priority, tightened selectivity
# V3 (2026-04-07) — Added negative examples, style guidance
```

3. **Test across datasets.** A prompt that works for a CX study may fail on a brand tracker. Tune for generality.

4. **The system prompt sets persona and guardrails.** It should rarely change after Round 1.

5. **The user prompt sets task framing.** This is where most tuning happens.

6. **The selectivity prompt is a separate editorial pass.** Tune it independently.

---

## Executive summary tuning

Tune separately from per-question callouts. Two stages:

**Stage 1 (patterns — `AI_EXEC_PATTERNS_PROMPT_TEMPLATE`):**
- Is it identifying the right 3-4 strongest/weakest measures?
- Is the "dominant subgroup pattern" genuinely the most important dimension?
- If not, add: "The most commercially relevant dimension is usually the one with the largest significant differences across the most questions."

**Stage 2 (narrative — `AI_EXEC_NARRATIVE_PROMPT_TEMPLATE`):**
- Does it read like an executive summary or a list with connecting words?
- Push for the Insight-Implications-Evidence structure
- Add examples of good executive summaries from your past reports (anonymised)

---

## Verification tuning

The verification pass catches hallucinated numbers. If it's suppressing too many callouts:

1. Check `verification_issues` in the sidecar JSON — what's actually failing?
2. If the issues are legitimate, the problem is in the callout prompt, not verification
3. If verification is being too strict, adjust `AI_VERIFICATION_PROMPT_TEMPLATE`
4. To skip verification temporarily: set `verify_callouts: false` in the sidecar JSON

---

## Selectivity tuning

If too many callouts are being removed:
- Lower the bar: "Only remove callouts that are completely generic"
- Check `selectivity_removed: true` in the sidecar to see what was cut

If too few are being removed:
- Raise the bar: "A good callout highlights a non-obvious pattern"
- Add: "If more than 60% of questions have callouts, you are not being selective enough"

---

## Temperature

Default is 0.3 in the sidecar JSON. This is the right setting for factual observation.

- **Lower (0.1-0.2):** More repetitive, deterministic output. Good for verification.
- **Higher (0.4-0.5):** More varied phrasing but risks creative interpretation.
- **Above 0.5:** Don't. You want observation, not creativity.

Fix the prompt before adjusting temperature.

---

## Banned words

The system prompt already bans: "delve", "dive into", "unpack", "landscape", "nuanced", "robust" (unless statistical), "leverage", "holistic", "key takeaway", "it is worth noting".

Add more as you spot them in generated output. The banned words list is in `AI_SYSTEM_PROMPT` in `ai_prompts.R`.

---

## When to stop tuning

You're done when:
- 60%+ of callouts across all test datasets score 4-5
- Zero score 1 (factual errors, recommendations)
- Selectivity pass catches score-3 callouts reliably
- Executive summary is "usable with minor edits" on 4/5 runs
- Jess reviews a full report and says the callouts save time

---

## Common pitfalls

1. **Over-tuning to one dataset.** "Always mention NPS" works for CX but breaks brand trackers.

2. **Prompt bloat.** Every instruction dilutes every other instruction. If the system prompt exceeds ~500 words, start removing less important guidance.

3. **Ignoring the extraction layer.** Most "prompt problems" are data problems. If the model can't see significance flags, it can't cite them. Check `extract_question_data()` output first.

4. **Tuning temperature instead of prompts.** Fix the prompt, not the temperature.

5. **Not testing re-runs.** After tuning, delete question entries from the sidecar JSON and re-run to verify the new prompts produce better output. Cached callouts won't reflect prompt changes.

---

## Quick reference: files to edit

| What to change | File | What to look for |
|----------------|------|------------------|
| Callout persona/guardrails | `ai_prompts.R` | `AI_SYSTEM_PROMPT` |
| What the model focuses on | `ai_prompts.R` | `AI_CALLOUT_USER_PROMPT_TEMPLATE` |
| Verification strictness | `ai_prompts.R` | `AI_VERIFICATION_PROMPT_TEMPLATE` |
| Which callouts get cut | `ai_prompts.R` | `AI_SELECTIVITY_PROMPT_TEMPLATE` |
| Exec summary patterns | `ai_prompts.R` | `AI_EXEC_PATTERNS_PROMPT_TEMPLATE` |
| Exec summary narrative | `ai_prompts.R` | `AI_EXEC_NARRATIVE_PROMPT_TEMPLATE` |
| Temperature / max_tokens | Sidecar JSON | `config.temperature`, `config.max_tokens` |
| Data the model sees | `ai_extraction.R` | `extract_question_data()` |
| Sig flag translation | `ai_extraction.R` | `extract_sig_flags()` |

---

## Forcing regeneration after prompt changes

Prompt changes don't automatically regenerate cached callouts. To apply new prompts:

**Regenerate everything:**
Delete all question entries from the sidecar JSON, keeping only the `config` section:
```json
{
  "version": "1.0",
  "config": { ... },
  "questions": {},
  "executive_summary": null
}
```

**Regenerate one question:**
Delete that question's entry from the `questions` object in the sidecar JSON.

**Regenerate executive summary only:**
Set `"executive_summary": null` in the sidecar JSON.

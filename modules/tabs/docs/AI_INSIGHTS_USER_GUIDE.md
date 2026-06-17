# Turas AI Insights — User Guide (Tabs Module)

## What it does

AI Insights adds optional AI-generated observational callouts to your HTML crosstab reports. The AI spots patterns, flags notable differences, and surfaces things worth attention. Your role remains strategic interpretation — "here's what it means for the business."

Two complementary voices, honestly labelled:

| Content | Source | Labelled as AI? | Visual style |
|---------|--------|-----------------|--------------|
| **AI callout** | LLM-generated | Yes — always | Grey background, sparkle icon |
| **Researcher commentary** | Comments sheet (you write it) | No — never | Brand-colour border |
| **Executive summary (reviewed)** | AI-drafted, researcher-edited | No (model named in methodology note) | Standard styling |
| **Executive summary (unreviewed)** | AI-generated, no review | Yes | Grey background |

## Choosing the model (easiest path)

You do **not** need to touch any JSON to pick the model. In the Settings sheet of
your crosstab config:

| Setting | Value |
|---------|-------|
| `enable_ai_insights` | `TRUE` |
| `ai_model` | `Sonnet 4.6` (default) or `Opus 4.8` |

- **Sonnet 4.6** — faster and lower cost; the sensible default.
- **Opus 4.8** — highest quality analytical reasoning; use for flagship reports.
- **Any exact model ID** (e.g. `claude-sonnet-4-6`) — typed verbatim, so you can
  adopt a newer Anthropic model the moment it ships, without a code update.
- **Blank** — hands control to the JSON sidecar (see *Provider switching* below);
  needed only for non-Anthropic providers.

`ai_model` is authoritative: switch it and re-run, and the callouts regenerate so
they are written by the model you chose. The model used is named in the
methodology note in the About tab, so clients see exactly which model produced the
commentary.

## Quick start

### 1. Create the AI sidecar file (optional)

The sidecar is **auto-created** the first time you run with `enable_ai_insights = TRUE`,
seeded with the model from your `ai_model` setting. You only need to create it by
hand to change advanced options or switch providers. If your config is
`Demo_CX_Crosstabs.xlsx`, the sidecar is `Demo_CX_Crosstabs_ai_insights.json`:

```json
{
  "version": "1.0",
  "config": {
    "enabled": true,
    "provider": "anthropic",
    "model": "claude-sonnet-4-6",
    "temperature": 0.3,
    "max_tokens": 1500,
    "verify_callouts": true,
    "rank_callouts": true,
    "generate_exec_summary": true,
    "generate_per_question": true,
    "exec_summary_reviewed": true,
    "easystats_narration": false,
    "max_verification_attempts": 2,
    "api_key_env": "ANTHROPIC_API_KEY"
  },
  "questions": {},
  "executive_summary": null
}
```

### 2. Set your API key

```r
Sys.setenv(ANTHROPIC_API_KEY = "your-api-key-here")
```

Or add it to your `.Renviron` file for persistence.

### 3. Run your report as normal

AI insights generate automatically during HTML report generation when the sidecar file exists and `enabled` is true.

## Configuration reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Master switch — set false to disable |
| `provider` | string | `"anthropic"` | `"anthropic"`, `"openai"`, `"google"`, or `"ollama"` |
| `model` | string | varies | Model identifier for the provider |
| `temperature` | number | `0.3` | LLM temperature (0.0–1.0) |
| `max_tokens` | integer | `1500` | Max tokens per callout API call |
| `exec_summary_max_tokens` | integer | `2500` | Max tokens for executive summary |
| `verify_callouts` | boolean | `true` | Run factual accuracy verification |
| `rank_callouts` | boolean | `true` | Run selectivity pass (remove low-value callouts) |
| `generate_exec_summary` | boolean | `true` | Generate executive summary |
| `generate_per_question` | boolean | `true` | Generate per-question callouts |
| `exec_summary_reviewed` | boolean | `true` | `true` = standard styling; `false` = AI-labelled |
| `easystats_narration` | boolean | `false` | Add APA statistical narration (no LLM needed) |
| `max_verification_attempts` | integer | `2` | Regeneration attempts on verification failure |
| `api_key_env` | string | `"ANTHROPIC_API_KEY"` | Environment variable name for API key |

### Provider switching

For Anthropic models, just set `ai_model` in the config (`Sonnet 4.6` / `Opus 4.8`).
To switch **provider**, leave `ai_model` blank and edit the sidecar:

```json
// Claude (default — or just set ai_model in the config)
"provider": "anthropic",
"model": "claude-sonnet-4-6",
"api_key_env": "ANTHROPIC_API_KEY"

// OpenAI
"provider": "openai",
"model": "gpt-4.1",
"api_key_env": "OPENAI_API_KEY"

// Local Ollama (no API key needed)
"provider": "ollama",
"model": "gemma4:31b"
```

## How caching works

Each AI callout stores a hash of the data that produced it. On re-run:

- **Data unchanged** → cached callout preserved, no API call (instant, free)
- **Data changed** → new callout generated automatically
- **Manually edited narrative** → edit preserved (hash still matches)
- **Manually suppressed** (has_insight set false) → suppression preserved
- **Pin state** → preserved across re-runs

To force regeneration of a specific question, delete its entry from the sidecar JSON.

## Editing and review workflow

1. Run the report → AI callouts appear in the HTML
2. Review each callout in the report
3. **Pin** callouts you want in the print/slide export
4. **Toggle** all callouts off if you want a clean view
5. Edit callout text directly in the sidecar JSON if needed
6. Add strategic commentary via the Comments sheet (standard workflow)
7. Re-run → edits, pins, and suppressions preserved

## Print/export behaviour

- **Unpinned callouts** → hidden in print/PDF
- **Pinned callouts** → visible in print/PDF
- **Researcher commentary** → always visible
- **Toggle** → hidden in print

## Graceful degradation

The report generates successfully with zero AI-related errors when:
- The API key is missing or invalid
- The API is unavailable
- The model returns malformed output
- The sidecar file doesn't exist

AI insights are purely additive. A report with AI disabled is identical to a report without the feature.

## File layout

```
modules/shared/lib/ai/       — Shared AI infrastructure
  ai_provider.R               — Provider abstraction
  ai_schemas.R                — Verification/selectivity schemas
  ai_utils.R                  — Sidecar persistence, caching
  ai_verify.R                 — Verification and selectivity passes

modules/tabs/lib/ai/          — Tabs-specific AI code
  ai_insights.R               — Main orchestrator
  ai_prompts.R                — Prompt templates
  ai_extraction.R             — Data extraction
  ai_schemas_tabs.R           — Callout/exec summary schemas
  ai_rendering.R              — HTML rendering
  ai_easystats.R              — APA statistical narration
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No AI callouts appear | Check sidecar exists and `enabled` is true |
| API key error | Set `ANTHROPIC_API_KEY` in environment |
| All callouts suppressed | Check verification isn't failing — set `verify_callouts: false` temporarily |
| Callouts are generic | Refine prompts in `ai_prompts.R` — see prompt tuning guide |
| Report is slow | ~30 API calls for 27 questions takes 2-4 minutes — this is expected |
| Changes not reflected | Delete the question's entry in the sidecar to force regeneration |

# TURAS Mapping & Refusal Standard (TRS v1.0)

## Purpose
This document defines the mandatory mapping, refusal, and reliability standards that apply to **ALL Turas modules**.
Its objective is to guarantee that Turas:
- never produces silent wrong output
- never degrades without disclosure
- never traps the user in an unfixable refusal state

## Scope
This standard applies to every Turas module, including but not limited to:
- Tabs
- Tracker
- Continuous Key Driver
- Categorical Key Driver
- Conjoint
- Pricing
- MaxDiff
- Segmentation
- Confidence

## Core Execution States
Every module execution **MUST** terminate in exactly one of the following states:
- PASS – All outputs valid and complete
- PARTIAL – Outputs produced with declared degradation
- REFUSE – User-fixable issue; no outputs produced
- ERROR – Internal Turas bug

Any other behaviour is forbidden.

## Refusal vs Error
Refusals represent user-fixable problems (configuration, data, mapping).
Errors represent internal Turas bugs.

Refusals must guide the user to a fix.
Errors must clearly state that Turas failed.

## Refusal Code Taxonomy
All refusal codes must use one of the following prefixes:
- CFG_ – configuration errors
- DATA_ – data integrity errors
- IO_ – file or path errors
- MODEL_ – model fitting errors
- MAPPER_ – mapping / coverage errors
- PKG_ – missing dependency errors
- FEATURE_ – optional feature failures
- BUG_ – internal logic failures

Codes must be unique, stable, and centrally registered.

## Mandatory Refusal Block Structure
Every refusal **MUST** present the following sections:

```
[REFUSE] <CODE>: <TITLE>

Problem:
<one-sentence description>

Why it matters:
<one-sentence explanation of analytical risk>

How to fix:
<explicit step-by-step actions>

Diagnostics:
Expected:
Observed:
Missing:
Unmapped:
```

If concrete diagnostics cannot be shown, the refusal is non-compliant.

## Mapping & Coverage Gates
Any module that translates configuration into model terms or outputs **MUST**:
1. Define expected entities from config
2. Extract observed entities from data/model
3. Compare expected vs observed
4. REFUSE on any mismatch

Warnings are never sufficient for mapping failures.

## Degraded Output Policy
If execution continues after a failure, this must be explicitly controlled by configuration.

Degraded outputs must:
- set run_status = PARTIAL
- list degraded reasons
- list affected outputs
- display a prominent console banner

Silent degradation is forbidden.

## Console UX Requirements
Every module run must display:
- start banner (module, version)
- input validation summary
- data exclusion summary
- mapping validation result
- output summary
- final status banner

## Minimum Testing Standard
Each module must include:
- one golden-path test
- one refusal test
- one mapping failure test
- one test proving no silent partial output

## Enforcement
Any Turas module that does not comply with this standard must not be released.

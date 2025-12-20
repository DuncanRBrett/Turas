# Categorical Key Driver – Hardening Specification
Document ID: TURAS-KD-CATEGORICAL-HARDENING-v1.1

## Purpose
Bring the existing Categorical Key Driver (CatDriver) into full, explicit compliance with TRS v1.0,
without introducing new analytical features or changing statistical logic.

## Scope
### In scope
- Alignment with TRS v1.0
- Formalisation of refusal codes
- Replacement of warning-based degradation
- Console and output consistency

### Out of scope
- Any change to model specification or estimation
- Any new predictor or outcome handling
- Any change to odds-ratio interpretation or sign conventions

## Governing Standard
This module MUST comply fully with TRS v1.0.
If any conflict exists, TRS takes precedence.

## Refusal Code Registry
All refusal codes must:
- be registered centrally
- use TRS-approved prefixes
- be unique and documented

Inline or undocumented codes are forbidden.

## Warning Elimination Policy
Any warning implying degraded correctness or incomplete output is forbidden.

Such situations must be handled by:
- REFUSE (default), or
- PARTIAL with explicit degraded status (only if config permits)

## Output Status Alignment
All outputs must include:
- run_status ∈ {PASS, PARTIAL}
- degraded (TRUE/FALSE)
- degraded_reasons (if applicable)

No output may be written if execution ends in REFUSE.

## Console Messaging Requirements
Console output must follow TRS formatting exactly:
- start banner with module name and version
- explicit [OK] banner on success
- structured refusal blocks
- prominent PARTIAL banner where applicable

## Reference Implementation Role
After hardening, CatDriver v1.1 serves as the reference TRS-compliant module.

## Definition of Done
CatDriver hardening is complete when:
- it fully complies with TRS v1.0
- no warning results in hidden degradation
- refusal behaviour is explicit and diagnostic
- outputs always declare status
- no analytical behaviour has changed

# TRS Integration & Compliance Specification – Existing Modules
Document ID: TURAS-TRS-INTEGRATION-COMPLIANCE-v1.0

## Purpose
Define the mandatory process for integrating TRS v1.0 into existing Turas modules
(Tabs, Tracker, Conjoint, Pricing, MaxDiff, Segmentation, Confidence) without altering analytical logic.

## Scope
### In scope
- TRS refusal framework integration
- Mapping and coverage gates
- Elimination of silent degradation
- Console and output status alignment

### Out of scope
- Analytical or statistical changes
- Feature additions
- Performance optimisation
- UX redesign beyond TRS console blocks

## Governing Standard
All work is governed by TRS v1.0.
If any conflict exists, TRS takes precedence.

## Mandatory Integration Steps
Each module must:
1. Wrap execution in with_refusal_handler()
2. Replace stop() with turas_refuse() for user-fixable issues
3. Eliminate warning-based degradation
4. Insert mapping/coverage gate at the correct architectural boundary
5. Add output status metadata (PASS / PARTIAL / REFUSE)
6. Align console output to TRS format

## Mapping Entity Definitions (By Module)
Each module must define its primary mapping entities:
- Tabs: question config → variables → nets → tables
- Tracker: wave keys → aligned questions → time series
- Conjoint: attributes/levels → design matrix → utilities
- Pricing: price points → responses → curves/metrics
- MaxDiff: items → design → counts → utilities
- Segmentation: variables → scaled inputs → clusters → labels
- Confidence: estimates → method → interval outputs

## Mapping Gate Placement
The mapping gate must be placed immediately after the last irreversible transformation
and before any output is written.
Mapping failure → REFUSE.

## Compliance Checklist
Each module must be audited for:
- refusal framework present
- no silent degradation
- mapping gate implemented
- output status recorded
- loop-proof diagnostics
- minimum tests updated

Modules are classified as PASS / PARTIAL / FAIL.

## Documentation Requirements
For each updated module:
- technical maintenance documentation
- user-facing documentation explaining refusals and PARTIAL outputs

## Definition of Done
A module is TRS-compliant when:
- all mandatory steps are implemented
- the checklist passes
- no analytical behaviour has changed
- documentation is complete

## Enforcement
Non-compliant modules must not be released or used for client work.

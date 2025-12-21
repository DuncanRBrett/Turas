#!/usr/bin/env bash
# ==============================================================================
# TRS GATE - CI/CD Compliance Check Script (TRS v1.0)
# ==============================================================================
#
# This script checks the Turas codebase for TRS v1.0 compliance.
# Use in CI/CD pipelines to enforce TRS coding standards.
#
# USAGE:
#   ./scripts/trs_gate.sh [--strict] [--fix-suggestions]
#
# OPTIONS:
#   --strict          Fail on any violation (default: warn-only for INFO level)
#   --fix-suggestions Show suggested fixes for violations
#
# EXIT CODES:
#   0 - All checks pass
#   1 - Critical violations found (warning() + return(NULL) patterns)
#   2 - Non-TRS compliant patterns found
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0
INFO=0

# Options
STRICT_MODE=false
SHOW_FIXES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --strict)
      STRICT_MODE=true
      shift
      ;;
    --fix-suggestions)
      SHOW_FIXES=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "============================================================"
echo "TRS Gate - Turas Run State Compliance Check"
echo "============================================================"
echo ""

# Determine project root
if [[ -d "modules" ]]; then
  PROJECT_ROOT="."
elif [[ -d "../modules" ]]; then
  PROJECT_ROOT=".."
else
  echo -e "${RED}ERROR: Cannot find Turas project root${NC}"
  exit 1
fi

cd "$PROJECT_ROOT"

# ==============================================================================
# CHECK 1: warning() + return(NULL) patterns (CRITICAL)
# ==============================================================================
echo -e "${BLUE}[1/4] Checking for warning() + return(NULL) patterns...${NC}"

# Search for warning() calls not already converted to TRS format
# Exclude archive, tests, and the fallback warning in guard files
WARN_RETURN_PATTERNS=$(grep -rn "warning(" modules --include="*.R" 2>/dev/null | \
  grep -v "archive/" | \
  grep -v "/tests/" | \
  grep -v "TRS infrastructure not found" | \
  grep -v "\[TRS" | \
  grep -v "create_warning" || true)

if [[ -n "$WARN_RETURN_PATTERNS" ]]; then
  echo -e "${YELLOW}WARNING: Found warning() calls that may need TRS conversion:${NC}"
  echo "$WARN_RETURN_PATTERNS" | head -20
  WARN_COUNT=$(echo "$WARN_RETURN_PATTERNS" | wc -l)
  if [[ $WARN_COUNT -gt 20 ]]; then
    echo "  ... and $((WARN_COUNT - 20)) more"
  fi
  WARNINGS=$((WARNINGS + WARN_COUNT))

  if [[ "$SHOW_FIXES" == true ]]; then
    echo ""
    echo -e "${BLUE}Suggested fix:${NC}"
    echo "  Replace: warning(\"message\", call. = FALSE)"
    echo "  With:    message(\"[TRS INFO] MODULE_CODE: message\")"
    echo ""
  fi
fi

# ==============================================================================
# CHECK 2: TRS infrastructure files exist
# ==============================================================================
echo -e "${BLUE}[2/4] Checking TRS infrastructure files...${NC}"

TRS_FILES=(
  "modules/shared/lib/trs_refusal.R"
  "modules/shared/lib/trs_run_state.R"
  "modules/shared/lib/trs_run_status_writer.R"
  "modules/shared/lib/trs_banner.R"
)

for file in "${TRS_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo -e "${RED}ERROR: Missing TRS infrastructure file: $file${NC}"
    ERRORS=$((ERRORS + 1))
  else
    echo -e "  ${GREEN}OK${NC} $file"
  fi
done

# ==============================================================================
# CHECK 3: Modules have guard files
# ==============================================================================
echo -e "${BLUE}[3/4] Checking module guard files...${NC}"

MODULES=(
  "modules/confidence/R/00_guard.R"
  "modules/conjoint/R/00_guard.R"
  "modules/maxdiff/R/00_guard.R"
  "modules/pricing/R/00_guard.R"
  "modules/segment/lib/00_guard.R"
  "modules/catdriver/R/00_guard.R"
  "modules/keydriver/R/00_guard.R"
  "modules/tabs/lib/00_guard.R"
  "modules/tracker/00_guard.R"
)

for guard_file in "${MODULES[@]}"; do
  if [[ ! -f "$guard_file" ]]; then
    echo -e "  ${YELLOW}WARN${NC} Missing guard file: $guard_file"
    WARNINGS=$((WARNINGS + 1))
  else
    echo -e "  ${GREEN}OK${NC} $guard_file"
  fi
done

# ==============================================================================
# CHECK 4: TRS message format compliance
# ==============================================================================
echo -e "${BLUE}[4/4] Checking TRS message format compliance...${NC}"

# Look for properly formatted TRS messages
TRS_MESSAGES=$(grep -rn "\[TRS" modules --include="*.R" 2>/dev/null | wc -l || echo "0")
echo -e "  Found ${GREEN}$TRS_MESSAGES${NC} TRS-formatted messages"

# Check for proper format: [TRS LEVEL] MODULE_CODE:
MALFORMED=$(grep -rn "\[TRS" modules --include="*.R" 2>/dev/null | \
  grep -v "\[TRS INFO\]" | \
  grep -v "\[TRS PARTIAL\]" | \
  grep -v "\[TRS REFUSE\]" | \
  grep -v "\[TRS PASS\]" || true)

if [[ -n "$MALFORMED" ]]; then
  echo -e "${YELLOW}WARNING: Found malformed TRS messages:${NC}"
  echo "$MALFORMED" | head -10
  WARNINGS=$((WARNINGS + $(echo "$MALFORMED" | wc -l)))
fi

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
echo "============================================================"
echo "TRS Gate Summary"
echo "============================================================"
echo -e "  Errors:   ${RED}$ERRORS${NC}"
echo -e "  Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "  Info:     ${BLUE}$INFO${NC}"
echo ""

if [[ $ERRORS -gt 0 ]]; then
  echo -e "${RED}GATE FAILED: Critical violations found${NC}"
  exit 1
elif [[ $WARNINGS -gt 0 && "$STRICT_MODE" == true ]]; then
  echo -e "${YELLOW}GATE FAILED: Warnings found in strict mode${NC}"
  exit 2
elif [[ $WARNINGS -gt 0 ]]; then
  echo -e "${YELLOW}GATE PASSED WITH WARNINGS${NC}"
  echo "  Run with --strict to fail on warnings"
  exit 0
else
  echo -e "${GREEN}GATE PASSED: All checks OK${NC}"
  exit 0
fi

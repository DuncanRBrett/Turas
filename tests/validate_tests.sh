#!/bin/bash
# ==============================================================================
# Test Structure Validator
# ==============================================================================
# Validates that test files are properly structured.
# Run this before committing test changes.
# ==============================================================================

echo "================================================================================"
echo "TURAS Test Structure Validator"
echo "================================================================================"
echo ""

TESTS_DIR="tests/testthat"
ERRORS=0

# Check that test directory exists
if [ ! -d "$TESTS_DIR" ]; then
  echo "❌ ERROR: $TESTS_DIR directory not found"
  exit 1
fi

echo "✓ Test directory exists: $TESTS_DIR"
echo ""

# Check for test files
TEST_FILES=$(find "$TESTS_DIR" -name "test_*.R" | wc -l)
echo "Found $TEST_FILES test file(s)"
echo ""

# List test files
echo "Test files:"
find "$TESTS_DIR" -name "test_*.R" | while read file; do
  echo "  - $(basename $file)"
done
echo ""

# Check each test file structure
echo "Validating test file structure..."
for test_file in "$TESTS_DIR"/test_*.R; do
  if [ -f "$test_file" ]; then
    filename=$(basename "$test_file")

    # Check for test_that() calls
    if ! grep -q "test_that(" "$test_file"; then
      echo "  ⚠️  WARNING: $filename - No test_that() calls found"
    else
      test_count=$(grep -c "test_that(" "$test_file")
      echo "  ✓ $filename - $test_count test(s)"
    fi

    # Check for syntax issues (basic check)
    if grep -q "test_that(\"" "$test_file"; then
      :  # Good - has properly quoted test names
    else
      echo "  ⚠️  WARNING: $filename - Check test_that() string quotes"
    fi
  fi
done

echo ""
echo "================================================================================"
if [ $ERRORS -eq 0 ]; then
  echo "✓ Validation complete - No critical errors"
  echo "================================================================================"
  exit 0
else
  echo "❌ Validation failed - $ERRORS error(s) found"
  echo "================================================================================"
  exit 1
fi

#!/bin/bash
# Extract and compare process_question functions

echo "Extracting process_question from run_crosstabs.R..."
sed -n '1360,1490p' modules/tabs/lib/run_crosstabs.R > /tmp/process_question_OLD.R

echo "Extracting process_standard_question from standard_processor.R..."
sed -n '58,214p' modules/tabs/lib/standard_processor.R > /tmp/process_standard_question_NEW.R

echo ""
echo "============================================================"
echo "FUNCTION COMPARISON"
echo "============================================================"
echo ""
echo "Lines in OLD (process_question): $(wc -l < /tmp/process_question_OLD.R)"
echo "Lines in NEW (process_standard_question): $(wc -l < /tmp/process_standard_question_NEW.R)"
echo ""
echo "Running diff..."
echo ""

diff -u /tmp/process_question_OLD.R /tmp/process_standard_question_NEW.R > /tmp/function_diff.txt

if [ $? -eq 0 ]; then
    echo "✓ Functions are IDENTICAL"
else
    echo "❌ Functions DIFFER - see /tmp/function_diff.txt"
    echo ""
    echo "First 100 lines of diff:"
    head -100 /tmp/function_diff.txt
fi

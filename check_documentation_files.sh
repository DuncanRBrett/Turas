#!/bin/bash
# Check which documentation files exist locally

echo "Checking for Segmentation Module Documentation Files..."
echo ""

echo "Documentation in modules/segment/:"
echo "----------------------------------------"

check_file() {
    if [ -f "$1" ]; then
        echo "✓ $(basename $1)"
    else
        echo "✗ $(basename $1) - MISSING"
    fi
}

check_file "modules/segment/QUICK_START.md"
check_file "modules/segment/USER_MANUAL.md"
check_file "modules/segment/MAINTENANCE_MANUAL.md"
check_file "modules/segment/EXAMPLE_WORKFLOWS.md"
check_file "modules/segment/TESTING_CHECKLIST.md"
check_file "modules/segment/README.md"

echo ""
echo "Testing Script:"
echo "----------------------------------------"
check_file "test_segmentation_real_data.R"

echo ""
echo "Library Files:"
echo "----------------------------------------"
check_file "modules/segment/lib/segment_scoring.R"
check_file "modules/segment/lib/segment_visualization.R"
check_file "modules/segment/lib/segment_validation.R"
check_file "modules/segment/lib/segment_profiling_enhanced.R"
check_file "modules/segment/lib/segment_utils.R"

echo ""
if [ -f "modules/segment/QUICK_START.md" ] && [ -f "modules/segment/USER_MANUAL.md" ]; then
    echo "✅ All documentation files present - ready to test!"
else
    echo "❌ Some files are missing. Run:"
    echo "   git fetch --all"
    echo "   git reset --hard origin/claude/create-segmentation-module-011CV6E18qExUgq7yjuNLe7s"
fi

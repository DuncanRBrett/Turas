@echo off
REM Check which documentation files exist locally
echo Checking for Segmentation Module Documentation Files...
echo.

echo Documentation in modules\segment\:
echo ----------------------------------------
if exist "modules\segment\QUICK_START.md" (
    echo [OK] QUICK_START.md
) else (
    echo [MISSING] QUICK_START.md
)

if exist "modules\segment\USER_MANUAL.md" (
    echo [OK] USER_MANUAL.md
) else (
    echo [MISSING] USER_MANUAL.md
)

if exist "modules\segment\MAINTENANCE_MANUAL.md" (
    echo [OK] MAINTENANCE_MANUAL.md
) else (
    echo [MISSING] MAINTENANCE_MANUAL.md
)

if exist "modules\segment\EXAMPLE_WORKFLOWS.md" (
    echo [OK] EXAMPLE_WORKFLOWS.md
) else (
    echo [MISSING] EXAMPLE_WORKFLOWS.md
)

if exist "modules\segment\TESTING_CHECKLIST.md" (
    echo [OK] TESTING_CHECKLIST.md
) else (
    echo [MISSING] TESTING_CHECKLIST.md
)

if exist "modules\segment\README.md" (
    echo [OK] README.md
) else (
    echo [MISSING] README.md
)

echo.
echo Testing Script:
echo ----------------------------------------
if exist "test_segmentation_real_data.R" (
    echo [OK] test_segmentation_real_data.R
) else (
    echo [MISSING] test_segmentation_real_data.R
)

echo.
echo If any files are missing, run: git reset --hard origin/claude/create-segmentation-module-011CV6E18qExUgq7yjuNLe7s
pause

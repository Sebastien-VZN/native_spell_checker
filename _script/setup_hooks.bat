@echo off
setlocal

:: --- Configure git to use the versioned githooks/ directory ---
:: Run this once after cloning the repo.

echo.
echo === Setting up git hooks for native_spell_checker ===
echo.

git config core.hooksPath githooks

if %errorlevel% equ 0 (
    echo [OK] core.hooksPath set to 'githooks'
    echo      Pre-commit hook: dart format -l 120 on staged .dart files
) else (
    echo [FAIL] Could not set core.hooksPath
)

echo.
echo Done. Hooks are now active.
endlocal
pause
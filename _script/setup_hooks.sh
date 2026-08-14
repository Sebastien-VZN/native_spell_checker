#!/usr/bin/env bash
# Configure git to use the versioned githooks/ directory.
# Run this once after cloning the repo.

set -e

echo ""
echo "=== Setting up git hooks for native_spell_checker ==="
echo ""

git config core.hooksPath githooks

echo "[OK] core.hooksPath set to 'githooks'"
echo "     Pre-commit hook: dart format -l 120 on staged .dart files"
echo ""
echo "Done. Hooks are now active."
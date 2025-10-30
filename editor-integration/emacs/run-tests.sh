#!/bin/bash

# Test runner for dune.el
# This script runs the ERT test suite for dune-mode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMACS="${EMACS:-emacs}"

echo "Running dune-mode tests with ${EMACS}..."
echo "========================================"

# Run tests in batch mode
"${EMACS}" -Q --batch \
    -L "${SCRIPT_DIR}" \
    -l "${SCRIPT_DIR}/dune.el" \
    -l "${SCRIPT_DIR}/dune-tests.el" \
    -f ert-run-tests-batch-and-exit

echo ""
echo "All tests passed!"

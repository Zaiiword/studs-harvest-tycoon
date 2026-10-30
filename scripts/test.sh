#!/usr/bin/env sh
# Équivalent Linux/macOS/CI de test.ps1
set -e
stylua --check src tests
selene src tests
lune run tests/run

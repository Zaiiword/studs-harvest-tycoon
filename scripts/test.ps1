# Qualité + tests : format, lint, tests unitaires/intégration/non-régression.
$ErrorActionPreference = "Stop"
stylua --check src tests;   if ($LASTEXITCODE) { exit 1 }
selene src tests;           if ($LASTEXITCODE) { exit 1 }
lune run tests/run;         exit $LASTEXITCODE

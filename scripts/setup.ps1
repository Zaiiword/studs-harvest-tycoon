# Installation complète de l'environnement (Windows / PowerShell).
# Usage : powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
$ErrorActionPreference = "Stop"

if (-not (Get-Command rokit -ErrorAction SilentlyContinue)) {
    Write-Host "Installation de Rokit..." -ForegroundColor Cyan
    Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
    $env:Path = "$env:USERPROFILE\.rokit\bin;$env:Path"
}

$tools = Select-String -Path rokit.toml -Pattern '"([^"]+@[^"]+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value -replace '@[^@]*$', '' }
rokit trust @tools
rokit install
wally install
rojo sourcemap default.project.json -o sourcemap.json
if (Test-Path Packages) { wally-package-types --sourcemap sourcemap.json Packages/ }
Write-Host "Environnement prêt. Lancez : .\scripts\dev.ps1" -ForegroundColor Green

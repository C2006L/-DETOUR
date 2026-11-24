param(
    [string]$GodotExe = "D:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot),
    [switch]$SkipSmoke
)

# DETOUR V0.3.2 unified test entry (ASCII-only for Windows PowerShell 5.1 compatibility).
# Usage: powershell -ExecutionPolicy Bypass -File tests/run_tests.ps1

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $GodotExe)) {
    Write-Error "Godot executable not found: $GodotExe (use -GodotExe)"
    exit 2
}
if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir "project.godot"))) {
    Write-Error "Wrong project directory: $ProjectDir"
    exit 2
}

$log = Join-Path $PSScriptRoot "last_run.log"
"DETOUR V0.3.2 TEST RUN  $(Get-Date -Format o)" | Set-Content -LiteralPath $log -Encoding UTF8

function Invoke-Suite([string]$scriptRes, [string]$title) {
    Write-Host ""
    Write-Host ">>> $title" -ForegroundColor Cyan
    "--- $title ---" | Add-Content -LiteralPath $log -Encoding UTF8
    & $GodotExe --headless --fixed-fps 60 --path $ProjectDir --script $scriptRes 2>&1 |
        Tee-Object -FilePath $log -Append
    if ($LASTEXITCODE -ne 0) {
        Write-Error "$title FAILED (exit=$LASTEXITCODE), see $log"
        exit $LASTEXITCODE
    }
    Write-Host "<<< $title PASS" -ForegroundColor Green
}

Invoke-Suite "res://tests/test_runner.gd" "Core and boundary assertions"
if (-not $SkipSmoke) {
    Invoke-Suite "res://tests/smoke_playthrough.gd" "Full playthrough smoke"
}

Write-Host ""
Write-Host "All suites passed. Log: $log" -ForegroundColor Green

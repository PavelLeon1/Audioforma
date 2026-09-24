param(
    [switch]$Headless,
    [int]$QuitAfter = 0,
    [string]$Script = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$editor = Join-Path $projectRoot '.local\godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) {
    throw 'Локальный Godot не найден. Выполните tools/setup_local.ps1.'
}

$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$profileRoot = Join-Path $projectRoot '.local\profile'
$roaming = Join-Path $profileRoot 'Roaming'
$local = Join-Path $profileRoot 'Local'
$logs = Join-Path $projectRoot '.local\logs'
New-Item -ItemType Directory -Force -Path $roaming, $local, $logs | Out-Null

try {
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = $local
    $arguments = @('--path', $projectRoot, '--log-file', (Join-Path $logs 'godot.log'))
    if ($Headless) { $arguments += '--headless' }
    if ($QuitAfter -gt 0) { $arguments += @('--quit-after', "$QuitAfter") }
    if ($Script) { $arguments += @('--script', $Script) }
    & $editor @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Godot завершился с кодом $LASTEXITCODE"
    }
}
finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}

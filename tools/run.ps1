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
$importLog = Join-Path $logs 'import.log'
$runLog = Join-Path $logs 'godot.log'

try {
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = $local
    & $editor --headless --path $projectRoot --import --log-file $importLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR:|Parse Error:' -Quiet)) {
        throw 'Не удалось импортировать ресурсы проекта Godot.'
    }

    $arguments = @('--path', $projectRoot, '--log-file', $runLog)
    if ($Headless) { $arguments += '--headless' }
    if ($QuitAfter -gt 0) { $arguments += @('--quit-after', "$QuitAfter") }
    if ($Script) { $arguments += @('--script', $Script) }
    & $editor @arguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $runLog -Pattern 'SCRIPT ERROR:|Parse Error:' -Quiet)) {
        throw "Godot завершился с ошибкой; журнал: $runLog"
    }
}
finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}

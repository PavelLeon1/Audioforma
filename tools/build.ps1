$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$editor = Join-Path $projectRoot '.local\godot\Godot_v4.7.2-stable_win64_console.exe'
$template = Join-Path $projectRoot '.local\godot\editor_data\export_templates\4.7.2.stable\windows_release_x86_64.exe'
$outputDirectory = Join-Path $projectRoot 'dist'
$output = Join-Path $outputDirectory 'Audioforma.exe'

if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) {
    throw 'Локальный редактор не найден. Выполните tools/setup_local.ps1.'
}
if (-not (Test-Path -LiteralPath $template -PathType Leaf)) {
    throw 'Шаблон экспорта не найден. Выполните python tools/setup_export_template.py.'
}

$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$profileRoot = Join-Path $projectRoot '.local\profile'
$roaming = Join-Path $profileRoot 'Roaming'
$local = Join-Path $profileRoot 'Local'
$logs = Join-Path $projectRoot '.local\logs'
New-Item -ItemType Directory -Force -Path $roaming, $local, $logs, $outputDirectory | Out-Null
$importLog = Join-Path $logs 'build_import.log'
$exportLog = Join-Path $logs 'build_export.log'

try {
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = $local
    & $editor --headless --path $projectRoot --import --log-file $importLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR:|Parse Error:' -Quiet)) {
        throw "Не удалось импортировать ресурсы; журнал: $importLog"
    }

    & $editor --headless --path $projectRoot --export-release 'Windows Desktop' $output --log-file $exportLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $exportLog -Pattern 'SCRIPT ERROR:|Parse Error:|Project export failed|Export failed' -Quiet)) {
        throw "Не удалось экспортировать проект; журнал: $exportLog"
    }
    if (-not (Select-String -LiteralPath $exportLog -Pattern 'res://scripts/spectrum_mapper.gdc' -Quiet)) {
        throw 'Анализатор спектра отсутствует в сборке.'
    }
    if (-not (Select-String -LiteralPath $exportLog -Pattern 'res://scripts/bass_beat_detector.gdc' -Quiet)) {
        throw 'Детектор басовых ударов отсутствует в сборке.'
    }
    if (-not (Select-String -LiteralPath $exportLog -Pattern 'res://shaders/halo.gdshader' -Quiet)) {
        throw 'Шейдер светящегося контура отсутствует в сборке.'
    }
    if (Select-String -LiteralPath $exportLog -Pattern 'res://tests/|res://tools/|res://[123]\.png|AGENT.md' -Quiet) {
        throw 'Сборка содержит файлы разработки.'
    }
    if (-not (Test-Path -LiteralPath $output -PathType Leaf) -or (Get-Item -LiteralPath $output).Length -lt 100000000) {
        throw 'Экспорт не создал ожидаемый Windows EXE.'
    }
    if (Test-Path -LiteralPath (Join-Path $outputDirectory 'Audioforma.pck')) {
        throw 'Ресурсы оказались в отдельном PCK вместо EXE.'
    }

    $smokeDirectory = Join-Path $projectRoot '.local\release-check'
    New-Item -ItemType Directory -Force -Path $smokeDirectory | Out-Null
    Copy-Item -LiteralPath $output -Destination (Join-Path $smokeDirectory 'Audioforma.exe') -Force
    Push-Location $smokeDirectory
    try {
        $runtimeOutput = & '.\Audioforma.exe' --headless --quit-after 90 2>&1 | Out-String
    }
    finally {
        Pop-Location
    }
    $runtimeOutput | Set-Content -LiteralPath (Join-Path $logs 'standalone_headless.txt') -Encoding UTF8
    if ($runtimeOutput -notmatch 'Godot Engine' -or $runtimeOutput -match 'SCRIPT ERROR:|Parse Error:|Failed to load script|Cannot connect to|(?m)^ERROR: (?!Failed to read the root certificate store)') {
        throw "Автономный EXE не прошёл проверку; журнал: $logs\standalone_headless.txt"
    }

    Write-Host "Сборка готова: $output"
    Write-Host 'Автономный запуск из чистой папки проверен.'
}
finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}

param(
    [string]$GodotDirectory = 'D:\Ucheba\4course\1semestr\PGiZ\tools\godot\Godot_v4.7.2-stable_win64.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$target = Join-Path $projectRoot '.local\godot'
$editorName = 'Godot_v4.7.2-stable_win64.exe'
$consoleName = 'Godot_v4.7.2-stable_win64_console.exe'

foreach ($name in @($editorName, $consoleName)) {
    $source = Join-Path $GodotDirectory $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Файл Godot не найден: $source"
    }
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -LiteralPath (Join-Path $GodotDirectory $editorName) -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $GodotDirectory $consoleName) -Destination $target -Force
New-Item -ItemType File -Force -Path (Join-Path $target '_sc_') | Out-Null

Write-Host "Локальный Godot подготовлен: $target"

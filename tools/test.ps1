$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run.ps1'

$settingsPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.local\Audioforma.ini'
$settingsExisted = Test-Path -LiteralPath $settingsPath
$settingsHash = if ($settingsExisted) { (Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash } else { '' }

& $runner -Headless -TestRun -Script 'res://tests/test_spectrum_mapper.gd'
& $runner -Headless -TestRun -Script 'res://tests/test_bass_beat_detector.gd'
& $runner -Headless -TestRun -Script 'res://tests/test_audio_analysis.gd'
& $runner -Headless -TestRun -Script 'res://tests/test_bass_playback.gd'
& $runner -Headless -TestRun -Script 'res://tests/test_visualizer.gd'

$settingsExistAfter = Test-Path -LiteralPath $settingsPath
if ($settingsExistAfter -ne $settingsExisted -or ($settingsExisted -and (Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash -ne $settingsHash)) {
    throw 'Тесты изменили пользовательский Audioforma.ini.'
}
Write-Host 'PASS: пользовательские настройки не изменены; тесты используют отдельный профиль.'

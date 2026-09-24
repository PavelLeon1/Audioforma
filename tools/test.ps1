$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run.ps1'

& $runner -Headless -Script 'res://tests/test_spectrum_mapper.gd'
& $runner -Headless -Script 'res://tests/test_audio_analysis.gd'

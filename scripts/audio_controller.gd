extends Node
class_name AudioController

signal playback_changed
signal source_changed

const SpectrumMapper = preload("res://scripts/spectrum_mapper.gd")
const DEMO_STREAM = preload("res://assets/audio/demo.wav")
const BUS_NAME := "Audio Analysis"

@onready var player: AudioStreamPlayer = $"../AudioPlayer"

var source_name := "Спектральный этюд"
var source_description := "Авторский аудиофрагмент · 24 секунды"
var last_error := ""
var _bus_index := -1
var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _spectrum := Vector3.ZERO
var _level := 0.0


func _ready() -> void:
	_prepare_audio_bus()
	player.finished.connect(_on_playback_finished)
	if player.stream == null:
		player.stream = DEMO_STREAM


func load_file(path: String) -> bool:
	last_error = ""
	var extension := path.get_extension().to_lower()
	if extension not in ["mp3", "wav", "ogg"]:
		last_error = "Поддерживаются файлы MP3, WAV и OGG Vorbis."
		return false
	if not FileAccess.file_exists(path):
		last_error = "Файл не найден или недоступен для чтения."
		return false

	var new_stream: AudioStream = null
	match extension:
		"mp3":
			new_stream = AudioStreamMP3.load_from_file(path)
		"wav":
			new_stream = AudioStreamWAV.load_from_file(path)
		"ogg":
			new_stream = AudioStreamOggVorbis.load_from_file(path)

	if new_stream == null:
		last_error = "Не удалось прочитать аудиофайл. Проверьте его формат."
		return false

	_set_stream(new_stream, path.get_file().get_basename(), extension.to_upper(), true)
	return true


func load_demo() -> void:
	_set_stream(DEMO_STREAM, "Спектральный этюд", "Демо", true)
	last_error = ""


func toggle_playback() -> void:
	if player.stream == null:
		return
	if player.playing:
		player.stream_paused = not player.stream_paused
	else:
		player.play()
	playback_changed.emit()


func is_active() -> bool:
	return player.playing and not player.stream_paused


func get_spectrum_analysis(delta: float) -> Vector3:
	var target := Vector3.ZERO
	if is_active():
		if _analyzer == null and _bus_index >= 0:
			_analyzer = AudioServer.get_bus_effect_instance(_bus_index, 0) as AudioEffectSpectrumAnalyzerInstance
		if _analyzer != null:
			target = Vector3(
				_read_band(20.0, 250.0),
				_read_band(250.0, 2000.0),
				_read_band(2000.0, 8000.0)
			)
	_spectrum = SpectrumMapper.smooth(_spectrum, target, delta)
	return _spectrum


func get_audio_level(delta: float) -> float:
	var target := 0.0
	if is_active() and _bus_index >= 0:
		var left := AudioServer.get_bus_peak_volume_left_db(_bus_index, 0)
		var right := AudioServer.get_bus_peak_volume_right_db(_bus_index, 0)
		target = SpectrumMapper.normalize_peak(maxf(left, right))
	_level = SpectrumMapper.smooth_level(_level, target, delta)
	return _level


func _read_band(from_hz: float, to_hz: float) -> float:
	var stereo := _analyzer.get_magnitude_for_frequency_range(
		from_hz, to_hz, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX
	)
	return SpectrumMapper.normalize_magnitude(maxf(stereo.x, stereo.y))


func _prepare_audio_bus() -> void:
	_bus_index = AudioServer.get_bus_index(BUS_NAME)
	if _bus_index < 0:
		AudioServer.add_bus()
		_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_index, BUS_NAME)
		AudioServer.set_bus_send(_bus_index, "Master")

	if AudioServer.get_bus_effect_count(_bus_index) == 0:
		var effect := AudioEffectSpectrumAnalyzer.new()
		effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		effect.buffer_length = 1.0
		AudioServer.add_bus_effect(_bus_index, effect)
	player.bus = BUS_NAME
	_analyzer = AudioServer.get_bus_effect_instance(_bus_index, 0) as AudioEffectSpectrumAnalyzerInstance


func _set_stream(stream: AudioStream, name: String, format: String, autoplay: bool) -> void:
	player.stop()
	player.stream = stream
	player.stream_paused = false
	source_name = name
	var seconds := roundi(stream.get_length())
	source_description = "%s · %d с" % [format, seconds]
	_spectrum = Vector3.ZERO
	_level = 0.0
	if autoplay:
		player.play()
	source_changed.emit()
	playback_changed.emit()


func _on_playback_finished() -> void:
	playback_changed.emit()

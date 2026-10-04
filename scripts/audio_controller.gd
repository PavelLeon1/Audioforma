extends Node
class_name AudioController

signal playback_changed
signal source_changed
signal playback_seeked

const SpectrumMapper = preload("res://scripts/spectrum_mapper.gd")
const BassBeatDetector = preload("res://scripts/bass_beat_detector.gd")
const DEMO_STREAM = preload("res://assets/audio/demo.wav")
const BUS_NAME := "Audio Analysis"
const INVALID_AUDIO_MESSAGE := "Не удалось прочитать аудиофайл. Проверьте его формат."

@onready var player: AudioStreamPlayer = $"../AudioPlayer"

var source_name := "Спектральный этюд"
var source_description := "Авторский аудиофрагмент · 24 секунды"
var last_error := ""
var _bus_index := -1
var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _spectrum := Vector3.ZERO
var _level := 0.0
var _bass_beat_detector = BassBeatDetector.new()
var _bass_hit := 0.0
var _volume_percent := 100.0
var _position := 0.0
var _analysis_ready_at_usec := 0


func _ready() -> void:
	_prepare_audio_bus()
	set_volume_percent(_volume_percent)
	player.finished.connect(_on_playback_finished)
	if player.stream == null:
		player.stream = DEMO_STREAM


func load_file(path: String) -> bool:
	last_error = ""
	var extension := path.get_extension().to_lower()
	if extension not in ["mp3", "wav", "ogg"]:
		last_error = "Поддерживаются файлы MP3, WAV и OGG Vorbis."
		return false
	var source_file := FileAccess.open(path, FileAccess.READ)
	if source_file == null:
		last_error = "Файл не найден или недоступен для чтения."
		return false
	if extension == "wav":
		var header: PackedByteArray = source_file.get_buffer(12)
		if header.size() < 12 or header.slice(0, 4).get_string_from_ascii() != "RIFF" or header.slice(8, 12).get_string_from_ascii() != "WAVE":
			source_file.close()
			last_error = INVALID_AUDIO_MESSAGE
			return false
	source_file.close()

	var new_stream: AudioStream = null
	match extension:
		"mp3":
			new_stream = AudioStreamMP3.load_from_file(path)
		"wav":
			new_stream = AudioStreamWAV.load_from_file(path)
		"ogg":
			new_stream = AudioStreamOggVorbis.load_from_file(path)

	if new_stream == null or new_stream.get_length() <= 0.0:
		last_error = INVALID_AUDIO_MESSAGE
		return false

	_set_stream(new_stream, path.get_file().get_basename(), extension.to_upper(), true)
	return true


func load_demo() -> void:
	_set_stream(DEMO_STREAM, "Спектральный этюд", "Демо", true)
	last_error = ""


func toggle_playback() -> void:
	if player.stream == null:
		return
	if player.stream_paused:
		player.stream_paused = false
	elif player.playing:
		_position = get_position()
		player.stream_paused = true
	else:
		if _position >= get_duration():
			_position = 0.0
		player.play(_position)
	playback_changed.emit()


func get_duration() -> float:
	return player.stream.get_length() if player.stream != null else 0.0


func get_position() -> float:
	if is_active():
		return clampf(player.get_playback_position(), 0.0, get_duration())
	return _position


func seek_to(seconds: float) -> bool:
	var duration := get_duration()
	if duration <= 0.0 or not is_finite(seconds):
		return false
	var keep_paused := not is_active()
	_position = clampf(seconds, 0.0, duration)
	player.stop()
	player.stream_paused = false
	_clear_analysis()
	# Новый экземпляр FFT не содержит спектр участка до перемотки.
	if _bus_index >= 0 and AudioServer.get_bus_effect_count(_bus_index) > 0:
		var effect := AudioServer.get_bus_effect(_bus_index, 0)
		AudioServer.remove_bus_effect(_bus_index, 0)
		AudioServer.add_bus_effect(_bus_index, effect, 0)
		_analyzer = AudioServer.get_bus_effect_instance(_bus_index, 0) as AudioEffectSpectrumAnalyzerInstance
	_analysis_ready_at_usec = Time.get_ticks_usec() + 60_000
	if _position < duration:
		player.play(_position)
		player.stream_paused = keep_paused
	playback_seeked.emit()
	playback_changed.emit()
	return true


func is_active() -> bool:
	return player.playing and not player.stream_paused


func get_spectrum_analysis(delta: float) -> Vector3:
	var target := Vector3.ZERO
	_bass_hit = 0.0
	if is_active() and Time.get_ticks_usec() >= _analysis_ready_at_usec:
		if _analyzer == null and _bus_index >= 0:
			_analyzer = AudioServer.get_bus_effect_instance(_bus_index, 0) as AudioEffectSpectrumAnalyzerInstance
		if _analyzer != null:
			target = Vector3(
				_read_band(20.0, 250.0),
				_read_band(250.0, 2000.0),
				_read_band(2000.0, 8000.0)
			)
			var bass_magnitude := _read_magnitude(20.0, 120.0, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
			_bass_hit = _bass_beat_detector.update(bass_magnitude, delta, true)
		else:
			_bass_beat_detector.reset()
	else:
		_bass_beat_detector.reset()
	_spectrum = SpectrumMapper.smooth(_spectrum, target, delta)
	return _spectrum


func get_bass_hit() -> float:
	return _bass_hit


func set_bass_sensitivity(value: float) -> void:
	_bass_beat_detector.sensitivity = clampf(value, 0.5, 2.0)


func get_bass_sensitivity() -> float:
	return _bass_beat_detector.sensitivity


func set_volume_percent(value: float) -> void:
	_volume_percent = clampf(value, 0.0, 100.0)
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_volume_linear(master_index, _volume_percent / 100.0)


func get_volume_percent() -> float:
	return _volume_percent


func get_audio_level(delta: float) -> float:
	var target := 0.0
	if is_active() and _bus_index >= 0 and Time.get_ticks_usec() >= _analysis_ready_at_usec:
		var left := AudioServer.get_bus_peak_volume_left_db(_bus_index, 0)
		var right := AudioServer.get_bus_peak_volume_right_db(_bus_index, 0)
		target = SpectrumMapper.normalize_peak(maxf(left, right))
	_level = SpectrumMapper.smooth_level(_level, target, delta)
	return _level


func _read_band(from_hz: float, to_hz: float) -> float:
	return SpectrumMapper.normalize_magnitude(_read_magnitude(from_hz, to_hz))


func _read_magnitude(from_hz: float, to_hz: float, mode: int = AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX) -> float:
	var stereo := _analyzer.get_magnitude_for_frequency_range(
		from_hz, to_hz, mode
	)
	return maxf(stereo.x, stereo.y)


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
	_position = 0.0
	_analysis_ready_at_usec = 0
	_clear_analysis()
	if autoplay:
		player.play()
	source_changed.emit()
	playback_changed.emit()


func _on_playback_finished() -> void:
	_position = get_duration()
	playback_changed.emit()


func _clear_analysis() -> void:
	_spectrum = Vector3.ZERO
	_level = 0.0
	_bass_beat_detector.reset()
	_bass_hit = 0.0

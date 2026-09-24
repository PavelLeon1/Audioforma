extends SceneTree

const AudioControllerScript = preload("res://scripts/audio_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node.new()
	root.add_child(holder)
	var player := AudioStreamPlayer.new()
	player.name = "AudioPlayer"
	holder.add_child(player)
	var controller: AudioController = AudioControllerScript.new()
	controller.name = "AudioController"
	holder.add_child(controller)

	var fixture_root := ProjectSettings.globalize_path("res://tests/fixtures")
	for entry in [{"hz": 80, "band": 0}, {"hz": 800, "band": 1}, {"hz": 5000, "band": 2}]:
		var path: String = fixture_root.path_join("%d.wav" % entry.hz)
		if not controller.load_file(path):
			_fail("Не удалось загрузить %s: %s" % [path, controller.last_error])
			return
		var levels := Vector3.ZERO
		var volume := 0.0
		for frame in range(20):
			await create_timer(0.04).timeout
			levels = controller.get_spectrum_analysis(0.04)
			volume = controller.get_audio_level(0.04)
		print("TONE %d Hz: %.3f %.3f %.3f" % [entry.hz, levels.x, levels.y, levels.z])
		if volume < 0.2:
			_fail("Сигнал %d Гц не изменил общую громкость" % entry.hz)
			return
		var selected: float = levels[entry.band]
		var other_a: float = levels[(entry.band + 1) % 3]
		var other_b: float = levels[(entry.band + 2) % 3]
		if selected < 0.2 or selected < maxf(other_a, other_b) + 0.08:
			_fail("Сигнал %d Гц не выделился в ожидаемой полосе" % entry.hz)
			return
		if entry.hz == 80:
			var position_before_pause := player.get_playback_position()
			controller.toggle_playback()
			if controller.is_active():
				_fail("Пауза должна останавливать анализ и воспроизведение")
				return
			var paused_volume := volume
			for frame in range(10):
				await create_timer(0.04).timeout
				paused_volume = controller.get_audio_level(0.04)
			if paused_volume >= volume * 0.4:
				_fail("При паузе свечение должно затухать")
				return
			if absf(player.get_playback_position() - position_before_pause) > 0.06:
				_fail("Позиция воспроизведения меняется во время паузы")
				return
			controller.toggle_playback()
			if not controller.is_active():
				_fail("После паузы воспроизведение должно продолжаться")
				return
			await create_timer(0.12).timeout
			if player.get_playback_position() <= position_before_pause + 0.05:
				_fail("Возобновление должно продолжать звук с прежней позиции")
				return

	for extension in ["mp3", "ogg"]:
		var encoded_path: String = fixture_root.path_join("800.%s" % extension)
		if not controller.load_file(encoded_path):
			_fail("Не удалось загрузить %s: %s" % [encoded_path, controller.last_error])
			return
		var encoded_levels := Vector3.ZERO
		for frame in range(12):
			await create_timer(0.04).timeout
			encoded_levels = controller.get_spectrum_analysis(0.04)
		print("FORMAT %s: %.3f %.3f %.3f" % [extension, encoded_levels.x, encoded_levels.y, encoded_levels.z])
		if encoded_levels.y < 0.2 or encoded_levels.y < maxf(encoded_levels.x, encoded_levels.z) + 0.08:
			_fail("Сигнал 800 Гц в %s не выделился в средней полосе" % extension)
			return

	var previous_stream := player.stream
	if controller.load_file(fixture_root.path_join("missing.wav")):
		_fail("Отсутствующий файл не должен загружаться")
		return
	if player.stream != previous_stream:
		_fail("Ошибка загрузки не должна заменять текущий трек")
		return

	controller.load_demo()
	if controller.source_name != "Спектральный этюд":
		_fail("Не удалось вернуться к демофрагменту")
		return

	print("PASS: загрузка WAV/MP3/OGG, спектр и общая громкость")
	player.stop()
	holder.queue_free()
	await create_timer(0.3).timeout
	var bus_index := AudioServer.get_bus_index("Audio Analysis")
	if bus_index >= 0:
		AudioServer.remove_bus(bus_index)
	await create_timer(0.1).timeout
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

extends SceneTree

const ControllerScript = preload("res://scripts/audio_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node.new()
	root.add_child(holder)
	var player := AudioStreamPlayer.new()
	player.name = "AudioPlayer"
	holder.add_child(player)
	var controller: AudioController = ControllerScript.new()
	controller.name = "AudioController"
	holder.add_child(controller)
	controller.set_volume_percent(0.0)
	var dense := _make_dense_stream()
	var old_max_fps := Engine.max_fps
	for profile in ["demo", "dense"]:
		var counts: Array[int] = []
		for fps in [30, 60, 144]:
			Engine.max_fps = fps
			if profile == "demo":
				controller.load_demo()
			else:
				controller._set_stream(dense, "Плотный тестовый бас", "PCM", true)
			var hits := 0
			var frames := 0
			var started := Time.get_ticks_usec()
			var previous := started
			while Time.get_ticks_usec() - started < 4_000_000:
				await process_frame
				var now := Time.get_ticks_usec()
				controller.get_spectrum_analysis((now - previous) / 1_000_000.0)
				previous = now
				frames += 1
				if controller.get_bass_hit() > 0.0:
					hits += 1
			counts.append(hits)
			print("PLAYBACK %s %d FPS: %d ударов, %d кадров" % [profile, fps, hits, frames])
			var minimum := 5 if profile == "demo" else 14
			var maximum := 10 if profile == "demo" else 22
			if hits < minimum or hits > maximum:
				Engine.max_fps = old_max_fps
				_fail("Число ударов %s при %d FPS вне ожидаемого диапазона" % [profile, fps])
				return
		if counts.max() - counts.min() > 2:
			Engine.max_fps = old_max_fps
			_fail("Реальный анализ %s заметно зависит от FPS: %s" % [profile, counts])
			return
	Engine.max_fps = old_max_fps
	player.stop()
	holder.queue_free()
	await create_timer(0.3).timeout
	var bus_index := AudioServer.get_bus_index("Audio Analysis")
	if bus_index >= 0:
		AudioServer.remove_bus(bus_index)
	print("PASS: воспроизведение демо и плотного баса при 30/60/144 FPS")
	quit(0)


func _make_dense_stream() -> AudioStreamWAV:
	var sample_rate := 44100
	var data := PackedByteArray()
	data.resize(sample_rate * 5 * 2)
	for index in range(sample_rate * 5):
		var time := float(index) / sample_rate
		var phase := fmod(time, 0.2)
		var kick := sin(TAU * 65.0 * time) * exp(-phase * 32.0) * 0.6
		var bass := sin(TAU * 110.0 * time) * 0.045
		var mid := sin(TAU * 800.0 * time) * 0.12
		var high := sin(TAU * 5000.0 * time) * exp(-phase * 65.0) * 0.07
		var sample := clampf((kick + bass + mid + high) * 1.5, -0.65, 0.65)
		data.encode_s16(index * 2, roundi(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

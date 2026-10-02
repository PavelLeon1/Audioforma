extends SceneTree

const Detector = preload("res://scripts/bass_beat_detector.gd")


func _initialize() -> void:
	var detector = Detector.new()
	for frame in range(40):
		if detector.update(db_to_linear(-28.0), 0.02, true) != 0.0:
			_fail("Ровный бас не должен запускать бегущую волну")
			return
	if detector.update(db_to_linear(-26.0), 0.02, true) != 0.0:
		_fail("Небольшое изменение баса не должно считаться ударом")
		return
	var first_hit: float = detector.update(db_to_linear(-20.0), 0.02, true)
	if first_hit < 0.4:
		_fail("Резкий басовый удар не обнаружен")
		return
	if detector.update(db_to_linear(-20.0), 0.02, true) != 0.0:
		_fail("Один удар не должен запускать две волны")
		return
	for frame in range(25):
		detector.update(db_to_linear(-28.0), 0.02, true)
	if detector.update(db_to_linear(-20.0), 0.02, true) < 0.4:
		_fail("Следующий басовый удар не обнаружен")
		return
	detector.update(0.0, 0.02, false)
	if detector.update(db_to_linear(-20.0), 0.02, true) != 0.0:
		_fail("После паузы детектор должен заново измерить фон")
		return
	detector.reset()
	for frame in range(40):
		detector.update(db_to_linear(-28.0), 0.02, true)
	detector.sensitivity = 2.0
	if detector.update(db_to_linear(-26.0), 0.02, true) <= 0.0:
		_fail("Повышенная чувствительность должна замечать более слабый удар")
		return
	for profile in [{"name": "обычный", "period": 0.5, "floor": -36.0, "peak": -18.0}, {"name": "плотный", "period": 0.2, "floor": -26.0, "peak": -16.0}]:
		var reference_hits: Array[float] = []
		for fps in [30, 60, 144]:
			var hits := _simulate_profile(fps, profile.period, profile.floor, profile.peak)
			var expected := roundi(3.0 / profile.period)
			if hits.size() != expected:
				_fail("%s бас при %d FPS: %d событий вместо %d" % [profile.name, fps, hits.size(), expected])
				return
			if not reference_hits.is_empty():
				for index in range(hits.size()):
					if absf(hits[index] - reference_hits[index]) > 1.0 / 30.0 + 0.005:
						_fail("Время удара зависит от FPS больше чем на один кадр 30 FPS")
						return
			reference_hits = hits
			print("PROFILE %s %d FPS: %d событий" % [profile.name, fps, hits.size()])
	var ramp_detector = Detector.new()
	for frame in range(60):
		ramp_detector.update(db_to_linear(-36.0), 1.0 / 60.0, true)
	var ramp_hits := 0
	for frame in range(120):
		if ramp_detector.update(db_to_linear(-36.0 + frame * 0.2), 1.0 / 60.0, true) > 0.0:
			ramp_hits += 1
	if ramp_hits != 0:
		_fail("Плавное усиление баса не должно считаться серией ударов")
		return
	print("PASS: детектор ударов, плотный бас и сравнение 30/60/144 FPS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _simulate_profile(fps: int, period: float, floor_db: float, peak_db: float) -> Array[float]:
	var detector = Detector.new()
	var hits: Array[float] = []
	var delta := 1.0 / fps
	for frame in range(fps):
		detector.update(db_to_linear(floor_db), delta, true)
	for frame in range(3 * fps):
		var time := frame * delta
		var phase := fmod(time, period)
		var envelope := phase / 0.035 if phase < 0.035 else maxf(0.0, 1.0 - (phase - 0.035) / 0.10)
		var db := lerpf(floor_db, peak_db, envelope)
		if detector.update(db_to_linear(db), delta, true) > 0.0:
			hits.append(time)
	return hits

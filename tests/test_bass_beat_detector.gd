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
	print("PASS: детектор басовых ударов")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

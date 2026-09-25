extends SceneTree

const Mapper = preload("res://scripts/spectrum_mapper.gd")


func _initialize() -> void:
	if Mapper.normalize_magnitude(0.0) != 0.0:
		_fail("Нулевой сигнал должен давать нулевой уровень")
		return
	if Mapper.normalize_magnitude(1.0) != 1.0:
		_fail("Сильный сигнал должен ограничиваться единицей")
		return
	if Mapper.normalize_magnitude(0.001) >= Mapper.normalize_magnitude(0.1):
		_fail("Уровень должен возрастать вместе с амплитудой")
		return

	var attack := Mapper.smooth(Vector3.ZERO, Vector3.ONE, 0.1)
	var release := Mapper.smooth(Vector3.ONE, Vector3.ZERO, 0.1)
	if attack.x <= 0.0 or attack.x >= 1.0:
		_fail("Атака должна плавно приближаться к новому уровню")
		return
	if release.x <= 0.0 or release.x >= 1.0:
		_fail("Спад должен плавно приближаться к нулю")
		return
	if attack.x <= 1.0 - release.x:
		_fail("Атака должна быть быстрее спада")
		return
	if Mapper.normalize_peak(-60.0) != 0.0 or Mapper.normalize_peak(0.0) != 1.0:
		_fail("Пиковая громкость должна ограничиваться диапазоном 0–1")
		return
	if Mapper.normalize_peak(-6.0) >= 1.0 or Mapper.normalize_magnitude(0.1) >= 1.0:
		_fail("Шкала должна сохранять запас для более громких треков")
		return
	if Mapper.normalize_peak(-30.0) <= Mapper.normalize_peak(-40.0):
		_fail("Рост громкости должен увеличивать яркость")
		return

	print("PASS: нормализация и сглаживание спектра и громкости")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

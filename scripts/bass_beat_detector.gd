extends RefCounted

const MIN_DB := -45.0
const ONSET_DB := 2.6
const RISE_DB := 1.2
const RISE_WINDOW_SECONDS := 0.08
const REARM_DB := 1.2
const BASELINE_SECONDS := 0.65
const COOLDOWN_SECONDS := 0.14

var _initialized := false
var _baseline_db := 0.0
var _cooldown := 0.0
var _elapsed := 0.0
var _history: Array[Vector2] = []
var _armed := true
var _peak_db := 0.0
var sensitivity := 1.0


func reset() -> void:
	_initialized = false
	_baseline_db = 0.0
	_cooldown = 0.0
	_elapsed = 0.0
	_history.clear()
	_armed = true
	_peak_db = 0.0


func update(magnitude: float, delta: float, active: bool) -> float:
	if not active:
		reset()
		return 0.0
	if not is_finite(magnitude) or not is_finite(delta) or delta <= 0.0:
		return 0.0

	var current_db := linear_to_db(maxf(magnitude, 0.000001))
	if not _initialized:
		if current_db < MIN_DB:
			return 0.0
		_initialized = true
		_baseline_db = current_db
		_history.append(Vector2(0.0, current_db))
		_peak_db = current_db
		return 0.0

	_elapsed += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_history.append(Vector2(_elapsed, current_db))
	var reference_time := _elapsed - RISE_WINDOW_SECONDS
	while _history.size() > 2 and _history[1].x <= reference_time:
		_history.pop_front()
	var reference_db := _history[0].y
	if _history[0].x < reference_time and _history[1].x > _history[0].x:
		var weight := clampf((reference_time - _history[0].x) / (_history[1].x - _history[0].x), 0.0, 1.0)
		reference_db = lerpf(_history[0].y, _history[1].y, weight)
	var threshold_factor := clampf(sensitivity, 0.5, 2.0)
	if not _armed:
		_peak_db = maxf(_peak_db, current_db)
		if current_db <= _peak_db - REARM_DB / threshold_factor:
			_armed = true
	var contrast := current_db - _baseline_db
	var rise := current_db - reference_db
	var detected := _armed and current_db >= MIN_DB and contrast >= ONSET_DB / threshold_factor and rise >= RISE_DB / threshold_factor and _cooldown <= 0.0
	var baseline_weight := 1.0 - exp(-delta / BASELINE_SECONDS)
	_baseline_db = lerpf(_baseline_db, current_db, baseline_weight)
	if detected:
		_cooldown = COOLDOWN_SECONDS
		_armed = false
		_peak_db = current_db
		return clampf(contrast / 7.0, 0.4, 1.0)
	return 0.0

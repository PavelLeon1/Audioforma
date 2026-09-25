extends RefCounted

const MIN_DB := -45.0
const ONSET_DB := 2.6
const RISE_DB := 1.2
const BASELINE_SECONDS := 0.65
const COOLDOWN_SECONDS := 0.27

var _initialized := false
var _baseline_db := 0.0
var _previous_db := 0.0
var _cooldown := 0.0


func reset() -> void:
	_initialized = false
	_baseline_db = 0.0
	_previous_db = 0.0
	_cooldown = 0.0


func update(magnitude: float, delta: float, active: bool) -> float:
	if not active:
		reset()
		return 0.0

	var current_db := linear_to_db(maxf(magnitude, 0.000001))
	if not _initialized:
		_initialized = true
		_baseline_db = current_db
		_previous_db = current_db
		return 0.0

	_cooldown = maxf(0.0, _cooldown - maxf(delta, 0.0))
	var contrast := current_db - _baseline_db
	var rise := current_db - _previous_db
	var detected := current_db >= MIN_DB and contrast >= ONSET_DB and rise >= RISE_DB and _cooldown <= 0.0
	var baseline_weight := 1.0 - exp(-maxf(delta, 0.0) / BASELINE_SECONDS)
	_baseline_db = lerpf(_baseline_db, current_db, baseline_weight)
	_previous_db = current_db
	if detected:
		_cooldown = COOLDOWN_SECONDS
		return clampf(contrast / 7.0, 0.4, 1.0)
	return 0.0

extends RefCounted

const FLOOR_DB := -66.0
const CEILING_DB := -18.0
const ATTACK_SECONDS := 0.055
const RELEASE_SECONDS := 0.22


static func normalize_magnitude(magnitude: float) -> float:
	if magnitude <= 0.0:
		return 0.0
	var decibels := linear_to_db(magnitude)
	return clampf((decibels - FLOOR_DB) / (CEILING_DB - FLOOR_DB), 0.0, 1.0)


static func smooth(current: Vector3, target: Vector3, delta: float) -> Vector3:
	return Vector3(
		_smooth_channel(current.x, target.x, delta),
		_smooth_channel(current.y, target.y, delta),
		_smooth_channel(current.z, target.z, delta)
	)


static func _smooth_channel(current: float, target: float, delta: float) -> float:
	var duration := ATTACK_SECONDS if target > current else RELEASE_SECONDS
	var weight := 1.0 - exp(-maxf(delta, 0.0) / duration)
	return lerpf(current, target, weight)

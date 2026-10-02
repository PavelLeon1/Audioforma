uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform int deformation_mode : hint_range(0, 3) = 0;
uniform float motion_time = 0.0;
uniform vec4 accent_color : source_color = vec4(0.76, 0.16, 0.92, 1.0);
uniform vec4 quiet_color : source_color = vec4(0.08, 0.48, 1.0, 1.0);
uniform vec4 loud_color : source_color = vec4(1.0, 0.16, 0.22, 1.0);
uniform float loudness_color_mix : hint_range(0.0, 1.0) = 0.45;
uniform float spectrum_mix : hint_range(0.0, 1.0) = 0.6;
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;
uniform float shape_strength : hint_range(0.0, 2.0) = 1.0;
uniform float bass_pulse_strength : hint_range(0.0, 2.0) = 1.0;
uniform float beat_pulse_strength : hint_range(0.0, 2.0) = 1.0;
uniform float beat_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float bass_wave_strength : hint_range(0.0, 2.0) = 1.0;
uniform float mid_wave_strength : hint_range(0.0, 2.0) = 1.0;
uniform float high_ripple_strength : hint_range(0.0, 2.0) = 1.0;
uniform float motion_speed : hint_range(0.25, 2.0) = 1.0;
uniform float outline_width : hint_range(0.5, 2.0) = 1.0;
uniform float bass_hit_time_a = -10.0;
uniform float bass_hit_strength_a : hint_range(0.0, 1.0) = 0.0;
uniform vec3 bass_hit_origin_a = vec3(0.0, 1.0, 0.0);
uniform float bass_hit_paired_a = 0.0;
uniform float bass_hit_time_b = -10.0;
uniform float bass_hit_strength_b : hint_range(0.0, 1.0) = 0.0;
uniform vec3 bass_hit_origin_b = vec3(0.0, 1.0, 0.0);
uniform float bass_hit_paired_b = 0.0;

float bass_wave(vec3 direction, float hit_time, float strength, vec3 origin, float paired) {
	float age = motion_time - hit_time;
	float alignment = dot(direction, normalize(origin));
	float polar_angle = acos(clamp(mix(alignment, abs(alignment), paired), -1.0, 1.0));
	float distance_to_front = (polar_angle - age * 4.0 * motion_speed) / 0.22;
	float front = exp(-distance_to_front * distance_to_front);
	float attenuation = exp(-max(age, 0.0) * 0.9);
	return strength * front * attenuation * step(0.0, age) * (1.0 - step(1.1, age));
}

float bass_front(vec3 direction) {
	return bass_wave(direction, bass_hit_time_a, bass_hit_strength_a, bass_hit_origin_a, bass_hit_paired_a)
		+ bass_wave(direction, bass_hit_time_b, bass_hit_strength_b, bass_hit_origin_b, bass_hit_paired_b);
}

float surface_wave(vec3 point) {
	return sin(point.y * 5.5 + atan(point.z, point.x) * 3.0 - motion_time * 4.0 * motion_speed);
}

float surface_ripple(vec3 point) {
	return sin(point.x * 23.0 + motion_time * 15.0 * motion_speed)
		* sin(point.y * 23.0 - motion_time * 13.0 * motion_speed);
}

float bounded_offset(float offset, float radius) {
	// Малые смещения сохраняются; большие плавно приближаются к пределу.
	float limit = max(radius, 0.001) * (offset < 0.0 ? 0.55 : 0.85);
	float knee = limit * 0.65;
	float excess = max(abs(offset) - knee, 0.0);
	float amount = min(abs(offset), knee) + (limit - knee) * (1.0 - exp(-excess / (limit - knee)));
	return sign(offset) * amount;
}

float deformation_offset(vec3 point, float wave, float ripple, float front) {
	float offset = 0.0;
	if (deformation_mode == 0 || deformation_mode == 1) {
		float pulse = bass * 0.24 * bass_pulse_strength + beat_pulse * 0.34 * beat_pulse_strength;
		offset += (pulse + front * 0.38 * bass_wave_strength) * shape_strength;
	}
	if (deformation_mode == 0 || deformation_mode == 2) {
		offset += mid * wave * 0.28 * mid_wave_strength * shape_strength;
	}
	if (deformation_mode == 0 || deformation_mode == 3) {
		offset += high * ripple * 0.14 * high_ripple_strength * shape_strength;
	}
	return bounded_offset(offset, length(point));
}

vec3 audio_color() {
	vec3 level_color = mix(quiet_color.rgb, loud_color.rgb, smoothstep(0.12, 0.90, level));
	vec3 base_color = mix(accent_color.rgb, level_color, loudness_color_mix);
	float band_sum = bass + mid + high;
	vec3 band_color = (bass * vec3(0.58, 0.20, 1.0)
		+ mid * vec3(1.0, 0.16, 0.53)
		+ high * vec3(0.08, 0.82, 1.0)) / max(band_sum, 0.001);
	// Спектр добавляет акцент, оставляя видимой зависимость оттенка от громкости.
	float spectral_weight = spectrum_mix * 0.6 * smoothstep(0.02, 0.12, band_sum);
	return mix(base_color, band_color, spectral_weight);
}

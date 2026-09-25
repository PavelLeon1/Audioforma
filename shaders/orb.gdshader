shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform int deformation_mode : hint_range(0, 3) = 0;
uniform float motion_time = 0.0;
uniform float bass_hit_time_a = -10.0;
uniform float bass_hit_strength_a : hint_range(0.0, 1.0) = 0.0;
uniform float bass_hit_time_b = -10.0;
uniform float bass_hit_strength_b : hint_range(0.0, 1.0) = 0.0;

varying float wave_light;
varying float ripple_light;
varying float impact_light;

float bass_wave(vec3 direction, float hit_time, float strength) {
	float age = motion_time - hit_time;
	float polar_angle = acos(clamp(direction.y, -1.0, 1.0));
	float distance_to_front = (polar_angle - age * 4.0) / 0.22;
	float front = exp(-distance_to_front * distance_to_front);
	float attenuation = exp(-max(age, 0.0) * 0.9);
	return strength * front * attenuation * step(0.0, age) * (1.0 - step(1.1, age));
}

void vertex() {
	vec3 point = VERTEX;
	vec3 direction = normalize(NORMAL);
	float angle = atan(point.z, point.x);
	float pulse = bass * 0.34;
	float wave = sin(point.y * 5.5 + angle * 3.0 - motion_time * 4.0);
	float ripple = sin(point.x * 23.0 + motion_time * 15.0)
		* sin(point.y * 23.0 - motion_time * 13.0);
	float bass_front = bass_wave(direction, bass_hit_time_a, bass_hit_strength_a)
		+ bass_wave(direction, bass_hit_time_b, bass_hit_strength_b);
	float offset = 0.0;

	if (deformation_mode == 0 || deformation_mode == 1) {
		offset += pulse + bass_front * 0.38;
	}
	if (deformation_mode == 0 || deformation_mode == 2) {
		offset += mid * wave * 0.23;
	}
	if (deformation_mode == 0 || deformation_mode == 3) {
		offset += high * ripple * 0.095;
	}

	VERTEX += direction * offset;
	wave_light = wave * mid;
	ripple_light = ripple * high;
	impact_light = bass_front;
}

void fragment() {
	vec3 quiet_color = vec3(0.055, 0.16, 0.31);
	vec3 bass_color = vec3(0.17, 0.14, 0.43);
	vec3 mid_color = vec3(0.48, 0.10, 0.32);
	vec3 high_color = vec3(0.09, 0.48, 0.60);
	float band_sum = max(bass + mid + high, 0.001);
	vec3 band_color = (bass * bass_color + mid * mid_color + high * high_color) / band_sum;
	vec3 surface_color = mix(quiet_color, band_color, smoothstep(0.05, 0.65, band_sum));
	float pattern = max(wave_light, 0.0) * 0.23 + max(ripple_light, 0.0) * 0.13 + impact_light * 0.52;
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.6);

	ALBEDO = surface_color + vec3(pattern * 0.18, pattern * 0.42, pattern * 0.56);
	METALLIC = 0.23;
	ROUGHNESS = 0.27;
	EMISSION = surface_color * (0.12 + level * 0.78 + pattern * 0.55)
		+ band_color * rim * (0.2 + level * 0.8)
		+ vec3(0.32, 0.78, 1.0) * impact_light * 1.5;
}

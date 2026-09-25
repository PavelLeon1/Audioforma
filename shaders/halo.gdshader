shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform int deformation_mode : hint_range(0, 3) = 0;
uniform float motion_time = 0.0;
uniform vec4 accent_color : source_color = vec4(0.76, 0.16, 0.92, 1.0);
uniform float spectrum_mix : hint_range(0.0, 1.0) = 0.6;
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;
uniform float shape_strength : hint_range(0.0, 2.0) = 1.0;
uniform float bass_pulse_strength : hint_range(0.0, 2.0) = 1.0;
uniform float bass_wave_strength : hint_range(0.0, 2.0) = 1.0;
uniform float mid_wave_strength : hint_range(0.0, 2.0) = 1.0;
uniform float high_ripple_strength : hint_range(0.0, 2.0) = 1.0;
uniform float motion_speed : hint_range(0.25, 2.0) = 1.0;
uniform float outline_width : hint_range(0.5, 2.0) = 1.0;
uniform float bass_hit_time_a = -10.0;
uniform float bass_hit_strength_a : hint_range(0.0, 1.0) = 0.0;
uniform float bass_hit_time_b = -10.0;
uniform float bass_hit_strength_b : hint_range(0.0, 1.0) = 0.0;

varying float impact_light;
varying float ripple_light;

float bass_wave(vec3 direction, float hit_time, float strength) {
	float age = motion_time - hit_time;
	float polar_angle = acos(clamp(direction.y, -1.0, 1.0));
	float distance_to_front = (polar_angle - age * 4.0 * motion_speed) / 0.22;
	float front = exp(-distance_to_front * distance_to_front);
	float attenuation = exp(-max(age, 0.0) * 0.9);
	return strength * front * attenuation * step(0.0, age) * (1.0 - step(1.1, age));
}

void vertex() {
	vec3 point = VERTEX;
	vec3 direction = normalize(NORMAL);
	float angle = atan(point.z, point.x);
	float wave = sin(point.y * 5.5 + angle * 3.0 - motion_time * 4.0 * motion_speed);
	float ripple = sin(point.x * 23.0 + motion_time * 15.0 * motion_speed)
		* sin(point.y * 23.0 - motion_time * 13.0 * motion_speed);
	float bass_front = bass_wave(direction, bass_hit_time_a, bass_hit_strength_a)
		+ bass_wave(direction, bass_hit_time_b, bass_hit_strength_b);
	float offset = 0.04;
	if (deformation_mode == 0 || deformation_mode == 1) {
		offset += (bass * 0.34 * bass_pulse_strength + bass_front * 0.38 * bass_wave_strength) * shape_strength;
	}
	if (deformation_mode == 0 || deformation_mode == 2) {
		offset += mid * wave * 0.23 * mid_wave_strength * shape_strength;
	}
	if (deformation_mode == 0 || deformation_mode == 3) {
		offset += high * ripple * 0.095 * high_ripple_strength * shape_strength;
	}
	VERTEX += direction * offset;
	impact_light = bass_front;
	ripple_light = ripple;
}

void fragment() {
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float rim = pow(1.0 - facing, 4.0 / outline_width);
	float band_sum = max(bass + mid + high, 0.001);
	vec3 band_color = (bass * vec3(0.55, 0.12, 1.0)
		+ mid * vec3(1.0, 0.09, 0.53)
		+ high * vec3(0.06, 0.85, 1.0)) / band_sum;
	vec3 color = mix(accent_color.rgb, band_color, spectrum_mix);
	float flicker = 0.88 + 0.12 * sin(motion_time * 2.0 * motion_speed);
	float strength = (0.24 + level * 1.4 + impact_light * bass_wave_strength * 1.6) * flicker * glow_strength;
	float edge = rim * strength;
	float sparkle = max(ripple_light, 0.0) * high * rim * 0.16;
	ALBEDO = color * (edge + sparkle);
	EMISSION = color * (edge * 2.2 + sparkle);
	ALPHA = clamp(edge * 0.8 + sparkle, 0.0, 0.9);
}

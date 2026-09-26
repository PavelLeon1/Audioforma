shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

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

varying float wave_light;
varying float ripple_light;
varying float impact_light;
varying vec3 local_point;

float bass_wave(vec3 direction, float hit_time, float strength, vec3 origin, float paired) {
	float age = motion_time - hit_time;
	float alignment = dot(direction, normalize(origin));
	float polar_angle = acos(clamp(mix(alignment, abs(alignment), paired), -1.0, 1.0));
	float distance_to_front = (polar_angle - age * 4.0 * motion_speed) / 0.22;
	float front = exp(-distance_to_front * distance_to_front);
	float attenuation = exp(-max(age, 0.0) * 0.9);
	return strength * front * attenuation * step(0.0, age) * (1.0 - step(1.1, age));
}

void vertex() {
	vec3 point = VERTEX;
	vec3 direction = normalize(NORMAL);
	float angle = atan(point.z, point.x);
	float pulse = bass * 0.24 * bass_pulse_strength + beat_pulse * 0.34 * beat_pulse_strength;
	float wave = sin(point.y * 5.5 + angle * 3.0 - motion_time * 4.0 * motion_speed);
	float ripple = sin(point.x * 23.0 + motion_time * 15.0 * motion_speed)
		* sin(point.y * 23.0 - motion_time * 13.0 * motion_speed);
	float bass_front = bass_wave(direction, bass_hit_time_a, bass_hit_strength_a, bass_hit_origin_a, bass_hit_paired_a)
		+ bass_wave(direction, bass_hit_time_b, bass_hit_strength_b, bass_hit_origin_b, bass_hit_paired_b);
	float offset = 0.0;

	if (deformation_mode == 0 || deformation_mode == 1) {
		offset += (pulse + bass_front * 0.38 * bass_wave_strength) * shape_strength;
	}
	if (deformation_mode == 0 || deformation_mode == 2) {
		offset += mid * wave * 0.28 * mid_wave_strength * shape_strength;
	}
	if (deformation_mode == 0 || deformation_mode == 3) {
		offset += high * ripple * 0.14 * high_ripple_strength * shape_strength;
	}

	VERTEX += direction * offset;
	wave_light = wave * mid;
	ripple_light = ripple * high;
	impact_light = bass_front;
	local_point = point;
}

void fragment() {
	vec3 bass_color = vec3(0.58, 0.20, 1.0);
	vec3 mid_color = vec3(1.0, 0.16, 0.53);
	vec3 high_color = vec3(0.08, 0.82, 1.0);
	float band_sum = max(bass + mid + high, 0.001);
	vec3 band_color = (bass * bass_color + mid * mid_color + high * high_color) / band_sum;
	vec3 light_color = mix(accent_color.rgb, band_color, spectrum_mix);
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.2 / outline_width);
	float longitude = atan(local_point.z, local_point.x);
	float filament = pow(max(sin(local_point.y * 8.0 + longitude * 3.0 - motion_time * 0.65 * motion_speed), 0.0), 22.0);
	float surface_detail = filament * (0.025 + mid * 0.09)
		+ max(wave_light, 0.0) * mid_wave_strength * 0.12
		+ max(ripple_light, 0.0) * high_ripple_strength * 0.18;

	ALBEDO = vec3(0.008, 0.011, 0.026) + light_color * 0.006;
	METALLIC = 0.0;
	ROUGHNESS = 0.82;
	SPECULAR = 0.08;
	EMISSION = glow_strength * (light_color * (rim * (0.28 + level * 1.2 + beat_pulse * beat_pulse_strength * 0.35) + surface_detail)
		+ mix(light_color, vec3(0.30, 0.72, 1.0), spectrum_mix) * impact_light * bass_wave_strength * 1.25);
}

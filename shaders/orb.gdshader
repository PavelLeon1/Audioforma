shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/reactive_common.gdshaderinc"

varying float wave_light;
varying float ripple_light;
varying float impact_light;
varying vec3 local_point;

void vertex() {
	vec3 point = VERTEX;
	vec3 direction = normalize(NORMAL);
	float wave = surface_wave(point);
	float ripple = surface_ripple(point);
	float front = bass_front(direction);
	float offset = deformation_offset(point, wave, ripple, front);

	VERTEX += direction * offset;
	wave_light = wave * mid;
	ripple_light = ripple * high;
	impact_light = front;
	local_point = point;
}

void fragment() {
	vec3 light_color = audio_color();
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

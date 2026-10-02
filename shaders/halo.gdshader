shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

#include "res://shaders/reactive_common.gdshaderinc"

varying float impact_light;
varying float ripple_light;
varying float wave_light;

void vertex() {
	vec3 point = VERTEX;
	vec3 direction = normalize(NORMAL);
	float wave = surface_wave(point);
	float ripple = surface_ripple(point);
	float front = bass_front(direction);
	float offset = deformation_offset(point, wave, ripple, front) + 0.04;

	VERTEX += direction * offset;
	impact_light = front;
	ripple_light = ripple * high;
	wave_light = wave * mid;
}

void fragment() {
	float facing = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float rim = pow(1.0 - facing, 4.0 / outline_width);
	vec3 color = audio_color();
	float flicker = 0.88 + 0.12 * sin(motion_time * 2.0 * motion_speed);
	float strength = (0.24 + level * 1.4 + beat_pulse * beat_pulse_strength * 0.45 + impact_light * bass_wave_strength * 1.6) * flicker * glow_strength;
	float edge = rim * strength;
	float sparkle = (max(ripple_light, 0.0) * high_ripple_strength * 0.34
		+ max(wave_light, 0.0) * mid_wave_strength * 0.16) * rim * glow_strength;
	ALBEDO = color * (edge + sparkle);
	EMISSION = color * (edge * 2.2 + sparkle);
	ALPHA = clamp(edge * 0.8 + sparkle, 0.0, 0.9);
}

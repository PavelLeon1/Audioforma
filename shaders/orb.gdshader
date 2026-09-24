shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float bass : hint_range(0.0, 1.0) = 0.0;
uniform float mid : hint_range(0.0, 1.0) = 0.0;
uniform float high : hint_range(0.0, 1.0) = 0.0;
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform int deformation_mode : hint_range(0, 3) = 0;
uniform float motion_time = 0.0;

varying float wave_light;
varying float ripple_light;

void vertex() {
	vec3 point = VERTEX;
	vec3 direction = normalize(NORMAL);
	float angle = atan(point.z, point.x);
	float pulse = bass * 0.34;
	float wave = sin(point.y * 5.5 + angle * 3.0 - motion_time * 4.0);
	float ripple = sin(point.x * 23.0 + motion_time * 15.0)
		* sin(point.y * 23.0 - motion_time * 13.0);
	float offset = 0.0;

	if (deformation_mode == 0 || deformation_mode == 1) {
		offset += pulse;
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
}

void fragment() {
	vec3 quiet_color = vec3(0.045, 0.33, 0.58);
	vec3 active_color = vec3(0.55, 0.09, 0.25);
	vec3 surface_color = mix(quiet_color, active_color, smoothstep(0.07, 0.92, level));
	float pattern = max(wave_light, 0.0) * 0.23 + max(ripple_light, 0.0) * 0.13;
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.6);

	ALBEDO = surface_color + vec3(pattern * 0.18, pattern * 0.42, pattern * 0.56);
	METALLIC = 0.23;
	ROUGHNESS = 0.27;
	EMISSION = surface_color * (0.12 + level * 0.85 + pattern * 0.4)
		+ mix(vec3(0.06, 0.3, 0.5), vec3(0.8, 0.13, 0.38), level) * rim * (0.2 + level * 0.8);
}
